import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/services/backup_service.dart';
import '../domain/services/ical_export.dart';
import '../domain/services/reminder_engine.dart';
import '../domain/services/zip_backup_service.dart';
import '../notifications/dnd_settings.dart';
import '../notifications/notification_service.dart';
import '../notifications/platform_notification_service.dart';
import '../notifications/reminder_sync.dart';
import '../sync/device_id.dart';
import '../sync/hlc.dart';
import '../sync/op_log.dart';
import '../shared/care_type_labels.dart';
import 'care_types.dart';
import 'database/app_database.dart';
import 'photo_blob_store.dart';
import 'repositories/care_event_repository.dart';
import 'repositories/care_schedule_repository.dart';
import 'repositories/inventory_transaction_repository.dart';
import 'repositories/location_repository.dart';
import 'repositories/photo_repository.dart';
import 'repositories/plant_repository.dart';
import 'repositories/search_repository.dart';
import 'repositories/species_repository.dart';
import 'repositories/tag_repository.dart';
import 'seed.dart';

/// App-wide dependencies. Everything downstream of [appBootstrapProvider]
/// waits for the async bootstrap to finish so widgets can consume the
/// repos synchronously via [plantRepositoryProvider] etc.

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((_) {
  return SharedPreferences.getInstance();
});

/// Default tenant for the single-user Phase 1 app. PLAN.md reserves
/// tenant_id for Phase 4 household sharing; every synced row needs a value
/// now so the schema doesn't rewrite later.
const String kDefaultTenantId = 'local';

class AppContext {
  const AppContext({
    required this.db,
    required this.clock,
    required this.opLog,
    required this.deviceId,
  });
  final AppDatabase db;
  final HlcClock clock;
  final OpLogWriter opLog;
  final String deviceId;
}

final appContextProvider = FutureProvider<AppContext>((ref) async {
  final db = ref.watch(databaseProvider);
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  final deviceId = await DeviceId.load(prefs);
  final clock = HlcClock(deviceId: deviceId);
  final opLog = OpLogWriter(db: db, clock: clock, tenantId: kDefaultTenantId);
  await seedIfEmpty(db: db, opLog: opLog);
  // Ask once at bootstrap so reminders can fire from day 1. Failures are
  // non-fatal — the user can deny and still use the rest of the app; the
  // Me screen surfaces the result + a retry button.
  unawaited(ref
      .read(notificationServiceProvider)
      .requestPermissions()
      .then((ok) => ref.read(notificationPermissionProvider.notifier).state = ok)
      .catchError((_) {
    ref.read(notificationPermissionProvider.notifier).state = false;
    return false;
  }));
  return AppContext(db: db, clock: clock, opLog: opLog, deviceId: deviceId);
});

final plantRepositoryProvider = Provider<PlantRepository>((ref) {
  final ctx = ref.watch(appContextProvider).requireValue;
  return PlantRepository(db: ctx.db, opLog: ctx.opLog, reminderSync: ref.watch(reminderSyncProvider));
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final svc = createPlatformNotificationService();
  // Best-effort init — failures here shouldn't block the app opening.
  svc.init().catchError((_) {});
  // Keep the service's DND settings in sync with the prefs-backed
  // provider. ReminderSync's sync path reads `svc.dnd` directly so we
  // only have to propagate the value, not the whole provider tree.
  ref.listen<DndSettings>(dndSettingsProvider, (_, next) => svc.dnd = next, fireImmediately: true);
  return svc;
});

/// Tracks whether the OS notification permission is granted. Updated by
/// `requestPermissions` calls — `null` while the first request is in
/// flight. Observers (Me screen) can react to changes.
final notificationPermissionProvider = StateProvider<bool?>((ref) => null);

final backupServiceProvider = Provider<BackupService>((ref) {
  final ctx = ref.watch(appContextProvider).requireValue;
  return BackupService(db: ctx.db);
});

final zipBackupServiceProvider = Provider<ZipBackupService>((ref) {
  final ctx = ref.watch(appContextProvider).requireValue;
  return ZipBackupService(
    db: ctx.db,
    backup: BackupService(db: ctx.db),
    photos: ref.watch(photoBlobStoreProvider),
  );
});

/// Build ICS bytes for the next 30 days of reminders against the current DB.
final iCalFutureProvider = FutureProvider.autoDispose<String>((ref) async {
  final ctx = ref.watch(appContextProvider).requireValue;
  final schedules = await (ctx.db.select(ctx.db.careSchedules)
        ..where((s) =>
            s.tenantId.equals(ctx.opLog.tenantId) &
            s.deletedAt.isNull() &
            s.enabled.equals(true)))
      .get();
  final plants = await (ctx.db.select(ctx.db.plants)
        ..where((p) => p.tenantId.equals(ctx.opLog.tenantId) & p.deletedAt.isNull()))
      .get();
  final locations = await (ctx.db.select(ctx.db.locations)
        ..where((l) => l.tenantId.equals(ctx.opLog.tenantId) & l.deletedAt.isNull()))
      .get();
  final events = ReminderEngine.buildUpcoming(
    schedules: schedules,
    plantsById: {for (final p in plants) p.id: p},
    locationsById: {for (final l in locations) l.id: l},
    now: DateTime.now().toUtc(),
    typeLabel: (type) => careKeyVerb(appLocalizationsForPlatform(), ref.read(careTypesProvider), type),
  );
  return ICalExport.fromEvents(
    productId: '-//PlantlyInventory//Phase1//EN',
    events: events,
  );
});

