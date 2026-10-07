import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/repositories/care_schedule_repository.dart';
import 'package:plantly_inventory/data/repositories/plant_repository.dart';
import 'package:plantly_inventory/domain/services/local_calendar.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Review coverage for LocalCalendar (commit e11f11f): the production
/// (location == null) path in whatever zone the test process runs
/// (run with TZ=Europe/Bucharest / America/New_York / UTC), fixed-mode
/// catch-up termination for sub-day intervals, and float edge cases.
void main() {
  tzdata.initializeTimeZones();
  final bucharest = tz.getLocation('Europe/Bucharest');

  test('platform zone: +1 / +7 days keep 09:00 on every day of 2026-2027 (covers the process TZ DST days)', () {
    const cal = LocalCalendar();
    for (var d = DateTime(2026, 1, 1, 9); d.year < 2028; d = DateTime(d.year, d.month, d.day + 1, 9)) {
      for (final n in [1.0, 7.0]) {
        final to = DateTime.fromMillisecondsSinceEpoch(cal.addDays(d.millisecondsSinceEpoch, n));
        expect([to.hour, to.minute], [9, 0], reason: '$d + $n');
        expect(DateTime(to.year, to.month, to.day), DateTime(d.year, d.month, d.day + n.toInt()), reason: '$d + $n');
      }
      final snoozed = DateTime.fromMillisecondsSinceEpoch(
          cal.addDuration(d.millisecondsSinceEpoch, const Duration(days: 1)));
      expect(snoozed.hour, 9, reason: 'snooze $d');
    }
  });

  test('platform zone: sub-day intervals are plain elapsed time', () {
    const cal = LocalCalendar();
    final from = DateTime(2026, 10, 24, 22).millisecondsSinceEpoch;
    expect(cal.addDays(from, 0.25), from + 6 * 3600000);
    expect(cal.addDuration(from, const Duration(hours: 3)), from + 3 * 3600000);
  });

  test('every result is strictly later than its input for positive intervals (no catch-up stall)', () {
    final cal = LocalCalendar(location: bucharest);
    // Wall times inside / next to both 2026-27 transitions.
    final starts = [
      tz.TZDateTime(bucharest, 2026, 10, 24, 3, 30),
      tz.TZDateTime(bucharest, 2026, 10, 25, 3, 30),
      tz.TZDateTime(bucharest, 2027, 3, 27, 3, 30),
      tz.TZDateTime(bucharest, 2027, 3, 28, 2, 59),
    ];
    for (final s in starts) {
      for (final d in [1e-6, 0.01, 0.5, 1.0, 1.5, 2.0, 7.0]) {
        final from = s.millisecondsSinceEpoch;
        expect(cal.addDays(from, d), greaterThan(from), reason: '$s + $d');
      }
    }
  });

  group('fixed-mode catch-up', () {
    late AppDatabase db;
    late PlantRepository plants;
    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      plants = PlantRepository(db: db, opLog: OpLogWriter(db: db, clock: HlcClock(deviceId: 'dev'), tenantId: 't'));
    });
    tearDown(() => db.close());

    CareScheduleRepository repo() => CareScheduleRepository(
          db: db,
          opLog: OpLogWriter(db: db, clock: HlcClock(deviceId: 'dev'), tenantId: 't'),
          calendar: LocalCalendar(location: bucharest),
        );

    Future<CareScheduleRow> run(double days, tz.TZDateTime anchor, tz.TZDateTime doneAt) async {
      final r = repo();
      final p = await plants.create(nickname: 'P');
      final s = await r.upsert(
        plantId: p.id,
        type: 'water',
        baseIntervalDays: days,
        recurrenceMode: 'fixed',
        firstDueAt: DateTime.fromMillisecondsSinceEpoch(anchor.millisecondsSinceEpoch, isUtc: true),
      );
      await r.applyCareEvent(
        plantId: p.id,
        type: 'water',
        doneAt: DateTime.fromMillisecondsSinceEpoch(doneAt.millisecondsSinceEpoch, isUtc: true),
      );
      return (db.select(db.careSchedules)..where((x) => x.id.equals(s.id))).getSingle();
    }

    test('half-day interval across fall-back terminates and lands after doneAt', () async {
      final row = await run(0.5, tz.TZDateTime(bucharest, 2026, 10, 20, 9), tz.TZDateTime(bucharest, 2026, 10, 26, 10));
      final due = tz.TZDateTime.fromMillisecondsSinceEpoch(bucharest, row.nextDueAt!);
      expect(due.isAfter(tz.TZDateTime(bucharest, 2026, 10, 26, 10)), isTrue);
      // 12 h steps of elapsed time: the fall-back hour shifts the half-day phase by 1 h.
      expect(due.hour, 20);
    });

    test('daily anchor a year in the past catches up to the next 09:00', () async {
      final row = await run(1, tz.TZDateTime(bucharest, 2025, 10, 1, 9), tz.TZDateTime(bucharest, 2026, 10, 25, 12));
      final due = tz.TZDateTime.fromMillisecondsSinceEpoch(bucharest, row.nextDueAt!);
      expect([due.year, due.month, due.day, due.hour], [2026, 10, 26, 9]);
    });

    test('tiny interval rounding to 0 ms disables instead of looping', () async {
      final row = await run(1e-12, tz.TZDateTime(bucharest, 2026, 10, 20, 9), tz.TZDateTime(bucharest, 2026, 10, 26, 10));
      expect(row.nextDueAt, isNull);
      expect(row.enabled, isFalse);
    });
  });

  // REVIEW FINDING (low): floor() on a value a hair below an integer (e.g.
  // a 123-day reminder round-tripped through the edit sheet's months unit:
  // 123/30*30 == 122.99999999999999) yields 122 calendar days + a fractional
  // remainder that rounds to a full 24 h of elapsed time, so the DST hour
  // leaks back in when the transition falls on the last day.
  test('near-integer interval behaves like the integer', () {
    final cal = LocalCalendar(location: bucharest);
    final from = tz.TZDateTime(bucharest, 2026, 6, 24, 9).millisecondsSinceEpoch;
    const days = 123 / 30 * 30; // 122.99999999999999
    expect(days, lessThan(123));
    expect(cal.addDays(from, days), cal.addDays(from, 123));
  });
}
