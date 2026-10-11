import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/cloud/oauth_handshake.dart';
import 'package:plantly_inventory/cloud/sign_in_events.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/handoff/handoff_listener.dart';
import 'package:plantly_inventory/handoff/incoming_links.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/marketplace/plantly_auth.dart';
import 'package:plantly_inventory/marketplace/plantly_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_app.dart';
import '../marketplace/plantly_session_test.dart' show fakeJwt;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'plantly_onboarded': true}));

  testWidgets('HandoffListener adopts the OAuth callback token and announces the sign-in', (tester) async {
    addTearDown(() => tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))));
    final token = fakeJwt(
      iat: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
      exp: DateTime.now().toUtc().add(const Duration(hours: 24)).millisecondsSinceEpoch ~/ 1000,
      username: 'bob',
      userId: 'u-2',
    );
    final links = FakeIncomingLinks();
    addTearDown(links.dispose);
    final navKey = GlobalKey<NavigatorState>();
    final events = <PlantlySession>[];
    late ProviderContainer container;
    await tester.pumpWidget(buildTestApp(
      overrides: [incomingLinksProvider.overrideWithValue(links)],
      child: MaterialApp(
        navigatorKey: navKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => HandoffListener(navigatorKey: navKey, child: child!),
        home: Consumer(builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          ref.watch(appContextProvider);
          return const Scaffold(body: Text('home'));
        }),
      ),
    ));
    await tester.pumpAndSettle();
    container.read(signInEventsProvider).stream.listen(events.add);
    expect(container.read(plantlyAuthProvider).valueOrNull, isNull);

    // No sign-in started on this device → a callback is a fixation attempt: ignored.
    links.emit(Uri.parse('plantlyinventory://auth/callback#token=$token'));
    await tester.pumpAndSettle();
    expect(container.read(plantlyAuthProvider).valueOrNull, isNull);
    expect(events, isEmpty);
    expect(links.consumed, 1, reason: 'the address bar is still scrubbed');

    // Sign-in started → the callback with the echoed nonce is adopted once.
    final nonce = await container.read(oauthHandshakeProvider).begin();
    final other = fakeJwt(iat: 1, exp: 4102444800, username: 'mallory', userId: 'u-9');
    links.emit(Uri.parse('plantlyinventory://auth/callback#token=$other&nonce=WRONGnonce_value_WRONGnonce_value'));
    await tester.pumpAndSettle();
    expect(container.read(plantlyAuthProvider).valueOrNull, isNull, reason: 'nonce mismatch');
    links.emit(Uri.parse('https://inventory.plantly.ro/#/auth/callback?token=$other'));
    await tester.pumpAndSettle();
    expect(container.read(plantlyAuthProvider).valueOrNull, isNull, reason: 'web form without nonce is never accepted');
    // Session fixation: another app fires the custom-scheme callback with
    // the attacker's token and no nonce while the victim's sign-in is open.
    final attacker = fakeJwt(iat: 1, exp: 4102444800, username: 'eve', userId: 'u-666');
    links.emit(Uri.parse('plantlyinventory://auth/callback#token=$attacker'));
    await tester.pumpAndSettle();
    expect(container.read(plantlyAuthProvider).valueOrNull, isNull,
        reason: 'custom-scheme callback without the nonce is never adopted');
    expect(events, isEmpty);

    links.emit(Uri.parse('plantlyinventory://auth/callback#token=$token&nonce=$nonce'));
    await tester.pumpAndSettle();
    expect(container.read(plantlyAuthProvider).valueOrNull?.username, 'bob');
    expect(events.map((s) => s.userId), ['u-2']);

    // The web shape (`?token=` after the hash route) with the echoed nonce is adopted too.
    final nonce2 = await container.read(oauthHandshakeProvider).begin();
    links.emit(Uri.parse('https://inventory.plantly.ro/#/auth/callback?token=$other&nonce=$nonce2'));
    await tester.pumpAndSettle();
    expect(container.read(plantlyAuthProvider).valueOrNull?.username, 'mallory');
    expect(events, hasLength(2));
    final nonce3 = await container.read(oauthHandshakeProvider).begin();
    links.emit(Uri.parse('plantlyinventory://auth/callback#token=$token&nonce=$nonce3'));
    await tester.pumpAndSettle();
    expect(container.read(plantlyAuthProvider).valueOrNull?.username, 'bob');
    expect(events, hasLength(3));

    // Same callback again (initial-link + stream double delivery) → ignored;
    // and the nonce is single-use, so a replay of a different token is too.
    links.emit(Uri.parse('plantlyinventory://auth/callback#token=$token&nonce=$nonce3'));
    await tester.pumpAndSettle();
    expect(events, hasLength(3));
    links.emit(Uri.parse('plantlyinventory://auth/callback#token=$other&nonce=$nonce3'));
    await tester.pumpAndSettle();
    expect(container.read(plantlyAuthProvider).valueOrNull?.username, 'bob');
    expect(events, hasLength(3));

    // Garbage is dropped silently; the session is untouched.
    final garbageNonce = await container.read(oauthHandshakeProvider).begin();
    links.emit(Uri.parse('plantlyinventory://auth/callback#token=abc.def.ghi&nonce=$garbageNonce'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(container.read(plantlyAuthProvider).valueOrNull?.username, 'bob');
    expect(find.byKey(const Key('import-error')), findsNothing);

    // A nonce-less custom-scheme callback while a sign-in is pending is
    // rejected even inside the window, and does not burn the pending nonce.
    final pending = await container.read(oauthHandshakeProvider).begin();
    links.emit(Uri.parse('plantlyinventory://auth/callback#token=$attacker'));
    await tester.pumpAndSettle();
    expect(container.read(plantlyAuthProvider).valueOrNull?.username, 'bob');
    expect(events, hasLength(3));
    links.emit(Uri.parse('plantlyinventory://auth/callback#token=$other&nonce=$pending'));
    await tester.pumpAndSettle();
    expect(container.read(plantlyAuthProvider).valueOrNull?.username, 'mallory');
    expect(events, hasLength(4));
  });
}
