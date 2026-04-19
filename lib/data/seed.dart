import 'package:drift/drift.dart';

import '../sync/op_log.dart';
import 'database/app_database.dart';
import 'mock_plants.dart';
import 'repositories/care_schedule_repository.dart';
import 'repositories/location_repository.dart';

/// Populates an empty database with the prototype's fixture plants so the
/// app is immediately demonstrable on first launch. No-op once the plants
/// table has any rows.
///
/// Also seeds default care schedules that match the prototype's visual
/// state (Bob + Green overdue, Snake + Calathea + Fiddle due today,
/// everyone else on a forward schedule).
Future<void> seedIfEmpty({
  required AppDatabase db,
  required OpLogWriter opLog,
}) async {
  final locations = LocationRepository(db: db, opLog: opLog);

  // Seed a small location tree whenever the tenant has none — runs
  // independently of the plants seed so users upgrading from a build that
  // shipped before `locations` were seeded still get starter spaces.
  final locRows = await db.managers.locations
      .filter((l) => l.tenantId(opLog.tenantId) & l.deletedAt.isNull())
      .get();
  if (locRows.isEmpty) {
    final home = await locations.create(name: 'Home', kind: 'home');
    await locations.create(name: 'Living room', kind: 'room', parentId: home.id);
    await locations.create(name: 'Balcony', kind: 'outdoor_bed', parentId: home.id, isOutdoor: true);
  }

  final count = await db.managers.plants.count();
  if (count > 0) return;

  final schedules = CareScheduleRepository(db: db, opLog: opLog);
  final now = DateTime.now().toUtc();
  // Anchor the mock data so Overdue/Today widgets match the prototype
  // regardless of wall-clock time.
  DateTime daysAgo(int n) => now.subtract(Duration(days: n));
  DateTime daysFromNow(int n) => now.add(Duration(days: n));

  for (final mock in MockPlants.all) {
    await db.transaction(() async {
      final value = {
        'id': mock.id,
        'tenant_id': opLog.tenantId,
        'nickname': mock.name,
        'status': 'alive',
        'notes': null,
      };
      final hlc = await opLog.recordCreate(
        entity: 'plants',
        entityId: mock.id,
        value: value,
      );
      await db.into(db.plants).insert(
            PlantsCompanion.insert(
              id: mock.id,
              tenantId: opLog.tenantId,
              nickname: mock.name,
              status: 'alive',
              updatedHlc: hlc.encode(),
              deviceId: opLog.clock.deviceId,
            ),
          );
    });
  }

  // Matches prototype: Bob + Green are overdue waterers, today group is
  // Snake/Calathea/Fiddle, grid's remaining plants ok (not due yet).
  const waterIntervalDays = 7.0;
  await schedules.upsert(
    plantId: 'bob',
    type: 'water',
    baseIntervalDays: waterIntervalDays,
    firstDueAt: daysAgo(2),
  );
  await schedules.upsert(
    plantId: 'green',
    type: 'fertilize',
    baseIntervalDays: 30,
    firstDueAt: daysAgo(1),
  );
  await schedules.upsert(
    plantId: 'snake',
    type: 'water',
    baseIntervalDays: 14,
    firstDueAt: now,
  );
  await schedules.upsert(
    plantId: 'cala',
    type: 'mist',
    baseIntervalDays: 3,
    firstDueAt: now,
  );
  await schedules.upsert(
    plantId: 'fid',
    type: 'rotate',
    baseIntervalDays: 7,
    firstDueAt: now,
  );
  await schedules.upsert(
    plantId: 'fern',
    type: 'water',
    baseIntervalDays: 3,
    firstDueAt: daysFromNow(2),
  );
  await schedules.upsert(
    plantId: 'suc',
    type: 'water',
    baseIntervalDays: 14,
    firstDueAt: daysFromNow(10),
  );
  await schedules.upsert(
    plantId: 'pete',
    type: 'water',
    baseIntervalDays: 14,
    firstDueAt: daysFromNow(9),
  );
}
