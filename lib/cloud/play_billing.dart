import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../marketplace/plantly_api.dart';
import '../marketplace/plantly_session.dart';
import 'entitlement.dart';

/// Google Play product + base plans for Inventory Cloud (PLAY-BILLING-CONTRACT §0).
const String kPlayProductId = 'inventory_cloud';
const String kPlayBasePlanMonthly = 'monthly';
const String kPlayBasePlanYearly = 'yearly';
const String kPlayPackageName = 'ro.plantly.inventory';

/// Play's "manage subscriptions" deep link for our product (§0 "Managed in Play").
const String kPlayManageSubscriptionUrl =
    'https://play.google.com/store/account/subscriptions?sku=$kPlayProductId&package=$kPlayPackageName';

/// `hex(sha256("plantly:" + userId))` — the account-linking value the server
/// recomputes for the JWT caller (§0). Sent as `applicationUserName`, which
/// `in_app_purchase_android` 0.5.3 forwards as `accountId` →
/// `BillingFlowParams.setObfuscatedAccountId` (plugin
/// `MethodCallHandlerImpl.java`), i.e. Google's
/// `externalAccountIdentifiers.obfuscatedExternalAccountId`.
String playObfuscatedAccountId(String userId) => sha256.convert(utf8.encode('plantly:$userId')).toString();

/// The slice of the `in_app_purchase` plugin the service talks to. Seam so
/// tests drive a fake store without a platform channel.
abstract class PlayStore {
  Future<bool> isAvailable();
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});
  Future<void> completePurchase(PurchaseDetails purchase);
  Future<void> restorePurchases({String? applicationUserName});
  Stream<List<PurchaseDetails>> get purchaseStream;
}

/// The real thing: `InAppPurchase.instance`.
class InAppPurchaseStore implements PlayStore {
  InAppPurchaseStore([InAppPurchase? plugin]) : _plugin = plugin ?? InAppPurchase.instance;
  final InAppPurchase _plugin;

  @override
  Future<bool> isAvailable() => _plugin.isAvailable();
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) =>
      _plugin.queryProductDetails(identifiers);
  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      _plugin.buyNonConsumable(purchaseParam: purchaseParam);
  @override
  Future<void> completePurchase(PurchaseDetails purchase) => _plugin.completePurchase(purchase);
  @override
  Future<void> restorePurchases({String? applicationUserName}) =>
      _plugin.restorePurchases(applicationUserName: applicationUserName);
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _plugin.purchaseStream;
}

/// One purchasable base plan of [kPlayProductId], priced by Play (§4: never
/// our own numbers).
class PlayPlan {
  const PlayPlan({
    required this.basePlanId,
    required this.formattedPrice,
    required this.billingPeriod,
    required this.offerToken,
    required this.productDetails,
  });

  /// `monthly` | `yearly`.
  final String basePlanId;

  /// Play's localized recurring price, e.g. `9,00 RON`, `€1.99`.
  final String formattedPrice;

  /// ISO 8601 duration of the recurring phase (`P1M`, `P1Y`).
  final String billingPeriod;

  /// `offerIdToken` of the chosen offer — what `launchBillingFlow` needs.
  final String offerToken;

  /// The plugin object to hand back to `buyNonConsumable`.
  final ProductDetails productDetails;

  bool get isYearly => basePlanId == kPlayBasePlanYearly;

