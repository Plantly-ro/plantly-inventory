import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/app_database.dart';
import '../../sync/hlc.dart';
import '../../sync/op_log.dart';

/// JSON backup / import with HMAC signature.
///
/// Every non-deleted row of the active tenant (collection) from every
/// synced table is serialised into a single JSON document; the document
/// (sans the `signature` field) is signed with HMAC-SHA256 under a
/// user-supplied secret, and the base64 mac is stored alongside. Import
/// refuses to apply any backup whose mac doesn't verify.
///
/// Tenant scope (format v1, unchanged on the wire): a device may hold
/// several tenants — one per collection the account can see, plus rows
/// parked by a previous account. A backup covers exactly one: the
/// [tenantId] this service was built for. The `tenant_id` column is still
/// written into the file, but it is **informational only**: [import] stamps
/// every restored row (and the op it emits) with the importing device's
/// active tenant, so a backup made under one account/collection lands in
/// the collection the user is looking at, never in a parked one.
///
/// Photo bytes are out of scope for this format — see `ZipBackupService`;
/// the `photos` metadata rows are included ([photosInScope]).
class BackupService {
  BackupService({required this.db, required this.tenantId});
  final AppDatabase db;

  /// The tenant (collection id) exported from and imported into.
  final String tenantId;

  static const int currentFormatVersion = 1;

  /// Serialize the active tenant's data (non-deleted rows only) to a
  /// signed JSON blob. [secret] is the passphrase the user will also need
  /// to import this file — we never persist it.
  Future<String> export({required String secret}) async {
    // Pull user preferences that live outside Drift so the round-trip is
    // complete: custom care types, home-widget layout, theme mode.
    final prefs = await SharedPreferences.getInstance();
    final prefSnapshot = <String, Object?>{
      for (final key in const ['plantly_care_types', 'plantly_layout', 'plantly_theme', 'plantly_plant_sort'])
        if (prefs.containsKey(key)) key: prefs.get(key),
    };
    final body = <String, Object?>{
      'format': 'plantly_inventory.backup',
      'version': currentFormatVersion,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'plants': await _rows(db.plants),
      'locations': await _rows(db.locations),
      'species': await _rows(db.species),
      'photos': [for (final r in await _photoQueryRows()) Map<String, dynamic>.from(r.data)],
      'plant_photos': await _rows(db.plantPhotos),
      'tags': await _rows(db.tags),
      'plant_tags': await _rows(db.plantTags),
      'care_events': await _rows(db.careEvents),
      'care_schedules': await _rows(db.careSchedules),
      'inventory_transactions': await _rows(db.inventoryTransactions),
      'location_photos': await _rows(db.locationPhotos),
      'prefs': prefSnapshot,
    };
    final canonical = json.encode(body);
    final mac = _hmac(canonical, secret);
    return json.encode({
      'signature': mac,
      'payload': body,
    });
  }

