import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/features/home/filter.dart';
import 'package:plantly_inventory/sync/hlc.dart';

PlantRow _plant(String id, String name) {
  final h = HlcClock(deviceId: 't').now().encode();
  return PlantRow(
    id: id,
    tenantId: kDefaultTenantId,
    nickname: name,
    speciesId: null,
    locationId: null,
    pinX: null,
    pinY: null,
    notificationsMuted: false,
    status: 'alive',
    acquiredAt: null,
    source: null,
    notes: null,
    potSizeCm: null,
    updatedHlc: h,
    deletedAt: null,
    deviceId: 't',
  );
}

CareScheduleRow _sched(String id, String plantId, int dueAtMs) => CareScheduleRow(
      id: id,
      tenantId: kDefaultTenantId,
      plantId: plantId,
      type: 'water',
      baseIntervalDays: 7,
      currentIntervalDays: 7,
      lastDoneAt: null,
      nextDueAt: dueAtMs,
      snoozeCount: 0,
      recentEventsJson: '[]',
      enabled: true,
      recurrenceMode: 'after_completion',
      notificationsMuted: false,
      updatedHlc: '0-0-t',
      deletedAt: null,
      deviceId: 't',
    );

void main() {
  ProviderContainer make({
    required List<PlantRow> plants,
    required List<CareScheduleRow> schedules,
  }) {
    return ProviderContainer(overrides: [
      plantsStreamProvider.overrideWith((_) => Stream.value(plants)),
      dueBeforeEodProvider.overrideWith((_) => Stream.value(schedules)),
    ]);
  }

  test('filter=all returns every plant unchanged', () async {
    final c = make(plants: [_plant('a', 'A'), _plant('b', 'B')], schedules: []);
    addTearDown(c.dispose);
    await c.read(plantsStreamProvider.future);
    final result = c.read(filteredPlantsProvider);
    expect(result.requireValue.map((p) => p.id), ['a', 'b']);
  });

  test('filter=overdue keeps only plants with nextDueAt < now', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final c = make(
      plants: [_plant('a', 'A'), _plant('b', 'B')],
      schedules: [
        _sched('s1', 'a', now - 86400000),
        _sched('s2', 'b', now + 86400000),
      ],
    );
    addTearDown(c.dispose);
    c.read(activeFilterProvider.notifier).state = PlantFilter.overdue;
    await c.read(plantsStreamProvider.future);
    await c.read(dueBeforeEodProvider.future);
    final result = c.read(filteredPlantsProvider);
    expect(result.requireValue.map((p) => p.id), ['a']);
  });

  test('filter=dueToday keeps only plants with nextDueAt ≥ now', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final c = make(
      plants: [_plant('a', 'A'), _plant('b', 'B')],
      schedules: [
        _sched('s1', 'a', now - 86400000),
        _sched('s2', 'b', now + 60000),
      ],
    );
    addTearDown(c.dispose);
    c.read(activeFilterProvider.notifier).state = PlantFilter.dueToday;
    await c.read(plantsStreamProvider.future);
    await c.read(dueBeforeEodProvider.future);
    final result = c.read(filteredPlantsProvider);
    expect(result.requireValue.map((p) => p.id), ['b']);
  });

  // PlantFilter.label now resolves against BuildContext — see i18n_test.dart
  // for coverage of the locale-driven label strings.
}
