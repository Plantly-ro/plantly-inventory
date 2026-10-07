import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:web/web.dart' as web;

import 'photo_blob_store.dart';

PhotoBlobStore createPhotoBlobStore() => IndexedDbPhotoBlobStore();

/// Browser store: one IndexedDB object store keyed by `<sha>.<ext>`, so
/// photos survive page reloads alongside the Drift database. Bytes go in as
/// typed arrays (structured-cloned, no base64). Decoded [MemoryImage]s are
/// memoised per key so list rebuilds don't re-read IndexedDB and re-decode.
class IndexedDbPhotoBlobStore implements PhotoBlobStore, ClearablePhotoBlobStore {
  IndexedDbPhotoBlobStore();

  static const _databaseName = 'plantly_inventory_photos';
  static const _storeName = 'blobs';
  static const _imageCacheMax = 64;

  Future<web.IDBDatabase>? _db;
  final _images = <String, MemoryImage>{};

  String _key(String sha, String mime) => '$sha.${PhotoBlobStore.extensionFor(mime)}';

  /// Lazily opened and cached; a failed open is dropped so the next call
  /// retries instead of replaying the same error forever.
  Future<web.IDBDatabase> _open() {
    return _db ??= _openDatabase().catchError((Object e, StackTrace st) {
      _db = null;
      return Future<web.IDBDatabase>.error(e, st);
    });
  }

  Future<web.IDBDatabase> _openDatabase() {
    final request = web.window.indexedDB.open(_databaseName, 1);
    request.onupgradeneeded = ((web.Event _) {
      final db = request.result as web.IDBDatabase;
      if (!db.objectStoreNames.contains(_storeName)) {
        db.createObjectStore(_storeName);
      }
    }).toJS;
    return _awaitRequest(request).then((r) => r as web.IDBDatabase);
  }

  @override
  Future<String> write({
    required String sha,
    required String mime,
    required Uint8List bytes,
  }) async {
    final key = _key(sha, mime);
    final db = await _open();
    final txn = db.transaction(_storeName.toJS, 'readwrite');
    txn.objectStore(_storeName).put(bytes.toJS, key.toJS);
    await _awaitTransaction(txn);
    return key;
  }

  @override
  Future<Uint8List?> read({
    required String sha,
    required String mime,
    String? localPath,
  }) async {
    final db = await _open();
    final txn = db.transaction(_storeName.toJS, 'readonly');
    final result = await _awaitRequest(txn.objectStore(_storeName).get(_key(sha, mime).toJS));
    if (result == null || result.isUndefinedOrNull) return null;
    return (result as JSUint8Array).toDart;
  }

  @override
  Future<ImageProvider?> imageFor({
    required String sha,
    required String mime,
    String? localPath,
  }) async {
    final key = _key(sha, mime);
    final cached = _images[key];
    if (cached != null) return cached;
    final bytes = await read(sha: sha, mime: mime, localPath: localPath);
    if (bytes == null) return null;
    if (_images.length >= _imageCacheMax) _images.remove(_images.keys.first);
    return _images[key] = MemoryImage(bytes);
  }

  @override
  Future<void> clear() async {
    _images.clear();
    final db = await _open();
    final txn = db.transaction(_storeName.toJS, 'readwrite');
    txn.objectStore(_storeName).clear();
    await _awaitTransaction(txn);
  }

  static Future<JSAny?> _awaitRequest(web.IDBRequest request) {
    final completer = Completer<JSAny?>();
    request.onsuccess = ((web.Event _) => completer.complete(request.result)).toJS;
    request.onerror = ((web.Event _) {
      completer.completeError(StateError('IndexedDB request failed: ${request.error?.message}'));
    }).toJS;
    return completer.future;
  }

  /// Resolves once the write is durable (oncomplete), not merely queued.
  static Future<void> _awaitTransaction(web.IDBTransaction txn) {
    final completer = Completer<void>();
    txn.oncomplete = ((web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }).toJS;
    txn.onerror = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('IndexedDB transaction failed: ${txn.error?.message}'));
      }
    }).toJS;
    txn.onabort = ((web.Event _) {
      if (!completer.isCompleted) completer.completeError(StateError('IndexedDB transaction aborted'));
    }).toJS;
    return completer.future;
  }
}
