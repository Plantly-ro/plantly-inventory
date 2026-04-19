import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/database/app_database.dart';
import '../../data/image_processor.dart';
import '../../data/mock_plants.dart';
import '../../data/photo_picker.dart';
import '../../data/providers.dart';
import '../../shared/plant_thumb.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';
import '../plant_detail/plant_detail_screen.dart';
import 'assign_plants_sheet.dart';
import 'location_edit_sheet.dart';

/// Full detail screen for a single location. Shows the metadata (kind,
/// parent, light/humidity/temp ranges, notes, outdoor flag), every
/// plant assigned to it, and an optional user-supplied "map" image
/// that the user can drop plant pins on to track where things sit.
class LocationDetailScreen extends ConsumerStatefulWidget {
  const LocationDetailScreen({super.key, required this.locationId});
  final String locationId;

  @override
  ConsumerState<LocationDetailScreen> createState() => _LocationDetailScreenState();
}

class _LocationDetailScreenState extends ConsumerState<LocationDetailScreen> {
  bool _editingPins = false;

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final repo = ref.watch(locationRepositoryProvider);
    final locAsync = ref.watch(locationByIdStreamProvider(widget.locationId));
    final plants = ref.watch(plantsByLocationProvider(widget.locationId)).maybeWhen(
          data: (rows) => rows,
          orElse: () => const <PlantRow>[],
        );