  /// Import a previously exported blob. Throws [BackupSignatureError] if
  /// the HMAC doesn't verify with [secret], or [BackupFormatError] on
  /// shape mismatches. On success, the import upserts every row into
  /// [tenantId] transactionally (the file's own `tenant_id` values are
  /// ignored) and emits a whole-row op per row so peers can converge.
  /// [opLog] must write under the same tenant.
  Future<BackupImportResult> import({
    required String blob,
    required String secret,
    required OpLogWriter opLog,
  }) async {
    if (opLog.tenantId != tenantId) {
      throw ArgumentError.value(
        opLog.tenantId,
        'opLog',
        'op log writes under a different tenant than this service ($tenantId)',
      );
    }
    final Map<String, dynamic> envelope;
    try {
      envelope = json.decode(blob) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw BackupFormatError('Not valid JSON: ${e.message}');
    }
    final sig = envelope['signature'];
    final payload = envelope['payload'];
    if (sig is! String || payload is! Map<String, dynamic>) {
      throw const BackupFormatError('Missing signature or payload');
    }
    final canonical = json.encode(payload);
    final expected = _hmac(canonical, secret);
    if (!_constantTimeEquals(sig, expected)) {
      throw const BackupSignatureError('HMAC signature mismatch');
    }
    final format = payload['format'];
    if (format != 'plantly_inventory.backup') {
      throw BackupFormatError('Unknown backup format: $format');
    }
    final version = payload['version'];
    if (version != currentFormatVersion) {
      throw BackupFormatError('Unsupported backup version: $version');
    }

    final counts = <String, int>{};
    await db.transaction(() async {
      counts['plants'] = await _restore(db.plants, payload['plants'], opLog, 'plants');
      counts['locations'] = await _restore(db.locations, payload['locations'], opLog, 'locations');
      counts['species'] = await _restore(db.species, payload['species'], opLog, 'species');
      counts['photos'] = await _restore(db.photos, payload['photos'], opLog, 'photos');
      counts['plant_photos'] = await _restore(db.plantPhotos, payload['plant_photos'], opLog, 'plant_photos');
      counts['tags'] = await _restore(db.tags, payload['tags'], opLog, 'tags');
      counts['plant_tags'] = await _restore(db.plantTags, payload['plant_tags'], opLog, 'plant_tags');
      counts['care_events'] = await _restore(db.careEvents, payload['care_events'], opLog, 'care_events');
      counts['care_schedules'] = await _restore(db.careSchedules, payload['care_schedules'], opLog, 'care_schedules');
      counts['inventory_transactions'] = await _restore(
        db.inventoryTransactions,
        payload['inventory_transactions'],
        opLog,
        'inventory_transactions',
      );
      counts['location_photos'] = await _restore(
        db.locationPhotos,
        payload['location_photos'],
        opLog,
        'location_photos',
      );
    });
    // Replay the user preferences blob (custom care types / layout /
    // theme / sort). Guards each value against the expected type so a
    // broken backup can't crash the app on read.
    final prefsBlob = payload['prefs'];
    if (prefsBlob is Map<String, dynamic>) {
      final prefs = await SharedPreferences.getInstance();
      for (final entry in prefsBlob.entries) {
        final v = entry.value;
        if (v is String) {
          await prefs.setString(entry.key, v);
        } else if (v is int) {
          await prefs.setInt(entry.key, v);
        } else if (v is bool) {
          await prefs.setBool(entry.key, v);
        } else if (v is double) {
          await prefs.setDouble(entry.key, v);
        } else if (v is List) {
          await prefs.setStringList(entry.key, v.whereType<String>().toList());
        }
      }
    }
    return BackupImportResult(rowsImported: counts);
  }

  Future<List<Map<String, dynamic>>> _rows(TableInfo<Table, dynamic> table) async {
    assert(table.$columns.any((c) => c.name == 'tenant_id'), '${table.actualTableName} is not tenant-scoped');
    // OR-Set join tables (plant_photos, plant_tags) use added_hlc/removed_hlc
    // instead of a `deleted_at` tombstone, so we only apply the filter when
    // the column actually exists on this table.
    final hasDeletedAt = table.$columns.any((c) => c.name == 'deleted_at');
    final sql = 'SELECT * FROM ${table.actualTableName} WHERE tenant_id = ?'
        '${hasDeletedAt ? ' AND deleted_at IS NULL' : ''}';
    final rows = await db.customSelect(sql, variables: [Variable<String>(tenantId)], readsFrom: {table}).get();
    return rows.map((r) => Map<String, dynamic>.from(r.data)).toList(growable: false);
  }

  /// `photos` is content-addressed (PK = sha) and shared across the tenants
  /// on a device: a row keeps the stamp of whichever tenant stored it first,
  /// while other collections may attach the same sha. In scope for this
  /// tenant's backup: rows stamped [tenantId], plus rows still referenced
  /// by one of its live join rows (plant / location galleries) or care
  /// events. Nothing else — a parked account's photos never leave the device.
  static const String _photosInScopeSql = '''
SELECT * FROM photos
WHERE deleted_at IS NULL AND (
  tenant_id = ?
  OR sha256 IN (SELECT photo_sha FROM plant_photos WHERE tenant_id = ? AND removed_hlc IS NULL)
  OR sha256 IN (SELECT photo_sha FROM location_photos WHERE tenant_id = ? AND removed_hlc IS NULL)
  OR sha256 IN (SELECT photo_sha FROM care_events WHERE tenant_id = ? AND deleted_at IS NULL AND photo_sha IS NOT NULL)
)
ORDER BY sha256''';

