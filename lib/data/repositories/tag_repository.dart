import 'package:drift/drift.dart';
import 'package:ulid/ulid.dart';

import '../../sync/op_log.dart';
import '../database/app_database.dart';

/// CRUD for the `tags` table. Tags are per-tenant, unique by name
/// (normalised lowercase) — `TagRepository.ensure` returns the existing
/// row if a tag with the same name already exists, else creates it.
class TagRepository {
  TagRepository({required this.db, required this.opLog});

  final AppDatabase db;
  final OpLogWriter opLog;

  Stream<List<TagRow>> watchAll() {
    return (db.select(db.tags)
          ..where((t) => t.tenantId.equals(opLog.tenantId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  Future<TagRow> ensure(String name) async {
    final normalised = name.trim().toLowerCase();
    final existing = await (db.select(db.tags)
          ..where((t) =>
              t.tenantId.equals(opLog.tenantId) &
              t.name.equals(normalised) &
              t.deletedAt.isNull()))
        .getSingleOrNull();
    if (existing != null) return existing;
    return db.transaction(() async {
      final id = Ulid().toString();
      final hlc = await opLog.recordCreate(
        entity: 'tags',
        entityId: id,
        value: {
          'id': id,
          'tenant_id': opLog.tenantId,
          'name': normalised,
          'color': null,
        },
      );
      await db.into(db.tags).insert(
            TagsCompanion.insert(
              id: id,
              tenantId: opLog.tenantId,
              name: normalised,
              updatedHlc: hlc.encode(),
              deviceId: opLog.clock.deviceId,
            ),
          );
      return (await (db.select(db.tags)..where((t) => t.id.equals(id))).getSingle());
    });
  }
}

/// OR-Set operations over `plant_tags`. Mirrors `PlantPhotoRepository`:
/// a (plantId, tagId) pair is "present" when the max added_hlc of live
/// rows outranks every removed_hlc for the same pair.
class PlantTagRepository {
  PlantTagRepository({required this.db, required this.opLog});

  final AppDatabase db;
  final OpLogWriter opLog;

  Future<void> attach(String plantId, String tagId) async {
    return db.transaction(() async {
      final id = Ulid().toString();
      final hlc = await opLog.recordCreate(
        entity: 'plant_tags',
        entityId: id,
        value: {
          'id': id,
          'tenant_id': opLog.tenantId,
          'plant_id': plantId,
          'tag_id': tagId,
        },
      );
      await db.into(db.plantTags).insert(
            PlantTagsCompanion.insert(
              id: id,
              tenantId: opLog.tenantId,
              plantId: plantId,
              tagId: tagId,
              addedHlc: hlc.encode(),
              deviceId: opLog.clock.deviceId,
            ),
          );
    });
  }

  Future<void> detach(String plantId, String tagId) async {
    return db.transaction(() async {
      // One `removed_hlc` field op per live add-row, keyed by the row id
      // (CLOUD-SYNC-CONTRACT §2.3: OR-Set removes are regular field ops);
      // a null value means "removed at the op's own HLC".
      final live = await (db.select(db.plantTags)
            ..where((r) =>
                r.tenantId.equals(opLog.tenantId) &
                r.plantId.equals(plantId) &
                r.tagId.equals(tagId) &
                r.removedHlc.isNull()))
          .get();
      for (final row in live) {
        final hlc = await opLog.recordFieldUpdate(
          entity: 'plant_tags',
          entityId: row.id,
          field: 'removed_hlc',
          value: null,
        );
        await (db.update(db.plantTags)..where((r) => r.id.equals(row.id))).write(
          PlantTagsCompanion(
            removedHlc: Value(hlc.encode()),
            deviceId: Value(opLog.clock.deviceId),
          ),
        );
      }
    });
  }

  /// Live set of tag ids currently attached to [plantId].
  Stream<List<String>> watchAttached(String plantId) {
    return (db.select(db.plantTags)
          ..where((r) => r.tenantId.equals(opLog.tenantId) & r.plantId.equals(plantId)))
        .watch()
        .map(_resolveOrSet);
  }

  List<String> _resolveOrSet(List<PlantTagRow> rows) {
    final grouped = <String, List<PlantTagRow>>{};
    for (final r in rows) {
      grouped.putIfAbsent(r.tagId, () => []).add(r);
    }
    final out = <String>[];
    for (final entry in grouped.entries) {
      final live = entry.value.where((r) => r.removedHlc == null).toList();
      if (live.isEmpty) continue;
      final maxAdd = live.map((r) => r.addedHlc).reduce((a, b) => a.compareTo(b) > 0 ? a : b);
      final tombs = entry.value.where((r) => r.removedHlc != null).map((r) => r.removedHlc!).toList();
      final maxTomb = tombs.isEmpty ? null : tombs.reduce((a, b) => a.compareTo(b) > 0 ? a : b);
      if (maxTomb == null || maxAdd.compareTo(maxTomb) > 0) {
        out.add(entry.key);
      }
    }
    return out;
  }
}