  /// Pick one [PlayPlan] per base plan out of the per-offer
  /// [GooglePlayProductDetails] the plugin expands a subscription into.
  /// Prefers the plain base-plan offer (`offerId == null`) over intro
  /// offers; the price shown is the recurring phase (the last one), so an
  /// intro price never masquerades as the renewal price. Ordered monthly,
  /// yearly; unknown base plans are dropped.
  static List<PlayPlan> fromProductDetails(Iterable<ProductDetails> details) {
    final byPlan = <String, PlayPlan>{};
    final hasBaseOffer = <String>{};
    for (final d in details) {
      if (d is! GooglePlayProductDetails || d.id != kPlayProductId) continue;
      final idx = d.subscriptionIndex;
      final offers = d.productDetails.subscriptionOfferDetails;
      if (idx == null || offers == null || idx >= offers.length) continue;
      final offer = offers[idx];
      if (offer.basePlanId != kPlayBasePlanMonthly && offer.basePlanId != kPlayBasePlanYearly) continue;
      if (offer.pricingPhases.isEmpty) continue;
      final isBase = offer.offerId == null;
      if (byPlan.containsKey(offer.basePlanId) && (!isBase || hasBaseOffer.contains(offer.basePlanId))) continue;
      final recurring = offer.pricingPhases.last;
      byPlan[offer.basePlanId] = PlayPlan(
        basePlanId: offer.basePlanId,
        formattedPrice: recurring.formattedPrice,
        billingPeriod: recurring.billingPeriod,
        offerToken: offer.offerIdToken,
        productDetails: d,
      );
      if (isBase) hasBaseOffer.add(offer.basePlanId);
    }
    return [?byPlan[kPlayBasePlanMonthly], ?byPlan[kPlayBasePlanYearly]];
  }

  @override
  String toString() => 'PlayPlan($basePlanId $formattedPrice/$billingPeriod)';
}

enum PlayBillingPhase {
  /// Nothing loaded yet (or feature off).
  idle,
  loadingPlans,

  /// Plans known; a purchase may be launched.
  ready,

  /// Play Billing not usable here (no Play, product not found, store error).
  unavailable,

  /// Billing flow launched, waiting for Play's verdict.
  purchasing,

  /// Server verification of a token in flight.
  verifying,
}

@immutable
class PlayBillingState {
  const PlayBillingState({this.phase = PlayBillingPhase.idle, this.plans = const [], this.error});

  final PlayBillingPhase phase;
  final List<PlayPlan> plans;

  /// Why plans could not be loaded (`unavailable`, `not_found`, `store_error`).
  final String? error;

  static const PlayBillingState initial = PlayBillingState();

  bool get busy => phase == PlayBillingPhase.purchasing || phase == PlayBillingPhase.verifying;

  PlayBillingState copyWith({PlayBillingPhase? phase, List<PlayPlan>? plans, String? error, bool clearError = false}) =>
      PlayBillingState(
        phase: phase ?? this.phase,
        plans: plans ?? this.plans,
        error: clearError ? null : (error ?? this.error),
      );

  @override
  bool operator ==(Object other) =>
      other is PlayBillingState && other.phase == phase && listEquals(other.plans, plans) && other.error == error;

  @override
  int get hashCode => Object.hash(phase, Object.hashAll(plans), error);

  @override
  String toString() => 'PlayBillingState($phase, plans=${plans.length}, error=$error)';
}

enum PlayOutcomeKind {
  /// Server said 200: the subscription row is active.
  verified,

  /// Server said 202 (Play PENDING) or Play delivered a pending purchase.
  pending,

  /// 409 `already_entitled`: the user already has Cloud by another row.
  alreadyEntitled,

  /// The user backed out of the Play sheet. Silent.
  canceled,

  /// Anything else — Play error, network, server 4xx/5xx. Retryable.
  failed,
}

/// A one-shot event for the UI (sheet / toast). Emitted on [PlayBillingService.outcomes].
@immutable
class PlayPurchaseOutcome {
  const PlayPurchaseOutcome(this.kind, {this.source, this.provider, this.code, this.restored = false});

  final PlayOutcomeKind kind;

  /// `pro` | `inventory_cloud` for [PlayOutcomeKind.alreadyEntitled].
  final String? source;

  /// `stripe` | `play` for [PlayOutcomeKind.alreadyEntitled].
  final String? provider;

  /// Stable code for [PlayOutcomeKind.failed]: `signed_out`, `launch_failed`,
  /// `network`, `store_error`, or the server's error code.
  final String? code;

  /// The purchase arrived via restore (app start / sign-in), not a tap.
  final bool restored;

  @override
  String toString() => 'PlayPurchaseOutcome($kind${code == null ? '' : ' $code'}${restored ? ' restored' : ''})';
}

