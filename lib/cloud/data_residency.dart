import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/plantly_features.dart';
import 'collections.dart';

/// Where the collection lives right now — picks the variant of any copy
/// that makes a claim about it (onboarding, Me → Privacy & data). Purely
/// derived from the platform and the sync engine's own gate; no state.
enum DataResidency {
  /// Native app, no sync running and never linked: plants and photos
  /// exist only on this device (cloud flag off, or no account ever linked).
  deviceOnly,

  /// Native app with cloud sync running: on this device and mirrored to
  /// the plantly.ro account.
  deviceAndCloud,

  /// Native app that is linked to a home collection (the link survives
  /// sign-out) but not syncing — plan lapsed, signed out, entitlement still
  /// loading. Nothing new leaves the device; whatever was synced before
  /// stays in the plantly.ro account under the retention rules.
  syncPaused,

  /// The browser build — always Inventory Cloud: the plantly.ro account
  /// holds the collection, the browser keeps a working copy.
  web,
}

/// "Syncing" means exactly what the sync engine uses:
/// [activeCollectionIdProvider] names a collection. "Paused" = a remembered
/// home collection ([homeCollectionIdProvider]) without that.
final dataResidencyProvider = Provider<DataResidency>((ref) {
  if (ref.watch(webPlatformProvider)) return DataResidency.web;
  if (ref.watch(activeCollectionIdProvider) != null) return DataResidency.deviceAndCloud;
  // Flag off: no link can exist — don't spin up the link store for nothing.
  if (!ref.watch(cloudEnabledProvider)) return DataResidency.deviceOnly;
  return ref.watch(homeCollectionIdProvider) != null ? DataResidency.syncPaused : DataResidency.deviceOnly;
});
