import 'package:drift/drift.dart' show ApplyInterceptor, QueryExecutor, QueryInterceptor, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/repositories/tag_repository.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';
import 'package:plantly_inventory/sync/sync_applier.dart';
import 'package:plantly_inventory/sync/sync_rejections.dart';
import 'package:plantly_inventory/sync/sync_transport.dart';

String hlcAt(int ms, {int logical = 0, String dev = 'dev-b'}) => Hlc(ms, logical, dev).encode();

SyncOpDto op(String entity, String id, String field, Object? value, String hlc, {String? device}) =>
    SyncOpDto(entity: entity, entityId: id, field: field, value: value, hlc: hlc, deviceId: device);

Map<String, dynamic> plantJson(String id, {String? nickname = 'Remote', String? notes, String hlc = ''}) => {
      'id': id,
      'nickname': nickname,
      'species_id': null,
      'location_id': null,
      'pin_x': null,
      'pin_y': null,
      'notifications_muted': false,
      'status': 'active',
      'acquired_at': '2023-11-14T22:13:20.000Z',
      'source': null,
      'notes': notes,
      'pot_size_cm': 10,
      'updated_hlc': hlc,
      'deleted_at': null,
      'device_id': 'dev-b',
    };

Map<String, dynamic> scheduleJson(String id, {String plant = 'p1', String type = 'water', int days = 7}) => {
      'id': id, 'plant_id': plant, 'type': type, 'base_interval_days': days, 'current_interval_days': days,
      'enabled': true, 'recurrence_mode': 'fixed', 'device_id': 'dev-b',
    };

/// One simulated device: its own DB, clock, op log and applier.
class Device {
  Device(this.deviceId, {this.tenant = 'col-1', int startWall = 1000, bool readOnly = false}) : _wall = startWall {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = HlcClock(deviceId: deviceId, nowProvider: () => DateTime.fromMillisecondsSinceEpoch(_wall++, isUtc: true));
    opLog = OpLogWriter(db: db, clock: clock, tenantId: tenant);
    applier = SyncApplier(db: db, opLog: opLog, clock: clock, readOnly: readOnly, nowMillis: () => 99);
  }
  final String deviceId;
  final String tenant;
  int _wall;
  late final AppDatabase db;
  late final HlcClock clock;
  late final OpLogWriter opLog;
  late final SyncApplier applier;

  Future<PlantRow?> plant(String id) => (db.select(db.plants)..where((p) => p.id.equals(id))).getSingleOrNull();
  Future<List<SyncRejectionRow>> ledger() => db.select(db.syncRejections).get();
  Future<int> localOpCount() async =>
      (await db.select(db.syncOps).get()).where((o) => o.deviceId == deviceId).length;

  Future<void> close() => db.close();
}

