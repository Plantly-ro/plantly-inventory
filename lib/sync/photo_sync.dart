import 'dart:async';

import 'package:drift/drift.dart';

import '../data/database/app_database.dart';
import '../data/photo_blob_store.dart';
import 'hlc.dart';
import 'sync_transport.dart';

/// Presigned upload as returned by `POST .../photos/upload-url`.
class PhotoUploadTicket {
  const PhotoUploadTicket({
    required this.alreadyStored,
    this.url,
    this.method = 'PUT',
    this.headers = const {},
  });

  final bool alreadyStored;
  final String? url;
  final String method;
  final Map<String, String> headers;
}

/// Photo blob endpoints (CLOUD-SYNC-CONTRACT §2.2). Implemented by
/// `HttpSyncTransport`; faked in tests.
abstract class PhotoTransport {
  Future<PhotoUploadTicket> requestUpload({
    required String sha256,
    required int bytes,
    required String mime,
  });

  Future<void> putBlob(PhotoUploadTicket ticket, Uint8List bytes, {required String mime});

  Future<void> completeUpload(String sha256);

  /// `DELETE .../photos/{sha}` — removes the collection's blob and frees its
  /// quota (204 also when already gone). Writers only (403 `read_only`).
  /// The server does NOT check whether ops still reference the sha.
  Future<void> deletePhoto(String sha256);

  /// `GET .../photos/{sha}` (`Accept: application/json` → `{url}`, or a 302
  /// from an older server), then the presigned object without a bearer.
  Future<Uint8List> download(String sha256);
}

class PhotoUploadSummary {
  int uploaded = 0;
  int alreadyStored = 0;

  /// Rows whose blob is missing on this device (nothing to upload; the row
  /// stays `local` so a later restore can retry).
  int missingBlob = 0;

  /// Upload stopped because the collection is over quota.
  bool quotaExceeded = false;

  /// Blobs removed from the collection by [PhotoUploader.collectGarbage].
  int deleted = 0;

  @override
  String toString() =>
      'PhotoUploadSummary(uploaded: $uploaded, alreadyStored: $alreadyStored, '
      'missingBlob: $missingBlob, quotaExceeded: $quotaExceeded, deleted: $deleted)';
}

/// `photos.remote_state` once [PhotoUploader.collectGarbage] deleted the
/// collection's blob. Device-local like the other states; the uploader skips
/// it, and `PhotoRepository.saveBytes` turns it back into `local` when the
/// same image is attached again.
const String kPhotoStateCollected = 'gc';

/// SQL predicate: [sha] (an SQL expression) is referenced by something live
/// in tenant [tenant] (an SQL expression) — a plant / location gallery row,
/// a care-event photo or a location map photo. The one definition of "still
/// in use" for garbage collection, revive and re-attach.
String photoLiveReferenceSql({required String tenant, required String sha}) =>
    '(EXISTS (SELECT 1 FROM plant_photos WHERE tenant_id = $tenant AND photo_sha = $sha AND removed_hlc IS NULL) '
    'OR EXISTS (SELECT 1 FROM location_photos WHERE tenant_id = $tenant AND photo_sha = $sha AND removed_hlc IS NULL) '
    'OR EXISTS (SELECT 1 FROM care_events WHERE tenant_id = $tenant AND photo_sha = $sha AND deleted_at IS NULL) '
    'OR EXISTS (SELECT 1 FROM locations WHERE tenant_id = $tenant AND map_photo_sha = $sha AND deleted_at IS NULL))';

/// Uploads every live `photos` row with `remote_state='local'`:
/// `upload-url` → PUT → `complete` → `remote_state='synced'`.
/// At most [maxConcurrent] transfers in flight. A 413 stops further uploads
/// for this run (rows keep syncing); any other [SyncError] aborts the run and
/// propagates so the runner can back off.
///
/// Before uploading, [collectGarbage] frees the collection's copy of photos
/// nothing references any more (needs [deviceId]; disabled without it).
class PhotoUploader {
  PhotoUploader({
    required this.db,
    required this.tenantId,
    required this.blobs,
    required this.transport,
    this.maxConcurrent = 3,
    this.deviceId,
    this.gcGrace = const Duration(days: 7),
    int Function()? nowMillis,
  }) : _nowMillis = nowMillis ?? (() => DateTime.now().millisecondsSinceEpoch);

  final AppDatabase db;
  final String tenantId;
  final PhotoBlobStore blobs;
  final PhotoTransport transport;
  final int maxConcurrent;

  /// This device's id (HLC suffix). Garbage collection only acts on photos
  /// whose last detach was made here; null disables it.
  final String? deviceId;

  /// How long a photo must have been unreferenced before its blob is
  /// deleted — the window in which another device's concurrent re-attach
  /// reaches us through a pull and cancels the delete.
  final Duration gcGrace;
  final int Function() _nowMillis;

