import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plantly_inventory/app/side_sheet.dart';
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

  Future<void> pump(WidgetTester tester, Locale locale) async {
    tester.view.physicalSize = const Size(420, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = PlantlyApi(client: MockClient((_) async => http.Response('{}', 503)), host: 'https://dev.example');
    final auth = PlantlyAuth(api: api, store: InMemorySessionStore(), autoLoad: false);
    await tester.pumpWidget(buildTestApp(
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: PlantlyLoginSheet(auth: auth, host: 'https://dev.example')),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('renders Google + Facebook buttons above the email form (en)', (tester) async {
    await pump(tester, const Locale('en'));
    expect(find.byKey(const Key('plantly-login-google')), findsOneWidget);
    expect(find.byKey(const Key('plantly-login-facebook')), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Facebook'), findsOneWidget);
    expect(find.text('or'), findsOneWidget);
    // Email + password stay.
    expect(find.byKey(const Key('plantly-login-email')), findsOneWidget);
    expect(find.byKey(const Key('plantly-login-password')), findsOneWidget);
    expect(find.byKey(const Key('plantly-login-submit')), findsOneWidget);
    expect(find.byKey(const Key('plantly-login-oauth-waiting')), findsNothing);
    final google = tester.getTopLeft(find.byKey(const Key('plantly-login-google')));
    final email = tester.getTopLeft(find.byKey(const Key('plantly-login-email')));
    expect(google.dy, lessThan(email.dy));
  });

  testWidgets('ro copy with diacritics', (tester) async {
    await pump(tester, const Locale('ro'));
    expect(find.text('Continuă cu Google'), findsOneWidget);
    expect(find.text('Continuă cu Facebook'), findsOneWidget);
    expect(find.text('sau'), findsOneWidget);
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
    });

    testWidgets('desktop: right-side sheet, title in the chrome header only', (tester) async {
      await open(tester, const Size(1440, 900));
      expect(find.byType(SideSheetPanel), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(PlantlyLoginSheet), findsOneWidget);
      expect(find.text('Sign in to plantly.ro'), findsOneWidget); // header, not duplicated in the body
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
