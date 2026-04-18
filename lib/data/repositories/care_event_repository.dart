import 'package:drift/drift.dart';
import 'package:ulid/ulid.dart';

import '../../sync/op_log.dart';
import '../database/app_database.dart';

/// CRUD for the `care_events` table. A care event is append-only by design
/// — there is no update flow, only create (record_care) and soft-delete
/// (undo_care). Adaptive scheduling (PLAN.md §Phase 1) will read the last
/// N events per (plant, type) and compute the next interval.
class CareEventRepository {
  CareEventRepository({required this.db, required this.opLog});

  final AppDatabase db;
  final OpLogWriter opLog;

  Stream<List<CareEventRow>> watchForPlant(String plantId) {
    return (db.select(db.careEvents)
          ..where((e) =>
              e.tenantId.equals(opLog.tenantId) &
              e.plantId.equals(plantId) &
              e.deletedAt.isNull())
          ..orderBy([(e) => OrderingTerm(expression: e.doneAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<CareEventRow> record({
    required String plantId,
    required String type,
    int? doneAt,
    String? notes,
    String? dose,
    String? product,
    String? photoSha,
  }) async {
    final ts = doneAt ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    return db.transaction(() async {
      final id = Ulid().toString();
      final value = {
        'id': id,
        'tenant_id': opLog.tenantId,
        'plant_id': plantId,
        'type': type,
        'done_at': ts,
        'notes': notes,
        'dose': dose,
        'product': product,
        'photo_sha': photoSha,
      };
      final hlc = await opLog.recordCreate(
        entity: 'care_events',
        entityId: id,
        value: value,
      );
      final row = CareEventsCompanion.insert(
        id: id,
        tenantId: opLog.tenantId,
        plantId: plantId,
        type: type,
        doneAt: ts,
        notes: Value(notes),
        dose: Value(dose),
        product: Value(product),
        photoSha: Value(photoSha),
        updatedHlc: hlc.encode(),
        deletedAt: const Value.absent(),
        deviceId: opLog.clock.deviceId,
      );
      await db.into(db.careEvents).insert(row);
      return (await (db.select(db.careEvents)..where((e) => e.id.equals(id))).getSingle());
    });
  }

  Future<void> undo(String id) async {
    return db.transaction(() async {
      final hlc = await opLog.recordTombstone(entity: 'care_events', entityId: id);
      await (db.update(db.careEvents)..where((e) => e.id.equals(id))).write(
        CareEventsCompanion(
          deletedAt: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
          updatedHlc: Value(hlc.encode()),
          deviceId: Value(opLog.clock.deviceId),
        ),
      );
    });
  }
}
