import 'package:drift/drift.dart';
import 'package:ulid/ulid.dart';

import '../../sync/op_log.dart';
import '../database/app_database.dart';

/// Ledger over `inventory_transactions` (PLAN.md §"Schema non-negotiables").
///
/// Phase 1 only needs propagation (parent → child) end-to-end; gifts /
/// sales / deaths are one-call conveniences that land with their UI.
class InventoryTransactionRepository {
  InventoryTransactionRepository({required this.db, required this.opLog, required this.plants});

  final AppDatabase db;
  final OpLogWriter opLog;
  final PlantsTableForWrites plants;

  /// Create a child plant + record the propagation transaction linking
  /// parent → child. Both rows land in one transaction so a crash never
  /// leaves an orphan child or a dangling transaction.
  Future<({PlantRow child, InventoryTransactionRow tx})> propagate({
    required String parentId,
    required String childNickname,
    String? notes,
    int? atMs,
  }) async {
    final ts = atMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    return db.transaction(() async {
      final child = await plants.createInTx(
        nickname: childNickname,
        notes: notes,
        source: 'propagation',
      );
      final txId = Ulid().toString();
      final hlc = await opLog.recordCreate(
        entity: 'inventory_transactions',
        entityId: txId,
        value: {
          'id': txId,
          'tenant_id': opLog.tenantId,
          'type': 'propagation',
          'parent_plant_id': parentId,
          'child_plant_id': child.id,
          'at': ts,
          'notes': notes,
        },
      );
      await db.into(db.inventoryTransactions).insert(
            InventoryTransactionsCompanion.insert(
              id: txId,
              tenantId: opLog.tenantId,
              type: 'propagation',
              at: ts,
              parentPlantId: Value(parentId),
              childPlantId: Value(child.id),
              notes: Value(notes),
              updatedHlc: hlc.encode(),
              deviceId: opLog.clock.deviceId,
            ),
          );
      final tx = (await (db.select(db.inventoryTransactions)
                ..where((r) => r.id.equals(txId)))
              .getSingle());
      return (child: child, tx: tx);
    });
  }

  Stream<List<InventoryTransactionRow>> watchForPlant(String plantId) {
    return (db.select(db.inventoryTransactions)
          ..where((r) =>
              r.tenantId.equals(opLog.tenantId) &
              r.deletedAt.isNull() &
              (r.plantId.equals(plantId) |
                  r.parentPlantId.equals(plantId) |
                  r.childPlantId.equals(plantId)))
          ..orderBy([(r) => OrderingTerm(expression: r.at, mode: OrderingMode.desc)]))
        .watch();
  }
}

/// Thin write surface on `plants` that the transaction repo can call
/// inside its own `db.transaction`. Avoids nesting `db.transaction` calls
/// (Drift refuses to nest transactions on the same executor).
class PlantsTableForWrites {
  PlantsTableForWrites({required this.db, required this.opLog});
  final AppDatabase db;
  final OpLogWriter opLog;

  Future<PlantRow> createInTx({
    required String nickname,
    String? notes,
    String? source,
  }) async {
    final id = Ulid().toString();
    final hlc = await opLog.recordCreate(
      entity: 'plants',
      entityId: id,
      value: {
        'id': id,
        'tenant_id': opLog.tenantId,
        'nickname': nickname,
        'status': 'alive',
        'notes': notes,
        'source': source,
      },
    );
    await db.into(db.plants).insert(
          PlantsCompanion.insert(
            id: id,
            tenantId: opLog.tenantId,
            nickname: nickname,
            status: 'alive',
            notes: Value(notes),
            source: Value(source),
            updatedHlc: hlc.encode(),
            deviceId: opLog.clock.deviceId,
          ),
        );
    return (await (db.select(db.plants)..where((p) => p.id.equals(id))).getSingle());
  }
}
