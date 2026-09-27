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
    this.currentUserId,
  });

  final AppDatabase db;
  final OpLogWriter opLog;
  final CareScheduleRepository? schedules;
  final ReminderSync? reminderSync;

  /// plantly.ro user id of the signed-in account (null when signed out) —
  /// stamped on new rows as `actor_user_id` (shared collections, §3).
  /// Device-local, not on the wire.
  final String? Function()? currentUserId;

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
        actorUserId: Value(currentUserId?.call()),
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
  /// the wrong dose or mis-remembered the date. Emits one op per field
  /// that actually changed.
  Future<void> edit(
    String id, {
    required String type,
    required int doneAt,
    required String? notes,
    required String? dose,
    required String? product,
  }) async {
    return db.transaction(() async {
      final current = await (db.select(db.careEvents)..where((e) => e.id.equals(id))).getSingleOrNull();
      if (current == null) return;
      final hlc = await opLog.recordFieldUpdates(entity: 'care_events', entityId: id, fields: {
        if (current.type != type) 'type': type,
        if (current.doneAt != doneAt) 'done_at': doneAt,
        if (current.notes != notes) 'notes': notes,
        if (current.dose != dose) 'dose': dose,
        if (current.product != product) 'product': product,
      });
      if (hlc == null) return;
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
