import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';
import 'package:plantly_inventory/sync/sync_applier.dart';
import 'package:plantly_inventory/sync/sync_rejections.dart';
import 'package:plantly_inventory/sync/sync_transport.dart';

String hlcAt(int ms, {int logical = 0, String dev = 'dev-b'}) => Hlc(ms, logical, dev).encode();

void main() {
  const tenant = 'col-1';
  late AppDatabase db;
  late HlcClock clock;
  late OpLogWriter opLog;
  late SyncApplier applier;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // Local device clock pinned to t=1000 so local ops are predictable.
    var wall = 1000;
    clock = HlcClock(deviceId: 'dev-a', nowProvider: () => DateTime.fromMillisecondsSinceEpoch(wall++, isUtc: true));
    opLog = OpLogWriter(db: db, clock: clock, tenantId: tenant);
    applier = SyncApplier(db: db, opLog: opLog, clock: clock, nowMillis: () => 99);
  });
  tearDown(() => db.close());

  SyncOpDto op(String entity, String id, String field, Object? value, String hlc, {String? device}) =>
      SyncOpDto(entity: entity, entityId: id, field: field, value: value, hlc: hlc, deviceId: device);

  Map<String, dynamic> plantJson(String id, {String nickname = 'Remote', String? notes, String hlc = ''}) => {
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

  Future<PlantRow?> plant(String id) => (db.select(db.plants)..where((p) => p.id.equals(id))).getSingleOrNull();

  /// Creates a plant the way a repository does: op first, then row.
  Future<Hlc> localPlant(String id, {String nickname = 'Local', String? notes}) async {
    final h = await opLog.recordCreate(entity: 'plants', entityId: id, value: {'id': id, 'nickname': nickname, 'status': 'active', 'notes': notes});
    await db.into(db.plants).insert(PlantsCompanion.insert(
        id: id, tenantId: tenant, nickname: nickname, status: 'active', notes: Value(notes), updatedHlc: h.encode(), deviceId: 'dev-a'));
    return h;
  }

  Future<Hlc> localField(String id, String field, Object? value) async {
    final h = await opLog.recordFieldUpdate(entity: 'plants', entityId: id, field: field, value: value);
    await (db.update(db.plants)..where((p) => p.id.equals(id))).write(PlantsCompanion(
      notes: field == 'notes' ? Value(value as String?) : const Value.absent(),
      nickname: field == 'nickname' ? Value(value as String) : const Value.absent(),
      updatedHlc: Value(h.encode()),
    ));
    return h;
  }

  test('whole-row op for an unknown row inserts it with decoded columns and the collection tenant', () async {
    final r = await applier.applyBatch([op('plants', 'p1', '*', plantJson('p1', notes: 'n', hlc: hlcAt(5000)), hlcAt(5000))]);
    expect(r.applied, 1);
    final row = (await plant('p1'))!;
    expect(row.tenantId, tenant);
    expect(row.nickname, 'Remote');
    expect(row.notes, 'n');
    expect(row.acquiredAt, 1700000000000);
    expect(row.notificationsMuted, isFalse);
    expect(row.updatedHlc, hlcAt(5000));
    expect(row.deviceId, 'dev-b');
  });

  test('remote ops are recorded as already-pushed and never enter the pending queue or fire changes', () async {
    var changes = 0;
    final sub = opLog.changes.listen((_) => changes++);
    await applier.applyBatch([op('plants', 'p1', '*', plantJson('p1'), hlcAt(5000))]);
    await Future<void>.delayed(Duration.zero);
    final rows = await db.select(db.syncOps).get();
    expect(rows, hasLength(1));
    expect(rows.single.pushedAt, 99);
    expect(rows.single.deviceId, 'dev-b');
    expect(await opLog.pendingCount(), 0);
    expect(changes, 0);
    await sub.cancel();
  });

  test('re-applying the same op is a no-op (idempotent)', () async {
    final o = op('plants', 'p1', '*', plantJson('p1'), hlcAt(5000));
    await applier.applyBatch([o]);
    final r = await applier.applyBatch([o, o]);
    expect(r.applied, 0);
    expect(r.skipped, 2);
    expect(await db.select(db.syncOps).get(), hasLength(1));
  });

  test('field op newer than the local field wins; older loses; tie breaks on device id', () async {
    // Local write at wall 1000 (dev-a).
    await localPlant('p1', notes: 'local');
    final localHlc = Hlc.parse((await plant('p1'))!.updatedHlc);

    // Older remote op → ignored.
    await applier.applyBatch([op('plants', 'p1', 'notes', 'older', hlcAt(500))]);
    expect((await plant('p1'))!.notes, 'local');

    // Same instant, device 'dev-b' > 'dev-a' → remote wins the tie.
    final tie = Hlc(localHlc.physicalMs, localHlc.logical, 'dev-b').encode();
    await applier.applyBatch([op('plants', 'p1', 'notes', 'tie-b', tie)]);
    expect((await plant('p1'))!.notes, 'tie-b');

    // Same instant, device 'dev-0' < 'dev-a' → local wins the tie.
    await localField('p1', 'notes', 'local2');
    final local2 = Hlc.parse((await plant('p1'))!.updatedHlc);
    final tieLow = Hlc(local2.physicalMs, local2.logical, 'dev-0').encode();
    final r = await applier.applyBatch([op('plants', 'p1', 'notes', 'tie-0', tieLow)]);
    expect(r.applied, 0);
    expect((await plant('p1'))!.notes, 'local2');

    // Newer remote → wins and bumps updated_hlc / device_id.
    await applier.applyBatch([op('plants', 'p1', 'notes', 'newer', hlcAt(9000))]);
    final row = (await plant('p1'))!;
    expect(row.notes, 'newer');
    expect(row.updatedHlc, hlcAt(9000));
    expect(row.deviceId, 'dev-b');
  });

  test('whole-row op is compared field by field: a newer local field op survives, the rest is overwritten', () async {
    await localPlant('p1', nickname: 'Local', notes: 'local-notes'); // t≈1000
    await localField('p1', 'notes', 'edited-later'); // t≈1001

    // Remote `*` stamped between the create and the notes edit.
    final createHlc = Hlc.parse((await db.select(db.syncOps).get()).first.hlc);
    final between = Hlc(createHlc.physicalMs, createHlc.logical + 1, 'dev-b');
    // Ensure it is newer than the create but older than the notes edit.
    final notesHlc = Hlc.parse((await plant('p1'))!.updatedHlc);
    expect(between > createHlc && between < notesHlc, isTrue);

    await applier.applyBatch([op('plants', 'p1', '*', plantJson('p1', nickname: 'RemoteName', notes: 'remote-notes'), between.encode())]);
    final row = (await plant('p1'))!;
    expect(row.nickname, 'RemoteName');
    expect(row.notes, 'edited-later');
    expect(row.potSizeCm, 10);
  });

  test('tombstone sets deleted_at; later field and whole-row ops cannot resurrect', () async {
    await localPlant('p1');
    await applier.applyBatch([op('plants', 'p1', '__tombstone__', null, hlcAt(5000))]);
    expect((await plant('p1'))!.deletedAt, 5000);

    final r = await applier.applyBatch([
      op('plants', 'p1', 'notes', 'zombie', hlcAt(9000)),
      op('plants', 'p1', '*', plantJson('p1', nickname: 'Zombie'), hlcAt(9001)),
    ]);
    expect(r.applied, 0);
    final row = (await plant('p1'))!;
    expect(row.deletedAt, 5000);
    expect(row.notes, isNull);
    expect(row.nickname, 'Local');
  });

  test('remote tombstone for a row we never had blocks its later whole-row op', () async {
    await applier.applyBatch([op('plants', 'ghost', '__tombstone__', null, hlcAt(5000))]);
    await applier.applyBatch([op('plants', 'ghost', '*', plantJson('ghost'), hlcAt(4000))]);
    expect(await plant('ghost'), isNull);
  });

  test('field op arriving before the row is kept and wins over the later `*` payload', () async {
    await applier.applyBatch([op('plants', 'p1', 'notes', 'newest-notes', hlcAt(7000))]);
    expect(await plant('p1'), isNull);
    await applier.applyBatch([op('plants', 'p1', '*', plantJson('p1', notes: 'stale-notes', hlc: hlcAt(6000)), hlcAt(6000))]);
    final row = (await plant('p1'))!;
    expect(row.notes, 'newest-notes');
    expect(row.nickname, 'Remote');
    expect(row.updatedHlc, hlcAt(7000));
  });

  test('older field op arriving after the `*` does not override it', () async {
    await applier.applyBatch([op('plants', 'p1', '*', plantJson('p1', notes: 'fresh'), hlcAt(6000))]);
    final r = await applier.applyBatch([op('plants', 'p1', 'notes', 'old', hlcAt(5000))]);
    expect(r.applied, 0);
    expect((await plant('p1'))!.notes, 'fresh');
  });

  group('OR-Set join tables', () {
    Future<List<PlantPhotoRow>> rows() => db.select(db.plantPhotos).get();

    test('add via `*`, remove via removed_hlc field op (null value = op hlc)', () async {
      await applier.applyBatch([
        op('plant_photos', 'pp1', '*', {
          'id': 'pp1', 'plant_id': 'p1', 'photo_sha': 'sha1', 'caption': null, 'captured_at': null,
          'display_order': 0, 'added_hlc': hlcAt(5000), 'removed_hlc': null, 'device_id': 'dev-b',
        }, hlcAt(5000)),
      ]);
      var r = await rows();
      expect(r.single.addedHlc, hlcAt(5000));
      expect(r.single.removedHlc, isNull);

      await applier.applyBatch([op('plant_photos', 'pp1', 'removed_hlc', null, hlcAt(6000))]);
      r = await rows();
      expect(r.single.removedHlc, hlcAt(6000));

      // Removed rows are final: a later caption edit is ignored.
      final res = await applier.applyBatch([op('plant_photos', 'pp1', 'caption', 'late', hlcAt(7000))]);
      expect(res.applied, 0);
      expect((await rows()).single.caption, isNull);
    });

    test('explicit removed_hlc value is honoured', () async {
      await db.into(db.plantPhotos).insert(PlantPhotosCompanion.insert(
          id: 'pp1', tenantId: tenant, plantId: 'p1', photoSha: 'sha1', addedHlc: hlcAt(100, dev: 'dev-a'), deviceId: 'dev-a'));
      await applier.applyBatch([op('plant_photos', 'pp1', 'removed_hlc', hlcAt(5500), hlcAt(5600))]);
      expect((await rows()).single.removedHlc, hlcAt(5500));
    });

    test('legacy `<plant>/<sha>` removed_hlc op stamps every live add-row of the pair', () async {
      await db.into(db.plantPhotos).insert(PlantPhotosCompanion.insert(
          id: 'pp1', tenantId: tenant, plantId: 'p1', photoSha: 'sha1', addedHlc: hlcAt(100, dev: 'dev-a'), deviceId: 'dev-a'));
      await db.into(db.plantPhotos).insert(PlantPhotosCompanion.insert(
          id: 'pp2', tenantId: tenant, plantId: 'p1', photoSha: 'sha1', addedHlc: hlcAt(200, dev: 'dev-c'), deviceId: 'dev-c'));
      await db.into(db.plantPhotos).insert(PlantPhotosCompanion.insert(
          id: 'pp3', tenantId: tenant, plantId: 'p1', photoSha: 'other', addedHlc: hlcAt(300, dev: 'dev-a'), deviceId: 'dev-a'));
      final r = await applier.applyBatch([op('plant_photos', 'p1/sha1', 'removed_hlc', null, hlcAt(5000))]);
      expect(r.applied, 1);
      final all = {for (final x in await rows()) x.id: x.removedHlc};
      expect(all['pp1'], hlcAt(5000));
      expect(all['pp2'], hlcAt(5000));
      expect(all['pp3'], isNull);
    });

    test('plant_tags tombstone sets removed_hlc', () async {
      await db.into(db.plantTags).insert(PlantTagsCompanion.insert(
          id: 'pt1', tenantId: tenant, plantId: 'p1', tagId: 't1', addedHlc: hlcAt(100, dev: 'dev-a'), deviceId: 'dev-a'));
      await applier.applyBatch([op('plant_tags', 'pt1', '__tombstone__', null, hlcAt(5000))]);
      expect((await db.select(db.plantTags).get()).single.removedHlc, hlcAt(5000));
    });
  });

  test('remote photos row lands with remote_state=remote and no local_path; a local row keeps its state', () async {
    await applier.applyBatch([
      op('photos', 'sha-remote', '*', {
        'sha256': 'sha-remote', 'width': 10, 'height': 20, 'mime': 'image/jpeg', 'bytes': 3,
        'taken_at': null, 'exif_json': null, 'updated_hlc': hlcAt(5000), 'deleted_at': null, 'device_id': 'dev-b',
        'local_path': '/other/device/path', 'remote_state': 'synced',
      }, hlcAt(5000)),
    ]);
    final remote = await (db.select(db.photos)..where((p) => p.sha256.equals('sha-remote'))).getSingle();
    expect(remote.remoteState, 'remote');
    expect(remote.localPath, isNull);
    expect(remote.width, 10);

    await opLog.recordCreate(entity: 'photos', entityId: 'sha-local', value: {'sha256': 'sha-local', 'mime': 'image/jpeg', 'bytes': 1});
    await db.into(db.photos).insert(PhotosCompanion.insert(
        sha256: 'sha-local', tenantId: tenant, mime: 'image/jpeg', bytes: 1, updatedHlc: hlcAt(100, dev: 'dev-a'), deviceId: 'dev-a',
        localPath: const Value('/mine'), remoteState: const Value('local')));
    // The clock absorbed 5000 above, so the local create is stamped after it;
    // a remote op at 6000 is the causally-later write here.
    await applier.applyBatch([
      op('photos', 'sha-local', '*', {'sha256': 'sha-local', 'mime': 'image/jpeg', 'bytes': 1, 'width': 77, 'remote_state': 'synced', 'local_path': '/x'}, hlcAt(6000)),
    ]);
    final local = await (db.select(db.photos)..where((p) => p.sha256.equals('sha-local'))).getSingle();
    expect(local.width, 77);
    expect(local.remoteState, 'local');
    expect(local.localPath, '/mine');
  });

  test('care_schedules unique (plant,type) conflict: the newer row survives, the loser gets a local tombstone op', () async {
    final h = await opLog.recordCreate(entity: 'care_schedules', entityId: 'cs-local', value: {'plant_id': 'p1', 'type': 'water', 'base_interval_days': 7, 'current_interval_days': 7});
    await db.into(db.careSchedules).insert(CareSchedulesCompanion.insert(
        id: 'cs-local', tenantId: tenant, plantId: 'p1', type: 'water', baseIntervalDays: 7, currentIntervalDays: 7, updatedHlc: h.encode(), deviceId: 'dev-a'));
    final pendingBefore = await opLog.pendingCount();

    // Incoming is newer → local row tombstoned, remote inserted.
    await applier.applyBatch([
      op('care_schedules', 'cs-remote', '*', {
        'id': 'cs-remote', 'plant_id': 'p1', 'type': 'water', 'base_interval_days': 3, 'current_interval_days': 3,
        'enabled': true, 'recurrence_mode': 'fixed', 'updated_hlc': hlcAt(5000), 'device_id': 'dev-b',
      }, hlcAt(5000)),
    ]);
    final rows = {for (final r in await db.select(db.careSchedules).get()) r.id: r};
    expect(rows['cs-remote']!.deletedAt, isNull);
    expect(rows['cs-remote']!.baseIntervalDays, 3);
    // UNIQUE(tenant, plant, type) is not partial: the local loser row is
    // dropped physically; its tombstone op is what other devices need.
    expect(rows.containsKey('cs-local'), isFalse);
    expect(await opLog.pendingCount(), pendingBefore + 1);
    final tomb = (await db.select(db.syncOps).get()).where((o) => o.field == '__tombstone__').single;
    expect(tomb.entityId, 'cs-local');
    expect(tomb.pushedAt, isNull);

    // Incoming older than the survivor → dropped, tombstoned locally.
    final r2 = await applier.applyBatch([
      op('care_schedules', 'cs-old', '*', {'id': 'cs-old', 'plant_id': 'p1', 'type': 'water', 'base_interval_days': 1, 'current_interval_days': 1}, hlcAt(4000)),
    ]);
    expect(r2.applied, 0);
    expect((await db.select(db.careSchedules).get()).map((r) => r.id), isNot(contains('cs-old')));
    expect((await db.select(db.syncOps).get()).where((o) => o.field == '__tombstone__' && o.entityId == 'cs-old'), hasLength(1));
  });

  test('tags unique(name) conflict: loser plant_tags are re-pointed at the survivor, no dangling tag_id', () async {
    // Device A (us) created "succulent" and tagged p1 + p2 with it.
    final ht = await opLog.recordCreate(entity: 'tags', entityId: 't-local', value: {'name': 'succulent'});
    await db.into(db.tags).insert(TagsCompanion.insert(id: 't-local', tenantId: tenant, name: 'succulent', updatedHlc: ht.encode(), deviceId: 'dev-a'));
    for (final (rowId, plantId) in [('pt-1', 'p1'), ('pt-2', 'p2')]) {
      final h = await opLog.recordCreate(entity: 'plant_tags', entityId: rowId, value: {'plant_id': plantId, 'tag_id': 't-local'});
      await db.into(db.plantTags).insert(PlantTagsCompanion.insert(id: rowId, tenantId: tenant, plantId: plantId, tagId: 't-local', addedHlc: h.encode(), deviceId: 'dev-a'));
    }
    // Device B created "succulent" later and already tagged p2 with ITS id.
    await applier.applyBatch([
      op('plant_tags', 'pt-remote', '*', {'id': 'pt-remote', 'plant_id': 'p2', 'tag_id': 't-remote', 'added_hlc': hlcAt(5001), 'device_id': 'dev-b'}, hlcAt(5001)),
      op('tags', 't-remote', '*', {'id': 't-remote', 'name': 'succulent', 'color': '#0f0', 'updated_hlc': hlcAt(5000), 'device_id': 'dev-b'}, hlcAt(5000)),
    ]);

    final tags = {for (final t in await db.select(db.tags).get()) t.id: t};
    expect(tags.keys, ['t-remote']);
    final live = (await db.select(db.plantTags).get()).where((r) => r.removedHlc == null).toList();
    expect(live.map((r) => r.tagId).toSet(), {'t-remote'}, reason: 'no live row may point at the deleted tag');
    expect(live.map((r) => (r.plantId, r.id)).toSet(), {('p1', 'pt-1'), ('p2', 'pt-remote')});
    final detached = (await db.select(db.plantTags).get()).firstWhere((r) => r.id == 'pt-2');
    expect(detached.removedHlc, isNotNull, reason: 'p2 already had the survivor → loser row detached');

    // The re-point + detach + tombstone all travel as local pending ops.
    final pending = (await db.select(db.syncOps).get()).where((o) => o.pushedAt == null && o.deviceId == 'dev-a');
    expect(pending.map((o) => (o.entity, o.entityId, o.field)), containsAll([
      ('plant_tags', 'pt-1', 'tag_id'),
      ('plant_tags', 'pt-2', 'removed_hlc'),
      ('tags', 't-local', '__tombstone__'),
    ]));
    final repoint = pending.firstWhere((o) => o.entityId == 'pt-1' && o.field == 'tag_id');
    expect(json.decode(repoint.valueJson!), 't-remote');
  });

  test('tags conflict where the incoming tag loses: its already-arrived plant_tags move to the local survivor', () async {
    await applier.applyBatch([
      op('plant_tags', 'pt-remote', '*', {'id': 'pt-remote', 'plant_id': 'p1', 'tag_id': 't-remote', 'added_hlc': hlcAt(400), 'device_id': 'dev-b'}, hlcAt(400)),
    ]);
    final ht = await opLog.recordCreate(entity: 'tags', entityId: 't-local', value: {'name': 'cactus'});
    await db.into(db.tags).insert(TagsCompanion.insert(id: 't-local', tenantId: tenant, name: 'cactus', updatedHlc: ht.encode(), deviceId: 'dev-a'));
    final r = await applier.applyBatch([
      op('tags', 't-remote', '*', {'id': 't-remote', 'name': 'cactus', 'updated_hlc': hlcAt(300), 'device_id': 'dev-b'}, hlcAt(300)),
    ]);
    expect(r.applied, 0);
    expect((await db.select(db.tags).get()).map((t) => t.id), ['t-local']);
    final row = (await db.select(db.plantTags).get()).single;
    expect(row.tagId, 't-local');
    expect(row.removedHlc, isNull);
  });

  test('unknown entity and malformed hlc are skipped without throwing; ops of a batch share one transaction', () async {
    final r = await applier.applyBatch([
      op('unicorns', 'u1', '*', {'id': 'u1'}, hlcAt(1)),
      op('plants', 'p1', '*', plantJson('p1'), 'garbage'),
      op('plants', 'p2', '*', plantJson('p2'), hlcAt(2)),
    ]);
    expect(r.applied, 1);
    expect(r.skipped, 2);
    expect(await plant('p2'), isNotNull);
  });

  test('the local clock absorbs remote HLCs (within the drift window)', () async {
    final ahead = 1000 + const Duration(hours: 1).inMilliseconds;
    await applier.applyBatch([op('plants', 'p1', '*', plantJson('p1'), hlcAt(ahead))]);
    expect(clock.now() > Hlc.parse(hlcAt(ahead)), isTrue);
  });

  test('a remote HLC far in the future is applied but does not move the local clock', () async {
    await applier.applyBatch([op('plants', 'p1', '*', plantJson('p1'), hlcAt(999999999))]);
    expect(await plant('p1'), isNotNull);
    expect(clock.ignoredRemoteCount, 1);
    expect(clock.now().physicalMs, lessThan(10000));
  });

  test('applied `*` payload survives a JSON round trip (as it would over the wire)', () async {
    final wire = json.decode(json.encode(plantJson('p1', notes: 'n'))) as Map<String, dynamic>;
    await applier.applyBatch([op('plants', 'p1', '*', wire, hlcAt(5000))]);
    expect((await plant('p1'))!.notes, 'n');
  });

  group('id collision across tenants (QA2 BUG-2)', () {
    Future<PlantRow> otherTenantPlant(String id) async {
      await db.into(db.plants).insert(PlantsCompanion.insert(
          id: id, tenantId: 'other', nickname: 'Mine', status: 'active', updatedHlc: hlcAt(100, dev: 'dev-a'), deviceId: 'dev-a'));
      return (await plant(id))!;
    }

    test("whole-row op whose id exists under another tenant → skipped, other tenant's row untouched, ledger row id_collision parked", () async {
      await otherTenantPlant('p1');
      final remote = op('plants', 'p1', '*', plantJson('p1', nickname: 'Theirs', hlc: hlcAt(5000)), hlcAt(5000));

      final r = await applier.applyBatch([remote]);
      expect(r.applied, 0);
      expect(r.skipped, 1);
      expect(r.idCollisions, hasLength(1));
      expect(r.idCollisions.single.entity, 'plants');
      expect(r.idCollisions.single.entityId, 'p1');
      expect(r.idCollisions.single.heldByTenant, 'other');

      // The other tenant's row is exactly as it was; nothing was inserted.
      final rows = await db.select(db.plants).get();
      expect(rows, hasLength(1));
      expect(rows.single.tenantId, 'other');
      expect(rows.single.nickname, 'Mine');
      expect(rows.single.updatedHlc, hlcAt(100, dev: 'dev-a'));

      // The remote op is persisted as already-pushed under the applier tenant …
      final stored = (await db.select(db.syncOps).get()).single;
      expect(stored.tenantId, tenant);
      expect(stored.pushedAt, 99);
      expect(stored.deviceId, 'dev-b');
      expect(r.idCollisions.single.opSeq, stored.seq);

      // … and parked in the ledger against that seq.
      final ledger = (await db.select(db.syncRejections).get()).single;
      expect(ledger.opSeq, stored.seq);
      expect(ledger.tenantId, tenant);
      expect(ledger.reason, kIdCollisionReason);
      expect(ledger.reason, 'id_collision');
      expect(ledger.parked, isTrue);
      expect(ledger.entity, 'plants');
      expect(ledger.entityId, 'p1');
      expect(ledger.field, '*');
      expect(ledger.hlc, hlcAt(5000));
      expect(ledger.at, 99);

      // "Retry all" must not re-queue a remote op: nothing un-parked, ledger cleared.
      final store = SyncRejectionStore(db: db, tenantId: tenant);
      expect(await store.retryAll(), 0);
      expect((await db.select(db.syncOps).get()).single.pushedAt, 99);
      expect(await db.select(db.syncRejections).get(), isEmpty);

      // Re-delivery of the same op is the usual idempotent skip — no second ledger row.
      final again = await applier.applyBatch([remote]);
      expect(again.applied, 0);
      expect(again.skipped, 1);
      expect(again.idCollisions, isEmpty);
      expect(await db.select(db.syncRejections).get(), isEmpty);
      expect(await db.select(db.syncOps).get(), hasLength(1));
    });

    test('retryAll re-queues server-rejected local ops but only forgets id_collision rows', () async {
      await otherTenantPlant('p1');
      await applier.applyBatch([op('plants', 'p1', '*', plantJson('p1', hlc: hlcAt(5000)), hlcAt(5000))]);
      final remoteSeq = (await db.select(db.syncOps).get()).single.seq;

      // A local op the server refused (parked by the store the usual way).
      await localPlant('p2');
      final local = await (db.select(db.syncOps)..where((o) => o.entityId.equals('p2'))).getSingle();
      await (db.update(db.syncOps)..where((o) => o.seq.equals(local.seq))).write(const SyncOpsCompanion(pushedAt: Value(7)));
      await db.into(db.syncRejections).insert(SyncRejectionsCompanion.insert(
          opSeq: Value(local.seq), tenantId: tenant, entity: 'plants', entityId: 'p2', field: '*',
          reason: 'bad_value', hlc: local.hlc, at: 7, parked: const Value(true)));

      final store = SyncRejectionStore(db: db, tenantId: tenant);
      expect((await store.summary()).total, 2);
      expect(await store.retryAll(), 1);
      expect((await (db.select(db.syncOps)..where((o) => o.seq.equals(local.seq))).getSingle()).pushedAt, isNull, reason: 're-queued');
      expect((await (db.select(db.syncOps)..where((o) => o.seq.equals(remoteSeq))).getSingle()).pushedAt, 99, reason: 'remote op stays parked');
      expect(await db.select(db.syncRejections).get(), isEmpty);
    });

    test('same id under the SAME tenant is not a collision (normal LWW merge path)', () async {
      await localPlant('p1', nickname: 'Local');
      final r = await applier.applyBatch([op('plants', 'p1', '*', plantJson('p1', nickname: 'Remote', hlc: hlcAt(5000)), hlcAt(5000))]);
      expect(r.applied, 1);
      expect(r.idCollisions, isEmpty);
      expect(await db.select(db.syncRejections).get(), isEmpty);
      expect((await plant('p1'))!.nickname, 'Remote');
    });
  });

  group('shared collections (§3): who did what', () {
    Map<String, dynamic> careJson(String id, {String hlc = ''}) => {
          'id': id,
          'plant_id': 'p1',
          'type': 'water',
          'done_at': '2026-09-27T08:00:00.000Z',
          'notes': null,
          'dose': null,
          'product': null,
          'photo_sha': null,
          'updated_hlc': hlc,
          'deleted_at': null,
          'device_id': 'dev-b',
        };

    Future<CareEventRow?> event(String id) =>
        (db.select(db.careEvents)..where((e) => e.id.equals(id))).getSingleOrNull();

    test('pulled care_events `*` op with user_id → actor_user_id on the row; without → null', () async {
      await localPlant('p1');
      final withUser = SyncOpDto.fromJson({
        'entity': 'care_events', 'entity_id': 'e1', 'field': '*', 'value': careJson('e1', hlc: hlcAt(5000)),
        'hlc': hlcAt(5000), 'device_id': 'dev-b', 'seq': 1, 'user_id': 'u-bob',
      });
      final withoutUser = op('care_events', 'e2', '*', careJson('e2', hlc: hlcAt(5001)), hlcAt(5001), device: 'dev-b');
      final r = await applier.applyBatch([withUser, withoutUser]);
      expect(r.applied, 2);
      expect((await event('e1'))!.actorUserId, 'u-bob');
      expect((await event('e2'))!.actorUserId, isNull);
      // Empty user_id is treated as absent.
      expect(SyncOpDto.fromJson({'entity': 'x', 'entity_id': 'y', 'field': '*', 'value': null, 'hlc': 'h', 'user_id': ''}).userId, isNull);
    });

    test('a later `*` for a row we already hold fills in a missing actor, never overwrites one', () async {
      await localPlant('p1');
      await applier.applyBatch([op('care_events', 'e1', '*', careJson('e1', hlc: hlcAt(5000)), hlcAt(5000), device: 'dev-b')]);
      expect((await event('e1'))!.actorUserId, isNull);
      await applier.applyBatch([
        SyncOpDto(entity: 'care_events', entityId: 'e1', field: '*', value: careJson('e1', hlc: hlcAt(6000)), hlc: hlcAt(6000), deviceId: 'dev-b', userId: 'u-bob'),
      ]);
      expect((await event('e1'))!.actorUserId, 'u-bob');
      await applier.applyBatch([
        SyncOpDto(entity: 'care_events', entityId: 'e1', field: '*', value: careJson('e1', hlc: hlcAt(7000)), hlc: hlcAt(7000), deviceId: 'dev-c', userId: 'u-carol'),
      ]);
      expect((await event('e1'))!.actorUserId, 'u-bob', reason: 'attribution is first-writer, device-local');
    });

    test('actor_user_id never travels: not in canonical `*` payloads, ignored on inbound rows, absent from toJson', () async {
      final codec = opLog.codecs.forEntity('care_events')!;
      expect(codec.wireColumnNames, isNot(contains('actor_user_id')));
      expect(codec.wireColumnNames, isNot(contains('tenant_id')));
      final h = await opLog.recordCreate(entity: 'care_events', entityId: 'e9', value: {
        'id': 'e9', 'plant_id': 'p1', 'type': 'water', 'done_at': 1000, 'actor_user_id': 'u-me',
      });
      final row = await (db.select(db.syncOps)..where((o) => o.entityId.equals('e9'))).getSingle();
      final payload = json.decode(row.valueJson!) as Map<String, dynamic>;
      expect(payload.containsKey('actor_user_id'), isFalse);
      expect(payload['updated_hlc'], h.encode());
      // An inbound payload smuggling the column is ignored; only op.user_id counts.
      await localPlant('p1');
      await applier.applyBatch([
        op('care_events', 'e3', '*', {...careJson('e3', hlc: hlcAt(5000)), 'actor_user_id': 'u-smuggled'}, hlcAt(5000), device: 'dev-b'),
      ]);
      expect((await event('e3'))!.actorUserId, isNull);
      expect(SyncOpDto(entity: 'a', entityId: 'b', field: '*', value: null, hlc: 'h', userId: 'u').toJson().containsKey('user_id'), isFalse);
    });
  });
}
