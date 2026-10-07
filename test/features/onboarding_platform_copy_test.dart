import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/cloud/account_name.dart';
import 'package:plantly_inventory/cloud/collections.dart';
import 'package:plantly_inventory/config/plantly_features.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/features/onboarding/onboarding_screen.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/notifications/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_app.dart';

/// Onboarding copy is true for where the collection lives: the Android app
/// without sync ("Everything lives on your phone"), the Android app with
/// Inventory Cloud sync running, and the web app (always cloud). The web
/// has no OS notifications, so its flow skips the permission step.
void main() {
  const bodyKey = ValueKey('onb-welcome-body');

  Future<void> pumpOnboarding(
    WidgetTester tester, {
    List<Override> overrides = const [],
    Locale locale = const Locale('en'),
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(buildTestApp(
      overrides: [
        accountGreetingNameProvider.overrideWith((ref) async => null),
        ...overrides,
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const OnboardingScreen())),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  String body(WidgetTester tester) => tester.widget<Text>(find.byKey(bodyKey)).data!;

  final web = <Override>[
    webPlatformProvider.overrideWithValue(true),
    notificationServiceProvider.overrideWith((ref) => UnsupportedNotificationService()),
  ];

  group('Android, no cloud sync', () {
    testWidgets('welcome says everything lives on the phone; three steps incl. notifications', (tester) async {
      await pumpOnboarding(tester);
      expect(body(tester), contains('Everything lives on your phone.'));
      expect(find.byKey(const ValueKey('onb-progress-2')), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('Plant reminders'), findsOneWidget);
      expect(find.textContaining('no push server involved'), findsOneWidget);
      expect(find.text('Grant'), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('Help us improve'), findsOneWidget);
      expect(find.textContaining('never include plant data or photos'), findsOneWidget);
      expect(find.textContaining('never leaves your device'), findsNothing);
      expect(find.text('Start using Plantly'), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsNothing);
    });
  });

  group('Android, cloud sync running', () {
    testWidgets('welcome says the collection syncs to the plantly.ro account', (tester) async {
      await pumpOnboarding(tester, overrides: [activeCollectionIdProvider.overrideWithValue('col-1')]);
      expect(body(tester), contains('syncs to your plantly.ro account'));
      expect(body(tester), isNot(contains('Everything lives on your phone')));
      // Notifications are still local on Android: the step stays.
      expect(find.byKey(const ValueKey('onb-progress-2')), findsOneWidget);
    });

    testWidgets('ro copy', (tester) async {
      await pumpOnboarding(tester,
          overrides: [activeCollectionIdProvider.overrideWithValue('col-1')], locale: const Locale('ro'));
      expect(body(tester), contains('se sincronizează cu contul tău plantly.ro'));
    });
  });

  testWidgets('Android, sync paused (linked, not syncing): local copy, no "syncs" claim', (tester) async {
    await pumpOnboarding(tester, overrides: [
      cloudEnabledProvider.overrideWithValue(true),
      activeCollectionIdProvider.overrideWithValue(null),
      homeCollectionIdProvider.overrideWithValue('col-1'),
    ]);
    expect(body(tester), contains('Everything lives on your phone.'));
    expect(body(tester), isNot(contains('syncs')));
  });

  group('web', () {
    testWidgets('welcome says the collection is in the plantly.ro account, never "your phone"', (tester) async {
      await pumpOnboarding(tester, overrides: web);
      expect(body(tester), contains('saved in your plantly.ro account'));
      expect(body(tester), isNot(contains('phone')));
      expect(body(tester), isNot(contains('offline')));
    });

    testWidgets('skips the notification step: two-segment progress, welcome → privacy → done', (tester) async {
      await pumpOnboarding(tester, overrides: web);
      expect(find.byKey(const ValueKey('onb-progress-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('onb-progress-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('onb-progress-2')), findsNothing);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('Plant reminders'), findsNothing);
      expect(find.text('Help us improve'), findsOneWidget);
      expect(find.text('Start using Plantly'), findsOneWidget);
      // Both segments filled on the last step.
      final last = tester.widget<Container>(find.byKey(const ValueKey('onb-progress-1')));
      final first = tester.widget<Container>(find.byKey(const ValueKey('onb-progress-0')));
      expect((last.decoration! as BoxDecoration).color, (first.decoration! as BoxDecoration).color);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('plantly_onboarded'), isTrue);
    });

    testWidgets('ro copy', (tester) async {
      await pumpOnboarding(tester, overrides: web, locale: const Locale('ro'));
      expect(body(tester), contains('Colecția ta e salvată în contul tău plantly.ro'));
      expect(body(tester), isNot(contains('telefon')));
    });
  });
}
