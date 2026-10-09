import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/clock.dart';
import '../../cloud/collections.dart';
import '../collections/read_only_banner.dart';
import '../../app/breakpoints.dart';
import '../../app/desktop_theme.dart';
import '../../app/navigation.dart';
import '../../data/care_types.dart';
import '../../data/database/app_database.dart' as db;
import '../../data/image_processor.dart';
import '../../data/mock_plants.dart';
import '../../data/photo_picker.dart';
import '../../config/plantly_features.dart';
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../marketplace/listing_records.dart';
import '../../plugins/plantly_ro/plantly_ro_plugin.dart';
import '../../plugins/plugin_registry.dart';
import '../../shared/plant_thumb.dart';
import '../../shared/assignee_initial.dart';
import '../../shared/stored_photo_image.dart';
import '../../sync/hlc.dart';
import '../../theme/tokens.dart';
import '../export/export_dialog.dart';
import '../home/home_providers.dart';
import '../home/sort.dart';
import '../../shared/care_feedback.dart';
import '../../shared/location_picker.dart';
import '../../shared/photo_source_sheet.dart';
import 'add_reminder_sheet.dart';
import 'edit_event_sheet.dart';
import 'edit_plant_sheet.dart';
import '../../shared/care_type_labels.dart';
import 'edit_reminder_sheet.dart';
import 'inventory_action_sheet.dart';
import 'log_event_sheet.dart';
import 'propagate_dialog.dart';
import 'tag_chip_input.dart';
import '../../app/side_sheet.dart';
import '../../shared/actor_label.dart';
import '../collections/collection_activity_screen.dart';
import '../../shared/relative_days.dart';
import '../../shared/sheet_chrome.dart';

String _localeOf(BuildContext context) => Localizations.localeOf(context).toString();

/// "Sep 25" / "25 sept." — locale-aware short date for timeline rows.
String _fmtDate(BuildContext context, DateTime d) => DateFormat.MMMd(_localeOf(context)).format(d);

/// "Sep 25, 2026" / "25 sept. 2026" — locale-aware date with year.
String _fmtDateLong(BuildContext context, DateTime d) => DateFormat.yMMMd(_localeOf(context)).format(d);

/// Live Plant Detail screen. Reads everything from Drift; `MockPlants` is
/// only consulted for the decorative colour swatch used by the photo
/// fallback stub.
class PlantDetailScreen extends ConsumerWidget {
  const PlantDetailScreen({super.key, required this.plantId});
  final String plantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final plantAsync = ref.watch(plantByIdProvider(plantId));
    final swatch = MockPlants.byId(plantId);

