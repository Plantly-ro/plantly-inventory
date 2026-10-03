// MULTI-USER-V2 §3 — the muted-items list on Me → Notifications: un-muting
// writes a synced row field, so a viewer of a shared collection gets the
// read-only snackbar and the row stays muted; an editor un-mutes as before.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/cloud/collections.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/features/me/notifications_screen.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';

const _snackKey = Key('read-only-snack');
const _unmuteKey = Key('muted-row-unmute');
const _probeKey = Key('probe');

void main() {
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({'plantly_onboarded': true, kSkipSeedPrefKey: true});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  /// One `ProviderScope` for the whole test; the screen is mounted only
  /// after seeding. Drift streams started by the screen live in the
  /// fake-async zone and hold the executor lock between pumps — a write
  /// from `runAsync` while they are open deadlocks, so seed first.
  Widget app({required bool canEdit, required ValueNotifier<bool> show}) => buildTestApp(
        overrides: [
          databaseProvider.overrideWithValue(db),
          canEditActiveCollectionProvider.overrideWithValue(canEdit),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ValueListenableBuilder<bool>(
            valueListenable: show,
            builder: (_, visible, _) => visible ? const NotificationsScreen() : const SizedBox(key: _probeKey),
          ),
        ),
      );

  Future<String> pumpWithMutedPlant(WidgetTester tester, {required bool canEdit}) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final show = ValueNotifier<bool>(false);
    addTearDown(show.dispose);
    await tester.pumpWidget(app(canEdit: canEdit, show: show));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byKey(_probeKey)));
    late String id;
    await tester.runAsync(() async {
      await container.read(appContextProvider.future);
      final repo = container.read(plantRepositoryProvider);
      final plant = await repo.create(nickname: 'Fern');
      await repo.setNotificationsMuted(plant.id, true);
      id = plant.id;
    });
    show.value = true;
    await tester.pumpAndSettle();
    expect(find.text('Fern'), findsOneWidget, reason: 'muted plant listed');
    expect(find.byKey(_unmuteKey), findsOneWidget);
    return id;
  }

  Future<bool> mutedOf(String id) async =>
      (await (db.select(db.plants)..where((p) => p.id.equals(id))).getSingle()).notificationsMuted;

  /// The screen's muted-row providers are private drift `StreamProvider`s
  /// (no static override possible); disposing the scope schedules drift's
  /// zero-duration stream-teardown timers in the fake zone. Dispose here
  /// and advance the clock (a bare `pump()` only flushes microtasks, it
  /// does not elapse timers) so they fire before the framework's leak check.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('viewer → Unmute shows the read-only snackbar, plant stays muted', (tester) async {
    final id = await pumpWithMutedPlant(tester, canEdit: false);
    await tester.tap(find.byKey(_unmuteKey));
    await tester.pump();
    expect(find.byKey(_snackKey), findsOneWidget);
    expect(find.text('View only — ask the owner for edit rights.'), findsOneWidget);
    // Let the snackbar's auto-dismiss timer (armed once its entrance
    // animation settles) elapse so nothing is pending at teardown.
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byKey(_snackKey), findsNothing);
    expect(find.text('Fern'), findsOneWidget, reason: 'row still listed');
    await tester.runAsync(() async {
      expect(await mutedOf(id), isTrue, reason: 'no write for a viewer');
    });
    await finish(tester);
  });

  testWidgets('editor → Unmute writes and the row disappears', (tester) async {
    final id = await pumpWithMutedPlant(tester, canEdit: true);
    await tester.tap(find.byKey(_unmuteKey));
    await tester.pumpAndSettle();
    expect(find.byKey(_snackKey), findsNothing);
    expect(find.text('Fern'), findsNothing);
    await tester.runAsync(() async {
      expect(await mutedOf(id), isFalse);
    });
    await finish(tester);
  });
}
