import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/mock_plants.dart';
import '../../../shared/plant_thumb.dart';
import '../../../theme/tokens.dart';
import '../filter.dart';
import 'widget_shell.dart';

/// DB-backed plant grid. Streams `plants.watchAll()` from the repository
/// and renders each row as a tappable card. Status colour (ok / terra) is
/// still driven by a small `_okFor` lookup until care_schedules feeds it.
class GridWidget extends ConsumerWidget {
  const GridWidget({
    super.key,
    required this.surface,
    this.onPlantTap,
    this.editing = false,
    this.onMoveUp,
    this.onMoveDown,
    this.onRemove,
  });

  final PlantlySurface surface;
  final void Function(MockPlant)? onPlantTap;
  final bool editing;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onRemove;

  // Two plant ids that are still "overdue" until the schedule engine takes
  // over — keeps the existing visual state so the prototype match holds.
  static const _overdueIds = {'bob', 'green'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(activeFilterProvider);
    final async = ref.watch(filteredPlantsProvider);
    return WidgetShell(
      surface: surface,
      editing: editing,
      onMoveUp: onMoveUp,
      onMoveDown: onMoveDown,
      onRemove: onRemove,
      title: 'All plants',
      accentLabel: async.maybeWhen(
        data: (rows) => '${rows.length}',
        orElse: () => null,
      ),
      accentColor: surface.muted,
      action: 'See all',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FilterChipsRow(active: filter, surface: surface, ref: ref),
          const SizedBox(height: 10),
          async.when(
            loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => _ErrorPlaceholder(message: '$e', surface: surface),
            data: (rows) => rows.isEmpty
                ? _EmptyPlaceholder(surface: surface, filter: filter)
                : GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 0.78,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    children: rows.map((row) {
                      final mock = MockPlants.byId(row.id);
                      return _Card(
                        plant: mock,
                        label: row.nickname,
                        ok: !_overdueIds.contains(row.id),
                        surface: surface,
                        onTap: () => onPlantTap?.call(mock),
                      );
                    }).toList(growable: false),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.plant,
    required this.label,
    required this.ok,
    required this.surface,
    required this.onTap,
  });

  final MockPlant plant;
  final String label;
  final bool ok;
  final PlantlySurface surface;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = ok ? surface.green : surface.terra;
    final soft = ok ? surface.greenSoft : surface.terraSoft;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
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
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      color: surface.surfaceAlt,
                      child: PlantThumb(plant: plant, size: 160),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: soft,
                        shape: BoxShape.circle,
                        border: Border.all(color: accent, width: 1.5),
                      ),
                      child: Center(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: surface.text,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.place_outlined, size: 9, color: surface.muted),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          plant.location.split(' ›').first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: surface.muted),
                        ),
                      ),
                    ],
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

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder({required this.surface, this.filter = PlantFilter.all});
  final PlantlySurface surface;
  final PlantFilter filter;

  @override
  Widget build(BuildContext context) {
    final message = switch (filter) {
      PlantFilter.all => 'No plants yet — tap the + button to add one.',
      PlantFilter.overdue => 'Nothing overdue — nice.',
      PlantFilter.dueToday => 'Nothing due today — all caught up.',
    };
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
      ),
      alignment: Alignment.center,
      child: Text(
        message,
        style: TextStyle(fontSize: 12, color: surface.muted),
      ),
    );
  }
}

class _FilterChipsRow extends StatelessWidget {
  const _FilterChipsRow({required this.active, required this.surface, required this.ref});
  final PlantFilter active;
  final PlantlySurface surface;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final f in PlantFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _Chip(
                label: f.label,
                selected: f == active,
                surface: surface,
                onTap: () => ref.read(activeFilterProvider.notifier).state = f,
              ),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.surface,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final PlantlySurface surface;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? surface.green : surface.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? surface.green : surface.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : surface.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorPlaceholder extends StatelessWidget {
  const _ErrorPlaceholder({required this.message, required this.surface});
  final String message;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface.surfaceAlt,
        border: Border.all(color: surface.terra),
        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
      ),
      child: Text(
        'Could not load plants.\n$message',
        style: TextStyle(fontSize: 12, color: surface.terra),
      ),
    );
  }
}

