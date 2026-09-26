import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
}
