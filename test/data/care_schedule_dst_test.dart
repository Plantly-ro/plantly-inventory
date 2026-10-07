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

const _dayMs = Duration.millisecondsPerDay;

void main() {
  tzdata.initializeTimeZones();
  final bucharest = tz.getLocation('Europe/Bucharest');
  final tokyo = tz.getLocation('Asia/Tokyo');

  int at(tz.Location loc, int y, int m, int d, int h, [int min = 0]) =>
      tz.TZDateTime(loc, y, m, d, h, min).millisecondsSinceEpoch;
  String wall(tz.Location loc, int ms) {
    final t = tz.TZDateTime.fromMillisecondsSinceEpoch(loc, ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)} ${t.timeZoneName}';
  }

  group('LocalCalendar', () {
    final cal = LocalCalendar(location: bucharest);

    test('fall-back (2026-10-25): +1 day keeps 09:00 (EEST → EET), 25 h elapsed', () {
      final from = at(bucharest, 2026, 10, 24, 9);
      final to = cal.addDays(from, 1);
      expect(wall(bucharest, to), '2026-10-25 09:00 EET');
      expect(to - from, _dayMs + 3600000);
    });

    test('spring-forward (2027-03-28): +1 day keeps 09:00 (EET → EEST), 23 h elapsed', () {
      final from = at(bucharest, 2027, 3, 27, 9);
      final to = cal.addDays(from, 1);
      expect(wall(bucharest, to), '2027-03-28 09:00 EEST');
      expect(to - from, _dayMs - 3600000);
    });

    test('fractional interval: whole days on the calendar, remainder as elapsed time', () {
      final from = at(bucharest, 2026, 10, 24, 9);
      expect(wall(bucharest, cal.addDays(from, 1.5)), '2026-10-25 21:00 EET');
      expect(cal.addDays(from, 0.5) - from, _dayMs ~/ 2);
    });

    test('addDuration: whole days on the calendar, rest as elapsed time', () {
      final from = at(bucharest, 2026, 10, 24, 9);
      expect(wall(bucharest, cal.addDuration(from, const Duration(days: 1))), '2026-10-25 09:00 EET');
      expect(wall(bucharest, cal.addDuration(from, const Duration(days: 3, hours: 2))), '2026-10-27 11:00 EET');
      expect(cal.addDuration(from, const Duration(hours: 5)) - from, 5 * 3600000);
    });

    test('a wall-clock time inside the spring-forward gap moves forward, never back', () {
      final from = at(bucharest, 2027, 3, 27, 3, 30);
      final to = cal.addDays(from, 1);
      expect(to, greaterThan(from));
      expect(wall(bucharest, to), '2027-03-28 04:30 EEST');
    });

    test('a zone without DST is plain elapsed-time arithmetic', () {
      final t = LocalCalendar(location: tokyo);
      final from = at(tokyo, 2026, 10, 24, 9);
      expect(t.addDays(from, 1), from + _dayMs);
      expect(t.addDays(from, 7.3), from + (7.3 * _dayMs).round());
      expect(t.addDuration(from, const Duration(days: 1)), from + _dayMs);
    });

    test('platform zone (location null) keeps the local wall-clock time', () {
      const cal = LocalCalendar();
      final from = DateTime(2026, 10, 24, 9).millisecondsSinceEpoch;
      final to = DateTime.fromMillisecondsSinceEpoch(cal.addDays(from, 1));
      expect([to.year, to.month, to.day, to.hour, to.minute], [2026, 10, 25, 9, 0]);
    });
  });

  group('CareScheduleRepository across DST (Europe/Bucharest)', () {
    late AppDatabase db;
    late PlantRepository plants;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      final opLog = OpLogWriter(db: db, clock: HlcClock(deviceId: 'dev'), tenantId: 't');
      plants = PlantRepository(db: db, opLog: opLog);
    });
    tearDown(() => db.close());

    CareScheduleRepository repo(tz.Location loc) => CareScheduleRepository(
          db: db,
          opLog: OpLogWriter(db: db, clock: HlcClock(deviceId: 'dev'), tenantId: 't'),
          calendar: LocalCalendar(location: loc),
        );

    Future<CareScheduleRow> schedule(CareScheduleRepository r, String mode, double days, int firstDueMs) async {
      final p = await plants.create(nickname: 'Pothos');
      return r.upsert(
        plantId: p.id,
        type: 'water',
        baseIntervalDays: days,
        recurrenceMode: mode,
        firstDueAt: DateTime.fromMillisecondsSinceEpoch(firstDueMs, isUtc: true),
      );
    }

    Future<CareScheduleRow> reload(String id) =>
        (db.select(db.careSchedules)..where((s) => s.id.equals(id))).getSingle();

    test('after_completion daily: done 09:00 EEST the day before fall-back → due 09:00 EET', () async {
      final r = repo(bucharest);
      final s = await schedule(r, 'after_completion', 1, at(bucharest, 2026, 10, 24, 9));
      await r.applyCareEvent(
        plantId: s.plantId,
        type: 'water',
        doneAt: DateTime.fromMillisecondsSinceEpoch(at(bucharest, 2026, 10, 24, 9), isUtc: true),
      );
      final row = await reload(s.id);
      expect(row.currentIntervalDays, 1);
      expect(wall(bucharest, row.nextDueAt!), '2026-10-25 09:00 EET');
    });

    test('after_completion daily across spring-forward → due 09:00 EEST', () async {
      final r = repo(bucharest);
      final s = await schedule(r, 'after_completion', 1, at(bucharest, 2027, 3, 27, 9));
      await r.applyCareEvent(
        plantId: s.plantId,
        type: 'water',
        doneAt: DateTime.fromMillisecondsSinceEpoch(at(bucharest, 2027, 3, 27, 9), isUtc: true),
      );
      expect(wall(bucharest, (await reload(s.id)).nextDueAt!), '2027-03-28 09:00 EEST');
    });

    test('fixed cadence keeps its 09:00 anchor across fall-back, including multi-step catch-up', () async {
      final r = repo(bucharest);
      final s = await schedule(r, 'fixed', 1, at(bucharest, 2026, 10, 24, 9));
      await r.applyCareEvent(
        plantId: s.plantId,
        type: 'water',
        doneAt: DateTime.fromMillisecondsSinceEpoch(at(bucharest, 2026, 10, 24, 10), isUtc: true),
      );
      expect(wall(bucharest, (await reload(s.id)).nextDueAt!), '2026-10-25 09:00 EET');

      // Logged late, days after the anchor: still lands on a 09:00.
      await r.applyCareEvent(
        plantId: s.plantId,
        type: 'water',
        doneAt: DateTime.fromMillisecondsSinceEpoch(at(bucharest, 2026, 10, 28, 12), isUtc: true),
      );
      expect(wall(bucharest, (await reload(s.id)).nextDueAt!), '2026-10-29 09:00 EET');
    });

    test('fixed weekly cadence across spring-forward', () async {
      final r = repo(bucharest);
      final s = await schedule(r, 'fixed', 7, at(bucharest, 2027, 3, 22, 9));
      await r.applyCareEvent(
        plantId: s.plantId,
        type: 'water',
        doneAt: DateTime.fromMillisecondsSinceEpoch(at(bucharest, 2027, 3, 22, 9, 30), isUtc: true),
      );
      expect(wall(bucharest, (await reload(s.id)).nextDueAt!), '2027-03-29 09:00 EEST');
    });

    test('snooze by 1 day across fall-back keeps 09:00', () async {
      final r = repo(bucharest);
      final s = await schedule(r, 'after_completion', 3, at(bucharest, 2026, 10, 24, 9));
      await r.snooze(s.id);
      expect(wall(bucharest, (await reload(s.id)).nextDueAt!), '2026-10-25 09:00 EET');
      await r.snooze(s.id, by: const Duration(days: 3));
      expect(wall(bucharest, (await reload(s.id)).nextDueAt!), '2026-10-28 09:00 EET');
    });

    test('a zone without DST computes exactly what elapsed-ms arithmetic did', () async {
      final r = repo(tokyo);
      final due = at(tokyo, 2026, 10, 24, 9);
      final s = await schedule(r, 'fixed', 1, due);
      await r.applyCareEvent(
        plantId: s.plantId,
        type: 'water',
        doneAt: DateTime.fromMillisecondsSinceEpoch(due + 3600000, isUtc: true),
      );
      expect((await reload(s.id)).nextDueAt, due + _dayMs);
      await r.snooze(s.id);
      expect((await reload(s.id)).nextDueAt, due + 2 * _dayMs);
    });
  });
}
