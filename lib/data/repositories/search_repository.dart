import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Full-text search over the plants table via the FTS5 virtual table
/// `plants_fts`. Returns matching plants ordered by relevance (FTS5 `rank`).
class SearchRepository {
  SearchRepository({required this.db, required this.tenantId});

  final AppDatabase db;
  final String tenantId;

  /// Run an FTS5 MATCH query. [rawQuery] is the user's input; we apply
  /// prefix matching (`*`) to each token so typing "mons" finds "monstera".
  Future<List<PlantRow>> search(String rawQuery, {int limit = 50}) async {
    final q = _sanitize(rawQuery);
    if (q.isEmpty) return const [];

    final results = await db.customSelect(
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

    return results.map((row) => db.plants.map(row.data)).toList(growable: false);
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
    // Wrap in double quotes + escape inner quotes → safe against any FTS5
    // syntax (booleans, operators, punctuation).
    final escaped = token.replaceAll('"', '""');
    return '"$escaped"';
  }
}
