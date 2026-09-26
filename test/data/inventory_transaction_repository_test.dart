import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/repositories/inventory_transaction_repository.dart';
import 'package:plantly_inventory/data/repositories/plant_repository.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';
import 'package:plantly_inventory/data/repositories/care_schedule_repository.dart';
import '../helpers/recording_reminder_sync.dart';

void main() {
  late AppDatabase db;
  late PlantRepository plants;
  late InventoryTransactionRepository inventory;
  late OpLogWriter opLog;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final clock = HlcClock(deviceId: 'test-device');
    opLog = OpLogWriter(db: db, clock: clock, tenantId: 'tenant-local');
    plants = PlantRepository(db: db, opLog: opLog);
    inventory = InventoryTransactionRepository(
      db: db,
      opLog: opLog,
      plants: PlantsTableForWrites(db: db, opLog: opLog),
    );
  });

  tearDown(() => db.close());

  group('propagate', () {
    test('creates child plant + transaction linking parent → child', () async {
      final parent = await plants.create(nickname: 'Monstera Bob');
      final result = await inventory.propagate(
        parentId: parent.id,
        childNickname: 'Monstera Bob Jr.',
        notes: 'propagated from node 3',
      );

      expect(result.child.nickname, 'Monstera Bob Jr.');
      expect(result.child.source, 'propagation');
      expect(result.tx.type, 'propagation');
      expect(result.tx.parentPlantId, parent.id);
      expect(result.tx.childPlantId, result.child.id);
      expect(result.tx.notes, 'propagated from node 3');

      // Both plants are visible to watchAll.
      final live = await plants.watchAll().first;
      expect(live.map((p) => p.id), containsAll([parent.id, result.child.id]));
    });

    test('emits op-log rows for plants + inventory_transactions', () async {
      final parent = await plants.create(nickname: 'P');
      final beforeOps = await db.select(db.syncOps).get();
      await inventory.propagate(parentId: parent.id, childNickname: 'C');
      final afterOps = await db.select(db.syncOps).get();
      final added = afterOps.length - beforeOps.length;
      // 1 plant create + 1 inventory_transactions create = 2 new ops.
      expect(added, 2);
      final entities = afterOps.skip(beforeOps.length).map((o) => o.entity).toSet();
      expect(entities, {'plants', 'inventory_transactions'});
    });
  });

  group('watchForPlant', () {
    test('returns transactions where the plant is parent, child, or self', () async {
      final p = await plants.create(nickname: 'P');
      final r1 = await inventory.propagate(parentId: p.id, childNickname: 'C1');
      final r2 = await inventory.propagate(parentId: p.id, childNickname: 'C2');

      final parentView = await inventory.watchForPlant(p.id).first;
      expect(parentView.map((t) => t.id).toSet(), {r1.tx.id, r2.tx.id});

      final childView = await inventory.watchForPlant(r1.child.id).first;
      expect(childView.map((t) => t.id), [r1.tx.id]);
    });
  });

  group('InventoryTransactionRepository — OS reminder re-sync (issue #13 follow-up)', () {
    test('markDead cascade-deletes schedules and re-syncs so their alarms are cancelled', () async {
      final sync = RecordingReminderSync(db: db);
      final synced = InventoryTransactionRepository(
        db: db,
        opLog: opLog,
        plants: PlantsTableForWrites(db: db, opLog: opLog),
        reminderSync: sync,
      );
      final p = await plants.create(nickname: 'Doomed');
      await CareScheduleRepository(db: db, opLog: opLog).upsert(plantId: p.id, type: 'water', baseIntervalDays: 7);
      await sync.syncFromDatabase();
      expect(sync.fake.calls, hasLength(1));
      sync.calls = 0;

      await synced.markDead(plantId: p.id);
      expect(sync.calls, 1);
      expect(sync.fake.calls, isEmpty);
    });
  });
}
