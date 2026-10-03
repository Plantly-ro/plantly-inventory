import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';
import 'package:plantly_inventory/sync/sync_engine.dart';
import 'package:plantly_inventory/sync/sync_rejections.dart';

void main() {
  const hour = Duration(hours: 1);
  final t0 = DateTime.utc(2026, 9, 27, 10).millisecondsSinceEpoch;
  final goodHlc = Hlc(t0, 0, 'dev-a').encode();

  group('SyncRejectionPolicy.classify', () {
    const policy = SyncRejectionPolicy();

    test('contract reasons: permanent set vs transient hlc_future', () {
      for (final reason in ['bad_hlc', 'bad_entity', 'bad_value', 'too_large', 'bad_device_id']) {
        expect(
          policy.classify(reason: reason, hlc: goodHlc, nowMillis: t0, firstSeenMillis: t0),
          SyncRejectionKind.permanent,
          reason: reason,
        );
      }
      expect(
        policy.classify(reason: 'hlc_future', hlc: goodHlc, nowMillis: t0, firstSeenMillis: t0),
        SyncRejectionKind.transient,
      );
    });

    test('unknown reasons are retried like hlc_future', () {
      expect(
        policy.classify(reason: 'brand_new_code', hlc: goodHlc, nowMillis: t0, firstSeenMillis: t0),
        SyncRejectionKind.transient,
      );
    });

    test('transient becomes permanent once the grace window since first seen is over', () {
      final inside = t0 + (hour * 24).inMilliseconds;
      final outside = inside + 1;
      expect(
        policy.classify(reason: 'hlc_future', hlc: goodHlc, nowMillis: inside, firstSeenMillis: t0),
        SyncRejectionKind.transient,
      );
      expect(
        policy.classify(reason: 'hlc_future', hlc: goodHlc, nowMillis: outside, firstSeenMillis: t0),
        SyncRejectionKind.permanent,
      );
    });

    test('an unparseable HLC is permanent whatever the reason', () {
      expect(
        policy.classify(reason: 'hlc_future', hlc: 'garbage', nowMillis: t0, firstSeenMillis: t0),
        SyncRejectionKind.permanent,
      );
    });
  });

  group('SyncRejectionStore', () {
    late AppDatabase db;
    late OpLogWriter opLog;
    late int now;
    late SyncRejectionStore store;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      opLog = OpLogWriter(db: db, clock: HlcClock(deviceId: 'dev-a'), tenantId: 'col-1');
      now = t0;
      store = SyncRejectionStore(db: db, tenantId: 'col-1', nowMillis: () => now);
    });
    tearDown(() => db.close());

    Future<SyncOpRow> op(String id) async {
      await opLog.recordCreate(entity: 'plants', entityId: id, value: {'id': id, 'nickname': id, 'status': 'active'});
      return (await (db.select(db.syncOps)..where((o) => o.entityId.equals(id))).getSingle());
    }

    SyncPushResult result({List<SyncRejectedOp> rejected = const [], List<int> accepted = const []}) => SyncPushResult(
          sent: rejected.length + accepted.length,
          accepted: accepted.length,
          rejected: rejected,
          batches: 1,
          cursor: '1',
          hasMore: false,
          freshOps: 0,
          acceptedSeqs: accepted,
        );

    test('permanent → row parked + op pushed_at set; summary carries count + reason', () async {
      final bad = await op('bad');
      final summary = await store.absorb(result(rejected: [SyncRejectedOp.fromRow(bad, 'bad_hlc')]));
      expect(summary.total, 1);
      expect(summary.parked, 1);
      expect(summary.topReason, 'bad_hlc');
      expect(summary.detail, '1 change could not be synced (bad_hlc)');
      final row = (await store.all()).single;
      expect(row.opSeq, bad.seq);
      expect((row.entity, row.entityId, row.field, row.hlc), ('plants', 'bad', '*', bad.hlc));
      expect(row.parked, isTrue);
      expect(row.at, t0);
      expect(await opLog.pendingCount(), 0);
    });

    test('transient → listed but still pending; first-seen sticks across cycles; parks after the grace window', () async {
      final f = await op('f');
      await store.absorb(result(rejected: [SyncRejectedOp.fromRow(f, 'hlc_future')]));
      expect((await store.all()).single.parked, isFalse);
      expect(await opLog.pendingCount(), 1);

      now = t0 + (hour * 12).inMilliseconds;
      await store.absorb(result(rejected: [SyncRejectedOp.fromRow(f, 'hlc_future')]));
      expect((await store.all()).single.at, t0, reason: 'first seen is not reset by a re-reject');
      expect(await opLog.pendingCount(), 1);

      now = t0 + (hour * 25).inMilliseconds;
      final summary = await store.absorb(result(rejected: [SyncRejectedOp.fromRow(f, 'hlc_future')]));
      expect(summary.parked, 1);
      expect((await store.all()).single.parked, isTrue);
      expect(await opLog.pendingCount(), 0);
    });

    test('acceptance forgets the row; plural detail + most common reason', () async {
      final a = await op('a');
      final b = await op('b');
      final c = await op('c');
      await store.absorb(result(rejected: [
        SyncRejectedOp.fromRow(a, 'hlc_future'),
        SyncRejectedOp.fromRow(b, 'bad_value'),
        SyncRejectedOp.fromRow(c, 'bad_value'),
      ]));
      expect((await store.summary()).detail, '3 changes could not be synced (bad_value)');
      final after = await store.absorb(result(accepted: [a.seq]));
      expect(after.total, 2);
      expect((await store.all()).map((r) => r.opSeq), unorderedEquals([b.seq, c.seq]));
    });

    test('retryAll un-parks and empties the ledger; clear only empties it', () async {
      final a = await op('a');
      final b = await op('b');
      await store.absorb(result(rejected: [SyncRejectedOp.fromRow(a, 'bad_hlc'), SyncRejectedOp.fromRow(b, 'bad_hlc')]));
      expect(await opLog.pendingCount(), 0);
      expect(await store.retryAll(), 2);
      expect(await opLog.pendingCount(), 2);
      expect(await store.all(), isEmpty);

      await store.absorb(result(rejected: [SyncRejectedOp.fromRow(a, 'bad_hlc')]));
      await store.clear();
      expect(await store.all(), isEmpty);
      expect(await opLog.pendingCount(), 1, reason: 'dismiss leaves the parked op parked');
    });

    test('ledger is tenant-scoped', () async {
      final a = await op('a');
      await store.absorb(result(rejected: [SyncRejectedOp.fromRow(a, 'bad_hlc')]));
      final other = SyncRejectionStore(db: db, tenantId: 'col-2', nowMillis: () => now);
      expect(await other.all(), isEmpty);
      expect((await other.summary()).isEmpty, isTrue);
      // Companion round-trip sanity for the generated table.
      await db.into(db.syncRejections).insert(SyncRejectionsCompanion.insert(
            opSeq: const Value(999),
            tenantId: 'col-2',
            entity: 'tags',
            entityId: 't',
            field: 'name',
            reason: 'bad_value',
            hlc: goodHlc,
            at: now,
          ));
      expect((await other.all()).single.parked, isFalse);
    });
  });
}
