import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/providers.dart';
import '../marketplace/plantly_api.dart';
import '../marketplace/plantly_auth.dart';
import 'sign_in_events.dart';

/// `entitlements.inventory_cloud.shared_access` (MULTI-USER-V2 §2.13, made
/// informational by §8): the caller is a member (any role) of [collections]
/// ≥ 1 non-deleted collections whose owner is currently entitled. It grants
/// NOTHING — every participant needs their own plan — and is kept only for
/// display / diagnostics. Absent on older servers → [none].
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
    this.cancelAtPeriodEnd = false,
    this.sharedAccess = SharedAccess.none,
  });

  /// The caller's OWN entitlement — the one and only cloud predicate
  /// (MULTI-USER-V2 §8): the web gate, the personal collection AND every
  /// shared collection the account takes part in all require it.
  final bool active;

  /// Informational only (§8): membership in an entitled owner's collection
  /// grants no access of its own.
  final SharedAccess sharedAccess;

  /// `pro` | `inventory_cloud` | null (not entitled, or the server predates
  /// the `entitlements` block and we fell back to `is_pro`).
  final String? source;

  /// `stripe` | `play` (PLAY-BILLING-CONTRACT §2, additive). Null when the
  /// server predates the field — treated as Stripe everywhere
  /// ([managedByPlay] is false).
  final String? provider;
  final DateTime? currentPeriodEnd;

  /// The granting subscription is cancelled and will not renew:
  /// [currentPeriodEnd] is when it ends, not when it renews. Read from the
  /// `subscriptions[]` row behind the grant (the `entitlements` block does
  /// not carry it); false when unknown.
  final bool cancelAtPeriodEnd;

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
        final source = e['source'] as String?;
        final provider = e['provider'] as String?;
        return CloudEntitlement(
          active: e['active'] == true,
          source: source,
          provider: provider,
          currentPeriodEnd: _date(e['current_period_end']),
          cancelAtPeriodEnd: _grantCancels(body['subscriptions'], source, provider),
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
      cancelAtPeriodEnd: isPro && body['cancel_at_period_end'] == true,
    );
  }

  /// `cancel_at_period_end` of the `subscriptions[]` row that grants the
  /// entitlement: product = [source] (`pro` | `inventory_cloud`), provider
  /// as given (absent provider = Stripe, as everywhere else).
  static bool _grantCancels(Object? subs, String? source, String? provider) {
    if (subs is! List || source == null) return false;
    for (final row in subs) {
      if (row is! Map<String, dynamic>) continue;
      if (row['product'] != source) continue;
      if ((row['provider'] ?? 'stripe') != (provider ?? 'stripe')) continue;
      return row['cancel_at_period_end'] == true;
    }
    return false;
  }

  static DateTime? _date(Object? v) => v is String && v.isNotEmpty ? DateTime.tryParse(v)?.toUtc() : null;

  Map<String, dynamic> toJson() => {
        'active': active,
        'source': source,
        'provider': provider,
        'current_period_end': currentPeriodEnd?.toIso8601String(),
        'cancel_at_period_end': cancelAtPeriodEnd,
        'shared_access': sharedAccess.toJson(),
      };

  factory CloudEntitlement.fromJson(Map<String, dynamic> m) => CloudEntitlement(
        active: m['active'] == true,
        source: m['source'] as String?,
        provider: m['provider'] as String?,
        currentPeriodEnd: _date(m['current_period_end']),
        cancelAtPeriodEnd: m['cancel_at_period_end'] == true,
        sharedAccess: SharedAccess.fromJson(m['shared_access']),
      );

  @override
  bool operator ==(Object other) =>
      other is CloudEntitlement &&
      other.active == active &&
      other.source == source &&
      other.provider == provider &&
      other.currentPeriodEnd == currentPeriodEnd &&
      other.cancelAtPeriodEnd == cancelAtPeriodEnd &&
      other.sharedAccess == sharedAccess;

  @override
  int get hashCode => Object.hash(active, source, provider, currentPeriodEnd, cancelAtPeriodEnd, sharedAccess);

  @override
  String toString() =>
      'CloudEntitlement(active=$active, source=$source, provider=$provider, until=$currentPeriodEnd, cancels=$cancelAtPeriodEnd, shared=$sharedAccess)';
}

