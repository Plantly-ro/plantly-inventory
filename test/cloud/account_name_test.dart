import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plantly_inventory/cloud/account_name.dart';
import 'package:plantly_inventory/data/user_prefs.dart';
import 'package:plantly_inventory/marketplace/plantly_auth.dart';
import 'package:plantly_inventory/marketplace/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../marketplace/plantly_session_test.dart' show fakeJwt;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('accountGreetingName', () {
    test('first_name wins over full_name and username', () {
      expect(accountGreetingName({'first_name': 'Paul', 'full_name': 'Pavel Schuldesz', 'username': 'paulschuldesz'}), 'Paul');
    });

    test('trims and collapses whitespace', () {
      expect(accountGreetingName({'first_name': '  Ana   Maria \n'}), 'Ana Maria');
    });

    test('falls back to the first word of full_name', () {
      expect(accountGreetingName({'full_name': '  Ioana  Popescu '}), 'Ioana');
      expect(accountGreetingName({'first_name': '   ', 'full_name': 'Ioana Popescu'}), 'Ioana');
      expect(accountGreetingName({'first_name': null, 'full_name': 'Ioana'}), 'Ioana');
    });

    test('empty / missing / non-string → null; username is never used', () {
      expect(accountGreetingName({}), isNull);
      expect(accountGreetingName({'username': 'paulschuldesz'}), isNull);
      expect(accountGreetingName({'first_name': '', 'full_name': '  ', 'username': 'x'}), isNull);
      expect(accountGreetingName({'first_name': 42, 'full_name': ['a']}), isNull);
    });

    test('caps overlong names at $accountGreetingNameMaxLength characters', () {
      final long = 'Ă' * 60;
      final capped = accountGreetingName({'first_name': long})!;
      expect(capped.runes.length, accountGreetingNameMaxLength);
      // A cut that lands on a space does not leave it dangling.
      final spaced = '${'a' * 39} bcdef';
      expect(accountGreetingName({'first_name': spaced}), 'a' * 39);
    });
  });

  group('accountGreetingNameProvider + accountNameAdoptionProvider', () {
    int secs(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;
    String token(String userId) => fakeJwt(
          iat: secs(DateTime.now().toUtc()),
          exp: secs(DateTime.now().toUtc().add(const Duration(hours: 24))),
          userId: userId,
        );

    late int calls;
    late Map<String, Map<String, dynamic>> bodies; // by bearer token
    late bool failing;

    setUp(() {
      calls = 0;
      bodies = {};
      failing = false;
    });

    ProviderContainer make({String? storedToken, Map<String, Object> prefs = const {}}) {
      SharedPreferences.setMockInitialValues(prefs);
      final c = ProviderContainer(overrides: [
        sessionStoreProvider.overrideWith((_) => InMemorySessionStore(storedToken)),
        httpClientProvider.overrideWith((_) => MockClient((req) async {
              if (req.url.path.endsWith('/users/me')) {
                calls++;
                if (failing) return http.Response('{"error":"boom"}', 500);
                final bearer = req.headers['Authorization']?.replaceFirst('Bearer ', '');
                return http.Response(json.encode(bodies[bearer] ?? {}), 200);
              }
              return http.Response('{"error":"nope"}', 404);
            })),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    /// Let microtasks + mock I/O settle.
    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    Future<void> startEffect(ProviderContainer c) async {
      c.listen(accountNameAdoptionProvider, (_, _) {});
      await c.read(plantlyAuthProvider.notifier).current();
      await c.read(accountGreetingNameProvider.future);
      await settle();
    }

    test('signed out → null, no request, nothing adopted', () async {
      final c = make();
      await startEffect(c);
      expect(await c.read(accountGreetingNameProvider.future), isNull);
      expect(calls, 0);
      expect(c.read(userPrefsProvider).userName, isNull);
    });

    test('HTTP error → null (never throws), nothing adopted', () async {
      final t = token('u-1');
      failing = true;
      final c = make(storedToken: t);
      await startEffect(c);
      expect(c.read(accountGreetingNameProvider).value, isNull);
      expect(c.read(accountGreetingNameProvider).hasError, isFalse);
      expect(calls, 1);
      expect(c.read(userPrefsProvider).userName, isNull);
    });

    test('adopt-if-empty: signed in with no local name → account first name', () async {
      final t = token('u-1');
      bodies[t] = {'first_name': 'Paul', 'full_name': 'Paul Schuldesz', 'username': 'paulschuldesz'};
      final c = make(storedToken: t);
      await startEffect(c);
      expect(c.read(accountGreetingNameProvider).value, 'Paul');
      expect(c.read(userPrefsProvider).userName, 'Paul');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('plantly_user_name'), 'Paul');
      expect(prefs.getString(adoptedForKey), 'u-1');
    });

    test('an existing local name is never overwritten', () async {
      final t = token('u-1');
      bodies[t] = {'first_name': 'Paul'};
      final c = make(storedToken: t, prefs: {'plantly_user_name': 'Pauli'});
      await startEffect(c);
      expect(c.read(accountGreetingNameProvider).value, 'Paul');
      expect(c.read(userPrefsProvider).userName, 'Pauli');
    });

    test('a later clear sticks for the same account (no refill behind the user)', () async {
      final t = token('u-1');
      bodies[t] = {'first_name': 'Paul'};
      final c = make(storedToken: t);
      await startEffect(c);
      expect(c.read(userPrefsProvider).userName, 'Paul');

      await c.read(userPrefsProvider.notifier).setName(null);
      await settle();
      expect(c.read(userPrefsProvider).userName, isNull);
    });

    test('account switch re-resolves and adopts for the new account when empty', () async {
      final t1 = token('u-1');
      final t2 = token('u-2');
      bodies[t1] = {'first_name': 'Paul'};
      bodies[t2] = {'full_name': 'Ioana Popescu'};
      final c = make(storedToken: t1);
      await startEffect(c);
      expect(c.read(accountGreetingNameProvider).value, 'Paul');
      expect(calls, 1);

      // The user cleared the name, then signs into another account.
      await c.read(userPrefsProvider.notifier).setName(null);
      await c.read(plantlyAuthProvider.notifier).signOut();
      expect(await c.read(accountGreetingNameProvider.future), isNull);
      await c.read(plantlyAuthProvider.notifier).adoptToken(t2);
      expect(await c.read(accountGreetingNameProvider.future), 'Ioana');
      await settle();
      expect(calls, 2);
      expect(c.read(userPrefsProvider).userName, 'Ioana');
    });
  });

  // Tester additions (2026-10-07): failure modes must not adopt nor mark the
  // account as considered; in-flight results never cross an account switch.
  group('adoption edge cases', () {
    int secs(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;
    String token(String userId) => fakeJwt(
          iat: secs(DateTime.now().toUtc()),
          exp: secs(DateTime.now().toUtc().add(const Duration(hours: 24))),
          userId: userId,
        );

    /// Per-bearer gated replies: the test completes each /users/me call.
    late Map<String, List<Completer<http.Response>>> pending;
    late int calls;

    setUp(() {
      pending = {};
      calls = 0;
    });

    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    ProviderContainer make({
      String? storedToken,
      Map<String, Object> prefs = const {},
      Future<http.Response> Function(String? bearer)? reply,
    }) {
      SharedPreferences.setMockInitialValues(prefs);
      final c = ProviderContainer(overrides: [
        sessionStoreProvider.overrideWith((_) => InMemorySessionStore(storedToken)),
        httpClientProvider.overrideWith((_) => MockClient((req) async {
              if (req.url.path.endsWith('/users/me')) {
                calls++;
                final bearer = req.headers['Authorization']?.replaceFirst('Bearer ', '');
                if (reply != null) return reply(bearer);
                final gate = Completer<http.Response>();
                pending.putIfAbsent(bearer ?? '', () => []).add(gate);
                return gate.future;
              }
              return http.Response('{"error":"nope"}', 404);
            })),
      ]);
      addTearDown(c.dispose);
      c.listen(accountNameAdoptionProvider, (_, _) {});
      return c;
    }

    http.Response ok(Map<String, Object?> body) => http.Response(json.encode(body), 200);

    Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

    for (final (label, reply) in <(String, Future<http.Response> Function(String?))>[
      ('401', (_) async => http.Response('{"error":"unauthorized"}', 401)),
      ('500', (_) async => http.Response('{"error":"boom"}', 500)),
      ('offline (ClientException)', (_) async => throw http.ClientException('Failed host lookup')),
      ('non-JSON 200', (_) async => http.Response('<html>proxy</html>', 200)),
    ]) {
      test('/users/me $label → null, no crash, nothing adopted, marker NOT written', () async {
        final c = make(storedToken: token('u-1'), reply: reply);
        await c.read(plantlyAuthProvider.notifier).current();
        expect(await c.read(accountGreetingNameProvider.future), isNull);
        await settle();
        expect(calls, 1);
        expect(c.read(accountGreetingNameProvider).hasError, isFalse);
        expect(c.read(userPrefsProvider).userName, isNull);
        final p = await prefs();
        expect(p.getString('plantly_user_name'), isNull);
        expect(p.getString(adoptedForKey), isNull);
      });
    }

    test("today's server (full_name only, plus username/email) → first word of full_name adopted", () async {
      final c = make(
        storedToken: token('u-1'),
        reply: (_) async => ok({
          'id': 'u-1',
          'username': 'paulschuldesz',
          'email': 'p@example.com',
          'full_name': 'Paul Schuldesz',
        }),
      );
      await c.read(plantlyAuthProvider.notifier).current();
      expect(await c.read(accountGreetingNameProvider.future), 'Paul');
      await settle();
      expect(c.read(userPrefsProvider).userName, 'Paul');
      expect((await prefs()).getString(adoptedForKey), 'u-1');
    });

    test('sign-out while /users/me is in flight → late reply ignored, no marker', () async {
      final t = token('u-1');
      final c = make(storedToken: t);
      await c.read(plantlyAuthProvider.notifier).current();
      c.read(accountGreetingNameProvider);
      await settle();
      expect(pending[t], hasLength(1));

      await c.read(plantlyAuthProvider.notifier).signOut();
      expect(await c.read(accountGreetingNameProvider.future), isNull);
      pending[t]!.single.complete(ok({'first_name': 'Paul'}));
      await settle();

      expect(c.read(accountGreetingNameProvider).value, isNull);
      expect(c.read(userPrefsProvider).userName, isNull);
      expect((await prefs()).getString(adoptedForKey), isNull);
    });

    test("A→B switch with A in flight: A's late reply is never applied to B", () async {
      final ta = token('u-a');
      final tb = token('u-b');
      final c = make(storedToken: ta);
      await c.read(plantlyAuthProvider.notifier).current();
      c.read(accountGreetingNameProvider);
      await settle();
      expect(pending[ta], hasLength(1));

      // Direct switch (no sign-out in between), e.g. a second OAuth callback.
      await c.read(plantlyAuthProvider.notifier).adoptToken(tb);
      c.read(accountGreetingNameProvider);
      await settle();
      expect(pending[tb], hasLength(1));

      // A answers late, while B is still loading → nothing happens.
      pending[ta]!.single.complete(ok({'first_name': 'Ana'}));
      await settle();
      expect(c.read(userPrefsProvider).userName, isNull);
      expect((await prefs()).getString(adoptedForKey), isNull);

      pending[tb]!.single.complete(ok({'first_name': 'Bea'}));
      expect(await c.read(accountGreetingNameProvider.future), 'Bea');
      await settle();
      expect(c.read(userPrefsProvider).userName, 'Bea');
      expect((await prefs()).getString(adoptedForKey), 'u-b');
    });

    test("A→B switch, B answers before A's stale reply → still B's name", () async {
      final ta = token('u-a');
      final tb = token('u-b');
      final c = make(storedToken: ta);
      await c.read(plantlyAuthProvider.notifier).current();
      c.read(accountGreetingNameProvider);
      await settle();
      await c.read(plantlyAuthProvider.notifier).adoptToken(tb);
      c.read(accountGreetingNameProvider);
      await settle();

      pending[tb]!.single.complete(ok({'first_name': 'Bea'}));
      await settle();
      pending[ta]!.single.complete(ok({'first_name': 'Ana'}));
      await settle();
      expect(c.read(accountGreetingNameProvider).value, 'Bea');
      expect(c.read(userPrefsProvider).userName, 'Bea');
    });

    test("A→B: A's adopted local name is kept (B never overwrites), B is marked considered", () async {
      final ta = token('u-a');
      final tb = token('u-b');
      final c = make(
        storedToken: ta,
        reply: (bearer) async => ok({'first_name': bearer == ta ? 'Ana' : 'Bea'}),
      );
      await c.read(plantlyAuthProvider.notifier).current();
      expect(await c.read(accountGreetingNameProvider.future), 'Ana');
      await settle();
      expect(c.read(userPrefsProvider).userName, 'Ana');

      await c.read(plantlyAuthProvider.notifier).adoptToken(tb);
      expect(await c.read(accountGreetingNameProvider.future), 'Bea');
      await settle();
      expect(c.read(userPrefsProvider).userName, 'Ana');
      expect((await prefs()).getString(adoptedForKey), 'u-b');

      // Clearing now sticks for B too.
      await c.read(userPrefsProvider.notifier).setName(null);
      await settle();
      expect(c.read(userPrefsProvider).userName, isNull);
    });

    test('B already considered on this device (cleared earlier) → not re-adopted on sign-in', () async {
      final c = make(
        storedToken: token('u-b'),
        prefs: {adoptedForKey: 'u-b'},
        reply: (_) async => ok({'first_name': 'Bea'}),
      );
      await c.read(plantlyAuthProvider.notifier).current();
      expect(await c.read(accountGreetingNameProvider.future), 'Bea');
      await settle();
      expect(c.read(userPrefsProvider).userName, isNull);
    });

    test('a different account considered earlier does not block adoption for this one', () async {
      final c = make(
        storedToken: token('u-b'),
        prefs: {adoptedForKey: 'u-a'},
        reply: (_) async => ok({'first_name': 'Bea'}),
      );
      await c.read(plantlyAuthProvider.notifier).current();
      await c.read(accountGreetingNameProvider.future);
      await settle();
      expect(c.read(userPrefsProvider).userName, 'Bea');
      expect((await prefs()).getString(adoptedForKey), 'u-b');
    });
  });
}
