import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session_store.dart';

SessionStore createSessionStore() => SecureSessionStore();

/// Keychain / EncryptedSharedPreferences-backed token store.
class SecureSessionStore implements SessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'plantly_ro/jwt';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> readToken() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      // A corrupt keystore entry must not brick the app — treat as signed out.
      return null;
    }
  }

  @override
  Future<void> writeToken(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
