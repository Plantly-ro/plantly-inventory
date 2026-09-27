import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/plantly_features.dart';
import '../../data/database/app_database.dart' as db;
import '../../data/mock_plants.dart';
import '../../data/providers.dart';
import '../../data/ro_locations.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../marketplace/plantly_api.dart';
import '../../marketplace/plantly_auth.dart';
import '../../plugins/export_plugin.dart';
import '../../plugins/plantly_ro/plantly_ro_plugin.dart';
import '../../plugins/plugin_registry.dart';
import '../../shared/plant_thumb.dart';
import '../../shared/stored_photo_image.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';
import 'category_search_field.dart';
import '../../app/side_sheet.dart';

/// Draft a plantly.ro listing. Reads live data from the DB:
///   - Title/description seeded from the plant row (nickname + notes).
///   - Photos come from the plant's attached OR-set (max 6).
///   - Category is a marketplace search (CONTRACT §5), pre-queried with the
///     plant's species; county from the local list; city free text.
///
/// "Post now" goes through the default [ExportPlugin] (plantly_ro when
/// registered): sign-in sheet if needed, then multipart upload with progress.
class ExportDialog extends ConsumerStatefulWidget {
  const ExportDialog({super.key, required this.plantRow});
  final db.PlantRow plantRow;

  @override
  ConsumerState<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<ExportDialog> {
  late final TextEditingController _title;
  late final TextEditingController _desc;
  late final TextEditingController _price;
  late final TextEditingController _city;
  final _selected = <String>{};
  bool _selectionInitialised = false;
  String? _category;
  String? _categoryLabel;
  String? _county;
  bool _submitting = false;
  double _progress = 0;
  final Map<String, String> _issues = {};

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.plantRow.nickname);
    _desc = TextEditingController(text: widget.plantRow.notes ?? '');
    _price = TextEditingController();
    _city = TextEditingController();
    // Fire-and-forget: if a draft exists for this plant, prefill — lets
    // the user resume a half-filled listing instead of re-typing.
    _loadDraft().then((_) {
      if (ref.read(sellEnabledProvider)) _preselectCategory();
    });
  }

  /// Pre-query the marketplace with the plant's species and preselect the
  /// top hit when it scores ≥ 0.7 (CONTRACT §5). Skipped when the draft
  /// already carries a category.
  Future<void> _preselectCategory() async {
    if (!mounted || _category != null) return;
    final speciesRef = widget.plantRow.speciesId;
    if (speciesRef == null || speciesRef.trim().isEmpty) return;
    try {
      final name = await ref.read(speciesRepositoryProvider).displayName(speciesRef);
      if (name == null || name.trim().length < 2 || !mounted) return;
      final lang = Localizations.localeOf(context).languageCode;
      final hits = await ref.read(plantlyApiProvider).searchCategories(name, lang: lang, limit: 5);
      if (!mounted || _category != null || hits.isEmpty) return;
      final top = hits.first;
      if (top.score >= 0.7) {
        setState(() {
          _category = top.id;
          _categoryLabel = top.path;
        });
      }
    } catch (_) {
      // Offline or no match — the user picks manually.
    }
  }

  Future<void> _loadDraft() async {
    final draft =
        await ref.read(localDraftStoreProvider).loadDraft(widget.plantRow.id);
    if (draft == null || !mounted) return;
    setState(() {
      if (draft.title.isNotEmpty) _title.text = draft.title;
      if (draft.description.isNotEmpty) _desc.text = draft.description;
      if (draft.priceLei != null) _price.text = draft.priceLei.toString();
      if (draft.photoRefs.isNotEmpty) {
        _selected
          ..clear()
          ..addAll(draft.photoRefs);
        _selectionInitialised = true;
      }
      // Selling on: only marketplace UUIDs are resumable (legacy drafts
      // carried free text from the local picker). Selling off: the local
      // picker's values are the categories.
      final sell = ref.read(sellEnabledProvider);
      if (sell ? PlantlyRoExportPlugin.isCategoryId(draft.category) : draft.category != null) {
        _category = draft.category;
        // Drafts saved before `category_label` existed have none: the field
        // then shows the generic "Category selected" until re-picked.
        _categoryLabel = draft.categoryLabel;
      }
      if (draft.county != null) _county = draft.county;
      if (draft.city != null) _city.text = draft.city!;
      _posted = draft.postedAt?.toUtc().toIso8601String();
    });
  }

  /// Snapshot the current form as an [ExportDraft].
  ExportDraft _buildDraft({DateTime? postedAt}) {
    final city = _city.text.trim();
    return ExportDraft(
      sourcePlantId: widget.plantRow.id,
      title: _title.text,
      description: _desc.text,
      priceLei: int.tryParse(_price.text.trim()),
      category: _category,
      categoryLabel: _categoryLabel,
      county: _county,
      city: city.isEmpty ? null : city,
      photoRefs: _selected.toList(),
      postedAt: postedAt ??
          (_posted != null ? DateTime.tryParse(_posted!) : null),
    );
  }

  Future<void> _persistDraft() async {
    await ref.read(localDraftStoreProvider).saveDraft(_buildDraft());
  }

  /// Present [options] in a scrollable bottom sheet; invoke [onSelected] with
  /// the picked value. Used for both category and county.
  Future<void> _pickFrom({
    required String title,
    required List<String> options,
    required String? current,
    required ValueChanged<String> onSelected,
  }) async {
    final mode = ref.read(themeModeProvider);
    final surface =
        mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final picked = await showAdaptiveSheet<String>(
      context,
      backgroundColor: surface.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: TextStyle(fontFamily: PlantlyFonts.plusJakartaSans, 
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: surface.text,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final o in options)
                      ListTile(
                        title: Text(o,
                            style: TextStyle(color: surface.text, fontSize: 14)),
                        trailing: o == current
                            ? Icon(Icons.check, size: 18, color: surface.green)
                            : null,
                        onTap: () => Navigator.of(ctx).pop(o),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
    if (picked != null) onSelected(picked);
  }

  String? _posted;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _price.dispose();
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final t = AppLocalizations.of(context);
    final plant = widget.plantRow;
    final swatch = MockPlants.byId(plant.id);
    final lang = Localizations.localeOf(context).languageCode;
    final sell = ref.watch(sellEnabledProvider);
    final shas = ref.watch(attachedPhotosProvider(plant.id)).maybeWhen(
          data: (list) => list,
          orElse: () => const <String>[],
        );
    // First time we see photos, preselect up to 6 so the user isn't greeted
    // with a zero-selected export.
    if (!_selectionInitialised && shas.isNotEmpty) {
      _selectionInitialised = true;
      _selected.addAll(shas.take(6));
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: surface.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                height: 4,
                width: 40,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: surface.border, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sell ? '🌿 PLANTLY.RO' : t.exportDraftEyebrow,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: surface.terra,
                              letterSpacing: 0.1 * 11,
                            ),
                          ),
                          Text(
                            sell ? t.exportPostTitle(plant.nickname) : t.exportDraftTitle(plant.nickname),
                            style: TextStyle(fontFamily: PlantlyFonts.plusJakartaSans, 
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: surface.text,
                              letterSpacing: -0.02 * 19,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.close, color: surface.text),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    _Label(text: t.exportTitleField, surface: surface),
                    _Field(controller: _title, maxLength: 64, surface: surface, onChanged: (_) => setState(() => _issues.remove('title'))),
                    _IssueOrCount(issue: _issues['title'], value: _title.text.length, max: 64, surface: surface),
                    const SizedBox(height: 10),
                    _Label(text: t.exportDescriptionField, surface: surface),
                    _Field(controller: _desc, maxLength: 2000, surface: surface, maxLines: 3, onChanged: (_) => setState(() => _issues.remove('description'))),
                    _IssueOrCount(issue: _issues['description'], value: _desc.text.length, max: 2000, surface: surface),
                    const SizedBox(height: 10),
                    _Label(text: t.exportPriceField, surface: surface),
                    Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        _Field(
                          controller: _price,
                          surface: surface,
                          keyboardType: TextInputType.number,
                          suffixPadding: 40,
                          onChanged: (_) => setState(() => _issues.remove('price')),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Text(
                            t.exportPriceUnit,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: surface.muted),
                          ),
                        ),
                      ],
                    ),
                    if (_issues['price'] != null) _IssueText(text: _issues['price']!, surface: surface),
                    const SizedBox(height: 10),
                    _Label(text: t.exportCategoryField, surface: surface),
                    if (sell)
                      CategorySearchField(
                        search: (q, l) => ref.read(plantlyApiProvider).searchCategories(q, lang: l, limit: 10),
                        lang: lang,
                        surface: surface,
                        selected: _category == null ? null : (_categoryLabel ?? t.exportCategorySelected),
                        onSelected: (hit) => setState(() {
                          _category = hit?.id;
                          _categoryLabel = hit?.path;
                          _issues.remove('category');
                        }),
                      )
                    else
                      // Selling off: the provisional local list, no network.
                      _PickerInput(
                        value: _category,
                        placeholder: t.exportCategoryPlaceholder,
                        surface: surface,
                        trailingIcon: Icons.expand_more,
                        onTap: () => _pickFrom(
                          title: t.exportCategoryTitle,
                          options: exportCategories,
                          current: _category,
                          onSelected: (v) => setState(() => _category = v),
                        ),
                      ),
                    if (_issues['category'] != null) _IssueText(text: _issues['category']!, surface: surface),
                    const SizedBox(height: 10),
                    _Label(text: t.exportLocationField, surface: surface),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _PickerInput(
                            value: _county,
                            placeholder: t.exportCountyPlaceholder,
                            surface: surface,
                            leadingIcon: Icons.place_outlined,
                            trailingIcon: Icons.expand_more,
                            onTap: () => _pickFrom(
                              title: t.exportCountyTitle,
                              options: roCounties,
                              current: _county,
                              onSelected: (v) => setState(() => _county = v),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Field(
                            controller: _city,
                            surface: surface,
                            hintText: t.exportCityPlaceholder,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    if (sell) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.storefront_outlined, size: 14, color: surface.muted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              t.exportDeliveryNote,
                              style: TextStyle(fontSize: 11.5, color: surface.muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    _Label(text: t.exportPhotosField(_selected.length), surface: surface),
                    if (_issues['photos'] != null) _IssueText(text: _issues['photos']!, surface: surface),
                    const SizedBox(height: 8),
                    _PhotoGrid(
                      shas: shas,
                      selected: _selected,
                      swatch: swatch,
                      surface: surface,
                      onToggle: (sha) {
                        setState(() {
                          _issues.remove('photos');
                          if (_selected.contains(sha)) {
                            _selected.remove(sha);
                          } else if (_selected.length < 6) {
                            _selected.add(sha);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: surface.surface,
                  border: Border(top: BorderSide(color: surface.border)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                child: SafeArea(
                  top: false,
                  child: _submitting
                      ? Column(
                          key: const Key('export-progress'),
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.exportPosting, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: surface.text)),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _progress <= 0 ? null : _progress,
                                minHeight: 6,
                                color: surface.green,
                                backgroundColor: surface.surfaceAlt,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: surface.surfaceAlt,
                                  foregroundColor: surface.text,
                                  side: BorderSide(color: surface.border),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radius + 2)),
                                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                onPressed: () async {
                                  await _persistDraft();
                                  if (context.mounted) _finish(t.exportDraftSaved);
                                },
                                child: Text(t.exportSaveDraft),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 14,
                              child: TextButton(
                                key: const Key('export-post-now'),
                                style: TextButton.styleFrom(
                                  backgroundColor: surface.terra,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radius + 2)),
                                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                                onPressed: _postNow,
                                child: Text(t.exportPostNow),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Validate → sign in if needed → submit through the default plugin,
  /// mirroring progress in the footer. Errors map to localized copy.
  Future<void> _postNow() async {
    final t = AppLocalizations.of(context);
    final plugin = ref.read(defaultExportPluginProvider);
    final draft = _buildDraft();

    final preview = await plugin.buildPreview(draft);
    if (!mounted) return;
    if (!preview.isValid) {
      setState(() {
        _issues
          ..clear()
          ..addEntries(preview.issues.map((i) => MapEntry(i.field, _issueText(t, i))));
      });
      return;
    }

    if (plugin.manifest.authType != PluginAuthType.none) {
      var session = await plugin.loadCredentials();
      if (!mounted) return;
      if (session == null) {
        try {
          session = await plugin.authenticate(context);
        } on PlantlyAuthCancelled {
          return;
        }
        if (!mounted) return;
        await plugin.storeCredentials(session);
      }
    }

    // Keep a local draft too so a failed upload can be retried without
    // re-typing.
    await _persistDraft();
    if (!mounted) return;
    setState(() {
      _submitting = true;
      _progress = 0;
    });
    ExportProgress? last;
    try {
      await for (final p in plugin.submit(draft)) {
        last = p;
        if (!mounted) return;
        setState(() => _progress = p.fraction);
      }
    } catch (e) {
      last = ExportProgress(fraction: 0, done: true, error: e);
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    final error = last?.error;
    if (error != null) {
      if (error is PlantlyExportError && error.kind == PlantlyExportErrorKind.validation && error.issueCode != null) {
        setState(() => _issues[_fieldForCode(error.issueCode!)] = _issueTextForCode(t, error.issueCode!, error.message));
        return;
      }
      _showError(_errorText(t, error));
      return;
    }
    final url = last?.url;
    final warnings = last?.message;
    Navigator.of(context).maybePop();
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(url == null
            ? (warnings ?? t.exportPosted)
            : (warnings == null ? t.exportPosted : t.exportPostedWithWarnings(warnings))),
        duration: const Duration(seconds: 6),
        action: url == null
            ? null
            : SnackBarAction(
                label: t.exportOpenListing,
                onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
              ),
      ));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 5)));
  }

  static String _fieldForCode(String code) => code.split('_').first;

  String _issueText(AppLocalizations t, ExportIssue issue) =>
      issue is PlantlyExportIssue ? _issueTextForCode(t, issue.code, issue.message) : issue.message;

  String _issueTextForCode(AppLocalizations t, String code, String fallback) => switch (code) {
        'title_required' => t.exportIssueTitleRequired,
        'title_too_long' => t.exportIssueTitleTooLong,
        'description_too_long' => t.exportIssueDescriptionTooLong,
        'price_invalid' => t.exportIssuePriceInvalid,
        'category_required' => t.exportIssueCategoryRequired,
        'category_invalid' => t.exportIssueCategoryInvalid,
        'photos_required' => t.exportIssuePhotosRequired,
        'photos_too_many' => t.exportIssuePhotosTooMany,
        _ => fallback,
      };

  String _errorText(AppLocalizations t, Object error) {
    if (error is PlantlyExportError) {
      return switch (error.kind) {
        PlantlyExportErrorKind.signInRequired => t.plantlyErrorSignInAgain,
        PlantlyExportErrorKind.rateLimited => t.plantlyErrorRateLimited,
        PlantlyExportErrorKind.network => t.plantlyErrorNetwork,
        PlantlyExportErrorKind.noPhotos => t.exportIssuePhotosRequired,
        PlantlyExportErrorKind.server => t.exportFailedServer(error.message),
        PlantlyExportErrorKind.validation => error.message,
      };
    }
    if (error is PlantlyApiException) return t.exportFailedServer(error.message);
    if (error is PlantlyNetworkException) return t.plantlyErrorNetwork;
    return t.exportFailedServer('$error');
  }

  void _finish(String msg) {
    Navigator.of(context).maybePop();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text, required this.surface});
  final String text;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: surface.muted,
          letterSpacing: 0.08 * 11,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.surface,
    this.maxLength,
    this.maxLines = 1,
    this.keyboardType,
    this.suffixPadding = 12,
    this.onChanged,
    this.hintText,
  });
  final TextEditingController controller;
  final PlantlySurface surface;
  final int? maxLength;
  final int maxLines;
  final TextInputType? keyboardType;
  final double suffixPadding;
  final ValueChanged<String>? onChanged;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: TextStyle(fontSize: 14, color: surface.text),
      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => const SizedBox.shrink(),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: surface.surface,
        hintText: hintText,
        hintStyle: TextStyle(fontSize: 14, color: surface.muted),
        contentPadding: EdgeInsets.fromLTRB(12, 10, suffixPadding, 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PlantlyTokens.radius),
          borderSide: BorderSide(color: surface.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PlantlyTokens.radius),
          borderSide: BorderSide(color: surface.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PlantlyTokens.radius),
          borderSide: BorderSide(color: surface.green, width: 1.5),
        ),
      ),
    );
  }
}

