import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/photo_blob_store.dart';
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
    expect(await state('noblob'), 'local');
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
}
