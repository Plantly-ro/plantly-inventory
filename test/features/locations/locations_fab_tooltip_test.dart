import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/features/locations/locations_screen.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';

/// QA B7 — the Spaces "+" FAB had no accessible label. Every FAB now carries
/// a tooltip from the existing ARB labels (Home → addPlant, Spaces →
/// addSpace, Care types → addBtn, Plant detail already had one).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'plantly_onboarded': true}));

  Future<void> pump(WidgetTester tester, Locale locale) async {
    addTearDown(() => tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))));
    await tester.pumpWidget(buildTestApp(
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LocationsScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Spaces FAB exposes a localized tooltip (ro)', (tester) async {
    await pump(tester, const Locale('ro'));
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byTooltip('Adaugă un spațiu'), findsOneWidget);
  });

  testWidgets('Spaces FAB exposes a localized tooltip (en)', (tester) async {
    await pump(tester, const Locale('en'));
    expect(find.byTooltip('Add a space'), findsOneWidget);
  });
}
