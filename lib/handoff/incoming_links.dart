import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'incoming_links_io.dart' if (dart.library.js_interop) 'incoming_links_web.dart' as platform;

/// Source of URIs the OS / browser hands to the app: the launch link plus
/// links arriving while running. Platform halves: `app_links` on io,
/// `location.hash` + `hashchange` on web.
abstract class IncomingLinks {
  /// The link the app was opened with, if any (consumed once).
  Future<Uri?> initial();

  /// Links arriving while the app is running.
  Stream<Uri> get stream;

  /// Called once an import link has been taken: the web half strips the
  /// payload from the address bar so reloads / bookmarks / history don't
  /// re-import (and the fragment never lingers in the URL). io: no-op.
  void consume() {}
}

/// Test double — push URIs with [emit].
class FakeIncomingLinks implements IncomingLinks {
  FakeIncomingLinks({this.initialUri});
  Uri? initialUri;
  final _controller = StreamController<Uri>.broadcast();

  @override
  Future<Uri?> initial() async => initialUri;

  @override
  Stream<Uri> get stream => _controller.stream;

  int consumed = 0;

  @override
  void consume() => consumed++;

  void emit(Uri uri) => _controller.add(uri);

  Future<void> dispose() => _controller.close();
}

/// Pull the PlantlyExport `d` parameter out of any of the three accepted
/// link forms (CONTRACT §4a), or null when [uri] is not an import link:
///  1. `plantlyinventory://import#d=<d>`
///  2. `https://<host>/app/inventory/import#d=<d>`
///  3. `<inventory web>/#/import?d=<d>`
String? extractImportParam(Uri uri) {
  final fragment = uri.fragment;
  if (uri.scheme == 'plantlyinventory') {
    if (uri.host != 'import' && !uri.path.startsWith('/import') && uri.path != 'import') return null;
    return _paramFromQueryString(fragment) ?? uri.queryParameters['d'];
  }
  if (uri.scheme == 'https' || uri.scheme == 'http') {
    if (uri.path.endsWith('/app/inventory/import')) {
      return _paramFromQueryString(fragment) ?? uri.queryParameters['d'];
    }
    return extractImportParamFromHash(fragment);
  }
  return null;
}

/// Form 3 — the fragment `/import?d=<d>` (with or without the leading `#`).
String? extractImportParamFromHash(String hash) {
  var h = hash.startsWith('#') ? hash.substring(1) : hash;
  if (!h.startsWith('/import')) return null;
  h = h.substring('/import'.length);
  if (h.startsWith('?')) h = h.substring(1);
  return _paramFromQueryString(h);
}

/// Pull the JWT out of an OAuth callback link (CLOUD-SYNC-CONTRACT §2.4),
/// or null when [uri] is not one. Accepted forms — the token rides in the
/// fragment so it never reaches a server log; `?token=` is tolerated:
///  1. `plantlyinventory://auth/callback#token=<jwt>`
///  2. `https://<host>/.../auth/callback#token=<jwt>`
///  3. `<inventory web>/#/auth/callback#token=<jwt>` (or `?token=`)
/// Anything that doesn't look like a three-segment JWT is rejected.
String? extractAuthToken(Uri uri) => extractAuthCallback(uri)?.token;

/// Token + the echoed `nonce` (null when the server sent none) of an OAuth
/// callback link, or null when [uri] is not one (incl. `#error=` /
/// `?error=` failure callbacks, which carry no token). Accepted forms:
///  - `plantlyinventory://auth/callback#token=<jwt>&nonce=<n>` (client=inventory)
///  - `<INVENTORY_WEB>/#/auth/callback?token=<jwt>&nonce=<n>` (client=inventory-web;
///    everything after the hash route stays in the fragment)
///  - the `%23`/`#token=` variant of the web form and `https://…/auth/callback#…`.
AuthCallback? extractAuthCallback(Uri uri) {
  if (uri.scheme == 'plantlyinventory') {
    final isCallback = uri.host == 'auth' && (uri.path == '/callback' || uri.path == 'callback');
    if (!isCallback) return null;
    return (_callbackFromQueryString(uri.fragment) ?? _callbackFromQueryString(uri.query))?.viaCustomScheme();
  }
  if (uri.scheme == 'https' || uri.scheme == 'http') {
    if (uri.path.endsWith('/auth/callback')) {
      return _callbackFromQueryString(uri.fragment) ?? _callbackFromQueryString(uri.query);
    }
    return extractAuthCallbackFromHash(uri.fragment);
  }
  return null;
}

class AuthCallback {
  const AuthCallback({required this.token, this.nonce, this.customScheme = false});
  final String token;
  final String? nonce;

  /// Arrived through `plantlyinventory://` (vs. the web hash route). Only
  /// this form may be accepted without a nonce (older servers).
  final bool customScheme;

  AuthCallback viaCustomScheme() => AuthCallback(token: token, nonce: nonce, customScheme: true);

  /// Never print the token.
  @override
  String toString() => 'AuthCallback(nonce=${nonce == null ? 'absent' : 'present'})';
}

/// Form 3 — the fragment `/auth/callback#token=<jwt>` / `/auth/callback?token=`.
String? extractAuthTokenFromHash(String hash) => extractAuthCallbackFromHash(hash)?.token;

AuthCallback? extractAuthCallbackFromHash(String hash) {
  var h = hash.startsWith('#') ? hash.substring(1) : hash;
  if (!h.startsWith('/auth/callback')) return null;
  h = h.substring('/auth/callback'.length);
  // `Uri.parse` keeps a second `#` inside the fragment percent-encoded.
  if (h.startsWith('%23')) {
    h = h.substring(3);
  } else if (h.startsWith('?') || h.startsWith('#')) {
    h = h.substring(1);
  } else if (h.isNotEmpty) {
    return null;
  }
  return _callbackFromQueryString(h);
}

final _jwtShape = RegExp(r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$');
final _nonceShape = RegExp(r'^[A-Za-z0-9_-]{16,64}$');

AuthCallback? _callbackFromQueryString(String qs) {
  if (qs.isEmpty) return null;
  String? token;
  String? nonce;
  try {
    final params = Uri.splitQueryString(qs);
    token = params['token'];
    nonce = params['nonce'];
  } on FormatException {
    token = RegExp(r'(?:^|&)token=([^&]+)').firstMatch(qs)?.group(1);
    nonce = RegExp(r'(?:^|&)nonce=([^&]+)').firstMatch(qs)?.group(1);
  }
  if (token == null || !_jwtShape.hasMatch(token)) return null;
  if (nonce != null && !_nonceShape.hasMatch(nonce)) nonce = null;
  return AuthCallback(token: token, nonce: nonce);
}

String? _paramFromQueryString(String qs) {
  if (qs.isEmpty) return null;
  try {
    final d = Uri.splitQueryString(qs)['d'];
    return d == null || d.isEmpty ? null : d;
  } on FormatException {
    // base64url never needs percent-decoding, but a stray '%' would throw.
    final m = RegExp(r'(?:^|&)d=([^&]+)').firstMatch(qs);
    return m?.group(1);
  }
}

final incomingLinksProvider = Provider<IncomingLinks>((ref) {
  final links = platform.createIncomingLinks();
  ref.onDispose(() => platform.disposeIncomingLinks(links));
  return links;
});
