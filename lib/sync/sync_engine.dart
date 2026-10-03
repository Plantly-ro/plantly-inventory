import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database/app_database.dart';
import 'sync_transport.dart';

/// Persists the server cursor (`server_seq`, opaque string) — the high-water
/// mark of ops the client has received. Push sends it as `since` so the
/// server can stream back anything newer; every push/pull reply advances it.
/// Abstracted so tests inject an in-memory cursor.
abstract class SyncCursor {
  Future<String> get();
  Future<void> set(String cursor);
}

/// SharedPreferences-backed cursor, keyed per tenant (= collection id).
class PrefsSyncCursor implements SyncCursor {
  PrefsSyncCursor({required this.prefs, required this.tenantId});
  final SharedPreferences prefs;
  final String tenantId;

  String get _key => 'plantly_sync_cursor/$tenantId';

  @override
  Future<String> get() async => prefs.getString(_key) ?? '';

  @override
  Future<void> set(String cursor) async => prefs.setString(_key, cursor);
}

/// Outcome of a [SyncEngine.pushPending] run.
class SyncPushResult {
  const SyncPushResult({
    required this.sent,
    required this.accepted,
    required this.rejected,
    required this.batches,
    required this.cursor,
    required this.hasMore,
    required this.freshOps,
    this.tooLarge = const [],
    this.acceptedSeqs = const [],
  });

  final int sent;
  final int accepted;

  /// Local `seq` of every op the server accepted in this run (so a caller
  /// tracking earlier rejections can forget them).
  final List<int> acceptedSeqs;

  /// Rejections as reported by the server, paired with the local row's
  /// `seq` and identity so callers can surface / quarantine it. The runner
  /// hands these to `SyncRejectionStore`, which decides per reason whether
  /// the op stays pending or gets parked.
  final List<SyncRejectedOp> rejected;
  final int batches;

  /// Cursor after the last push (empty when nothing was pushed).
  final String cursor;

  /// The last reply signalled more fresh ops beyond [cursor].
  final bool hasMore;

  /// Total fresh ops handed to `onFresh`.
  final int freshOps;

  /// Ops the server refused as a batch of one (413): marked `pushed_at` so
  /// they can't wedge the queue, reported here for the UI.
  final List<SyncRejectedOp> tooLarge;

  bool get allAccepted => rejected.isEmpty && tooLarge.isEmpty;
}

/// One op the server would not take, with enough identity to list it.
class SyncRejectedOp {
  const SyncRejectedOp({
    required this.seq,
    required this.reason,
    required this.entity,
    required this.entityId,
    required this.field,
    required this.hlc,
  });

  factory SyncRejectedOp.fromRow(SyncOpRow row, String reason) => SyncRejectedOp(
        seq: row.seq,
        reason: reason,
        entity: row.entity,
        entityId: row.entityId,
        field: row.field,
        hlc: row.hlc,
      );

  final int seq;
  final String reason;
  final String entity;
  final String entityId;
  final String field;
  final String hlc;

  @override
  String toString() => 'SyncRejectedOp($entity/$entityId.$field seq=$seq reason=$reason)';
}

/// Drives op-log push against `sync_ops`.
///
/// Reads rows with `pushed_at IS NULL` for the tenant in `seq` order, ships
/// them through a [SyncTransport] in batches, and stamps `pushed_at` on the
/// ones the server accepted. Rejected rows are left unpushed and reported
/// (the runner's `SyncRejectionStore` parks the permanent ones); the scan
/// advances past them by `seq` so a persistent reject can't wedge the loop
/// into re-sending the same op forever within one run.
///
/// Each reply's `fresh_ops` (ops from other devices since `since`) are handed
/// to `onFresh` before the cursor advances, so a crash between the two leaves
/// the cursor behind — replaying is safe (the applier is idempotent).
class SyncEngine {
  SyncEngine({
    required this.db,
    required this.transport,
    required this.cursor,
    required this.tenantId,
    required this.deviceId,
    this.userId,
    this.batchSize = 500,
    this.maxBatchBytes = 3 * 1024 * 1024,
    int Function()? nowMillis,
  })  : _nowMillis = nowMillis ??
            (() => DateTime.now().toUtc().millisecondsSinceEpoch),
        _batchLimit = batchSize;

