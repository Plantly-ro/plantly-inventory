import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:ulid/ulid.dart';

import '../../sync/op_log.dart';
import '../database/app_database.dart';

/// Lookups + upsert for the `species` table. Phase 1 stored species as free
/// text in `plants.species_id`; rows created here are the first real
/// `Species` entries (used by the Assistant/marketplace import, CONTRACT §4b),
/// so readers should resolve `plants.species_id` through [displayName].
class SpeciesRepository {
  SpeciesRepository({required this.db, required this.opLog});

  final AppDatabase db;
  final OpLogWriter opLog;

  Future<SpeciesRow?> byId(String id) {
    return (db.select(db.species)..where((s) => s.id.equals(id))).getSingleOrNull();
  }

  /// Case-insensitive match on `scientific_name` within the tenant.
  Future<SpeciesRow?> byScientificName(String name) {
    final needle = name.trim().toLowerCase();
    return (db.select(db.species)
          ..where((s) =>
              s.tenantId.equals(opLog.tenantId) &
              s.deletedAt.isNull() &
              s.scientificName.lower().equals(needle)))
        .getSingleOrNull();
  }

  /// Find-or-create by scientific name. When the row exists and
  /// [commonName] is new, it is appended to `common_names_json`.
  Future<SpeciesRow> upsertByScientificName(String scientificName, {String? commonName}) async {
    final name = scientificName.trim();
    final common = commonName?.trim();
    return db.transaction(() async {
      final existing = await byScientificName(name);
      if (existing != null) {
        if (common != null && common.isNotEmpty) {
          final names = _decodeNames(existing.commonNamesJson);
          if (!names.any((n) => n.toLowerCase() == common.toLowerCase())) {
            names.add(common);
            final encoded = json.encode(names);
            final hlc = await opLog.recordFieldUpdate(
              entity: 'species',
              entityId: existing.id,
              field: 'common_names_json',
              value: encoded,
            );
            await (db.update(db.species)..where((s) => s.id.equals(existing.id))).write(
              SpeciesCompanion(
                commonNamesJson: Value(encoded),
                updatedHlc: Value(hlc.encode()),
                deviceId: Value(opLog.clock.deviceId),
              ),
            );
            return (await byId(existing.id))!;
          }
        }
        return existing;
      }
      final id = Ulid().toString();
      final commonNames = json.encode([if (common != null && common.isNotEmpty) common]);
      final hlc = await opLog.recordCreate(
        entity: 'species',
        entityId: id,
        value: {
          'id': id,
          'tenant_id': opLog.tenantId,
          'scientific_name': name,
          'common_names_json': commonNames,
          'is_seed': false,
        },
      );
      await db.into(db.species).insert(
            SpeciesCompanion.insert(
              id: id,
              tenantId: opLog.tenantId,
              scientificName: name,
              commonNamesJson: commonNames,
              isSeed: const Value(false),
              updatedHlc: hlc.encode(),
              deviceId: opLog.clock.deviceId,
            ),
          );
      return (await byId(id))!;
    });
  }

  /// What to show for a plant's `species_id`: the scientific name when it
  /// points at a real `species` row, else the stored text itself (Phase 1
  /// free-text species). Null/empty in → null out.
  Future<String?> displayName(String? speciesIdOrName) async {
    if (speciesIdOrName == null || speciesIdOrName.trim().isEmpty) return null;
    final row = await byId(speciesIdOrName);
    return row?.scientificName ?? speciesIdOrName;
  }

  static List<String> _decodeNames(String raw) {
    try {
      final decoded = json.decode(raw);
      if (decoded is List) return decoded.map((e) => '$e').toList();
    } catch (_) {}
    return [];
  }
}
