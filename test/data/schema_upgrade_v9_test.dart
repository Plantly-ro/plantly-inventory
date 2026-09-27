import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Schema 8 → 9 (shared collections, CLOUD-SYNC-CONTRACT §3): `care_events`
/// gains a nullable `actor_user_id`. The step is guarded by `PRAGMA
/// table_info`, so a device that crashed between the ALTER and the version
/// bump upgrades cleanly on the next start.
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

  Future<List<String>> columns(AppDatabase db) async {
    final rows = await db.customSelect('PRAGMA table_info(care_events)').get();
    return [for (final r in rows) r.read<String>('name')];
  }

  test('schemaVersion is >= 9 and a fresh database has actor_user_id', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    // 9 introduced the column; later steps (10: sync_rejections) chain after
    // it — see schema_upgrade_chain_test.dart for the full 8 → latest run.
    expect(db.schemaVersion, greaterThanOrEqualTo(9));
    expect(await columns(db), contains('actor_user_id'));
    expect(db.careEvents.actorUserId.$nullable, isTrue);
  });

  test('v8 → v9 adds the column; existing rows read back with actor null', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory(setup: (raw) {
      raw.execute(v8CareEvents);
      raw.execute("INSERT INTO care_events (id, tenant_id, plant_id, type, done_at, updated_hlc, device_id) "
          "VALUES ('e1', 'local', 'p1', 'water', 1000, '0-0-t', 't')");
      raw.execute('PRAGMA user_version = 8');
    }));
    addTearDown(db.close);
    expect(await columns(db), contains('actor_user_id'));
    final row = await (db.select(db.careEvents)..where((e) => e.id.equals('e1'))).getSingle();
    expect(row.actorUserId, isNull);
    expect(row.type, 'water');
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), db.schemaVersion);
  });

  test('v8 → v9 is idempotent: a column already present (interrupted upgrade) is left alone', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory(setup: (raw) {
      raw.execute(v8CareEvents);
      raw.execute('ALTER TABLE care_events ADD COLUMN actor_user_id TEXT NULL');
      raw.execute("INSERT INTO care_events (id, tenant_id, plant_id, type, done_at, updated_hlc, device_id, actor_user_id) "
          "VALUES ('e1', 'local', 'p1', 'water', 1000, '0-0-t', 't', 'u-1')");
      raw.execute('PRAGMA user_version = 8');
    }));
    addTearDown(db.close);
    // Opening runs onUpgrade(8 → 9); an unguarded ADD COLUMN would throw here.
    final cols = await columns(db);
    expect(cols.where((c) => c == 'actor_user_id'), hasLength(1));
    final row = await (db.select(db.careEvents)..where((e) => e.id.equals('e1'))).getSingle();
    expect(row.actorUserId, 'u-1', reason: 'data preserved');
  });

  test('raw sqlite sanity: the setup hook runs before drift opens', () {
    final raw = sqlite.sqlite3.openInMemory();
    addTearDown(raw.dispose);
    raw.execute(v8CareEvents);
    expect(raw.select('PRAGMA table_info(care_events)').map((r) => r['name']), isNot(contains('actor_user_id')));
  });
}
