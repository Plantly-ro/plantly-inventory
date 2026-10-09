import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/cloud/collection_link.dart' show migrateTenant;
import 'package:plantly_inventory/cloud/local_data_wipe.dart' show wipeDatabase;
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/repositories/care_event_repository.dart';
import 'package:plantly_inventory/data/repositories/care_schedule_repository.dart';
import 'package:plantly_inventory/data/repositories/plant_repository.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';
import 'package:plantly_inventory/sync/sync_applier.dart';
import 'package:plantly_inventory/sync/sync_markers.dart';
import 'package:plantly_inventory/sync/sync_transport.dart';

/// Marking care done on one device must move the reminder on every other
/// device / member. 1.1.0 recorded the schedule change as one
/// `@applyCareEvent` pseudo-field op that no applier understood.
class _Device {
  _Device(String id) {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = HlcClock(deviceId: id);
    opLog = OpLogWriter(db: db, clock: clock, tenantId: 'col-1');
    applier = SyncApplier(db: db, opLog: opLog, clock: clock);
    plants = PlantRepository(db: db, opLog: opLog);
    schedules = CareScheduleRepository(db: db, opLog: opLog);
    events = CareEventRepository(db: db, opLog: opLog, schedules: schedules);
  }

  late final AppDatabase db;
  late final HlcClock clock;
  late final OpLogWriter opLog;
  late final SyncApplier applier;
  late final PlantRepository plants;
  late final CareScheduleRepository schedules;
  late final CareEventRepository events;

  Future<List<SyncOpDto>> push() async {
    final rows = await (db.select(db.syncOps)
          ..where((o) => o.pushedAt.isNull())
          ..orderBy([(o) => OrderingTerm(expression: o.seq)]))
        .get();
    await (db.update(db.syncOps)..where((o) => o.pushedAt.isNull())).write(const SyncOpsCompanion(pushedAt: Value(1)));
    return [for (final r in rows) SyncOpDto.fromRow(r)];
  }

  Future<CareScheduleRow> schedule(String id) =>
      (db.select(db.careSchedules)..where((s) => s.id.equals(id))).getSingle();

  /// A fresh applier on the same DB = the next app launch (full repair).
  SyncApplier relaunch() => SyncApplier(db: db, opLog: opLog, clock: clock);
}

/// Columns care logging changes, as one comparable record.
(int?, double, int?, int, String, bool) _state(CareScheduleRow s) =>
    (s.lastDoneAt, s.currentIntervalDays, s.nextDueAt, s.snoozeCount, s.recentEventsJson, s.enabled);

/// The op a 1.1.0 build records for a care event — value shape copied from
/// `origin/main:lib/data/repositories/care_schedule_repository.dart`
/// (raw millis, `enabled` as 1/0).
SyncOpDto _legacyOp({
  required String scheduleId,
  required Hlc hlc,
  required int doneAt,
  required int nextDueAt,
  double interval = 3,
  int snoozeCount = 0,
  int enabled = 1,
  Map<String, Object?> extra = const {},
}) =>
    SyncOpDto(
      entity: 'care_schedules',
      entityId: scheduleId,
      field: kLegacyApplyCareEventField,
      value: {
        'last_done_at': doneAt,
        'current_interval_days': interval,
        'next_due_at': nextDueAt,
        'snooze_count': snoozeCount,
        'recent_events_json': json.encode([
          {'done_at': doneAt, 'snoozed': false, 'actual_interval_days': null},
        ]),
        'enabled': enabled,
        ...extra,
      },
      hlc: hlc.encode(),
      deviceId: hlc.deviceId,
    );

