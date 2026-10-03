import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:plantly_inventory/cloud/entitlement.dart';
import 'package:plantly_inventory/cloud/play_billing.dart';
import 'package:plantly_inventory/marketplace/plantly_api.dart';
import 'package:plantly_inventory/marketplace/plantly_session.dart';

import '../marketplace/plantly_session_test.dart' show fakeJwt;

/// Scripted stand-in for `InAppPurchase` (PLAY-BILLING-CONTRACT §4 tests).
class FakePlayStore implements PlayStore {
  bool available = true;
  ProductDetailsResponse? response;
  bool launchResult = true;
  final purchaseParams = <PurchaseParam>[];
  final completed = <String>[];
  final restoreCalls = <String?>[];
  final _stream = StreamController<List<PurchaseDetails>>.broadcast();

  /// Purchases `restorePurchases()` re-delivers (as `restored`).
  List<PurchaseDetails> owned = [];

  void deliver(List<PurchaseDetails> purchases) => _stream.add(purchases);

  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async =>
      response ?? ProductDetailsResponse(productDetails: const [], notFoundIDs: identifiers.toList());
  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    purchaseParams.add(purchaseParam);
    return launchResult;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async =>
      completed.add(purchase.verificationData.serverVerificationData);
  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoreCalls.add(applicationUserName);
    if (owned.isNotEmpty) _stream.add([for (final p in owned) _restored(p)]);
  }

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _stream.stream;

  static PurchaseDetails _restored(PurchaseDetails p) {
    final g = p as GooglePlayPurchaseDetails;
    return GooglePlayPurchaseDetails(
      purchaseID: g.purchaseID,
      productID: g.productID,
      verificationData: g.verificationData,
      transactionDate: g.transactionDate,
      billingClientPurchase: g.billingClientPurchase,
      status: PurchaseStatus.restored,
    );
  }
}

PricingPhaseWrapper _phase(String price, String period, {RecurrenceMode mode = RecurrenceMode.infiniteRecurring}) =>
    PricingPhaseWrapper(
      billingCycleCount: 0,
      billingPeriod: period,
      formattedPrice: price,
      priceAmountMicros: 1990000,
      priceCurrencyCode: 'RON',
      recurrenceMode: mode,
    );

ProductDetailsWrapper _subscription({bool withIntro = false, bool yearlyFirst = false}) {
  final monthly = SubscriptionOfferDetailsWrapper(
    basePlanId: 'monthly',
    offerTags: const [],
    offerIdToken: 'tok-monthly',
    pricingPhases: [_phase('9,00 RON', 'P1M')],
  );
  final yearly = SubscriptionOfferDetailsWrapper(
    basePlanId: 'yearly',
    offerTags: const [],
    offerIdToken: 'tok-yearly',
    pricingPhases: [_phase('79,00 RON', 'P1Y')],
  );
  final intro = SubscriptionOfferDetailsWrapper(
    basePlanId: 'yearly',
    offerId: 'intro',
    offerTags: const ['intro'],
    offerIdToken: 'tok-yearly-intro',
    pricingPhases: [_phase('39,00 RON', 'P1Y', mode: RecurrenceMode.finiteRecurring), _phase('79,00 RON', 'P1Y')],
  );
  return ProductDetailsWrapper(
    description: 'Cloud backup & sync',
    name: 'Inventory Cloud',
    productId: kPlayProductId,
    productType: ProductType.subs,
    title: 'Inventory Cloud (PlantlyInventory)',
    subscriptionOfferDetails: [
      if (withIntro) intro,
      if (yearlyFirst) yearly,
      monthly,
      if (!yearlyFirst) yearly,
    ],
  );
}

ProductDetailsResponse _response(ProductDetailsWrapper w) =>
    ProductDetailsResponse(productDetails: GooglePlayProductDetails.fromProductDetails(w), notFoundIDs: const []);

