import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/care_types.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/features/plant_detail/plant_detail_screen.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations_ro.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';

/// Issue #15 (part B): the plant-detail screen was hardcoded English and
/// rendered an orphan "STATS" header for plants without any care events.
/// These tests pump the real screen under an explicit locale and assert
/// on the rendered strings, so a regression in either the ARB wiring or
/// the header gating shows up here rather than on a phone.
const _plantId = 'plant-l10n-1';

String _hlc() => HlcClock(deviceId: 'test-device').now().encode();

PlantRow _plant() => PlantRow(
      id: _plantId,
      tenantId: kDefaultTenantId,
      nickname: 'Ferigă "Zed"',
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
      updatedHlc: _hlc(),
      deletedAt: null,
      deviceId: 'test-device',
    );

CareEventRow _waterEvent({required int doneAt}) => CareEventRow(
      id: 'event-l10n-1',
      tenantId: kDefaultTenantId,
      plantId: _plantId,
      type: 'water',
      doneAt: doneAt,
      updatedHlc: _hlc(),
      deviceId: 'test-device',
    );

Future<void> _pumpDetail(
  WidgetTester tester, {
  required Locale locale,
  required List<CareEventRow> events,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues({'plantly_onboarded': true, ...prefs});
  // Tall viewport so every section (stats / upcoming / timeline) actually
  // builds; the default 800×600 surface would clip the list. Wider than a
  // phone because the test font renders every glyph as a fontSize-wide
  // square, so the longer Romanian strings overflow a 420px Row that fits
  // comfortably with a real font on-device.
  tester.view.physicalSize = const Size(720, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  // Drift stream teardown schedules a zero-duration Timer; drain it in
  // real time so the binding doesn't flag it as pending (same dance as
  // widget_test.dart).
  addTearDown(() => tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))));

  final plant = _plant();
  await tester.pumpWidget(buildTestApp(
    overrides: [
      plantByIdProvider.overrideWith((ref, id) => Stream.value(plant)),
      careEventsForPlantProvider.overrideWith((ref, id) => Stream.value(events)),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const PlantDetailScreen(plantId: _plantId),
    ),
  ));
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'plantly_onboarded': true}));

  group('PlantDetailScreen · Romanian locale', () {
    testWidgets('section headers, empty hints and CTAs render in Romanian', (tester) async {
      await _pumpDetail(tester, locale: const Locale('ro'), events: const []);

      expect(find.text('ÎNGRIJIRI URMĂTOARE'), findsOneWidget);
      expect(find.text('ISTORIC'), findsOneWidget);
      expect(find.text('Niciun memento încă — apasă mai jos pentru a adăuga unul.'), findsOneWidget);
      expect(find.text('Adaugă memento'), findsOneWidget);
      expect(find.text('Niciun eveniment încă — înregistrează prima udare mai jos.'), findsOneWidget);
      expect(find.text('Înregistrează eveniment'), findsOneWidget);
      expect(find.text('Fără spațiu setat'), findsOneWidget);

      // No English leaks on the localized surface.
      expect(find.text('UPCOMING CARE'), findsNothing);
      expect(find.text('TIMELINE'), findsNothing);
      expect(find.text('Add reminder'), findsNothing);
      expect(find.text('Log event'), findsNothing);
    });

    testWidgets('stats header + card appear (localized) once the plant has an event', (tester) async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await _pumpDetail(tester, locale: const Locale('ro'), events: [_waterEvent(doneAt: now)]);

      expect(find.text('STATISTICI'), findsOneWidget);
      expect(find.text('EVENIMENTE'), findsOneWidget);
      expect(find.text('ULTIMA UDARE'), findsOneWidget);
      expect(find.text('azi'), findsOneWidget);
      // The timeline row uses the past-tense verb, not the raw type key.
      expect(find.text('Udată'), findsOneWidget);
      expect(find.text('Watered'), findsNothing);
    });
  });

  group('PlantDetailScreen · STATS header gating (#15)', () {
    testWidgets('no STATS header when the plant has no events', (tester) async {
      await _pumpDetail(tester, locale: const Locale('en'), events: const []);

      expect(find.text('STATS'), findsNothing);
      // Neighbouring sections still render, so the absence is not a blank screen.
      expect(find.text('UPCOMING CARE'), findsOneWidget);
      expect(find.text('TIMELINE'), findsOneWidget);
    });

    testWidgets('STATS header returns once there is an event', (tester) async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await _pumpDetail(tester, locale: const Locale('en'), events: [_waterEvent(doneAt: now)]);

      expect(find.text('STATS'), findsOneWidget);
      expect(find.text('EVENTS'), findsOneWidget);
      expect(find.text('LAST WATER'), findsOneWidget);
    });
  });

  group('PlantDetailScreen · built-in care-type labels (#15 remainder)', () {
    testWidgets('FAB reads "Udă acum" (imperative), not "Water acum"', (tester) async {
      await _pumpDetail(tester, locale: const Locale('ro'), events: const []);

      expect(find.text('Udă acum'), findsOneWidget);
      expect(find.text('Water acum'), findsNothing);
      expect(find.text('Water now'), findsNothing);
    });

    testWidgets('FAB keeps English under en', (tester) async {
      await _pumpDetail(tester, locale: const Locale('en'), events: const []);
      expect(find.text('Water now'), findsOneWidget);
    });

    testWidgets('a renamed built-in keeps the user label on the FAB and in the timeline', (tester) async {
      final renamed = json.encode([
        for (final t in kBuiltInCareTypes)
          t.key == 'water' ? t.copyWith(label: 'Apă').toJson() : t.toJson(),
      ]);
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await _pumpDetail(
        tester,
        locale: const Locale('ro'),
        events: [_waterEvent(doneAt: now)],
        prefs: {'plantly_care_types': renamed},
      );

      expect(find.text('Apă acum'), findsOneWidget);
      expect(find.text('Udă acum'), findsNothing);
      // Timeline row + stats card follow the rename too (no "Udată" /
      // "ULTIMA UDARE" for a type the user calls "Apă").
      expect(find.text('Apă'), findsOneWidget);
      expect(find.text('ULTIMA APĂ'), findsOneWidget);
      expect(find.text('Udată'), findsNothing);
    });

    testWidgets('a custom care type shows its own label everywhere', (tester) async {
      final withCustom = json.encode([
        for (final t in kBuiltInCareTypes) t.toJson(),
        const CareType(key: 'neem_spray', label: 'Spray cu neem', iconCode: 0, defaultIntervalDays: 14).toJson(),
      ]);
      await _pumpDetail(
        tester,
        locale: const Locale('ro'),
        events: [_waterEvent(doneAt: DateTime.now().toUtc().millisecondsSinceEpoch)],
        prefs: {'plantly_care_types': withCustom, 'plantly_quick_fab_type': 'neem_spray'},
      );
      expect(find.text('Spray cu neem acum'), findsOneWidget);
    });
  });

  group('Romanian plural forms', () {
    test('few / other buckets follow CLDR ro rules', () {
      final ro = AppLocalizationsRo();
      expect(ro.detailDueInDays(1), 'într-o zi');
      expect(ro.detailDueInDays(3), 'în 3 zile');
      expect(ro.detailDueInDays(21), 'în 21 de zile');
      expect(ro.detailOverdueDays(1), 'restant de o zi');
      expect(ro.detailOverdueDays(2), 'restant de 2 zile');
      expect(ro.detailOverdueDays(30), 'restant de 30 de zile');
      expect(ro.meImportedRows(1), 'Importat 1 rând');
      expect(ro.meImportedRows(12), 'Importate 12 rânduri');
      expect(ro.meImportedRows(25), 'Importate 25 de rânduri');
      expect(ro.meCareTypeDefaultEvery('7', 7), 'Implicit: la fiecare 7 zile');
      expect(ro.meCareTypeDefaultEvery('30', 30), 'Implicit: la fiecare 30 de zile');
    });
  });
}
