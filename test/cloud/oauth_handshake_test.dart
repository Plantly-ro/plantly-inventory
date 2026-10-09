import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/cloud/oauth_handshake.dart';
import 'package:plantly_inventory/config/plantly_hosts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final t0 = DateTime.utc(2026, 9, 27, 12);
  late DateTime now;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = t0;
  });
  OAuthHandshake make() => OAuthHandshake(SharedPreferences.getInstance(), now: () => now);

  test('begin() persists a random base64url nonce + start time and puts it on the start URL', () async {
    final h = make();
    final a = await h.begin();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(OAuthHandshake.nonceKey), a);
    expect(prefs.getInt(OAuthHandshake.startedAtKey), t0.millisecondsSinceEpoch);
    expect(RegExp(r'^[A-Za-z0-9_-]{32}$').hasMatch(a), isTrue, reason: '24 random bytes, unpadded base64url');
    expect(await h.begin(), isNot(a));
    expect(PlantlyHosts.oauthStartUrl('google', origin: 'https://dev.example', nonce: a),
        'https://dev.example/api/v1/auth/oauth/google/start?client=inventory&nonce=$a');
  });

  test('no sign-in started → callback ignored (with or without nonce)', () async {
    final h = make();
    expect(await h.consume('whatever'), isFalse);
    expect(await h.consume(null), isFalse);
  });

  test('started 11 minutes ago → ignored and cleared', () async {
    final h = make();
    final n = await h.begin();
    now = t0.add(const Duration(minutes: 11));
    expect(await h.consume(n), isFalse);
    expect((await SharedPreferences.getInstance()).getString(OAuthHandshake.nonceKey), isNull);
  });

  test('nonce mismatch → ignored, the pending sign-in survives for the real callback', () async {
    final h = make();
    final n = await h.begin();
    now = t0.add(const Duration(minutes: 9));
    expect(await h.consume('not-it'), isFalse);
    expect(await h.consume(n), isTrue);
  });

  test('nonce match → accepted once; identical second callback ignored', () async {
    final h = make();
    final n = await h.begin();
    expect(await h.consume(n), isTrue);
    expect(await h.consume(n), isFalse);
    expect(await h.consume(null), isFalse);
  });

  test('missing nonce inside the window → rejected on every platform; the pending sign-in survives', () async {
    // Session fixation (QA 2026-10-07): another app firing
    // `plantlyinventory://auth/callback#token=<ATTACKER_JWT>` while the
    // victim's sign-in is open must NOT be adopted. The server has echoed
    // the nonce since monolith 69872a0, so a nonce-less callback is never
    // a legitimate answer.
    final h = make();
    final n = await h.begin();
    now = t0.add(const Duration(minutes: 1));
    expect(await h.consume(null), isFalse);
    expect(await h.consume(''), isFalse);
    expect((await SharedPreferences.getInstance()).getString(OAuthHandshake.nonceKey), n,
        reason: 'a forged callback must not cancel the real sign-in');
    expect(await h.consume(n), isTrue, reason: 'the genuine echoed callback still lands');
  });

  test('a nonce differing only in case / length is rejected', () async {
    final h = make();
    final n = await h.begin();
    expect(await h.consume(n.toUpperCase() == n ? n.toLowerCase() : n.toUpperCase()), isFalse);
    expect(await h.consume(n.substring(1)), isFalse);
    expect(await h.consume('${n}x'), isFalse);
    expect(await h.consume(n), isTrue);
  });

  test('start URL: client=inventory (io) / inventory-web (web), nonce appended', () {
    expect(PlantlyHosts.oauthStartUrl('facebook', origin: 'https://dev.example', client: 'inventory-web', nonce: 'n'),
        'https://dev.example/api/v1/auth/oauth/facebook/start?client=inventory-web&nonce=n');
    expect(PlantlyHosts.oauthClient, 'inventory'); // tests run on the VM, not the web build
  });
}
