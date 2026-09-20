import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../config/plantly_hosts.dart';
import '../../marketplace/listing_records.dart';
import '../../marketplace/plantly_api.dart';
import '../../marketplace/plantly_auth.dart';
import '../../marketplace/plantly_session.dart';
import '../../marketplace/upload_image_prep.dart';
import '../export_plugin.dart';
import 'login_sheet.dart';

/// The networked marketplace plugin (apps-integration CONTRACT §5). Speaks
/// to plantly.ro through [PlantlyApi]; the session lives in [PlantlyAuth];
/// the "this plant is listed" memory lives in [ListingRecords].
class PlantlyRoExportPlugin implements ExportPlugin {
  PlantlyRoExportPlugin({
    required PlantlyApi api,
    required PlantlyAuth auth,
    required ListingRecords records,
    required Future<Uint8List?> Function(String sha) photoBytes,
    required UploadImagePreparer preparer,
    String? host,
    DateTime Function()? now,
  })  : _api = api,
        _auth = auth,
        _records = records,
        _photoBytes = photoBytes,
        _preparer = preparer,
        _host = host ?? PlantlyHosts.host,
        _now = now ?? (() => DateTime.now().toUtc());

  static const pluginId = 'plantly_ro';

  /// Price string accepted by the server: whole lei or up to 2 decimals.
  static final priceRe = RegExp(r'^[0-9]+(\.[0-9]{1,2})?$');

  /// Marketplace category ids are UUIDs (§5: draft `category` = UUID).
  static final uuidRe = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
  static bool isCategoryId(String? v) => v != null && uuidRe.hasMatch(v.trim());

  final PlantlyApi _api;
  final PlantlyAuth _auth;
  final ListingRecords _records;
  final Future<Uint8List?> Function(String sha) _photoBytes;
  final UploadImagePreparer _preparer;
  final String _host;
  final DateTime Function() _now;

  PlantlyAuth get auth => _auth;
  ListingRecords get records => _records;

  @override
  String get id => pluginId;

  @override
  PluginManifest get manifest => const PluginManifest(
        id: pluginId,
        displayName: 'plantly.ro',
        authType: PluginAuthType.jwt,
        titleMaxLength: 64,
        descriptionMaxLength: 2000,
        maxPhotos: 6,
        priceCurrency: 'lei',
        supportsStatusUpdate: true,
      );

  static AuthSession _toAuthSession(PlantlySession s) => AuthSession(
        token: s.token,
        accountLabel: s.username,
        expiresAt: s.expiresAt,
      );

  /// Opens the email/password sheet. Throws [PlantlyAuthCancelled] when the
  /// user dismisses it without signing in.
  @override
  Future<AuthSession> authenticate(BuildContext ctx) async {
    final session = await showPlantlyLoginSheet(ctx, auth: _auth, host: _host);
    if (session == null) throw const PlantlyAuthCancelled();
    return _toAuthSession(session);
  }

  @override
  Future<void> storeCredentials(AuthSession session) async {
    final token = session.token;
    if (token == null || token.isEmpty) return;
    await _auth.adoptToken(token);
  }

  @override
  Future<AuthSession?> loadCredentials() async {
    final s = await _auth.current();
    return s == null ? null : _toAuthSession(s);
  }

  @override
  Future<void> revoke() => _auth.signOut();

  @override
  Future<ExportPreview> buildPreview(ExportDraft draft) async {
    final issues = <ExportIssue>[];
    final title = draft.title.trim();
    if (title.isEmpty) {
      issues.add(const PlantlyExportIssue('title', 'title_required', 'Title is required'));
    } else if (title.runes.length > manifest.titleMaxLength) {
      issues.add(PlantlyExportIssue('title', 'title_too_long', 'Title exceeds ${manifest.titleMaxLength} characters'));
    }
    if (draft.description.runes.length > manifest.descriptionMaxLength) {
      issues.add(PlantlyExportIssue(
          'description', 'description_too_long', 'Description exceeds ${manifest.descriptionMaxLength} characters'));
    }
    final price = draft.priceLei;
    if (price == null || !priceRe.hasMatch('$price') || price <= 0) {
      issues.add(const PlantlyExportIssue('price', 'price_invalid', 'Enter a price greater than 0'));
    }
    if (draft.category == null || draft.category!.trim().isEmpty) {
      issues.add(const PlantlyExportIssue('category', 'category_required', 'Pick a category'));
    } else if (!isCategoryId(draft.category)) {
      issues.add(const PlantlyExportIssue('category', 'category_invalid', 'Pick a category from the search results'));
    }
    if (draft.photoRefs.isEmpty) {
      issues.add(const PlantlyExportIssue('photos', 'photos_required', 'Add at least one photo'));
    } else if (draft.photoRefs.length > manifest.maxPhotos) {
      issues.add(PlantlyExportIssue('photos', 'photos_too_many', 'At most ${manifest.maxPhotos} photos'));
    }
    return ExportPreview(draft: draft, issues: issues);
  }