GooglePlayPurchaseDetails _purchase(String token, {PurchaseStatus status = PurchaseStatus.purchased, bool acked = false}) {
  final w = PurchaseWrapper(
    orderId: 'GPA.1234-$token',
    packageName: kPlayPackageName,
    purchaseTime: 1700000000000,
    purchaseToken: token,
    signature: 'sig',
    products: const [kPlayProductId],
    isAutoRenewing: true,
    originalJson: '{}',
    isAcknowledged: acked,
    purchaseState: PurchaseStateWrapper.purchased,
  );
  return GooglePlayPurchaseDetails(
    purchaseID: w.orderId,
    productID: kPlayProductId,
    verificationData: PurchaseVerificationData(localVerificationData: '{}', serverVerificationData: token, source: 'google_play'),
    transactionDate: '1700000000000',
    billingClientPurchase: w,
    status: status,
  );
}

class _Harness {
  _Harness({
    this.verifyStatus = 200,
    Map<String, dynamic>? verifyBody,
    this.entitled = false,
    bool signedIn = true,
    bool completeOnAlreadyEntitled = false,
    this.throwNetwork = false,
  }) : verifyBody = verifyBody ?? const {} {
    final token = fakeJwt(
      iat: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
      exp: DateTime.now().toUtc().add(const Duration(hours: 24)).millisecondsSinceEpoch ~/ 1000,
      userId: 'u-42',
    );
    session = signedIn ? PlantlySession.fromToken(token) : null;
    store = FakePlayStore()..response = _response(_subscription());
    final api = PlantlyApi(
      host: 'https://plantly.test',
      sendUserAgent: false,
      client: MockClient((req) async {
        requests.add(req);
        if (req.url.path.endsWith('/subscriptions/play/verify')) {
          if (throwNetwork) throw http.ClientException('offline');
          final body = verifyStatus >= 400
              ? verifyBody
              : {
                  'status': verifyStatus == 202 ? 'pending' : 'active',
                  'product': kPlayProductId,
                  'provider': 'play',
                  ...this.verifyBody,
                };
          return http.Response(json.encode(body), verifyStatus, headers: {'content-type': 'application/json'});
        }
        return http.Response('{"error":"nope"}', 404);
      }),
    );
    service = PlayBillingService(
      store: store,
      api: api,
      session: () async => session,
      refreshEntitlement: () async {
        refreshes++;
        return entitled
            ? const CloudEntitlement(active: true, source: 'pro', provider: 'stripe')
            : CloudEntitlement.none;
      },
      completeOnAlreadyEntitled: completeOnAlreadyEntitled,
      now: () => now,
    );
    service.outcomes.listen(outcomes.add);
  }

  int verifyStatus;
  final Map<String, dynamic> verifyBody;
  bool entitled;
  final bool throwNetwork;
  PlantlySession? session;
  late final FakePlayStore store;
  late final PlayBillingService service;
  final requests = <http.Request>[];
  final outcomes = <PlayPurchaseOutcome>[];
  int refreshes = 0;
  DateTime now = DateTime.utc(2026, 10, 3, 12);

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));
}

