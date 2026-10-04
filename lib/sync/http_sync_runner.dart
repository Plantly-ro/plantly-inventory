import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';

import '../cloud/sync_runner.dart';
import '../data/database/app_database.dart';
import 'entity_codecs.dart';
import 'hlc.dart';
import 'op_log.dart';
import 'photo_sync.dart';
import 'sync_applier.dart';
import 'sync_engine.dart';
import 'sync_rejections.dart';
import 'sync_transport.dart';

/// Refreshes the session after a 401; returns true when a usable token
/// exists afterwards.
typedef SyncAuthRefresher = Future<bool> Function();

/// The sync loop of CLOUD-SYNC-CONTRACT §2.4 for one collection.
///
/// Cycle: synthesize `*` ops for rows without any op (initial upload) →
/// push pending in batches (applying each reply's `fresh_ops`) → pull until
/// `has_more=false` → upload local photo blobs → refresh usage (≤ every
/// [usageInterval]).
///
/// Triggers: [syncNow], [start], app resume, [debounce] after a local
/// write, every [periodic] while resumed. Single-flight; triggers during a
/// cycle queue exactly one follow-up cycle.
///
/// Oversized pushes (413) are handled inside [SyncEngine]: the batch is
/// halved and retried; a lone op the server still refuses is parked
/// (`pushed_at` set) and surfaced as `lastError='op_too_large'` with
/// `lastErrorDetail='<entity>/<id>'`. Row sync continues.
///
/// Per-op rejections in a push reply go through [SyncRejectionStore]
/// (`SyncRejectionPolicy` decides permanent vs transient): permanent ones
/// are parked so the pending count drops, transient ones stay pending and
/// are retried on later cycles until the grace window runs out. Any listed
/// rejection surfaces as `lastError='rejected'` with
/// `lastErrorDetail='<n> changes could not be synced (<reason>)'` plus
/// `SyncStatus.rejectedOps` / `rejectedReason` until the user retries or
/// dismisses them (Me → Cloud → Details).
///
/// Failure policy: retryable errors (429/5xx/network) back off exponentially
/// from [minBackoff] to [maxBackoff] (`Retry-After` honoured); 402 halts with
/// `cloud_required`; 401 refreshes once via [refreshAuth] then halts with
/// `unauthorized`; 403/404 halt with `collection_unavailable` (detail = the
/// server code, e.g. `not_a_member`). A halted
/// runner ignores debounce/periodic triggers until [syncNow] or app resume.
class HttpSyncRunner with WidgetsBindingObserver implements SyncRunner {
  HttpSyncRunner({
    required this.db,
    required this.opLog,
    HlcClock? clock,
    required this.transport,
    required this.cursor,
    required this.deviceId,
    required this.collectionId,
    this.userId,
    Stream<void>? localChanges,
    this.photos,
    this.usage,
    this.refreshAuth,
    SyncRejectionStore? rejections,
    this.debounce = const Duration(seconds: 3),
    this.periodic = const Duration(minutes: 15),
    this.minBackoff = const Duration(seconds: 1),
    this.maxBackoff = const Duration(minutes: 15),
    this.usageInterval = const Duration(minutes: 10),
    this.observeLifecycle = true,
    this.batchSize = 500,
    this.entitlementIsOwners = false,
    this.readOnly = false,
    DateTime Function()? now,
  })  : assert(clock == null || identical(clock, opLog.clock),
            'one HlcClock per device: pass the OpLogWriter\'s clock (or omit it)'),
        clock = clock ?? opLog.clock,
        _localChanges = localChanges ?? opLog.changes,
        _now = now ?? (() => DateTime.now().toUtc()),
        _rejections = rejections ?? SyncRejectionStore(db: db, tenantId: collectionId),
        _engine = SyncEngine(
          db: db,
          transport: transport,
          cursor: cursor,
          tenantId: collectionId,
          deviceId: deviceId,
          userId: userId,
          batchSize: batchSize,
        ),
        _applier = SyncApplier(db: db, opLog: opLog, clock: opLog.clock) {
    _backoff = minBackoff;
  }

  final AppDatabase db;

  /// Tenant-scoped writer for the collection (used for LWW lookups and to
  /// record remote/synthesized ops).
  final OpLogWriter opLog;

