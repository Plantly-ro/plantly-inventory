import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/seed_manifest.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Review 2026-10-07 (link-wipe): the legacy burst heuristic applies to
/// tenants that were NEVER seeded (web, "Start empty", skip-seed installs).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('REVIEW: never-seeded tenant — two real plants with common species names added 10 s apart must survive', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    var now = DateTime.utc(2026, 10, 7, 9);
    final opLog = OpLogWriter(db: db, clock: HlcClock(deviceId: 'web-dev', nowProvider: () => now), tenantId: 'local');

    Future<void> add(String id, String nickname) async {
      final h = await opLog.recordCreate(entity: 'plants', entityId: id, value: {'id': id, 'nickname': nickname, 'status': 'alive'});
      await db.into(db.plants).insert(PlantsCompanion.insert(
            id: id, tenantId: 'local', nickname: nickname, status: 'alive', updatedHlc: h.encode(), deviceId: 'web-dev'));
    }

    // A web user (no seed ever) types two plants before Me → Cloud links.
    await add('p1', 'Calathea');
    now = now.add(const Duration(seconds: 10));
    await add('p2', 'Snake plant');

    final report = await dropUntouchedSeed(db: db, tenant: 'local', prefs: prefs, deviceId: 'web-dev');
    // Regression test for the review finding: FAILS on the reviewed diff
    // (both user plants are hard-deleted) — must pass once fixed.
    expect(report.isEmpty, isTrue, reason: 'never-seeded tenant: nothing is demo data');
    expect(await db.select(db.plants).get(), hasLength(2));
  });
}
