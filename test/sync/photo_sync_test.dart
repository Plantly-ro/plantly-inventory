import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/photo_blob_store.dart';
import 'package:plantly_inventory/data/repositories/care_event_repository.dart';
import 'package:plantly_inventory/data/repositories/photo_repository.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';
import 'package:plantly_inventory/sync/photo_sync.dart';
import 'package:plantly_inventory/sync/sync_transport.dart';

class FakePhotoTransport implements PhotoTransport {
  final List<String> calls = [];
  final Set<String> stored = {};
  final Map<String, Uint8List> remoteBlobs = {};
  int inFlight = 0;
  int maxInFlight = 0;
  Duration putDelay = Duration.zero;
  Object? Function(String sha)? failRequest;

  @override
  Future<PhotoUploadTicket> requestUpload({required String sha256, required int bytes, required String mime}) async {
    calls.add('request:$sha256');
    final err = failRequest?.call(sha256);
    if (err != null) throw err;
    if (stored.contains(sha256)) return const PhotoUploadTicket(alreadyStored: true);
    return PhotoUploadTicket(alreadyStored: false, url: 'https://r2/$sha256', headers: const {'Content-Type': 'image/jpeg'});
  }

  @override
  Future<void> putBlob(PhotoUploadTicket ticket, Uint8List bytes, {required String mime}) async {
    calls.add('put:${ticket.url}');
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    await Future<void>.delayed(putDelay);
    inFlight--;
  }

  @override
  Future<void> completeUpload(String sha256) async {
    calls.add('complete:$sha256');
    stored.add(sha256);
  }

  Object? Function(String sha)? failDelete;
  Future<void> Function(String sha)? whileDeleting;

  @override
  Future<void> deletePhoto(String sha256) async {
    calls.add('delete:$sha256');
    await whileDeleting?.call(sha256);
    final err = failDelete?.call(sha256);
    if (err != null) throw err;
    stored.remove(sha256);
  }

  @override
  Future<Uint8List> download(String sha256) async {
    calls.add('download:$sha256');
    final b = remoteBlobs[sha256];
    if (b == null) throw const SyncCollectionError('not_found', status: 404);
    return b;
  }
}

