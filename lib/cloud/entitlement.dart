import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/providers.dart';
import '../marketplace/plantly_api.dart';
import '../marketplace/plantly_auth.dart';
import 'sign_in_events.dart';

/// `entitlements.inventory_cloud.shared_access` (MULTI-USER-V2 §0/§2.13):
/// the caller is a member (any role) of [collections] ≥ 1 non-deleted
/// collections whose owner is currently entitled. Absent on older servers
/// → [none].
class SharedAccess {
  const SharedAccess({required this.active, this.collections = 0});

  final bool active;

  /// Number of such collections (0 when inactive / unknown).
  final int collections;

  static const SharedAccess none = SharedAccess(active: false);

  factory SharedAccess.fromJson(Object? m) {
    if (m is! Map<String, dynamic>) return none;
    return SharedAccess(
      active: m['active'] == true,
      collections: (m['collections'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'active': active, 'collections': collections};

  @override
  bool operator ==(Object other) => other is SharedAccess && other.active == active && other.collections == collections;

  @override
  int get hashCode => Object.hash(active, collections);

  @override
  String toString() => 'SharedAccess(active=$active, collections=$collections)';
}

/// The `inventory_cloud` entitlement (CLOUD-SYNC-CONTRACT §1.2/§1.3):
/// granted by an active Plantly Pro OR Plantly Inventory Cloud subscription.
class CloudEntitlement {
  const CloudEntitlement({
    required this.active,
    this.source,
    this.provider,
    this.currentPeriodEnd,
    this.sharedAccess = SharedAccess.none,
  });

  /// The caller's OWN entitlement. Shared collections do not set this —
  /// see [sharedAccess] and [hasCloudAccess].
  final bool active;

  /// Membership in an entitled owner's collection (MULTI-USER-V2 §0):
  /// opens the web gate and the shared collections, never the personal
  /// one (push there → 402 as today).
  final SharedAccess sharedAccess;

  /// Own plan active OR access through a shared collection — the web-gate
  /// predicate (§3 "Web gate").
  bool get hasCloudAccess => active || sharedAccess.active;

  /// Only shared access: the Cloud screen explains that the personal
  /// collection stays local-only.
  bool get sharedAccessOnly => !active && sharedAccess.active;

  /// `pro` | `inventory_cloud` | null (not entitled, or the server predates
  /// the `entitlements` block and we fell back to `is_pro`).
  final String? source;

  /// `stripe` | `play` (PLAY-BILLING-CONTRACT §2, additive). Null when the
  /// server predates the field — treated as Stripe everywhere
  /// ([managedByPlay] is false).
  final String? provider;
  final DateTime? currentPeriodEnd;

  /// The entitling row is a Google Play subscription: managed (cancel /
  /// pause / change plan) in Play, not on plantly.ro.
  bool get managedByPlay => active && provider == 'play';

  static const CloudEntitlement none = CloudEntitlement(active: false);

  /// Parse `GET /subscriptions/me`. Prefers `entitlements.inventory_cloud`;
  /// when the block is absent (older monolith) falls back to the top-level
  /// Pro fields — Pro includes cloud (§0).
  factory CloudEntitlement.fromSubscriptionJson(Map<String, dynamic> body) {
    final ents = body['entitlements'];
    if (ents is Map<String, dynamic>) {
      final e = ents['inventory_cloud'];
      if (e is Map<String, dynamic>) {
        return CloudEntitlement(
          active: e['active'] == true,
          source: e['source'] as String?,
          provider: e['provider'] as String?,
          currentPeriodEnd: _date(e['current_period_end']),
          sharedAccess: SharedAccess.fromJson(e['shared_access']),
        );
      }
      // Block present but no inventory_cloud key: the server knows about
      // entitlements and this user has none.
      return none;
    }
    final isPro = body['is_pro'] == true;
    return CloudEntitlement(
      active: isPro,
      source: isPro ? 'pro' : null,
      currentPeriodEnd: isPro ? _date(body['current_period_end']) : null,
    );
  }

  static DateTime? _date(Object? v) => v is String && v.isNotEmpty ? DateTime.tryParse(v)?.toUtc() : null;

  Map<String, dynamic> toJson() => {
        'active': active,
        'source': source,
        'provider': provider,
        'current_period_end': currentPeriodEnd?.toIso8601String(),
        'shared_access': sharedAccess.toJson(),
      };

  factory CloudEntitlement.fromJson(Map<String, dynamic> m) => CloudEntitlement(
        active: m['active'] == true,
        source: m['source'] as String?,
        provider: m['provider'] as String?,
        currentPeriodEnd: _date(m['current_period_end']),
        sharedAccess: SharedAccess.fromJson(m['shared_access']),
      );

  @override
  bool operator ==(Object other) =>
      other is CloudEntitlement &&
      other.active == active &&
      other.source == source &&
      other.provider == provider &&
      other.currentPeriodEnd == currentPeriodEnd &&
      other.sharedAccess == sharedAccess;

  @override
  int get hashCode => Object.hash(active, source, provider, currentPeriodEnd, sharedAccess);

  @override
  String toString() =>
      'CloudEntitlement(active=$active, source=$source, provider=$provider, until=$currentPeriodEnd, shared=$sharedAccess)';
}

/// Prefs-cached entitlement for the signed-in user. `null` = signed out.
///
/// Refresh policy: a cached value younger than [maxAge] is served as-is;
/// otherwise the server is asked (falling back to the stale cache when the
/// network is down). Re-fetched on app resume, every [maxAge] while
/// foregrounded, on every sign-in ([SignInEvents]) and on [refresh].
class CloudEntitlementNotifier extends AsyncNotifier<CloudEntitlement?> with WidgetsBindingObserver {
  static const Duration maxAge = Duration(minutes: 15);
  static const String cacheKey = 'plantly_cloud_entitlement';
  static const String cacheAtKey = 'plantly_cloud_entitlement_at';
  static const String cacheUserKey = 'plantly_cloud_entitlement_user';

  /// Overridable clock for tests.
  DateTime Function() now = () => DateTime.now().toUtc();

  bool _forceNext = false;
  bool _observing = false;
  Timer? _timer;
  StreamSubscription<Object?>? _signIns;

  @override
  Future<CloudEntitlement?> build() async {
    // Select the user id only: `auth.current()` below re-emits an equal
    // session object, and watching the whole AsyncValue would rebuild us
    // in a loop.
    final userId = ref.watch(plantlyAuthProvider.select((s) => s.valueOrNull?.userId));
    _installHooks(signedIn: userId != null);
    if (userId == null) return null;
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    final force = _forceNext;
    _forceNext = false;

    final cached = _readCache(prefs, userId);
    if (!force && cached != null && now().difference(cached.at) < maxAge) return cached.entitlement;

    final auth = ref.read(plantlyAuthProvider.notifier);
    final api = ref.read(plantlyApiProvider);
    try {
      final live = await auth.current();
      if (live == null) return null;
      final body = await api.getMySubscription(live.token);
      final entitlement = CloudEntitlement.fromSubscriptionJson(body);
      await _writeCache(prefs, userId, entitlement);
      return entitlement;
    } on PlantlyNetworkException {
      if (cached != null) return cached.entitlement;
      rethrow;
    } on PlantlyApiException catch (e) {
      // 401: the session is gone (auth.current() already cleared it when it
      // could tell). Anything else with a cache: keep showing the cache.
      if (e.isUnauthorized) return null;
      if (cached != null) return cached.entitlement;
      rethrow;
    }
  }

  /// Bypass the cache and ask the server (the "Refresh status" row).
  Future<void> refresh() async {
    _forceNext = true;
    ref.invalidateSelf();
    await future;
  }

  /// Re-fetch only when the cache is older than [maxAge] (resume, timer).
  Future<void> refreshIfStale() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final at = prefs.getInt(cacheAtKey);
    if (at == null || now().difference(DateTime.fromMillisecondsSinceEpoch(at, isUtc: true)) >= maxAge) {
      ref.invalidateSelf();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refreshIfStale());
  }

  void _installHooks({required bool signedIn}) {
    // `build()` runs on every rebuild; hooks are (re)made per build so they
    // never outlive the notifier and never double up. The periodic timer and
    // lifecycle observer only matter while signed in.
    _teardownHooks();
    _signIns = ref.read(signInEventsProvider).stream.listen((_) => unawaited(refresh()));
    if (signedIn) {
      _timer = Timer.periodic(maxAge, (_) => unawaited(refreshIfStale()));
      final binding = _bindingOrNull();
      if (binding != null) {
        binding.addObserver(this);
        _observing = true;
      }
    }
    ref.onDispose(_teardownHooks);
  }

  void _teardownHooks() {
    _timer?.cancel();
    _timer = null;
    _signIns?.cancel();
    _signIns = null;
    if (_observing) {
      _bindingOrNull()?.removeObserver(this);
      _observing = false;
    }
  }

  static WidgetsBinding? _bindingOrNull() {
    try {
      return WidgetsBinding.instance;
    } catch (_) {
      // Pure-Dart tests without a binding.
      return null;
    }
  }

  ({CloudEntitlement entitlement, DateTime at})? _readCache(SharedPreferences prefs, String userId) {
    if (prefs.getString(cacheUserKey) != userId) return null;
    final raw = prefs.getString(cacheKey);
    final at = prefs.getInt(cacheAtKey);
    if (raw == null || at == null) return null;
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return (
        entitlement: CloudEntitlement.fromJson(decoded),
        at: DateTime.fromMillisecondsSinceEpoch(at, isUtc: true),
      );
    } on FormatException {
      return null;
    }
  }

  Future<void> _writeCache(SharedPreferences prefs, String userId, CloudEntitlement e) async {
    await prefs.setString(cacheUserKey, userId);
    await prefs.setString(cacheKey, json.encode(e.toJson()));
    await prefs.setInt(cacheAtKey, now().millisecondsSinceEpoch);
  }
}

final cloudEntitlementProvider =
    AsyncNotifierProvider<CloudEntitlementNotifier, CloudEntitlement?>(CloudEntitlementNotifier.new);

/// Web-gate predicate (MULTI-USER-V2 §3): the signed-in account may use the
/// cloud surfaces when its own entitlement is active OR it has access
/// through a shared collection. False while signed out / still loading.
final hasCloudAccessProvider = Provider<bool>((ref) {
  final e = ref.watch(cloudEntitlementProvider).valueOrNull;
  return e?.hasCloudAccess ?? false;
});
