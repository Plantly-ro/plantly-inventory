import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/database/cross_tab_lock.dart';
import 'package:plantly_inventory/data/mock_plants.dart';
import 'package:plantly_inventory/data/seed.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations_en.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// FIFO async mutex standing in for the `plantly-db` Web Lock; records who
/// held it and fails the test on overlap.
class FakeLock implements CrossTabLock {
  Future<void> _tail = Future.value();
  int acquisitions = 0;
  int held = 0;
  int maxHeld = 0;

  @override
  Future<void Function()> acquire() {
    final prev = _tail;
    final mine = Completer<void>();
    _tail = mine.future;
    return prev.then((_) {
      acquisitions++;
      held++;
      if (held > maxHeld) maxHeld = held;
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

/// Fails the next [failures] statements with [error].
class Flaky extends QueryInterceptor {
  Flaky(this.failures, this.error);
  int failures;
  final Object error;
  int calls = 0;

  @override
  Future<int> runInsert(QueryExecutor executor, String statement, List<Object?> args) {
    calls++;
    if (failures > 0) {
      failures--;
      throw error;
    }
    return executor.runInsert(statement, args);
  }
}

void main() {
  late FakeLock lock;
  setUp(() => lock = FakeLock());

  AppDatabase open(QueryExecutor e, {Duration maxShare = const Duration(milliseconds: 250)}) =>
      AppDatabase.forTesting(e.interceptWith(CrossTabDbInterceptor(lock, maxShare: maxShare, retryDelays: const [
        Duration(milliseconds: 1),
        Duration(milliseconds: 2),
        Duration(milliseconds: 4),
      ])));

  test('every statement runs under the lock; a transaction holds ONE lease from its first statement to commit', () async {
    final db = open(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    expect(lock.held, 0, reason: 'released after the statement');
    final before = lock.acquisitions;
    await db.transaction(() async {
      await db.customStatement("INSERT INTO tags (id, tenant_id, name, updated_hlc, device_id) VALUES ('t1','x','a','h','d')");
      expect(lock.held, 1, reason: 'held inside the transaction');
      await db.customStatement("INSERT INTO tags (id, tenant_id, name, updated_hlc, device_id) VALUES ('t2','x','b','h','d')");
      await db.transaction(() async {
        await db.customSelect('SELECT COUNT(*) FROM tags').get(); // nested: no second acquisition
      });
    });
    expect(lock.acquisitions - before, 1);
    expect(lock.held, 0);
    expect(lock.maxHeld, 1);
  });

  test('a failing transaction releases the lease (rollback)', () async {
    final db = open(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    await expectLater(
      db.transaction(() async {
        await db.customStatement("INSERT INTO tags (id, tenant_id, name, updated_hlc, device_id) VALUES ('t1','x','a','h','d')");
        throw StateError('boom');
      }),
      throwsStateError,
    );
    expect(lock.held, 0);
    expect(await db.customSelect('SELECT COUNT(*) AS n FROM tags').map((r) => r.read<int>('n')).getSingle(), 0);
  });

  test('two "tabs" (two connections, one file) writing at once: never overlap, every write lands', () async {
    final dir = await Directory.systemTemp.createTemp('xtab');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/db.sqlite');
    final a = open(NativeDatabase(file));
    final b = open(NativeDatabase(file));
    addTearDown(a.close);
    addTearDown(b.close);
    await a.customSelect('SELECT 1').get(); // creates the schema first
    Future<void> writer(AppDatabase db, String tag) async {
      for (var i = 0; i < 20; i++) {
        await db.transaction(() async {
          await db.customStatement(
              "INSERT INTO tags (id, tenant_id, name, updated_hlc, device_id) VALUES ('$tag$i','x','$tag$i','h','d')");
          await Future<void>.delayed(Duration.zero);
          await db.customSelect('SELECT COUNT(*) FROM tags').get();
        });
        await db.customSelect('SELECT COUNT(*) FROM tags').get();
      }
    }

    await Future.wait([writer(a, 'a'), writer(b, 'b')]);
    expect(lock.maxHeld, 1, reason: 'the two connections never held the lock together');
    expect(await b.customSelect('SELECT COUNT(*) AS n FROM tags').map((r) => r.read<int>('n')).getSingle(), 40);
  });

  test('backstop: I/O / busy errors outside a transaction retry with backoff; other errors do not', () async {
    final flaky = Flaky(2, SqliteException(10, 'disk I/O error'));
    final db = open(NativeDatabase.memory().interceptWith(flaky));
    addTearDown(db.close);
    await db.customInsert("INSERT INTO tags (id, tenant_id, name, updated_hlc, device_id) VALUES ('t1','x','a','h','d')");
    expect(flaky.calls, 3);
    expect(lock.held, 0);

    flaky
      ..failures = 1
      ..calls = 0;
    final other = Flaky(1, SqliteException(19, 'UNIQUE constraint failed'));
    final db2 = open(NativeDatabase.memory().interceptWith(other));
    addTearDown(db2.close);
    await expectLater(
      db2.customInsert("INSERT INTO tags (id, tenant_id, name, updated_hlc, device_id) VALUES ('t1','x','a','h','d')"),
      throwsA(isA<SqliteException>()),
    );
    expect(other.calls, 1);
  });

  test('isRetryableDbError: native codes (extended too) and remote error text', () {
    expect(isRetryableDbError(SqliteException(10, 'x')), isTrue);
    expect(isRetryableDbError(SqliteException(3850, 'x')), isTrue); // IOERR_LOCK
    expect(isRetryableDbError(SqliteException(5, 'x')), isTrue);
    expect(isRetryableDbError(SqliteException(19, 'x')), isFalse);
    expect(isRetryableDbError(Exception('Remote error: SqliteException(266): disk I/O error')), isTrue);
    expect(isRetryableDbError(StateError('nope')), isFalse);
  });

  test('a busy tab stops admitting newcomers after maxShare, so others get a turn', () async {
    final db = open(NativeDatabase.memory(), maxShare: const Duration(milliseconds: 20));
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    final before = lock.acquisitions;
    // A long transaction keeps the lease; statements issued meanwhile wait
    // for it to drain and re-acquire instead of sharing indefinitely.
    final tx = db.transaction(() async {
      await db.customSelect('SELECT 1').get();
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await Future<void>.delayed(const Duration(milliseconds: 40));
    await Future.wait([tx, db.customSelect('SELECT 2').get()]);
    expect(lock.acquisitions - before, 2);
    expect(lock.held, 0);
  });

  test('a lock wait that times out is retryable: the statement retries; a timed-out transaction start leaks nothing',
      () async {
    final timing = TimingOutLock(lock, timeouts: 1);
    final db = AppDatabase.forTesting(NativeDatabase.memory().interceptWith(CrossTabDbInterceptor(timing,
        retryDelays: const [Duration(milliseconds: 1), Duration(milliseconds: 2)])));
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    expect(timing.timedOut, 1);
    expect(isRetryableDbError(const CrossTabLockTimeout(Duration(seconds: 10))), isTrue);

    timing.timeouts = 1;
    await expectLater(db.transaction(() => db.customSelect('SELECT 1').get()), throwsA(isA<CrossTabLockTimeout>()));
    expect(lock.held, 0);
    await db.transaction(() => db.customSelect('SELECT 1').get());
    expect(lock.held, 0);
  });

  test('the lease is only taken once the connection is ready (never across the WASM / worker spin-up)', () async {
    final ready = Completer<void>();
    final db = AppDatabase.forTesting(
        NativeDatabase.memory().interceptWith(CrossTabDbInterceptor(lock, ready: ready.future)));
    addTearDown(db.close);
    final q = db.customSelect('SELECT 1').get();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(lock.acquisitions, 0, reason: 'nothing held while the connection is still opening');
    ready.complete();
    await q;
    expect(lock.acquisitions, greaterThan(0));
    expect(lock.held, 0);
  });

  test('two tabs booting at once seed the demo set ONCE (check + inserts are one leased transaction)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final dir = await Directory.systemTemp.createTemp('xtab-seed');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/db.sqlite');
    final a = open(NativeDatabase(file));
    final b = open(NativeDatabase(file));
    addTearDown(a.close);
    addTearDown(b.close);
    await a.customSelect('SELECT 1').get(); // schema
    await b.customSelect('SELECT 1').get();
    OpLogWriter log(AppDatabase db, int lane) =>
        OpLogWriter(db: db, clock: HlcClock(deviceId: 'dev', lane: lane), tenantId: 'local');
    await Future.wait([
      seedIfEmpty(db: a, opLog: log(a, 0), l10n: AppLocalizationsEn(), prefs: prefs),
      seedIfEmpty(db: b, opLog: log(b, 1), l10n: AppLocalizationsEn(), prefs: prefs),
    ]);
    Future<int> count(String table) =>
        a.customSelect('SELECT COUNT(*) AS n FROM $table').map((r) => r.read<int>('n')).getSingle();
    expect(await count('plants'), MockPlants.all.length);
    expect(await count('locations'), 3);
    expect(lock.maxHeld, 1);
  });
}

/// Throws [CrossTabLockTimeout] for the next [timeouts] acquisitions.
class TimingOutLock implements CrossTabLock {
  TimingOutLock(this.inner, {this.timeouts = 0});
  final CrossTabLock inner;
  int timeouts;
  int timedOut = 0;

  @override
  Future<void Function()> acquire() async {
    if (timeouts > 0) {
      timeouts--;
      timedOut++;
      throw const CrossTabLockTimeout(Duration(seconds: 10));
    }
    return inner.acquire();
  }
}