    return plantAsync.when(
      loading: () => Scaffold(
        backgroundColor: surface.bg,
        body: Center(child: CircularProgressIndicator(color: surface.green)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: surface.bg,
        appBar: AppBar(backgroundColor: surface.bg, elevation: 0),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(t.detailLoadFailed('$e'), style: TextStyle(color: surface.terra)),
        ),
      ),
      data: (plantRow) {
        if (plantRow == null || plantRow.deletedAt != null) {
          return Scaffold(
            backgroundColor: surface.bg,
            appBar: AppBar(
              backgroundColor: surface.bg,
              elevation: 0,
              leading: detailLeading(context, surface, parent: AppRoutes.home),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  t.plantDetailNotInCollection,
                  style: TextStyle(color: surface.muted),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return _PlantDetailBody(
          plantRow: plantRow,
          surface: surface,
          swatch: swatch,
        );
      },
    );
  }
}

class _PlantDetailBody extends ConsumerWidget {
  const _PlantDetailBody({
    required this.plantRow,
    required this.surface,
    required this.swatch,
  });

  final db.PlantRow plantRow;
  final PlantlySurface surface;
  final MockPlant swatch;

  String _locationName(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final locationAsync = plantRow.locationId == null
        ? null
        : ref.watch(locationByIdProvider(plantRow.locationId!));
    return locationAsync?.maybeWhen(
          data: (loc) => loc?.name,
          orElse: () => null,
        ) ??
        (plantRow.locationId == null ? t.detailNoLocation : t.detailLoadingLocation);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final locationName = _locationName(context, ref);

    final types = ref.watch(careTypesProvider);
    final fabKey = ref.watch(quickFabTypeProvider);
    final fabType = resolveCareType(types, fabKey);
    // Viewer of a shared collection (MULTI-USER-V2 §3): every mutating
    // affordance below is hidden; the body shows the read-only banner.
    final canEdit = ref.watch(canEditActiveCollectionProvider);
    if (context.isDesktop) {
      // DESKTOP-POLISH §2: full-width two-column page; the toolbar carries
      // every AppBar/FAB action, so neither is rendered.
      return Scaffold(
        backgroundColor: surface.bg,
        body: _DesktopDetailLayout(
          plantRow: plantRow,
          surface: surface,
          swatch: swatch,
          locationName: locationName,
          types: types,
          fabKey: fabKey,
          fabType: fabType,
          onEdit: () => _editPlant(context),
          onAddPhotos: () => _addPhotos(context, ref),
          moreMenu: _moreMenu(context, ref),
        ),
      );
    }
    return Scaffold(
      backgroundColor: surface.bg,
      floatingActionButton: !canEdit ? null : GestureDetector(
        onLongPress: () => _pickFabType(context, ref, types),
        onSecondaryTap: () => _pickFabType(context, ref, types),
        child: FloatingActionButton.extended(
          backgroundColor: fabType.color ?? surface.green,
          foregroundColor: Colors.white,
          icon: Icon(fabType.icon),
          label: Text(t.detailFabNow(careTypeVerb(t, fabType))),
          // "Long-press to change" is phone copy (§7); tablet keeps the
          // gesture but not the hint.
          tooltip: context.isWide ? null : (kIsWeb ? t.detailFabTooltipWeb : t.detailFabTooltip),
          onPressed: () async {
            await ref.read(careEventRepositoryProvider).record(
                  plantId: plantRow.id,
                  type: fabKey,
                );
            if (!context.mounted) return;
            await showCareFeedback(
              context,
              type: fabType,
              plantName: plantRow.nickname,
              surface: surface,
            );
          },
        ),
      ),
      appBar: AppBar(
        backgroundColor: surface.bg,
        elevation: 0,
        leading: detailLeading(context, surface, parent: AppRoutes.home),
        actions: [
          if (canEdit) ...[
            IconButton(
              icon: Icon(Icons.edit_outlined, color: surface.text),
              tooltip: t.plantDetailEdit,
              onPressed: () => _editPlant(context),
            ),
            IconButton(
              icon: Icon(Icons.add_a_photo_outlined, color: surface.text),
              tooltip: t.plantDetailAddPhotos,
              onPressed: () => _addPhotos(context, ref),
            ),
            _moreMenu(context, ref),
          ],
        ],
      ),
      body: Column(
        children: [
          const ReadOnlyBanner(),
          Expanded(child: _phoneBody(context, ref)),
        ],
      ),
    );
  }

  void _editPlant(BuildContext context) {
    showAdaptiveSheet(
      context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditPlantSheet(plantRow: plantRow),
    );
  }

  Future<void> _addPhotos(BuildContext context, WidgetRef ref) async {
    final picker = ref.read(photoPickerProvider);
    final picked = await pickMultiPhotoWithSource(context, picker, surface);
    if (picked.isEmpty) return;
    final processor = ref.read(imageProcessorProvider);
    final photos = ref.read(photoRepositoryProvider);
    final joins = ref.read(plantPhotoRepositoryProvider);
    for (final p in picked) {
      final shrunk = await processor.toDisplay(p.bytes);
      final sha = await photos.saveBytes(shrunk, mime: 'image/jpeg');
      await joins.attach(plantRow.id, sha);
    }
  }

  /// The overflow menu, shared by the phone AppBar and the desktop toolbar.
  Widget _moreMenu(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final plantId = plantRow.id;
    return PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz, color: surface.text),
            onSelected: (value) async {
              switch (value) {
                case 'propagate':
                  final child = await PropagateDialog.show(
                    context,
                    parentId: plantId,
                    parentName: plantRow.nickname,
                  );
                  if (child != null && context.mounted) {
                    replaceWithPlant(context, child.id);
                  }
                  break;
                case 'move':
                  await _pickLocationDialog(context, ref, plantRow);
                  break;
                case 'duplicate':
                  final child = await ref.read(plantRepositoryProvider).duplicate(plantRow.id);
                  if (context.mounted) {
                    replaceWithPlant(context, child.id);
                  }
                  break;
                case 'mute':
                  await ref
                      .read(plantRepositoryProvider)
                      .setNotificationsMuted(plantRow.id, !plantRow.notificationsMuted);
                  break;
                case 'gift':
                case 'sale':
                case 'death':
                  final closed = await showAdaptiveSheet<bool>(
                    context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => InventoryActionSheet(plantRow: plantRow, type: value),
                  );
                  if (closed == true && context.mounted) {
                    goBack(context);
                  }
                  break;
                case 'delete':
                  final messenger = ScaffoldMessenger.of(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dctx) => AlertDialog(
                      title: Text(t.detailDeleteTitle),
                      content: Text(t.detailDeleteBody(plantRow.nickname)),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: Text(t.cancel)),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: surface.terra),
                          onPressed: () => Navigator.of(dctx).pop(true),
                          child: Text(t.commonDelete),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref.read(plantRepositoryProvider).softDelete(plantRow.id);
                    if (context.mounted) goBack(context);
                    messenger
                      ..clearSnackBars()
                      ..showSnackBar(SnackBar(
                        content: Text(t.detailDeletedToast(plantRow.nickname)),
                        action: SnackBarAction(
                          label: t.detailUndo,
                          onPressed: () {
                            ref.read(plantRepositoryProvider).restoreFromSoftDelete(plantRow.id);
                          },
                        ),
                      ));
                  }
                  break;
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'move', child: Text(t.plantDetailMoveToSpace)),
              PopupMenuItem(value: 'duplicate', child: Text(t.plantDetailDuplicate)),
              PopupMenuItem(value: 'propagate', child: Text(t.plantDetailPropagate)),
              PopupMenuItem(
                value: 'mute',
                child: Text(plantRow.notificationsMuted ? t.plantDetailUnmuteAll : t.plantDetailMuteAll),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'gift', child: Text(t.plantDetailGift)),
              PopupMenuItem(value: 'sale', child: Text(t.plantDetailSold)),
              PopupMenuItem(value: 'death', child: Text(t.plantDetailMarkDead)),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'delete', child: Text(t.plantDetailDelete)),
            ],
          );
  }

  Widget _phoneBody(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final plantId = plantRow.id;
    final locationName = _locationName(context, ref);
    return ListView(
        // Clear the extended FAB (56 + 16 margin, plus the gesture-nav
        // inset) so the last card — the listing-draft CTA — stays tappable
        // when scrolled to the bottom instead of sitting under the button.
        padding: EdgeInsets.only(bottom: 96 + MediaQuery.paddingOf(context).bottom),
        children: [
          // Phone: the prototype's 1.3 hero. Wide panes cap the height so
          // a 700 px pane doesn't spend 540 px on the photo.
          if (context.isWide)
            SizedBox(
              height: 360,
              child: Container(
                color: surface.surfaceAlt,
                child: _HeroCarousel(plantId: plantId, fallback: swatch, surface: surface),
              ),
            )
          else
            AspectRatio(
              aspectRatio: 1.3,
              child: Container(
                color: surface.surfaceAlt,
                child: _HeroCarousel(plantId: plantId, fallback: swatch, surface: surface),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plantRow.nickname,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: PlantlyFonts.plusJakartaSans, 
                    fontSize: PlantlyTokens.text2xl,
                    fontWeight: FontWeight.w800,
                    color: surface.text,
                    letterSpacing: -0.02 * PlantlyTokens.text2xl,
                  ),
                ),
                if (plantRow.speciesId != null && plantRow.speciesId!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    // Resolves a `species` row id to its scientific name; legacy
                    // free-text species pass through unchanged.
                    ref.watch(speciesDisplayNameProvider(plantRow.speciesId!)).maybeWhen(
                          data: (name) => name ?? plantRow.speciesId!,
                          orElse: () => plantRow.speciesId!,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: surface.muted, fontStyle: FontStyle.italic),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 12, color: surface.muted),
                    const SizedBox(width: 5),
                    Flexible(child: Text(locationName, style: TextStyle(fontSize: 12, color: surface.muted))),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  plantRow.acquiredAt == null
                      ? t.detailAddedOn(_fmtDateLong(context, ref.read(clockProvider)()))
                      : t.detailAcquiredOn(_fmtDateLong(
                          context,
                          DateTime.fromMillisecondsSinceEpoch(plantRow.acquiredAt!, isUtc: true).toLocal(),
                        )),
                  style: TextStyle(fontSize: 12, color: surface.muted),
                ),
                // MULTI-USER-V2 §3: who touched this plant last (shared
                // collections only, from the activity cache).
                LastEditedByLine(tenantId: plantRow.tenantId, entityId: plantId, surface: surface),
                if (plantRow.notes != null && plantRow.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    plantRow.notes!,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: surface.text),
                  ),
                ],
                const SizedBox(height: 12),
                TagChipInput(plantId: plantId, surface: surface),
              ],
            ),
          ),
          // Header + card live together in _StatsCard so a plant with no
          // events shows neither (issue #15: orphan "STATS" header).
          _StatsCard(plantId: plantId, surface: surface),
          _SectionLabel(text: t.plantDetailSectionUpcoming, surface: surface),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _UpcomingCare(surface: surface, plantId: plantId),
          ),
          const SizedBox(height: 16),
          _SectionLabel(text: t.plantDetailSectionTimeline, surface: surface),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _Timeline(surface: surface, plantId: plantId),
          ),
          _InventoryLedger(surface: surface, plantId: plantId),
          if (ref.watch(listingRecordsProvider)[plantId] case final ListingRecord record)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: _ListedOnPlantlyRow(surface: surface, record: record),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: _ExportCTA(
              surface: surface,
              onPressed: () {
                showAdaptiveSheet(
                  context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => ExportDialog(plantRow: plantRow),
                );
              },
            ),
          ),
        ],
    );
  }

  Future<void> _pickFabType(BuildContext context, WidgetRef ref, List<CareType> types) async {
    final t = AppLocalizations.of(context);
    final current = ref.read(quickFabTypeProvider);
    final mode = ref.read(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final picked = await showAdaptiveSheet<String>(
      context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SheetChrome(
        surface: surface,
        title: t.plantDetailQuickAction,
        subtitle: t.plantDetailQuickActionHelp,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        handleGap: 14,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            if (!ctx.isDesktop) ...[
            Text(
              t.plantDetailQuickAction,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: surface.text),
            ),
            Text(
              t.plantDetailQuickActionHelp,
              style: TextStyle(fontSize: 12, color: surface.muted),
            ),
            const SizedBox(height: 14),
            ],
            for (final ct in types)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ct.color ?? surface.greenSoft,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(ct.icon, color: ct.color == null ? surface.green : Colors.white),
                ),
                title: Text(careTypeLabel(t, ct)),
                trailing: ct.key == current ? Icon(Icons.check, color: surface.green) : null,
                onTap: () => Navigator.of(ctx).pop(ct.key),
              ),
          ],
      ),
    );
    if (picked != null) {
      await ref.read(quickFabTypeProvider.notifier).set(picked);
    }
  }

  Future<void> _pickLocationDialog(
    BuildContext context,
    WidgetRef ref,
    db.PlantRow plant,
  ) async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final picked = await pickLocation(context, ref: ref, currentLocationId: plant.locationId);
    if (picked == plant.locationId) return;
    await ref.read(plantRepositoryProvider).setLocation(plant.id, picked);
    final locations = ref.read(locationsStreamProvider).maybeWhen(
          data: (rows) => rows,
          orElse: () => const <db.LocationRow>[],
        );
    final label = picked == null
        ? t.detailRemovedFromSpace
        : t.detailMovedTo(locations.where((l) => l.id == picked).map((l) => l.name).firstOrNull ?? t.detailThatSpace);
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(label)));
  }
}

class _HeroCarousel extends ConsumerStatefulWidget {
  const _HeroCarousel({required this.plantId, required this.fallback, required this.surface});
  final String plantId;
  final MockPlant fallback;
  final PlantlySurface surface;

