// WebAccessGate (WEB-ACCESS-POLICY §0): the three states' copy and
// controls, RO + EN, prices from /subscriptions/plans with the EUR fallback,
// the Play badge per locale, retry → re-fetch, sign-out from state 2.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plantly_inventory/cloud/entitlement.dart';
import 'package:plantly_inventory/cloud/local_data_wipe.dart';
import 'package:plantly_inventory/cloud/web_access.dart';
import 'package:plantly_inventory/config/plantly_features.dart';
import 'package:plantly_inventory/features/gate/web_access_gate.dart';
import 'package:plantly_inventory/features/gate/web_offline_banner.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/marketplace/plantly_auth.dart';
import 'package:plantly_inventory/marketplace/session_store.dart';
import 'package:plantly_inventory/plugins/plantly_ro/login_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../cloud/cloud_state_test.dart' show FixedEntitlement;
import '../../helpers/test_app.dart';
import '../../marketplace/plantly_session_test.dart' show fakeJwt;

void main() {
  final nowSecs = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  final token = fakeJwt(iat: nowSecs, exp: nowSecs + 86400);

  late int plansHits;
  late int meHits;
  late bool plansFail;

  setUp(() {
    SharedPreferences.setMockInitialValues({'plantly_onboarded': true});
    plansHits = 0;
    meHits = 0;
    plansFail = false;
  });

  http.Response jsonRes(Object body, [int status = 200]) =>
      http.Response(json.encode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

  MockClient client() => MockClient((req) async {
        final path = req.url.path;
        if (path.endsWith('/subscriptions/plans')) {
          plansHits++;
          expect(req.url.queryParameters['product'], 'inventory_cloud');
          if (plansFail) return jsonRes({'error': 'down'}, 503);
          return jsonRes({
            'product': 'inventory_cloud',
            'plans': [
              {'interval': 'month', 'amount_minor': 199, 'currency': 'eur', 'prices': {'eur': 199, 'ron': 900, 'usd': 199}},
              {'interval': 'year', 'amount_minor': 1799, 'currency': 'eur', 'prices': {'eur': 1799, 'ron': 7900, 'usd': 1799}},
            ],
          });
        }
        if (path.endsWith('/subscriptions/me')) {
          meHits++;
          return jsonRes({
            'entitlements': {
              'inventory_cloud': {'active': false, 'source': null},
            },
          });
        }
        return jsonRes({'error': 'unexpected $path'}, 404);
      });

  Future<void> pump(
    WidgetTester tester, {
    required WebAccess access,
    Locale locale = const Locale('ro'),
    String? storedToken,
    bool settle = true,
    Size size = const Size(480, 1400),
    List<Override> extra = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(buildTestApp(
      overrides: [
        webPlatformProvider.overrideWithValue(true),
        webAccessProvider.overrideWithValue(access),
        httpClientProvider.overrideWith((_) => client()),
        sessionStoreProvider.overrideWith((_) => InMemorySessionStore(storedToken)),
        ...extra,
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const WebAccessGate(),
      ),
    ));
    // The open/checking state spins indefinitely — settling never ends there.
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  String badgeAsset(WidgetTester tester) {
    final image = tester.widget<Image>(find.descendant(
      of: find.byKey(const Key('gate-play-badge')),
      matching: find.byType(Image),
    ));
    return (image.image as AssetImage).assetName;
  }

  group('state 1 — signed out', () {
    testWidgets('RO: headline, value prop, sign-in, Android card with RO badge', (tester) async {
      await pump(tester, access: WebAccess.closedSignedOut);
      expect(find.byKey(const Key('gate-signed-out')), findsOneWidget);
      expect(find.text('Colecția ta, sincronizată peste tot'), findsOneWidget);
      expect(find.byKey(const Key('gate-sign-in')), findsOneWidget);
      expect(find.text('Intră în cont'), findsOneWidget);
      expect(find.text('Preferi telefonul?'), findsOneWidget);
      expect(find.text('Aplicația Android este gratuită și merge offline.'), findsOneWidget);
      expect(find.text('Abonează-te la Inventory Cloud și totul se sincronizează între telefon și web.'), findsOneWidget);
      expect(badgeAsset(tester), 'assets/badges/ro_badge_web_generic.png');
      // Nothing from state 2 leaks in.
      expect(find.byKey(const Key('gate-subscribe')), findsNothing);
      expect(find.byKey(const Key('gate-sign-out')), findsNothing);
      expect(plansHits, 0);
    });

    testWidgets('EN copy + EN badge', (tester) async {
      await pump(tester, access: WebAccess.closedSignedOut, locale: const Locale('en'));
      expect(find.text('Your collection, in sync everywhere'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Prefer your phone?'), findsOneWidget);
      expect(badgeAsset(tester), 'assets/badges/en_badge_web_generic.png');
    });

    testWidgets('Sign in opens the plantly.ro login sheet (cloud purpose)', (tester) async {
      await pump(tester, access: WebAccess.closedSignedOut);
      await tester.tap(find.byKey(const Key('gate-sign-in')));
      await tester.pumpAndSettle();
      expect(find.byType(PlantlyLoginSheet), findsOneWidget);
      expect(tester.widget<PlantlyLoginSheet>(find.byType(PlantlyLoginSheet)).purpose, LoginPurpose.cloud);
    });
  });

  group('state 2 via the real verdict (MULTI-USER-V2 §8)', () {
    testWidgets('own inactive + shared_access.active → state 2 with prices, Pro note, subscribe', (tester) async {
      tester.view.physicalSize = const Size(480, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(buildTestApp(
        overrides: [
          webPlatformProvider.overrideWithValue(true),
          httpClientProvider.overrideWith((_) => client()),
          sessionStoreProvider.overrideWith((_) => InMemorySessionStore(token)),
          cloudEntitlementProvider.overrideWith(() => FixedEntitlement(
              const CloudEntitlement(active: false, sharedAccess: SharedAccess(active: true, collections: 2)))),
        ],
        child: MaterialApp(
          locale: const Locale('ro'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const WebAccessGate(),
        ),
      ));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.byType(WebAccessGate)));
      await tester.runAsync(() => container.read(plantlyAuthProvider.notifier).current());
      await tester.pumpAndSettle();
      expect(container.read(webAccessProvider), WebAccess.closedNotEntitled('alice'));
      expect(find.byKey(const Key('gate-not-entitled')), findsOneWidget);
      expect(find.byKey(const Key('gate-signed-out')), findsNothing);
      final plans = tester.widget<Text>(find.byKey(const Key('gate-plans'))).data!;
      expect(plans, contains('/lună'));
      expect(plans, contains('RON'));
      expect(find.text('Inclus în Plantly Pro.'), findsOneWidget);
      expect(find.byKey(const Key('gate-subscribe')), findsOneWidget);
      expect(find.textContaining('colecția partajată'), findsNothing, reason: 'no shared-access copy anywhere');
    });
  });

  group('state 2 — signed in, not entitled', () {
    testWidgets('RO: greeting, RON prices, subscribe, retry, Pro note, data-kept, Android card, sign-out', (tester) async {
      await pump(tester, access: WebAccess.closedNotEntitled('alice'), storedToken: token);
      expect(find.byKey(const Key('gate-not-entitled')), findsOneWidget);
      expect(find.text('Bună, alice. Versiunea web este inclusă în Inventory Cloud.'), findsOneWidget);
      expect(plansHits, 1);
      final plans = tester.widget<Text>(find.byKey(const Key('gate-plans'))).data!;
      expect(plans, contains('/lună'));
      expect(plans, contains('/an'));
      expect(plans, contains('sau'));
      expect(plans, contains('RON'), reason: 'Romanian UI → RON from the per-currency map');
      expect(plans, isNot(contains('€')));
      expect(find.text('Abonează-te pe plantly.ro'), findsOneWidget);
      expect(find.text('Am deja abonament — reîncearcă'), findsOneWidget);
      expect(find.text('Inclus în Plantly Pro.'), findsOneWidget);
      expect(find.byKey(const Key('gate-data-kept')), findsOneWidget);
      expect(find.byKey(const Key('gate-android-card')), findsOneWidget);
      expect(find.text('Nu ești tu? Deconectează-te'), findsOneWidget);
      expect(find.byKey(const Key('gate-sign-in')), findsNothing);
    });

    testWidgets('RO at 375×667 (small phone): nothing overflows, CTA label fully laid out', (tester) async {
      await pump(tester, access: WebAccess.closedNotEntitled('alice'), storedToken: token, size: const Size(375, 667));
      expect(tester.takeException(), isNull, reason: 'a RenderFlex overflow would surface here');
      expect(find.byKey(const Key('gate-not-entitled')), findsOneWidget);

      final button = find.byKey(const Key('gate-subscribe'));
      final label = find.descendant(of: button, matching: find.text('Abonează-te pe plantly.ro'));
      expect(label, findsOneWidget);
      final buttonBox = tester.getRect(button);
      final labelBox = tester.getRect(label);
      expect(labelBox.right, lessThan(buttonBox.right - 8), reason: 'label must not touch the button edge');
      expect(labelBox.left, greaterThan(buttonBox.left + 8));
      expect(tester.renderObject<RenderParagraph>(label).didExceedMaxLines, isFalse);
      // Same-tab navigation glyph, not "opens in a new window".
      expect(find.descendant(of: button, matching: find.byIcon(Icons.arrow_forward)), findsOneWidget);
      expect(find.descendant(of: button, matching: find.byIcon(Icons.open_in_new)), findsNothing);
      // The whole page (incl. the Android card) is reachable by scrolling.
      await tester.scrollUntilVisible(find.byKey(const Key('gate-sign-out')), 200);
      expect(tester.takeException(), isNull);
    });

    testWidgets('EN: EUR prices', (tester) async {
      await pump(tester, access: WebAccess.closedNotEntitled('alice'), locale: const Locale('en'), storedToken: token);
      expect(find.text('Hi, alice. The web version is included in Inventory Cloud.'), findsOneWidget);
      final plans = tester.widget<Text>(find.byKey(const Key('gate-plans'))).data!;
      expect(plans, contains('1.99'));
      expect(plans, contains('/month'));
      expect(plans, contains('17.99'));
      expect(plans, contains('/year'));
      expect(find.text('Subscribe on plantly.ro'), findsOneWidget);
      expect(find.text('Included in Plantly Pro.'), findsOneWidget);
    });

    testWidgets('plans endpoint down → fixed EUR copy', (tester) async {
      plansFail = true;
      await pump(tester, access: WebAccess.closedNotEntitled('alice'), storedToken: token);
      expect(find.byKey(const Key('gate-plans-fallback')), findsOneWidget);
      expect(find.text('1,99 €/lună sau 17,99 €/an'), findsOneWidget);
      expect(find.byKey(const Key('gate-subscribe')), findsOneWidget, reason: 'CTA does not depend on prices');
    });

    testWidgets('"check again" re-fetches the entitlement', (tester) async {
      await pump(tester, access: WebAccess.closedNotEntitled('alice'), storedToken: token);
      // Settle the session so the notifier has a user to ask about.
      final container = ProviderScope.containerOf(tester.element(find.byType(WebAccessGate)));
      await tester.runAsync(() => container.read(plantlyAuthProvider.notifier).current());
      await tester.pumpAndSettle();
      final before = meHits;
      await tester.tap(find.byKey(const Key('gate-retry')));
      await tester.pumpAndSettle();
      expect(meHits, greaterThan(before));
    });

    testWidgets('sign-out link → confirm → session cleared', (tester) async {
      await pump(tester, access: WebAccess.closedNotEntitled('alice'), storedToken: token);
      final container = ProviderScope.containerOf(tester.element(find.byType(WebAccessGate)));
      await tester.runAsync(() => container.read(plantlyAuthProvider.notifier).current());
      await tester.pumpAndSettle();
      expect(container.read(plantlyAuthProvider).valueOrNull, isNotNull);

      await tester.ensureVisible(find.byKey(const Key('gate-sign-out')));
      await tester.tap(find.byKey(const Key('gate-sign-out')));
      await tester.pumpAndSettle();
      expect(find.text('Te deconectezi de la plantly.ro?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('gate-sign-out-confirm')));
      await tester.pumpAndSettle();
      expect(container.read(plantlyAuthProvider).valueOrNull, isNull);
    });
  });

  group('held by another account (shared computer)', () {
    testWidgets('RO: names the other account, no way in but "clear" or sign out; clear wipes + reloads', (tester) async {
      final wiper = _CountingWiper();
      await pump(
        tester,
        access: WebAccess.closedHeldByOther('alice', 'bob'),
        storedToken: token,
        extra: [localDataWiperProvider.overrideWith((ref) => wiper)],
      );
      expect(find.byKey(const Key('gate-held-by-other')), findsOneWidget);
      expect(find.text('Acest browser conține încă plantele lui bob'), findsOneWidget);
      expect(find.textContaining('Ești conectat ca alice.'), findsOneWidget);
      expect(find.byKey(const Key('gate-subscribe')), findsNothing);
      expect(find.byKey(const Key('gate-sign-out')), findsOneWidget);

      await tester.tap(find.byKey(const Key('gate-clear-local')));
      await tester.pump();
      expect(wiper.calls, 1);
      // Busy: a second tap does nothing.
      await tester.tap(find.byKey(const Key('gate-clear-local')), warnIfMissed: false);
      await tester.pump();
      expect(wiper.calls, 1);
    });

    testWidgets('explicit sign-out: flush, then a second confirm when changes would be lost', (tester) async {
      final wiper = _CountingWiper()..pending = 2;
      await pump(
        tester,
        access: WebAccess.closedNotEntitled('alice'),
        locale: const Locale('en'),
        storedToken: token,
        extra: [localDataWiperProvider.overrideWith((ref) => wiper)],
      );
      Future<void> startSignOut() async {
        await tester.ensureVisible(find.byKey(const Key('gate-sign-out')));
        await tester.tap(find.byKey(const Key('gate-sign-out')));
        await tester.pumpAndSettle();
        expect(find.textContaining("this browser's copy of the collection is removed"), findsOneWidget);
        await tester.tap(find.byKey(const Key('gate-sign-out-confirm')));
        await tester.pumpAndSettle();
      }

      await startSignOut();
      expect(find.text("2 changes haven't reached the cloud yet. Sign out anyway? They will be lost."), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(wiper.signOuts, 0, reason: 'backing out keeps the session and the data');

      await startSignOut();
      await tester.tap(find.byKey(const Key('sign-out-anyway')));
      await tester.pumpAndSettle();
      expect(wiper.signOuts, 1);

      wiper.pending = 0;
      await startSignOut();
      expect(find.byKey(const Key('sign-out-unsynced')), findsNothing, reason: 'all synced: no second question');
      expect(wiper.signOuts, 2);
    });

    testWidgets('EN copy', (tester) async {
      await pump(tester, access: WebAccess.closedHeldByOther('alice', 'bob'), locale: const Locale('en'), storedToken: token);
      expect(find.text("This browser still holds bob's plants"), findsOneWidget);
      expect(find.text('Clear this browser and continue'), findsOneWidget);
    });
  });

  group('unreachable variant', () {
    testWidgets('offline, nothing usable cached → retry, no plan summary', (tester) async {
      await pump(tester, access: WebAccess.closedUnreachable('alice'), storedToken: token);
      expect(find.byKey(const Key('gate-unreachable')), findsOneWidget);
      expect(find.text('Nu putem verifica abonamentul'), findsOneWidget);
      expect(find.text('Reîncearcă'), findsOneWidget);
      expect(find.byKey(const Key('gate-subscribe')), findsNothing);
      expect(find.byKey(const Key('gate-sign-out')), findsOneWidget);
      expect(plansHits, 0);
    });
  });

  group('state 3 — open', () {
    testWidgets('the gate itself only shows a spinner (the router moves on)', (tester) async {
      await pump(tester, access: WebAccess.open, settle: false);
      expect(find.byKey(const Key('gate-checking')), findsOneWidget);
      expect(find.byKey(const Key('gate-sign-in')), findsNothing);
    });

    testWidgets('offline banner renders only for open(offline)', (tester) async {
      Future<void> pumpBanner(WebAccess access) async {
        await tester.pumpWidget(buildTestApp(
          overrides: [webAccessProvider.overrideWithValue(access)],
          child: MaterialApp(
            locale: const Locale('ro'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const WebOfflineBanner(child: Scaffold(body: Text('app'))),
          ),
        ));
        await tester.pumpAndSettle();
      }

      await pumpBanner(WebAccess.open);
      expect(find.byKey(const Key('web-offline-banner')), findsNothing);
      expect(find.text('app'), findsOneWidget);

      await pumpBanner(const WebAccessOpen(offline: true));
      expect(find.byKey(const Key('web-offline-banner')), findsOneWidget);
      expect(find.text('Fără conexiune — modificările se vor sincroniza când revii online'), findsOneWidget);
      expect(find.text('app'), findsOneWidget);
      // Announced on appearance (a11y): the banner sits in a live region.
      final live = find.ancestor(of: find.byKey(const Key('web-offline-banner')), matching: find.byType(Semantics));
      expect(live, findsWidgets);
      expect(tester.widgetList<Semantics>(live).any((w) => w.properties.liveRegion == true), isTrue);
    });
  });
}

class _CountingWiper implements LocalDataWiper {
  int calls = 0;
  int signOuts = 0;
  int pending = 0;
  @override
  Future<void> wipeAndReload() async => calls++;
  @override
  Future<int> flush({Duration timeout = Duration.zero, Duration pause = Duration.zero}) async => pending;
  @override
  Future<int> pendingCount() async => pending;
  @override
  Future<void> signOutAndWipe() async => signOuts++;
}
