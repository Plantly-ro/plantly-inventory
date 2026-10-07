import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/database/app_database.dart';

/// Wire JSON ↔ SQL-shaped rows for every synced entity
/// (CLOUD-SYNC-CONTRACT §2.3: snake_case column names, ISO-8601 UTC
/// timestamps, hlc strings, booleans as JSON booleans).
///
/// One codec per entity, driven by the Drift `TableInfo` so the column list
/// can never drift from the schema. Both directions use the same codec: the
/// op-log writer canonicalises outgoing `*` ops through [canonicalRow], the
/// applier decodes incoming ops through [decodeRow] / [decodeField].
///
/// "SQL-shaped" means `Map<String, Object?>` keyed by SQL column name with
/// Dart values as Drift stores them (`int` millis for timestamps, `bool`
/// for booleans, `String` for JSON-text columns) — exactly what
/// `QueryRow.data` yields modulo sqlite's `0/1` booleans, which
/// [encodeRow] normalises.
class EntityCodec<D> {
  EntityCodec({
    required this.entity,
    required this.table,
    this.timestampColumns = const {},
    Set<String> excludedColumns = const {},
  }) : excludedColumns = {'tenant_id', ...excludedColumns};

  /// Contract entity string (`plants`, `plant_photos`, …).
  final String entity;
  final TableInfo<Table, D> table;

  /// Integer columns holding unix millis — rendered as ISO-8601 UTC strings
  /// on the wire.
  final Set<String> timestampColumns;

  /// Columns that never travel: `tenant_id` (implied by the collection) plus
  /// device-local state such as `photos.local_path` / `photos.remote_state`.
  final Set<String> excludedColumns;

  /// OR-Set join tables carry `added_hlc`/`removed_hlc` instead of
  /// `updated_hlc`/`deleted_at`.
  bool get isOrSet => table.columnsByName.containsKey('added_hlc');

  /// Primary-key column (`sha256` for photos, `id` elsewhere).
  String get idColumn => table.columnsByName.containsKey('id') ? 'id' : 'sha256';

  /// The row-level HLC column used as the LWW fallback when no op is known.
  String get hlcColumn => isOrSet ? 'added_hlc' : 'updated_hlc';

  /// Columns present on the wire, in schema order.
  List<GeneratedColumn> get wireColumns => [
        for (final c in table.$columns)
          if (!excludedColumns.contains(c.name)) c
      ];

  Iterable<String> get wireColumnNames => wireColumns.map((c) => c.name);

  bool hasColumn(String name) => table.columnsByName.containsKey(name);

  bool isWireColumn(String name) =>
      hasColumn(name) && !excludedColumns.contains(name);

  // --- SQL → wire ---------------------------------------------------------

  /// Full-row wire JSON from a SQL-shaped row (e.g. `QueryRow.data`).
  Map<String, dynamic> encodeRow(Map<String, Object?> sqlRow) {
    return {
      for (final c in wireColumns) c.name: encodeField(c.name, sqlRow[c.name]),
    };
  }

  Object? encodeField(String column, Object? sqlValue) {
    if (sqlValue == null) return null;
    final col = table.columnsByName[column];
    if (col == null) return sqlValue;
    if (timestampColumns.contains(column)) {
      final ms = _toInt(sqlValue);
      return ms == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String();
    }
    switch (col.type) {
      case DriftSqlType.bool:
        return _toBool(sqlValue);
      case DriftSqlType.int:
      case DriftSqlType.bigInt:
        return _toInt(sqlValue);
      case DriftSqlType.double:
        return _toDouble(sqlValue);
      default:
        return sqlValue is String ? sqlValue : '$sqlValue';
    }
  }

