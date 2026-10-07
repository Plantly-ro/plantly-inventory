import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/repositories/photo_repository.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';
import 'package:plantly_inventory/sync/sync_applier.dart';
import 'package:plantly_inventory/sync/sync_transport.dart';

/// One simulated device: its own database, clock, op log and applier.
/// [wall] drives the clock so tests can order HLCs across devices.
class _Device {
  _Device(this.id, {required int startMs}) : wall = startMs {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = HlcClock(deviceId: id, nowProvider: () => DateTime.fromMillisecondsSinceEpoch(wall++, isUtc: true));
    opLog = OpLogWriter(db: db, clock: clock, tenantId: 'col-1');
    applier = SyncApplier(db: db, opLog: opLog, clock: clock, nowMillis: () => wall);
    plantPhotos = PlantPhotoRepository(db: db, opLog: opLog);
    locationPhotos = LocationPhotoRepository(db: db, opLog: opLog);
  }

  final String id;
  int wall;
  late final AppDatabase db;
  late final HlcClock clock;
  late final OpLogWriter opLog;
  late final SyncApplier applier;
  late final PlantPhotoRepository plantPhotos;
  late final LocationPhotoRepository locationPhotos;

  /// Local ops not yet "pushed"; marks them pushed (the server's ack).
  Future<List<SyncOpDto>> push() async {
    final rows = await (db.select(db.syncOps)
          ..where((o) => o.pushedAt.isNull())
          ..orderBy([(o) => OrderingTerm(expression: o.seq)]))
        .get();
    await (db.update(db.syncOps)..where((o) => o.pushedAt.isNull())).write(SyncOpsCompanion(pushedAt: Value(wall)));
    return [for (final r in rows) SyncOpDto.fromRow(r)];
  }

  Future<List<PlantPhotoRow>> rows() =>
      (db.select(db.plantPhotos)..orderBy([(r) => OrderingTerm(expression: r.id)])).get();

  Future<void> close() => db.close();
}

