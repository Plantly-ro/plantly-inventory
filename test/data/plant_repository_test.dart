import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/repositories/care_event_repository.dart';
import 'package:plantly_inventory/data/repositories/plant_repository.dart';
import 'package:plantly_inventory/data/repositories/species_repository.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';

void main() {
  group('SpeciesRepository.byScientificName', () {
    test('matches case-insensitively and tolerates duplicate rows differing by case', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final opLog = OpLogWriter(db: db, clock: HlcClock(deviceId: 'd'), tenantId: 'local');
      final species = SpeciesRepository(db: db, opLog: opLog);
      final a = await species.upsertByScientificName('Monstera deliciosa');
      expect((await species.upsertByScientificName('MONSTERA DELICIOSA', commonName: 'Swiss cheese')).id, a.id);
      expect((await species.byScientificName('  monstera Deliciosa '))!.id, a.id);
      expect(await species.displayName(a.id), 'Monstera deliciosa');
      expect(await species.displayName('free text'), 'free text');
      // Two rows differing only in case (e.g. restored from an older backup)
      // must not make the lookup throw.
      await db.into(db.species).insert(SpeciesCompanion.insert(
            id: 'dup', tenantId: 'local', scientificName: 'monstera deliciosa', commonNamesJson: '[]',
            updatedHlc: 'z', deviceId: 'd',
          ));
      expect(await species.byScientificName('Monstera deliciosa'), isNotNull);
    });
  });

  late AppDatabase db;
  late HlcClock clock;
  late OpLogWriter opLog;
  late PlantRepository plants;
  late CareEventRepository careEvents;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = HlcClock(deviceId: 'test-device');
    opLog = OpLogWriter(db: db, clock: clock, tenantId: 'tenant-local');
    plants = PlantRepository(db: db, opLog: opLog);
    careEvents = CareEventRepository(db: db, opLog: opLog);
  });

  tearDown(() async {
    await db.close();
  });

  group('PlantRepository.create', () {
    test('inserts a plant + emits a sync_ops row with field="*"', () async {
      final plant = await plants.create(nickname: 'Monstera Bob');

      expect(plant.nickname, 'Monstera Bob');
      expect(plant.tenantId, 'tenant-local');
      expect(plant.deviceId, 'test-device');
      expect(plant.deletedAt, isNull);
      expect(plant.updatedHlc, isNotEmpty);
      expect(plant.id.length, 26); // ULID

      final ops = await db.select(db.syncOps).get();
      expect(ops, hasLength(1));
      expect(ops.single.entity, 'plants');
      expect(ops.single.entityId, plant.id);
      expect(ops.single.field, kWholeRowField);
      expect(ops.single.pushedAt, isNull);
      final payload = json.decode(ops.single.valueJson!) as Map<String, dynamic>;
      expect(payload['nickname'], 'Monstera Bob');
    });

    test('pending-op count reflects each mutation', () async {
      expect(await opLog.pendingCount(), 0);
      await plants.create(nickname: 'A');
      await plants.create(nickname: 'B');
      await plants.create(nickname: 'C');
      expect(await opLog.pendingCount(), 3);
    });
  });

  group('PlantRepository.rename', () {
    test('updates nickname + bumps updated_hlc + writes a field op-log entry', () async {
      final plant = await plants.create(nickname: 'original');
      final createdHlc = Hlc.parse(plant.updatedHlc);

      await plants.rename(plant.id, 'renamed');
      final after = await plants.byId(plant.id);
      expect(after!.nickname, 'renamed');
      final newHlc = Hlc.parse(after.updatedHlc);
      expect(newHlc > createdHlc, isTrue);

      final ops = await db.select(db.syncOps).get();
      expect(ops, hasLength(2));
      final renameOp = ops.last;
      expect(renameOp.entity, 'plants');
      expect(renameOp.entityId, plant.id);
      expect(renameOp.field, 'nickname');
      expect(json.decode(renameOp.valueJson!), 'renamed');
    });
  });

  group('PlantRepository.softDelete', () {
    test('sets deleted_at + writes a tombstone op + hides from watchAll', () async {
      final plant = await plants.create(nickname: 'goner');
      await plants.softDelete(plant.id);

      final row = await plants.byId(plant.id);
      expect(row!.deletedAt, isNotNull);

      final ops = await db.select(db.syncOps).get();
      final tomb = ops.last;
      expect(tomb.field, kTombstoneField);
      expect(tomb.valueJson, isNull);

      final visible = await plants.watchAll().first;
      expect(visible, isEmpty);
    });
  });

  group('CareEventRepository.record', () {
    test('appends an event + its op-log entry under the given plant', () async {
      final plant = await plants.create(nickname: 'Fiddle');
      final event = await careEvents.record(
        plantId: plant.id,
        type: 'water',
        notes: '250ml from the can',
      );

      expect(event.plantId, plant.id);
      expect(event.type, 'water');
      expect(event.notes, '250ml from the can');

      final ops = await db.select(db.syncOps).get();
      expect(ops, hasLength(2));
      final careOp = ops.last;
      expect(careOp.entity, 'care_events');
      expect(careOp.entityId, event.id);
      expect(careOp.field, kWholeRowField);
    });

    test('watchForPlant streams newest-first', () async {
      final plant = await plants.create(nickname: 'Snake');
      await careEvents.record(plantId: plant.id, type: 'water', doneAt: 1000);
      await careEvents.record(plantId: plant.id, type: 'mist', doneAt: 2000);
      final rows = await careEvents.watchForPlant(plant.id).first;
      expect(rows.map((e) => e.doneAt).toList(), [2000, 1000]);
    });
  });

  group('OpLog pending push', () {
    test('setting pushed_at removes rows from pending count', () async {
      final plant = await plants.create(nickname: 'counted');
      expect(await opLog.pendingCount(), 1);
      await (db.update(db.syncOps)..where((s) => s.entityId.equals(plant.id))).write(
        SyncOpsCompanion(pushedAt: Value(DateTime.now().millisecondsSinceEpoch)),
      );
      expect(await opLog.pendingCount(), 0);
    });
  });
}