  /// Progress: 0.1 sign-in check → 0.2…0.8 per photo prepared → 0.9 uploading
  /// → terminal tick with `remoteId` = post id and the bare listing URL.
  @override
  Stream<ExportProgress> submit(ExportDraft draft) async* {
    final preview = await buildPreview(draft);
    if (!preview.isValid) {
      final first = preview.issues.first;
      yield ExportProgress(
        fraction: 0,
        done: true,
        error: PlantlyExportError(PlantlyExportErrorKind.validation, first.message,
            issueCode: first is PlantlyExportIssue ? first.code : null),
      );
      return;
    }

    yield const ExportProgress(fraction: 0.1, message: 'Checking sign-in…');
    final session = await _auth.current();
    if (session == null) {
      yield const ExportProgress(
        fraction: 0.1,
        done: true,
        error: PlantlyExportError(PlantlyExportErrorKind.signInRequired, 'Sign in to plantly.ro first'),
      );
      return;
    }

    final images = <UploadImage>[];
    final skipped = <String>[];
    final refs = draft.photoRefs.take(manifest.maxPhotos).toList();
    for (var i = 0; i < refs.length; i++) {
      final sha = refs[i];
      final bytes = await _photoBytes(sha);
      if (bytes == null) {
        skipped.add(sha);
      } else {
        try {
          images.add(UploadImage(bytes: await _preparer.prepare(bytes), fileName: 'photo-${i + 1}.jpg'));
        } catch (_) {
          skipped.add(sha);
        }
      }
      yield ExportProgress(
        fraction: 0.2 + 0.6 * ((i + 1) / refs.length),
        message: 'Preparing photo ${i + 1}/${refs.length}',
      );
    }
    if (images.isEmpty) {
      yield const ExportProgress(
        fraction: 0.8,
        done: true,
        error: PlantlyExportError(PlantlyExportErrorKind.noPhotos, 'None of the selected photos could be read'),
      );
      return;
    }

    yield const ExportProgress(fraction: 0.9, message: 'Uploading…');
    final CreatePostResult result;
    try {
      result = await _api.createPost(
        token: session.token,
        title: draft.title.trim(),
        description: draft.description.trim(),
        price: '${draft.priceLei}',
        categoryId: draft.category!.trim(),
        county: draft.county,
        city: draft.city,
        images: images,
      );
    } on PlantlyApiException catch (e) {
      if (e.isUnauthorized) {
        await _auth.signOut();
        yield ExportProgress(
          fraction: 0.9,
          done: true,
          error: PlantlyExportError(PlantlyExportErrorKind.signInRequired, e.message),
        );
      } else if (e.isRateLimited) {
        yield ExportProgress(
          fraction: 0.9,
          done: true,
          error: PlantlyExportError(PlantlyExportErrorKind.rateLimited, e.message, retryAfter: e.retryAfter),
        );
      } else {
        yield ExportProgress(
          fraction: 0.9,
          done: true,
          error: PlantlyExportError(PlantlyExportErrorKind.server, e.message, status: e.status, code: e.code),
        );
      }
      return;
    } on PlantlyNetworkException catch (e) {
      yield ExportProgress(
        fraction: 0.9,
        done: true,
        error: PlantlyExportError(PlantlyExportErrorKind.network, '${e.cause}'),
      );
      return;
    }

    final url = PlantlyHosts.postUrl(result.id, origin: _host);
    await _records.put(ListingRecord(
      plantId: draft.sourcePlantId,
      postId: result.id,
      url: url,
      postedAt: _now(),
      status: 'active',
    ));
    final warnings = [
      ...result.uploadWarnings,
      if (skipped.isNotEmpty) '${skipped.length} photo(s) could not be read and were skipped',
    ];
    yield ExportProgress(
      fraction: 1,
      done: true,
      remoteId: result.id,
      url: url,
      message: warnings.isEmpty ? null : warnings.join('\n'),
    );
  }

  /// `sold` → `POST /posts/{id}/sold`; other statuses aren't supported by
  /// the marketplace API from this client.
  @override
  Future<void> updateStatus(String remoteId, String newStatus) async {
    if (newStatus != 'sold') {
      throw ArgumentError.value(newStatus, 'newStatus', 'only "sold" is supported');
    }
    final session = await _auth.current();
    if (session == null) {
      throw const PlantlyExportError(PlantlyExportErrorKind.signInRequired, 'Sign in to plantly.ro first');
    }
    try {
      await _api.markSold(session.token, remoteId);
    } on PlantlyApiException catch (e) {
      if (e.isUnauthorized) {
        await _auth.signOut();
        throw PlantlyExportError(PlantlyExportErrorKind.signInRequired, e.message);
      }
      throw PlantlyExportError(PlantlyExportErrorKind.server, e.message, status: e.status, code: e.code);
    } on PlantlyNetworkException catch (e) {
      throw PlantlyExportError(PlantlyExportErrorKind.network, '${e.cause}');
    }
    for (final rec in _records.all.values.toList()) {
      if (rec.postId == remoteId) await _records.setStatus(rec.plantId, 'sold');
    }
  }
}

/// A validation issue with a stable [code] the dialog can localize.
class PlantlyExportIssue extends ExportIssue {
  const PlantlyExportIssue(super.field, this.code, super.message);
  final String code;
}

enum PlantlyExportErrorKind { validation, signInRequired, noPhotos, rateLimited, network, server }

/// Terminal failure of [PlantlyRoExportPlugin.submit] / `updateStatus`,
/// typed so the UI maps [kind] to copy instead of parsing strings.
class PlantlyExportError implements Exception {
  const PlantlyExportError(this.kind, this.message, {this.retryAfter, this.status, this.code, this.issueCode});
  final PlantlyExportErrorKind kind;
  final String message;
  final int? retryAfter;
  final int? status;
  final String? code;
  final String? issueCode;

  @override
  String toString() => 'PlantlyExportError(${kind.name}: $message)';
}

/// The user closed the sign-in sheet without signing in.
class PlantlyAuthCancelled implements Exception {
  const PlantlyAuthCancelled();
}
