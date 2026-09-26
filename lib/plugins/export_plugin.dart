import 'package:flutter/widgets.dart';

/// The marketplace-export boundary.
///
/// The Flutter core never talks to plantly.ro (or any marketplace) directly —
/// it only knows this contract. A concrete plugin (e.g. `plantly_ro`, landing
/// in Phase 2) implements the network side; the app registers it in
/// `plugin_registry.dart`. Keeping this the single coupling point is a locked
/// decision (see CLAUDE.md "What to avoid" + PLAN.md §"ExportPlugin contract").
///
/// The field/limit shape below is fixed by PLAN.md §Context and mirrored by the
/// export dialog: title ≤64, description ≤2000, price in lei, a category,
/// county + city, and ≤6 photos referenced by content hash.
abstract class ExportPlugin {
  /// Stable machine id, e.g. `'plantly_ro'` or `'local_draft'`.
  String get id;

  /// Static description of the plugin's fields, limits, and auth style.
  PluginManifest get manifest;

  /// Interactively obtain an [AuthSession] (may push a login screen). Plugins
  /// that need no credentials (e.g. the local draft store) return a session
  /// with [AuthSession.anonymous] set.
  Future<AuthSession> authenticate(BuildContext ctx);

  /// Persist credentials securely (flutter_secure_storage in networked
  /// plugins). No-op for credential-less plugins.
  Future<void> storeCredentials(AuthSession session);

  /// Load previously-stored credentials, or null if the user isn't signed in.
  Future<AuthSession?> loadCredentials();

  /// Resolve a draft into a preview: normalised fields plus any validation
  /// issues (over-length text, missing required fields, too many photos).
  Future<ExportPreview> buildPreview(ExportDraft draft);

  /// Submit the draft, streaming progress and ending with a terminal event
  /// that carries the remote id + url (on success) or an error.
  Stream<ExportProgress> submit(ExportDraft draft);

  /// Change the status of an already-submitted listing (e.g. mark sold).
  Future<void> updateStatus(String remoteId, String newStatus);

  /// Sign out / forget stored credentials.
  Future<void> revoke();
}

/// How a plugin authenticates.
enum PluginAuthType {
  /// No credentials required (local-only plugins).
  none,

  /// Username/password exchanged for a bearer token.
  jwt,

  /// OAuth-style redirect flow.
  oauth,
}

/// Static, compile-time description of a plugin's capabilities. Drives the
/// dialog's field limits and gating so the UI doesn't hard-code them.
@immutable
class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.displayName,
    required this.authType,
    this.titleMaxLength = 64,
    this.descriptionMaxLength = 2000,
    this.maxPhotos = 6,
    this.priceCurrency = 'lei',
    this.supportsStatusUpdate = false,
  });

  final String id;
  final String displayName;
  final PluginAuthType authType;
  final int titleMaxLength;
  final int descriptionMaxLength;
  final int maxPhotos;
  final String priceCurrency;

  /// Whether [ExportPlugin.updateStatus] is meaningful (e.g. mark-sold).
  final bool supportsStatusUpdate;
}

/// An authenticated session with a marketplace. [anonymous] sessions are the
/// convention for plugins that need no login.
@immutable
class AuthSession {
  const AuthSession({
    this.token,
    this.accountLabel,
    this.expiresAt,
    this.anonymous = false,
  });

  /// A credential-less session for local-only plugins.
  const AuthSession.anonymous()
      : token = null,
        accountLabel = null,
        expiresAt = null,
        anonymous = true;

  final String? token;

  /// Human-facing label for the signed-in account (shown in the UI).
  final String? accountLabel;
  final DateTime? expiresAt;
  final bool anonymous;

  bool get isExpired =>
      expiresAt != null && DateTime.now().toUtc().isAfter(expiresAt!.toUtc());
}

/// The user-editable listing, decoupled from any plant row so plugins never
/// depend on the Drift schema. Photos are referenced by content hash (sha256),
/// resolved to bytes by the plugin at submit time.
@immutable
class ExportDraft {
  const ExportDraft({
    required this.sourcePlantId,
    required this.title,
    required this.description,
    this.priceLei,
    this.category,
    this.categoryLabel,
    this.county,
    this.city,
    this.photoRefs = const [],
    this.postedAt,
  });

