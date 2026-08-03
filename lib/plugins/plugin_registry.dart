import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'export_plugin.dart';
import 'local_draft/local_draft_plugin.dart';

/// Compile-time registry of export plugins (a locked decision: no dynamic
/// plugin loading — plugins are registered here at build time). Phase 2 adds
/// the networked `plantly_ro` plugin to this list; until then the app ships
/// with the local-draft fallback only.
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
  return PluginRegistry([
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
