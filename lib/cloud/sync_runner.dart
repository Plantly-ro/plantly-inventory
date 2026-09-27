import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Snapshot of the cloud sync loop for the status surface (Me → Cloud,
/// CLOUD-SYNC-CONTRACT §2.4). Emitted by [SyncRunner.status]; every field
/// is optional so the no-op runner and a half-initialised engine can both
/// describe themselves honestly.
class SyncStatus {
  const SyncStatus({
    this.lastSyncAt,
    this.pendingOps = 0,
    this.bytesStored,
    this.bytesQuota,
    this.inFlight = false,
    this.lastError,
    this.lastErrorDetail,
  });

  /// UTC time of the last push/pull round that completed without error.
  final DateTime? lastSyncAt;

  /// `sync_ops` rows with `pushed_at IS NULL` for the linked collection.
  final int pendingOps;

  /// From `GET /collections/{id}/usage`; null until first fetched.
  final int? bytesStored;
  final int? bytesQuota;

  /// A push/pull round (or a manual "Sync now") is running.
  final bool inFlight;

  /// Stable code for the last failure, cleared on success. Well-known
  /// values the UI maps to copy (`describeSyncError`): `cloud_required`
  /// (402), `unauthorized` (401 after refresh failed),
  /// `collection_unavailable` (403/404), `quota_exceeded` (photo 413),
  /// `op_too_large` (a single op the server refuses), `retrying`
  /// (429/5xx, backing off), `offline` (network), `error` (anything else).
  /// Unknown values are shown raw.
  final String? lastError;

  /// Optional detail for [lastError] — for `op_too_large` the first
  /// offending `<entity>/<entity_id>` plus a count. Cleared together with
  /// [lastError].
  final String? lastErrorDetail;

  static const SyncStatus empty = SyncStatus();

  /// [clearError] nulls both [lastError] and [lastErrorDetail]; setting a
  /// new [lastError] without a [lastErrorDetail] drops the stale detail.
  SyncStatus copyWith({
    Object? lastSyncAt = _unset,
    int? pendingOps,
    Object? bytesStored = _unset,
    Object? bytesQuota = _unset,
    bool? inFlight,
    Object? lastError = _unset,
    Object? lastErrorDetail = _unset,
    bool clearError = false,
  }) {
    final errorChanged = !identical(lastError, _unset);
    final String? nextError = clearError ? null : (errorChanged ? lastError as String? : this.lastError);
    final String? nextDetail = clearError
        ? null
        : !identical(lastErrorDetail, _unset)
            ? lastErrorDetail as String?
            : errorChanged
                ? null
                : this.lastErrorDetail;
    return SyncStatus(
      lastSyncAt: identical(lastSyncAt, _unset) ? this.lastSyncAt : lastSyncAt as DateTime?,
      pendingOps: pendingOps ?? this.pendingOps,
      bytesStored: identical(bytesStored, _unset) ? this.bytesStored : bytesStored as int?,
      bytesQuota: identical(bytesQuota, _unset) ? this.bytesQuota : bytesQuota as int?,
      inFlight: inFlight ?? this.inFlight,
      lastError: nextError,
      lastErrorDetail: nextDetail,
    );
  }

  static const _unset = Object();

  @override
  String toString() =>
      'SyncStatus(lastSyncAt=$lastSyncAt, pending=$pendingOps, bytes=$bytesStored/$bytesQuota, inFlight=$inFlight, err=$lastError'
      '${lastErrorDetail == null ? '' : ' ($lastErrorDetail)'})';
}

/// The seam between the cloud UI/state (this module) and the sync engine
/// (`lib/sync/**`). The engine implements it; the UI only ever calls
/// [syncNow] and renders [status]. Which runner is live is decided by
/// `syncRunnerProvider` (`cloud/cloud_sync.dart`): the HTTP runner while
/// `cloudStateProvider.canSync`, [NoopSyncRunner] otherwise. "Sync now" is
/// a hint, not the schedule.
abstract class SyncRunner {
  /// Run one full push → apply → pull round now. Resolves when the round is
  /// over (successfully or not — failures land in [SyncStatus.lastError],
  /// they are not thrown). Concurrent calls coalesce into the running round.
  Future<void> syncNow();

  /// Broadcast of status snapshots; should replay the latest value to new
  /// listeners (a `BehaviorSubject`-style stream, or `Stream.value` for a
  /// static runner).
  Stream<SyncStatus> get status;
}

/// Runner used while cloud sync is off: never syncs, reports nothing.
class NoopSyncRunner implements SyncRunner {
  const NoopSyncRunner();

  @override
  Future<void> syncNow() async {}

  @override
  Stream<SyncStatus> get status => Stream.value(SyncStatus.empty);
}