  /// The plant this draft was built from — used to key local persistence.
  final String sourcePlantId;
  final String title;
  final String description;

  /// Price in whole lei. Null while the user hasn't entered one.
  final int? priceLei;
  final String? category;

  /// Human-readable name/path of [category] for display when a draft is
  /// resumed (the marketplace `category` is an opaque UUID). Purely
  /// presentational — plugins submit [category] only.
  final String? categoryLabel;
  final String? county;
  final String? city;

  /// Content hashes (sha256) of attached photos, in display order, ≤ manifest
  /// maxPhotos.
  final List<String> photoRefs;

  /// Set once the draft has been posted (locally or remotely).
  final DateTime? postedAt;

  ExportDraft copyWith({
    String? title,
    String? description,
    int? priceLei,
    String? category,
    String? categoryLabel,
    String? county,
    String? city,
    List<String>? photoRefs,
    DateTime? postedAt,
  }) {
    return ExportDraft(
      sourcePlantId: sourcePlantId,
      title: title ?? this.title,
      description: description ?? this.description,
      priceLei: priceLei ?? this.priceLei,
      category: category ?? this.category,
      categoryLabel: categoryLabel ?? this.categoryLabel,
      county: county ?? this.county,
      city: city ?? this.city,
      photoRefs: photoRefs ?? this.photoRefs,
      postedAt: postedAt ?? this.postedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'source_plant_id': sourcePlantId,
        'title': title,
        'description': description,
        if (priceLei != null) 'price_lei': priceLei,
        if (category != null) 'category': category,
        // Additive (issue #11): absent in drafts saved before it existed.
        if (categoryLabel != null) 'category_label': categoryLabel,
        if (county != null) 'county': county,
        if (city != null) 'city': city,
        'photos': photoRefs,
        if (postedAt != null) 'posted_at': postedAt!.toUtc().toIso8601String(),
      };

  static ExportDraft fromJson(String sourcePlantId, Map<String, dynamic> m) {
    return ExportDraft(
      sourcePlantId: sourcePlantId,
      title: (m['title'] as String?) ?? '',
      description: (m['description'] as String?) ?? '',
      // `price_lei` (int) is the current shape; `price` (string) is the
      // legacy pre-plugin key kept so existing on-disk drafts still resume.
      priceLei: switch (m['price_lei'] ?? m['price']) {
        final int v => v,
        final String v => int.tryParse(v),
        _ => null,
      },
      category: m['category'] as String?,
      categoryLabel: m['category_label'] as String?,
      county: m['county'] as String?,
      city: m['city'] as String?,
      photoRefs: (m['photos'] as List?)?.cast<String>() ?? const [],
      postedAt: switch (m['posted_at']) {
        final String v => DateTime.tryParse(v),
        _ => null,
      },
    );
  }
}

/// A single validation problem with a draft, keyed to the offending field so
/// the UI can highlight it.
@immutable
class ExportIssue {
  const ExportIssue(this.field, this.message);
  final String field;
  final String message;
}

/// The normalised, validated view of a draft the plugin is willing to submit.
@immutable
class ExportPreview {
  const ExportPreview({required this.draft, this.issues = const []});
  final ExportDraft draft;
  final List<ExportIssue> issues;
  bool get isValid => issues.isEmpty;
}

/// One progress tick from [ExportPlugin.submit]. The terminal tick has
/// [done] true and either [remoteId]/[url] populated or [error] set.
@immutable
class ExportProgress {
  const ExportProgress({
    required this.fraction,
    this.message,
    this.remoteId,
    this.url,
    this.error,
    this.done = false,
  });

  /// 0.0 → 1.0 completion.
  final double fraction;
  final String? message;

  /// Remote listing id, set on the terminal success tick.
  final String? remoteId;

  /// Public listing url, set on the terminal success tick.
  final String? url;

  /// Set on the terminal failure tick.
  final Object? error;
  final bool done;

  bool get succeeded => done && error == null;
}
