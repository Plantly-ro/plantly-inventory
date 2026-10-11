import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/photo_blob_store_io.dart';
import 'package:plantly_inventory/data/repositories/photo_repository.dart';
import 'package:plantly_inventory/data/repositories/plant_repository.dart';
import 'package:plantly_inventory/domain/services/backup_service.dart';
import 'package:plantly_inventory/domain/services/zip_backup_service.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _bytes(String s) => Uint8List.fromList(s.codeUnits);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const secret = 'secret-passphrase';

  Future<
      ({
        AppDatabase db,
        OpLogWriter opLog,
        PlantRepository plants,
        PhotoRepository photos,
        PlantPhotoRepository joins,
        ZipBackupService zip,
        BackupService json,
        Directory tmp,
      })> stack() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final clock = HlcClock(deviceId: 'test-device');
    final opLog = OpLogWriter(db: db, clock: clock, tenantId: 'tenant-local');
    final tmp = await Directory.systemTemp.createTemp('plantly-zip-');
    final store = IoPhotoBlobStore(root: tmp);
    final photos = PhotoRepository(db: db, opLog: opLog, store: store);
    final json = BackupService(db: db, tenantId: 'tenant-local');
    return (
      db: db,
      opLog: opLog,
      plants: PlantRepository(db: db, opLog: opLog),
      photos: photos,
      joins: PlantPhotoRepository(db: db, opLog: opLog),
      zip: ZipBackupService(db: db, backup: json, photos: store),
      json: json,
      tmp: tmp,
    );
  }

  test('exportZip round-trips JSON + photo bytes', () async {
    final a = await stack();
    addTearDown(() async {
      await a.db.close();
      await a.tmp.delete(recursive: true);
    });

    final p = await a.plants.create(nickname: 'Monstera');
    final sha = await a.photos.saveBytes(_bytes('image-bytes'));
    await a.joins.attach(p.id, sha);

    final bytes = await a.zip.exportZip(secret: secret);
    expect(bytes.length, greaterThan(100));

    // Import into a fresh DB + store.
    final b = await stack();
    addTearDown(() async {
      await b.db.close();
      await b.tmp.delete(recursive: true);
    });

    final result = await b.zip.importZip(
      bytes: bytes,
      secret: secret,
      opLog: b.opLog,
    );
    expect(result.json.rowsImported['plants'], 1);
    expect(result.photosRestored, 1);

    // The restored photo bytes live under the correct sharded path.
    final restoredPath = '${b.tmp.path}/${sha.substring(0, 2)}/$sha.jpg';
    expect(File(restoredPath).existsSync(), isTrue);
    expect(await File(restoredPath).readAsBytes(), _bytes('image-bytes'));
    // Bytes came with the ZIP → queued for upload to this collection.
    expect((await b.db.select(b.db.photos).getSingle()).remoteState, 'local');
  });

  test('exportZip bundles only the active tenant\'s photo bytes', () async {
    final a = await stack();
    addTearDown(() async {
      await a.db.close();
      await a.tmp.delete(recursive: true);
    });
    final mine = await a.plants.create(nickname: 'Mine');
    final shaMine = await a.photos.saveBytes(_bytes('mine'));
    await a.joins.attach(mine.id, shaMine);

    // Another tenant on the same device + store (a parked account).
    final parked = OpLogWriter(db: a.db, clock: HlcClock(deviceId: 'test-device'), tenantId: 'col-parked');
    final theirs = await PlantRepository(db: a.db, opLog: parked).create(nickname: 'Theirs');
    final shaTheirs = await PhotoRepository(db: a.db, opLog: parked, store: IoPhotoBlobStore(root: a.tmp))
        .saveBytes(_bytes('theirs'));
    await PlantPhotoRepository(db: a.db, opLog: parked).attach(theirs.id, shaTheirs);

    final names = ZipDecoder().decodeBytes(await a.zip.exportZip(secret: secret)).files.map((f) => f.name).toList();
    expect(names, contains('photos/${shaMine.substring(0, 2)}/$shaMine.jpg'));
    expect(names.where((n) => n.contains(shaTheirs)), isEmpty);
    expect(names.where((n) => n.startsWith('photos/')), hasLength(1));
  });

  test('wrong secret rejects the zip import via the JSON layer', () async {
    final a = await stack();
    addTearDown(() async {
      await a.db.close();
      await a.tmp.delete(recursive: true);
    });

    await a.plants.create(nickname: 'Monstera');
    final bytes = await a.zip.exportZip(secret: secret);

    await expectLater(
      a.zip.importZip(
        bytes: bytes,
        secret: 'wrong',
        opLog: a.opLog,
      ),
      throwsA(isA<BackupSignatureError>()),
    );
  });

  test('importZip rejects path-traversal entries outside the photo root', () async {
    final a = await stack();
    addTearDown(() async {
      await a.db.close();
      await a.tmp.delete(recursive: true);
    });

    // Produce a valid signed JSON document the importer will accept.
    await a.plants.create(nickname: 'Monstera');
    final legit = await a.zip.exportZip(secret: secret);
    final legitArchive = ZipDecoder().decodeBytes(legit);
    final jsonFile = legitArchive.files.firstWhere((f) => f.name == 'plantly.backup.json');

    // Stitch a malicious archive: same JSON, plus a `photos/../../pwn` entry.
    final malicious = Archive()
      ..addFile(ArchiveFile.bytes(
        'plantly.backup.json',
        Uint8List.fromList(jsonFile.content as List<int>),
      ))
      ..addFile(ArchiveFile.bytes(
        'photos/../../pwn.txt',
        Uint8List.fromList('pwn'.codeUnits),
      ));
    final bytes = Uint8List.fromList(ZipEncoder().encode(malicious));

    final b = await stack();
    addTearDown(() async {
      await b.db.close();
      await b.tmp.delete(recursive: true);
    });
    final sibling = Directory('${b.tmp.path}/../pwn-target')..createSync();
    addTearDown(() async {
      if (sibling.existsSync()) await sibling.delete(recursive: true);
    });

    final r = await b.zip.importZip(
      bytes: bytes,
      secret: secret,
      opLog: b.opLog,
    );

    expect(r.photosRestored, 0);
    // The escape attempt must not have produced any file outside the root.
    expect(File('${sibling.path}/pwn.txt').existsSync(), isFalse);
    expect(File('${b.tmp.parent.path}/pwn.txt').existsSync(), isFalse);
  });

  test('export without photos still produces a valid zip', () async {
    final a = await stack();
    addTearDown(() async {
      await a.db.close();
      await a.tmp.delete(recursive: true);
    });

    await a.plants.create(nickname: 'No pics');
    final bytes = await a.zip.exportZip(secret: secret);
    expect(bytes, isNotEmpty);

    final b = await stack();
    addTearDown(() async {
      await b.db.close();
      await b.tmp.delete(recursive: true);
    });

    final r = await b.zip.importZip(
      bytes: bytes,
      secret: secret,
      opLog: b.opLog,
    );
    expect(r.photosRestored, 0);
    expect(r.json.rowsImported['plants'], 1);
  });

  test('importZip drops photo entries whose bytes do not match the sha', () async {
    final a = await stack();
    addTearDown(() async {
      await a.db.close();
      await a.tmp.delete(recursive: true);
    });
    await a.plants.create(nickname: 'Monstera');
    final legit = await a.zip.exportZip(secret: secret);
    final jsonFile = ZipDecoder().decodeBytes(legit).files.firstWhere((f) => f.name == 'plantly.backup.json');

    const fakeSha = 'ab' 'cd' 'ef0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab';
    final forged = Archive()
      ..addFile(ArchiveFile.bytes(
        'plantly.backup.json',
        Uint8List.fromList(jsonFile.content as List<int>),
      ))
      ..addFile(ArchiveFile.bytes('photos/ab/$fakeSha.jpg', Uint8List.fromList('junk'.codeUnits)));

    final b = await stack();
    addTearDown(() async {
      await b.db.close();
      await b.tmp.delete(recursive: true);
    });
    final r = await b.zip.importZip(
      bytes: Uint8List.fromList(ZipEncoder().encode(forged)),
      secret: secret,
      opLog: b.opLog,
    );
    expect(r.photosRestored, 0);
    expect(File('${b.tmp.path}/ab/$fakeSha.jpg').existsSync(), isFalse);
  });
}