  /// The device's single HLC clock — always [OpLogWriter.clock], so ops
  /// stamped by repositories, ops synthesized here and remote merges all
  /// move the same counter.
  final HlcClock clock;
  final SyncTransport transport;
  final SyncCursor cursor;
  final String deviceId;
  final String collectionId;

  /// Account the runner pushes for (`SyncEngine.userId`): pending ops of
  /// another account on this device are neither counted nor uploaded.
  final String? userId;
  final PhotoUploader? photos;
  final CollectionUsageSource? usage;
  final SyncAuthRefresher? refreshAuth;
  final Duration debounce;
  final Duration periodic;
  final Duration minBackoff;
  final Duration maxBackoff;
  final Duration usageInterval;
  final bool observeLifecycle;
  final int batchSize;

  /// The collection is shared with this account (§3 / MULTI-USER-V2 §8): a
  /// 402 is reported as `cloud_required` with detail
  /// [kOwnerPlanLapsedDetail] (`cloud_required_owner`: the owner lapsed) or
  /// [kMemberPlanLapsedDetail] (plain `cloud_required`: the caller's own
  /// plan lapsed) rather than the personal-collection paywall.
  final bool entitlementIsOwners;

  /// Viewer role (MULTI-USER-V2 §0): never push — the server would answer
  /// `403 read_only` and halt the runner. Pull still runs, pending local
  /// ops (if any slipped in) stay queued for a later role change.
  final bool readOnly;

  final Stream<void> _localChanges;
  final DateTime Function() _now;
  final SyncEngine _engine;
  final SyncApplier _applier;
  final SyncRejectionStore _rejections;

  /// The rejection ledger (Me → Cloud → Details reads and acts on it).
  SyncRejectionStore get rejections => _rejections;

  SyncStatus _status = SyncStatus();
  final StreamController<SyncStatus> _statusCtrl = StreamController<SyncStatus>.broadcast();

  Future<void>? _inflight;
  bool _dirty = false;
  bool _halted = false;
  bool _started = false;
  bool _disposed = false;
  bool _resumed = true;
  late Duration _backoff;
  DateTime? _usageFetchedAt;

  StreamSubscription<void>? _changesSub;
  Timer? _debounceTimer;
  Timer? _periodicTimer;
  Timer? _retryTimer;

  /// Latest status, synchronously.
  SyncStatus get current => _status;

  @override
  Stream<SyncStatus> get status => Stream<SyncStatus>.multi((c) {
        c.add(_status);
        final sub = _statusCtrl.stream.listen(c.add, onDone: c.close);
        c.onCancel = sub.cancel;
      });

  /// Install triggers and run the first cycle.
  void start() {
    if (_started || _disposed) return;
    _started = true;
    if (observeLifecycle) WidgetsBinding.instance.addObserver(this);
    _changesSub = _localChanges.listen((_) {
      unawaited(_refreshPending());
      _debounceTimer?.cancel();
      _debounceTimer = Timer(debounce, () => _trigger());
    });
    _startPeriodic();
    unawaited(_refreshPending());
    unawaited(_trigger(force: true));
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (_started && observeLifecycle) WidgetsBinding.instance.removeObserver(this);
    await _changesSub?.cancel();
    _debounceTimer?.cancel();
    _periodicTimer?.cancel();
    _retryTimer?.cancel();
    await _statusCtrl.close();
  }

  @override
  Future<void> syncNow() {
    _halted = false;
    return _trigger(force: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resumed = true;
      _startPeriodic();
      unawaited(_trigger(force: true));
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _resumed = false;
      _periodicTimer?.cancel();
      _periodicTimer = null;
    }
  }

  // --- scheduling -----------------------------------------------------------

  void _startPeriodic() {
    _periodicTimer?.cancel();
    if (periodic == Duration.zero) return;
    _periodicTimer = Timer.periodic(periodic, (_) {
      if (_resumed) unawaited(_trigger());
    });
  }

  /// Run a cycle unless halted (or [force]). Joins the in-flight cycle and
  /// marks it dirty so one more cycle follows.
  Future<void> _trigger({bool force = false}) {
    if (_disposed) return Future.value();
    if (_halted && !force) return Future.value();
    _retryTimer?.cancel();
    _retryTimer = null;
    final running = _inflight;
    if (running != null) {
      _dirty = true;
      return running;
    }
    final run = _cycle().whenComplete(() {
      _inflight = null;
      if (_dirty && !_disposed && !_halted) {
        _dirty = false;
        unawaited(_trigger());
      } else {
        _dirty = false;
      }
    });
    _inflight = run;
    return run;
  }