  @override
  ConsumerState<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends ConsumerState<_HeroCarousel> {
  final _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _editAnnotation(db.PlantPhotoRow row) async {
    final t = AppLocalizations.of(context);
    final controller = TextEditingController(text: row.caption ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.plantDetailCaptionTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: t.plantDetailCaptionHint,
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: Text(t.cancel)),
          if ((row.caption ?? '').isNotEmpty)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: widget.surface.terra),
              onPressed: () => Navigator.of(ctx).pop(''),
              child: Text(t.commonClear),
            ),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(controller.text), child: Text(t.commonSave)),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    await ref
        .read(plantPhotoRepositoryProvider)
        .setCaption(row.id, result.isEmpty ? null : result.trim());
  }

  /// Edit the display-only "date added" for a photo attachment. Defaults to
  /// the current captured_at if set, otherwise the HLC physicalMs.
  Future<void> _editCapturedAt(db.PlantPhotoRow row) async {
    final initial = _photoDate(row);
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    await ref
        .read(plantPhotoRepositoryProvider)
        .setCapturedAt(row.id, picked.toUtc().millisecondsSinceEpoch);
  }

  /// Resolve the visible "date added" for a photo — user override wins,
  /// else fall back to the HLC's physicalMs component.
  DateTime _photoDate(db.PlantPhotoRow row) {
    final ms = row.capturedAt ?? Hlc.parse(row.addedHlc).physicalMs;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  }

  Future<void> _openReorder(List<db.PlantPhotoRow> rows) async {
    final reordered = await Navigator.of(context).push<List<db.PlantPhotoRow>>(
      MaterialPageRoute(builder: (_) => _ReorderPhotosScreen(rows: rows, fallback: widget.fallback)),
    );
    if (reordered == null) return;
    await ref.read(plantPhotoRepositoryProvider).reorder(reordered);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final canEdit = ref.watch(canEditActiveCollectionProvider);
    final attachedAsync = ref.watch(attachedPhotosProvider(widget.plantId));
    final rows = ref.watch(plantPhotoRowsProvider(widget.plantId)).maybeWhen(
          data: (r) => r,
          orElse: () => const <db.PlantPhotoRow>[],
        );
    return attachedAsync.when(
      loading: () => Center(child: PlantThumb(plant: widget.fallback, size: 280)),
      error: (_, _) => Center(child: PlantThumb(plant: widget.fallback, size: 280)),
      data: (shas) {
        if (shas.isEmpty) {
          return Center(child: PlantThumb(plant: widget.fallback, size: 280));
        }
        // Clamp page index if the user detached the current photo.
        final current = _index.clamp(0, shas.length - 1);
        if (current != _index) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_pageController.hasClients) _pageController.jumpToPage(current);
            setState(() => _index = current);
          });
        }
        return Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: shas.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => GestureDetector(
                onLongPress: canEdit ? () => _confirmDetach(shas[i]) : null,
                child: _PhotoView(sha: shas[i], fallback: widget.fallback),
              ),
            ),
            if (shas.length > 1)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < shas.length; i++)
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _index
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                  ],
                ),
              ),
            Positioned(
              top: 10,
              right: 10,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_index + 1} / ${shas.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (canEdit) ...[
                  const SizedBox(width: 6),
                  if (rows.length > 1)
                    _CarouselIconBtn(
                      icon: Icons.swap_vert,
                      tooltip: t.detailReorderTooltip,
                      onTap: () => _openReorder(rows),
                    ),
                  if (rows.length > 1) const SizedBox(width: 6),
                  _CarouselIconBtn(
                    icon: Icons.edit_calendar_outlined,
                    tooltip: t.detailEditDateTooltip,
                    onTap: () {
                      if (_index < rows.length) _editCapturedAt(rows[_index]);
                    },
                  ),
                  const SizedBox(width: 6),
                  _CarouselIconBtn(
                    icon: Icons.edit_note_outlined,
                    tooltip: t.detailCaptionTooltip,
                    onTap: () {
                      if (_index < rows.length) _editAnnotation(rows[_index]);
                    },
                  ),
                  const SizedBox(width: 6),
                  _CarouselIconBtn(
                    icon: Icons.delete_outline,
                    tooltip: t.commonRemove,
                    onTap: () => _confirmDetach(shas[_index]),
                  ),
                  ],
                ],
              ),
            ),
            if (_index < rows.length)
              Positioned(
                top: 10,
                left: 10,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                  onTap: canEdit ? () => _editCapturedAt(rows[_index]) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event_outlined, size: 11, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          _fmtDateLong(context, _photoDate(rows[_index])),
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                ),
              ),
            // Show caption overlay at the bottom if the current row has one.
            if (_index < rows.length && (rows[_index].caption ?? '').isNotEmpty)
              Positioned(
                left: 10,
                right: 10,
                bottom: shas.length > 1 ? 26 : 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(PlantlyTokens.radius),
                  ),
                  child: Text(
                    rows[_index].caption!,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDetach(String sha) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.plantDetailRemovePhotoTitle),
        content: Text(t.plantDetailRemovePhotoBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t.cancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(t.commonRemove)),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(plantPhotoRepositoryProvider).detach(widget.plantId, sha);
    }
  }
}

class _PhotoView extends StatelessWidget {
  const _PhotoView({required this.sha, required this.fallback});
  final String sha;
  final MockPlant fallback;

  @override
  Widget build(BuildContext context) {
    return StoredPhotoImage(
      sha: sha,
      width: double.infinity,
      placeholder: Center(child: PlantThumb(plant: fallback, size: 280)),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.text,
    required this.surface,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 10),
  });
  final String text;
  final PlantlySurface surface;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: surface.green,
          letterSpacing: 0.1 * 11,
        ),
      ),
    );
  }
}

class _UpcomingCare extends ConsumerWidget {
  const _UpcomingCare({required this.surface, required this.plantId});
  final PlantlySurface surface;
  final String plantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final canEdit = ref.watch(canEditActiveCollectionProvider);
    final schedulesAsync = ref.watch(schedulesForPlantProvider(plantId));
    return Container(
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
      ),
      clipBehavior: Clip.antiAlias,
      child: schedulesAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(14),
          child: Text('$e', style: TextStyle(color: surface.terra, fontSize: 12)),
        ),
        data: (schedules) {
          if (schedules.isEmpty) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    t.plantDetailNoReminders,
                    style: TextStyle(fontSize: 12, color: surface.muted),
                  ),
                ),
                if (canEdit) _AddReminderButton(surface: surface, plantId: plantId, leadingDivider: true),
              ],
            );
          }
          return Column(
            children: [
              for (var i = 0; i < schedules.length; i++)
                _UpcomingRowView(
                  schedule: schedules[i],
                  plantId: plantId,
                  surface: surface,
                  last: i == schedules.length - 1,
                ),
              if (canEdit) _AddReminderButton(surface: surface, plantId: plantId, leadingDivider: true),
            ],
          );
        },
      ),
    );
  }
}

