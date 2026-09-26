import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/repositories/location_repository.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';
import 'package:plantly_inventory/data/repositories/care_schedule_repository.dart';
import 'package:plantly_inventory/data/repositories/plant_repository.dart';
import '../helpers/recording_reminder_sync.dart';

void main() {
  late AppDatabase db;
  late LocationRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final clock = HlcClock(deviceId: 'test-device');
    final opLog = OpLogWriter(db: db, clock: clock, tenantId: 'tenant-local');
    repo = LocationRepository(db: db, opLog: opLog);
  });

  tearDown(() => db.close());

  group('LocationRepository.create', () {
    test('assigns a ULID + stamps hlc + writes op-log row', () async {
      final row = await repo.create(name: 'Living room', kind: 'room');
      expect(row.id.length, 26);
      expect(row.name, 'Living room');
      expect(row.kind, 'room');
      expect(row.parentId, isNull);
      expect(row.updatedHlc, isNotEmpty);
      final ops = await db.select(db.syncOps).get();
      expect(ops, hasLength(1));
      expect(ops.single.entity, 'locations');
    });

    test('soft-delete flips deleted_at + emits tombstone', () async {
      final row = await repo.create(name: 'Doomed', kind: 'shelf');
      await repo.softDelete(row.id);
      final after = await repo.byId(row.id);
      expect(after!.deletedAt, isNotNull);
      final ops = await db.select(db.syncOps).get();
      expect(ops.last.field, '__tombstone__');
    });
  });

  group('buildTree', () {
    test('builds a hierarchy from a flat list', () async {
      final home = await repo.create(name: 'Home', kind: 'home');
      final living = await repo.create(name: 'Living room', kind: 'room', parentId: home.id);
      final shelf = await repo.create(name: 'South shelf', kind: 'shelf', parentId: living.id);
      await repo.create(name: 'Balcony', kind: 'outdoor_bed');

      final rows = await repo.watchAll().first;
      final tree = buildTree(rows);
      expect(tree, hasLength(2)); // Home, Balcony

      final homeNode = tree.firstWhere((n) => n.row.id == home.id);
      expect(homeNode.children, hasLength(1));
      final livingNode = homeNode.children.first;
      expect(livingNode.row.id, living.id);
      expect(livingNode.children, hasLength(1));
      expect(livingNode.children.single.row.id, shelf.id);
    });

    test('orphan rows (missing parent) do not silently hide siblings', () async {
      final home = await repo.create(name: 'Home', kind: 'home');
      // Create an orphan by deleting its parent AFTER creating a child.
      final ghost = await repo.create(name: 'Ghost room', kind: 'room');
      await repo.create(name: 'Ghost shelf', kind: 'shelf', parentId: ghost.id);
      await repo.softDelete(ghost.id);

      final rows = await repo.watchAll().first;
      final tree = buildTree(rows);
      // Home is still a root — the orphan branch (ghost shelf under deleted
      // parent) is pruned, but home remains visible.
      expect(tree.map((n) => n.row.id), contains(home.id));
    });
  });

  group('LocationRepository — OS reminder re-sync (issue #13 follow-up)', () {
    late RecordingReminderSync sync;
    late LocationRepository synced;
    late LocationRow loc;

    setUp(() async {
      final clock = HlcClock(deviceId: 'test-device');
      final opLog = OpLogWriter(db: db, clock: clock, tenantId: 'tenant-local');
      sync = RecordingReminderSync(db: db);
      synced = LocationRepository(db: db, opLog: opLog, reminderSync: sync);
      loc = await synced.create(name: 'Balcony', kind: 'room');
      final plants = PlantRepository(db: db, opLog: opLog);
      final p = await plants.create(nickname: 'Basil', locationId: loc.id);
      await CareScheduleRepository(db: db, opLog: opLog).upsert(plantId: p.id, type: 'water', baseIntervalDays: 3);
      await sync.syncFromDatabase();
      expect(sync.fake.calls, hasLength(1));
      sync.calls = 0;
    });

    test('setNotificationsMuted re-syncs so every plant in the space goes quiet', () async {
      await synced.setNotificationsMuted(loc.id, true);
      expect(sync.calls, 1);
      expect(sync.fake.calls, isEmpty);
    });

    test('softDelete re-syncs', () async {
      await synced.softDelete(loc.id);
      expect(sync.calls, 1);
    });
  });
}
