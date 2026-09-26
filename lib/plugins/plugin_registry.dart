import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/plantly_features.dart';
import '../data/providers.dart';
import '../marketplace/listing_records.dart';
import '../marketplace/plantly_auth.dart';
import '../marketplace/upload_image_prep.dart';
import 'export_plugin.dart';
import 'local_draft/local_draft_plugin.dart';
import 'plantly_ro/plantly_ro_plugin.dart';

/// Compile-time registry of export plugins (a locked decision: no dynamic
/// plugin loading — plugins are registered here at build time). `plantly_ro`
/// is registered first so it is the default; `local_draft` stays as the
/// marketplace-agnostic draft store.
class PluginRegistry {
  PluginRegistry(this._plugins);

  final List<ExportPlugin> _plugins;

  List<ExportPlugin> get all => List.unmodifiable(_plugins);

  ExportPlugin? byId(String id) {
    for (final p in _plugins) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// The plugin the export dialog targets by default. Prefers the first
  /// networked marketplace plugin if one is registered, else the local draft
  /// store — so wiring up `plantly_ro` later flips the default with no dialog
  /// change.
  ExportPlugin get defaultPlugin {
    for (final p in _plugins) {
      if (p.manifest.authType != PluginAuthType.none) return p;
    }
    return _plugins.first;
  }
}

/// The single app-wide registry. Add new plugins to the list here.
final pluginRegistryProvider = Provider<PluginRegistry>((ref) {
  final sell = ref.watch(sellEnabledProvider);
  return PluginRegistry([
    // Behind PLANTLY_SELL_ENABLED: with the flag off the registry is exactly
    // the pre-marketplace one (local_draft only, and therefore the default).
    if (sell)
      PlantlyRoExportPlugin(
      api: ref.watch(plantlyApiProvider),
      auth: ref.watch(plantlyAuthProvider.notifier),
      records: ref.watch(listingRecordsProvider.notifier),
      preparer: ref.watch(uploadImagePreparerProvider),
      // Resolved lazily: the photo repository only exists after bootstrap,
      // and submit() runs long after that.
      photoBytes: (sha) async {
        final repo = ref.read(photoRepositoryProvider);
        final row = await repo.byHash(sha);
        return row == null ? null : repo.bytesFor(row);
      },
    ),
    LocalDraftExportPlugin(),
  ]);
});

/// Convenience: the export dialog's target plugin.
final defaultExportPluginProvider = Provider<ExportPlugin>((ref) {
  return ref.watch(pluginRegistryProvider).defaultPlugin;
});

/// The local draft store, used for marketplace-agnostic "Save draft" / resume
/// regardless of which plugin a post is submitted through.
final localDraftStoreProvider = Provider<LocalDraftExportPlugin>((ref) {
  return ref.watch(pluginRegistryProvider).byId(LocalDraftExportPlugin.pluginId)
      as LocalDraftExportPlugin;
});

/// The marketplace plugin, typed — for the Me screen account section and the
/// plant-detail "Listed on plantly.ro" row. Null while selling is disabled.
final plantlyRoPluginProvider = Provider<PlantlyRoExportPlugin?>((ref) {
  return ref.watch(pluginRegistryProvider).byId(PlantlyRoExportPlugin.pluginId) as PlantlyRoExportPlugin?;
});
