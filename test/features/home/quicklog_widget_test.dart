import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/care_types.dart';
import 'package:plantly_inventory/features/home/widgets/quicklog_widget.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/theme/tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';

/// Issue #16 — the Quick log tiles used fixed `quickLog*` ARB keys, so a
/// user-renamed built-in ("water" → "Apă") still showed the default name
/// there while every other surface followed the rename. Tiles must resolve
/// through `lib/shared/care_type_labels.dart` against the live
/// `careTypesProvider` registry.

/// Registry the way `CareTypesController` persists it, with [patch]
/// applied to the built-ins and any [extra] (custom) types appended.
String _registry({
  CareType Function(CareType t)? patch,
  List<CareType> extra = const [],
}) =>
    json.encode([
      for (final t in kBuiltInCareTypes) (patch ?? (t) => t)(t).toJson(),
      for (final t in extra) t.toJson(),
    ]);

Future<void> _pump(WidgetTester tester, Locale locale) async {
  tester.view.physicalSize = const Size(420, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(buildTestApp(
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: QuickLogWidget(surface: PlantlySurface.light),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(QuickLogWidget)));

void main() {
  testWidgets('untouched built-ins render the localized default (en)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pump(tester, const Locale('en'));

    for (final label in ['Water', 'Fertilize', 'Mist', 'Rotate']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('untouched built-ins render the localized default (ro)', (tester) async {
    // Persisted registry with the seeded English labels — must still
    // localize, never leak "Water" on a Romanian device.
    SharedPreferences.setMockInitialValues({'plantly_care_types': _registry()});
    await _pump(tester, const Locale('ro'));

    for (final label in ['Udare', 'Fertilizare', 'Pulverizare', 'Rotire']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    for (final leaked in ['Water', 'Fertilize', 'Mist', 'Rotate']) {
      expect(find.text(leaked), findsNothing, reason: leaked);
    }
  });

  testWidgets('a renamed built-in shows the user label in ro (persisted rename)', (tester) async {
    SharedPreferences.setMockInitialValues({
      'plantly_care_types': _registry(patch: (t) => t.key == 'water' ? t.copyWith(label: 'Apă') : t),
    });
    await _pump(tester, const Locale('ro'));

    expect(find.text('Apă'), findsOneWidget);
    expect(find.text('Udare'), findsNothing);
    // Untouched siblings keep localizing.
    expect(find.text('Fertilizare'), findsOneWidget);
  });

  testWidgets('a renamed built-in shows the user label in en', (tester) async {
    SharedPreferences.setMockInitialValues({
      'plantly_care_types': _registry(patch: (t) => t.key == 'mist' ? t.copyWith(label: 'Spritz') : t),
    });
    await _pump(tester, const Locale('en'));

    expect(find.text('Spritz'), findsOneWidget);
    expect(find.text('Mist'), findsNothing);
    expect(find.text('Water'), findsOneWidget);
  });

  testWidgets('a rename while the widget is on screen re-renders live (registry is watched)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pump(tester, const Locale('ro'));
    expect(find.text('Rotire'), findsOneWidget);

    final notifier = _container(tester).read(careTypesProvider.notifier);
    final rotate = kBuiltInCareTypes.firstWhere((t) => t.key == 'rotate');
    await tester.runAsync(() => notifier.update('rotate', rotate.copyWith(label: 'Întoarce')));
    await tester.pumpAndSettle();

    expect(find.text('Întoarce'), findsOneWidget);
    expect(find.text('Rotire'), findsNothing);

    // Resetting to built-ins localizes again.
    await tester.runAsync(notifier.resetToBuiltIn);
    await tester.pumpAndSettle();
    expect(find.text('Rotire'), findsOneWidget);
  });

  testWidgets('the plant picker header follows the rename too', (tester) async {
    SharedPreferences.setMockInitialValues({
      'plantly_care_types': _registry(patch: (t) => t.key == 'water' ? t.copyWith(label: 'Apă') : t),
    });
    await _pump(tester, const Locale('ro'));

    await tester.tap(find.text('Apă'));
    await tester.pumpAndSettle();
    expect(find.text('Apă — care plantă?'), findsOneWidget);
    expect(find.text('Udare — care plantă?'), findsNothing);
  });

  testWidgets('custom types and a custom icon on a built-in are honoured', (tester) async {
    SharedPreferences.setMockInitialValues({
      'plantly_care_types': _registry(
        patch: (t) => t.key == 'fertilize' ? t.copyWith(iconCode: Icons.spa_outlined.codePoint) : t,
        extra: [
          CareType(key: 'neem_spray', label: 'Spray cu neem', iconCode: Icons.bug_report_outlined.codePoint, defaultIntervalDays: 14),
        ],
      ),
    });
    await _pump(tester, const Locale('ro'));

    // The four built-in shortcuts still render (localized, untouched label)
    // and a custom type in the registry neither replaces nor breaks them.
    for (final label in ['Udare', 'Fertilizare', 'Pulverizare', 'Rotire']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Spray cu neem'), findsNothing);
    // The user's icon choice for "fertilize" is used instead of a fixed one.
    expect(find.byIcon(Icons.spa_outlined), findsOneWidget);
    expect(find.byIcon(Icons.eco_outlined), findsNothing);
  });
}
