import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../export_plugin.dart';

/// The always-available fallback plugin: it doesn't talk to any marketplace,
/// it persists the draft locally (SharedPreferences) exactly as Phase 1 does.
///
/// This is what the export dialog uses until a networked plugin (plantly_ro)
/// is registered. Keeping the current behaviour behind the [ExportPlugin]
/// contract means the boundary is real and exercised now, not a Phase-2
/// afterthought — "Post now" just saves locally and reports success.
class LocalDraftExportPlugin implements ExportPlugin {
  LocalDraftExportPlugin({SharedPreferences? prefs}) : _injectedPrefs = prefs;

  /// Test seam — production leaves this null and uses the singleton instance.
  final SharedPreferences? _injectedPrefs;

  static const pluginId = 'local_draft';

  @override
  String get id => pluginId;

  @override
  PluginManifest get manifest => const PluginManifest(
        id: pluginId,
        displayName: 'Local draft',
        authType: PluginAuthType.none,
        // Mirrors plantly.ro's locked limits so drafts built here transfer to
        // the networked plugin without re-validation surprises.
        titleMaxLength: 64,
        descriptionMaxLength: 2000,
        maxPhotos: 6,
        priceCurrency: 'lei',
        supportsStatusUpdate: false,
      );

  Future<SharedPreferences> get _prefs async =>
      _injectedPrefs ?? await SharedPreferences.getInstance();

  static String _key(String plantId) => 'plantly_export_draft/$plantId';

  @override
  Future<AuthSession> authenticate(BuildContext ctx) async =>
      const AuthSession.anonymous();

  @override
  Future<void> storeCredentials(AuthSession session) async {}

  @override
  Future<AuthSession?> loadCredentials() async => const AuthSession.anonymous();

  @override
  Future<void> revoke() async {}

  @override
  Future<void> updateStatus(String remoteId, String newStatus) async {
    // Local drafts have no server-side status to update.
  }

  /// Load a previously-saved draft for [plantId], or null if none exists.
  Future<ExportDraft?> loadDraft(String plantId) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_key(plantId));
    if (raw == null) return null;
    try {
      return ExportDraft.fromJson(
          plantId, json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Malformed draft — treat as absent so the dialog falls back to defaults.
      return null;
    }
  }

  /// Persist [draft] as-is (used by "Save draft").
  Future<void> saveDraft(ExportDraft draft) async {
    final prefs = await _prefs;
    await prefs.setString(_key(draft.sourcePlantId), json.encode(draft.toJson()));
  }

  @override
  Future<ExportPreview> buildPreview(ExportDraft draft) async {
    final issues = <ExportIssue>[];
    if (draft.title.trim().isEmpty) {
      issues.add(const ExportIssue('title', 'Title is required'));
    }
    if (draft.title.length > manifest.titleMaxLength) {
      issues.add(ExportIssue(
          'title', 'Title exceeds ${manifest.titleMaxLength} characters'));
    }
    if (draft.description.length > manifest.descriptionMaxLength) {
      issues.add(ExportIssue('description',
          'Description exceeds ${manifest.descriptionMaxLength} characters'));
    }
    if (draft.photoRefs.length > manifest.maxPhotos) {
      issues.add(
          ExportIssue('photos', 'At most ${manifest.maxPhotos} photos'));
    }
    return ExportPreview(draft: draft, issues: issues);
  }

  @override
  Stream<ExportProgress> submit(ExportDraft draft) async* {
    final preview = await buildPreview(draft);
    if (!preview.isValid) {
      yield ExportProgress(
        fraction: 0,
        done: true,
        error: StateError(preview.issues.first.message),
      );
      return;
    }
    yield const ExportProgress(fraction: 0.3, message: 'Saving draft…');
    final posted = draft.copyWith(postedAt: DateTime.now().toUtc());
    await saveDraft(posted);
    // No network — the "remote id" is just the local key so the UI has a
    // stable handle; the real plantly_ro plugin returns a server id. No
    // message: the dialog shows its own localized "Draft saved".
    yield ExportProgress(
      fraction: 1,
      done: true,
      remoteId: _key(draft.sourcePlantId),
    );
  }
}
