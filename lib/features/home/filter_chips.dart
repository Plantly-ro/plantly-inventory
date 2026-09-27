import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/tokens.dart';
import 'filter.dart';

/// Status chips (All · Overdue · Due today) bound to [activeFilterProvider].
/// Lives inside the grid widget on phone/tablet and in the dashboard
/// toolbar on desktop.
class FilterChipsRow extends ConsumerWidget {
  const FilterChipsRow({super.key, required this.surface});
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeFilterProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final f in PlantFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: PlantFilterChip(
                label: f.label(context),
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

class PlantFilterChip extends StatelessWidget {
  const PlantFilterChip({
    super.key,
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
