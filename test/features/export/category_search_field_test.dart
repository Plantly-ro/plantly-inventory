import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/features/export/category_search_field.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/marketplace/plantly_api.dart';
import 'package:plantly_inventory/theme/tokens.dart';

void main() {
  final hits = [
    const CategoryHit(id: 'c1', slug: 'monstera-deliciosa', name: 'Monstera deliciosa', path: 'Plants › Monstera deliciosa', score: 0.9),
    const CategoryHit(id: 'c2', slug: 'monstera-adansonii', name: 'Monstera adansonii', path: 'Plants › Monstera adansonii', score: 0.4),
  ];

  Widget host({
    required Future<List<CategoryHit>> Function(String, String) search,
    required ValueChanged<CategoryHit?> onSelected,
    String? selected,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CategorySearchField(
          search: search,
          lang: 'en',
          surface: PlantlySurface.light,
          selected: selected,
          onSelected: onSelected,
        ),
      ),
    );
  }

  testWidgets('debounces 300 ms and issues one request for rapid typing', (tester) async {
    final queries = <String>[];
    await tester.pumpWidget(host(
      search: (q, lang) async {
        queries.add('$q/$lang');
        return hits;
      },
      onSelected: (_) {},
    ));
    final field = find.byKey(const Key('category-search'));
    await tester.enterText(field, 'mo');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(field, 'mon');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(field, 'monstera');
    expect(queries, isEmpty);
    await tester.pump(const Duration(milliseconds: 299));
    expect(queries, isEmpty);
    await tester.pump(const Duration(milliseconds: 2));
    await tester.pumpAndSettle();
    expect(queries, ['monstera/en']);
    expect(find.byKey(const Key('category-results')), findsOneWidget);
    expect(find.text('Plants › Monstera deliciosa'), findsOneWidget);
  });

  testWidgets('queries shorter than 2 chars never hit the API', (tester) async {
    var calls = 0;
    await tester.pumpWidget(host(search: (q, l) async {
      calls++;
      return hits;
    }, onSelected: (_) {}));
    await tester.enterText(find.byKey(const Key('category-search')), 'm');
    await tester.pump(const Duration(milliseconds: 400));
    expect(calls, 0);
  });

  testWidgets('tapping a hit emits it, clears the results and the text', (tester) async {
    CategoryHit? picked;
    await tester.pumpWidget(host(search: (q, l) async => hits, onSelected: (h) => picked = h));
    await tester.enterText(find.byKey(const Key('category-search')), 'monstera');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('category-hit-c2')));
    await tester.pumpAndSettle();
    expect(picked?.id, 'c2');
    expect(find.byKey(const Key('category-results')), findsNothing);
    expect((tester.widget(find.byKey(const Key('category-search'))) as TextField).controller!.text, isEmpty);
  });

  testWidgets('shows the selected path and clears via the × control', (tester) async {
    CategoryHit? last = hits.first;
    await tester.pumpWidget(host(
      search: (q, l) async => hits,
      selected: 'Plants › Monstera deliciosa',
      onSelected: (h) => last = h,
    ));
    expect(find.byKey(const Key('category-selected')), findsOneWidget);
    await tester.tap(find.descendant(of: find.byKey(const Key('category-selected')), matching: find.byIcon(Icons.close)));
    expect(last, isNull);
  });

  testWidgets('empty result shows "no results"; failure shows the error copy', (tester) async {
    await tester.pumpWidget(host(search: (q, l) async => const [], onSelected: (_) {}));
    await tester.enterText(find.byKey(const Key('category-search')), 'zzzz');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('No matching category — try another word'), findsOneWidget);

    await tester.pumpWidget(host(search: (q, l) async => throw Exception('offline'), onSelected: (_) {}));
    // Different text: re-entering the same value would not fire onChanged.
    await tester.enterText(find.byKey(const Key('category-search')), 'yyyy');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.textContaining("Couldn't reach plantly.ro"), findsOneWidget);
  });
}
