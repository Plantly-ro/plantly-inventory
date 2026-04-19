import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/repositories/photo_repository.dart';
import 'package:plantly_inventory/data/repositories/plant_repository.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';

Uint8List _bytes(String s) => Uint8List.fromList(List<int>.generate(s.length, (i) => s.codeUnitAt(i)));

void main() {
  late AppDatabase db;
  late OpLogWriter opLog;
  late PhotoRepository photos;
  late PlantPhotoRepository joins;
  late PlantRepository plants;
  late Directory tmp;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final clock = HlcClock(deviceId: 'test-device');
    opLog = OpLogWriter(db: db, clock: clock, tenantId: 'tenant-local');
    tmp = await Directory.systemTemp.createTemp('plantly-photos-');
    photos = PhotoRepository(db: db, opLog: opLog, rootOverride: tmp);
    joins = PlantPhotoRepository(db: db, opLog: opLog);
    plants = PlantRepository(db: db, opLog: opLog);
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  group('PhotoRepository.saveBytes', () {
    test('stores bytes under sha256 path + inserts photos row', () async {
      final sha = await photos.saveBytes(_bytes('hello world'));
      expect(sha, hasLength(64));
      final row = await photos.byHash(sha);
      expect(row, isNotNull);
      expect(row!.bytes, 11);
      expect(row.mime, 'image/jpeg');
      expect(row.localPath, contains('${sha.substring(0, 2)}/$sha.jpg'));
      expect(File(row.localPath!).existsSync(), isTrue);
    });

    test('is idempotent on identical bytes — one photos row', () async {
      final a = await photos.saveBytes(_bytes('dup'));
      final b = await photos.saveBytes(_bytes('dup'));
      expect(a, b);
      final all = await db.select(db.photos).get();
      expect(all, hasLength(1));
    });

    test('different bytes produce different hashes', () async {
      final a = await photos.saveBytes(_bytes('one'));
      final b = await photos.saveBytes(_bytes('two'));
      expect(a, isNot(equals(b)));
    });
  });

  group('PlantPhotoRepository OR-Set', () {
    test('attach → detach → attach resolves to present again', () async {
      final plant = await plants.create(nickname: 'M');
      final sha = await photos.saveBytes(_bytes('a'));

      await joins.attach(plant.id, sha);
      expect(await joins.currentAttached(plant.id), [sha]);

      await joins.detach(plant.id, sha);
      expect(await joins.currentAttached(plant.id), isEmpty);

      await joins.attach(plant.id, sha);
      expect(await joins.currentAttached(plant.id), [sha]);
    });

    test('attach is idempotent across multiple calls (returns single hash)', () async {
      final plant = await plants.create(nickname: 'M');
      final sha = await photos.saveBytes(_bytes('a'));
      await joins.attach(plant.id, sha);
      await joins.attach(plant.id, sha);
      final live = await joins.currentAttached(plant.id);
      expect(live, [sha]);
    });

    test('multiple photos on one plant are ordered by display_order', () async {
      final plant = await plants.create(nickname: 'M');
      final s1 = await photos.saveBytes(_bytes('a'));
      final s2 = await photos.saveBytes(_bytes('b'));
      final s3 = await photos.saveBytes(_bytes('c'));
      await joins.attach(plant.id, s1, displayOrder: 2);
      await joins.attach(plant.id, s2, displayOrder: 0);
      await joins.attach(plant.id, s3, displayOrder: 1);
      final live = await joins.currentAttached(plant.id);
      expect(live, [s2, s3, s1]);
    });

    test('watchAttached streams updates as attach/detach happen', () async {
      final plant = await plants.create(nickname: 'M');
      final sha = await photos.saveBytes(_bytes('x'));
      expect(await joins.watchAttached(plant.id).first, isEmpty);
      await joins.attach(plant.id, sha);
      expect(await joins.watchAttached(plant.id).first, [sha]);
    });
  });
}
