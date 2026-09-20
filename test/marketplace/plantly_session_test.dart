import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/marketplace/plantly_session.dart';

/// Unsigned HS256-shaped token — the client only reads the payload.
String fakeJwt({
  required int iat,
  required int exp,
  String username = 'alice',
  String userId = 'u-1',
}) {
  String seg(Map<String, Object> m) => base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  return '${seg({'alg': 'HS256', 'typ': 'JWT'})}.${seg({
        'user_id': userId,
        'username': username,
        'iat': iat,
        'exp': exp,
      })}.sig';
}

void main() {
  final now = DateTime.utc(2026, 9, 19, 12);
  int secs(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

  group('PlantlySession.fromToken', () {
    test('decodes username / user_id / iat / exp from the payload (no padding)', () {
      final s = PlantlySession.fromToken(fakeJwt(
        iat: secs(now.subtract(const Duration(hours: 1))),
        exp: secs(now.add(const Duration(hours: 23))),
      ));
      expect(s.username, 'alice');
      expect(s.userId, 'u-1');
      expect(s.issuedAt, now.subtract(const Duration(hours: 1)));
      expect(s.expiresAt, now.add(const Duration(hours: 23)));
    });

    test('rejects non-JWT strings and payloads without exp', () {
      expect(() => PlantlySession.fromToken('nope'), throwsFormatException);
      expect(() => PlantlySession.fromToken('a.b'), throwsFormatException);
      final noExp = '${base64Url.encode(utf8.encode('{}'))}.${base64Url.encode(utf8.encode('{"username":"x"}'))}.s';
      expect(() => PlantlySession.fromToken(noExp), throwsFormatException);
    });

    test('decodeJwtPayload tolerates padded segments', () {
      final payload = base64Url.encode(utf8.encode('{"exp":1,"a":"b"}'));
      expect(payload, endsWith('=')); // proves padding is present
      final claims = PlantlySession.decodeJwtPayload('h.$payload.s');
      expect(claims['a'], 'b');
    });
  });

  group('refresh policy (§1: exp - now < 12h)', () {
    test('fresh token does not need refresh', () {
      final s = PlantlySession.fromToken(fakeJwt(iat: secs(now), exp: secs(now.add(const Duration(hours: 24)))));
      expect(s.needsRefresh(now), isFalse);
      expect(s.isExpired(now), isFalse);
    });

    test('token inside the 12h window needs refresh', () {
      final s = PlantlySession.fromToken(fakeJwt(
        iat: secs(now.subtract(const Duration(hours: 13))),
        exp: secs(now.add(const Duration(hours: 11))),
      ));
      expect(s.needsRefresh(now), isTrue);
      expect(s.isExpired(now), isFalse);
    });

    test('expired token needs refresh and is still refreshable within 30 days of iat', () {
      final s = PlantlySession.fromToken(fakeJwt(
        iat: secs(now.subtract(const Duration(days: 10))),
        exp: secs(now.subtract(const Duration(days: 9))),
      ));
      expect(s.isExpired(now), isTrue);
      expect(s.needsRefresh(now), isTrue);
      expect(s.isRefreshable(now), isTrue);
    });

    test('token older than 30 days is not refreshable', () {
      final s = PlantlySession.fromToken(fakeJwt(
        iat: secs(now.subtract(const Duration(days: 31))),
        exp: secs(now.subtract(const Duration(days: 30))),
      ));
      expect(s.isRefreshable(now), isFalse);
    });
  });
}
