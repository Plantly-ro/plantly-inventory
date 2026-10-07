import 'web_document_base_stub.dart'
    if (dart.library.js_interop) 'web_document_base_web.dart' as platform;

/// Web-only drift binaries, committed under `web/vendor/` by
/// `tool/fetch_web_sqlite.sh`. The package version is part of the path on
/// purpose: Caddy serves `/vendor/*` as immutable (year-long browser + edge
/// cache), so new bytes must mean a new URL — bump the path together with
/// the files (`tool/web_vendor.sha256` + lint-tools tests enforce it). A
/// version-stable path also keeps the drift SharedWorker identity stable
/// across app releases (a new worker URL = a second worker on the same OPFS
/// database while an old tab is still open).
const String kSqlite3WasmPath = 'vendor/sqlite3-2.9.4/sqlite3.wasm';
const String kDriftWorkerPath = 'vendor/drift-2.31.0/drift_worker.js';

/// [path] resolved against the page's `<base href>`, as an absolute URL.
///
/// Must be absolute: drift hands the sqlite3 URI to its worker, which would
/// otherwise resolve it relative to the worker script (`vendor/drift-…/`).
Uri webDeployedFileUri(String path, {String? documentBase}) =>
    Uri.parse(documentBase ?? platform.documentBaseUri()).resolve(path);
