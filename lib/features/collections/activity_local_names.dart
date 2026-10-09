import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cloud/collection_activity.dart';
import '../../data/database/app_database.dart';
import '../../data/providers.dart';
import '../../marketplace/activity_models.dart';

/// Key of [resolveActivityNames]' map.
String activityNameKey(String entity, String entityId) => '$entity/$entityId';

/// Local display names for activity events the server sent without a
/// `summary.name` ("qafinal1 edited a plant" → "… edited Monstera"): the
/// plant itself, or the plant a reminder / care entry / photo belongs to,
/// or the space — read from this device's copy of [tenantId] (deleted rows
/// included, so "deleted Monstera" still names it). Events whose row never
/// reached this device stay unnamed.
Future<Map<String, String>> resolveActivityNames(AppDatabase db, String tenantId, Iterable<ActivityEvent> events) async {
  final byEntity = <String, Set<String>>{};
  for (final e in events) {
    if ((e.summaryName ?? '').trim().isNotEmpty || e.entityId.isEmpty) continue;
    byEntity.putIfAbsent(e.entity, () => <String>{}).add(e.entityId);
  }
  if (byEntity.isEmpty) return const {};

  const queries = <String, String>{
    'plants': 'SELECT id AS k, nickname AS n FROM plants WHERE tenant_id = ? AND id IN',
    'locations': 'SELECT id AS k, name AS n FROM locations WHERE tenant_id = ? AND id IN',
    'care_schedules': 'SELECT s.id AS k, p.nickname AS n FROM care_schedules s JOIN plants p ON p.id = s.plant_id '
        'WHERE s.tenant_id = ? AND s.id IN',
    'care_events': 'SELECT e.id AS k, p.nickname AS n FROM care_events e JOIN plants p ON p.id = e.plant_id '
        'WHERE e.tenant_id = ? AND e.id IN',
    'plant_photos': 'SELECT pp.id AS k, p.nickname AS n FROM plant_photos pp JOIN plants p ON p.id = pp.plant_id '
        'WHERE pp.tenant_id = ? AND pp.id IN',
    'location_photos': 'SELECT lp.id AS k, l.name AS n FROM location_photos lp JOIN locations l ON l.id = lp.location_id '
        'WHERE lp.tenant_id = ? AND lp.id IN',
    // `photos` rows are keyed by sha: name the plant (else space) showing it.
    'photos': 'SELECT pp.photo_sha AS k, p.nickname AS n FROM plant_photos pp JOIN plants p ON p.id = pp.plant_id '
        'WHERE pp.tenant_id = ? AND pp.photo_sha IN',
  };

  final out = <String, String>{};
  for (final MapEntry(key: entity, value: ids) in byEntity.entries) {
    final sql = queries[entity];
    if (sql == null) continue;
    final list = ids.toList(growable: false);
    for (var i = 0; i < list.length; i += 400) {
      final chunk = list.sublist(i, i + 400 > list.length ? list.length : i + 400);
      final marks = List.filled(chunk.length, '?').join(', ');
      final rows = await db.customSelect(
        '$sql ($marks)',
        variables: [Variable<String>(tenantId), for (final id in chunk) Variable<String>(id)],
      ).get();
      for (final r in rows) {
        final name = (r.read<String?>('n') ?? '').trim();
        if (name.isNotEmpty) out.putIfAbsent(activityNameKey(entity, r.read<String>('k')), () => name);
      }
    }
    if (entity == 'photos') {
      final missing = [for (final id in list) if (!out.containsKey(activityNameKey(entity, id))) id];
      if (missing.isEmpty) continue;
      final marks = List.filled(missing.length, '?').join(', ');
      final rows = await db.customSelect(
        'SELECT lp.photo_sha AS k, l.name AS n FROM location_photos lp JOIN locations l ON l.id = lp.location_id '
        'WHERE lp.tenant_id = ? AND lp.photo_sha IN ($marks)',
        variables: [Variable<String>(tenantId), for (final id in missing) Variable<String>(id)],
      ).get();
      for (final r in rows) {
        final name = (r.read<String?>('n') ?? '').trim();
        if (name.isNotEmpty) out.putIfAbsent(activityNameKey(entity, r.read<String>('k')), () => name);
      }
    }
  }
  return out;
}

/// [resolveActivityNames] for the feed of a collection (its id is the local
/// tenant id); follows the feed as it loads / pages.
final activityLocalNamesProvider = FutureProvider.autoDispose.family<Map<String, String>, String>((ref, collectionId) async {
  final events = ref.watch(collectionActivityProvider(collectionId).select((s) => s.events));
  final db = ref.watch(databaseProvider);
  try {
    return await resolveActivityNames(db, collectionId, events);
  } catch (_) {
    return const {}; // names are a nicety — never break the feed
  }
});
