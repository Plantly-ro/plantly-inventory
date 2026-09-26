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

  /// Human-readable summary of the last failure, cleared on success.
  /// Well-known values the UI maps to copy: `cloud_required` (402),
  /// `unauthorized` (401 after refresh failed), anything else is shown raw.
  final String? lastError;

  static const SyncStatus empty = SyncStatus();

  SyncStatus copyWith({
    Object? lastSyncAt = _unset,
    int? pendingOps,
    Object? bytesStored = _unset,
    Object? bytesQuota = _unset,
    bool? inFlight,
    Object? lastError = _unset,
  }) {
    return SyncStatus(
      lastSyncAt: identical(lastSyncAt, _unset) ? this.lastSyncAt : lastSyncAt as DateTime?,
      pendingOps: pendingOps ?? this.pendingOps,
      bytesStored: identical(bytesStored, _unset) ? this.bytesStored : bytesStored as int?,
      bytesQuota: identical(bytesQuota, _unset) ? this.bytesQuota : bytesQuota as int?,
      inFlight: inFlight ?? this.inFlight,
      lastError: identical(lastError, _unset) ? this.lastError : lastError as String?,
    );
  }

  static const _unset = Object();

  @override
  String toString() =>
      'SyncStatus(lastSyncAt=$lastSyncAt, pending=$pendingOps, bytes=$bytesStored/$bytesQuota, inFlight=$inFlight, err=$lastError)';
}

/// The seam between the cloud UI/state (this module) and the sync engine
/// (`lib/sync/**`). The engine implements it and overrides
/// [syncRunnerProvider]; the UI only ever calls [syncNow] and renders
/// [status]. The engine decides on its own when to run (it watches
/// `cloudStateProvider` — sync only when `phase == ready` and
/// `collectionId != null`); "Sync now" is a hint, not the schedule.
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

/// Default until the engine is wired in: never syncs, reports nothing.
class NoopSyncRunner implements SyncRunner {
  const NoopSyncRunner();

  @override
  Future<void> syncNow() async {}

  @override
  Stream<SyncStatus> get status => Stream.value(SyncStatus.empty);
}

/// Overridden by the sync engine (`ProviderScope(overrides: [
/// syncRunnerProvider.overrideWith(...)])` or a provider-level override).
final syncRunnerProvider = Provider<SyncRunner>((ref) => const NoopSyncRunner());

/// Latest [SyncStatus] for widgets; `SyncStatus.empty` before the first
/// emission so callers never need to special-case loading.
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  return ref.watch(syncRunnerProvider).status;
});
