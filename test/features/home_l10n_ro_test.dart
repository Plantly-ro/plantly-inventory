import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/features/home/home_screen.dart';
import 'package:plantly_inventory/features/locations/locations_screen.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_app.dart';

/// Issue #15 — Home, add-plant sheet and Spaces must render Romanian copy
/// (not English, and never the raw `locations.kind` enum) when the app
/// locale is `ro`.
Widget _roApp(Widget home, {List<Override> overrides = const []}) {
  return buildTestApp(
    overrides: overrides,
    child: MaterialApp(
      locale: const Locale('ro'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget root) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() async {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  });
  await tester.pumpWidget(root);
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

LocationRow _space(String id, String name, String kind) => LocationRow(
      id: id,
      tenantId: kDefaultTenantId,
      name: name,
      kind: kind,
      isOutdoor: kind == 'outdoor_bed',
      notificationsMuted: false,
      updatedHlc: HlcClock(deviceId: 'test-device').now().encode(),
      deviceId: 'test-device',
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'plantly_onboarded': true});
  });

  testWidgets('Home renders Romanian nav, widget titles and stat labels', (tester) async {
    await _pump(tester, _roApp(const HomeScreen()));

    // Bottom nav.
    expect(find.text('Acasă'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Eu'), findsOneWidget);
    // Widget titles + stat tiles (statSpaces + nav share "Spații").
    expect(find.text('Toate plantele'), findsOneWidget);
    expect(find.text('Activitate recentă'), findsOneWidget);
    expect(find.text('Spații'), findsWidgets);
    expect(find.text('Plante'), findsOneWidget);
    // Nothing leaked in English.
    expect(find.text('Home'), findsNothing);
    expect(find.text('All plants'), findsNothing);
    expect(find.text('Recent activity'), findsNothing);
    expect(find.text('Me'), findsNothing);
  });

  testWidgets('Add-plant sheet renders Romanian labels and a human space kind', (tester) async {
    await _pump(
      tester,
      _roApp(
        const HomeScreen(),
        overrides: [
          locationsStreamProvider.overrideWith(
            (ref) => Stream.value([_space('loc-1', 'Balcon', 'outdoor_bed')]),
          ),
        ],
      ),
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Adaugă o plantă'), findsOneWidget);
    expect(find.text('NUME'), findsOneWidget);
    expect(find.text('SPAȚIU'), findsOneWidget);
    expect(find.text('NOTE'), findsOneWidget);
    expect(find.text('— fără spațiu —'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Adaugă planta'), findsOneWidget);
    expect(find.text('Add a plant'), findsNothing);
    expect(find.text('NICKNAME'), findsNothing);

    // Picking the space shows "Balcon · Strat exterior", never the raw enum.
    await tester.tap(find.text('— fără spațiu —'));
    await tester.pumpAndSettle();
    // Picking a space for a NEW plant gets the neutral title; "Mută în
    // spațiu" (move) is reserved for Edit / Move flows.
    expect(find.text('Alege spațiul'), findsOneWidget);
    expect(find.text('Mută în spațiu'), findsNothing);
    expect(find.text('Choose a space'), findsNothing);
    expect(find.text('Strat exterior'), findsOneWidget);
    expect(find.textContaining('outdoor_bed'), findsNothing);
    // The grid's location filter chip also says "Balcon" — tap the picker row.
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Balcon')));
    await tester.pumpAndSettle();
    expect(find.text('Balcon · Strat exterior'), findsOneWidget);
    expect(find.textContaining('outdoor_bed'), findsNothing);
  });

  testWidgets('Spaces list renders human kind labels in Romanian, never the raw enum', (tester) async {
    await _pump(
      tester,
      _roApp(
        const LocationsScreen(),
        overrides: [
          locationsStreamProvider.overrideWith(
            (ref) => Stream.value([
              _space('loc-home', 'Acasă la mine', 'home'),
              _space('loc-room', 'Sufragerie', 'room'),
              _space('loc-bed', 'Grădină', 'outdoor_bed'),
            ]),
          ),
        ],
      ),
    );

    expect(find.text('Spații'), findsOneWidget); // app bar title
    expect(find.text('Acasă'), findsOneWidget); // kind: home
    expect(find.text('Cameră'), findsOneWidget); // kind: room
    expect(find.text('Strat exterior'), findsOneWidget); // kind: outdoor_bed
    expect(find.text('Adaugă plante'), findsNWidgets(3));
    for (final raw in ['outdoor_bed', 'room', 'home', 'zone', 'shelf']) {
      expect(find.text(raw), findsNothing, reason: 'raw kind "$raw" leaked into the UI');
    }
    expect(find.text('Spaces'), findsNothing);
    expect(find.text('Add plants'), findsNothing);
  });
}
