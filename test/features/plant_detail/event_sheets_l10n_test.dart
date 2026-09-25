import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/mock_plants.dart';
import 'package:plantly_inventory/features/plant_detail/add_reminder_sheet.dart';
import 'package:plantly_inventory/features/plant_detail/log_event_sheet.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';

/// Device QA (ro-RO Pixel 8): the Log-event "CÂND" value and the
/// Add-reminder preview still printed English dates ("Sep 25, 2026 · 12:22")
/// and an English "NEXT 3 REMINDERS" header. Both now go through intl for
/// the active locale and the plural ARB key.
final _englishMonth = RegExp(r'\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\b');
// "25 sept. 2026 · 12:22" / "25 mai 2026 · 09:05"
final _roDateTime = RegExp(r'^\d{1,2} [a-zăâîșț]+\.? \d{4} · \d{2}:\d{2}$');
// "sâm., 26 sept. · 12:22" / "joi, 1 mai · 08:00"
final _roWeekdayDateTime = RegExp(r'^[a-zăâîșț]+\.?, \d{1,2} [a-zăâîșț]+\.? · \d{2}:\d{2}$');

Future<void> _pump(WidgetTester tester, Widget sheet) async {
  SharedPreferences.setMockInitialValues({'plantly_onboarded': true});
  tester.view.physicalSize = const Size(720, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))));
  await tester.pumpWidget(buildTestApp(
    child: MaterialApp(
      locale: const Locale('ro'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: sheet)),
    ),
  ));
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

Iterable<String> _texts(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '').where((s) => s.isNotEmpty);

void main() {
  testWidgets('LogEventSheet: past-tense chips + Romanian CÂND date', (tester) async {
    await _pump(tester, LogEventSheet(plantId: MockPlants.all.first.id));

    expect(find.text('CÂND'), findsOneWidget);
    // Past-tense chips via careTypePastLabel, not the seeded English label.
    expect(find.text('Udată'), findsOneWidget);
    expect(find.text('Fertilizată'), findsOneWidget);
    expect(find.text('Water'), findsNothing);
    expect(find.text('Watered'), findsNothing);

    final dates = _texts(tester).where(_roDateTime.hasMatch).toList();
    expect(dates, hasLength(1), reason: 'CÂND should render one "25 sept. 2026 · 12:22"-style value');
    expect(_texts(tester).where(_englishMonth.hasMatch), isEmpty);
  });

  testWidgets('AddReminderSheet: plural header + Romanian preview dates', (tester) async {
    await _pump(tester, AddReminderSheet(plantId: MockPlants.all.first.id));

    // Default mode repeats, so the preview lists three firings.
    expect(find.text('URMĂTOARELE 3 MEMENTO-URI'), findsOneWidget);
    expect(find.text('NEXT 3 REMINDERS'), findsNothing);

    final previews = _texts(tester).where(_roWeekdayDateTime.hasMatch).toList();
    expect(previews, hasLength(3), reason: 'three "sâm., 26 sept. · 12:22"-style rows');
    // First-due field: "26 sept. 2026 · 12:22".
    expect(_texts(tester).where(_roDateTime.hasMatch), hasLength(1));
    expect(_texts(tester).where(_englishMonth.hasMatch), isEmpty);
  });
}
