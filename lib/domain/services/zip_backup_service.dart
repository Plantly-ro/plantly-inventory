import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import '../../data/database/app_database.dart';
import '../../data/photo_blob_store.dart';
import '../../sync/op_log.dart';
import 'backup_service.dart';

/// ZIP-with-photos export (PLAN.md §Phase 1). Produces a single archive
/// containing:
///   - `plantly.backup.json` — the same signed JSON blob the plain
///     `BackupService` produces.
///   - `photos/<first-2>/<sha>.{ext}` — the content-addressed bytes for
///     every photo currently stored on the device. Because photos are
///     already value-addressed, no filename conflicts are possible.
///
/// Import verifies the signed JSON against [secret] and optionally rehydrates
/// photo bytes from the archive into the photo store.
class ZipBackupService {
  ZipBackupService({required this.db, required this.backup, required this.photos});

  final AppDatabase db;
  final BackupService backup;
  final PhotoBlobStore photos;

  /// Archive entry layout: `photos/<shard>/<sha>.<ext>`. Anything else
  /// under `photos/` is ignored on import — the entry name is untrusted.
  static final _photoEntry = RegExp(r'^photos/([0-9a-f]{2})/([0-9a-f]{64})\.([a-z0-9]+)$');

  /// Build the zip archive. [photoBytesFor] lets callers provide raw
  /// bytes — by default we read from the photo store.
  Future<Uint8List> exportZip({
    required String secret,
    Future<Uint8List?> Function(PhotoRow photo)? photoBytesFor,
  }) async {
    final jsonBlob = await backup.export(secret: secret);
    final photoRows = await (db.select(db.photos)
          ..where((p) => p.deletedAt.isNull()))
        .get();

    final archive = Archive()
      ..addFile(ArchiveFile.bytes(
        'plantly.backup.json',
        BackupService.encodeBlob(jsonBlob),
      ));

    for (final photo in photoRows) {
      final bytes = photoBytesFor != null
          ? await photoBytesFor(photo)
          : await photos.read(sha: photo.sha256, mime: photo.mime, localPath: photo.localPath);
      if (bytes == null) continue;
      final ext = PhotoBlobStore.extensionFor(photo.mime);
      final shard = photo.sha256.substring(0, 2);
      archive.addFile(ArchiveFile.bytes(
        'photos/$shard/${photo.sha256}.$ext',
        bytes,
      ));
    }

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  /// Restore from a zip. Mirrors [BackupService.import] for the JSON
  /// document, then writes any photo bytes found in `photos/**` into the
  /// photo store under their content hash.
  Future<ZipImportResult> importZip({
    required Uint8List bytes,
    required String secret,
    required OpLogWriter opLog,
  }) async {
    final decoded = ZipDecoder().decodeBytes(bytes);
    final jsonFile = decoded.files.firstWhere(
      (f) => f.name == 'plantly.backup.json',
      orElse: () => throw const ZipBackupFormatError('Missing plantly.backup.json'),
    );
    final jsonBlob = BackupService.decodeBlob(jsonFile.content as List<int>);
    final jsonResult = await backup.import(blob: jsonBlob, secret: secret, opLog: opLog);

    var photoCount = 0;
    for (final f in decoded.files) {
      if (f.isDirectory) continue;
      // The store only ever writes under the content hash, so a hostile
      // entry name (`photos/../../x`) can't escape; names that don't parse
      // — or whose bytes don't hash to the claimed sha — are dropped.
      final m = _photoEntry.firstMatch(f.name);
      if (m == null || m.group(2)!.substring(0, 2) != m.group(1)) continue;
      final sha = m.group(2)!;
      final content = Uint8List.fromList(f.content as List<int>);
      if (sha256.convert(content).toString() != sha) continue;
      await photos.write(
        sha: sha,
        mime: PhotoBlobStore.mimeForExtension(m.group(3)!),
        bytes: content,
      );
      photoCount++;
    }

    return ZipImportResult(
      json: jsonResult,
      photosRestored: photoCount,
    );
  }

}

class ZipImportResult {
  const ZipImportResult({required this.json, required this.photosRestored});
  final BackupImportResult json;
  final int photosRestored;
}

class ZipBackupFormatError implements Exception {
  const ZipBackupFormatError(this.message);
  final String message;
  @override
  String toString() => 'ZipBackupFormatError: $message';
}
