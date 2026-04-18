import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// Columns in the "synced-row common" bundle — id/tenant_id/updated_hlc/
// deleted_at/device_id appear on every synced table (PLAN.md §"Schema
// non-negotiables"). Photos join tables use a different primitive
// (add_hlc/removed_hlc) so they don't extend this.

@DataClassName('SpeciesRow')
class Species extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get scientificName => text().named('scientific_name')();
  TextColumn get commonNamesJson => text().named('common_names_json')();
  TextColumn get defaultCareJson => text().named('default_care_json').nullable()();
  BoolColumn get isSeed => boolean().named('is_seed').withDefault(const Constant(false))();
  TextColumn get updatedHlc => text().named('updated_hlc')();
  IntColumn get deletedAt => integer().named('deleted_at').nullable()();
  TextColumn get deviceId => text().named('device_id')();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocationRow')
class Locations extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get parentId => text().named('parent_id').nullable()();
  TextColumn get name => text()();
  TextColumn get kind => text()();
  TextColumn get light => text().nullable()();
  IntColumn get humidityMin => integer().named('humidity_min').nullable()();
  IntColumn get humidityMax => integer().named('humidity_max').nullable()();
  RealColumn get tempMinC => real().named('temp_min_c').nullable()();
  RealColumn get tempMaxC => real().named('temp_max_c').nullable()();
  BoolColumn get isOutdoor => boolean().named('is_outdoor').withDefault(const Constant(false))();
  RealColumn get lat => real().nullable()();
  RealColumn get lon => real().nullable()();
  TextColumn get updatedHlc => text().named('updated_hlc')();
  IntColumn get deletedAt => integer().named('deleted_at').nullable()();
  TextColumn get deviceId => text().named('device_id')();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PlantRow')
class Plants extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get nickname => text()();
  TextColumn get speciesId => text().named('species_id').nullable()();
  TextColumn get locationId => text().named('location_id').nullable()();
  TextColumn get status => text()();
  IntColumn get acquiredAt => integer().named('acquired_at').nullable()();
  TextColumn get source => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get potSizeCm => integer().named('pot_size_cm').nullable()();
  TextColumn get updatedHlc => text().named('updated_hlc')();
  IntColumn get deletedAt => integer().named('deleted_at').nullable()();
  TextColumn get deviceId => text().named('device_id')();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PhotoRow')
class Photos extends Table {
  // Primary key = content hash — photos are value-addressed, not id-addressed.
  TextColumn get sha256 => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  TextColumn get mime => text()();
  IntColumn get bytes => integer()();
  IntColumn get takenAt => integer().named('taken_at').nullable()();
  TextColumn get exifJson => text().named('exif_json').nullable()();
  TextColumn get localPath => text().named('local_path').nullable()();
  TextColumn get remoteState => text().named('remote_state').withDefault(const Constant('local'))();
  TextColumn get updatedHlc => text().named('updated_hlc')();
  IntColumn get deletedAt => integer().named('deleted_at').nullable()();
  TextColumn get deviceId => text().named('device_id')();

  @override
  Set<Column> get primaryKey => {sha256};
}

@DataClassName('PlantPhotoRow')
class PlantPhotos extends Table {
  // OR-Set semantics: presence = any add-op whose add_hlc is greater than
  // every remove-op for the same (plant, photo).
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get plantId => text().named('plant_id')();
  TextColumn get photoSha => text().named('photo_sha')();
  IntColumn get displayOrder => integer().named('display_order').withDefault(const Constant(0))();
  TextColumn get addedHlc => text().named('added_hlc')();
  TextColumn get removedHlc => text().named('removed_hlc').nullable()();
  TextColumn get deviceId => text().named('device_id')();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TagRow')
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get name => text()();
  TextColumn get color => text().nullable()();
  TextColumn get updatedHlc => text().named('updated_hlc')();
  IntColumn get deletedAt => integer().named('deleted_at').nullable()();
  TextColumn get deviceId => text().named('device_id')();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PlantTagRow')
class PlantTags extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get plantId => text().named('plant_id')();
  TextColumn get tagId => text().named('tag_id')();
  TextColumn get addedHlc => text().named('added_hlc')();
  TextColumn get removedHlc => text().named('removed_hlc').nullable()();
  TextColumn get deviceId => text().named('device_id')();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CareEventRow')
class CareEvents extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get plantId => text().named('plant_id')();
  TextColumn get type => text()();
  IntColumn get doneAt => integer().named('done_at')();
  TextColumn get notes => text().nullable()();
  TextColumn get dose => text().nullable()();
  TextColumn get product => text().nullable()();
  TextColumn get photoSha => text().named('photo_sha').nullable()();
  TextColumn get updatedHlc => text().named('updated_hlc')();
  IntColumn get deletedAt => integer().named('deleted_at').nullable()();
  TextColumn get deviceId => text().named('device_id')();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CareScheduleRow')
class CareSchedules extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get plantId => text().named('plant_id')();
  TextColumn get type => text()();
  RealColumn get baseIntervalDays => real().named('base_interval_days')();
  RealColumn get currentIntervalDays => real().named('current_interval_days')();
  IntColumn get lastDoneAt => integer().named('last_done_at').nullable()();
  IntColumn get nextDueAt => integer().named('next_due_at').nullable()();
  IntColumn get snoozeCount => integer().named('snooze_count').withDefault(const Constant(0))();
  TextColumn get recentEventsJson => text().named('recent_events_json').withDefault(const Constant('[]'))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get updatedHlc => text().named('updated_hlc')();
  IntColumn get deletedAt => integer().named('deleted_at').nullable()();
  TextColumn get deviceId => text().named('device_id')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['UNIQUE(tenant_id, plant_id, type)'];
}

@DataClassName('SyncOpRow')
class SyncOps extends Table {
  // The wire format: one row per (entity, entity_id, field, hlc). field='*'
  // for create (value_json is the whole row); field='__tombstone__' for
  // soft-delete. pushedAt tracks round-trip status.
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get entity => text()();
  TextColumn get entityId => text().named('entity_id')();
  TextColumn get field => text()();
  TextColumn get valueJson => text().named('value_json').nullable()();
  TextColumn get hlc => text()();
  TextColumn get deviceId => text().named('device_id')();
  IntColumn get pushedAt => integer().named('pushed_at').nullable()();
}

@DriftDatabase(tables: [
  Species,
  Locations,
  Plants,
  Photos,
  PlantPhotos,
  Tags,
  PlantTags,
  CareEvents,
  CareSchedules,
  SyncOps,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'plantly_inventory'));
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_plants_tenant ON plants(tenant_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_plants_location ON plants(tenant_id, location_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_plants_status ON plants(tenant_id, status)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_care_events_plant_done ON care_events(tenant_id, plant_id, done_at DESC)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_schedules_due ON care_schedules(tenant_id, enabled, next_due_at)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_sync_ops_tenant_pending ON sync_ops(tenant_id, pushed_at) WHERE pushed_at IS NULL',
          );
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_tags_tenant_name ON tags(tenant_id, name)',
          );
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_plant_photos_unique_add ON plant_photos(tenant_id, plant_id, photo_sha, added_hlc)',
          );
        },
      );
}
