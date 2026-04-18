import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/repositories/care_event_repository.dart';
import 'package:plantly_inventory/data/repositories/care_schedule_repository.dart';
import 'package:plantly_inventory/data/repositories/plant_repository.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';

void main() {
  late AppDatabase db;
  late PlantRepository plants;
  late CareScheduleRepository schedules;
  late CareEventRepository events;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final clock = HlcClock(deviceId: 'test-device');
    final opLog = OpLogWriter(db: db, clock: clock, tenantId: 'tenant-local');
    plants = PlantRepository(db: db, opLog: opLog);
    schedules = CareScheduleRepository(db: db, opLog: opLog);
    events = CareEventRepository(db: db, opLog: opLog, schedules: schedules);
  });

  tearDown(() => db.close());

  group('CareScheduleRepository.upsert', () {
    test('creates a schedule with base interval and first due date', () async {
      final p = await plants.create(nickname: 'Monstera');
      final target = DateTime.utc(2026, 5, 1);
      final s = await schedules.upsert(
        plantId: p.id,
        type: 'water',
        baseIntervalDays: 7,
        firstDueAt: target,
      );
      expect(s.plantId, p.id);
      expect(s.type, 'water');
      expect(s.baseIntervalDays, 7);
      expect(s.currentIntervalDays, 7);
      expect(s.nextDueAt, target.millisecondsSinceEpoch);
      expect(s.enabled, isTrue);
    });

    test('is idempotent — second upsert returns the existing row', () async {
      final p = await plants.create(nickname: 'Fern');
      final a = await schedules.upsert(plantId: p.id, type: 'water', baseIntervalDays: 5);
      final b = await schedules.upsert(plantId: p.id, type: 'water', baseIntervalDays: 99);
      expect(a.id, b.id);
      expect(b.baseIntervalDays, 5); // not overwritten
    });
  });

  group('CareScheduleRepository.applyCareEvent — run via CareEventRepository', () {
    test('records last_done_at + recomputes next_due_at on first event', () async {
      final p = await plants.create(nickname: 'Snake');
      await schedules.upsert(
        plantId: p.id,
        type: 'water',
        baseIntervalDays: 7,
        firstDueAt: DateTime.utc(2026, 5, 1),
      );
      final doneAt = DateTime.utc(2026, 5, 1, 9);
      await events.record(plantId: p.id, type: 'water', doneAt: doneAt.millisecondsSinceEpoch);

      final s = await schedules.forPlantAndType(p.id, 'water');
      expect(s!.lastDoneAt, doneAt.millisecondsSinceEpoch);
      // With no prior events, the window has one entry → no adjustment.
      expect(s.currentIntervalDays, 7);
      expect(s.nextDueAt, doneAt.add(const Duration(days: 7)).millisecondsSinceEpoch);
    });

    test('populates recent_events_json with newest-first samples', () async {
      final p = await plants.create(nickname: 'A');
      await schedules.upsert(plantId: p.id, type: 'water', baseIntervalDays: 7);
      await events.record(plantId: p.id, type: 'water', doneAt: DateTime.utc(2026, 5, 1).millisecondsSinceEpoch);
      await events.record(plantId: p.id, type: 'water', doneAt: DateTime.utc(2026, 5, 8).millisecondsSinceEpoch);

      final s = await schedules.forPlantAndType(p.id, 'water');
      expect(s!.recentEventsJson, contains('"done_at":1778198400000')); // 2026-05-08
      // Second event is newest → appears first in the json.
      expect(s.recentEventsJson.indexOf('1778198400000'), lessThan(s.recentEventsJson.indexOf('1777593600000')));
    });

    test('shrinks current_interval when completions trend early', () async {
      final p = await plants.create(nickname: 'B');
      await schedules.upsert(plantId: p.id, type: 'water', baseIntervalDays: 10);
      // 5 completions each 3 days apart (< 0.8 * 10 = 8) → algorithm should
      // shrink after the third-or-later event that breaks the 30% threshold.
      final base = DateTime.utc(2026, 1, 1);
      for (var i = 0; i < 5; i++) {
        await events.record(
          plantId: p.id,
          type: 'water',
          doneAt: base.add(Duration(days: 3 * i)).millisecondsSinceEpoch,
        );
      }
      final s = await schedules.forPlantAndType(p.id, 'water');
      expect(s!.currentIntervalDays, lessThan(10));
      expect(s.currentIntervalDays, greaterThanOrEqualTo(5.0)); // floored at 0.5× base
    });
  });

  group('CareScheduleRepository.watchDueBefore', () {
    test('returns only enabled, non-deleted schedules with next_due_at ≤ cutoff', () async {
      final p = await plants.create(nickname: 'C');
      await schedules.upsert(
        plantId: p.id,
        type: 'water',
        baseIntervalDays: 7,
        firstDueAt: DateTime.utc(2026, 1, 1),
      );
      final due = await schedules.watchDueBefore(DateTime.utc(2026, 1, 2).millisecondsSinceEpoch).first;
      expect(due, hasLength(1));

      final notDueYet = await schedules.watchDueBefore(DateTime.utc(2025, 12, 31).millisecondsSinceEpoch).first;
      expect(notDueYet, isEmpty);
    });
  });

  group('CareScheduleRepository.snooze', () {
    test('pushes next_due_at forward and bumps snooze_count', () async {
      final p = await plants.create(nickname: 'D');
      final s = await schedules.upsert(
        plantId: p.id,
        type: 'water',
        baseIntervalDays: 7,
        firstDueAt: DateTime.utc(2026, 2, 1),
      );
      await schedules.snooze(s.id, by: const Duration(days: 1));
      final after = await schedules.forPlantAndType(p.id, 'water');
      expect(after!.nextDueAt, DateTime.utc(2026, 2, 2).millisecondsSinceEpoch);
      expect(after.snoozeCount, 1);
    });
  });
}
