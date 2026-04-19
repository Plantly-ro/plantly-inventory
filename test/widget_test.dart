import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/features/home/home_providers.dart';
import 'package:plantly_inventory/features/home/home_screen.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_app.dart';

/// Widget tests default to an 800×600 viewport; the prototype home stacks
/// six widgets vertically (~2000 logical px), so without a tall surface the
/// offscreen portions (grid / activity / edit panel) never build and the
/// finders miss them. Use a tall, phone-width surface for every test.
Future<void> _pumpHome(WidgetTester tester, [Widget? root]) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // Drift's stream teardown schedules a zero-duration Timer that the
  // flutter_test fake clock leaves "pending" at widget-tree disposal;
  // give it real time to drain in tearDown so the binding doesn't fail.
  addTearDown(() async {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  });

  await tester.pumpWidget(
    root ?? buildTestApp(child: const PlantlyApp()),
  );
  // Pump extra frames so the async appContextProvider (DB open + seed) finishes.
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Home renders default layout widgets', (tester) async {
    await _pumpHome(tester);

    // Greeting — any of the time-of-day salutations depending on when the
    // test runs. No more hardcoded "Good morning, Ana".
    final hasGreeting = [
      'Good morning',
      'Good afternoon',
      'Good evening',
      'Still up?',
    ].any((s) => find.text(s).evaluate().isNotEmpty);
    expect(hasGreeting, isTrue, reason: 'expected a time-of-day greeting');

    // Stats: live counts from seeded data. Seed puts 8 plants, 0 spaces,
    // 2 overdue (bob + green), 3 due today (snake, cala, fid).
    expect(find.text('All plants'), findsOneWidget);
    expect(find.text('Recent activity'), findsOneWidget);
    expect(find.text('Monstera "Bob"'), findsWidgets);
    expect(find.text('Calendar'), findsWidgets); // tab label
    expect(find.text('Spaces'), findsWidgets);
  });

  testWidgets('Customize → Dashboard preset swaps widgets + persists to prefs', (tester) async {
    await _pumpHome(tester);

    // Long-press anywhere on the home body to enter edit mode — the
    // explicit button was removed in v0.5.14.
    await tester.longPress(find.text('Recent activity'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();

    // "Weather" widget is now a rotating tip card (phase-1 — no weather
    // provider yet); we assert the shared header instead of any specific
    // tip string, which changes daily by design.
    expect(find.text('TIP OF THE DAY'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('plantly_layout'), contains('weather'));
  });

  testWidgets('Layout persists across restarts', (tester) async {
    SharedPreferences.setMockInitialValues({
      'plantly_layout': '["greeting","quicklog"]',
    });
    await _pumpHome(tester);

    expect(find.text('Quick log'), findsOneWidget);
    expect(find.text('All plants'), findsNothing);
    expect(find.text('Recent activity'), findsNothing);
  });

  testWidgets('Reset restores default layout', (tester) async {
    SharedPreferences.setMockInitialValues({
      'plantly_layout': '["greeting"]',
    });
    await _pumpHome(tester);

    expect(find.text('All plants'), findsNothing);
    // Grab the container via a dummy ConsumerWidget so we can drive the
    // layout controller from the test.
    final BuildContext homeContext = tester.element(find.byType(HomeScreen));
    final container = ProviderScope.containerOf(homeContext);
    await container.read(homeLayoutProvider.notifier).reset();
    await tester.pumpAndSettle();
    expect(find.text('All plants'), findsOneWidget);
  });

  testWidgets('HomeScreen navigates to Calendar via tab bar', (tester) async {
    await _pumpHome(tester);

    await tester.tap(find.widgetWithText(InkWell, 'Calendar'));
    await tester.pumpAndSettle();

    // Real calendar always renders a "Week / Month / Year" segmented
    // control at the top; asserting those labels exist confirms we
    // navigated into the CalendarScreen.
    expect(find.text('Week'), findsWidgets);
    expect(find.text('Month'), findsWidgets);
    expect(find.text('Year'), findsWidgets);
  });

  testWidgets('HomeScreen builds without crash', (tester) async {
    await _pumpHome(
      tester,
      buildTestApp(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('FAB opens the add-plant sheet + submits to the repository', (tester) async {
    await _pumpHome(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Add a plant'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Test Sprout');
    await tester.tap(find.widgetWithText(FilledButton, 'Add plant'));
    await tester.pumpAndSettle();

    // Sheet dismissed on successful save.
    expect(find.text('Add a plant'), findsNothing);
  });
}
