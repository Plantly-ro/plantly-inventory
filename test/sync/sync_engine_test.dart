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
  FakeSyncTransport({this.serverHlc = 'srv-1'});
  final String serverHlc;

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
      serverHlc: serverHlc,
    );
  }

  @override
  Future<PullResponse> pull(PullRequest request) async =>
      PullResponse(ops: const [], serverHlc: serverHlc, hasMore: false);
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
    expect(ops[0].value, {'nickname': 'Bob'});
    expect(ops[1].field, 'water_days');
    expect(ops[1].value, 7);
    expect(ops[2].field, '__tombstone__');
    expect(ops[2].value, isNull);
  });

  test('sends last_seen_server_hlc from the cursor', () async {
    await opLog.recordCreate(entity: 'plants', entityId: 'p1', value: {'n': 1});
    final cursor = InMemoryCursor()..value = 'srv-cursor-42';
    final t = FakeSyncTransport();
    await engine(t, cursor: cursor).pushPending();
    expect(t.pushes.single.lastSeenServerHlc, 'srv-cursor-42');
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
}
