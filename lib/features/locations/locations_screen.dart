import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/mock_plants.dart';
import '../../data/providers.dart';
import '../../data/repositories/location_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/hover_card.dart';
import '../../shared/plant_thumb.dart';
import '../../shared/stored_photo_image.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';
import 'assign_plants_sheet.dart';
import 'location_edit_sheet.dart';
import 'space_kind_label.dart';
import '../../app/breakpoints.dart';
import '../../app/side_sheet.dart';
import '../../app/navigation.dart';

/// Hierarchical Spaces list + add-dialog + assign-plants flow.
///
/// Desktop (DESKTOP-POLISH §4) renders the tree flattened into a card grid
/// with a page header; phone keeps the list + FAB, tablet keeps the list
/// with the Add button moved into the app bar.
class LocationsScreen extends ConsumerWidget {
  const LocationsScreen({super.key});

  static void _openAdd(BuildContext context) {
    showAdaptiveSheet(
      context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LocationEditSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final async = ref.watch(locationsStreamProvider);
    final t = AppLocalizations.of(context);

    if (context.isDesktop) return _DesktopSpaces(surface: surface, async: async);

    return Scaffold(
      backgroundColor: surface.bg,
      appBar: AppBar(
        backgroundColor: surface.bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: adaptiveBackButton(context, surface),
        title: Text(
          t.spaces,
          style: TextStyle(fontFamily: PlantlyFonts.plusJakartaSans,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: surface.text,
            letterSpacing: -0.02 * 22,
          ),
        ),
        actions: [
          if (context.isWide)
            Padding(
              padding: const EdgeInsets.only(right: PlantlyTokens.space4),
              child: _AddSpaceButton(surface: surface, onPressed: () => _openAdd(context)),
            ),
        ],
      ),
      floatingActionButton: context.isWide
          ? null
          : FloatingActionButton(
              backgroundColor: surface.green,
              foregroundColor: Colors.white,
              tooltip: t.addSpace,
              onPressed: () => _openAdd(context),
              child: const Icon(Icons.add),
            ),
      body: async.when(
        loading: () => Center(child: CircularProgressIndicator(color: surface.green)),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text(t.spaceLoadFailed('$e'), style: TextStyle(color: surface.terra)),
        ),
        data: (rows) {
          if (rows.isEmpty) return _Empty(surface: surface);
          final tree = buildTree(rows);
          return ListView(
            // Bottom clearance for the FAB (+ gesture-nav inset).
            padding: EdgeInsets.fromLTRB(20, 8, 20, 96 + MediaQuery.paddingOf(context).bottom),
            children: [
              for (final node in tree) _LocationTile(node: node, depth: 0, surface: surface),
            ],
          );
        },
      ),
    );
  }
}

class _AddSpaceButton extends StatelessWidget {
  const _AddSpaceButton({required this.surface, required this.onPressed});
  final PlantlySurface surface;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(backgroundColor: surface.green, foregroundColor: Colors.white),
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 18),
      label: Text(AppLocalizations.of(context).addSpace),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.surface});
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          AppLocalizations.of(context).noSpacesYet,
          textAlign: TextAlign.center,
          style: TextStyle(color: surface.muted, fontSize: 14),
        ),
      ),
    );
  }
}

