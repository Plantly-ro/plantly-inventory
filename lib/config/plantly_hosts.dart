import 'package:flutter/foundation.dart' show kIsWeb;

/// Marketplace host configuration (apps-integration CONTRACT §0).
///
/// Everything that talks to plantly.ro reads the base URL from the
/// `PLANTLY_HOST` dart-define so the same binary can target a preview
/// environment: `--dart-define=PLANTLY_HOST=https://development.agent-khepri.urundead.win`.
abstract final class PlantlyHosts {
  /// Marketplace API + web origin. Prod default; no trailing slash.
  static const String host = String.fromEnvironment(
    'PLANTLY_HOST',
    defaultValue: 'https://plantly.ro',
  );

  /// App version reported in the User-Agent. Overridable at build time so CI
  /// can stamp the real pubspec version without a code change.
  static const String appVersion = String.fromEnvironment(
    'PLANTLY_APP_VERSION',
    defaultValue: '1.0.0',
  );

  static String apiBase([String? origin]) => '${origin ?? host}/api/v1';

  /// `PlantlyInventory/<version> (+https://plantly.ro/app/inventory)` (§0).
  /// Browsers forbid overriding the User-Agent header, so callers skip it on
  /// web (see [PlantlyApi]).
  static String get userAgent =>
      'PlantlyInventory/$appVersion (+https://plantly.ro/app/inventory)';

  /// Whether the UA header can be sent by this platform's HTTP stack.
  static bool get canSendUserAgent => !kIsWeb;

  /// Marketplace auth page. The web page has a single sign-in/register
  /// surface with no `mode` query today, so both links land on `/auth`; the
  /// `mode` hint is still appended (harmless, forward-compatible with §1).
  static String authUrl({String? mode, String? origin}) {
    final base = '${origin ?? host}/auth';
    return mode == null ? base : '$base?mode=$mode';
  }

  /// Bare listing URL; the server redirects to the slugged form.
  static String postUrl(String id, {String? origin}) => '${origin ?? host}/posts/$id';
}
