import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/sync_runner.dart';
import 'hlc.dart';
import 'sync_tabs_stub.dart' if (dart.library.js_interop) 'sync_tabs_web.dart' as platform;

/// One sync runner per collection across browser tabs (web).
///
/// Every tab of the install shares one database and one device id. Without
/// coordination each tab ran its own runner: duplicate pushes/pulls, two
/// tabs advancing the same cursor, both reacting to the same halt. Here the
/// tab holding the Web Lock `plantly-sync-<collection id>` runs the real
/// runner for that collection ("leader"); the others run a
/// [FollowerSyncRunner] that forwards "something changed" / "sync now" to
/// the leader over a BroadcastChannel and shows the leader's status. When
/// the leader closes (or switches collection) the lock passes to the next
/// tab waiting for it. Tabs on DIFFERENT collections each lead their own.
///
/// Off the web there is one writer: [SyncTabs.single] grants every lease at
/// once and carries no messages, so the runner is exactly what it was.
abstract class SyncTabs {
  /// Ask for the sync lock of [collectionId]. Release with [SyncLease.release].
  SyncLease acquire(String collectionId);

  /// Messages from OTHER tabs.
  Stream<SyncTabMessage> get messages;

  /// Send to the other tabs (never echoed back to this one).
  void post(SyncTabMessage message);

  static const SyncTabs single = _SingleTab();
}

class SyncLease {
  SyncLease({required this.granted, required void Function() onRelease, bool grantedNow = false})
      : _onRelease = onRelease,
        _grantedNow = grantedNow;

  /// Completes when this tab holds the lock (never, if released first).
  final Future<void> granted;
  final void Function() _onRelease;
  final bool _grantedNow;
  bool _released = false;

  /// Already held at creation (single-writer platforms).
  bool get grantedNow => _grantedNow;

  void release() {
    if (_released) return;
    _released = true;
    _onRelease();
  }
}

enum SyncTabMessageKind {
  /// A follower recorded local ops for the collection: push soon.
  changed,

  /// A follower's "Sync now".
  syncNow,

  /// The leader's latest [SyncStatus].
  status,

  /// A follower just started: the leader re-sends its status.
  hello,

  /// The link changed in another tab (re-home, first link, account
  /// switch): reload — this tab's providers still point at the old one.
  reload,
}

class SyncTabMessage {
  const SyncTabMessage(this.kind, this.collectionId, {this.status, this.hlc});
  final SyncTabMessageKind kind;
  final String collectionId;
  final SyncStatus? status;

  /// The sender's latest HLC ([HlcClock.latest]); receivers merge it so a
  /// later edit in any tab sorts after what the other tabs already wrote.
  final String? hlc;

  Map<String, Object?> toJson() => {
        'k': kind.name,
        'c': collectionId,
        if (status != null) 's': encodeSyncStatus(status!),
        if (hlc != null) 'h': hlc,
      };

  static SyncTabMessage? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final kind = SyncTabMessageKind.values.where((k) => k.name == raw['k']).firstOrNull;
    final col = raw['c'];
    if (kind == null || col is! String) return null;
    final s = raw['s'];
    final h = raw['h'];
    return SyncTabMessage(kind, col, status: s is Map ? decodeSyncStatus(s) : null, hlc: h is String ? h : null);
  }
}

Map<String, Object?> encodeSyncStatus(SyncStatus s) => {
      'at': s.lastSyncAt?.toUtc().toIso8601String(),
      'p': s.pendingOps,
      'b': s.bytesStored,
      'q': s.bytesQuota,
      'f': s.inFlight,
      'e': s.lastError,
      'd': s.lastErrorDetail,
      'r': s.rejectedOps,
      'rr': s.rejectedReason,
    };

SyncStatus decodeSyncStatus(Map<dynamic, dynamic> m) {
  int? asInt(Object? v) => v is num ? v.toInt() : null;
  return SyncStatus(
    lastSyncAt: m['at'] is String ? DateTime.tryParse(m['at'] as String) : null,
    pendingOps: asInt(m['p']) ?? 0,
    bytesStored: asInt(m['b']),
    bytesQuota: asInt(m['q']),
    inFlight: m['f'] == true,
    lastError: m['e'] as String?,
    lastErrorDetail: m['d'] as String?,
    rejectedOps: asInt(m['r']) ?? 0,
    rejectedReason: m['rr'] as String?,
  );
}