  Future<PhotoUploadSummary> uploadPending() async {
    final summary = PhotoUploadSummary();
    await reviveReferenced();
    // Before uploading, so a collection at its quota can make room.
    await collectGarbage(summary);
    final rows = await (db.select(db.photos)
          ..where((p) =>
              p.tenantId.equals(tenantId) & p.remoteState.equals('local') & p.deletedAt.isNull())
          ..orderBy([(p) => OrderingTerm.asc(p.updatedHlc)]))
        .get();
    if (rows.isEmpty) return summary;

    final queue = List<PhotoRow>.from(rows);
    Object? failure;
    StackTrace? failureTrace;

    Future<void> worker() async {
      while (queue.isNotEmpty && failure == null && !summary.quotaExceeded) {
        final row = queue.removeAt(0);
        try {
          await _uploadOne(row, summary);
        } on SyncQuotaError {
          summary.quotaExceeded = true;
        } catch (e, st) {
          failure ??= e;
          failureTrace ??= st;
        }
      }
    }

    final n = maxConcurrent.clamp(1, rows.length);
    await Future.wait([for (var i = 0; i < n; i++) worker()]);
    if (failure != null) Error.throwWithStackTrace(failure!, failureTrace!);
    return summary;
  }

  Future<void> _uploadOne(PhotoRow row, PhotoUploadSummary summary) async {
    final bytes = await blobs.read(sha: row.sha256, mime: row.mime, localPath: row.localPath);
    if (bytes == null) {
      // Nothing to upload from here: let the fetcher download it instead
      // (a restored row, or a blob lost on this device). If the bytes turn
      // up locally, the fetcher queues the upload again.
      summary.missingBlob++;
      await _setState(row.sha256, 'remote');
      return;
    }
    final ticket = await transport.requestUpload(sha256: row.sha256, bytes: bytes.length, mime: row.mime);
    if (ticket.alreadyStored) {
      summary.alreadyStored++;
    } else {
      await transport.putBlob(ticket, bytes, mime: row.mime);
      await transport.completeUpload(row.sha256);
      summary.uploaded++;
    }
    await _setState(row.sha256, 'synced');
  }

  /// A collected (`gc`) photo that is referenced again — a re-attach that
  /// reached us through a pull (made offline, before our delete, by an older
  /// client, or merged in by a tenant migration) — goes back to `local`, so
  /// the next upload restores the blob (`already_stored` if it never left).
  Future<int> reviveReferenced() => db.customUpdate(
        "UPDATE photos SET remote_state = 'local' "
        'WHERE tenant_id = ?1 AND remote_state = ?2 AND deleted_at IS NULL '
        'AND ${photoLiveReferenceSql(tenant: '?1', sha: 'photos.sha256')}',
        variables: [Variable<String>(tenantId), Variable<String>(kPhotoStateCollected)],
        updates: {db.photos},
        updateKind: UpdateKind.update,
      );

  /// Deletes (`DELETE .../photos/{sha}`) the collection blob of every photo
  /// in this tenant that:
  ///   * has no live reference left here — plant / location gallery rows
  ///     (`removed_hlc IS NULL`), care-event photos, location map photos;
  ///   * was attached through a gallery at least once, and its LAST detach
  ///     was made by this device ([deviceId]) — one deleter per photo, and
  ///     viewers (who never detach) never call the writer-only route;
  ///   * whose last detach op has been accepted by the server (pushed and
  ///     not parked as rejected) at least [gcGrace] ago — measured on OUR
  ///     push time, not the HLC: a detach made offline long ago has only
  ///     been visible to peers since it was pushed.
  /// The server deletes unconditionally, so all checks are on our side;
  /// this runs after the pull, so references other devices pushed in the
  /// meantime are already visible. The row stays (no tombstone: deletes are
  /// final in v1 and the sha is content-addressed, a tombstone would block
  /// re-attaching the same image forever) and is marked
  /// [kPhotoStateCollected]. Best effort: any [SyncError] ends this pass
  /// silently and the sync run carries on.
  Future<void> collectGarbage(PhotoUploadSummary summary) async {
    final me = deviceId;
    if (me == null) return;
    final cutoff = _nowMillis() - gcGrace.inMilliseconds;
    final candidates = await db.customSelect(
      _gcCandidatesSql,
      variables: [Variable<String>(tenantId), Variable<String>(kPhotoStateCollected), Variable<int>(cutoff)],
      readsFrom: {db.photos, db.plantPhotos, db.locationPhotos, db.careEvents, db.locations, db.syncOps, db.syncRejections},
    ).get();
    for (final c in candidates) {
      final sha = c.read<String>('sha256');
      final last = c.readNullable<String>('last_removed');
      if (last == null) continue;
      final Hlc h;
      try {
        h = Hlc.parse(last);
      } on FormatException {
        continue;
      }
      if (h.deviceId != me) continue;
      if (c.read<int>('accepted') == 0) continue;
      try {
        await transport.deletePhoto(sha);
      } on SyncError {
        return;
      }
      // Unless the row went `local` meanwhile (a re-attach's revive, a
      // restore): that upload must still happen. A concurrent download
      // (remote → synced) does not change that the object is gone.
      await (db.update(db.photos)
            ..where((p) => p.sha256.equals(sha) & p.tenantId.equals(tenantId) & p.remoteState.equals('local').not()))
          .write(const PhotosCompanion(remoteState: Value(kPhotoStateCollected)));
      summary.deleted++;
    }
  }

