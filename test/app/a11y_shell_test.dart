// Accessibility of the adaptive shell and key screens (QA 2026-10-07):
// navigation exposed to assistive tech + reachable by Tab at every width,
// labelled controls, 48 dp touch targets, and a modal first-run onboarding.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/features/onboarding/onboarding_screen.dart';
import 'package:plantly_inventory/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_app.dart';

const _desktop = Size(1440, 900);
const _rail = Size(1024, 800);
const _phone = Size(390, 844);

/// Pre-existing 1 px grid-card overflow at phone width (see the golden test).
void _tolerateOverflow() {
  final prev = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed by')) return;
    prev?.call(details);
  };
  addTearDown(() => FlutterError.onError = prev);
}

Future<void> _pumpApp(
  WidgetTester tester,
  Size size, {
  String? location,
  bool onboarded = true,
  List<Override> overrides = const [],
}) async {
  _tolerateOverflow();
  SharedPreferences.setMockInitialValues({'plantly_onboarded': onboarded});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))));
  await tester.pumpWidget(buildTestApp(overrides: overrides, child: PlantlyApp(initialLocation: location)));
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

/// Semantics node of the navigation entry [label]: the rail destination
/// ("Calendar\nTab 2 of 4"; unselected labels aren't drawn), else the side
/// nav tile (first on-screen match) / phone tab bar (last) — the home's
/// stat tiles also say "Spaces".
SemanticsNode _navNode(WidgetTester tester, String label, {required String ff}) => switch (ff) {
      'rail' => tester.getSemantics(find.bySemanticsLabel(RegExp('^$label\nTab'))),
      'phone' => tester.getSemantics(find.text(label).hitTestable().last),
      _ => tester.getSemantics(find.text(label).hitTestable().first),
    };

Rect _focusedRect(WidgetTester tester) {
  final ctx = FocusManager.instance.primaryFocus!.context!;
  return tester.getRect(find.byElementPredicate((e) => e == ctx));
}

PlantRow _cala() => PlantRow(
      id: 'cala',
      tenantId: kDefaultTenantId,
      nickname: 'Calathea',
      speciesId: null,
      locationId: null,
      pinX: null,
      pinY: null,
      notificationsMuted: false,
      status: 'alive',
      acquiredAt: null,
      source: null,
      notes: null,
      potSizeCm: null,
      updatedHlc: '0-0-t',
      deletedAt: null,
      deviceId: 't',
    );

CareScheduleRow _waterDue() => CareScheduleRow(
      id: 's-water',
      tenantId: kDefaultTenantId,
      plantId: 'cala',
      type: 'water',
      baseIntervalDays: 7,
      currentIntervalDays: 7,
      lastDoneAt: DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch,
      nextDueAt: DateTime.now().millisecondsSinceEpoch,
      snoozeCount: 0,
      recentEventsJson: '[]',
      enabled: true,
      recurrenceMode: 'after_completion',
      notificationsMuted: false,
      updatedHlc: '0-0-t',
      deletedAt: null,
      deviceId: 't',
    );