class _SingleTab implements SyncTabs {
  const _SingleTab();

  @override
  SyncLease acquire(String collectionId) => SyncLease(granted: Future.value(), onRelease: () {}, grantedNow: true);

  @override
  Stream<SyncTabMessage> get messages => const Stream.empty();

  @override
  void post(SyncTabMessage message) {}
}

/// The platform's coordinator: Web Locks + BroadcastChannel in a browser,
/// [SyncTabs.single] elsewhere. Tests override it.
final syncTabsProvider = Provider<SyncTabs>((ref) {
  final tabs = platform.createSyncTabs();
  ref.onDispose(() => platform.disposeSyncTabs(tabs));
  return tabs;
});

/// Whether THIS tab runs the sync runner for a collection. Holding the
/// provider holds the lock; disposing it (collection switch, sign-out,
/// runner rebuilt for another id) releases it to the next tab.
final syncLeaderProvider = StateNotifierProvider.autoDispose.family<SyncLeadership, bool, String>((ref, collectionId) {
  return SyncLeadership(ref.watch(syncTabsProvider).acquire(collectionId), onGranted: platform.onLeadershipGranted);
});

class SyncLeadership extends StateNotifier<bool> {
  SyncLeadership(this._lease, {Future<void> Function()? onGranted}) : super(_lease.grantedNow) {
    if (_lease.grantedNow) return;
    unawaited(_lease.granted.then((_) async {
      // Another tab synced until now: its cursor / prefs writes are not in
      // this tab's in-memory prefs cache yet.
      await onGranted?.call();
      if (mounted) state = true;
    }));
  }

  final SyncLease _lease;

  @override
  void dispose() {
    _lease.release();
    super.dispose();
  }
}

/// Runner of a tab that does not hold the collection's sync lock: forwards
/// this tab's local writes and "Sync now" to the leading tab and mirrors
/// its status (same database, so pending counts include ours).
class FollowerSyncRunner implements SyncRunner {
  FollowerSyncRunner({
    required this.tabs,
    required this.collectionId,
    required Stream<void> localChanges,
    this.clock,
  }) {
    _changes = localChanges.listen(
        (_) => tabs.post(SyncTabMessage(SyncTabMessageKind.changed, collectionId, hlc: clock?.latest?.encode())));
    _messages = tabs.messages.listen((m) {
      if (m.kind != SyncTabMessageKind.status || m.collectionId != collectionId || m.status == null) return;
      _last = m.status!;
      _status.add(_last);
    });
    tabs.post(SyncTabMessage(SyncTabMessageKind.hello, collectionId));
  }

  final SyncTabs tabs;
  final String collectionId;
  final HlcClock? clock;
  late final StreamSubscription<void> _changes;
  late final StreamSubscription<SyncTabMessage> _messages;
  final _status = StreamController<SyncStatus>.broadcast();
  SyncStatus _last = SyncStatus.empty;

  SyncStatus get current => _last;

  @override
  Future<void> syncNow() async => tabs.post(SyncTabMessage(SyncTabMessageKind.syncNow, collectionId));

  @override
  Stream<SyncStatus> get status async* {
    yield _last;
    yield* _status.stream;
  }

  Future<void> dispose() async {
    await _changes.cancel();
    await _messages.cancel();
    await _status.close();
  }
}

/// Merges the HLC another tab sent into [clock] (malformed stamps ignored).
void mergeTabHlc(HlcClock clock, SyncTabMessage m) {
  final raw = m.hlc;
  if (raw == null) return;
  try {
    clock.merge(Hlc.parse(raw));
  } catch (_) {
    // Not an HLC: ignore.
  }
}

/// Keeps this tab's HLC clock merged with every other tab's latest stamp
/// (all tabs share one device id and write the same database). Lives as
/// long as the app context.
final tabClockBridgeProvider = Provider.family<void, HlcClock>((ref, clock) {
  final sub = ref.watch(syncTabsProvider).messages.listen((m) => mergeTabHlc(clock, m));
  ref.onDispose(sub.cancel);
});

/// Tell the other tabs to reload (the link moved under them).
void broadcastTabReload(SyncTabs tabs) => tabs.post(const SyncTabMessage(SyncTabMessageKind.reload, ''));
