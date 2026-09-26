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

  PlantlySession? get sessionOrNull => state.asData?.value;

  /// Every transition lands after an await (store / network); the notifier
  /// may have been disposed meanwhile, so never assign `state` blindly.
  void _set(AsyncValue<PlantlySession?> next) {
    if (mounted) state = next;
  }

  /// The usable session, refreshing first when it is inside the 12 h
  /// window. Returns null (and clears the store) when there is no session,
  /// it is malformed, or a needed refresh is refused by the server. A
  /// network failure during refresh keeps the old token if it is still
  /// valid — offline users shouldn't be logged out.
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
    final now = _now();
    if (session.needsRefresh(now)) {
      if (!session.isRefreshable(now)) {
        await signOut();
        return null;
      }
      try {
        final fresh = PlantlySession.fromToken(await _api.refresh(session.token));
        await _store.writeToken(fresh.token);
        session = fresh;
      } on PlantlyApiException {
        // Server refused (revoked / too old): the session is dead.
        await signOut();
        return null;
      } on PlantlyNetworkException {
        if (session.isExpired(now)) {
          await signOut();
          return null;
        }
        // Offline but still valid: keep going with the old token.
      } on FormatException {
        await signOut();
        return null;
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
    _set(AsyncValue.data(session));
    return session;
  }

  /// Adopt an externally obtained token (OAuth callback, tests).
  Future<PlantlySession> adoptToken(String token) async {
    final session = PlantlySession.fromToken(token);
    await _store.writeToken(token);
    _set(AsyncValue.data(session));
    return session;
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
