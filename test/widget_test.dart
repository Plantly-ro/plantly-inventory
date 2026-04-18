import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/features/home/home_providers.dart';
import 'package:plantly_inventory/features/home/home_screen.dart';
import 'package:plantly_inventory/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Widget tests default to an 800×600 viewport; the prototype home stacks
/// six widgets vertically (~2000 logical px), so without a tall surface the
/// offscreen portions (grid / activity / edit panel) never build and the
/// finders miss them. Use a tall, phone-width surface for every test.
Future<void> _pumpHome(WidgetTester tester, [Widget? root]) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(root ?? const ProviderScope(child: PlantlyApp()));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Home renders default layout widgets', (tester) async {
    await _pumpHome(tester);

    expect(find.text('Good morning, Ana'), findsOneWidget);
    expect(find.text('Friday · April 18'), findsOneWidget);

    for (final value in ['2', '3', '24', '6']) {
      expect(find.text(value), findsWidgets, reason: 'missing stats value $value');
    }
    expect(find.text('All plants'), findsOneWidget);
    expect(find.text('Recent activity'), findsOneWidget);
    expect(find.text('Monstera "Bob"'), findsWidgets);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Spaces'), findsWidgets);
  });

  testWidgets('Customize → Dashboard preset swaps widgets + persists to prefs', (tester) async {
    await _pumpHome(tester);

    await tester.tap(find.text('✎ Customize home'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();

    expect(find.text('TIMIȘOARA · 19°C'), findsOneWidget);

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
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await _pumpHome(
      tester,
      UncontrolledProviderScope(container: container, child: const PlantlyApp()),
    );

    expect(find.text('All plants'), findsNothing);
    await container.read(homeLayoutProvider.notifier).reset();
    await tester.pumpAndSettle();
    expect(find.text('All plants'), findsOneWidget);
  });

  testWidgets('HomeScreen navigates to Calendar via tab bar', (tester) async {
    await _pumpHome(tester);

    await tester.tap(find.widgetWithText(InkWell, 'Calendar'));
    await tester.pumpAndSettle();

    expect(find.text('This week'), findsOneWidget);
    expect(find.textContaining('Skip outdoor watering'), findsOneWidget);
  });

  testWidgets('HomeScreen builds without crash', (tester) async {
    await _pumpHome(tester, const ProviderScope(child: MaterialApp(home: HomeScreen())));
    expect(tester.takeException(), isNull);
  });
}
