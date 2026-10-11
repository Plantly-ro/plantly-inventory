import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/web_db_assets.dart';

void main() {
  group('webDeployedFileUri', () {
    test('resolves against the document base, not the current route', () {
      expect(
        webDeployedFileUri(kSqlite3WasmPath, documentBase: 'https://inventory.plantly.ro/').toString(),
        'https://inventory.plantly.ro/vendor/sqlite3-2.9.4/sqlite3.wasm',
      );
      expect(
        webDeployedFileUri(kDriftWorkerPath, documentBase: 'https://example.test/app/').toString(),
        'https://example.test/app/vendor/drift-2.31.0/drift_worker.js',
      );
    });

    test('stays relative off the web (no document base)', () {
      expect(webDeployedFileUri(kSqlite3WasmPath).toString(), kSqlite3WasmPath);
    });
  });

  test('the referenced vendor files are committed under web/', () {
    for (final path in [kSqlite3WasmPath, kDriftWorkerPath]) {
      expect(File('web/$path').existsSync(), isTrue, reason: 'web/$path missing — see tool/fetch_web_sqlite.sh');
    }
  });
}
