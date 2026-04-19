import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../notifications/notification_service.dart';
import '../notifications/reminder_sync.dart';
import '../sync/device_id.dart';
import '../sync/hlc.dart';
import '../sync/op_log.dart';
import 'database/app_database.dart';
import 'repositories/care_event_repository.dart';
import 'repositories/care_schedule_repository.dart';
import 'repositories/inventory_transaction_repository.dart';
import 'repositories/location_repository.dart';
import 'repositories/photo_repository.dart';
import 'repositories/plant_repository.dart';
import 'repositories/search_repository.dart';
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
  // non-fatal — the user can deny and still use the rest of the app.
  unawaited(ref.read(notificationServiceProvider).requestPermissions().catchError((_) => false));
  return AppContext(db: db, clock: clock, opLog: opLog, deviceId: deviceId);
});

final plantRepositoryProvider = Provider<PlantRepository>((ref) {
  final ctx = ref.watch(appContextProvider).requireValue;
  return PlantRepository(db: ctx.db, opLog: ctx.opLog);
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final svc = LocalNotificationService();
  // Best-effort init — failures here shouldn't block the app opening.
  svc.init().catchError((_) {});
  return svc;
});

final reminderSyncProvider = Provider<ReminderSync>((ref) {
  final ctx = ref.watch(appContextProvider).requireValue;
  return ReminderSync(
    db: ctx.db,
    notifications: ref.watch(notificationServiceProvider),
    tenantId: ctx.opLog.tenantId,
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
  return LocationRepository(db: ctx.db, opLog: ctx.opLog);
});

final photoRepositoryProvider = Provider<PhotoRepository>((ref) {
  final ctx = ref.watch(appContextProvider).requireValue;
  return PhotoRepository(db: ctx.db, opLog: ctx.opLog);
});

final plantPhotoRepositoryProvider = Provider<PlantPhotoRepository>((ref) {
  final ctx = ref.watch(appContextProvider).requireValue;
  return PlantPhotoRepository(db: ctx.db, opLog: ctx.opLog);
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