class _UpcomingRowView extends ConsumerWidget {
  const _UpcomingRowView({
    required this.schedule,
    required this.plantId,
    required this.surface,
    required this.last,
  });
  final db.CareScheduleRow schedule;
  final String plantId;
  final PlantlySurface surface;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final types = ref.watch(careTypesProvider);
    final ct = resolveCareType(types, schedule.type);
    final (label, whenText, urgent) = _describeSchedule(t, schedule, careTypeLabel(t, ct), now: ref.read(clockProvider)());
    final icon = ct.icon;
    final muted = schedule.notificationsMuted;
    // If the user gave this type a colour, use it as the chip fill; the
    // terra urgent tint still wins when the reminder is actually overdue.
    final chipBg = urgent ? surface.terraSoft : (ct.color ?? surface.greenSoft);
    final chipFg = urgent ? surface.terra : (ct.color == null ? surface.green : Colors.white);
    final canEdit = ref.watch(canEditActiveCollectionProvider);
    return InkWell(
      onLongPress: !canEdit ? null : () {
        showAdaptiveSheet(
          context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => EditReminderSheet(schedule: schedule),
        );
      },
      child: Container(
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: surface.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(PlantlyTokens.radius),
            ),
            child: Icon(icon, size: 16, color: chipFg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text)),
                    if (muted) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.notifications_off_outlined, size: 13, color: surface.muted),
                    ],
                    AssigneeChip(userId: schedule.assigneeUserId, tenantId: schedule.tenantId, surface: surface, size: 18),
                  ],
                ),
                Text(
                  whenText,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: urgent ? surface.terra : surface.muted,
                    fontWeight: urgent ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (canEdit) ...[
          IconButton(
            tooltip: muted ? t.detailUnmuteReminderTooltip : t.detailMuteReminderTooltip,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(
              muted ? Icons.notifications_off_outlined : Icons.notifications_outlined,
              size: 16,
              color: surface.muted,
            ),
            onPressed: () {
              ref.read(careScheduleRepositoryProvider).setNotificationsMuted(schedule.id, !muted);
            },
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: surface.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radiusMd)),
            ),
            onPressed: () => _recordSchedule(context, ref, schedule, ct, plantId, label, surface),
            child: Text(t.doneBtn),
          ),
          const SizedBox(width: 6),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: surface.surfaceAlt,
              foregroundColor: surface.muted,
              side: BorderSide(color: surface.border),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radiusMd)),
            ),
            onPressed: () => _snoozeSchedule(context, ref, schedule),
            child: Text(t.snoozeBtn),
          ),
          ],
        ],
      ),
      ),
    );
  }
}

/// Reminder row copy: "Water · in 3 days" and whether it reads as urgent.
(String label, String when, bool urgent) _describeSchedule(
  AppLocalizations t,
  db.CareScheduleRow s,
  String label, {
  DateTime? now,
}) {
  final (whenText, urgent) = describeScheduleDue(t, s.nextDueAt, now: now);
  return (label, whenText, urgent);
}

/// "in 3 days" / "tomorrow" / "2 days overdue" for a due instant, counted
/// in CALENDAR days ([calendarDaysBetween]) — the same number Calendar and
/// Home show for that date.
@visibleForTesting
(String when, bool urgent) describeScheduleDue(AppLocalizations t, int? dueMs, {DateTime? now}) {
  if (dueMs == null) return (t.detailNoDueDate, false);
  final at = now ?? DateTime.now();
  final days = calendarDaysUntilMs(dueMs, at);
  if (dueMs < at.millisecondsSinceEpoch) {
    final late = -days;
    return (late <= 0 ? t.detailOverdue : t.detailOverdueDays(late), true);
  }
  if (days == 0) return (t.detailDueToday, true);
  if (days == 1) return (t.detailDueTomorrow, false);
  return (t.detailDueInDays(days), false);
}

/// "Done" on a reminder: record the event, then the care feedback overlay.
Future<void> _recordSchedule(
  BuildContext context,
  WidgetRef ref,
  db.CareScheduleRow schedule,
  CareType ct,
  String plantId,
  String fallbackName,
  PlantlySurface surface,
) async {
  await ref.read(careEventRepositoryProvider).record(plantId: plantId, type: schedule.type);
  if (!context.mounted) return;
  await showCareFeedback(
    context,
    type: ct,
    plantName: ref.read(plantByIdProvider(plantId)).maybeWhen(
          data: (p) => p?.nickname ?? fallbackName,
          orElse: () => fallbackName,
        ),
    surface: surface,
  );
}

Future<void> _snoozeSchedule(BuildContext context, WidgetRef ref, db.CareScheduleRow schedule) async {
  final t = AppLocalizations.of(context);
  await ref.read(careScheduleRepositoryProvider).snooze(schedule.id, by: const Duration(days: 3));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(t.detailSnoozedToast)));
}

void _editReminder(BuildContext context, db.CareScheduleRow schedule) {
  showAdaptiveSheet(
    context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => EditReminderSheet(schedule: schedule),
  );
}

class _AddReminderButton extends StatelessWidget {
  const _AddReminderButton({
    required this.surface,
    required this.plantId,
    this.leadingDivider = false,
  });
  final PlantlySurface surface;
  final String plantId;
  final bool leadingDivider;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        border: leadingDivider ? Border(top: BorderSide(color: surface.border)) : null,
      ),
      child: InkWell(
        onTap: () {
          showAdaptiveSheet(
            context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => AddReminderSheet(plantId: plantId),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.add_circle_outline, size: 18, color: surface.green),
              const SizedBox(width: 10),
              Text(
                t.plantDetailAddReminder,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: surface.green),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Timeline extends ConsumerWidget {
  const _Timeline({required this.surface, required this.plantId});
  final PlantlySurface surface;
  final String plantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final eventsAsync = ref.watch(careEventsForPlantProvider(plantId));
    return Container(
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
      ),
      clipBehavior: Clip.antiAlias,
      child: eventsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(14),
          child: Text('$e', style: TextStyle(color: surface.terra, fontSize: 12)),
        ),
        data: (events) {
          final Widget logButton = ref.watch(canEditActiveCollectionProvider)
              ? _LogEventButton(
                  surface: surface,
                  plantId: plantId,
                  leadingDivider: events.isNotEmpty,
                )
              : const SizedBox.shrink();
          if (events.isEmpty) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    t.plantDetailNoEvents,
                    style: TextStyle(fontSize: 12, color: surface.muted),
                  ),
                ),
                logButton,
              ],
            );
          }
          if (context.isDesktop) return _desktopTable(context, ref, events, logButton);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    for (var i = 0; i < events.length; i++)
                      _timelineRow(context, ref, events[i], i == events.length - 1),
                  ],
                ),
              ),
              logButton,
            ],
          );
        },
      ),
    );
  }

  /// Desktop: care history as a proper table (date · care · details · ⌫)
  /// instead of the stacked phone rows — the pane is wide enough and
  /// scanning a column of dates is what a desk user expects.
  Widget _desktopTable(BuildContext context, WidgetRef ref, List<db.CareEventRow> events, Widget logButton) {
    final t = AppLocalizations.of(context);
    final types = ref.watch(careTypesProvider);
    final rowHeight = Theme.of(context).extension<PlantlyDensity>()?.tableRowHeight ?? 44;
    final headStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: surface.muted,
      letterSpacing: 0.08 * 11,
    );
    final cellStyle = TextStyle(fontSize: 13, color: surface.text);
    final canEdit = ref.watch(canEditActiveCollectionProvider);
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: DataTable(
            showCheckboxColumn: false,
            headingRowHeight: 36,
            dataRowMinHeight: rowHeight,
            dataRowMaxHeight: rowHeight,
            horizontalMargin: 14,
            columnSpacing: 20,
            dividerThickness: 1,
            headingTextStyle: headStyle,
            dataTextStyle: cellStyle,
            columns: [
              DataColumn(label: Text(t.historyColDate.toUpperCase())),
              DataColumn(label: Text(t.historyColCare.toUpperCase())),
              DataColumn(label: Text(t.historyColDetails.toUpperCase())),
              const DataColumn(label: SizedBox.shrink()),
            ],
            rows: [
              for (final event in events)
                () {
                  final ct = resolveCareType(types, event.type);
                  final verb = careKeyPastLabel(t, types, event.type);
                  final details = withActor(_detailsOf(event) ?? '', careEventActorLabel(ref, t, event));
                  final when = _fmtDateLong(
                    context,
                    DateTime.fromMillisecondsSinceEpoch(event.doneAt, isUtc: true).toLocal(),
                  );
                  return DataRow(
                    onSelectChanged: !canEdit ? null : (_) {
                      showAdaptiveSheet(
                        context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => EditEventSheet(event: event),
                      );
                    },
                    cells: [
                      DataCell(Text(when, style: TextStyle(fontSize: 12, color: surface.muted, fontWeight: FontWeight.w500))),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(color: ct.color ?? surface.greenSoft, shape: BoxShape.circle),
                            child: Icon(ct.icon, size: 12, color: ct.color == null ? surface.green : Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Text(verb, style: cellStyle),
                        ],
                      )),
                      DataCell(Text(details.isEmpty ? '—' : details, overflow: TextOverflow.ellipsis)),
                      DataCell(!canEdit
                          ? const SizedBox.shrink()
                          : IconButton(
                              icon: Icon(Icons.delete_outline, size: 16, color: surface.muted),
                              tooltip: t.plantDetailDeleteEvent,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () => _deleteEvent(context, ref, event, _describe(t, event, verb)),
                            )),
                    ],
                  );
                }(),
            ],
          ),
        ),
        logButton,
      ],
    );
  }

  Future<void> _deleteEvent(BuildContext context, WidgetRef ref, db.CareEventRow event, String text) async {
    if (!ensureCanEdit(context, ref)) return;
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(t.detailDeleteEventTitle),
        content: Text(t.detailDeleteEventBody(text)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: Text(t.cancel)),
          TextButton(onPressed: () => Navigator.of(dctx).pop(true), child: Text(t.commonDelete)),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(careEventRepositoryProvider).undo(event.id);
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(t.plantDetailEventRemoved),
          action: SnackBarAction(
            label: t.detailUndo,
            onPressed: () async {
              // "Undo" an undo → re-record the same event verbatim.
              await ref.read(careEventRepositoryProvider).record(
                    plantId: event.plantId,
                    type: event.type,
                    doneAt: event.doneAt,
                    notes: event.notes,
                    dose: event.dose,
                    product: event.product,
                    photoSha: event.photoSha,
                  );
            },
          ),
        ));
    }
  }

  Widget _timelineRow(BuildContext context, WidgetRef ref, db.CareEventRow event, bool last) {
    final t = AppLocalizations.of(context);
    final types = ref.watch(careTypesProvider);
    final when = _fmtDate(context, DateTime.fromMillisecondsSinceEpoch(event.doneAt, isUtc: true).toLocal());
    final text = withActor(_describe(t, event, careKeyPastLabel(t, types, event.type)), careEventActorLabel(ref, t, event));
    Future<void> delete() => _deleteEvent(context, ref, event, text);
    final canEdit = ref.watch(canEditActiveCollectionProvider);

    return InkWell(
      onLongPress: canEdit ? delete : null,
      onTap: !canEdit ? null : () {
        showAdaptiveSheet(
          context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => EditEventSheet(event: event),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: surface.border)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Builder(builder: (ctx) {
              final types = ref.watch(careTypesProvider);
              final ct = resolveCareType(types, event.type);
              final bg = ct.color ?? surface.greenSoft;
              final fg = ct.color == null ? surface.green : Colors.white;
              return Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(ct.icon, size: 14, color: fg),
              );
            }),
            const SizedBox(width: 11),
            Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: surface.text))),
            Text(when, style: TextStyle(fontSize: 11, color: surface.muted, fontWeight: FontWeight.w500)),
            if (canEdit) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 16, color: surface.muted),
              tooltip: t.plantDetailDeleteEvent,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: delete,
            ),
            ],
          ],
        ),
      ),
    );
  }

  String _describe(AppLocalizations t, db.CareEventRow e, String verb) {
    final details = _detailsOf(e);
    return details == null ? verb : '$verb — $details';
  }

  /// "product · dose · notes", or null when the event carries none.
  String? _detailsOf(db.CareEventRow e) {
    final parts = <String>[];
    if (e.product != null && e.product!.isNotEmpty) parts.add(e.product!);
    if (e.dose != null && e.dose!.isNotEmpty) parts.add(e.dose!);
    if (e.notes != null && e.notes!.isNotEmpty) parts.add(e.notes!);
    return parts.isEmpty ? null : parts.join(' · ');
  }

}