final reminderSyncProvider = Provider<ReminderSync>((ref) {
  final ctx = ref.watch(appContextProvider).requireValue;
  return ReminderSync(
    db: ctx.db,
    notifications: ref.watch(notificationServiceProvider),
    tenantId: ctx.opLog.tenantId,
    mutedTypesSnapshot: () => ref.read(mutedCareTypesProvider),
    typeLabel: (type) => careKeyVerb(appLocalizationsForPlatform(), ref.read(careTypesProvider), type),
  );
});

final careScheduleRepositoryProvider = Provider<CareScheduleRepository>((ref) {
  final ctx = ref.watch(appContextProvider).requireValue;
  return CareScheduleRepository(
    db: ctx.db,
    opLog: ctx.opLog,
    reminderSync: ref.watch(reminderSyncProvider),
  );
});

final careEventRepositoryProvider = Provider<CareEventRepository>((ref) {
  final ctx = ref.watch(appContextProvider).requireValue;
  return CareEventRepository(
    db: ctx.db,
    opLog: ctx.opLog,
    schedules: ref.watch(careScheduleRepositoryProvider),
    reminderSync: ref.watch(reminderSyncProvider),
  );
});

/// Live care schedules for a single plant — drives Plant Detail's
/// "Upcoming Care" list, so users see real data and can tap Done/Snooze.
final schedulesForPlantProvider =
    StreamProvider.family<List<CareScheduleRow>, String>((ref, plantId) {
  return ref.watch(careScheduleRepositoryProvider).watchForPlant(plantId);
});

/// Recent care events for a plant — drives Plant Detail's Timeline.
final careEventsForPlantProvider =
    StreamProvider.family<List<CareEventRow>, String>((ref, plantId) {
  return ref.watch(careEventRepositoryProvider).watchForPlant(plantId);
});

/// Live single-plant row — lets Plant Detail read current nickname /
/// location / species without falling back to MockPlants.
final plantByIdProvider =
    StreamProvider.family<PlantRow?, String>((ref, plantId) {
  return ref.watch(plantRepositoryProvider).watchById(plantId);
});

/// Live single-location row by id. Used by Plant Detail header.
final locationByIdProvider =
    FutureProvider.family<LocationRow?, String>((ref, locationId) async {
  return ref.watch(locationRepositoryProvider).byId(locationId);
});

/// Plants currently assigned to a given location.
final plantsByLocationProvider =
    StreamProvider.family<List<PlantRow>, String>((ref, locationId) {
  return ref.watch(plantRepositoryProvider).watchByLocation(locationId);
});

/// Every non-deleted care event in the database, newest first. Feeds the
/// Home screen's Recent Activity widget + the "View all" activity screen.
/// Small app, small dataset — no pagination needed in Phase 1.
final recentCareEventsProvider = StreamProvider<List<CareEventRow>>((ref) {
  final ctx = ref.watch(appContextProvider).requireValue;
  return (ctx.db.select(ctx.db.careEvents)
        ..where((e) => e.tenantId.equals(ctx.opLog.tenantId) & e.deletedAt.isNull())
        ..orderBy([(e) => OrderingTerm(expression: e.doneAt, mode: OrderingMode.desc)]))
      .watch();
});

/// Every non-deleted schedule across every plant, ordered by next_due_at.
/// Feeds the Calendar's weekly pivot.
final allSchedulesProvider = StreamProvider<List<CareScheduleRow>>((ref) {
  final ctx = ref.watch(appContextProvider).requireValue;
  return (ctx.db.select(ctx.db.careSchedules)
        ..where((s) =>
            s.tenantId.equals(ctx.opLog.tenantId) &
            s.deletedAt.isNull() &
            s.enabled.equals(true) &
            s.nextDueAt.isNotNull())
        ..orderBy([(s) => OrderingTerm(expression: s.nextDueAt)]))
      .watch();
});

/// "Due today or earlier" — everything OverdueWidget + TodayWidget need.
final dueBeforeEodProvider = StreamProvider<List<CareScheduleRow>>((ref) {
  final repo = ref.watch(careScheduleRepositoryProvider);
  final now = DateTime.now();
  // End of the current local day (23:59:59.999) so "due today" reminders
  // surface even though the wall clock is mid-afternoon.
  final eod = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  return repo.watchDueBefore(eod.millisecondsSinceEpoch);
});

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  final ctx = ref.watch(appContextProvider).requireValue;
  return SearchRepository(db: ctx.db, tenantId: ctx.opLog.tenantId);
});

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  final ctx = ref.watch(appContextProvider).requireValue;
  return LocationRepository(db: ctx.db, opLog: ctx.opLog, reminderSync: ref.watch(reminderSyncProvider));
});