/// How the value currently held by [cloudEntitlementProvider] was obtained.
/// Read (not watched) by the web access gate's offline rule
/// (WEB-ACCESS-POLICY §0): only a value the server confirmed — now, or
/// recently enough to be served from the fresh cache — opens the gate
/// without a banner; a stale-cache fallback opens it read-only for ≤ 24 h.
enum EntitlementSource {
  /// Nothing fetched yet / signed out.
  none,

  /// The server answered this session (or the fresh cache, < [CloudEntitlementNotifier.maxAge]).
  server,

  /// The server could not be reached (network / 5xx / 429); the value is
  /// the last one it gave us — see [CloudEntitlementNotifier.lastVerifiedAt].
  staleCache,

  /// The server answered 401: the session is gone.
  unauthorized,

  /// The server answered 403 (account suspended / refused): the value is the
  /// cache, kept for the Me screen, but it must not open anything.
  forbidden,
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

  /// Provenance of the current value (set right before `build` returns, so
  /// a listener reacting to the new state reads the matching source).
  EntitlementSource source = EntitlementSource.none;

  /// When the server last confirmed the current value (the cache's write
  /// time); null until a fetch succeeded for this user.
  DateTime? lastVerifiedAt;

  bool _forceNext = false;
  bool _observing = false;

  /// The user the current [source] / [lastVerifiedAt] describe. Sentinel
  /// (not null) before the first build so a signed-out start also counts as
  /// a change.
  Object? _sourceUserId = _noUser;
  static const Object _noUser = Object();
  Timer? _timer;
  StreamSubscription<Object?>? _signIns;

  @override
  Future<CloudEntitlement?> build() async {
    // Select the user id only: `auth.current()` below re-emits an equal
    // session object, and watching the whole AsyncValue would rebuild us
    // in a loop.
    final userId = ref.watch(plantlyAuthProvider.select((s) => s.valueOrNull?.userId));
    _installHooks(signedIn: userId != null);
    if (userId != _sourceUserId) {
      // A different account (or none): whatever provenance we held belongs
      // to the previous user. Reset *before* the first await so a reader
      // that sees the loading state cannot pair it with the old user's
      // `server` source and keep their verdict (WEB-ACCESS-POLICY §0).
      _sourceUserId = userId;
      source = EntitlementSource.none;
      lastVerifiedAt = null;
    }
    if (userId == null) return null;
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    final force = _forceNext;
    _forceNext = false;

    final cached = _readCache(prefs, userId);
    lastVerifiedAt = cached?.at;
    if (!force && cached != null && now().difference(cached.at) < maxAge) {
      source = EntitlementSource.server;
      return cached.entitlement;
    }

    final auth = ref.read(plantlyAuthProvider.notifier);
    final api = ref.read(plantlyApiProvider);
    try {
      final live = await auth.current();
      if (live == null) {
        source = EntitlementSource.unauthorized;
        return null;
      }
      final body = await api.getMySubscription(live.token);
      final entitlement = CloudEntitlement.fromSubscriptionJson(body);
      await _writeCache(prefs, userId, entitlement);
      source = EntitlementSource.server;
      lastVerifiedAt = now();
      return entitlement;
    } on PlantlyNetworkException {
      source = EntitlementSource.staleCache;
      if (cached != null) return cached.entitlement;
      rethrow;
    } on PlantlyApiException catch (e) {
      // 401: the session is gone (auth.current() already cleared it when it
      // could tell). Anything else with a cache: keep showing the cache.
      if (e.isUnauthorized) {
        source = EntitlementSource.unauthorized;
        return null;
      }
      if (e.status == 403) {
        // A refusal is a verdict about the account, not an outage: the
        // cached value may stay (Me screen) but it must never again be
        // served through the ≤ maxAge fast path as if the server confirmed
        // it — drop the timestamp so the next build asks the server.
        source = EntitlementSource.forbidden;
        await prefs.remove(cacheAtKey);
        lastVerifiedAt = null;
      } else {
        source = EntitlementSource.staleCache;
      }
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

  /// Re-fetch only when the cache is older than [olderThan] (default
  /// [maxAge]: resume, timer; the web gate passes a shorter window on
  /// window focus / visibility).
  Future<void> refreshIfStale({Duration? olderThan}) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final at = prefs.getInt(cacheAtKey);
    if (at == null || now().difference(DateTime.fromMillisecondsSinceEpoch(at, isUtc: true)) >= (olderThan ?? maxAge)) {
      _forceNext = true;
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
