import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/photo_blob_store.dart';
import 'package:plantly_inventory/data/repositories/photo_repository.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';
import 'package:plantly_inventory/sync/photo_sync.dart';
import 'package:plantly_inventory/sync/sync_applier.dart';
import 'package:plantly_inventory/sync/sync_rejections.dart' show kIdCollisionReason;
import 'package:plantly_inventory/sync/sync_transport.dart';

// Audit P2: with `photos` keyed by sha alone, the same image stored in two
// collections on one device only ever existed under the first tenant — no
// row, op or upload in the second. Schema 13 keys it (tenant_id, sha256).

void main() {
  late AppDatabase db;
  late InMemoryPhotoBlobStore blobs;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    blobs = InMemoryPhotoBlobStore();
  });
  tearDown(() => db.close());

  PhotoRepository repo(String tenant) => PhotoRepository(
        db: db,
        opLog: OpLogWriter(db: db, clock: HlcClock(deviceId: 'dev-a'), tenantId: tenant),
        store: blobs,
      );

  test('same bytes saved in a second collection get a photos row + `*` op there', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final sha = await repo('own').saveBytes(bytes);
    expect(await repo('shared').saveBytes(bytes), sha);

    final ops = await (db.select(db.syncOps)..where((o) => o.entity.equals('photos'))).get();
    expect(ops.map((o) => o.tenantId).toSet(), {'own', 'shared'});
    final rows = await (db.select(db.photos)..where((p) => p.sha256.equals(sha))).get();
    expect(rows.map((r) => r.tenantId).toSet(), {'own', 'shared'});
  });

  test('a pulled photos `*` for a sha this device holds in another collection is not an id collision', () async {
    final sha = await repo('own').saveBytes(Uint8List.fromList([9, 9]));
    final opLog = OpLogWriter(db: db, clock: HlcClock(deviceId: 'dev-a'), tenantId: 'shared');
    final applier = SyncApplier(db: db, opLog: opLog, clock: opLog.clock);
    final hlc = const Hlc(5000, 0, 'dev-b').encode();
    final r = await applier.applyBatch([
      SyncOpDto(entity: 'photos', entityId: sha, field: '*', hlc: hlc, deviceId: 'dev-b', value: {
        'sha256': sha, 'mime': 'image/jpeg', 'bytes': 2, 'width': null, 'height': null, 'taken_at': null,
        'updated_hlc': hlc, 'deleted_at': null, 'device_id': 'dev-b',
      }),
    ]);
    expect(r.idCollisions, isEmpty);
    expect((await (db.select(db.photos)..where((p) => p.tenantId.equals('shared'))).get()).single.sha256, sha);
  });

  test('the second collection uploads its own copy; byHash prefers the current collection', () async {
    final bytes = Uint8List.fromList([5, 6, 7]);
    final sha = await repo('own').saveBytes(bytes);
    await repo('shared').saveBytes(bytes);
    final transport = _Transport();
    final s = await PhotoUploader(db: db, tenantId: 'shared', blobs: blobs, transport: transport).uploadPending();
    expect(s.uploaded, 1);
    expect(transport.uploaded, [sha]);
    final own = (await repo('own').byHash(sha))!;
    final shared = (await repo('shared').byHash(sha))!;
    expect((own.tenantId, own.remoteState), ('own', 'local'));
    expect((shared.tenantId, shared.remoteState), ('shared', 'synced'));
    expect(await repo('third').byHash(sha), isNotNull, reason: 'legacy fallback: any live row, blob is shared');
  });

  test('a pulled (remote) row whose blob another collection already stored needs no download', () async {
    final sha = await repo('own').saveBytes(Uint8List.fromList([1, 1, 1]));
    await db.into(db.photos).insert(PhotosCompanion.insert(
        sha256: sha, tenantId: 'shared', mime: 'image/jpeg', bytes: 3, updatedHlc: 'h', deviceId: 'dev-b',
        remoteState: const Value('remote')));
    final transport = _Transport();
    final fetcher = PhotoFetcher(db: db, tenantId: 'shared', blobs: blobs, transport: transport);
    expect(await fetcher.ensureLocal(sha), isTrue);
    expect(transport.downloads, isEmpty);
    expect((await repo('shared').byHash(sha))!.remoteState, 'local', reason: 'upload re-checks this collection');
  });

  test('photos `*` ops parked as id_collision before schema 13 are replayed once and cleared', () async {
    final sha = await repo('own').saveBytes(Uint8List.fromList([4, 2]));
    final opLog = OpLogWriter(db: db, clock: HlcClock(deviceId: 'dev-a'), tenantId: 'shared');
    final hlc = const Hlc(5000, 0, 'dev-b').encode();
    // What a 1.1.0 applier left behind: the remote op stored, a parked ledger row.
    final seq = await opLog.recordRemote(
      SyncOpDto(entity: 'photos', entityId: sha, field: '*', hlc: hlc, deviceId: 'dev-b', value: {
        'sha256': sha, 'mime': 'image/png', 'bytes': 2, 'width': 3, 'height': 4, 'taken_at': null,
        'updated_hlc': hlc, 'deleted_at': null, 'device_id': 'dev-b',
      }),
      deviceId: 'dev-b',
      nowMillis: 1,
    );
    await db.into(db.syncRejections).insert(SyncRejectionsCompanion.insert(
        opSeq: Value(seq), tenantId: 'shared', entity: 'photos', entityId: sha, field: '*',
        reason: kIdCollisionReason, hlc: hlc, at: 1, parked: const Value(true)));

    final applier = SyncApplier(db: db, opLog: opLog, clock: opLog.clock);
    final r = await applier.applyBatch(const []);
    expect(r.remotePhotoShas, [sha]);
    final row = await (db.select(db.photos)..where((p) => p.tenantId.equals('shared'))).getSingle();
    expect((row.sha256, row.mime, row.width, row.remoteState), (sha, 'image/png', 3, 'remote'));
    expect(await db.select(db.syncRejections).get(), isEmpty);
    expect((await (db.select(db.photos)..where((p) => p.tenantId.equals('own'))).getSingle()).mime, 'image/jpeg');
  });
}

class _Transport implements PhotoTransport {
  final List<String> uploaded = [];
  final List<String> downloads = [];

  @override
  Future<PhotoUploadTicket> requestUpload({required String sha256, required int bytes, required String mime}) async =>
      PhotoUploadTicket(alreadyStored: false, url: 'https://r2/$sha256');

  @override
  Future<void> putBlob(PhotoUploadTicket ticket, Uint8List bytes, {required String mime}) async {}

  @override
  Future<void> completeUpload(String sha256) async => uploaded.add(sha256);

  @override
  Future<void> deletePhoto(String sha256) async {}

  @override
  Future<Uint8List> download(String sha256) async {
    downloads.add(sha256);
    return Uint8List(0);
  }
}
