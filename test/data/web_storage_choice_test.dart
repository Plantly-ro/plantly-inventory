import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/web_storage_choice.dart';

void main() {
  const chromeIsolated = {
    WebStorageKind.opfsLocks,
    WebStorageKind.sharedIndexedDb,
    WebStorageKind.unsafeIndexedDb,
    WebStorageKind.inMemory,
  };
  WebStorageKind? choose(Set<WebStorageKind> available,
          {Set<String> missing = const {}, bool opfs = false, bool idb = false}) =>
      chooseWebStorage(available: available, missingFeatures: missing, opfsDbExists: opfs, indexedDbExists: idb);

  test('Chrome / Safari (isolated): OPFS (opfsLocks), as drift picks it today', () {
    expect(choose(chromeIsolated, missing: {'dedicatedWorkersInSharedWorkers'}), WebStorageKind.opfsLocks);
    expect(choose(chromeIsolated, opfs: true), WebStorageKind.opfsLocks);
  });

  test('Firefox: opfsShared', () {
    expect(choose({WebStorageKind.opfsShared, ...chromeIsolated}, opfs: true), WebStorageKind.opfsShared);
  });

  test('concurrent boot: a probe with workerError is retried, never answered with IndexedDB', () {
    // What three tabs booting at once produced: OPFS missing from the list,
    // drift fell back to sharedIndexedDb (a different, empty database).
    expect(
        choose({WebStorageKind.sharedIndexedDb, WebStorageKind.unsafeIndexedDb, WebStorageKind.inMemory},
            missing: {'workerError'}, opfs: true),
        isNull);
    expect(choose(chromeIsolated, missing: {'workerError'}), isNull);
  });

  test('an existing OPFS database is never traded for IndexedDB unless OPFS is truly unsupported', () {
    const noOpfs = {WebStorageKind.sharedIndexedDb, WebStorageKind.unsafeIndexedDb, WebStorageKind.inMemory};
    expect(choose(noOpfs, opfs: true), isNull, reason: 'OPFS should be there: probe again');
    expect(choose(noOpfs, opfs: true, missing: {'sharedArrayBuffers'}), WebStorageKind.sharedIndexedDb,
        reason: 'page not cross-origin isolated: OPFS genuinely unusable');
  });

  test('non-isolated page keeps its IndexedDB database; nothing usable → in memory', () {
    expect(choose({WebStorageKind.sharedIndexedDb, WebStorageKind.unsafeIndexedDb}, missing: {'sharedArrayBuffers'}, idb: true),
        WebStorageKind.sharedIndexedDb);
    expect(choose(const {}), WebStorageKind.inMemory);
  });
}
