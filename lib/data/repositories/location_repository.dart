import 'package:drift/drift.dart';
import 'package:ulid/ulid.dart';

import '../../notifications/reminder_sync.dart';
import '../../sync/op_log.dart';
import '../database/app_database.dart';

/// CRUD for the hierarchical `locations` table. Locations form a tree via
/// `parent_id`; children of null are top-level ("Home", "Balcony").
class LocationRepository {
  LocationRepository({required this.db, required this.opLog, this.reminderSync});

  final AppDatabase db;
  final OpLogWriter opLog;

  /// Optional: re-synced after mute/delete since ReminderSync silences
  /// every plant in a muted location. Null in seed/tests.
  final ReminderSync? reminderSync;

  Stream<List<LocationRow>> watchAll() {
    return (db.select(db.locations)
          ..where((l) => l.tenantId.equals(opLog.tenantId) & l.deletedAt.isNull())
          ..orderBy([(l) => OrderingTerm(expression: l.name)]))
        .watch();
  }

  Future<LocationRow?> byId(String id) {
    return (db.select(db.locations)..where((l) => l.id.equals(id))).getSingleOrNull();
  }

  Future<LocationRow> create({
    required String name,
    required String kind,
    String? parentId,
    bool isOutdoor = false,
    String? light,
  }) async {
    return db.transaction(() async {
      final id = Ulid().toString();
      final value = {
        'id': id,
        'tenant_id': opLog.tenantId,
        'parent_id': parentId,
        'name': name,
        'kind': kind,
        'is_outdoor': isOutdoor ? 1 : 0,
        'light': light,
      };
      final hlc = await opLog.recordCreate(
        entity: 'locations',
        entityId: id,
        value: value,
      );
      await db.into(db.locations).insert(
            LocationsCompanion.insert(
              id: id,
              tenantId: opLog.tenantId,
              name: name,
              kind: kind,
              parentId: Value(parentId),
              isOutdoor: Value(isOutdoor),
              light: Value(light),
              updatedHlc: hlc.encode(),
              deviceId: opLog.clock.deviceId,
            ),
          );
      return (await byId(id))!;
    });
  }

  Future<void> rename(String id, String name) async {
    return db.transaction(() async {
      final hlc = await opLog.recordFieldUpdate(
        entity: 'locations',
        entityId: id,
        field: 'name',
        value: name,
      );
      await (db.update(db.locations)..where((l) => l.id.equals(id))).write(
        LocationsCompanion(
          name: Value(name),
          updatedHlc: Value(hlc.encode()),
          deviceId: Value(opLog.clock.deviceId),
        ),
      );
    });
  }

  /// Full-row edit: covers every user-editable field in one transaction
  /// so the op-log emits a coherent burst. Pass `null` to clear a field
  /// (light / humidity / temp / notes can all be null-able).
  Future<void> edit(
    String id, {
    required String name,
    required String kind,
    required String? parentId,
    required bool isOutdoor,
    required String? light,
    required int? humidityMin,
    required int? humidityMax,
    required double? tempMinC,
    required double? tempMaxC,
    required String? notes,
  }) async {
    return db.transaction(() async {
      await opLog.recordFieldUpdate(entity: 'locations', entityId: id, field: 'name', value: name);
      await opLog.recordFieldUpdate(entity: 'locations', entityId: id, field: 'kind', value: kind);
      await opLog.recordFieldUpdate(entity: 'locations', entityId: id, field: 'parent_id', value: parentId);
      await opLog.recordFieldUpdate(entity: 'locations', entityId: id, field: 'is_outdoor', value: isOutdoor);
      await opLog.recordFieldUpdate(entity: 'locations', entityId: id, field: 'light', value: light);
      await opLog.recordFieldUpdate(entity: 'locations', entityId: id, field: 'humidity_min', value: humidityMin);
      await opLog.recordFieldUpdate(entity: 'locations', entityId: id, field: 'humidity_max', value: humidityMax);
      await opLog.recordFieldUpdate(entity: 'locations', entityId: id, field: 'temp_min_c', value: tempMinC);
      await opLog.recordFieldUpdate(entity: 'locations', entityId: id, field: 'temp_max_c', value: tempMaxC);
      final hlc = await opLog.recordFieldUpdate(entity: 'locations', entityId: id, field: 'notes', value: notes);
      await (db.update(db.locations)..where((l) => l.id.equals(id))).write(
        LocationsCompanion(
          name: Value(name),
          kind: Value(kind),
          parentId: Value(parentId),
          isOutdoor: Value(isOutdoor),
          light: Value(light),
          humidityMin: Value(humidityMin),
          humidityMax: Value(humidityMax),
          tempMinC: Value(tempMinC),
          tempMaxC: Value(tempMaxC),
          notes: Value(notes),
          updatedHlc: Value(hlc.encode()),
          deviceId: Value(opLog.clock.deviceId),
        ),
      );
    });
  }

