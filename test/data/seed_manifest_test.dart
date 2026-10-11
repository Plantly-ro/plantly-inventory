import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/seed.dart';
import 'package:plantly_inventory/data/seed_manifest.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations_en.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations_ro.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Audit P1: the demo seed must never reach a real cloud collection. A
/// link drops the seed rows the user never touched — and keeps every one
/// they edited, cared for, photographed or filed somewhere.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const tenant = 'local';
  const device = 'dev-a';
  late AppDatabase db;
  late OpLogWriter opLog;
  late SharedPreferences prefs;
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    now = DateTime.utc(2026, 10, 1, 9);
    opLog = OpLogWriter(db: db, clock: HlcClock(deviceId: device, nowProvider: () => now), tenantId: tenant);
  });
  tearDown(() => db.close());

  Future<SeedDropReport> drop() => dropUntouchedSeed(db: db, tenant: tenant, prefs: prefs, deviceId: device);

  Future<List<PlantRow>> plants() => (db.select(db.plants)..where((p) => p.tenantId.equals(tenant))).get();
  Future<List<LocationRow>> locations() => (db.select(db.locations)..where((l) => l.tenantId.equals(tenant))).get();
  Future<int> opsCount() async => (await db.select(db.syncOps).get()).length;

  Future<String> userPlant(String nickname, {String? locationId}) async {
    final id = 'user-${nickname.hashCode}';
    final h = await opLog.recordCreate(
      entity: 'plants',
      entityId: id,
      value: {'id': id, 'nickname': nickname, 'status': 'alive', 'location_id': locationId},
    );
    await db.into(db.plants).insert(PlantsCompanion.insert(
          id: id,
          tenantId: tenant,
          nickname: nickname,
          status: 'alive',
          locationId: Value(locationId),
          updatedHlc: h.encode(),
          deviceId: device,
        ));
    return id;
  }

  Future<void> careEvent(String plantId) async {
    final h = await opLog.recordCreate(entity: 'care_events', entityId: 'ev-$plantId', value: {'id': 'ev-$plantId'});
    await db.into(db.careEvents).insert(CareEventsCompanion.insert(
          id: 'ev-$plantId',
          tenantId: tenant,
          plantId: plantId,
          type: 'water',
          doneAt: now.millisecondsSinceEpoch,
          updatedHlc: h.encode(),
          deviceId: device,
        ));
  }

  group('with the manifest (seeded by this build)', () {
    test('seedIfEmpty records its ops; an untouched seed is dropped whole — rows and ops', () async {
      await seedIfEmpty(db: db, opLog: opLog, l10n: AppLocalizationsEn(), prefs: prefs);
      expect(prefs.getString(kSeedManifestPrefKey), isNotNull);
      expect(await plants(), hasLength(8));
      expect(await locations(), hasLength(3));
      final report = await drop();
      expect(report.plants, hasLength(8));
      expect(report.locations, hasLength(3));
      expect(report.schedules, hasLength(8));
      expect(await plants(), isEmpty);
      expect(await locations(), isEmpty);
      expect(await db.select(db.careSchedules).get(), isEmpty);
      expect(await opsCount(), 0, reason: 'nothing of the seed is left to push');
      expect(await db.customSelect('SELECT * FROM plants_fts').get(), isEmpty);
    });

    test('touched seed rows stay: an edit, a care event, a moved-into location, a user child space', () async {
      await seedIfEmpty(db: db, opLog: opLog, l10n: AppLocalizationsEn(), prefs: prefs);
      now = now.add(const Duration(days: 3));
      final seeded = await plants();
      final byName = {for (final p in seeded) p.nickname: p};
      // Renamed.
      await opLog.recordFieldUpdate(entity: 'plants', entityId: byName['Snake plant']!.id, field: 'nickname', value: 'Sammy');
      // Cared for.
      await careEvent(byName['Calathea']!.id);
      // A user plant filed under the seeded "Balcony".
      final balcony = (await locations()).singleWhere((l) => l.name == 'Balcony');
      final mine = await userPlant('Tomato', locationId: balcony.id);

      final report = await drop();
      final left = {for (final p in await plants()) p.id};
      expect(left, containsAll([byName['Snake plant']!.id, byName['Calathea']!.id, mine]));
      expect(left, hasLength(3), reason: 'the 6 untouched demo plants go');
      expect(report.plants, hasLength(6));
      // Balcony holds a kept plant, so it and its parent Home stay; Living room goes.
      expect({for (final l in await locations()) l.name}, {'Home', 'Balcony'});
      // The kept plants keep their schedules and every op.
      final schedules = await db.select(db.careSchedules).get();
      expect(schedules.map((s) => s.plantId).toSet(), {byName['Snake plant']!.id, byName['Calathea']!.id});
    });

    test('a seed schedule the user edited keeps its plant', () async {
      await seedIfEmpty(db: db, opLog: opLog, l10n: AppLocalizationsEn(), prefs: prefs);
      final schedule = (await db.select(db.careSchedules).get()).first;
      await opLog.recordFieldUpdate(entity: 'care_schedules', entityId: schedule.id, field: 'base_interval_days', value: 9.0);
      await drop();
      expect((await plants()).map((p) => p.id), [schedule.plantId]);
    });

    test('a second seed pass (locations backfill) adds a range without swallowing user ops in between', () async {
      await seedIfEmpty(db: db, opLog: opLog, l10n: AppLocalizationsEn(), prefs: prefs);
      final seeded = await plants();
      await opLog.recordFieldUpdate(entity: 'plants', entityId: seeded.first.id, field: 'notes', value: 'mine now');
      // The user removed every location → the next boot backfills them.
      await db.delete(db.locations).go();
      await seedIfEmpty(db: db, opLog: opLog, l10n: AppLocalizationsEn(), prefs: prefs);
      await drop();
      expect((await plants()).map((p) => p.id), [seeded.first.id]);
      expect(await locations(), isEmpty);
    });
  });

  group('without the manifest (installs seeded by an older build)', () {
    test('recognises the first-launch burst by demo names (any locale) and drops it untouched', () async {
      await seedIfEmpty(db: db, opLog: opLog, l10n: AppLocalizationsRo());
      expect(prefs.getString(kSeedManifestPrefKey), isNull);
      final report = await drop();
      expect(report.plants, hasLength(8));
      expect(report.locations, hasLength(3));
      expect(await plants(), isEmpty);
      expect(await opsCount(), 0);
    });

    test('a user plant that merely shares a demo name, created later, is never dropped', () async {
      await seedIfEmpty(db: db, opLog: opLog, l10n: AppLocalizationsEn());
      now = now.add(const Duration(days: 1));
      final mine = await userPlant('Calathea');
      await drop();
      expect((await plants()).map((p) => p.id), [mine]);
    });

    test('a lone demo-named plant (no burst) is the user\'s', () async {
      final mine = await userPlant('Snake plant');
      final report = await drop();
      expect(report.isEmpty, isTrue);
      expect((await plants()).map((p) => p.id), [mine]);
    });

    test('a burst seeded by ANOTHER device (pulled rows) is not ours to drop', () async {
      await seedIfEmpty(db: db, opLog: opLog, l10n: AppLocalizationsEn());
      final report = await dropUntouchedSeed(db: db, tenant: tenant, prefs: prefs, deviceId: 'dev-other');
      expect(report.isEmpty, isTrue);
      expect(await plants(), hasLength(8));
    });
  });

  group('legacy fingerprint is all-or-nothing (review 2026-10-07: real plants were dropped)', () {
    test('no legacy path on web, after skip-seed, on a local-* tenant, or once a manifest exists', () async {
      await seedIfEmpty(db: db, opLog: opLog, l10n: AppLocalizationsEn());
      Future<bool> dropsAnything({bool web = false, String t = tenant}) async {
        // Read-only probe: run inside a transaction we roll back.
        var dropped = false;
        try {
          await db.transaction(() async {
            final r = await dropUntouchedSeed(db: db, tenant: t, prefs: prefs, deviceId: device, web: web);
            dropped = !r.isEmpty;
            throw _Rollback();
          });
        } on _Rollback {
          // expected
        }
        return dropped;
      }

      expect(await dropsAnything(), isTrue, reason: 'sanity: the full fingerprint matches');
      expect(await dropsAnything(web: true), isFalse);
      await prefs.setBool('plantly_skip_seed', true);
      expect(await dropsAnything(), isFalse);
      await prefs.remove('plantly_skip_seed');
      await db.customStatement("UPDATE plants SET tenant_id = 'local-x'");
      await db.customStatement("UPDATE sync_ops SET tenant_id = 'local-x'");
      expect(await dropsAnything(t: 'local-x'), isFalse);
      await db.customStatement("UPDATE plants SET tenant_id = 'local'");
      await db.customStatement("UPDATE sync_ops SET tenant_id = 'local'");
      // A manifest that does not cover these rows: the manifest is the only judge.
      await recordSeedOpRange(prefs, 100000, 100010);
      expect(await dropsAnything(), isFalse);
    });

    test('fewer than 6 demo plants in the burst → nothing dropped', () async {
      await seedIfEmpty(db: db, opLog: opLog, l10n: AppLocalizationsEn());
      final ids = [for (final p in await plants()) p.id].take(3).toList();
      for (final id in ids) {
        await db.customStatement("DELETE FROM sync_ops WHERE entity_id = '$id'");
        await db.customStatement("DELETE FROM care_schedules WHERE plant_id = '$id'");
        await db.customStatement("DELETE FROM plants WHERE id = '$id'");
      }
      expect((await drop()).isEmpty, isTrue);
      expect(await plants(), hasLength(5));
    });

    test('demo plants without the demo spaces (or with a reshaped tree) → nothing dropped', () async {
      await seedIfEmpty(db: db, opLog: opLog, l10n: AppLocalizationsEn());
      final room = (await locations()).singleWhere((l) => l.name == 'Living room');
      await db.customStatement("UPDATE locations SET parent_id = NULL WHERE id = '${room.id}'");
      expect((await drop()).isEmpty, isTrue);
      expect(await plants(), hasLength(8));
    });

    test('a schedule that is not the fixture one disqualifies its plant from the fingerprint', () async {
      await seedIfEmpty(db: db, opLog: opLog, l10n: AppLocalizationsEn());
      await db.customStatement('UPDATE care_schedules SET base_interval_days = 99');
      expect((await drop()).isEmpty, isTrue);
    });
  });

  test('other tenants are never touched', () async {
    final other = OpLogWriter(db: db, clock: opLog.clock, tenantId: 'col-1');
    await seedIfEmpty(db: db, opLog: other, l10n: AppLocalizationsEn(), prefs: prefs);
    final report = await drop();
    expect(report.isEmpty, isTrue);
    expect(await db.select(db.plants).get(), hasLength(8));
  });
}

class _Rollback implements Exception {}