class _CharCount extends StatelessWidget {
  const _CharCount({required this.value, required this.max, required this.surface});
  final int value;
  final int max;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text('$value/$max', style: TextStyle(fontSize: 10.5, color: surface.muted)),
      ),
    );
  }
}

/// Shows a validation issue in place of the char counter when present.
class _IssueOrCount extends StatelessWidget {
  const _IssueOrCount({required this.issue, required this.value, required this.max, required this.surface});
  final String? issue;
  final int value;
  final int max;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    if (issue != null) return _IssueText(text: issue!, surface: surface);
    return _CharCount(value: value, max: max, surface: surface);
  }
}

class _IssueText extends StatelessWidget {
  const _IssueText({required this.text, required this.surface});
  final String text;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(text, key: Key('issue-$text'), style: TextStyle(fontSize: 11, color: surface.terra)),
    );
  }
}

/// A read-only, tappable field that looks like [_Field] but opens a picker.
/// Shows [value] when set, else [placeholder] in muted text.
class _PickerInput extends StatelessWidget {
  const _PickerInput({
    required this.value,
    required this.placeholder,
    required this.surface,
    required this.onTap,
    this.leadingIcon,
    this.trailingIcon,
  });
  final String? value;
  final String placeholder;
  final PlantlySurface surface;
  final VoidCallback onTap;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PlantlyTokens.radius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: surface.surface,
          borderRadius: BorderRadius.circular(PlantlyTokens.radius),
          border: Border.all(color: surface.border),
        ),
        child: Row(
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 13, color: surface.muted),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                hasValue ? value! : placeholder,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: hasValue ? surface.text : surface.muted,
                ),
              ),
            ),
            if (trailingIcon != null) Icon(trailingIcon, size: 14, color: surface.muted),
          ],
        ),
      ),
    );
  }
}

