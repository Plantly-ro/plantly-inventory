import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/repositories/care_event_repository.dart';
import 'package:plantly_inventory/data/repositories/photo_repository.dart';
import 'package:plantly_inventory/data/repositories/plant_repository.dart';
import 'package:plantly_inventory/data/repositories/species_repository.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';
import 'package:plantly_inventory/data/repositories/care_schedule_repository.dart';
import '../helpers/recording_reminder_sync.dart';

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

  group('PlantRepository.softDelete cascade', () {
    test('detaches the plant\'s photos with ops keyed like PlantPhotoRepository.detach', () async {
      final plant = await plants.create(nickname: 'With photo');
      final sha = 'ab' * 32;
      await PlantPhotoRepository(db: db, opLog: opLog).attach(plant.id, sha);
      final join = (await db.select(db.plantPhotos).get()).single;

      await plants.softDelete(plant.id);

      final removes = (await db.select(db.syncOps).get()).where((o) => o.field == 'removed_hlc').toList();
      expect(removes, hasLength(1));
      expect(removes.single.entity, 'plant_photos');
      expect(removes.single.entityId, join.id, reason: 'CLOUD-SYNC-CONTRACT §2.3: OR-Set removes address the add-row');
      expect((await db.select(db.plantPhotos).get()).single.removedHlc, isNotNull);
    });
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

  group('PlantRepository — OS reminder re-sync (issue #13 follow-up)', () {
    late RecordingReminderSync sync;
    late PlantRepository synced;
    late CareScheduleRepository schedules;

    setUp(() {
      sync = RecordingReminderSync(db: db);
      synced = PlantRepository(db: db, opLog: opLog, reminderSync: sync);
      schedules = CareScheduleRepository(db: db, opLog: opLog);
    });

    Future<PlantRow> plantWithSchedule(String nickname) async {
      final p = await synced.create(nickname: nickname);
      await schedules.upsert(plantId: p.id, type: 'water', baseIntervalDays: 7);
      await sync.syncFromDatabase();
      expect(sync.fake.calls, hasLength(1));
      sync.calls = 0;
      return p;
    }

    test('setNotificationsMuted re-syncs so the muted plant drops out immediately', () async {
      final p = await plantWithSchedule('Muted');
      await synced.setNotificationsMuted(p.id, true);
      expect(sync.calls, 1);
      expect(sync.fake.calls, isEmpty);
      await synced.setNotificationsMuted(p.id, false);
      expect(sync.calls, 2);
      expect(sync.fake.calls, hasLength(1));
    });

    test('softDelete re-syncs so cascade-deleted schedules stop firing', () async {
      final p = await plantWithSchedule('Gone');
      await synced.softDelete(p.id);
      expect(sync.calls, 1);
      expect(sync.fake.calls, isEmpty);
    });

    test('duplicate re-syncs so the copied schedules are scheduled', () async {
      final p = await plantWithSchedule('Original');
      await synced.duplicate(p.id, nicknameOverride: 'Copy');
      expect(sync.calls, 1);
      expect(sync.fake.calls, hasLength(2));
    });
  });

  group('PlantRepository.edit — ops only for fields that changed', () {
    Future<List<SyncOpRow>> fieldOps() async =>
        (await db.select(db.syncOps).get()).where((o) => o.field != kWholeRowField).toList();

    test('nickname-only edit → exactly one field op', () async {
      final plant = await plants.create(nickname: 'Bob', notes: 'shady corner', speciesId: 'Monstera');
      await plants.edit(plant.id, nickname: 'Bobby', notes: 'shady corner', locationId: null, speciesId: 'Monstera');
      final ops = await fieldOps();
      expect(ops, hasLength(1));
      expect(ops.single.field, 'nickname');
      expect(json.decode(ops.single.valueJson!), 'Bobby');
      final after = await plants.byId(plant.id);
      expect(after!.nickname, 'Bobby');
      expect(Hlc.parse(after.updatedHlc) > Hlc.parse(plant.updatedHlc), isTrue);
    });

    test('no-op edit → no ops and the row HLC is untouched', () async {
      final plant = await plants.create(nickname: 'Bob', notes: null, speciesId: null);
      await plants.edit(plant.id, nickname: 'Bob', notes: null, locationId: null, speciesId: null);
      expect(await fieldOps(), isEmpty);
      expect((await plants.byId(plant.id))!.updatedHlc, plant.updatedHlc);
    });

    test('two changed fields → two ops, in field order', () async {
      final plant = await plants.create(nickname: 'Bob');
      await plants.edit(plant.id, nickname: 'Bob', notes: 'new', locationId: 'loc-1', speciesId: null);
      expect((await fieldOps()).map((o) => o.field), ['notes', 'location_id']);
    });

    test('setPin: unchanged coordinates → no ops; a move → two ops', () async {
      final plant = await plants.create(nickname: 'Pinned');
      await plants.setPin(plant.id, null, null);
      expect(await fieldOps(), isEmpty);
      await plants.setPin(plant.id, 0.25, 0.5);
      expect((await fieldOps()).map((o) => o.field), ['pin_x', 'pin_y']);
    });
  });

  group('CareEventRepository.edit — ops only for fields that changed', () {
    test('dose-only edit → exactly one field op', () async {
      final plant = await plants.create(nickname: 'Fiddle');
      final event = await careEvents.record(plantId: plant.id, type: 'water', doneAt: 1000, dose: '200ml', product: 'p');
      await careEvents.edit(event.id, type: 'water', doneAt: 1000, notes: null, dose: '250ml', product: 'p');
      final ops = (await db.select(db.syncOps).get()).where((o) => o.field != kWholeRowField).toList();
      expect(ops, hasLength(1));
      expect(ops.single.field, 'dose');
      expect(json.decode(ops.single.valueJson!), '250ml');
      await careEvents.edit(event.id, type: 'water', doneAt: 1000, notes: null, dose: '250ml', product: 'p');
      expect((await db.select(db.syncOps).get()).where((o) => o.field != kWholeRowField), hasLength(1));
    });
  });
}
