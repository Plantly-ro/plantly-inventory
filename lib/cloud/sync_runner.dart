import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The seam between the account/entitlement layer (owner: ACCOUNT track)
/// and the sync machinery (`lib/sync/http_sync_runner.dart`).
///
/// The UI only ever talks to this interface; the concrete runner is bound via
/// [syncRunnerProvider] once the account is signed in, entitled and linked to
/// a server collection. Until then the default no-op runner keeps every
/// caller trivially safe.
abstract class SyncRunner {
  /// Run one full sync cycle now (push → apply fresh → pull). Single-flight:
  /// calling while a cycle is in progress joins the in-flight cycle.
  Future<void> syncNow();

  /// Emits on every state change; the latest value is replayed to new
  /// listeners.
  Stream<SyncStatus> get status;
}

class SyncStatus {
  SyncStatus({
    this.lastSyncAt,
    this.pendingOps = 0,
    this.bytesStored = 0,
    this.bytesQuota = 0,
    this.inFlight = false,
    this.lastError,
    this.lastErrorDetail,
  });

  DateTime? lastSyncAt;
  int pendingOps;
  int bytesStored;
  int bytesQuota;
  bool inFlight;

  /// Stable code for the UI: `cloud_required`, `auth_required`,
  /// `quota_exceeded`, `op_too_large`, `collection_unavailable`, `offline`,
  /// `retrying`, or null when the last cycle succeeded.
  String? lastError;

  /// Optional human/debug detail for [lastError] — for `op_too_large` the
  /// first offending `<entity>/<entity_id>` plus a count.
  String? lastErrorDetail;

  SyncStatus copyWith({
    DateTime? lastSyncAt,
    int? pendingOps,
    int? bytesStored,
    int? bytesQuota,
    bool? inFlight,
    String? lastError,
    String? lastErrorDetail,
    bool clearError = false,
  }) {
    return SyncStatus(
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      pendingOps: pendingOps ?? this.pendingOps,
      bytesStored: bytesStored ?? this.bytesStored,
      bytesQuota: bytesQuota ?? this.bytesQuota,
      inFlight: inFlight ?? this.inFlight,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastErrorDetail: clearError ? null : (lastErrorDetail ?? (lastError == null ? this.lastErrorDetail : null)),
    );
  }

  @override
  String toString() =>
      'SyncStatus(lastSyncAt: $lastSyncAt, pending: $pendingOps, '
      'bytes: $bytesStored/$bytesQuota, inFlight: $inFlight, error: $lastError'
      '${lastErrorDetail == null ? '' : ' ($lastErrorDetail)'})';
}

/// Runner used while cloud sync is off: never syncs, never errors.
class NoopSyncRunner implements SyncRunner {
  const NoopSyncRunner();

  @override
  Future<void> syncNow() async {}

  @override
  Stream<SyncStatus> get status => Stream.value(SyncStatus());
}

/// Bound to the real runner by the account layer once cloud is ready.
final syncRunnerProvider = Provider<SyncRunner>((_) => const NoopSyncRunner());