/// Android in-app purchase of Inventory Cloud (PLAY-BILLING-CONTRACT §4).
///
/// Pure Dart: everything platform- or app-shaped is injected ([PlayStore],
/// [PlantlyApi], the session + entitlement lookups) so the unit tests run on
/// the VM. The Riverpod glue lives in `play_billing_providers.dart`.
///
/// Flow: [loadPlans] → [buy] (re-checks the entitlement first, §0 "no double
/// charge") → `purchaseStream` → [PlantlyApi.verifyPlayPurchase] → only then
/// `completePurchase`. [restore] re-delivers every owned purchase through
/// the same stream, so restore and purchase share one verification path.
class PlayBillingService {
  PlayBillingService({
    required PlayStore store,
    required PlantlyApi api,
    required Future<PlantlySession?> Function() session,
    required Future<CloudEntitlement?> Function() refreshEntitlement,
    this.enabled = true,
    this.completeOnAlreadyEntitled = false,
    this.restoreThrottle = const Duration(minutes: 10),
    DateTime Function()? now,
  })  : _store = store,
        _api = api,
        _session = session,
        _refreshEntitlement = refreshEntitlement,
        _now = now ?? (() => DateTime.now().toUtc()) {
    _sub = _store.purchaseStream.listen(_onPurchases, onError: (Object e) {
      _emit(const PlayPurchaseOutcome(PlayOutcomeKind.failed, code: 'store_error'));
      _setPhase(_resting);
    });
  }

  final PlayStore _store;
  final PlantlyApi _api;
  final Future<PlantlySession?> Function() _session;
  final Future<CloudEntitlement?> Function() _refreshEntitlement;
  final DateTime Function() _now;

  /// Platform × flags verdict from the caller. When false every entry point
  /// is a no-op, so the service is safe to construct on any platform.
  final bool enabled;

  /// Whether to `completePurchase` (= `acknowledgePurchase` on Android)
  /// after the server answered 409 `already_entitled`.
  ///
  /// Default OFF on purpose: §0(b) relies on the purchase staying
  /// unacknowledged so Google auto-refunds it after 3 days. On Android the
  /// plugin's `completePurchase` IS the acknowledgement (there is no
  /// separate "clear locally" step — see `InAppPurchaseAndroidPlatform
  /// .completePurchase`), so acknowledging here would keep the user's money
  /// without granting anything. Left as a switch so the contract owner can
  /// flip it deliberately if the server-side policy changes.
  final bool completeOnAlreadyEntitled;

  /// Minimum gap between two [restore] calls for the same user (§4 restore
  /// runs on start + sign-in; not on every resume).
  final Duration restoreThrottle;

  final _state = ValueNotifier<PlayBillingState>(PlayBillingState.initial);
  final _outcomes = StreamController<PlayPurchaseOutcome>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// Tokens the server answered 202 for (or that failed with a retryable
  /// error): re-verified on [retryPending] (app resume).
  final Map<String, PurchaseDetails> _retry = {};

  /// Tokens currently in a verify round-trip — the stream can re-deliver a
  /// purchase while we are still talking to the server.
  final Set<String> _inFlight = {};

  /// Tokens the server already accepted (200) in this process; a later
  /// restore re-delivers them and we skip the round-trip.
  final Set<String> _accepted = {};

  String? _lastRestoreUser;
  DateTime? _lastRestoreAt;
  bool _restoring = false;
  bool _disposed = false;

  ValueListenable<PlayBillingState> get listenable => _state;
  PlayBillingState get state => _state.value;
  Stream<PlayPurchaseOutcome> get outcomes => _outcomes.stream;

  /// Tokens awaiting a retry (tests / diagnostics).
  List<String> get pendingTokens => List.unmodifiable(_retry.keys);