  Future<List<QueryRow>> _photoQueryRows() => db.customSelect(
        _photosInScopeSql,
        variables: [for (var i = 0; i < 4; i++) Variable<String>(tenantId)],
        readsFrom: {db.photos, db.plantPhotos, db.locationPhotos, db.careEvents},
      ).get();

  /// The photo rows [export] includes — the ZIP exporter bundles exactly
  /// these bytes, so the two formats agree on scope.
  Future<List<PhotoRow>> photosInScope() async {
    final rows = await _photoQueryRows();
    return [for (final r in rows) db.photos.map(r.data)];
  }

  /// Insert-or-replace semantics keyed on the primary key. Because each
  /// synced entity already carries `id`/`updated_hlc`/`device_id`, the
  /// restore re-seats them as-is — except `tenant_id`, which is forced to
  /// [tenantId] (the file's value is informational, see the class doc).
  /// Uses `INSERT OR REPLACE` so a second import of the same blob is
  /// idempotent.
  Future<int> _restore(
    TableInfo<Table, dynamic> table,
    Object? data,
    OpLogWriter opLog,
    String entity,
  ) async {
    if (data is! List) return 0;
    final cols = table.$columns;
    final tenantScoped = cols.any((c) => c.name == 'tenant_id');
    var count = 0;
    for (final raw in data) {
      if (raw is! Map<String, dynamic>) continue;
      final item = tenantScoped ? <String, dynamic>{...raw, 'tenant_id': tenantId} : raw;
      final columnsList = <String>[];
      final placeholders = <String>[];
      final values = <Object?>[];
      for (final c in cols) {
        if (!item.containsKey(c.name)) continue;
        columnsList.add(c.name);
        placeholders.add('?');
        values.add(item[c.name]);
      }
      if (columnsList.isEmpty) continue;
      await db.customInsert(
        'INSERT OR REPLACE INTO ${table.actualTableName}(${columnsList.join(',')}) VALUES (${placeholders.join(',')})',
        variables: [for (final v in values) _variable(v)],
        updates: {table},
      );
      // Emit a whole-row op so peers converge. We reuse the entity's
      // existing HLC rather than stamping a new one — this keeps ordering
      // deterministic on re-import.
      final id = item['id'] ?? item['sha256'];
      if (id is String) {
        await opLog.recordFieldUpdate(
          entity: entity,
          entityId: id,
          field: kWholeRowField,
          value: item,
        );
      }
      count++;
    }
    return count;
  }

  /// Drift's `Variable<T>` doesn't accept nullable T, so we dispatch on the
  /// runtime type of each serialized column.
  Variable _variable(Object? v) {
    if (v == null) return const Variable<String>(null);
    if (v is int) return Variable<int>(v);
    if (v is double) return Variable<double>(v);
    if (v is bool) return Variable<bool>(v);
    if (v is String) return Variable<String>(v);
    // Fall back to JSON-encoded string for any other map/list.
    return Variable<String>(json.encode(v));
  }

  /// Bytes of an exported JSON document — always UTF-8.
  static Uint8List encodeBlob(String blob) => Uint8List.fromList(utf8.encode(blob));

  /// Inverse of [encodeBlob]. Backups written before 2026-09 went through
  /// `String.codeUnits`, i.e. Latin-1 (and silently truncated anything
  /// beyond it); those aren't valid UTF-8, so fall back to Latin-1 for them.
  static String decodeBlob(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  String _hmac(String canonical, String secret) {
    final hmac = Hmac(sha256, utf8.encode(secret));
    return base64Encode(hmac.convert(utf8.encode(canonical)).bytes);
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

class BackupImportResult {
  const BackupImportResult({required this.rowsImported});
  final Map<String, int> rowsImported;
  int get total => rowsImported.values.fold(0, (a, b) => a + b);
}

class BackupSignatureError implements Exception {
  const BackupSignatureError(this.message);
  final String message;
  @override
  String toString() => 'BackupSignatureError: $message';
}

class BackupFormatError implements Exception {
  const BackupFormatError(this.message);
  final String message;
  @override
  String toString() => 'BackupFormatError: $message';
}

// The import emits op-log entries; keep the import signature imported.
// ignore: unused_element
void _forceHlcImport() => Hlc(0, 0, '').encode();