  /// `?1` tenant, `?2` the collected state, `?3` the grace cutoff (ms).
  /// `last_removed` = newest `removed_hlc` over the photo's gallery rows
  /// (HLC strings sort in HLC order); `accepted` = the op that stamped it was
  /// pushed no later than the cutoff and not parked as rejected.
  static const String _gcCandidatesSql = '''
SELECT p.sha256 AS sha256, x.last_removed AS last_removed,
  EXISTS (
    SELECT 1 FROM sync_ops o
    WHERE o.tenant_id = ?1 AND o.entity IN ('plant_photos', 'location_photos')
      AND o.field IN ('removed_hlc', '__tombstone__') AND o.hlc = x.last_removed
      AND o.pushed_at IS NOT NULL AND o.pushed_at <= ?3
      AND NOT EXISTS (SELECT 1 FROM sync_rejections r WHERE r.op_seq = o.seq)
  ) AS accepted
FROM photos p
JOIN (
  SELECT photo_sha, MAX(removed_hlc) AS last_removed FROM (
    SELECT photo_sha, removed_hlc FROM plant_photos WHERE tenant_id = ?1
    UNION ALL
    SELECT photo_sha, removed_hlc FROM location_photos WHERE tenant_id = ?1
  ) GROUP BY photo_sha
  HAVING SUM(CASE WHEN removed_hlc IS NULL THEN 1 ELSE 0 END) = 0
) x ON x.photo_sha = p.sha256
WHERE p.tenant_id = ?1 AND p.deleted_at IS NULL AND p.remote_state <> ?2
  AND NOT EXISTS (SELECT 1 FROM care_events e WHERE e.tenant_id = ?1 AND e.photo_sha = p.sha256 AND e.deleted_at IS NULL)
  AND NOT EXISTS (SELECT 1 FROM locations l WHERE l.tenant_id = ?1 AND l.map_photo_sha = p.sha256 AND l.deleted_at IS NULL)
''';

  Future<void> _setState(String sha, String state) {
    return (db.update(db.photos)..where((p) => p.sha256.equals(sha) & p.tenantId.equals(tenantId)))
        .write(PhotosCompanion(remoteState: Value(state)));
  }
}

/// Lazy download for photos that arrived through the op log
/// (`remote_state='remote'`). Call [ensureLocal] before displaying; it is
/// single-flight per sha and a no-op once the blob is present.
class PhotoFetcher {
  PhotoFetcher({
    required this.db,
    required this.tenantId,
    required this.blobs,
    required this.transport,
  });

  final AppDatabase db;
  final String tenantId;
  final PhotoBlobStore blobs;
  final PhotoTransport transport;

  final Map<String, Future<bool>> _inflight = {};

  /// True when the blob is available locally afterwards. Throws [SyncError]
  /// on transport failure (callers usually show a placeholder and retry on
  /// the next build).
  Future<bool> ensureLocal(String sha256) {
    return _inflight.putIfAbsent(sha256, () {
      // Block body on purpose: `remove` returns the future itself and an
      // expression body would make whenComplete wait on its own result.
      return _fetch(sha256).whenComplete(() {
        _inflight.remove(sha256);
      });
    });
  }

  Future<bool> _fetch(String sha) async {
    final row = await (db.select(db.photos)
          ..where((p) => p.sha256.equals(sha) & p.tenantId.equals(tenantId)))
        .getSingleOrNull();
    if (row == null) return false;
    // Blobs are shared by sha across collections on this device: a `remote`
    // row whose image is already here needs no download. It goes to `local`,
    // not `synced` — nothing proves THIS collection holds the object (a
    // restored row, a self-healed one); the uploader's `already_stored`
    // answer settles it for one request.
    final existing = await blobs.read(sha: sha, mime: row.mime, localPath: row.localPath);
    if (existing != null) {
      if (row.remoteState == 'remote') {
        await (db.update(db.photos)
              ..where((p) => p.sha256.equals(sha) & p.tenantId.equals(tenantId) & p.remoteState.equals('remote')))
            .write(const PhotosCompanion(remoteState: Value('local')));
      }
      return true;
    }
    final bytes = await transport.download(sha);
    final localPath = await blobs.write(sha: sha, mime: row.mime, bytes: bytes);
    await (db.update(db.photos)..where((p) => p.sha256.equals(sha) & p.tenantId.equals(tenantId)))
        .write(PhotosCompanion(remoteState: const Value('synced'), localPath: Value(localPath)));
    return true;
  }
}
