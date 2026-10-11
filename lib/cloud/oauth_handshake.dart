import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/providers.dart';

/// Anti-fixation guard for the OAuth deep link. Any app/page can open
/// `plantlyinventory://auth/callback#token=<jwt>`; without this the device
/// would adopt an attacker's session (and upload the user's plants into the
/// attacker's account). So: every sign-in the user starts mints a random
/// nonce (sent as `&nonce=` on the start URL, echoed back by the server in
/// the callback fragment — monolith 69872a0, live on prod) and a callback is
/// adopted only if a sign-in was started within [window] AND it carries
/// exactly that nonce. Strict on every platform and both callback forms: a
/// callback without the nonce is never a legitimate answer. Single-use:
/// consumed on the first accepted callback.
class OAuthHandshake {
  OAuthHandshake(this._prefs, {DateTime Function()? now, Random? random})
      : _now = now ?? (() => DateTime.now().toUtc()),
        _random = random ?? Random.secure();

  static const String nonceKey = 'plantly_oauth_nonce';
  static const String startedAtKey = 'plantly_oauth_started_at';
  static const Duration window = Duration(minutes: 10);

  final Future<SharedPreferences> _prefs;
  final DateTime Function() _now;
  final Random _random;

  /// Mint + persist a fresh nonce for a sign-in the user just started:
  /// 24 random bytes → 32 chars base64url (server accepts 16–64).
  Future<String> begin() async {
    final bytes = List<int>.generate(24, (_) => _random.nextInt(256));
    final nonce = base64Url.encode(bytes).replaceAll('=', '');
    final p = await _prefs;
    await p.setString(nonceKey, nonce);
    await p.setInt(startedAtKey, _now().millisecondsSinceEpoch);
    return nonce;
  }

  /// Decide whether a callback carrying [callbackNonce] may be adopted:
  /// only when a sign-in is pending (started inside [window]) and
  /// [callbackNonce] equals its nonce. Clears the stored nonce on
  /// acceptance (single-use) and when the window has lapsed. A missing or
  /// wrong nonce is rejected and logged but leaves the pending sign-in in
  /// place, so a forged link cannot cancel the user's real sign-in.
  Future<bool> consume(String? callbackNonce) async {
    final p = await _prefs;
    final stored = p.getString(nonceKey);
    final startedAt = p.getInt(startedAtKey);
    if (stored == null || stored.isEmpty || startedAt == null) {
      debugPrint('oauth callback rejected: no sign-in in progress');
      return false;
    }
    final age = _now().difference(DateTime.fromMillisecondsSinceEpoch(startedAt, isUtc: true));
    if (age.isNegative || age > window) {
      await _clear(p);
      debugPrint('oauth callback rejected: sign-in window expired');
      return false;
    }
    if (callbackNonce == null || callbackNonce.isEmpty) {
      debugPrint('oauth callback rejected: nonce missing');
      return false;
    }
    if (!_constantTimeEquals(callbackNonce, stored)) {
      debugPrint('oauth callback rejected: nonce mismatch');
      return false;
    }
    await _clear(p);
    return true;
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  Future<void> _clear(SharedPreferences p) async {
    await p.remove(nonceKey);
    await p.remove(startedAtKey);
  }
}

final oauthHandshakeProvider = Provider<OAuthHandshake>((ref) {
  return OAuthHandshake(ref.read(sharedPreferencesProvider.future));
});
