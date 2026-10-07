import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/care_types.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/features/activity/activity_screen.dart';
import 'package:plantly_inventory/features/home/widgets/activity_widget.dart';
import 'package:plantly_inventory/features/home/widgets/overdue_widget.dart';
import 'package:plantly_inventory/features/home/widgets/today_widget.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/shared/care_type_labels.dart';
import 'package:plantly_inventory/theme/tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';

/// Issue #16 follow-up — Today / Overdue / Activity (widget + screen) picked
/// row icons from hard-coded `_iconFor` switches, so an icon the user chose
/// for a care type (Me → Care types) and every custom type's icon were
/// ignored; Today / Overdue even drew a water drop for unknown keys. All of
/// them now resolve through the registry (`careKeyIcon` / `CareType.icon`)
/// with one shared fallback, [kUnknownCareTypeIcon].

const _waterIcon = Icons.spa_outlined; // user re-iconed the "water" built-in
const _neemIcon = Icons.bug_report_outlined; // custom type's own icon

String _registry() => json.encode([
      for (final t in kBuiltInCareTypes)
        (t.key == 'water' ? t.copyWith(iconCode: _waterIcon.codePoint) : t).toJson(),
      CareType(key: 'neem_spray', label: 'Neem', iconCode: _neemIcon.codePoint, defaultIntervalDays: 14).toJson(),
    ]);

/// `ghost` is not in the registry (deleted custom type / legacy row).
const _types = ['water', 'neem_spray', 'ghost'];

CareScheduleRow _schedule(String type, Duration due) => CareScheduleRow(
      id: 's-$type',
      tenantId: kDefaultTenantId,
      plantId: 'bob',
      type: type,
      baseIntervalDays: 7,
      currentIntervalDays: 7,
      lastDoneAt: null,
      nextDueAt: DateTime.now().add(due).millisecondsSinceEpoch,
      snoozeCount: 0,
      recentEventsJson: '[]',
      enabled: true,
      recurrenceMode: 'after_completion',
      notificationsMuted: false,
      updatedHlc: '0-0-t',
      deletedAt: null,
      deviceId: 't',
    );

CareEventRow _event(String type, int i) => CareEventRow(
      id: 'e-$type',
      tenantId: kDefaultTenantId,
      plantId: 'bob',
      type: type,
      doneAt: DateTime.now().subtract(Duration(hours: i + 1)).millisecondsSinceEpoch,
      notes: null,
      dose: null,
      product: null,
      photoSha: null,
      updatedHlc: '0-0-t',
      deletedAt: null,
      deviceId: 't',
    );

Future<void> _pump(WidgetTester tester, Widget body, {Duration due = Duration.zero}) async {
  SharedPreferences.setMockInitialValues({'plantly_care_types': _registry(), 'plantly_onboarded': true});
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(buildTestApp(
    overrides: [
      dueBeforeEodProvider.overrideWith((ref) => Stream.value([for (final t in _types) _schedule(t, due)])),
      recentCareEventsProvider.overrideWith((ref) => Stream.value([
            for (var i = 0; i < _types.length; i++) _event(_types[i], i),
          ])),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: body is ActivityScreen ? body : Scaffold(body: SingleChildScrollView(child: body)),
    ),
  ));
  await tester.pumpAndSettle();
}

void _expectRegistryIcons() {
  expect(find.byIcon(_waterIcon), findsOneWidget, reason: 'user-chosen icon for the water built-in');
  expect(find.byIcon(Icons.water_drop_outlined), findsNothing, reason: 'hard-coded built-in icon leaked');
  expect(find.byIcon(_neemIcon), findsOneWidget, reason: 'custom type icon');
  expect(find.byIcon(kUnknownCareTypeIcon), findsOneWidget, reason: 'unknown key fallback');
}

void main() {
  test('careKeyIcon: registry icon, custom icon, shared fallback for unknown keys', () {
    final types = [
      for (final t in kBuiltInCareTypes) t.key == 'water' ? t.copyWith(iconCode: _waterIcon.codePoint) : t,
      CareType(key: 'neem_spray', label: 'Neem', iconCode: _neemIcon.codePoint, defaultIntervalDays: 14),
      const CareType(key: 'bad_icon', label: 'Bad', iconCode: 0, defaultIntervalDays: 7),
    ];
    expect(careKeyIcon(types, 'water'), _waterIcon);
    expect(careKeyIcon(types, 'mist'), Icons.bubble_chart_outlined);
    expect(careKeyIcon(types, 'neem_spray'), _neemIcon);
    expect(careKeyIcon(types, 'ghost'), kUnknownCareTypeIcon);
    expect(careKeyIcon(types, ''), kUnknownCareTypeIcon);
    expect(careKeyIcon(types, 'bad_icon'), kUnknownCareTypeIcon, reason: 'codepoint outside the palette');
  });

  testWidgets('Today widget uses registry icons', (tester) async {
    await _pump(tester, const TodayWidget(surface: PlantlySurface.light), due: const Duration(hours: 1));
    _expectRegistryIcons();
  });

  testWidgets('Overdue widget uses registry icons', (tester) async {
    await _pump(tester, const OverdueWidget(surface: PlantlySurface.light), due: const Duration(days: -1));
    _expectRegistryIcons();
  });

  testWidgets('Activity widget uses registry icons', (tester) async {
    await _pump(tester, const ActivityWidget(surface: PlantlySurface.light));
    _expectRegistryIcons();
  });

  testWidgets('Activity screen uses registry icons', (tester) async {
    await _pump(tester, const ActivityScreen());
    _expectRegistryIcons();
  });
}
