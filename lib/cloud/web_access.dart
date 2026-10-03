import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/plantly_features.dart';
import '../data/providers.dart';
import '../marketplace/plantly_api.dart';
import '../marketplace/plantly_auth.dart';
import 'entitlement.dart';

/// Web access gate (WEB-ACCESS-POLICY §0/§1): the browser build is the
/// Inventory Cloud surface, so the app shell renders only for a signed-in
/// plantly.ro account with cloud access: its own `inventory_cloud`
/// entitlement active OR membership in an entitled owner's shared
/// collection ([CloudEntitlement.hasCloudAccess], shared-access amendment).
/// Off web the gate never engages ([WebAccess.open] always).
///
/// Derived — never fetched here — from the existing session / entitlement
/// providers; the only web-specific ingredient is the offline rule, which
/// reads the entitlement notifier's provenance ([EntitlementSource]).
sealed class WebAccess {
  const WebAccess();

  /// Session or entitlement lookup still in flight with nothing cached.
  static const WebAccess checking = WebAccessChecking();

  /// State 1: no plantly.ro session.
  static const WebAccess closedSignedOut = WebAccessSignedOut();

  /// State 2: signed in, not entitled (or the entitlement lapsed).
  static WebAccess closedNotEntitled(String username) => WebAccessNotEntitled(username);

  /// Signed in, server unreachable and no entitled check cached in the last
  /// 24 h: closed, with a retry.
  static WebAccess closedUnreachable(String username) => WebAccessUnreachable(username);

  /// State 3: normal app. [offline] = served from a ≤ 24 h cached check
  /// while the server is unreachable → read-only banner.
  static const WebAccess open = WebAccessOpen();

  bool get isOpen => this is WebAccessOpen;
  bool get isClosed => !isOpen && this is! WebAccessChecking;
}

class WebAccessChecking extends WebAccess {
  const WebAccessChecking();
  @override
  bool operator ==(Object other) => other is WebAccessChecking;
  @override
  int get hashCode => 1;
  @override
  String toString() => 'WebAccess.checking';
}

class WebAccessSignedOut extends WebAccess {
  const WebAccessSignedOut();
  @override
  bool operator ==(Object other) => other is WebAccessSignedOut;
  @override
  int get hashCode => 2;
  @override
  String toString() => 'WebAccess.closedSignedOut';
}

class WebAccessNotEntitled extends WebAccess {
  const WebAccessNotEntitled(this.username);
  final String username;
  @override
  bool operator ==(Object other) => other is WebAccessNotEntitled && other.username == username;
  @override
  int get hashCode => Object.hash(3, username);
  @override
  String toString() => 'WebAccess.closedNotEntitled($username)';
}

class WebAccessUnreachable extends WebAccess {
  const WebAccessUnreachable(this.username);
  final String username;
  @override
  bool operator ==(Object other) => other is WebAccessUnreachable && other.username == username;
  @override
  int get hashCode => Object.hash(4, username);
  @override
  String toString() => 'WebAccess.closedUnreachable($username)';
}

class WebAccessOpen extends WebAccess {
  const WebAccessOpen({this.offline = false});

  /// True when the server is unreachable and the entitlement comes from a
  /// cached check younger than [webAccessOfflineGrace].
  final bool offline;
  @override
  bool operator ==(Object other) => other is WebAccessOpen && other.offline == offline;
  @override
  int get hashCode => Object.hash(5, offline);
  @override
  String toString() => 'WebAccess.open(offline=$offline)';
}

/// How long a cached *entitled* verdict keeps the web app usable while the
/// server cannot be reached (§0 "Offline / API unreachable on web").
const Duration webAccessOfflineGrace = Duration(hours: 24);

/// Clock for the offline rule (overridable in tests).
final webAccessClockProvider = Provider<DateTime Function()>(
  (_) =>
      () => DateTime.now().toUtc(),
);

