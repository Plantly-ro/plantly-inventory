@TestOn('browser')
library;

import 'package:drift/wasm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:sqlite3/wasm.dart';

/// Web check for the schema 13 table rebuild: the same v12 (release 1.1.0)
/// DDL + data, upgraded by drift on the sqlite3.wasm the app ships
/// (web/sqlite3.wasm). Run manually — needs the repo served over HTTP:
///   python3 -m http.server-like server with CORS on :8765 at the repo root,
///   CHROME_EXECUTABLE=… flutter test --platform chrome test/web/
const base = 'http://127.0.0.1:8765';

void main() {
  test('v12 → v13 photos rebuild on sqlite3.wasm', () async {
    final sqlite = await WasmSqlite3.loadFromUrl(Uri.parse('$base/web/sqlite3.wasm'));
    sqlite.registerVirtualFileSystem(InMemoryFileSystem(), makeDefault: true);
    final ddl = (await http.get(Uri.parse('$base/test/data/fixtures/schema_v12_release_1_1_0.sql'))).body;
    final db = AppDatabase.forTesting(WasmDatabase.inMemory(sqlite, setup: (raw) {
      raw.execute(ddl);
      raw.execute("INSERT INTO photos (sha256, tenant_id, mime, bytes, local_path, remote_state, updated_hlc, device_id) VALUES "
          "('s1', 'col-1', 'image/jpeg', 10, NULL, 'local', 'h1', 'd'), ('s2', 'col-2', 'image/jpeg', 20, NULL, 'gc', 'h2', 'd')");
      raw.execute('PRAGMA user_version = 12');
    }));
    final version = (await db.customSelect('SELECT sqlite_version() AS v').getSingle()).read<String>('v');
    final rows = await db.select(db.photos).get();
    expect(rows.map((r) => (r.sha256, r.tenantId, r.remoteState)).toSet(), {('s1', 'col-1', 'local'), ('s2', 'col-2', 'gc')});
    await db.into(db.photos).insert(PhotosCompanion.insert(
        sha256: 's1', tenantId: 'col-2', mime: 'image/jpeg', bytes: 10, updatedHlc: 'h', deviceId: 'd'));
    expect((await db.customSelect('PRAGMA user_version').getSingle()).data.values.first, 13);
    final pk = await db.customSelect("SELECT name FROM pragma_table_info('photos') WHERE pk > 0 ORDER BY pk").get();
    expect(pk.map((r) => r.read<String>('name')), ['tenant_id', 'sha256']);
    // ignore: avoid_print
    print('sqlite3.wasm $version: v12 → v13 OK');
    await db.close();
  });
}
