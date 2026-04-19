import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../../data/database/app_database.dart';
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
/// photo bytes from the archive into the on-disk photo store.
class ZipBackupService {
  ZipBackupService({required this.db, required this.backup});

  final AppDatabase db;
  final BackupService backup;

  /// Build the zip archive. [photoBytesFor] lets callers provide raw
  /// bytes — by default we read from each photo's `local_path`.
  Future<Uint8List> exportZip({
    required String secret,
    Future<Uint8List?> Function(PhotoRow photo)? photoBytesFor,
  }) async {
    final jsonBlob = await backup.export(secret: secret);
    final photos = await (db.select(db.photos)
          ..where((p) => p.deletedAt.isNull()))
        .get();

    final archive = Archive()
      ..addFile(ArchiveFile.bytes(
        'plantly.backup.json',
        Uint8List.fromList(jsonBlob.codeUnits),
      ));

    for (final photo in photos) {
      Uint8List? bytes;
      if (photoBytesFor != null) {
        bytes = await photoBytesFor(photo);
      } else if (photo.localPath != null) {
        final f = File(photo.localPath!);
        if (await f.exists()) {
          bytes = await f.readAsBytes();
        }
      }
      if (bytes == null) continue;
      final ext = _extFor(photo.mime);
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
  /// document, then writes any photo bytes found in `photos/**` to
  /// `[photoStoreRoot]/<shard>/<sha>.ext` — the same layout the live
  /// [PhotoRepository] uses.
  Future<ZipImportResult> importZip({
    required Uint8List bytes,
    required String secret,
    required OpLogWriter opLog,
    required Directory photoStoreRoot,
  }) async {
    final decoded = ZipDecoder().decodeBytes(bytes);
    final jsonFile = decoded.files.firstWhere(
      (f) => f.name == 'plantly.backup.json',
      orElse: () => throw const ZipBackupFormatError('Missing plantly.backup.json'),
    );
    final jsonBlob = String.fromCharCodes(jsonFile.content as List<int>);
    final jsonResult = await backup.import(blob: jsonBlob, secret: secret, opLog: opLog);

    var photoCount = 0;
    final rootPath = p.normalize(photoStoreRoot.path);
    for (final f in decoded.files) {
      if (!f.name.startsWith('photos/')) continue;
      if (f.isDirectory) continue;
      // Reject absolute paths and any entry whose normalised form escapes
      // `photos/` via `..` segments — treating archive names as untrusted.
      final rel = f.name.substring('photos/'.length);
      if (rel.isEmpty || rel.startsWith('/') || rel.contains('\\')) continue;
      final target = p.normalize(p.join(rootPath, rel));
      if (target != rootPath && !p.isWithin(rootPath, target)) continue;
      final file = File(target);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(f.content as List<int>, flush: true);
      photoCount++;
    }

    return ZipImportResult(
      json: jsonResult,
      photosRestored: photoCount,
    );
  }

  String _extFor(String mime) {
    switch (mime) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/heic':
        return 'heic';
      default:
        return 'jpg';
    }
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
