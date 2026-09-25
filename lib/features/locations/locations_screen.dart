import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/mock_plants.dart';
import '../../data/providers.dart';
import '../../data/repositories/location_repository.dart';
import '../../shared/plant_thumb.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';
import 'assign_plants_sheet.dart';
import 'location_detail_screen.dart';
import 'location_edit_sheet.dart';

/// Hierarchical Spaces list + add-dialog + assign-plants flow.
class LocationsScreen extends ConsumerWidget {
  const LocationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final async = ref.watch(locationsStreamProvider);

    return Scaffold(
      backgroundColor: surface.bg,
      appBar: AppBar(
        backgroundColor: surface.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: surface.text),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Spaces',
          style: TextStyle(fontFamily: PlantlyFonts.plusJakartaSans, 
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: surface.text,
            letterSpacing: -0.02 * 22,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: surface.green,
        foregroundColor: Colors.white,
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const LocationEditSheet(),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: async.when(
        loading: () => Center(child: CircularProgressIndicator(color: surface.green)),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load locations.\n$e', style: TextStyle(color: surface.terra)),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No spaces yet. Tap + to add a room, shelf, or balcony.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: surface.muted, fontSize: 14),
                ),
              ),
            );
          }
          final tree = buildTree(rows);
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            children: [
              for (final node in tree) _LocationTile(node: node, depth: 0, surface: surface),
            ],
          );
        },
      ),
    );
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
            child: InkWell(
              borderRadius: BorderRadius.circular(PlantlyTokens.radius),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => LocationDetailScreen(locationId: node.row.id)),
                );
              },
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
                    Icon(_iconFor(node.row.kind), size: 18, color: surface.green),
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
                            '${node.row.kind}${plants.isEmpty ? '' : ' · ${plants.length} plant${plants.length == 1 ? '' : 's'}'}',
                            style: TextStyle(fontSize: 11, color: surface.muted),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      icon: Icon(Icons.eco_outlined, size: 14, color: surface.green),
                      label: Text(
                        plants.isEmpty ? 'Add plants' : 'Manage',
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
                        showModalBottomSheet(
                          context: context,
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

  IconData _iconFor(String kind) {
    switch (kind) {
      case 'home':
        return Icons.home_outlined;
      case 'room':
        return Icons.meeting_room_outlined;
      case 'shelf':
        return Icons.shelves;
      case 'outdoor_bed':
        return Icons.outdoor_grill_outlined;
      default:
        return Icons.place_outlined;
    }
  }
}

