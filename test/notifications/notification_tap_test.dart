import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/data/repositories/care_schedule_repository.dart';
import 'package:plantly_inventory/data/repositories/plant_repository.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/notifications/notification_service.dart';
import 'package:plantly_inventory/notifications/notification_tap_listener.dart';
import 'package:plantly_inventory/notifications/reminder_payload.dart';
import 'package:plantly_inventory/notifications/reminder_sync.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// QA 2026-10-07 (P2): tapping a plant-care reminder opened Home instead of
/// the plant. Reminders now carry a payload (plant id + tenant) and the
/// app routes a tap — warm or cold start — to the plant's detail page.
void main() {
  group('ReminderPayload', () {
    test('round-trips and tolerates garbage', () {
      const p = ReminderPayload(plantId: '01JPLANT', tenantId: 'col-1');
      expect(ReminderPayload.decode(p.encode()), p);
      expect(ReminderPayload.decode(const ReminderPayload(plantId: 'x').encode()), const ReminderPayload(plantId: 'x'));
      for (final bad in [null, '', 'not json', '[]', '{"plant":1}', '{"tenant":"t"}']) {
        expect(ReminderPayload.decode(bad), isNull, reason: '$bad');
      }
    });
  });

  test('ReminderSync schedules every reminder with its plant + tenant payload', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final opLog = OpLogWriter(db: db, clock: HlcClock(deviceId: 'd'), tenantId: 'col-1');
    final plant = await PlantRepository(db: db, opLog: opLog).create(nickname: 'Bob');
    await CareScheduleRepository(db: db, opLog: opLog).upsert(
      plantId: plant.id,
      type: 'water',
      baseIntervalDays: 7,
      firstDueAt: DateTime.utc(2026, 5, 3),
    );
    final fake = FakeNotificationService();
    await ReminderSync(db: db, notifications: fake, tenantId: 'col-1', clock: () => DateTime.utc(2026, 5, 1))
        .syncFromDatabase();
    expect(fake.calls, hasLength(1));
    expect(ReminderPayload.decode(fake.calls.single.payload), ReminderPayload(plantId: plant.id, tenantId: 'col-1'));
  });

  group('NotificationTapListener', () {
    late FakeNotificationService fake;
    late AppDatabase db;

    setUp(() {
      SharedPreferences.setMockInitialValues({'plantly_onboarded': true, kSkipSeedPrefKey: true});
      fake = FakeNotificationService();
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    Future<String> addPlant(String tenant, String name) async {
      final opLog = OpLogWriter(db: db, clock: HlcClock(deviceId: 'd'), tenantId: tenant);
      return (await PlantRepository(db: db, opLog: opLog).create(nickname: name)).id;
    }

    Future<GoRouter> pumpApp(WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('home'))),
          GoRoute(path: '/plants/:id', builder: (_, s) => Scaffold(body: Text('plant ${s.pathParameters['id']}'))),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notificationServiceProvider.overrideWithValue(fake),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => NotificationTapListener(router: router, child: child!),
        ),
      ));
      await tester.runAsync(() => tester.pumpAndSettle());
      return router;
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    testWidgets('tap while running opens the plant', (tester) async {
      final id = await tester.runAsync(() => addPlant(kDefaultTenantId, 'Bob'));
      await pumpApp(tester);
      expect(find.text('home'), findsOneWidget);

      fake.tap(ReminderPayload(plantId: id!, tenantId: kDefaultTenantId).encode());
      await settle(tester);
      expect(find.text('plant $id'), findsOneWidget);
      await tester.runAsync(db.close);
    });

    testWidgets('cold start from a tapped reminder opens the plant', (tester) async {
      final id = await tester.runAsync(() => addPlant(kDefaultTenantId, 'Bob'));
      // Reminder armed before a link re-tenanted the rows: the stale tenant in
      // the payload must not stop the plant from opening.
      fake.launchPayload = ReminderPayload(plantId: id!, tenantId: 'local-old').encode();
      await pumpApp(tester);
      await settle(tester);
      expect(find.text('plant $id'), findsOneWidget);
      expect(fake.launchPayload, isNull, reason: 'taken once');
      await tester.runAsync(db.close);
    });

    testWidgets('plant in another collection → Home with a notice', (tester) async {
      final id = await tester.runAsync(() => addPlant('col-hidden', 'Other'));
      await pumpApp(tester);
      fake.tap(ReminderPayload(plantId: id!, tenantId: 'col-hidden').encode());
      await settle(tester);
      expect(find.text('home'), findsOneWidget);
      expect(find.byKey(const Key('reminder-tap-other-collection')), findsOneWidget);
      await tester.runAsync(db.close);
    });

    testWidgets('deleted plant → Home with a notice; garbage payload → nothing', (tester) async {
      await pumpApp(tester);
      fake.tap('not-a-payload');
      await settle(tester);
      expect(find.text('home'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      fake.tap(const ReminderPayload(plantId: 'gone', tenantId: kDefaultTenantId).encode());
      await settle(tester);
      expect(find.text('home'), findsOneWidget);
      expect(find.byKey(const Key('reminder-tap-gone')), findsOneWidget);
      await tester.runAsync(db.close);
    });
  });
}
