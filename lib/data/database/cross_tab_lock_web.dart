import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:drift_flutter/drift_flutter.dart' show DriftWebOptions;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:web/web.dart' as web;

import 'cross_tab_lock.dart';
import 'web_storage_choice.dart';

bool get _hasWebLocks {
  try {
    return (web.window.navigator as JSObject).has('locks');
  } catch (_) {
    return false;
  }
}

QueryExecutor openAppDatabase({required String name, required DriftWebOptions web}) {
  if (!_hasWebLocks) {
    // Very old browser: drift's own open, one tab at a time is all we get.
    return DatabaseConnection.delayed(Future(() async {
      final result = await WasmDatabase.open(
        databaseName: name,
        sqlite3Uri: web.sqlite3Wasm,
        driftWorkerUri: web.driftWorker,
        initializeDatabase: web.initializeDatabase,
      );
      web.onResult?.call(result);
      return result.resolvedExecutor;
    }));
  }
  final lock = WebDbLock();
  final opened = _openUnderLock(name, web, lock);
  final connection = DatabaseConnection.delayed(opened);
  return connection.interceptWith(CrossTabDbInterceptor(lock, ready: opened.then((_) {})));
}

/// Probe + open while holding `plantly-db`: drift's probe creates a test
/// file in OPFS, and two tabs probing at once make one of them see
/// `workerError` (drift would then silently pick IndexedDB — a different,
/// empty database). Retried with backoff instead; see [chooseWebStorage].
Future<DatabaseConnection> _openUnderLock(String name, DriftWebOptions options, WebDbLock lock) async {
  const delays = [250, 500, 1000, 2000, 4000, 8000];
  for (var attempt = 0;; attempt++) {
    final void Function() release;
    try {
      release = await lock.acquire(timeout: const Duration(seconds: 30));
    } on CrossTabLockTimeout {
      // A stuck holder: the next acquire steals the lock (see WebDbLock).
      if (attempt >= delays.length) rethrow;
      continue;
    }
    try {
      final probe = await WasmDatabase.probe(
        sqlite3Uri: options.sqlite3Wasm,
        driftWorkerUri: options.driftWorker,
        databaseName: name,
      );
      final missing = {for (final f in probe.missingFeatures) f.name};
      final choice = chooseWebStorage(
        available: {for (final s in probe.availableStorages) _kind(s)},
        missingFeatures: missing,
        opfsDbExists: probe.existingDatabases.any((e) => e.$1 == WebStorageApi.opfs && e.$2 == name),
        indexedDbExists: probe.existingDatabases.any((e) => e.$1 == WebStorageApi.indexedDb && e.$2 == name),
      );
      if (choice != null) {
        final implementation = _impl(choice);
        final connection = await probe.open(implementation, name, initializeDatabase: options.initializeDatabase);
        options.onResult?.call(WasmDatabaseResult(connection, implementation, probe.missingFeatures));
        return connection;
      }
      if (attempt >= delays.length) {
        throw StateError('database unavailable: the browser storage probe kept failing (${missing.join(', ')})');
      }
      debugPrint('AppDatabase: storage probe failed (${missing.join(', ')}), retrying');
    } finally {
      release();
    }
    await Future<void>.delayed(Duration(milliseconds: delays[attempt]));
  }
}

WebStorageKind _kind(WasmStorageImplementation s) => switch (s) {
      WasmStorageImplementation.opfsShared => WebStorageKind.opfsShared,
      WasmStorageImplementation.opfsLocks => WebStorageKind.opfsLocks,
      WasmStorageImplementation.sharedIndexedDb => WebStorageKind.sharedIndexedDb,
      WasmStorageImplementation.unsafeIndexedDb => WebStorageKind.unsafeIndexedDb,
      WasmStorageImplementation.inMemory => WebStorageKind.inMemory,
    };

WasmStorageImplementation _impl(WebStorageKind s) => switch (s) {
      WebStorageKind.opfsShared => WasmStorageImplementation.opfsShared,
      WebStorageKind.opfsLocks => WasmStorageImplementation.opfsLocks,
      WebStorageKind.sharedIndexedDb => WasmStorageImplementation.sharedIndexedDb,
      WebStorageKind.unsafeIndexedDb => WasmStorageImplementation.unsafeIndexedDb,
      WebStorageKind.inMemory => WasmStorageImplementation.inMemory,
    };

/// The `plantly-db` Web Lock (exclusive, FIFO across tabs; released by the
/// browser if the tab dies). A wait longer than [timeout] gives up with a
/// retryable [CrossTabLockTimeout] and raises [crossTabDbBusy]; after
/// [stealAfter] of consecutive timeouts the lock is stolen (the holder is
/// stuck — e.g. a frozen tab), its statement then fails and retries.
class WebDbLock implements CrossTabLock {
  WebDbLock({this.timeout = const Duration(seconds: 10), this.stealAfter = const Duration(seconds: 30)});

  final Duration timeout;
  final Duration stealAfter;
  Duration _waitedInARow = Duration.zero;

  @override
  Future<void Function()> acquire({Duration? timeout}) async {
    final limit = timeout ?? this.timeout;
    final steal = _waitedInARow >= stealAfter;
    final granted = Completer<void Function()>();
    final options = steal
        ? web.LockOptions(steal: true)
        : web.LockOptions(signal: web.AbortSignal.timeout(limit.inMilliseconds));
    if (steal) debugPrint('AppDatabase: another tab held the database for ${_waitedInARow.inSeconds}s, taking it over');
    web.window.navigator.locks
        .request(
          'plantly-db',
          options,
          ((web.Lock? lock) {
            final held = Completer<void>();
            if (granted.isCompleted) return null;
            granted.complete(() {
              if (!held.isCompleted) held.complete();
            });
            return held.future.toJS;
          }).toJS,
        )
        .toDart
        .then((_) {}, onError: (Object e) {
      if (!granted.isCompleted) granted.completeError(CrossTabLockTimeout(limit));
    });
    try {
      final release = await granted.future;
      _waitedInARow = Duration.zero;
      if (crossTabDbBusy.value) crossTabDbBusy.value = false;
      return release;
    } on CrossTabLockTimeout {
      _waitedInARow += limit;
      crossTabDbBusy.value = true;
      rethrow;
    }
  }
}