void main() {
  late _Device a;
  late _Device b;
  setUp(() {
    a = _Device('dev-a');
    b = _Device('dev-b');
  });
  tearDown(() async {
    await a.db.close();
    await b.db.close();
  });

  Future<void> sync(_Device from, _Device to) async => to.applier.applyBatch(await from.push());

  /// Plant + water schedule on A, mirrored to B. Due long ago (overdue).
  Future<CareScheduleRow> sharedOverdueSchedule() async {
    final p = await a.plants.create(nickname: 'Monstera');
    final s = await a.schedules.upsert(
      plantId: p.id,
      type: 'water',
      baseIntervalDays: 4,
      firstDueAt: DateTime.utc(2026, 1, 1),
    );
    await sync(a, b);
    expect(_state(await b.schedule(s.id)), _state(s));
    return s;
  }

  Hlc later(int ms) => Hlc(DateTime.now().toUtc().millisecondsSinceEpoch + ms, 0, 'dev-old');

  test('watering on A moves next_due / last_done (and the rest) on B; only wire-column ops are emitted', () async {
    final s = await sharedOverdueSchedule();
    final doneAt = DateTime.now().toUtc().millisecondsSinceEpoch;
    await a.events.record(plantId: s.plantId, type: 'water', doneAt: doneAt);

    final ops = await a.push();
    final scheduleOps = ops.where((o) => o.entity == 'care_schedules').toList();
    expect(scheduleOps.map((o) => o.field).toSet(), {
      'last_done_at',
      'current_interval_days',
      'next_due_at',
      'snooze_count',
      'recent_events_json',
      'enabled',
    });
    expect(ops.where((o) => o.field.startsWith('@')), isEmpty);
    await b.applier.applyBatch(ops);

    final mine = await a.schedule(s.id);
    final theirs = await b.schedule(s.id);
    expect(mine.lastDoneAt, doneAt);
    expect(mine.nextDueAt, greaterThan(doneAt), reason: 'no longer overdue');
    expect(_state(theirs), _state(mine));
    expect(theirs.updatedHlc, mine.updatedHlc);
  });

  test('a "once" schedule disabled by care on A is disabled on B', () async {
    final p = await a.plants.create(nickname: 'Fern');
    final s = await a.schedules.upsert(plantId: p.id, type: 'repot', baseIntervalDays: 30, recurrenceMode: 'once');
    await sync(a, b);
    await a.events.record(plantId: p.id, type: 'repot');
    await sync(a, b);
    final theirs = await b.schedule(s.id);
    expect(theirs.enabled, isFalse);
    expect(theirs.nextDueAt, isNull);
    expect(_state(theirs), _state(await a.schedule(s.id)));
  });

  test('snooze carries snooze_count to peers', () async {
    final s = await sharedOverdueSchedule();
    await a.schedules.snooze(s.id);
    await sync(a, b);
    final theirs = await b.schedule(s.id);
    expect(theirs.snoozeCount, 1);
    expect(_state(theirs), _state(await a.schedule(s.id)));
  });

  test('a legacy @applyCareEvent op from a 1.1.0 device is applied column by column', () async {
    final s = await sharedOverdueSchedule();
    final doneAt = DateTime.utc(2026, 10, 7, 9).millisecondsSinceEpoch;
    final next = DateTime.utc(2026, 10, 10, 9).millisecondsSinceEpoch;
    final hlc = later(1000);
    final r = await b.applier.applyBatch([
      _legacyOp(
        scheduleId: s.id,
        hlc: hlc,
        doneAt: doneAt,
        nextDueAt: next,
        // forged / unexpected columns are never written
        extra: {'plant_id': 'elsewhere', 'deleted_at': doneAt, 'base_interval_days': 99},
      ),
    ]);
    expect(r.applied, 1);
    expect(r.rejected, isEmpty);
    final row = await b.schedule(s.id);
    expect(row.lastDoneAt, doneAt);
    expect(row.nextDueAt, next);
    expect(row.currentIntervalDays, 3);
    expect(row.enabled, isTrue);
    expect(row.updatedHlc, hlc.encode());
    expect(row.plantId, s.plantId);
    expect(row.deletedAt, isNull);
    expect(row.baseIntervalDays, 4);

    // Re-delivery is an idempotent skip.
    final again = await b.applier.applyBatch([_legacyOp(scheduleId: s.id, hlc: hlc, doneAt: doneAt, nextDueAt: next)]);
    expect(again.applied, 0);
  });

  test('a legacy op outranks older field ops whatever the arrival order', () async {
    final s = await sharedOverdueSchedule();
    // A snoozes (older field op); a 1.1.0 device waters afterwards.
    await a.schedules.snooze(s.id);
    final snoozeOps = await a.push();
    final next = DateTime.utc(2026, 12, 1).millisecondsSinceEpoch;
    final legacy = _legacyOp(scheduleId: s.id, hlc: later(60000), doneAt: next - 86400000, nextDueAt: next);

    await b.applier.applyBatch([legacy]);
    await b.applier.applyBatch(snoozeOps); // older, arrives late
    await a.applier.applyBatch([legacy]);

    for (final d in [a, b]) {
      final row = await d.schedule(s.id);
      expect(row.nextDueAt, next, reason: d.clock.deviceId);
      expect(row.snoozeCount, 0, reason: d.clock.deviceId);
    }
    expect(_state(await b.schedule(s.id)), _state(await a.schedule(s.id)));
  });

  test('a legacy op that arrives before the schedule row is folded in when the row materialises', () async {
    final p = await a.plants.create(nickname: 'Pothos');
    final s = await a.schedules.upsert(plantId: p.id, type: 'water', baseIntervalDays: 4);
    final next = DateTime.utc(2026, 11, 1).millisecondsSinceEpoch;
    final legacy = _legacyOp(scheduleId: s.id, hlc: later(1000), doneAt: next - 1, nextDueAt: next);
    await b.applier.applyBatch([legacy]);
    await sync(a, b);
    final row = await b.schedule(s.id);
    expect(row.nextDueAt, next);
    expect(row.lastDoneAt, next - 1);
  });

  test('repair heals a DB where an earlier build stored a legacy op as ignored', () async {
    final s = await sharedOverdueSchedule();
    final next = DateTime.utc(2026, 11, 2).millisecondsSinceEpoch;
    final legacy = _legacyOp(scheduleId: s.id, hlc: later(1000), doneAt: next - 5, nextDueAt: next);
    // What an older applier did with it: store as remote, touch nothing.
    await b.opLog.recordRemote(legacy, deviceId: 'dev-old', nowMillis: 1);
    expect((await b.schedule(s.id)).nextDueAt, s.nextDueAt, reason: 'still overdue before the upgrade');

    final repaired = await b.relaunch().repair();
    expect(repaired.applied, 1);
    final row = await b.schedule(s.id);
    expect(row.nextDueAt, next);
    expect(row.lastDoneAt, next - 5);
    expect(row.updatedHlc, legacy.hlc);

    // Idempotent on the next launch.
    expect((await b.relaunch().repair()).applied, 0);
    expect(_state(await b.schedule(s.id)), _state(row));
  });

  test('repair leaves newer edits alone and restores a 1.1.0 device\'s own watering lost to an older op', () async {
    final s = await sharedOverdueSchedule();
    // 1.1.0 device = A (its own legacy op, applied locally back then).
    final mine = DateTime.utc(2026, 11, 3).millisecondsSinceEpoch;
    final own = _legacyOp(scheduleId: s.id, hlc: Hlc(later(60000).physicalMs, 0, 'dev-a'), doneAt: mine - 1, nextDueAt: mine);
    await a.opLog.recordRemote(own, deviceId: 'dev-a', nowMillis: 1);
    a.clock.merge(Hlc.parse(own.hlc)); // it was A's own clock that stamped it
    // ... then an OLDER next_due_at field op from B overwrote it there
    // (1.1.0 ignored legacy ops in LWW).
    await b.schedules.snooze(s.id);
    final older = (await b.push()).where((o) => o.field == 'next_due_at').single;
    await a.opLog.recordRemote(older, deviceId: 'dev-b', nowMillis: 1);
    await (a.db.update(a.db.careSchedules)..where((r) => r.id.equals(s.id))).write(
      CareSchedulesCompanion(nextDueAt: Value(Hlc.parse(older.hlc).physicalMs)),
    );

    await a.relaunch().repair();
    expect((await a.schedule(s.id)).nextDueAt, mine);

    // A later, ordinary edit is not undone by the next repair.
    final edited = DateTime.utc(2027, 1, 1);
    await a.schedules.edit(s.id, baseIntervalDays: 4, recurrenceMode: 'after_completion', nextDueAt: edited);
    await a.relaunch().repair();
    expect((await a.schedule(s.id)).nextDueAt, edited.millisecondsSinceEpoch);
  });

  test('concurrent waterings on A and B converge', () async {
    final s = await sharedOverdueSchedule();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await a.events.record(plantId: s.plantId, type: 'water', doneAt: now - 3600000);
    await b.events.record(plantId: s.plantId, type: 'water', doneAt: now);
    final fromA = await a.push();
    final fromB = await b.push();
    await b.applier.applyBatch(fromA);
    await a.applier.applyBatch(fromB);

    final ra = await a.schedule(s.id);
    final rb = await b.schedule(s.id);
    expect(_state(ra), _state(rb));
    expect(ra.updatedHlc, rb.updatedHlc);
    expect(ra.lastDoneAt, anyOf(now, now - 3600000));
    // Both care events exist on both devices.
    for (final d in [a, b]) {
      final evs = await (d.db.select(d.db.careEvents)..where((e) => e.plantId.equals(s.plantId))).get();
      expect(evs, hasLength(2));
    }
  });

  test('concurrent legacy (1.1.0) and new waterings converge on both new clients', () async {
    final s = await sharedOverdueSchedule();
    await a.events.record(plantId: s.plantId, type: 'water');
    final fromA = await a.push();
    final legacy = _legacyOp(
      scheduleId: s.id,
      hlc: Hlc(
        fromA.where((o) => o.entity == 'care_schedules').map((o) => Hlc.parse(o.hlc).physicalMs).reduce((x, y) => x < y ? x : y) - 1,
        0,
        'dev-old',
      ),
      doneAt: DateTime.utc(2026, 10, 1).millisecondsSinceEpoch,
      nextDueAt: DateTime.utc(2026, 10, 4).millisecondsSinceEpoch,
    );
    await b.applier.applyBatch([legacy, ...fromA]);
    await a.applier.applyBatch([legacy]);
    expect(_state(await b.schedule(s.id)), _state(await a.schedule(s.id)));
    expect((await b.schedule(s.id)).nextDueAt, isNot(DateTime.utc(2026, 10, 4).millisecondsSinceEpoch),
        reason: 'the newer (A) watering wins');
  });

  group('performance', () {
    List<SyncOpDto> legacyHistory(String scheduleId, int n, int baseMs) => [
          for (var i = 0; i < n; i++)
            _legacyOp(
              scheduleId: scheduleId,
              hlc: Hlc(baseMs + i * 1000, 0, 'dev-old'),
              doneAt: baseMs + i * 1000,
              nextDueAt: baseMs + i * 1000 + 3 * 86400000,
            ),
        ];

    test('a pulled page of 365 legacy ops for one schedule applies in < 1 s', () async {
      final s = await sharedOverdueSchedule();
      final base = DateTime.now().toUtc().millisecondsSinceEpoch + 1000;
      final ops = legacyHistory(s.id, 365, base);
      final sw = Stopwatch()..start();
      final r = await b.applier.applyBatch(ops);
      sw.stop();
      expect(r.applied, 365);
      expect((await b.schedule(s.id)).nextDueAt, base + 364 * 1000 + 3 * 86400000);
      expect(sw.elapsedMilliseconds, lessThan(1000), reason: '${sw.elapsedMilliseconds} ms');
    });

    test('a page of 365 legacy ops interleaved with new-style field ops stays linear (< 1.5 s)', () async {
      final s = await sharedOverdueSchedule();
      final base = DateTime.now().toUtc().millisecondsSinceEpoch + 1000;
      final ops = [
        for (final legacy in legacyHistory(s.id, 365, base)) ...[
          legacy,
          SyncOpDto(
            entity: 'care_schedules',
            entityId: s.id,
            field: 'next_due_at',
            value: Hlc.parse(legacy.hlc).physicalMs + 1,
            hlc: Hlc(Hlc.parse(legacy.hlc).physicalMs + 1, 0, 'dev-c').encode(),
            deviceId: 'dev-c',
          ),
        ],
      ];
      final sw = Stopwatch()..start();
      final r = await b.applier.applyBatch(ops);
      sw.stop();
      expect(r.applied, 730);
      expect((await b.schedule(s.id)).nextDueAt, base + 364 * 1000 + 1);
      expect(sw.elapsedMilliseconds, lessThan(1500), reason: '${sw.elapsedMilliseconds} ms');
    });

    test('repair over 5 schedules x 200 ignored legacy ops runs in < 1 s, once', () async {
      final p = await a.plants.create(nickname: 'Shelf');
      final ids = <String>[];
      for (final t in ['water', 'fertilize', 'mist', 'rotate', 'repot']) {
        ids.add((await a.schedules.upsert(plantId: p.id, type: t, baseIntervalDays: 4)).id);
      }
      await sync(a, b);
      final base = DateTime.now().toUtc().millisecondsSinceEpoch + 1000;
      for (final id in ids) {
        for (final op in legacyHistory(id, 200, base)) {
          await b.opLog.recordRemote(op, deviceId: 'dev-old', nowMillis: 1);
        }
      }
      final sw = Stopwatch()..start();
      final r = await b.relaunch().repair();
      sw.stop();
      expect(r.applied, 5);
      for (final id in ids) {
        expect((await b.schedule(id)).nextDueAt, base + 199 * 1000 + 3 * 86400000);
      }
      expect(sw.elapsedMilliseconds, lessThan(1000), reason: '${sw.elapsedMilliseconds} ms');

      // Marker: the next launch does not scan again, even if a row drifted.
      await (b.db.update(b.db.careSchedules)..where((r) => r.id.equals(ids.first)))
          .write(const CareSchedulesCompanion(nextDueAt: Value(1)));
      expect((await b.relaunch().repair()).applied, 0);
      expect((await b.schedule(ids.first)).nextDueAt, 1);
    });
  });

  group('one-shot marker lifecycle', () {
    const marker = 'reapply_legacy_care_events_v1';

    test('clearing / migrating without the table is a no-op', () async {
      await clearSyncMarkers(b.db);
      await clearSyncMarkers(b.db, tenantId: 'col-1');
      await migrateTenant(b.db, from: 'col-1', to: 'col-2');
      await wipeDatabase(b.db);
    });

    test('the web wipe clears every marker', () async {
      await b.relaunch().repair();
      await setSyncMarker(b.db, tenantId: 'other', name: marker, atMillis: 1);
      expect(await hasSyncMarker(b.db, tenantId: 'col-1', name: marker), isTrue);
      await wipeDatabase(b.db);
      expect(await hasSyncMarker(b.db, tenantId: 'col-1', name: marker), isFalse);
      expect(await hasSyncMarker(b.db, tenantId: 'other', name: marker), isFalse);
    });

    test('migrateTenant drops both tenants\' markers; reusing the tenant id re-runs the pass', () async {
      final s = await sharedOverdueSchedule();
      await b.relaunch().repair();
      await setSyncMarker(b.db, tenantId: 'col-2', name: marker, atMillis: 1);
      await setSyncMarker(b.db, tenantId: 'bystander', name: marker, atMillis: 1);

      await migrateTenant(b.db, from: 'col-1', to: 'col-2', resetSyncState: true);
      expect(await hasSyncMarker(b.db, tenantId: 'col-1', name: marker), isFalse);
      expect(await hasSyncMarker(b.db, tenantId: 'col-2', name: marker), isFalse);
      expect(await hasSyncMarker(b.db, tenantId: 'bystander', name: marker), isTrue);

      // Tenant id col-1 is used again: its rows and an ignored legacy op
      // come back (what an older build left behind), and the pass heals it.
      await migrateTenant(b.db, from: 'col-2', to: 'col-1');
      final next = DateTime.utc(2026, 11, 9).millisecondsSinceEpoch;
      final legacy = _legacyOp(scheduleId: s.id, hlc: later(1000), doneAt: next - 1, nextDueAt: next);
      await b.opLog.recordRemote(legacy, deviceId: 'dev-old', nowMillis: 1);
      expect((await b.relaunch().repair()).applied, 1);
      expect((await b.schedule(s.id)).nextDueAt, next);
    });
  });
}
