import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/painting.dart';
import 'package:ulid/ulid.dart';

import '../../sync/op_log.dart';
import '../database/app_database.dart';
import '../photo_blob_store.dart';

/// Content-addressed photo store (PLAN.md §"Schema non-negotiables").
///
/// Photos are keyed by SHA-256 of their raw bytes, not a random id, so
/// importing the same image twice is a no-op and sync has a natural
/// dedup key. Bytes live in the platform [PhotoBlobStore] (sharded files
/// on io, IndexedDB on web); this class owns the metadata row.
class PhotoRepository {
  PhotoRepository({
    required this.db,
    required this.opLog,
    required this.store,
  });

  final AppDatabase db;
  final OpLogWriter opLog;
  final PhotoBlobStore store;

  /// Compute SHA-256 + write to the sharded store + insert a `photos` row.
  /// Idempotent: the same bytes always produce the same sha, and the
  /// INSERT OR REPLACE semantics keep the row count at 1 per unique photo.
  /// Returns the SHA-256 hex string so callers can attach it to plants.
  Future<String> saveBytes(
    Uint8List bytes, {
    String mime = 'image/jpeg',
    int? width,
    int? height,
    int? takenAtMs,
  }) async {
    final shaHex = sha256.convert(bytes).toString();
    final localPath = await store.write(sha: shaHex, mime: mime, bytes: bytes);

    await db.transaction(() async {
      final existing = await (db.select(db.photos)..where((t) => t.sha256.equals(shaHex))).getSingleOrNull();
      if (existing != null) return;
      final hlc = await opLog.recordCreate(
        entity: 'photos',
        entityId: shaHex,
        value: {
          'sha256': shaHex,
          'tenant_id': opLog.tenantId,
          'mime': mime,
          'bytes': bytes.length,
          'width': width,
          'height': height,
          'taken_at': takenAtMs,
          'local_path': localPath,
          'remote_state': 'local',
        },
      );
      await db.into(db.photos).insert(
            PhotosCompanion.insert(
              sha256: shaHex,
              tenantId: opLog.tenantId,
              mime: mime,
              bytes: bytes.length,
              width: Value(width),
              height: Value(height),
              takenAt: Value(takenAtMs),
              localPath: Value(localPath),
              updatedHlc: hlc.encode(),
              deviceId: opLog.clock.deviceId,
            ),
          );
    });

    return shaHex;
  }

  Future<PhotoRow?> byHash(String sha) {
    return (db.select(db.photos)..where((p) => p.sha256.equals(sha))).getSingleOrNull();
  }

  /// Raw bytes for a stored photo row, or null if the blob is gone.
  Future<Uint8List?> bytesFor(PhotoRow photo) {
    return store.read(sha: photo.sha256, mime: photo.mime, localPath: photo.localPath);
  }

  /// Image for the widget tree — null when the row or its blob is missing,
  /// so callers fall back to the gradient stub.
  Future<ImageProvider?> imageFor(String sha) async {
    final row = await byHash(sha);
    if (row == null) return null;
    return store.imageFor(sha: row.sha256, mime: row.mime, localPath: row.localPath);
  }
}

/// OR-Set operations over `plant_photos`. A photo is "present" on a plant
/// when its most-recent add_hlc outranks every remove_hlc for the same
/// (plant, photo) pair — PLAN.md §"Schema non-negotiables".
class PlantPhotoRepository {
  PlantPhotoRepository({required this.db, required this.opLog});

  final AppDatabase db;
  final OpLogWriter opLog;

  /// Attach a photo to a plant — inserts a new add-op with a fresh HLC.
  Future<void> attach(String plantId, String photoSha, {int displayOrder = 0}) async {
    return db.transaction(() async {
      final id = Ulid().toString();
      final hlc = await opLog.recordCreate(
        entity: 'plant_photos',
        entityId: id,
        value: {
          'id': id,
          'tenant_id': opLog.tenantId,
          'plant_id': plantId,
          'photo_sha': photoSha,
          'display_order': displayOrder,
          'added_hlc': null, // stamped below
        },
      );
      await db.into(db.plantPhotos).insert(
            PlantPhotosCompanion.insert(
              id: id,
              tenantId: opLog.tenantId,
              plantId: plantId,
              photoSha: photoSha,
              addedHlc: hlc.encode(),
              displayOrder: Value(displayOrder),
              deviceId: opLog.clock.deviceId,
            ),
          );
    });
  }

