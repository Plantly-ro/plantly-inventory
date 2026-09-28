import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/seed.dart';
import 'package:plantly_inventory/data/seed_rekey.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations_en.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';

/// QA2 BUG-2 — demo seed plants used the fixture's literal ids (`bob`,
/// `snake`, …). Primary keys are `{id}` with no tenant component, so two
/// installs sharing a collection collided on them. Fresh seeds must be
/// ULIDs.
void main() {
  // package:ulid renders Crockford base32 in lower case (same as DeviceId / location ids).
  final ulid = RegExp(r'^[0-9A-HJKMNP-TV-Z]{26}$', caseSensitive: false);

  late AppDatabase db;
  late OpLogWriter opLog;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    opLog = OpLogWriter(db: db, clock: HlcClock(deviceId: 'test-device'), tenantId: 'local');
  });

  tearDown(() => db.close());

  test('fresh seed: every plant id is a ULID, none is a legacy literal id', () async {
    await seedIfEmpty(db: db, opLog: opLog, l10n: AppLocalizationsEn());

    final plants = await db.select(db.plants).get();
    expect(plants, hasLength(8));
    for (final p in plants) {
      expect(p.id, matches(ulid), reason: '${p.nickname} → ${p.id}');
      expect(kLegacySeedPlantIds, isNot(contains(p.id)));
    }
    expect(plants.map((p) => p.id).toSet(), hasLength(8), reason: 'ids are unique');
  });

  test('fresh seed: all 8 care schedules point at seeded plant ids', () async {
    await seedIfEmpty(db: db, opLog: opLog, l10n: AppLocalizationsEn());

    final plantIds = (await db.select(db.plants).get()).map((p) => p.id).toSet();
    final schedules = await db.select(db.careSchedules).get();
    expect(schedules, hasLength(8));
    for (final s in schedules) {
      expect(plantIds, contains(s.plantId), reason: 'schedule ${s.type} → ${s.plantId}');
      expect(s.plantId, matches(ulid));
    }
  });

  test('fresh seed: every pending `*` op keys on the row it created', () async {
    await seedIfEmpty(db: db, opLog: opLog, l10n: AppLocalizationsEn());

    final ops = await (db.select(db.syncOps)..where((o) => o.field.equals(kWholeRowField) & o.pushedAt.isNull())).get();
    expect(ops.where((o) => o.entity == 'plants'), hasLength(8));
    expect(ops.where((o) => o.entity == 'care_schedules'), hasLength(8));
    final plantIds = (await db.select(db.plants).get()).map((p) => p.id).toSet();
    final scheduleIds = (await db.select(db.careSchedules).get()).map((s) => s.id).toSet();
    for (final o in ops) {
      final payload = json.decode(o.valueJson!) as Map<String, dynamic>;
      expect(payload['id'], o.entityId, reason: '${o.entity}/${o.entityId}');
      if (o.entity == 'plants') {
        expect(plantIds, contains(o.entityId));
        expect(kLegacySeedPlantIds, isNot(contains(o.entityId)));
      } else if (o.entity == 'care_schedules') {
        expect(scheduleIds, contains(o.entityId));
        expect(plantIds, contains(payload['plant_id']), reason: 'schedule payload plant_id is a seeded ULID');
      }
    }
  });
}
