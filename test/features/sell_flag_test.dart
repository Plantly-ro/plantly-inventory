import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/config/plantly_features.dart';
import 'package:plantly_inventory/config/plantly_hosts.dart';
import 'package:plantly_inventory/features/me/me_screen.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/marketplace/session_store.dart';
import 'package:plantly_inventory/plugins/local_draft/local_draft_plugin.dart';
import 'package:plantly_inventory/plugins/plantly_ro/plantly_ro_plugin.dart';
import 'package:plantly_inventory/plugins/plugin_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_app.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'plantly_onboarded': true}));

  test('PLANTLY_SELL_ENABLED defaults to off', () {
    expect(PlantlyFeatures.sellEnabled, isFalse);
  });

  group('PluginRegistry', () {
    ProviderContainer container(bool sell) {
      final c = ProviderContainer(overrides: [
        sellEnabledProvider.overrideWithValue(sell),
        sessionStoreProvider.overrideWith((_) => InMemorySessionStore()),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('flag off → local_draft only and default (pre-marketplace behaviour)', () {
      final c = container(false);
      final registry = c.read(pluginRegistryProvider);
      expect(registry.all.map((p) => p.id), [LocalDraftExportPlugin.pluginId]);
      expect(c.read(defaultExportPluginProvider).id, LocalDraftExportPlugin.pluginId);
      expect(c.read(plantlyRoPluginProvider), isNull);
    });

    test('flag on → plantly_ro registered first and default', () {
      final c = container(true);
      final registry = c.read(pluginRegistryProvider);
      expect(registry.all.map((p) => p.id), [PlantlyRoExportPlugin.pluginId, LocalDraftExportPlugin.pluginId]);
      expect(c.read(defaultExportPluginProvider).id, PlantlyRoExportPlugin.pluginId);
      expect(c.read(plantlyRoPluginProvider), isNotNull);
    });
  });

  group('Me screen', () {
    Future<void> pumpMe(WidgetTester tester, bool sell) async {
      tester.view.physicalSize = const Size(420, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))));
      await tester.pumpWidget(buildTestApp(
        overrides: [sellEnabledProvider.overrideWithValue(sell)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MeScreen(),
        ),
      ));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
    }

    testWidgets('flag off → no "Plantly account" section', (tester) async {
      await pumpMe(tester, false);
      expect(find.byKey(const Key('me-plantly-account')), findsNothing);
      expect(find.text('PLANTLY ACCOUNT'), findsNothing);
      expect(find.text('APPEARANCE'), findsOneWidget);
    });

    testWidgets('About → App shows the app name and build version, no "Phase 1"', (tester) async {
      await pumpMe(tester, false);
      expect(find.text('Plantly Inventory · ${PlantlyHosts.appVersion}'), findsOneWidget);
      expect(find.textContaining('Phase 1'), findsNothing);
    });

    testWidgets('flag on → "Plantly account" section with Sign in', (tester) async {
      await pumpMe(tester, true);
      expect(find.byKey(const Key('me-plantly-account')), findsOneWidget);
      expect(find.text('PLANTLY ACCOUNT'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
    });
  });
}
