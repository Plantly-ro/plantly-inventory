import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/features/collections/join_collection_sheet.dart';
import 'package:plantly_inventory/handoff/handoff_listener.dart';
import 'package:plantly_inventory/handoff/incoming_links.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_app.dart';

void main() {
  const code = 'ABCDEFGH';

  group('extractJoinCode — the join link forms (CLOUD-SYNC-CONTRACT §3)', () {
    test('1. custom scheme plantlyinventory://join#c=', () {
      expect(extractJoinCode(Uri.parse('plantlyinventory://join#c=$code')), code);
      expect(extractJoinCode(Uri.parse('plantlyinventory://join?c=$code')), code, reason: 'query tolerated');
      expect(extractJoinCode(Uri.parse('plantlyinventory://join#c=abcd-efgh')), code, reason: 'normalised');
    });

    test('2. invite url https://plantly.ro/app/inventory/join#c=', () {
      expect(extractJoinCode(Uri.parse('https://plantly.ro/app/inventory/join#c=$code')), code);
      expect(extractJoinCode(Uri.parse('https://plantly.ro/ro/app/inventory/join#c=$code')), code);
      expect(extractJoinCode(Uri.parse('https://development.agent-khepri.urundead.win/app/inventory/join?c=$code')), code);
    });

    test('3. inventory web path route /join?c= (+ legacy hash route /#/join?c=)', () {
      expect(extractJoinCode(Uri.parse('https://inventory.plantly.ro/join?c=$code')), code);
      expect(extractJoinCode(Uri.parse('http://127.0.0.1:8099/join?c=$code&x=1')), code);
      expect(extractJoinCode(Uri.parse('https://host/inventory/join/?c=$code')), code);
      expect(extractJoinCode(Uri.parse('https://inventory.plantly.ro/join#c=$code')), code);
      expect(extractJoinCode(Uri.parse('http://127.0.0.1:8099/#/join?c=$code')), code);
      expect(isJoinPath('/join'), isTrue);
      expect(isJoinPath('/join/'), isTrue);
      expect(isJoinPath('/plants/join-notes'), isFalse);
      expect(isJoinPath('/'), isFalse);
    });

    test('non-join links and invalid codes → null', () {
      expect(extractJoinCode(Uri.parse('https://inventory.plantly.ro/join')), isNull);
      expect(extractJoinCode(Uri.parse('https://inventory.plantly.ro/join?c=short')), isNull);
      expect(extractJoinCode(Uri.parse('https://inventory.plantly.ro/join?c=ABCDEFG1')), isNull, reason: '1 not in alphabet');
      expect(extractJoinCode(Uri.parse('plantlyinventory://import#d=$code')), isNull);
      expect(extractJoinCode(Uri.parse('plantlyinventory://other#c=$code')), isNull);
      expect(extractJoinCode(Uri.parse('https://plantly.ro/posts/abc')), isNull);
      expect(extractJoinCode(Uri.parse('http://127.0.0.1:8099/#/plants/1')), isNull);
      // A join link is never mistaken for an import / auth link.
      expect(extractImportParam(Uri.parse('plantlyinventory://join#c=$code')), isNull);
      expect(extractAuthCallback(Uri.parse('https://inventory.plantly.ro/join?c=$code')), isNull);
    });
  });

  testWidgets('HandoffListener opens the join sheet with the code pre-filled, once per link', (tester) async {
    SharedPreferences.setMockInitialValues({'plantly_onboarded': true});
    addTearDown(() => tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))));
    final links = FakeIncomingLinks();
    addTearDown(links.dispose);
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(buildTestApp(
      overrides: [incomingLinksProvider.overrideWithValue(links)],
      child: MaterialApp(
        navigatorKey: navKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => HandoffListener(navigatorKey: navKey, child: child!),
        home: Consumer(builder: (context, ref, _) {
          ref.watch(appContextProvider);
          return const Scaffold(body: Text('home'));
        }),
      ),
    ));
    await tester.pumpAndSettle();

    links.emit(Uri.parse('plantlyinventory://join#c=abcd-efgh'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('join-collection-title')), findsOneWidget);
    final field = tester.widget<TextField>(find.byKey(const Key('join-collection-code')));
    expect(field.controller!.text, code, reason: 'normalised and pre-filled');
    expect(links.consumed, 1, reason: 'address bar scrubbed');
    expect(find.byKey(const Key('join-sign-in-note')), findsOneWidget, reason: 'signed out → sign-in note');
    final submit = tester.widget<FilledButton>(find.byKey(const Key('join-collection-submit')));
    expect(submit.onPressed, isNotNull, reason: 'valid code → Join enabled');

    // The same link delivered twice (initial + stream) opens one sheet.
    links.emit(Uri.parse('plantlyinventory://join#c=$code'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('join-collection-title')), findsOneWidget);

    // Close → the same link can be opened again deliberately.
    navKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('join-collection-title')), findsNothing);
    links.emit(Uri.parse('https://plantly.ro/app/inventory/join#c=$code'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('join-collection-title')), findsOneWidget);
  });

  testWidgets('join sheet: code validation gates the button; invalid input shows the alphabet hint', (tester) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))));
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(buildTestApp(
      child: MaterialApp(
        navigatorKey: navKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          return Scaffold(
            body: TextButton(
              onPressed: () => showJoinCollectionSheet(context),
              child: const Text('open'),
            ),
          );
        }),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    FilledButton submit() => tester.widget<FilledButton>(find.byKey(const Key('join-collection-submit')));
    expect(submit().onPressed, isNull, reason: 'empty');
    await tester.enterText(find.byKey(const Key('join-collection-code')), 'abcdefg');
    await tester.pumpAndSettle();
    expect(submit().onPressed, isNull, reason: '7 chars');
    expect(find.byKey(const Key('join-collection-hint')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('join-collection-code')), 'abcd-efgh');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('join-collection-code'))).controller!.text, 'ABCD-EFGH',
        reason: 'upper-cased as typed');
    expect(submit().onPressed, isNotNull);
    expect(find.byKey(const Key('join-collection-hint')), findsNothing);
  });
}
