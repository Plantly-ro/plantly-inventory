import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';
import 'package:plantly_inventory/sync/sync_engine.dart';
import 'package:plantly_inventory/sync/sync_transport.dart';

/// Records every push and replies with a scripted response. By default it
/// accepts everything.
class FakeSyncTransport implements SyncTransport {
  FakeSyncTransport({this.serverCursor = '1'});
  final String serverCursor;

  final List<PushRequest> pushes = [];

  /// opIndex → reason, applied to whichever batch the index falls in.
  Set<int> Function(PushRequest req)? rejectIndexes;

  @override
  Future<PushResponse> push(PushRequest request) async {
    pushes.add(request);
    final rejects = rejectIndexes?.call(request) ?? const <int>{};
    return PushResponse(
      accepted: request.ops.length - rejects.length,
      rejected: [
        for (final i in rejects) OpRejection(opIndex: i, reason: 'bad-op')
      ],
      cursor: serverCursor,
    );
  }

  @override
  Future<PullResponse> pull(PullRequest request) async =>
      PullResponse(ops: const [], cursor: serverCursor, hasMore: false);
}

class InMemoryCursor implements SyncCursor {
  String value = '';
  @override
  Future<String> get() async => value;
  @override
  Future<void> set(String hlc) async => value = hlc;
}

