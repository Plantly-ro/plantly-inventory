import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/care_types.dart';
import 'package:plantly_inventory/features/me/care_types_screen.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations_en.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations_ro.dart';
import 'package:plantly_inventory/shared/care_type_labels.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_app.dart';

/// Issue #15 remainder — the six seeded care types carry English labels
/// in `kBuiltInCareTypes`; everything that renders one must go through
/// `lib/shared/care_type_labels.dart` so a Romanian device never sees
/// "Water acum". Built-ins are identified by `key` + `builtin`, so a user
/// rename is honoured and custom types are untouched.
CareType _builtin(String key) => kBuiltInCareTypes.firstWhere((t) => t.key == key);

/// Serialised registry the way `CareTypesController` persists it, with the
/// `water` built-in renamed by the user.
String _prefsWithRenamedWater(String label) => json.encode([
      for (final t in kBuiltInCareTypes)
        t.key == 'water' ? t.copyWith(label: label).toJson() : t.toJson(),
    ]);

void main() {
  final ro = AppLocalizationsRo();
  final en = AppLocalizationsEn();

  group('careTypeLabel / careTypeVerb / careTypePastLabel', () {
    test('built-ins with the seeded label localize in all three forms (ro)', () {
      expect(careTypeLabel(ro, _builtin('water')), 'Udare');
      expect(careTypeVerb(ro, _builtin('water')), 'Udă');
      expect(careTypePastLabel(ro, _builtin('water')), 'Udată');
      expect(careTypeLabel(ro, _builtin('fertilize')), 'Fertilizare');
      expect(careTypeVerb(ro, _builtin('fertilize')), 'Fertilizează');
      expect(careTypePastLabel(ro, _builtin('fertilize')), 'Fertilizată');
      expect(careTypeLabel(ro, _builtin('mist')), 'Pulverizare');
      expect(careTypeVerb(ro, _builtin('mist')), 'Pulverizează');
      expect(careTypePastLabel(ro, _builtin('mist')), 'Pulverizată');
      expect(careTypeLabel(ro, _builtin('repot')), 'Replantare');
      expect(careTypeVerb(ro, _builtin('repot')), 'Replantează');
      expect(careTypePastLabel(ro, _builtin('repot')), 'Replantată');
      expect(careTypeLabel(ro, _builtin('prune')), 'Tundere');
      expect(careTypeVerb(ro, _builtin('prune')), 'Tunde');
      expect(careTypePastLabel(ro, _builtin('prune')), 'Tunsă');
      expect(careTypeLabel(ro, _builtin('rotate')), 'Rotire');
      expect(careTypeVerb(ro, _builtin('rotate')), 'Rotește');
      expect(careTypePastLabel(ro, _builtin('rotate')), 'Rotită');
    });

    test('built-ins keep their English copy under the en locale', () {
      expect(careTypeLabel(en, _builtin('water')), 'Water');
      expect(careTypeVerb(en, _builtin('water')), 'Water');
      expect(careTypePastLabel(en, _builtin('water')), 'Watered');
      expect(careTypePastLabel(en, _builtin('repot')), 'Repotted');
    });

    test('a renamed built-in shows the user label in every form', () {
      final renamed = _builtin('water').copyWith(label: 'Apă');
      expect(renamed.builtin, isTrue);
      expect(careTypeLabel(ro, renamed), 'Apă');
      expect(careTypeVerb(ro, renamed), 'Apă');
      expect(careTypePastLabel(ro, renamed), 'Apă');
      expect(careTypeLabel(en, renamed), 'Apă');
    });

    test('a built-in carrying the localized noun is not treated as a rename', () {
      // e.g. registry saved after an editor round-trip under ro before
      // canonicalisation existed.
      final roundTripped = _builtin('water').copyWith(label: 'Udare');
      expect(careTypeUsesDefaultLabel(ro, roundTripped), isTrue);
      expect(careTypeVerb(ro, roundTripped), 'Udă');
      expect(careTypePastLabel(ro, roundTripped), 'Udată');
    });

    test('custom types always show their own label', () {
      const custom = CareType(key: 'neem_spray', label: 'Neem spray', iconCode: 0, defaultIntervalDays: 14);
      expect(careTypeLabel(ro, custom), 'Neem spray');
      expect(careTypeVerb(ro, custom), 'Neem spray');
      expect(careTypePastLabel(ro, custom), 'Neem spray');
      // A type that reuses a built-in key but was created as non-builtin is
      // also left alone — identification is key+flag, never the label.
      const shadow = CareType(key: 'water', label: 'Water', iconCode: 0, defaultIntervalDays: 7);
      expect(careTypeLabel(ro, shadow), 'Water');
    });

    test('key-based conveniences resolve through the registry and fall back for unknown keys', () {
      final types = [for (final t in kBuiltInCareTypes) t.key == 'mist' ? t.copyWith(label: 'Ceață') : t];
      expect(careKeyLabel(ro, types, 'water'), 'Udare');
      expect(careKeyVerb(ro, types, 'water'), 'Udă');
      expect(careKeyPastLabel(ro, types, 'water'), 'Udată');
      expect(careKeyLabel(ro, types, 'mist'), 'Ceață');
      // Legacy / unknown key → capitalised key (resolveCareType fallback).
      expect(careKeyLabel(ro, types, 'dust'), 'Dust');
      expect(careKeyPastLabel(ro, types, ''), 'Înregistrat');
    });
  });

  group('canonicalCareTypeLabel (editor save)', () {
    test('typing the localized default stores the seeded English key label', () {
      expect(canonicalCareTypeLabel(ro, _builtin('water'), 'Udare'), 'Water');
      expect(canonicalCareTypeLabel(en, _builtin('water'), 'Water'), 'Water');
    });

    test('any other text is a real rename and is stored verbatim', () {
      expect(canonicalCareTypeLabel(ro, _builtin('water'), 'Apă'), 'Apă');
      const custom = CareType(key: 'neem', label: 'Neem', iconCode: 0, defaultIntervalDays: 14);
      expect(canonicalCareTypeLabel(ro, custom, 'Udare'), 'Udare');
    });
  });

  group('resolveAppLocale / appLocalizationsForPlatform (no BuildContext)', () {
    testWidgets('follows the platform locale when supported', (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('ro', 'RO')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      expect(resolveAppLocale().languageCode, 'ro');
      expect(appLocalizationsForPlatform().careTypeWater, 'Udare');
    });

    testWidgets('falls back to English for an unsupported platform locale', (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('de', 'DE')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      expect(resolveAppLocale().languageCode, 'en');
      expect(appLocalizationsForPlatform().careTypeWater, 'Water');
    });
  });

  group('CareTypesScreen · Romanian locale', () {
    Widget app(Widget home) => buildTestApp(
          child: MaterialApp(
            locale: const Locale('ro'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: home,
          ),
        );

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(720, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))));
      await tester.pumpWidget(app(const CareTypesScreen()));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
    }

    testWidgets('built-in rows render Romanian nouns, never the seeded English', (tester) async {
      SharedPreferences.setMockInitialValues({'plantly_onboarded': true});
      await pump(tester);

      for (final label in ['Udare', 'Fertilizare', 'Pulverizare', 'Replantare', 'Tundere', 'Rotire']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      for (final leak in ['Water', 'Fertilize', 'Mist', 'Repot', 'Prune', 'Rotate']) {
        expect(find.text(leak), findsNothing, reason: leak);
      }
    });

    testWidgets('a renamed built-in keeps the user label; the others still localize', (tester) async {
      SharedPreferences.setMockInitialValues({
        'plantly_onboarded': true,
        'plantly_care_types': _prefsWithRenamedWater('Apă'),
      });
      await pump(tester);

      expect(find.text('Apă'), findsOneWidget);
      expect(find.text('Udare'), findsNothing);
      expect(find.text('Water'), findsNothing);
      expect(find.text('Fertilizare'), findsOneWidget);
    });
  });
}
