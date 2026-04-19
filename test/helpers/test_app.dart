import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/mock_plants.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/notifications/notification_service.dart';
import 'package:plantly_inventory/sync/hlc.dart';

/// Widget-test helper: wraps the given widget in a `ProviderScope` whose
/// `databaseProvider` returns an in-memory Drift instance, and overrides
/// `plantsStreamProvider` with a single pre-canned list so Drift's stream
/// teardown (which schedules a zero-duration Timer) never leaks past the
/// widget-tree disposal.
Widget buildTestApp({
  required Widget child,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWith((ref) => AppDatabase.forTesting(NativeDatabase.memory())),
      plantsStreamProvider.overrideWith((ref) => Stream.value(_seedRows())),
      // Every Drift-backed StreamProvider needs a static override in tests,
      // otherwise the teardown Timer leaks past the widget tree. Add new
      // providers here as they get wired into widgets.
      dueBeforeEodProvider.overrideWith((ref) => Stream.value(const <CareScheduleRow>[])),
      locationsStreamProvider.overrideWith((ref) => Stream.value(const <LocationRow>[])),
      recentCareEventsProvider.overrideWith((ref) => Stream.value(const <CareEventRow>[])),
      allSchedulesProvider.overrideWith((ref) => Stream.value(const <CareScheduleRow>[])),
      // Swap the real flutter_local_notifications-backed service for a
      // no-op fake so bootstrap's unawaited `requestPermissions()` call
      // doesn't leave a Future pending past widget-tree disposal.
      notificationServiceProvider.overrideWith((ref) => FakeNotificationService()),
      // Family providers emit via Drift's `watch()` which leaves a Timer
      // pending past dispose. Return empty streams in tests.
      attachedPhotosProvider.overrideWith((ref, plantId) => Stream.value(const <String>[])),
      schedulesForPlantProvider.overrideWith((ref, plantId) => Stream.value(const <CareScheduleRow>[])),
      careEventsForPlantProvider.overrideWith((ref, plantId) => Stream.value(const <CareEventRow>[])),
      plantsByLocationProvider.overrideWith((ref, locationId) => Stream.value(const <PlantRow>[])),
      inventoryForPlantProvider.overrideWith((ref, plantId) => Stream.value(const <InventoryTransactionRow>[])),
      plantByIdProvider.overrideWith((ref, plantId) => Stream.value(null)),
      allTagsProvider.overrideWith((ref) => Stream.value(const <TagRow>[])),
      tagsForPlantProvider.overrideWith((ref, plantId) => Stream.value(const <String>[])),
      ...overrides,
    ],
    child: child,
  );
}

/// Materialize the mock fixtures as `PlantRow` instances so widgets that
/// consume the stream see the same seven plants the prototype shows.
List<PlantRow> _seedRows() {
  final clock = HlcClock(deviceId: 'test-device');
  return MockPlants.all
      .map((m) => PlantRow(
            id: m.id,
            tenantId: kDefaultTenantId,
            nickname: m.name,
            speciesId: null,
            locationId: null,
            status: 'alive',
            acquiredAt: null,
            source: null,
            notes: null,
            potSizeCm: null,
            updatedHlc: clock.now().encode(),
            deletedAt: null,
            deviceId: 'test-device',
          ))
      .toList();
}