  final AppDatabase db;
  final SyncTransport transport;
  final SyncCursor cursor;
  final String tenantId;
  final String deviceId;

  /// Account this engine pushes for. Only ops with `user_id` NULL (legacy /
  /// signed-out writes) or equal to [userId] are pending *for this engine*;
  /// ops another account recorded on this device stay on disk until that
  /// account signs in again — never uploaded under the wrong bearer token.
  /// Null = only unattributed ops.
  final String? userId;

  /// Upper bound on ops per push (contract: ≤ 500).
  final int batchSize;

  /// Upper bound on the summed encoded size of the ops in one push. The
  /// server caps the body at 4 MiB; 3 MiB leaves headroom for the envelope.
  final int maxBatchBytes;
  final int Function() _nowMillis;

  /// Current count limit — halved on every 413 (min 1). Only shrinks within
  /// a run (resetting after each success would thrash: 8→4→2→ok→8→413…);
  /// doubles once at the start of every run so it probes back up to
  /// [batchSize] once payloads shrink again.
  int _batchLimit;

  /// Effective count limit right now (for tests / diagnostics).
  int get currentBatchLimit => _batchLimit;

  Future<int> pendingCount() async {
    final q = db.selectOnly(db.syncOps)
      ..addColumns([db.syncOps.seq.count()])
      ..where(db.syncOps.pushedAt.isNull() &
          db.syncOps.tenantId.equals(tenantId) &
          _ownedBy(db.syncOps));
    final row = await q.getSingle();
    return row.read(db.syncOps.seq.count()) ?? 0;
  }

  /// `user_id IS NULL [OR user_id = ?]` — see [userId].
  Expression<bool> _ownedBy($SyncOpsTable o) {
    final me = userId;
    return me == null ? o.userId.isNull() : (o.userId.isNull() | o.userId.equals(me));
  }

  /// Push all currently-pending ops. Returns a summary; on transport error the
  /// batches already accepted stay marked (partial progress is durable).
  ///
  /// Batches are bounded by BOTH count ([batchSize], halved after a 413) and
  /// bytes ([maxBatchBytes], measured as the UTF-8 JSON of each op). A 413 on
  /// a multi-op batch halves the count limit and retries the same rows; a 413
  /// on a single op marks that op `pushed_at` and reports it in
  /// [SyncPushResult.tooLarge] so the queue never wedges on it.
  Future<SyncPushResult> pushPending({
    Future<void> Function(List<SyncOpDto> fresh)? onFresh,
  }) async {
    var afterSeq = 0;
    var sent = 0;
    var accepted = 0;
    var batches = 0;
    var fresh = 0;
    var lastCursor = '';
    var hasMore = false;
    final rejected = <SyncRejectedOp>[];
    final tooLarge = <SyncRejectedOp>[];
    final acceptedSeqs = <int>[];
    _batchLimit = (_batchLimit * 2).clamp(1, batchSize);

    while (true) {
      final rows = await _nextBatch(afterSeq);
      if (rows.isEmpty) break;

      final ops = [for (final r in rows) SyncOpDto.fromRow(r)];
      final PushResponse resp;
      try {
        resp = await transport.push(PushRequest(
          deviceId: deviceId,
          ops: ops,
          since: await cursor.get(),
        ));
      } on SyncBatchTooLargeError {
        if (rows.length > 1) {
          _batchLimit = (rows.length ~/ 2).clamp(1, batchSize);
          continue; // same afterSeq → retry the head of the queue, smaller
        }
        // A single op the server will never take: park it.
        await (db.update(db.syncOps)..where((o) => o.seq.equals(rows.single.seq)))
            .write(SyncOpsCompanion(pushedAt: Value(_nowMillis())));
        tooLarge.add(SyncRejectedOp.fromRow(rows.single, 'too_large'));
        afterSeq = rows.single.seq;
        continue;
      }
      batches++;
      sent += rows.length;

      final rejectedIndexes = {for (final r in resp.rejected) r.opIndex};
      final batchAccepted = <int>[];
      for (var i = 0; i < rows.length; i++) {
        if (rejectedIndexes.contains(i)) {
          rejected.add(SyncRejectedOp.fromRow(rows[i], _reasonFor(resp.rejected, i)));
        } else {
          batchAccepted.add(rows[i].seq);
        }
      }

      if (batchAccepted.isNotEmpty) {
        final now = _nowMillis();
        await (db.update(db.syncOps)..where((o) => o.seq.isIn(batchAccepted)))
            .write(SyncOpsCompanion(pushedAt: Value(now)));
        accepted += batchAccepted.length;
        acceptedSeqs.addAll(batchAccepted);
      }

      if (resp.freshOps.isNotEmpty && onFresh != null) {
        await onFresh(resp.freshOps);
        fresh += resp.freshOps.length;
      }
      if (resp.cursor.isNotEmpty) {
        await cursor.set(resp.cursor);
        lastCursor = resp.cursor;
      }
      hasMore = resp.hasMore;

      // Advance past this batch (including rejects) so the loop terminates.
      afterSeq = rows.last.seq;
    }

    return SyncPushResult(
      sent: sent,
      accepted: accepted,
      rejected: rejected,
      batches: batches,
      cursor: lastCursor,
      hasMore: hasMore,
      freshOps: fresh,
      tooLarge: tooLarge,
      acceptedSeqs: acceptedSeqs,
    );
  }