  /// Query Play for the two base plans. Safe to call repeatedly; a second
  /// call while loading is ignored.
  Future<void> loadPlans() async {
    if (!enabled || _disposed || state.phase == PlayBillingPhase.loadingPlans) return;
    if (state.busy) return;
    _set(state.copyWith(phase: PlayBillingPhase.loadingPlans, clearError: true));
    try {
      if (!await _store.isAvailable()) {
        _set(const PlayBillingState(phase: PlayBillingPhase.unavailable, error: 'unavailable'));
        return;
      }
      final res = await _store.queryProductDetails({kPlayProductId});
      if (res.error != null) {
        _set(const PlayBillingState(phase: PlayBillingPhase.unavailable, error: 'store_error'));
        return;
      }
      final plans = PlayPlan.fromProductDetails(res.productDetails);
      if (plans.isEmpty) {
        _set(const PlayBillingState(phase: PlayBillingPhase.unavailable, error: 'not_found'));
        return;
      }
      _set(PlayBillingState(phase: PlayBillingPhase.ready, plans: plans));
    } catch (_) {
      _set(const PlayBillingState(phase: PlayBillingPhase.unavailable, error: 'store_error'));
    }
  }

  /// Launch the Play billing flow for [plan]. Re-fetches the entitlement
  /// first and refuses when the user is already entitled (§0(b)(a)).
  Future<void> buy(PlayPlan plan) async {
    if (!enabled || _disposed || state.busy) return;
    final session = await _session();
    if (session == null) {
      _emit(const PlayPurchaseOutcome(PlayOutcomeKind.failed, code: 'signed_out'));
      return;
    }
    _setPhase(PlayBillingPhase.purchasing);
    try {
      final current = await _refreshEntitlement();
      if (current != null && current.active) {
        _emit(PlayPurchaseOutcome(PlayOutcomeKind.alreadyEntitled, source: current.source, provider: current.provider));
        _setPhase(_resting);
        return;
      }
    } on Exception {
      // Could not confirm the entitlement (offline?) — do not sell blind.
      _emit(const PlayPurchaseOutcome(PlayOutcomeKind.failed, code: 'network'));
      _setPhase(_resting);
      return;
    }
    final bool launched;
    try {
      launched = await _store.buyNonConsumable(
        purchaseParam: GooglePlayPurchaseParam(
          productDetails: plan.productDetails,
          applicationUserName: playObfuscatedAccountId(session.userId),
          offerToken: plan.offerToken,
        ),
      );
    } catch (_) {
      _emit(const PlayPurchaseOutcome(PlayOutcomeKind.failed, code: 'launch_failed'));
      _setPhase(_resting);
      return;
    }
    if (!launched) {
      _emit(const PlayPurchaseOutcome(PlayOutcomeKind.failed, code: 'launch_failed'));
      _setPhase(_resting);
    }
    // Otherwise the verdict arrives on purchaseStream.
  }

  /// `restorePurchases()` for the signed-in user (§4). Throttled to one call
  /// per [restoreThrottle] per user unless [force]. Returns true when a
  /// restore was issued.
  Future<bool> restore({bool force = false}) async {
    if (!enabled || _disposed || _restoring) return false;
    final session = await _session();
    if (session == null) return false;
    final now = _now();
    if (!force &&
        _lastRestoreUser == session.userId &&
        _lastRestoreAt != null &&
        now.difference(_lastRestoreAt!) < restoreThrottle) {
      return false;
    }
    _lastRestoreUser = session.userId;
    _lastRestoreAt = now;
    _restoring = true;
    try {
      await _store.restorePurchases(applicationUserName: playObfuscatedAccountId(session.userId));
      return true;
    } catch (_) {
      return false;
    } finally {
      _restoring = false;
    }
  }

