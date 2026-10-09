import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/repositories/care_event_repository.dart';
import 'package:plantly_inventory/data/repositories/care_schedule_repository.dart';
import 'package:plantly_inventory/data/repositories/plant_repository.dart';
import 'package:plantly_inventory/domain/services/ical_export.dart';
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
    // Pin the clock so the record()/snooze() re-sync path — which windows
    // reminders against "now" — is deterministic. Fixed before every
    // schedule's first due date so past-due clamping (reminder_engine.dart)
    // never rewrites the asserted start times. See issue #1.
    sync = ReminderSync(
      db: db,
      notifications: fake,
      tenantId: 'tenant-local',
      clock: () => DateTime.utc(2026, 5, 1),
    );
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

  group('overdue occurrences never reach the OS (fresh-install storm)', () {
    // The seed deliberately creates overdue / due-today demo plants so the
    // Home widgets have content. Before this guard every overdue row was
    // clamped to `now`, handed to flutter_local_notifications 1s ahead and
    // fired the instant POST_NOTIFICATIONS was granted — N notifications
    // at once. Overdue rows stay visible in-app (they read the table).
    test('an overdue schedule schedules nothing; a future one is scheduled', () async {
      final overdue = await plants.create(nickname: 'Bob');
      final future = await plants.create(nickname: 'Fern');
      await schedules.upsert(
        plantId: overdue.id,
        type: 'water',
        baseIntervalDays: 7,
        firstDueAt: DateTime.utc(2026, 4, 20), // 11 days before the pinned clock
      );
      await schedules.upsert(
        plantId: future.id,
        type: 'water',
        baseIntervalDays: 3,
        firstDueAt: DateTime.utc(2026, 5, 3),
      );
      fake.calls.clear();

      final count = await sync.syncFromDatabase(now: DateTime.utc(2026, 5, 1));

      expect(count, 1);
      expect(fake.calls.map((c) => c.event.summary).toList(), ['Water — Fern']);
      expect(fake.calls.single.event.start, DateTime.utc(2026, 5, 3));
    });

    test('a schedule due exactly now is still handed over at now (service-level guard skips it)', () async {
      final p = await plants.create(nickname: 'Snake');
      await schedules.upsert(plantId: p.id, type: 'water', baseIntervalDays: 14, firstDueAt: DateTime.utc(2026, 5, 1));
      fake.calls.clear();
      await sync.syncFromDatabase(now: DateTime.utc(2026, 5, 1));
      // Not "overdue" (not strictly before now) so the engine keeps it — the
      // LocalNotificationService.schedule guard (`!when.isAfter(now)` → skip)
      // is what prevents an immediate fire for this edge.
      expect(fake.calls.map((c) => c.event.start).toList(), [DateTime.utc(2026, 5, 1)]);
    });

    test('all-overdue seed-like state → zero OS reminders, no throw', () async {
      for (final (name, daysAgo) in [('Bob', 2), ('Green', 1), ('Cala', 0)]) {
        final p = await plants.create(nickname: name);
        await schedules.upsert(
          plantId: p.id,
          type: 'water',
          baseIntervalDays: 7,
          firstDueAt: DateTime.utc(2026, 5, 1).subtract(Duration(days: daysAgo, seconds: 1)),
        );
      }
      fake.calls.clear();
      expect(await sync.syncFromDatabase(now: DateTime.utc(2026, 5, 1)), 0);
      expect(fake.calls, isEmpty);
      expect(fake.cancelAllCalled, isTrue, reason: 'stale OS entries are still cleared');
    });
  });

  group('syncFromDatabase coalescing (single-flight + trailing run)', () {
    late _GatedNotificationService gated;
    late ReminderSync coalescing;

    setUp(() {
      gated = _GatedNotificationService();
      coalescing = ReminderSync(
        db: db,
        notifications: gated,
        tenantId: 'tenant-local',
        clock: () => DateTime.utc(2026, 5, 1),
      );
    });

    test('20 concurrent calls → at most 2 pipeline runs, every caller sees the final state', () async {
      final p = await plants.create(nickname: 'Bob');
      await schedules.upsert(plantId: p.id, type: 'water', baseIntervalDays: 7, firstDueAt: DateTime.utc(2026, 5, 2));

      final results = await Future.wait([for (var i = 0; i < 20; i++) coalescing.syncFromDatabase()]);

      expect(gated.runs, inInclusiveRange(1, 2));
      expect(results, everyElement(1));
      expect(gated.calls.map((c) => c.event.summary), ['Water — Bob']);
    });

    test('a write that lands mid-run is picked up by the single trailing run', () async {
      final p = await plants.create(nickname: 'Bob');
      await schedules.upsert(plantId: p.id, type: 'water', baseIntervalDays: 7, firstDueAt: DateTime.utc(2026, 5, 2));

      // Run 1 reads the rows, then parks inside syncAll on the gate.
      final gate = gated.gate = Completer<void>();
      final first = coalescing.syncFromDatabase();
      await gated.entered.future;
      expect(gated.runs, 1);

      // Mutations while run 1 is in flight: each would normally trigger a
      // full rebuild. They share one trailing run instead.
      await plants.setNotificationsMuted(p.id, true); // repo has no reminderSync → no auto sync
      final second = coalescing.syncFromDatabase();
      final third = coalescing.syncFromDatabase();
      expect(gated.runs, 1, reason: 'no new run may start while one is in flight');

      gate.complete();
      expect(await first, 1, reason: 'run 1 saw the pre-mute rows');
      expect(await second, 0);
      expect(await third, 0);
      expect(gated.runs, 2);
      expect(gated.calls, isEmpty, reason: 'final OS state reflects the mute');
    });

    test('a failing run does not wedge the pipeline', () async {
      final p = await plants.create(nickname: 'Bob');
      await schedules.upsert(plantId: p.id, type: 'water', baseIntervalDays: 7, firstDueAt: DateTime.utc(2026, 5, 2));
      gated.failNext = true;
      await expectLater(coalescing.syncFromDatabase(), throwsStateError);
      expect(await coalescing.syncFromDatabase(), 1);
      expect(gated.runs, 2);
    });
  });

  test('arms at most kMaxOsReminders (Android caps alarms at 500) — the nearest ones', () async {
    final opLog = OpLogWriter(db: db, clock: HlcClock(deviceId: 'cap'), tenantId: 'tenant-local');
    final capPlants = PlantRepository(db: db, opLog: opLog);
    final capSchedules = CareScheduleRepository(db: db, opLog: opLog);
    for (var i = 0; i < kMaxOsReminders + 20; i++) {
      final p = await capPlants.create(nickname: 'P$i');
      await capSchedules.upsert(
        plantId: p.id,
        type: 'water',
        baseIntervalDays: 30,
        firstDueAt: DateTime.utc(2026, 5, 2).add(Duration(minutes: i)),
      );
    }
    final n = await sync.syncFromDatabase();
    expect(n, kMaxOsReminders);
    expect(fake.calls, hasLength(kMaxOsReminders));
    expect(fake.calls.map((c) => c.event.summary), contains('Water — P0'));
    expect(fake.calls.map((c) => c.event.summary), isNot(contains('Water — P${kMaxOsReminders + 19}')));
  });
}

/// [FakeNotificationService] that counts `syncAll` pipeline runs and can
/// park a run on a [gate] so a test can deterministically overlap calls.
class _GatedNotificationService extends FakeNotificationService {
  int runs = 0;
  Completer<void>? gate;
  Completer<void> entered = Completer<void>();
  bool failNext = false;

  @override
  Future<void> syncAll(Iterable<ICalEvent> events, {String? tenantId}) async {
    runs++;
    if (!entered.isCompleted) entered.complete();
    if (failNext) {
      failNext = false;
      throw StateError('plugin unavailable');
    }
    final g = gate;
    if (g != null) {
      gate = null;
      await g.future;
    }
    await super.syncAll(events, tenantId: tenantId);
  }
}