  /// Remove every live add-op for (plantId, photoSha) by stamping a
  /// removed_hlc that wins. Idempotent — a second detach is a no-op.
  Future<void> detach(String plantId, String photoSha) async {
    return db.transaction(() async {
      final hlc = await opLog.recordFieldUpdate(
        entity: 'plant_photos',
        entityId: '$plantId/$photoSha',
        field: 'removed_hlc',
        value: null,
      );
      await (db.update(db.plantPhotos)
            ..where((r) =>
                r.tenantId.equals(opLog.tenantId) &
                r.plantId.equals(plantId) &
                r.photoSha.equals(photoSha) &
                r.removedHlc.isNull()))
          .write(
        PlantPhotosCompanion(
          removedHlc: Value(hlc.encode()),
          deviceId: Value(opLog.clock.deviceId),
        ),
      );
    });
  }

  /// SHA-256 of every photo currently attached to the plant, ordered by
  /// display_order then added_hlc. Uses the OR-Set rule: a (plant, photo)
  /// pair is present if at least one add-row exists whose removed_hlc is
  /// null (live) AND there is no LATER removed_hlc for the same pair.
  Stream<List<String>> watchAttached(String plantId) {
    return (db.select(db.plantPhotos)
          ..where((r) => r.tenantId.equals(opLog.tenantId) & r.plantId.equals(plantId))
          ..orderBy([
            (r) => OrderingTerm(expression: r.displayOrder),
            (r) => OrderingTerm(expression: r.addedHlc),
          ]))
        .watch()
        .map(_resolveOrSet);
  }

  /// Full live rows for a plant — lets the UI read `display_order` and
  /// `caption` alongside the sha. Same OR-set rules as [watchAttached].
  Stream<List<PlantPhotoRow>> watchAttachedRows(String plantId) {
    return (db.select(db.plantPhotos)
          ..where((r) => r.tenantId.equals(opLog.tenantId) & r.plantId.equals(plantId))
          ..orderBy([
            (r) => OrderingTerm(expression: r.displayOrder),
            (r) => OrderingTerm(expression: r.addedHlc),
          ]))
        .watch()
        .map(_resolveOrSetRows);
  }

  List<PlantPhotoRow> _resolveOrSetRows(List<PlantPhotoRow> rows) {
    final grouped = <String, List<PlantPhotoRow>>{};
    for (final r in rows) {
      grouped.putIfAbsent('${r.plantId}/${r.photoSha}', () => []).add(r);
    }
    final result = <PlantPhotoRow>[];
    for (final entry in grouped.entries) {
      final live = entry.value.where((r) => r.removedHlc == null).toList();
      if (live.isEmpty) continue;
      final max = live.reduce((a, b) => a.addedHlc.compareTo(b.addedHlc) > 0 ? a : b);
      final tombs = entry.value.where((r) => r.removedHlc != null).map((r) => r.removedHlc!).toList();
      final maxTomb = tombs.isEmpty ? null : tombs.reduce((a, b) => a.compareTo(b) > 0 ? a : b);
      if (maxTomb == null || max.addedHlc.compareTo(maxTomb) > 0) result.add(max);
    }
    result.sort((a, b) {
      final c = a.displayOrder.compareTo(b.displayOrder);
      return c != 0 ? c : a.addedHlc.compareTo(b.addedHlc);
    });
    return result;
  }

  /// Update the caption of a specific attachment.
  Future<void> setCaption(String plantPhotoRowId, String? caption) async {
    return db.transaction(() async {
      final hlc = await opLog.recordFieldUpdate(
        entity: 'plant_photos',
        entityId: plantPhotoRowId,
        field: 'caption',
        value: caption,
      );
      await (db.update(db.plantPhotos)..where((r) => r.id.equals(plantPhotoRowId))).write(
        PlantPhotosCompanion(
          caption: Value(caption),
          addedHlc: Value(hlc.encode()),
          deviceId: Value(opLog.clock.deviceId),
        ),
      );
    });
  }

