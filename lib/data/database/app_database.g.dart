// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SpeciesTable extends Species with TableInfo<$SpeciesTable, SpeciesRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpeciesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scientificNameMeta = const VerificationMeta(
    'scientificName',
  );
  @override
  late final GeneratedColumn<String> scientificName = GeneratedColumn<String>(
    'scientific_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commonNamesJsonMeta = const VerificationMeta(
    'commonNamesJson',
  );
  @override
  late final GeneratedColumn<String> commonNamesJson = GeneratedColumn<String>(
    'common_names_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _defaultCareJsonMeta = const VerificationMeta(
    'defaultCareJson',
  );
  @override
  late final GeneratedColumn<String> defaultCareJson = GeneratedColumn<String>(
    'default_care_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isSeedMeta = const VerificationMeta('isSeed');
  @override
  late final GeneratedColumn<bool> isSeed = GeneratedColumn<bool>(
    'is_seed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_seed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedHlcMeta = const VerificationMeta(
    'updatedHlc',
  );
  @override
  late final GeneratedColumn<String> updatedHlc = GeneratedColumn<String>(
    'updated_hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    scientificName,
    commonNamesJson,
    defaultCareJson,
    isSeed,
    updatedHlc,
    deletedAt,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'species';
  @override
  VerificationContext validateIntegrity(
    Insertable<SpeciesRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('scientific_name')) {
      context.handle(
        _scientificNameMeta,
        scientificName.isAcceptableOrUnknown(
          data['scientific_name']!,
          _scientificNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scientificNameMeta);
    }
    if (data.containsKey('common_names_json')) {
      context.handle(
        _commonNamesJsonMeta,
        commonNamesJson.isAcceptableOrUnknown(
          data['common_names_json']!,
          _commonNamesJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_commonNamesJsonMeta);
    }
    if (data.containsKey('default_care_json')) {
      context.handle(
        _defaultCareJsonMeta,
        defaultCareJson.isAcceptableOrUnknown(
          data['default_care_json']!,
          _defaultCareJsonMeta,
        ),
      );
    }
    if (data.containsKey('is_seed')) {
      context.handle(
        _isSeedMeta,
        isSeed.isAcceptableOrUnknown(data['is_seed']!, _isSeedMeta),
      );
    }
    if (data.containsKey('updated_hlc')) {
      context.handle(
        _updatedHlcMeta,
        updatedHlc.isAcceptableOrUnknown(data['updated_hlc']!, _updatedHlcMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedHlcMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SpeciesRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SpeciesRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      scientificName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scientific_name'],
      )!,
      commonNamesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}common_names_json'],
      )!,
      defaultCareJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_care_json'],
      ),
      isSeed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_seed'],
      )!,
      updatedHlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_hlc'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  $SpeciesTable createAlias(String alias) {
    return $SpeciesTable(attachedDatabase, alias);
  }
}

class SpeciesRow extends DataClass implements Insertable<SpeciesRow> {
  final String id;
  final String tenantId;
  final String scientificName;
  final String commonNamesJson;
  final String? defaultCareJson;
  final bool isSeed;
  final String updatedHlc;
  final int? deletedAt;
  final String deviceId;
  const SpeciesRow({
    required this.id,
    required this.tenantId,
    required this.scientificName,
    required this.commonNamesJson,
    this.defaultCareJson,
    required this.isSeed,
    required this.updatedHlc,
    this.deletedAt,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['scientific_name'] = Variable<String>(scientificName);
    map['common_names_json'] = Variable<String>(commonNamesJson);
    if (!nullToAbsent || defaultCareJson != null) {
      map['default_care_json'] = Variable<String>(defaultCareJson);
    }
    map['is_seed'] = Variable<bool>(isSeed);
    map['updated_hlc'] = Variable<String>(updatedHlc);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  SpeciesCompanion toCompanion(bool nullToAbsent) {
    return SpeciesCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      scientificName: Value(scientificName),
      commonNamesJson: Value(commonNamesJson),
      defaultCareJson: defaultCareJson == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultCareJson),
      isSeed: Value(isSeed),
      updatedHlc: Value(updatedHlc),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
    );
  }

  factory SpeciesRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SpeciesRow(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      scientificName: serializer.fromJson<String>(json['scientificName']),
      commonNamesJson: serializer.fromJson<String>(json['commonNamesJson']),
      defaultCareJson: serializer.fromJson<String?>(json['defaultCareJson']),
      isSeed: serializer.fromJson<bool>(json['isSeed']),
      updatedHlc: serializer.fromJson<String>(json['updatedHlc']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'scientificName': serializer.toJson<String>(scientificName),
      'commonNamesJson': serializer.toJson<String>(commonNamesJson),
      'defaultCareJson': serializer.toJson<String?>(defaultCareJson),
      'isSeed': serializer.toJson<bool>(isSeed),
      'updatedHlc': serializer.toJson<String>(updatedHlc),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
    };
  }