void main() {
  late _Device a;
  late _Device b;

  setUp(() {
    a = _Device('dev-a', startMs: 1000);
    b = _Device('dev-b', startMs: 1000);
  });
  tearDown(() async {
    await a.close();
    await b.close();
  });

  /// Push [from]'s pending ops and apply them on [to].
  Future<void> sync(_Device from, _Device to) async => to.applier.applyBatch(await from.push());

  test('caption / captured_at / reorder edits never rewrite added_hlc (local or remote)', () async {
    await a.plantPhotos.attach('p1', 'sha-1');
    await a.plantPhotos.attach('p1', 'sha-2');
    await sync(a, b);
    final before = {for (final r in await a.rows()) r.id: r.addedHlc};

    final first = (await a.rows()).firstWhere((r) => r.photoSha == 'sha-1');
    await a.plantPhotos.setCaption(first.id, 'yellow leaf');
    await a.plantPhotos.setCapturedAt(first.id, 1700000000000);
    await sync(a, b);

    for (final d in [a, b]) {
      final rows = await d.rows();
      expect({for (final r in rows) r.id: r.addedHlc}, before, reason: '${d.id} added_hlc');
      expect(rows.firstWhere((r) => r.id == first.id).caption, 'yellow leaf', reason: d.id);
      // Gallery order (display_order, then added_hlc) is untouched by the edit.
      expect(await d.plantPhotos.currentAttached('p1'), ['sha-1', 'sha-2'], reason: '${d.id} order');
    }

    final rows = await a.plantPhotos.watchAttachedRows('p1').first;
    await a.plantPhotos.reorder(rows.reversed.toList());
    await sync(a, b);
    for (final d in [a, b]) {
      expect({for (final r in await d.rows()) r.id: r.addedHlc}, before, reason: '${d.id} after reorder');
      expect(await d.plantPhotos.currentAttached('p1'), ['sha-2', 'sha-1'], reason: '${d.id} reordered');
    }
  });

  test('location photo caption / captured_at edits never rewrite added_hlc', () async {
    await a.locationPhotos.attach('loc-1', 'sha-1');
    await sync(a, b);
    final before = (await a.db.select(a.db.locationPhotos).getSingle()).addedHlc;
    final id = (await a.db.select(a.db.locationPhotos).getSingle()).id;
    await a.locationPhotos.setCaption(id, 'window');
    await a.locationPhotos.setCapturedAt(id, 1700000000000);
    await sync(a, b);
    for (final d in [a, b]) {
      final row = await d.db.select(d.db.locationPhotos).getSingle();
      expect(row.addedHlc, before, reason: d.id);
      expect(row.caption, 'window', reason: d.id);
      expect(row.capturedAt, 1700000000000, reason: d.id);
    }
  });

  test('A edits the caption of a photo B detached concurrently: both converge on detached', () async {
    await a.plantPhotos.attach('p1', 'sha-1');
    await sync(a, b);
    b.wall = 5000;
    await b.plantPhotos.detach('p1', 'sha-1'); // tomb t≈5000
    a.wall = 9000;
    final row = (await a.rows()).single;
    await a.plantPhotos.setCaption(row.id, 'late edit'); // t≈9000 > tomb, A has not pulled
    await sync(b, a);
    await sync(a, b);
    expect(await a.plantPhotos.currentAttached('p1'), isEmpty);
    expect(await b.plantPhotos.currentAttached('p1'), isEmpty);
  });

  test('a caption edit does not resurrect an add that a concurrent detach outranks', () async {
    // A attaches sha-1; B sees it. B's clock runs ahead.
    await a.plantPhotos.attach('p1', 'sha-1'); // R1 @ ~1000
    await sync(a, b);
    // A attaches the same photo again (second add-row R2 @ ~2000) without
    // having pulled; B, unaware of R2, detaches the pair @ ~5000.
    a.wall = 2000;
    await a.plantPhotos.attach('p1', 'sha-1');
    b.wall = 5000;
    await b.plantPhotos.detach('p1', 'sha-1');
    // Still before pulling, A captions R2 @ ~9000.
    a.wall = 9000;
    final r2 = (await a.rows()).firstWhere((r) => r.removedHlc == null && Hlc.parse(r.addedHlc).physicalMs >= 2000);
    await a.plantPhotos.setCaption(r2.id, 'still here?');
    await sync(b, a);
    await sync(a, b);
    // Presence = max live add (R2 @ 2000) > max remove (5000)? No → absent,
    // and the caption edit must not change that.
    expect(await a.plantPhotos.currentAttached('p1'), isEmpty);
    expect(await b.plantPhotos.currentAttached('p1'), isEmpty);
  });

  group('applier: OR-set field ops', () {
    String h(int ms, [String dev = 'dev-b']) => Hlc(ms, 0, dev).encode();
    Map<String, dynamic> star(String id, int ms) => {
          'id': id, 'plant_id': 'p1', 'photo_sha': 'sha1', 'caption': null, 'captured_at': null,
          'display_order': 0, 'added_hlc': h(ms), 'removed_hlc': null, 'device_id': 'dev-b',
        };
    SyncOpDto op(String id, String field, Object? value, int ms) =>
        SyncOpDto(entity: 'plant_photos', entityId: id, field: field, value: value, hlc: h(ms), deviceId: 'dev-b');

    test('metadata field ops update the column but keep added_hlc', () async {
      await a.applier.applyBatch([op('pp1', '*', star('pp1', 5000), 5000)]);
      await a.applier.applyBatch([
        op('pp1', 'caption', 'c', 6000),
        op('pp1', 'display_order', 3, 6100),
        op('pp1', 'captured_at', '2023-11-14T22:13:20.000Z', 6200),
      ]);
      final row = (await a.rows()).single;
      expect(row.caption, 'c');
      expect(row.displayOrder, 3);
      expect(row.capturedAt, 1700000000000);
      expect(row.addedHlc, h(5000));
    });

    test('metadata field ops that arrive before the `*` do not raise added_hlc on insert', () async {
      await a.applier.applyBatch([op('pp1', 'caption', 'early', 7000)]);
      await a.applier.applyBatch([op('pp1', '*', star('pp1', 5000), 5000)]);
      final row = (await a.rows()).single;
      expect(row.caption, 'early');
      expect(row.addedHlc, h(5000));
    });

    test('a removed_hlc op (null value) that arrives before the `*` lands as removed on insert', () async {
      await a.applier.applyBatch([op('pp1', 'removed_hlc', null, 6000)]);
      await a.applier.applyBatch([op('pp1', '*', star('pp1', 5000), 5000)]);
      final row = (await a.rows()).single;
      expect(row.removedHlc, h(6000));
      expect(row.addedHlc, h(5000));
      expect(await a.plantPhotos.currentAttached('p1'), isEmpty);
    });

    test('a membership field op (re-pointed tag) still re-stamps added_hlc', () async {
      await a.applier.applyBatch([
        SyncOpDto(entity: 'plant_tags', entityId: 'pt1', field: '*', value: {
          'id': 'pt1', 'plant_id': 'p1', 'tag_id': 't-old', 'added_hlc': h(5000), 'removed_hlc': null, 'device_id': 'dev-b',
        }, hlc: h(5000), deviceId: 'dev-b'),
      ]);
      await a.applier.applyBatch([
        SyncOpDto(entity: 'plant_tags', entityId: 'pt1', field: 'tag_id', value: 't-new', hlc: h(6000), deviceId: 'dev-b'),
      ]);
      final row = await a.db.select(a.db.plantTags).getSingle();
      expect(row.tagId, 't-new');
      expect(row.addedHlc, h(6000));
    });
  });
}
