import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/care_types.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/data/repositories/care_schedule_repository.dart';
import 'package:plantly_inventory/data/repositories/plant_repository.dart';
import 'package:plantly_inventory/domain/services/backup_service.dart';
import 'package:plantly_inventory/features/me/backup_actions.dart';
import 'package:plantly_inventory/notifications/notification_service.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android QA 2026-10-07: custom care types restored from a backup only
/// showed up after an app restart — the import wrote SharedPreferences
/// behind the registry's back. They must appear at once, and the restored
/// reminders must be titled with their custom label, not the raw key.
/// End-to-end through the app's providers, which also covers the demo seed
/// a fresh install boots with (QA b06).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secret = 'hunter2';
  const neem = CareType(key: 'neem_spray', label: 'Neem spray', iconCode: 0, defaultIntervalDays: 14);

  /// A backup from another install: one plant with a reminder of the
  /// custom "Neem spray" type, and that type in the registry snapshot.
  Future<Uint8List> backupWithCustomType() async {
    SharedPreferences.setMockInitialValues({
      'plantly_care_types': json.encode([for (final t in [...kBuiltInCareTypes, neem]) t.toJson()]),
    });
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final opLog = OpLogWriter(db: db, clock: HlcClock(deviceId: 'old-phone'), tenantId: kDefaultTenantId);
    final plant = await PlantRepository(db: db, opLog: opLog).create(nickname: 'Bob');
    await CareScheduleRepository(db: db, opLog: opLog).upsert(
      plantId: plant.id,
      type: 'neem_spray',
      baseIntervalDays: 14,
      firstDueAt: DateTime.now().toUtc().add(const Duration(days: 2)),
    );
    final blob = await BackupService(db: db, tenantId: kDefaultTenantId).export(secret: secret);
    return BackupService.encodeBlob(blob);
  }

  test('restored custom care types are live at once and title the restored reminders', () async {
    final bytes = await backupWithCustomType();

    // Fresh install.
    SharedPreferences.setMockInitialValues({'plantly_onboarded': true});
    final fake = FakeNotificationService();
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        ref.onDispose(db.close);
        return db;
      }),
      notificationServiceProvider.overrideWith((ref) => fake),
    ]);
    addTearDown(container.dispose);
    final ctx = await container.read(appContextProvider.future);
    container.read(careTypesProvider);
    for (var i = 0; i < 5; i++) {
      await pumpEventQueue();
    }
    expect(container.read(careTypesProvider).map((t) => t.key), isNot(contains('neem_spray')));

    await container.read(backupActionsProvider).importBackup(fileName: 'b.json', bytes: bytes, secret: secret);

    expect(container.read(careTypesProvider).map((t) => t.label), contains('Neem spray'));
    final titles = [for (final c in fake.calls) c.event.summary];
    expect(titles, contains('Neem spray — Bob'));
    expect(titles, isNot(contains('Neem_spray — Bob')));

    // And the 8 demo plants of the fresh install made way for the backup.
    final plants = await ctx.db.select(ctx.db.plants).get();
    expect(plants.map((p) => p.nickname), ['Bob']);
  });
}