/// The gate's verdict. Pure derivation; re-evaluated whenever the session,
/// the entitlement or the cloud state change.
final webAccessProvider = Provider<WebAccess>((ref) {
  if (!ref.watch(webPlatformProvider)) return WebAccess.open;
  final auth = ref.watch(plantlyAuthProvider);
  final session = auth.valueOrNull;
  if (session == null) return auth.isLoading ? WebAccess.checking : WebAccess.closedSignedOut;

  final entitlement = ref.watch(cloudEntitlementProvider);
  final notifier = ref.read(cloudEntitlementProvider.notifier);
  final username = session.username;

  // A refresh in flight keeps the previous verdict (no gate flash every
  // 15 min); the first lookup of a session shows "checking". The notifier
  // resets its provenance to `none` the moment the user id changes, so a
  // loading state paired with `none` is a new session's first fetch — the
  // previous user's `open` (or the signed-out state) must not show meanwhile.
  if (entitlement.isLoading && notifier.source == EntitlementSource.none) return WebAccess.checking;

  if (entitlement.hasError && !entitlement.hasValue) {
    final e = entitlement.error;
    // 401/403 never open the gate (§0). 401 also clears the session → state 1
    // on the next tick; 403 = the server refuses this account → state 2.
    if (e is PlantlyApiException && (e.isUnauthorized || e.status == 403)) {
      return WebAccess.closedNotEntitled(username);
    }
    // Network / 5xx / 429 and nothing cached for this user.
    return WebAccess.closedUnreachable(username);
  }

  final e = entitlement.valueOrNull;
  if (e == null) {
    // Signed in but the notifier found no session server-side (401 while
    // refreshing): the auth layer is clearing it — treat as signed out.
    return WebAccess.closedSignedOut;
  }
  if (!e.hasCloudAccess) return WebAccess.closedNotEntitled(username);

  // A 403 is a verdict about this account, not an outage: never open (§0).
  if (notifier.source == EntitlementSource.forbidden) return WebAccess.closedNotEntitled(username);

  if (notifier.source == EntitlementSource.staleCache) {
    final at = notifier.lastVerifiedAt;
    final now = ref.watch(webAccessClockProvider)();
    if (at == null || now.difference(at) > webAccessOfflineGrace) return WebAccess.closedUnreachable(username);
    return const WebAccessOpen(offline: true);
  }
  return WebAccess.open;
});

/// Where to go once the gate opens (§0 "Deep links are preserved through
/// the gate"). Persisted in prefs because the OAuth sign-in reloads the
/// page (same-tab round trip through plantly.ro): the route the visitor
/// asked for and any import / join payload must survive that reload.
/// Entries expire after [ttl].
class WebGateParking {
  WebGateParking(Future<SharedPreferences> prefs, {DateTime Function()? now})
    : _now = now ?? (() => DateTime.now().toUtc()) {
    ready = prefs
        .then((p) {
          _prefs = p;
          // Hydrate only what this session hasn't parked itself meanwhile.
          _route ??= _read(routeKey, routeAtKey);
          _link ??= _read(linkKey, linkAtKey);
        })
        .catchError((_) {});
  }

  static const String routeKey = 'plantly_web_gate_route';
  static const String routeAtKey = 'plantly_web_gate_route_at';
  static const String linkKey = 'plantly_web_gate_link';
  static const String linkAtKey = 'plantly_web_gate_link_at';
  static const Duration ttl = Duration(hours: 1);

  final DateTime Function() _now;
  SharedPreferences? _prefs;

  /// Completes once the prefs copy has been read (tests).
  late final Future<void> ready;

  // In-memory mirror so the router's synchronous redirect never waits on
  // prefs; the prefs copy is what survives the OAuth reload.
  String? _route;
  String? _link;

  String? _read(String key, String atKey) {
    final p = _prefs;
    if (p == null) return null;
    final v = p.getString(key);
    final at = p.getInt(atKey);
    if (v == null || v.isEmpty || at == null) return null;
    if (_now().difference(DateTime.fromMillisecondsSinceEpoch(at, isUtc: true)) > ttl) {
      unawaited(p.remove(key));
      unawaited(p.remove(atKey));
      return null;
    }
    return v;
  }

