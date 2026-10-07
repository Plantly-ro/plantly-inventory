import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

/// Schema 13: `photos` primary key sha256 → (tenant_id, sha256), via a table
/// rebuild. The fixtures are the exact DDL the shipped builds create
/// (`sqlite_master` dumped from a fresh database of each):
///   * schema_v12_release_1_1_0.sql — release 1.1.0 (origin/main), which is
///     also the current development schema (no database changes since);
///   * schema_v7_release_1_0_0.sql  — release 1.0.0 (pre-cloud).
/// Real data goes in at the old version; one open must upgrade it in full.
void main() {
  String fixture(String name) => File('test/data/fixtures/$name').readAsStringSync();

  const shaA = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const shaB = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const shaC = 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  const shaD = 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

  /// Photos across two tenants in every upload state the field can hold:
  /// a pending upload, an uploaded one, a pulled-not-downloaded one, a
  /// garbage-collected one, plus a deleted row; join rows + pending ops.
  void seed(raw.Database db, int version) {
    void photo(String sha, String tenant, String state, {String? path, int? deletedAt}) => db.execute(
          'INSERT INTO photos (sha256, tenant_id, width, height, mime, bytes, taken_at, exif_json, local_path, '
          'remote_state, updated_hlc, deleted_at, device_id) VALUES (?, ?, 640, 480, ?, 1234, 1700000000000, NULL, ?, ?, ?, ?, ?)',
          [sha, tenant, 'image/jpeg', path, state, 'hlc-$sha', deletedAt, 'dev-a'],
        );
    photo(shaA, 'local', 'local', path: '/docs/photos/aa/$shaA.jpg');
    photo(shaB, 'col-1', 'synced', path: '/docs/photos/bb/$shaB.jpg');
    photo(shaC, 'col-1', 'remote');
    photo(shaD, 'col-2', 'gc', path: '/docs/photos/dd/$shaD.jpg', deletedAt: null);
    db.execute(
      'INSERT INTO plant_photos (id, tenant_id, plant_id, photo_sha, caption, display_order, added_hlc, device_id) '
      "VALUES ('pp1', 'col-1', 'p1', ?, 'leaf', 0, 'h1', 'dev-a'), ('pp2', 'col-2', 'p2', ?, NULL, 0, 'h2', 'dev-a')",
      [shaB, shaB],
    );
    db.execute(
      'INSERT INTO sync_ops (tenant_id, entity, entity_id, field, value_json, hlc, device_id, pushed_at) '
      "VALUES ('local', 'photos', ?, '*', '{}', 'h0', 'dev-a', NULL)",
      [shaA],
    );
    db.execute('PRAGMA user_version = $version');
  }

  AppDatabase open(String fixtureName, int version) => AppDatabase.forTesting(NativeDatabase.memory(setup: (db) {
        // Only when the file is new: drift calls setup on every open of the
        // executor, and the schema check below reopens nothing.
        final v = db.select('PRAGMA user_version').single.values.first as int;
        if (v != 0) return;
        db.execute(fixture(fixtureName));
        seed(db, version);
      }));

  Future<List<Map<String, Object?>>> tableInfo(AppDatabase db, String table) async => [
        for (final r in await db.customSelect('PRAGMA table_info($table)').get())
          {'name': r.data['name'], 'type': r.data['type'], 'notnull': r.data['notnull'], 'dflt': r.data['dflt_value'], 'pk': r.data['pk']},
      ];

  Future<Map<String, List<Map<String, Object?>>>> schemaOf(AppDatabase db) async {
    final names = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name")
        .get();
    // Column ORDER differs for columns earlier steps added with ALTER TABLE
    // (appended); drift addresses columns by name, so compare by name.
    return {
      for (final n in names)
        n.read<String>('name'): (await tableInfo(db, n.read<String>('name')))
          ..sort((x, y) => '${x['name']}'.compareTo('${y['name']}')),
    };
  }

  Future<Set<String>> indexes(AppDatabase db) async => {
        for (final r in await db
            .customSelect("SELECT name FROM sqlite_master WHERE type = 'index' AND name NOT LIKE 'sqlite_%'")
            .get())
          r.read<String>('name'),
      };

  for (final (fixtureName, version) in [
    ('schema_v12_release_1_1_0.sql', 12),
    ('schema_v7_release_1_0_0.sql', 7),
  ]) {
    group('upgrade from $fixtureName (v$version) → v13', () {
      test('photos survive unchanged, keyed (tenant_id, sha256); same schema as a fresh install', () async {
        final db = open(fixtureName, version);
        addTearDown(db.close);

        final rows = await (db.select(db.photos)..orderBy([(p) => OrderingTerm(expression: p.sha256)])).get();
        expect([for (final r in rows) (r.sha256, r.tenantId, r.remoteState, r.localPath, r.deletedAt)], [
          (shaA, 'local', 'local', '/docs/photos/aa/$shaA.jpg', null),
          (shaB, 'col-1', 'synced', '/docs/photos/bb/$shaB.jpg', null),
          (shaC, 'col-1', 'remote', null, null),
          (shaD, 'col-2', 'gc', '/docs/photos/dd/$shaD.jpg', null),
        ]);
        final a = rows.first;
        expect((a.width, a.height, a.mime, a.bytes, a.takenAt, a.updatedHlc, a.deviceId),
            (640, 480, 'image/jpeg', 1234, 1700000000000, 'hlc-$shaA', 'dev-a'));

        final pk = {for (final c in await tableInfo(db, 'photos')) if ((c['pk'] as int) > 0) c['name']: c['pk']};
        expect(pk, {'tenant_id': 1, 'sha256': 2});

        // Other tables untouched by the rebuild.
        expect((await db.select(db.plantPhotos).get()).map((r) => (r.id, r.photoSha, r.caption)),
            [('pp1', shaB, 'leaf'), ('pp2', shaB, null)]);
        final op = await db.select(db.syncOps).getSingle();
        expect((op.entity, op.entityId, op.pushedAt), ('photos', shaA, null));

        final fresh = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(fresh.close);
        expect(await schemaOf(db), await schemaOf(fresh), reason: 'every table matches a fresh v13 install');
        expect(await tableInfo(db, 'photos'), await tableInfo(fresh, 'photos'), reason: 'rebuilt table: exact, in order');
        expect(await indexes(db), await indexes(fresh));
        expect((await db.customSelect('PRAGMA user_version').getSingle()).data.values.first, 13);
        expect((await db.customSelect('PRAGMA integrity_check').getSingle()).data.values.first, 'ok');
      });

      test('after the upgrade the same sha can live in a second tenant (the bug being fixed)', () async {
        final db = open(fixtureName, version);
        addTearDown(db.close);
        await db.into(db.photos).insert(PhotosCompanion.insert(
            sha256: shaB, tenantId: 'col-2', mime: 'image/jpeg', bytes: 1234, updatedHlc: 'h', deviceId: 'dev-a'));
        final tenants = await (db.select(db.photos)..where((p) => p.sha256.equals(shaB))).get();
        expect(tenants.map((r) => r.tenantId).toSet(), {'col-1', 'col-2'});
        // Still unique per (tenant, sha).
        await expectLater(
          db.into(db.photos).insert(PhotosCompanion.insert(
              sha256: shaB, tenantId: 'col-2', mime: 'image/jpeg', bytes: 1, updatedHlc: 'h', deviceId: 'dev-a')),
          throwsA(isA<SqliteException>()),
        );
      });
    });
  }

  test('a re-run of the 12 → 13 step (crash before the version bump) is harmless', () async {
    final file = File('${Directory.systemTemp.createTempSync('plantly-v13-').path}/db.sqlite');
    addTearDown(() => file.parent.deleteSync(recursive: true));
    final pre = raw.sqlite3.open(file.path);
    pre.execute(fixture('schema_v12_release_1_1_0.sql'));
    seed(pre, 12);
    pre.dispose();

    final first = AppDatabase.forTesting(NativeDatabase(file));
    expect(await first.select(first.photos).get(), hasLength(4));
    await first.close();

    // Simulate the interrupted upgrade: the table is already rebuilt but the
    // version still says 12.
    final mid = raw.sqlite3.open(file.path);
    mid.execute('PRAGMA user_version = 12');
    mid.dispose();

    final second = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(second.close);
    expect(await second.select(second.photos).get(), hasLength(4));
    expect((await second.customSelect('PRAGMA user_version').getSingle()).data.values.first, 13);
  });

  group('interrupted 12 → 13 step resumes without data loss', () {
    test('after photos_v13 was created and partly filled', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory(setup: (raw) {
        raw.execute(fixture('schema_v12_release_1_1_0.sql'));
        seed(raw, 12);
        raw.execute(AppDatabase.photosV13Ddl('photos_v13'));
        raw.execute("INSERT INTO photos_v13 SELECT * FROM photos WHERE sha256 = '$shaB'");
      }));
      addTearDown(db.close);
      expect(await db.select(db.photos).get(), hasLength(4));
      expect(await db.customSelect("SELECT name FROM sqlite_master WHERE name = 'photos_v13'").get(), isEmpty);
    });

    test('after the old table was dropped, before the rename', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory(setup: (raw) {
        raw.execute(fixture('schema_v12_release_1_1_0.sql'));
        seed(raw, 12);
        raw.execute(AppDatabase.photosV13Ddl('photos_v13'));
        raw.execute('INSERT INTO photos_v13 SELECT * FROM photos');
        raw.execute('DROP TABLE photos');
      }));
      addTearDown(db.close);
      expect(await db.select(db.photos).get(), hasLength(4));
    });
  });

  test('a re-run on a photos table already keyed (tenant_id, sha256) changes nothing, later columns included', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory(setup: (raw) {
      raw.execute(fixture('schema_v12_release_1_1_0.sql'));
      seed(raw, 12);
      // Already rekeyed, plus a column a later (v14+) step added.
      raw.execute(AppDatabase.photosV13Ddl('photos_v13'));
      raw.execute('INSERT INTO photos_v13 SELECT * FROM photos');
      raw.execute('DROP TABLE photos');
      raw.execute('ALTER TABLE photos_v13 RENAME TO photos');
      raw.execute('ALTER TABLE photos ADD COLUMN future_col TEXT NULL');
      raw.execute("UPDATE photos SET future_col = 'kept'");
      raw.execute('PRAGMA user_version = 12');
    }));
    addTearDown(db.close);
    final rows = await db.customSelect('SELECT future_col FROM photos').get();
    expect(rows.map((r) => r.read<String>('future_col')), everyElement('kept'));
    expect(rows, hasLength(4));
  });

  group('the v13 step is frozen', () {
    test('its DDL is the v12 photos table with only the primary key changed', () {
      final db = raw.sqlite3.openInMemory();
      addTearDown(db.dispose);
      db.execute(fixture('schema_v12_release_1_1_0.sql'));
      db.execute(AppDatabase.photosV13Ddl('photos_v13'));
      List<List<Object?>> info(String t) =>
          [for (final r in db.select('PRAGMA table_info($t)')) [r['name'], r['type'], r['notnull'], r['dflt_value']]];
      expect(info('photos_v13'), info('photos'));
      expect(info('photos_v13').map((c) => c.first), AppDatabase.photosV13Columns);
      final pk = [for (final r in db.select("SELECT name FROM pragma_table_info('photos_v13') WHERE pk > 0 ORDER BY pk")) r['name']];
      expect(pk, ['tenant_id', 'sha256']);
    });

    test('a later schema adding a photos column does not change what the step builds', () async {
      // The step runs on raw SQL only — a future `photos` column (v14+) can't
      // leak into it through the drift definition.
      final src = File('lib/data/database/app_database.dart').readAsStringSync();
      final body = src.substring(src.indexOf('static Future<void> rekeyPhotosV13('), src.indexOf("await exec('ALTER TABLE \$next RENAME TO photos');"));
      expect(body, isNot(contains(r'$columns')));
      expect(body, isNot(contains('createTable')));
      expect(body, isNot(contains('photos.')));

      // And on a plain database (no drift tables at all) it produces v13.
      final db = raw.sqlite3.openInMemory();
      addTearDown(db.dispose);
      db.execute(fixture('schema_v12_release_1_1_0.sql'));
      seed(db, 12);
      await AppDatabase.rekeyPhotosV13(
        exec: (sql) async => db.execute(sql),
        exists: (t) async => db.select("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?", [t]).isNotEmpty,
        photosPrimaryKey: () async =>
            [for (final r in db.select("SELECT name FROM pragma_table_info('photos') WHERE pk > 0 ORDER BY pk")) r['name'] as String],
      );
      expect([for (final r in db.select('PRAGMA table_info(photos)')) r['name']], AppDatabase.photosV13Columns);
      expect(db.select('SELECT COUNT(*) AS n FROM photos').single['n'], 4);
    });
  });
}
