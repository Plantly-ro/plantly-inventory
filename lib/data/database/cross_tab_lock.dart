import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart' show DriftWebOptions;
import 'package:flutter/foundation.dart' show ValueNotifier;

import 'cross_tab_lock_stub.dart' if (dart.library.js_interop) 'cross_tab_lock_web.dart' as platform;

/// Cross-tab serialization of database access (web).
///
/// On Chrome / Safari drift opens the database with `opfsLocks`: every
/// browser tab has its OWN sqlite connection to the same OPFS file, and the
/// file can only be opened by one tab at a time (an exclusive sync access
/// handle). sqlite3's VFS retries 6 times without backoff, then fails the
/// statement with `SQLITE_IOERR` — a write in one tab fails whenever another
/// tab happens to hold the file. Here every statement (and every transaction,
/// from its first statement to commit / rollback) runs while holding one
/// tab-wide lease on the Web Lock `plantly-db`, so tabs take turns instead
/// of colliding. Statements of the same tab share the lease (they are
/// serialized by the tab's own connection anyway); a lease held longer than
/// [CrossTabDbInterceptor.maxShare] stops admitting newcomers, so a busy tab
/// cannot starve the others. As a backstop, a statement outside a
/// transaction that still fails with an I/O / busy error is retried with
/// backoff.
///
/// Off the web there is one connection per process: exactly
/// `driftDatabase(name:, web:)`. On the web the connection is opened here
/// (see `cross_tab_lock_web.dart`): under the same lock, with OPFS chosen
/// explicitly, then wrapped in [CrossTabDbInterceptor].
QueryExecutor openAppDatabase({required String name, required DriftWebOptions web}) =>
    platform.openAppDatabase(name: name, web: web);

/// The exclusive lock all tabs share. [acquire] resolves once it is held;
/// the returned callback releases it. May throw [CrossTabLockTimeout].
abstract class CrossTabLock {
  Future<void Function()> acquire();
}

/// Another tab held the database lock for too long. Retryable: the
/// statement is tried again (see [CrossTabDbInterceptor.retryDelays]).
class CrossTabLockTimeout implements Exception {
  const CrossTabLockTimeout(this.waited);
  final Duration waited;

  @override
  String toString() => 'CrossTabLockTimeout: another tab held the database for ${waited.inSeconds}s (SQLITE_BUSY)';
}

/// True while this tab is waiting on a database another tab holds for too
/// long; the UI shows a non-blocking "Another Plantly tab is busy" notice.
final ValueNotifier<bool> crossTabDbBusy = ValueNotifier(false);

/// Tab-wide lease over a [CrossTabLock]: concurrent holders of the same tab
/// share one acquisition; the lock is released when the last one leaves.
class _Lease {
  _Lease(this._lock, this._maxShare);

  final CrossTabLock _lock;
  final Duration _maxShare;
  int _holders = 0;
  void Function()? _release;
  Future<void>? _acquiring;
  DateTime? _since;

  /// Waiters while the current lease stopped admitting newcomers.
  Completer<void>? _drained;

  Future<void> enter() async {
    while (true) {
      final since = _since;
      if (_release != null && since != null && DateTime.now().difference(since) < _maxShare) {
        _holders++;
        return;
      }
      if (_release != null) {
        // Held too long: let the other tabs in before taking it again.
        await (_drained ??= Completer<void>()).future;
        continue;
      }
      final pending = _acquiring;
      if (pending != null) {
        await pending;
        continue;
      }
      final done = Completer<void>();
      _acquiring = done.future;
      try {
        _release = await _lock.acquire();
        _since = DateTime.now();
        _holders++;
        return;
      } finally {
        _acquiring = null;
        done.complete();
      }
    }
  }

  void leave() {
    _holders--;
    if (_holders > 0) return;
    final release = _release;
    _release = null;
    _since = null;
    release?.call();
    final drained = _drained;
    _drained = null;
    drained?.complete();
  }
}

class CrossTabDbInterceptor extends QueryInterceptor {
  CrossTabDbInterceptor(
    CrossTabLock lock, {
    Future<void>? ready,
    this.maxShare = const Duration(milliseconds: 250),
    this.retryDelays = const [
      Duration(milliseconds: 20),
      Duration(milliseconds: 60),
      Duration(milliseconds: 150),
      Duration(milliseconds: 400),
    ],
  })  : _lease = _Lease(lock, maxShare),
        _ready = ready;

  /// Completes once the underlying connection exists (web: WASM + worker
  /// loaded, opened under the lock by the opener). The lease is only taken
  /// after it — never held across the spin-up.
  final Future<void>? _ready;

