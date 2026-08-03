import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database/app_database.dart';
import 'sync_transport.dart';

/// Persists the `last_seen_server_hlc` cursor — the high-water mark of ops the
/// client has pulled from the server. Push sends it so the server can stream
/// back anything newer; pull advances it. Abstracted so tests inject an
/// in-memory cursor.
abstract class SyncCursor {
  Future<String> get();
  Future<void> set(String hlc);
}

/// SharedPreferences-backed cursor, keyed per tenant.
class PrefsSyncCursor implements SyncCursor {
  PrefsSyncCursor({required this.prefs, required this.tenantId});
  final SharedPreferences prefs;
  final String tenantId;

  String get _key => 'plantly_sync_cursor/$tenantId';

  @override
  Future<String> get() async => prefs.getString(_key) ?? '';

  @override
  Future<void> set(String hlc) async => prefs.setString(_key, hlc);
}

/// Outcome of a [SyncEngine.pushPending] run.
class SyncPushResult {
  const SyncPushResult({
    required this.sent,
    required this.accepted,
    required this.rejected,
    required this.batches,
    required this.serverHlc,
  });

  final int sent;
  final int accepted;

  /// Rejections as reported by the server, paired with the local `seq` of the
  /// offending row so callers can surface / quarantine it.
  final List<({int seq, String reason})> rejected;
  final int batches;
  final String serverHlc;

  bool get allAccepted => rejected.isEmpty;
}

/// Drives op-log push against `sync_ops`.
///
/// Reads rows with `pushed_at IS NULL` for the tenant in `seq` order, ships
/// them through a [SyncTransport] in batches, and stamps `pushed_at` on the
/// ones the server accepted. Rejected rows are left unpushed and reported; the
/// scan advances past them by `seq` so a persistent reject can't wedge the loop
/// into re-sending the same op forever.
///
/// Pull/apply (field-level LWW + OR-Set reconciliation, PLAN.md §"Conflict
/// semantics") is intentionally NOT here yet — applying remote ops touches
/// every entity table and is best built and tested against the real server.
/// The transport's [SyncTransport.pull] shape is defined so that work is
/// purely additive. Tracked as a follow-up.
class SyncEngine {
  SyncEngine({
    required this.db,
    required this.transport,
    required this.cursor,
    required this.tenantId,
    required this.deviceId,
    this.batchSize = 500,
    int Function()? nowMillis,
  }) : _nowMillis = nowMillis ??
            (() => DateTime.now().toUtc().millisecondsSinceEpoch);

  final AppDatabase db;
  final SyncTransport transport;
  final SyncCursor cursor;
  final String tenantId;
  final String deviceId;
  final int batchSize;
  final int Function() _nowMillis;

  Future<int> pendingCount() async {
    final q = db.selectOnly(db.syncOps)
      ..addColumns([db.syncOps.seq.count()])
      ..where(
          db.syncOps.pushedAt.isNull() & db.syncOps.tenantId.equals(tenantId));
    final row = await q.getSingle();
    return row.read(db.syncOps.seq.count()) ?? 0;
  }

  /// Push all currently-pending ops. Returns a summary; on transport error the
  /// batches already accepted stay marked (partial progress is durable).
  Future<SyncPushResult> pushPending() async {
    final lastSeen = await cursor.get();
    var afterSeq = 0;
    var sent = 0;
    var accepted = 0;
    var batches = 0;
    var serverHlc = '';
    final rejected = <({int seq, String reason})>[];

    while (true) {
      final rows = await (db.select(db.syncOps)
            ..where((o) =>
                o.pushedAt.isNull() &
                o.tenantId.equals(tenantId) &
                o.seq.isBiggerThanValue(afterSeq))
            ..orderBy([(o) => OrderingTerm.asc(o.seq)])
            ..limit(batchSize))
          .get();
      if (rows.isEmpty) break;

      final ops = [for (final r in rows) SyncOpDto.fromRow(r)];
      final resp = await transport.push(PushRequest(
        deviceId: deviceId,
        ops: ops,
        lastSeenServerHlc: lastSeen,
      ));
      batches++;
      sent += rows.length;
      serverHlc = resp.serverHlc;

      final rejectedIndexes = {for (final r in resp.rejected) r.opIndex};
      final acceptedSeqs = <int>[];
      for (var i = 0; i < rows.length; i++) {
        if (rejectedIndexes.contains(i)) {
          rejected.add((seq: rows[i].seq, reason: _reasonFor(resp.rejected, i)));
        } else {
          acceptedSeqs.add(rows[i].seq);
        }
      }

      if (acceptedSeqs.isNotEmpty) {
        final now = _nowMillis();
        await (db.update(db.syncOps)..where((o) => o.seq.isIn(acceptedSeqs)))
            .write(SyncOpsCompanion(pushedAt: Value(now)));
        accepted += acceptedSeqs.length;
      }

      // Advance past this batch (including rejects) so the loop terminates.
      afterSeq = rows.last.seq;
    }

    return SyncPushResult(
      sent: sent,
      accepted: accepted,
      rejected: rejected,
      batches: batches,
      serverHlc: serverHlc,
    );
  }

  String _reasonFor(List<OpRejection> rejections, int index) {
    for (final r in rejections) {
      if (r.opIndex == index) return r.reason;
    }
    return 'unknown';
  }
}