void main() {
  const tenant = 'col-1';
  late AppDatabase db;
  late InMemoryPhotoBlobStore blobs;
  late FakePhotoTransport transport;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    blobs = InMemoryPhotoBlobStore();
    transport = FakePhotoTransport();
  });
  tearDown(() => db.close());

  Future<void> photo(String sha, {String state = 'local', bool withBlob = true}) async {
    String? path;
    if (withBlob) path = await blobs.write(sha: sha, mime: 'image/jpeg', bytes: Uint8List.fromList([1, 2, 3]));
    await db.into(db.photos).insert(PhotosCompanion.insert(
        sha256: sha, tenantId: tenant, mime: 'image/jpeg', bytes: 3, updatedHlc: '00000000000000001-00000-d', deviceId: 'd',
        localPath: Value(path), remoteState: Value(state)));
  }

  Future<String> state(String sha) async => (await (db.select(db.photos)..where((p) => p.sha256.equals(sha))).getSingle()).remoteState;

  PhotoUploader uploader({int max = 3}) => PhotoUploader(db: db, tenantId: tenant, blobs: blobs, transport: transport, maxConcurrent: max);

  test('uploads local rows: upload-url → PUT → complete → synced', () async {
    await photo('a');
    final s = await uploader().uploadPending();
    expect(s.uploaded, 1);
    expect(transport.calls, ['request:a', 'put:https://r2/a', 'complete:a']);
    expect(await state('a'), 'synced');
  });

  test('already_stored:true flips to synced without a PUT', () async {
    await photo('a');
    transport.stored.add('a');
    final s = await uploader().uploadPending();
    expect(s.alreadyStored, 1);
    expect(transport.calls, ['request:a']);
    expect(await state('a'), 'synced');
  });

  test('skips synced/remote/deleted rows and rows without a blob', () async {
    await photo('synced', state: 'synced');
    await photo('remote', state: 'remote', withBlob: false);
    await photo('noblob', withBlob: false);
    await photo('gone');
    await (db.update(db.photos)..where((p) => p.sha256.equals('gone'))).write(const PhotosCompanion(deletedAt: Value(1)));
    final s = await uploader().uploadPending();
    expect(s.uploaded, 0);
    expect(s.missingBlob, 1);
    expect(transport.calls, isEmpty);
    expect(await state('noblob'), 'remote', reason: 'nothing to upload from here: hand it to the fetcher');
  });

  test('413 stops further uploads for the run, keeps remaining rows local, reports quotaExceeded', () async {
    for (final s in ['a', 'b', 'c', 'd']) {
      await photo(s);
    }
    transport.failRequest = (sha) => sha == 'b' ? const SyncQuotaError(bytesQuota: 10, bytesStored: 10) : null;
    final s = await uploader(max: 1).uploadPending();
    expect(s.quotaExceeded, isTrue);
    expect(s.uploaded, 1);
    expect(await state('a'), 'synced');
    expect(await state('b'), 'local');
    expect(await state('c'), 'local');
    expect(transport.calls.where((c) => c.startsWith('request:')), ['request:a', 'request:b']);
  });

  test('other transport errors abort the run and propagate', () async {
    await photo('a');
    await photo('b');
    transport.failRequest = (sha) => sha == 'a' ? const SyncRetryableError('503', status: 503) : null;
    await expectLater(uploader(max: 1).uploadPending(), throwsA(isA<SyncRetryableError>()));
    expect(await state('a'), 'local');
  });

  test('at most 3 uploads in flight', () async {
    for (var i = 0; i < 8; i++) {
      await photo('s$i');
    }
    transport.putDelay = const Duration(milliseconds: 20);
    final s = await uploader().uploadPending();
    expect(s.uploaded, 8);
    expect(transport.maxInFlight, 3);
  });

  group('PhotoFetcher', () {
    PhotoFetcher fetcher() => PhotoFetcher(db: db, tenantId: tenant, blobs: blobs, transport: transport);

    test('downloads a remote photo, stores the blob and flips to synced', () async {
      await photo('r', state: 'remote', withBlob: false);
      transport.remoteBlobs['r'] = Uint8List.fromList([7, 7]);
      expect(await fetcher().ensureLocal('r'), isTrue);
      expect(await blobs.read(sha: 'r', mime: 'image/jpeg'), [7, 7]);
      final row = await (db.select(db.photos)..where((p) => p.sha256.equals('r'))).getSingle();
      expect(row.remoteState, 'synced');
      expect(row.localPath, isNotNull);
      expect(transport.calls, ['download:r']);
    });

    test('a remote row whose blob is already on this device: no download, queued for upload (local)', () async {
      await photo('r', state: 'remote');
      expect(await fetcher().ensureLocal('r'), isTrue);
      expect(transport.calls, isEmpty);
      expect(await state('r'), 'local');
    });

    test('a local row whose blob is gone self-heals: uploader → remote → fetcher downloads', () async {
      await photo('x', withBlob: false);
      transport.remoteBlobs['x'] = Uint8List.fromList([9]);
      await uploader().uploadPending();
      expect(await state('x'), 'remote');
      expect(await fetcher().ensureLocal('x'), isTrue);
      expect(await state('x'), 'synced');
    });

    test('no download when the blob is already local; unknown sha → false', () async {
      await photo('l');
      expect(await fetcher().ensureLocal('l'), isTrue);
      expect(transport.calls, isEmpty);
      expect(await fetcher().ensureLocal('nope'), isFalse);
    });

    test('concurrent calls for one sha share a single download', () async {
      await photo('r', state: 'remote', withBlob: false);
      transport.remoteBlobs['r'] = Uint8List.fromList([1]);
      final f = fetcher();
      final results = await Future.wait([f.ensureLocal('r'), f.ensureLocal('r'), f.ensureLocal('r')]);
      expect(results, [true, true, true]);
      expect(transport.calls.where((c) => c == 'download:r'), hasLength(1));
    });

    test('a synced row whose blob went missing is re-downloaded', () async {
      await photo('s', state: 'synced', withBlob: false);
      transport.remoteBlobs['s'] = Uint8List.fromList([2]);
      expect(await fetcher().ensureLocal('s'), isTrue);
      expect(transport.calls, ['download:s']);
    });

    test('transport failure propagates and leaves the row remote', () async {
      await photo('r', state: 'remote', withBlob: false);
      await expectLater(fetcher().ensureLocal('r'), throwsA(isA<SyncCollectionError>()));
      expect(await state('r'), 'remote');
    });
  });

  group('garbage collection (DELETE .../photos/{sha})', () {
    const day = 86400000;
    late int wall;
    late OpLogWriter opLog;
    late PhotoRepository photos;
    late PlantPhotoRepository joins;

    setUp(() {
      wall = 1000000000000;
      final clock = HlcClock(deviceId: 'dev-a', nowProvider: () => DateTime.fromMillisecondsSinceEpoch(wall, isUtc: true));
      opLog = OpLogWriter(db: db, clock: clock, tenantId: tenant);
      photos = PhotoRepository(db: db, opLog: opLog, store: blobs);
      joins = PlantPhotoRepository(db: db, opLog: opLog);
    });

    PhotoUploader gcUploader({String? device = 'dev-a'}) => PhotoUploader(
        db: db, tenantId: tenant, blobs: blobs, transport: transport, deviceId: device, nowMillis: () => wall);

    Future<void> markPushed() =>
        (db.update(db.syncOps)..where((o) => o.pushedAt.isNull())).write(SyncOpsCompanion(pushedAt: Value(wall)));

    /// Saved, attached to p1, uploaded, everything pushed.
    Future<String> uploaded(List<int> bytes) async {
      final sha = await photos.saveBytes(Uint8List.fromList(bytes));
      await joins.attach('p1', sha);
      await markPushed();
      await gcUploader().uploadPending();
      expect(await state(sha), 'synced');
      return sha;
    }

    test('PROBE gc row + remote device re-attach (pulled) → should re-upload', () async {
      final sha = await uploaded([1, 1]);
      await joins.detach('p1', sha);
      await markPushed();
      wall += 8 * day;
      await gcUploader().uploadPending();
      expect(await state(sha), kPhotoStateCollected);
      // dev-b's attach (made offline before our gc) arrives through a pull.
      final h = const Hlc(1000000000400, 0, 'dev-b').encode();
      await db.into(db.plantPhotos).insert(PlantPhotosCompanion.insert(
          id: 'remote-row', tenantId: tenant, plantId: 'p9', photoSha: sha, addedHlc: h, deviceId: 'dev-b'));
      transport.calls.clear();
      await gcUploader().uploadPending();
      expect(transport.calls, contains('request:$sha'), reason: 'live ref + blob deleted by us → must re-upload');
    });

    test('PROBE detach made offline 8 days ago, pushed just now → should wait grace from push', () async {
      final sha = await uploaded([2, 2]);
      await joins.detach('p1', sha);
      wall += 8 * day;
      await markPushed(); // pushed now, 8 days after the detach
      final s = await gcUploader().uploadPending();
      expect(s.deleted, 0, reason: 'peers had no chance to see the detach yet');
    });

    test('a concurrent download (remote → synced) during the DELETE still ends as gc', () async {
      final sha = await uploaded([3, 5]);
      await joins.detach('p1', sha);
      await markPushed();
      wall += 8 * day;
      transport.whileDeleting = (s) => (db.update(db.photos)..where((p) => p.sha256.equals(s)))
          .write(const PhotosCompanion(remoteState: Value('synced')));
      await gcUploader().collectGarbage(PhotoUploadSummary());
      expect(await state(sha), kPhotoStateCollected);
    });

    test('a row whose state changed while the DELETE was in flight is not marked gc', () async {
      final sha = await uploaded([3, 4]);
      await joins.detach('p1', sha);
      await markPushed();
      wall += 8 * day;
      transport.whileDeleting = (s) => (db.update(db.photos)..where((p) => p.sha256.equals(s)))
          .write(const PhotosCompanion(remoteState: Value('local')));
      await gcUploader().collectGarbage(PhotoUploadSummary());
      expect(await state(sha), 'local');
    });

    test('detached here, pushed, older than the grace period → DELETE, row marked gc, never re-uploaded', () async {
      final sha = await uploaded([1, 1]);
      await joins.detach('p1', sha);
      await markPushed();

      wall += 6 * day;
      var s = await gcUploader().uploadPending();
      expect(s.deleted, 0, reason: 'inside the grace period');
      expect(transport.calls.where((c) => c.startsWith('delete:')), isEmpty);

      wall += 2 * day;
      s = await gcUploader().uploadPending();
      expect(s.deleted, 1);
      expect(transport.calls.last, 'delete:$sha');
      expect(await state(sha), kPhotoStateCollected);

      transport.calls.clear();
      s = await gcUploader().uploadPending();
      expect(transport.calls, isEmpty, reason: 'gc rows are neither deleted again nor uploaded');
    });

    test('nothing happens while the detach op is unpushed or was parked as rejected', () async {
      final sha = await uploaded([2, 2]);
      await joins.detach('p1', sha);
      wall += 8 * day;
      await gcUploader().uploadPending();
      expect(await state(sha), 'synced', reason: 'pending detach');

      await markPushed();
      final op = await (db.select(db.syncOps)..where((o) => o.field.equals('removed_hlc'))).getSingle();
      await db.into(db.syncRejections).insert(SyncRejectionsCompanion.insert(
          opSeq: Value(op.seq), tenantId: tenant, entity: op.entity, entityId: op.entityId, field: op.field,
          reason: 'forbidden', hlc: op.hlc, at: wall, parked: const Value(true)));
      await gcUploader().uploadPending();
      expect(await state(sha), 'synced', reason: 'server refused the detach');
    });

    test('still referenced elsewhere in the collection → kept', () async {
      final sha = await uploaded([3, 3]);
      await joins.attach('p2', sha);
      await joins.detach('p1', sha);
      await markPushed();
      wall += 8 * day;
      await gcUploader().uploadPending();
      expect(await state(sha), 'synced', reason: 'live on p2');

      await joins.detach('p2', sha);
      await CareEventRepository(db: db, opLog: opLog).record(plantId: 'p1', type: 'note', photoSha: sha);
      await markPushed();
      wall += 8 * day;
      await gcUploader().uploadPending();
      expect(await state(sha), 'synced', reason: 'a care event shows it');
    });

    test('last detach made by another device, or no device id → this device never deletes', () async {
      final sha = await uploaded([4, 4]);
      final row = (await db.select(db.plantPhotos).get()).single;
      final remote = const Hlc(1000000000500, 0, 'dev-b').encode();
      await (db.update(db.plantPhotos)..where((r) => r.id.equals(row.id))).write(PlantPhotosCompanion(removedHlc: Value(remote)));
      // The pulled detach op is in the log as accepted — only its author differs.
      await opLog.recordRemote(
          SyncOpDto(entity: 'plant_photos', entityId: row.id, field: 'removed_hlc', value: null, hlc: remote, deviceId: 'dev-b'),
          deviceId: 'dev-b', nowMillis: wall);
      wall += 8 * day;
      await gcUploader(device: 'dev-b').uploadPending();
      expect(await state(sha), kPhotoStateCollected, reason: 'sanity: dev-b would collect it');
      await (db.update(db.photos)..where((p) => p.sha256.equals(sha))).write(const PhotosCompanion(remoteState: Value('synced')));
      wall += 8 * day;
      await gcUploader().uploadPending();
      expect(await state(sha), 'synced');

      final mine = await uploaded([5, 5]);
      await joins.detach('p1', mine);
      await markPushed();
      wall += 8 * day;
      await gcUploader(device: null).uploadPending();
      expect(await state(mine), 'synced');
    });

    test('a refused DELETE (viewer: 403 read_only) ends the pass quietly; uploads still run', () async {
      final sha = await uploaded([6, 6]);
      await joins.detach('p1', sha);
      await markPushed();
      wall += 8 * day;
      final fresh = await photos.saveBytes(Uint8List.fromList([7, 7]));
      await joins.attach('p1', fresh);
      transport.failDelete = (_) => const SyncCollectionError('read_only', status: 403);
      final s = await gcUploader().uploadPending();
      expect(s.deleted, 0);
      expect(s.uploaded, 1);
      expect(await state(sha), 'synced');
      expect(await state(fresh), 'synced');
    });

    test('saving the same image again re-queues the upload: after our gc, and when another device may have collected it', () async {
      final sha = await uploaded([8, 8]);
      await joins.detach('p1', sha);
      await markPushed();
      wall += 8 * day;
      await gcUploader().uploadPending();
      expect(await state(sha), kPhotoStateCollected);

      expect(await photos.saveBytes(Uint8List.fromList([8, 8])), sha);
      expect(await state(sha), 'local');
      await joins.attach('p1', sha);
      transport.calls.clear();
      await gcUploader().uploadPending();
      expect(transport.calls, ['request:$sha', 'put:https://r2/$sha', 'complete:$sha']);

      // Synced but unreferenced here (someone else's gc is invisible to us).
      final other = await uploaded([9, 9]);
      await joins.detach('p1', other);
      await photos.saveBytes(Uint8List.fromList([9, 9]));
      expect(await state(other), 'local');

      // Still referenced → untouched, no extra request.
      await photos.saveBytes(Uint8List.fromList([8, 8]));
      expect(await state(sha), 'synced');
    });
  });
}
