import 'package:drift/drift.dart';
import 'package:intl/intl.dart';

import '../data/database/app_database.dart';
import '../data/repositories/photo_repository.dart';
import '../data/repositories/plant_repository.dart';
import '../data/repositories/species_repository.dart';
import '../l10n/generated/app_localizations.dart';
import 'plantly_export.dart';

/// Writes one PlantlyExport into the local DB (CONTRACT §4b): species
/// upsert → plant row → optional thumb attached as the first photo. No care
/// schedules. Pure data layer — the sheet owns the UI.
class ImportPlantService {
  ImportPlantService({
    required this.db,
    required this.plants,
    required this.species,
    required this.photos,
    required this.plantPhotos,
    required this.tenantId,
    DateTime Function()? now,
  }) : _now = now ?? (() => DateTime.now().toUtc());

  final AppDatabase db;
  final PlantRepository plants;
  final SpeciesRepository species;
  final PhotoRepository photos;
  final PlantPhotoRepository plantPhotos;
  final String tenantId;
  final DateTime Function() _now;

  /// Window for the "you added this one just now" hint.
  static const Duration recentWindow = Duration(minutes: 10);

  static const Set<String> handoffSources = {'plantly-assistant', 'plantly-marketplace'};

  /// A plant of the same species imported through a handoff within the last
  /// 10 minutes (no dedupe — just the hint).
  Future<PlantRow?> recentDuplicate(PlantlyExportPayload payload) async {
    final row = await species.byScientificName(payload.scientificName);
    if (row == null) return null;
    final since = _now().subtract(recentWindow).millisecondsSinceEpoch;
    final matches = await (db.select(db.plants)
          ..where((p) =>
              p.tenantId.equals(tenantId) &
              p.deletedAt.isNull() &
              p.speciesId.equals(row.id) &
              p.acquiredAt.isBiggerOrEqualValue(since) &
              p.source.isIn(handoffSources.toList()))
          ..orderBy([(p) => OrderingTerm(expression: p.acquiredAt, mode: OrderingMode.desc)])
          ..limit(1))
        .get();
    return matches.firstOrNull;
  }

  /// Creates the plant and returns its row.
  Future<PlantRow> import(
    PlantlyExportPayload payload, {
    required String nickname,
    required AppLocalizations t,
  }) async {
    final speciesRow = await species.upsertByScientificName(
      payload.scientificName,
      commonName: payload.commonName,
    );
    final plant = await plants.create(
      nickname: nickname.trim().isEmpty ? payload.defaultNickname : nickname.trim(),
      speciesId: speciesRow.id,
      acquiredAt: _now().millisecondsSinceEpoch,
      source: payload.source,
      notes: buildNotes(payload, t),
    );
    final thumb = payload.thumbBytes;
    if (thumb != null) {
      final sha = await photos.saveBytes(thumb, takenAtMs: payload.capturedAt?.toUtc().millisecondsSinceEpoch);
      await plantPhotos.attach(plant.id, sha, displayOrder: 0);
    }
    return plant;
  }

  /// "Identified with Plantly Assistant on `date`. Health: `status`.
  /// Observations: `kind (severity)…`" — parts omitted when absent (§4b).
  static String? buildNotes(PlantlyExportPayload payload, AppLocalizations t) {
    final parts = <String>[];
    final when = payload.capturedAt ?? payload.exportedAt;
    final date = when == null ? null : DateFormat.yMMMd(t.localeName).format(when.toLocal());
    if (payload.isFromMarketplace) {
      parts.add(date == null ? t.importNotesBoughtNoDate : t.importNotesBought(date));
    } else {
      parts.add(date == null ? t.importNotesIdentifiedNoDate : t.importNotesIdentified(date));
    }
    final status = payload.healthStatus;
    if (status != null) parts.add(t.importNotesHealth(healthLabel(status, t)));
    final obs = payload.observations;
    if (obs != null && obs.isNotEmpty) {
      final items = obs.map((o) {
        final pct = (o.severity.clamp(0, 1) * 100).round();
        final label = observationLabel(o.kind, t);
        final note = o.note == null ? '' : ' — ${o.note}';
        return '$label ($pct%)$note';
      }).join(', ');
      parts.add(t.importNotesObservations(items));
    }
    return parts.isEmpty ? null : parts.join(' ');
  }

  static String healthLabel(String status, AppLocalizations t) => switch (status) {
        'healthy' => t.importHealthHealthy,
        'stressed' => t.importHealthStressed,
        'diseased' => t.importHealthDiseased,
        _ => t.importHealthUnknown,
      };

  static String observationLabel(String kind, AppLocalizations t) => switch (kind) {
        'yellowing' => t.importObsYellowing,
        'browning' => t.importObsBrowning,
        'spots' => t.importObsSpots,
        'wilting' => t.importObsWilting,
        'pests' => t.importObsPests,
        _ => t.importObsOther,
      };
}