  /// Next pending rows after [afterSeq], cut by count ([_batchLimit]) and by
  /// cumulative encoded bytes ([maxBatchBytes]). Always returns at least one
  /// row when any is pending, even if that row alone exceeds the byte cap.
  Future<List<SyncOpRow>> _nextBatch(int afterSeq) async {
    final rows = await (db.select(db.syncOps)
          ..where((o) =>
              o.pushedAt.isNull() &
              o.tenantId.equals(tenantId) &
              _ownedBy(o) &
              o.seq.isBiggerThanValue(afterSeq))
          ..orderBy([(o) => OrderingTerm.asc(o.seq)])
          ..limit(_batchLimit))
        .get();
    var bytes = 0;
    final out = <SyncOpRow>[];
    for (final r in rows) {
      final size = encodedOpSize(r);
      if (out.isNotEmpty && bytes + size > maxBatchBytes) break;
      out.add(r);
      bytes += size;
    }
    return out;
  }

  /// UTF-8 length of one op as it appears in the push body.
  static int encodedOpSize(SyncOpRow row) =>
      utf8.encode(json.encode(SyncOpDto.fromRow(row).toJson())).length;

  /// Pull from the persisted cursor until the server reports no more,
  /// handing each page to [onOps] before advancing the cursor.
  /// Returns the number of ops received.
  Future<int> pullAll({
    required Future<void> Function(List<SyncOpDto> ops) onOps,
    int maxPages = 1000,
  }) async {
    var received = 0;
    for (var page = 0; page < maxPages; page++) {
      final since = await cursor.get();
      final resp = await transport.pull(PullRequest(since: since, limit: batchSize));
      if (resp.ops.isNotEmpty) {
        await onOps(resp.ops);
        received += resp.ops.length;
      }
      if (resp.cursor.isNotEmpty && resp.cursor != since) {
        await cursor.set(resp.cursor);
      } else if (resp.hasMore) {
        // A server that says "more" without moving the cursor would loop us
        // forever; stop and let the next cycle retry.
        break;
      }
      if (!resp.hasMore) break;
    }
    return received;
  }

  String _reasonFor(List<OpRejection> rejections, int index) {
    for (final r in rejections) {
      if (r.opIndex == index) return r.reason;
    }
    return 'unknown';
  }
}
