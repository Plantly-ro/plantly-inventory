import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plantly_inventory/app/side_sheet.dart';
import 'package:plantly_inventory/config/plantly_features.dart';
import 'package:plantly_inventory/config/plantly_hosts.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/marketplace/plantly_api.dart';
import 'package:plantly_inventory/marketplace/plantly_auth.dart';
import 'package:plantly_inventory/marketplace/session_store.dart';
import 'package:plantly_inventory/plugins/plantly_ro/login_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_app.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('OAuth start URLs (CLOUD-SYNC-CONTRACT §2.4)', () {
    expect(PlantlyHosts.oauthStartUrl('google', origin: 'https://dev.example'),
        'https://dev.example/api/v1/auth/oauth/google/start?client=inventory');
    expect(PlantlyHosts.oauthStartUrl('facebook'), '${PlantlyHosts.host}/api/v1/auth/oauth/facebook/start?client=inventory');
    expect(PlantlyHosts.subscriptionUrl(), '${PlantlyHosts.host}/account/subscription?product=inventory_cloud');
  });

  Future<void> pump(
    WidgetTester tester,
    Locale locale, {
    LoginPurpose purpose = LoginPurpose.sell,
    bool? facebook,
  }) async {
    tester.view.physicalSize = const Size(420, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = PlantlyApi(client: MockClient((_) async => http.Response('{}', 503)), host: 'https://dev.example');
    final auth = PlantlyAuth(api: api, store: InMemorySessionStore(), autoLoad: false);
    await tester.pumpWidget(buildTestApp(
      overrides: [if (facebook != null) facebookLoginEnabledProvider.overrideWithValue(facebook)],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: PlantlyLoginSheet(auth: auth, host: 'https://dev.example', purpose: purpose)),
      ),
    ));
    await tester.pumpAndSettle();
  }

  test('PLANTLY_FACEBOOK_LOGIN_ENABLED defaults to off', () {
    expect(PlantlyFeatures.facebookLoginEnabled, isFalse);
  });

  testWidgets('default: renders Google (no Facebook) above the email form (en)', (tester) async {
    await pump(tester, const Locale('en'));
    expect(find.byKey(const Key('plantly-login-google')), findsOneWidget);
    expect(find.byKey(const Key('plantly-login-facebook')), findsNothing);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Facebook'), findsNothing);
    expect(find.text('or'), findsOneWidget);
    // Email + password stay.
    expect(find.byKey(const Key('plantly-login-email')), findsOneWidget);
    expect(find.byKey(const Key('plantly-login-password')), findsOneWidget);
    expect(find.byKey(const Key('plantly-login-submit')), findsOneWidget);
    expect(find.byKey(const Key('plantly-login-oauth-waiting')), findsNothing);
    // The show/hide eye is named and flips its name.
    expect(find.byTooltip('Show password'), findsOneWidget);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(find.byTooltip('Hide password'), findsOneWidget);
    final google = tester.getTopLeft(find.byKey(const Key('plantly-login-google')));
    final email = tester.getTopLeft(find.byKey(const Key('plantly-login-email')));
    expect(google.dy, lessThan(email.dy));
    // With Facebook gone the "or" divider sits right under Google (14px gap),
    // no orphaned 8px spacer.
    final googleBottom = tester.getBottomLeft(find.byKey(const Key('plantly-login-google'))).dy;
    final orTop = tester.getTopLeft(find.text('or')).dy;
    expect(orTop - googleBottom, lessThan(30));
  });

  testWidgets('PLANTLY_FACEBOOK_LOGIN_ENABLED on: Google + Facebook, Facebook between Google and the divider',
      (tester) async {
    await pump(tester, const Locale('en'), facebook: true);
    expect(find.byKey(const Key('plantly-login-google')), findsOneWidget);
    expect(find.byKey(const Key('plantly-login-facebook')), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Facebook'), findsOneWidget);
    expect(find.text('or'), findsOneWidget);
    final google = tester.getTopLeft(find.byKey(const Key('plantly-login-google')));
    final facebook = tester.getTopLeft(find.byKey(const Key('plantly-login-facebook')));
    final email = tester.getTopLeft(find.byKey(const Key('plantly-login-email')));
    expect(google.dy, lessThan(facebook.dy));
    expect(facebook.dy, lessThan(email.dy));
  });

  testWidgets('PLANTLY_FACEBOOK_LOGIN_ENABLED explicitly off: same as default', (tester) async {
    await pump(tester, const Locale('en'), facebook: false);
    expect(find.byKey(const Key('plantly-login-google')), findsOneWidget);
    expect(find.byKey(const Key('plantly-login-facebook')), findsNothing);
  });

  testWidgets('ro copy with diacritics (default: no Facebook)', (tester) async {
    await pump(tester, const Locale('ro'));
    expect(find.text('Continuă cu Google'), findsOneWidget);
    expect(find.text('Continuă cu Facebook'), findsNothing);
    expect(find.text('sau'), findsOneWidget);
  });

  testWidgets('ro copy with diacritics (flag on)', (tester) async {
    await pump(tester, const Locale('ro'), facebook: true);
    expect(find.text('Continuă cu Google'), findsOneWidget);
    expect(find.text('Continuă cu Facebook'), findsOneWidget);
  });

  group('subtitle follows the purpose', () {
    testWidgets('sell (default) keeps the listing copy', (tester) async {
      await pump(tester, const Locale('en'));
      expect(find.byKey(const Key('plantly-login-subtitle')), findsOneWidget);
      expect(find.text('Use your plantly.ro account to post listings.'), findsOneWidget);
      expect(find.text('Use your plantly.ro account for cloud backup & sync.'), findsNothing);
    });

    testWidgets('cloud (en)', (tester) async {
      await pump(tester, const Locale('en'), purpose: LoginPurpose.cloud);
      expect(find.text('Use your plantly.ro account for cloud backup & sync.'), findsOneWidget);
      expect(find.text('Use your plantly.ro account to post listings.'), findsNothing);
    });

    testWidgets('cloud (ro)', (tester) async {
      await pump(tester, const Locale('ro'), purpose: LoginPurpose.cloud);
      expect(find.text('Folosește contul tău plantly.ro pentru backup și sincronizare în cloud.'), findsOneWidget);
    });
  });

  group('showPlantlyLoginSheet is adaptive (bottom sheet ↔ side sheet)', () {
    Future<void> open(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = PlantlyApi(client: MockClient((_) async => http.Response('{}', 503)), host: 'https://dev.example');
      final auth = PlantlyAuth(api: api, store: InMemorySessionStore(), autoLoad: false);
      await tester.pumpWidget(buildTestApp(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                key: const Key('open'),
                onPressed: () => showPlantlyLoginSheet(ctx, auth: auth, host: 'https://dev.example'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
    }

    testWidgets('phone: modal bottom sheet, in-body title', (tester) async {
      await open(tester, const Size(420, 1200));
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(SideSheetPanel), findsNothing);
      expect(find.byType(PlantlyLoginSheet), findsOneWidget);
      expect(find.text('Sign in to plantly.ro'), findsOneWidget);
      expect(find.byKey(const Key('plantly-login-google')), findsOneWidget);
      expect(find.byKey(const Key('plantly-login-submit')), findsOneWidget);
      // Title is a heading; an explicit Close closes the sheet.
      final semantics = tester.ensureSemantics();
      expect(tester.getSemantics(find.text('Sign in to plantly.ro')), isSemantics(label: 'Sign in to plantly.ro', isHeader: true));
      semantics.dispose();
      await tester.tap(find.byKey(const Key('plantly-login-close')));
      await tester.pumpAndSettle();
      expect(find.byType(PlantlyLoginSheet), findsNothing);
    });

    testWidgets('desktop: right-side sheet, title in the chrome header only', (tester) async {
      await open(tester, const Size(1440, 900));
      expect(find.byType(SideSheetPanel), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(PlantlyLoginSheet), findsOneWidget);
      expect(find.text('Sign in to plantly.ro'), findsOneWidget); // header, not duplicated in the body
      expect(find.byKey(const Key('plantly-login-close')), findsNothing, reason: 'the chrome header has the ×');
      expect(find.byKey(const Key('plantly-login-google')), findsOneWidget);
      expect(find.byKey(const Key('plantly-login-submit')), findsOneWidget);
      // Panel hugs the right edge at the desktop side-sheet width.
      final panel = tester.getRect(find.byType(SideSheetPanel));
      expect(panel.right, 1440);
      // Close via the chrome `×`.
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(PlantlyLoginSheet), findsNothing);
    });
  });
}
