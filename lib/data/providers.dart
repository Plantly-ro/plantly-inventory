import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../sync/device_id.dart';
import '../sync/hlc.dart';
import '../sync/op_log.dart';
import 'database/app_database.dart';
import 'repositories/care_event_repository.dart';
import 'repositories/care_schedule_repository.dart';
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
  return AppContext(db: db, clock: clock, opLog: opLog, deviceId: deviceId);
});

final plantRepositoryProvider = Provider<PlantRepository>((ref) {
  final ctx = ref.watch(appContextProvider).requireValue;
  return PlantRepository(db: ctx.db, opLog: ctx.opLog);
});

final careScheduleRepositoryProvider = Provider<CareScheduleRepository>((ref) {
  final ctx = ref.watch(appContextProvider).requireValue;
  return CareScheduleRepository(db: ctx.db, opLog: ctx.opLog);
});

final careEventRepositoryProvider = Provider<CareEventRepository>((ref) {
  final ctx = ref.watch(appContextProvider).requireValue;
  return CareEventRepository(
    db: ctx.db,
    opLog: ctx.opLog,
    schedules: ref.watch(careScheduleRepositoryProvider),
  );
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

final locationsStreamProvider = StreamProvider<List<LocationRow>>((ref) {
  final repo = ref.watch(locationRepositoryProvider);
  return repo.watchAll();
});

/// Live stream of non-deleted plants.
final plantsStreamProvider = StreamProvider<List<PlantRow>>((ref) {
  final repo = ref.watch(plantRepositoryProvider);
  return repo.watchAll();
});
