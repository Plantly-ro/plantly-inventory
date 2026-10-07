import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/care_types.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/notifications/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Issue #16 follow-through — OS notification titles are baked at sync
/// time from `careKeyVerb(registry, key)`. Renaming a care type only
/// changed the registry, so already-scheduled reminders kept the old name
/// until some unrelated write happened to re-sync. `reminderSyncProvider`
/// now re-syncs when a care-type label changes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeNotificationService fake;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({'plantly_onboarded': true});
    fake = FakeNotificationService();
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        ref.onDispose(db.close);
        return db;
      }),
      notificationServiceProvider.overrideWith((ref) => fake),
    ]);
  });

  tearDown(() => container.dispose());

  List<String> bobTitles() => [
        for (final c in fake.calls)
          if (c.event.summary.endsWith('— Bob')) c.event.summary,
      ];

  Future<List<String>> titlesAfterSync() async {
    await container.read(appContextProvider.future);
    final plant = await container.read(plantRepositoryProvider).create(nickname: 'Bob');
    await container.read(careScheduleRepositoryProvider).upsert(
          plantId: plant.id,
          type: 'water',
          baseIntervalDays: 7,
          firstDueAt: DateTime.now().toUtc().add(const Duration(days: 1)),
        );
    await container.read(careScheduleRepositoryProvider).upsert(
          plantId: plant.id,
          type: 'neem_spray',
          baseIntervalDays: 14,
          firstDueAt: DateTime.now().toUtc().add(const Duration(days: 2)),
        );
    await container.read(reminderSyncProvider).syncFromDatabase();
    return bobTitles();
  }

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await pumpEventQueue();
    }
  }

  test('renaming a built-in re-schedules reminders with the new name', () async {
    // Let the registry finish loading from prefs before we listen.
    await container.read(sharedPreferencesProvider.future);
    container.read(careTypesProvider);
    await settle();

    expect(await titlesAfterSync(), containsAll(['Water — Bob']));

    final water = kBuiltInCareTypes.firstWhere((t) => t.key == 'water');
    await container.read(careTypesProvider.notifier).update('water', water.copyWith(label: 'Hydrate'));
    await settle();

    expect(bobTitles(), contains('Hydrate — Bob'));
    expect(bobTitles(), isNot(contains('Water — Bob')));
  });

  test('adding / renaming a custom type re-schedules its reminders', () async {
    await container.read(sharedPreferencesProvider.future);
    container.read(careTypesProvider);
    await settle();

    // Before the type exists in the registry the key falls back to a
    // capitalised raw key.
    expect(await titlesAfterSync(), contains('Neem_spray — Bob'));

    final notifier = container.read(careTypesProvider.notifier);
    const neem = CareType(key: 'neem_spray', label: 'Neem spray', iconCode: 0, defaultIntervalDays: 14);
    await notifier.add(neem);
    await settle();
    expect(bobTitles(), contains('Neem spray — Bob'));

    await notifier.update('neem_spray', neem.copyWith(label: 'Anti-pest'));
    await settle();
    expect(bobTitles(), contains('Anti-pest — Bob'));
    expect(bobTitles(), isNot(contains('Neem spray — Bob')));
  });

  test('icon-only edits do not trigger a re-sync', () async {
    await container.read(sharedPreferencesProvider.future);
    container.read(careTypesProvider);
    await settle();
    await titlesAfterSync();

    fake.cancelAllCalled = false;
    final water = kBuiltInCareTypes.firstWhere((t) => t.key == 'water');
    await container.read(careTypesProvider.notifier).update('water', water.copyWith(iconCode: 0));
    await settle();
    expect(fake.cancelAllCalled, isFalse);
  });
}
