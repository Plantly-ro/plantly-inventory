import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// QA B1 — every handoff deep link logged a caught
/// `Null check operator used on a null value` from
/// `_WidgetsAppState._onUnknownRoute` ← `didPushRouteInformation`: the
/// Flutter embedder forwarded each VIEW intent to the Navigator as a named
/// route *in addition to* app_links delivering it (incoming_links_io.dart
/// uses `getInitialLink` + `uriLinkStream`). Both platforms must opt out of
/// the framework's built-in deep-link routing.
void main() {
  test('AndroidManifest disables Flutter deep-linking inside <activity>', () {
    final xml = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final activityStart = xml.indexOf('<activity');
    final activityEnd = xml.indexOf('</activity>');
    expect(activityStart, greaterThan(-1));
    expect(activityEnd, greaterThan(activityStart));
    final activity = xml.substring(activityStart, activityEnd);
    final meta = RegExp(
      r'<meta-data\s+android:name="flutter_deeplinking_enabled"\s+android:value="false"\s*/>',
    );
    expect(meta.hasMatch(activity), isTrue,
        reason: 'flutter_deeplinking_enabled=false must sit inside the MainActivity element');
    // The intent-filters app_links relies on are still declared.
    expect(activity, contains('android:scheme="plantlyinventory"'));
    expect(activity, contains('android:host="plantly.ro"'));
  });

  test('AndroidManifest registers the shared-collection join links (§3)', () {
    final xml = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(xml, contains('android:scheme="plantlyinventory" android:host="join"'));
    for (final prefix in ['', '/ro', '/en']) {
      expect(xml, contains('android:path="$prefix/app/inventory/join"'));
    }
  });

  test('iOS Info.plist sets FlutterDeepLinkingEnabled = false', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final key = RegExp(r'<key>FlutterDeepLinkingEnabled</key>\s*<false/>');
    expect(key.hasMatch(plist), isTrue);
  });
}
