import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/photo_blob_store.dart';
import 'package:plantly_inventory/data/photo_blob_store_io.dart';

Uint8List _bytes(String s) => Uint8List.fromList(s.codeUnits);

const _sha = 'ab' 'cd' 'ef0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab';

void main() {
  group('PhotoBlobStore mime <-> extension', () {
    test('maps known mimes both ways and defaults to jpeg', () {
      expect(PhotoBlobStore.extensionFor('image/png'), 'png');
      expect(PhotoBlobStore.extensionFor('image/webp'), 'webp');
      expect(PhotoBlobStore.extensionFor('image/heic'), 'heic');
      expect(PhotoBlobStore.extensionFor('image/jpeg'), 'jpg');
      expect(PhotoBlobStore.extensionFor('application/octet-stream'), 'jpg');
      expect(PhotoBlobStore.mimeForExtension('PNG'), 'image/png');
      expect(PhotoBlobStore.mimeForExtension('jpg'), 'image/jpeg');
      expect(PhotoBlobStore.mimeForExtension('bin'), 'image/jpeg');
    });
  });

  group('InMemoryPhotoBlobStore', () {
    late InMemoryPhotoBlobStore store;
    setUp(() => store = InMemoryPhotoBlobStore());

    test('round-trips bytes and keys by sha + extension', () async {
      final key = await store.write(sha: _sha, mime: 'image/png', bytes: _bytes('png-bytes'));
      expect(key, '$_sha.png');
      expect(await store.read(sha: _sha, mime: 'image/png'), _bytes('png-bytes'));
      expect(await store.read(sha: _sha, mime: 'image/jpeg'), isNull);
    });

    test('second write of the same sha is a no-op', () async {
      await store.write(sha: _sha, mime: 'image/jpeg', bytes: _bytes('first'));
      await store.write(sha: _sha, mime: 'image/jpeg', bytes: _bytes('second'));
      expect(await store.read(sha: _sha, mime: 'image/jpeg'), _bytes('first'));
    });

    test('imageFor yields a MemoryImage, or null when missing', () async {
      expect(await store.imageFor(sha: _sha, mime: 'image/jpeg'), isNull);
      await store.write(sha: _sha, mime: 'image/jpeg', bytes: _bytes('x'));
      expect(await store.imageFor(sha: _sha, mime: 'image/jpeg'), isA<MemoryImage>());
    });
  });

  group('IoPhotoBlobStore', () {
    late Directory tmp;
    late IoPhotoBlobStore store;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('plantly-blob-');
      store = IoPhotoBlobStore(root: tmp);
    });
    tearDown(() => tmp.delete(recursive: true));

    test('writes to the sharded path and returns it as local_path', () async {
      final path = await store.write(sha: _sha, mime: 'image/jpeg', bytes: _bytes('hello'));
      expect(path, '${tmp.path}/${_sha.substring(0, 2)}/$_sha.jpg');
      expect(File(path).readAsBytesSync(), _bytes('hello'));
      expect(await store.read(sha: _sha, mime: 'image/jpeg', localPath: path), _bytes('hello'));
      expect(await store.imageFor(sha: _sha, mime: 'image/jpeg', localPath: path), isA<FileImage>());
    });

    test('falls back to the canonical path when local_path is foreign', () async {
      // A row restored from another device carries that device's path.
      await store.write(sha: _sha, mime: 'image/jpeg', bytes: _bytes('hello'));
      final bytes = await store.read(
        sha: _sha,
        mime: 'image/jpeg',
        localPath: '/data/user/0/ro.plantly.inventory/files/photos/ab/$_sha.jpg',
      );
      expect(bytes, _bytes('hello'));
    });

    test('missing blob reads as null', () async {
      expect(await store.read(sha: _sha, mime: 'image/jpeg', localPath: null), isNull);
      expect(await store.imageFor(sha: _sha, mime: 'image/jpeg', localPath: null), isNull);
    });
  });
}
