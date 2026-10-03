import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/plantly_features.dart';
import '../marketplace/plantly_auth.dart';
import 'entitlement.dart';
import 'play_billing.dart';
import 'sign_in_events.dart';

/// Platform × flags: Play Billing is a thing in this build (PLAY-BILLING-
/// CONTRACT §0 "Feature flags"). Android only, both `PLANTLY_CLOUD_ENABLED`
/// and `PLANTLY_PLAY_BILLING_ENABLED` true. Overridable in tests.
final playBillingAvailableProvider = Provider<bool>((ref) {
  if (!ref.watch(cloudEnabledProvider) || !ref.watch(playBillingEnabledProvider)) return false;
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android;
});

/// The plugin seam; tests override with a fake.
final playStoreProvider = Provider<PlayStore>((_) => InAppPurchaseStore());

/// One [PlayBillingService] for the app's lifetime. Built even when
/// [playBillingAvailableProvider] is false (then `enabled: false`, every
/// call a no-op) so widgets can read it unconditionally.
final playBillingServiceProvider = Provider<PlayBillingService>((ref) {
  final auth = ref.watch(plantlyAuthProvider.notifier);
  final service = PlayBillingService(
    store: ref.watch(playStoreProvider),
    api: ref.watch(plantlyApiProvider),
    session: auth.current,
    refreshEntitlement: () async {
      final notifier = ref.read(cloudEntitlementProvider.notifier);
      await notifier.refresh();
      return ref.read(cloudEntitlementProvider).valueOrNull;
    },
    enabled: ref.watch(playBillingAvailableProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Live [PlayBillingState] for widgets.
final playBillingStateProvider = Provider<PlayBillingState>((ref) {
  final service = ref.watch(playBillingServiceProvider);
  void onChange() => ref.state = service.state;
  service.listenable.addListener(onChange);
  ref.onDispose(() => service.listenable.removeListener(onChange));
  return service.state;
});

/// App-lifetime glue (mounted from `main.dart` like the sync coordinator):
/// restore on start when signed in, on every sign-in, and retry pending
/// verifications on resume. Inert unless [playBillingAvailableProvider].
class PlayBillingCoordinator with WidgetsBindingObserver {
  PlayBillingCoordinator(this._ref);
  final Ref _ref;

  StreamSubscription<Object?>? _signIns;
  bool _observing = false;

  void start() {
    if (!_ref.read(playBillingAvailableProvider)) return;
    final service = _ref.read(playBillingServiceProvider);
    _signIns = _ref.read(signInEventsProvider).stream.listen((_) => unawaited(service.restore(force: true)));
    final binding = _bindingOrNull();
    if (binding != null) {
      binding.addObserver(this);
      _observing = true;
    }
    // Signed in at launch? `restore()` checks the session itself.
    unawaited(service.restore());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final service = _ref.read(playBillingServiceProvider);
    unawaited(service.retryPending());
    unawaited(service.restore()); // throttled
  }

  void dispose() {
    _signIns?.cancel();
    if (_observing) _bindingOrNull()?.removeObserver(this);
  }

  static WidgetsBinding? _bindingOrNull() {
    try {
      return WidgetsBinding.instance;
    } catch (_) {
      return null;
    }
  }
}

final playBillingCoordinatorProvider = Provider<PlayBillingCoordinator>((ref) {
  final c = PlayBillingCoordinator(ref)..start();
  ref.onDispose(c.dispose);
  return c;
});
