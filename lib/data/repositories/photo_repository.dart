import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:ulid/ulid.dart';

import '../../sync/op_log.dart';
import '../database/app_database.dart';

/// Content-addressed photo store (PLAN.md §"Schema non-negotiables").
///
/// Photos are keyed by SHA-256 of their raw bytes, not a random id, so
/// importing the same image twice is a no-op and sync has a natural
/// dedup key. On disk we use a 2-char shard (`$docs/photos/ab/<sha>.jpg`)
/// so a hot directory never gets millions of siblings.
class PhotoRepository {
  PhotoRepository({
    required this.db,
    required this.opLog,
    Directory? rootOverride,
  }) : _rootOverride = rootOverride;

  final AppDatabase db;
  final OpLogWriter opLog;
  final Directory? _rootOverride;

  Future<Directory> _rootDir() async {
    if (_rootOverride != null) return _rootOverride;
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'photos'));
  }

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
    final root = await _rootDir();
    final shardDir = Directory(p.join(root.path, shaHex.substring(0, 2)));
    if (!await shardDir.exists()) {
      await shardDir.create(recursive: true);
    }
    final file = File(p.join(shardDir.path, '$shaHex.${_extension(mime)}'));
    if (!await file.exists()) {
      await file.writeAsBytes(bytes, flush: true);
    }

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
          'local_path': file.path,
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
              localPath: Value(file.path),
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

  String _extension(String mime) {
    switch (mime) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/heic':
        return 'heic';
      default:
        return 'jpg';
    }
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
