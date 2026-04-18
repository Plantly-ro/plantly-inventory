import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/main.dart';

void main() {
  testWidgets('Home screen renders greeting + stats tiles', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PlantlyApp()));
    await tester.pump();

    expect(find.text('Good morning, Ana'), findsOneWidget);
    expect(find.text('Friday · April 18'), findsOneWidget);

    for (final label in ['Overdue', 'Due today', 'Plants', 'Spaces']) {
      expect(find.text(label), findsOneWidget,
          reason: 'missing stats tile for $label');
    }
    for (final value in ['2', '3', '24', '6']) {
      expect(find.text(value), findsOneWidget,
          reason: 'missing stats value $value');
    }
  });

  testWidgets('Theme toggle flips ThemeMode', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PlantlyApp()));
    await tester.pump();

    expect(find.text('Use dark theme'), findsOneWidget);
    await tester.tap(find.text('Use dark theme'));
    await tester.pumpAndSettle();

    expect(find.text('Use light theme'), findsOneWidget);
  });
}
