import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/providers.dart';

/// Anti-fixation guard for the OAuth deep link. Any app/page can open
/// `plantlyinventory://auth/callback#token=<jwt>`; without this the device
/// would adopt an attacker's session. So: every sign-in the user starts
/// mints a random nonce (sent as `&nonce=` on the start URL, echoed back by
/// the server in the callback fragment) and a callback is adopted only if a
/// sign-in was started within [window] and the nonce — when present —
/// matches. Single-use: consumed on the first accepted callback.
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

  /// Decide whether a callback carrying [callbackNonce] may be adopted.
  /// Strict when a nonce is present (mismatch → false). A callback WITHOUT
  /// a nonce is accepted only when [allowMissingNonce] (the custom-scheme
  /// form, for servers that predate the echo) and a sign-in started inside
  /// the window; the web `?token=` form always needs the nonce. Clears the
  /// stored nonce on acceptance; a mismatch leaves it in place so the
  /// legitimate callback can still land.
  Future<bool> consume(String? callbackNonce, {bool allowMissingNonce = false}) async {
    final p = await _prefs;
    final stored = p.getString(nonceKey);
    final startedAt = p.getInt(startedAtKey);
    if (stored == null || stored.isEmpty || startedAt == null) return false;
    final age = _now().difference(DateTime.fromMillisecondsSinceEpoch(startedAt, isUtc: true));
    if (age.isNegative || age > window) {
      await _clear(p);
      return false;
    }
    if (callbackNonce != null) {
      if (callbackNonce != stored) return false;
    } else {
      if (!allowMissingNonce) return false;
      // Transitional (custom scheme only): older monolith builds don't echo
      // `nonce`. Flip to strict once every server does.
      debugPrint('oauth callback: nonce missing (server not echoing yet) — accepted inside the sign-in window');
    }
    await _clear(p);
    return true;
  }

  Future<void> _clear(SharedPreferences p) async {
    await p.remove(nonceKey);
    await p.remove(startedAtKey);
  }
}

final oauthHandshakeProvider = Provider<OAuthHandshake>((ref) {
  return OAuthHandshake(ref.read(sharedPreferencesProvider.future));
});
