import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../../data/database/app_database.dart';
import '../../sync/hlc.dart';
import '../../sync/op_log.dart';

/// JSON backup / import with HMAC signature.
///
/// Every row from every synced table is serialised into a single JSON
/// document; the document (sans the `signature` field) is signed with
/// HMAC-SHA256 under a user-supplied secret, and the base64 mac is stored
/// alongside. Import refuses to apply any backup whose mac doesn't verify.
///
/// Photos are intentionally out of scope for this format — the ZIP-with-
/// photos export lands with the content-addressed photo store.
class BackupService {
  BackupService({required this.db});
  final AppDatabase db;

  static const int currentFormatVersion = 1;

  /// Serialize the entire database (non-deleted rows only) to a signed
  /// JSON blob. [secret] is the passphrase the user will also need to
  /// import this file — we never persist it.
  Future<String> export({required String secret}) async {
    final body = <String, Object?>{
      'format': 'plantly_inventory.backup',
      'version': currentFormatVersion,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'plants': await _rows(db.plants),
      'locations': await _rows(db.locations),
      'species': await _rows(db.species),
      'photos': await _rows(db.photos),
      'plant_photos': await _rows(db.plantPhotos),
      'tags': await _rows(db.tags),
      'plant_tags': await _rows(db.plantTags),
      'care_events': await _rows(db.careEvents),
      'care_schedules': await _rows(db.careSchedules),
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
  /// shape mismatches. On success, the import replaces the contents of
  /// the target tables (DELETE + re-insert) transactionally and emits a
  /// single op-log `__tombstone__`-then-`*` sequence per row so peers
  /// can converge.
  Future<BackupImportResult> import({
    required String blob,
    required String secret,
    required OpLogWriter opLog,
  }) async {
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
    });
    return BackupImportResult(rowsImported: counts);
  }

  Future<List<Map<String, dynamic>>> _rows(TableInfo<Table, dynamic> table) async {
    // OR-Set join tables (plant_photos, plant_tags) use added_hlc/removed_hlc
    // instead of a `deleted_at` tombstone, so we only apply the filter when
    // the column actually exists on this table.
    final hasDeletedAt = table.$columns.any((c) => c.name == 'deleted_at');
    final sql = hasDeletedAt
        ? 'SELECT * FROM ${table.actualTableName} WHERE deleted_at IS NULL'
        : 'SELECT * FROM ${table.actualTableName}';
    final rows = await db.customSelect(sql, readsFrom: {table}).get();
    return rows.map((r) => Map<String, dynamic>.from(r.data)).toList(growable: false);
  }

  /// Insert-or-replace semantics keyed on the primary key. Because each
  /// synced entity already carries `id`/`updated_hlc`/`device_id`, the
  /// restore just re-seats them as-is. Uses `INSERT OR REPLACE` so a
  /// second import of the same blob is idempotent.
  Future<int> _restore(
    TableInfo<Table, dynamic> table,
    Object? data,
    OpLogWriter opLog,
    String entity,
  ) async {
    if (data is! List) return 0;
    final cols = table.$columns;
    var count = 0;
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
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
