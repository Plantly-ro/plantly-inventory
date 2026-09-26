import 'package:drift/drift.dart';
import 'package:ulid/ulid.dart';

import '../../notifications/reminder_sync.dart';
import '../../sync/op_log.dart';
import '../database/app_database.dart';
import 'care_schedule_repository.dart';

/// CRUD for the `care_events` table. A care event is append-only by design
/// — there is no update flow, only create (record_care) and soft-delete
/// (undo_care). After each record we (a) refresh the adaptive schedule,
/// (b) re-sync OS notifications so pushed reminders track reality.
class CareEventRepository {
  CareEventRepository({
    required this.db,
    required this.opLog,
    this.schedules,
    this.reminderSync,
  });

  final AppDatabase db;
  final OpLogWriter opLog;
  final CareScheduleRepository? schedules;
  final ReminderSync? reminderSync;

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
    int snoozedBeforeDone = 0,
  }) async {
    final ts = doneAt ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    final inserted = await db.transaction(() async {
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

    // Refresh the matching schedule (if any) after the event is committed.
    await schedules?.applyCareEvent(
      plantId: plantId,
      type: type,
      doneAt: DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true),
      snoozedBeforeDone: snoozedBeforeDone,
    );
    // Re-sync OS notifications so the user's push-reminder set reflects
    // the new next_due_at. Best-effort — notification failures must not
    // rollback the committed care event.
    try {
      await reminderSync?.syncFromDatabase();
    } catch (_) {
      // swallow — the next successful record() will catch up.
    }
    return inserted;
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

  /// Edit a previously-logged care event. Useful when the user typed
  /// the wrong dose or mis-remembered the date.
  Future<void> edit(
    String id, {
    required String type,
    required int doneAt,
    required String? notes,
    required String? dose,
    required String? product,
  }) async {
    return db.transaction(() async {
      await opLog.recordFieldUpdate(entity: 'care_events', entityId: id, field: 'type', value: type);
      await opLog.recordFieldUpdate(entity: 'care_events', entityId: id, field: 'done_at', value: doneAt);
      await opLog.recordFieldUpdate(entity: 'care_events', entityId: id, field: 'notes', value: notes);
      await opLog.recordFieldUpdate(entity: 'care_events', entityId: id, field: 'dose', value: dose);
      final hlc = await opLog.recordFieldUpdate(
        entity: 'care_events', entityId: id, field: 'product', value: product);
      await (db.update(db.careEvents)..where((e) => e.id.equals(id))).write(
        CareEventsCompanion(
          type: Value(type),
          doneAt: Value(doneAt),
          notes: Value(notes),
          dose: Value(dose),
          product: Value(product),
          updatedHlc: Value(hlc.encode()),
          deviceId: Value(opLog.clock.deviceId),
        ),
      );
    });
  }
}
