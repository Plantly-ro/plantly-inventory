import 'package:drift/drift.dart';
import 'package:ulid/ulid.dart';

import '../l10n/generated/app_localizations.dart';
import '../shared/care_type_labels.dart';
import '../sync/op_log.dart';
import 'database/app_database.dart';
import 'mock_plants.dart';
import 'repositories/care_schedule_repository.dart';
import 'repositories/location_repository.dart';

/// Localized display nickname for a seeded demo plant. Species / scientific
/// names stay as-is (they live on the decorative [MockPlant]); only the
/// common-name nicknames follow the device locale ("Snake plant" →
/// "Limba soacrei"). Unknown ids fall back to the fixture's English name.
String seedPlantName(AppLocalizations t, MockPlant mock) => switch (mock.id) {
      'bob' => t.seedPlantBob,
      'green' => t.seedPlantGreen,
      'snake' => t.seedPlantSnake,
      'cala' => t.seedPlantCala,
      'fid' => t.seedPlantFid,
      'fern' => t.seedPlantFern,
      'suc' => t.seedPlantSuc,
      'pete' => t.seedPlantPete,
      _ => mock.name,
    };

/// Populates an empty database with the prototype's fixture plants so the
/// app is immediately demonstrable on first launch. No-op once the plants
/// table has any rows.
///
/// Also seeds default care schedules that match the prototype's visual
/// state (Bob + Green overdue, Snake + Calathea + Fiddle due today,
/// everyone else on a forward schedule).
///
/// Runs once, outside the widget tree, so the demo names are resolved via
/// [appLocalizationsForPlatform] (the locale `MaterialApp` is about to
/// pick) unless a caller injects [l10n]. Existing installs are unaffected —
/// the seed is a no-op when data exists.
Future<void> seedIfEmpty({
  required AppDatabase db,
  required OpLogWriter opLog,
  AppLocalizations? l10n,
}) async {
  final t = l10n ?? appLocalizationsForPlatform();
  final locations = LocationRepository(db: db, opLog: opLog);

  // Seed a small location tree whenever the tenant has none — runs
  // independently of the plants seed so users upgrading from a build that
  // shipped before `locations` were seeded still get starter spaces.
  final locRows = await db.managers.locations
      .filter((l) => l.tenantId(opLog.tenantId) & l.deletedAt.isNull())
      .get();
  if (locRows.isEmpty) {
    final home = await locations.create(name: t.seedSpaceHome, kind: 'home');
    await locations.create(name: t.seedSpaceLivingRoom, kind: 'room', parentId: home.id);
    await locations.create(name: t.seedSpaceBalcony, kind: 'outdoor_bed', parentId: home.id, isOutdoor: true);
  }

  final count = await db.managers.plants.count();
  if (count > 0) return;

  final schedules = CareScheduleRepository(db: db, opLog: opLog);
  final now = DateTime.now().toUtc();
  // Anchor the mock data so Overdue/Today widgets match the prototype
  // regardless of wall-clock time.
  DateTime daysAgo(int n) => now.subtract(Duration(days: n));
  DateTime daysFromNow(int n) => now.add(Duration(days: n));

  // Row ids are fresh ULIDs, never the fixture's literal id (`bob`, `snake`,
  // …): every Drift primary key is `{id}` without a tenant component, so a
  // literal id seeded on two installs collides the moment one of them pulls
  // the other's rows through a shared collection (QA2 BUG-2). The fixture
  // id is only used to look up the localized name and the decorative swatch.
  final ids = {for (final mock in MockPlants.all) mock.id: Ulid().toString()};

  for (final mock in MockPlants.all) {
    final nickname = seedPlantName(t, mock);
    final id = ids[mock.id]!;
    await db.transaction(() async {
      final value = {
        'id': id,
        'tenant_id': opLog.tenantId,
        'nickname': nickname,
        'status': 'alive',
        'notes': null,
      };
      final hlc = await opLog.recordCreate(
        entity: 'plants',
        entityId: id,
        value: value,
      );
      await db.into(db.plants).insert(
            PlantsCompanion.insert(
              id: id,
              tenantId: opLog.tenantId,
              nickname: nickname,
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
    plantId: ids['bob']!,
    type: 'water',
    baseIntervalDays: waterIntervalDays,
    firstDueAt: daysAgo(2),
  );
  await schedules.upsert(
    plantId: ids['green']!,
    type: 'fertilize',
    baseIntervalDays: 30,
    firstDueAt: daysAgo(1),
  );
  await schedules.upsert(
    plantId: ids['snake']!,
    type: 'water',
    baseIntervalDays: 14,
    firstDueAt: now,
  );
  await schedules.upsert(
    plantId: ids['cala']!,
    type: 'mist',
    baseIntervalDays: 3,
    firstDueAt: now,
  );
  await schedules.upsert(
    plantId: ids['fid']!,
    type: 'rotate',
    baseIntervalDays: 7,
    firstDueAt: now,
  );
  await schedules.upsert(
    plantId: ids['fern']!,
    type: 'water',
    baseIntervalDays: 3,
    firstDueAt: daysFromNow(2),
  );
  await schedules.upsert(
    plantId: ids['suc']!,
    type: 'water',
    baseIntervalDays: 14,
    firstDueAt: daysFromNow(10),
  );
  await schedules.upsert(
    plantId: ids['pete']!,
    type: 'water',
    baseIntervalDays: 14,
    firstDueAt: daysFromNow(9),
  );
}