class _LogEventButton extends StatelessWidget {
  const _LogEventButton({
    required this.surface,
    required this.plantId,
    this.leadingDivider = false,
  });
  final PlantlySurface surface;
  final String plantId;
  final bool leadingDivider;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        border: leadingDivider ? Border(top: BorderSide(color: surface.border)) : null,
      ),
      child: InkWell(
        onTap: () {
          showAdaptiveSheet(
            context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => LogEventSheet(plantId: plantId),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.note_add_outlined, size: 18, color: surface.green),
              const SizedBox(width: 10),
              Text(
                t.logEventTitle,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: surface.green),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact transaction ledger (propagations, gifts, sales, deaths).
/// Hidden when the plant has no history so new plants aren't greeted
/// with a giant empty card.
class _InventoryLedger extends ConsumerWidget {
  const _InventoryLedger({required this.surface, required this.plantId, this.inset = true});
  final PlantlySurface surface;
  final String plantId;

  /// Phone: 20 px page gutter around the card. Desktop column: none.
  final bool inset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final async = ref.watch(inventoryForPlantProvider(plantId));
    return async.maybeWhen(
      data: (txs) {
        if (txs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionLabel(text: t.plantDetailSectionLedger, surface: surface, padding: _labelPad(inset)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: inset ? 20 : 0),
              child: Container(
                decoration: BoxDecoration(
                  color: surface.surface,
                  border: Border.all(color: surface.border),
                  borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    for (var i = 0; i < txs.length; i++)
                      _ledgerRow(context, t, txs[i], i == txs.length - 1),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _ledgerRow(BuildContext context, AppLocalizations t, db.InventoryTransactionRow tx, bool last) {
    final when = DateTime.fromMillisecondsSinceEpoch(tx.at, isUtc: true).toLocal();
    final dateLabel = _fmtDate(context, when);
    final (label, icon, color) = _descriptor(t, tx);
    return Container(
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: surface.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 13, color: surface.text, fontWeight: FontWeight.w600)),
                if (tx.notes != null && tx.notes!.isNotEmpty)
                  Text(tx.notes!, style: TextStyle(fontSize: 11.5, color: surface.muted)),
              ],
            ),
          ),
          Text(dateLabel, style: TextStyle(fontSize: 11, color: surface.muted, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  (String label, IconData icon, Color color) _descriptor(AppLocalizations t, db.InventoryTransactionRow tx) {
    switch (tx.type) {
      case 'propagation':
        final out = tx.parentPlantId == plantId;
        return (out ? t.detailLedgerPropagatedOut : t.detailLedgerPropagatedIn, Icons.content_copy_outlined, surface.green);
      case 'gift':
        final who = tx.counterparty == null || tx.counterparty!.isEmpty ? t.detailLedgerSomeone : tx.counterparty!;
        return (t.detailLedgerGaveTo(who), Icons.card_giftcard_outlined, surface.green);
      case 'sale':
        final buyer = tx.counterparty == null || tx.counterparty!.isEmpty ? null : tx.counterparty!;
        final price = tx.amountMinor == null || tx.currency == null
            ? ''
            : ' · ${(tx.amountMinor! / 100).toStringAsFixed(2)} ${tx.currency}';
        final sold = buyer == null ? t.detailLedgerSold : t.detailLedgerSoldTo(buyer);
        return ('$sold$price', Icons.sell_outlined, surface.terra);
      case 'death':
        return (t.detailLedgerMarkedDead, Icons.local_fire_department_outlined, surface.terra);
      default:
        return (tx.type, Icons.history_toggle_off, surface.muted);
    }
  }
}

/// "Listed on plantly.ro" (CONTRACT §5): Open + Mark as sold, driven by the
/// local listing record written when the export succeeded.
class _ListedOnPlantlyRow extends ConsumerStatefulWidget {
  const _ListedOnPlantlyRow({required this.surface, required this.record});
  final PlantlySurface surface;
  final ListingRecord record;

  @override
  ConsumerState<_ListedOnPlantlyRow> createState() => _ListedOnPlantlyRowState();
}

class _ListedOnPlantlyRowState extends ConsumerState<_ListedOnPlantlyRow> {
  bool _busy = false;

  Future<void> _markSold() async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.listedMarkSoldTitle),
        content: Text(t.listedMarkSoldBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t.listedCancel)),
          FilledButton(
            key: const Key('listed-mark-sold-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.listedMarkSold),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final plugin = ref.read(plantlyRoPluginProvider);
      if (plugin == null) return;
      await plugin.updateStatus(widget.record.postId, 'sold');
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(t.listedMarkedSold)));
    } on PlantlyExportError catch (e) {
      final msg = switch (e.kind) {
        PlantlyExportErrorKind.signInRequired => t.plantlyErrorSignInAgain,
        PlantlyExportErrorKind.network => t.plantlyErrorNetwork,
        _ => t.exportFailedServer(e.message),
      };
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(t.exportFailedServer('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface = widget.surface;
    final record = widget.record;
    final t = AppLocalizations.of(context);
    return Container(
      key: const Key('listed-on-plantly'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface.surface,
        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
        border: Border.all(color: surface.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storefront_outlined, size: 16, color: surface.terra),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.listedOnPlantly,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: surface.text),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: record.isSold ? surface.surfaceAlt : surface.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  record.isSold ? t.listedStatusSold : t.listedStatusActive,
                  key: const Key('listed-status'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: record.isSold ? surface.muted : surface.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('listed-open'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: surface.text,
                    side: BorderSide(color: surface.border),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radius)),
                  ),
                  onPressed: record.url.isEmpty
                      ? null
                      : () => launchUrl(Uri.parse(record.url), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: Text(t.listedOpen, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              ),
              if (!record.isSold) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('listed-mark-sold'),
                    style: FilledButton.styleFrom(
                      backgroundColor: surface.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radius)),
                    ),
                    onPressed: _busy ? null : _markSold,
                    icon: _busy
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.sell_outlined, size: 14),
                    label: Text(t.listedMarkSold, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ExportCTA extends ConsumerWidget {
  const _ExportCTA({required this.surface, required this.onPressed});
  final PlantlySurface surface;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Viewers can't list a plant (read-only collection, §3): no CTA.
    if (!ref.watch(canEditActiveCollectionProvider)) return const SizedBox.shrink();
    final t = AppLocalizations.of(context);
    final sell = ref.watch(sellEnabledProvider);
    return Material(
      color: surface.surface,
      borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: surface.terra, width: 2, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.open_in_new, size: 16, color: surface.terra),
              const SizedBox(width: 8),
              Text(
                sell ? t.exportPostOnPlantlyRoCta : t.exportDraftCta,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: surface.terra),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "LAST `type`" stat: the newest care event that already happened and
/// how many calendar days ago. A future-dated event (logged ahead, or a
/// device clock that ran fast) is not "last" — it read "−16d"; only when
/// every event lies ahead is the nearest one shown, as upcoming
/// ([LastCareStat.future]). Null when there are no events.
@visibleForTesting
LastCareStat? lastCareStat(List<db.CareEventRow> events, DateTime now) {
  if (events.isEmpty) return null;
  final nowMs = now.millisecondsSinceEpoch;
  db.CareEventRow? past;
  db.CareEventRow? upcoming;
  for (final e in events) {
    if (e.doneAt <= nowMs) {
      if (past == null || e.doneAt > past.doneAt) past = e;
    } else if (upcoming == null || e.doneAt < upcoming.doneAt) {
      upcoming = e;
    }
  }
  final pick = past ?? upcoming!;
  final days = calendarDaysUntilMs(pick.doneAt, now).abs();
  return LastCareStat(pick, days, future: past == null);
}

class LastCareStat {
  const LastCareStat(this.event, this.days, {required this.future});
  final db.CareEventRow event;

  /// Calendar days between today and the event's date (never negative).
  final int days;

  /// The event lies ahead (no past event exists): label "in Nd".
  final bool future;
}

class _StatsCard extends ConsumerWidget {
  const _StatsCard({required this.plantId, required this.surface, this.inset = true});
  final String plantId;
  final PlantlySurface surface;
  final bool inset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final types = ref.watch(careTypesProvider);
    final events = ref.watch(careEventsForPlantProvider(plantId)).maybeWhen(
          data: (rows) => rows,
          orElse: () => const <db.CareEventRow>[],
        );
    final lastStat = lastCareStat(events, ref.read(clockProvider)());
    if (lastStat == null) return const SizedBox.shrink();
    final total = events.length;
    final lastType = lastStat.event.type;
    // Average interval for the most-common type.
    final byType = <String, List<int>>{};
    for (final e in events) {
      byType.putIfAbsent(e.type, () => []).add(e.doneAt);
    }
    MapEntry<String, List<int>>? mostFrequent;
    for (final entry in byType.entries) {
      if (mostFrequent == null || entry.value.length > mostFrequent.value.length) {
        mostFrequent = entry;
      }
    }
    double? avgDays;
    if (mostFrequent != null && mostFrequent.value.length >= 2) {
      final sorted = [...mostFrequent.value]..sort();
      var sum = 0;
      for (var i = 1; i < sorted.length; i++) {
        sum += sorted[i] - sorted[i - 1];
      }
      avgDays = (sum / (sorted.length - 1)) / (86400 * 1000);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(text: t.plantDetailSectionStats, surface: surface, padding: _labelPad(inset)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: inset ? 20 : 0),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surface.surface,
              border: Border.all(color: surface.border),
              borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
            ),
            child: Row(
              children: [
                Expanded(child: _StatCell(label: t.statsCellEvents, value: '$total', surface: surface)),
                Container(width: 1, height: 32, color: surface.border),
                Expanded(
                  child: _StatCell(
                    label: t.statsCardLast(careKeyLabel(t, types, lastType)).toUpperCase(),
                    value: lastStat.days == 0
                        ? t.statsCardToday
                        : lastStat.future
                            ? t.statsCardInDaysShort(lastStat.days)
                            : t.statsCardDaysShort(lastStat.days),
                    surface: surface,
                  ),
                ),
                if (avgDays != null) ...[
                  Container(width: 1, height: 32, color: surface.border),
                  Expanded(
                    child: _StatCell(
                      label: t.statsCardAvg(careKeyLabel(t, types, mostFrequent!.key)).toUpperCase(),
                      value: t.statsCardAvgDaysShort(avgDays.toStringAsFixed(avgDays >= 10 ? 0 : 1)),
                      surface: surface,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value, required this.surface});
  final String label;
  final String value;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: surface.text)),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: surface.muted, letterSpacing: 0.08 * 10),
        ),
      ],
    );
  }
}

class _CarouselIconBtn extends StatelessWidget {
  const _CarouselIconBtn({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Tooltip(
            message: tooltip,
            child: Icon(icon, size: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Drag-to-reorder photo list. Pops with the new ordering (or null on
/// cancel) so the caller can persist it via `PlantPhotoRepository.reorder`.
class _ReorderPhotosScreen extends ConsumerStatefulWidget {
  const _ReorderPhotosScreen({required this.rows, required this.fallback});
  final List<db.PlantPhotoRow> rows;
  final MockPlant fallback;

  @override
  ConsumerState<_ReorderPhotosScreen> createState() => _ReorderPhotosScreenState();
}

class _ReorderPhotosScreenState extends ConsumerState<_ReorderPhotosScreen> {
  late List<db.PlantPhotoRow> _order;

  @override
  void initState() {
    super.initState();
    _order = [...widget.rows];
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: surface.bg,
      appBar: AppBar(
        backgroundColor: surface.bg,
        elevation: 0,
        title: Text(t.detailReorderPhotosTitle, style: TextStyle(color: surface.text)),
        leading: IconButton(
          icon: Icon(Icons.close, color: surface.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_order),
            child: Text(t.commonSave, style: TextStyle(color: surface.green, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _order.length,
        // onReorderItem hands us a newIdx already adjusted for the item being
        // removed at oldIdx, so the historical `if (newIdx > oldIdx) newIdx -= 1`
        // compensation that onReorder needed must NOT be repeated here.
        onReorderItem: (oldIdx, newIdx) {
          setState(() {
            final row = _order.removeAt(oldIdx);
            _order.insert(newIdx, row);
          });
        },
        itemBuilder: (_, i) {
          final row = _order[i];
          return Padding(
            key: ValueKey(row.id),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Container(
              decoration: BoxDecoration(
                color: surface.surface,
                border: Border.all(color: surface.border),
                borderRadius: BorderRadius.circular(PlantlyTokens.radius),
              ),
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(PlantlyTokens.radiusMd),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: _PhotoView(sha: row.photoSha, fallback: widget.fallback),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.detailPhotoN(i + 1), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: surface.text)),
                        if ((row.caption ?? '').isNotEmpty)
                          Text(row.caption!, style: TextStyle(fontSize: 11.5, color: surface.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Icon(Icons.drag_handle, color: surface.muted),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

EdgeInsets _labelPad(bool inset) =>
    inset ? const EdgeInsets.fromLTRB(20, 16, 20, 10) : const EdgeInsets.fromLTRB(0, 16, 0, 10);

/// `/plants/:id` on desktop (DESKTOP-POLISH §2): header row (‹ Home ·
/// title · prev/next), action toolbar, then a two-column body — hero +
/// facts + stats + ledger + export on the left (≤ 400 px), the reminders
/// table and the care-history table on the right. `Esc` goes back to `/`.
class _DesktopDetailLayout extends ConsumerWidget {
  const _DesktopDetailLayout({
    required this.plantRow,
    required this.surface,
    required this.swatch,
    required this.locationName,
    required this.types,
    required this.fabKey,
    required this.fabType,
    required this.onEdit,
    required this.onAddPhotos,
    required this.moreMenu,
  });

  final db.PlantRow plantRow;
  final PlantlySurface surface;
  final MockPlant swatch;
  final String locationName;
  final List<CareType> types;
  final String fabKey;
  final CareType fabType;
  final VoidCallback onEdit;
  final VoidCallback onAddPhotos;
  final Widget moreMenu;

  static const double _leftMax = 400;
  static const double _heroMax = 360;

  Future<void> _record(BuildContext context, WidgetRef ref, CareType ct) async {
    await ref.read(careEventRepositoryProvider).record(plantId: plantRow.id, type: ct.key);
    if (!context.mounted) return;
    await showCareFeedback(context, type: ct, plantName: plantRow.nickname, surface: surface);
  }

  void _openSheet(BuildContext context, Widget sheet) {
    showAdaptiveSheet(
      context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => sheet,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final plantId = plantRow.id;
    // Prev/next walk the grid's current sorted + filtered order.
    final sorted = ref.watch(sortedPlantsProvider).maybeWhen(
          data: (rows) => rows,
          orElse: () => const <db.PlantRow>[],
        );
    final idx = sorted.indexWhere((p) => p.id == plantId);
    final prev = idx > 0 ? sorted[idx - 1] : null;
    final next = idx >= 0 && idx < sorted.length - 1 ? sorted[idx + 1] : null;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => goBack(context, fallback: AppRoutes.home),
      },
      child: Focus(
        autofocus: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: PlantlyTokens.space4),
            _header(context, t, ref, prev: prev, next: next),
            // Every toolbar action mutates; a viewer gets the banner instead.
            if (ref.watch(canEditActiveCollectionProvider)) _toolbar(context, t, ref) else const ReadOnlyBanner(),
            const SizedBox(height: PlantlyTokens.space4),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: PlantlyTokens.space8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const gap = PlantlyTokens.space8;
                    final leftW = math.min(_leftMax, (constraints.maxWidth - gap) * 2 / 5);
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: leftW, child: _leftColumn(context, t, ref, leftW)),
                        const SizedBox(width: gap),
                        Expanded(child: _rightColumn(context, t)),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, AppLocalizations t, WidgetRef ref,
      {required db.PlantRow? prev, required db.PlantRow? next}) {
    final species = plantRow.speciesId == null || plantRow.speciesId!.isEmpty
        ? null
        : ref.watch(speciesDisplayNameProvider(plantRow.speciesId!)).maybeWhen(
              data: (name) => name ?? plantRow.speciesId!,
              orElse: () => plantRow.speciesId!,
            );
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: surface.muted,
              padding: const EdgeInsets.symmetric(horizontal: PlantlyTokens.space2),
              textStyle: const TextStyle(fontFamily: PlantlyFonts.inter, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            onPressed: () => goBack(context, fallback: AppRoutes.home),
            icon: const Icon(Icons.chevron_left, size: 20),
            label: Text(t.navHome),
          ),
          const SizedBox(width: PlantlyTokens.space3),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    plantRow.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: PlantlyFonts.plusJakartaSans,
                      fontSize: PlantlyTokens.text3xl,
                      fontWeight: FontWeight.w800,
                      color: surface.text,
                      letterSpacing: -0.02 * PlantlyTokens.text3xl,
                    ),
                  ),
                ),
                if (species != null) ...[
                  const SizedBox(width: PlantlyTokens.space3),
                  Flexible(
                    child: Text(
                      species,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: surface.muted, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: PlantlyTokens.space3),
          IconButton(
            tooltip: t.detailPrevPlant,
            icon: Icon(Icons.navigate_before, color: prev == null ? surface.border : surface.text),
            onPressed: prev == null ? null : () => openPlant(context, prev.id),
          ),
          IconButton(
            tooltip: t.detailNextPlant,
            icon: Icon(Icons.navigate_next, color: next == null ? surface.border : surface.text),
            onPressed: next == null ? null : () => openPlant(context, next.id),
          ),
        ],
      ),
    );
  }

  Widget _toolbar(BuildContext context, AppLocalizations t, WidgetRef ref) {
    final primary = fabType.color ?? surface.green;
    final outlined = OutlinedButton.styleFrom(
      foregroundColor: surface.text,
      side: BorderSide(color: surface.border),
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radius)),
      textStyle: const TextStyle(fontFamily: PlantlyFonts.inter, fontSize: 13, fontWeight: FontWeight.w600),
    );
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          // Split primary: the quick-care type on the left, every other
          // care type behind the chevron (the phone's long-press).
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.horizontal(left: Radius.circular(PlantlyTokens.radius)),
              ),
              textStyle: const TextStyle(fontFamily: PlantlyFonts.inter, fontSize: 13, fontWeight: FontWeight.w700),
            ),
            onPressed: () => _record(context, ref, fabType),
            icon: Icon(fabType.icon, size: 16),
            label: Text(t.detailFabNow(careTypeVerb(t, fabType))),
          ),
          Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.35)),
          PopupMenuButton<String>(
            tooltip: t.detailMoreCareActions,
            onSelected: (key) => _record(context, ref, resolveCareType(types, key)),
            itemBuilder: (_) => [
              for (final ct in types)
                if (ct.key != fabKey)
                  PopupMenuItem(
                    value: ct.key,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(ct.icon, size: 16, color: ct.color ?? surface.green),
                        const SizedBox(width: 10),
                        Text(t.detailFabNow(careTypeVerb(t, ct))),
                      ],
                    ),
                  ),
            ],
            child: Container(
              width: 30,
              height: 36,
              decoration: BoxDecoration(
                color: primary,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(PlantlyTokens.radius)),
              ),
              child: const Icon(Icons.expand_more, size: 18, color: Colors.white),
            ),
          ),
          const SizedBox(width: PlantlyTokens.space2),
          OutlinedButton.icon(
            style: outlined,
            onPressed: () => _openSheet(context, LogEventSheet(plantId: plantRow.id)),
            icon: Icon(Icons.note_add_outlined, size: 16, color: surface.muted),
            label: Text(t.logEventTitle),
          ),
          const SizedBox(width: PlantlyTokens.space2),
          OutlinedButton.icon(
            style: outlined,
            onPressed: () => _openSheet(context, AddReminderSheet(plantId: plantRow.id)),
            icon: Icon(Icons.add_alert_outlined, size: 16, color: surface.muted),
            label: Text(t.plantDetailAddReminder),
          ),
          const SizedBox(width: PlantlyTokens.space2),
          OutlinedButton.icon(
            style: outlined,
            onPressed: onEdit,
            icon: Icon(Icons.edit_outlined, size: 16, color: surface.muted),
            label: Text(t.plantDetailEdit),
          ),
          const SizedBox(width: PlantlyTokens.space2),
          IconButton(
            tooltip: t.plantDetailAddPhotos,
            icon: Icon(Icons.add_a_photo_outlined, color: surface.text),
            onPressed: onAddPhotos,
          ),
          moreMenu,
        ],
      ),
    );
  }

  Widget _leftColumn(BuildContext context, AppLocalizations t, WidgetRef ref, double width) {
    final plantId = plantRow.id;
    final hero = math.min(_heroMax, width);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: hero,
            height: hero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
              child: Container(
                color: surface.surfaceAlt,
                child: _HeroCarousel(plantId: plantId, fallback: swatch, surface: surface),
              ),
            ),
          ),
        ),
        const SizedBox(height: PlantlyTokens.space4),
        _FactsCard(plantRow: plantRow, surface: surface, locationName: locationName),
        _StatsCard(plantId: plantId, surface: surface, inset: false),
        _InventoryLedger(surface: surface, plantId: plantId, inset: false),
        if (ref.watch(listingRecordsProvider)[plantId] case final ListingRecord record)
          Padding(
            padding: const EdgeInsets.only(top: PlantlyTokens.space5),
            child: _ListedOnPlantlyRow(surface: surface, record: record),
          ),
        Padding(
          padding: const EdgeInsets.only(top: PlantlyTokens.space5),
          child: _ExportCTA(
            surface: surface,
            onPressed: () => _openSheet(context, ExportDialog(plantRow: plantRow)),
          ),
        ),
      ],
    );
  }

  Widget _rightColumn(BuildContext context, AppLocalizations t) {
    final plantId = plantRow.id;
    const labelPad = EdgeInsets.fromLTRB(0, 0, 0, 10);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(text: t.plantDetailSectionUpcoming, surface: surface, padding: labelPad),
        _UpcomingTable(surface: surface, plantId: plantId),
        const SizedBox(height: PlantlyTokens.space6),
        _SectionLabel(text: t.plantDetailSectionTimeline, surface: surface, padding: labelPad),
        _Timeline(surface: surface, plantId: plantId),
      ],
    );
  }
}

