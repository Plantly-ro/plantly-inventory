import 'package:drift/drift.dart';

import '../data/database/app_database.dart';
import 'hlc.dart';
import 'sync_engine.dart';

/// What the runner does with a server-rejected op.
enum SyncRejectionKind {
  /// The server will never take this op: park it (`pushed_at` set) so the
  /// pending count drops, and list it for the user.
  permanent,

  /// Worth another try on a later cycle: leave it pending. Listed too, so a
  /// stuck op is visible rather than a forever "n changes waiting".
  transient,
}

/// Classifies `rejected[].reason` from a push reply (CLOUD-SYNC-CONTRACT
/// §2.2).
///
/// | reason          | kind      | note                                     |
/// |-----------------|-----------|------------------------------------------|
/// | `bad_hlc`       | permanent | malformed HLC — immutable, re-send is futile |
/// | `bad_entity`    | permanent | entity the server does not know          |
/// | `bad_value`     | permanent | payload failed validation                |
/// | `too_large`     | permanent | server-side size verdict on one op       |
/// | `bad_device_id` | permanent | request-level identity problem           |
/// | `hlc_future`    | transient | op's HLC ahead of server time — becomes acceptable once the wall clock catches up; retried until [transientGrace] after first seen |
/// | anything else   | transient | unknown code — retried with the same grace, then parked |
///
/// An op whose HLC does not even parse is permanent whatever the reason.
class SyncRejectionPolicy {
  const SyncRejectionPolicy({this.transientGrace = const Duration(hours: 24)});

  static const Set<String> permanentReasons = {
    'bad_hlc',
    'bad_entity',
    'bad_value',
    'too_large',
    'bad_device_id',
  };

  static const Set<String> transientReasons = {'hlc_future'};

  /// How long a transient rejection keeps being retried, measured from the
  /// first cycle that saw it ([firstSeenMillis]).
  final Duration transientGrace;

  SyncRejectionKind classify({
    required String reason,
    required String hlc,
    required int nowMillis,
    required int firstSeenMillis,
  }) {
    if (permanentReasons.contains(reason)) return SyncRejectionKind.permanent;
    try {
      Hlc.parse(hlc);
    } on FormatException {
      return SyncRejectionKind.permanent;
    }
    if (nowMillis - firstSeenMillis > transientGrace.inMilliseconds) {
      return SyncRejectionKind.permanent;
    }
    return SyncRejectionKind.transient;
  }
}

/// Outcome of [SyncRejectionStore.absorb] — what the status surface shows.
class SyncRejectionSummary {
  const SyncRejectionSummary({required this.total, required this.parked, required this.topReason});

  /// Rows currently listed for the tenant (parked + retrying).
  final int total;

  /// Of those, ops that were given up on.
  final int parked;

  /// Most frequent reason among the listed rows; null when none.
  final String? topReason;

  bool get isEmpty => total == 0;

  /// `SyncStatus.lastErrorDetail` shape: `'<n> changes could not be synced (<reason>)'`.
  String? get detail => isEmpty ? null : '$total change${total == 1 ? '' : 's'} could not be synced ($topReason)';
}

/// The `sync_rejections` table for one tenant: records what the server
/// refused, parks permanent ones, forgets rows once their op is accepted,
/// and offers the two user actions (retry everything / dismiss).
class SyncRejectionStore {
  SyncRejectionStore({
    required this.db,
    required this.tenantId,
    this.policy = const SyncRejectionPolicy(),
    int Function()? nowMillis,
  }) : _nowMillis = nowMillis ?? (() => DateTime.now().toUtc().millisecondsSinceEpoch);

  final AppDatabase db;
  final String tenantId;
  final SyncRejectionPolicy policy;
  final int Function() _nowMillis;

  /// Fold one push run into the table: drop rows for accepted ops, upsert
  /// rows for rejected ops, park the permanent ones. Ops the engine parked
  /// as too large (413) keep their own per-cycle `op_too_large` status and
  /// are not listed here.
  Future<SyncRejectionSummary> absorb(SyncPushResult pushed) async {
    final now = _nowMillis();
    await db.transaction(() async {
      if (pushed.acceptedSeqs.isNotEmpty) {
        await (db.delete(db.syncRejections)..where((r) => r.opSeq.isIn(pushed.acceptedSeqs))).go();
      }
      final toPark = <int>[];
      for (final r in pushed.rejected) {
        final existing = await _byOpSeq(r.seq);
        final firstSeen = existing?.at ?? now;
        final kind = policy.classify(reason: r.reason, hlc: r.hlc, nowMillis: now, firstSeenMillis: firstSeen);
        final parked = kind == SyncRejectionKind.permanent;
        await db.into(db.syncRejections).insert(
              SyncRejectionsCompanion.insert(
                opSeq: Value(r.seq),
                tenantId: tenantId,
                entity: r.entity,
                entityId: r.entityId,
                field: r.field,
                reason: r.reason,
                hlc: r.hlc,
                at: firstSeen,
                parked: Value(parked),
              ),
              mode: InsertMode.insertOrReplace,
            );
        if (parked) toPark.add(r.seq);
      }
      if (toPark.isNotEmpty) {
        await (db.update(db.syncOps)..where((o) => o.seq.isIn(toPark)))
            .write(SyncOpsCompanion(pushedAt: Value(now)));
      }
    });
    return summary();
  }

  Future<SyncRejectionRow?> _byOpSeq(int seq) =>
      (db.select(db.syncRejections)..where((r) => r.opSeq.equals(seq))).getSingleOrNull();

  Future<List<SyncRejectionRow>> all() => (db.select(db.syncRejections)
        ..where((r) => r.tenantId.equals(tenantId))
        ..orderBy([(r) => OrderingTerm.desc(r.at), (r) => OrderingTerm.desc(r.opSeq)]))
      .get();

  Stream<List<SyncRejectionRow>> watchAll() => (db.select(db.syncRejections)
        ..where((r) => r.tenantId.equals(tenantId))
        ..orderBy([(r) => OrderingTerm.desc(r.at), (r) => OrderingTerm.desc(r.opSeq)]))
      .watch();

  Future<SyncRejectionSummary> summary() async {
    final rows = await all();
    if (rows.isEmpty) return const SyncRejectionSummary(total: 0, parked: 0, topReason: null);
    final counts = <String, int>{};
    var parked = 0;
    for (final r in rows) {
      counts[r.reason] = (counts[r.reason] ?? 0) + 1;
      if (r.parked) parked++;
    }
    String? top;
    var best = 0;
    for (final e in counts.entries) {
      if (e.value > best) {
        best = e.value;
        top = e.key;
      }
    }
    return SyncRejectionSummary(total: rows.length, parked: parked, topReason: top);
  }

  /// User action "Retry all": un-park every listed op (`pushed_at` back to
  /// NULL so the next cycle sends it again) and forget the rows. Returns
  /// how many ops were re-queued.
  Future<int> retryAll() async {
    return db.transaction(() async {
      final rows = await all();
      if (rows.isEmpty) return 0;
      final seqs = [for (final r in rows) r.opSeq];
      await (db.update(db.syncOps)..where((o) => o.seq.isIn(seqs)))
          .write(const SyncOpsCompanion(pushedAt: Value(null)));
      await (db.delete(db.syncRejections)..where((r) => r.tenantId.equals(tenantId))).go();
      return seqs.length;
    });
  }

  /// User action "Dismiss": forget the rows. Parked ops stay parked (local
  /// only); retrying ones keep retrying and will be listed again if refused.
  Future<void> clear() =>
      (db.delete(db.syncRejections)..where((r) => r.tenantId.equals(tenantId))).go();
}
