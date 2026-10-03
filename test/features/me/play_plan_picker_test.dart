import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:plantly_inventory/cloud/entitlement.dart';
import 'package:plantly_inventory/cloud/play_billing.dart';
import 'package:plantly_inventory/cloud/play_billing_notices.dart';
import 'package:plantly_inventory/cloud/play_billing_providers.dart';
import 'package:plantly_inventory/config/plantly_features.dart';
import 'package:plantly_inventory/features/me/cloud_screen.dart';
import 'package:plantly_inventory/features/me/cloud_section.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/marketplace/session_store.dart';
import 'package:plantly_inventory/theme/tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../cloud/cloud_state_test.dart' show FixedEntitlement;
import '../../helpers/test_app.dart';
import '../../marketplace/plantly_session_test.dart' show fakeJwt;

/// Minimal scripted store for the widget tests (the service logic itself is
/// covered in test/cloud/play_billing_test.dart).
class _Store implements PlayStore {
  _Store({this.available = true});
  bool available;
  bool plans = true;
  final params = <PurchaseParam>[];
  final _stream = StreamController<List<PurchaseDetails>>.broadcast();

  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async {
    if (!plans) return ProductDetailsResponse(productDetails: const [], notFoundIDs: identifiers.toList());
    PricingPhaseWrapper phase(String price, String period) => PricingPhaseWrapper(
          billingCycleCount: 0,
          billingPeriod: period,
          formattedPrice: price,
          priceAmountMicros: 0,
          priceCurrencyCode: 'RON',
          recurrenceMode: RecurrenceMode.infiniteRecurring,
        );
    final w = ProductDetailsWrapper(
      description: '',
      name: 'Inventory Cloud',
      productId: kPlayProductId,
      productType: ProductType.subs,
      title: '',
      subscriptionOfferDetails: [
        SubscriptionOfferDetailsWrapper(basePlanId: 'monthly', offerTags: const [], offerIdToken: 'm', pricingPhases: [phase('9,00 RON', 'P1M')]),
        SubscriptionOfferDetailsWrapper(basePlanId: 'yearly', offerTags: const [], offerIdToken: 'y', pricingPhases: [phase('79,00 RON', 'P1Y')]),
      ],
    );
    return ProductDetailsResponse(productDetails: GooglePlayProductDetails.fromProductDetails(w), notFoundIDs: const []);
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    params.add(purchaseParam);
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}
  @override
  Future<void> restorePurchases({String? applicationUserName}) async {}
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _stream.stream;
}