void main() {
  late Device d;
  setUp(() => d = Device('dev-a'));
  tearDown(() => d.close());

  group('P1: one bad pulled op never wedges the batch', () {
    test('NOT NULL field op set to null: batch succeeds, valid ops apply, bad op recorded remote + parked', () async {
      await d.applier.applyBatch([op('plants', 'p1', '*', plantJson('p1', nickname: 'Fern', hlc: hlcAt(5000)), hlcAt(5000))]);

      final batch = [
        op('plants', 'p1', 'notes', 'before', hlcAt(6000)),
        op('plants', 'p1', 'nickname', null, hlcAt(6001)), // NOT NULL column
        op('plants', 'p2', '*', plantJson('p2', hlc: hlcAt(6002)), hlcAt(6002)),
        op('plants', 'p1', 'pot_size_cm', 14, hlcAt(6003)),
      ];
      final r = await d.applier.applyBatch(batch);
      expect(r.applied, 3);
      expect(r.rejected, hasLength(1));
      final p1 = (await d.plant('p1'))!;
      expect(p1.nickname, 'Fern');
      expect(p1.notes, 'before');
      expect(p1.potSizeCm, 14);
      expect(await d.plant('p2'), isNotNull);

      // The bad op is stored as remote (idempotent, never pushed) …
      final stored = (await d.db.select(d.db.syncOps).get()).singleWhere((o) => o.field == 'nickname');
      expect(stored.pushedAt, 99);
      expect(await d.opLog.pendingCount(), 0);
      // … and parked in the ledger with the inbound reason.
      final ledger = (await d.ledger()).single;
      expect(ledger.opSeq, stored.seq);
      expect(ledger.reason, kInvalidRemoteOpReason);
      expect(ledger.parked, isTrue);
      expect(ledger.entity, 'plants');
      expect(ledger.field, 'nickname');

      // Re-delivery (cursor reset, fresh page) is a plain idempotent skip.
      final again = await d.applier.applyBatch(batch);
      expect(again.applied, 0);
      expect(again.rejected, isEmpty);
      expect(await d.ledger(), hasLength(1));

      // "Retry all" never re-queues a remote op.
      final store = SyncRejectionStore(db: d.db, tenantId: d.tenant);
      expect(await store.retryAll(), 0);
      expect(await d.opLog.pendingCount(), 0);
    });

    test('a fresh device pulling the whole history including the bad op materialises everything', () async {
      final r = await d.applier.applyBatch([
        op('plants', 'p1', '*', plantJson('p1', nickname: 'Fern', hlc: hlcAt(5000)), hlcAt(5000)),
        op('plants', 'p1', 'nickname', null, hlcAt(6001)),
        op('plants', 'p1', 'notes', 'later', hlcAt(7000)),
      ]);
      expect(r.applied, 2);
      final p1 = (await d.plant('p1'))!;
      expect(p1.nickname, 'Fern');
      expect(p1.notes, 'later');
    });

    test('type mismatch on a field op is rejected, not coerced to null', () async {
      await d.applier.applyBatch([op('plants', 'p1', '*', plantJson('p1', hlc: hlcAt(5000)), hlcAt(5000))]);
      final r = await d.applier.applyBatch([
        op('plants', 'p1', 'pot_size_cm', 'huge', hlcAt(6000)),
        op('plants', 'p1', 'acquired_at', 'not-a-date', hlcAt(6001)),
      ]);
      expect(r.applied, 0);
      expect(r.rejected, hasLength(2));
      expect((await d.plant('p1'))!.potSizeCm, 10);
      expect((await d.plant('p1'))!.acquiredAt, 1700000000000);
    });

    test('`*` update with a null NOT NULL column applies the other columns, keeps the stored value', () async {
      await d.applier.applyBatch([op('plants', 'p1', '*', plantJson('p1', nickname: 'Fern', hlc: hlcAt(5000)), hlcAt(5000))]);
      final r = await d.applier.applyBatch([
        op('plants', 'p1', '*', plantJson('p1', nickname: null, notes: 'new', hlc: hlcAt(6000)), hlcAt(6000)),
      ]);
      expect(r.applied, 1);
      final p1 = (await d.plant('p1'))!;
      expect(p1.nickname, 'Fern');
      expect(p1.notes, 'new');
    });

    test('`*` insert with a null NOT NULL column still materialises the row (schema default)', () async {
      final r = await d.applier.applyBatch([
        op('plants', 'p1', '*', {...plantJson('p1', nickname: null, hlc: hlcAt(5000)), 'status': null}, hlcAt(5000)),
      ]);
      expect(r.applied, 1);
      final p1 = (await d.plant('p1'))!;
      expect(p1.nickname, '');
      expect(p1.status, isNotNull);
    });

    test('a bad field op that arrived before its row does not poison the `*` materialisation', () async {
      await d.applier.applyBatch([op('plants', 'p1', 'nickname', null, hlcAt(7000))]);
      final r = await d.applier.applyBatch([op('plants', 'p1', '*', plantJson('p1', nickname: 'Fern', hlc: hlcAt(6000)), hlcAt(6000))]);
      expect(r.applied, 1);
      expect((await d.plant('p1'))!.nickname, 'Fern');
    });

    test('invalid ops do not take part in LWW: an older valid op arriving after a newer bad one still applies', () async {
      await d.applier.applyBatch([op('plants', 'p1', '*', plantJson('p1', nickname: 'Fern', hlc: hlcAt(5000)), hlcAt(5000))]);
      await d.applier.applyBatch([op('plants', 'p1', 'nickname', null, hlcAt(8000))]);
      final r = await d.applier.applyBatch([op('plants', 'p1', 'nickname', 'Older but valid', hlcAt(7000))]);
      expect(r.applied, 1);
      expect((await d.plant('p1'))!.nickname, 'Older but valid');
    });

    test('an unexpected SQL failure (tag rename onto a taken name) is isolated by a savepoint and parked', () async {
      await d.applier.applyBatch([
        op('tags', 't1', '*', {'id': 't1', 'name': 'cactus', 'device_id': 'dev-b'}, hlcAt(5000)),
        op('tags', 't2', '*', {'id': 't2', 'name': 'fern', 'device_id': 'dev-b'}, hlcAt(5001)),
      ]);
      final r = await d.applier.applyBatch([
        op('tags', 't2', 'color', '#f00', hlcAt(6000)),
        op('tags', 't2', 'name', 'cactus', hlcAt(6001)), // UNIQUE(tenant, name)
        op('tags', 't1', 'color', '#0f0', hlcAt(6002)),
      ]);
      expect(r.applied, 2);
      expect(r.rejected, hasLength(1));
      final tags = {for (final t in await d.db.select(d.db.tags).get()) t.id: t};
      expect(tags['t2']!.name, 'fern');
      expect(tags['t2']!.color, '#f00');
      expect(tags['t1']!.color, '#0f0');
      final ledger = (await d.ledger()).single;
      expect(ledger.reason, kApplyErrorReason);
      expect(ledger.entityId, 't2');
      expect(ledger.field, 'name');
      // Nothing half-applied, op stored as remote.
      final stored = (await d.db.select(d.db.syncOps).get()).singleWhere((o) => o.field == 'name');
      expect(stored.pushedAt, 99);
      expect(ledger.opSeq, stored.seq);
    });
  });

  group('P2: delete a reminder, add the same type again', () {
    Future<void> localSchedule(String id, {String type = 'water'}) async {
      final h = await d.opLog.recordCreate(
          entity: 'care_schedules', entityId: id, value: {'plant_id': 'p1', 'type': type, 'base_interval_days': 7, 'current_interval_days': 7});
      await d.db.into(d.db.careSchedules).insert(CareSchedulesCompanion.insert(
          id: id, tenantId: d.tenant, plantId: 'p1', type: type, baseIntervalDays: 7, currentIntervalDays: 7, updatedHlc: h.encode(), deviceId: 'dev-a'));
    }

    test('remote re-create colliding with a locally tombstoned row is inserted; the dead row is purged; no local ops', () async {
      await localSchedule('cs-old');
      await d.applier.applyBatch([op('care_schedules', 'cs-old', '__tombstone__', null, hlcAt(5000))]);
      final before = await d.localOpCount();

      final r = await d.applier.applyBatch([op('care_schedules', 'cs-new', '*', scheduleJson('cs-new', days: 3), hlcAt(6000))]);
      expect(r.applied, 1);
      final rows = await d.db.select(d.db.careSchedules).get();
      expect(rows.map((s) => s.id), ['cs-new']);
      expect(rows.single.deletedAt, isNull);
      expect(rows.single.baseIntervalDays, 3);
      expect(await d.localOpCount(), before);

      // A late op for the purged row stays inert (its tombstone is in the log).
      final late = await d.applier.applyBatch([op('care_schedules', 'cs-old', '*', scheduleJson('cs-old'), hlcAt(4000))]);
      expect(late.applied, 0);
      expect((await d.db.select(d.db.careSchedules).get()).map((s) => s.id), ['cs-new']);
    });
  });

  test('tag deleted remotely, then re-created locally under the same name (TagRepository.ensure)', () async {
    await d.applier.applyBatch([
      op('tags', 't-old', '*', {'id': 't-old', 'name': 'cactus', 'device_id': 'dev-b'}, hlcAt(5000)),
      op('tags', 't-old', '__tombstone__', null, hlcAt(5001)),
    ]);
    final tag = await TagRepository(db: d.db, opLog: d.opLog).ensure('Cactus');
    expect(tag.id, isNot('t-old'));
    expect(tag.deletedAt, isNull);
    expect((await d.db.select(d.db.tags).get()).map((t) => t.id), [tag.id]);
  });

  group('P3: a viewer resolves unique conflicts without recording ops', () {
    test('care_schedules (plant,type) conflict in either direction: no pending ops on a viewer', () async {
      final v = Device('dev-v', readOnly: true);
      try {
        await v.applier.applyBatch([op('care_schedules', 'cs-1', '*', scheduleJson('cs-1', days: 1), hlcAt(3000))]);
        await v.applier.applyBatch([op('care_schedules', 'cs-2', '*', scheduleJson('cs-2', days: 2), hlcAt(5000))]);
        expect((await v.db.select(v.db.careSchedules).get()).map((s) => s.id), ['cs-2']);
        final r = await v.applier.applyBatch([op('care_schedules', 'cs-0', '*', scheduleJson('cs-0', days: 9), hlcAt(4000))]);
        expect(r.applied, 0);
        expect((await v.db.select(v.db.careSchedules).get()).map((s) => s.id), ['cs-2']);
        expect(await v.localOpCount(), 0);
        expect(await v.opLog.pendingCount(), 0);
      } finally {
        await v.close();
      }
    });

    test('tags conflict on a viewer: plant_tags re-pointed / detached locally, no ops', () async {
      final v = Device('dev-v', readOnly: true);
      try {
        await v.applier.applyBatch([
          op('tags', 't1', '*', {'id': 't1', 'name': 'succulent', 'device_id': 'dev-x'}, hlcAt(3000, dev: 'dev-x')),
          op('plant_tags', 'pt-1', '*', {'id': 'pt-1', 'plant_id': 'p1', 'tag_id': 't1', 'device_id': 'dev-x'}, hlcAt(3001, dev: 'dev-x')),
          op('plant_tags', 'pt-2', '*', {'id': 'pt-2', 'plant_id': 'p2', 'tag_id': 't1', 'device_id': 'dev-x'}, hlcAt(3002, dev: 'dev-x')),
          op('plant_tags', 'pt-r', '*', {'id': 'pt-r', 'plant_id': 'p2', 'tag_id': 't2', 'device_id': 'dev-y'}, hlcAt(3500, dev: 'dev-y')),
          op('tags', 't2', '*', {'id': 't2', 'name': 'succulent', 'device_id': 'dev-y'}, hlcAt(4000, dev: 'dev-y')),
        ]);
        expect((await v.db.select(v.db.tags).get()).map((t) => t.id), ['t2']);
        final live = {
          for (final r in await v.db.select(v.db.plantTags).get())
            if (r.removedHlc == null) r.id: r.tagId,
        };
        expect(live, {'pt-1': 't2', 'pt-r': 't2'});
        expect(await v.localOpCount(), 0);
      } finally {
        await v.close();
      }
    });

    test("a viewer ends where the writer does once the writer's resolution ops arrive", () async {
      final w = Device('dev-w');
      final v = Device('dev-v', readOnly: true);
      try {
        final ops = [
          op('care_schedules', 'cs-1', '*', scheduleJson('cs-1', days: 1), hlcAt(3000, dev: 'dev-x')),
          op('care_schedules', 'cs-2', '*', scheduleJson('cs-2', days: 2), hlcAt(5000, dev: 'dev-y')),
        ];
        await w.applier.applyBatch(ops);
        await v.applier.applyBatch(ops);
        final pushed = [
          for (final o in await w.db.select(w.db.syncOps).get())
            if (o.pushedAt == null) SyncOpDto.fromRow(o),
        ];
        expect(pushed.map((o) => '${o.entityId}.${o.field}'), ['cs-1.__tombstone__']);
        await v.applier.applyBatch(pushed);
        Future<List<String>> live(Device x) async =>
            [for (final s in await x.db.select(x.db.careSchedules).get()) if (s.deletedAt == null) s.id];
        expect(await live(v), await live(w));
        expect(await v.localOpCount(), 0);
      } finally {
        await w.close();
        await v.close();
      }
    });
  });

  group('repair pass', () {
    test('1.1.0 dropped a re-created reminder (insert lost to the dead row): the first repair materialises it', () async {
      // State as 1.1.0 left it: cs-a soft-deleted (its row still holds the
      // unique key); cs-c's ops recorded but its insert failed → no row.
      await d.applier.applyBatch([
        op('care_schedules', 'cs-a', '*', scheduleJson('cs-a', days: 7), hlcAt(1000, dev: 'dev-x')),
        op('care_schedules', 'cs-a', '__tombstone__', null, hlcAt(2000, dev: 'dev-x')),
      ]);
      await d.opLog.recordRemote(op('care_schedules', 'cs-c', '*', scheduleJson('cs-c', days: 3), hlcAt(3000, dev: 'dev-x')),
          deviceId: 'dev-x', nowMillis: 99);
      await d.opLog.recordRemote(op('care_schedules', 'cs-c', 'base_interval_days', 4, hlcAt(3500, dev: 'dev-y')),
          deviceId: 'dev-y', nowMillis: 99);
      expect((await d.db.select(d.db.careSchedules).get()).map((s) => s.id), ['cs-a']);

      final r = await d.applier.repair();
      expect(r.applied, 1);
      final rows = await d.db.select(d.db.careSchedules).get();
      expect(rows.map((s) => '${s.id}/${s.baseIntervalDays}/${s.deletedAt}'), ['cs-c/4.0/null']);
      expect(await d.localOpCount(), 0);

      // A fresh applier (next launch) repairs again: idempotent, and the
      // tombstoned cs-a is never resurrected.
      final next = SyncApplier(db: d.db, opLog: d.opLog, clock: d.clock, nowMillis: () => 99);
      expect((await next.repair()).applied, 0);
      expect((await d.db.select(d.db.careSchedules).get()).map((s) => s.id), ['cs-c']);
    });

    test('OR-Set removal that arrived before its `*` keeps the row removed — on apply and via repair', () async {
      Map<String, dynamic> pt(String id) =>
          {'id': id, 'plant_id': 'p1', 'tag_id': 't1', 'removed_hlc': null, 'device_id': 'dev-b'};
      await d.applier.applyBatch([op('plant_tags', 'pt-1', 'removed_hlc', null, hlcAt(6000))]);
      await d.applier.applyBatch([op('plant_tags', 'pt-1', '*', pt('pt-1'), hlcAt(5000))]);
      final applied = await (d.db.select(d.db.plantTags)..where((r) => r.id.equals('pt-1'))).getSingle();
      expect(applied.removedHlc, hlcAt(6000));

      // Same history pre-recorded with no row (e.g. a dropped insert): the
      // repair pass must not resurrect the detached tag.
      await d.opLog.recordRemote(op('plant_tags', 'pt-2', '*', pt('pt-2'), hlcAt(5000)), deviceId: 'dev-b', nowMillis: 99);
      await d.opLog.recordRemote(op('plant_tags', 'pt-2', 'removed_hlc', null, hlcAt(6000)), deviceId: 'dev-b', nowMillis: 99);
      await d.applier.repair();
      final repaired = await (d.db.select(d.db.plantTags)..where((r) => r.id.equals('pt-2'))).getSingle();
      expect(repaired.removedHlc, hlcAt(6000));
    });

    test('repair never re-records our own still-pending op as remote (it must still reach the server)', () async {
      final h = await d.opLog.recordCreate(entity: 'plants', entityId: 'p1', value: {'id': 'p1', 'nickname': 'Mine', 'status': 'active'});
      final local = (await d.db.select(d.db.syncOps).get()).single;
      await d.db.into(d.db.syncRejections).insert(SyncRejectionsCompanion.insert(
          opSeq: Value(local.seq), tenantId: d.tenant, entity: 'plants', entityId: 'p1', field: '*',
          reason: kApplyErrorReason, hlc: h.encode(), at: 1, parked: const Value(true)));
      await d.applier.repair();
      final after = (await d.db.select(d.db.syncOps).get()).where((o) => o.entityId == 'p1').toList();
      expect(after.map((o) => (o.seq, o.pushedAt)), [(local.seq, null)]);
      expect(await d.opLog.pendingCount(), 1);
      expect(await d.ledger(), isEmpty);
    });

    test('a parked apply_error op is re-applied after "Retry all" once it can succeed', () async {
      await d.applier.applyBatch([
        op('tags', 't1', '*', {'id': 't1', 'name': 'cactus', 'device_id': 'dev-b'}, hlcAt(5000)),
        op('tags', 't2', '*', {'id': 't2', 'name': 'fern', 'device_id': 'dev-b'}, hlcAt(5001)),
      ]);
      await d.applier.repair(); // full pass done
      final r = await d.applier.applyBatch([op('tags', 't2', 'name', 'cactus', hlcAt(6001))]);
      expect(r.rejected.single.reason, kApplyErrorReason);
      expect((await d.applier.repair()).applied, 0, reason: 'not retried on its own after the full pass');
      // Another device renames t1 away, freeing the name.
      await d.applier.applyBatch([op('tags', 't1', 'name', 'cacti', hlcAt(6000, dev: 'dev-c'))]);

      final store = SyncRejectionStore(db: d.db, tenantId: d.tenant);
      expect(await store.retryAll(), 0);
      expect((await d.ledger()).single.parked, isFalse, reason: 'flagged for the applier, not re-queued for push');
      final repaired = await d.applier.repair();
      expect(repaired.applied, 1);
      expect(await d.ledger(), isEmpty);
      final tags = {for (final t in await d.db.select(d.db.tags).get()) t.id: t.name};
      expect(tags, {'t1': 'cacti', 't2': 'cactus'});
      expect(await d.opLog.pendingCount(), 0);
    });
  });

  group('failure classification', () {
    test('constraint / mismatch / logic errors and Dart type errors park; busy, locked, I/O, full, closed rethrow', () {
      expect(isDeterministicApplyFailure(_Fake('SqliteException(2067): UNIQUE constraint failed')), isTrue);
      expect(isDeterministicApplyFailure(_Fake('SqliteException(1299): NOT NULL constraint failed')), isTrue);
      expect(isDeterministicApplyFailure(_Fake('SqliteException(20): datatype mismatch')), isTrue);
      expect(isDeterministicApplyFailure(_Fake('SqliteException(1): no such column')), isTrue);
      expect(isDeterministicApplyFailure(_Fake('SqliteException(1): no such savepoint: s2')), isFalse);
      expect(isDeterministicApplyFailure(_Fake('SqliteException(1): cannot start a transaction within a transaction')), isFalse);
      expect(isDeterministicApplyFailure(_Fake('SqliteException(1): no such table: plants')), isFalse);
      expect(isDeterministicApplyFailure(_Fake('SqliteException(257): some extended ERROR')), isFalse);
      expect(isDeterministicApplyFailure(const FormatException('x')), isTrue);
      expect(isDeterministicApplyFailure(ArgumentError('x')), isTrue);
      expect(isDeterministicApplyFailure(_Fake('SqliteException(5): database is locked')), isFalse);
      expect(isDeterministicApplyFailure(_Fake('SqliteException(517): SQLITE_BUSY_SNAPSHOT')), isFalse);
      expect(isDeterministicApplyFailure(_Fake('SqliteException(6): table is locked')), isFalse);
      expect(isDeterministicApplyFailure(_Fake('SqliteException(10): disk I/O error')), isFalse);
      expect(isDeterministicApplyFailure(_Fake('SqliteException(13): database or disk is full')), isFalse);
      expect(isDeterministicApplyFailure(StateError('database closed')), isFalse);
      expect(isDeterministicApplyFailure(UnsupportedError('no nested transactions')), isFalse);
      expect(isDeterministicApplyFailure(_Fake('OPFS: NoModificationAllowedError')), isFalse);
    });

    test('a transient failure (SQLITE_BUSY) aborts the whole batch: nothing committed, nothing parked', () async {
      final busy = _BusyInterceptor();
      final db = AppDatabase.forTesting(NativeDatabase.memory().interceptWith(busy));
      final clock = HlcClock(deviceId: 'dev-a');
      final opLog = OpLogWriter(db: db, clock: clock, tenantId: 'col-1');
      final applier = SyncApplier(db: db, opLog: opLog, clock: clock, nowMillis: () => 99);
      try {
        await applier.applyBatch([op('plants', 'p1', '*', plantJson('p1', hlc: hlcAt(5000)), hlcAt(5000))]);
        final page = [
          op('plants', 'p2', '*', plantJson('p2', hlc: hlcAt(5500)), hlcAt(5500)),
          op('plants', 'p1', 'notes', 'n', hlcAt(6000)),
        ];
        busy.on = true;
        await expectLater(applier.applyBatch(page), throwsA(isA<_Fake>()));
        busy.on = false;
        expect(await (db.select(db.plants)..where((p) => p.id.equals('p2'))).getSingleOrNull(), isNull);
        expect(await db.select(db.syncRejections).get(), isEmpty);
        expect((await db.select(db.syncOps).get()).map((o) => o.entityId), ['p1']);
        // The retried page applies normally.
        final r = await applier.applyBatch(page);
        expect(r.applied, 2);
      } finally {
        await db.close();
      }
    });
  });
}

class _Fake implements Exception {
  _Fake(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Fails every UPDATE of `plants` with SQLITE_BUSY while [on].
class _BusyInterceptor extends QueryInterceptor {
  bool on = false;
  @override
  Future<int> runUpdate(QueryExecutor executor, String statement, List<Object?> args) {
    if (on && statement.contains('"plants"')) throw _Fake('SqliteException(5): database is locked');
    return super.runUpdate(executor, statement, args);
  }
}
