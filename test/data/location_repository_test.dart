import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/repositories/location_repository.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';

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
}
