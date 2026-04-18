import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations_en.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations_ro.dart';

void main() {
  test('supported locales include en + ro', () {
    final codes = AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet();
    expect(codes, containsAll(<String>['en', 'ro']));
  });

  test('en + ro strings differ for translated keys', () {
    final en = AppLocalizationsEn();
    final ro = AppLocalizationsRo();
    expect(en.customizeHome, 'Customize home');
    expect(ro.customizeHome, 'Personalizează ecranul');
    expect(en.rainExpected, 'Rain expected');
    expect(ro.rainExpected, 'Se așteaptă ploaie');
    expect(en.goodMorning('Ana'), 'Good morning, Ana');
    expect(ro.goodMorning('Ana'), 'Bună dimineața, Ana');
  });

  testWidgets('MaterialApp resolves AppLocalizations from the active locale', (tester) async {
    Future<void> pumpWith(Locale locale) async {
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Text(AppLocalizations.of(context).customizeHome),
        ),
      ));
      await tester.pumpAndSettle();
    }

    await pumpWith(const Locale('en'));
    expect(find.text('Customize home'), findsOneWidget);

    await pumpWith(const Locale('ro'));
    expect(find.text('Personalizează ecranul'), findsOneWidget);
  });
}