  /// App resume: re-verify tokens the server left pending / that failed.
  Future<void> retryPending() async {
    if (!enabled || _disposed || _retry.isEmpty) return;
    for (final p in List<PurchaseDetails>.of(_retry.values)) {
      await _verify(p, restored: true);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _sub?.cancel();
    await _outcomes.close();
    _state.dispose();
  }

  // --- stream handling -----------------------------------------------------

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID != kPlayProductId) continue;
      switch (p.status) {
        case PurchaseStatus.pending:
          // Play says the user still has to pay (e.g. cash at a kiosk). Keep
          // it for a retry; nothing to verify or acknowledge yet.
          _retry[_token(p)] = p;
          _emit(const PlayPurchaseOutcome(PlayOutcomeKind.pending));
          _setPhase(_resting);
        case PurchaseStatus.purchased:
          await _verify(p, restored: false);
        case PurchaseStatus.restored:
          await _verify(p, restored: true);
        case PurchaseStatus.canceled:
          _emit(const PlayPurchaseOutcome(PlayOutcomeKind.canceled));
          _setPhase(_resting);
        case PurchaseStatus.error:
          _emit(PlayPurchaseOutcome(PlayOutcomeKind.failed, code: p.error?.code ?? 'store_error'));
          _setPhase(_resting);
      }
    }
  }

  Future<void> _verify(PurchaseDetails p, {required bool restored}) async {
    final token = _token(p);
    if (token.isEmpty || _inFlight.contains(token)) return;
    if (_accepted.contains(token)) {
      // Already verified this process; just make sure Play is told.
      await _complete(p);
      return;
    }
    final session = await _session();
    if (session == null) {
      _retry[token] = p;
      if (!restored) _emit(const PlayPurchaseOutcome(PlayOutcomeKind.failed, code: 'signed_out', restored: false));
      _setPhase(_resting);
      return;
    }
    _inFlight.add(token);
    _setPhase(PlayBillingPhase.verifying);
    try {
      final reply = await _api.verifyPlayPurchase(session.token, purchaseToken: token, productId: p.productID);
      if (reply.pending) {
        _retry[token] = p;
        await _complete(p);
        _emit(PlayPurchaseOutcome(PlayOutcomeKind.pending, restored: restored));
      } else {
        _retry.remove(token);
        _accepted.add(token);
        await _complete(p);
        _emit(PlayPurchaseOutcome(PlayOutcomeKind.verified, restored: restored));
        unawaited(_refreshEntitlement().catchError((Object _) => null));
      }
    } on PlantlyApiException catch (e) {
      switch (e.message) {
        case 'already_entitled':
          _retry.remove(token);
          if (completeOnAlreadyEntitled) await _complete(p);
          _emit(PlayPurchaseOutcome(
            PlayOutcomeKind.alreadyEntitled,
            source: e.details['source'] as String?,
            provider: e.details['provider'] as String?,
            restored: restored,
          ));
        case 'token_owned_by_other_user' || 'invalid_purchase':
          // Terminal for this token: never ours to acknowledge.
          _retry.remove(token);
          _emit(PlayPurchaseOutcome(PlayOutcomeKind.failed, code: e.message, restored: restored));
        default:
          // 5xx / 503 play_billing_unavailable / 401: retry on resume.
          _retry[token] = p;
          _emit(PlayPurchaseOutcome(PlayOutcomeKind.failed, code: e.message, restored: restored));
      }
    } on PlantlyNetworkException {
      _retry[token] = p;
      _emit(PlayPurchaseOutcome(PlayOutcomeKind.failed, code: 'network', restored: restored));
    } finally {
      _inFlight.remove(token);
      _setPhase(_resting);
    }
  }

  /// Tell Play the purchase was processed — never before the server did.
  Future<void> _complete(PurchaseDetails p) async {
    if (!p.pendingCompletePurchase) return;
    try {
      await _store.completePurchase(p);
    } catch (_) {
      // Play will re-deliver it on the next restore; the server is idempotent.
    }
  }

  static String _token(PurchaseDetails p) => p.verificationData.serverVerificationData;

  PlayBillingPhase get _resting => state.plans.isEmpty
      ? (state.phase == PlayBillingPhase.unavailable ? PlayBillingPhase.unavailable : PlayBillingPhase.idle)
      : PlayBillingPhase.ready;

  void _setPhase(PlayBillingPhase phase) => _set(state.copyWith(phase: phase));

  void _set(PlayBillingState s) {
    if (!_disposed) _state.value = s;
  }

  void _emit(PlayPurchaseOutcome o) {
    if (!_disposed && !_outcomes.isClosed) _outcomes.add(o);
  }
}
