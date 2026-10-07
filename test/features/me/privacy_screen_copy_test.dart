import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/cloud/cloud_state.dart';
import 'package:plantly_inventory/cloud/collections.dart';
import 'package:plantly_inventory/cloud/data_residency.dart';
import 'package:plantly_inventory/config/plantly_features.dart';
import 'package:plantly_inventory/features/me/cloud_screen.dart';
import 'package:plantly_inventory/features/me/privacy_screen.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';

/// Me → Privacy & data (and the Cloud intro) state what is true where the
/// collection lives: the Android app without sync, with Inventory Cloud
/// sync running, and the web app (always cloud).
void main() {
  const storageKey = ValueKey('privacy-bullet-storage');
  final syncing = <Override>[activeCollectionIdProvider.overrideWithValue('col-1')];
  final web = <Override>[webPlatformProvider.overrideWithValue(true)];
  // Linked home collection remembered (survives sign-out), nothing syncing.
  final paused = <Override>[
    cloudEnabledProvider.overrideWithValue(true),
    activeCollectionIdProvider.overrideWithValue(null),
    homeCollectionIdProvider.overrideWithValue('col-1'),
  ];
  final sell = <Override>[sellEnabledProvider.overrideWithValue(true)];

  group('dataResidencyProvider', () {
    DataResidency read(List<Override> overrides) {
      final c = ProviderContainer(overrides: overrides);
      addTearDown(c.dispose);
      return c.read(dataResidencyProvider);
    }

    test('native, cloud flag off → device only', () {
      expect(read([cloudEnabledProvider.overrideWithValue(false)]), DataResidency.deviceOnly);
    });

    test('native, no active sync collection → device only', () {
      expect(read([activeCollectionIdProvider.overrideWithValue(null)]), DataResidency.deviceOnly);
    });

    test('native, sync running → device and cloud', () {
      expect(read(syncing), DataResidency.deviceAndCloud);
    });

    test('native, remembered home collection but no sync (lapsed / signed out) → paused', () {
      expect(read(paused), DataResidency.syncPaused);
    });

    test('native, cloud flag on, never linked → device only', () {
      expect(
        read([
          cloudEnabledProvider.overrideWithValue(true),
          activeCollectionIdProvider.overrideWithValue(null),
          homeCollectionIdProvider.overrideWithValue(null),
        ]),
        DataResidency.deviceOnly,
      );
    });

    test('flag off ignores a stale link', () {
      expect(
        read([cloudEnabledProvider.overrideWithValue(false), homeCollectionIdProvider.overrideWithValue('col-1')]),
        DataResidency.deviceOnly,
      );
    });

    test('web → web, whatever the sync state', () {
      expect(read([...web, activeCollectionIdProvider.overrideWithValue(null)]), DataResidency.web);
      expect(read([...web, ...syncing]), DataResidency.web);
    });
  });

  Future<void> pump(WidgetTester tester, Widget screen,
      {List<Override> overrides = const [], Locale locale = const Locale('en')}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(buildTestApp(
      overrides: overrides,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: screen,
      ),
    ));
    await tester.pumpAndSettle();
  }

  String storage(WidgetTester tester) => tester.widget<Text>(
        find.descendant(of: find.byKey(storageKey), matching: find.byType(Text)),
      ).data!;

  group('Privacy & data', () {
    testWidgets('Android, no sync: local-only statement', (tester) async {
      await pump(tester, const PrivacyScreen(), overrides: sell);
      expect(find.text('What leaves your device'), findsOneWidget);
      expect(storage(tester), startsWith('Nothing by default.'));
      expect(storage(tester), contains('on your phone'));
      expect(storage(tester), isNot(contains('Devices list')));
      expect(find.textContaining('via the share sheet'), findsOneWidget);
      expect(find.textContaining('OS alarm system'), findsOneWidget);
      expect(find.textContaining('never the full database'), findsOneWidget);
    });

    testWidgets('Android, sync running: says it syncs to the plantly.ro account', (tester) async {
      await pump(tester, const PrivacyScreen(), overrides: [...syncing, ...sell]);
      expect(find.text('What leaves your device'), findsOneWidget);
      expect(storage(tester), startsWith('Cloud sync is on'));
      expect(storage(tester), contains('synced to your plantly.ro account'));
      expect(storage(tester), contains('stored privately'));
      expect(storage(tester), contains('device name, platform and app version'));
      expect(find.textContaining('Nothing by default'), findsNothing);
      // Reminders stay local; backups still go through the share sheet.
      expect(find.textContaining('OS alarm system'), findsOneWidget);
      expect(find.textContaining('via the share sheet'), findsOneWidget);
      // "never the full database" would contradict the sync bullet.
      expect(find.textContaining('never the full database'), findsNothing);
      expect(find.textContaining('nothing else from your collection is published'), findsOneWidget);
    });

    testWidgets('web: plantly.ro account + browser copy, no phone / share sheet / OS alarms', (tester) async {
      await pump(tester, const PrivacyScreen(), overrides: [...web, ...sell]);
      expect(find.text('Where your data lives'), findsOneWidget);
      expect(find.text('What leaves your device'), findsNothing);
      expect(storage(tester), contains('saved in your plantly.ro account'));
      expect(storage(tester), contains('this browser'));
      expect(storage(tester), contains('device name, platform and app version'));
      expect(find.textContaining('phone'), findsNothing);
      expect(find.textContaining('share sheet'), findsNothing);
      expect(find.textContaining('OS alarm system'), findsNothing);
      expect(find.textContaining('your browser downloads the file'), findsOneWidget);
      expect(find.textContaining("browser version doesn't send notifications"), findsOneWidget);
      expect(find.textContaining('nothing else from your collection is published'), findsOneWidget);
    });

    testWidgets('Android, sync paused: nothing new leaves; the account copy is kept per the policy', (tester) async {
      await pump(tester, const PrivacyScreen(), overrides: paused);
      expect(find.text('What leaves your device'), findsOneWidget);
      expect(storage(tester), startsWith('Sync is paused: nothing new leaves this phone'));
      expect(storage(tester), contains('kept as described in the privacy policy'));
      expect(find.textContaining('Nothing by default'), findsNothing);
      expect(find.textContaining('Cloud sync is on'), findsNothing);
    });

    testWidgets('Android, sync paused (ro)', (tester) async {
      await pump(tester, const PrivacyScreen(), overrides: paused, locale: const Locale('ro'));
      expect(storage(tester), startsWith('Sincronizarea e în pauză'));
    });

    for (final (name, o) in [('local', <Override>[]), ('sync', syncing), ('web', web)]) {
      testWidgets('selling off (default): no marketplace bullet ($name)', (tester) async {
        await pump(tester, const PrivacyScreen(), overrides: o);
        expect(find.byKey(const ValueKey('privacy-bullet-marketplace')), findsNothing);
        expect(find.textContaining('post a plant'), findsNothing);
      });
    }

    testWidgets('selling on (ro, cloud): "scoți o plantă la vânzare"', (tester) async {
      await pump(tester, const PrivacyScreen(), overrides: [...syncing, ...sell], locale: const Locale('ro'));
      expect(find.textContaining('Dacă scoți o plantă la vânzare pe plantly.ro'), findsOneWidget);
    });

    testWidgets('web (ro)', (tester) async {
      await pump(tester, const PrivacyScreen(), overrides: web, locale: const Locale('ro'));
      expect(find.text('Unde stau datele tale'), findsOneWidget);
      expect(storage(tester), contains('salvate în contul tău plantly.ro'));
      expect(find.textContaining('telefon'), findsNothing);
    });

    testWidgets('Android, sync running (ro)', (tester) async {
      await pump(tester, const PrivacyScreen(), overrides: syncing, locale: const Locale('ro'));
      expect(storage(tester), startsWith('Sincronizarea cloud e pornită'));
      expect(storage(tester), contains('numele dispozitivului, platforma și versiunea aplicației'));
    });
  });

  group('Cloud screen intro', () {
    final off = <Override>[cloudStateProvider.overrideWithValue(CloudState.off)];
    String intro(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('cloud-screen-intro'))).data!;

    testWidgets('native keeps "nothing leaves this device until you link it"', (tester) async {
      await pump(tester, const CloudScreen(), overrides: off);
      expect(intro(tester), contains('Nothing leaves this device until you link it.'));
    });

    testWidgets('web drops the link clause — the browser is always linked', (tester) async {
      await pump(tester, const CloudScreen(), overrides: [...off, ...web]);
      expect(intro(tester), contains('saved in your plantly.ro account'));
      expect(intro(tester), isNot(contains('until you link it')));
    });
  });
}
