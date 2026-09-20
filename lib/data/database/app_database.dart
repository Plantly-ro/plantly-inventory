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
  TextColumn get notes => text().nullable()();
  /// SHA-256 of a user-supplied image used as a "room layout" map for
  /// positioning plant pins. Lives in the same content-addressed
  /// `photos` store as plant photos — share the infrastructure.
  TextColumn get mapPhotoSha => text().named('map_photo_sha').nullable()();
  /// If true, every schedule whose plant sits in this location stops
  /// firing OS notifications. Does not affect the in-app reminder UI.
  BoolColumn get notificationsMuted =>
      boolean().named('notifications_muted').withDefault(const Constant(false))();
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
  /// Pin coordinates on the current location's `map_photo_sha`, stored
  /// as fractions 0..1 relative to the map image so the pin stays put
  /// if the user re-exports the map at a different resolution. Null
  /// when the plant isn't placed.
  RealColumn get pinX => real().named('pin_x').nullable()();
  RealColumn get pinY => real().named('pin_y').nullable()();
  /// Per-plant notification mute (applies to every schedule for this
  /// plant). Users can also mute per-schedule — see `care_schedules`.
  BoolColumn get notificationsMuted =>
      boolean().named('notifications_muted').withDefault(const Constant(false))();
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
  /// Optional free-form annotation for this attachment — e.g. "yellow
  /// leaf Apr 18". Stored per-attachment, not per-SHA, so the same
  /// photo attached to two plants can carry different captions.
  TextColumn get caption => text().nullable()();
  /// User-visible "date this photo was taken/added" — display-only metadata
  /// distinct from [addedHlc] (which is load-bearing for OR-set merge).
  /// Nullable; when null, the UI falls back to the physicalMs component of
  /// [addedHlc]. Editing this does not perturb CRDT ordering.
  IntColumn get capturedAt => integer().named('captured_at').nullable()();
  IntColumn get displayOrder => integer().named('display_order').withDefault(const Constant(0))();
  TextColumn get addedHlc => text().named('added_hlc')();
  TextColumn get removedHlc => text().named('removed_hlc').nullable()();
  TextColumn get deviceId => text().named('device_id')();

  @override
  Set<Column> get primaryKey => {id};
}

/// Photo attachments for a location (room layout, ambient shots,
/// before/after comparisons). Same OR-set semantics as `plant_photos`;
/// separate table so the two features evolve independently.
@DataClassName('LocationPhotoRow')
class LocationPhotos extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get locationId => text().named('location_id')();
  TextColumn get photoSha => text().named('photo_sha')();
  TextColumn get caption => text().nullable()();
  IntColumn get capturedAt => integer().named('captured_at').nullable()();
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
  /// How the schedule advances after a care event:
  ///   'after_completion' — `next_due_at = doneAt + currentIntervalDays`
  ///   'fixed'            — `next_due_at = anchor + N × interval` for
  ///                        smallest N making next_due_at > doneAt
  ///   'once'             — disable the schedule after the first event
  TextColumn get recurrenceMode =>
      text().named('recurrence_mode').withDefault(const Constant('after_completion'))();
  /// Suppresses OS notifications for just this schedule (e.g. mute the
  /// weekly fertilize reminder but keep the daily mist reminder firing).
  /// The schedule still shows up on Home / Calendar / Upcoming Care.
  BoolColumn get notificationsMuted =>
      boolean().named('notifications_muted').withDefault(const Constant(false))();
  TextColumn get updatedHlc => text().named('updated_hlc')();
  IntColumn get deletedAt => integer().named('deleted_at').nullable()();
  TextColumn get deviceId => text().named('device_id')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['UNIQUE(tenant_id, plant_id, type)'];
}