class _PhotoGrid extends ConsumerWidget {
  const _PhotoGrid({
    required this.shas,
    required this.selected,
    required this.swatch,
    required this.surface,
    required this.onToggle,
  });
  final List<String> shas;
  final Set<String> selected;
  final MockPlant swatch;
  final PlantlySurface surface;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (shas.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surface.surface,
          border: Border.all(color: surface.border),
          borderRadius: BorderRadius.circular(PlantlyTokens.radius),
        ),
        alignment: Alignment.center,
        child: Text(
          AppLocalizations.of(context).exportNoPhotos,
          style: TextStyle(fontSize: 12, color: surface.muted),
          textAlign: TextAlign.center,
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: [
        for (final sha in shas)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
            onTap: () => onToggle(sha),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(PlantlyTokens.radius),
                    border: Border.all(
                      color: selected.contains(sha) ? surface.green : surface.border,
                      width: 2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Opacity(
                    opacity: selected.contains(sha) ? 1 : 0.45,
                    child: _GridPhoto(sha: sha, fallback: swatch),
                  ),
                ),
                if (selected.contains(sha))
                  Positioned(
                    top: 3,
                    right: 3,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(color: surface.green, shape: BoxShape.circle),
                      child: const Icon(Icons.check, size: 11, color: Colors.white),
                    ),
                  ),
              ],
            ),
            ),
          ),
      ],
    );
  }
}

class _GridPhoto extends StatelessWidget {
  const _GridPhoto({required this.sha, required this.fallback});
  final String sha;
  final MockPlant fallback;

  @override
  Widget build(BuildContext context) {
    return StoredPhotoImage(
      sha: sha,
      width: 80,
      height: 80,
      placeholder: PlantThumb(plant: fallback, size: 80),
    );
  }
}
