import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/database/cross_tab_lock.dart';

/// Reviewer test (not part of the change): a transaction whose BEGIN fails
/// must not leave the `plantly-db` lease held. drift's `transaction()` calls
/// `ensureOpen` OUTSIDE its try/rollback, so the interceptor gets neither
/// `commitTransaction` nor `rollbackTransaction` for it.
class FakeLock implements CrossTabLock {
  Future<void> _tail = Future.value();
  int held = 0;

  @override
  Future<void Function()> acquire() {
    final prev = _tail;
    final mine = Completer<void>();
    _tail = mine.future;
    return prev.then((_) {
      held++;
      var released = false;
      return () {
        if (released) return;
        released = true;
        held--;
        mine.complete();
      };
    });
  }
}

/// Fails the next transaction's BEGIN (its ensureOpen) once.
class FailBeginOnce extends QueryInterceptor {
  bool armed = false;

  @override
  Future<bool> ensureOpen(QueryExecutor executor, QueryExecutorUser user) {
    if (armed && executor is TransactionExecutor) {
      armed = false;
      throw StateError('SqliteException(10): disk I/O error (BEGIN)');
    }
    return executor.ensureOpen(user);
  }
}

void main() {
  test('a transaction whose BEGIN fails releases the cross-tab lease', () async {
    final lock = FakeLock();
    final fail = FailBeginOnce();
    final db = AppDatabase.forTesting(
        NativeDatabase.memory().interceptWith(fail).interceptWith(CrossTabDbInterceptor(lock)));
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    expect(lock.held, 0);

    fail.armed = true;
    await expectLater(db.transaction(() async {
      await db.customSelect('SELECT 1').get();
    }), throwsA(anything));

    // Another "tab" sharing the lock must still get its turn.
    final other = AppDatabase.forTesting(NativeDatabase.memory().interceptWith(CrossTabDbInterceptor(lock)));
    addTearDown(other.close);
    expect(lock.held, 0, reason: 'lease leaked by the failed BEGIN');
    await other.customSelect('SELECT 1').get().timeout(const Duration(seconds: 2));
  });
}
