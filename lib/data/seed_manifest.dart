import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/generated/app_localizations.dart';
import '../sync/hlc.dart';
import 'database/app_database.dart';
import 'mock_plants.dart';
import 'providers.dart' show kDefaultTenantId, kSkipSeedPrefKey;
import 'seed.dart' show seedPlantName;

/// Which `sync_ops` the demo seed wrote ([seedIfEmpty]): a list of
/// `(from, to]` ranges of `sync_ops.seq` (AUTOINCREMENT, never reused).
/// A row whose create op lies in a range is a seed row; it is *untouched*
/// while every op it has lies in a range too (an edit, a care event, a
/// photo… all leave ops / rows outside them).
const String kSeedManifestPrefKey = 'plantly_seed_manifest';

/// Highest `sync_ops.seq` so far (0 when the log is empty).
Future<int> maxSyncOpSeq(AppDatabase db) async {
  final row = await db
      .customSelect('SELECT COALESCE(MAX(seq), 0) AS m FROM sync_ops', readsFrom: {db.syncOps})
      .getSingle();
  return row.read<int>('m');
}

List<(int, int)> _readRanges(SharedPreferences prefs) {
  final raw = prefs.getString(kSeedManifestPrefKey);
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = json.decode(raw);
    final ranges = decoded is Map ? decoded['ranges'] : null;
    if (ranges is! List) return const [];
    return [
      for (final r in ranges)
        if (r is List && r.length == 2 && r[0] is int && r[1] is int) (r[0] as int, r[1] as int),
    ];
  } on FormatException {
    return const [];
  }
}

/// Remember that the seed wrote the ops with `from < seq <= to`.
Future<void> recordSeedOpRange(SharedPreferences prefs, int from, int to) async {
  if (to <= from) return;
  final ranges = [..._readRanges(prefs), (from, to)];
  await prefs.setString(
    kSeedManifestPrefKey,
    json.encode({
      'ranges': [for (final r in ranges) [r.$1, r.$2]],
    }),
  );
}

/// What [dropUntouchedSeed] removed.
class SeedDropReport {
  const SeedDropReport({this.plants = const {}, this.locations = const {}, this.schedules = const {}});
  final Set<String> plants;
  final Set<String> locations;
  final Set<String> schedules;
  bool get isEmpty => plants.isEmpty && locations.isEmpty && schedules.isEmpty;
  @override
  String toString() =>
      'SeedDropReport(plants: ${plants.length}, locations: ${locations.length}, schedules: ${schedules.length})';
}

/// Max spread of a pre-manifest install's seed burst (the seed writes its
/// ~20 rows in one tight loop on first launch).
const Duration kLegacySeedBurst = Duration(seconds: 5);

/// How many of the 8 demo plants a legacy fingerprint needs.
const int kLegacySeedMinPlants = 6;

/// The schedule each demo plant was seeded with ([seedIfEmpty]).
const Map<String, ({String type, double interval})> kSeedFixtureSchedules = {
  'bob': (type: 'water', interval: 7),
  'green': (type: 'fertilize', interval: 30),
  'snake': (type: 'water', interval: 14),
  'cala': (type: 'mist', interval: 3),
  'fid': (type: 'rotate', interval: 7),
  'fern': (type: 'water', interval: 3),
  'suc': (type: 'water', interval: 14),
  'pete': (type: 'water', interval: 14),
};

/// Demo nickname (any shipped locale, plus the fixture names older builds
/// wrote verbatim) → fixture id.
Map<String, String> legacySeedPlantNames() => {
      for (final m in MockPlants.all) m.name: m.id,
      for (final l in AppLocalizations.supportedLocales)
        for (final m in MockPlants.all) seedPlantName(lookupAppLocalizations(Locale(l.languageCode)), m): m.id,
    };

/// Demo space names per role, every shipped locale.
({Set<String> home, Set<String> room, Set<String> balcony}) legacySeedSpaceNames() {
  final ts = [for (final l in AppLocalizations.supportedLocales) lookupAppLocalizations(Locale(l.languageCode))];
  return (
    home: {for (final t in ts) t.seedSpaceHome},
    room: {for (final t in ts) t.seedSpaceLivingRoom},
    balcony: {for (final t in ts) t.seedSpaceBalcony},
  );
}

typedef _Op = ({int seq, String field, Hlc? hlc, String device});
typedef _Window = ({int from, int to});

