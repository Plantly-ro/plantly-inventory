import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'plantly_api.dart';
import 'plantly_session.dart';
import 'session_store.dart';

/// Owns the marketplace session: persistence, the refresh-when-<12h policy
/// (CONTRACT §1) and a reactive `state` the Me screen / plugin watch.
///
/// `state` is `AsyncLoading` until the first read of the store completes,
/// then `AsyncData(session | null)`.
///
/// Clock policy (QA2 BUG-3): the DEVICE clock never ends a session. A token
/// that looks expired locally is refreshed (`/auth/refresh` is the
/// authority); the session is cleared only on an explicit 401 from that
/// call, or when the token is older than [PlantlySession.maxRefreshAge] by
/// SERVER time. Server time is learned from the `iat` of every token the
/// server hands us (login, OAuth callback, refresh) as a clock skew, so a
/// device running days ahead refreshes once and then judges the new token
/// correctly instead of hammering `/auth/refresh` on every read. Offline,
/// rate-limited or erroring refreshes keep the stored token.
class PlantlyAuth extends StateNotifier<AsyncValue<PlantlySession?>> {
  PlantlyAuth({
    required PlantlyApi api,
    required SessionStore store,
    DateTime Function()? now,
    bool autoLoad = true,
  })  : _api = api,
        _store = store,
        _now = now ?? (() => DateTime.now().toUtc()),
        super(const AsyncValue.loading()) {
    if (autoLoad) unawaited(current());
  }

  final PlantlyApi _api;
  final SessionStore _store;
  final DateTime Function() _now;
  Future<PlantlySession?>? _inflight;

  /// Local clock minus server clock, learned from server-issued tokens;
  /// null until the server has issued us a token in this process.
  Duration? _skew;

  /// Local time of the last refresh attempt the server did not answer with
  /// a verdict (offline / 429 / 5xx): no retry before [refreshRetryAfter].
  DateTime? _refreshDeferredAt;

  /// Quiet period after an inconclusive refresh attempt.
  static const Duration refreshRetryAfter = Duration(minutes: 1);

  /// Best estimate of the server's current time.
  DateTime get serverNow {
    final skew = _skew;
    return skew == null ? _now() : _now().subtract(skew);
  }

  /// Learned clock skew (tests / diagnostics); null = unknown.
  Duration? get clockSkew => _skew;

  PlantlySession? get sessionOrNull => state.asData?.value;

  /// Every transition lands after an await (store / network); the notifier
  /// may have been disposed meanwhile, so never assign `state` blindly.
  void _set(AsyncValue<PlantlySession?> next) {
    if (mounted) state = next;
  }

  /// A token the server just issued: its `iat` is "server now".
  void _learnSkew(PlantlySession fresh) {
    if (fresh.issuedAt.millisecondsSinceEpoch <= 0) return;
    _skew = _now().difference(fresh.issuedAt);
  }

  /// The usable session, refreshing first when it is inside the 12 h
  /// window (judged by server time when known). Returns null (and clears
  /// the store) when there is no session, it is malformed, the server
  /// answers the refresh with 401, or the token is past the 30-day refresh
  /// age by server time. Anything else keeps the stored token: a clock that
  /// is off, a flaky network or a rate limit must never log the user out.
  Future<PlantlySession?> current() {
    return _inflight ??= _load().whenComplete(() => _inflight = null);
  }

  Future<PlantlySession?> _load() async {
    final token = await _store.readToken();
    if (token == null || token.isEmpty) {
      _set(const AsyncValue.data(null));
      return null;
    }
    PlantlySession session;
    try {
      session = PlantlySession.fromToken(token);
    } on FormatException {
      await _store.clear();
      _set(const AsyncValue.data(null));
      return null;
    }
    if (session.needsRefresh(serverNow)) {
      if (_skew != null && !session.isRefreshable(serverNow)) {
        // Older than 30 days by SERVER time: the server would refuse anyway.
        await signOut();
        return null;
      }
      final deferred = _refreshDeferredAt;
      if (deferred == null || _now().difference(deferred).abs() >= refreshRetryAfter) {
        try {
          final fresh = PlantlySession.fromToken(await _api.refresh(session.token));
          await _store.writeToken(fresh.token);
          _learnSkew(fresh);
          _refreshDeferredAt = null;
          session = fresh;
        } on PlantlyApiException catch (e) {
          if (e.isUnauthorized) {
            // The server's verdict: revoked / too old. The session is dead.
            await signOut();
            return null;
          }
          // 429 / 5xx / anything else: no verdict — keep the token, retry later.
          _refreshDeferredAt = _now();
        } on PlantlyNetworkException {
          // Offline: expiry is the server's call, not the device clock's.
          _refreshDeferredAt = _now();
        } on FormatException {
          // Malformed refresh reply: keep the token we have.
          _refreshDeferredAt = _now();
        }
      }
    }
    _set(AsyncValue.data(session));
    return session;
  }

  /// Email + password → persisted session. Throws [PlantlyApiException] /
  /// [PlantlyNetworkException] straight through for the UI to map.
  Future<PlantlySession> signIn(String email, String password) async {
    final result = await _api.login(email.trim(), password);
    final session = PlantlySession.fromToken(result.token);
    await _store.writeToken(session.token);
    _learnSkew(session);
    _refreshDeferredAt = null;
    _set(AsyncValue.data(session));
    return session;
  }

  /// Adopt an externally obtained token (OAuth callback, tests).
  Future<PlantlySession> adoptToken(String token) async {
    final session = PlantlySession.fromToken(token);
    await _store.writeToken(token);
    // An OAuth callback token was minted moments ago — server time too.
    _learnSkew(session);
    _refreshDeferredAt = null;
    _set(AsyncValue.data(session));
    return session;
  }

  /// A call outside this notifier was answered 401 with the stored token:
  /// ask `/auth/refresh` before giving up on the session (a token the
  /// device clock thought valid may simply have been rotated). Returns the
  /// refreshed session; null when the server rejected the refresh too (the
  /// session is then dropped — data on this device stays) or gave no
  /// verdict (offline / 5xx: the token is kept).
  Future<PlantlySession?> refreshAfterUnauthorized() async {
    final token = await _store.readToken();
    if (token == null || token.isEmpty) return null;
    try {
      final fresh = PlantlySession.fromToken(await _api.refresh(token));
      await _store.writeToken(fresh.token);
      _learnSkew(fresh);
      _refreshDeferredAt = null;
      _set(AsyncValue.data(fresh));
      return fresh;
    } on PlantlyApiException catch (e) {
      if (e.isUnauthorized) await signOut();
      return null;
    } on PlantlyNetworkException {
      return null;
    } on FormatException {
      return null;
    }
  }

  /// Drop the token. There is no logout route (§1).
  Future<void> signOut() async {
    await _store.clear();
    _set(const AsyncValue.data(null));
  }
}

/// Shared `http.Client` — one connection pool for every marketplace call.
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final plantlyApiProvider = Provider<PlantlyApi>((ref) {
  return PlantlyApi(client: ref.watch(httpClientProvider));
});

final plantlyAuthProvider = StateNotifierProvider<PlantlyAuth, AsyncValue<PlantlySession?>>((ref) {
  return PlantlyAuth(api: ref.watch(plantlyApiProvider), store: ref.watch(sessionStoreProvider));
});