  /// Attach or clear the map-photo SHA — rendered as the backdrop on
  /// `LocationDetailScreen` with plant pins overlaid.
  Future<void> setMapPhoto(String id, String? sha) async {
    return db.transaction(() async {
      final hlc = await opLog.recordFieldUpdate(
        entity: 'locations',
        entityId: id,
        field: 'map_photo_sha',
        value: sha,
      );
      await (db.update(db.locations)..where((l) => l.id.equals(id))).write(
        LocationsCompanion(
          mapPhotoSha: Value(sha),
          updatedHlc: Value(hlc.encode()),
          deviceId: Value(opLog.clock.deviceId),
        ),
      );
    });
  }

  Stream<LocationRow?> watchById(String id) {
    return (db.select(db.locations)..where((l) => l.id.equals(id))).watchSingleOrNull();
  }

  /// Toggle per-location notification mute — silences OS notifications
  /// for every plant in this location.
  Future<void> setNotificationsMuted(String id, bool muted) async {
    await db.transaction(() async {
      final hlc = await opLog.recordFieldUpdate(
        entity: 'locations',
        entityId: id,
        field: 'notifications_muted',
        value: muted,
      );
      await (db.update(db.locations)..where((l) => l.id.equals(id))).write(
        LocationsCompanion(
          notificationsMuted: Value(muted),
          updatedHlc: Value(hlc.encode()),
          deviceId: Value(opLog.clock.deviceId),
        ),
      );
    });
    await _resync();
  }

  Future<void> softDelete(String id) async {
    await db.transaction(() async {
      final hlc = await opLog.recordTombstone(entity: 'locations', entityId: id);
      await (db.update(db.locations)..where((l) => l.id.equals(id))).write(
        LocationsCompanion(
          deletedAt: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
          updatedHlc: Value(hlc.encode()),
          deviceId: Value(opLog.clock.deviceId),
        ),
      );
    });
    await _resync();
  }

  /// Best-effort OS reminder rebuild after a committed mutation (issue #13).
  Future<void> _resync() async {
    try {
      await reminderSync?.syncFromDatabase();
    } catch (_) {}
  }
}

/// Pure tree-builder — given a flat list of [LocationRow]s, returns the
/// top-level nodes, each carrying their (recursive) children. Used by the
/// picker + by tests without a live Drift connection.
List<LocationNode> buildTree(List<LocationRow> rows) {
  final byId = <String, LocationRow>{for (final r in rows) r.id: r};
  final childrenByParent = <String?, List<LocationRow>>{};
  for (final r in rows) {
    final parent = r.parentId;
    // Skip orphans — a row whose parent points at a deleted or missing id
    // would otherwise make an entire branch disappear from the tree.
    if (parent != null && !byId.containsKey(parent)) continue;
    childrenByParent.putIfAbsent(parent, () => []).add(r);
  }
  LocationNode build(LocationRow row) {
    final kids = (childrenByParent[row.id] ?? const <LocationRow>[])
        .map(build)
        .toList(growable: false);
    return LocationNode(row: row, children: kids);
  }
  final roots = (childrenByParent[null] ?? const <LocationRow>[]).map(build).toList(growable: false);
  return roots;
}

class LocationNode {
  const LocationNode({required this.row, required this.children});
  final LocationRow row;
  final List<LocationNode> children;
}
