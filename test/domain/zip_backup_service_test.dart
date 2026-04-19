import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
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
    final photos = PhotoRepository(db: db, opLog: opLog, rootOverride: tmp);
    final json = BackupService(db: db);
    return (
      db: db,
      opLog: opLog,
      plants: PlantRepository(db: db, opLog: opLog),
      photos: photos,
      joins: PlantPhotoRepository(db: db, opLog: opLog),
      zip: ZipBackupService(db: db, backup: json),
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
      photoStoreRoot: b.tmp,
    );
    expect(result.json.rowsImported['plants'], 1);
    expect(result.photosRestored, 1);

    // The restored photo bytes live under the correct sharded path.
    final restoredPath = '${b.tmp.path}/${sha.substring(0, 2)}/$sha.jpg';
    expect(File(restoredPath).existsSync(), isTrue);
    expect(await File(restoredPath).readAsBytes(), _bytes('image-bytes'));
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
        photoStoreRoot: a.tmp,
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
      photoStoreRoot: b.tmp,
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
      photoStoreRoot: b.tmp,
    );
    expect(r.photosRestored, 0);
    expect(r.json.rowsImported['plants'], 1);
  });
}
