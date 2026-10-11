import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/providers.dart' show kDefaultTenantId, kSkipSeedPrefKey;
import 'package:plantly_inventory/data/repositories/plant_repository.dart';
import 'package:plantly_inventory/data/seed.dart';
import 'package:plantly_inventory/domain/services/backup_service.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations_en.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android QA 2026-10-07 (b06): importing a backup into a fresh install
/// kept the 8 demo plants next to the restored ones. A restore replaces the
/// demo: untouched seed rows of the target tenant go first (same rules as a
/// collection link — `dropUntouchedSeed`), touched ones stay, and the seed
/// never comes back on this install.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secret = 'correct-horse-battery-staple';
  const tenant = kDefaultTenantId;

  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// A backup holding three of the user's own plants, made on another
  /// install (its own DB, no seed).
  Future<String> userBackup() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final opLog = OpLogWriter(db: db, clock: HlcClock(deviceId: 'old-phone'), tenantId: tenant);
    final repo = PlantRepository(db: db, opLog: opLog);
    for (final n in ['Monstera', 'Pothos', 'Aloe']) {
      await repo.create(nickname: n);
    }
    return BackupService(db: db, tenantId: tenant).export(secret: secret);
  }

  /// A fresh install: the demo seed on the default tenant, with manifest.
  Future<(AppDatabase, OpLogWriter, BackupService)> freshInstall() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final opLog = OpLogWriter(db: db, clock: HlcClock(deviceId: 'new-phone'), tenantId: tenant);
    await seedIfEmpty(db: db, opLog: opLog, l10n: AppLocalizationsEn(), prefs: prefs);
    return (db, opLog, BackupService(db: db, tenantId: tenant));
  }

  Future<Set<String>> nicknames(AppDatabase db) async =>
      {for (final p in await (db.select(db.plants)..where((p) => p.deletedAt.isNull())).get()) p.nickname};

  test('restoring into a fresh install replaces the untouched demo plants and spaces', () async {
    final blob = await userBackup();
    final (db, opLog, service) = await freshInstall();
    expect(await nicknames(db), hasLength(8));

    await service.import(blob: blob, secret: secret, opLog: opLog);

    expect(await nicknames(db), {'Monstera', 'Pothos', 'Aloe'});
    expect(await db.select(db.locations).get(), isEmpty, reason: 'the demo spaces go too');
    expect(await db.select(db.careSchedules).get(), isEmpty, reason: 'and the demo schedules');
    expect(prefs.getBool(kSkipSeedPrefKey), isTrue, reason: 'the demo must not come back on the next boot');
  });

  test('a demo plant the user touched survives the restore', () async {
    final blob = await userBackup();
    final (db, opLog, service) = await freshInstall();
    final snake = (await db.select(db.plants).get()).singleWhere((p) => p.nickname == 'Snake plant');
    await opLog.recordFieldUpdate(entity: 'plants', entityId: snake.id, field: 'notes', value: 'mine now');

    await service.import(blob: blob, secret: secret, opLog: opLog);

    expect(await nicknames(db), {'Snake plant', 'Monstera', 'Pothos', 'Aloe'});
  });

  test('a rejected backup (wrong passphrase) leaves the demo alone', () async {
    final blob = await userBackup();
    final (db, opLog, service) = await freshInstall();

    await expectLater(
      service.import(blob: blob, secret: 'wrong', opLog: opLog),
      throwsA(isA<BackupSignatureError>()),
    );

    expect(await nicknames(db), hasLength(8));
    expect(prefs.getBool(kSkipSeedPrefKey), isNot(isTrue));
  });

  test('a collection tenant is never pruned (its rows are pushed; no tombstone-less deletes)', () async {
    final blob = await userBackup();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    // Seed rows that somehow live in a collection tenant with a manifest
    // still around: a restore must not hard-delete them.
    final opLog = OpLogWriter(db: db, clock: HlcClock(deviceId: 'new-phone'), tenantId: 'col-123');
    await seedIfEmpty(db: db, opLog: opLog, l10n: AppLocalizationsEn(), prefs: prefs);
    final service = BackupService(db: db, tenantId: 'col-123');

    await service.import(blob: blob, secret: secret, opLog: opLog);

    expect(await nicknames(db), hasLength(11));
  });
}