void main() {
  late AppDatabase db;
  late OpLogWriter opLog;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    opLog = OpLogWriter(
      db: db,
      clock: HlcClock(deviceId: 'dev-a'),
      tenantId: 'tenant-local',
    );
  });
  tearDown(() => db.close());

  Future<List<SyncOpRow>> allOps() =>
      (db.select(db.syncOps)..orderBy([(o) => OrderingTerm.asc(o.seq)])).get();

  SyncEngine engine(SyncTransport t,
          {SyncCursor? cursor, int batchSize = 500}) =>
      SyncEngine(
        db: db,
        transport: t,
        cursor: cursor ?? InMemoryCursor(),
        tenantId: 'tenant-local',
        deviceId: 'dev-a',
        batchSize: batchSize,
        nowMillis: () => 1234,
      );

  test('pushes all pending ops and stamps pushed_at on acceptance', () async {
    await opLog.recordCreate(
        entity: 'plants', entityId: 'p1', value: {'nickname': 'Bob'});
    await opLog
        .recordFieldUpdate(entity: 'plants', entityId: 'p1', field: 'notes', value: 'hi');
    await opLog.recordTombstone(entity: 'plants', entityId: 'p1');

    final t = FakeSyncTransport();
    final result = await engine(t).pushPending();

    expect(result.sent, 3);
    expect(result.accepted, 3);
    expect(result.allAccepted, isTrue);
    expect(t.pushes, hasLength(1));
    expect(await engine(t).pendingCount(), 0);
    for (final row in await allOps()) {
      expect(row.pushedAt, 1234);
    }
  });

  test('op DTOs carry decoded values and the wire field sentinels', () async {
    await opLog.recordCreate(
        entity: 'plants', entityId: 'p1', value: {'nickname': 'Bob'});
    await opLog.recordFieldUpdate(
        entity: 'plants', entityId: 'p1', field: 'water_days', value: 7);
    await opLog.recordTombstone(entity: 'plants', entityId: 'p1');

    final t = FakeSyncTransport();
    await engine(t).pushPending();

    final ops = t.pushes.single.ops;
    expect(ops[0].field, '*');
    // `*` payloads are canonicalised through the entity codec: full row.
    expect((ops[0].value as Map)['nickname'], 'Bob');
    expect((ops[0].value as Map)['id'], 'p1');
    expect((ops[0].value as Map).containsKey('tenant_id'), isFalse);
    expect(ops[1].field, 'water_days');
    expect(ops[1].value, 7);
    expect(ops[2].field, '__tombstone__');
    expect(ops[2].value, isNull);
  });

  test('sends `since` from the cursor and advances it from the reply', () async {
    await opLog.recordCreate(entity: 'plants', entityId: 'p1', value: {'n': 1});
    final cursor = InMemoryCursor()..value = '42';
    final t = FakeSyncTransport(serverCursor: '57');
    await engine(t, cursor: cursor).pushPending();
    expect(t.pushes.single.since, '42');
    expect(cursor.value, '57');
  });

  test('empty cursor is sent as "0" on the wire', () async {
    await opLog.recordCreate(entity: 'plants', entityId: 'p1', value: {'n': 1});
    final t = FakeSyncTransport();
    await engine(t).pushPending();
    expect(t.pushes.single.toJson()['since'], '0');
  });

  test('fresh_ops are handed to onFresh before the cursor advances', () async {
    await opLog.recordCreate(entity: 'plants', entityId: 'p1', value: {'n': 1});
    final cursor = InMemoryCursor();
    final t = _FreshTransport();
    String? cursorWhenFresh;
    final res = await engine(t, cursor: cursor).pushPending(onFresh: (ops) async {
      cursorWhenFresh = cursor.value;
      expect(ops.single.entityId, 'remote-1');
    });
    expect(res.freshOps, 1);
    expect(res.hasMore, isTrue);
    expect(cursorWhenFresh, '');
    expect(cursor.value, '9');
  });

  test('pullAll pages until has_more is false and persists the cursor', () async {
    final cursor = InMemoryCursor();
    final t = _PagingTransport(pages: 3);
    final pages = <int>[];
    final n = await engine(t, cursor: cursor).pullAll(onOps: (ops) async => pages.add(ops.length));
    expect(n, 3);
    expect(pages, [1, 1, 1]);
    expect(t.sinces, ['', '1', '2']);
    expect(cursor.value, '3');
  });

  test('batches large op sets and does not exceed batchSize per push',
      () async {
    for (var i = 0; i < 7; i++) {
      await opLog.recordCreate(entity: 'plants', entityId: 'p$i', value: {'i': i});
    }
    final t = FakeSyncTransport();
    final result = await engine(t, batchSize: 3).pushPending();

    expect(result.sent, 7);
    expect(result.accepted, 7);
    expect(result.batches, 3); // 3 + 3 + 1
    expect(t.pushes.map((p) => p.ops.length), [3, 3, 1]);
    expect(await engine(t).pendingCount(), 0);
  });

  test('rejected ops stay pending, are reported, and do not wedge the loop',
      () async {
    for (var i = 0; i < 4; i++) {
      await opLog.recordCreate(entity: 'plants', entityId: 'p$i', value: {'i': i});
    }
    // Reject index 1 within the (single) batch.
    final t = FakeSyncTransport()..rejectIndexes = (_) => {1};

    final result = await engine(t).pushPending();

    expect(result.sent, 4);
    expect(result.accepted, 3);
    expect(result.rejected, hasLength(1));
    expect(result.rejected.single.reason, 'bad-op');
    expect(result.rejected.single.entity, 'plants');
    expect(result.rejected.single.entityId, 'p1');
    expect(result.rejected.single.field, '*');
    expect(result.rejected.single.hlc, isNotEmpty);
    expect(result.acceptedSeqs, hasLength(3));
    expect(result.acceptedSeqs, isNot(contains(result.rejected.single.seq)));

    // One row remains pending; the loop terminated (single push, no resend).
    expect(t.pushes, hasLength(1));
    expect(await engine(t).pendingCount(), 1);
    final pending =
        (await allOps()).where((o) => o.pushedAt == null).toList();
    expect(pending, hasLength(1));
    expect(pending.single.entityId, 'p1');
  });

  test('no-op when nothing is pending', () async {
    final t = FakeSyncTransport();
    final result = await engine(t).pushPending();
    expect(result.sent, 0);
    expect(result.batches, 0);
    expect(t.pushes, isEmpty);
  });

  group('byte cap + 413', () {
    Future<void> bigCreate(String id, int approxBytes) => opLog.recordCreate(
        entity: 'plants', entityId: id, value: {'nickname': 'x' * approxBytes});

    test('batches are cut by cumulative encoded bytes as well as count', () async {
      for (var i = 0; i < 5; i++) {
        await bigCreate('p$i', 400);
      }
      final rows = await allOps();
      final one = SyncEngine.encodedOpSize(rows.first);
      expect(one, greaterThan(400));
      final t = FakeSyncTransport();
      final e = SyncEngine(
        db: db, transport: t, cursor: InMemoryCursor(), tenantId: 'tenant-local', deviceId: 'dev-a',
        batchSize: 500, maxBatchBytes: one * 2 + 10, nowMillis: () => 1,
      );
      final r = await e.pushPending();
      expect(r.sent, 5);
      expect(t.pushes.map((p) => p.ops.length), [2, 2, 1]);
      expect(await e.pendingCount(), 0);
    });

    test('413 on a multi-op batch halves the batch and retries the same rows until it fits', () async {
      for (var i = 0; i < 8; i++) {
        await opLog.recordCreate(entity: 'plants', entityId: 'p$i', value: {'n': i});
      }
      final t = _TooLargeTransport(maxOps: 2);
      final e = engine(t);
      final r = await e.pushPending();
      expect(r.sent, 8);
      expect(r.accepted, 8);
      expect(r.tooLarge, isEmpty);
      expect(t.attempts, [8, 4, 2, 2, 2, 2]);
      expect(t.pushes.map((p) => p.ops.first.entityId), ['p0', 'p2', 'p4', 'p6']);
      expect(await e.pendingCount(), 0);
      // The limit only shrinks within a run and probes back up (×2) per run.
      expect(e.currentBatchLimit, 2);
      for (var i = 8; i < 13; i++) {
        await opLog.recordCreate(entity: 'plants', entityId: 'p$i', value: {'n': i});
      }
      t.attempts.clear();
      await e.pushPending();
      expect(t.attempts, [4, 2, 2, 1]);
      expect(e.currentBatchLimit, 2);
    });

    test('a single op the server still refuses is parked (pushed_at) and reported, not resent', () async {
      await opLog.recordCreate(entity: 'plants', entityId: 'small-1', value: {'n': 1});
      await bigCreate('giant', 5000);
      await opLog.recordCreate(entity: 'plants', entityId: 'small-2', value: {'n': 2});
      final t = _TooLargeTransport(maxOps: 500, maxBytes: 3000);
      final e = engine(t);
      final r = await e.pushPending();
      expect(r.tooLarge, hasLength(1));
      expect(r.tooLarge.single.entity, 'plants');
      expect(r.tooLarge.single.entityId, 'giant');
      expect(r.accepted, 2);
      expect(r.allAccepted, isFalse);
      expect(await e.pendingCount(), 0);
      final giant = (await allOps()).firstWhere((o) => o.entityId == 'giant');
      expect(giant.pushedAt, 1234);
      // Second run: nothing pending, no resend.
      final r2 = await e.pushPending();
      expect(r2.sent, 0);
      expect(r2.tooLarge, isEmpty);
    });
  });

  test('only pushes the given tenant\'s ops', () async {
    await opLog.recordCreate(entity: 'plants', entityId: 'p1', value: {'n': 1});
    final otherTenant = OpLogWriter(
        db: db, clock: HlcClock(deviceId: 'dev-a'), tenantId: 'tenant-other');
    await otherTenant.recordCreate(
        entity: 'plants', entityId: 'x1', value: {'n': 2});

    final t = FakeSyncTransport();
    final result = await engine(t).pushPending();

    expect(result.sent, 1);
    expect(t.pushes.single.ops.single.entityId, 'p1');
  });

  group('account attribution (sync_ops.user_id)', () {
    SyncEngine forUser(SyncTransport t, String? userId) => SyncEngine(
          db: db,
          transport: t,
          cursor: InMemoryCursor(),
          tenantId: 'tenant-local',
          deviceId: 'dev-a',
          userId: userId,
          nowMillis: () => 1234,
        );

    test('local ops are stamped with the writer\'s current user; remote/synthesized-without-user stay null', () async {
      String? me = 'u-1';
      final stamped = OpLogWriter(db: db, clock: HlcClock(deviceId: 'dev-a'), tenantId: 'tenant-local', currentUserId: () => me);
      await stamped.recordCreate(entity: 'plants', entityId: 'p1', value: {'n': 1});
      await stamped.recordFieldUpdate(entity: 'plants', entityId: 'p1', field: 'notes', value: 'x');
      await stamped.recordTombstone(entity: 'plants', entityId: 'p1');
      await stamped.recordSynthesized(entity: 'plants', entityId: 'p2', wireRow: {'id': 'p2'}, hlc: 'h', deviceId: 'dev-a');
      me = null; // signed out: unattributed
      await stamped.recordCreate(entity: 'plants', entityId: 'p3', value: {'n': 3});
      await opLog.recordCreate(entity: 'plants', entityId: 'p4', value: {'n': 4}); // writer without the closure
      await stamped.recordRemote(
        const SyncOpDto(entity: 'plants', entityId: 'r1', field: 'notes', value: 'v', hlc: 'h2', deviceId: 'dev-b'),
        deviceId: 'dev-b',
        nowMillis: 1,
      );
      final rows = await allOps();
      expect({for (final r in rows) r.entityId: r.userId}, {'p1': 'u-1', 'p2': 'u-1', 'p3': null, 'p4': null, 'r1': null});
      expect(rows.where((r) => r.entityId == 'p1').map((r) => r.userId), everyElement('u-1'));
    });

    test('an engine for u-2 never pushes u-1\'s pending ops; legacy (null) ops go with anyone; pendingCount agrees', () async {
      final alice = OpLogWriter(db: db, clock: HlcClock(deviceId: 'dev-a'), tenantId: 'tenant-local', currentUserId: () => 'u-1');
      final bob = OpLogWriter(db: db, clock: HlcClock(deviceId: 'dev-a'), tenantId: 'tenant-local', currentUserId: () => 'u-2');
      await alice.recordCreate(entity: 'plants', entityId: 'a1', value: {'n': 1});
      await alice.recordFieldUpdate(entity: 'plants', entityId: 'a1', field: 'notes', value: 'x');
      await opLog.recordCreate(entity: 'plants', entityId: 'legacy', value: {'n': 0});
      await bob.recordCreate(entity: 'plants', entityId: 'b1', value: {'n': 2});

      expect(await forUser(FakeSyncTransport(), 'u-2').pendingCount(), 2, reason: 'b1 + legacy');
      expect(await forUser(FakeSyncTransport(), 'u-1').pendingCount(), 3, reason: 'a1 ×2 + legacy');
      expect(await forUser(FakeSyncTransport(), null).pendingCount(), 1, reason: 'signed out: only unattributed');

      final t = FakeSyncTransport();
      final r = await forUser(t, 'u-2').pushPending();
      expect(r.sent, 2);
      expect(t.pushes.single.ops.map((o) => o.entityId), ['legacy', 'b1']);
      expect(await forUser(t, 'u-2').pendingCount(), 0);

      final left = (await allOps()).where((o) => o.pushedAt == null).toList();
      expect(left.map((o) => o.entityId), ['a1', 'a1']);
      expect(left.map((o) => o.userId), everyElement('u-1'), reason: 'still alice\'s, still pending');

      // Alice signs back in: hers go up, nothing is re-sent.
      final t2 = FakeSyncTransport();
      final r2 = await forUser(t2, 'u-1').pushPending();
      expect(r2.sent, 2);
      expect(t2.pushes.single.ops.map((o) => o.entityId), ['a1', 'a1']);
      expect(await forUser(t2, 'u-1').pendingCount(), 0);
    });

    test('signed-out engine (userId null) leaves every attributed op alone', () async {
      final alice = OpLogWriter(db: db, clock: HlcClock(deviceId: 'dev-a'), tenantId: 'tenant-local', currentUserId: () => 'u-1');
      await alice.recordCreate(entity: 'plants', entityId: 'a1', value: {'n': 1});
      final t = FakeSyncTransport();
      final r = await forUser(t, null).pushPending();
      expect(r.sent, 0);
      expect(t.pushes, isEmpty);
    });
  });
}

