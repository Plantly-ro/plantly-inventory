import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ulid/ulid.dart';

import '../cloud/collection_link.dart' show isCollectionTenant;
import '../sync/hlc.dart';
import '../sync/op_log.dart';
import 'database/app_database.dart';

/// Plant ids the demo seed used to write verbatim (`MockPlants.all[*].id`)
/// before QA2 BUG-2: every Drift primary key is `{id}` with no tenant
/// component, so the same literal id seeded on two installs collides the
/// moment one pulls the other's rows through a shared collection.
const Set<String> kLegacySeedPlantIds = {'bob', 'green', 'snake', 'cala', 'fid', 'fern', 'suc', 'pete'};

/// Set once [rekeyLegacySeedIds] has completed successfully; later boots
/// take the fast path and never scan `plants`.
const String kSeedRekeyDonePrefKey = 'plantly_seed_rekey_done';

/// Columns that can hold a plant id. `plants.location_id`,
/// `location_photos.location_id` and `locations.parent_id` reference
/// *locations*, which were always ULIDs (`LocationRepository.create`), so
/// they are deliberately absent — only plant ids were ever literal.
const List<({String entity, String column})> kPlantIdColumns = [
  (entity: 'plant_photos', column: 'plant_id'),
  (entity: 'plant_tags', column: 'plant_id'),
  (entity: 'care_events', column: 'plant_id'),
  (entity: 'care_schedules', column: 'plant_id'),
  (entity: 'inventory_transactions', column: 'plant_id'),
  (entity: 'inventory_transactions', column: 'parent_plant_id'),
  (entity: 'inventory_transactions', column: 'child_plant_id'),
];

const Set<String> _fkColumns = {'plant_id', 'parent_plant_id', 'child_plant_id'};

/// What one [rekeyLegacySeedIds] run did.
class SeedRekeyReport {
  const SeedRekeyReport({this.rekeyed = const {}, this.opsEmitted = 0});

  /// old literal id → replacement id.
  final Map<String, String> rekeyed;

  /// `sync_ops` rows recorded for synced tenants (tombstone + `*` + one
  /// field op per re-pointed live child row).
  final int opsEmitted;

  bool get isEmpty => rekeyed.isEmpty;

  @override
  String toString() => 'SeedRekeyReport(rekeyed: $rekeyed, opsEmitted: $opsEmitted)';
}

/// Replacement id for a legacy seed plant in a *synced* tenant: derived from
/// `(tenant, old id)` so every device holding the same literal plant in the
/// same collection picks the same replacement and their re-keys converge
/// (tombstone + `*` for one id) instead of forking the plant into two rows.
/// ULID-shaped (26 Crockford chars) but not time-ordered. Local tenants use
/// a random [Ulid] instead — a deterministic id there would be the same on
/// every install in the world, i.e. the bug all over again.
String deterministicSeedReplacementId(String tenant, String oldId) {
  final digest = sha256.convert(utf8.encode('plantly-seed-rekey|$tenant|$oldId')).bytes;
  final bytes = Uint8List.fromList(digest.sublist(0, 16));
  bytes[0] &= 0x3F; // canonical ULID: 128 bits in 26×5, the top two bits are zero
  return Ulid.fromBytes(bytes).toString();
}