/// `/spaces` on desktop: page header + flattened tree as a card grid. The
/// shell already centres the content column and applies the gutters.
class _DesktopSpaces extends StatelessWidget {
  const _DesktopSpaces({required this.surface, required this.async});
  final PlantlySurface surface;
  final AsyncValue<List<LocationRow>> async;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Material(
      color: surface.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: PlantlyTokens.space6, bottom: PlantlyTokens.space4),
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  Text(
                    t.spaces,
                    style: TextStyle(
                      fontFamily: PlantlyFonts.plusJakartaSans,
                      fontSize: PlantlyTokens.text3xl,
                      fontWeight: FontWeight.w800,
                      color: surface.text,
                      letterSpacing: -0.02 * PlantlyTokens.text3xl,
                    ),
                  ),
                  const Spacer(),
                  _AddSpaceButton(surface: surface, onPressed: () => LocationsScreen._openAdd(context)),
                ],
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => Center(child: CircularProgressIndicator(color: surface.green)),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text(t.spaceLoadFailed('$e'), style: TextStyle(color: surface.terra)),
              ),
              data: (rows) {
                if (rows.isEmpty) return _Empty(surface: surface);
                final byId = {for (final r in rows) r.id: r};
                final flat = <LocationRow>[];
                void walk(List<LocationNode> nodes) {
                  for (final n in nodes) {
                    flat.add(n.row);
                    walk(n.children);
                  }
                }

                walk(buildTree(rows));
                return LayoutBuilder(
                  builder: (context, constraints) {
                    const gap = PlantlyTokens.space4;
                    final cols = adaptiveColumns(context, constraints.maxWidth, phone: 1, minTileWidth: 240);
                    final tileWidth = (constraints.maxWidth - gap * (cols - 1)) / cols;
                    return GridView.builder(
                      padding: const EdgeInsets.only(bottom: PlantlyTokens.space8),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: gap,
                        crossAxisSpacing: gap,
                        // 4:3 cover + meta block; see _SpaceCard.metaHeight.
                        mainAxisExtent: tileWidth * 3 / 4 + _SpaceCard.metaHeight,
                      ),
                      itemCount: flat.length,
                      itemBuilder: (context, i) => _SpaceCard(row: flat[i], byId: byId, surface: surface),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One grid tile: 4:3 cover, name, "Home › Room · kind · n plants", plant
/// thumbs. Every text line has a fixed line height so the grid's
/// `mainAxisExtent` can be computed without measuring.
class _SpaceCard extends ConsumerWidget {
  const _SpaceCard({required this.row, required this.byId, required this.surface});
  final LocationRow row;
  final Map<String, LocationRow> byId;
  final PlantlySurface surface;

  static const double _pad = 12;
  static const double _nameLine = 14 * 1.3;
  static const double _metaLine = 12 * 1.3;
  static const double _thumb = 28;

  /// Height of everything under the cover, plus the card's 1 px borders.
  /// The cover is `Expanded`, so if real text metrics run a few px over
  /// these line heights the cover gives, rather than the column overflowing.
  static const double metaHeight = _pad + _nameLine + 2 + _metaLine + 8 + _thumb + _pad + 2;

  String _path() {
    final names = <String>[];
    var parent = row.parentId;
    while (parent != null) {
      final p = byId[parent];
      if (p == null) break;
      names.insert(0, p.name);
      parent = p.parentId;
    }
    return names.join(' › ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final plants = ref.watch(plantsByLocationProvider(row.id)).maybeWhen(
          data: (rows) => rows,
          orElse: () => const <PlantRow>[],
        );
    final path = _path();
    final meta = [
      if (path.isNotEmpty) path,
      spaceKindLabel(t, row.kind),
      t.spaceCardPlantCount(plants.length),
    ].join(' · ');
    final shown = plants.length > 5 ? plants.sublist(0, 5) : plants;

    return HoverCard(
      surface: surface,
      onTap: () => openSpace(context, row.id),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: surface.surface,
          border: Border.all(color: surface.border),
          borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _Cover(row: row, surface: surface)),
            Padding(
              padding: const EdgeInsets.all(_pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    row.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, height: 1.3, fontWeight: FontWeight.w600, color: surface.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, height: 1.3, color: surface.muted),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: _thumb,
                    child: Stack(
                      children: [
                        for (var i = 0; i < shown.length; i++)
                          Positioned(
                            left: i * (_thumb - 8),
                            child: Container(
                              width: _thumb,
                              height: _thumb,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: surface.surface, width: 1.5),
                              ),
                              child: PlantPhotoThumb(
                                plantId: shown[i].id,
                                fallback: MockPlants.byId(shown[i].id),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cover extends ConsumerWidget {
  const _Cover({required this.row, required this.surface});
  final LocationRow row;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallback = Container(
      color: surface.surfaceAlt,
      alignment: Alignment.center,
      child: Icon(spaceKindIcon(row.kind), size: 40, color: surface.muted),
    );
    var sha = row.mapPhotoSha;
    if (sha == null) {
      final photos = ref.watch(locationPhotosProvider(row.id)).maybeWhen(
            data: (rows) => rows,
            orElse: () => const <LocationPhotoRow>[],
          );
      if (photos.isNotEmpty) sha = photos.first.photoSha;
    }
    if (sha == null) return fallback;
    return StoredPhotoImage(sha: sha, placeholder: fallback);
  }
}

class _LocationTile extends ConsumerWidget {
  const _LocationTile({required this.node, required this.depth, required this.surface});
  final LocationNode node;
  final int depth;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plants = ref.watch(plantsByLocationProvider(node.row.id)).maybeWhen(
          data: (rows) => rows,
          orElse: () => const <PlantRow>[],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(left: depth * 20.0, bottom: 4, top: depth == 0 ? 12 : 4),
          child: Material(
            color: surface.surface,
            borderRadius: BorderRadius.circular(PlantlyTokens.radius),
            child: HoverCard(
            surface: surface,
            borderRadius: PlantlyTokens.radius,
            onTap: () => openSpace(context, node.row.id),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: surface.border),
                borderRadius: BorderRadius.circular(PlantlyTokens.radius),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(spaceKindIcon(node.row.kind), size: 18, color: surface.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            node.row.name,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text),
                          ),
                          Text(
                            '${spaceKindLabel(AppLocalizations.of(context), node.row.kind)}${plants.isEmpty ? '' : ' · ${AppLocalizations.of(context).spacePlantCount(plants.length)}'}',
                            style: TextStyle(fontSize: 11, color: surface.muted),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      icon: Icon(Icons.eco_outlined, size: 14, color: surface.green),
                      label: Text(
                        plants.isEmpty ? AppLocalizations.of(context).spaceAddPlants : AppLocalizations.of(context).spaceManage,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: surface.green),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: surface.green, width: 1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: () {
                        showAdaptiveSheet(
                          context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => AssignPlantsSheet(location: node.row),
                        );
                      },
                    ),
                  ],
                ),
                if (plants.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: plants.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (_, i) {
                        final p = plants[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: surface.surfaceAlt,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: surface.border),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: PlantPhotoThumb(
                                  plantId: p.id,
                                  fallback: MockPlants.byId(p.id),
                                  size: 28,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(p.nickname, style: TextStyle(fontSize: 12, color: surface.text)),
                              const SizedBox(width: 6),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
            ),
            ),
          ),
        ),
        for (final child in node.children) _LocationTile(node: child, depth: depth + 1, surface: surface),
      ],
    );
  }
}
