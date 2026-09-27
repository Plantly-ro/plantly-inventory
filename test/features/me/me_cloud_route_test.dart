import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:plantly_inventory/app/master_detail.dart';
import 'package:plantly_inventory/app/navigation.dart';
import 'package:plantly_inventory/config/plantly_features.dart';
import 'package:plantly_inventory/features/home/home_screen.dart';
import 'package:plantly_inventory/features/me/cloud_screen.dart';
import 'package:plantly_inventory/features/me/me_screen.dart';
import 'package:plantly_inventory/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';

/// `/me/cloud` is a real Me section (phone: pushed page; desktop: detail
/// pane next to the Me master list) and `/auth/callback` never 404s.
void main() {
  const phone = Size(430, 1000);
  const desktop = Size(1440, 900);

  Future<void> pumpApp(WidgetTester tester, Size size, {required String location, bool cloud = true}) async {
    SharedPreferences.setMockInitialValues({'plantly_onboarded': true});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))));
    await tester.pumpWidget(buildTestApp(
      overrides: [cloudEnabledProvider.overrideWithValue(cloud)],
      child: PlantlyApp(initialLocation: location),
    ));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  String currentPath(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(Scaffold).first)).routerDelegate.currentConfiguration.uri.path;

  test('cloud is a routed Me section', () {
    expect(AppRoutes.meSections, contains('cloud'));
    expect(meSectionScreen('cloud'), isA<CloudScreen>());
    expect(AppRoutes.meSection('cloud'), '/me/cloud');
  });

  testWidgets('phone /me/cloud renders CloudScreen', (tester) async {
    await pumpApp(tester, phone, location: '/me/cloud');
    expect(find.byType(CloudScreen), findsOneWidget);
    expect(find.byKey(const Key('cloud-screen-intro')), findsOneWidget);
    expect(find.byType(MeMasterDetail), findsNothing);
    expect(currentPath(tester), '/me/cloud');
  });

  testWidgets('phone: Me list shows the Cloud section; its title goes to /me/cloud', (tester) async {
    await pumpApp(tester, phone, location: '/me');
    expect(find.byKey(const Key('me-cloud-section')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('cloud-section-title')));
    await tester.tap(find.byKey(const Key('cloud-section-title')));
    await tester.pumpAndSettle();
    expect(find.byType(CloudScreen), findsOneWidget);
    // Phone pushes (go_router `push`); the URL reflects `go` only, so the
    // address bar stays `/me` here exactly as for every other pushed section.
    expect(find.byType(MeMasterDetail), findsNothing);
  });

  testWidgets('phone: flag off → no Cloud section, /me/cloud still resolves', (tester) async {
    await pumpApp(tester, phone, location: '/me', cloud: false);
    expect(find.byKey(const Key('me-cloud-section')), findsNothing);
  });

  testWidgets('desktop /me/cloud = Me master list + CloudScreen detail', (tester) async {
    await pumpApp(tester, desktop, location: '/me/cloud');
    expect(find.byType(MeMasterDetail), findsOneWidget);
    expect(find.byType(MeScreen), findsOneWidget);
    expect(find.byKey(const Key('me-cloud-section')), findsOneWidget); // in the master list
    expect(find.byType(CloudScreen), findsOneWidget);
    expect(currentPath(tester), '/me/cloud');
  });

  testWidgets('desktop: Cloud title in the master list selects /me/cloud in place', (tester) async {
    await pumpApp(tester, desktop, location: '/me');
    expect(find.byType(CloudScreen), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('cloud-section-title')));
    await tester.tap(find.byKey(const Key('cloud-section-title')));
    await tester.pumpAndSettle();
    expect(find.byType(MeMasterDetail), findsOneWidget);
    expect(find.byType(CloudScreen), findsOneWidget);
    expect(currentPath(tester), '/me/cloud');
  });

  testWidgets('/auth/callback?token= redirects home instead of 404-ing', (tester) async {
    await pumpApp(tester, phone, location: '/auth/callback?token=aaa.bbb.ccc&nonce=abcdefghijklmnop0123456789');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.textContaining('Page Not Found'), findsNothing);
    expect(currentPath(tester), '/');
  });
}
