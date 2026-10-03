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

  /// Cloud backup & sync (CLOUD-SYNC-CONTRACT §0/§2.4). OFF by default: the
  /// Me screen hides the Cloud section, nothing links a collection and the
  /// sync runner stays the no-op. Dev/preview builds pass
  /// `--dart-define=PLANTLY_CLOUD_ENABLED=true`.
  static const bool cloudEnabled = bool.fromEnvironment('PLANTLY_CLOUD_ENABLED', defaultValue: false);

  /// Google Play in-app purchase of Inventory Cloud (PLAY-BILLING-CONTRACT
  /// §0). OFF by default; only meaningful together with [cloudEnabled] and
  /// only on Android — both true ⇒ the Cloud screen shows the Play plan
  /// picker instead of the no-link "available on plantly.ro" copy, and the
  /// app restores/verifies Play purchases on start + sign-in.
  /// `--dart-define=PLANTLY_PLAY_BILLING_ENABLED=true`.
  static const bool playBillingEnabled =
      bool.fromEnvironment('PLANTLY_PLAY_BILLING_ENABLED', defaultValue: false);
}

/// Riverpod view of [PlantlyFeatures.sellEnabled] so tests can exercise both
/// states without rebuilding.
final sellEnabledProvider = Provider<bool>((_) => PlantlyFeatures.sellEnabled);

/// Riverpod view of [PlantlyFeatures.cloudEnabled] (overridable in tests).
final cloudEnabledProvider = Provider<bool>((_) => PlantlyFeatures.cloudEnabled);

/// Riverpod view of [PlantlyFeatures.playBillingEnabled] (overridable in tests).
final playBillingEnabledProvider = Provider<bool>((_) => PlantlyFeatures.playBillingEnabled);
