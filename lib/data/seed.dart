import '../sync/op_log.dart';
import 'database/app_database.dart';
import 'mock_plants.dart';

/// Populates an empty database with the prototype's fixture plants so the
/// app is immediately demonstrable on first launch. No-op once the plants
/// table has any rows.
Future<void> seedIfEmpty({
  required AppDatabase db,
  required OpLogWriter opLog,
}) async {
  final count = await db.managers.plants.count();
  if (count > 0) return;

  // Map from MockPlants data — keeps the names/ids consistent with what
  // every existing test and widget expects.
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
}