  /// Override the display-only "date added" for an attachment. Pass null to
  /// fall back to the HLC physicalMs.
  Future<void> setCapturedAt(String plantPhotoRowId, int? capturedAtMs) async {
    return db.transaction(() async {
      final hlc = await opLog.recordFieldUpdate(
        entity: 'plant_photos',
        entityId: plantPhotoRowId,
        field: 'captured_at',
        value: capturedAtMs,
      );
      await (db.update(db.plantPhotos)..where((r) => r.id.equals(plantPhotoRowId))).write(
        PlantPhotosCompanion(
          capturedAt: Value(capturedAtMs),
          addedHlc: Value(hlc.encode()),
          deviceId: Value(opLog.clock.deviceId),
        ),
      );
    });
  }

  /// Reorder a plant's attachments. Writes the supplied list's index as
  /// `display_order` for each row so the UI's PageView picks up the new
  /// sequence on its next rebuild.
  Future<void> reorder(List<PlantPhotoRow> orderedRows) async {
    return db.transaction(() async {
      for (var i = 0; i < orderedRows.length; i++) {
        final row = orderedRows[i];
        if (row.displayOrder == i) continue;
        final hlc = await opLog.recordFieldUpdate(
          entity: 'plant_photos',
          entityId: row.id,
          field: 'display_order',
          value: i,
        );
        await (db.update(db.plantPhotos)..where((r) => r.id.equals(row.id))).write(
          PlantPhotosCompanion(
            displayOrder: Value(i),
            addedHlc: Value(hlc.encode()),
            deviceId: Value(opLog.clock.deviceId),
          ),
        );
      }
    });
  }

  Future<List<String>> currentAttached(String plantId) async {
    final rows = await (db.select(db.plantPhotos)
          ..where((r) => r.tenantId.equals(opLog.tenantId) & r.plantId.equals(plantId))
          ..orderBy([
            (r) => OrderingTerm(expression: r.displayOrder),
            (r) => OrderingTerm(expression: r.addedHlc),
          ]))
        .get();
    return _resolveOrSet(rows);
  }

  List<String> _resolveOrSet(List<PlantPhotoRow> rows) {
    // Group by (plant, photo). For each group, compare the max added_hlc
    // of rows with removed_hlc == null against the max removed_hlc; if
    // any live add outranks every remove, the photo is present.
    final grouped = <String, List<PlantPhotoRow>>{};
    for (final r in rows) {
      grouped.putIfAbsent('${r.plantId}/${r.photoSha}', () => []).add(r);
    }
    final result = <String>[];
    for (final entry in grouped.entries) {
      final live = entry.value.where((r) => r.removedHlc == null).toList();
      if (live.isEmpty) continue;
      final maxAdd = live.map((r) => r.addedHlc).reduce((a, b) => a.compareTo(b) > 0 ? a : b);
      final tombs = entry.value.where((r) => r.removedHlc != null).map((r) => r.removedHlc!).toList();
      final maxTomb = tombs.isEmpty ? null : tombs.reduce((a, b) => a.compareTo(b) > 0 ? a : b);
      if (maxTomb == null || maxAdd.compareTo(maxTomb) > 0) {
        result.add(entry.value.first.photoSha);
      }
    }
    return result;
  }
}

/// OR-set attachments for the `location_photos` table — mirror of
/// `PlantPhotoRepository` but keyed on locationId. Separate so the two
/// gallery surfaces can evolve independently.
class LocationPhotoRepository {
  LocationPhotoRepository({required this.db, required this.opLog});

  final AppDatabase db;
  final OpLogWriter opLog;