    return Scaffold(
      backgroundColor: surface.bg,
      body: locAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Failed to load location.\n$e', style: TextStyle(color: surface.terra)),
        ),
        data: (loc) {
          if (loc == null) {
            return Scaffold(
              appBar: AppBar(backgroundColor: surface.bg, elevation: 0),
              body: Center(
                child: Text('Location no longer exists.', style: TextStyle(color: surface.muted)),
              ),
            );
          }
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: surface.bg,
                elevation: 0,
                pinned: true,
                leading: IconButton(
                  icon: Icon(Icons.chevron_left, color: surface.text),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                title: Text(
                  loc.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: surface.text,
                    letterSpacing: -0.02 * 20,
                  ),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => LocationEditSheet(existing: loc),
                      );
                    },
                    icon: Icon(Icons.edit_outlined, color: surface.text),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_horiz, color: surface.text),
                    onSelected: (v) async {
                      switch (v) {
                        case 'assign':
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => AssignPlantsSheet(location: loc),
                          );
                          break;
                        case 'mute':
                          await repo.setNotificationsMuted(loc.id, !loc.notificationsMuted);
                          break;
                        case 'map':
                          await _pickMap(context, ref);
                          break;
                        case 'clearmap':
                          await repo.setMapPhoto(loc.id, null);
                          break;
                        case 'delete':
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (dctx) => AlertDialog(
                              title: const Text('Delete space?'),
                              content: Text('Removes "${loc.name}". Plants keep their existing position in other spaces.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('Cancel')),
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: surface.terra),
                                  onPressed: () => Navigator.of(dctx).pop(true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await repo.softDelete(loc.id);
                            if (context.mounted) Navigator.of(context).maybePop();
                          }
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'assign', child: Text('Assign plants…')),
                      PopupMenuItem(
                        value: 'mute',
                        child: Text(loc.notificationsMuted ? 'Unmute notifications' : 'Mute notifications'),
                      ),
                      if (loc.mapPhotoSha == null)
                        const PopupMenuItem(value: 'map', child: Text('Add map image…'))
                      else
                        const PopupMenuItem(value: 'clearmap', child: Text('Remove map image')),
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'delete', child: Text('Delete space…')),
                    ],
                  ),
                ],
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  _Meta(loc: loc, surface: surface),
                  if (loc.mapPhotoSha != null) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                      child: Row(
                        children: [
                          Text('MAP', style: _sectionStyle(surface)),
                          const Spacer(),
                          TextButton.icon(
                            icon: Icon(_editingPins ? Icons.check : Icons.edit_location_outlined, size: 16),
                            label: Text(_editingPins ? 'Done placing' : 'Place pins', style: const TextStyle(fontSize: 11.5)),
                            onPressed: () => setState(() => _editingPins = !_editingPins),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _LocationMapView(
                        mapPhotoSha: loc.mapPhotoSha!,
                        plants: plants,
                        surface: surface,
                        editing: _editingPins,
                      ),
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                      child: Text('MAP', style: _sectionStyle(surface)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _EmptyMapCta(
                        surface: surface,
                        onPick: () => _pickMap(context, ref),
                      ),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                    child: Text('PLANTS (${plants.length})', style: _sectionStyle(surface)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _PlantsList(plants: plants, surface: surface),
                  ),
                  const SizedBox(height: 30),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickMap(BuildContext context, WidgetRef ref) async {
    final picker = ref.read(photoPickerProvider);
    final picked = await picker.pickFromGallery();
    if (picked == null) return;
    final processor = ref.read(imageProcessorProvider);
    final shrunk = await processor.toDisplay(picked.bytes);
    final sha = await ref.read(photoRepositoryProvider).saveBytes(shrunk, mime: 'image/jpeg');
    await ref.read(locationRepositoryProvider).setMapPhoto(widget.locationId, sha);
  }

  TextStyle _sectionStyle(PlantlySurface s) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: s.green,
        letterSpacing: 0.1 * 11,
      );
}

final locationByIdStreamProvider =
    StreamProvider.family<LocationRow?, String>((ref, id) {
  return ref.watch(locationRepositoryProvider).watchById(id);
});

class _Meta extends StatelessWidget {
  const _Meta({required this.loc, required this.surface});
  final LocationRow loc;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    chips.add(_Chip(label: loc.kind, surface: surface));
    if (loc.isOutdoor) chips.add(_Chip(label: 'outdoor', surface: surface, accent: true));
    if (loc.light != null) chips.add(_Chip(label: 'light: ${loc.light}', surface: surface));
    if (loc.humidityMin != null || loc.humidityMax != null) {
      chips.add(_Chip(label: 'humidity ${loc.humidityMin ?? '—'}–${loc.humidityMax ?? '—'}%', surface: surface));
    }
    if (loc.tempMinC != null || loc.tempMaxC != null) {
      chips.add(_Chip(label: 'temp ${loc.tempMinC ?? '—'}–${loc.tempMaxC ?? '—'}°C', surface: surface));
    }
    if (loc.notificationsMuted) {
      chips.add(_Chip(label: 'muted', surface: surface, accent: true));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 6, runSpacing: 6, children: chips),
          if (loc.notes != null && loc.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(loc.notes!, style: TextStyle(fontSize: 13, color: surface.text)),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.surface, this.accent = false});
  final String label;
  final PlantlySurface surface;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final bg = accent ? surface.terraSoft : surface.greenSoft;
    final fg = accent ? surface.terra : surface.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _EmptyMapCta extends StatelessWidget {
  const _EmptyMapCta({required this.surface, required this.onPick});
  final PlantlySurface surface;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: surface.surface,
          border: Border.all(color: surface.border, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, size: 30, color: surface.muted),
            const SizedBox(height: 8),
            Text(
              'Add a layout image',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: surface.text),
            ),
            Text(
              'Room photo or a rough sketch — drop plant pins on top.',
              style: TextStyle(fontSize: 11.5, color: surface.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationMapView extends ConsumerWidget {
  const _LocationMapView({
    required this.mapPhotoSha,
    required this.plants,
    required this.surface,
    required this.editing,
  });
  final String mapPhotoSha;
  final List<PlantRow> plants;
  final PlantlySurface surface;
  final bool editing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoRepo = ref.watch(photoRepositoryProvider);
    return FutureBuilder(
      future: photoRepo.byHash(mapPhotoSha),
      builder: (context, snap) {
        final path = snap.data?.localPath;
        if (path == null || !File(path).existsSync()) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: surface.surfaceAlt,
              borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
            ),
            child: const Center(child: Text('Map image missing')),
          );
        }
        return AspectRatio(
          aspectRatio: 4 / 3,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              return ClipRRect(
                borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.file(File(path), fit: BoxFit.cover),
                    ),
                    if (editing)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTapUp: (details) => _assignTap(context, ref, details, w, h),
                        ),
                      ),
                    for (final p in plants)
                      if (p.pinX != null && p.pinY != null)
                        _PositionedPin(
                          plant: p,
                          surface: surface,
                          width: w,
                          height: h,
                          editing: editing,
                          onMove: editing
                              ? (x, y) => ref.read(plantRepositoryProvider).setPin(p.id, x, y)
                              : null,
                          onRemove: editing
                              ? () => ref.read(plantRepositoryProvider).setPin(p.id, null, null)
                              : null,
                        ),
                    if (editing)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            plants.any((p) => p.pinX == null || p.pinY == null)
                                ? 'Tap to place • drag to move • long-press to remove'
                                : 'Drag pins to move • long-press to remove',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _assignTap(
    BuildContext context,
    WidgetRef ref,
    TapUpDetails details,
    double w,
    double h,
  ) async {
    final unplaced = plants.where((p) => p.pinX == null || p.pinY == null).toList();
    if (unplaced.isEmpty) return;
    final target = unplaced.first;
    final fx = (details.localPosition.dx / w).clamp(0.0, 1.0);
    final fy = (details.localPosition.dy / h).clamp(0.0, 1.0);
    await ref.read(plantRepositoryProvider).setPin(target.id, fx, fy);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text('Placed ${target.nickname}')));
  }
}

