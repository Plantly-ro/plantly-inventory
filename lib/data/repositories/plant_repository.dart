import 'package:drift/drift.dart';
import 'package:ulid/ulid.dart';

import '../../sync/op_log.dart';
import '../database/app_database.dart';

/// CRUD for the `plants` table. Every mutation is transactional and emits an
/// op-log entry via [OpLogWriter] so a future sync push ships the same bits
/// that landed locally.
class PlantRepository {
  PlantRepository({required this.db, required this.opLog});

  final AppDatabase db;
  final OpLogWriter opLog;

  Stream<List<PlantRow>> watchAll() {
    return (db.select(db.plants)
          ..where((p) => p.tenantId.equals(opLog.tenantId) & p.deletedAt.isNull())
          ..orderBy([(p) => OrderingTerm(expression: p.nickname)]))
        .watch();
  }

  Future<PlantRow?> byId(String id) {
    return (db.select(db.plants)..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  /// Create a plant. Returns the inserted row, complete with generated ULID
  /// and stamped HLC.
  Future<PlantRow> create({
    required String nickname,
    String? speciesId,
    String? locationId,
    String status = 'alive',
    int? acquiredAt,
    String? source,
    String? notes,
    int? potSizeCm,
  }) async {
    return db.transaction(() async {
      final id = Ulid().toString();
      final value = {
        'id': id,
        'tenant_id': opLog.tenantId,
        'nickname': nickname,
        'species_id': speciesId,
        'location_id': locationId,
        'status': status,
        'acquired_at': acquiredAt,
        'source': source,
        'notes': notes,
        'pot_size_cm': potSizeCm,
      };
      final hlc = await opLog.recordCreate(
        entity: 'plants',
        entityId: id,
        value: value,
      );
      final row = PlantsCompanion.insert(
        id: id,
        tenantId: opLog.tenantId,
        nickname: nickname,
        speciesId: Value(speciesId),
        locationId: Value(locationId),
        status: status,
        acquiredAt: Value(acquiredAt),
        source: Value(source),
        notes: Value(notes),
        potSizeCm: Value(potSizeCm),
        updatedHlc: hlc.encode(),
        deletedAt: const Value.absent(),
        deviceId: opLog.clock.deviceId,
      );
      await db.into(db.plants).insert(row);
      final fetched = await byId(id);
      return fetched!;
    });
  }

  Future<void> rename(String id, String nickname) async {
    return db.transaction(() async {
      final hlc = await opLog.recordFieldUpdate(
        entity: 'plants',
        entityId: id,
        field: 'nickname',
        value: nickname,
      );
      await (db.update(db.plants)..where((p) => p.id.equals(id))).write(
        PlantsCompanion(
          nickname: Value(nickname),
          updatedHlc: Value(hlc.encode()),
          deviceId: Value(opLog.clock.deviceId),
        ),
      );
    });
  }

  /// Update nickname + notes + location + species in one transaction. Any
  /// field left as `null` is deliberately erased; callers who want to leave
  /// a field untouched should re-pass its current value.
  Future<void> edit(
    String id, {
    required String nickname,
    required String? notes,
    required String? locationId,
    required String? speciesId,
  }) async {
    return db.transaction(() async {
      await opLog.recordFieldUpdate(entity: 'plants', entityId: id, field: 'nickname', value: nickname);
      await opLog.recordFieldUpdate(entity: 'plants', entityId: id, field: 'notes', value: notes);
      await opLog.recordFieldUpdate(entity: 'plants', entityId: id, field: 'location_id', value: locationId);
      final finalHlc = await opLog.recordFieldUpdate(
        entity: 'plants',
        entityId: id,
        field: 'species_id',
        value: speciesId,
      );
      await (db.update(db.plants)..where((p) => p.id.equals(id))).write(
        PlantsCompanion(
          nickname: Value(nickname),
          notes: Value(notes),
          locationId: Value(locationId),
          speciesId: Value(speciesId),
          updatedHlc: Value(finalHlc.encode()),
          deviceId: Value(opLog.clock.deviceId),
        ),
      );
    });
  }

  /// Move a plant into [locationId] (or clear, when null).
  Future<void> setLocation(String id, String? locationId) async {
    return db.transaction(() async {
      final hlc = await opLog.recordFieldUpdate(
        entity: 'plants',
        entityId: id,
        field: 'location_id',
        value: locationId,
      );
      await (db.update(db.plants)..where((p) => p.id.equals(id))).write(
        PlantsCompanion(
          locationId: Value(locationId),
          updatedHlc: Value(hlc.encode()),
          deviceId: Value(opLog.clock.deviceId),
        ),
      );
    });
  }

  Stream<PlantRow?> watchById(String id) {
    return (db.select(db.plants)..where((p) => p.id.equals(id)))
        .watchSingleOrNull();
  }

  /// Update the plant's pin coordinates on its current location map.
  /// Pass (null, null) to unplace the pin.
  Future<void> setPin(String id, double? x, double? y) async {
    return db.transaction(() async {
      await opLog.recordFieldUpdate(entity: 'plants', entityId: id, field: 'pin_x', value: x);
      final hlc = await opLog.recordFieldUpdate(entity: 'plants', entityId: id, field: 'pin_y', value: y);
      await (db.update(db.plants)..where((p) => p.id.equals(id))).write(
        PlantsCompanion(
          pinX: Value(x),
          pinY: Value(y),
          updatedHlc: Value(hlc.encode()),
          deviceId: Value(opLog.clock.deviceId),
        ),
      );
    });
  }

  /// Toggle per-plant notification mute. ReminderSync reads this flag
  /// and skips every schedule for this plant when true.
  Future<void> setNotificationsMuted(String id, bool muted) async {
    return db.transaction(() async {
      final hlc = await opLog.recordFieldUpdate(
        entity: 'plants',
        entityId: id,
        field: 'notifications_muted',
        value: muted,
      );
      await (db.update(db.plants)..where((p) => p.id.equals(id))).write(
        PlantsCompanion(
          notificationsMuted: Value(muted),
          updatedHlc: Value(hlc.encode()),
          deviceId: Value(opLog.clock.deviceId),
        ),
      );
    });
  }

  Stream<List<PlantRow>> watchByLocation(String locationId) {
    return (db.select(db.plants)
          ..where((p) =>
              p.tenantId.equals(opLog.tenantId) &
              p.deletedAt.isNull() &
              p.locationId.equals(locationId))
          ..orderBy([(p) => OrderingTerm(expression: p.nickname)]))
        .watch();
  }

  Future<void> softDelete(String id) async {
    return db.transaction(() async {
      final ts = DateTime.now().toUtc().millisecondsSinceEpoch;
      final hlc = await opLog.recordTombstone(entity: 'plants', entityId: id);
      await (db.update(db.plants)..where((p) => p.id.equals(id))).write(
        PlantsCompanion(
          deletedAt: Value(ts),
          updatedHlc: Value(hlc.encode()),
          deviceId: Value(opLog.clock.deviceId),
        ),
      );
      await cascadeDeleteSchedules(db, opLog, id, ts);
    });
  }

  /// Re-animate a soft-deleted plant. Primarily used by snackbar Undo
  /// flows. Does NOT re-attach photos / tags that were detached as part
  /// of the delete cascade — those OR-set rows carry their own tombstone
  /// HLC and would need to be re-issued with a newer add-op.
  Future<void> restoreFromSoftDelete(String id) async {
    return db.transaction(() async {
      final hlc = await opLog.recordFieldUpdate(
        entity: 'plants',
        entityId: id,
        field: 'deleted_at',
        value: null,
      );
      await (db.update(db.plants)..where((p) => p.id.equals(id))).write(
        PlantsCompanion(
          deletedAt: const Value(null),
          updatedHlc: Value(hlc.encode()),
          deviceId: Value(opLog.clock.deviceId),
        ),
      );
    });
  }
}

/// Soft-deletes every schedule for [plantId]. Exposed so the inventory
/// repo can call it inside its own transaction without nesting.
Future<void> cascadeDeleteSchedules(
  AppDatabase db,
  OpLogWriter opLog,
  String plantId,
  int ts,
) async {
  final schedules = await (db.select(db.careSchedules)
        ..where((s) =>
            s.tenantId.equals(opLog.tenantId) &
            s.plantId.equals(plantId) &
            s.deletedAt.isNull()))
      .get();
  for (final s in schedules) {
    final hlc = await opLog.recordTombstone(entity: 'care_schedules', entityId: s.id);
    await (db.update(db.careSchedules)..where((r) => r.id.equals(s.id))).write(
      CareSchedulesCompanion(
        deletedAt: Value(ts),
        updatedHlc: Value(hlc.encode()),
        deviceId: Value(opLog.clock.deviceId),
      ),
    );
  }
  // Also detach every `plant_photos` OR-Set row pointing at this plant,
  // so the live OR-Set rule drops the photo from the plant's gallery.
  // The underlying content-addressed `photos` rows stay (other plants
  // may reference the same SHA).
  final joins = await (db.select(db.plantPhotos)
        ..where((r) =>
            r.tenantId.equals(opLog.tenantId) &
            r.plantId.equals(plantId) &
            r.removedHlc.isNull()))
      .get();
  for (final j in joins) {
    final hlc = await opLog.recordFieldUpdate(
      entity: 'plant_tags',
      entityId: '$plantId/${j.photoSha}',
      field: 'removed_hlc',
      value: null,
    );
    await (db.update(db.plantPhotos)..where((r) => r.id.equals(j.id))).write(
      PlantPhotosCompanion(
        removedHlc: Value(hlc.encode()),
        deviceId: Value(opLog.clock.deviceId),
      ),
    );
  }
  // Same for tags.
  final tagJoins = await (db.select(db.plantTags)
        ..where((r) =>
            r.tenantId.equals(opLog.tenantId) &
            r.plantId.equals(plantId) &
            r.removedHlc.isNull()))
      .get();
  for (final j in tagJoins) {
    final hlc = await opLog.recordFieldUpdate(
      entity: 'plant_tags',
      entityId: '$plantId/${j.tagId}',
      field: 'removed_hlc',
      value: null,
    );
    await (db.update(db.plantTags)..where((r) => r.id.equals(j.id))).write(
      PlantTagsCompanion(
        removedHlc: Value(hlc.encode()),
        deviceId: Value(opLog.clock.deviceId),
      ),
    );
  }
}
