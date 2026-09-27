
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/cloud/sync_runner.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/http_sync_runner.dart';
import 'package:plantly_inventory/sync/op_log.dart';
import 'package:plantly_inventory/sync/sync_engine.dart';
import 'package:plantly_inventory/sync/sync_rejections.dart';
import 'package:plantly_inventory/sync/sync_transport.dart';

String hlcAt(int ms, {String dev = 'dev-b'}) => Hlc(ms, 0, dev).encode();

SyncOpDto remotePlant(String id, int ms) => SyncOpDto(
      entity: 'plants',
      entityId: id,
      field: '*',
      value: {'id': id, 'nickname': 'R-$id', 'status': 'active', 'updated_hlc': hlcAt(ms), 'device_id': 'dev-b'},
      hlc: hlcAt(ms),
      deviceId: 'dev-b',
    );

/// Scripted server: an append-only log of ops with a numeric cursor.
class ScriptedTransport implements SyncTransport, CollectionUsageSource {
  final List<PushRequest> pushes = [];
  final List<PullRequest> pulls = [];
  int usageCalls = 0;

  /// Server-side log of ops from OTHER devices; index+1 = server_seq.
  final List<SyncOpDto> serverOps = [];
  int pageSize = 500;

  /// Thrown by the next push/pull calls (consumed in order).
  final List<Object> failures = [];

  /// When set, pushes whose encoded body exceeds this many bytes get a 413.
  int? rejectPushesOver;

  /// entity_id → reason: ops for these rows come back in `rejected[]`.
  final Map<String, String> rejectByEntityId = {};

  @override
  Future<PushResponse> push(PushRequest request) async {
    pushes.add(request);
    if (failures.isNotEmpty) throw failures.removeAt(0);
    final cap = rejectPushesOver;
    if (cap != null && utf8.encode(json.encode(request.toJson())).length > cap) {
      throw const SyncBatchTooLargeError();
    }
    final rejected = <OpRejection>[];
    for (var i = 0; i < request.ops.length; i++) {
      final reason = rejectByEntityId[request.ops[i].entityId];
      if (reason != null) rejected.add(OpRejection(opIndex: i, reason: reason));
    }
    final since = int.tryParse(request.since) ?? 0;
    final fresh = serverOps.skip(since).take(pageSize).toList();
    final cursor = since + fresh.length;
    return PushResponse(
      accepted: request.ops.length - rejected.length,
      rejected: rejected,
      cursor: '$cursor',
      freshOps: fresh,
      hasMore: cursor < serverOps.length,
    );
  }

  @override
  Future<PullResponse> pull(PullRequest request) async {
    pulls.add(request);
    if (failures.isNotEmpty) throw failures.removeAt(0);
    final since = int.tryParse(request.since) ?? 0;
    final ops = serverOps.skip(since).take(pageSize).toList();
    final cursor = since + ops.length;
    return PullResponse(ops: ops, cursor: '$cursor', hasMore: cursor < serverOps.length);
  }

  @override
  Future<CollectionUsage> usage() async {
    usageCalls++;
    return const CollectionUsage(bytesStored: 10, bytesQuota: 100);
  }
}

class InMemoryCursor implements SyncCursor {
  String value = '';
  @override
  Future<String> get() async => value;
  @override
  Future<void> set(String cursor) async => value = cursor;
}