void main() {
  group('PlayPlan.fromProductDetails', () {
    test('one plan per base plan, monthly first, Play price strings', () {
      final plans = PlayPlan.fromProductDetails(GooglePlayProductDetails.fromProductDetails(_subscription(yearlyFirst: true)));
      expect(plans.map((p) => p.basePlanId), ['monthly', 'yearly']);
      expect(plans[0].formattedPrice, '9,00 RON');
      expect(plans[0].billingPeriod, 'P1M');
      expect(plans[0].offerToken, 'tok-monthly');
      expect(plans[1].formattedPrice, '79,00 RON');
      expect(plans[1].isYearly, isTrue);
    });

    test('prefers the plain base-plan offer over an intro offer', () {
      final plans = PlayPlan.fromProductDetails(GooglePlayProductDetails.fromProductDetails(_subscription(withIntro: true)));
      final yearly = plans.singleWhere((p) => p.isYearly);
      expect(yearly.offerToken, 'tok-yearly');
      expect(yearly.formattedPrice, '79,00 RON');
    });

    test('ignores other products and unknown base plans', () {
      final other = ProductDetailsWrapper(
        description: '',
        name: '',
        productId: 'something_else',
        productType: ProductType.subs,
        title: '',
        subscriptionOfferDetails: [
          SubscriptionOfferDetailsWrapper(basePlanId: 'monthly', offerTags: const [], offerIdToken: 'x', pricingPhases: [_phase('1', 'P1M')]),
        ],
      );
      expect(PlayPlan.fromProductDetails(GooglePlayProductDetails.fromProductDetails(other)), isEmpty);
    });
  });

  test('playObfuscatedAccountId = hex(sha256("plantly:" + userId)) (§0)', () {
    expect(playObfuscatedAccountId('u-42'), sha256.convert(utf8.encode('plantly:u-42')).toString());
    expect(playObfuscatedAccountId('u-42'), hasLength(64));
  });

  group('loadPlans', () {
    test('ready with both plans', () async {
      final h = _Harness();
      await h.service.loadPlans();
      expect(h.service.state.phase, PlayBillingPhase.ready);
      expect(h.service.state.plans.map((p) => p.basePlanId), ['monthly', 'yearly']);
    });

    test('store unavailable / product not found / store error → unavailable', () async {
      final h = _Harness();
      h.store.available = false;
      await h.service.loadPlans();
      expect(h.service.state.phase, PlayBillingPhase.unavailable);
      expect(h.service.state.error, 'unavailable');

      h.store.available = true;
      h.store.response = null;
      await h.service.loadPlans();
      expect(h.service.state.error, 'not_found');

      h.store.response = ProductDetailsResponse(
        productDetails: const [],
        notFoundIDs: const [],
        error: IAPError(source: 'google_play', code: 'x', message: 'boom'),
      );
      await h.service.loadPlans();
      expect(h.service.state.error, 'store_error');
    });

    test('disabled service never touches the store', () async {
      final store = FakePlayStore();
      final s = PlayBillingService(
        store: store,
        api: PlantlyApi(client: MockClient((_) async => http.Response('', 500)), host: 'https://x'),
        session: () async => null,
        refreshEntitlement: () async => null,
        enabled: false,
      );
      await s.loadPlans();
      expect(await s.restore(force: true), isFalse);
      expect(s.state.phase, PlayBillingPhase.idle);
      expect(store.restoreCalls, isEmpty);
      await s.dispose();
    });
  });

  group('buy → purchaseStream → verify → completePurchase', () {
    test('happy path: obfuscated account id + offer token, verify 200, then complete, entitlement refreshed', () async {
      final h = _Harness();
      await h.service.loadPlans();
      final monthly = h.service.state.plans.first;
      await h.service.buy(monthly);
      expect(h.refreshes, 1, reason: 're-fetches /me before launching (§0 no double charge)');
      expect(h.service.state.phase, PlayBillingPhase.purchasing);
      final param = h.store.purchaseParams.single as GooglePlayPurchaseParam;
      expect(param.applicationUserName, playObfuscatedAccountId('u-42'));
      expect(param.offerToken, 'tok-monthly');
      expect(param.productDetails.id, kPlayProductId);
      expect(h.store.completed, isEmpty);

      h.store.deliver([_purchase('tok-A')]);
      await h.settle();
      final req = h.requests.single;
      expect(req.url.path, '/api/v1/subscriptions/play/verify');
      expect(req.headers['authorization'], 'Bearer ${h.session!.token}');
      expect(json.decode(req.body), {'purchase_token': 'tok-A', 'product_id': kPlayProductId});
      expect(h.store.completed, ['tok-A']);
      expect(h.outcomes.map((o) => o.kind), [PlayOutcomeKind.verified]);
      expect(h.refreshes, 2, reason: 'entitlement re-fetched after a 200');
      expect(h.service.state.phase, PlayBillingPhase.ready);
      expect(h.service.pendingTokens, isEmpty);
      await h.service.dispose();
    });

    test('already entitled locally → no billing flow, alreadyEntitled outcome', () async {
      final h = _Harness(entitled: true);
      await h.service.loadPlans();
      await h.service.buy(h.service.state.plans.first);
      await h.settle();
      expect(h.store.purchaseParams, isEmpty);
      expect(h.outcomes.single.kind, PlayOutcomeKind.alreadyEntitled);
      expect(h.outcomes.single.source, 'pro');
      expect(h.service.state.phase, PlayBillingPhase.ready);
      await h.service.dispose();
    });

    test('signed out → failed(signed_out), nothing launched', () async {
      final h = _Harness(signedIn: false);
      await h.service.loadPlans();
      await h.service.buy(h.service.state.plans.first);
      await h.settle();
      expect(h.store.purchaseParams, isEmpty);
      expect(h.outcomes.single.code, 'signed_out');
      await h.service.dispose();
    });

    test('launch refused by Play → failed(launch_failed), back to ready', () async {
      final h = _Harness();
      h.store.launchResult = false;
      await h.service.loadPlans();
      await h.service.buy(h.service.state.plans.first);
      await h.settle();
      expect(h.outcomes.single.code, 'launch_failed');
      expect(h.service.state.phase, PlayBillingPhase.ready);
      await h.service.dispose();
    });

    test('409 already_entitled: sheet data from the envelope; NOT acknowledged by default (Google auto-refunds)', () async {
      final h = _Harness(verifyStatus: 409, verifyBody: {'error': 'already_entitled', 'source': 'pro', 'provider': 'stripe'});
      await h.service.loadPlans();
      h.store.deliver([_purchase('tok-B')]);
      await h.settle();
      expect(h.requests, hasLength(1));
      final o = h.outcomes.single;
      expect(o.kind, PlayOutcomeKind.alreadyEntitled);
      expect(o.source, 'pro');
      expect(o.provider, 'stripe');
      expect(h.store.completed, isEmpty);
      expect(h.service.pendingTokens, isEmpty, reason: 'not retried: the server will say 409 again');
      expect(h.service.state.phase, PlayBillingPhase.ready);
      await h.service.dispose();
    });

    test('409 already_entitled with completeOnAlreadyEntitled: completePurchase called only AFTER the server answered', () async {
      final h = _Harness(
        verifyStatus: 409,
        verifyBody: {'error': 'already_entitled', 'source': 'inventory_cloud', 'provider': 'stripe'},
        completeOnAlreadyEntitled: true,
      );
      final order = <String>[];
      h.service.outcomes.listen((_) => order.add('outcome'));
      await h.service.loadPlans();
      h.store.deliver([_purchase('tok-C')]);
      // Before the HTTP round-trip resolves nothing may be completed.
      expect(h.store.completed, isEmpty);
      await h.settle();
      expect(h.requests, hasLength(1));
      expect(h.store.completed, ['tok-C']);
      expect(h.outcomes.single.kind, PlayOutcomeKind.alreadyEntitled);
      await h.service.dispose();
    });

    test('202 pending: completePurchase, pending outcome, token kept for retryPending → 200 clears it', () async {
      final h = _Harness(verifyStatus: 202);
      await h.service.loadPlans();
      h.store.deliver([_purchase('tok-D')]);
      await h.settle();
      expect(h.outcomes.single.kind, PlayOutcomeKind.pending);
      expect(h.store.completed, ['tok-D']);
      expect(h.service.pendingTokens, ['tok-D']);
      expect(h.refreshes, 0);

      h.verifyStatus = 200;
      await h.service.retryPending();
      await h.settle();
      expect(h.requests, hasLength(2));
      expect(h.outcomes.last.kind, PlayOutcomeKind.verified);
      expect(h.outcomes.last.restored, isTrue);
      expect(h.service.pendingTokens, isEmpty);
      await h.service.dispose();
    });

    test('network error: no completePurchase, failed(network), retried on resume', () async {
      final h = _Harness(throwNetwork: true);
      await h.service.loadPlans();
      h.store.deliver([_purchase('tok-E')]);
      await h.settle();
      expect(h.store.completed, isEmpty);
      expect(h.outcomes.single.code, 'network');
      expect(h.service.pendingTokens, ['tok-E']);
      await h.service.dispose();
    });

    test('token_owned_by_other_user is terminal: not completed, not retried', () async {
      final h = _Harness(verifyStatus: 409, verifyBody: {'error': 'token_owned_by_other_user'});
      await h.service.loadPlans();
      h.store.deliver([_purchase('tok-F')]);
      await h.settle();
      expect(h.store.completed, isEmpty);
      expect(h.outcomes.single.code, 'token_owned_by_other_user');
      expect(h.service.pendingTokens, isEmpty);
      await h.service.dispose();
    });

    test('canceled / error / pending from Play → outcome, phase back to ready, no server call', () async {
      final h = _Harness();
      await h.service.loadPlans();
      h.store.deliver([_purchase('tok-G', status: PurchaseStatus.canceled)]);
      h.store.deliver([_purchase('tok-H', status: PurchaseStatus.error)]);
      h.store.deliver([_purchase('tok-I', status: PurchaseStatus.pending)]);
      await h.settle();
      expect(h.outcomes.map((o) => o.kind), [PlayOutcomeKind.canceled, PlayOutcomeKind.failed, PlayOutcomeKind.pending]);
      expect(h.requests, isEmpty);
      expect(h.store.completed, isEmpty);
      expect(h.service.state.phase, PlayBillingPhase.ready);
      await h.service.dispose();
    });

    test('an already-acknowledged purchase re-delivered by restore is verified but not re-completed', () async {
      final h = _Harness();
      h.store.deliver([_purchase('tok-J', status: PurchaseStatus.restored, acked: true)]);
      await h.settle();
      expect(h.requests, hasLength(1));
      expect(h.store.completed, isEmpty);
      expect(h.outcomes.single.kind, PlayOutcomeKind.verified);
      expect(h.outcomes.single.restored, isTrue);
      await h.service.dispose();
    });
  });

  group('restore', () {
    test('verifies every owned token (idempotent), throttled to once per 10 min per user', () async {
      final h = _Harness();
      h.store.owned = [_purchase('tok-R1'), _purchase('tok-R2')];
      expect(await h.service.restore(), isTrue);
      await h.settle();
      expect(h.store.restoreCalls, [playObfuscatedAccountId('u-42')]);
      expect(h.requests.map((r) => (json.decode(r.body) as Map)['purchase_token']), ['tok-R1', 'tok-R2']);
      expect(h.store.completed, ['tok-R1', 'tok-R2']);

      h.now = h.now.add(const Duration(minutes: 9));
      expect(await h.service.restore(), isFalse, reason: 'throttled');
      expect(h.store.restoreCalls, hasLength(1));

      expect(await h.service.restore(force: true), isTrue, reason: 'sign-in forces');
      expect(h.store.restoreCalls, hasLength(2));
      await h.settle();
      // Re-delivered tokens were accepted this process: no second round-trip.
      expect(h.requests, hasLength(2));

      h.now = h.now.add(const Duration(minutes: 11));
      expect(await h.service.restore(), isTrue, reason: 'window elapsed');
      expect(h.store.restoreCalls, hasLength(3));
      await h.service.dispose();
    });

    test('signed out → no restore', () async {
      final h = _Harness(signedIn: false);
      expect(await h.service.restore(force: true), isFalse);
      expect(h.store.restoreCalls, isEmpty);
      await h.service.dispose();
    });

    test('a different user is not throttled by the previous one', () async {
      final h = _Harness();
      expect(await h.service.restore(), isTrue);
      final other = fakeJwt(
        iat: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
        exp: DateTime.now().toUtc().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
        userId: 'u-99',
      );
      h.session = PlantlySession.fromToken(other);
      expect(await h.service.restore(), isTrue);
      expect(h.store.restoreCalls, [playObfuscatedAccountId('u-42'), playObfuscatedAccountId('u-99')]);
      await h.service.dispose();
    });
  });
}
