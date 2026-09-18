import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'photo_blob_store.dart';

PhotoBlobStore createPhotoBlobStore() => IoPhotoBlobStore();

/// Sharded on-disk store: `$docs/photos/ab/<sha>.jpg` so a hot directory
/// never gets millions of siblings. [root] overrides the documents dir
/// (tests point it at a temp folder).
class IoPhotoBlobStore implements PhotoBlobStore {
  IoPhotoBlobStore({Directory? root}) : _rootOverride = root;

  final Directory? _rootOverride;

  Future<Directory> _rootDir() async {
    if (_rootOverride != null) return _rootOverride;
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'photos'));
  }

  Future<File> _canonicalFile(String sha, String mime) async {
    final root = await _rootDir();
    return File(p.join(root.path, sha.substring(0, 2), '$sha.${PhotoBlobStore.extensionFor(mime)}'));
  }

  @override
  Future<String> write({
    required String sha,
    required String mime,
    required Uint8List bytes,
  }) async {
    final file = await _canonicalFile(sha, mime);
    if (!await file.exists()) {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
    }
    return file.path;
  }

  /// `local_path` first (what this device wrote), then the canonical
  /// location — covers rows restored from another device's backup.
  Future<File?> _resolve(String sha, String mime, String? localPath) async {
    if (localPath != null) {
      final f = File(localPath);
      if (await f.exists()) return f;
    }
    final canonical = await _canonicalFile(sha, mime);
    return await canonical.exists() ? canonical : null;
  }

  @override
  Future<Uint8List?> read({
    required String sha,
    required String mime,
    String? localPath,
  }) async {
    final f = await _resolve(sha, mime, localPath);
    return f?.readAsBytes();
  }

  @override
  Future<ImageProvider?> imageFor({
    required String sha,
    required String mime,
    String? localPath,
  }) async {
    final f = await _resolve(sha, mime, localPath);
    return f == null ? null : FileImage(f);
  }
}
