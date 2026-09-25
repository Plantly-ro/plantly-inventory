import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/shared/photo_source_sheet.dart';
import 'package:plantly_inventory/theme/tokens.dart';

/// The camera / gallery chooser was hard-coded English ("Take photo",
/// "Choose from gallery") on a Romanian device.
Future<void> _pumpAndOpen(WidgetTester tester, {required Locale locale, required bool multi}) async {
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showPhotoSourceSheet(context, surface: PlantlySurface.light, multi: multi),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('multi picker renders Romanian labels', (tester) async {
    await _pumpAndOpen(tester, locale: const Locale('ro'), multi: true);
    expect(find.text('Fă o poză'), findsOneWidget);
    expect(find.text('Deschide camera'), findsOneWidget);
    expect(find.text('Alege din galerie'), findsOneWidget);
    expect(find.text('Selectează mai multe imagini'), findsOneWidget);
    expect(find.text('Take photo'), findsNothing);
    expect(find.text('Choose from gallery'), findsNothing);
  });

  testWidgets('single picker renders Romanian labels', (tester) async {
    await _pumpAndOpen(tester, locale: const Locale('ro'), multi: false);
    expect(find.text('Alege una din galerie'), findsOneWidget);
    expect(find.text('Alege o singură imagine'), findsOneWidget);
    expect(find.text('Choose one from gallery'), findsNothing);
  });

  testWidgets('English stays English', (tester) async {
    await _pumpAndOpen(tester, locale: const Locale('en'), multi: true);
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Select multiple images'), findsOneWidget);
  });
}
