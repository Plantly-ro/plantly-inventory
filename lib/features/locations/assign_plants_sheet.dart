import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/mock_plants.dart';
import '../../data/providers.dart';
import '../../shared/plant_thumb.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';

/// Bottom sheet that reassigns plants into (or out of) a single location.
/// Lists every active plant with a toggle marking membership; toggling
/// immediately writes to the DB via `PlantRepository.setLocation`.
class AssignPlantsSheet extends ConsumerWidget {
  const AssignPlantsSheet({super.key, required this.location});
  final LocationRow location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final plantsAsync = ref.watch(plantsStreamProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: surface.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(PlantlyTokens.radius2xl)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        height: 4,
                        width: 40,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: surface.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      'Plants in "${location.name}"',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: surface.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Toggle to add or remove from this space.',
                      style: TextStyle(fontSize: 12, color: surface.muted),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: plantsAsync.when(
                  loading: () => Center(child: CircularProgressIndicator(color: surface.green)),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('$e', style: TextStyle(color: surface.terra)),
                  ),
                  data: (plants) {
                    if (plants.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No plants to assign yet.',
                            style: TextStyle(color: surface.muted),
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
                      itemCount: plants.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (_, i) {
                        final p = plants[i];
                        final assignedHere = p.locationId == location.id;
                        return _PlantAssignRow(
                          plant: p,
                          location: location,
                          assignedHere: assignedHere,
                          surface: surface,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlantAssignRow extends ConsumerWidget {
  const _PlantAssignRow({
    required this.plant,
    required this.location,
    required this.assignedHere,
    required this.surface,
  });

  final PlantRow plant;
  final LocationRow location;
  final bool assignedHere;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elsewhere = !assignedHere && plant.locationId != null;
    return Material(
      color: surface.surface,
      borderRadius: BorderRadius.circular(PlantlyTokens.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(PlantlyTokens.radius),
        onTap: () => _toggle(ref),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: surface.border),
            borderRadius: BorderRadius.circular(PlantlyTokens.radius),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plant.nickname,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text),
                    ),
                    Text(
                      assignedHere
                          ? 'In this space'
                          : elsewhere
                              ? 'In another space'
                              : 'No space',
                      style: TextStyle(fontSize: 11.5, color: surface.muted),
                    ),
                  ],
                ),
              ),
              Switch(
                value: assignedHere,
                activeThumbColor: surface.green,
                onChanged: (_) => _toggle(ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(WidgetRef ref) async {
    final repo = ref.read(plantRepositoryProvider);
    if (assignedHere) {
      await repo.setLocation(plant.id, null);
    } else {
      await repo.setLocation(plant.id, location.id);
    }
  }
}
