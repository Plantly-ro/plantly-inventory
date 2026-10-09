import 'package:drift/drift.dart';

/// One-shot passes already done, per tenant (e.g. `SyncApplier`'s re-apply
/// of 1.1.0 `@applyCareEvent` ops). Deliberately not a Drift table (no
/// schema bump for a cache of "already done" flags): created on first use,
/// lives in the database so it is lost together with the data it describes.
/// Every path that discards a tenant's `sync_ops` must also drop its markers
/// ([clearSyncMarkers]) so a later reuse of the tenant id re-runs the pass.
const String kSyncMarkersTable = 'sync_markers';

Future<void> ensureSyncMarkersTable(DatabaseConnectionUser db) => db.customStatement(
      'CREATE TABLE IF NOT EXISTS $kSyncMarkersTable ('
      'tenant_id TEXT NOT NULL, name TEXT NOT NULL, at INTEGER NOT NULL, '
      'PRIMARY KEY (tenant_id, name))',
    );

Future<bool> hasSyncMarker(DatabaseConnectionUser db, {required String tenantId, required String name}) async {
  await ensureSyncMarkersTable(db);
  final row = await db.customSelect(
    'SELECT 1 FROM $kSyncMarkersTable WHERE tenant_id = ? AND name = ?',
    variables: [Variable<String>(tenantId), Variable<String>(name)],
  ).getSingleOrNull();
  return row != null;
}

Future<void> setSyncMarker(
  DatabaseConnectionUser db, {
  required String tenantId,
  required String name,
  required int atMillis,
}) async {
  await ensureSyncMarkersTable(db);
  await db.customStatement(
    'INSERT OR REPLACE INTO $kSyncMarkersTable (tenant_id, name, at) VALUES (?, ?, ?)',
    [tenantId, name, atMillis],
  );
}

/// Drop the markers of [tenantId] (every tenant when null). A no-op when
/// the table was never created.
Future<void> clearSyncMarkers(DatabaseConnectionUser db, {String? tenantId}) async {
  final exists = await db.customSelect(
    "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
    variables: [Variable<String>(kSyncMarkersTable)],
  ).getSingleOrNull();
  if (exists == null) return;
  if (tenantId == null) {
    await db.customStatement('DELETE FROM $kSyncMarkersTable');
  } else {
    await db.customStatement('DELETE FROM $kSyncMarkersTable WHERE tenant_id = ?', [tenantId]);
  }
}
