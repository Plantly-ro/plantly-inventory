import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/app/ro_informal_material.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';

void main() {
  Future<MaterialLocalizations> pump(WidgetTester tester, Locale locale) async {
    late MaterialLocalizations m;
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: const [RoInformalMaterialLocalizations.delegate, ...AppLocalizations.localizationsDelegates],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        m = MaterialLocalizations.of(context);
        return const SizedBox();
      }),
    ));
    return m;
  }

  testWidgets('ro framework strings use the informal "tu"', (tester) async {
    final m = await pump(tester, const Locale('ro'));
    expect(m.showMenuTooltip, 'Afișează meniul');
    expect(m.cancelButtonLabel, 'Anulează');
    expect(m.backButtonTooltip, 'Înapoi', reason: 'non-verb strings stay stock');
    expect(m.formatMediumDate(DateTime(2026, 10, 9)), isNotEmpty, reason: 'date formats intact');
  });

  testWidgets('en untouched', (tester) async {
    final m = await pump(tester, const Locale('en'));
    expect(m.showMenuTooltip, 'Show menu');
    expect(m, isNot(isA<RoInformalMaterialLocalizations>()));
  });
}