final photoRepositoryProvider = Provider<PhotoRepository>((ref) {
  final ctx = ref.watch(appContextProvider).requireValue;
  return PhotoRepository(db: ctx.db, opLog: ctx.opLog, store: ref.watch(photoBlobStoreProvider));
});

final plantPhotoRepositoryProvider = Provider<PlantPhotoRepository>((ref) {
  final ctx = ref.watch(appContextProvider).requireValue;
  return PlantPhotoRepository(db: ctx.db, opLog: ctx.opLog);
});

final locationPhotoRepositoryProvider = Provider<LocationPhotoRepository>((ref) {
  final ctx = ref.watch(appContextProvider).requireValue;
  return LocationPhotoRepository(db: ctx.db, opLog: ctx.opLog);
});

/// Live full-row attachments for a plant (caption + displayOrder + sha).
final plantPhotoRowsProvider =
    StreamProvider.family<List<PlantPhotoRow>, String>((ref, plantId) {
  return ref.watch(plantPhotoRepositoryProvider).watchAttachedRows(plantId);
});

/// Live attachments for a location.
final locationPhotosProvider =
    StreamProvider.family<List<LocationPhotoRow>, String>((ref, locationId) {
  return ref.watch(locationPhotoRepositoryProvider).watchAttached(locationId);
});

final tagRepositoryProvider = Provider<TagRepository>((ref) {
  final ctx = ref.watch(appContextProvider).requireValue;
  return TagRepository(db: ctx.db, opLog: ctx.opLog);
});

final plantTagRepositoryProvider = Provider<PlantTagRepository>((ref) {
  final ctx = ref.watch(appContextProvider).requireValue;
  return PlantTagRepository(db: ctx.db, opLog: ctx.opLog);
});

/// All tags in the tenant — for autocomplete on the tag chip input.
final allTagsProvider = StreamProvider<List<TagRow>>((ref) {
  return ref.watch(tagRepositoryProvider).watchAll();
});

/// Recently-used `product` values across every care event — feeds the
/// Log-event sheet's autocomplete so users don't re-type product names.
/// Dedup + trimmed; newest first, max 10.
final recentProductsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final ctx = ref.watch(appContextProvider).requireValue;
  final events = await (ctx.db.select(ctx.db.careEvents)
        ..where((e) =>
            e.tenantId.equals(ctx.opLog.tenantId) &
            e.deletedAt.isNull() &
            e.product.isNotNull())
        ..orderBy([(e) => OrderingTerm(expression: e.doneAt, mode: OrderingMode.desc)])
        ..limit(100))
      .get();
  final seen = <String>{};
  final out = <String>[];
  for (final e in events) {
    final p = e.product?.trim();
    if (p == null || p.isEmpty) continue;
    final key = p.toLowerCase();
    if (seen.add(key)) out.add(p);
    if (out.length >= 10) break;
  }
  return out;
});

/// Tag ids currently attached to a plant.
final tagsForPlantProvider =
    StreamProvider.family<List<String>, String>((ref, plantId) {
  return ref.watch(plantTagRepositoryProvider).watchAttached(plantId);
});

/// Live set of SHA-256 hashes currently attached to a given plant — drives
/// the Plant Detail hero + carousel.
final attachedPhotosProvider = StreamProvider.family<List<String>, String>((ref, plantId) {
  return ref.watch(plantPhotoRepositoryProvider).watchAttached(plantId);
});

final inventoryTransactionRepositoryProvider = Provider<InventoryTransactionRepository>((ref) {
  final ctx = ref.watch(appContextProvider).requireValue;
  return InventoryTransactionRepository(
    db: ctx.db,
    opLog: ctx.opLog,
    plants: PlantsTableForWrites(db: ctx.db, opLog: ctx.opLog),
    reminderSync: ref.watch(reminderSyncProvider),
  );
});

final inventoryForPlantProvider = StreamProvider.family<List<InventoryTransactionRow>, String>((ref, plantId) {
  return ref.watch(inventoryTransactionRepositoryProvider).watchForPlant(plantId);
});

final locationsStreamProvider = StreamProvider<List<LocationRow>>((ref) {
  final repo = ref.watch(locationRepositoryProvider);
  return repo.watchAll();
});

/// Live stream of non-deleted plants.
final plantsStreamProvider = StreamProvider<List<PlantRow>>((ref) {
  final repo = ref.watch(plantRepositoryProvider);
  return repo.watchAll();
});

final speciesRepositoryProvider = Provider<SpeciesRepository>((ref) {
  final ctx = ref.watch(appContextProvider).requireValue;
  return SpeciesRepository(db: ctx.db, opLog: ctx.opLog);
});

/// Human-readable species for a plant's `species_id` — the `species` row's
/// scientific name when one exists, else the legacy free-text value.
final speciesDisplayNameProvider = FutureProvider.family<String?, String>((ref, speciesIdOrName) {
  return ref.watch(speciesRepositoryProvider).displayName(speciesIdOrName);
});
