import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/cloud/collections.dart' show canEditActiveCollectionProvider;
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/features/plant_detail/plant_detail_screen.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations_en.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';

/// QA 2026-10-07 (o): a viewer of a shared collection still saw "Prepare
/// listing draft" on plant detail. Listing is a mutation — hidden for viewers.
const _plantId = 'plant-viewer-1';

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

Future<void> _pump(WidgetTester tester, {required EdgeInsets viewPadding, required bool canEdit}) async {
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
      canEditActiveCollectionProvider.overrideWithValue(canEdit),
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

Finder _ctaLabel() {
  final en = AppLocalizationsEn();
  final label = find.byWidgetPredicate(
    (w) => w is Text && (w.data == en.exportDraftCta || w.data == en.exportPostOnPlantlyRoCta),
  );
  return label;
}

void main() {
  testWidgets('editor sees the listing CTA; viewer does not', (tester) async {
    await _pump(tester, viewPadding: EdgeInsets.zero, canEdit: true);
    await tester.drag(find.byType(ListView).first, const Offset(0, -10000));
    await tester.pumpAndSettle();
    expect(_ctaLabel(), findsOneWidget);
  });

  testWidgets('viewer: no "Prepare listing draft"', (tester) async {
    await _pump(tester, viewPadding: EdgeInsets.zero, canEdit: false);
    await tester.drag(find.byType(ListView).first, const Offset(0, -10000));
    await tester.pumpAndSettle();
    expect(_ctaLabel(), findsNothing);
  });
}