/// Hard-deletes the demo seed rows of [tenant] that the user never touched,
/// so linking a device never pushes demo plants into a real collection.
///
/// Seed rows are recognised by the manifest ([kSeedManifestPrefKey]) when
/// one exists — then ONLY by it. Without one (installs seeded by a build
/// before the manifest) a legacy fingerprint must match in full, else
/// nothing is dropped (when in doubt, keep the data):
///   * ≥ [kLegacySeedMinPlants] distinct demo plants created by this device
///     in one burst ≤ [kLegacySeedBurst], each with its fixture schedule
///     (type + interval, [kSeedFixtureSchedules]) in the same burst;
///   * the 3 demo spaces in their shape (Home ← Living room, Home ←
///     Balcony) created by this device in one burst.
/// The legacy path never runs on web, on a tenant other than the pre-cloud
/// `local`, or once [kSkipSeedPrefKey] is set — none of those was seeded.
///
/// A seed row is dropped only while *untouched*: every op it has is a seed
/// op and nothing else references it —
///   * plant: no care event, photo, tag or inventory transaction, and every
///     care schedule of it is itself an untouched seed schedule;
///   * location: no photo, no surviving plant in it, no surviving child.
///
/// Only for local tenants (never pushed): rows and their ops are deleted
/// outright, no tombstones. One transaction.
Future<SeedDropReport> dropUntouchedSeed({
  required AppDatabase db,
  required String tenant,
  required SharedPreferences prefs,
  required String deviceId,
  bool web = false,
}) async {
  final ranges = _readRanges(prefs);
  final manifest = ranges.isNotEmpty;
  final legacyAllowed =
      !manifest && !web && tenant == kDefaultTenantId && !(prefs.getBool(kSkipSeedPrefKey) ?? false);
  if (!manifest && !legacyAllowed) return const SeedDropReport();
  bool inSeed(int seq) => ranges.any((r) => seq > r.$1 && seq <= r.$2);

  return db.transaction(() async {
    final opRows = await db
        .customSelect(
          "SELECT seq, entity, entity_id, field, hlc, device_id FROM sync_ops WHERE tenant_id = ? "
          "AND entity IN ('plants', 'locations', 'care_schedules') ORDER BY seq",
          variables: [Variable<String>(tenant)],
          readsFrom: {db.syncOps},
        )
        .get();
    final ops = <String, List<_Op>>{};
    for (final r in opRows) {
      Hlc? h;
      try {
        h = Hlc.parse(r.read<String>('hlc'));
      } catch (_) {
        h = null;
      }
      ops
          .putIfAbsent('${r.read<String>('entity')}/${r.read<String>('entity_id')}', () => [])
          .add((seq: r.read<int>('seq'), field: r.read<String>('field'), hlc: h, device: r.read<String>('device_id')));
    }

    final plants = await (db.select(db.plants)..where((p) => p.tenantId.equals(tenant))).get();
    final locations = await (db.select(db.locations)..where((l) => l.tenantId.equals(tenant))).get();
    final schedules = await (db.select(db.careSchedules)..where((s) => s.tenantId.equals(tenant))).get();

    /// Create time of [key] when its first op is a `*` by this device.
    int? createdAt(String key) {
      final list = ops[key];
      if (list == null || list.isEmpty) return null;
      final first = list.first;
      if (first.field != '*' || first.hlc == null || first.device != deviceId) return null;
      return first.hlc!.physicalMs;
    }

    bool inWindow(_Op op, _Window w) =>
        op.hlc != null && op.device == deviceId && op.hlc!.physicalMs >= w.from && op.hlc!.physicalMs <= w.to;

    bool untouchedByManifest(String key) {
      final list = ops[key];
      if (list == null || list.isEmpty || list.first.field != '*') return false;
      return list.every((o) => inSeed(o.seq));
    }

    bool untouchedInWindow(String key, _Window w) {
      final list = ops[key];
      if (list == null || list.isEmpty || list.first.field != '*') return false;
      return list.every((o) => inWindow(o, w));
    }

    // --- legacy fingerprint --------------------------------------------------
    _Window? plantWindow;
    _Window? spaceWindow;
    var legacyPlants = <String>{};
    var legacySpaces = <String>{};
    if (legacyAllowed) {
      final burst = kLegacySeedBurst.inMilliseconds;
      final names = legacySeedPlantNames();
      final candidates = <({PlantRow plant, String mock, int at})>[];
      for (final p in plants) {
        final mock = names[p.nickname];
        final at = createdAt('plants/${p.id}');
        if (mock != null && at != null) candidates.add((plant: p, mock: mock, at: at));
      }
      candidates.sort((a, b) => a.at.compareTo(b.at));
      bool fixtureSchedule(PlantRow p, String mock, _Window w) {
        final f = kSeedFixtureSchedules[mock]!;
        return schedules.any((s) {
          if (s.plantId != p.id || s.type != f.type || s.baseIntervalDays != f.interval) return false;
          final at = createdAt('care_schedules/${s.id}');
          return at != null && at >= w.from && at <= w.to;
        });
      }

      for (final c in candidates) {
        final w = (from: c.at, to: c.at + burst);
        final inBurst = candidates.where((o) => o.at >= w.from && o.at <= w.to).toList();
        final mocks = inBurst.map((o) => o.mock).toList();
        // Two plants claiming the same demo slot: not the seed's doing.
        if (mocks.toSet().length != mocks.length) continue;
        final matched = {
          for (final o in inBurst)
            if (fixtureSchedule(o.plant, o.mock, w)) o.plant.id,
        };
        if (matched.length >= kLegacySeedMinPlants && matched.length > legacyPlants.length) {
          legacyPlants = matched;
          plantWindow = w;
        }
      }

      final spaceNames = legacySeedSpaceNames();
      final triples = <Set<String>>[];
      for (final home in locations) {
        if (!spaceNames.home.contains(home.name) || home.kind != 'home' || home.parentId != null) continue;
        final rooms = locations
            .where((l) => l.parentId == home.id && l.kind == 'room' && spaceNames.room.contains(l.name))
            .toList();
        final balconies = locations
            .where((l) => l.parentId == home.id && l.kind == 'outdoor_bed' && spaceNames.balcony.contains(l.name))
            .toList();
        if (rooms.length != 1 || balconies.length != 1) continue;
        final times = [
          createdAt('locations/${home.id}'),
          createdAt('locations/${rooms.single.id}'),
          createdAt('locations/${balconies.single.id}'),
        ];
        if (times.contains(null)) continue;
        final ts = times.cast<int>()..sort();
        if (ts.last - ts.first > burst) continue;
        triples.add({home.id, rooms.single.id, balconies.single.id});
        spaceWindow = (from: ts.first, to: ts.first + burst);
      }
      // Exactly one demo space tree, and the plants matched too — or nothing.
      if (triples.length == 1 && legacyPlants.isNotEmpty) {
        legacySpaces = triples.single;
      } else {
        legacyPlants = {};
        legacySpaces = {};
      }
    }

    bool seedPlantUntouched(PlantRow p) => manifest
        ? untouchedByManifest('plants/${p.id}')
        : legacyPlants.contains(p.id) && untouchedInWindow('plants/${p.id}', plantWindow!);
    bool seedScheduleUntouched(CareScheduleRow s) => manifest
        ? untouchedByManifest('care_schedules/${s.id}')
        : untouchedInWindow('care_schedules/${s.id}', plantWindow!);
    bool seedSpaceUntouched(LocationRow l) => manifest
        ? untouchedByManifest('locations/${l.id}')
        : legacySpaces.contains(l.id) && untouchedInWindow('locations/${l.id}', spaceWindow!);

    Future<bool> referenced(String table, String column, String id) async {
      final row = await db
          .customSelect(
            'SELECT EXISTS(SELECT 1 FROM $table WHERE tenant_id = ? AND $column = ?) AS present',
            variables: [Variable<String>(tenant), Variable<String>(id)],
          )
          .getSingle();
      return row.read<bool>('present');
    }

    // --- plants ---------------------------------------------------------------
    final dropPlants = <String>{};
    final dropSchedules = <String>{};
    for (final p in plants) {
      if (!seedPlantUntouched(p)) continue;
      if (await referenced('care_events', 'plant_id', p.id)) continue;
      if (await referenced('plant_photos', 'plant_id', p.id)) continue;
      if (await referenced('plant_tags', 'plant_id', p.id)) continue;
      if (await referenced('inventory_transactions', 'plant_id', p.id)) continue;
      if (await referenced('inventory_transactions', 'parent_plant_id', p.id)) continue;
      if (await referenced('inventory_transactions', 'child_plant_id', p.id)) continue;
      final own = schedules.where((s) => s.plantId == p.id).toList();
      if (!own.every(seedScheduleUntouched)) continue;
      dropPlants.add(p.id);
      dropSchedules.addAll(own.map((s) => s.id));
    }

    // --- locations (children first: iterate to a fixpoint) ----------------------
    final keptPlantLocations = {
      for (final p in plants)
        if (!dropPlants.contains(p.id) && p.locationId != null) p.locationId!,
    };
    final candidates = <String>{};
    for (final l in locations) {
      if (!seedSpaceUntouched(l)) continue;
      if (keptPlantLocations.contains(l.id)) continue;
      if (await referenced('location_photos', 'location_id', l.id)) continue;
      candidates.add(l.id);
    }
    var changed = true;
    while (changed) {
      changed = false;
      for (final l in locations) {
        if (!candidates.contains(l.id)) continue;
        final keptChild = locations.any((c) => c.parentId == l.id && !candidates.contains(c.id));
        if (keptChild) {
          candidates.remove(l.id);
          changed = true;
        }
      }
    }

    // --- delete ---------------------------------------------------------------
    Future<void> deleteRows(TableInfo table, String entity, Set<String> ids) async {
      for (final id in ids) {
        await db.customUpdate(
          'DELETE FROM ${table.actualTableName} WHERE tenant_id = ? AND id = ?',
          variables: [Variable<String>(tenant), Variable<String>(id)],
          updates: {table},
          updateKind: UpdateKind.delete,
        );
        await db.customUpdate(
          'DELETE FROM sync_ops WHERE tenant_id = ? AND entity = ? AND entity_id = ?',
          variables: [Variable<String>(tenant), Variable<String>(entity), Variable<String>(id)],
          updates: {db.syncOps},
          updateKind: UpdateKind.delete,
        );
      }
    }

    await deleteRows(db.careSchedules, 'care_schedules', dropSchedules);
    await deleteRows(db.plants, 'plants', dropPlants);
    await deleteRows(db.locations, 'locations', candidates);
    return SeedDropReport(plants: dropPlants, locations: candidates, schedules: dropSchedules);
  });
}

/// Forget the manifest (after the seed was dropped / the tenant linked).
Future<void> clearSeedManifest(SharedPreferences prefs) => prefs.remove(kSeedManifestPrefKey);
