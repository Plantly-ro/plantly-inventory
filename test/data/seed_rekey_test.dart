import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/seed_rekey.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// QA2 BUG-2 — installs seeded before the ULID seed hold plants keyed
/// `bob`, `snake`, … . `rekeyLegacySeedIds` gives them fresh ids once,
/// re-points every FK and every pending op, and tells peers of synced
/// tenants about it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // package:ulid renders Crockford base32 in lower case (same as DeviceId / location ids).
  final ulid = RegExp(r'^[0-9A-HJKMNP-TV-Z]{26}$', caseSensitive: false);
  String hlc(int ms, {String dev = 'dev-a'}) => Hlc(ms, 0, dev).encode();

  late AppDatabase db;
  late SharedPreferences prefs;
  late HlcClock clock;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    clock = HlcClock(deviceId: 'dev-a');
  });

  tearDown(() => db.close());

  Future<void> plant(String id, String tenant, {String nickname = 'Plant'}) => db.into(db.plants).insert(
        PlantsCompanion.insert(id: id, tenantId: tenant, nickname: nickname, status: 'alive', updatedHlc: hlc(10), deviceId: 'dev-0'),
      );

  Future<int> pendingOp(
    String tenant,
    String entity,
    String entityId,
    String field,
    Object? value, {
    int? pushedAt,
  }) =>
      db.into(db.syncOps).insert(SyncOpsCompanion.insert(
            tenantId: tenant,
            entity: entity,
            entityId: entityId,
            field: field,
            hlc: hlc(10),
            deviceId: 'dev-0',
            valueJson: Value(json.encode(value)),
            pushedAt: Value(pushedAt),
          ));

  Map<String, dynamic> plantPayload(String id) => {'id': id, 'nickname': 'Plant', 'status': 'alive', 'updated_hlc': hlc(10), 'device_id': 'dev-0'};

  /// The scenario from the brief: `bob` + `green` under `'local'` with a mix
  /// of pending and pushed ops; `snake` under `'col-1'` with one child row
  /// of every kind (plus a soft-deleted one that must be re-pointed but
  /// gets no op).
  late int pushedBobSeq;
  Future<void> seedLegacy() async {
    await plant('bob', 'local', nickname: 'Monstera "Bob"');
    await plant('green', 'local', nickname: 'Pothos "Green"');
    await db.into(db.careSchedules).insert(CareSchedulesCompanion.insert(
        id: 'cs-bob', tenantId: 'local', plantId: 'bob', type: 'water', baseIntervalDays: 7, currentIntervalDays: 7, updatedHlc: hlc(10), deviceId: 'dev-0'));
    await pendingOp('local', 'plants', 'bob', kWholeRowField, plantPayload('bob'));
    await pendingOp('local', 'plants', 'green', kWholeRowField, plantPayload('green'));
    await pendingOp('local', 'care_schedules', 'cs-bob', kWholeRowField, {'id': 'cs-bob', 'plant_id': 'bob', 'type': 'water'});
    await pendingOp('local', 'care_schedules', 'cs-bob', 'plant_id', 'bob');
    pushedBobSeq = await pendingOp('local', 'plants', 'bob', kWholeRowField, plantPayload('bob'), pushedAt: 42);

    await plant('snake', 'col-1', nickname: 'Snake plant');
    await db.into(db.careSchedules).insert(CareSchedulesCompanion.insert(
        id: 'cs-snake', tenantId: 'col-1', plantId: 'snake', type: 'water', baseIntervalDays: 14, currentIntervalDays: 14, updatedHlc: hlc(10), deviceId: 'dev-0'));
    await db.into(db.careEvents).insert(CareEventsCompanion.insert(
        id: 'ce-snake', tenantId: 'col-1', plantId: 'snake', type: 'water', doneAt: 1000, updatedHlc: hlc(10), deviceId: 'dev-0'));
    await db.into(db.careEvents).insert(CareEventsCompanion.insert(
        id: 'ce-snake-del', tenantId: 'col-1', plantId: 'snake', type: 'water', doneAt: 900, updatedHlc: hlc(10), deviceId: 'dev-0', deletedAt: const Value(950)));
    await db.into(db.plantPhotos).insert(PlantPhotosCompanion.insert(
        id: 'pp-snake', tenantId: 'col-1', plantId: 'snake', photoSha: 'sha-1', addedHlc: hlc(10), deviceId: 'dev-0'));
    await db.into(db.plantTags).insert(PlantTagsCompanion.insert(
        id: 'pt-snake', tenantId: 'col-1', plantId: 'snake', tagId: 'tag-1', addedHlc: hlc(10), deviceId: 'dev-0'));
    await db.into(db.inventoryTransactions).insert(InventoryTransactionsCompanion.insert(
        id: 'it-snake', tenantId: 'col-1', type: 'propagate', at: 1000, updatedHlc: hlc(10), deviceId: 'dev-0',
        parentPlantId: const Value('snake'), childPlantId: const Value('kid')));
  }

  Future<List<Map<String, Object?>>> rows(String sql, [List<Object> args = const []]) async =>
      (await db.customSelect(sql, variables: [for (final a in args) Variable(a)]).get()).map((r) => r.data).toList();

  Future<List<SyncOpRow>> opsOf(String tenant) => (db.select(db.syncOps)
        ..where((o) => o.tenantId.equals(tenant))
        ..orderBy([(o) => OrderingTerm.asc(o.seq)]))
      .get();

  Future<SeedRekeyReport> run() => rekeyLegacySeedIds(db: db, clock: clock, prefs: prefs);

  test('no literal ids remain; every FK column points at the new ids within its tenant', () async {
    await seedLegacy();
    final report = await run();

    expect(report.rekeyed.keys, unorderedEquals(['bob', 'green', 'snake']));
    for (final id in report.rekeyed.values) {
      expect(id, matches(ulid));
    }
    final plants = await db.select(db.plants).get();
    expect(plants.map((p) => p.id).toSet(), report.rekeyed.values.toSet());
    expect(plants.map((p) => p.id).where(kLegacySeedPlantIds.contains), isEmpty);
    expect(plants.firstWhere((p) => p.id == report.rekeyed['bob']).tenantId, 'local');
    expect(plants.firstWhere((p) => p.id == report.rekeyed['snake']).tenantId, 'col-1');
    expect(plants.firstWhere((p) => p.id == report.rekeyed['snake']).nickname, 'Snake plant');

    final bob = report.rekeyed['bob']!;
    final snake = report.rekeyed['snake']!;
    expect((await rows('SELECT plant_id, tenant_id FROM care_schedules WHERE id = ?', ['cs-bob'])).single, {'plant_id': bob, 'tenant_id': 'local'});
    expect((await rows('SELECT plant_id, tenant_id FROM care_schedules WHERE id = ?', ['cs-snake'])).single, {'plant_id': snake, 'tenant_id': 'col-1'});
    expect((await rows('SELECT plant_id FROM care_events WHERE id = ?', ['ce-snake'])).single['plant_id'], snake);
    expect((await rows('SELECT plant_id FROM care_events WHERE id = ?', ['ce-snake-del'])).single['plant_id'], snake, reason: 'deleted rows are re-pointed too');
    expect((await rows('SELECT plant_id FROM plant_photos WHERE id = ?', ['pp-snake'])).single['plant_id'], snake);
    expect((await rows('SELECT plant_id FROM plant_tags WHERE id = ?', ['pt-snake'])).single['plant_id'], snake);
    final it = (await rows('SELECT parent_plant_id, child_plant_id, plant_id FROM inventory_transactions WHERE id = ?', ['it-snake'])).single;
    expect(it, {'parent_plant_id': snake, 'child_plant_id': 'kid', 'plant_id': null});
    for (final t in ['care_schedules', 'care_events', 'plant_photos', 'plant_tags']) {
      expect(await rows("SELECT id FROM $t WHERE plant_id IN ('bob','green','snake')"), isEmpty, reason: t);
    }
  });

  test('plants_fts follows the re-key (new plant_id present, old gone)', () async {
    await seedLegacy();
    final report = await run();
    final fts = (await rows('SELECT plant_id, nickname FROM plants_fts')).map((r) => r['plant_id']).toSet();
    expect(fts, report.rekeyed.values.toSet());
    expect(fts.where(kLegacySeedPlantIds.contains), isEmpty);
    final hit = await rows("SELECT plant_id FROM plants_fts WHERE plants_fts MATCH 'Snake'");
    expect(hit.single['plant_id'], report.rekeyed['snake']);
  });

  test("'local' tenant: pending ops re-pointed (entity_id + payload), pushed op untouched, NO new ops", () async {
    await seedLegacy();
    final before = (await opsOf('local')).length;
    final report = await run();
    final bob = report.rekeyed['bob']!;
    final green = report.rekeyed['green']!;

    final ops = await opsOf('local');
    expect(ops, hasLength(before), reason: 'never-linked tenant emits nothing');
    expect(ops.where((o) => o.pushedAt == null).map((o) => o.entityId), isNot(anyElement(isIn(kLegacySeedPlantIds))));

    final bobStar = ops.where((o) => o.entity == 'plants' && o.pushedAt == null && o.entityId == bob).single;
    expect(json.decode(bobStar.valueJson!)['id'], bob);
    final greenStar = ops.where((o) => o.entity == 'plants' && o.pushedAt == null && o.entityId == green).single;
    expect(json.decode(greenStar.valueJson!)['id'], green);
    final csStar = ops.where((o) => o.entity == 'care_schedules' && o.field == kWholeRowField).single;
    expect(csStar.entityId, 'cs-bob');
    expect(json.decode(csStar.valueJson!)['plant_id'], bob);
    final csField = ops.where((o) => o.entity == 'care_schedules' && o.field == 'plant_id').single;
    expect(json.decode(csField.valueJson!), bob);

    final pushed = ops.where((o) => o.seq == pushedBobSeq).single;
    expect(pushed.entityId, 'bob', reason: 'already-pushed ops are history');
    expect(json.decode(pushed.valueJson!)['id'], 'bob');
    expect(pushed.pushedAt, 42);
  });

  test("'col-1' tenant: tombstone for the old id, `*` for the new one, one field op per re-pointed LIVE child", () async {
    await seedLegacy();
    final report = await run();
    final snake = report.rekeyed['snake']!;
    expect(report.opsEmitted, 7);

    final ops = await opsOf('col-1');
    expect(ops, hasLength(7));
    expect(ops.every((o) => o.pushedAt == null && o.deviceId == 'dev-a'), isTrue);

    expect(ops[0].entity, 'plants');
    expect(ops[0].entityId, 'snake');
    expect(ops[0].field, kTombstoneField);

    expect(ops[1].entity, 'plants');
    expect(ops[1].entityId, snake);
    expect(ops[1].field, kWholeRowField);
    final payload = json.decode(ops[1].valueJson!) as Map<String, dynamic>;
    expect(payload['id'], snake);
    expect(payload['nickname'], 'Snake plant');
    expect(payload.containsKey('tenant_id'), isFalse);
    expect(payload['updated_hlc'], ops[1].hlc);
    expect(payload['device_id'], 'dev-a');

    final fieldOps = {for (final o in ops.skip(2)) (o.entity, o.entityId, o.field): json.decode(o.valueJson!)};
    expect(fieldOps, {
      ('plant_photos', 'pp-snake', 'plant_id'): snake,
      ('plant_tags', 'pt-snake', 'plant_id'): snake,
      ('care_events', 'ce-snake', 'plant_id'): snake,
      ('care_schedules', 'cs-snake', 'plant_id'): snake,
      ('inventory_transactions', 'it-snake', 'parent_plant_id'): snake,
    });
    expect(fieldOps.keys.map((k) => k.$2), isNot(contains('ce-snake-del')), reason: 'deleted child rows get no op');

    // Row and its `*` op agree; child rows carry their field op's HLC.
    final row = await (db.select(db.plants)..where((p) => p.id.equals(snake))).getSingle();
    expect(row.updatedHlc, ops[1].hlc);
    expect(row.deviceId, 'dev-a');
    final cs = await (db.select(db.careSchedules)..where((s) => s.id.equals('cs-snake'))).getSingle();
    expect(cs.updatedHlc, ops.firstWhere((o) => o.entityId == 'cs-snake').hlc);
    final pt = await (db.select(db.plantTags)..where((s) => s.id.equals('pt-snake'))).getSingle();
    expect(pt.addedHlc, ops.firstWhere((o) => o.entityId == 'pt-snake').hlc);
    expect(pt.removedHlc, isNull);
  });

  test('done-pref is set; a second run is a no-op (empty report, op count unchanged)', () async {
    await seedLegacy();
    final first = await run();
    expect(first.isEmpty, isFalse);
    expect(prefs.getBool(kSeedRekeyDonePrefKey), isTrue);
    final ops = (await db.select(db.syncOps).get()).length;
    final plants = (await db.select(db.plants).get()).map((p) => p.id).toSet();

    final second = await run();
    expect(second.isEmpty, isTrue);
    expect(second.opsEmitted, 0);
    expect((await db.select(db.syncOps).get()).length, ops);
    expect((await db.select(db.plants).get()).map((p) => p.id).toSet(), plants);
  });

  test('pref already set → fast path: nothing happens even with literal ids present', () async {
    await seedLegacy();
    await prefs.setBool(kSeedRekeyDonePrefKey, true);
    final report = await run();
    expect(report.isEmpty, isTrue);
    expect((await db.select(db.plants).get()).map((p) => p.id), containsAll(['bob', 'green', 'snake']));
    expect(await opsOf('col-1'), isEmpty);
  });

  test('a fresh install (no literal ids) just sets the pref', () async {
    await plant('01HZZZZZZZZZZZZZZZZZZZZZZZ', 'local');
    final report = await run();
    expect(report.isEmpty, isTrue);
    expect(prefs.getBool(kSeedRekeyDonePrefKey), isTrue);
    expect(await db.select(db.syncOps).get(), isEmpty);
  });

  test('isSyncedTenant override decides which tenants emit ops', () async {
    await plant('fern', 'local-abc');
    final report = await rekeyLegacySeedIds(db: db, clock: clock, prefs: prefs, isSyncedTenant: (_) => true);
    expect(report.opsEmitted, 2, reason: 'tombstone + `*`, no children');
    expect((await opsOf('local-abc')).map((o) => o.field), [kTombstoneField, kWholeRowField]);
  });

  test("'local-…' tenants are treated as never linked by default", () async {
    await plant('fern', 'local-abc');
    final report = await run();
    expect(report.rekeyed.keys, ['fern']);
    expect(report.opsEmitted, 0);
  });

  group('replacement id', () {
    test('synced tenant: deterministic per (tenant, old id) so two devices converge on one row', () async {
      await plant('snake', 'col-1');
      final a = await run();
      final other = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(other.close);
      await other.into(other.plants).insert(
          PlantsCompanion.insert(id: 'snake', tenantId: 'col-1', nickname: 'x', status: 'alive', updatedHlc: hlc(10), deviceId: 'dev-9'));
      SharedPreferences.setMockInitialValues({});
      final b = await rekeyLegacySeedIds(db: other, clock: HlcClock(deviceId: 'dev-b'), prefs: await SharedPreferences.getInstance());

      expect(a.rekeyed['snake'], b.rekeyed['snake']);
      expect(a.rekeyed['snake'], deterministicSeedReplacementId('col-1', 'snake'));
      expect(a.rekeyed['snake'], matches(ulid));
      expect(deterministicSeedReplacementId('col-2', 'snake'), isNot(a.rekeyed['snake']), reason: 'another collection → another id');
    });

    test('local tenant: random, so two installs never pick the same id', () async {
      await plant('bob', 'local');
      final a = await run();
      final other = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(other.close);
      await other.into(other.plants).insert(
          PlantsCompanion.insert(id: 'bob', tenantId: 'local', nickname: 'x', status: 'alive', updatedHlc: hlc(10), deviceId: 'dev-9'));
      SharedPreferences.setMockInitialValues({});
      final b = await rekeyLegacySeedIds(db: other, clock: HlcClock(deviceId: 'dev-b'), prefs: await SharedPreferences.getInstance());
      expect(a.rekeyed['bob'], isNot(b.rekeyed['bob']));
    });

    test('deterministic id already present locally (peer re-keyed first) → falls back to a fresh id, no PK trip', () async {
      final taken = deterministicSeedReplacementId('col-1', 'snake');
      await plant(taken, 'col-1', nickname: 'from peer');
      await plant('snake', 'col-1');
      final report = await run();
      expect(report.rekeyed['snake'], isNot(taken));
      expect(report.rekeyed['snake'], matches(ulid));
      expect((await db.select(db.plants).get()).map((p) => p.id), unorderedEquals([taken, report.rekeyed['snake']]));
    });
  });
}
