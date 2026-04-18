import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/mock_plants.dart';
import 'package:plantly_inventory/data/providers.dart';
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