  void _scheduleRetry(Duration? hint) {
    if (_disposed) return;
    final delay = hint ?? _backoff;
    _backoff = Duration(
      milliseconds: math.min(_backoff.inMilliseconds * 2, maxBackoff.inMilliseconds),
    );
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => _trigger());
  }

  void _halt(String code, {String? detail}) {
    _halted = true;
    _dirty = false;
    _emit(_status.copyWith(inFlight: false, lastError: code, lastErrorDetail: detail));
  }

  // --- the cycle ------------------------------------------------------------

  Future<void> _cycle() async {
    _emit(_status.copyWith(inFlight: true));
    var authRetried = false;
    while (true) {
      try {
        await _synthesizeInitialOps();
        final pushed = readOnly
            ? const SyncPushResult(
                sent: 0, accepted: 0, rejected: [], batches: 0, cursor: '', hasMore: false, freshOps: 0)
            : await _engine.pushPending(
                onFresh: (ops) async {
                  await _applier.applyBatch(ops);
                },
              );
        if (pushed.batches == 0 || pushed.hasMore) {
          await _engine.pullAll(onOps: (ops) async {
            await _applier.applyBatch(ops);
          });
        }
        String? error;
        String? detail;
        if (pushed.tooLarge.isNotEmpty) {
          final first = pushed.tooLarge.first;
          error = 'op_too_large';
          detail = '${first.entity}/${first.entityId}'
              '${pushed.tooLarge.length > 1 ? ' (+${pushed.tooLarge.length - 1} more)' : ''}';
        }
        final uploader = photos;
        if (uploader != null) {
          final summary = await uploader.uploadPending();
          if (summary.quotaExceeded) {
            error = 'quota_exceeded';
            detail = null;
          }
        }
        // Sticky until retried/dismissed: a rejection that vanished on the
        // next clean cycle would leave nowhere to find "Details".
        final rejected = await _rejections.absorb(pushed);
        if (!rejected.isEmpty) {
          error = 'rejected';
          detail = rejected.detail;
        }
        await _refreshUsageIfStale();
        _backoff = minBackoff;
        _emit(_status.copyWith(
          inFlight: false,
          lastSyncAt: _now(),
          pendingOps: await _engine.pendingCount(),
          lastError: error,
          lastErrorDetail: detail,
          clearError: error == null,
          rejectedOps: rejected.total,
          rejectedReason: rejected.topReason,
        ));
        return;
      } on SyncAuthError {
        final refresher = refreshAuth;
        if (!authRetried && refresher != null && await _safeRefresh(refresher)) {
          authRetried = true;
          continue;
        }
        _halt('unauthorized');
        return;
      } on SyncEntitlementError catch (e) {
        // §8: two codes on a shared collection — `cloud_required_owner`
        // (the owner lapsed) vs plain `cloud_required` (the caller's own
        // plan). On the caller's own collection the plain code is the
        // paywall as before (no detail).
        final String? detail;
        if (e.message == kCloudRequiredOwnerCode) {
          detail = kOwnerPlanLapsedDetail;
        } else if (entitlementIsOwners) {
          detail = kMemberPlanLapsedDetail;
        } else {
          detail = null;
        }
        _halt('cloud_required', detail: detail);
        return;
      } on SyncCollectionError catch (e) {
        // The server code (`not_a_member`, `collection_not_found`,
        // `read_only`, `device_revoked`, `too_many_devices`) rides along so
        // the integrator can react (removed → back home + notice; role
        // downgrade → list refresh → read-only rebuild; device cap → point
        // at Me → Cloud → Devices). None of these heal by retrying.
        _halt('collection_unavailable', detail: e.message);
        return;
      } on SyncRetryableError catch (e) {
        _scheduleRetry(e.retryAfter);
        // The server code (e.g. `device_lookup_failed`) rides along as the
        // detail so the Me section can say *why* it is retrying.
        _emit(_status.copyWith(
          inFlight: false,
          pendingOps: await _pendingSafe(),
          lastError: e.status == null ? 'offline' : 'retrying',
          lastErrorDetail: e.status == null ? null : e.message,
        ));
        return;
      } on SyncQuotaError {
        // Only photo uploads raise this and the uploader swallows it; a
        // stray one is not fatal for row sync.
        _emit(_status.copyWith(inFlight: false, lastSyncAt: _now(), lastError: 'quota_exceeded'));
        return;
      } catch (e) {
        _scheduleRetry(null);
        _emit(_status.copyWith(inFlight: false, lastError: 'error'));
        return;
      }
    }
  }

  Future<bool> _safeRefresh(SyncAuthRefresher refresher) async {
    try {
      return await refresher();
    } catch (_) {
      return false;
    }
  }

  /// Rows that exist locally without any op (pre-cloud data, restored
  /// backups) get one `*` op each carrying the row's own HLC, so the first
  /// push uploads the whole collection. Idempotent and cheap once caught up.
  Future<void> _synthesizeInitialOps() async {
    for (final codec in opLog.codecs.all) {
      final live = codec.isOrSet ? 'removed_hlc IS NULL' : 'deleted_at IS NULL';
      final rows = await db.customSelect(
        'SELECT * FROM ${codec.table.actualTableName} t '
        'WHERE t.tenant_id = ? AND $live AND NOT EXISTS ('
        '  SELECT 1 FROM sync_ops s WHERE s.tenant_id = ? AND s.entity = ? '
        '  AND s.entity_id = t.${codec.idColumn})',
        variables: [
          Variable<String>(collectionId),
          Variable<String>(collectionId),
          Variable<String>(codec.entity),
        ],
        readsFrom: {codec.table, db.syncOps},
      ).get();
      if (rows.isEmpty) continue;
      await db.transaction(() async {
        for (final r in rows) {
          final data = r.data;
          final id = data[codec.idColumn] as String;
          final hlc = data[codec.hlcColumn];
          final device = data['device_id'];
          await opLog.recordSynthesized(
            entity: codec.entity,
            entityId: id,
            wireRow: codec.encodeRow(data),
            hlc: hlc is String && hlc.isNotEmpty ? hlc : clock.now().encode(),
            deviceId: device is String && device.isNotEmpty ? device : deviceId,
          );
        }
      });
    }
  }

  Future<void> _refreshUsageIfStale() async {
    final source = usage;
    if (source == null) return;
    final last = _usageFetchedAt;
    if (last != null && _now().difference(last) < usageInterval) return;
    try {
      final u = await source.usage();
      _usageFetchedAt = _now();
      _emit(_status.copyWith(bytesStored: u.bytesStored, bytesQuota: u.bytesQuota));
    } on SyncError {
      // Usage is decorative; the sync outcome already carries the verdict.
    }
  }

  Future<void> _refreshPending() async {
    if (_disposed) return;
    final n = await _pendingSafe();
    if (n != _status.pendingOps) _emit(_status.copyWith(pendingOps: n));
  }

  /// Ops *this account* still has to push (see [userId]).
  Future<int> _pendingSafe() async {
    try {
      return await _engine.pendingCount();
    } catch (_) {
      return _status.pendingOps;
    }
  }

  void _emit(SyncStatus next) {
    _status = next;
    if (!_statusCtrl.isClosed) _statusCtrl.add(next);
  }
}

/// Convenience for the integrator: synthesizes the initial upload ops for
/// every codec entity without running a network cycle (e.g. right after the
/// tenant migration, before the runner exists).
Future<void> synthesizeInitialOps({
  required AppDatabase db,
  required OpLogWriter opLog,
  required String deviceId,
}) async {
  final runner = HttpSyncRunner(
    db: db,
    opLog: opLog,
    transport: _NullTransport(),
    cursor: _NullCursor(),
    deviceId: deviceId,
    collectionId: opLog.tenantId,
    observeLifecycle: false,
  );
  await runner._synthesizeInitialOps();
  await runner.dispose();
}

class _NullTransport implements SyncTransport {
  @override
  Future<PullResponse> pull(PullRequest request) => throw UnimplementedError();
  @override
  Future<PushResponse> push(PushRequest request) => throw UnimplementedError();
}

class _NullCursor implements SyncCursor {
  @override
  Future<String> get() async => '';
  @override
  Future<void> set(String cursor) async {}
}

/// Exposed for tests / the integrator: the contract entity list in upload
/// order.
List<String> get syncEntityOrder => EntityCodecs.entities;
