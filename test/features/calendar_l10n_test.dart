import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/mock_plants.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/features/calendar/calendar_screen.dart';
import 'package:plantly_inventory/features/calendar/day_detail_sheet.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations_en.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations_ro.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_app.dart';

/// Device QA on a ro-RO Pixel 8 found the calendar still fully English:
/// header ranges, weekday/month symbols, the upcoming "Water · 24 min
/// overdue" rows and the day sheet. These tests pump the real screens under
/// `Locale('ro')` and assert on the rendered copy, plus unit-test the
/// relative-time phrases (Romanian few/other plural forms).
CareScheduleRow _sched(String id, int dueAtMs) => CareScheduleRow(
      id: id,
      tenantId: kDefaultTenantId,
      plantId: MockPlants.all.first.id,
      type: 'water',
      baseIntervalDays: 7,
      currentIntervalDays: 7,
      lastDoneAt: null,
      nextDueAt: dueAtMs,
      snoozeCount: 0,
      recentEventsJson: '[]',
      enabled: true,
      recurrenceMode: 'after_completion',
      notificationsMuted: false,
      updatedHlc: '0-0-t',
      deletedAt: null,
      deviceId: 't',
    );

Future<void> _pump(
  WidgetTester tester, {
  required Widget home,
  Locale locale = const Locale('ro'),
  List<CareScheduleRow> schedules = const [],
}) async {
  SharedPreferences.setMockInitialValues({'plantly_onboarded': true});
  tester.view.physicalSize = const Size(720, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))));

  await tester.pumpWidget(buildTestApp(
    overrides: [
      allSchedulesProvider.overrideWith((ref) => Stream.value(schedules)),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  ));
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

void main() {
  group('upcomingDueLabel · relative phrases', () {
    final ro = AppLocalizationsRo();
    final en = AppLocalizationsEn();

    test('Romanian few/other plural forms', () {
      expect(upcomingDueLabel(ro, const Duration(minutes: -24)), ('restant de 24 de minute', true));
      expect(upcomingDueLabel(ro, const Duration(minutes: -3)), ('restant de 3 minute', true));
      expect(upcomingDueLabel(ro, const Duration(minutes: -1)), ('restant de un minut', true));
      expect(upcomingDueLabel(ro, const Duration(hours: -2)), ('restant de 2 ore', true));
      expect(upcomingDueLabel(ro, const Duration(hours: -21)), ('restant de 21 de ore', true));
      expect(upcomingDueLabel(ro, const Duration(days: -1)), ('restant de o zi', true));
      expect(upcomingDueLabel(ro, const Duration(days: -25)), ('restant de 25 de zile', true));
      expect(upcomingDueLabel(ro, const Duration(minutes: 10)), ('în 10 minute', true));
      expect(upcomingDueLabel(ro, const Duration(minutes: 45)), ('în 45 de minute', false));
      expect(upcomingDueLabel(ro, const Duration(hours: 5)), ('în 5 ore', false));
      expect(upcomingDueLabel(ro, const Duration(days: 1, hours: 2)), ('mâine', false));
      expect(upcomingDueLabel(ro, const Duration(days: 2, hours: 1)), ('în 2 zile', false));
      expect(upcomingDueLabel(ro, const Duration(days: 30)), ('în 30 de zile', false));
    });

    test('English one/other plural forms', () {
      expect(upcomingDueLabel(en, const Duration(minutes: -24)), ('24 min overdue', true));
      expect(upcomingDueLabel(en, const Duration(hours: -1)), ('1 hour overdue', true));
      expect(upcomingDueLabel(en, const Duration(hours: -3)), ('3 hours overdue', true));
      expect(upcomingDueLabel(en, const Duration(days: -1)), ('1 day overdue', true));
      expect(upcomingDueLabel(en, const Duration(minutes: 1)), ('in 1 min', true));
      expect(upcomingDueLabel(en, const Duration(hours: 1)), ('in 1 hour', false));
      expect(upcomingDueLabel(en, const Duration(hours: 6)), ('in 6 hours', false));
      expect(upcomingDueLabel(en, const Duration(days: 1)), ('tomorrow', false));
      expect(upcomingDueLabel(en, const Duration(days: 4)), ('in 4 days', false));
    });

    test('never renders "0 min overdue"', () {
      expect(upcomingDueLabel(en, const Duration(seconds: -5)).$1, '1 min overdue');
    });
  });

  group('weekRangeLabel · locale-aware header', () {
    setUpAll(() async {
      await initializeDateFormatting('ro');
      await initializeDateFormatting('en');
    });

    test('same month puts the day range where the locale puts the day', () {
      final from = DateTime(2026, 9, 21);
      final to = DateTime(2026, 9, 27);
      expect(weekRangeLabel('en', from, to), 'Sep 21–27');
      expect(weekRangeLabel('ro', from, to), '21–27 sept.');
    });

    test('month boundary formats both ends', () {
      final from = DateTime(2026, 9, 28);
      final to = DateTime(2026, 10, 4);
      expect(weekRangeLabel('en', from, to), 'Sep 28 – Oct 4');
      expect(weekRangeLabel('ro', from, to), '28 sept. – 4 oct.');
    });
  });

  group('weekStartOf', () {
    test('respects the first weekday', () {
      final thu = DateTime(2026, 9, 24);
      expect(weekStartOf(thu, DateTime.monday), DateTime(2026, 9, 21));
      expect(weekStartOf(thu, DateTime.sunday), DateTime(2026, 9, 20));
      expect(weekStartOf(DateTime(2026, 9, 20), DateTime.sunday), DateTime(2026, 9, 20));
      expect(weekStartOf(DateTime(2026, 9, 21), DateTime.monday), DateTime(2026, 9, 21));
    });
  });

  group('CalendarScreen · Romanian locale', () {
    testWidgets('week view: weekday labels, free days and upcoming rows are Romanian', (tester) async {
      final now = DateTime.now();
      await _pump(
        tester,
        home: const CalendarScreen(),
        schedules: [
          _sched('s-overdue', now.subtract(const Duration(minutes: 24)).toUtc().millisecondsSinceEpoch),
          _sched('s-soon', now.add(const Duration(days: 2, hours: 1)).toUtc().millisecondsSinceEpoch),
        ],
      );

      // Romanian is Monday-first: the week rows start with LUN and end with DUM.
      expect(find.text('LUN'), findsOneWidget);
      expect(find.text('DUM'), findsOneWidget);
      expect(find.text('MON'), findsNothing);
      expect(find.text('Clear'), findsNothing);
      expect(find.text('Liber'), findsWidgets);

      // Upcoming rows: imperative verb + localized relative phrase.
      expect(find.text('Udă · restant de 24 de minute'), findsOneWidget);
      expect(find.text('Udă · în 2 zile'), findsOneWidget);
      expect(find.textContaining('overdue'), findsNothing);

      // Header + tooltips.
      expect(find.byTooltip('Anterior'), findsOneWidget);
      expect(find.byTooltip('Previous'), findsNothing);
      expect(find.text('URMĂTOARELE  ·  1'), findsOneWidget);
    });

    testWidgets('month grid uses Romanian narrow weekday symbols, Monday first', (tester) async {
      await _pump(tester, home: const CalendarScreen());
      await tester.tap(find.text('Lună'));
      await tester.pumpAndSettle();

      // L M M J V S D — two Ms (marți / miercuri), no W.
      expect(find.text('L'), findsOneWidget);
      expect(find.text('M'), findsNWidgets(2));
      expect(find.text('J'), findsOneWidget);
      expect(find.text('V'), findsOneWidget);
      expect(find.text('S'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
      expect(find.text('W'), findsNothing);
      expect(find.text('T'), findsNothing);
    });

    testWidgets('year grid uses Romanian month abbreviations', (tester) async {
      await _pump(tester, home: const CalendarScreen());
      await tester.tap(find.text('An'));
      await tester.pumpAndSettle();

      expect(find.text('ian.'), findsOneWidget);
      expect(find.text('mai'), findsOneWidget);
      expect(find.text('dec.'), findsOneWidget);
      expect(find.text('Jan'), findsNothing);
      expect(find.text('Dec'), findsNothing);
    });

    testWidgets('English month grid is Sunday-first (en_US)', (tester) async {
      await _pump(tester, home: const CalendarScreen(), locale: const Locale('en', 'US'));
      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();

      final labels = tester
          .widgetList<Text>(find.byWidgetPredicate((w) => w is Text && (w.data?.length ?? 0) == 1 && w.style?.fontSize == 10))
          .map((w) => w.data)
          .toList();
      expect(labels, ['S', 'M', 'T', 'W', 'T', 'F', 'S']);
    });
  });

  group('DayDetailSheet · Romanian locale', () {
    testWidgets('empty day: long weekday, full date and the empty hint', (tester) async {
      await _pump(
        tester,
        home: Scaffold(body: DayDetailSheet(day: DateTime(2026, 9, 24))),
      );

      expect(find.text('JOI'), findsOneWidget);
      expect(find.text('24 septembrie 2026'), findsOneWidget);
      expect(find.text('Nimic programat sau înregistrat în această zi.'), findsOneWidget);
      expect(find.text('THURSDAY'), findsNothing);
      expect(find.text('September 24, 2026'), findsNothing);
    });

    testWidgets('scheduled day: PROGRAMAT header with Gata / Amână actions', (tester) async {
      final due = DateTime(2026, 9, 24, 9, 30);
      await _pump(
        tester,
        home: Scaffold(body: DayDetailSheet(day: DateTime(2026, 9, 24))),
        schedules: [_sched('s-day', due.toUtc().millisecondsSinceEpoch)],
      );

      expect(find.text('PROGRAMAT'), findsOneWidget);
      expect(find.text('Gata'), findsOneWidget);
      expect(find.text('Amână'), findsOneWidget);
      expect(find.text('SCHEDULED'), findsNothing);
      expect(find.text('Done'), findsNothing);
      expect(find.text('Snooze'), findsNothing);
    });
  });
}