/// One-time migration for installs seeded before the ULID seed: gives each
/// literal seed plant a fresh id, re-points every FK and every PENDING op,
/// and — for synced tenants — emits the ops peers need to follow.
///
/// Runs across *all* tenants in the database (a literal id exists at most
/// once, so each hit names exactly one tenant). Everything happens in one
/// transaction; the done-pref is written only after it committed, so a
/// failure simply retries on the next boot. Idempotent: a second run finds
/// no literal ids and changes nothing.
Future<SeedRekeyReport> rekeyLegacySeedIds({
  required AppDatabase db,
  required HlcClock clock,
  required SharedPreferences prefs,
  bool Function(String tenantId)? isSyncedTenant,
}) async {
  if (prefs.getBool(kSeedRekeyDonePrefKey) == true) return const SeedRekeyReport();
  final synced = isSyncedTenant ?? isCollectionTenant;
  final rekeyed = <String, String>{};
  var opsEmitted = 0;

  await db.transaction(() async {
    final marks = List.filled(kLegacySeedPlantIds.length, '?').join(', ');
    final hits = await db
        .customSelect(
          'SELECT id, tenant_id FROM plants WHERE id IN ($marks)',
          variables: [for (final id in kLegacySeedPlantIds) Variable<String>(id)],
          readsFrom: {db.plants},
        )
        .get();
    for (final hit in hits) {
      final old = hit.read<String>('id');
      final tenant = hit.read<String>('tenant_id');
      final emitOps = synced(tenant);
      var newId = emitOps ? deterministicSeedReplacementId(tenant, old) : Ulid().toString();
      // A peer that re-keyed first may already have handed us the
      // deterministic row; never trip the PK — fall back to a random id.
      if (await _plantExists(db, newId)) newId = Ulid().toString();
      opsEmitted += await _rekeyOne(db, clock, tenant: tenant, old: old, newId: newId, emitOps: emitOps);
      rekeyed[old] = newId;
    }
  });

  await prefs.setBool(kSeedRekeyDonePrefKey, true);
  return SeedRekeyReport(rekeyed: rekeyed, opsEmitted: opsEmitted);
}

Future<bool> _plantExists(AppDatabase db, String id) async {
  final row = await db
      .customSelect('SELECT 1 AS present FROM plants WHERE id = ?', variables: [Variable<String>(id)], readsFrom: {db.plants})
      .getSingleOrNull();
  return row != null;
}

