import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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
import '../../shared/stored_photo_image.dart';
import '../../sync/hlc.dart';
import '../../theme/tokens.dart';
import '../export/export_dialog.dart';
import '../home/home_providers.dart';
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
              leading: IconButton(
                icon: Icon(Icons.chevron_left, color: surface.text),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final plantId = plantRow.id;
    final locationAsync = plantRow.locationId == null
        ? null
        : ref.watch(locationByIdProvider(plantRow.locationId!));
    final locationName = locationAsync?.maybeWhen(
          data: (loc) => loc?.name,
          orElse: () => null,
        ) ??
        (plantRow.locationId == null ? t.detailNoLocation : t.detailLoadingLocation);

    final types = ref.watch(careTypesProvider);
    final fabKey = ref.watch(quickFabTypeProvider);
    final fabType = resolveCareType(types, fabKey);
    return Scaffold(
      backgroundColor: surface.bg,
      floatingActionButton: GestureDetector(
        onLongPress: () => _pickFabType(context, ref, types),
        child: FloatingActionButton.extended(
          backgroundColor: fabType.color ?? surface.green,
          foregroundColor: Colors.white,
          icon: Icon(fabType.icon),
          label: Text(t.detailFabNow(careTypeVerb(t, fabType))),
          tooltip: t.detailFabTooltip,
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
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: surface.text),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: surface.text),
            tooltip: t.plantDetailEdit,
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => EditPlantSheet(plantRow: plantRow),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.add_a_photo_outlined, color: surface.text),
            tooltip: t.plantDetailAddPhotos,
            onPressed: () async {
              final picker = ref.read(photoPickerProvider);
              final picked = await pickMultiPhotoWithSource(context, picker, surface);
              if (picked.isEmpty) return;
              final processor = ref.read(imageProcessorProvider);
              final photos = ref.read(photoRepositoryProvider);
              final joins = ref.read(plantPhotoRepositoryProvider);
              for (final p in picked) {
                final shrunk = await processor.toDisplay(p.bytes);
                final sha = await photos.saveBytes(shrunk, mime: 'image/jpeg');
                await joins.attach(plantId, sha);
              }
            },
          ),
          PopupMenuButton<String>(
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
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => PlantDetailScreen(plantId: child.id)),
                    );
                  }
                  break;
                case 'move':
                  await _pickLocationDialog(context, ref, plantRow);
                  break;
                case 'duplicate':
                  final child = await ref.read(plantRepositoryProvider).duplicate(plantRow.id);
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => PlantDetailScreen(plantId: child.id)),
                    );
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
                  final navigator = Navigator.of(context);
                  final closed = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => InventoryActionSheet(plantRow: plantRow, type: value),
                  );
                  if (closed == true && context.mounted) {
                    navigator.maybePop();
                  }
                  break;
                case 'delete':
                  final nav = Navigator.of(context);
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
                    if (context.mounted) nav.maybePop();
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
          ),
        ],
      ),
      body: ListView(
        children: [
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
                  style: GoogleFonts.plusJakartaSans(
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
                      ? t.detailAddedOn(_fmtDateLong(context, DateTime.now()))
                      : t.detailAcquiredOn(_fmtDateLong(
                          context,
                          DateTime.fromMillisecondsSinceEpoch(plantRow.acquiredAt!, isUtc: true).toLocal(),
                        )),
                  style: TextStyle(fontSize: 12, color: surface.muted),
                ),
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
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => ExportDialog(plantRow: plantRow),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFabType(BuildContext context, WidgetRef ref, List<CareType> types) async {
    final t = AppLocalizations.of(context);
    final current = ref.read(quickFabTypeProvider);
    final mode = ref.read(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: surface.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(PlantlyTokens.radius2xl)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(color: surface.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              t.plantDetailQuickAction,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: surface.text),
            ),
            Text(
              t.plantDetailQuickActionHelp,
              style: TextStyle(fontSize: 12, color: surface.muted),
            ),
            const SizedBox(height: 14),
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
                onLongPress: () => _confirmDetach(shas[i]),
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
              ),
            ),
            if (_index < rows.length)
              Positioned(
                top: 10,
                left: 10,
                child: GestureDetector(
                  onTap: () => _editCapturedAt(rows[_index]),
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
  const _SectionLabel({required this.text, required this.surface});
  final String text;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
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
                _AddReminderButton(surface: surface, plantId: plantId, leadingDivider: true),
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
              _AddReminderButton(surface: surface, plantId: plantId, leadingDivider: true),
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
    final (label, whenText, urgent) = _describe(t, schedule, careTypeLabel(t, ct));
    final icon = ct.icon;
    final muted = schedule.notificationsMuted;
    // If the user gave this type a colour, use it as the chip fill; the
    // terra urgent tint still wins when the reminder is actually overdue.
    final chipBg = urgent ? surface.terraSoft : (ct.color ?? surface.greenSoft);
    final chipFg = urgent ? surface.terra : (ct.color == null ? surface.green : Colors.white);
    return InkWell(
      onLongPress: () {
        showModalBottomSheet(
          context: context,
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
            onPressed: () async {
              await ref.read(careEventRepositoryProvider).record(
                    plantId: plantId,
                    type: schedule.type,
                  );
              if (!context.mounted) return;
              await showCareFeedback(
                context,
                type: ct,
                plantName: ref.read(plantByIdProvider(plantId)).maybeWhen(
                      data: (p) => p?.nickname ?? label,
                      orElse: () => label,
                    ),
                surface: surface,
              );
            },
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
            onPressed: () async {
              await ref
                  .read(careScheduleRepositoryProvider)
                  .snooze(schedule.id, by: const Duration(days: 3));
              if (context.mounted) _toast(context, t.detailSnoozedToast);
            },
            child: Text(t.snoozeBtn),
          ),
        ],
      ),
      ),
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  (String label, String when, bool urgent) _describe(
    AppLocalizations t,
    db.CareScheduleRow s,
    String label,
  ) {
    final due = s.nextDueAt;
    if (due == null) return (label, t.detailNoDueDate, false);
    final now = DateTime.now().millisecondsSinceEpoch;
    final diffMs = due - now;
    final days = (diffMs / (86400 * 1000)).round();
    if (diffMs < 0) {
      final late = -days;
      return (label, late == 0 ? t.detailOverdue : t.detailOverdueDays(late), true);
    }
    if (days == 0) return (label, t.detailDueToday, true);
    if (days == 1) return (label, t.detailDueTomorrow, false);
    return (label, t.detailDueInDays(days), false);
  }
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
          showModalBottomSheet(
            context: context,
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
          final logButton = _LogEventButton(
            surface: surface,
            plantId: plantId,
            leadingDivider: events.isNotEmpty,
          );
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

  Widget _timelineRow(BuildContext context, WidgetRef ref, db.CareEventRow event, bool last) {
    final t = AppLocalizations.of(context);
    final types = ref.watch(careTypesProvider);
    final when = _fmtDate(context, DateTime.fromMillisecondsSinceEpoch(event.doneAt, isUtc: true).toLocal());
    final text = _describe(t, event, careKeyPastLabel(t, types, event.type));
    Future<void> delete() async {
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

    return InkWell(
      onLongPress: delete,
      onTap: () {
        showModalBottomSheet(
          context: context,
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
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 16, color: surface.muted),
              tooltip: t.plantDetailDeleteEvent,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: delete,
            ),
          ],
        ),
      ),
    );
  }

  String _describe(AppLocalizations t, db.CareEventRow e, String verb) {
    final parts = <String>[];
    if (e.product != null && e.product!.isNotEmpty) parts.add(e.product!);
    if (e.dose != null && e.dose!.isNotEmpty) parts.add(e.dose!);
    if (e.notes != null && e.notes!.isNotEmpty) parts.add(e.notes!);
    if (parts.isEmpty) return verb;
    return '$verb — ${parts.join(' · ')}';
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
          showModalBottomSheet(
            context: context,
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
  const _InventoryLedger({required this.surface, required this.plantId});
  final PlantlySurface surface;
  final String plantId;

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
            _SectionLabel(text: t.plantDetailSectionLedger, surface: surface),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
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

class _StatsCard extends ConsumerWidget {
  const _StatsCard({required this.plantId, required this.surface});
  final String plantId;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final types = ref.watch(careTypesProvider);
    final events = ref.watch(careEventsForPlantProvider(plantId)).maybeWhen(
          data: (rows) => rows,
          orElse: () => const <db.CareEventRow>[],
        );
    if (events.isEmpty) return const SizedBox.shrink();
    final total = events.length;
    // events is newest-first — the first entry is the last action.
    final last = events.first;
    final lastType = last.type;
    final lastWhen = DateTime.fromMillisecondsSinceEpoch(last.doneAt, isUtc: true).toLocal();
    final daysAgo = DateTime.now().difference(lastWhen).inDays;
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
        _SectionLabel(text: t.plantDetailSectionStats, surface: surface),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
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
                    value: daysAgo == 0 ? t.statsCardToday : t.statsCardDaysShort(daysAgo),
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
