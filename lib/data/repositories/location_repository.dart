import 'package:drift/drift.dart';
import 'package:ulid/ulid.dart';

import '../../sync/op_log.dart';
import '../database/app_database.dart';

/// CRUD for the hierarchical `locations` table. Locations form a tree via
/// `parent_id`; children of null are top-level ("Home", "Balcony").
class LocationRepository {
  LocationRepository({required this.db, required this.opLog});

  final AppDatabase db;
  final OpLogWriter opLog;

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

  Future<void> softDelete(String id) async {
    return db.transaction(() async {
      final hlc = await opLog.recordTombstone(entity: 'locations', entityId: id);
      await (db.update(db.locations)..where((l) => l.id.equals(id))).write(
        LocationsCompanion(
          deletedAt: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
          updatedHlc: Value(hlc.encode()),
          deviceId: Value(opLog.clock.deviceId),
        ),
      );
    });
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
