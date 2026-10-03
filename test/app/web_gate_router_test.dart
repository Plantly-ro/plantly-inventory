// Router side of the web access gate (WEB-ACCESS-POLICY §1): closed →
// `/gate` (route parked), open → the requested route, `/gate` while open →
// parked route or Home, a join link parked through the gate and replayed
// once it opens, and the gate never engaging off web.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:plantly_inventory/app/navigation.dart';
import 'package:plantly_inventory/cloud/web_access.dart';
import 'package:plantly_inventory/config/plantly_features.dart';
import 'package:plantly_inventory/features/calendar/calendar_screen.dart';
import 'package:plantly_inventory/features/collections/join_collection_sheet.dart';
import 'package:plantly_inventory/features/gate/web_access_gate.dart';
import 'package:plantly_inventory/features/home/home_screen.dart';
import 'package:plantly_inventory/handoff/incoming_links.dart';
import 'package:plantly_inventory/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_app.dart';

void main() {
  const phone = Size(430, 1000);

  /// The verdict under test; flipping it re-runs the redirect through
  /// `webAccessListenableProvider` exactly as the real derivation would.
  final fakeAccess = StateProvider<WebAccess>((_) => WebAccess.closedSignedOut);

  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    required String location,
    required WebAccess access,
    bool web = true,
    Uri? initialLink,
  }) async {
    SharedPreferences.setMockInitialValues({'plantly_onboarded': true});
    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))));
    await tester.pumpWidget(buildTestApp(
      overrides: [
        webPlatformProvider.overrideWithValue(web),
        fakeAccess.overrideWith((_) => access),
        webAccessProvider.overrideWith((ref) => ref.watch(fakeAccess)),
        if (initialLink != null) incomingLinksProvider.overrideWith((_) => FakeIncomingLinks(initialUri: initialLink)),
      ],
      child: PlantlyApp(initialLocation: location),
    ));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(PlantlyApp)));
  }

  String currentPath(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(Scaffold).first)).routerDelegate.currentConfiguration.uri.path;

  Future<void> open(WidgetTester tester, ProviderContainer c) async {
    c.read(fakeAccess.notifier).state = WebAccess.open;
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  testWidgets('closed (signed out): /calendar → /gate, route parked', (tester) async {
    final c = await pumpApp(tester, location: AppRoutes.calendar, access: WebAccess.closedSignedOut);
    expect(find.byType(WebAccessGate), findsOneWidget);
    expect(find.byKey(const Key('gate-signed-out')), findsOneWidget);
    expect(find.byType(CalendarScreen), findsNothing);
    expect(currentPath(tester), AppRoutes.gate);
    expect(c.read(webGateParkingProvider).route, AppRoutes.calendar);
  });

  testWidgets('closed (not entitled): state 2 at /gate; opening resumes the parked route', (tester) async {
    final c = await pumpApp(tester, location: '/calendar', access: WebAccess.closedNotEntitled('alice'));
    expect(find.byKey(const Key('gate-not-entitled')), findsOneWidget);
    expect(currentPath(tester), AppRoutes.gate);

    await open(tester, c);
    expect(find.byType(WebAccessGate), findsNothing);
    expect(find.byType(CalendarScreen), findsOneWidget);
    expect(currentPath(tester), AppRoutes.calendar);
    expect(c.read(webGateParkingProvider).route, isNull, reason: 'consumed');
  });

  testWidgets('closed at `/` with a query: the full location is parked and resumed', (tester) async {
    final c = await pumpApp(tester, location: '/?prefill=abc', access: WebAccess.closedSignedOut);
    expect(currentPath(tester), AppRoutes.gate);
    expect(c.read(webGateParkingProvider).route, '/?prefill=abc');
    await open(tester, c);
    expect(find.byType(HomeScreen), findsOneWidget);
    final uri = GoRouter.of(tester.element(find.byType(Scaffold).first)).routerDelegate.currentConfiguration.uri;
    expect(uri.path, AppRoutes.home);
    expect(uri.queryParameters['prefill'], 'abc');
    expect(c.read(webGateParkingProvider).route, isNull);
  });

  testWidgets('closed at Home: no route parked; opening lands on Home', (tester) async {
    final c = await pumpApp(tester, location: AppRoutes.home, access: WebAccess.closedSignedOut);
    expect(currentPath(tester), AppRoutes.gate);
    expect(c.read(webGateParkingProvider).route, isNull);
    await open(tester, c);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(currentPath(tester), AppRoutes.home);
  });

  testWidgets('open: the requested route renders, never the gate', (tester) async {
    await pumpApp(tester, location: AppRoutes.calendar, access: WebAccess.open);
    expect(find.byType(CalendarScreen), findsOneWidget);
    expect(find.byType(WebAccessGate), findsNothing);
    expect(currentPath(tester), AppRoutes.calendar);
  });

  testWidgets('open: visiting /gate by hand goes Home', (tester) async {
    await pumpApp(tester, location: AppRoutes.gate, access: WebAccess.open);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(currentPath(tester), AppRoutes.home);
  });

  testWidgets('open(offline): app renders with the banner', (tester) async {
    await pumpApp(tester, location: AppRoutes.calendar, access: const WebAccessOpen(offline: true));
    expect(find.byType(CalendarScreen), findsOneWidget);
    expect(find.byKey(const Key('web-offline-banner')), findsOneWidget);
  });

  testWidgets('a lapse while in the app closes the gate again (state 2) and keeps the session', (tester) async {
    final c = await pumpApp(tester, location: AppRoutes.calendar, access: WebAccess.open);
    expect(find.byType(CalendarScreen), findsOneWidget);
    c.read(fakeAccess.notifier).state = WebAccess.closedNotEntitled('alice');
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('gate-not-entitled')), findsOneWidget);
    expect(currentPath(tester), AppRoutes.gate);
    expect(c.read(webGateParkingProvider).route, AppRoutes.calendar, reason: 'comes back where they were');
  });

  testWidgets('join link while closed: parked (no sheet over the gate), replayed once open', (tester) async {
    final link = Uri.parse('https://inventory.plantly.ro/join?c=ABCD-EFGH');
    final c = await pumpApp(tester, location: '/join?c=ABCD-EFGH', access: WebAccess.closedSignedOut, initialLink: link);
    expect(find.byType(WebAccessGate), findsOneWidget);
    expect(find.byType(JoinCollectionSheet), findsNothing);
    expect(currentPath(tester), AppRoutes.gate);
    final parking = c.read(webGateParkingProvider);
    expect(parking.link, link.toString());
    expect(parking.route, isNull, reason: 'the link is the payload, not the route');

    await open(tester, c);
    expect(find.byType(WebAccessGate), findsNothing);
    expect(find.byType(JoinCollectionSheet), findsOneWidget);
    expect(tester.widget<JoinCollectionSheet>(find.byType(JoinCollectionSheet)).initialCode, 'ABCDEFGH');
    expect(parking.link, isNull);
  });

  testWidgets('join link while open: sheet opens straight away (unchanged behaviour)', (tester) async {
    final link = Uri.parse('https://inventory.plantly.ro/join?c=ABCD-EFGH');
    await pumpApp(tester, location: '/join?c=ABCD-EFGH', access: WebAccess.open, initialLink: link);
    expect(find.byType(JoinCollectionSheet), findsOneWidget);
    expect(find.byType(WebAccessGate), findsNothing);
  });

  testWidgets('/auth/callback while closed lands on the gate, not a 404, and is never parked', (tester) async {
    final c = await pumpApp(
      tester,
      location: '/auth/callback?token=aaa.bbb.ccc&nonce=abcdefghijklmnop0123456789',
      access: WebAccess.closedSignedOut,
    );
    expect(find.byType(WebAccessGate), findsOneWidget);
    expect(find.textContaining('Page Not Found'), findsNothing);
    expect(currentPath(tester), AppRoutes.gate);
    final parking = c.read(webGateParkingProvider);
    expect(parking.route, isNull, reason: 'a callback URL (with its token) must not be replayed as a destination');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(WebGateParking.routeKey), isNull);

    // Opening afterwards goes Home, never back to the callback URL.
    await open(tester, c);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(currentPath(tester), AppRoutes.home);
  });

  testWidgets('off web with the real derivation: no session → Home, no gate', (tester) async {
    SharedPreferences.setMockInitialValues({'plantly_onboarded': true});
    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))));
    await tester.pumpWidget(buildTestApp(
      overrides: [webPlatformProvider.overrideWithValue(false)],
      child: const PlantlyApp(initialLocation: AppRoutes.calendar),
    ));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarScreen), findsOneWidget);
    expect(find.byType(WebAccessGate), findsNothing);
    expect(currentPath(tester), AppRoutes.calendar);
  });
}
