import 'package:drift/drift.dart';
import 'package:ulid/ulid.dart';

import '../../sync/op_log.dart';
import '../database/app_database.dart';
import 'plant_repository.dart' show cascadeDeleteSchedules;

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

  /// Gift a plant away. Records a `gift` transaction and soft-deletes the
  /// plant (so it disappears from the user's active collection but the
  /// ledger still has a row).
  Future<InventoryTransactionRow> gift({
    required String plantId,
    String? counterparty,
    String? notes,
    int? atMs,
  }) async {
    return _close(
      plantId: plantId,
      type: 'gift',
      counterparty: counterparty,
      notes: notes,
      atMs: atMs,
    );
  }

  /// Record a sale. `amountMinor` is cents/bani; `currency` ISO-4217.
  Future<InventoryTransactionRow> sell({
    required String plantId,
    int? amountMinor,
    String? currency,
    String? counterparty,
    String? notes,
    int? atMs,
  }) async {
    return _close(
      plantId: plantId,
      type: 'sale',
      amountMinor: amountMinor,
      currency: currency,
      counterparty: counterparty,
      notes: notes,
      atMs: atMs,
    );
  }

  /// Mark a plant dead. Sets `plants.status = 'dead'` and soft-deletes
  /// the plant row alongside the ledger entry.
  Future<InventoryTransactionRow> markDead({
    required String plantId,
    String? notes,
    int? atMs,
  }) async {
    return _close(
      plantId: plantId,
      type: 'death',
      notes: notes,
      atMs: atMs,
    );
  }

  /// Shared "close the book on a plant" path. Records a ledger entry in
  /// the same transaction as the soft-delete so we can't end up with a
  /// ledger row pointing at a still-active plant.
  Future<InventoryTransactionRow> _close({
    required String plantId,
    required String type,
    String? counterparty,
    String? notes,
    int? amountMinor,
    String? currency,
    int? atMs,
  }) async {
    final ts = atMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    return db.transaction(() async {
      final txId = Ulid().toString();
      final hlc = await opLog.recordCreate(
        entity: 'inventory_transactions',
        entityId: txId,
        value: {
          'id': txId,
          'tenant_id': opLog.tenantId,
          'type': type,
          'plant_id': plantId,
          'at': ts,
          'notes': notes,
          'counterparty': counterparty,
          'amount_minor': amountMinor,
          'currency': currency,
        },
      );
      await db.into(db.inventoryTransactions).insert(
            InventoryTransactionsCompanion.insert(
              id: txId,
              tenantId: opLog.tenantId,
              type: type,
              at: ts,
              plantId: Value(plantId),
              notes: Value(notes),
              counterparty: Value(counterparty),
              amountMinor: Value(amountMinor),
              currency: Value(currency),
              updatedHlc: hlc.encode(),
              deviceId: opLog.clock.deviceId,
            ),
          );
      // Soft-delete the plant so it leaves the main grid, plus flip
      // `status` to 'dead' for death events (useful reporting signal).
      final plantHlc = await opLog.recordTombstone(entity: 'plants', entityId: plantId);
      await (db.update(db.plants)..where((p) => p.id.equals(plantId))).write(
        PlantsCompanion(
          status: type == 'death' ? const Value('dead') : const Value.absent(),
          deletedAt: Value(ts),
          updatedHlc: Value(plantHlc.encode()),
          deviceId: Value(opLog.clock.deviceId),
        ),
      );
      // Cascade: schedules stop firing reminders, stop showing on Home /
      // Calendar, drop out of ReminderSync.
      await cascadeDeleteSchedules(db, opLog, plantId, ts);
      return (await (db.select(db.inventoryTransactions)
                ..where((r) => r.id.equals(txId)))
              .getSingle());
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
