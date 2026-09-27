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
}

/// Riverpod view of [PlantlyFeatures.sellEnabled] so tests can exercise both
/// states without rebuilding.
final sellEnabledProvider = Provider<bool>((_) => PlantlyFeatures.sellEnabled);

/// Riverpod view of [PlantlyFeatures.cloudEnabled] (overridable in tests).
final cloudEnabledProvider = Provider<bool>((_) => PlantlyFeatures.cloudEnabled);