/// Desktop facts card: label/value rows (space · acquired · pot size ·
/// tags · notes). Rows a plant has no data for are omitted.
class _FactsCard extends StatelessWidget {
  const _FactsCard({required this.plantRow, required this.surface, required this.locationName});
  final db.PlantRow plantRow;
  final PlantlySurface surface;
  final String locationName;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final acquired = plantRow.acquiredAt == null
        ? null
        : _fmtDateLong(context, DateTime.fromMillisecondsSinceEpoch(plantRow.acquiredAt!, isUtc: true).toLocal());
    final notes = plantRow.notes;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _row(t.detailFactSpace, Text(locationName, style: _value, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (acquired != null) _row(t.detailFactAcquired, Text(acquired, style: _value)),
          if (plantRow.potSizeCm != null) _row(t.detailFactPotSize, Text('${plantRow.potSizeCm} cm', style: _value)),
          _row(t.detailFactTags, TagChipInput(plantId: plantRow.id, surface: surface), fixedHeight: false),
          if (notes != null && notes.isNotEmpty)
            _row(t.detailFactNotes, Text(notes, style: _value.copyWith(height: 1.4)), fixedHeight: false),
        ],
      ),
    );
  }

  TextStyle get _value => TextStyle(fontSize: 13, color: surface.text);

  Widget _row(String label, Widget value, {bool fixedHeight = true}) {
    final content = Row(
      crossAxisAlignment: fixedHeight ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Padding(
            padding: EdgeInsets.only(top: fixedHeight ? 0 : 6),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: surface.muted,
                letterSpacing: 0.08 * 11,
              ),
            ),
          ),
        ),
        Expanded(child: value),
      ],
    );
    if (fixedHeight) return SizedBox(height: 32, child: content);
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: content);
  }
}