void main() {
  final token = fakeJwt(
    iat: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
    exp: DateTime.now().toUtc().add(const Duration(hours: 24)).millisecondsSinceEpoch ~/ 1000,
  );

  Future<_Store> pump(
    WidgetTester tester, {
    bool playBilling = true,
    bool signedIn = true,
    CloudEntitlement? entitlement = CloudEntitlement.none,
    bool hang = false,
    Locale locale = const Locale('en'),
    _Store? store,
    bool detailed = false,
  }) async {
    SharedPreferences.setMockInitialValues({'plantly_onboarded': true});
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))));
    final s = store ?? _Store();
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(buildTestApp(
      overrides: [
        cloudEnabledProvider.overrideWithValue(true),
        playBillingEnabledProvider.overrideWithValue(playBilling),
        // The platform verdict is taken out of the equation: tests run on the
        // Linux VM, so force "Android" when the flag is on.
        playBillingAvailableProvider.overrideWithValue(playBilling),
        cloudPurchaseLinkAllowedProvider.overrideWithValue(false),
        playStoreProvider.overrideWithValue(s),
        sessionStoreProvider.overrideWith((_) => InMemorySessionStore(signedIn ? token : null)),
        cloudEntitlementProvider.overrideWith(() => FixedEntitlement(entitlement, hang: hang)),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorKey: navKey,
        builder: (context, child) => PlayBillingNotices(navigatorKey: navKey, child: child!),
        home: detailed
            ? const CloudScreen()
            : Scaffold(
                body: ListView(
                  padding: const EdgeInsets.all(20),
                  children: const [CloudSection(surface: PlantlySurface.light)],
                ),
              ),
      ),
    ));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    return s;
  }

  group('Cloud screen states (PLAY-BILLING-CONTRACT §4)', () {
    testWidgets('Android, both flags on, not entitled → plan picker with Play prices; no web link', (tester) async {
      await pump(tester);
      expect(find.byKey(const Key('cloud-play-plans')), findsOneWidget);
      expect(find.byKey(const Key('cloud-not-included')), findsOneWidget);
      expect(find.byKey(const Key('cloud-subscribe')), findsNothing);
      expect(find.text('Subscribe in Google Play'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('9,00 RON / month'), findsOneWidget);
      expect(find.text('Yearly'), findsOneWidget);
      expect(find.text('79,00 RON / year'), findsOneWidget);
    });

    testWidgets('ro copy', (tester) async {
      await pump(tester, locale: const Locale('ro'));
      expect(find.text('Abonează-te prin Google Play'), findsOneWidget);
      expect(find.text('Lunar'), findsOneWidget);
      expect(find.text('9,00 RON / lună'), findsOneWidget);
      expect(find.text('79,00 RON / an'), findsOneWidget);
    });

    testWidgets('billing flag off → today\'s no-link policy copy, no picker', (tester) async {
      await pump(tester, playBilling: false);
      expect(find.byKey(const Key('cloud-play-plans')), findsNothing);
      expect(find.byKey(const Key('cloud-subscribe')), findsNothing);
      expect(find.byKey(const Key('cloud-not-included')), findsOneWidget);
      expect(find.text('Included with Plantly Pro or Plantly Inventory Cloud'), findsOneWidget);
    });

    testWidgets('entitled → no picker (no purchase CTA, §0)', (tester) async {
      await pump(tester, entitlement: const CloudEntitlement(active: true, source: 'pro', provider: 'stripe'));
      expect(find.byKey(const Key('cloud-play-plans')), findsNothing);
      expect(find.byKey(const Key('cloud-status')), findsOneWidget);
    });

    testWidgets('while the entitlement is still being checked → no picker', (tester) async {
      await pump(tester, hang: true);
      expect(find.byKey(const Key('cloud-play-plans')), findsNothing);
      expect(find.text('Checking your subscription…'), findsOneWidget);
    });

    testWidgets('signed out → sign-in row only', (tester) async {
      await pump(tester, signedIn: false);
      expect(find.byKey(const Key('cloud-play-plans')), findsNothing);
      expect(find.byKey(const Key('cloud-sign-in')), findsOneWidget);
    });

    testWidgets('Play unavailable → honest copy + Retry, nothing else', (tester) async {
      await pump(tester, store: _Store(available: false));
      expect(find.byKey(const Key('play-plans-unavailable')), findsOneWidget);
      expect(find.byKey(const Key('play-plans-retry')), findsOneWidget);
      expect(find.byKey(const Key('play-plan-monthly')), findsNothing);
    });

    testWidgets('tapping a plan launches the billing flow with the hashed account id and the offer token', (tester) async {
      final store = await pump(tester);
      await tester.tap(find.byKey(const Key('play-plan-yearly')));
      // Busy state spins a progress indicator, so pump frames, not settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final p = store.params.single as GooglePlayPurchaseParam;
      expect(p.offerToken, 'y');
      expect(p.applicationUserName, hasLength(64));
      expect(p.applicationUserName, isNot(contains('u-')));
      // Busy until Play answers: both cards show "Activating…" and are inert.
      expect(find.text('Activating…'), findsNWidgets(2));
      await tester.tap(find.byKey(const Key('play-plan-monthly')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(store.params, hasLength(1));
    });

    testWidgets('entitled via Play (detailed) → "Manage in Google Play" row + via-Play plan copy', (tester) async {
      await pump(
        tester,
        detailed: true,
        entitlement: CloudEntitlement(
          active: true,
          source: 'inventory_cloud',
          provider: 'play',
          currentPeriodEnd: DateTime.utc(2026, 11, 3),
        ),
      );
      expect(find.byKey(const Key('cloud-manage-play')), findsOneWidget);
      expect(find.text('Manage subscription in Google Play'), findsOneWidget);
      expect(find.textContaining('via Google Play'), findsOneWidget);
      expect(find.byKey(const Key('cloud-play-plans')), findsNothing);
    });

    testWidgets('entitled via Stripe (detailed) → existing copy, no Play row', (tester) async {
      await pump(
        tester,
        detailed: true,
        entitlement: const CloudEntitlement(active: true, source: 'inventory_cloud', provider: 'stripe'),
      );
      expect(find.byKey(const Key('cloud-manage-play')), findsNothing);
      expect(find.text('Plantly Inventory Cloud'), findsOneWidget);
    });

    testWidgets('entitled, provider absent (older server) → treated as Stripe', (tester) async {
      await pump(tester, detailed: true, entitlement: const CloudEntitlement(active: true, source: 'inventory_cloud'));
      expect(find.byKey(const Key('cloud-manage-play')), findsNothing);
    });
  });

  group('PlayBillingNotices', () {
    testWidgets('already entitled → the §4 sheet (ro), dismissable', (tester) async {
      await pump(tester, locale: const Locale('ro'), entitlement: const CloudEntitlement(active: true, source: 'pro'));
      // Simulate a buy that the local re-check refuses: outcome alreadyEntitled.
      final element = tester.element(find.byType(PlayBillingNotices));
      final service = ProviderScope.containerOf(element).read(playBillingServiceProvider);
      await service.loadPlans();
      await tester.pump();
      await service.buy(service.state.plans.first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('play-already-entitled-sheet')), findsOneWidget);
      expect(find.text('Ai deja Inventory Cloud'), findsOneWidget);
      expect(
        find.text('Ai deja Inventory Cloud (inclus în Plantly Pro / abonament web). Achiziția din Google Play nu a fost '
            'activată și va fi rambursată automat de Google în 3 zile.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('play-already-entitled-ok')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('play-already-entitled-sheet')), findsNothing);
    });

    testWidgets('en sheet copy', (tester) async {
      await pump(tester, entitlement: const CloudEntitlement(active: true, source: 'pro'));
      final element = tester.element(find.byType(PlayBillingNotices));
      final service = ProviderScope.containerOf(element).read(playBillingServiceProvider);
      await service.loadPlans();
      await tester.pump();
      await service.buy(service.state.plans.first);
      await tester.pumpAndSettle();
      expect(find.text('You already have Inventory Cloud'), findsOneWidget);
    });
  });
}