@DataClassName('InventoryTransactionRow')
class InventoryTransactions extends Table {
  // PLAN.md §"Schema non-negotiables": records plant-lifecycle transitions
  // including propagation (parent → child), gift, sale, death. `type`
  // decides which of parent_plant_id / child_plant_id / plant_id is set.
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get type => text()();
  TextColumn get parentPlantId => text().named('parent_plant_id').nullable()();
  TextColumn get childPlantId => text().named('child_plant_id').nullable()();
  TextColumn get plantId => text().named('plant_id').nullable()();
  TextColumn get counterparty => text().nullable()();
  IntColumn get at => integer()();
  TextColumn get notes => text().nullable()();
  IntColumn get amountMinor => integer().named('amount_minor').nullable()();
  TextColumn get currency => text().nullable()();
  TextColumn get updatedHlc => text().named('updated_hlc')();
  IntColumn get deletedAt => integer().named('deleted_at').nullable()();
  TextColumn get deviceId => text().named('device_id')();

  @override
  Set<Column> get primaryKey => {id};
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
  LocationPhotos,
  Tags,
  PlantTags,
  CareEvents,
  CareSchedules,
  InventoryTransactions,
  SyncOps,
])
class AppDatabase extends _$AppDatabase {
  /// io: sqlite file in the app's data dir. Web: sqlite3.wasm + the drift
  /// worker committed under `web/` (see tool/fetch_web_sqlite.sh), persisted
  /// to OPFS when the page is cross-origin isolated, IndexedDB otherwise.
  /// `driftDatabase` throws synchronously on web without these options.
  AppDatabase()
      : super(driftDatabase(
          name: 'plantly_inventory',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ));
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createIndexes();
          await _createPlantsFts();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await _createPlantsFts();
          }
          if (from < 3) {
            await m.createTable(inventoryTransactions);
          }
          if (from < 4) {
            await m.addColumn(careSchedules, careSchedules.recurrenceMode);
          }
          if (from < 5) {
            // Location expansion + pins + per-row mute flags.
            await m.addColumn(locations, locations.notes);
            await m.addColumn(locations, locations.mapPhotoSha);
            await m.addColumn(locations, locations.notificationsMuted);
            await m.addColumn(plants, plants.pinX);
            await m.addColumn(plants, plants.pinY);
            await m.addColumn(plants, plants.notificationsMuted);
            await m.addColumn(careSchedules, careSchedules.notificationsMuted);
          }
          if (from < 6) {
            // Photo annotations + location photo gallery.
            await m.addColumn(plantPhotos, plantPhotos.caption);
            await m.createTable(locationPhotos);
          }
          if (from < 7) {
            // User-editable capture date per photo attachment.
            await m.addColumn(plantPhotos, plantPhotos.capturedAt);
            await m.addColumn(locationPhotos, locationPhotos.capturedAt);
          }
        },
      );

  Future<void> _createIndexes() async {
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
  }

  /// FTS5 virtual table over plants (PLAN.md §"Schema non-negotiables"). The
  /// full schema eventually joins species/tags/locations; Phase 1 indexes
  /// nickname + notes. Triggers keep the FTS table in sync with plants.
  ///
  /// tokenize = 'unicode61 remove_diacritics 2' — Romanian plant names with
  /// diacritics (ă, â, î, ș, ț) match their ASCII-folded counterparts.
  Future<void> _createPlantsFts() async {
    await customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS plants_fts USING fts5(
        plant_id UNINDEXED,
        tenant_id UNINDEXED,
        nickname,
        notes,
        tokenize = 'unicode61 remove_diacritics 2'
      )
    ''');

    // Backfill from existing rows (harmless when empty).
    await customStatement('''
      INSERT INTO plants_fts(plant_id, tenant_id, nickname, notes)
      SELECT id, tenant_id, nickname, COALESCE(notes, '') FROM plants
      WHERE deleted_at IS NULL
    ''');

    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS plants_fts_ai AFTER INSERT ON plants BEGIN
        INSERT INTO plants_fts(plant_id, tenant_id, nickname, notes)
        VALUES (new.id, new.tenant_id, new.nickname, COALESCE(new.notes, ''));
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS plants_fts_ad AFTER DELETE ON plants BEGIN
        DELETE FROM plants_fts WHERE plant_id = old.id;
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS plants_fts_au AFTER UPDATE ON plants BEGIN
        DELETE FROM plants_fts WHERE plant_id = old.id;
        INSERT INTO plants_fts(plant_id, tenant_id, nickname, notes)
        SELECT new.id, new.tenant_id, new.nickname, COALESCE(new.notes, '')
        WHERE new.deleted_at IS NULL;
      END
    ''');
  }
}
