import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Backend chosen at compile time: the sharded on-disk store on io platforms,
// IndexedDB on web. Keeps io-only and browser-only imports out of the shared
// code path so the same repositories run on Android and in a browser.
import 'photo_blob_store_io.dart'
    if (dart.library.js_interop) 'photo_blob_store_web.dart' as platform;

/// Where photo bytes live. The `photos` table only stores metadata plus
/// `local_path`, an opaque hint produced by [write] — a filesystem path on
/// io, a `<sha>.<ext>` key on web. Readers always pass the sha + mime too so
/// a row imported from another device (whose `local_path` is meaningless
/// here) still resolves by content hash.
abstract class PhotoBlobStore {
  /// Persist [bytes] under [sha]; returns the value to record as `local_path`.
  /// Writing the same sha twice is a no-op.
  Future<String> write({
    required String sha,
    required String mime,
    required Uint8List bytes,
  });

  /// Raw bytes for a photo, or null when the blob is missing.
  Future<Uint8List?> read({
    required String sha,
    required String mime,
    String? localPath,
  });

  /// Image for the widget tree, or null when the blob is missing.
  Future<ImageProvider?> imageFor({
    required String sha,
    required String mime,
    String? localPath,
  });

  static String extensionFor(String mime) {
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

  static String mimeForExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }
}

/// A store whose every blob can be dropped at once (the web sign-out wipe:
/// a shared computer must not keep the previous account's photos).
abstract interface class ClearablePhotoBlobStore {
  Future<void> clear();
}

/// Pure-Dart store for tests — the same behavioural contract without a
/// filesystem or a browser.
class InMemoryPhotoBlobStore implements PhotoBlobStore, ClearablePhotoBlobStore {
  final Map<String, Uint8List> blobs = {};

  @override
  Future<void> clear() async => blobs.clear();

  String _key(String sha, String mime) => '$sha.${PhotoBlobStore.extensionFor(mime)}';

  @override
  Future<String> write({
    required String sha,
    required String mime,
    required Uint8List bytes,
  }) async {
    final key = _key(sha, mime);
    blobs.putIfAbsent(key, () => Uint8List.fromList(bytes));
    return key;
  }

  @override
  Future<Uint8List?> read({
    required String sha,
    required String mime,
    String? localPath,
  }) async {
    final bytes = blobs[_key(sha, mime)];
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  @override
  Future<ImageProvider?> imageFor({
    required String sha,
    required String mime,
    String? localPath,
  }) async {
    final bytes = await read(sha: sha, mime: mime, localPath: localPath);
    return bytes == null ? null : MemoryImage(bytes);
  }
}

final photoBlobStoreProvider = Provider<PhotoBlobStore>((_) => platform.createPhotoBlobStore());
