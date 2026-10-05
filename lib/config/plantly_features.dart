import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Compile-time feature flags.
abstract final class PlantlyFeatures {
  /// "Sell on plantly.ro" (apps-integration CONTRACT §5). OFF by default until
  /// the marketplace side is ready: the `plantly_ro` plugin isn't registered,
  /// the export dialog is the local draft form with the local category list,
  /// the Me screen hides the account section and the export path never talks
  /// to `PLANTLY_HOST`. The import/handoff side (§4) is always on.
  ///
  /// Build with it on: `--dart-define=PLANTLY_SELL_ENABLED=true`.
  static const bool sellEnabled = bool.fromEnvironment('PLANTLY_SELL_ENABLED', defaultValue: false);

  /// Cloud backup & sync (CLOUD-SYNC-CONTRACT §0/§2.4). OFF by default on
  /// Android/iOS/desktop: the Me screen hides the Cloud section, nothing
  /// links a collection and the sync runner stays the no-op. Dev/preview
  /// builds pass `--dart-define=PLANTLY_CLOUD_ENABLED=true`.
  ///
  /// **Web is always ON** (WEB-ACCESS-POLICY §0): the browser build is the
  /// Inventory Cloud surface — using it needs a plantly.ro account with an
  /// active `inventory_cloud` entitlement (`cloud/web_access.dart`), so the
  /// define is ignored there. See [cloudEnabledFor].
  static const bool cloudEnabled = kIsWeb || _cloudDefine;

  static const bool _cloudDefine = bool.fromEnvironment('PLANTLY_CLOUD_ENABLED', defaultValue: false);

  /// The rule behind [cloudEnabled], testable off-web: web forces the flag
  /// on, every other platform follows the define.
  static bool cloudEnabledFor({required bool isWeb, required bool define}) => isWeb || define;

  /// Google Play in-app purchase of Inventory Cloud (PLAY-BILLING-CONTRACT
  /// §0). OFF by default; only meaningful together with [cloudEnabled] and
  /// only on Android — both true ⇒ the Cloud screen shows the Play plan
  /// picker instead of the no-link "available on plantly.ro" copy, and the
  /// app restores/verifies Play purchases on start + sign-in.
  /// `--dart-define=PLANTLY_PLAY_BILLING_ENABLED=true`.
  static const bool playBillingEnabled =
      bool.fromEnvironment('PLANTLY_PLAY_BILLING_ENABLED', defaultValue: false);

  /// "Continue with Facebook" on the plantly.ro login sheet. OFF by default
  /// (Paul, 2026-10-05: the Meta app is unpublished pending business
  /// verification, so the button only leads to a dead end). Only the entry
  /// button is gated — the OAuth callback/deep-link handling is provider-
  /// agnostic, so a session already obtained via Facebook keeps working.
  /// `--dart-define=PLANTLY_FACEBOOK_LOGIN_ENABLED=true`.
  static const bool facebookLoginEnabled =
      bool.fromEnvironment('PLANTLY_FACEBOOK_LOGIN_ENABLED', defaultValue: false);
}

/// Riverpod view of [PlantlyFeatures.sellEnabled] so tests can exercise both
/// states without rebuilding.
final sellEnabledProvider = Provider<bool>((_) => PlantlyFeatures.sellEnabled);

/// Riverpod view of [PlantlyFeatures.cloudEnabled] (overridable in tests).
final cloudEnabledProvider = Provider<bool>((_) => PlantlyFeatures.cloudEnabled);

/// Riverpod view of [PlantlyFeatures.playBillingEnabled] (overridable in tests).
final playBillingEnabledProvider = Provider<bool>((_) => PlantlyFeatures.playBillingEnabled);

/// Riverpod view of [PlantlyFeatures.facebookLoginEnabled] (overridable in tests).
final facebookLoginEnabledProvider = Provider<bool>((_) => PlantlyFeatures.facebookLoginEnabled);

/// `kIsWeb` as a provider so widget tests (which always run on the VM) can
/// exercise the web-only paths — the access gate, the forced cloud flag.
final webPlatformProvider = Provider<bool>((_) => kIsWeb);