void main() {
  const tenant = 'col-1';
  late AppDatabase db;
  late HlcClock clock;
  late OpLogWriter opLog;
  late ScriptedTransport transport;
  late InMemoryCursor cursor;
  HttpSyncRunner? runner;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = HlcClock(deviceId: 'dev-a');
    opLog = OpLogWriter(db: db, clock: clock, tenantId: tenant);
    transport = ScriptedTransport();
    cursor = InMemoryCursor();
  });
  tearDown(() async {
    await runner?.dispose();
    runner = null;
    await db.close();
  });

  HttpSyncRunner make({
    Duration debounce = const Duration(milliseconds: 40),
    Duration minBackoff = const Duration(milliseconds: 30),
    Duration maxBackoff = const Duration(milliseconds: 120),
    Duration usageInterval = const Duration(minutes: 10),
    Future<bool> Function()? refreshAuth,
    int batchSize = 500,
    DateTime Function()? now,
    SyncRejectionStore? rejections,
  }) {
    return runner = HttpSyncRunner(
      db: db,
      opLog: opLog,
      clock: clock,
      transport: transport,
      cursor: cursor,
      deviceId: 'dev-a',
      collectionId: tenant,
      usage: transport,
      refreshAuth: refreshAuth,
      rejections: rejections,
      debounce: debounce,
      periodic: Duration.zero,
      minBackoff: minBackoff,
      maxBackoff: maxBackoff,
      usageInterval: usageInterval,
      observeLifecycle: false,
      batchSize: batchSize,
      now: now,
    );
  }

  Future<void> localPlant(String id) async {
    final h = await opLog.recordCreate(entity: 'plants', entityId: id, value: {'id': id, 'nickname': id, 'status': 'active'});
    await db.into(db.plants).insert(PlantsCompanion.insert(id: id, tenantId: tenant, nickname: id, status: 'active', updatedHlc: h.encode(), deviceId: 'dev-a'));
  }

  Future<Set<String>> plantIds() async => {for (final p in await db.select(db.plants).get()) p.id};

  Future<void> settle([Duration d = const Duration(milliseconds: 20)]) => Future<void>.delayed(d);

  test('full loop: push pending → apply fresh_ops → pull until has_more=false → cursor + status', () async {
    await localPlant('L1');
    await localPlant('L2');
    transport.serverOps.addAll([for (var i = 1; i <= 5; i++) remotePlant('R$i', i * 1000)]);
    transport.pageSize = 2;

    final statuses = <SyncStatus>[];
    final r = make();
    final sub = r.status.listen(statuses.add);
    await r.syncNow();
    await settle();

    // One push (2 ops, since '0'), which streamed 2 fresh ops + has_more → pulls.
    expect(transport.pushes, hasLength(1));
    expect(transport.pushes.single.ops.map((o) => o.entityId), ['L1', 'L2']);
    expect(transport.pushes.single.toJson()['since'], '0');
    expect(transport.pulls.map((p) => p.since), ['2', '4']);
    expect(cursor.value, '5');
    expect(await plantIds(), {'L1', 'L2', 'R1', 'R2', 'R3', 'R4', 'R5'});
    expect(await opLog.pendingCount(), 0);

    final last = r.current;
    expect(last.inFlight, isFalse);
    expect(last.lastError, isNull);
    expect(last.lastSyncAt, isNotNull);
    expect(last.pendingOps, 0);
    expect(last.bytesStored, 10);
    expect(last.bytesQuota, 100);
    expect(statuses.any((s) => s.inFlight), isTrue);
    expect(statuses.first.pendingOps, 0); // replayed initial value
    await sub.cancel();
  });

  test('nothing pending → pull only, and remote ops never become pending', () async {
    transport.serverOps.add(remotePlant('R1', 1000));
    final r = make();
    await r.syncNow();
    expect(transport.pushes, isEmpty);
    expect(transport.pulls, hasLength(1));
    expect(await plantIds(), {'R1'});
    expect(await opLog.pendingCount(), 0);
    expect(r.current.pendingOps, 0);
  });

  test('initial upload: rows without ops get one synthesized `*` op carrying the row HLC', () async {
    // Pre-cloud data: rows exist, sync_ops is empty.
    await db.into(db.plants).insert(PlantsCompanion.insert(
        id: 'old-1', tenantId: tenant, nickname: 'Old', status: 'active', updatedHlc: hlcAt(123, dev: 'dev-a'), deviceId: 'dev-a'));
    await db.into(db.tags).insert(TagsCompanion.insert(id: 'tag-1', tenantId: tenant, name: 'sun', updatedHlc: hlcAt(124, dev: 'dev-a'), deviceId: 'dev-a'));
    await db.into(db.plants).insert(PlantsCompanion.insert(
        id: 'deleted', tenantId: tenant, nickname: 'x', status: 'active', updatedHlc: hlcAt(1, dev: 'dev-a'), deviceId: 'dev-a', deletedAt: const Value(5)));
    await db.into(db.plants).insert(PlantsCompanion.insert(
        id: 'other-tenant', tenantId: 'elsewhere', nickname: 'x', status: 'active', updatedHlc: hlcAt(1, dev: 'dev-a'), deviceId: 'dev-a'));

    final r = make();
    await r.syncNow();
    final ops = transport.pushes.single.ops;
    expect(ops.map((o) => (o.entity, o.entityId, o.field)).toSet(), {('plants', 'old-1', '*'), ('tags', 'tag-1', '*')});
    final plantOp = ops.firstWhere((o) => o.entityId == 'old-1');
    expect(plantOp.hlc, hlcAt(123, dev: 'dev-a'));
    expect((plantOp.value as Map)['nickname'], 'Old');
    expect((plantOp.value as Map)['updated_hlc'], hlcAt(123, dev: 'dev-a'));
    expect((plantOp.value as Map).containsKey('tenant_id'), isFalse);

    // Second cycle: nothing new to synthesize.
    await r.syncNow();
    expect(transport.pushes, hasLength(1));
  });

  test('local writes trigger one debounced sync', () async {
    final r = make(debounce: const Duration(milliseconds: 50));
    r.start();
    await settle(const Duration(milliseconds: 30));
    expect(transport.pushes, isEmpty); // start() pushed nothing (no pending)
    final pullsAfterStart = transport.pulls.length;

    await localPlant('a');
    await settle(const Duration(milliseconds: 10));
    await localPlant('b');
    expect(transport.pushes, isEmpty);
    await settle(const Duration(milliseconds: 120));
    expect(transport.pushes, hasLength(1));
    expect(transport.pushes.single.ops.map((o) => o.entityId), ['a', 'b']);
    expect(transport.pulls.length, pullsAfterStart); // push reply said has_more=false → no extra pull
    expect(r.current.pendingOps, 0);
  });

  test('429 → status retrying, exponential backoff, then success', () async {
    await localPlant('a');
    transport.failures.addAll([
      const SyncRetryableError('429', status: 429),
      const SyncRetryableError('503', status: 503),
    ]);
    final r = make(minBackoff: const Duration(milliseconds: 30), maxBackoff: const Duration(milliseconds: 500));
    final errors = <String?>[];
    final sub = r.status.listen((s) => errors.add(s.lastError));
    await r.syncNow();
    expect(r.current.lastError, 'retrying');
    expect(transport.pushes, hasLength(1));
    // retry #1 after ~30 ms, retry #2 after ~60 ms
    await settle(const Duration(milliseconds: 45));
    expect(transport.pushes, hasLength(2));
    expect(r.current.lastError, 'retrying');
    await settle(const Duration(milliseconds: 45));
    expect(transport.pushes, hasLength(2), reason: 'second backoff is longer');
    await settle(const Duration(milliseconds: 60));
    expect(transport.pushes, hasLength(3));
    expect(r.current.lastError, isNull);
    expect(await opLog.pendingCount(), 0);
    expect(errors, contains('retrying'));
    await sub.cancel();
  });

  test('Retry-After overrides the backoff and network errors read as offline', () async {
    await localPlant('a');
    transport.failures.add(const SyncRetryableError('net', retryAfter: Duration(milliseconds: 80)));
    final r = make(minBackoff: const Duration(milliseconds: 10));
    await r.syncNow();
    expect(r.current.lastError, 'offline');
    await settle(const Duration(milliseconds: 40));
    expect(transport.pushes, hasLength(1));
    await settle(const Duration(milliseconds: 70));
    expect(transport.pushes, hasLength(2));
    expect(r.current.lastError, isNull);
  });

  test('402 halts with cloud_required; debounce triggers are ignored until syncNow', () async {
    await localPlant('a');
    transport.failures.add(const SyncEntitlementError());
    final r = make(debounce: const Duration(milliseconds: 20));
    r.start();
    await settle(const Duration(milliseconds: 30));
    expect(r.current.lastError, 'cloud_required');
    expect(transport.pushes, hasLength(1));

    await localPlant('b');
    await settle(const Duration(milliseconds: 80));
    expect(transport.pushes, hasLength(1), reason: 'halted runner ignores local-write triggers');
    expect(r.current.pendingOps, 2);

    await r.syncNow();
    expect(transport.pushes, hasLength(2));
    expect(r.current.lastError, isNull);
    expect(r.current.pendingOps, 0);
  });

  test('401 → refresh once and retry; failing refresh → unauthorized', () async {
    await localPlant('a');
    transport.failures.add(const SyncAuthError());
    var refreshes = 0;
    final r = make(refreshAuth: () async {
      refreshes++;
      return true;
    });
    await r.syncNow();
    expect(refreshes, 1);
    expect(transport.pushes, hasLength(2));
    expect(r.current.lastError, isNull);

    transport.failures.addAll([const SyncAuthError(), const SyncAuthError()]);
    await localPlant('b');
    await r.syncNow();
    expect(refreshes, 2);
    expect(r.current.lastError, 'unauthorized');
  });

  test('403/404 halt with collection_unavailable', () async {
    transport.failures.add(const SyncCollectionError('collection_not_found', status: 404));
    final r = make();
    await r.syncNow();
    expect(r.current.lastError, 'collection_unavailable');
  });

  test('single-flight: concurrent syncNow calls share the cycle and queue exactly one follow-up', () async {
    await localPlant('a');
    final r = make();
    final f1 = r.syncNow();
    final f2 = r.syncNow();
    final f3 = r.syncNow();
    expect(identical(f1, f2), isTrue);
    expect(identical(f2, f3), isTrue);
    await f1;
    await settle(const Duration(milliseconds: 30));
    // First cycle pushed 'a'; the queued follow-up had nothing to push → pull only.
    expect(transport.pushes, hasLength(1));
    expect(transport.pulls, hasLength(1));
  });

  test('usage is fetched at most once per usageInterval', () async {
    var t = DateTime.utc(2026, 1, 1);
    final r = make(usageInterval: const Duration(minutes: 10), now: () => t);
    await r.syncNow();
    await r.syncNow();
    expect(transport.usageCalls, 1);
    t = t.add(const Duration(minutes: 11));
    await r.syncNow();
    expect(transport.usageCalls, 2);
  });

  test('pushes in batches of batchSize, each carrying the advancing cursor', () async {
    for (var i = 0; i < 7; i++) {
      await localPlant('p$i');
    }
    transport.serverOps.add(remotePlant('R1', 5));
    final r = make(batchSize: 3);
    await r.syncNow();
    expect(transport.pushes.map((p) => p.ops.length), [3, 3, 1]);
    expect(transport.pushes.map((p) => p.since), ['', '1', '1']); // '' → "0" on the wire
    expect(await plantIds(), containsAll(['p0', 'p6', 'R1']));
  });

  test('synthesizeInitialOps helper works without a network cycle', () async {
    await db.into(db.plants).insert(PlantsCompanion.insert(
        id: 'old', tenantId: tenant, nickname: 'Old', status: 'active', updatedHlc: hlcAt(7, dev: 'dev-a'), deviceId: 'dev-a'));
    await synthesizeInitialOps(db: db, opLog: opLog, deviceId: 'dev-a');
    expect(await opLog.pendingCount(), 1);
    final op = (await db.select(db.syncOps).get()).single;
    expect(op.field, '*');
    expect(op.hlc, hlcAt(7, dev: 'dev-a'));
  });

  test('an op the server refuses as too large is parked and surfaced as op_too_large; sync continues', () async {
    await localPlant('ok-1');
    await opLog.recordFieldUpdate(entity: 'plants', entityId: 'giant', field: 'notes', value: 'x' * 5000);
    await localPlant('ok-2');
    transport.rejectPushesOver = 3000;
    final r = make();
    await r.syncNow();
    expect(r.current.lastError, 'op_too_large');
    expect(r.current.lastErrorDetail, 'plants/giant');
    expect(r.current.pendingOps, 0);
    expect(r.current.lastSyncAt, isNotNull);
    // Next clean cycle clears it.
    await localPlant('ok-3');
    await r.syncNow();
    expect(r.current.lastError, isNull);
    expect(r.current.lastErrorDetail, isNull);
  });

  test('NoopSyncRunner is inert', () async {
    const n = NoopSyncRunner();
    await n.syncNow();
    final s = await n.status.first;
    expect(s.pendingOps, 0);
    expect(s.lastError, isNull);
  });

  group('server rejections', () {
    Future<SyncOpRow> opFor(String id) async =>
        (await (db.select(db.syncOps)..where((o) => o.entityId.equals(id))).getSingle());

    test('permanent (bad_hlc): parked, listed, surfaced as `rejected`; sticky until dismissed', () async {
      await localPlant('ok');
      await localPlant('bad');
      transport.rejectByEntityId['bad'] = 'bad_hlc';
      final r = make();
      await r.syncNow();

      expect(await opLog.pendingCount(), 0, reason: 'a permanent reject must not stay "waiting"');
      expect((await opFor('bad')).pushedAt, isNotNull);
      expect(r.current.lastError, 'rejected');
      expect(r.current.lastErrorDetail, '1 change could not be synced (bad_hlc)');
      expect(r.current.rejectedOps, 1);
      expect(r.current.rejectedReason, 'bad_hlc');
      expect(r.current.pendingOps, 0);
      expect(r.current.lastSyncAt, isNotNull);
      final row = (await r.rejections.all()).single;
      expect((row.entity, row.entityId, row.field, row.parked), ('plants', 'bad', '*', true));

      // Next cycle: the parked op is not re-sent, the verdict stays visible.
      await localPlant('later');
      await r.syncNow();
      expect(transport.pushes.last.ops.map((o) => o.entityId), ['later']);
      expect(r.current.lastError, 'rejected');
      expect(r.current.rejectedOps, 1);

      // Dismiss → next cycle is clean.
      await r.rejections.clear();
      await r.syncNow();
      expect(r.current.lastError, isNull);
      expect(r.current.lastErrorDetail, isNull);
      expect(r.current.rejectedOps, 0);
      expect(r.current.rejectedReason, isNull);
    });

    test('transient (hlc_future): stays pending, listed as retrying, re-sent next cycle; acceptance clears it', () async {
      await localPlant('f');
      transport.rejectByEntityId['f'] = 'hlc_future';
      final r = make();
      await r.syncNow();
      expect(await opLog.pendingCount(), 1);
      expect(r.current.lastError, 'rejected');
      expect(r.current.pendingOps, 1);
      expect((await r.rejections.all()).single.parked, isFalse);

      transport.rejectByEntityId.clear();
      await r.syncNow();
      expect(transport.pushes, hasLength(2));
      expect(transport.pushes.last.ops.single.entityId, 'f');
      expect(await opLog.pendingCount(), 0);
      expect(await r.rejections.all(), isEmpty);
      expect(r.current.lastError, isNull);
      expect(r.current.rejectedOps, 0);
    });

    test('transient past the 24 h grace window is parked', () async {
      var t = DateTime.utc(2026, 9, 27, 10);
      final store = SyncRejectionStore(db: db, tenantId: tenant, nowMillis: () => t.millisecondsSinceEpoch);
      await localPlant('f');
      transport.rejectByEntityId['f'] = 'hlc_future';
      final r = make(rejections: store, now: () => t);
      await r.syncNow();
      expect(await opLog.pendingCount(), 1);
      t = t.add(const Duration(hours: 25));
      await r.syncNow();
      expect(await opLog.pendingCount(), 0);
      expect((await store.all()).single.parked, isTrue);
      expect(r.current.lastError, 'rejected');
    });

    test('retryAll re-queues parked ops and a clean push clears the ledger', () async {
      await localPlant('bad');
      transport.rejectByEntityId['bad'] = 'bad_value';
      final r = make();
      await r.syncNow();
      expect(await opLog.pendingCount(), 0);

      transport.rejectByEntityId.clear();
      expect(await r.rejections.retryAll(), 1);
      expect(await opLog.pendingCount(), 1);
      await r.syncNow();
      expect(transport.pushes.last.ops.single.entityId, 'bad');
      expect(await opLog.pendingCount(), 0);
      expect(await r.rejections.all(), isEmpty);
      expect(r.current.lastError, isNull);
    });

    test('rejected outranks op_too_large in the status', () async {
      await localPlant('bad');
      transport.rejectByEntityId['bad'] = 'bad_hlc';
      await opLog.recordFieldUpdate(entity: 'plants', entityId: 'giant', field: 'notes', value: 'x' * 5000);
      transport.rejectPushesOver = 3000;
      final r = make();
      await r.syncNow();
      expect(r.current.lastError, 'rejected');
      expect(r.current.pendingOps, 0);
    });
  });

  group('one HLC clock', () {
    test('runner defaults to the op log\'s clock and refuses a different one', () {
      final r = make();
      expect(identical(r.clock, opLog.clock), isTrue);
      expect(
        () => HttpSyncRunner(
          db: db,
          opLog: opLog,
          clock: HlcClock(deviceId: 'dev-a'),
          transport: transport,
          cursor: cursor,
          deviceId: 'dev-a',
          collectionId: tenant,
          observeLifecycle: false,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('a remote op stamped in the far future is applied but does not drag the local clock along', () async {
      // The QA device merged `20260927102954-…` (year ~2612) and every later
      // local edit inherited that physical part. Now the merge is refused.
      transport.serverOps.add(remotePlant('R-2612', 20260927102954));
      final r = make();
      await r.syncNow();
      expect(await plantIds(), contains('R-2612'));
      expect(clock.ignoredRemoteCount, 1);
      final stamp = clock.now();
      final wall = DateTime.now().toUtc().millisecondsSinceEpoch;
      expect(stamp.physicalMs, lessThanOrEqualTo(wall + const Duration(minutes: 1).inMilliseconds));
      // Sanity: a peer only slightly ahead still merges.
      transport.serverOps.add(remotePlant('R-soon', wall + const Duration(hours: 1).inMilliseconds));
      await r.syncNow();
      expect(clock.ignoredRemoteCount, 1);
      expect(clock.now().physicalMs, greaterThanOrEqualTo(wall + const Duration(hours: 1).inMilliseconds));
    });
  });
}
