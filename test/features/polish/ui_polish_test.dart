// QA 2026-10-07 UI polish: large-font overflow (a), controllers disposed
// after the exit animation (b), add-plant discard confirm (e), empty-grid
// copy (h), not-found page (i).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/providers.dart' show appContextProvider;
import 'package:plantly_inventory/features/home/add_plant_sheet.dart';
import 'package:plantly_inventory/features/home/filter.dart';
import 'package:plantly_inventory/features/home/widgets/grid_widget.dart';
import 'package:plantly_inventory/features/home/widgets/stats_widget.dart';
import 'package:plantly_inventory/features/me/care_types_screen.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations_en.dart';
import 'package:plantly_inventory/main.dart';
import 'package:plantly_inventory/theme/tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';

Widget _app(Widget home, {double textScale = 1.0, Locale locale = const Locale('en'), List<Override> overrides = const []}) {
  return buildTestApp(
    overrides: overrides,
    child: MaterialApp(
      theme: PlantlyApp.buildTheme(Brightness.light),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: home,
    ),
  );
}

Future<void> _phone(WidgetTester tester, {Size size = const Size(360, 780)}) async {
  SharedPreferences.setMockInitialValues({'plantly_onboarded': true});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))));
}

/// Builds [child] once the app context (database, repositories) is up —
/// AddPlantSheet reads repositories in build.
class _Ready extends ConsumerWidget {
  const _Ready(this.child);
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(appContextProvider).hasValue ? child : const SizedBox.shrink();
}

Future<void> _settleReady(WidgetTester tester) async {
  for (var i = 0; i < 50; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    if (find.byType(_Ready).evaluate().isEmpty) break;
    final el = find.byType(_Ready).evaluate().first;
    if (ProviderScope.containerOf(el).read(appContextProvider).hasValue) break;
  }
  await tester.pumpAndSettle();
}

void main() {
  group('(a) large font on a 360 dp phone', () {
    testWidgets('stats tiles + plant grid + section titles: no overflow at text scale 1.3 (ro)', (tester) async {
      await _phone(tester);
      await tester.pumpWidget(_app(
        const Scaffold(
          body: SingleChildScrollView(
            child: Column(children: [
              StatsWidget(surface: PlantlySurface.light),
              GridWidget(surface: PlantlySurface.light),
            ]),
          ),
        ),
        textScale: 1.3,
        locale: const Locale('ro'),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'no RenderFlex overflow');
      // "Toate plantele" fits next to its count — not "Toate plan…".
      final title = tester.renderObject<RenderParagraph>(find.text('Toate plantele'));
      expect(title.didExceedMaxLines, isFalse);
    });

    testWidgets('plant cards: wide tiles keep the 0.78 ratio; narrow ones grow to fit their text', (tester) async {
      await _phone(tester, size: const Size(390, 844));
      await tester.pumpWidget(_app(const Scaffold(body: SingleChildScrollView(child: GridWidget(surface: PlantlySurface.light)))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'no overflow at 390 dp, default font');
      final ctx = tester.element(find.byType(GridWidget));
      final wide = plantGridDelegate(ctx, width: 900, columns: 4, spacing: 12, desktop: true) as SliverGridDelegateWithFixedCrossAxisCount;
      expect(wide.childAspectRatio, 0.78);
      expect(wide.mainAxisExtent, isNull);
      final narrow = plantGridDelegate(ctx, width: 320, columns: 2, spacing: 10, desktop: false) as SliverGridDelegateWithFixedCrossAxisCount;
      expect(narrow.mainAxisExtent, greaterThan(155 / 0.78));
    });

    testWidgets('add-plant sheet with the keyboard up: the Add button stays visible', (tester) async {
      await _phone(tester, size: const Size(360, 640));
      await tester.pumpWidget(_app(
        Builder(builder: (context) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(viewInsets: const EdgeInsets.only(bottom: 300)),
            child: const Scaffold(body: Align(alignment: Alignment.bottomCenter, child: _Ready(AddPlantSheet()))),
          );
        }),
        textScale: 1.3,
      ));
      await _settleReady(tester);
      expect(tester.takeException(), isNull);
      final button = tester.getRect(find.widgetWithText(FilledButton, AppLocalizationsEn().addPlantSubmit));
      expect(button.bottom, lessThanOrEqualTo(640 - 300), reason: 'above the keyboard');
    });
  });

  group('(b) dialogs / sheets own their controllers', () {
    testWidgets('care-type sheet: save and cancel close without "used after dispose"; no overflow on a small phone', (tester) async {
      await _phone(tester, size: const Size(360, 640));
      await tester.pumpWidget(_app(const CareTypesScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'sheet fits (scrolls) — no 7.5 px overflow');
      await tester.enterText(find.byType(TextField).first, 'Hydrate');
      await tester.pump();
      await tester.tap(find.text(AppLocalizationsEn().cancel));
      // Pump through the exit animation frame by frame: a disposed
      // controller would throw while the TextField still rebuilds.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('(e) add plant: back on a half-filled sheet asks first', () {
    Future<void> openSheet(WidgetTester tester) async {
      await _phone(tester);
      await tester.pumpWidget(_app(_Ready(Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const AddPlantSheet(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ))));
      await _settleReady(tester);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('empty sheet: back closes at once', (tester) async {
      await openSheet(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AddPlantSheet), findsNothing);
    });

    testWidgets('typed a name: back → confirm; Keep editing keeps it; Discard closes', (tester) async {
      await openSheet(tester);
      await tester.enterText(find.byType(TextField).first, 'Fern');
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('add-plant-discard-dialog')), findsOneWidget);
      await tester.tap(find.text(AppLocalizationsEn().addPlantDiscardKeep));
      await tester.pumpAndSettle();
      expect(find.byType(AddPlantSheet), findsOneWidget);
      expect(find.text('Fern'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-plant-discard-confirm')));
      await tester.pumpAndSettle();
      expect(find.byType(AddPlantSheet), findsNothing);
    });
  });

  test('(h) empty-grid copy fits the reason and the platform', () {
    final t = AppLocalizationsEn();
    String msg({PlantFilter filter = PlantFilter.all, String query = '', bool narrowed = false, bool desktop = false, bool canEdit = true}) =>
        emptyGridMessage(t, filter: filter, query: query, narrowed: narrowed, desktop: desktop, canEdit: canEdit);
    expect(msg(query: 'fic'), t.searchNoMatch('fic'), reason: 'a search, not "no plants yet"');
    expect(msg(narrowed: true), t.homeGridEmptyFiltered);
    expect(msg(desktop: true), contains('sidebar'));
    expect(msg(desktop: true), isNot(contains('+ button')));
    expect(msg(), t.homeGridEmptyAll);
    expect(msg(canEdit: false), t.homeGridEmptyViewer);
    expect(msg(filter: PlantFilter.overdue), t.nothingOverdue);
  });

  testWidgets('(i) unknown URL → localized not-found page with a way Home', (tester) async {
    await _phone(tester, size: const Size(430, 900));
    await tester.pumpWidget(buildTestApp(child: const PlantlyApp(initialLocation: '/locations-nope')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('not-found')), findsOneWidget);
    expect(find.textContaining('GoException'), findsNothing);
    await tester.tap(find.byKey(const Key('not-found-home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('not-found')), findsNothing);
  });
}