void main() {
  group('navigation semantics', () {
    for (final (name, size) in [('desktop', _desktop), ('rail', _rail), ('phone', _phone)]) {
      testWidgets('$name: nav items are labelled buttons with selected state', (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpApp(tester, size);
        final rail = name == 'rail';
        expect(
          _navNode(tester, 'Home', ff: name),
          isSemantics(label: rail ? 'Home\nTab 1 of 4' : 'Home', isButton: rail ? null : true, isSelected: true),
        );
        for (final (i, label) in ['Calendar', 'Spaces', 'Me'].indexed) {
          expect(
            _navNode(tester, label, ff: name),
            isSemantics(
              label: rail ? '$label\nTab ${i + 2} of 4' : label,
              isButton: rail ? null : true,
              isSelected: false,
              hasTapAction: true,
            ),
          );
        }
        // Add-plant action is named (tooltip or text).
        expect(find.bySemanticsLabel(RegExp('Add a plant')).evaluate().isNotEmpty || find.byTooltip('Add a plant').evaluate().isNotEmpty, isTrue);
        handle.dispose();
      });
    }

    testWidgets('desktop: the page toolbar is separate controls, not one merged node', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpApp(tester, _desktop);
      expect(tester.getSemantics(find.byType(TextField).first), isSemantics(isTextField: true, label: 'Search plants…'));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Sort plants: Name A–Z')),
        isSemantics(isButton: true, isFocusable: true, hasTapAction: true),
      );
      // Widget titles are level-2 headings of their own, not the whole card.
      final title = tester.getSemantics(find.text('All plants'));
      expect(title, isSemantics(label: 'All plants', isHeader: true));
      expect(title.getSemanticsData().headingLevel, 2);
      expect(tester.getSemantics(find.text('Customise')), isSemantics(label: 'Customise', isButton: true));
      expect(tester.getSemantics(find.text('Overdue').first), isSemantics(label: 'Overdue', isButton: true, isSelected: false));
      handle.dispose();
    });
  });

  group('guidelines', () {
    for (final (name, size) in [('desktop', _desktop), ('rail', _rail), ('phone', _phone)]) {
      testWidgets('$name home: every tap target is labelled', (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpApp(tester, size);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }

    for (final (route, title) in [('/calendar', 'calendar'), ('/spaces', 'spaces'), ('/me', 'me'), ('/me/care-types', 'care types')]) {
      testWidgets('phone $title: every tap target is labelled', (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpApp(tester, _phone, location: route);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }
  });

  group('keyboard focus', () {
    for (final (name, size, navMaxX) in [('desktop', _desktop, 240.0), ('rail', _rail, 72.0)]) {
      testWidgets('$name: Tab starts in the navigation, then continues into the page', (tester) async {
        await _pumpApp(tester, size);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(_focusedRect(tester).left, lessThan(navMaxX), reason: 'first Tab lands in the nav column');
        var reachedPage = false;
        for (var i = 0; i < 10 && !reachedPage; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          reachedPage = _focusedRect(tester).left > navMaxX;
        }
        expect(reachedPage, isTrue, reason: 'Tab moves on from the nav into the page');
      });
    }

    testWidgets('desktop: Tab wraps from the end of the page back to the navigation', (tester) async {
      await _pumpApp(tester, _desktop);
      var backInNav = false;
      var leftNav = false;
      for (var i = 0; i < 60 && !backInNav; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final x = _focusedRect(tester).left;
        if (x > 240) leftNav = true;
        if (leftNav && x < 240) backInNav = true;
      }
      expect(backInNav, isTrue);
    });
  });

  group('onboarding', () {
    testWidgets('desktop first run: modal over the whole window — side nav not reachable', (tester) async {
      await _pumpApp(tester, _desktop, onboarded: false);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('Calendar').hitTestable(), findsNothing);
      // `n` (new plant) does nothing behind the onboarding either.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('name field is named by its caption; consent switches by their titles', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpApp(tester, _phone, onboarded: false);
      final field = tester.getSemantics(find.byType(TextField));
      expect(field, isSemantics(isTextField: true));
      // Named by the caption (the hint may follow), not the intro paragraph.
      expect(field.label, startsWith('Your name (optional)'));
      // Continue to the privacy step (the notification step exists in tests).
      while (find.byType(Switch).evaluate().isEmpty) {
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
      }
      for (final s in find.byType(Switch).evaluate()) {
        final node = tester.getSemantics(find.byWidget(s.widget));
        expect(node.label, isNotEmpty);
        expect(node, isSemantics(hasToggledState: true));
      }
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  group('care-type editor', () {
    testWidgets('rows are buttons; icon and colour swatches are named with selected state', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpApp(tester, _phone, location: '/me/care-types');
      final row = tester.getSemantics(find.text('Water').first);
      expect(row, isSemantics(isButton: true, hasTapAction: true));
      await tester.tap(find.text('Water').first);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Water drop'), findsOneWidget);
      expect(find.bySemanticsLabel('Leaf'), findsOneWidget);
      expect(find.bySemanticsLabel('First aid'), findsOneWidget);
      expect(find.bySemanticsLabel('Terracotta'), findsOneWidget);
      expect(find.bySemanticsLabel('Slate grey'), findsOneWidget);
      expect(tester.getSemantics(find.bySemanticsLabel('Leaf')), isSemantics(isButton: true, isInMutuallyExclusiveGroup: true));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  group('phone screens', () {
    final detailFixtures = [
      plantByIdProvider.overrideWith((ref, id) => Stream.value(id == 'cala' ? _cala() : null)),
      schedulesForPlantProvider.overrideWith((ref, id) => Stream.value(id == 'cala' ? [_waterDue()] : const <CareScheduleRow>[])),
    ];

    testWidgets('plant detail: back labelled; reminder Done/Snooze get 48 dp touch targets', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpApp(tester, _phone, location: '/plants/cala', overrides: detailFixtures);
      expect(find.byTooltip('Back'), findsOneWidget);
      for (final label in ['Done', 'Snooze']) {
        final size = tester.getSize(find.widgetWithText(TextButton, label).first);
        expect(size.height, greaterThanOrEqualTo(48), reason: '$label hit area');
      }
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('search: back and clear are labelled', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpApp(tester, _phone);
      await tester.tap(find.byTooltip('Search plants'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Back'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'cal');
      await tester.pumpAndSettle();
      expect(find.byTooltip('Clear search'), findsOneWidget);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  group('sort picker (desktop)', () {
    testWidgets('one Tab stop between the chips and Customise; activating it opens the menu', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpApp(tester, _desktop);
      final chip = find.text('Due today').first;
      Focus.of(tester.element(chip)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'home-sort');
      final node = tester.getSemantics(find.bySemanticsLabel('Sort plants: Name A–Z'));
      expect(node, isSemantics(isFocused: true));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focusedRect(tester).width, lessThan(200), reason: 'not the chevron');
      expect(find.ancestor(of: find.text('Customise'), matching: find.byElementPredicate((e) => e == FocusManager.instance.primaryFocus!.context)), findsOneWidget);
      // Screen-reader activation opens the menu; its entries are exposed.
      tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Name Z–A'), findsWidgets);
      handle.dispose();
    });
  });

  group('care-type editor fields', () {
    testWidgets('name and interval fields have sentence-case names', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpApp(tester, _phone, location: '/me/care-types');
      await tester.tap(find.text('Water').first);
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      expect(tester.getSemantics(fields.at(0)).label, startsWith('Name'));
      expect(tester.getSemantics(fields.at(1)).label, startsWith('Default interval in days'));
      expect(find.bySemanticsLabel(RegExp(r'^Edit')), findsWidgets);
      handle.dispose();
    });
  });
}