  SpeciesRow copyWith({
    String? id,
    String? tenantId,
    String? scientificName,
    String? commonNamesJson,
    Value<String?> defaultCareJson = const Value.absent(),
    bool? isSeed,
    String? updatedHlc,
    Value<int?> deletedAt = const Value.absent(),
    String? deviceId,
  }) => SpeciesRow(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    scientificName: scientificName ?? this.scientificName,
    commonNamesJson: commonNamesJson ?? this.commonNamesJson,
    defaultCareJson: defaultCareJson.present
        ? defaultCareJson.value
        : this.defaultCareJson,
    isSeed: isSeed ?? this.isSeed,
    updatedHlc: updatedHlc ?? this.updatedHlc,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
  );
  SpeciesRow copyWithCompanion(SpeciesCompanion data) {
    return SpeciesRow(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      scientificName: data.scientificName.present
          ? data.scientificName.value
          : this.scientificName,
      commonNamesJson: data.commonNamesJson.present
          ? data.commonNamesJson.value
          : this.commonNamesJson,
      defaultCareJson: data.defaultCareJson.present
          ? data.defaultCareJson.value
          : this.defaultCareJson,
      isSeed: data.isSeed.present ? data.isSeed.value : this.isSeed,
      updatedHlc: data.updatedHlc.present
          ? data.updatedHlc.value
          : this.updatedHlc,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SpeciesRow(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('scientificName: $scientificName, ')
          ..write('commonNamesJson: $commonNamesJson, ')
          ..write('defaultCareJson: $defaultCareJson, ')
          ..write('isSeed: $isSeed, ')
          ..write('updatedHlc: $updatedHlc, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    scientificName,
    commonNamesJson,
    defaultCareJson,
    isSeed,
    updatedHlc,
    deletedAt,
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpeciesRow &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.scientificName == this.scientificName &&
          other.commonNamesJson == this.commonNamesJson &&
          other.defaultCareJson == this.defaultCareJson &&
          other.isSeed == this.isSeed &&
          other.updatedHlc == this.updatedHlc &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId);
}

class SpeciesCompanion extends UpdateCompanion<SpeciesRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> scientificName;
  final Value<String> commonNamesJson;
  final Value<String?> defaultCareJson;
  final Value<bool> isSeed;
  final Value<String> updatedHlc;
  final Value<int?> deletedAt;
  final Value<String> deviceId;
  final Value<int> rowid;
  const SpeciesCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.scientificName = const Value.absent(),
    this.commonNamesJson = const Value.absent(),
    this.defaultCareJson = const Value.absent(),
    this.isSeed = const Value.absent(),
    this.updatedHlc = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SpeciesCompanion.insert({
    required String id,
    required String tenantId,
    required String scientificName,
    required String commonNamesJson,
    this.defaultCareJson = const Value.absent(),
    this.isSeed = const Value.absent(),
    required String updatedHlc,
    this.deletedAt = const Value.absent(),
    required String deviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       scientificName = Value(scientificName),
       commonNamesJson = Value(commonNamesJson),
       updatedHlc = Value(updatedHlc),
       deviceId = Value(deviceId);
  static Insertable<SpeciesRow> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? scientificName,
    Expression<String>? commonNamesJson,
    Expression<String>? defaultCareJson,
    Expression<bool>? isSeed,
    Expression<String>? updatedHlc,
    Expression<int>? deletedAt,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (scientificName != null) 'scientific_name': scientificName,
      if (commonNamesJson != null) 'common_names_json': commonNamesJson,
      if (defaultCareJson != null) 'default_care_json': defaultCareJson,
      if (isSeed != null) 'is_seed': isSeed,
      if (updatedHlc != null) 'updated_hlc': updatedHlc,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SpeciesCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? scientificName,
    Value<String>? commonNamesJson,
    Value<String?>? defaultCareJson,
    Value<bool>? isSeed,
    Value<String>? updatedHlc,
    Value<int?>? deletedAt,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return SpeciesCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      scientificName: scientificName ?? this.scientificName,
      commonNamesJson: commonNamesJson ?? this.commonNamesJson,
      defaultCareJson: defaultCareJson ?? this.defaultCareJson,
      isSeed: isSeed ?? this.isSeed,
      updatedHlc: updatedHlc ?? this.updatedHlc,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (scientificName.present) {
      map['scientific_name'] = Variable<String>(scientificName.value);
    }
    if (commonNamesJson.present) {
      map['common_names_json'] = Variable<String>(commonNamesJson.value);
    }
    if (defaultCareJson.present) {
      map['default_care_json'] = Variable<String>(defaultCareJson.value);
    }
    if (isSeed.present) {
      map['is_seed'] = Variable<bool>(isSeed.value);
    }
    if (updatedHlc.present) {
      map['updated_hlc'] = Variable<String>(updatedHlc.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpeciesCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('scientificName: $scientificName, ')
          ..write('commonNamesJson: $commonNamesJson, ')
          ..write('defaultCareJson: $defaultCareJson, ')
          ..write('isSeed: $isSeed, ')
          ..write('updatedHlc: $updatedHlc, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocationsTable extends Locations
    with TableInfo<$LocationsTable, LocationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lightMeta = const VerificationMeta('light');
  @override
  late final GeneratedColumn<String> light = GeneratedColumn<String>(
    'light',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _humidityMinMeta = const VerificationMeta(
    'humidityMin',
  );
  @override
  late final GeneratedColumn<int> humidityMin = GeneratedColumn<int>(
    'humidity_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _humidityMaxMeta = const VerificationMeta(
    'humidityMax',
  );
  @override
  late final GeneratedColumn<int> humidityMax = GeneratedColumn<int>(
    'humidity_max',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tempMinCMeta = const VerificationMeta(
    'tempMinC',
  );
  @override
  late final GeneratedColumn<double> tempMinC = GeneratedColumn<double>(
    'temp_min_c',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tempMaxCMeta = const VerificationMeta(
    'tempMaxC',
  );
  @override
  late final GeneratedColumn<double> tempMaxC = GeneratedColumn<double>(
    'temp_max_c',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isOutdoorMeta = const VerificationMeta(
    'isOutdoor',
  );
  @override
  late final GeneratedColumn<bool> isOutdoor = GeneratedColumn<bool>(
    'is_outdoor',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_outdoor" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lonMeta = const VerificationMeta('lon');
  @override
  late final GeneratedColumn<double> lon = GeneratedColumn<double>(
    'lon',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mapPhotoShaMeta = const VerificationMeta(
    'mapPhotoSha',
  );
  @override
  late final GeneratedColumn<String> mapPhotoSha = GeneratedColumn<String>(
    'map_photo_sha',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notificationsMutedMeta =
      const VerificationMeta('notificationsMuted');
  @override
  late final GeneratedColumn<bool> notificationsMuted = GeneratedColumn<bool>(
    'notifications_muted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("notifications_muted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedHlcMeta = const VerificationMeta(
    'updatedHlc',
  );
  @override
  late final GeneratedColumn<String> updatedHlc = GeneratedColumn<String>(
    'updated_hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    parentId,
    name,
    kind,
    light,
    humidityMin,
    humidityMax,
    tempMinC,
    tempMaxC,
    isOutdoor,
    lat,
    lon,
    notes,
    mapPhotoSha,
    notificationsMuted,
    updatedHlc,
    deletedAt,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'locations';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('light')) {
      context.handle(
        _lightMeta,
        light.isAcceptableOrUnknown(data['light']!, _lightMeta),
      );
    }
    if (data.containsKey('humidity_min')) {
      context.handle(
        _humidityMinMeta,
        humidityMin.isAcceptableOrUnknown(
          data['humidity_min']!,
          _humidityMinMeta,
        ),
      );
    }
    if (data.containsKey('humidity_max')) {
      context.handle(
        _humidityMaxMeta,
        humidityMax.isAcceptableOrUnknown(
          data['humidity_max']!,
          _humidityMaxMeta,
        ),
      );
    }
    if (data.containsKey('temp_min_c')) {
      context.handle(
        _tempMinCMeta,
        tempMinC.isAcceptableOrUnknown(data['temp_min_c']!, _tempMinCMeta),
      );
    }
    if (data.containsKey('temp_max_c')) {
      context.handle(
        _tempMaxCMeta,
        tempMaxC.isAcceptableOrUnknown(data['temp_max_c']!, _tempMaxCMeta),
      );
    }
    if (data.containsKey('is_outdoor')) {
      context.handle(
        _isOutdoorMeta,
        isOutdoor.isAcceptableOrUnknown(data['is_outdoor']!, _isOutdoorMeta),
      );
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    }
    if (data.containsKey('lon')) {
      context.handle(
        _lonMeta,
        lon.isAcceptableOrUnknown(data['lon']!, _lonMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('map_photo_sha')) {
      context.handle(
        _mapPhotoShaMeta,
        mapPhotoSha.isAcceptableOrUnknown(
          data['map_photo_sha']!,
          _mapPhotoShaMeta,
        ),
      );
    }
    if (data.containsKey('notifications_muted')) {
      context.handle(
        _notificationsMutedMeta,
        notificationsMuted.isAcceptableOrUnknown(
          data['notifications_muted']!,
          _notificationsMutedMeta,
        ),
      );
    }
    if (data.containsKey('updated_hlc')) {
      context.handle(
        _updatedHlcMeta,
        updatedHlc.isAcceptableOrUnknown(data['updated_hlc']!, _updatedHlcMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedHlcMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      light: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}light'],
      ),
      humidityMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}humidity_min'],
      ),
      humidityMax: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}humidity_max'],
      ),
      tempMinC: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}temp_min_c'],
      ),
      tempMaxC: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}temp_max_c'],
      ),
      isOutdoor: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_outdoor'],
      )!,
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      ),
      lon: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lon'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      mapPhotoSha: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}map_photo_sha'],
      ),
      notificationsMuted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notifications_muted'],
      )!,
      updatedHlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_hlc'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  $LocationsTable createAlias(String alias) {
    return $LocationsTable(attachedDatabase, alias);
  }
}

class LocationRow extends DataClass implements Insertable<LocationRow> {
  final String id;
  final String tenantId;
  final String? parentId;
  final String name;
  final String kind;
  final String? light;
  final int? humidityMin;
  final int? humidityMax;
  final double? tempMinC;
  final double? tempMaxC;
  final bool isOutdoor;
  final double? lat;
  final double? lon;
  final String? notes;

  /// SHA-256 of a user-supplied image used as a "room layout" map for
  /// positioning plant pins. Lives in the same content-addressed
  /// `photos` store as plant photos — share the infrastructure.
  final String? mapPhotoSha;

  /// If true, every schedule whose plant sits in this location stops
  /// firing OS notifications. Does not affect the in-app reminder UI.
  final bool notificationsMuted;
  final String updatedHlc;
  final int? deletedAt;
  final String deviceId;
  const LocationRow({
    required this.id,
    required this.tenantId,
    this.parentId,
    required this.name,
    required this.kind,
    this.light,
    this.humidityMin,
    this.humidityMax,
    this.tempMinC,
    this.tempMaxC,
    required this.isOutdoor,
    this.lat,
    this.lon,
    this.notes,
    this.mapPhotoSha,
    required this.notificationsMuted,
    required this.updatedHlc,
    this.deletedAt,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || light != null) {
      map['light'] = Variable<String>(light);
    }
    if (!nullToAbsent || humidityMin != null) {
      map['humidity_min'] = Variable<int>(humidityMin);
    }
    if (!nullToAbsent || humidityMax != null) {
      map['humidity_max'] = Variable<int>(humidityMax);
    }
    if (!nullToAbsent || tempMinC != null) {
      map['temp_min_c'] = Variable<double>(tempMinC);
    }
    if (!nullToAbsent || tempMaxC != null) {
      map['temp_max_c'] = Variable<double>(tempMaxC);
    }
    map['is_outdoor'] = Variable<bool>(isOutdoor);
    if (!nullToAbsent || lat != null) {
      map['lat'] = Variable<double>(lat);
    }
    if (!nullToAbsent || lon != null) {
      map['lon'] = Variable<double>(lon);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || mapPhotoSha != null) {
      map['map_photo_sha'] = Variable<String>(mapPhotoSha);
    }
    map['notifications_muted'] = Variable<bool>(notificationsMuted);
    map['updated_hlc'] = Variable<String>(updatedHlc);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  LocationsCompanion toCompanion(bool nullToAbsent) {
    return LocationsCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      name: Value(name),
      kind: Value(kind),
      light: light == null && nullToAbsent
          ? const Value.absent()
          : Value(light),
      humidityMin: humidityMin == null && nullToAbsent
          ? const Value.absent()
          : Value(humidityMin),
      humidityMax: humidityMax == null && nullToAbsent
          ? const Value.absent()
          : Value(humidityMax),
      tempMinC: tempMinC == null && nullToAbsent
          ? const Value.absent()
          : Value(tempMinC),
      tempMaxC: tempMaxC == null && nullToAbsent
          ? const Value.absent()
          : Value(tempMaxC),
      isOutdoor: Value(isOutdoor),
      lat: lat == null && nullToAbsent ? const Value.absent() : Value(lat),
      lon: lon == null && nullToAbsent ? const Value.absent() : Value(lon),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      mapPhotoSha: mapPhotoSha == null && nullToAbsent
          ? const Value.absent()
          : Value(mapPhotoSha),
      notificationsMuted: Value(notificationsMuted),
      updatedHlc: Value(updatedHlc),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
    );
  }

  factory LocationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocationRow(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String>(json['kind']),
      light: serializer.fromJson<String?>(json['light']),
      humidityMin: serializer.fromJson<int?>(json['humidityMin']),
      humidityMax: serializer.fromJson<int?>(json['humidityMax']),
      tempMinC: serializer.fromJson<double?>(json['tempMinC']),
      tempMaxC: serializer.fromJson<double?>(json['tempMaxC']),
      isOutdoor: serializer.fromJson<bool>(json['isOutdoor']),
      lat: serializer.fromJson<double?>(json['lat']),
      lon: serializer.fromJson<double?>(json['lon']),
      notes: serializer.fromJson<String?>(json['notes']),
      mapPhotoSha: serializer.fromJson<String?>(json['mapPhotoSha']),
      notificationsMuted: serializer.fromJson<bool>(json['notificationsMuted']),
      updatedHlc: serializer.fromJson<String>(json['updatedHlc']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'parentId': serializer.toJson<String?>(parentId),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(kind),
      'light': serializer.toJson<String?>(light),
      'humidityMin': serializer.toJson<int?>(humidityMin),
      'humidityMax': serializer.toJson<int?>(humidityMax),
      'tempMinC': serializer.toJson<double?>(tempMinC),
      'tempMaxC': serializer.toJson<double?>(tempMaxC),
      'isOutdoor': serializer.toJson<bool>(isOutdoor),
      'lat': serializer.toJson<double?>(lat),
      'lon': serializer.toJson<double?>(lon),
      'notes': serializer.toJson<String?>(notes),
      'mapPhotoSha': serializer.toJson<String?>(mapPhotoSha),
      'notificationsMuted': serializer.toJson<bool>(notificationsMuted),
      'updatedHlc': serializer.toJson<String>(updatedHlc),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
    };
  }

  LocationRow copyWith({
    String? id,
    String? tenantId,
    Value<String?> parentId = const Value.absent(),
    String? name,
    String? kind,
    Value<String?> light = const Value.absent(),
    Value<int?> humidityMin = const Value.absent(),
    Value<int?> humidityMax = const Value.absent(),
    Value<double?> tempMinC = const Value.absent(),
    Value<double?> tempMaxC = const Value.absent(),
    bool? isOutdoor,
    Value<double?> lat = const Value.absent(),
    Value<double?> lon = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<String?> mapPhotoSha = const Value.absent(),
    bool? notificationsMuted,
    String? updatedHlc,
    Value<int?> deletedAt = const Value.absent(),
    String? deviceId,
  }) => LocationRow(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    parentId: parentId.present ? parentId.value : this.parentId,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    light: light.present ? light.value : this.light,
    humidityMin: humidityMin.present ? humidityMin.value : this.humidityMin,
    humidityMax: humidityMax.present ? humidityMax.value : this.humidityMax,
    tempMinC: tempMinC.present ? tempMinC.value : this.tempMinC,
    tempMaxC: tempMaxC.present ? tempMaxC.value : this.tempMaxC,
    isOutdoor: isOutdoor ?? this.isOutdoor,
    lat: lat.present ? lat.value : this.lat,
    lon: lon.present ? lon.value : this.lon,
    notes: notes.present ? notes.value : this.notes,
    mapPhotoSha: mapPhotoSha.present ? mapPhotoSha.value : this.mapPhotoSha,
    notificationsMuted: notificationsMuted ?? this.notificationsMuted,
    updatedHlc: updatedHlc ?? this.updatedHlc,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
  );
  LocationRow copyWithCompanion(LocationsCompanion data) {
    return LocationRow(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      light: data.light.present ? data.light.value : this.light,
      humidityMin: data.humidityMin.present
          ? data.humidityMin.value
          : this.humidityMin,
      humidityMax: data.humidityMax.present
          ? data.humidityMax.value
          : this.humidityMax,
      tempMinC: data.tempMinC.present ? data.tempMinC.value : this.tempMinC,
      tempMaxC: data.tempMaxC.present ? data.tempMaxC.value : this.tempMaxC,
      isOutdoor: data.isOutdoor.present ? data.isOutdoor.value : this.isOutdoor,
      lat: data.lat.present ? data.lat.value : this.lat,
      lon: data.lon.present ? data.lon.value : this.lon,
      notes: data.notes.present ? data.notes.value : this.notes,
      mapPhotoSha: data.mapPhotoSha.present
          ? data.mapPhotoSha.value
          : this.mapPhotoSha,
      notificationsMuted: data.notificationsMuted.present
          ? data.notificationsMuted.value
          : this.notificationsMuted,
      updatedHlc: data.updatedHlc.present
          ? data.updatedHlc.value
          : this.updatedHlc,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocationRow(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('light: $light, ')
          ..write('humidityMin: $humidityMin, ')
          ..write('humidityMax: $humidityMax, ')
          ..write('tempMinC: $tempMinC, ')
          ..write('tempMaxC: $tempMaxC, ')
          ..write('isOutdoor: $isOutdoor, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon, ')
          ..write('notes: $notes, ')
          ..write('mapPhotoSha: $mapPhotoSha, ')
          ..write('notificationsMuted: $notificationsMuted, ')
          ..write('updatedHlc: $updatedHlc, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    parentId,
    name,
    kind,
    light,
    humidityMin,
    humidityMax,
    tempMinC,
    tempMaxC,
    isOutdoor,
    lat,
    lon,
    notes,
    mapPhotoSha,
    notificationsMuted,
    updatedHlc,
    deletedAt,
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocationRow &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.parentId == this.parentId &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.light == this.light &&
          other.humidityMin == this.humidityMin &&
          other.humidityMax == this.humidityMax &&
          other.tempMinC == this.tempMinC &&
          other.tempMaxC == this.tempMaxC &&
          other.isOutdoor == this.isOutdoor &&
          other.lat == this.lat &&
          other.lon == this.lon &&
          other.notes == this.notes &&
          other.mapPhotoSha == this.mapPhotoSha &&
          other.notificationsMuted == this.notificationsMuted &&
          other.updatedHlc == this.updatedHlc &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId);
}

class LocationsCompanion extends UpdateCompanion<LocationRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String?> parentId;
  final Value<String> name;
  final Value<String> kind;
  final Value<String?> light;
  final Value<int?> humidityMin;
  final Value<int?> humidityMax;
  final Value<double?> tempMinC;
  final Value<double?> tempMaxC;
  final Value<bool> isOutdoor;
  final Value<double?> lat;
  final Value<double?> lon;
  final Value<String?> notes;
  final Value<String?> mapPhotoSha;
  final Value<bool> notificationsMuted;
  final Value<String> updatedHlc;
  final Value<int?> deletedAt;
  final Value<String> deviceId;
  final Value<int> rowid;
  const LocationsCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.parentId = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.light = const Value.absent(),
    this.humidityMin = const Value.absent(),
    this.humidityMax = const Value.absent(),
    this.tempMinC = const Value.absent(),
    this.tempMaxC = const Value.absent(),
    this.isOutdoor = const Value.absent(),
    this.lat = const Value.absent(),
    this.lon = const Value.absent(),
    this.notes = const Value.absent(),
    this.mapPhotoSha = const Value.absent(),
    this.notificationsMuted = const Value.absent(),
    this.updatedHlc = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocationsCompanion.insert({
    required String id,
    required String tenantId,
    this.parentId = const Value.absent(),
    required String name,
    required String kind,
    this.light = const Value.absent(),
    this.humidityMin = const Value.absent(),
    this.humidityMax = const Value.absent(),
    this.tempMinC = const Value.absent(),
    this.tempMaxC = const Value.absent(),
    this.isOutdoor = const Value.absent(),
    this.lat = const Value.absent(),
    this.lon = const Value.absent(),
    this.notes = const Value.absent(),
    this.mapPhotoSha = const Value.absent(),
    this.notificationsMuted = const Value.absent(),
    required String updatedHlc,
    this.deletedAt = const Value.absent(),
    required String deviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       name = Value(name),
       kind = Value(kind),
       updatedHlc = Value(updatedHlc),
       deviceId = Value(deviceId);
  static Insertable<LocationRow> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? parentId,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<String>? light,
    Expression<int>? humidityMin,
    Expression<int>? humidityMax,
    Expression<double>? tempMinC,
    Expression<double>? tempMaxC,
    Expression<bool>? isOutdoor,
    Expression<double>? lat,
    Expression<double>? lon,
    Expression<String>? notes,
    Expression<String>? mapPhotoSha,
    Expression<bool>? notificationsMuted,
    Expression<String>? updatedHlc,
    Expression<int>? deletedAt,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (parentId != null) 'parent_id': parentId,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (light != null) 'light': light,
      if (humidityMin != null) 'humidity_min': humidityMin,
      if (humidityMax != null) 'humidity_max': humidityMax,
      if (tempMinC != null) 'temp_min_c': tempMinC,
      if (tempMaxC != null) 'temp_max_c': tempMaxC,
      if (isOutdoor != null) 'is_outdoor': isOutdoor,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
      if (notes != null) 'notes': notes,
      if (mapPhotoSha != null) 'map_photo_sha': mapPhotoSha,
      if (notificationsMuted != null) 'notifications_muted': notificationsMuted,
      if (updatedHlc != null) 'updated_hlc': updatedHlc,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocationsCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String?>? parentId,
    Value<String>? name,
    Value<String>? kind,
    Value<String?>? light,
    Value<int?>? humidityMin,
    Value<int?>? humidityMax,
    Value<double?>? tempMinC,
    Value<double?>? tempMaxC,
    Value<bool>? isOutdoor,
    Value<double?>? lat,
    Value<double?>? lon,
    Value<String?>? notes,
    Value<String?>? mapPhotoSha,
    Value<bool>? notificationsMuted,
    Value<String>? updatedHlc,
    Value<int?>? deletedAt,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return LocationsCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      light: light ?? this.light,
      humidityMin: humidityMin ?? this.humidityMin,
      humidityMax: humidityMax ?? this.humidityMax,
      tempMinC: tempMinC ?? this.tempMinC,
      tempMaxC: tempMaxC ?? this.tempMaxC,
      isOutdoor: isOutdoor ?? this.isOutdoor,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      notes: notes ?? this.notes,
      mapPhotoSha: mapPhotoSha ?? this.mapPhotoSha,
      notificationsMuted: notificationsMuted ?? this.notificationsMuted,
      updatedHlc: updatedHlc ?? this.updatedHlc,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (light.present) {
      map['light'] = Variable<String>(light.value);
    }
    if (humidityMin.present) {
      map['humidity_min'] = Variable<int>(humidityMin.value);
    }
    if (humidityMax.present) {
      map['humidity_max'] = Variable<int>(humidityMax.value);
    }
    if (tempMinC.present) {
      map['temp_min_c'] = Variable<double>(tempMinC.value);
    }
    if (tempMaxC.present) {
      map['temp_max_c'] = Variable<double>(tempMaxC.value);
    }
    if (isOutdoor.present) {
      map['is_outdoor'] = Variable<bool>(isOutdoor.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lon.present) {
      map['lon'] = Variable<double>(lon.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (mapPhotoSha.present) {
      map['map_photo_sha'] = Variable<String>(mapPhotoSha.value);
    }
    if (notificationsMuted.present) {
      map['notifications_muted'] = Variable<bool>(notificationsMuted.value);
    }
    if (updatedHlc.present) {
      map['updated_hlc'] = Variable<String>(updatedHlc.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocationsCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('light: $light, ')
          ..write('humidityMin: $humidityMin, ')
          ..write('humidityMax: $humidityMax, ')
          ..write('tempMinC: $tempMinC, ')
          ..write('tempMaxC: $tempMaxC, ')
          ..write('isOutdoor: $isOutdoor, ')
          ..write('lat: $lat, ')
          ..write('lon: $lon, ')
          ..write('notes: $notes, ')
          ..write('mapPhotoSha: $mapPhotoSha, ')
          ..write('notificationsMuted: $notificationsMuted, ')
          ..write('updatedHlc: $updatedHlc, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlantsTable extends Plants with TableInfo<$PlantsTable, PlantRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlantsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nicknameMeta = const VerificationMeta(
    'nickname',
  );
  @override
  late final GeneratedColumn<String> nickname = GeneratedColumn<String>(
    'nickname',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _speciesIdMeta = const VerificationMeta(
    'speciesId',
  );
  @override
  late final GeneratedColumn<String> speciesId = GeneratedColumn<String>(
    'species_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationIdMeta = const VerificationMeta(
    'locationId',
  );
  @override
  late final GeneratedColumn<String> locationId = GeneratedColumn<String>(
    'location_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pinXMeta = const VerificationMeta('pinX');
  @override
  late final GeneratedColumn<double> pinX = GeneratedColumn<double>(
    'pin_x',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pinYMeta = const VerificationMeta('pinY');
  @override
  late final GeneratedColumn<double> pinY = GeneratedColumn<double>(
    'pin_y',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notificationsMutedMeta =
      const VerificationMeta('notificationsMuted');
  @override
  late final GeneratedColumn<bool> notificationsMuted = GeneratedColumn<bool>(
    'notifications_muted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("notifications_muted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _acquiredAtMeta = const VerificationMeta(
    'acquiredAt',
  );
  @override
  late final GeneratedColumn<int> acquiredAt = GeneratedColumn<int>(
    'acquired_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _potSizeCmMeta = const VerificationMeta(
    'potSizeCm',
  );
  @override
  late final GeneratedColumn<int> potSizeCm = GeneratedColumn<int>(
    'pot_size_cm',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedHlcMeta = const VerificationMeta(
    'updatedHlc',
  );
  @override
  late final GeneratedColumn<String> updatedHlc = GeneratedColumn<String>(
    'updated_hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    nickname,
    speciesId,
    locationId,
    pinX,
    pinY,
    notificationsMuted,
    status,
    acquiredAt,
    source,
    notes,
    potSizeCm,
    updatedHlc,
    deletedAt,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plants';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlantRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('nickname')) {
      context.handle(
        _nicknameMeta,
        nickname.isAcceptableOrUnknown(data['nickname']!, _nicknameMeta),
      );
    } else if (isInserting) {
      context.missing(_nicknameMeta);
    }
    if (data.containsKey('species_id')) {
      context.handle(
        _speciesIdMeta,
        speciesId.isAcceptableOrUnknown(data['species_id']!, _speciesIdMeta),
      );
    }
    if (data.containsKey('location_id')) {
      context.handle(
        _locationIdMeta,
        locationId.isAcceptableOrUnknown(data['location_id']!, _locationIdMeta),
      );
    }
    if (data.containsKey('pin_x')) {
      context.handle(
        _pinXMeta,
        pinX.isAcceptableOrUnknown(data['pin_x']!, _pinXMeta),
      );
    }
    if (data.containsKey('pin_y')) {
      context.handle(
        _pinYMeta,
        pinY.isAcceptableOrUnknown(data['pin_y']!, _pinYMeta),
      );
    }
    if (data.containsKey('notifications_muted')) {
      context.handle(
        _notificationsMutedMeta,
        notificationsMuted.isAcceptableOrUnknown(
          data['notifications_muted']!,
          _notificationsMutedMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('acquired_at')) {
      context.handle(
        _acquiredAtMeta,
        acquiredAt.isAcceptableOrUnknown(data['acquired_at']!, _acquiredAtMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('pot_size_cm')) {
      context.handle(
        _potSizeCmMeta,
        potSizeCm.isAcceptableOrUnknown(data['pot_size_cm']!, _potSizeCmMeta),
      );
    }
    if (data.containsKey('updated_hlc')) {
      context.handle(
        _updatedHlcMeta,
        updatedHlc.isAcceptableOrUnknown(data['updated_hlc']!, _updatedHlcMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedHlcMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlantRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlantRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      nickname: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nickname'],
      )!,
      speciesId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}species_id'],
      ),
      locationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_id'],
      ),
      pinX: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pin_x'],
      ),
      pinY: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pin_y'],
      ),
      notificationsMuted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notifications_muted'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      acquiredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}acquired_at'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      potSizeCm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pot_size_cm'],
      ),
      updatedHlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_hlc'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  $PlantsTable createAlias(String alias) {
    return $PlantsTable(attachedDatabase, alias);
  }
}

class PlantRow extends DataClass implements Insertable<PlantRow> {
  final String id;
  final String tenantId;
  final String nickname;
  final String? speciesId;
  final String? locationId;

  /// Pin coordinates on the current location's `map_photo_sha`, stored
  /// as fractions 0..1 relative to the map image so the pin stays put
  /// if the user re-exports the map at a different resolution. Null
  /// when the plant isn't placed.
  final double? pinX;
  final double? pinY;

  /// Per-plant notification mute (applies to every schedule for this
  /// plant). Users can also mute per-schedule — see `care_schedules`.
  final bool notificationsMuted;
  final String status;
  final int? acquiredAt;
  final String? source;
  final String? notes;
  final int? potSizeCm;
  final String updatedHlc;
  final int? deletedAt;
  final String deviceId;
  const PlantRow({
    required this.id,
    required this.tenantId,
    required this.nickname,
    this.speciesId,
    this.locationId,
    this.pinX,
    this.pinY,
    required this.notificationsMuted,
    required this.status,
    this.acquiredAt,
    this.source,
    this.notes,
    this.potSizeCm,
    required this.updatedHlc,
    this.deletedAt,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['nickname'] = Variable<String>(nickname);
    if (!nullToAbsent || speciesId != null) {
      map['species_id'] = Variable<String>(speciesId);
    }
    if (!nullToAbsent || locationId != null) {
      map['location_id'] = Variable<String>(locationId);
    }
    if (!nullToAbsent || pinX != null) {
      map['pin_x'] = Variable<double>(pinX);
    }
    if (!nullToAbsent || pinY != null) {
      map['pin_y'] = Variable<double>(pinY);
    }
    map['notifications_muted'] = Variable<bool>(notificationsMuted);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || acquiredAt != null) {
      map['acquired_at'] = Variable<int>(acquiredAt);
    }
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || potSizeCm != null) {
      map['pot_size_cm'] = Variable<int>(potSizeCm);
    }
    map['updated_hlc'] = Variable<String>(updatedHlc);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  PlantsCompanion toCompanion(bool nullToAbsent) {
    return PlantsCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      nickname: Value(nickname),
      speciesId: speciesId == null && nullToAbsent
          ? const Value.absent()
          : Value(speciesId),
      locationId: locationId == null && nullToAbsent
          ? const Value.absent()
          : Value(locationId),
      pinX: pinX == null && nullToAbsent ? const Value.absent() : Value(pinX),
      pinY: pinY == null && nullToAbsent ? const Value.absent() : Value(pinY),
      notificationsMuted: Value(notificationsMuted),
      status: Value(status),
      acquiredAt: acquiredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(acquiredAt),
      source: source == null && nullToAbsent
          ? const Value.absent()
          : Value(source),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      potSizeCm: potSizeCm == null && nullToAbsent
          ? const Value.absent()
          : Value(potSizeCm),
      updatedHlc: Value(updatedHlc),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
    );
  }

  factory PlantRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlantRow(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      nickname: serializer.fromJson<String>(json['nickname']),
      speciesId: serializer.fromJson<String?>(json['speciesId']),
      locationId: serializer.fromJson<String?>(json['locationId']),
      pinX: serializer.fromJson<double?>(json['pinX']),
      pinY: serializer.fromJson<double?>(json['pinY']),
      notificationsMuted: serializer.fromJson<bool>(json['notificationsMuted']),
      status: serializer.fromJson<String>(json['status']),
      acquiredAt: serializer.fromJson<int?>(json['acquiredAt']),
      source: serializer.fromJson<String?>(json['source']),
      notes: serializer.fromJson<String?>(json['notes']),
      potSizeCm: serializer.fromJson<int?>(json['potSizeCm']),
      updatedHlc: serializer.fromJson<String>(json['updatedHlc']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'nickname': serializer.toJson<String>(nickname),
      'speciesId': serializer.toJson<String?>(speciesId),
      'locationId': serializer.toJson<String?>(locationId),
      'pinX': serializer.toJson<double?>(pinX),
      'pinY': serializer.toJson<double?>(pinY),
      'notificationsMuted': serializer.toJson<bool>(notificationsMuted),
      'status': serializer.toJson<String>(status),
      'acquiredAt': serializer.toJson<int?>(acquiredAt),
      'source': serializer.toJson<String?>(source),
      'notes': serializer.toJson<String?>(notes),
      'potSizeCm': serializer.toJson<int?>(potSizeCm),
      'updatedHlc': serializer.toJson<String>(updatedHlc),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
    };
  }

  PlantRow copyWith({
    String? id,
    String? tenantId,
    String? nickname,
    Value<String?> speciesId = const Value.absent(),
    Value<String?> locationId = const Value.absent(),
    Value<double?> pinX = const Value.absent(),
    Value<double?> pinY = const Value.absent(),
    bool? notificationsMuted,
    String? status,
    Value<int?> acquiredAt = const Value.absent(),
    Value<String?> source = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<int?> potSizeCm = const Value.absent(),
    String? updatedHlc,
    Value<int?> deletedAt = const Value.absent(),
    String? deviceId,
  }) => PlantRow(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    nickname: nickname ?? this.nickname,
    speciesId: speciesId.present ? speciesId.value : this.speciesId,
    locationId: locationId.present ? locationId.value : this.locationId,
    pinX: pinX.present ? pinX.value : this.pinX,
    pinY: pinY.present ? pinY.value : this.pinY,
    notificationsMuted: notificationsMuted ?? this.notificationsMuted,
    status: status ?? this.status,
    acquiredAt: acquiredAt.present ? acquiredAt.value : this.acquiredAt,
    source: source.present ? source.value : this.source,
    notes: notes.present ? notes.value : this.notes,
    potSizeCm: potSizeCm.present ? potSizeCm.value : this.potSizeCm,
    updatedHlc: updatedHlc ?? this.updatedHlc,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
  );
  PlantRow copyWithCompanion(PlantsCompanion data) {
    return PlantRow(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      nickname: data.nickname.present ? data.nickname.value : this.nickname,
      speciesId: data.speciesId.present ? data.speciesId.value : this.speciesId,
      locationId: data.locationId.present
          ? data.locationId.value
          : this.locationId,
      pinX: data.pinX.present ? data.pinX.value : this.pinX,
      pinY: data.pinY.present ? data.pinY.value : this.pinY,
      notificationsMuted: data.notificationsMuted.present
          ? data.notificationsMuted.value
          : this.notificationsMuted,
      status: data.status.present ? data.status.value : this.status,
      acquiredAt: data.acquiredAt.present
          ? data.acquiredAt.value
          : this.acquiredAt,
      source: data.source.present ? data.source.value : this.source,
      notes: data.notes.present ? data.notes.value : this.notes,
      potSizeCm: data.potSizeCm.present ? data.potSizeCm.value : this.potSizeCm,
      updatedHlc: data.updatedHlc.present
          ? data.updatedHlc.value
          : this.updatedHlc,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlantRow(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('nickname: $nickname, ')
          ..write('speciesId: $speciesId, ')
          ..write('locationId: $locationId, ')
          ..write('pinX: $pinX, ')
          ..write('pinY: $pinY, ')
          ..write('notificationsMuted: $notificationsMuted, ')
          ..write('status: $status, ')
          ..write('acquiredAt: $acquiredAt, ')
          ..write('source: $source, ')
          ..write('notes: $notes, ')
          ..write('potSizeCm: $potSizeCm, ')
          ..write('updatedHlc: $updatedHlc, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    nickname,
    speciesId,
    locationId,
    pinX,
    pinY,
    notificationsMuted,
    status,
    acquiredAt,
    source,
    notes,
    potSizeCm,
    updatedHlc,
    deletedAt,
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlantRow &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.nickname == this.nickname &&
          other.speciesId == this.speciesId &&
          other.locationId == this.locationId &&
          other.pinX == this.pinX &&
          other.pinY == this.pinY &&
          other.notificationsMuted == this.notificationsMuted &&
          other.status == this.status &&
          other.acquiredAt == this.acquiredAt &&
          other.source == this.source &&
          other.notes == this.notes &&
          other.potSizeCm == this.potSizeCm &&
          other.updatedHlc == this.updatedHlc &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId);
}

class PlantsCompanion extends UpdateCompanion<PlantRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> nickname;
  final Value<String?> speciesId;
  final Value<String?> locationId;
  final Value<double?> pinX;
  final Value<double?> pinY;
  final Value<bool> notificationsMuted;
  final Value<String> status;
  final Value<int?> acquiredAt;
  final Value<String?> source;
  final Value<String?> notes;
  final Value<int?> potSizeCm;
  final Value<String> updatedHlc;
  final Value<int?> deletedAt;
  final Value<String> deviceId;
  final Value<int> rowid;
  const PlantsCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.nickname = const Value.absent(),
    this.speciesId = const Value.absent(),
    this.locationId = const Value.absent(),
    this.pinX = const Value.absent(),
    this.pinY = const Value.absent(),
    this.notificationsMuted = const Value.absent(),
    this.status = const Value.absent(),
    this.acquiredAt = const Value.absent(),
    this.source = const Value.absent(),
    this.notes = const Value.absent(),
    this.potSizeCm = const Value.absent(),
    this.updatedHlc = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlantsCompanion.insert({
    required String id,
    required String tenantId,
    required String nickname,
    this.speciesId = const Value.absent(),
    this.locationId = const Value.absent(),
    this.pinX = const Value.absent(),
    this.pinY = const Value.absent(),
    this.notificationsMuted = const Value.absent(),
    required String status,
    this.acquiredAt = const Value.absent(),
    this.source = const Value.absent(),
    this.notes = const Value.absent(),
    this.potSizeCm = const Value.absent(),
    required String updatedHlc,
    this.deletedAt = const Value.absent(),
    required String deviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       nickname = Value(nickname),
       status = Value(status),
       updatedHlc = Value(updatedHlc),
       deviceId = Value(deviceId);
  static Insertable<PlantRow> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? nickname,
    Expression<String>? speciesId,
    Expression<String>? locationId,
    Expression<double>? pinX,
    Expression<double>? pinY,
    Expression<bool>? notificationsMuted,
    Expression<String>? status,
    Expression<int>? acquiredAt,
    Expression<String>? source,
    Expression<String>? notes,
    Expression<int>? potSizeCm,
    Expression<String>? updatedHlc,
    Expression<int>? deletedAt,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (nickname != null) 'nickname': nickname,
      if (speciesId != null) 'species_id': speciesId,
      if (locationId != null) 'location_id': locationId,
      if (pinX != null) 'pin_x': pinX,
      if (pinY != null) 'pin_y': pinY,
      if (notificationsMuted != null) 'notifications_muted': notificationsMuted,
      if (status != null) 'status': status,
      if (acquiredAt != null) 'acquired_at': acquiredAt,
      if (source != null) 'source': source,
      if (notes != null) 'notes': notes,
      if (potSizeCm != null) 'pot_size_cm': potSizeCm,
      if (updatedHlc != null) 'updated_hlc': updatedHlc,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlantsCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? nickname,
    Value<String?>? speciesId,
    Value<String?>? locationId,
    Value<double?>? pinX,
    Value<double?>? pinY,
    Value<bool>? notificationsMuted,
    Value<String>? status,
    Value<int?>? acquiredAt,
    Value<String?>? source,
    Value<String?>? notes,
    Value<int?>? potSizeCm,
    Value<String>? updatedHlc,
    Value<int?>? deletedAt,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return PlantsCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      nickname: nickname ?? this.nickname,
      speciesId: speciesId ?? this.speciesId,
      locationId: locationId ?? this.locationId,
      pinX: pinX ?? this.pinX,
      pinY: pinY ?? this.pinY,
      notificationsMuted: notificationsMuted ?? this.notificationsMuted,
      status: status ?? this.status,
      acquiredAt: acquiredAt ?? this.acquiredAt,
      source: source ?? this.source,
      notes: notes ?? this.notes,
      potSizeCm: potSizeCm ?? this.potSizeCm,
      updatedHlc: updatedHlc ?? this.updatedHlc,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (nickname.present) {
      map['nickname'] = Variable<String>(nickname.value);
    }
    if (speciesId.present) {
      map['species_id'] = Variable<String>(speciesId.value);
    }
    if (locationId.present) {
      map['location_id'] = Variable<String>(locationId.value);
    }
    if (pinX.present) {
      map['pin_x'] = Variable<double>(pinX.value);
    }
    if (pinY.present) {
      map['pin_y'] = Variable<double>(pinY.value);
    }
    if (notificationsMuted.present) {
      map['notifications_muted'] = Variable<bool>(notificationsMuted.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (acquiredAt.present) {
      map['acquired_at'] = Variable<int>(acquiredAt.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (potSizeCm.present) {
      map['pot_size_cm'] = Variable<int>(potSizeCm.value);
    }
    if (updatedHlc.present) {
      map['updated_hlc'] = Variable<String>(updatedHlc.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlantsCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('nickname: $nickname, ')
          ..write('speciesId: $speciesId, ')
          ..write('locationId: $locationId, ')
          ..write('pinX: $pinX, ')
          ..write('pinY: $pinY, ')
          ..write('notificationsMuted: $notificationsMuted, ')
          ..write('status: $status, ')
          ..write('acquiredAt: $acquiredAt, ')
          ..write('source: $source, ')
          ..write('notes: $notes, ')
          ..write('potSizeCm: $potSizeCm, ')
          ..write('updatedHlc: $updatedHlc, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PhotosTable extends Photos with TableInfo<$PhotosTable, PhotoRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mimeMeta = const VerificationMeta('mime');
  @override
  late final GeneratedColumn<String> mime = GeneratedColumn<String>(
    'mime',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _takenAtMeta = const VerificationMeta(
    'takenAt',
  );
  @override
  late final GeneratedColumn<int> takenAt = GeneratedColumn<int>(
    'taken_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exifJsonMeta = const VerificationMeta(
    'exifJson',
  );
  @override
  late final GeneratedColumn<String> exifJson = GeneratedColumn<String>(
    'exif_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteStateMeta = const VerificationMeta(
    'remoteState',
  );
  @override
  late final GeneratedColumn<String> remoteState = GeneratedColumn<String>(
    'remote_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  static const VerificationMeta _updatedHlcMeta = const VerificationMeta(
    'updatedHlc',
  );
  @override
  late final GeneratedColumn<String> updatedHlc = GeneratedColumn<String>(
    'updated_hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sha256,
    tenantId,
    width,
    height,
    mime,
    bytes,
    takenAt,
    exifJson,
    localPath,
    remoteState,
    updatedHlc,
    deletedAt,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'photos';
  @override
  VerificationContext validateIntegrity(
    Insertable<PhotoRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    } else if (isInserting) {
      context.missing(_sha256Meta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('mime')) {
      context.handle(
        _mimeMeta,
        mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('taken_at')) {
      context.handle(
        _takenAtMeta,
        takenAt.isAcceptableOrUnknown(data['taken_at']!, _takenAtMeta),
      );
    }
    if (data.containsKey('exif_json')) {
      context.handle(
        _exifJsonMeta,
        exifJson.isAcceptableOrUnknown(data['exif_json']!, _exifJsonMeta),
      );
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('remote_state')) {
      context.handle(
        _remoteStateMeta,
        remoteState.isAcceptableOrUnknown(
          data['remote_state']!,
          _remoteStateMeta,
        ),
      );
    }
    if (data.containsKey('updated_hlc')) {
      context.handle(
        _updatedHlcMeta,
        updatedHlc.isAcceptableOrUnknown(data['updated_hlc']!, _updatedHlcMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedHlcMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sha256};
  @override
  PhotoRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhotoRow(
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      ),
      mime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      )!,
      takenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}taken_at'],
      ),
      exifJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exif_json'],
      ),
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      remoteState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_state'],
      )!,
      updatedHlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_hlc'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  $PhotosTable createAlias(String alias) {
    return $PhotosTable(attachedDatabase, alias);
  }
}

class PhotoRow extends DataClass implements Insertable<PhotoRow> {
  final String sha256;
  final String tenantId;
  final int? width;
  final int? height;
  final String mime;
  final int bytes;
  final int? takenAt;
  final String? exifJson;
  final String? localPath;
  final String remoteState;
  final String updatedHlc;
  final int? deletedAt;
  final String deviceId;
  const PhotoRow({
    required this.sha256,
    required this.tenantId,
    this.width,
    this.height,
    required this.mime,
    required this.bytes,
    this.takenAt,
    this.exifJson,
    this.localPath,
    required this.remoteState,
    required this.updatedHlc,
    this.deletedAt,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sha256'] = Variable<String>(sha256);
    map['tenant_id'] = Variable<String>(tenantId);
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<int>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    map['mime'] = Variable<String>(mime);
    map['bytes'] = Variable<int>(bytes);
    if (!nullToAbsent || takenAt != null) {
      map['taken_at'] = Variable<int>(takenAt);
    }
    if (!nullToAbsent || exifJson != null) {
      map['exif_json'] = Variable<String>(exifJson);
    }
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    map['remote_state'] = Variable<String>(remoteState);
    map['updated_hlc'] = Variable<String>(updatedHlc);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  PhotosCompanion toCompanion(bool nullToAbsent) {
    return PhotosCompanion(
      sha256: Value(sha256),
      tenantId: Value(tenantId),
      width: width == null && nullToAbsent
          ? const Value.absent()
          : Value(width),
      height: height == null && nullToAbsent
          ? const Value.absent()
          : Value(height),
      mime: Value(mime),
      bytes: Value(bytes),
      takenAt: takenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(takenAt),
      exifJson: exifJson == null && nullToAbsent
          ? const Value.absent()
          : Value(exifJson),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      remoteState: Value(remoteState),
      updatedHlc: Value(updatedHlc),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
    );
  }

  factory PhotoRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhotoRow(
      sha256: serializer.fromJson<String>(json['sha256']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      width: serializer.fromJson<int?>(json['width']),
      height: serializer.fromJson<int?>(json['height']),
      mime: serializer.fromJson<String>(json['mime']),
      bytes: serializer.fromJson<int>(json['bytes']),
      takenAt: serializer.fromJson<int?>(json['takenAt']),
      exifJson: serializer.fromJson<String?>(json['exifJson']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      remoteState: serializer.fromJson<String>(json['remoteState']),
      updatedHlc: serializer.fromJson<String>(json['updatedHlc']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sha256': serializer.toJson<String>(sha256),
      'tenantId': serializer.toJson<String>(tenantId),
      'width': serializer.toJson<int?>(width),
      'height': serializer.toJson<int?>(height),
      'mime': serializer.toJson<String>(mime),
      'bytes': serializer.toJson<int>(bytes),
      'takenAt': serializer.toJson<int?>(takenAt),
      'exifJson': serializer.toJson<String?>(exifJson),
      'localPath': serializer.toJson<String?>(localPath),
      'remoteState': serializer.toJson<String>(remoteState),
      'updatedHlc': serializer.toJson<String>(updatedHlc),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
    };
  }

  PhotoRow copyWith({
    String? sha256,
    String? tenantId,
    Value<int?> width = const Value.absent(),
    Value<int?> height = const Value.absent(),
    String? mime,
    int? bytes,
    Value<int?> takenAt = const Value.absent(),
    Value<String?> exifJson = const Value.absent(),
    Value<String?> localPath = const Value.absent(),
    String? remoteState,
    String? updatedHlc,
    Value<int?> deletedAt = const Value.absent(),
    String? deviceId,
  }) => PhotoRow(
    sha256: sha256 ?? this.sha256,
    tenantId: tenantId ?? this.tenantId,
    width: width.present ? width.value : this.width,
    height: height.present ? height.value : this.height,
    mime: mime ?? this.mime,
    bytes: bytes ?? this.bytes,
    takenAt: takenAt.present ? takenAt.value : this.takenAt,
    exifJson: exifJson.present ? exifJson.value : this.exifJson,
    localPath: localPath.present ? localPath.value : this.localPath,
    remoteState: remoteState ?? this.remoteState,
    updatedHlc: updatedHlc ?? this.updatedHlc,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
  );
  PhotoRow copyWithCompanion(PhotosCompanion data) {
    return PhotoRow(
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      mime: data.mime.present ? data.mime.value : this.mime,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      takenAt: data.takenAt.present ? data.takenAt.value : this.takenAt,
      exifJson: data.exifJson.present ? data.exifJson.value : this.exifJson,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      remoteState: data.remoteState.present
          ? data.remoteState.value
          : this.remoteState,
      updatedHlc: data.updatedHlc.present
          ? data.updatedHlc.value
          : this.updatedHlc,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhotoRow(')
          ..write('sha256: $sha256, ')
          ..write('tenantId: $tenantId, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('mime: $mime, ')
          ..write('bytes: $bytes, ')
          ..write('takenAt: $takenAt, ')
          ..write('exifJson: $exifJson, ')
          ..write('localPath: $localPath, ')
          ..write('remoteState: $remoteState, ')
          ..write('updatedHlc: $updatedHlc, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sha256,
    tenantId,
    width,
    height,
    mime,
    bytes,
    takenAt,
    exifJson,
    localPath,
    remoteState,
    updatedHlc,
    deletedAt,
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhotoRow &&
          other.sha256 == this.sha256 &&
          other.tenantId == this.tenantId &&
          other.width == this.width &&
          other.height == this.height &&
          other.mime == this.mime &&
          other.bytes == this.bytes &&
          other.takenAt == this.takenAt &&
          other.exifJson == this.exifJson &&
          other.localPath == this.localPath &&
          other.remoteState == this.remoteState &&
          other.updatedHlc == this.updatedHlc &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId);
}

class PhotosCompanion extends UpdateCompanion<PhotoRow> {
  final Value<String> sha256;
  final Value<String> tenantId;
  final Value<int?> width;
  final Value<int?> height;
  final Value<String> mime;
  final Value<int> bytes;
  final Value<int?> takenAt;
  final Value<String?> exifJson;
  final Value<String?> localPath;
  final Value<String> remoteState;
  final Value<String> updatedHlc;
  final Value<int?> deletedAt;
  final Value<String> deviceId;
  final Value<int> rowid;
  const PhotosCompanion({
    this.sha256 = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.mime = const Value.absent(),
    this.bytes = const Value.absent(),
    this.takenAt = const Value.absent(),
    this.exifJson = const Value.absent(),
    this.localPath = const Value.absent(),
    this.remoteState = const Value.absent(),
    this.updatedHlc = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PhotosCompanion.insert({
    required String sha256,
    required String tenantId,
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    required String mime,
    required int bytes,
    this.takenAt = const Value.absent(),
    this.exifJson = const Value.absent(),
    this.localPath = const Value.absent(),
    this.remoteState = const Value.absent(),
    required String updatedHlc,
    this.deletedAt = const Value.absent(),
    required String deviceId,
    this.rowid = const Value.absent(),
  }) : sha256 = Value(sha256),
       tenantId = Value(tenantId),
       mime = Value(mime),
       bytes = Value(bytes),
       updatedHlc = Value(updatedHlc),
       deviceId = Value(deviceId);
  static Insertable<PhotoRow> custom({
    Expression<String>? sha256,
    Expression<String>? tenantId,
    Expression<int>? width,
    Expression<int>? height,
    Expression<String>? mime,
    Expression<int>? bytes,
    Expression<int>? takenAt,
    Expression<String>? exifJson,
    Expression<String>? localPath,
    Expression<String>? remoteState,
    Expression<String>? updatedHlc,
    Expression<int>? deletedAt,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sha256 != null) 'sha256': sha256,
      if (tenantId != null) 'tenant_id': tenantId,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (mime != null) 'mime': mime,
      if (bytes != null) 'bytes': bytes,
      if (takenAt != null) 'taken_at': takenAt,
      if (exifJson != null) 'exif_json': exifJson,
      if (localPath != null) 'local_path': localPath,
      if (remoteState != null) 'remote_state': remoteState,
      if (updatedHlc != null) 'updated_hlc': updatedHlc,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PhotosCompanion copyWith({
    Value<String>? sha256,
    Value<String>? tenantId,
    Value<int?>? width,
    Value<int?>? height,
    Value<String>? mime,
    Value<int>? bytes,
    Value<int?>? takenAt,
    Value<String?>? exifJson,
    Value<String?>? localPath,
    Value<String>? remoteState,
    Value<String>? updatedHlc,
    Value<int?>? deletedAt,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return PhotosCompanion(
      sha256: sha256 ?? this.sha256,
      tenantId: tenantId ?? this.tenantId,
      width: width ?? this.width,
      height: height ?? this.height,
      mime: mime ?? this.mime,
      bytes: bytes ?? this.bytes,
      takenAt: takenAt ?? this.takenAt,
      exifJson: exifJson ?? this.exifJson,
      localPath: localPath ?? this.localPath,
      remoteState: remoteState ?? this.remoteState,
      updatedHlc: updatedHlc ?? this.updatedHlc,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (mime.present) {
      map['mime'] = Variable<String>(mime.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (takenAt.present) {
      map['taken_at'] = Variable<int>(takenAt.value);
    }
    if (exifJson.present) {
      map['exif_json'] = Variable<String>(exifJson.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (remoteState.present) {
      map['remote_state'] = Variable<String>(remoteState.value);
    }
    if (updatedHlc.present) {
      map['updated_hlc'] = Variable<String>(updatedHlc.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhotosCompanion(')
          ..write('sha256: $sha256, ')
          ..write('tenantId: $tenantId, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('mime: $mime, ')
          ..write('bytes: $bytes, ')
          ..write('takenAt: $takenAt, ')
          ..write('exifJson: $exifJson, ')
          ..write('localPath: $localPath, ')
          ..write('remoteState: $remoteState, ')
          ..write('updatedHlc: $updatedHlc, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlantPhotosTable extends PlantPhotos
    with TableInfo<$PlantPhotosTable, PlantPhotoRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlantPhotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plantIdMeta = const VerificationMeta(
    'plantId',
  );
  @override
  late final GeneratedColumn<String> plantId = GeneratedColumn<String>(
    'plant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _photoShaMeta = const VerificationMeta(
    'photoSha',
  );
  @override
  late final GeneratedColumn<String> photoSha = GeneratedColumn<String>(
    'photo_sha',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _captionMeta = const VerificationMeta(
    'caption',
  );
  @override
  late final GeneratedColumn<String> caption = GeneratedColumn<String>(
    'caption',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<int> capturedAt = GeneratedColumn<int>(
    'captured_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _displayOrderMeta = const VerificationMeta(
    'displayOrder',
  );
  @override
  late final GeneratedColumn<int> displayOrder = GeneratedColumn<int>(
    'display_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _addedHlcMeta = const VerificationMeta(
    'addedHlc',
  );
  @override
  late final GeneratedColumn<String> addedHlc = GeneratedColumn<String>(
    'added_hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _removedHlcMeta = const VerificationMeta(
    'removedHlc',
  );
  @override
  late final GeneratedColumn<String> removedHlc = GeneratedColumn<String>(
    'removed_hlc',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    plantId,
    photoSha,
    caption,
    capturedAt,
    displayOrder,
    addedHlc,
    removedHlc,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plant_photos';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlantPhotoRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('plant_id')) {
      context.handle(
        _plantIdMeta,
        plantId.isAcceptableOrUnknown(data['plant_id']!, _plantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_plantIdMeta);
    }
    if (data.containsKey('photo_sha')) {
      context.handle(
        _photoShaMeta,
        photoSha.isAcceptableOrUnknown(data['photo_sha']!, _photoShaMeta),
      );
    } else if (isInserting) {
      context.missing(_photoShaMeta);
    }
    if (data.containsKey('caption')) {
      context.handle(
        _captionMeta,
        caption.isAcceptableOrUnknown(data['caption']!, _captionMeta),
      );
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    }
    if (data.containsKey('display_order')) {
      context.handle(
        _displayOrderMeta,
        displayOrder.isAcceptableOrUnknown(
          data['display_order']!,
          _displayOrderMeta,
        ),
      );
    }
    if (data.containsKey('added_hlc')) {
      context.handle(
        _addedHlcMeta,
        addedHlc.isAcceptableOrUnknown(data['added_hlc']!, _addedHlcMeta),
      );
    } else if (isInserting) {
      context.missing(_addedHlcMeta);
    }
    if (data.containsKey('removed_hlc')) {
      context.handle(
        _removedHlcMeta,
        removedHlc.isAcceptableOrUnknown(data['removed_hlc']!, _removedHlcMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlantPhotoRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlantPhotoRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      plantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plant_id'],
      )!,
      photoSha: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_sha'],
      )!,
      caption: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}caption'],
      ),
      capturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}captured_at'],
      ),
      displayOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}display_order'],
      )!,
      addedHlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}added_hlc'],
      )!,
      removedHlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}removed_hlc'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  $PlantPhotosTable createAlias(String alias) {
    return $PlantPhotosTable(attachedDatabase, alias);
  }
}

class PlantPhotoRow extends DataClass implements Insertable<PlantPhotoRow> {
  final String id;
  final String tenantId;
  final String plantId;
  final String photoSha;

  /// Optional free-form annotation for this attachment — e.g. "yellow
  /// leaf Apr 18". Stored per-attachment, not per-SHA, so the same
  /// photo attached to two plants can carry different captions.
  final String? caption;

  /// User-visible "date this photo was taken/added" — display-only metadata
  /// distinct from [addedHlc] (which is load-bearing for OR-set merge).
  /// Nullable; when null, the UI falls back to the physicalMs component of
  /// [addedHlc]. Editing this does not perturb CRDT ordering.
  final int? capturedAt;
  final int displayOrder;
  final String addedHlc;
  final String? removedHlc;
  final String deviceId;
  const PlantPhotoRow({
    required this.id,
    required this.tenantId,
    required this.plantId,
    required this.photoSha,
    this.caption,
    this.capturedAt,
    required this.displayOrder,
    required this.addedHlc,
    this.removedHlc,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['plant_id'] = Variable<String>(plantId);
    map['photo_sha'] = Variable<String>(photoSha);
    if (!nullToAbsent || caption != null) {
      map['caption'] = Variable<String>(caption);
    }
    if (!nullToAbsent || capturedAt != null) {
      map['captured_at'] = Variable<int>(capturedAt);
    }
    map['display_order'] = Variable<int>(displayOrder);
    map['added_hlc'] = Variable<String>(addedHlc);
    if (!nullToAbsent || removedHlc != null) {
      map['removed_hlc'] = Variable<String>(removedHlc);
    }
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  PlantPhotosCompanion toCompanion(bool nullToAbsent) {
    return PlantPhotosCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      plantId: Value(plantId),
      photoSha: Value(photoSha),
      caption: caption == null && nullToAbsent
          ? const Value.absent()
          : Value(caption),
      capturedAt: capturedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(capturedAt),
      displayOrder: Value(displayOrder),
      addedHlc: Value(addedHlc),
      removedHlc: removedHlc == null && nullToAbsent
          ? const Value.absent()
          : Value(removedHlc),
      deviceId: Value(deviceId),
    );
  }

  factory PlantPhotoRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlantPhotoRow(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      plantId: serializer.fromJson<String>(json['plantId']),
      photoSha: serializer.fromJson<String>(json['photoSha']),
      caption: serializer.fromJson<String?>(json['caption']),
      capturedAt: serializer.fromJson<int?>(json['capturedAt']),
      displayOrder: serializer.fromJson<int>(json['displayOrder']),
      addedHlc: serializer.fromJson<String>(json['addedHlc']),
      removedHlc: serializer.fromJson<String?>(json['removedHlc']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'plantId': serializer.toJson<String>(plantId),
      'photoSha': serializer.toJson<String>(photoSha),
      'caption': serializer.toJson<String?>(caption),
      'capturedAt': serializer.toJson<int?>(capturedAt),
      'displayOrder': serializer.toJson<int>(displayOrder),
      'addedHlc': serializer.toJson<String>(addedHlc),
      'removedHlc': serializer.toJson<String?>(removedHlc),
      'deviceId': serializer.toJson<String>(deviceId),
    };
  }

  PlantPhotoRow copyWith({
    String? id,
    String? tenantId,
    String? plantId,
    String? photoSha,
    Value<String?> caption = const Value.absent(),
    Value<int?> capturedAt = const Value.absent(),
    int? displayOrder,
    String? addedHlc,
    Value<String?> removedHlc = const Value.absent(),
    String? deviceId,
  }) => PlantPhotoRow(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    plantId: plantId ?? this.plantId,
    photoSha: photoSha ?? this.photoSha,
    caption: caption.present ? caption.value : this.caption,
    capturedAt: capturedAt.present ? capturedAt.value : this.capturedAt,
    displayOrder: displayOrder ?? this.displayOrder,
    addedHlc: addedHlc ?? this.addedHlc,
    removedHlc: removedHlc.present ? removedHlc.value : this.removedHlc,
    deviceId: deviceId ?? this.deviceId,
  );
  PlantPhotoRow copyWithCompanion(PlantPhotosCompanion data) {
    return PlantPhotoRow(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      plantId: data.plantId.present ? data.plantId.value : this.plantId,
      photoSha: data.photoSha.present ? data.photoSha.value : this.photoSha,
      caption: data.caption.present ? data.caption.value : this.caption,
      capturedAt: data.capturedAt.present
          ? data.capturedAt.value
          : this.capturedAt,
      displayOrder: data.displayOrder.present
          ? data.displayOrder.value
          : this.displayOrder,
      addedHlc: data.addedHlc.present ? data.addedHlc.value : this.addedHlc,
      removedHlc: data.removedHlc.present
          ? data.removedHlc.value
          : this.removedHlc,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlantPhotoRow(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('plantId: $plantId, ')
          ..write('photoSha: $photoSha, ')
          ..write('caption: $caption, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('displayOrder: $displayOrder, ')
          ..write('addedHlc: $addedHlc, ')
          ..write('removedHlc: $removedHlc, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    plantId,
    photoSha,
    caption,
    capturedAt,
    displayOrder,
    addedHlc,
    removedHlc,
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlantPhotoRow &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.plantId == this.plantId &&
          other.photoSha == this.photoSha &&
          other.caption == this.caption &&
          other.capturedAt == this.capturedAt &&
          other.displayOrder == this.displayOrder &&
          other.addedHlc == this.addedHlc &&
          other.removedHlc == this.removedHlc &&
          other.deviceId == this.deviceId);
}

class PlantPhotosCompanion extends UpdateCompanion<PlantPhotoRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> plantId;
  final Value<String> photoSha;
  final Value<String?> caption;
  final Value<int?> capturedAt;
  final Value<int> displayOrder;
  final Value<String> addedHlc;
  final Value<String?> removedHlc;
  final Value<String> deviceId;
  final Value<int> rowid;
  const PlantPhotosCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.plantId = const Value.absent(),
    this.photoSha = const Value.absent(),
    this.caption = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.displayOrder = const Value.absent(),
    this.addedHlc = const Value.absent(),
    this.removedHlc = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlantPhotosCompanion.insert({
    required String id,
    required String tenantId,
    required String plantId,
    required String photoSha,
    this.caption = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.displayOrder = const Value.absent(),
    required String addedHlc,
    this.removedHlc = const Value.absent(),
    required String deviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       plantId = Value(plantId),
       photoSha = Value(photoSha),
       addedHlc = Value(addedHlc),
       deviceId = Value(deviceId);
  static Insertable<PlantPhotoRow> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? plantId,
    Expression<String>? photoSha,
    Expression<String>? caption,
    Expression<int>? capturedAt,
    Expression<int>? displayOrder,
    Expression<String>? addedHlc,
    Expression<String>? removedHlc,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (plantId != null) 'plant_id': plantId,
      if (photoSha != null) 'photo_sha': photoSha,
      if (caption != null) 'caption': caption,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (displayOrder != null) 'display_order': displayOrder,
      if (addedHlc != null) 'added_hlc': addedHlc,
      if (removedHlc != null) 'removed_hlc': removedHlc,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlantPhotosCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? plantId,
    Value<String>? photoSha,
    Value<String?>? caption,
    Value<int?>? capturedAt,
    Value<int>? displayOrder,
    Value<String>? addedHlc,
    Value<String?>? removedHlc,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return PlantPhotosCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      plantId: plantId ?? this.plantId,
      photoSha: photoSha ?? this.photoSha,
      caption: caption ?? this.caption,
      capturedAt: capturedAt ?? this.capturedAt,
      displayOrder: displayOrder ?? this.displayOrder,
      addedHlc: addedHlc ?? this.addedHlc,
      removedHlc: removedHlc ?? this.removedHlc,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (plantId.present) {
      map['plant_id'] = Variable<String>(plantId.value);
    }
    if (photoSha.present) {
      map['photo_sha'] = Variable<String>(photoSha.value);
    }
    if (caption.present) {
      map['caption'] = Variable<String>(caption.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<int>(capturedAt.value);
    }
    if (displayOrder.present) {
      map['display_order'] = Variable<int>(displayOrder.value);
    }
    if (addedHlc.present) {
      map['added_hlc'] = Variable<String>(addedHlc.value);
    }
    if (removedHlc.present) {
      map['removed_hlc'] = Variable<String>(removedHlc.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlantPhotosCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('plantId: $plantId, ')
          ..write('photoSha: $photoSha, ')
          ..write('caption: $caption, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('displayOrder: $displayOrder, ')
          ..write('addedHlc: $addedHlc, ')
          ..write('removedHlc: $removedHlc, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocationPhotosTable extends LocationPhotos
    with TableInfo<$LocationPhotosTable, LocationPhotoRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocationPhotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locationIdMeta = const VerificationMeta(
    'locationId',
  );
  @override
  late final GeneratedColumn<String> locationId = GeneratedColumn<String>(
    'location_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _photoShaMeta = const VerificationMeta(
    'photoSha',
  );
  @override
  late final GeneratedColumn<String> photoSha = GeneratedColumn<String>(
    'photo_sha',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _captionMeta = const VerificationMeta(
    'caption',
  );
  @override
  late final GeneratedColumn<String> caption = GeneratedColumn<String>(
    'caption',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<int> capturedAt = GeneratedColumn<int>(
    'captured_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _displayOrderMeta = const VerificationMeta(
    'displayOrder',
  );
  @override
  late final GeneratedColumn<int> displayOrder = GeneratedColumn<int>(
    'display_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _addedHlcMeta = const VerificationMeta(
    'addedHlc',
  );
  @override
  late final GeneratedColumn<String> addedHlc = GeneratedColumn<String>(
    'added_hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _removedHlcMeta = const VerificationMeta(
    'removedHlc',
  );
  @override
  late final GeneratedColumn<String> removedHlc = GeneratedColumn<String>(
    'removed_hlc',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    locationId,
    photoSha,
    caption,
    capturedAt,
    displayOrder,
    addedHlc,
    removedHlc,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'location_photos';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocationPhotoRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('location_id')) {
      context.handle(
        _locationIdMeta,
        locationId.isAcceptableOrUnknown(data['location_id']!, _locationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_locationIdMeta);
    }
    if (data.containsKey('photo_sha')) {
      context.handle(
        _photoShaMeta,
        photoSha.isAcceptableOrUnknown(data['photo_sha']!, _photoShaMeta),
      );
    } else if (isInserting) {
      context.missing(_photoShaMeta);
    }
    if (data.containsKey('caption')) {
      context.handle(
        _captionMeta,
        caption.isAcceptableOrUnknown(data['caption']!, _captionMeta),
      );
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    }
    if (data.containsKey('display_order')) {
      context.handle(
        _displayOrderMeta,
        displayOrder.isAcceptableOrUnknown(
          data['display_order']!,
          _displayOrderMeta,
        ),
      );
    }
    if (data.containsKey('added_hlc')) {
      context.handle(
        _addedHlcMeta,
        addedHlc.isAcceptableOrUnknown(data['added_hlc']!, _addedHlcMeta),
      );
    } else if (isInserting) {
      context.missing(_addedHlcMeta);
    }
    if (data.containsKey('removed_hlc')) {
      context.handle(
        _removedHlcMeta,
        removedHlc.isAcceptableOrUnknown(data['removed_hlc']!, _removedHlcMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocationPhotoRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocationPhotoRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      locationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_id'],
      )!,
      photoSha: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_sha'],
      )!,
      caption: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}caption'],
      ),
      capturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}captured_at'],
      ),
      displayOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}display_order'],
      )!,
      addedHlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}added_hlc'],
      )!,
      removedHlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}removed_hlc'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  $LocationPhotosTable createAlias(String alias) {
    return $LocationPhotosTable(attachedDatabase, alias);
  }
}

class LocationPhotoRow extends DataClass
    implements Insertable<LocationPhotoRow> {
  final String id;
  final String tenantId;
  final String locationId;
  final String photoSha;
  final String? caption;
  final int? capturedAt;
  final int displayOrder;
  final String addedHlc;
  final String? removedHlc;
  final String deviceId;
  const LocationPhotoRow({
    required this.id,
    required this.tenantId,
    required this.locationId,
    required this.photoSha,
    this.caption,
    this.capturedAt,
    required this.displayOrder,
    required this.addedHlc,
    this.removedHlc,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['location_id'] = Variable<String>(locationId);
    map['photo_sha'] = Variable<String>(photoSha);
    if (!nullToAbsent || caption != null) {
      map['caption'] = Variable<String>(caption);
    }
    if (!nullToAbsent || capturedAt != null) {
      map['captured_at'] = Variable<int>(capturedAt);
    }
    map['display_order'] = Variable<int>(displayOrder);
    map['added_hlc'] = Variable<String>(addedHlc);
    if (!nullToAbsent || removedHlc != null) {
      map['removed_hlc'] = Variable<String>(removedHlc);
    }
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  LocationPhotosCompanion toCompanion(bool nullToAbsent) {
    return LocationPhotosCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      locationId: Value(locationId),
      photoSha: Value(photoSha),
      caption: caption == null && nullToAbsent
          ? const Value.absent()
          : Value(caption),
      capturedAt: capturedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(capturedAt),
      displayOrder: Value(displayOrder),
      addedHlc: Value(addedHlc),
      removedHlc: removedHlc == null && nullToAbsent
          ? const Value.absent()
          : Value(removedHlc),
      deviceId: Value(deviceId),
    );
  }

  factory LocationPhotoRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocationPhotoRow(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      locationId: serializer.fromJson<String>(json['locationId']),
      photoSha: serializer.fromJson<String>(json['photoSha']),
      caption: serializer.fromJson<String?>(json['caption']),
      capturedAt: serializer.fromJson<int?>(json['capturedAt']),
      displayOrder: serializer.fromJson<int>(json['displayOrder']),
      addedHlc: serializer.fromJson<String>(json['addedHlc']),
      removedHlc: serializer.fromJson<String?>(json['removedHlc']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'locationId': serializer.toJson<String>(locationId),
      'photoSha': serializer.toJson<String>(photoSha),
      'caption': serializer.toJson<String?>(caption),
      'capturedAt': serializer.toJson<int?>(capturedAt),
      'displayOrder': serializer.toJson<int>(displayOrder),
      'addedHlc': serializer.toJson<String>(addedHlc),
      'removedHlc': serializer.toJson<String?>(removedHlc),
      'deviceId': serializer.toJson<String>(deviceId),
    };
  }

  LocationPhotoRow copyWith({
    String? id,
    String? tenantId,
    String? locationId,
    String? photoSha,
    Value<String?> caption = const Value.absent(),
    Value<int?> capturedAt = const Value.absent(),
    int? displayOrder,
    String? addedHlc,
    Value<String?> removedHlc = const Value.absent(),
    String? deviceId,
  }) => LocationPhotoRow(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    locationId: locationId ?? this.locationId,
    photoSha: photoSha ?? this.photoSha,
    caption: caption.present ? caption.value : this.caption,
    capturedAt: capturedAt.present ? capturedAt.value : this.capturedAt,
    displayOrder: displayOrder ?? this.displayOrder,
    addedHlc: addedHlc ?? this.addedHlc,
    removedHlc: removedHlc.present ? removedHlc.value : this.removedHlc,
    deviceId: deviceId ?? this.deviceId,
  );
  LocationPhotoRow copyWithCompanion(LocationPhotosCompanion data) {
    return LocationPhotoRow(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      locationId: data.locationId.present
          ? data.locationId.value
          : this.locationId,
      photoSha: data.photoSha.present ? data.photoSha.value : this.photoSha,
      caption: data.caption.present ? data.caption.value : this.caption,
      capturedAt: data.capturedAt.present
          ? data.capturedAt.value
          : this.capturedAt,
      displayOrder: data.displayOrder.present
          ? data.displayOrder.value
          : this.displayOrder,
      addedHlc: data.addedHlc.present ? data.addedHlc.value : this.addedHlc,
      removedHlc: data.removedHlc.present
          ? data.removedHlc.value
          : this.removedHlc,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocationPhotoRow(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('locationId: $locationId, ')
          ..write('photoSha: $photoSha, ')
          ..write('caption: $caption, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('displayOrder: $displayOrder, ')
          ..write('addedHlc: $addedHlc, ')
          ..write('removedHlc: $removedHlc, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    locationId,
    photoSha,
    caption,
    capturedAt,
    displayOrder,
    addedHlc,
    removedHlc,
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocationPhotoRow &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.locationId == this.locationId &&
          other.photoSha == this.photoSha &&
          other.caption == this.caption &&
          other.capturedAt == this.capturedAt &&
          other.displayOrder == this.displayOrder &&
          other.addedHlc == this.addedHlc &&
          other.removedHlc == this.removedHlc &&
          other.deviceId == this.deviceId);
}

class LocationPhotosCompanion extends UpdateCompanion<LocationPhotoRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> locationId;
  final Value<String> photoSha;
  final Value<String?> caption;
  final Value<int?> capturedAt;
  final Value<int> displayOrder;
  final Value<String> addedHlc;
  final Value<String?> removedHlc;
  final Value<String> deviceId;
  final Value<int> rowid;
  const LocationPhotosCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.locationId = const Value.absent(),
    this.photoSha = const Value.absent(),
    this.caption = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.displayOrder = const Value.absent(),
    this.addedHlc = const Value.absent(),
    this.removedHlc = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocationPhotosCompanion.insert({
    required String id,
    required String tenantId,
    required String locationId,
    required String photoSha,
    this.caption = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.displayOrder = const Value.absent(),
    required String addedHlc,
    this.removedHlc = const Value.absent(),
    required String deviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       locationId = Value(locationId),
       photoSha = Value(photoSha),
       addedHlc = Value(addedHlc),
       deviceId = Value(deviceId);
  static Insertable<LocationPhotoRow> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? locationId,
    Expression<String>? photoSha,
    Expression<String>? caption,
    Expression<int>? capturedAt,
    Expression<int>? displayOrder,
    Expression<String>? addedHlc,
    Expression<String>? removedHlc,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (locationId != null) 'location_id': locationId,
      if (photoSha != null) 'photo_sha': photoSha,
      if (caption != null) 'caption': caption,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (displayOrder != null) 'display_order': displayOrder,
      if (addedHlc != null) 'added_hlc': addedHlc,
      if (removedHlc != null) 'removed_hlc': removedHlc,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocationPhotosCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? locationId,
    Value<String>? photoSha,
    Value<String?>? caption,
    Value<int?>? capturedAt,
    Value<int>? displayOrder,
    Value<String>? addedHlc,
    Value<String?>? removedHlc,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return LocationPhotosCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      locationId: locationId ?? this.locationId,
      photoSha: photoSha ?? this.photoSha,
      caption: caption ?? this.caption,
      capturedAt: capturedAt ?? this.capturedAt,
      displayOrder: displayOrder ?? this.displayOrder,
      addedHlc: addedHlc ?? this.addedHlc,
      removedHlc: removedHlc ?? this.removedHlc,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (locationId.present) {
      map['location_id'] = Variable<String>(locationId.value);
    }
    if (photoSha.present) {
      map['photo_sha'] = Variable<String>(photoSha.value);
    }
    if (caption.present) {
      map['caption'] = Variable<String>(caption.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<int>(capturedAt.value);
    }
    if (displayOrder.present) {
      map['display_order'] = Variable<int>(displayOrder.value);
    }
    if (addedHlc.present) {
      map['added_hlc'] = Variable<String>(addedHlc.value);
    }
    if (removedHlc.present) {
      map['removed_hlc'] = Variable<String>(removedHlc.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocationPhotosCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('locationId: $locationId, ')
          ..write('photoSha: $photoSha, ')
          ..write('caption: $caption, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('displayOrder: $displayOrder, ')
          ..write('addedHlc: $addedHlc, ')
          ..write('removedHlc: $removedHlc, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, TagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedHlcMeta = const VerificationMeta(
    'updatedHlc',
  );
  @override
  late final GeneratedColumn<String> updatedHlc = GeneratedColumn<String>(
    'updated_hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    name,
    color,
    updatedHlc,
    deletedAt,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<TagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('updated_hlc')) {
      context.handle(
        _updatedHlcMeta,
        updatedHlc.isAcceptableOrUnknown(data['updated_hlc']!, _updatedHlcMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedHlcMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      updatedHlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_hlc'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class TagRow extends DataClass implements Insertable<TagRow> {
  final String id;
  final String tenantId;
  final String name;
  final String? color;
  final String updatedHlc;
  final int? deletedAt;
  final String deviceId;
  const TagRow({
    required this.id,
    required this.tenantId,
    required this.name,
    this.color,
    required this.updatedHlc,
    this.deletedAt,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    map['updated_hlc'] = Variable<String>(updatedHlc);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      name: Value(name),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      updatedHlc: Value(updatedHlc),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
    );
  }

  factory TagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagRow(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<String?>(json['color']),
      updatedHlc: serializer.fromJson<String>(json['updatedHlc']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<String?>(color),
      'updatedHlc': serializer.toJson<String>(updatedHlc),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
    };
  }

  TagRow copyWith({
    String? id,
    String? tenantId,
    String? name,
    Value<String?> color = const Value.absent(),
    String? updatedHlc,
    Value<int?> deletedAt = const Value.absent(),
    String? deviceId,
  }) => TagRow(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    name: name ?? this.name,
    color: color.present ? color.value : this.color,
    updatedHlc: updatedHlc ?? this.updatedHlc,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
  );
  TagRow copyWithCompanion(TagsCompanion data) {
    return TagRow(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      updatedHlc: data.updatedHlc.present
          ? data.updatedHlc.value
          : this.updatedHlc,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TagRow(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('updatedHlc: $updatedHlc, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, tenantId, name, color, updatedHlc, deletedAt, deviceId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagRow &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.name == this.name &&
          other.color == this.color &&
          other.updatedHlc == this.updatedHlc &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId);
}

class TagsCompanion extends UpdateCompanion<TagRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> name;
  final Value<String?> color;
  final Value<String> updatedHlc;
  final Value<int?> deletedAt;
  final Value<String> deviceId;
  final Value<int> rowid;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.updatedHlc = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagsCompanion.insert({
    required String id,
    required String tenantId,
    required String name,
    this.color = const Value.absent(),
    required String updatedHlc,
    this.deletedAt = const Value.absent(),
    required String deviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       name = Value(name),
       updatedHlc = Value(updatedHlc),
       deviceId = Value(deviceId);
  static Insertable<TagRow> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? name,
    Expression<String>? color,
    Expression<String>? updatedHlc,
    Expression<int>? deletedAt,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (updatedHlc != null) 'updated_hlc': updatedHlc,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagsCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? name,
    Value<String?>? color,
    Value<String>? updatedHlc,
    Value<int?>? deletedAt,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      color: color ?? this.color,
      updatedHlc: updatedHlc ?? this.updatedHlc,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (updatedHlc.present) {
      map['updated_hlc'] = Variable<String>(updatedHlc.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('updatedHlc: $updatedHlc, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlantTagsTable extends PlantTags
    with TableInfo<$PlantTagsTable, PlantTagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlantTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plantIdMeta = const VerificationMeta(
    'plantId',
  );
  @override
  late final GeneratedColumn<String> plantId = GeneratedColumn<String>(
    'plant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedHlcMeta = const VerificationMeta(
    'addedHlc',
  );
  @override
  late final GeneratedColumn<String> addedHlc = GeneratedColumn<String>(
    'added_hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _removedHlcMeta = const VerificationMeta(
    'removedHlc',
  );
  @override
  late final GeneratedColumn<String> removedHlc = GeneratedColumn<String>(
    'removed_hlc',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    plantId,
    tagId,
    addedHlc,
    removedHlc,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plant_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlantTagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('plant_id')) {
      context.handle(
        _plantIdMeta,
        plantId.isAcceptableOrUnknown(data['plant_id']!, _plantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_plantIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    if (data.containsKey('added_hlc')) {
      context.handle(
        _addedHlcMeta,
        addedHlc.isAcceptableOrUnknown(data['added_hlc']!, _addedHlcMeta),
      );
    } else if (isInserting) {
      context.missing(_addedHlcMeta);
    }
    if (data.containsKey('removed_hlc')) {
      context.handle(
        _removedHlcMeta,
        removedHlc.isAcceptableOrUnknown(data['removed_hlc']!, _removedHlcMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlantTagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlantTagRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      plantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plant_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
      addedHlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}added_hlc'],
      )!,
      removedHlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}removed_hlc'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  $PlantTagsTable createAlias(String alias) {
    return $PlantTagsTable(attachedDatabase, alias);
  }
}

class PlantTagRow extends DataClass implements Insertable<PlantTagRow> {
  final String id;
  final String tenantId;
  final String plantId;
  final String tagId;
  final String addedHlc;
  final String? removedHlc;
  final String deviceId;
  const PlantTagRow({
    required this.id,
    required this.tenantId,
    required this.plantId,
    required this.tagId,
    required this.addedHlc,
    this.removedHlc,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['plant_id'] = Variable<String>(plantId);
    map['tag_id'] = Variable<String>(tagId);
    map['added_hlc'] = Variable<String>(addedHlc);
    if (!nullToAbsent || removedHlc != null) {
      map['removed_hlc'] = Variable<String>(removedHlc);
    }
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  PlantTagsCompanion toCompanion(bool nullToAbsent) {
    return PlantTagsCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      plantId: Value(plantId),
      tagId: Value(tagId),
      addedHlc: Value(addedHlc),
      removedHlc: removedHlc == null && nullToAbsent
          ? const Value.absent()
          : Value(removedHlc),
      deviceId: Value(deviceId),
    );
  }

  factory PlantTagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlantTagRow(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      plantId: serializer.fromJson<String>(json['plantId']),
      tagId: serializer.fromJson<String>(json['tagId']),
      addedHlc: serializer.fromJson<String>(json['addedHlc']),
      removedHlc: serializer.fromJson<String?>(json['removedHlc']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'plantId': serializer.toJson<String>(plantId),
      'tagId': serializer.toJson<String>(tagId),
      'addedHlc': serializer.toJson<String>(addedHlc),
      'removedHlc': serializer.toJson<String?>(removedHlc),
      'deviceId': serializer.toJson<String>(deviceId),
    };
  }

  PlantTagRow copyWith({
    String? id,
    String? tenantId,
    String? plantId,
    String? tagId,
    String? addedHlc,
    Value<String?> removedHlc = const Value.absent(),
    String? deviceId,
  }) => PlantTagRow(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    plantId: plantId ?? this.plantId,
    tagId: tagId ?? this.tagId,
    addedHlc: addedHlc ?? this.addedHlc,
    removedHlc: removedHlc.present ? removedHlc.value : this.removedHlc,
    deviceId: deviceId ?? this.deviceId,
  );
  PlantTagRow copyWithCompanion(PlantTagsCompanion data) {
    return PlantTagRow(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      plantId: data.plantId.present ? data.plantId.value : this.plantId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
      addedHlc: data.addedHlc.present ? data.addedHlc.value : this.addedHlc,
      removedHlc: data.removedHlc.present
          ? data.removedHlc.value
          : this.removedHlc,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlantTagRow(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('plantId: $plantId, ')
          ..write('tagId: $tagId, ')
          ..write('addedHlc: $addedHlc, ')
          ..write('removedHlc: $removedHlc, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, tenantId, plantId, tagId, addedHlc, removedHlc, deviceId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlantTagRow &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.plantId == this.plantId &&
          other.tagId == this.tagId &&
          other.addedHlc == this.addedHlc &&
          other.removedHlc == this.removedHlc &&
          other.deviceId == this.deviceId);
}

class PlantTagsCompanion extends UpdateCompanion<PlantTagRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> plantId;
  final Value<String> tagId;
  final Value<String> addedHlc;
  final Value<String?> removedHlc;
  final Value<String> deviceId;
  final Value<int> rowid;
  const PlantTagsCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.plantId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.addedHlc = const Value.absent(),
    this.removedHlc = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlantTagsCompanion.insert({
    required String id,
    required String tenantId,
    required String plantId,
    required String tagId,
    required String addedHlc,
    this.removedHlc = const Value.absent(),
    required String deviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       plantId = Value(plantId),
       tagId = Value(tagId),
       addedHlc = Value(addedHlc),
       deviceId = Value(deviceId);
  static Insertable<PlantTagRow> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? plantId,
    Expression<String>? tagId,
    Expression<String>? addedHlc,
    Expression<String>? removedHlc,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (plantId != null) 'plant_id': plantId,
      if (tagId != null) 'tag_id': tagId,
      if (addedHlc != null) 'added_hlc': addedHlc,
      if (removedHlc != null) 'removed_hlc': removedHlc,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlantTagsCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? plantId,
    Value<String>? tagId,
    Value<String>? addedHlc,
    Value<String?>? removedHlc,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return PlantTagsCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      plantId: plantId ?? this.plantId,
      tagId: tagId ?? this.tagId,
      addedHlc: addedHlc ?? this.addedHlc,
      removedHlc: removedHlc ?? this.removedHlc,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (plantId.present) {
      map['plant_id'] = Variable<String>(plantId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (addedHlc.present) {
      map['added_hlc'] = Variable<String>(addedHlc.value);
    }
    if (removedHlc.present) {
      map['removed_hlc'] = Variable<String>(removedHlc.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlantTagsCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('plantId: $plantId, ')
          ..write('tagId: $tagId, ')
          ..write('addedHlc: $addedHlc, ')
          ..write('removedHlc: $removedHlc, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CareEventsTable extends CareEvents
    with TableInfo<$CareEventsTable, CareEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CareEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plantIdMeta = const VerificationMeta(
    'plantId',
  );
  @override
  late final GeneratedColumn<String> plantId = GeneratedColumn<String>(
    'plant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _doneAtMeta = const VerificationMeta('doneAt');
  @override
  late final GeneratedColumn<int> doneAt = GeneratedColumn<int>(
    'done_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _doseMeta = const VerificationMeta('dose');
  @override
  late final GeneratedColumn<String> dose = GeneratedColumn<String>(
    'dose',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _productMeta = const VerificationMeta(
    'product',
  );
  @override
  late final GeneratedColumn<String> product = GeneratedColumn<String>(
    'product',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _photoShaMeta = const VerificationMeta(
    'photoSha',
  );
  @override
  late final GeneratedColumn<String> photoSha = GeneratedColumn<String>(
    'photo_sha',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedHlcMeta = const VerificationMeta(
    'updatedHlc',
  );
  @override
  late final GeneratedColumn<String> updatedHlc = GeneratedColumn<String>(
    'updated_hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    plantId,
    type,
    doneAt,
    notes,
    dose,
    product,
    photoSha,
    updatedHlc,
    deletedAt,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'care_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<CareEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('plant_id')) {
      context.handle(
        _plantIdMeta,
        plantId.isAcceptableOrUnknown(data['plant_id']!, _plantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_plantIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('done_at')) {
      context.handle(
        _doneAtMeta,
        doneAt.isAcceptableOrUnknown(data['done_at']!, _doneAtMeta),
      );
    } else if (isInserting) {
      context.missing(_doneAtMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('dose')) {
      context.handle(
        _doseMeta,
        dose.isAcceptableOrUnknown(data['dose']!, _doseMeta),
      );
    }
    if (data.containsKey('product')) {
      context.handle(
        _productMeta,
        product.isAcceptableOrUnknown(data['product']!, _productMeta),
      );
    }
    if (data.containsKey('photo_sha')) {
      context.handle(
        _photoShaMeta,
        photoSha.isAcceptableOrUnknown(data['photo_sha']!, _photoShaMeta),
      );
    }
    if (data.containsKey('updated_hlc')) {
      context.handle(
        _updatedHlcMeta,
        updatedHlc.isAcceptableOrUnknown(data['updated_hlc']!, _updatedHlcMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedHlcMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CareEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CareEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      plantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plant_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      doneAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}done_at'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      dose: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dose'],
      ),
      product: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product'],
      ),
      photoSha: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_sha'],
      ),
      updatedHlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_hlc'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  $CareEventsTable createAlias(String alias) {
    return $CareEventsTable(attachedDatabase, alias);
  }
}

class CareEventRow extends DataClass implements Insertable<CareEventRow> {
  final String id;
  final String tenantId;
  final String plantId;
  final String type;
  final int doneAt;
  final String? notes;
  final String? dose;
  final String? product;
  final String? photoSha;
  final String updatedHlc;
  final int? deletedAt;
  final String deviceId;
  const CareEventRow({
    required this.id,
    required this.tenantId,
    required this.plantId,
    required this.type,
    required this.doneAt,
    this.notes,
    this.dose,
    this.product,
    this.photoSha,
    required this.updatedHlc,
    this.deletedAt,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['plant_id'] = Variable<String>(plantId);
    map['type'] = Variable<String>(type);
    map['done_at'] = Variable<int>(doneAt);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || dose != null) {
      map['dose'] = Variable<String>(dose);
    }
    if (!nullToAbsent || product != null) {
      map['product'] = Variable<String>(product);
    }
    if (!nullToAbsent || photoSha != null) {
      map['photo_sha'] = Variable<String>(photoSha);
    }
    map['updated_hlc'] = Variable<String>(updatedHlc);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  CareEventsCompanion toCompanion(bool nullToAbsent) {
    return CareEventsCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      plantId: Value(plantId),
      type: Value(type),
      doneAt: Value(doneAt),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      dose: dose == null && nullToAbsent ? const Value.absent() : Value(dose),
      product: product == null && nullToAbsent
          ? const Value.absent()
          : Value(product),
      photoSha: photoSha == null && nullToAbsent
          ? const Value.absent()
          : Value(photoSha),
      updatedHlc: Value(updatedHlc),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
    );
  }

  factory CareEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CareEventRow(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      plantId: serializer.fromJson<String>(json['plantId']),
      type: serializer.fromJson<String>(json['type']),
      doneAt: serializer.fromJson<int>(json['doneAt']),
      notes: serializer.fromJson<String?>(json['notes']),
      dose: serializer.fromJson<String?>(json['dose']),
      product: serializer.fromJson<String?>(json['product']),
      photoSha: serializer.fromJson<String?>(json['photoSha']),
      updatedHlc: serializer.fromJson<String>(json['updatedHlc']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'plantId': serializer.toJson<String>(plantId),
      'type': serializer.toJson<String>(type),
      'doneAt': serializer.toJson<int>(doneAt),
      'notes': serializer.toJson<String?>(notes),
      'dose': serializer.toJson<String?>(dose),
      'product': serializer.toJson<String?>(product),
      'photoSha': serializer.toJson<String?>(photoSha),
      'updatedHlc': serializer.toJson<String>(updatedHlc),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
    };
  }

  CareEventRow copyWith({
    String? id,
    String? tenantId,
    String? plantId,
    String? type,
    int? doneAt,
    Value<String?> notes = const Value.absent(),
    Value<String?> dose = const Value.absent(),
    Value<String?> product = const Value.absent(),
    Value<String?> photoSha = const Value.absent(),
    String? updatedHlc,
    Value<int?> deletedAt = const Value.absent(),
    String? deviceId,
  }) => CareEventRow(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    plantId: plantId ?? this.plantId,
    type: type ?? this.type,
    doneAt: doneAt ?? this.doneAt,
    notes: notes.present ? notes.value : this.notes,
    dose: dose.present ? dose.value : this.dose,
    product: product.present ? product.value : this.product,
    photoSha: photoSha.present ? photoSha.value : this.photoSha,
    updatedHlc: updatedHlc ?? this.updatedHlc,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
  );
  CareEventRow copyWithCompanion(CareEventsCompanion data) {
    return CareEventRow(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      plantId: data.plantId.present ? data.plantId.value : this.plantId,
      type: data.type.present ? data.type.value : this.type,
      doneAt: data.doneAt.present ? data.doneAt.value : this.doneAt,
      notes: data.notes.present ? data.notes.value : this.notes,
      dose: data.dose.present ? data.dose.value : this.dose,
      product: data.product.present ? data.product.value : this.product,
      photoSha: data.photoSha.present ? data.photoSha.value : this.photoSha,
      updatedHlc: data.updatedHlc.present
          ? data.updatedHlc.value
          : this.updatedHlc,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CareEventRow(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('plantId: $plantId, ')
          ..write('type: $type, ')
          ..write('doneAt: $doneAt, ')
          ..write('notes: $notes, ')
          ..write('dose: $dose, ')
          ..write('product: $product, ')
          ..write('photoSha: $photoSha, ')
          ..write('updatedHlc: $updatedHlc, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    plantId,
    type,
    doneAt,
    notes,
    dose,
    product,
    photoSha,
    updatedHlc,
    deletedAt,
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CareEventRow &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.plantId == this.plantId &&
          other.type == this.type &&
          other.doneAt == this.doneAt &&
          other.notes == this.notes &&
          other.dose == this.dose &&
          other.product == this.product &&
          other.photoSha == this.photoSha &&
          other.updatedHlc == this.updatedHlc &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId);
}

class CareEventsCompanion extends UpdateCompanion<CareEventRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> plantId;
  final Value<String> type;
  final Value<int> doneAt;
  final Value<String?> notes;
  final Value<String?> dose;
  final Value<String?> product;
  final Value<String?> photoSha;
  final Value<String> updatedHlc;
  final Value<int?> deletedAt;
  final Value<String> deviceId;
  final Value<int> rowid;
  const CareEventsCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.plantId = const Value.absent(),
    this.type = const Value.absent(),
    this.doneAt = const Value.absent(),
    this.notes = const Value.absent(),
    this.dose = const Value.absent(),
    this.product = const Value.absent(),
    this.photoSha = const Value.absent(),
    this.updatedHlc = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CareEventsCompanion.insert({
    required String id,
    required String tenantId,
    required String plantId,
    required String type,
    required int doneAt,
    this.notes = const Value.absent(),
    this.dose = const Value.absent(),
    this.product = const Value.absent(),
    this.photoSha = const Value.absent(),
    required String updatedHlc,
    this.deletedAt = const Value.absent(),
    required String deviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       plantId = Value(plantId),
       type = Value(type),
       doneAt = Value(doneAt),
       updatedHlc = Value(updatedHlc),
       deviceId = Value(deviceId);
  static Insertable<CareEventRow> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? plantId,
    Expression<String>? type,
    Expression<int>? doneAt,
    Expression<String>? notes,
    Expression<String>? dose,
    Expression<String>? product,
    Expression<String>? photoSha,
    Expression<String>? updatedHlc,
    Expression<int>? deletedAt,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (plantId != null) 'plant_id': plantId,
      if (type != null) 'type': type,
      if (doneAt != null) 'done_at': doneAt,
      if (notes != null) 'notes': notes,
      if (dose != null) 'dose': dose,
      if (product != null) 'product': product,
      if (photoSha != null) 'photo_sha': photoSha,
      if (updatedHlc != null) 'updated_hlc': updatedHlc,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CareEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? plantId,
    Value<String>? type,
    Value<int>? doneAt,
    Value<String?>? notes,
    Value<String?>? dose,
    Value<String?>? product,
    Value<String?>? photoSha,
    Value<String>? updatedHlc,
    Value<int?>? deletedAt,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return CareEventsCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      plantId: plantId ?? this.plantId,
      type: type ?? this.type,
      doneAt: doneAt ?? this.doneAt,
      notes: notes ?? this.notes,
      dose: dose ?? this.dose,
      product: product ?? this.product,
      photoSha: photoSha ?? this.photoSha,
      updatedHlc: updatedHlc ?? this.updatedHlc,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (plantId.present) {
      map['plant_id'] = Variable<String>(plantId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (doneAt.present) {
      map['done_at'] = Variable<int>(doneAt.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (dose.present) {
      map['dose'] = Variable<String>(dose.value);
    }
    if (product.present) {
      map['product'] = Variable<String>(product.value);
    }
    if (photoSha.present) {
      map['photo_sha'] = Variable<String>(photoSha.value);
    }
    if (updatedHlc.present) {
      map['updated_hlc'] = Variable<String>(updatedHlc.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CareEventsCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('plantId: $plantId, ')
          ..write('type: $type, ')
          ..write('doneAt: $doneAt, ')
          ..write('notes: $notes, ')
          ..write('dose: $dose, ')
          ..write('product: $product, ')
          ..write('photoSha: $photoSha, ')
          ..write('updatedHlc: $updatedHlc, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CareSchedulesTable extends CareSchedules
    with TableInfo<$CareSchedulesTable, CareScheduleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CareSchedulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plantIdMeta = const VerificationMeta(
    'plantId',
  );
  @override
  late final GeneratedColumn<String> plantId = GeneratedColumn<String>(
    'plant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseIntervalDaysMeta = const VerificationMeta(
    'baseIntervalDays',
  );
  @override
  late final GeneratedColumn<double> baseIntervalDays = GeneratedColumn<double>(
    'base_interval_days',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentIntervalDaysMeta =
      const VerificationMeta('currentIntervalDays');
  @override
  late final GeneratedColumn<double> currentIntervalDays =
      GeneratedColumn<double>(
        'current_interval_days',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _lastDoneAtMeta = const VerificationMeta(
    'lastDoneAt',
  );
  @override
  late final GeneratedColumn<int> lastDoneAt = GeneratedColumn<int>(
    'last_done_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextDueAtMeta = const VerificationMeta(
    'nextDueAt',
  );
  @override
  late final GeneratedColumn<int> nextDueAt = GeneratedColumn<int>(
    'next_due_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snoozeCountMeta = const VerificationMeta(
    'snoozeCount',
  );
  @override
  late final GeneratedColumn<int> snoozeCount = GeneratedColumn<int>(
    'snooze_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _recentEventsJsonMeta = const VerificationMeta(
    'recentEventsJson',
  );
  @override
  late final GeneratedColumn<String> recentEventsJson = GeneratedColumn<String>(
    'recent_events_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _recurrenceModeMeta = const VerificationMeta(
    'recurrenceMode',
  );
  @override
  late final GeneratedColumn<String> recurrenceMode = GeneratedColumn<String>(
    'recurrence_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('after_completion'),
  );
  static const VerificationMeta _notificationsMutedMeta =
      const VerificationMeta('notificationsMuted');
  @override
  late final GeneratedColumn<bool> notificationsMuted = GeneratedColumn<bool>(
    'notifications_muted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("notifications_muted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedHlcMeta = const VerificationMeta(
    'updatedHlc',
  );
  @override
  late final GeneratedColumn<String> updatedHlc = GeneratedColumn<String>(
    'updated_hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    plantId,
    type,
    baseIntervalDays,
    currentIntervalDays,
    lastDoneAt,
    nextDueAt,
    snoozeCount,
    recentEventsJson,
    enabled,
    recurrenceMode,
    notificationsMuted,
    updatedHlc,
    deletedAt,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'care_schedules';
  @override
  VerificationContext validateIntegrity(
    Insertable<CareScheduleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('plant_id')) {
      context.handle(
        _plantIdMeta,
        plantId.isAcceptableOrUnknown(data['plant_id']!, _plantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_plantIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('base_interval_days')) {
      context.handle(
        _baseIntervalDaysMeta,
        baseIntervalDays.isAcceptableOrUnknown(
          data['base_interval_days']!,
          _baseIntervalDaysMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_baseIntervalDaysMeta);
    }
    if (data.containsKey('current_interval_days')) {
      context.handle(
        _currentIntervalDaysMeta,
        currentIntervalDays.isAcceptableOrUnknown(
          data['current_interval_days']!,
          _currentIntervalDaysMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currentIntervalDaysMeta);
    }
    if (data.containsKey('last_done_at')) {
      context.handle(
        _lastDoneAtMeta,
        lastDoneAt.isAcceptableOrUnknown(
          data['last_done_at']!,
          _lastDoneAtMeta,
        ),
      );
    }
    if (data.containsKey('next_due_at')) {
      context.handle(
        _nextDueAtMeta,
        nextDueAt.isAcceptableOrUnknown(data['next_due_at']!, _nextDueAtMeta),
      );
    }
    if (data.containsKey('snooze_count')) {
      context.handle(
        _snoozeCountMeta,
        snoozeCount.isAcceptableOrUnknown(
          data['snooze_count']!,
          _snoozeCountMeta,
        ),
      );
    }
    if (data.containsKey('recent_events_json')) {
      context.handle(
        _recentEventsJsonMeta,
        recentEventsJson.isAcceptableOrUnknown(
          data['recent_events_json']!,
          _recentEventsJsonMeta,
        ),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('recurrence_mode')) {
      context.handle(
        _recurrenceModeMeta,
        recurrenceMode.isAcceptableOrUnknown(
          data['recurrence_mode']!,
          _recurrenceModeMeta,
        ),
      );
    }
    if (data.containsKey('notifications_muted')) {
      context.handle(
        _notificationsMutedMeta,
        notificationsMuted.isAcceptableOrUnknown(
          data['notifications_muted']!,
          _notificationsMutedMeta,
        ),
      );
    }
    if (data.containsKey('updated_hlc')) {
      context.handle(
        _updatedHlcMeta,
        updatedHlc.isAcceptableOrUnknown(data['updated_hlc']!, _updatedHlcMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedHlcMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CareScheduleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CareScheduleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      plantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plant_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      baseIntervalDays: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}base_interval_days'],
      )!,
      currentIntervalDays: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}current_interval_days'],
      )!,
      lastDoneAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_done_at'],
      ),
      nextDueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_due_at'],
      ),
      snoozeCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}snooze_count'],
      )!,
      recentEventsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recent_events_json'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      recurrenceMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_mode'],
      )!,
      notificationsMuted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notifications_muted'],
      )!,
      updatedHlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_hlc'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  $CareSchedulesTable createAlias(String alias) {
    return $CareSchedulesTable(attachedDatabase, alias);
  }
}

class CareScheduleRow extends DataClass implements Insertable<CareScheduleRow> {
  final String id;
  final String tenantId;
  final String plantId;
  final String type;
  final double baseIntervalDays;
  final double currentIntervalDays;
  final int? lastDoneAt;
  final int? nextDueAt;
  final int snoozeCount;
  final String recentEventsJson;
  final bool enabled;

  /// How the schedule advances after a care event:
  ///   'after_completion' — `next_due_at = doneAt + currentIntervalDays`
  ///   'fixed'            — `next_due_at = anchor + N × interval` for
  ///                        smallest N making next_due_at > doneAt
  ///   'once'             — disable the schedule after the first event
  final String recurrenceMode;

  /// Suppresses OS notifications for just this schedule (e.g. mute the
  /// weekly fertilize reminder but keep the daily mist reminder firing).
  /// The schedule still shows up on Home / Calendar / Upcoming Care.
  final bool notificationsMuted;
  final String updatedHlc;
  final int? deletedAt;
  final String deviceId;
  const CareScheduleRow({
    required this.id,
    required this.tenantId,
    required this.plantId,
    required this.type,
    required this.baseIntervalDays,
    required this.currentIntervalDays,
    this.lastDoneAt,
    this.nextDueAt,
    required this.snoozeCount,
    required this.recentEventsJson,
    required this.enabled,
    required this.recurrenceMode,
    required this.notificationsMuted,
    required this.updatedHlc,
    this.deletedAt,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['plant_id'] = Variable<String>(plantId);
    map['type'] = Variable<String>(type);
    map['base_interval_days'] = Variable<double>(baseIntervalDays);
    map['current_interval_days'] = Variable<double>(currentIntervalDays);
    if (!nullToAbsent || lastDoneAt != null) {
      map['last_done_at'] = Variable<int>(lastDoneAt);
    }
    if (!nullToAbsent || nextDueAt != null) {
      map['next_due_at'] = Variable<int>(nextDueAt);
    }
    map['snooze_count'] = Variable<int>(snoozeCount);
    map['recent_events_json'] = Variable<String>(recentEventsJson);
    map['enabled'] = Variable<bool>(enabled);
    map['recurrence_mode'] = Variable<String>(recurrenceMode);
    map['notifications_muted'] = Variable<bool>(notificationsMuted);
    map['updated_hlc'] = Variable<String>(updatedHlc);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  CareSchedulesCompanion toCompanion(bool nullToAbsent) {
    return CareSchedulesCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      plantId: Value(plantId),
      type: Value(type),
      baseIntervalDays: Value(baseIntervalDays),
      currentIntervalDays: Value(currentIntervalDays),
      lastDoneAt: lastDoneAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastDoneAt),
      nextDueAt: nextDueAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextDueAt),
      snoozeCount: Value(snoozeCount),
      recentEventsJson: Value(recentEventsJson),
      enabled: Value(enabled),
      recurrenceMode: Value(recurrenceMode),
      notificationsMuted: Value(notificationsMuted),
      updatedHlc: Value(updatedHlc),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
    );
  }

  factory CareScheduleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CareScheduleRow(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      plantId: serializer.fromJson<String>(json['plantId']),
      type: serializer.fromJson<String>(json['type']),
      baseIntervalDays: serializer.fromJson<double>(json['baseIntervalDays']),
      currentIntervalDays: serializer.fromJson<double>(
        json['currentIntervalDays'],
      ),
      lastDoneAt: serializer.fromJson<int?>(json['lastDoneAt']),
      nextDueAt: serializer.fromJson<int?>(json['nextDueAt']),
      snoozeCount: serializer.fromJson<int>(json['snoozeCount']),
      recentEventsJson: serializer.fromJson<String>(json['recentEventsJson']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      recurrenceMode: serializer.fromJson<String>(json['recurrenceMode']),
      notificationsMuted: serializer.fromJson<bool>(json['notificationsMuted']),
      updatedHlc: serializer.fromJson<String>(json['updatedHlc']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'plantId': serializer.toJson<String>(plantId),
      'type': serializer.toJson<String>(type),
      'baseIntervalDays': serializer.toJson<double>(baseIntervalDays),
      'currentIntervalDays': serializer.toJson<double>(currentIntervalDays),
      'lastDoneAt': serializer.toJson<int?>(lastDoneAt),
      'nextDueAt': serializer.toJson<int?>(nextDueAt),
      'snoozeCount': serializer.toJson<int>(snoozeCount),
      'recentEventsJson': serializer.toJson<String>(recentEventsJson),
      'enabled': serializer.toJson<bool>(enabled),
      'recurrenceMode': serializer.toJson<String>(recurrenceMode),
      'notificationsMuted': serializer.toJson<bool>(notificationsMuted),
      'updatedHlc': serializer.toJson<String>(updatedHlc),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
    };
  }

  CareScheduleRow copyWith({
    String? id,
    String? tenantId,
    String? plantId,
    String? type,
    double? baseIntervalDays,
    double? currentIntervalDays,
    Value<int?> lastDoneAt = const Value.absent(),
    Value<int?> nextDueAt = const Value.absent(),
    int? snoozeCount,
    String? recentEventsJson,
    bool? enabled,
    String? recurrenceMode,
    bool? notificationsMuted,
    String? updatedHlc,
    Value<int?> deletedAt = const Value.absent(),
    String? deviceId,
  }) => CareScheduleRow(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    plantId: plantId ?? this.plantId,
    type: type ?? this.type,
    baseIntervalDays: baseIntervalDays ?? this.baseIntervalDays,
    currentIntervalDays: currentIntervalDays ?? this.currentIntervalDays,
    lastDoneAt: lastDoneAt.present ? lastDoneAt.value : this.lastDoneAt,
    nextDueAt: nextDueAt.present ? nextDueAt.value : this.nextDueAt,
    snoozeCount: snoozeCount ?? this.snoozeCount,
    recentEventsJson: recentEventsJson ?? this.recentEventsJson,
    enabled: enabled ?? this.enabled,
    recurrenceMode: recurrenceMode ?? this.recurrenceMode,
    notificationsMuted: notificationsMuted ?? this.notificationsMuted,
    updatedHlc: updatedHlc ?? this.updatedHlc,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
  );
  CareScheduleRow copyWithCompanion(CareSchedulesCompanion data) {
    return CareScheduleRow(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      plantId: data.plantId.present ? data.plantId.value : this.plantId,
      type: data.type.present ? data.type.value : this.type,
      baseIntervalDays: data.baseIntervalDays.present
          ? data.baseIntervalDays.value
          : this.baseIntervalDays,
      currentIntervalDays: data.currentIntervalDays.present
          ? data.currentIntervalDays.value
          : this.currentIntervalDays,
      lastDoneAt: data.lastDoneAt.present
          ? data.lastDoneAt.value
          : this.lastDoneAt,
      nextDueAt: data.nextDueAt.present ? data.nextDueAt.value : this.nextDueAt,
      snoozeCount: data.snoozeCount.present
          ? data.snoozeCount.value
          : this.snoozeCount,
      recentEventsJson: data.recentEventsJson.present
          ? data.recentEventsJson.value
          : this.recentEventsJson,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      recurrenceMode: data.recurrenceMode.present
          ? data.recurrenceMode.value
          : this.recurrenceMode,
      notificationsMuted: data.notificationsMuted.present
          ? data.notificationsMuted.value
          : this.notificationsMuted,
      updatedHlc: data.updatedHlc.present
          ? data.updatedHlc.value
          : this.updatedHlc,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CareScheduleRow(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('plantId: $plantId, ')
          ..write('type: $type, ')
          ..write('baseIntervalDays: $baseIntervalDays, ')
          ..write('currentIntervalDays: $currentIntervalDays, ')
          ..write('lastDoneAt: $lastDoneAt, ')
          ..write('nextDueAt: $nextDueAt, ')
          ..write('snoozeCount: $snoozeCount, ')
          ..write('recentEventsJson: $recentEventsJson, ')
          ..write('enabled: $enabled, ')
          ..write('recurrenceMode: $recurrenceMode, ')
          ..write('notificationsMuted: $notificationsMuted, ')
          ..write('updatedHlc: $updatedHlc, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    plantId,
    type,
    baseIntervalDays,
    currentIntervalDays,
    lastDoneAt,
    nextDueAt,
    snoozeCount,
    recentEventsJson,
    enabled,
    recurrenceMode,
    notificationsMuted,
    updatedHlc,
    deletedAt,
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CareScheduleRow &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.plantId == this.plantId &&
          other.type == this.type &&
          other.baseIntervalDays == this.baseIntervalDays &&
          other.currentIntervalDays == this.currentIntervalDays &&
          other.lastDoneAt == this.lastDoneAt &&
          other.nextDueAt == this.nextDueAt &&
          other.snoozeCount == this.snoozeCount &&
          other.recentEventsJson == this.recentEventsJson &&
          other.enabled == this.enabled &&
          other.recurrenceMode == this.recurrenceMode &&
          other.notificationsMuted == this.notificationsMuted &&
          other.updatedHlc == this.updatedHlc &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId);
}

class CareSchedulesCompanion extends UpdateCompanion<CareScheduleRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> plantId;
  final Value<String> type;
  final Value<double> baseIntervalDays;
  final Value<double> currentIntervalDays;
  final Value<int?> lastDoneAt;
  final Value<int?> nextDueAt;
  final Value<int> snoozeCount;
  final Value<String> recentEventsJson;
  final Value<bool> enabled;
  final Value<String> recurrenceMode;
  final Value<bool> notificationsMuted;
  final Value<String> updatedHlc;
  final Value<int?> deletedAt;
  final Value<String> deviceId;
  final Value<int> rowid;
  const CareSchedulesCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.plantId = const Value.absent(),
    this.type = const Value.absent(),
    this.baseIntervalDays = const Value.absent(),
    this.currentIntervalDays = const Value.absent(),
    this.lastDoneAt = const Value.absent(),
    this.nextDueAt = const Value.absent(),
    this.snoozeCount = const Value.absent(),
    this.recentEventsJson = const Value.absent(),
    this.enabled = const Value.absent(),
    this.recurrenceMode = const Value.absent(),
    this.notificationsMuted = const Value.absent(),
    this.updatedHlc = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CareSchedulesCompanion.insert({
    required String id,
    required String tenantId,
    required String plantId,
    required String type,
    required double baseIntervalDays,
    required double currentIntervalDays,
    this.lastDoneAt = const Value.absent(),
    this.nextDueAt = const Value.absent(),
    this.snoozeCount = const Value.absent(),
    this.recentEventsJson = const Value.absent(),
    this.enabled = const Value.absent(),
    this.recurrenceMode = const Value.absent(),
    this.notificationsMuted = const Value.absent(),
    required String updatedHlc,
    this.deletedAt = const Value.absent(),
    required String deviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       plantId = Value(plantId),
       type = Value(type),
       baseIntervalDays = Value(baseIntervalDays),
       currentIntervalDays = Value(currentIntervalDays),
       updatedHlc = Value(updatedHlc),
       deviceId = Value(deviceId);
  static Insertable<CareScheduleRow> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? plantId,
    Expression<String>? type,
    Expression<double>? baseIntervalDays,
    Expression<double>? currentIntervalDays,
    Expression<int>? lastDoneAt,
    Expression<int>? nextDueAt,
    Expression<int>? snoozeCount,
    Expression<String>? recentEventsJson,
    Expression<bool>? enabled,
    Expression<String>? recurrenceMode,
    Expression<bool>? notificationsMuted,
    Expression<String>? updatedHlc,
    Expression<int>? deletedAt,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (plantId != null) 'plant_id': plantId,
      if (type != null) 'type': type,
      if (baseIntervalDays != null) 'base_interval_days': baseIntervalDays,
      if (currentIntervalDays != null)
        'current_interval_days': currentIntervalDays,
      if (lastDoneAt != null) 'last_done_at': lastDoneAt,
      if (nextDueAt != null) 'next_due_at': nextDueAt,
      if (snoozeCount != null) 'snooze_count': snoozeCount,
      if (recentEventsJson != null) 'recent_events_json': recentEventsJson,
      if (enabled != null) 'enabled': enabled,
      if (recurrenceMode != null) 'recurrence_mode': recurrenceMode,
      if (notificationsMuted != null) 'notifications_muted': notificationsMuted,
      if (updatedHlc != null) 'updated_hlc': updatedHlc,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CareSchedulesCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? plantId,
    Value<String>? type,
    Value<double>? baseIntervalDays,
    Value<double>? currentIntervalDays,
    Value<int?>? lastDoneAt,
    Value<int?>? nextDueAt,
    Value<int>? snoozeCount,
    Value<String>? recentEventsJson,
    Value<bool>? enabled,
    Value<String>? recurrenceMode,
    Value<bool>? notificationsMuted,
    Value<String>? updatedHlc,
    Value<int?>? deletedAt,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return CareSchedulesCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      plantId: plantId ?? this.plantId,
      type: type ?? this.type,
      baseIntervalDays: baseIntervalDays ?? this.baseIntervalDays,
      currentIntervalDays: currentIntervalDays ?? this.currentIntervalDays,
      lastDoneAt: lastDoneAt ?? this.lastDoneAt,
      nextDueAt: nextDueAt ?? this.nextDueAt,
      snoozeCount: snoozeCount ?? this.snoozeCount,
      recentEventsJson: recentEventsJson ?? this.recentEventsJson,
      enabled: enabled ?? this.enabled,
      recurrenceMode: recurrenceMode ?? this.recurrenceMode,
      notificationsMuted: notificationsMuted ?? this.notificationsMuted,
      updatedHlc: updatedHlc ?? this.updatedHlc,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (plantId.present) {
      map['plant_id'] = Variable<String>(plantId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (baseIntervalDays.present) {
      map['base_interval_days'] = Variable<double>(baseIntervalDays.value);
    }
    if (currentIntervalDays.present) {
      map['current_interval_days'] = Variable<double>(
        currentIntervalDays.value,
      );
    }
    if (lastDoneAt.present) {
      map['last_done_at'] = Variable<int>(lastDoneAt.value);
    }
    if (nextDueAt.present) {
      map['next_due_at'] = Variable<int>(nextDueAt.value);
    }
    if (snoozeCount.present) {
      map['snooze_count'] = Variable<int>(snoozeCount.value);
    }
    if (recentEventsJson.present) {
      map['recent_events_json'] = Variable<String>(recentEventsJson.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (recurrenceMode.present) {
      map['recurrence_mode'] = Variable<String>(recurrenceMode.value);
    }
    if (notificationsMuted.present) {
      map['notifications_muted'] = Variable<bool>(notificationsMuted.value);
    }
    if (updatedHlc.present) {
      map['updated_hlc'] = Variable<String>(updatedHlc.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CareSchedulesCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('plantId: $plantId, ')
          ..write('type: $type, ')
          ..write('baseIntervalDays: $baseIntervalDays, ')
          ..write('currentIntervalDays: $currentIntervalDays, ')
          ..write('lastDoneAt: $lastDoneAt, ')
          ..write('nextDueAt: $nextDueAt, ')
          ..write('snoozeCount: $snoozeCount, ')
          ..write('recentEventsJson: $recentEventsJson, ')
          ..write('enabled: $enabled, ')
          ..write('recurrenceMode: $recurrenceMode, ')
          ..write('notificationsMuted: $notificationsMuted, ')
          ..write('updatedHlc: $updatedHlc, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InventoryTransactionsTable extends InventoryTransactions
    with TableInfo<$InventoryTransactionsTable, InventoryTransactionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InventoryTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentPlantIdMeta = const VerificationMeta(
    'parentPlantId',
  );
  @override
  late final GeneratedColumn<String> parentPlantId = GeneratedColumn<String>(
    'parent_plant_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _childPlantIdMeta = const VerificationMeta(
    'childPlantId',
  );
  @override
  late final GeneratedColumn<String> childPlantId = GeneratedColumn<String>(
    'child_plant_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plantIdMeta = const VerificationMeta(
    'plantId',
  );
  @override
  late final GeneratedColumn<String> plantId = GeneratedColumn<String>(
    'plant_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _counterpartyMeta = const VerificationMeta(
    'counterparty',
  );
  @override
  late final GeneratedColumn<String> counterparty = GeneratedColumn<String>(
    'counterparty',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<int> at = GeneratedColumn<int>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedHlcMeta = const VerificationMeta(
    'updatedHlc',
  );
  @override
  late final GeneratedColumn<String> updatedHlc = GeneratedColumn<String>(
    'updated_hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    type,
    parentPlantId,
    childPlantId,
    plantId,
    counterparty,
    at,
    notes,
    amountMinor,
    currency,
    updatedHlc,
    deletedAt,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inventory_transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<InventoryTransactionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('parent_plant_id')) {
      context.handle(
        _parentPlantIdMeta,
        parentPlantId.isAcceptableOrUnknown(
          data['parent_plant_id']!,
          _parentPlantIdMeta,
        ),
      );
    }
    if (data.containsKey('child_plant_id')) {
      context.handle(
        _childPlantIdMeta,
        childPlantId.isAcceptableOrUnknown(
          data['child_plant_id']!,
          _childPlantIdMeta,
        ),
      );
    }
    if (data.containsKey('plant_id')) {
      context.handle(
        _plantIdMeta,
        plantId.isAcceptableOrUnknown(data['plant_id']!, _plantIdMeta),
      );
    }
    if (data.containsKey('counterparty')) {
      context.handle(
        _counterpartyMeta,
        counterparty.isAcceptableOrUnknown(
          data['counterparty']!,
          _counterpartyMeta,
        ),
      );
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('updated_hlc')) {
      context.handle(
        _updatedHlcMeta,
        updatedHlc.isAcceptableOrUnknown(data['updated_hlc']!, _updatedHlcMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedHlcMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InventoryTransactionRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InventoryTransactionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      parentPlantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_plant_id'],
      ),
      childPlantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}child_plant_id'],
      ),
      plantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plant_id'],
      ),
      counterparty: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}counterparty'],
      ),
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      ),
      updatedHlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_hlc'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
    );
  }

  @override
  $InventoryTransactionsTable createAlias(String alias) {
    return $InventoryTransactionsTable(attachedDatabase, alias);
  }
}

class InventoryTransactionRow extends DataClass
    implements Insertable<InventoryTransactionRow> {
  final String id;
  final String tenantId;
  final String type;
  final String? parentPlantId;
  final String? childPlantId;
  final String? plantId;
  final String? counterparty;
  final int at;
  final String? notes;
  final int? amountMinor;
  final String? currency;
  final String updatedHlc;
  final int? deletedAt;
  final String deviceId;
  const InventoryTransactionRow({
    required this.id,
    required this.tenantId,
    required this.type,
    this.parentPlantId,
    this.childPlantId,
    this.plantId,
    this.counterparty,
    required this.at,
    this.notes,
    this.amountMinor,
    this.currency,
    required this.updatedHlc,
    this.deletedAt,
    required this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || parentPlantId != null) {
      map['parent_plant_id'] = Variable<String>(parentPlantId);
    }
    if (!nullToAbsent || childPlantId != null) {
      map['child_plant_id'] = Variable<String>(childPlantId);
    }
    if (!nullToAbsent || plantId != null) {
      map['plant_id'] = Variable<String>(plantId);
    }
    if (!nullToAbsent || counterparty != null) {
      map['counterparty'] = Variable<String>(counterparty);
    }
    map['at'] = Variable<int>(at);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || amountMinor != null) {
      map['amount_minor'] = Variable<int>(amountMinor);
    }
    if (!nullToAbsent || currency != null) {
      map['currency'] = Variable<String>(currency);
    }
    map['updated_hlc'] = Variable<String>(updatedHlc);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    return map;
  }

  InventoryTransactionsCompanion toCompanion(bool nullToAbsent) {
    return InventoryTransactionsCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      type: Value(type),
      parentPlantId: parentPlantId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentPlantId),
      childPlantId: childPlantId == null && nullToAbsent
          ? const Value.absent()
          : Value(childPlantId),
      plantId: plantId == null && nullToAbsent
          ? const Value.absent()
          : Value(plantId),
      counterparty: counterparty == null && nullToAbsent
          ? const Value.absent()
          : Value(counterparty),
      at: Value(at),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      amountMinor: amountMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(amountMinor),
      currency: currency == null && nullToAbsent
          ? const Value.absent()
          : Value(currency),
      updatedHlc: Value(updatedHlc),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
    );
  }

  factory InventoryTransactionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InventoryTransactionRow(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      type: serializer.fromJson<String>(json['type']),
      parentPlantId: serializer.fromJson<String?>(json['parentPlantId']),
      childPlantId: serializer.fromJson<String?>(json['childPlantId']),
      plantId: serializer.fromJson<String?>(json['plantId']),
      counterparty: serializer.fromJson<String?>(json['counterparty']),
      at: serializer.fromJson<int>(json['at']),
      notes: serializer.fromJson<String?>(json['notes']),
      amountMinor: serializer.fromJson<int?>(json['amountMinor']),
      currency: serializer.fromJson<String?>(json['currency']),
      updatedHlc: serializer.fromJson<String>(json['updatedHlc']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'type': serializer.toJson<String>(type),
      'parentPlantId': serializer.toJson<String?>(parentPlantId),
      'childPlantId': serializer.toJson<String?>(childPlantId),
      'plantId': serializer.toJson<String?>(plantId),
      'counterparty': serializer.toJson<String?>(counterparty),
      'at': serializer.toJson<int>(at),
      'notes': serializer.toJson<String?>(notes),
      'amountMinor': serializer.toJson<int?>(amountMinor),
      'currency': serializer.toJson<String?>(currency),
      'updatedHlc': serializer.toJson<String>(updatedHlc),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
    };
  }

  InventoryTransactionRow copyWith({
    String? id,
    String? tenantId,
    String? type,
    Value<String?> parentPlantId = const Value.absent(),
    Value<String?> childPlantId = const Value.absent(),
    Value<String?> plantId = const Value.absent(),
    Value<String?> counterparty = const Value.absent(),
    int? at,
    Value<String?> notes = const Value.absent(),
    Value<int?> amountMinor = const Value.absent(),
    Value<String?> currency = const Value.absent(),
    String? updatedHlc,
    Value<int?> deletedAt = const Value.absent(),
    String? deviceId,
  }) => InventoryTransactionRow(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    type: type ?? this.type,
    parentPlantId: parentPlantId.present
        ? parentPlantId.value
        : this.parentPlantId,
    childPlantId: childPlantId.present ? childPlantId.value : this.childPlantId,
    plantId: plantId.present ? plantId.value : this.plantId,
    counterparty: counterparty.present ? counterparty.value : this.counterparty,
    at: at ?? this.at,
    notes: notes.present ? notes.value : this.notes,
    amountMinor: amountMinor.present ? amountMinor.value : this.amountMinor,
    currency: currency.present ? currency.value : this.currency,
    updatedHlc: updatedHlc ?? this.updatedHlc,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
  );
  InventoryTransactionRow copyWithCompanion(
    InventoryTransactionsCompanion data,
  ) {
    return InventoryTransactionRow(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      type: data.type.present ? data.type.value : this.type,
      parentPlantId: data.parentPlantId.present
          ? data.parentPlantId.value
          : this.parentPlantId,
      childPlantId: data.childPlantId.present
          ? data.childPlantId.value
          : this.childPlantId,
      plantId: data.plantId.present ? data.plantId.value : this.plantId,
      counterparty: data.counterparty.present
          ? data.counterparty.value
          : this.counterparty,
      at: data.at.present ? data.at.value : this.at,
      notes: data.notes.present ? data.notes.value : this.notes,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      updatedHlc: data.updatedHlc.present
          ? data.updatedHlc.value
          : this.updatedHlc,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InventoryTransactionRow(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('type: $type, ')
          ..write('parentPlantId: $parentPlantId, ')
          ..write('childPlantId: $childPlantId, ')
          ..write('plantId: $plantId, ')
          ..write('counterparty: $counterparty, ')
          ..write('at: $at, ')
          ..write('notes: $notes, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('updatedHlc: $updatedHlc, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    type,
    parentPlantId,
    childPlantId,
    plantId,
    counterparty,
    at,
    notes,
    amountMinor,
    currency,
    updatedHlc,
    deletedAt,
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InventoryTransactionRow &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.type == this.type &&
          other.parentPlantId == this.parentPlantId &&
          other.childPlantId == this.childPlantId &&
          other.plantId == this.plantId &&
          other.counterparty == this.counterparty &&
          other.at == this.at &&
          other.notes == this.notes &&
          other.amountMinor == this.amountMinor &&
          other.currency == this.currency &&
          other.updatedHlc == this.updatedHlc &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId);
}

class InventoryTransactionsCompanion
    extends UpdateCompanion<InventoryTransactionRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> type;
  final Value<String?> parentPlantId;
  final Value<String?> childPlantId;
  final Value<String?> plantId;
  final Value<String?> counterparty;
  final Value<int> at;
  final Value<String?> notes;
  final Value<int?> amountMinor;
  final Value<String?> currency;
  final Value<String> updatedHlc;
  final Value<int?> deletedAt;
  final Value<String> deviceId;
  final Value<int> rowid;
  const InventoryTransactionsCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.type = const Value.absent(),
    this.parentPlantId = const Value.absent(),
    this.childPlantId = const Value.absent(),
    this.plantId = const Value.absent(),
    this.counterparty = const Value.absent(),
    this.at = const Value.absent(),
    this.notes = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.updatedHlc = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InventoryTransactionsCompanion.insert({
    required String id,
    required String tenantId,
    required String type,
    this.parentPlantId = const Value.absent(),
    this.childPlantId = const Value.absent(),
    this.plantId = const Value.absent(),
    this.counterparty = const Value.absent(),
    required int at,
    this.notes = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.currency = const Value.absent(),
    required String updatedHlc,
    this.deletedAt = const Value.absent(),
    required String deviceId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       type = Value(type),
       at = Value(at),
       updatedHlc = Value(updatedHlc),
       deviceId = Value(deviceId);
  static Insertable<InventoryTransactionRow> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? type,
    Expression<String>? parentPlantId,
    Expression<String>? childPlantId,
    Expression<String>? plantId,
    Expression<String>? counterparty,
    Expression<int>? at,
    Expression<String>? notes,
    Expression<int>? amountMinor,
    Expression<String>? currency,
    Expression<String>? updatedHlc,
    Expression<int>? deletedAt,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (type != null) 'type': type,
      if (parentPlantId != null) 'parent_plant_id': parentPlantId,
      if (childPlantId != null) 'child_plant_id': childPlantId,
      if (plantId != null) 'plant_id': plantId,
      if (counterparty != null) 'counterparty': counterparty,
      if (at != null) 'at': at,
      if (notes != null) 'notes': notes,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (currency != null) 'currency': currency,
      if (updatedHlc != null) 'updated_hlc': updatedHlc,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InventoryTransactionsCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? type,
    Value<String?>? parentPlantId,
    Value<String?>? childPlantId,
    Value<String?>? plantId,
    Value<String?>? counterparty,
    Value<int>? at,
    Value<String?>? notes,
    Value<int?>? amountMinor,
    Value<String?>? currency,
    Value<String>? updatedHlc,
    Value<int?>? deletedAt,
    Value<String>? deviceId,
    Value<int>? rowid,
  }) {
    return InventoryTransactionsCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      type: type ?? this.type,
      parentPlantId: parentPlantId ?? this.parentPlantId,
      childPlantId: childPlantId ?? this.childPlantId,
      plantId: plantId ?? this.plantId,
      counterparty: counterparty ?? this.counterparty,
      at: at ?? this.at,
      notes: notes ?? this.notes,
      amountMinor: amountMinor ?? this.amountMinor,
      currency: currency ?? this.currency,
      updatedHlc: updatedHlc ?? this.updatedHlc,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (parentPlantId.present) {
      map['parent_plant_id'] = Variable<String>(parentPlantId.value);
    }
    if (childPlantId.present) {
      map['child_plant_id'] = Variable<String>(childPlantId.value);
    }
    if (plantId.present) {
      map['plant_id'] = Variable<String>(plantId.value);
    }
    if (counterparty.present) {
      map['counterparty'] = Variable<String>(counterparty.value);
    }
    if (at.present) {
      map['at'] = Variable<int>(at.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (updatedHlc.present) {
      map['updated_hlc'] = Variable<String>(updatedHlc.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InventoryTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('type: $type, ')
          ..write('parentPlantId: $parentPlantId, ')
          ..write('childPlantId: $childPlantId, ')
          ..write('plantId: $plantId, ')
          ..write('counterparty: $counterparty, ')
          ..write('at: $at, ')
          ..write('notes: $notes, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('updatedHlc: $updatedHlc, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOpsTable extends SyncOps with TableInfo<$SyncOpsTable, SyncOpRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOpsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldMeta = const VerificationMeta('field');
  @override
  late final GeneratedColumn<String> field = GeneratedColumn<String>(
    'field',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueJsonMeta = const VerificationMeta(
    'valueJson',
  );
  @override
  late final GeneratedColumn<String> valueJson = GeneratedColumn<String>(
    'value_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pushedAtMeta = const VerificationMeta(
    'pushedAt',
  );
  @override
  late final GeneratedColumn<int> pushedAt = GeneratedColumn<int>(
    'pushed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    seq,
    tenantId,
    entity,
    entityId,
    field,
    valueJson,
    hlc,
    deviceId,
    pushedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_ops';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncOpRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('field')) {
      context.handle(
        _fieldMeta,
        field.isAcceptableOrUnknown(data['field']!, _fieldMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldMeta);
    }
    if (data.containsKey('value_json')) {
      context.handle(
        _valueJsonMeta,
        valueJson.isAcceptableOrUnknown(data['value_json']!, _valueJsonMeta),
      );
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    } else if (isInserting) {
      context.missing(_hlcMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('pushed_at')) {
      context.handle(
        _pushedAtMeta,
        pushedAt.isAcceptableOrUnknown(data['pushed_at']!, _pushedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  SyncOpRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOpRow(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      field: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field'],
      )!,
      valueJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_json'],
      ),
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      pushedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pushed_at'],
      ),
    );
  }

  @override
  $SyncOpsTable createAlias(String alias) {
    return $SyncOpsTable(attachedDatabase, alias);
  }
}

class SyncOpRow extends DataClass implements Insertable<SyncOpRow> {
  final int seq;
  final String tenantId;
  final String entity;
  final String entityId;
  final String field;
  final String? valueJson;
  final String hlc;
  final String deviceId;
  final int? pushedAt;
  const SyncOpRow({
    required this.seq,
    required this.tenantId,
    required this.entity,
    required this.entityId,
    required this.field,
    this.valueJson,
    required this.hlc,
    required this.deviceId,
    this.pushedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['tenant_id'] = Variable<String>(tenantId);
    map['entity'] = Variable<String>(entity);
    map['entity_id'] = Variable<String>(entityId);
    map['field'] = Variable<String>(field);
    if (!nullToAbsent || valueJson != null) {
      map['value_json'] = Variable<String>(valueJson);
    }
    map['hlc'] = Variable<String>(hlc);
    map['device_id'] = Variable<String>(deviceId);
    if (!nullToAbsent || pushedAt != null) {
      map['pushed_at'] = Variable<int>(pushedAt);
    }
    return map;
  }

  SyncOpsCompanion toCompanion(bool nullToAbsent) {
    return SyncOpsCompanion(
      seq: Value(seq),
      tenantId: Value(tenantId),
      entity: Value(entity),
      entityId: Value(entityId),
      field: Value(field),
      valueJson: valueJson == null && nullToAbsent
          ? const Value.absent()
          : Value(valueJson),
      hlc: Value(hlc),
      deviceId: Value(deviceId),
      pushedAt: pushedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(pushedAt),
    );
  }

  factory SyncOpRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOpRow(
      seq: serializer.fromJson<int>(json['seq']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      entity: serializer.fromJson<String>(json['entity']),
      entityId: serializer.fromJson<String>(json['entityId']),
      field: serializer.fromJson<String>(json['field']),
      valueJson: serializer.fromJson<String?>(json['valueJson']),
      hlc: serializer.fromJson<String>(json['hlc']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      pushedAt: serializer.fromJson<int?>(json['pushedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'tenantId': serializer.toJson<String>(tenantId),
      'entity': serializer.toJson<String>(entity),
      'entityId': serializer.toJson<String>(entityId),
      'field': serializer.toJson<String>(field),
      'valueJson': serializer.toJson<String?>(valueJson),
      'hlc': serializer.toJson<String>(hlc),
      'deviceId': serializer.toJson<String>(deviceId),
      'pushedAt': serializer.toJson<int?>(pushedAt),
    };
  }

  SyncOpRow copyWith({
    int? seq,
    String? tenantId,
    String? entity,
    String? entityId,
    String? field,
    Value<String?> valueJson = const Value.absent(),
    String? hlc,
    String? deviceId,
    Value<int?> pushedAt = const Value.absent(),
  }) => SyncOpRow(
    seq: seq ?? this.seq,
    tenantId: tenantId ?? this.tenantId,
    entity: entity ?? this.entity,
    entityId: entityId ?? this.entityId,
    field: field ?? this.field,
    valueJson: valueJson.present ? valueJson.value : this.valueJson,
    hlc: hlc ?? this.hlc,
    deviceId: deviceId ?? this.deviceId,
    pushedAt: pushedAt.present ? pushedAt.value : this.pushedAt,
  );
  SyncOpRow copyWithCompanion(SyncOpsCompanion data) {
    return SyncOpRow(
      seq: data.seq.present ? data.seq.value : this.seq,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      entity: data.entity.present ? data.entity.value : this.entity,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      field: data.field.present ? data.field.value : this.field,
      valueJson: data.valueJson.present ? data.valueJson.value : this.valueJson,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      pushedAt: data.pushedAt.present ? data.pushedAt.value : this.pushedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOpRow(')
          ..write('seq: $seq, ')
          ..write('tenantId: $tenantId, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('field: $field, ')
          ..write('valueJson: $valueJson, ')
          ..write('hlc: $hlc, ')
          ..write('deviceId: $deviceId, ')
          ..write('pushedAt: $pushedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    seq,
    tenantId,
    entity,
    entityId,
    field,
    valueJson,
    hlc,
    deviceId,
    pushedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOpRow &&
          other.seq == this.seq &&
          other.tenantId == this.tenantId &&
          other.entity == this.entity &&
          other.entityId == this.entityId &&
          other.field == this.field &&
          other.valueJson == this.valueJson &&
          other.hlc == this.hlc &&
          other.deviceId == this.deviceId &&
          other.pushedAt == this.pushedAt);
}

class SyncOpsCompanion extends UpdateCompanion<SyncOpRow> {
  final Value<int> seq;
  final Value<String> tenantId;
  final Value<String> entity;
  final Value<String> entityId;
  final Value<String> field;
  final Value<String?> valueJson;
  final Value<String> hlc;
  final Value<String> deviceId;
  final Value<int?> pushedAt;
  const SyncOpsCompanion({
    this.seq = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.entity = const Value.absent(),
    this.entityId = const Value.absent(),
    this.field = const Value.absent(),
    this.valueJson = const Value.absent(),
    this.hlc = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.pushedAt = const Value.absent(),
  });
  SyncOpsCompanion.insert({
    this.seq = const Value.absent(),
    required String tenantId,
    required String entity,
    required String entityId,
    required String field,
    this.valueJson = const Value.absent(),
    required String hlc,
    required String deviceId,
    this.pushedAt = const Value.absent(),
  }) : tenantId = Value(tenantId),
       entity = Value(entity),
       entityId = Value(entityId),
       field = Value(field),
       hlc = Value(hlc),
       deviceId = Value(deviceId);
  static Insertable<SyncOpRow> custom({
    Expression<int>? seq,
    Expression<String>? tenantId,
    Expression<String>? entity,
    Expression<String>? entityId,
    Expression<String>? field,
    Expression<String>? valueJson,
    Expression<String>? hlc,
    Expression<String>? deviceId,
    Expression<int>? pushedAt,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (tenantId != null) 'tenant_id': tenantId,
      if (entity != null) 'entity': entity,
      if (entityId != null) 'entity_id': entityId,
      if (field != null) 'field': field,
      if (valueJson != null) 'value_json': valueJson,
      if (hlc != null) 'hlc': hlc,
      if (deviceId != null) 'device_id': deviceId,
      if (pushedAt != null) 'pushed_at': pushedAt,
    });
  }

  SyncOpsCompanion copyWith({
    Value<int>? seq,
    Value<String>? tenantId,
    Value<String>? entity,
    Value<String>? entityId,
    Value<String>? field,
    Value<String?>? valueJson,
    Value<String>? hlc,
    Value<String>? deviceId,
    Value<int?>? pushedAt,
  }) {
    return SyncOpsCompanion(
      seq: seq ?? this.seq,
      tenantId: tenantId ?? this.tenantId,
      entity: entity ?? this.entity,
      entityId: entityId ?? this.entityId,
      field: field ?? this.field,
      valueJson: valueJson ?? this.valueJson,
      hlc: hlc ?? this.hlc,
      deviceId: deviceId ?? this.deviceId,
      pushedAt: pushedAt ?? this.pushedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (field.present) {
      map['field'] = Variable<String>(field.value);
    }
    if (valueJson.present) {
      map['value_json'] = Variable<String>(valueJson.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (pushedAt.present) {
      map['pushed_at'] = Variable<int>(pushedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOpsCompanion(')
          ..write('seq: $seq, ')
          ..write('tenantId: $tenantId, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('field: $field, ')
          ..write('valueJson: $valueJson, ')
          ..write('hlc: $hlc, ')
          ..write('deviceId: $deviceId, ')
          ..write('pushedAt: $pushedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SpeciesTable species = $SpeciesTable(this);
  late final $LocationsTable locations = $LocationsTable(this);
  late final $PlantsTable plants = $PlantsTable(this);
  late final $PhotosTable photos = $PhotosTable(this);
  late final $PlantPhotosTable plantPhotos = $PlantPhotosTable(this);
  late final $LocationPhotosTable locationPhotos = $LocationPhotosTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $PlantTagsTable plantTags = $PlantTagsTable(this);
  late final $CareEventsTable careEvents = $CareEventsTable(this);
  late final $CareSchedulesTable careSchedules = $CareSchedulesTable(this);
  late final $InventoryTransactionsTable inventoryTransactions =
      $InventoryTransactionsTable(this);
  late final $SyncOpsTable syncOps = $SyncOpsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    species,
    locations,
    plants,
    photos,
    plantPhotos,
    locationPhotos,
    tags,
    plantTags,
    careEvents,
    careSchedules,
    inventoryTransactions,
    syncOps,
  ];
}

typedef $$SpeciesTableCreateCompanionBuilder =
    SpeciesCompanion Function({
      required String id,
      required String tenantId,
      required String scientificName,
      required String commonNamesJson,
      Value<String?> defaultCareJson,
      Value<bool> isSeed,
      required String updatedHlc,
      Value<int?> deletedAt,
      required String deviceId,
      Value<int> rowid,
    });
typedef $$SpeciesTableUpdateCompanionBuilder =
    SpeciesCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> scientificName,
      Value<String> commonNamesJson,
      Value<String?> defaultCareJson,
      Value<bool> isSeed,
      Value<String> updatedHlc,
      Value<int?> deletedAt,
      Value<String> deviceId,
      Value<int> rowid,
    });

class $$SpeciesTableFilterComposer
    extends Composer<_$AppDatabase, $SpeciesTable> {
  $$SpeciesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scientificName => $composableBuilder(
    column: $table.scientificName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commonNamesJson => $composableBuilder(
    column: $table.commonNamesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultCareJson => $composableBuilder(
    column: $table.defaultCareJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSeed => $composableBuilder(
    column: $table.isSeed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedHlc => $composableBuilder(
    column: $table.updatedHlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SpeciesTableOrderingComposer
    extends Composer<_$AppDatabase, $SpeciesTable> {
  $$SpeciesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scientificName => $composableBuilder(
    column: $table.scientificName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commonNamesJson => $composableBuilder(
    column: $table.commonNamesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultCareJson => $composableBuilder(
    column: $table.defaultCareJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSeed => $composableBuilder(
    column: $table.isSeed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedHlc => $composableBuilder(
    column: $table.updatedHlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SpeciesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SpeciesTable> {
  $$SpeciesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get scientificName => $composableBuilder(
    column: $table.scientificName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get commonNamesJson => $composableBuilder(
    column: $table.commonNamesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get defaultCareJson => $composableBuilder(
    column: $table.defaultCareJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isSeed =>
      $composableBuilder(column: $table.isSeed, builder: (column) => column);

  GeneratedColumn<String> get updatedHlc => $composableBuilder(
    column: $table.updatedHlc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $$SpeciesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SpeciesTable,
          SpeciesRow,
          $$SpeciesTableFilterComposer,
          $$SpeciesTableOrderingComposer,
          $$SpeciesTableAnnotationComposer,
          $$SpeciesTableCreateCompanionBuilder,
          $$SpeciesTableUpdateCompanionBuilder,
          (
            SpeciesRow,
            BaseReferences<_$AppDatabase, $SpeciesTable, SpeciesRow>,
          ),
          SpeciesRow,
          PrefetchHooks Function()
        > {
  $$SpeciesTableTableManager(_$AppDatabase db, $SpeciesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpeciesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpeciesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SpeciesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> scientificName = const Value.absent(),
                Value<String> commonNamesJson = const Value.absent(),
                Value<String?> defaultCareJson = const Value.absent(),
                Value<bool> isSeed = const Value.absent(),
                Value<String> updatedHlc = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SpeciesCompanion(
                id: id,
                tenantId: tenantId,
                scientificName: scientificName,
                commonNamesJson: commonNamesJson,
                defaultCareJson: defaultCareJson,
                isSeed: isSeed,
                updatedHlc: updatedHlc,
                deletedAt: deletedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String scientificName,
                required String commonNamesJson,
                Value<String?> defaultCareJson = const Value.absent(),
                Value<bool> isSeed = const Value.absent(),
                required String updatedHlc,
                Value<int?> deletedAt = const Value.absent(),
                required String deviceId,
                Value<int> rowid = const Value.absent(),
              }) => SpeciesCompanion.insert(
                id: id,
                tenantId: tenantId,
                scientificName: scientificName,
                commonNamesJson: commonNamesJson,
                defaultCareJson: defaultCareJson,
                isSeed: isSeed,
                updatedHlc: updatedHlc,
                deletedAt: deletedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SpeciesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SpeciesTable,
      SpeciesRow,
      $$SpeciesTableFilterComposer,
      $$SpeciesTableOrderingComposer,
      $$SpeciesTableAnnotationComposer,
      $$SpeciesTableCreateCompanionBuilder,
      $$SpeciesTableUpdateCompanionBuilder,
      (SpeciesRow, BaseReferences<_$AppDatabase, $SpeciesTable, SpeciesRow>),
      SpeciesRow,
      PrefetchHooks Function()
    >;
typedef $$LocationsTableCreateCompanionBuilder =
    LocationsCompanion Function({
      required String id,
      required String tenantId,
      Value<String?> parentId,
      required String name,
      required String kind,
      Value<String?> light,
      Value<int?> humidityMin,
      Value<int?> humidityMax,
      Value<double?> tempMinC,
      Value<double?> tempMaxC,
      Value<bool> isOutdoor,
      Value<double?> lat,
      Value<double?> lon,
      Value<String?> notes,
      Value<String?> mapPhotoSha,
      Value<bool> notificationsMuted,
      required String updatedHlc,
      Value<int?> deletedAt,
      required String deviceId,
      Value<int> rowid,
    });
typedef $$LocationsTableUpdateCompanionBuilder =
    LocationsCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String?> parentId,
      Value<String> name,
      Value<String> kind,
      Value<String?> light,
      Value<int?> humidityMin,
      Value<int?> humidityMax,
      Value<double?> tempMinC,
      Value<double?> tempMaxC,
      Value<bool> isOutdoor,
      Value<double?> lat,
      Value<double?> lon,
      Value<String?> notes,
      Value<String?> mapPhotoSha,
      Value<bool> notificationsMuted,
      Value<String> updatedHlc,
      Value<int?> deletedAt,
      Value<String> deviceId,
      Value<int> rowid,
    });

class $$LocationsTableFilterComposer
    extends Composer<_$AppDatabase, $LocationsTable> {
  $$LocationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get light => $composableBuilder(
    column: $table.light,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get humidityMin => $composableBuilder(
    column: $table.humidityMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get humidityMax => $composableBuilder(
    column: $table.humidityMax,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get tempMinC => $composableBuilder(
    column: $table.tempMinC,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get tempMaxC => $composableBuilder(
    column: $table.tempMaxC,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isOutdoor => $composableBuilder(
    column: $table.isOutdoor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lon => $composableBuilder(
    column: $table.lon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mapPhotoSha => $composableBuilder(
    column: $table.mapPhotoSha,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notificationsMuted => $composableBuilder(
    column: $table.notificationsMuted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedHlc => $composableBuilder(
    column: $table.updatedHlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocationsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocationsTable> {
  $$LocationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get light => $composableBuilder(
    column: $table.light,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get humidityMin => $composableBuilder(
    column: $table.humidityMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get humidityMax => $composableBuilder(
    column: $table.humidityMax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get tempMinC => $composableBuilder(
    column: $table.tempMinC,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get tempMaxC => $composableBuilder(
    column: $table.tempMaxC,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isOutdoor => $composableBuilder(
    column: $table.isOutdoor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lon => $composableBuilder(
    column: $table.lon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mapPhotoSha => $composableBuilder(
    column: $table.mapPhotoSha,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notificationsMuted => $composableBuilder(
    column: $table.notificationsMuted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedHlc => $composableBuilder(
    column: $table.updatedHlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocationsTable> {
  $$LocationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get light =>
      $composableBuilder(column: $table.light, builder: (column) => column);

  GeneratedColumn<int> get humidityMin => $composableBuilder(
    column: $table.humidityMin,
    builder: (column) => column,
  );

  GeneratedColumn<int> get humidityMax => $composableBuilder(
    column: $table.humidityMax,
    builder: (column) => column,
  );

  GeneratedColumn<double> get tempMinC =>
      $composableBuilder(column: $table.tempMinC, builder: (column) => column);

  GeneratedColumn<double> get tempMaxC =>
      $composableBuilder(column: $table.tempMaxC, builder: (column) => column);

  GeneratedColumn<bool> get isOutdoor =>
      $composableBuilder(column: $table.isOutdoor, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lon =>
      $composableBuilder(column: $table.lon, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get mapPhotoSha => $composableBuilder(
    column: $table.mapPhotoSha,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get notificationsMuted => $composableBuilder(
    column: $table.notificationsMuted,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedHlc => $composableBuilder(
    column: $table.updatedHlc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $$LocationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocationsTable,
          LocationRow,
          $$LocationsTableFilterComposer,
          $$LocationsTableOrderingComposer,
          $$LocationsTableAnnotationComposer,
          $$LocationsTableCreateCompanionBuilder,
          $$LocationsTableUpdateCompanionBuilder,
          (
            LocationRow,
            BaseReferences<_$AppDatabase, $LocationsTable, LocationRow>,
          ),
          LocationRow,
          PrefetchHooks Function()
        > {
  $$LocationsTableTableManager(_$AppDatabase db, $LocationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> light = const Value.absent(),
                Value<int?> humidityMin = const Value.absent(),
                Value<int?> humidityMax = const Value.absent(),
                Value<double?> tempMinC = const Value.absent(),
                Value<double?> tempMaxC = const Value.absent(),
                Value<bool> isOutdoor = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lon = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> mapPhotoSha = const Value.absent(),
                Value<bool> notificationsMuted = const Value.absent(),
                Value<String> updatedHlc = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocationsCompanion(
                id: id,
                tenantId: tenantId,
                parentId: parentId,
                name: name,
                kind: kind,
                light: light,
                humidityMin: humidityMin,
                humidityMax: humidityMax,
                tempMinC: tempMinC,
                tempMaxC: tempMaxC,
                isOutdoor: isOutdoor,
                lat: lat,
                lon: lon,
                notes: notes,
                mapPhotoSha: mapPhotoSha,
                notificationsMuted: notificationsMuted,
                updatedHlc: updatedHlc,
                deletedAt: deletedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                Value<String?> parentId = const Value.absent(),
                required String name,
                required String kind,
                Value<String?> light = const Value.absent(),
                Value<int?> humidityMin = const Value.absent(),
                Value<int?> humidityMax = const Value.absent(),
                Value<double?> tempMinC = const Value.absent(),
                Value<double?> tempMaxC = const Value.absent(),
                Value<bool> isOutdoor = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lon = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> mapPhotoSha = const Value.absent(),
                Value<bool> notificationsMuted = const Value.absent(),
                required String updatedHlc,
                Value<int?> deletedAt = const Value.absent(),
                required String deviceId,
                Value<int> rowid = const Value.absent(),
              }) => LocationsCompanion.insert(
                id: id,
                tenantId: tenantId,
                parentId: parentId,
                name: name,
                kind: kind,
                light: light,
                humidityMin: humidityMin,
                humidityMax: humidityMax,
                tempMinC: tempMinC,
                tempMaxC: tempMaxC,
                isOutdoor: isOutdoor,
                lat: lat,
                lon: lon,
                notes: notes,
                mapPhotoSha: mapPhotoSha,
                notificationsMuted: notificationsMuted,
                updatedHlc: updatedHlc,
                deletedAt: deletedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocationsTable,
      LocationRow,
      $$LocationsTableFilterComposer,
      $$LocationsTableOrderingComposer,
      $$LocationsTableAnnotationComposer,
      $$LocationsTableCreateCompanionBuilder,
      $$LocationsTableUpdateCompanionBuilder,
      (
        LocationRow,
        BaseReferences<_$AppDatabase, $LocationsTable, LocationRow>,
      ),
      LocationRow,
      PrefetchHooks Function()
    >;
typedef $$PlantsTableCreateCompanionBuilder =
    PlantsCompanion Function({
      required String id,
      required String tenantId,
      required String nickname,
      Value<String?> speciesId,
      Value<String?> locationId,
      Value<double?> pinX,
      Value<double?> pinY,
      Value<bool> notificationsMuted,
      required String status,
      Value<int?> acquiredAt,
      Value<String?> source,
      Value<String?> notes,
      Value<int?> potSizeCm,
      required String updatedHlc,
      Value<int?> deletedAt,
      required String deviceId,
      Value<int> rowid,
    });
typedef $$PlantsTableUpdateCompanionBuilder =
    PlantsCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> nickname,
      Value<String?> speciesId,
      Value<String?> locationId,
      Value<double?> pinX,
      Value<double?> pinY,
      Value<bool> notificationsMuted,
      Value<String> status,
      Value<int?> acquiredAt,
      Value<String?> source,
      Value<String?> notes,
      Value<int?> potSizeCm,
      Value<String> updatedHlc,
      Value<int?> deletedAt,
      Value<String> deviceId,
      Value<int> rowid,
    });

class $$PlantsTableFilterComposer
    extends Composer<_$AppDatabase, $PlantsTable> {
  $$PlantsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get speciesId => $composableBuilder(
    column: $table.speciesId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pinX => $composableBuilder(
    column: $table.pinX,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pinY => $composableBuilder(
    column: $table.pinY,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notificationsMuted => $composableBuilder(
    column: $table.notificationsMuted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get acquiredAt => $composableBuilder(
    column: $table.acquiredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get potSizeCm => $composableBuilder(
    column: $table.potSizeCm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedHlc => $composableBuilder(
    column: $table.updatedHlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlantsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlantsTable> {
  $$PlantsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get speciesId => $composableBuilder(
    column: $table.speciesId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pinX => $composableBuilder(
    column: $table.pinX,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pinY => $composableBuilder(
    column: $table.pinY,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notificationsMuted => $composableBuilder(
    column: $table.notificationsMuted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get acquiredAt => $composableBuilder(
    column: $table.acquiredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get potSizeCm => $composableBuilder(
    column: $table.potSizeCm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedHlc => $composableBuilder(
    column: $table.updatedHlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlantsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlantsTable> {
  $$PlantsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get nickname =>
      $composableBuilder(column: $table.nickname, builder: (column) => column);

  GeneratedColumn<String> get speciesId =>
      $composableBuilder(column: $table.speciesId, builder: (column) => column);

  GeneratedColumn<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get pinX =>
      $composableBuilder(column: $table.pinX, builder: (column) => column);

  GeneratedColumn<double> get pinY =>
      $composableBuilder(column: $table.pinY, builder: (column) => column);

  GeneratedColumn<bool> get notificationsMuted => $composableBuilder(
    column: $table.notificationsMuted,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get acquiredAt => $composableBuilder(
    column: $table.acquiredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get potSizeCm =>
      $composableBuilder(column: $table.potSizeCm, builder: (column) => column);

  GeneratedColumn<String> get updatedHlc => $composableBuilder(
    column: $table.updatedHlc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $$PlantsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlantsTable,
          PlantRow,
          $$PlantsTableFilterComposer,
          $$PlantsTableOrderingComposer,
          $$PlantsTableAnnotationComposer,
          $$PlantsTableCreateCompanionBuilder,
          $$PlantsTableUpdateCompanionBuilder,
          (PlantRow, BaseReferences<_$AppDatabase, $PlantsTable, PlantRow>),
          PlantRow,
          PrefetchHooks Function()
        > {
  $$PlantsTableTableManager(_$AppDatabase db, $PlantsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlantsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlantsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlantsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> nickname = const Value.absent(),
                Value<String?> speciesId = const Value.absent(),
                Value<String?> locationId = const Value.absent(),
                Value<double?> pinX = const Value.absent(),
                Value<double?> pinY = const Value.absent(),
                Value<bool> notificationsMuted = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> acquiredAt = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int?> potSizeCm = const Value.absent(),
                Value<String> updatedHlc = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlantsCompanion(
                id: id,
                tenantId: tenantId,
                nickname: nickname,
                speciesId: speciesId,
                locationId: locationId,
                pinX: pinX,
                pinY: pinY,
                notificationsMuted: notificationsMuted,
                status: status,
                acquiredAt: acquiredAt,
                source: source,
                notes: notes,
                potSizeCm: potSizeCm,
                updatedHlc: updatedHlc,
                deletedAt: deletedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String nickname,
                Value<String?> speciesId = const Value.absent(),
                Value<String?> locationId = const Value.absent(),
                Value<double?> pinX = const Value.absent(),
                Value<double?> pinY = const Value.absent(),
                Value<bool> notificationsMuted = const Value.absent(),
                required String status,
                Value<int?> acquiredAt = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int?> potSizeCm = const Value.absent(),
                required String updatedHlc,
                Value<int?> deletedAt = const Value.absent(),
                required String deviceId,
                Value<int> rowid = const Value.absent(),
              }) => PlantsCompanion.insert(
                id: id,
                tenantId: tenantId,
                nickname: nickname,
                speciesId: speciesId,
                locationId: locationId,
                pinX: pinX,
                pinY: pinY,
                notificationsMuted: notificationsMuted,
                status: status,
                acquiredAt: acquiredAt,
                source: source,
                notes: notes,
                potSizeCm: potSizeCm,
                updatedHlc: updatedHlc,
                deletedAt: deletedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlantsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlantsTable,
      PlantRow,
      $$PlantsTableFilterComposer,
      $$PlantsTableOrderingComposer,
      $$PlantsTableAnnotationComposer,
      $$PlantsTableCreateCompanionBuilder,
      $$PlantsTableUpdateCompanionBuilder,
      (PlantRow, BaseReferences<_$AppDatabase, $PlantsTable, PlantRow>),
      PlantRow,
      PrefetchHooks Function()
    >;
typedef $$PhotosTableCreateCompanionBuilder =
    PhotosCompanion Function({
      required String sha256,
      required String tenantId,
      Value<int?> width,
      Value<int?> height,
      required String mime,
      required int bytes,
      Value<int?> takenAt,
      Value<String?> exifJson,
      Value<String?> localPath,
      Value<String> remoteState,
      required String updatedHlc,
      Value<int?> deletedAt,
      required String deviceId,
      Value<int> rowid,
    });
typedef $$PhotosTableUpdateCompanionBuilder =
    PhotosCompanion Function({
      Value<String> sha256,
      Value<String> tenantId,
      Value<int?> width,
      Value<int?> height,
      Value<String> mime,
      Value<int> bytes,
      Value<int?> takenAt,
      Value<String?> exifJson,
      Value<String?> localPath,
      Value<String> remoteState,
      Value<String> updatedHlc,
      Value<int?> deletedAt,
      Value<String> deviceId,
      Value<int> rowid,
    });

class $$PhotosTableFilterComposer
    extends Composer<_$AppDatabase, $PhotosTable> {
  $$PhotosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exifJson => $composableBuilder(
    column: $table.exifJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteState => $composableBuilder(
    column: $table.remoteState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedHlc => $composableBuilder(
    column: $table.updatedHlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PhotosTableOrderingComposer
    extends Composer<_$AppDatabase, $PhotosTable> {
  $$PhotosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exifJson => $composableBuilder(
    column: $table.exifJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteState => $composableBuilder(
    column: $table.remoteState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedHlc => $composableBuilder(
    column: $table.updatedHlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PhotosTableAnnotationComposer
    extends Composer<_$AppDatabase, $PhotosTable> {
  $$PhotosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<String> get mime =>
      $composableBuilder(column: $table.mime, builder: (column) => column);

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<int> get takenAt =>
      $composableBuilder(column: $table.takenAt, builder: (column) => column);

  GeneratedColumn<String> get exifJson =>
      $composableBuilder(column: $table.exifJson, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get remoteState => $composableBuilder(
    column: $table.remoteState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedHlc => $composableBuilder(
    column: $table.updatedHlc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $$PhotosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PhotosTable,
          PhotoRow,
          $$PhotosTableFilterComposer,
          $$PhotosTableOrderingComposer,
          $$PhotosTableAnnotationComposer,
          $$PhotosTableCreateCompanionBuilder,
          $$PhotosTableUpdateCompanionBuilder,
          (PhotoRow, BaseReferences<_$AppDatabase, $PhotosTable, PhotoRow>),
          PhotoRow,
          PrefetchHooks Function()
        > {
  $$PhotosTableTableManager(_$AppDatabase db, $PhotosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhotosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhotosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhotosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sha256 = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<String> mime = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                Value<int?> takenAt = const Value.absent(),
                Value<String?> exifJson = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<String> remoteState = const Value.absent(),
                Value<String> updatedHlc = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhotosCompanion(
                sha256: sha256,
                tenantId: tenantId,
                width: width,
                height: height,
                mime: mime,
                bytes: bytes,
                takenAt: takenAt,
                exifJson: exifJson,
                localPath: localPath,
                remoteState: remoteState,
                updatedHlc: updatedHlc,
                deletedAt: deletedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sha256,
                required String tenantId,
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                required String mime,
                required int bytes,
                Value<int?> takenAt = const Value.absent(),
                Value<String?> exifJson = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<String> remoteState = const Value.absent(),
                required String updatedHlc,
                Value<int?> deletedAt = const Value.absent(),
                required String deviceId,
                Value<int> rowid = const Value.absent(),
              }) => PhotosCompanion.insert(
                sha256: sha256,
                tenantId: tenantId,
                width: width,
                height: height,
                mime: mime,
                bytes: bytes,
                takenAt: takenAt,
                exifJson: exifJson,
                localPath: localPath,
                remoteState: remoteState,
                updatedHlc: updatedHlc,
                deletedAt: deletedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PhotosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PhotosTable,
      PhotoRow,
      $$PhotosTableFilterComposer,
      $$PhotosTableOrderingComposer,
      $$PhotosTableAnnotationComposer,
      $$PhotosTableCreateCompanionBuilder,
      $$PhotosTableUpdateCompanionBuilder,
      (PhotoRow, BaseReferences<_$AppDatabase, $PhotosTable, PhotoRow>),
      PhotoRow,
      PrefetchHooks Function()
    >;
typedef $$PlantPhotosTableCreateCompanionBuilder =
    PlantPhotosCompanion Function({
      required String id,
      required String tenantId,
      required String plantId,
      required String photoSha,
      Value<String?> caption,
      Value<int?> capturedAt,
      Value<int> displayOrder,
      required String addedHlc,
      Value<String?> removedHlc,
      required String deviceId,
      Value<int> rowid,
    });
typedef $$PlantPhotosTableUpdateCompanionBuilder =
    PlantPhotosCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> plantId,
      Value<String> photoSha,
      Value<String?> caption,
      Value<int?> capturedAt,
      Value<int> displayOrder,
      Value<String> addedHlc,
      Value<String?> removedHlc,
      Value<String> deviceId,
      Value<int> rowid,
    });

class $$PlantPhotosTableFilterComposer
    extends Composer<_$AppDatabase, $PlantPhotosTable> {
  $$PlantPhotosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plantId => $composableBuilder(
    column: $table.plantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoSha => $composableBuilder(
    column: $table.photoSha,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caption => $composableBuilder(
    column: $table.caption,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addedHlc => $composableBuilder(
    column: $table.addedHlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get removedHlc => $composableBuilder(
    column: $table.removedHlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlantPhotosTableOrderingComposer
    extends Composer<_$AppDatabase, $PlantPhotosTable> {
  $$PlantPhotosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plantId => $composableBuilder(
    column: $table.plantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoSha => $composableBuilder(
    column: $table.photoSha,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caption => $composableBuilder(
    column: $table.caption,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addedHlc => $composableBuilder(
    column: $table.addedHlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get removedHlc => $composableBuilder(
    column: $table.removedHlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlantPhotosTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlantPhotosTable> {
  $$PlantPhotosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get plantId =>
      $composableBuilder(column: $table.plantId, builder: (column) => column);

  GeneratedColumn<String> get photoSha =>
      $composableBuilder(column: $table.photoSha, builder: (column) => column);

  GeneratedColumn<String> get caption =>
      $composableBuilder(column: $table.caption, builder: (column) => column);

  GeneratedColumn<int> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => column,
  );

  GeneratedColumn<String> get addedHlc =>
      $composableBuilder(column: $table.addedHlc, builder: (column) => column);

  GeneratedColumn<String> get removedHlc => $composableBuilder(
    column: $table.removedHlc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $$PlantPhotosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlantPhotosTable,
          PlantPhotoRow,
          $$PlantPhotosTableFilterComposer,
          $$PlantPhotosTableOrderingComposer,
          $$PlantPhotosTableAnnotationComposer,
          $$PlantPhotosTableCreateCompanionBuilder,
          $$PlantPhotosTableUpdateCompanionBuilder,
          (
            PlantPhotoRow,
            BaseReferences<_$AppDatabase, $PlantPhotosTable, PlantPhotoRow>,
          ),
          PlantPhotoRow,
          PrefetchHooks Function()
        > {
  $$PlantPhotosTableTableManager(_$AppDatabase db, $PlantPhotosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlantPhotosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlantPhotosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlantPhotosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> plantId = const Value.absent(),
                Value<String> photoSha = const Value.absent(),
                Value<String?> caption = const Value.absent(),
                Value<int?> capturedAt = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
                Value<String> addedHlc = const Value.absent(),
                Value<String?> removedHlc = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlantPhotosCompanion(
                id: id,
                tenantId: tenantId,
                plantId: plantId,
                photoSha: photoSha,
                caption: caption,
                capturedAt: capturedAt,
                displayOrder: displayOrder,
                addedHlc: addedHlc,
                removedHlc: removedHlc,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String plantId,
                required String photoSha,
                Value<String?> caption = const Value.absent(),
                Value<int?> capturedAt = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
                required String addedHlc,
                Value<String?> removedHlc = const Value.absent(),
                required String deviceId,
                Value<int> rowid = const Value.absent(),
              }) => PlantPhotosCompanion.insert(
                id: id,
                tenantId: tenantId,
                plantId: plantId,
                photoSha: photoSha,
                caption: caption,
                capturedAt: capturedAt,
                displayOrder: displayOrder,
                addedHlc: addedHlc,
                removedHlc: removedHlc,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlantPhotosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlantPhotosTable,
      PlantPhotoRow,
      $$PlantPhotosTableFilterComposer,
      $$PlantPhotosTableOrderingComposer,
      $$PlantPhotosTableAnnotationComposer,
      $$PlantPhotosTableCreateCompanionBuilder,
      $$PlantPhotosTableUpdateCompanionBuilder,
      (
        PlantPhotoRow,
        BaseReferences<_$AppDatabase, $PlantPhotosTable, PlantPhotoRow>,
      ),
      PlantPhotoRow,
      PrefetchHooks Function()
    >;
typedef $$LocationPhotosTableCreateCompanionBuilder =
    LocationPhotosCompanion Function({
      required String id,
      required String tenantId,
      required String locationId,
      required String photoSha,
      Value<String?> caption,
      Value<int?> capturedAt,
      Value<int> displayOrder,
      required String addedHlc,
      Value<String?> removedHlc,
      required String deviceId,
      Value<int> rowid,
    });
typedef $$LocationPhotosTableUpdateCompanionBuilder =
    LocationPhotosCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> locationId,
      Value<String> photoSha,
      Value<String?> caption,
      Value<int?> capturedAt,
      Value<int> displayOrder,
      Value<String> addedHlc,
      Value<String?> removedHlc,
      Value<String> deviceId,
      Value<int> rowid,
    });

class $$LocationPhotosTableFilterComposer
    extends Composer<_$AppDatabase, $LocationPhotosTable> {
  $$LocationPhotosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoSha => $composableBuilder(
    column: $table.photoSha,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caption => $composableBuilder(
    column: $table.caption,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addedHlc => $composableBuilder(
    column: $table.addedHlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get removedHlc => $composableBuilder(
    column: $table.removedHlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocationPhotosTableOrderingComposer
    extends Composer<_$AppDatabase, $LocationPhotosTable> {
  $$LocationPhotosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoSha => $composableBuilder(
    column: $table.photoSha,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caption => $composableBuilder(
    column: $table.caption,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addedHlc => $composableBuilder(
    column: $table.addedHlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get removedHlc => $composableBuilder(
    column: $table.removedHlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocationPhotosTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocationPhotosTable> {
  $$LocationPhotosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get locationId => $composableBuilder(
    column: $table.locationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get photoSha =>
      $composableBuilder(column: $table.photoSha, builder: (column) => column);

  GeneratedColumn<String> get caption =>
      $composableBuilder(column: $table.caption, builder: (column) => column);

  GeneratedColumn<int> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => column,
  );

  GeneratedColumn<String> get addedHlc =>
      $composableBuilder(column: $table.addedHlc, builder: (column) => column);

  GeneratedColumn<String> get removedHlc => $composableBuilder(
    column: $table.removedHlc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $$LocationPhotosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocationPhotosTable,
          LocationPhotoRow,
          $$LocationPhotosTableFilterComposer,
          $$LocationPhotosTableOrderingComposer,
          $$LocationPhotosTableAnnotationComposer,
          $$LocationPhotosTableCreateCompanionBuilder,
          $$LocationPhotosTableUpdateCompanionBuilder,
          (
            LocationPhotoRow,
            BaseReferences<
              _$AppDatabase,
              $LocationPhotosTable,
              LocationPhotoRow
            >,
          ),
          LocationPhotoRow,
          PrefetchHooks Function()
        > {
  $$LocationPhotosTableTableManager(
    _$AppDatabase db,
    $LocationPhotosTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocationPhotosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocationPhotosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocationPhotosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> locationId = const Value.absent(),
                Value<String> photoSha = const Value.absent(),
                Value<String?> caption = const Value.absent(),
                Value<int?> capturedAt = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
                Value<String> addedHlc = const Value.absent(),
                Value<String?> removedHlc = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocationPhotosCompanion(
                id: id,
                tenantId: tenantId,
                locationId: locationId,
                photoSha: photoSha,
                caption: caption,
                capturedAt: capturedAt,
                displayOrder: displayOrder,
                addedHlc: addedHlc,
                removedHlc: removedHlc,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String locationId,
                required String photoSha,
                Value<String?> caption = const Value.absent(),
                Value<int?> capturedAt = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
                required String addedHlc,
                Value<String?> removedHlc = const Value.absent(),
                required String deviceId,
                Value<int> rowid = const Value.absent(),
              }) => LocationPhotosCompanion.insert(
                id: id,
                tenantId: tenantId,
                locationId: locationId,
                photoSha: photoSha,
                caption: caption,
                capturedAt: capturedAt,
                displayOrder: displayOrder,
                addedHlc: addedHlc,
                removedHlc: removedHlc,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocationPhotosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocationPhotosTable,
      LocationPhotoRow,
      $$LocationPhotosTableFilterComposer,
      $$LocationPhotosTableOrderingComposer,
      $$LocationPhotosTableAnnotationComposer,
      $$LocationPhotosTableCreateCompanionBuilder,
      $$LocationPhotosTableUpdateCompanionBuilder,
      (
        LocationPhotoRow,
        BaseReferences<_$AppDatabase, $LocationPhotosTable, LocationPhotoRow>,
      ),
      LocationPhotoRow,
      PrefetchHooks Function()
    >;
typedef $$TagsTableCreateCompanionBuilder =
    TagsCompanion Function({
      required String id,
      required String tenantId,
      required String name,
      Value<String?> color,
      required String updatedHlc,
      Value<int?> deletedAt,
      required String deviceId,
      Value<int> rowid,
    });
typedef $$TagsTableUpdateCompanionBuilder =
    TagsCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> name,
      Value<String?> color,
      Value<String> updatedHlc,
      Value<int?> deletedAt,
      Value<String> deviceId,
      Value<int> rowid,
    });

class $$TagsTableFilterComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedHlc => $composableBuilder(
    column: $table.updatedHlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TagsTableOrderingComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedHlc => $composableBuilder(
    column: $table.updatedHlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get updatedHlc => $composableBuilder(
    column: $table.updatedHlc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagsTable,
          TagRow,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (TagRow, BaseReferences<_$AppDatabase, $TagsTable, TagRow>),
          TagRow,
          PrefetchHooks Function()
        > {
  $$TagsTableTableManager(_$AppDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<String> updatedHlc = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion(
                id: id,
                tenantId: tenantId,
                name: name,
                color: color,
                updatedHlc: updatedHlc,
                deletedAt: deletedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String name,
                Value<String?> color = const Value.absent(),
                required String updatedHlc,
                Value<int?> deletedAt = const Value.absent(),
                required String deviceId,
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion.insert(
                id: id,
                tenantId: tenantId,
                name: name,
                color: color,
                updatedHlc: updatedHlc,
                deletedAt: deletedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagsTable,
      TagRow,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (TagRow, BaseReferences<_$AppDatabase, $TagsTable, TagRow>),
      TagRow,
      PrefetchHooks Function()
    >;
typedef $$PlantTagsTableCreateCompanionBuilder =
    PlantTagsCompanion Function({
      required String id,
      required String tenantId,
      required String plantId,
      required String tagId,
      required String addedHlc,
      Value<String?> removedHlc,
      required String deviceId,
      Value<int> rowid,
    });
typedef $$PlantTagsTableUpdateCompanionBuilder =
    PlantTagsCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> plantId,
      Value<String> tagId,
      Value<String> addedHlc,
      Value<String?> removedHlc,
      Value<String> deviceId,
      Value<int> rowid,
    });

class $$PlantTagsTableFilterComposer
    extends Composer<_$AppDatabase, $PlantTagsTable> {
  $$PlantTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plantId => $composableBuilder(
    column: $table.plantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addedHlc => $composableBuilder(
    column: $table.addedHlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get removedHlc => $composableBuilder(
    column: $table.removedHlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlantTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlantTagsTable> {
  $$PlantTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plantId => $composableBuilder(
    column: $table.plantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addedHlc => $composableBuilder(
    column: $table.addedHlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get removedHlc => $composableBuilder(
    column: $table.removedHlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlantTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlantTagsTable> {
  $$PlantTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get plantId =>
      $composableBuilder(column: $table.plantId, builder: (column) => column);

  GeneratedColumn<String> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => column);

  GeneratedColumn<String> get addedHlc =>
      $composableBuilder(column: $table.addedHlc, builder: (column) => column);

  GeneratedColumn<String> get removedHlc => $composableBuilder(
    column: $table.removedHlc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $$PlantTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlantTagsTable,
          PlantTagRow,
          $$PlantTagsTableFilterComposer,
          $$PlantTagsTableOrderingComposer,
          $$PlantTagsTableAnnotationComposer,
          $$PlantTagsTableCreateCompanionBuilder,
          $$PlantTagsTableUpdateCompanionBuilder,
          (
            PlantTagRow,
            BaseReferences<_$AppDatabase, $PlantTagsTable, PlantTagRow>,
          ),
          PlantTagRow,
          PrefetchHooks Function()
        > {
  $$PlantTagsTableTableManager(_$AppDatabase db, $PlantTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlantTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlantTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlantTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> plantId = const Value.absent(),
                Value<String> tagId = const Value.absent(),
                Value<String> addedHlc = const Value.absent(),
                Value<String?> removedHlc = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlantTagsCompanion(
                id: id,
                tenantId: tenantId,
                plantId: plantId,
                tagId: tagId,
                addedHlc: addedHlc,
                removedHlc: removedHlc,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String plantId,
                required String tagId,
                required String addedHlc,
                Value<String?> removedHlc = const Value.absent(),
                required String deviceId,
                Value<int> rowid = const Value.absent(),
              }) => PlantTagsCompanion.insert(
                id: id,
                tenantId: tenantId,
                plantId: plantId,
                tagId: tagId,
                addedHlc: addedHlc,
                removedHlc: removedHlc,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlantTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlantTagsTable,
      PlantTagRow,
      $$PlantTagsTableFilterComposer,
      $$PlantTagsTableOrderingComposer,
      $$PlantTagsTableAnnotationComposer,
      $$PlantTagsTableCreateCompanionBuilder,
      $$PlantTagsTableUpdateCompanionBuilder,
      (
        PlantTagRow,
        BaseReferences<_$AppDatabase, $PlantTagsTable, PlantTagRow>,
      ),
      PlantTagRow,
      PrefetchHooks Function()
    >;
typedef $$CareEventsTableCreateCompanionBuilder =
    CareEventsCompanion Function({
      required String id,
      required String tenantId,
      required String plantId,
      required String type,
      required int doneAt,
      Value<String?> notes,
      Value<String?> dose,
      Value<String?> product,
      Value<String?> photoSha,
      required String updatedHlc,
      Value<int?> deletedAt,
      required String deviceId,
      Value<int> rowid,
    });
typedef $$CareEventsTableUpdateCompanionBuilder =
    CareEventsCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> plantId,
      Value<String> type,
      Value<int> doneAt,
      Value<String?> notes,
      Value<String?> dose,
      Value<String?> product,
      Value<String?> photoSha,
      Value<String> updatedHlc,
      Value<int?> deletedAt,
      Value<String> deviceId,
      Value<int> rowid,
    });

class $$CareEventsTableFilterComposer
    extends Composer<_$AppDatabase, $CareEventsTable> {
  $$CareEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plantId => $composableBuilder(
    column: $table.plantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get doneAt => $composableBuilder(
    column: $table.doneAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dose => $composableBuilder(
    column: $table.dose,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get product => $composableBuilder(
    column: $table.product,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoSha => $composableBuilder(
    column: $table.photoSha,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedHlc => $composableBuilder(
    column: $table.updatedHlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CareEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $CareEventsTable> {
  $$CareEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plantId => $composableBuilder(
    column: $table.plantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get doneAt => $composableBuilder(
    column: $table.doneAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dose => $composableBuilder(
    column: $table.dose,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get product => $composableBuilder(
    column: $table.product,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoSha => $composableBuilder(
    column: $table.photoSha,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedHlc => $composableBuilder(
    column: $table.updatedHlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CareEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CareEventsTable> {
  $$CareEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get plantId =>
      $composableBuilder(column: $table.plantId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get doneAt =>
      $composableBuilder(column: $table.doneAt, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get dose =>
      $composableBuilder(column: $table.dose, builder: (column) => column);

  GeneratedColumn<String> get product =>
      $composableBuilder(column: $table.product, builder: (column) => column);

  GeneratedColumn<String> get photoSha =>
      $composableBuilder(column: $table.photoSha, builder: (column) => column);

  GeneratedColumn<String> get updatedHlc => $composableBuilder(
    column: $table.updatedHlc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $$CareEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CareEventsTable,
          CareEventRow,
          $$CareEventsTableFilterComposer,
          $$CareEventsTableOrderingComposer,
          $$CareEventsTableAnnotationComposer,
          $$CareEventsTableCreateCompanionBuilder,
          $$CareEventsTableUpdateCompanionBuilder,
          (
            CareEventRow,
            BaseReferences<_$AppDatabase, $CareEventsTable, CareEventRow>,
          ),
          CareEventRow,
          PrefetchHooks Function()
        > {
  $$CareEventsTableTableManager(_$AppDatabase db, $CareEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CareEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CareEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CareEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> plantId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> doneAt = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> dose = const Value.absent(),
                Value<String?> product = const Value.absent(),
                Value<String?> photoSha = const Value.absent(),
                Value<String> updatedHlc = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CareEventsCompanion(
                id: id,
                tenantId: tenantId,
                plantId: plantId,
                type: type,
                doneAt: doneAt,
                notes: notes,
                dose: dose,
                product: product,
                photoSha: photoSha,
                updatedHlc: updatedHlc,
                deletedAt: deletedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String plantId,
                required String type,
                required int doneAt,
                Value<String?> notes = const Value.absent(),
                Value<String?> dose = const Value.absent(),
                Value<String?> product = const Value.absent(),
                Value<String?> photoSha = const Value.absent(),
                required String updatedHlc,
                Value<int?> deletedAt = const Value.absent(),
                required String deviceId,
                Value<int> rowid = const Value.absent(),
              }) => CareEventsCompanion.insert(
                id: id,
                tenantId: tenantId,
                plantId: plantId,
                type: type,
                doneAt: doneAt,
                notes: notes,
                dose: dose,
                product: product,
                photoSha: photoSha,
                updatedHlc: updatedHlc,
                deletedAt: deletedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CareEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CareEventsTable,
      CareEventRow,
      $$CareEventsTableFilterComposer,
      $$CareEventsTableOrderingComposer,
      $$CareEventsTableAnnotationComposer,
      $$CareEventsTableCreateCompanionBuilder,
      $$CareEventsTableUpdateCompanionBuilder,
      (
        CareEventRow,
        BaseReferences<_$AppDatabase, $CareEventsTable, CareEventRow>,
      ),
      CareEventRow,
      PrefetchHooks Function()
    >;
typedef $$CareSchedulesTableCreateCompanionBuilder =
    CareSchedulesCompanion Function({
      required String id,
      required String tenantId,
      required String plantId,
      required String type,
      required double baseIntervalDays,
      required double currentIntervalDays,
      Value<int?> lastDoneAt,
      Value<int?> nextDueAt,
      Value<int> snoozeCount,
      Value<String> recentEventsJson,
      Value<bool> enabled,
      Value<String> recurrenceMode,
      Value<bool> notificationsMuted,
      required String updatedHlc,
      Value<int?> deletedAt,
      required String deviceId,
      Value<int> rowid,
    });
typedef $$CareSchedulesTableUpdateCompanionBuilder =
    CareSchedulesCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> plantId,
      Value<String> type,
      Value<double> baseIntervalDays,
      Value<double> currentIntervalDays,
      Value<int?> lastDoneAt,
      Value<int?> nextDueAt,
      Value<int> snoozeCount,
      Value<String> recentEventsJson,
      Value<bool> enabled,
      Value<String> recurrenceMode,
      Value<bool> notificationsMuted,
      Value<String> updatedHlc,
      Value<int?> deletedAt,
      Value<String> deviceId,
      Value<int> rowid,
    });

class $$CareSchedulesTableFilterComposer
    extends Composer<_$AppDatabase, $CareSchedulesTable> {
  $$CareSchedulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plantId => $composableBuilder(
    column: $table.plantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get baseIntervalDays => $composableBuilder(
    column: $table.baseIntervalDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get currentIntervalDays => $composableBuilder(
    column: $table.currentIntervalDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastDoneAt => $composableBuilder(
    column: $table.lastDoneAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextDueAt => $composableBuilder(
    column: $table.nextDueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get snoozeCount => $composableBuilder(
    column: $table.snoozeCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recentEventsJson => $composableBuilder(
    column: $table.recentEventsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceMode => $composableBuilder(
    column: $table.recurrenceMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notificationsMuted => $composableBuilder(
    column: $table.notificationsMuted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedHlc => $composableBuilder(
    column: $table.updatedHlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CareSchedulesTableOrderingComposer
    extends Composer<_$AppDatabase, $CareSchedulesTable> {
  $$CareSchedulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plantId => $composableBuilder(
    column: $table.plantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get baseIntervalDays => $composableBuilder(
    column: $table.baseIntervalDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get currentIntervalDays => $composableBuilder(
    column: $table.currentIntervalDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastDoneAt => $composableBuilder(
    column: $table.lastDoneAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextDueAt => $composableBuilder(
    column: $table.nextDueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get snoozeCount => $composableBuilder(
    column: $table.snoozeCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recentEventsJson => $composableBuilder(
    column: $table.recentEventsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceMode => $composableBuilder(
    column: $table.recurrenceMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notificationsMuted => $composableBuilder(
    column: $table.notificationsMuted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedHlc => $composableBuilder(
    column: $table.updatedHlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CareSchedulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CareSchedulesTable> {
  $$CareSchedulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get plantId =>
      $composableBuilder(column: $table.plantId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get baseIntervalDays => $composableBuilder(
    column: $table.baseIntervalDays,
    builder: (column) => column,
  );

  GeneratedColumn<double> get currentIntervalDays => $composableBuilder(
    column: $table.currentIntervalDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastDoneAt => $composableBuilder(
    column: $table.lastDoneAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nextDueAt =>
      $composableBuilder(column: $table.nextDueAt, builder: (column) => column);

  GeneratedColumn<int> get snoozeCount => $composableBuilder(
    column: $table.snoozeCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recentEventsJson => $composableBuilder(
    column: $table.recentEventsJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get recurrenceMode => $composableBuilder(
    column: $table.recurrenceMode,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get notificationsMuted => $composableBuilder(
    column: $table.notificationsMuted,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedHlc => $composableBuilder(
    column: $table.updatedHlc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $$CareSchedulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CareSchedulesTable,
          CareScheduleRow,
          $$CareSchedulesTableFilterComposer,
          $$CareSchedulesTableOrderingComposer,
          $$CareSchedulesTableAnnotationComposer,
          $$CareSchedulesTableCreateCompanionBuilder,
          $$CareSchedulesTableUpdateCompanionBuilder,
          (
            CareScheduleRow,
            BaseReferences<_$AppDatabase, $CareSchedulesTable, CareScheduleRow>,
          ),
          CareScheduleRow,
          PrefetchHooks Function()
        > {
  $$CareSchedulesTableTableManager(_$AppDatabase db, $CareSchedulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CareSchedulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CareSchedulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CareSchedulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> plantId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<double> baseIntervalDays = const Value.absent(),
                Value<double> currentIntervalDays = const Value.absent(),
                Value<int?> lastDoneAt = const Value.absent(),
                Value<int?> nextDueAt = const Value.absent(),
                Value<int> snoozeCount = const Value.absent(),
                Value<String> recentEventsJson = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String> recurrenceMode = const Value.absent(),
                Value<bool> notificationsMuted = const Value.absent(),
                Value<String> updatedHlc = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CareSchedulesCompanion(
                id: id,
                tenantId: tenantId,
                plantId: plantId,
                type: type,
                baseIntervalDays: baseIntervalDays,
                currentIntervalDays: currentIntervalDays,
                lastDoneAt: lastDoneAt,
                nextDueAt: nextDueAt,
                snoozeCount: snoozeCount,
                recentEventsJson: recentEventsJson,
                enabled: enabled,
                recurrenceMode: recurrenceMode,
                notificationsMuted: notificationsMuted,
                updatedHlc: updatedHlc,
                deletedAt: deletedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String plantId,
                required String type,
                required double baseIntervalDays,
                required double currentIntervalDays,
                Value<int?> lastDoneAt = const Value.absent(),
                Value<int?> nextDueAt = const Value.absent(),
                Value<int> snoozeCount = const Value.absent(),
                Value<String> recentEventsJson = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String> recurrenceMode = const Value.absent(),
                Value<bool> notificationsMuted = const Value.absent(),
                required String updatedHlc,
                Value<int?> deletedAt = const Value.absent(),
                required String deviceId,
                Value<int> rowid = const Value.absent(),
              }) => CareSchedulesCompanion.insert(
                id: id,
                tenantId: tenantId,
                plantId: plantId,
                type: type,
                baseIntervalDays: baseIntervalDays,
                currentIntervalDays: currentIntervalDays,
                lastDoneAt: lastDoneAt,
                nextDueAt: nextDueAt,
                snoozeCount: snoozeCount,
                recentEventsJson: recentEventsJson,
                enabled: enabled,
                recurrenceMode: recurrenceMode,
                notificationsMuted: notificationsMuted,
                updatedHlc: updatedHlc,
                deletedAt: deletedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CareSchedulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CareSchedulesTable,
      CareScheduleRow,
      $$CareSchedulesTableFilterComposer,
      $$CareSchedulesTableOrderingComposer,
      $$CareSchedulesTableAnnotationComposer,
      $$CareSchedulesTableCreateCompanionBuilder,
      $$CareSchedulesTableUpdateCompanionBuilder,
      (
        CareScheduleRow,
        BaseReferences<_$AppDatabase, $CareSchedulesTable, CareScheduleRow>,
      ),
      CareScheduleRow,
      PrefetchHooks Function()
    >;
typedef $$InventoryTransactionsTableCreateCompanionBuilder =
    InventoryTransactionsCompanion Function({
      required String id,
      required String tenantId,
      required String type,
      Value<String?> parentPlantId,
      Value<String?> childPlantId,
      Value<String?> plantId,
      Value<String?> counterparty,
      required int at,
      Value<String?> notes,
      Value<int?> amountMinor,
      Value<String?> currency,
      required String updatedHlc,
      Value<int?> deletedAt,
      required String deviceId,
      Value<int> rowid,
    });
typedef $$InventoryTransactionsTableUpdateCompanionBuilder =
    InventoryTransactionsCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> type,
      Value<String?> parentPlantId,
      Value<String?> childPlantId,
      Value<String?> plantId,
      Value<String?> counterparty,
      Value<int> at,
      Value<String?> notes,
      Value<int?> amountMinor,
      Value<String?> currency,
      Value<String> updatedHlc,
      Value<int?> deletedAt,
      Value<String> deviceId,
      Value<int> rowid,
    });

class $$InventoryTransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $InventoryTransactionsTable> {
  $$InventoryTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentPlantId => $composableBuilder(
    column: $table.parentPlantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get childPlantId => $composableBuilder(
    column: $table.childPlantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plantId => $composableBuilder(
    column: $table.plantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get counterparty => $composableBuilder(
    column: $table.counterparty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedHlc => $composableBuilder(
    column: $table.updatedHlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InventoryTransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $InventoryTransactionsTable> {
  $$InventoryTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentPlantId => $composableBuilder(
    column: $table.parentPlantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get childPlantId => $composableBuilder(
    column: $table.childPlantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plantId => $composableBuilder(
    column: $table.plantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get counterparty => $composableBuilder(
    column: $table.counterparty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedHlc => $composableBuilder(
    column: $table.updatedHlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InventoryTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InventoryTransactionsTable> {
  $$InventoryTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get parentPlantId => $composableBuilder(
    column: $table.parentPlantId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get childPlantId => $composableBuilder(
    column: $table.childPlantId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get plantId =>
      $composableBuilder(column: $table.plantId, builder: (column) => column);

  GeneratedColumn<String> get counterparty => $composableBuilder(
    column: $table.counterparty,
    builder: (column) => column,
  );

  GeneratedColumn<int> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get updatedHlc => $composableBuilder(
    column: $table.updatedHlc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $$InventoryTransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InventoryTransactionsTable,
          InventoryTransactionRow,
          $$InventoryTransactionsTableFilterComposer,
          $$InventoryTransactionsTableOrderingComposer,
          $$InventoryTransactionsTableAnnotationComposer,
          $$InventoryTransactionsTableCreateCompanionBuilder,
          $$InventoryTransactionsTableUpdateCompanionBuilder,
          (
            InventoryTransactionRow,
            BaseReferences<
              _$AppDatabase,
              $InventoryTransactionsTable,
              InventoryTransactionRow
            >,
          ),
          InventoryTransactionRow,
          PrefetchHooks Function()
        > {
  $$InventoryTransactionsTableTableManager(
    _$AppDatabase db,
    $InventoryTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InventoryTransactionsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$InventoryTransactionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$InventoryTransactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> parentPlantId = const Value.absent(),
                Value<String?> childPlantId = const Value.absent(),
                Value<String?> plantId = const Value.absent(),
                Value<String?> counterparty = const Value.absent(),
                Value<int> at = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int?> amountMinor = const Value.absent(),
                Value<String?> currency = const Value.absent(),
                Value<String> updatedHlc = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InventoryTransactionsCompanion(
                id: id,
                tenantId: tenantId,
                type: type,
                parentPlantId: parentPlantId,
                childPlantId: childPlantId,
                plantId: plantId,
                counterparty: counterparty,
                at: at,
                notes: notes,
                amountMinor: amountMinor,
                currency: currency,
                updatedHlc: updatedHlc,
                deletedAt: deletedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String type,
                Value<String?> parentPlantId = const Value.absent(),
                Value<String?> childPlantId = const Value.absent(),
                Value<String?> plantId = const Value.absent(),
                Value<String?> counterparty = const Value.absent(),
                required int at,
                Value<String?> notes = const Value.absent(),
                Value<int?> amountMinor = const Value.absent(),
                Value<String?> currency = const Value.absent(),
                required String updatedHlc,
                Value<int?> deletedAt = const Value.absent(),
                required String deviceId,
                Value<int> rowid = const Value.absent(),
              }) => InventoryTransactionsCompanion.insert(
                id: id,
                tenantId: tenantId,
                type: type,
                parentPlantId: parentPlantId,
                childPlantId: childPlantId,
                plantId: plantId,
                counterparty: counterparty,
                at: at,
                notes: notes,
                amountMinor: amountMinor,
                currency: currency,
                updatedHlc: updatedHlc,
                deletedAt: deletedAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InventoryTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InventoryTransactionsTable,
      InventoryTransactionRow,
      $$InventoryTransactionsTableFilterComposer,
      $$InventoryTransactionsTableOrderingComposer,
      $$InventoryTransactionsTableAnnotationComposer,
      $$InventoryTransactionsTableCreateCompanionBuilder,
      $$InventoryTransactionsTableUpdateCompanionBuilder,
      (
        InventoryTransactionRow,
        BaseReferences<
          _$AppDatabase,
          $InventoryTransactionsTable,
          InventoryTransactionRow
        >,
      ),
      InventoryTransactionRow,
      PrefetchHooks Function()
    >;
typedef $$SyncOpsTableCreateCompanionBuilder =
    SyncOpsCompanion Function({
      Value<int> seq,
      required String tenantId,
      required String entity,
      required String entityId,
      required String field,
      Value<String?> valueJson,
      required String hlc,
      required String deviceId,
      Value<int?> pushedAt,
    });
typedef $$SyncOpsTableUpdateCompanionBuilder =
    SyncOpsCompanion Function({
      Value<int> seq,
      Value<String> tenantId,
      Value<String> entity,
      Value<String> entityId,
      Value<String> field,
      Value<String?> valueJson,
      Value<String> hlc,
      Value<String> deviceId,
      Value<int?> pushedAt,
    });

class $$SyncOpsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncOpsTable> {
  $$SyncOpsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get field => $composableBuilder(
    column: $table.field,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pushedAt => $composableBuilder(
    column: $table.pushedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncOpsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncOpsTable> {
  $$SyncOpsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get field => $composableBuilder(
    column: $table.field,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pushedAt => $composableBuilder(
    column: $table.pushedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncOpsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncOpsTable> {
  $$SyncOpsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get field =>
      $composableBuilder(column: $table.field, builder: (column) => column);

  GeneratedColumn<String> get valueJson =>
      $composableBuilder(column: $table.valueJson, builder: (column) => column);

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get pushedAt =>
      $composableBuilder(column: $table.pushedAt, builder: (column) => column);
}

class $$SyncOpsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncOpsTable,
          SyncOpRow,
          $$SyncOpsTableFilterComposer,
          $$SyncOpsTableOrderingComposer,
          $$SyncOpsTableAnnotationComposer,
          $$SyncOpsTableCreateCompanionBuilder,
          $$SyncOpsTableUpdateCompanionBuilder,
          (SyncOpRow, BaseReferences<_$AppDatabase, $SyncOpsTable, SyncOpRow>),
          SyncOpRow,
          PrefetchHooks Function()
        > {
  $$SyncOpsTableTableManager(_$AppDatabase db, $SyncOpsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOpsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOpsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOpsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> field = const Value.absent(),
                Value<String?> valueJson = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int?> pushedAt = const Value.absent(),
              }) => SyncOpsCompanion(
                seq: seq,
                tenantId: tenantId,
                entity: entity,
                entityId: entityId,
                field: field,
                valueJson: valueJson,
                hlc: hlc,
                deviceId: deviceId,
                pushedAt: pushedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String tenantId,
                required String entity,
                required String entityId,
                required String field,
                Value<String?> valueJson = const Value.absent(),
                required String hlc,
                required String deviceId,
                Value<int?> pushedAt = const Value.absent(),
              }) => SyncOpsCompanion.insert(
                seq: seq,
                tenantId: tenantId,
                entity: entity,
                entityId: entityId,
                field: field,
                valueJson: valueJson,
                hlc: hlc,
                deviceId: deviceId,
                pushedAt: pushedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOpsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncOpsTable,
      SyncOpRow,
      $$SyncOpsTableFilterComposer,
      $$SyncOpsTableOrderingComposer,
      $$SyncOpsTableAnnotationComposer,
      $$SyncOpsTableCreateCompanionBuilder,
      $$SyncOpsTableUpdateCompanionBuilder,
      (SyncOpRow, BaseReferences<_$AppDatabase, $SyncOpsTable, SyncOpRow>),
      SyncOpRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SpeciesTableTableManager get species =>
      $$SpeciesTableTableManager(_db, _db.species);
  $$LocationsTableTableManager get locations =>
      $$LocationsTableTableManager(_db, _db.locations);
  $$PlantsTableTableManager get plants =>
      $$PlantsTableTableManager(_db, _db.plants);
  $$PhotosTableTableManager get photos =>
      $$PhotosTableTableManager(_db, _db.photos);
  $$PlantPhotosTableTableManager get plantPhotos =>
      $$PlantPhotosTableTableManager(_db, _db.plantPhotos);
  $$LocationPhotosTableTableManager get locationPhotos =>
      $$LocationPhotosTableTableManager(_db, _db.locationPhotos);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$PlantTagsTableTableManager get plantTags =>
      $$PlantTagsTableTableManager(_db, _db.plantTags);
  $$CareEventsTableTableManager get careEvents =>
      $$CareEventsTableTableManager(_db, _db.careEvents);
  $$CareSchedulesTableTableManager get careSchedules =>
      $$CareSchedulesTableTableManager(_db, _db.careSchedules);
  $$InventoryTransactionsTableTableManager get inventoryTransactions =>
      $$InventoryTransactionsTableTableManager(_db, _db.inventoryTransactions);
  $$SyncOpsTableTableManager get syncOps =>
      $$SyncOpsTableTableManager(_db, _db.syncOps);
}
