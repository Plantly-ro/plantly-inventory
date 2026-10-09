import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/data/repositories/care_schedule_repository.dart';
import 'package:plantly_inventory/data/repositories/plant_repository.dart';
import 'package:plantly_inventory/domain/services/ical_export.dart';
import 'package:plantly_inventory/notifications/notification_service.dart';
import 'package:plantly_inventory/notifications/reminder_sync.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// QA 2026-10-07 (P2): the OS reminders were re-derived only when the
/// signed-in user changed. After an account switch → "Start empty" the
/// hidden tenant's alarms kept firing, and switching back left the device
/// with no alarms until a cold start. The active tenant flipping (link,
/// move, join, start-empty, switch, rehome, unlink) must cancel everything
/// and re-arm for the tenant now on screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('reminderTenantResyncProvider', () {
    late FakeNotificationService fake;
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'plantly_onboarded': true,
        kSkipSeedPrefKey: true, // no demo plants in the way
      });
      fake = FakeNotificationService();
      container = ProviderContainer(overrides: [
        databaseProvider.overrideWith((ref) {
          final db = AppDatabase.forTesting(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
        notificationServiceProvider.overrideWith((ref) => fake),
      ]);
      // The app root keeps it alive (main.dart); so does this test.
      container.listen<void>(reminderTenantResyncProvider, (_, _) {});
    });

    tearDown(() => container.dispose());

    Future<void> settle() async {
      for (var i = 0; i < 20; i++) {
        await pumpEventQueue();
      }
    }

    List<String> titles() => [for (final c in fake.calls) c.event.summary];

    Future<void> addBob() async {
      await container.read(appContextProvider.future);
      final plant = await container.read(plantRepositoryProvider).create(nickname: 'Bob');
      await container.read(careScheduleRepositoryProvider).upsert(
            plantId: plant.id,
            type: 'water',
            baseIntervalDays: 7,
            firstDueAt: DateTime.now().toUtc().add(const Duration(days: 1)),
          );
      await settle();
    }

    Future<void> flipTo(String tenant) async {
      container.read(currentTenantIdProvider.notifier).state = tenant;
      await container.read(appContextProvider.future);
      await settle();
    }

    test('switching to an empty tenant cancels the hidden tenant\'s alarms; switching back re-arms them', () async {
      await addBob();
      expect(titles(), ['Water — Bob']);

      // "Start empty": a fresh tenant with no rows.
      await flipTo('local-fresh');
      expect(fake.cancelAllCalled, isTrue);
      expect(titles(), isEmpty, reason: 'the parked tenant must not keep firing');

      // Switch back to the original collection: re-armed without a cold start.
      fake.cancelAllCalled = false;
      await flipTo(kDefaultTenantId);
      expect(fake.cancelAllCalled, isTrue);
      expect(titles(), ['Water — Bob']);
    });

    test('link / move: rows that moved with the flip are armed under the new tenant', () async {
      await addBob();
      final db = container.read(databaseProvider);
      // What CollectionLinkService.link() does: rewrite tenant ids, then flip.
      await db.customStatement("UPDATE plants SET tenant_id = 'col-A'");
      await db.customStatement("UPDATE care_schedules SET tenant_id = 'col-A'");
      await flipTo('col-A');
      expect(titles(), ['Water — Bob']);
    });

    test('launch: re-arms once and remembers the tenant; a same-tenant launch leaves the OS alone', () async {
      await container.read(appContextProvider.future);
      await settle();
      expect(fake.cancelAllCalled, isTrue, reason: 'first launch of this build: armed once');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kRemindersArmedTenantPrefKey), kDefaultTenantId);

      // Next launch, same tenant: nothing is replaced (the shade stays as is).
      final fake2 = FakeNotificationService();
      final next = ProviderContainer(overrides: [
        databaseProvider.overrideWith((ref) {
          final db = AppDatabase.forTesting(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
        notificationServiceProvider.overrideWith((ref) => fake2),
      ]);
      addTearDown(next.dispose);
      next.listen<void>(reminderTenantResyncProvider, (_, _) {});
      await next.read(appContextProvider.future);
      await settle();
      expect(fake2.cancelAllCalled, isFalse);
      // ...but a flip still re-arms, and is remembered.
      next.read(currentTenantIdProvider.notifier).state = 'col-B';
      await next.read(appContextProvider.future);
      await settle();
      expect(fake2.cancelAllCalled, isTrue);
      expect(prefs.getString(kRemindersArmedTenantPrefKey), 'col-B');
    });

    test('no flip → no extra cancelAll', () async {
      await addBob();
      fake.cancelAllCalled = false;
      container.read(currentTenantIdProvider.notifier).state = kDefaultTenantId;
      await settle();
      expect(fake.cancelAllCalled, isFalse);
    });
  });

  group('ReminderSync after the tenant moved on', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> seed(String tenant, String name) async {
      final opLog = OpLogWriter(db: db, clock: HlcClock(deviceId: 'd'), tenantId: tenant);
      final plant = await PlantRepository(db: db, opLog: opLog).create(nickname: name);
      await CareScheduleRepository(db: db, opLog: opLog).upsert(
        plantId: plant.id,
        type: 'water',
        baseIntervalDays: 7,
        firstDueAt: DateTime.utc(2026, 5, 3),
      );
    }

    test('a disposed instance (old tenant) never reaches the OS', () async {
      await seed('A', 'Old');
      final fake = FakeNotificationService();
      final sync = ReminderSync(db: db, notifications: fake, tenantId: 'A', clock: () => DateTime.utc(2026, 5, 1));
      sync.dispose();
      await sync.syncFromDatabase();
      expect(fake.cancelAllCalled, isFalse);
      expect(fake.calls, isEmpty);
    });

    test('an in-flight run of the old tenant cannot overwrite the new tenant\'s alarms', () async {
      await seed('A', 'Old');
      await seed('B', 'New');
      final gated = _GatedNotificationService();
      DateTime clock() => DateTime.utc(2026, 5, 1);
      final oldSync = ReminderSync(db: db, notifications: gated, tenantId: 'A', clock: clock);
      final newSync = ReminderSync(db: db, notifications: gated, tenantId: 'B', clock: clock);

      final oldRun = oldSync.syncFromDatabase(); // blocks inside syncAll
      await gated.entered.future;
      // Tenant flips: the old instance is disposed, the new one re-syncs.
      oldSync.dispose();
      final newRun = newSync.syncFromDatabase();
      await pumpEventQueue();
      expect(gated.syncAllCalls, 1, reason: 'the new run waits for the OS lock');
      gated.release.complete();
      await Future.wait([oldRun, newRun]);
      expect([for (final c in gated.calls) c.event.summary], ['Water — New']);
    });
  });
}

/// Blocks the first [syncAll] until [release] completes, so a test can
/// interleave a second run with an in-flight one.
class _GatedNotificationService extends FakeNotificationService {
  final entered = Completer<void>();
  final release = Completer<void>();
  int syncAllCalls = 0;

  @override
  Future<void> syncAll(Iterable<ICalEvent> events, {String? tenantId}) async {
    syncAllCalls++;
    if (syncAllCalls == 1) {
      entered.complete();
      await release.future;
    }
    await super.syncAll(events, tenantId: tenantId);
  }
}