/// Desktop reminders table: Care · Every · Next due · mute/Done/Snooze/Edit.
class _UpcomingTable extends ConsumerWidget {
  const _UpcomingTable({required this.surface, required this.plantId});
  final PlantlySurface surface;
  final String plantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final canEdit = ref.watch(canEditActiveCollectionProvider);
    final schedulesAsync = ref.watch(schedulesForPlantProvider(plantId));
    final types = ref.watch(careTypesProvider);
    final rowHeight = Theme.of(context).extension<PlantlyDensity>()?.tableRowHeight ?? 44;
    final headStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: surface.muted, letterSpacing: 0.08 * 11);
    final cellStyle = TextStyle(fontSize: 13, color: surface.text);
    return Container(
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
      ),
      clipBehavior: Clip.antiAlias,
      child: schedulesAsync.when(
        loading: () => const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(14),
          child: Text('$e', style: TextStyle(color: surface.terra, fontSize: 12)),
        ),
        data: (schedules) {
          if (schedules.isEmpty) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(t.plantDetailNoReminders, style: TextStyle(fontSize: 12, color: surface.muted)),
                ),
                if (canEdit) _AddReminderButton(surface: surface, plantId: plantId, leadingDivider: true),
              ],
            );
          }
          return Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: DataTable(
                  showCheckboxColumn: false,
                  headingRowHeight: 36,
                  dataRowMinHeight: rowHeight,
                  dataRowMaxHeight: rowHeight,
                  horizontalMargin: 14,
                  columnSpacing: 20,
                  dividerThickness: 1,
                  headingTextStyle: headStyle,
                  dataTextStyle: cellStyle,
                  columns: [
                    DataColumn(label: Text(t.detailColCare.toUpperCase())),
                    DataColumn(label: Text(t.detailColEvery.toUpperCase())),
                    DataColumn(label: Text(t.detailColNextDue.toUpperCase())),
                    const DataColumn(label: SizedBox.shrink()),
                  ],
                  rows: [
                    for (final s in schedules) _row(context, ref, t, s, resolveCareType(types, s.type), cellStyle, canEdit),
                  ],
                ),
              ),
              if (canEdit) _AddReminderButton(surface: surface, plantId: plantId, leadingDivider: true),
            ],
          );
        },
      ),
    );
  }

  String _every(AppLocalizations t, double days) {
    if (days >= 1) return t.detailEveryNDays(days.round());
    // Sub-day intervals only come from the minutes/hours test units.
    return '${(days * 24).toStringAsFixed(1)} h';
  }

  DataRow _row(BuildContext context, WidgetRef ref, AppLocalizations t, db.CareScheduleRow s, CareType ct, TextStyle cellStyle, bool canEdit) {
    final (label, whenText, urgent) = _describeSchedule(t, s, careTypeLabel(t, ct), now: ref.read(clockProvider)());
    final muted = s.notificationsMuted;
    final chipBg = urgent ? surface.terraSoft : (ct.color ?? surface.greenSoft);
    final chipFg = urgent ? surface.terra : (ct.color == null ? surface.green : Colors.white);
    ButtonStyle small({required Color bg, required Color fg, BorderSide? side}) => TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          side: side,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontFamily: PlantlyFonts.inter, fontSize: 11, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radiusMd)),
        );
    return DataRow(
      onSelectChanged: canEdit ? (_) => _editReminder(context, s) : null,
      cells: [
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: chipBg, shape: BoxShape.circle),
              child: Icon(ct.icon, size: 12, color: chipFg),
            ),
            const SizedBox(width: 8),
            Text(label, style: cellStyle.copyWith(fontWeight: FontWeight.w600)),
            if (muted) ...[
              const SizedBox(width: 4),
              Icon(Icons.notifications_off_outlined, size: 13, color: surface.muted),
            ],
          ],
        )),
        DataCell(Text(_every(t, s.currentIntervalDays))),
        DataCell(Text(
          whenText,
          style: TextStyle(
            fontSize: 13,
            color: urgent ? surface.terra : surface.muted,
            fontWeight: urgent ? FontWeight.w600 : FontWeight.w500,
          ),
        )),
        DataCell(!canEdit ? const SizedBox.shrink() : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: muted ? t.detailUnmuteReminderTooltip : t.detailMuteReminderTooltip,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: Icon(muted ? Icons.notifications_off_outlined : Icons.notifications_outlined, size: 16, color: surface.muted),
              onPressed: () => ref.read(careScheduleRepositoryProvider).setNotificationsMuted(s.id, !muted),
            ),
            const SizedBox(width: 4),
            TextButton(
              style: small(bg: surface.green, fg: Colors.white),
              onPressed: () => _recordSchedule(context, ref, s, ct, plantId, label, surface),
              child: Text(t.doneBtn),
            ),
            const SizedBox(width: 6),
            TextButton(
              style: small(bg: surface.surfaceAlt, fg: surface.muted, side: BorderSide(color: surface.border)),
              onPressed: () => _snoozeSchedule(context, ref, s),
              child: Text(t.snoozeBtn),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: t.editReminderTitle(careTypeLabel(t, ct).toLowerCase()),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: Icon(Icons.edit_outlined, size: 16, color: surface.muted),
              onPressed: () => _editReminder(context, s),
            ),
          ],
        )),
      ],
    );
  }
}
