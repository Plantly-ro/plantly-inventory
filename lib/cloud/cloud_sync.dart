import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/plantly_features.dart';
import '../sync/sync_providers.dart';
import 'cloud_state.dart';
import 'collection_link.dart';
import 'entitlement.dart';
import 'sign_in_events.dart';
import 'sync_runner.dart';

/// The runner the app talks to. While the feature flag is on this is
/// always `httpSyncRunnerProvider`, which itself yields [NoopSyncRunner]
/// unless `activeCollectionIdProvider` names a collection (signed in +
/// linked + the caller's plan for own collections / the owner's plan for
/// shared ones, §3) and rebuilds — disposing the previous runner —
/// whenever the collection id changes. Sign-out / unlink / lost entitlement therefore stop the loop,
/// and a (re-)link starts a fresh runner bound to the new collection.
///
/// Watched continuously by [cloudSyncCoordinatorProvider] so those
/// transitions are applied eagerly rather than on the next UI read.
final syncRunnerProvider = Provider<SyncRunner>((ref) {
  if (!ref.watch(cloudEnabledProvider)) return const NoopSyncRunner();
  return ref.watch(httpSyncRunnerProvider);
});

/// Latest [SyncStatus] for widgets; `SyncStatus.empty` before the first
/// emission so callers never need to special-case loading.
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  return ref.watch(syncRunnerProvider).status;
});

/// Glue between the account layer and the engine that no widget owns:
///
/// * keeps [syncRunnerProvider] alive for the app's lifetime (see there);
/// * on a sign-in ([SignInEvents]): once the entitlement lookup settled,
///   links the device to the account's default collection when nothing is
///   linked yet (entitled or not — see [_handleSignIn]; never when the
///   stored link belongs to another account — that is the user's call in
///   Me → Cloud), or asks for a sync when it already is and is entitled;
/// * on every link change asks the runner for a sync (debounced by
///   [debounce]; the freshly built runner's first cycle usually wins the
///   race, in which case the request just joins it).
class CloudSyncCoordinator {
  CloudSyncCoordinator(this._ref, {this.debounce = const Duration(milliseconds: 500)});

  final Ref _ref;
  final Duration debounce;

  Timer? _timer;
  StreamSubscription<Object?>? _signIns;
  Future<void>? _signInInFlight;

  /// Number of sign-in events handled so far (tests).
  int signInsHandled = 0;

  void start() {
    _ref.listen<SyncRunner>(syncRunnerProvider, (_, _) {});
    _signIns = _ref.read(signInEventsProvider).stream.listen((_) => _onSignIn());
    _ref.listen<String?>(collectionLinkProvider.select((s) => s.link?.id), (prev, next) {
      if (next != null && next != prev) requestSync();
    });
  }

  /// Resolves when the most recent sign-in has been fully handled.
  Future<void> get idle => _signInInFlight ?? Future.value();

  void _onSignIn() {
    final run = _handleSignIn().whenComplete(() {
      signInsHandled++;
    });
    _signInInFlight = run;
  }

  Future<void> _handleSignIn() async {
    // The entitlement notifier listens to the same event and invalidates
    // itself; yield once so we await the refreshed value, not the cache.
    await Future<void>.delayed(Duration.zero);
    try {
      await _ref.read(cloudEntitlementProvider.future);
    } catch (_) {
      return; // offline / server error — the Me section shows it
    }
    final state = _ref.read(cloudStateProvider);
    if (state.phase == CloudPhase.signedOut || state.phase == CloudPhase.off || state.heldByOther != null) return;
    if (state.linked) {
      if (state.phase == CloudPhase.ready) requestSync();
      return;
    }
    // Linking needs no plan of the caller's own (§3: editors sync shared
    // collections on the OWNER's plan, and the link is what tells the
    // device which collection is "home"). `activeCollectionIdProvider`
    // keeps the runner a no-op for their own collection until they subscribe.
    try {
      // A new sign-in is the documented way out of "unlinked by user"
      // (CollectionLinkState); `link()` clears that flag itself.
      await _ref.read(collectionLinkProvider.notifier).ensureLinked();
      // The link listener in [start] (or the new runner's first cycle)
      // takes it from here.
    } catch (_) {
      // Surfaced by the Me section's own link attempt / retry row.
    }
  }

  /// Ask the current runner for a cycle, coalescing bursts.
  void requestSync() {
    _timer?.cancel();
    _timer = Timer(debounce, () {
      _timer = null;
      unawaited(_ref.read(syncRunnerProvider).syncNow());
    });
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _signIns?.cancel();
    _signIns = null;
  }
}

/// Read once from the app root (`PlantlyApp.build`) so the coordinator —
/// and with it the runner chain — exists for the whole session. Inert
/// while `PlantlyFeatures.cloudEnabled` is off.
final cloudSyncCoordinatorProvider = Provider<CloudSyncCoordinator>((ref) {
  final coordinator = CloudSyncCoordinator(ref, debounce: ref.watch(syncRunnerConfigProvider).linkDebounce);
  if (ref.watch(cloudEnabledProvider)) coordinator.start();
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