  void _write(String key, String atKey, String? value) {
    unawaited(
      ready.then((_) {
        final p = _prefs;
        if (p == null) return;
        if (value == null) {
          unawaited(p.remove(key));
          unawaited(p.remove(atKey));
        } else {
          unawaited(p.setString(key, value));
          unawaited(p.setInt(atKey, _now().millisecondsSinceEpoch));
        }
      }),
    );
  }

  /// The route (path + query) the visitor wanted; null when none parked.
  String? get route => _route;

  /// A parked incoming link (import / join URI), see `HandoffListener`.
  String? get link => _link;

  void parkRoute(String location) {
    _route = location;
    _write(routeKey, routeAtKey, location);
  }

  /// Take the parked route (clears it).
  String? takeRoute() {
    final r = _route;
    _route = null;
    _write(routeKey, routeAtKey, null);
    return r;
  }

  /// Forget the parked route (sign-out / account switch: the destination
  /// belonged to the previous session).
  void clearRoute() {
    _route = null;
    _write(routeKey, routeAtKey, null);
  }

  void parkLink(Uri uri) {
    _link = uri.toString();
    _write(linkKey, linkAtKey, _link);
  }

  Uri? takeLink() {
    final l = _link;
    _link = null;
    _write(linkKey, linkAtKey, null);
    return l == null ? null : Uri.tryParse(l);
  }
}

/// One parking lot per app session, bound to the app's prefs.
final webGateParkingProvider = Provider<WebGateParking>((ref) {
  final parking = WebGateParking(ref.read(sharedPreferencesProvider.future), now: ref.watch(webAccessClockProvider));
  // A parked route belongs to the session that parked it: drop it on
  // sign-out and when another account signs in. Signing in from signed-out
  // (null → id, incl. the session restore after the OAuth reload) keeps it —
  // that is the very case the parking lot exists for.
  ref.listen<String?>(plantlyAuthProvider.select((s) => s.valueOrNull?.userId), (prev, next) {
    if (prev != null && prev != next) parking.clearRoute();
  });
  return parking;
});

/// Web-only: re-check the entitlement when the tab regains focus /
/// becomes visible (Flutter web maps both onto `AppLifecycleState.resumed`)
/// if the last check is older than [focusWindow]. The 15-minute periodic
/// re-check and the sign-in trigger already live in
/// [CloudEntitlementNotifier]; this only tightens the resume rule for the
/// gate, where a lapse must show up promptly.
class WebAccessWatcher with WidgetsBindingObserver {
  WebAccessWatcher(this._ref);

  static const Duration focusWindow = Duration(minutes: 1);

  final Ref _ref;
  bool _observing = false;

  /// Resume events handled (tests).
  int resumes = 0;

  void start() {
    try {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    } catch (_) {
      // No binding (pure-Dart tests).
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    resumes++;
    unawaited(_ref.read(cloudEntitlementProvider.notifier).refreshIfStale(olderThan: focusWindow));
  }

  void dispose() {
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    _observing = false;
  }
}

/// Read once from the app root; inert off web.
final webAccessWatcherProvider = Provider<WebAccessWatcher>((ref) {
  final watcher = WebAccessWatcher(ref);
  if (ref.watch(webPlatformProvider)) watcher.start();
  ref.onDispose(watcher.dispose);
  return watcher;
});

/// Bridges [webAccessProvider] to go_router's `refreshListenable` so the
/// redirect re-runs on every verdict change.
final webAccessListenableProvider = Provider<ChangeNotifier>((ref) {
  final notifier = _Notifier();
  ref.listen<WebAccess>(webAccessProvider, (_, _) => notifier.ping());
  ref.onDispose(notifier.dispose);
  return notifier;
});

class _Notifier extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// Plans of the Inventory Cloud product for the gate's price summary.
/// Public endpoint, no token. Errors propagate (the gate falls back to the
/// fixed EUR copy).
final cloudPlansProvider = FutureProvider.autoDispose<List<SubscriptionPlan>>((ref) {
  return ref.watch(plantlyApiProvider).getPlans(product: 'inventory_cloud');
});