  Future<void> attach(String locationId, String photoSha, {String? caption}) async {
    return db.transaction(() async {
      final id = Ulid().toString();
      final hlc = await opLog.recordCreate(
        entity: 'location_photos',
        entityId: id,
        value: {
          'id': id,
          'tenant_id': opLog.tenantId,
          'location_id': locationId,
          'photo_sha': photoSha,
          'caption': caption,
        },
      );
      await db.into(db.locationPhotos).insert(
            LocationPhotosCompanion.insert(
              id: id,
              tenantId: opLog.tenantId,
              locationId: locationId,
              photoSha: photoSha,
              caption: Value(caption),
              addedHlc: hlc.encode(),
              deviceId: opLog.clock.deviceId,
            ),
          );
    });
  }

  Future<void> detach(String locationId, String photoSha) async {
    return db.transaction(() async {
      final hlc = await opLog.recordFieldUpdate(
        entity: 'location_photos',
        entityId: '$locationId/$photoSha',
        field: 'removed_hlc',
        value: null,
      );
      await (db.update(db.locationPhotos)
            ..where((r) =>
                r.tenantId.equals(opLog.tenantId) &
                r.locationId.equals(locationId) &
                r.photoSha.equals(photoSha) &
                r.removedHlc.isNull()))
          .write(
        LocationPhotosCompanion(
          removedHlc: Value(hlc.encode()),
          deviceId: Value(opLog.clock.deviceId),
        ),
      );
    });
  }

  Future<void> setCaption(String rowId, String? caption) async {
    return db.transaction(() async {
      final hlc = await opLog.recordFieldUpdate(
        entity: 'location_photos',
        entityId: rowId,
        field: 'caption',
        value: caption,
      );
      await (db.update(db.locationPhotos)..where((r) => r.id.equals(rowId))).write(
        LocationPhotosCompanion(
          caption: Value(caption),
          addedHlc: Value(hlc.encode()),
          deviceId: Value(opLog.clock.deviceId),
        ),
      );
    });
  }

  Future<void> setCapturedAt(String rowId, int? capturedAtMs) async {
    return db.transaction(() async {
      final hlc = await opLog.recordFieldUpdate(
        entity: 'location_photos',
        entityId: rowId,
        field: 'captured_at',
        value: capturedAtMs,
      );
      await (db.update(db.locationPhotos)..where((r) => r.id.equals(rowId))).write(
        LocationPhotosCompanion(
          capturedAt: Value(capturedAtMs),
          addedHlc: Value(hlc.encode()),
          deviceId: Value(opLog.clock.deviceId),
        ),
      );
    });
  }

  Stream<List<LocationPhotoRow>> watchAttached(String locationId) {
    return (db.select(db.locationPhotos)
          ..where((r) => r.tenantId.equals(opLog.tenantId) & r.locationId.equals(locationId))
          ..orderBy([
            (r) => OrderingTerm(expression: r.displayOrder),
            (r) => OrderingTerm(expression: r.addedHlc),
          ]))
        .watch()
        .map(_resolveOrSet);
  }

  List<LocationPhotoRow> _resolveOrSet(List<LocationPhotoRow> rows) {
    final grouped = <String, List<LocationPhotoRow>>{};
    for (final r in rows) {
      grouped.putIfAbsent('${r.locationId}/${r.photoSha}', () => []).add(r);
    }
    final out = <LocationPhotoRow>[];
    for (final entry in grouped.entries) {
      final live = entry.value.where((r) => r.removedHlc == null).toList();
      if (live.isEmpty) continue;
      final max = live.reduce((a, b) => a.addedHlc.compareTo(b.addedHlc) > 0 ? a : b);
      final tombs = entry.value.where((r) => r.removedHlc != null).map((r) => r.removedHlc!).toList();
      final maxTomb = tombs.isEmpty ? null : tombs.reduce((a, b) => a.compareTo(b) > 0 ? a : b);
      if (maxTomb == null || max.addedHlc.compareTo(maxTomb) > 0) out.add(max);
    }
    out.sort((a, b) {
      final c = a.displayOrder.compareTo(b.displayOrder);
      return c != 0 ? c : a.addedHlc.compareTo(b.addedHlc);
    });
    return out;
  }
}