  /// Canonical `*` payload for an outgoing create: a possibly partial,
  /// loosely-typed map (whatever the repository handed the op-log) becomes a
  /// full row with every wire column present, typed per the contract, the
  /// row HLC / device stamped in.
  Map<String, dynamic> canonicalRow(
    Map<String, dynamic> raw, {
    required String hlc,
    required String deviceId,
  }) {
    final sql = decodeRow(raw, fillDefaults: true);
    sql[hlcColumn] = hlc;
    sql['device_id'] = deviceId;
    return encodeRow(sql);
  }

  // --- wire → SQL ---------------------------------------------------------

  /// SQL-shaped values for the known wire columns of [wire]; unknown keys are
  /// ignored. With [fillDefaults], absent non-nullable columns receive the
  /// schema default (or a type-appropriate zero) so an insert can't fail
  /// NOT NULL on a partial payload from an older client. With [dropInvalid],
  /// a column whose value [acceptsValue] refuses is treated as absent.
  Map<String, Object?> decodeRow(
    Map<String, dynamic> wire, {
    bool fillDefaults = false,
    bool dropInvalid = false,
  }) {
    final out = <String, Object?>{};
    for (final c in wireColumns) {
      if (wire.containsKey(c.name) && (!dropInvalid || acceptsValue(c.name, wire[c.name]))) {
        out[c.name] = decodeField(c.name, wire[c.name]);
      } else if (fillDefaults) {
        final d = _defaultFor(c);
        if (d != null || c.$nullable) out[c.name] = d;
      }
    }
    return out;
  }

  Object? decodeField(String column, Object? wireValue) {
    if (wireValue == null) return null;
    final col = table.columnsByName[column];
    if (col == null) return wireValue;
    if (timestampColumns.contains(column)) return _toMillis(wireValue);
    switch (col.type) {
      case DriftSqlType.bool:
        return _toBool(wireValue);
      case DriftSqlType.int:
      case DriftSqlType.bigInt:
        return _toInt(wireValue);
      case DriftSqlType.double:
        return _toDouble(wireValue);
      case DriftSqlType.string:
        if (wireValue is String) return wireValue;
        if (wireValue is Map || wireValue is List) return json.encode(wireValue);
        return '$wireValue';
      default:
        return wireValue;
    }
  }

  /// Whether [wireValue] can be stored in [column]: it decodes to the
  /// column's type (a non-null value that decodes to null — `"abc"` for an
  /// int, an unparseable timestamp — does not) and is not null for a NOT
  /// NULL column. Unknown columns are refused.
  bool acceptsValue(String column, Object? wireValue) {
    final col = table.columnsByName[column];
    if (col == null) return false;
    final decoded = decodeField(column, wireValue);
    if (decoded == null) return wireValue == null && col.$nullable;
    return true;
  }

  /// Drift insertable for a SQL-shaped map, typed per column so the
  /// statement binds correctly.
  Insertable<D> insertable(Map<String, Object?> sql) {
    final data = <String, Expression>{};
    for (final e in sql.entries) {
      final col = table.columnsByName[e.key];
      if (col == null) continue;
      data[e.key] = _variable(col, e.value);
    }
    return RawValuesInsertable<D>(data);
  }

  Expression _variable(GeneratedColumn col, Object? v) {
    switch (col.type) {
      case DriftSqlType.bool:
        return Variable<bool>(v == null ? null : _toBool(v));
      case DriftSqlType.int:
      case DriftSqlType.bigInt:
        return Variable<int>(v == null ? null : _toInt(v));
      case DriftSqlType.double:
        return Variable<double>(v == null ? null : _toDouble(v));
      default:
        return Variable<String>(v == null ? null : (v is String ? v : '$v'));
    }
  }

  Object? _defaultFor(GeneratedColumn c) {
    final d = c.defaultValue;
    if (d is Constant) return d.value;
    if (c.$nullable) return null;
    switch (c.type) {
      case DriftSqlType.bool:
        return false;
      case DriftSqlType.int:
      case DriftSqlType.bigInt:
        return 0;
      case DriftSqlType.double:
        return 0.0;
      default:
        return '';
    }
  }

