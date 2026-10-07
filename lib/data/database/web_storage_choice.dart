/// Which drift web storage to open — pure logic (no browser imports) so it
/// is unit-tested on the VM. Names mirror drift's `WasmStorageImplementation`
/// / `MissingBrowserFeature` (mapped in `cross_tab_lock_web.dart`).
library;

enum WebStorageKind { opfsShared, opfsLocks, sharedIndexedDb, unsafeIndexedDb, inMemory }

bool _isOpfs(WebStorageKind k) => k == WebStorageKind.opfsShared || k == WebStorageKind.opfsLocks;

/// Drift's own choice, minus its silent fallbacks:
/// * a probe that hit `workerError` (two tabs probing at once collide on
///   drift's OPFS test file) is RETRIED (null), never answered with a
///   weaker storage — an IndexedDB pick would be a different, empty
///   database, and a sync leader there would move the shared cursor;
/// * an existing OPFS database is never traded for IndexedDB; only when the
///   browser truly lacks OPFS (no file system access / no shared array
///   buffers) does the choice fall back.
/// Otherwise: best available, existing database's storage first.
WebStorageKind? chooseWebStorage({
  required Set<WebStorageKind> available,
  required Set<String> missingFeatures,
  required bool opfsDbExists,
  required bool indexedDbExists,
}) {
  if (missingFeatures.contains('workerError')) return null;
  final ordered = WebStorageKind.values.where(available.contains).toList();
  final opfs = ordered.where(_isOpfs).toList();
  if (opfsDbExists) {
    if (opfs.isNotEmpty) return opfs.first;
    final opfsUnsupported =
        missingFeatures.contains('fileSystemAccess') || missingFeatures.contains('sharedArrayBuffers');
    if (!opfsUnsupported) return null;
  }
  if (indexedDbExists && !opfsDbExists) {
    for (final k in ordered) {
      if (k == WebStorageKind.sharedIndexedDb || k == WebStorageKind.unsafeIndexedDb) return k;
    }
  }
  return ordered.isEmpty ? WebStorageKind.inMemory : ordered.first;
}
