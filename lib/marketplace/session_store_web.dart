import 'package:web/web.dart' as web;

import 'session_store.dart';

SessionStore createSessionStore() => LocalStorageSessionStore();

/// Browser store — `localStorage`, mirroring how the marketplace web app
/// persists its own session (CONTRACT §1).
class LocalStorageSessionStore implements SessionStore {
  static const _key = 'plantly_ro/jwt';

  @override
  Future<String?> readToken() async => web.window.localStorage.getItem(_key);

  @override
  Future<void> writeToken(String token) async => web.window.localStorage.setItem(_key, token);

  @override
  Future<void> clear() async => web.window.localStorage.removeItem(_key);
}
