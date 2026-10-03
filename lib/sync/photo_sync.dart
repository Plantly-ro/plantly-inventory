import 'dart:async';

import 'package:drift/drift.dart';

import '../data/database/app_database.dart';
import '../data/photo_blob_store.dart';
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

  @override
  String toString() =>
      'PhotoUploadSummary(uploaded: $uploaded, alreadyStored: $alreadyStored, '
      'missingBlob: $missingBlob, quotaExceeded: $quotaExceeded)';
}

/// Uploads every live `photos` row with `remote_state='local'`:
/// `upload-url` → PUT → `complete` → `remote_state='synced'`.
/// At most [maxConcurrent] transfers in flight. A 413 stops further uploads
/// for this run (rows keep syncing); any other [SyncError] aborts the run and
/// propagates so the runner can back off.
class PhotoUploader {
  PhotoUploader({
    required this.db,
    required this.tenantId,
    required this.blobs,
    required this.transport,
    this.maxConcurrent = 3,
  });

  final AppDatabase db;
  final String tenantId;
  final PhotoBlobStore blobs;
  final PhotoTransport transport;
  final int maxConcurrent;

  Future<PhotoUploadSummary> uploadPending() async {
    final summary = PhotoUploadSummary();
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
      summary.missingBlob++;
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
    if (row.remoteState != 'remote') {
      final existing = await blobs.read(sha: sha, mime: row.mime, localPath: row.localPath);
      if (existing != null) return true;
    }
    final bytes = await transport.download(sha);
    final localPath = await blobs.write(sha: sha, mime: row.mime, bytes: bytes);
    await (db.update(db.photos)..where((p) => p.sha256.equals(sha) & p.tenantId.equals(tenantId)))
        .write(PhotosCompanion(remoteState: const Value('synced'), localPath: Value(localPath)));
    return true;
  }
}
