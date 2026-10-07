import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/cloud/account_name.dart';
import 'package:plantly_inventory/features/onboarding/onboarding_screen.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_app.dart';

/// Onboarding step 1 prefills the name from the signed-in plantly.ro account
/// (web: the user signed in before onboarding ever showed) without ever
/// clobbering what the user typed, and says where the value came from.
void main() {
  const fromAccountKey = ValueKey('onb-name-from-account');

  // Created inside each test body: a Completer made in setUp() lives in the
  // real zone and would resolve outside the widget tester's fake clock.
  late Completer<String?> account;

  Future<void> pumpOnboarding(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
    account = Completer<String?>();
    SharedPreferences.setMockInitialValues(prefs);
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(buildTestApp(
      overrides: [accountGreetingNameProvider.overrideWith((ref) => account.future)],
      child: MaterialApp(
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

  String fieldText(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField)).controller!.text;

  Future<void> resolve(WidgetTester tester, String? name) async {
    account.complete(name);
    await tester.pumpAndSettle();
  }

  testWidgets('account name arriving after the screen is up fills the empty field, with the helper', (tester) async {
    await pumpOnboarding(tester);
    expect(fieldText(tester), isEmpty);
    expect(find.byKey(fromAccountKey), findsNothing);

    await resolve(tester, 'Paul');
    expect(fieldText(tester), 'Paul');
    expect(find.byKey(fromAccountKey), findsOneWidget);
    expect(find.text('From your plantly.ro account — you can change it.'), findsOneWidget);

    // Finishing onboarding saves the prefilled name like a typed one.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
    }
    expect(find.byType(OnboardingScreen), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('plantly_user_name'), 'Paul');
    expect(prefs.getBool('plantly_onboarded'), isTrue);
  });

  testWidgets('typed text is never overwritten by a late account name', (tester) async {
    await pumpOnboarding(tester);
    await tester.enterText(find.byType(TextField), 'Pa');
    await tester.pump();

    await resolve(tester, 'Paul');
    expect(fieldText(tester), 'Pa');
    expect(find.byKey(fromAccountKey), findsNothing);
  });

  testWidgets('a cleared prefilled field stays cleared', (tester) async {
    await pumpOnboarding(tester);
    await resolve(tester, 'Paul');
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(fieldText(tester), isEmpty);
    expect(find.byKey(fromAccountKey), findsNothing);
  });

  testWidgets('editing the prefilled name hides the helper', (tester) async {
    await pumpOnboarding(tester);
    await resolve(tester, 'Paul');
    expect(find.byKey(fromAccountKey), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Pauli');
    await tester.pump();
    expect(fieldText(tester), 'Pauli');
    expect(find.byKey(fromAccountKey), findsNothing);
  });

  testWidgets('a local name wins over the account name and shows no helper', (tester) async {
    await pumpOnboarding(tester, prefs: {'plantly_user_name': 'Pauli'});
    expect(fieldText(tester), 'Pauli');

    await resolve(tester, 'Paul');
    expect(fieldText(tester), 'Pauli');
    expect(find.byKey(fromAccountKey), findsNothing);
  });

  testWidgets('already-resolved account name prefills on first build (ro copy)', (tester) async {
    account = Completer<String?>()..complete('Ioana');
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(buildTestApp(
      overrides: [accountGreetingNameProvider.overrideWith((ref) => account.future)],
      child: const MaterialApp(
        locale: Locale('ro'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnboardingScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(fieldText(tester), 'Ioana');
    expect(find.text('Din contul tău plantly.ro — îl poți schimba.'), findsOneWidget);
  });

  testWidgets('no account name (signed out) → empty field, no helper', (tester) async {
    await pumpOnboarding(tester);
    await resolve(tester, null);
    expect(fieldText(tester), isEmpty);
    expect(find.byKey(fromAccountKey), findsNothing);
  });
}