  final Duration maxShare;

  /// Backoff before each retry of a statement that failed with an I/O or
  /// busy error (outside transactions only).
  final List<Duration> retryDelays;

  final _Lease _lease;

  /// Top-level transactions that hold a lease (from their first statement).
  final Expando<bool> _holding = Expando('crossTabTx');

  /// Transactions started by this interceptor at top level (not nested).
  final Expando<bool> _topLevel = Expando('crossTabTopLevel');

  bool _opened = false;

  @override
  TransactionExecutor beginTransaction(QueryExecutor parent) {
    final tx = parent.beginTransaction();
    if (parent is! TransactionExecutor) _topLevel[tx] = true;
    return tx;
  }

  @override
  Future<bool> ensureOpen(QueryExecutor executor, QueryExecutorUser user) async {
    if (executor is TransactionExecutor) {
      // The transaction's BEGIN goes out on its first ensureOpen: take the
      // lease before it, keep it until commit / rollback.
      if (_topLevel[executor] == true && _holding[executor] != true) {
        await _ready;
        await _lease.enter();
        _holding[executor] = true;
        try {
          return await executor.ensureOpen(user);
        } catch (_) {
          // BEGIN failed: drift calls neither commit nor rollback for this
          // transaction — give the lease back here or every tab hangs.
          _holding[executor] = null;
          _lease.leave();
          rethrow;
        }
      }
      return executor.ensureOpen(user);
    }
    if (_opened) return executor.ensureOpen(user);
    // First open (schema migrations) — one tab at a time.
    final opened = await _guarded(() => executor.ensureOpen(user), retry: false);
    _opened = true;
    return opened;
  }

  Future<void> _endTransaction(TransactionExecutor inner, Future<void> Function() end) async {
    try {
      await end();
    } finally {
      if (_holding[inner] == true) {
        _holding[inner] = null;
        _lease.leave();
      }
    }
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) => _endTransaction(inner, inner.send);

  @override
  Future<void> rollbackTransaction(TransactionExecutor inner) => _endTransaction(inner, inner.rollback);

  Future<T> _run<T>(QueryExecutor executor, Future<T> Function() body) {
    // Inside a transaction: the transaction holds the lease already.
    if (executor is TransactionExecutor) return body();
    return _guarded(body, retry: true);
  }

  Future<T> _guarded<T>(Future<T> Function() body, {required bool retry}) async {
    await _ready;
    for (var attempt = 0;; attempt++) {
      try {
        await _lease.enter();
      } on CrossTabLockTimeout {
        // Nothing ran yet: always safe to wait again.
        if (attempt >= retryDelays.length) rethrow;
        await Future<void>.delayed(retryDelays[attempt]);
        continue;
      }
      try {
        return await body();
      } catch (e) {
        if (!retry || attempt >= retryDelays.length || !isRetryableDbError(e)) rethrow;
      } finally {
        _lease.leave();
      }
      await Future<void>.delayed(retryDelays[attempt]);
    }
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(QueryExecutor executor, String statement, List<Object?> args) =>
      _run(executor, () => executor.runSelect(statement, args));

  @override
  Future<int> runInsert(QueryExecutor executor, String statement, List<Object?> args) =>
      _run(executor, () => executor.runInsert(statement, args));

  @override
  Future<int> runUpdate(QueryExecutor executor, String statement, List<Object?> args) =>
      _run(executor, () => executor.runUpdate(statement, args));

  @override
  Future<int> runDelete(QueryExecutor executor, String statement, List<Object?> args) =>
      _run(executor, () => executor.runDelete(statement, args));

  @override
  Future<void> runCustom(QueryExecutor executor, String statement, List<Object?> args) =>
      _run(executor, () => executor.runCustom(statement, args));

  @override
  Future<void> runBatched(QueryExecutor executor, BatchedStatements statements) =>
      _run(executor, () => executor.runBatched(statements));
}

/// `SQLITE_IOERR*` (10 + extended) or `SQLITE_BUSY*` (5 + extended), as a
/// native `SqliteException` or as the text of a remote (web worker) error.
bool isRetryableDbError(Object e) {
  if (e is CrossTabLockTimeout) return true;
  final text = e.toString();
  final code = RegExp(r'SqliteException\((\d+)\)').firstMatch(text);
  if (code != null) {
    final primary = int.parse(code.group(1)!) & 0xff;
    if (primary == 10 || primary == 5) return true;
  }
  return text.contains('SQLITE_IOERR') ||
      text.contains('SQLITE_BUSY') ||
      text.contains('disk I/O error') ||
      text.contains('database is locked');
}
