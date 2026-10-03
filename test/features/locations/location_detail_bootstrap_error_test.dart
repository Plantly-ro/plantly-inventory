import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/features/locations/location_detail_screen.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';

/// The bootstrap gate on the space detail must surface an `AsyncError` (DB
/// failed to open) as copy rather than spinning forever — the screen is
/// reachable straight from the URL on desktop, before Home ever rendered.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'plantly_onboarded': true}));

  testWidgets('bootstrap error shows the load-failed copy, not a spinner', (tester) async {
    await tester.pumpWidget(buildTestApp(
      overrides: [
        appContextProvider.overrideWith((ref) async => throw StateError('db exploded')),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LocationDetailScreen(locationId: 'living'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Failed to load location.'), findsOneWidget);
    expect(find.textContaining('db exploded'), findsOneWidget);
  });
}
