import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/repositories/care_event_repository.dart';
import 'package:plantly_inventory/data/repositories/care_schedule_repository.dart';
import 'package:plantly_inventory/data/repositories/plant_repository.dart';
import 'package:plantly_inventory/notifications/notification_service.dart';
import 'package:plantly_inventory/notifications/reminder_sync.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';

void main() {
  late AppDatabase db;
  late FakeNotificationService fake;
  late ReminderSync sync;
  late PlantRepository plants;
  late CareScheduleRepository schedules;
  late CareEventRepository events;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final clock = HlcClock(deviceId: 'test-device');
    final opLog = OpLogWriter(db: db, clock: clock, tenantId: 'tenant-local');
    fake = FakeNotificationService();
    sync = ReminderSync(db: db, notifications: fake, tenantId: 'tenant-local');
    plants = PlantRepository(db: db, opLog: opLog);
    schedules = CareScheduleRepository(db: db, opLog: opLog, reminderSync: sync);
    events = CareEventRepository(
      db: db,
      opLog: opLog,
      schedules: schedules,
      reminderSync: sync,
    );
  });

  tearDown(() => db.close());

  test('syncFromDatabase schedules one reminder per enabled schedule in window', () async {
    final p = await plants.create(nickname: 'Bob');
    await schedules.upsert(
      plantId: p.id,
      type: 'water',
      baseIntervalDays: 7,
      firstDueAt: DateTime.utc(2026, 5, 1),
    );
    await schedules.upsert(
      plantId: p.id,
      type: 'fertilize',
      baseIntervalDays: 30,
      firstDueAt: DateTime.utc(2026, 5, 15),
    );
    final count = await sync.syncFromDatabase(now: DateTime.utc(2026, 4, 18));
    expect(count, 2);
    expect(fake.cancelAllCalled, isTrue);
    expect(fake.calls.map((c) => c.event.summary), contains('Water — Bob'));
    expect(fake.calls.map((c) => c.event.summary), contains('Fertilize — Bob'));
  });

  test('recording a care event triggers reminder re-sync', () async {
    final p = await plants.create(nickname: 'Fiddle');
    await schedules.upsert(
      plantId: p.id,
      type: 'water',
      baseIntervalDays: 7,
      firstDueAt: DateTime.utc(2026, 5, 1),
    );
    // Clear any calls from upsert flow (upsert itself doesn't call sync,
    // but we want to assert record() does).
    fake.calls.clear();
    fake.cancelAllCalled = false;

    await events.record(plantId: p.id, type: 'water', doneAt: DateTime.utc(2026, 5, 1).millisecondsSinceEpoch);

    expect(fake.cancelAllCalled, isTrue,
        reason: 'care-event record should trigger a reminder sync');
    expect(fake.calls, isNotEmpty);
    // After record, the schedule's next_due_at was pushed +7 days to 2026-05-08.
    expect(fake.calls.first.event.start, DateTime.utc(2026, 5, 8, 0));
  });

  test('snooze triggers reminder re-sync with shifted start time', () async {
    final p = await plants.create(nickname: 'Pete');
    final s = await schedules.upsert(
      plantId: p.id,
      type: 'water',
      baseIntervalDays: 7,
      firstDueAt: DateTime.utc(2026, 5, 1),
    );
    fake.calls.clear();
    fake.cancelAllCalled = false;

    await schedules.snooze(s.id, by: const Duration(days: 2));

    expect(fake.cancelAllCalled, isTrue);
    expect(fake.calls, isNotEmpty);
    expect(fake.calls.first.event.start, DateTime.utc(2026, 5, 3));
  });

  test('disabled schedules are not scheduled', () async {
    final p = await plants.create(nickname: 'X');
    final s = await schedules.upsert(
      plantId: p.id,
      type: 'water',
      baseIntervalDays: 7,
      firstDueAt: DateTime.utc(2026, 5, 1),
    );
    // Directly flip enabled off by rewriting the row.
    await db.customStatement(
      'UPDATE care_schedules SET enabled = 0 WHERE id = ?',
      [s.id],
    );
    fake.calls.clear();
    await sync.syncFromDatabase(now: DateTime.utc(2026, 4, 18));
    expect(fake.calls, isEmpty);
  });
}
