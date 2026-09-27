import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plantly_inventory/marketplace/plantly_api.dart';
import 'package:plantly_inventory/marketplace/plantly_auth.dart';
import 'package:plantly_inventory/marketplace/session_store.dart';

import 'plantly_session_test.dart' show fakeJwt;

/// QA2 BUG-3 — a device clock ≥ 24 h ahead used to sign the user out for
/// good: every freshly issued token (exp = server now + 24 h) was already
/// "expired" by the device clock. The device clock never ends a session:
/// `/auth/refresh` is the authority, and only its 401 (or a token older
/// than 30 days by SERVER time) clears the stored token.
void main() {
  // Server time vs a device running 3 days ahead.
  final serverNow = DateTime.utc(2026, 9, 27, 12);
  final deviceNow = serverNow.add(const Duration(days: 3));
  int secs(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

  // Issued by the server a minute ago, valid for 24 h — a perfectly good token.
  final goodToken = fakeJwt(iat: secs(serverNow.subtract(const Duration(minutes: 1))), exp: secs(serverNow.add(const Duration(hours: 24))));
  final refreshedToken = fakeJwt(iat: secs(serverNow), exp: secs(serverNow.add(const Duration(hours: 24))));

  late List<http.Request> requests;
  late InMemorySessionStore store;
  late DateTime clock;

  PlantlyAuth auth(Future<http.Response> Function(http.Request) handler) {
    requests = [];
    final api = PlantlyApi(
      client: MockClient((req) async {
        requests.add(req);
        return handler(req);
      }),
      host: 'https://dev.example',
    );
    return PlantlyAuth(api: api, store: store, now: () => clock, autoLoad: false);
  }

  http.Response tokenReply(String token) => http.Response(json.encode({'token': token}), 200, headers: {'content-type': 'application/json'});

  setUp(() {
    store = InMemorySessionStore(goodToken);
    clock = deviceNow;
  });

  test('clock 3 days ahead: refresh is attempted, the user stays signed in, and the skew is learned (no refresh storm)', () async {
    final a = auth((req) async {
      expect(req.url.path, '/api/v1/auth/refresh');
      expect(req.headers['Authorization'], 'Bearer $goodToken');
      return tokenReply(refreshedToken);
    });

    final s = await a.current();
    expect(s, isNotNull);
    expect(s!.token, refreshedToken);
    expect(await store.readToken(), refreshedToken);
    expect(requests, hasLength(1));
    expect(a.clockSkew, const Duration(days: 3));

    // Subsequent reads judge the token by server time: no second refresh.
    expect((await a.current())!.token, refreshedToken);
    expect((await a.current())!.token, refreshedToken);
    expect(requests, hasLength(1), reason: 'the refreshed token is fresh by server time');
    expect(a.sessionOrNull?.token, refreshedToken);
  });

  test('refresh answered with 401 → signed out (store cleared, state null)', () async {
    final a = auth((_) async => http.Response('{"error":"session expired"}', 401));
    expect(await a.current(), isNull);
    expect(await store.readToken(), isNull);
    expect(a.sessionOrNull, isNull);
    expect(requests, hasLength(1));
  });

  test('refresh answered with 429 / 5xx → NOT signed out; the token is kept and the retry waits a minute', () async {
    var status = 429;
    final a = auth((_) async => http.Response('{"error":"rate limited"}', status, headers: {'retry-after': '30'}));
    expect((await a.current())!.token, goodToken);
    expect(await store.readToken(), goodToken);
    expect(requests, hasLength(1));

    // Within the quiet period: no new attempt, still signed in.
    clock = clock.add(const Duration(seconds: 20));
    expect((await a.current())!.token, goodToken);
    expect(requests, hasLength(1));

    // After it: tried again; a 500 is still no verdict.
    status = 500;
    clock = clock.add(const Duration(minutes: 1));
    expect((await a.current())!.token, goodToken);
    expect(requests, hasLength(2));
    expect(a.sessionOrNull?.token, goodToken);
  });

  test('offline with a locally "expired" token → still signed in (expiry is the server\'s call)', () async {
    final a = auth((_) async => throw http.ClientException('offline'));
    expect((await a.current())!.token, goodToken);
    expect(await store.readToken(), goodToken);
    expect(a.sessionOrNull?.token, goodToken);
  });

  test('a locally "too old to refresh" token (> 30 d by the device clock) is still offered to the server', () async {
    // Device clock 40 days ahead; the token is 1 minute old by server time.
    clock = serverNow.add(const Duration(days: 40));
    final a = auth((_) async => tokenReply(refreshedToken));
    expect((await a.current())!.token, refreshedToken);
    expect(requests, hasLength(1));
  });

  test('older than 30 days by SERVER time (skew known) → signed out without a refresh call', () async {
    // Learn server time from a sign-in, then find a stale token in the store.
    final a = auth((req) async {
      if (req.url.path.endsWith('/auth/login')) {
        return http.Response(json.encode({'token': refreshedToken, 'user': {'id': 'u-1', 'username': 'alice', 'email': 'a@x'}}), 200);
      }
      fail('no refresh expected for a token the server would refuse anyway');
    });
    await a.signIn('a@x', 'pw');
    expect(a.clockSkew, const Duration(days: 3));
    final stale = fakeJwt(iat: secs(serverNow.subtract(const Duration(days: 31))), exp: secs(serverNow.subtract(const Duration(days: 30))));
    await store.writeToken(stale);
    expect(await a.current(), isNull);
    expect(await store.readToken(), isNull);
    expect(requests.where((r) => r.url.path.endsWith('/auth/refresh')), isEmpty);
  });

  test('a token that is fresh by the device clock is used as-is (no refresh)', () async {
    clock = serverNow; // clock in sync
    final a = auth((_) async => fail('no request expected'));
    expect((await a.current())!.token, goodToken);
    expect(requests, isEmpty);
  });
}
