import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/features/plant_detail/plant_detail_screen.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations_en.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';

/// QA B2 — on a phone-sized viewport the extended FAB covered the last card
/// ("Prepare listing draft") once the detail list was scrolled to the
/// bottom. The list now reserves FAB height + margins (+ nav inset) at the
/// end, so the CTA's bottom edge always clears the FAB's top edge.
const _plantId = 'plant-fab-1';

PlantRow _plant() => PlantRow(
      id: _plantId,
      tenantId: kDefaultTenantId,
      nickname: 'Monstera "Bob"',
      speciesId: null,
      locationId: null,
      pinX: null,
      pinY: null,
      notificationsMuted: false,
      status: 'alive',
      acquiredAt: null,
      source: null,
      notes: null,
      potSizeCm: null,
      updatedHlc: HlcClock(deviceId: 'test-device').now().encode(),
      deletedAt: null,
      deviceId: 'test-device',
    );

Future<void> _pump(WidgetTester tester, {required EdgeInsets viewPadding}) async {
  SharedPreferences.setMockInitialValues({'plantly_onboarded': true});
  // Phone-sized so the list actually scrolls (the l10n test uses a tall
  // surface on purpose; here we need the bottom of the list under the FAB).
  tester.view.physicalSize = const Size(420, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))));

  final plant = _plant();
  await tester.pumpWidget(buildTestApp(
    overrides: [
      plantByIdProvider.overrideWith((ref, id) => Stream.value(plant)),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(size: const Size(420, 800), padding: viewPadding, viewPadding: viewPadding),
        child: const PlantDetailScreen(plantId: _plantId),
      ),
    ),
  ));
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

Finder _cta() {
  final en = AppLocalizationsEn();
  final label = find.byWidgetPredicate(
    (w) => w is Text && (w.data == en.exportDraftCta || w.data == en.exportPostOnPlantlyRoCta),
  );
  // Nearest InkWell = the CTA card itself.
  return find.ancestor(of: label, matching: find.byType(InkWell)).first;
}

void main() {
  for (final (label, inset) in [('no nav inset', 0.0), ('gesture-nav inset', 48.0)]) {
    testWidgets('scrolled to the bottom, the listing CTA clears the FAB ($label)', (tester) async {
      await _pump(tester, viewPadding: EdgeInsets.only(bottom: inset));

      final list = find.byType(ListView).first;
      await tester.drag(list, const Offset(0, -10000));
      await tester.pumpAndSettle();

      final fab = tester.getRect(find.byType(FloatingActionButton));
      final cta = tester.getRect(_cta());
      expect(cta.bottom, lessThanOrEqualTo(fab.top),
          reason: 'CTA bottom ${cta.bottom} must not run under the FAB (top ${fab.top})');
      // And nothing silly like the CTA being pushed off-screen.
      expect(cta.bottom, lessThanOrEqualTo(800));
      expect(cta.top, greaterThan(0));
    });
  }

  testWidgets('the list reserves FAB clearance + the bottom safe-area inset', (tester) async {
    await _pump(tester, viewPadding: const EdgeInsets.only(bottom: 30));
    final list = tester.widget<ListView>(find.byType(ListView).first);
    expect(list.padding?.resolve(TextDirection.ltr).bottom, 96 + 30);
  });
}
