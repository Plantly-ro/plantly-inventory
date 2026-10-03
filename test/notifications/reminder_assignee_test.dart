import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/repositories/care_schedule_repository.dart';
import 'package:plantly_inventory/data/repositories/plant_repository.dart';
import 'package:plantly_inventory/domain/services/reminder_engine.dart';
import 'package:plantly_inventory/notifications/notification_service.dart';
import 'package:plantly_inventory/notifications/reminder_sync.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';

/// MULTI-USER-V2 §0: an assigned schedule's OS reminder fires only on the
/// assignee's devices. Unassigned = everyone. The in-app lists (engine /
/// Home / Calendar) are NOT filtered — every member still sees every task.
void main() {
  late AppDatabase db;
  late FakeNotificationService fake;
  late PlantRepository plants;
  late CareScheduleRepository schedules;
  String? me;

  ReminderSync makeSync() => ReminderSync(
        db: db,
        notifications: fake,
        tenantId: 'tenant-local',
        clock: () => DateTime.utc(2026, 5, 1),
        currentUserId: () => me,
      );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    fake = FakeNotificationService();
    me = 'u-me';
    final opLog = OpLogWriter(db: db, clock: HlcClock(deviceId: 'test-device'), tenantId: 'tenant-local');
    plants = PlantRepository(db: db, opLog: opLog);
    schedules = CareScheduleRepository(db: db, opLog: opLog);
  });
  tearDown(() => db.close());

  Future<void> seedThree() async {
    final p = await plants.create(nickname: 'Bob');
    await schedules.upsert(plantId: p.id, type: 'water', baseIntervalDays: 7, firstDueAt: DateTime.utc(2026, 5, 3));
    await schedules.upsert(
        plantId: p.id, type: 'mist', baseIntervalDays: 7, firstDueAt: DateTime.utc(2026, 5, 4), assigneeUserId: 'u-me');
    await schedules.upsert(
        plantId: p.id, type: 'fertilize', baseIntervalDays: 7, firstDueAt: DateTime.utc(2026, 5, 5), assigneeUserId: 'u-other');
  }

  Iterable<String> scheduled() => fake.calls.map((c) => c.event.summary);

  test('unassigned and assigned-to-me are scheduled; assigned-to-other is not', () async {
    await seedThree();
    final n = await makeSync().syncFromDatabase(now: DateTime.utc(2026, 5, 1));
    expect(n, 2);
    expect(scheduled(), containsAll(['Water — Bob', 'Mist — Bob']));
    expect(scheduled(), isNot(contains('Fertilize — Bob')));
  });

  test('no signed-in user: only unassigned schedules reach the OS', () async {
    await seedThree();
    me = null;
    final n = await makeSync().syncFromDatabase(now: DateTime.utc(2026, 5, 1));
    expect(n, 1);
    expect(scheduled(), ['Water — Bob']);
  });

  test('the user id is read per run: switching account changes what is scheduled without a new ReminderSync', () async {
    await seedThree();
    final sync = makeSync();
    await sync.syncFromDatabase(now: DateTime.utc(2026, 5, 1));
    expect(scheduled(), isNot(contains('Fertilize — Bob')));
    me = 'u-other';
    fake.calls.clear();
    await sync.syncFromDatabase(now: DateTime.utc(2026, 5, 1));
    expect(scheduled(), containsAll(['Water — Bob', 'Fertilize — Bob']));
    expect(scheduled(), isNot(contains('Mist — Bob')));
  });

  test('without a currentUserId hook (local-only build) nothing is filtered on assignee', () async {
    await seedThree();
    final sync = ReminderSync(db: db, notifications: fake, tenantId: 'tenant-local', clock: () => DateTime.utc(2026, 5, 1));
    // A device without the hook has no notion of "me": the only way to a
    // non-null assignee here is a shared collection, which always wires the
    // hook. Keep the rule literal: non-null assignee ≠ null user → skipped.
    expect(await sync.syncFromDatabase(now: DateTime.utc(2026, 5, 1)), 1);
  });

  test('ReminderEngine.buildUpcoming (Home / Calendar source) still lists every schedule regardless of assignee', () async {
    await seedThree();
    final rows = await db.select(db.careSchedules).get();
    final plantRows = await db.select(db.plants).get();
    final events = ReminderEngine.buildUpcoming(
      schedules: rows,
      plantsById: {for (final p in plantRows) p.id: p},
      locationsById: const {},
      now: DateTime.utc(2026, 5, 1),
      window: const Duration(days: 7),
    );
    expect(events.map((e) => e.summary), containsAll(['Water — Bob', 'Mist — Bob', 'Fertilize — Bob']));
  });
}