class _FreshTransport extends FakeSyncTransport {
  @override
  Future<PushResponse> push(PushRequest request) async {
    pushes.add(request);
    return PushResponse(
      accepted: request.ops.length,
      rejected: const [],
      cursor: '9',
      hasMore: true,
      freshOps: const [
        SyncOpDto(
          entity: 'plants',
          entityId: 'remote-1',
          field: 'notes',
          value: 'x',
          hlc: '00000000000001-00000-dev-b',
          deviceId: 'dev-b',
        ),
      ],
    );
  }
}

class _PagingTransport extends FakeSyncTransport {
  _PagingTransport({required this.pages});
  final int pages;
  final List<String> sinces = [];

  @override
  Future<PullResponse> pull(PullRequest request) async {
    sinces.add(request.since);
    final page = sinces.length;
    return PullResponse(
      ops: [
        SyncOpDto(
          entity: 'plants',
          entityId: 'r$page',
          field: 'notes',
          value: 'v',
          hlc: '0000000000000$page-00000-dev-b',
        ),
      ],
      cursor: '$page',
      hasMore: page < pages,
    );
  }
}

/// Rejects a push with 413 when it exceeds [maxOps] ops or [maxBytes] of
/// encoded ops; records the size of every attempt.
class _TooLargeTransport extends FakeSyncTransport {
  _TooLargeTransport({required this.maxOps, this.maxBytes});
  final int maxOps;
  final int? maxBytes;
  final List<int> attempts = [];

  @override
  Future<PushResponse> push(PushRequest request) async {
    attempts.add(request.ops.length);
    final bytes = utf8.encode(json.encode(request.toJson())).length;
    if (request.ops.length > maxOps || (maxBytes != null && bytes > maxBytes!)) {
      throw const SyncBatchTooLargeError();
    }
    return super.push(request);
  }
}
