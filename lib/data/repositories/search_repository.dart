import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Search over the plants table — FTS5 MATCH on nickname + notes, plus
/// tag-name lookup (so typing "variegated" finds every plant tagged
/// `#variegated`).
class SearchRepository {
  SearchRepository({required this.db, required this.tenantId});

  final AppDatabase db;
  final String tenantId;

  /// Run an FTS5 MATCH query + union tag-matched plants. [rawQuery] is
  /// the user's input; we apply prefix matching (`*`) to each token so
  /// typing "mons" finds "monstera".
  Future<List<PlantRow>> search(String rawQuery, {int limit = 50}) async {
    final trimmed = rawQuery.trim();
    if (trimmed.isEmpty) return const [];
    final q = _sanitize(trimmed);
    final tokens = trimmed
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => t.toLowerCase())
        .toList(growable: false);

    // Use a LinkedHashSet behaviour via LinkedHashMap of id → PlantRow so
    // each plant appears at most once and in FTS-then-tag order.
    final byId = <String, PlantRow>{};

    if (q.isNotEmpty) {
      final ftsResults = await db.customSelect(
        '''
        SELECT plants.* FROM plants
        INNER JOIN plants_fts ON plants_fts.plant_id = plants.id
        WHERE plants_fts MATCH ?1
          AND plants.tenant_id = ?2
          AND plants.deleted_at IS NULL
        ORDER BY plants_fts.rank
        LIMIT ?3
        ''',
        variables: [Variable(q), Variable(tenantId), Variable(limit)],
        readsFrom: {db.plants},
      ).get();
      for (final row in ftsResults) {
        final plant = db.plants.map(row.data);
        byId[plant.id] = plant;
      }
    }

    // Tag pass — find any tag whose name contains one of the tokens as
    // a prefix, then pull every live `plant_tags` row pointing at it.
    if (tokens.isNotEmpty && byId.length < limit) {
      final likeClauses = tokens.map((_) => 'name LIKE ?').join(' OR ');
      final tagArgs = <Variable<Object>>[
        for (final t in tokens) Variable('$t%'),
        Variable(tenantId),
      ];
      final tagHits = await db.customSelect(
        '''
        SELECT id FROM tags
        WHERE ($likeClauses)
          AND tenant_id = ?
          AND deleted_at IS NULL
        ''',
        variables: tagArgs,
        readsFrom: {db.tags},
      ).get();
      final tagIds = [for (final t in tagHits) t.data['id'] as String];
      if (tagIds.isNotEmpty) {
        final placeholders = List.filled(tagIds.length, '?').join(',');
        final plantRows = await db.customSelect(
          '''
          SELECT DISTINCT plants.*
          FROM plants
          INNER JOIN plant_tags pt ON pt.plant_id = plants.id
          WHERE pt.tag_id IN ($placeholders)
            AND pt.removed_hlc IS NULL
            AND plants.tenant_id = ?
            AND plants.deleted_at IS NULL
          ORDER BY plants.nickname
          LIMIT ?
          ''',
          variables: [
            for (final id in tagIds) Variable(id),
            Variable(tenantId),
            Variable(limit - byId.length),
          ],
          readsFrom: {db.plants, db.plantTags},
        ).get();
        for (final row in plantRows) {
          final plant = db.plants.map(row.data);
          byId.putIfAbsent(plant.id, () => plant);
        }
      }
    }

    return byId.values.take(limit).toList(growable: false);
  }

  /// Tokenize + escape. FTS5 treats `"` as a phrase delimiter and reserves
  /// a handful of operators (AND, OR, NOT, NEAR, ^, -, :); splitting on
  /// whitespace and appending `*` to each token gives robust prefix search.
  String _sanitize(String raw) {
    final tokens = raw
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map(_escapeToken)
        .toList();
    if (tokens.isEmpty) return '';
    return tokens.map((t) => '$t*').join(' ');
  }

  String _escapeToken(String token) {
    final escaped = token.replaceAll('"', '""');
    return '"$escaped"';
  }
}
