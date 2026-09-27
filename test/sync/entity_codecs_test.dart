import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/sync/entity_codecs.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';

void main() {
  late AppDatabase db;
  late EntityCodecs codecs;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    codecs = EntityCodecs(db);
  });
  tearDown(() => db.close());

  const hlc = '00001700000000000-00000-dev-a';

  Future<Map<String, Object?>> readRow(String table, String idCol, String id) async {
    final r = await db.customSelect('SELECT * FROM $table WHERE $idCol = ?', variables: [Variable(id)]).getSingle();
    return r.data;
  }

  test('registry covers the eleven contract entities in order', () {
    expect(EntityCodecs.entities, [
      'species',
      'locations',
      'plants',
      'photos',
      'plant_photos',
      'location_photos',
      'tags',
      'plant_tags',
      'care_events',
      'care_schedules',
      'inventory_transactions',
    ]);
    for (final e in EntityCodecs.entities) {
      expect(codecs.forEntity(e), isNotNull, reason: e);
    }
    expect(codecs.forEntity('nope'), isNull);
  });

  test('plants: canonical `*` JSON (the shape other clients must match)', () {
    final c = codecs.forEntity('plants')!;
    final wire = c.canonicalRow(
      {
        'id': 'p1',
        'tenant_id': 'local',
        'nickname': 'Bob',
        'species_id': null,
        'location_id': 'l1',
        'status': 'active',
        'acquired_at': 1700000000000,
        'source': null,
        'notes': 'hi',
        'pot_size_cm': 12,
      },
      hlc: hlc,
      deviceId: 'dev-a',
    );
    expect(json.decode(json.encode(wire)), {
      'id': 'p1',
      'nickname': 'Bob',
      'species_id': null,
      'location_id': 'l1',
      'pin_x': null,
      'pin_y': null,
      'notifications_muted': false,
      'status': 'active',
      'acquired_at': '2023-11-14T22:13:20.000Z',
      'source': null,
      'notes': 'hi',
      'pot_size_cm': 12,
      'updated_hlc': hlc,
      'deleted_at': null,
      'device_id': 'dev-a',
    });
    expect(wire.containsKey('tenant_id'), isFalse);
  });

  test('photos: local_path / remote_state never travel; taken_at is ISO', () {
    final c = codecs.forEntity('photos')!;
    final wire = c.canonicalRow(
      {'sha256': 'abc', 'mime': 'image/jpeg', 'bytes': 10, 'taken_at': 0, 'local_path': '/x', 'remote_state': 'local'},
      hlc: hlc,
      deviceId: 'dev-a',
    );
    expect(wire.keys, isNot(contains('local_path')));
    expect(wire.keys, isNot(contains('remote_state')));
    expect(wire['taken_at'], '1970-01-01T00:00:00.000Z');
    expect(wire['bytes'], 10);
  });

  test('decodeField is lenient: ISO or millis for timestamps, 0/1 or bool for booleans', () {
    final c = codecs.forEntity('plants')!;
    expect(c.decodeField('acquired_at', '2023-11-14T22:13:20.000Z'), 1700000000000);
    expect(c.decodeField('acquired_at', '2023-11-15T00:13:20.000+02:00'), 1700000000000);
    expect(c.decodeField('acquired_at', 1700000000000), 1700000000000);
    expect(c.decodeField('notifications_muted', 1), true);
    expect(c.decodeField('notifications_muted', false), false);
    expect(c.decodeField('pot_size_cm', 12.0), 12);
    expect(c.decodeField('pin_x', 1), 1.0);
    expect(c.decodeField('nickname', 5), '5');
    expect(codecs.forEntity('species')!.decodeField('common_names_json', ['a', 'b']), '["a","b"]');
  });

  test('OR-Set join tables use added_hlc as the row HLC and `id` as key', () {
    for (final e in ['plant_photos', 'location_photos', 'plant_tags']) {
      final c = codecs.forEntity(e)!;
      expect(c.isOrSet, isTrue, reason: e);
      expect(c.hlcColumn, 'added_hlc');
      expect(c.idColumn, 'id');
    }
    expect(codecs.forEntity('photos')!.idColumn, 'sha256');
    expect(codecs.forEntity('plants')!.hlcColumn, 'updated_hlc');
  });

  group('round-trip for every entity', () {
    Future<void> seed() async {
      const t = 'tenant';
      await db.into(db.species).insert(SpeciesCompanion.insert(
          id: 's1', tenantId: t, scientificName: 'Ficus', commonNamesJson: '["fig"]', updatedHlc: hlc, deviceId: 'd', isSeed: const Value(true)));
      await db.into(db.locations).insert(LocationsCompanion.insert(
          id: 'l1', tenantId: t, name: 'Living', kind: 'room', updatedHlc: hlc, deviceId: 'd', tempMinC: const Value(18.5), isOutdoor: const Value(true)));
      await db.into(db.plants).insert(PlantsCompanion.insert(
          id: 'p1', tenantId: t, nickname: 'Bob', status: 'active', updatedHlc: hlc, deviceId: 'd', acquiredAt: const Value(1700000000000), pinX: const Value(0.25)));
      await db.into(db.photos).insert(PhotosCompanion.insert(
          sha256: 'sha1', tenantId: t, mime: 'image/jpeg', bytes: 3, updatedHlc: hlc, deviceId: 'd', takenAt: const Value(1700000000000), localPath: const Value('/p')));
      await db.into(db.plantPhotos).insert(PlantPhotosCompanion.insert(
          id: 'pp1', tenantId: t, plantId: 'p1', photoSha: 'sha1', addedHlc: hlc, deviceId: 'd', capturedAt: const Value(1700000000000), caption: const Value('c')));
      await db.into(db.locationPhotos).insert(LocationPhotosCompanion.insert(
          id: 'lp1', tenantId: t, locationId: 'l1', photoSha: 'sha1', addedHlc: hlc, deviceId: 'd'));
      await db.into(db.tags).insert(TagsCompanion.insert(id: 't1', tenantId: t, name: 'sun', updatedHlc: hlc, deviceId: 'd'));
      await db.into(db.plantTags).insert(PlantTagsCompanion.insert(
          id: 'pt1', tenantId: t, plantId: 'p1', tagId: 't1', addedHlc: hlc, deviceId: 'd', removedHlc: const Value('00001700000000001-00000-d')));
      await db.into(db.careEvents).insert(CareEventsCompanion.insert(
          id: 'ce1', tenantId: t, plantId: 'p1', type: 'water', doneAt: 1700000000000, updatedHlc: hlc, deviceId: 'd', dose: const Value('200ml')));
      await db.into(db.careSchedules).insert(CareSchedulesCompanion.insert(
          id: 'cs1', tenantId: t, plantId: 'p1', type: 'water', baseIntervalDays: 7, currentIntervalDays: 7.5, updatedHlc: hlc, deviceId: 'd',
          nextDueAt: const Value(1700000000000), enabled: const Value(false), recurrenceMode: const Value('fixed')));
      await db.into(db.inventoryTransactions).insert(InventoryTransactionsCompanion.insert(
          id: 'it1', tenantId: t, type: 'sale', at: 1700000000000, updatedHlc: hlc, deviceId: 'd', amountMinor: const Value(1500), currency: const Value('RON')));
    }

    const ids = {
      'species': ('species', 'id', 's1'),
      'locations': ('locations', 'id', 'l1'),
      'plants': ('plants', 'id', 'p1'),
      'photos': ('photos', 'sha256', 'sha1'),
      'plant_photos': ('plant_photos', 'id', 'pp1'),
      'location_photos': ('location_photos', 'id', 'lp1'),
      'tags': ('tags', 'id', 't1'),
      'plant_tags': ('plant_tags', 'id', 'pt1'),
      'care_events': ('care_events', 'id', 'ce1'),
      'care_schedules': ('care_schedules', 'id', 'cs1'),
      'inventory_transactions': ('inventory_transactions', 'id', 'it1'),
    };

    for (final entity in EntityCodecs.entities) {
      test(entity, () async {
        await seed();
        final (table, idCol, id) = ids[entity]!;
        final c = codecs.forEntity(entity)!;
        final sql = await readRow(table, idCol, id);
        final wire = c.encodeRow(sql);
        // JSON-safe and stable through a real encode/decode.
        final wire2 = json.decode(json.encode(wire)) as Map<String, dynamic>;
        expect(wire2.containsKey('tenant_id'), isFalse);
        for (final ts in c.timestampColumns) {
          final v = wire2[ts];
          if (v != null) expect(v, matches(RegExp(r'^\d{4}-\d{2}-\d{2}T.*Z$')), reason: ts);
        }
        final back = c.decodeRow(wire2);
        for (final col in c.wireColumns) {
          var expected = sql[col.name];
          if (col.type == DriftSqlType.bool && expected is int) expected = expected != 0;
          expect(back[col.name], expected, reason: '$entity.${col.name}');
        }
        // Re-inserting under a new id (and tenant, to dodge the per-tenant
        // unique indexes) through the codec's insertable works.
        final again = Map<String, Object?>.from(back)
          ..[c.idColumn] = '${id}_copy'
          ..['tenant_id'] = 'tenant2';
        await db.into(c.table).insert(c.insertable(again));
        final copy = await readRow(table, idCol, '${id}_copy');
        for (final col in c.wireColumns) {
          if (col.name == c.idColumn) continue;
          expect(copy[col.name], sql[col.name], reason: 'reinsert $entity.${col.name}');
        }
      });
    }
  });

  test('OpLogWriter.recordCreate stores the canonical full-row payload', () async {
    final opLog = OpLogWriter(db: db, clock: HlcClock(deviceId: 'dev-a'), tenantId: 'local');
    final h = await opLog.recordCreate(entity: 'locations', entityId: 'l1', value: {
      'id': 'l1',
      'tenant_id': 'local',
      'name': 'Balcony',
      'kind': 'outdoor',
      'is_outdoor': 1,
      'light': null,
    });
    final row = await (db.select(db.syncOps)).getSingle();
    final v = json.decode(row.valueJson!) as Map<String, dynamic>;
    expect(v['is_outdoor'], true);
    expect(v['notifications_muted'], false);
    expect(v['humidity_min'], isNull);
    expect(v['updated_hlc'], h.encode());
    expect(v['device_id'], 'dev-a');
    expect(v.containsKey('tenant_id'), isFalse);
    expect(v.keys.toSet(), codecs.forEntity('locations')!.wireColumnNames.toSet());
  });

  test('OpLogWriter.recordFieldUpdate renders timestamp fields ISO-8601', () async {
    final opLog = OpLogWriter(db: db, clock: HlcClock(deviceId: 'dev-a'), tenantId: 'local');
    await opLog.recordFieldUpdate(entity: 'care_events', entityId: 'e1', field: 'done_at', value: 1700000000000);
    await opLog.recordFieldUpdate(entity: 'care_events', entityId: 'e1', field: 'notes', value: 'n');
    final rows = await (db.select(db.syncOps)..orderBy([(o) => OrderingTerm.asc(o.seq)])).get();
    expect(json.decode(rows[0].valueJson!), '2023-11-14T22:13:20.000Z');
    expect(json.decode(rows[1].valueJson!), 'n');
  });

  test('OpLogWriter.changes fires for local ops only', () async {
    final opLog = OpLogWriter(db: db, clock: HlcClock(deviceId: 'dev-a'), tenantId: 'local');
    var n = 0;
    final sub = opLog.changes.listen((_) => n++);
    await opLog.recordCreate(entity: 'tags', entityId: 't1', value: {'name': 'x'});
    await opLog.recordFieldUpdate(entity: 'tags', entityId: 't1', field: 'color', value: '#fff');
    await opLog.recordTombstone(entity: 'tags', entityId: 't1');
    await Future<void>.delayed(Duration.zero);
    expect(n, 3);
    expect(await opLog.pendingCount(), 3);
    await sub.cancel();
    await opLog.dispose();
  });
}
