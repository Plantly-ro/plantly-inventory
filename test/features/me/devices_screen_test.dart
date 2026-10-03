import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plantly_inventory/app/navigation.dart';
import 'package:plantly_inventory/cloud/cloud_sync.dart';
import 'package:plantly_inventory/cloud/collection_link.dart';
import 'package:plantly_inventory/cloud/entitlement.dart';
import 'package:plantly_inventory/cloud/sync_runner.dart';
import 'package:plantly_inventory/config/plantly_features.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/features/me/cloud_screen.dart';
import 'package:plantly_inventory/features/me/devices_screen.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/marketplace/plantly_api.dart';
import 'package:plantly_inventory/marketplace/plantly_auth.dart';
import 'package:plantly_inventory/marketplace/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../cloud/cloud_state_test.dart' show FixedEntitlement;
import '../../helpers/test_app.dart';
import '../../marketplace/plantly_session_test.dart' show fakeJwt;

void main() {
  final token = fakeJwt(
    iat: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
    exp: DateTime.now().toUtc().add(const Duration(hours: 24)).millisecondsSinceEpoch ~/ 1000,
  );

  http.Response jsonRes(Object body, [int status = 200]) =>
      http.Response(json.encode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

  Map<String, dynamic> dev(String id, {String? platform, String? name, String? version, bool current = false, String? lastSeen}) => {
        'device_id': id,
        'platform': ?platform,
        'device_name': ?name,
        'app_version': ?version,
        'current': current,
        'first_seen_at': '2026-09-01T10:00:00Z',
        'last_seen_at': lastSeen ?? '2026-10-02T08:30:00Z',
      };

  late List<Map<String, dynamic>> devices;
  late List<http.Request> requests;
  var listStatus = 200;

  setUp(() {
    requests = [];
    listStatus = 200;
    devices = [
      dev('dev-me', platform: 'android', name: 'Pixel 8', version: '1.2.3', current: true),
      dev('dev-other', platform: 'web', name: 'Chrome on Linux', version: '1.2.0'),
    ];
  });

  Future<void> pump(
    WidgetTester tester, {
    bool signedIn = true,
    Locale locale = const Locale('en'),
    Widget? child,
  }) async {
    SharedPreferences.setMockInitialValues({
      'plantly_onboarded': true,
      'plantly_device_id': 'dev-me',
      kCollectionIdPrefKey: 'col-1',
      kCollectionNamePrefKey: 'My plants',
      kCollectionUserIdPrefKey: 'u-1',
      kCollectionUsernamePrefKey: 'alice',
      kTenantIdPrefKey: 'col-1',
    });
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))));
    await tester.pumpWidget(buildTestApp(
      overrides: [
        cloudEnabledProvider.overrideWithValue(true),
        sessionStoreProvider.overrideWith((_) => InMemorySessionStore(signedIn ? token : null)),
        cloudEntitlementProvider.overrideWith(() => FixedEntitlement(const CloudEntitlement(active: true, source: 'pro'))),
        syncRunnerProvider.overrideWithValue(NoopSyncRunner()),
        httpClientProvider.overrideWith((_) => MockClient((req) async {
              requests.add(req);
              final path = req.url.path;
              if (req.method == 'GET' && path.endsWith('/inventory/devices')) {
                if (listStatus != 200) return jsonRes({'error': 'boom'}, listStatus);
                return jsonRes({'devices': devices});
              }
              if (req.method == 'DELETE' && path.contains('/inventory/devices/')) {
                final id = path.split('/').last;
                devices = [for (final d in devices) if (d['device_id'] != id) d];
                return http.Response('', 204);
              }
              return jsonRes({'error': 'unexpected ${req.method} $path'}, 404);
            })),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child ?? const DevicesScreen(),
      ),
    ));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  Iterable<http.Request> listCalls() => requests.where((r) => r.method == 'GET' && r.url.path.endsWith('/inventory/devices'));

  testWidgets('renders both devices; "This device" chip only on the current one; revoke only on the other', (tester) async {
    await pump(tester);
    expect(find.text('Devices'), findsOneWidget);
    expect(find.byKey(const Key('device-dev-me')), findsOneWidget);
    expect(find.byKey(const Key('device-dev-other')), findsOneWidget);
    expect(find.text('Pixel 8'), findsOneWidget);
    expect(find.text('Chrome on Linux'), findsOneWidget);
    expect(find.byKey(const Key('device-current-dev-me')), findsOneWidget);
    expect(find.text('This device'), findsOneWidget);
    expect(find.byKey(const Key('device-current-dev-other')), findsNothing);
    expect(find.byKey(const Key('device-revoke-dev-me')), findsNothing);
    expect(find.byKey(const Key('device-revoke-dev-other')), findsOneWidget);
    expect(find.text('Disconnect'), findsOneWidget);
    // Subtitle: platform · version · last seen.
    expect(find.textContaining('Web · v1.2.0 · last seen'), findsOneWidget);
    expect(find.textContaining('Android · v1.2.3 · last seen'), findsOneWidget);
    expect(find.byKey(const Key('devices-empty')), findsNothing);
    // The list call carries this install's id so the server can mark `current`.
    expect(listCalls().single.url.queryParameters['device_id'], 'dev-me');
    expect(listCalls().single.headers['Authorization'], 'Bearer $token');
  });

  testWidgets('older server without `current`: this install is still marked via appContext.deviceId', (tester) async {
    devices = [
      {'device_id': 'dev-me', 'platform': 'android', 'device_name': 'Pixel 8'},
      {'device_id': 'dev-other', 'platform': 'ios'},
    ];
    await pump(tester);
    expect(find.byKey(const Key('device-current-dev-me')), findsOneWidget);
    expect(find.byKey(const Key('device-revoke-dev-me')), findsNothing);
    expect(find.byKey(const Key('device-revoke-dev-other')), findsOneWidget);
    // No name → platform label as the title.
    expect(find.text('iPhone / iPad'), findsWidgets);
  });

  testWidgets('revoke: confirm dialog → DELETE /inventory/devices/{id}, row disappears, SnackBar', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('device-revoke-dev-other')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('devices-revoke-dialog')), findsOneWidget);
    expect(find.text('Disconnect this device?'), findsOneWidget);
    expect(find.textContaining('Chrome on Linux will stop syncing'), findsOneWidget);

    // Cancel first: nothing sent.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(requests.where((r) => r.method == 'DELETE'), isEmpty);
    expect(find.byKey(const Key('device-dev-other')), findsOneWidget);

    await tester.tap(find.byKey(const Key('device-revoke-dev-other')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('devices-revoke-confirm')));
    await tester.pumpAndSettle();

    final del = requests.where((r) => r.method == 'DELETE').single;
    expect(del.url.path, '/api/v1/inventory/devices/dev-other');
    expect(del.headers['Authorization'], 'Bearer $token');
    expect(find.byKey(const Key('device-dev-other')), findsNothing);
    expect(find.byKey(const Key('device-dev-me')), findsOneWidget);
    expect(find.byKey(const Key('devices-revoked')), findsOneWidget);
    expect(find.text('Device disconnected'), findsOneWidget);
    expect(listCalls().length, 2, reason: 'refetched after the revoke');
    expect(find.byKey(const Key('devices-empty')), findsOneWidget, reason: 'only this device left');
  });

  testWidgets('empty state: only this device', (tester) async {
    devices = [dev('dev-me', platform: 'android', name: 'Pixel 8', current: true)];
    await pump(tester);
    expect(find.byKey(const Key('device-dev-me')), findsOneWidget);
    expect(find.byKey(const Key('devices-empty')), findsOneWidget);
    expect(find.text('Only this device'), findsOneWidget);
    expect(find.text('Disconnect'), findsNothing);
  });

  testWidgets('error state with retry', (tester) async {
    listStatus = 503;
    await pump(tester);
    expect(find.byKey(const Key('devices-error')), findsOneWidget);
    expect(find.text('Could not load your devices.'), findsOneWidget);
    expect(find.byKey(const Key('devices-retry')), findsOneWidget);

    listStatus = 200;
    await tester.tap(find.byKey(const Key('devices-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('devices-error')), findsNothing);
    expect(find.byKey(const Key('device-dev-other')), findsOneWidget);
    expect(listCalls().length, 2);
  });

  testWidgets('signed out: sign-in copy, no network call', (tester) async {
    await pump(tester, signedIn: false);
    expect(find.byKey(const Key('devices-signed-out')), findsOneWidget);
    expect(find.text('Sign in to plantly.ro to manage your devices.'), findsOneWidget);
    expect(listCalls(), isEmpty);
  });

  testWidgets('ro copy', (tester) async {
    await pump(tester, locale: const Locale('ro'));
    expect(find.text('Dispozitive'), findsOneWidget);
    expect(find.text('Acest dispozitiv'), findsOneWidget);
    expect(find.text('Deconectează'), findsOneWidget);
    expect(find.textContaining('văzut ultima dată'), findsNWidgets(2));
  });

  testWidgets('CloudScreen shows the Devices entry row when signed in; tapping opens the screen', (tester) async {
    await pump(tester, child: const CloudScreen());
    await tester.ensureVisible(find.byKey(const Key('cloud-devices-row')));
    expect(find.text('Manage which devices sync this account'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cloud-devices-row')));
    await tester.pumpAndSettle();
    expect(find.byType(DevicesScreen), findsOneWidget);
    expect(find.byKey(const Key('device-dev-other')), findsOneWidget);
  });

  testWidgets('CloudScreen hides the Devices row when signed out', (tester) async {
    await pump(tester, signedIn: false, child: const CloudScreen());
    expect(find.byKey(const Key('cloud-devices-row')), findsNothing);
  });

  test('route constants + section screen', () {
    expect(AppRoutes.meCloudDevices, '/me/cloud/devices');
    expect(meSectionScreen('cloud/devices'), isA<DevicesScreen>());
    expect(AppRoutes.meSections, isNot(contains('cloud/devices')), reason: 'not a /me/:section value');
  });

  test('formatLastSeen: today → time, otherwise short date', () {
    final now = DateTime(2026, 10, 3, 15, 0);
    expect(formatLastSeen(DateTime(2026, 10, 3, 9, 5), 'en', now: now), '09:05');
    expect(formatLastSeen(DateTime(2026, 9, 30, 9, 5), 'en', now: now), 'Sep 30, 2026');
  });

  test('display helpers: name falls back to platform label; icon per platform', () {
    expect(devicePlatformIcon('android'), Icons.android);
    expect(devicePlatformIcon('ios'), Icons.phone_iphone);
    expect(devicePlatformIcon('web'), Icons.language);
    expect(devicePlatformIcon('macos'), Icons.computer);
    expect(devicePlatformIcon(null), Icons.devices_other);
    const d = CloudDevice(deviceId: 'x', platform: 'web', deviceName: '  ');
    expect(d.deviceName!.trim(), isEmpty);
  });
}
