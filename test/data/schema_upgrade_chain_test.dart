import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';

/// The cloud-era migration steps landed on separate branches and chain in
/// `onUpgrade`: 8 → 9 adds `care_events.actor_user_id` (shared collections),
/// 9 → 10 creates `sync_rejections` (per-op server refusals), 10 → 11 adds
/// `sync_ops.user_id` (account attribution of pending ops). A device still
/// on 8 must get ALL of them in one open, and a re-run of any step (crash
/// between DDL and the `user_version` bump, or an app restart) must be a
/// no-op.
void main() {
  const v8CareEvents = '''
    CREATE TABLE care_events (
      id TEXT NOT NULL PRIMARY KEY,
      tenant_id TEXT NOT NULL,
      plant_id TEXT NOT NULL,
      type TEXT NOT NULL,
      done_at INTEGER NOT NULL,
      notes TEXT NULL,
      dose TEXT NULL,
      product TEXT NULL,
      photo_sha TEXT NULL,
      updated_hlc TEXT NOT NULL,
      deleted_at INTEGER NULL,
      device_id TEXT NOT NULL
    )''';
  // sync_ops as it has existed since schema 1 (minus user_id).
  const v8SyncOps = '''
    CREATE TABLE sync_ops (
      seq INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      tenant_id TEXT NOT NULL,
      entity TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      field TEXT NOT NULL,
      value_json TEXT NULL,
      hlc TEXT NOT NULL,
      device_id TEXT NOT NULL,
      pushed_at INTEGER NULL
    )''';
  const v8OpRow = "INSERT INTO sync_ops (tenant_id, entity, entity_id, field, value_json, hlc, device_id) "
      "VALUES ('local', 'plants', 'p1', 'notes', '\"n\"', '0-0-t', 't')";
  const v8Row = "INSERT INTO care_events (id, tenant_id, plant_id, type, done_at, updated_hlc, device_id) "
      "VALUES ('e1', 'local', 'p1', 'water', 1000, '0-0-t', 't')";

  Future<List<String>> columns(AppDatabase db, String table) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return [for (final r in rows) r.read<String>('name')];
  }

  Future<List<String>> tables(AppDatabase db) async {
    final rows = await db.customSelect("SELECT name FROM sqlite_master WHERE type = 'table'").get();
    return [for (final r in rows) r.read<String>('name')];
  }

  Future<int> userVersion(AppDatabase db) async =>
      (await db.customSelect('PRAGMA user_version').getSingle()).read<int>('user_version');

  Future<void> expectV11Shape(AppDatabase db) async {
    expect(await columns(db, 'care_events'), contains('actor_user_id'));
    expect(await tables(db), contains('sync_rejections'));
    expect(
      await columns(db, 'sync_rejections'),
      containsAll(['op_seq', 'tenant_id', 'entity', 'entity_id', 'field', 'reason', 'hlc', 'at', 'parked']),
    );
    final idx = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'idx_sync_rejections_tenant'")
        .get();
    expect(idx, hasLength(1), reason: 'tenant index created with the table');
    expect(await columns(db, 'sync_ops'), contains('user_id'));
    expect(await userVersion(db), 11);
  }

  test('schemaVersion is 11', () {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 11);
  });

  test('v8 → v11 in one open: actor_user_id, sync_rejections AND sync_ops.user_id, data preserved', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory(setup: (raw) {
      raw.execute(v8CareEvents);
      raw.execute(v8Row);
      raw.execute(v8SyncOps);
      raw.execute(v8OpRow);
      raw.execute('PRAGMA user_version = 8');
    }));
    addTearDown(db.close);

    await expectV11Shape(db);
    final row = await (db.select(db.careEvents)..where((e) => e.id.equals('e1'))).getSingle();
    expect(row.actorUserId, isNull);
    expect(row.type, 'water');
    final op = await db.select(db.syncOps).getSingle();
    expect(op.userId, isNull, reason: 'legacy pending op: no account attribution');
    expect(op.pushedAt, isNull);
    expect(op.entityId, 'p1');

    // The new table is usable, not just present.
    await db.into(db.syncRejections).insert(SyncRejectionsCompanion.insert(
          opSeq: const Value(1),
          tenantId: 'local',
          entity: 'plants',
          entityId: 'p1',
          field: 'name',
          reason: 'bad_hlc',
          hlc: '0-0-t',
          at: 1000,
        ));
    expect(await db.select(db.syncRejections).get(), hasLength(1));
  });

  test('re-running the chain is idempotent (interrupted upgrade left both artefacts at user_version 8)', () async {
    // Capture the exact DDL drift emits for sync_rejections so the "already
    // there" table matches what a crashed 9 → 10 step would have created.
    final fresh = AppDatabase.forTesting(NativeDatabase.memory());
    final ddl = (await fresh
            .customSelect("SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'sync_rejections'")
            .getSingle())
        .read<String>('sql');
    await fresh.close();

    final db = AppDatabase.forTesting(NativeDatabase.memory(setup: (raw) {
      raw.execute(v8CareEvents);
      raw.execute('ALTER TABLE care_events ADD COLUMN actor_user_id TEXT NULL');
      raw.execute(ddl);
      raw.execute(v8SyncOps);
      raw.execute('ALTER TABLE sync_ops ADD COLUMN user_id TEXT NULL');
      raw.execute("INSERT INTO sync_ops (tenant_id, entity, entity_id, field, hlc, device_id, user_id) "
          "VALUES ('local', 'plants', 'p1', 'notes', '0-0-t', 't', 'u-1')");
      raw.execute("INSERT INTO care_events (id, tenant_id, plant_id, type, done_at, updated_hlc, device_id, actor_user_id) "
          "VALUES ('e1', 'local', 'p1', 'water', 1000, '0-0-t', 't', 'u-1')");
      raw.execute("INSERT INTO sync_rejections (op_seq, tenant_id, entity, entity_id, field, reason, hlc, at, parked) "
          "VALUES (7, 'local', 'plants', 'p1', 'name', 'bad_hlc', '0-0-t', 1000, 1)");
      raw.execute('PRAGMA user_version = 8');
    }));
    addTearDown(db.close);

    // Opening runs onUpgrade(8 → 11) again over all three artefacts; an
    // unguarded ADD COLUMN / CREATE TABLE would throw here.
    await expectV11Shape(db);
    expect((await columns(db, 'care_events')).where((c) => c == 'actor_user_id'), hasLength(1));
    expect((await columns(db, 'sync_ops')).where((c) => c == 'user_id'), hasLength(1));
    expect((await db.select(db.syncOps).getSingle()).userId, 'u-1', reason: 'column data preserved');
    final ev = await (db.select(db.careEvents)..where((e) => e.id.equals('e1'))).getSingle();
    expect(ev.actorUserId, 'u-1', reason: 'column data preserved');
    final rej = await db.select(db.syncRejections).get();
    expect(rej, hasLength(1), reason: 'ledger rows preserved');
    expect(rej.single.opSeq, 7);
    expect(rej.single.parked, isTrue);
  });

  test('a second open of the same upgraded file is a no-op at v11', () async {
    final dir = await Directory.systemTemp.createTemp('plantly-schema-chain-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/app.db');

    final first = AppDatabase.forTesting(NativeDatabase(file, setup: (raw) {
      if (raw.userVersion == 0) {
        raw.execute(v8CareEvents);
        raw.execute(v8Row);
        raw.execute(v8SyncOps);
        raw.execute('PRAGMA user_version = 8');
      }
    }));
    await expectV11Shape(first);
    await first.close();

    final second = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(second.close);
    await expectV11Shape(second);
    final row = await (second.select(second.careEvents)..where((e) => e.id.equals('e1'))).getSingle();
    expect(row.type, 'water');
  });
}