/// Re-keys one plant. Returns the number of ops emitted.
Future<int> _rekeyOne(
  AppDatabase db,
  HlcClock clock, {
  required String tenant,
  required String old,
  required String newId,
  required bool emitOps,
}) async {
  final tables = {for (final t in db.allTables) t.actualTableName: t};
  final t = Variable<String>(tenant);

  // 1. The plant row itself. `plants_fts_au` re-indexes it under the new id.
  await db.customUpdate(
    'UPDATE plants SET id = ? WHERE id = ? AND tenant_id = ?',
    variables: [Variable<String>(newId), Variable<String>(old), t],
    updates: {db.plants},
    updateKind: UpdateKind.update,
  );

  // 2. Every FK column that can hold a plant id, same tenant. Live rows are
  //    remembered so the synced case can emit one field op each.
  final repointed = <({String entity, String rowId, String column})>[];
  for (final ref in kPlantIdColumns) {
    final table = tables[ref.entity]!;
    final live = table.columnsByName.containsKey('removed_hlc') ? 'removed_hlc IS NULL' : 'deleted_at IS NULL';
    final rows = await db
        .customSelect(
          'SELECT id FROM ${ref.entity} WHERE tenant_id = ? AND ${ref.column} = ? AND $live',
          variables: [t, Variable<String>(old)],
          readsFrom: {table},
        )
        .get();
    for (final r in rows) {
      repointed.add((entity: ref.entity, rowId: r.read<String>('id'), column: ref.column));
    }
    await db.customUpdate(
      'UPDATE ${ref.entity} SET ${ref.column} = ? WHERE tenant_id = ? AND ${ref.column} = ?',
      variables: [Variable<String>(newId), t, Variable<String>(old)],
      updates: {table},
      updateKind: UpdateKind.update,
    );
  }

  // 3. PENDING ops only — pushed ops are history and stay as they were.
  await db.customUpdate(
    "UPDATE sync_ops SET entity_id = ? WHERE tenant_id = ? AND pushed_at IS NULL AND entity = 'plants' AND entity_id = ?",
    variables: [Variable<String>(newId), t, Variable<String>(old)],
    updates: {db.syncOps},
    updateKind: UpdateKind.update,
  );
  final children = {for (final ref in kPlantIdColumns) ref.entity};
  final entityMarks = List.filled(children.length + 1, '?').join(', ');
  final pending = await db
      .customSelect(
        'SELECT seq, entity, entity_id, field, value_json FROM sync_ops '
        'WHERE tenant_id = ? AND pushed_at IS NULL AND value_json IS NOT NULL AND entity IN ($entityMarks)',
        variables: [t, Variable<String>('plants'), for (final e in children) Variable<String>(e)],
        readsFrom: {db.syncOps},
      )
      .get();
  for (final p in pending) {
    final entity = p.read<String>('entity');
    if (entity == 'plants' && p.read<String>('entity_id') != newId) continue;
    final rewritten = _rewritePayload(
      entity: entity,
      field: p.read<String>('field'),
      valueJson: p.read<String>('value_json'),
      old: old,
      newId: newId,
    );
    if (rewritten == null) continue;
    await db.customUpdate(
      'UPDATE sync_ops SET value_json = ? WHERE seq = ?',
      variables: [Variable<String>(rewritten), Variable<int>(p.read<int>('seq'))],
      updates: {db.syncOps},
      updateKind: UpdateKind.update,
    );
  }

  // 4. Synced tenant: tell peers. Local tenants emit nothing — their
  //    re-pointed pending ops go out after a future link.
  if (!emitOps) return 0;
  final w = OpLogWriter(db: db, clock: clock, tenantId: tenant);
  try {
    var emitted = 0;
    await w.recordTombstone(entity: 'plants', entityId: old);
    emitted++;
    final row = (await db
            .customSelect('SELECT * FROM plants WHERE id = ?', variables: [Variable<String>(newId)], readsFrom: {db.plants})
            .getSingle())
        .data;
    final hlc = await w.recordCreate(entity: 'plants', entityId: newId, value: {...row, 'id': newId});
    emitted++;
    await db.customUpdate(
      'UPDATE plants SET updated_hlc = ?, device_id = ? WHERE id = ?',
      variables: [Variable<String>(hlc.encode()), Variable<String>(clock.deviceId), Variable<String>(newId)],
      updates: {db.plants},
      updateKind: UpdateKind.update,
    );
    for (final c in repointed) {
      final h = await w.recordFieldUpdate(entity: c.entity, entityId: c.rowId, field: c.column, value: newId);
      emitted++;
      final table = tables[c.entity]!;
      final hlcColumn = table.columnsByName.containsKey('added_hlc') ? 'added_hlc' : 'updated_hlc';
      await db.customUpdate(
        'UPDATE ${c.entity} SET $hlcColumn = ?, device_id = ? WHERE id = ?',
        variables: [Variable<String>(h.encode()), Variable<String>(clock.deviceId), Variable<String>(c.rowId)],
        updates: {table},
        updateKind: UpdateKind.update,
      );
    }
    return emitted;
  } finally {
    await w.dispose();
  }
}

/// New `value_json` for a pending op that mentions [old], or null when the
/// payload does not reference it. `*` payloads carry the id in `id`
/// (plants) or one of the FK columns (children); single-field ops carry it
/// as the bare value when `field` is an FK column.
String? _rewritePayload({
  required String entity,
  required String field,
  required String valueJson,
  required String old,
  required String newId,
}) {
  final Object? decoded;
  try {
    decoded = json.decode(valueJson);
  } on FormatException {
    return null;
  }
  if (field == kWholeRowField) {
    if (decoded is! Map) return null;
    final keys = entity == 'plants' ? const ['id'] : _fkColumns;
    var changed = false;
    for (final k in keys) {
      if (decoded[k] == old) {
        decoded[k] = newId;
        changed = true;
      }
    }
    return changed ? json.encode(decoded) : null;
  }
  if (entity != 'plants' && _fkColumns.contains(field) && decoded == old) return json.encode(newId);
  return null;
}
