import 'dart:convert';

/// A signed-in marketplace session: the raw JWT plus the claims we read
/// client-side (CONTRACT §1 — HS256, `{user_id, username, iat, exp}`,
/// 24 h TTL). The payload is decoded, never verified: the server is the
/// only party that checks the signature.
class PlantlySession {
  const PlantlySession({
    required this.token,
    required this.username,
    required this.userId,
    required this.issuedAt,
    required this.expiresAt,
  });

  final String token;
  final String username;
  final String userId;
  final DateTime issuedAt;
  final DateTime expiresAt;

  /// Refresh when less than this much lifetime is left (§1: `exp - now < 12h`).
  static const Duration refreshWindow = Duration(hours: 12);

  /// `/auth/refresh` accepts tokens up to 30 days after `iat`.
  static const Duration maxRefreshAge = Duration(days: 30);

  /// Build a session from a JWT. Throws [FormatException] when the token is
  /// not a three-part JWT with a JSON payload carrying `exp`.
  factory PlantlySession.fromToken(String token) {
    final claims = decodeJwtPayload(token);
    final exp = claims['exp'];
    final iat = claims['iat'];
    if (exp is! num) throw const FormatException('jwt payload has no exp');
    return PlantlySession(
      token: token,
      username: (claims['username'] as String?) ?? '',
      userId: (claims['user_id'] as String?) ?? '',
      issuedAt: iat is num
          ? DateTime.fromMillisecondsSinceEpoch(iat.toInt() * 1000, isUtc: true)
          : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true),
    );
  }

  bool isExpired([DateTime? now]) => !(now ?? DateTime.now().toUtc()).isBefore(expiresAt);

  /// True when the token should be refreshed before the next write.
  bool needsRefresh([DateTime? now]) =>
      expiresAt.difference((now ?? DateTime.now()).toUtc()) < refreshWindow;

  /// True while the server will still accept this token on `/auth/refresh`.
  bool isRefreshable([DateTime? now]) =>
      (now ?? DateTime.now()).toUtc().difference(issuedAt) <= maxRefreshAge;

  /// Decode the middle segment of a JWT (base64url, padding optional) into
  /// its JSON claims. No signature check.
  static Map<String, dynamic> decodeJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) throw const FormatException('not a jwt');
    final raw = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final decoded = json.decode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('jwt payload is not an object');
    }
    return decoded;
  }

  @override
  String toString() => 'PlantlySession($username, exp=$expiresAt)';
}