  static int? _toInt(Object? v) => switch (v) {
        null => null,
        final int i => i,
        final num n => n.toInt(),
        final bool b => b ? 1 : 0,
        final String s => int.tryParse(s) ?? double.tryParse(s)?.toInt(),
        _ => null,
      };

  static double? _toDouble(Object? v) => switch (v) {
        null => null,
        final num n => n.toDouble(),
        final String s => double.tryParse(s),
        _ => null,
      };

  static bool? _toBool(Object? v) => switch (v) {
        null => null,
        final bool b => b,
        final num n => n != 0,
        final String s => s == 'true' || s == '1',
        _ => null,
      };

  /// ISO-8601 (any offset) or a bare millis number → unix millis.
  static int? _toMillis(Object? v) => switch (v) {
        null => null,
        final int i => i,
        final num n => n.toInt(),
        final String s => DateTime.tryParse(s)?.toUtc().millisecondsSinceEpoch ?? int.tryParse(s),
        _ => null,
      };
}

/// Registry of the eleven contract entities for one database instance.
class EntityCodecs {
  EntityCodecs(AppDatabase db)
      : _byEntity = {
          for (final c in _build(db)) c.entity: c,
        };

  final Map<String, EntityCodec> _byEntity;

  /// Contract §2.3 entity strings, in dependency order (parents first) so a
  /// full-table initial upload lands referentially sane on the other side.
  static const List<String> entities = [
    'species',
    'locations',
    'plants',
    'photos',
    'plant_photos',
    'location_photos',
    'tags',
    'plant_tags',
    'care_events',
    'care_schedules',
    'inventory_transactions',
  ];

  EntityCodec? forEntity(String entity) => _byEntity[entity];

  Iterable<EntityCodec> get all => entities.map((e) => _byEntity[e]!);

  // Explicit row types: a `List<EntityCodec>` context would otherwise infer
  // `D = dynamic` and Drift's integrity check rejects the insertable.
  static List<EntityCodec> _build(AppDatabase db) => [
        EntityCodec<SpeciesRow>(entity: 'species', table: db.species, timestampColumns: {'deleted_at'}),
        EntityCodec<LocationRow>(entity: 'locations', table: db.locations, timestampColumns: {'deleted_at'}),
        EntityCodec<PlantRow>(
          entity: 'plants',
          table: db.plants,
          timestampColumns: {'acquired_at', 'deleted_at'},
        ),
        EntityCodec<PhotoRow>(
          entity: 'photos',
          table: db.photos,
          timestampColumns: {'taken_at', 'deleted_at'},
          excludedColumns: {'local_path', 'remote_state'},
        ),
        EntityCodec<PlantPhotoRow>(entity: 'plant_photos', table: db.plantPhotos, timestampColumns: {'captured_at'}),
        EntityCodec<LocationPhotoRow>(
          entity: 'location_photos',
          table: db.locationPhotos,
          timestampColumns: {'captured_at'},
        ),
        EntityCodec<TagRow>(entity: 'tags', table: db.tags, timestampColumns: {'deleted_at'}),
        EntityCodec<PlantTagRow>(entity: 'plant_tags', table: db.plantTags),
        EntityCodec<CareEventRow>(
          entity: 'care_events',
          table: db.careEvents,
          timestampColumns: {'done_at', 'deleted_at'},
          // Device-local attribution (§3): the server derives `user_id`
          // from the bearer token, the applier copies it off pulled ops.
          excludedColumns: {'actor_user_id'},
        ),
        EntityCodec<CareScheduleRow>(
          entity: 'care_schedules',
          table: db.careSchedules,
          timestampColumns: {'last_done_at', 'next_due_at', 'deleted_at'},
        ),
        EntityCodec<InventoryTransactionRow>(
          entity: 'inventory_transactions',
          table: db.inventoryTransactions,
          timestampColumns: {'at', 'deleted_at'},
        ),
      ];
}
