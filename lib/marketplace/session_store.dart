import 'package:flutter_riverpod/flutter_riverpod.dart';

// Platform half chosen at compile time (CONTRACT §1 token storage):
// flutter_secure_storage on io, localStorage in the browser — the same place
// the marketplace web app keeps its token.
import 'session_store_io.dart' if (dart.library.js_interop) 'session_store_web.dart' as platform;

/// Where the marketplace JWT lives between launches.
abstract class SessionStore {
  Future<String?> readToken();
  Future<void> writeToken(String token);
  Future<void> clear();
}

/// Test double / fallback — holds the token in memory only.
class InMemorySessionStore implements SessionStore {
  InMemorySessionStore([this._token]);
  String? _token;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> writeToken(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

final sessionStoreProvider = Provider<SessionStore>((_) => platform.createSessionStore());
