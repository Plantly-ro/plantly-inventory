import 'package:flutter/foundation.dart' show kIsWeb;

/// Marketplace host configuration (apps-integration CONTRACT §0).
///
/// Everything that talks to plantly.ro reads the base URL from the
/// `PLANTLY_HOST` dart-define so the same binary can target a preview
/// environment: `--dart-define=PLANTLY_HOST=https://development.agent-khepri.urundead.win`.
abstract final class PlantlyHosts {
  static const String _hostDefine = String.fromEnvironment(
    'PLANTLY_HOST',
    defaultValue: 'https://plantly.ro',
  );

  /// Marketplace API + web origin. Prod default; trailing slashes stripped so
  /// a `--dart-define=PLANTLY_HOST=https://x/` doesn't produce `//api`.
  static String get host => _hostDefine.replaceAll(RegExp(r'/+$'), '');

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

  /// OAuth entry point for the Inventory client (CLOUD-SYNC-CONTRACT §2.4):
  /// the marketplace runs the provider dance and lands on
  /// `plantlyinventory://auth/callback#token=<jwt>` (web: `/#/auth/callback`).
  /// `client` picks the callback shape the monolith redirects to:
  /// `inventory` → `plantlyinventory://auth/callback#token=<jwt>&nonce=<n>`,
  /// `inventory-web` → `<INVENTORY_WEB>/#/auth/callback?token=<jwt>&nonce=<n>`
  /// (failures: `#error=` / `?error=`). `nonce` (random, per attempt) is
  /// echoed back verbatim — see `cloud/oauth_handshake.dart`.
  static String oauthStartUrl(String provider, {String? origin, String? nonce, String? client}) {
    final c = client ?? oauthClient;
    final n = nonce == null ? '' : '&nonce=${Uri.encodeQueryComponent(nonce)}';
    return '${apiBase(origin)}/auth/oauth/$provider/start?client=$c$n';
  }

  /// `inventory-web` in the browser build, `inventory` everywhere else.
  static String get oauthClient => kIsWeb ? 'inventory-web' : 'inventory';

  /// Subscription page on the marketplace, pre-selecting a product tab
  /// (§4). Only linked from web/desktop builds — never from Android/iOS.
  static String subscriptionUrl({String product = 'inventory_cloud', String? origin}) =>
      '${origin ?? host}/account/subscription?product=$product';

  /// Google Play listing of the Android app (the free, local-first build the
  /// web gate points phone users to — WEB-ACCESS-POLICY §0).
  static const String playStoreUrl = 'https://play.google.com/store/apps/details?id=ro.plantly.inventory';

  /// `X-Plantly-Client` value logged by the inventory routes (§2.2).
  static String get clientHeader => 'inventory/$appVersion';
}