class _PositionedPin extends StatelessWidget {
  const _PositionedPin({
    required this.plant,
    required this.surface,
    required this.width,
    required this.height,
    required this.editing,
    required this.onMove,
    required this.onRemove,
  });
  final PlantRow plant;
  final PlantlySurface surface;
  final double width;
  final double height;
  final bool editing;
  final void Function(double x, double y)? onMove;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    const size = 44.0;
    final x = (plant.pinX ?? 0.5) * width - size / 2;
    final y = (plant.pinY ?? 0.5) * height - size / 2;
    return Positioned(
      left: x,
      top: y,
      width: size,
      height: size,
      child: GestureDetector(
        onLongPress: onRemove,
        onPanUpdate: onMove == null
            ? null
            : (details) {
                final nx = ((x + details.delta.dx + size / 2) / width).clamp(0.0, 1.0);
                final ny = ((y + details.delta.dy + size / 2) / height).clamp(0.0, 1.0);
                onMove!.call(nx, ny);
              },
        onTap: editing
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PlantDetailScreen(plantId: plant.id)),
                );
              },
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: PlantPhotoThumb(
            plantId: plant.id,
            fallback: MockPlants.byId(plant.id),
            size: size,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class _PlantsList extends ConsumerWidget {
  const _PlantsList({required this.plants, required this.surface});
  final List<PlantRow> plants;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (plants.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surface.surface,
          border: Border.all(color: surface.border),
          borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
        ),
        alignment: Alignment.center,
        child: Text('No plants here yet.', style: TextStyle(color: surface.muted, fontSize: 12)),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < plants.length; i++)
          _Row(
            plant: plants[i],
            surface: surface,
            first: i == 0,
            last: i == plants.length - 1,
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.plant, required this.surface, required this.first, required this.last});
  final PlantRow plant;
  final PlantlySurface surface;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface.surface,
      borderRadius: BorderRadius.vertical(
        top: first ? const Radius.circular(PlantlyTokens.radiusXl) : Radius.zero,
        bottom: last ? const Radius.circular(PlantlyTokens.radiusXl) : Radius.zero,
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PlantDetailScreen(plantId: plant.id)),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: surface.border),
              right: BorderSide(color: surface.border),
              top: first ? BorderSide(color: surface.border) : BorderSide.none,
              bottom: BorderSide(color: surface.border),
            ),
            borderRadius: BorderRadius.vertical(
              top: first ? const Radius.circular(PlantlyTokens.radiusXl) : Radius.zero,
              bottom: last ? const Radius.circular(PlantlyTokens.radiusXl) : Radius.zero,
            ),
          ),
          child: Row(
            children: [
              PlantPhotoThumb(
                plantId: plant.id,
                fallback: MockPlants.byId(plant.id),
                size: 40,
                borderRadius: BorderRadius.circular(PlantlyTokens.radius),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(plant.nickname, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text)),
              ),
              if (plant.pinX != null && plant.pinY != null)
                Icon(Icons.place, size: 14, color: surface.green),
              Icon(Icons.chevron_right, color: surface.muted),
            ],
          ),
        ),
      ),
    );
  }
}
