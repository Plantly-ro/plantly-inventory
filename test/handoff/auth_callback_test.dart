import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/handoff/incoming_links.dart';

/// OAuth callback deep link (CLOUD-SYNC-CONTRACT §2.4): token in the
/// fragment (never logged server-side), `?token=` tolerated, garbage refused.
void main() {
  const jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoidS0xIn0.c2ln';

  group('extractAuthToken', () {
    test('1. custom scheme plantlyinventory://auth/callback#token=', () {
      expect(extractAuthToken(Uri.parse('plantlyinventory://auth/callback#token=$jwt')), jwt);
      expect(extractAuthToken(Uri.parse('plantlyinventory://auth/callback?token=$jwt')), jwt);
      expect(extractAuthToken(Uri.parse('plantlyinventory://auth/callback#token=$jwt&state=x')), jwt);
    });

    test('2. https page …/auth/callback#token=', () {
      expect(extractAuthToken(Uri.parse('https://plantly.ro/app/inventory/auth/callback#token=$jwt')), jwt);
      expect(extractAuthToken(Uri.parse('https://development.agent-khepri.urundead.win/auth/callback?token=$jwt')), jwt);
    });

    test('3. inventory web hash route /#/auth/callback#token= and ?token=', () {
      expect(extractAuthToken(Uri.parse('http://127.0.0.1:8099/#/auth/callback#token=$jwt')), jwt);
      expect(extractAuthToken(Uri.parse('https://inventory.plantly.ro/#/auth/callback?token=$jwt')), jwt);
      expect(extractAuthTokenFromHash('#/auth/callback#token=$jwt'), jwt);
      expect(extractAuthTokenFromHash('/auth/callback?token=$jwt'), jwt);
    });

    test('rejects garbage and non-callback links', () {
      expect(extractAuthToken(Uri.parse('plantlyinventory://auth/callback')), isNull);
      expect(extractAuthToken(Uri.parse('plantlyinventory://auth/callback#token=')), isNull);
      expect(extractAuthToken(Uri.parse('plantlyinventory://auth/callback#token=not-a-jwt')), isNull);
      expect(extractAuthToken(Uri.parse('plantlyinventory://auth/callback#token=a.b')), isNull);
      expect(extractAuthToken(Uri.parse('plantlyinventory://auth/callback#token=<script>.x.y')), isNull);
      expect(extractAuthToken(Uri.parse('plantlyinventory://auth/other#token=$jwt')), isNull);
      expect(extractAuthToken(Uri.parse('plantlyinventory://import#d=abc')), isNull);
      expect(extractAuthToken(Uri.parse('https://plantly.ro/posts/abc#token=$jwt')), isNull);
      expect(extractAuthToken(Uri.parse('http://127.0.0.1:8099/#/plants/1')), isNull);
      expect(extractAuthToken(Uri.parse('http://127.0.0.1:8099/#/auth/callbackx?token=$jwt')), isNull);
      expect(extractAuthTokenFromHash(''), isNull);
      expect(extractAuthTokenFromHash('/auth/callback'), isNull);
    });

    test('nonce is extracted from the same query string (fragment or query, any order)', () {
      const n = 'abcDEF123_-abcDEF123_-abcDEF1234';
      final native = extractAuthCallback(Uri.parse('plantlyinventory://auth/callback#token=$jwt&nonce=$n'));
      expect(native?.nonce, n);
      expect(native?.customScheme, isTrue);
      expect(extractAuthCallback(Uri.parse('plantlyinventory://auth/callback#nonce=$n&token=$jwt'))?.nonce, n);
      // client=inventory-web shape: `?token=` AFTER the hash route.
      final web = extractAuthCallback(Uri.parse('https://inventory.plantly.ro/#/auth/callback?token=$jwt&nonce=$n'));
      expect(web?.token, jwt);
      expect(web?.nonce, n);
      expect(web?.customScheme, isFalse);
      expect(extractAuthCallback(Uri.parse('http://127.0.0.1:8099/#/auth/callback#token=$jwt&nonce=$n'))?.nonce, n);
      expect(extractAuthCallback(Uri.parse('plantlyinventory://auth/callback#token=$jwt'))?.nonce, isNull);
      // Failure callbacks carry no token → not a sign-in.
      expect(extractAuthCallback(Uri.parse('plantlyinventory://auth/callback#error=access_denied')), isNull);
      expect(extractAuthCallback(Uri.parse('https://inventory.plantly.ro/#/auth/callback?error=access_denied')), isNull);
      // Out-of-spec nonce (too short) is dropped, token still parsed.
      expect(extractAuthCallback(Uri.parse('plantlyinventory://auth/callback#token=$jwt&nonce=short'))?.nonce, isNull);
      // Malformed nonce is dropped (treated as absent), token still parsed.
      final odd = extractAuthCallback(Uri.parse('plantlyinventory://auth/callback#token=$jwt&nonce=<x>'));
      expect(odd?.token, jwt);
      expect(odd?.nonce, isNull);
      expect('${extractAuthCallback(Uri.parse('plantlyinventory://auth/callback#token=$jwt'))}', isNot(contains(jwt)));
    });

    test('an import link is never mistaken for an auth link and vice versa', () {
      final auth = Uri.parse('plantlyinventory://auth/callback#token=$jwt');
      expect(extractImportParam(auth), isNull);
      final import = Uri.parse('plantlyinventory://import#d=eyJzY2hlbWFWZXJzaW9uIjoxfQ');
      expect(extractAuthToken(import), isNull);
    });
  });

  group('platform registration', () {
    test('AndroidManifest declares the auth/callback intent-filter beside the import one', () {
      final xml = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      final activity = xml.substring(xml.indexOf('<activity'), xml.indexOf('</activity>'));
      final filter = RegExp(
        r'<data\s+android:scheme="plantlyinventory"\s+android:host="auth"\s+android:path="/callback"\s*/>',
      );
      expect(filter.hasMatch(activity), isTrue);
      expect(activity, contains('android:scheme="plantlyinventory" android:host="import"'));
    });

    test('iOS Info.plist registers the plantlyinventory URL scheme', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, contains('<key>CFBundleURLTypes</key>'));
      expect(RegExp(r'<key>CFBundleURLSchemes</key>\s*<array>\s*<string>plantlyinventory</string>').hasMatch(plist), isTrue);
    });
  });

  group('isAuthCallbackPath — path-URL web build', () {
    const jwt = 'aaa.bbb.ccc';
    test('matches /auth/callback with or without base href / trailing slash', () {
      expect(isAuthCallbackPath('/auth/callback'), isTrue);
      expect(isAuthCallbackPath('/auth/callback/'), isTrue);
      expect(isAuthCallbackPath('/inventory/auth/callback'), isTrue);
      expect(isAuthCallbackPath('/'), isFalse);
      expect(isAuthCallbackPath('/auth/callbacks'), isFalse);
      expect(isAuthCallbackPath('/me/cloud'), isFalse);
    });

    test('path form ?token=&nonce= and #token= both parse; hash-on-root still parses', () {
      const nonce = 'abcdefghijklmnop0123456789';
      final path = extractAuthCallback(Uri.parse('https://inv.example/auth/callback?token=$jwt&nonce=$nonce'));
      expect(path?.token, jwt);
      expect(path?.nonce, nonce);
      expect(path?.customScheme, isFalse);
      expect(extractAuthCallback(Uri.parse('https://inv.example/auth/callback/#token=$jwt'))?.token, jwt);
      // What the server actually sends (`/#/auth/callback?…`) arrives under
      // the path strategy as location `/` + hash — must keep working.
      final hash = extractAuthCallback(Uri.parse('https://inv.example/#/auth/callback?token=$jwt&nonce=$nonce'));
      expect(hash?.token, jwt);
      expect(hash?.nonce, nonce);
    });
  });
}
