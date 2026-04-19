import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/care_types.dart';
import '../../../data/database/app_database.dart';
import '../../../data/mock_plants.dart';
import '../../../data/providers.dart';
import '../../../shared/plant_thumb.dart';
import '../../../theme/tokens.dart';
import '../../search/search_screen.dart';
import '../filter.dart';
import '../selection.dart';
import '../sort.dart';
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
  final void Function(String plantId)? onPlantTap;
  final bool editing;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(activeFilterProvider);
    final async = ref.watch(filteredPlantsProvider);
    final sort = ref.watch(plantSortProvider);
    final types = ref.watch(careTypesProvider);
    final locationsById = ref.watch(locationsStreamProvider).maybeWhen(
          data: (rows) => {for (final l in rows) l.id: l.name},
          orElse: () => const <String, String>{},
        );
    final allSchedules = ref.watch(allSchedulesProvider).maybeWhen(
          data: (rows) => rows,
          orElse: () => const <CareScheduleRow>[],
        );
    final earliestDue = <String, int>{};
    final nextTypeByPlant = <String, String>{};
    for (final s in allSchedules) {
      final due = s.nextDueAt;
      if (due == null) continue;
      final existing = earliestDue[s.plantId];
      if (existing == null || due < existing) {
        earliestDue[s.plantId] = due;
        nextTypeByPlant[s.plantId] = s.type;
      }
    }
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
      action: editing ? null : 'Search',
      onAction: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SearchScreen()),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _FilterChipsRow(active: filter, surface: surface, ref: ref)),
              _SortMenu(surface: surface, value: sort, onChanged: (s) => ref.read(plantSortProvider.notifier).set(s)),
            ],
          ),
          _LocationTagChipsRow(surface: surface),
          const SizedBox(height: 10),
          async.when(
            loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => _ErrorPlaceholder(message: '$e', surface: surface),
            data: (rows) {
              if (rows.isEmpty) return _EmptyPlaceholder(surface: surface, filter: filter);
              final sorted = sortPlants(
                plants: rows,
                sort: sort,
                earliestDueByPlantId: earliestDue,
                locationNameById: locationsById,
              );
              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.78,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: sorted.map((row) {
                  final swatch = MockPlants.byId(row.id);
                  final locName = row.locationId == null ? null : locationsById[row.locationId];
                  final nowMs = DateTime.now().millisecondsSinceEpoch;
                  final nextDueMs = earliestDue[row.id];
                  final overdue = nextDueMs != null && nextDueMs < nowMs;
                  final nextType = nextTypeByPlant[row.id];
                  final dueLabel = nextDueMs == null
                      ? null
                      : _DueLabel.forMs(nextDueMs - nowMs);
                  final selection = ref.watch(plantSelectionProvider);
                  final selected = selection.contains(row.id);
                  final inSelectionMode = selection.isNotEmpty;
                  return _Card(
                    plantId: row.id,
                    swatch: swatch,
                    label: row.nickname,
                    locationName: locName,
                    ok: !overdue,
                    dueLabel: dueLabel,
                    nextType: nextType,
                    types: types,
                    selected: selected,
                    selectionMode: inSelectionMode,
                    surface: surface,
                    onTap: inSelectionMode
                        ? () => ref.read(plantSelectionProvider.notifier).toggle(row.id)
                        : () => onPlantTap?.call(row.id),
                    onLongPress: () =>
                        ref.read(plantSelectionProvider.notifier).toggle(row.id),
                  );
                }).toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.plantId,
    required this.swatch,
    required this.label,
    required this.locationName,
    required this.ok,
    required this.dueLabel,
    required this.nextType,
    required this.types,
    required this.selected,
    required this.selectionMode,
    required this.surface,
    required this.onTap,
    required this.onLongPress,
  });

  final String plantId;
  final MockPlant swatch;
  final String label;
  final String? locationName;
  final bool ok;
  final String? dueLabel;
  final String? nextType;
  final List<CareType> types;
  final bool selected;
  final bool selectionMode;
  final PlantlySurface surface;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final accent = ok ? surface.green : surface.terra;
    final soft = ok ? surface.greenSoft : surface.terraSoft;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: surface.surface,
          border: Border.all(
            color: selected ? surface.green : surface.border,
            width: selected ? 2 : 1,
          ),
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
                      child: PlantPhotoThumb(
                        plantId: plantId,
                        fallback: swatch,
                        stubSize: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  if (selectionMode)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: selected ? surface.green : Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: selected
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : null,
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
                  if (dueLabel != null && nextType != null)
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              resolveCareType(types, nextType!).icon,
                              size: 10,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dueLabel!,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ],
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
                          locationName ?? 'No space',
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


class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.surface, required this.value, required this.onChanged});
  final PlantlySurface surface;
  final PlantSort value;
  final ValueChanged<PlantSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<PlantSort>(
      tooltip: 'Sort plants',
      icon: Icon(Icons.sort, size: 18, color: surface.muted),
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final s in PlantSort.values)
          PopupMenuItem(
            value: s,
            child: Row(
              children: [
                Icon(s == value ? Icons.check : Icons.radio_button_unchecked,
                    size: 14, color: s == value ? surface.green : surface.muted),
                const SizedBox(width: 8),
                Text(s.label),
              ],
            ),
          ),
      ],
    );
  }
}

/// Stand-alone short-form due-time formatter. Kept out of the `Card`
/// widget so it's cheap to compute per item in the grid loop.
class _DueLabel {
  static String forMs(int diffMs) {
    if (diffMs < 0) {
      final late = (-diffMs / (86400 * 1000)).floor();
      if (late >= 1) return '$late d late';
      final h = (-diffMs / (3600 * 1000)).floor();
      if (h >= 1) return '$h h late';
      return 'now';
    }
    final days = (diffMs / (86400 * 1000)).round();
    if (days == 0) {
      final h = (diffMs / (3600 * 1000)).round();
      if (h < 1) return '< 1h';
      return 'in $h h';
    }
    if (days == 1) return 'tomorrow';
    return 'in $days d';
  }
}

class _LocationTagChipsRow extends ConsumerWidget {
  const _LocationTagChipsRow({required this.surface});
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = ref.watch(locationsStreamProvider).maybeWhen(
          data: (rows) => rows,
          orElse: () => const <LocationRow>[],
        );
    final tags = ref.watch(allTagsProvider).maybeWhen(
          data: (rows) => rows,
          orElse: () => const <TagRow>[],
        );
    final locId = ref.watch(activeLocationFilterProvider);
    final tagId = ref.watch(activeTagFilterProvider);
    if (locations.isEmpty && tags.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final l in locations)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _SecondaryChip(
                  label: l.name,
                  icon: Icons.place_outlined,
                  selected: locId == l.id,
                  surface: surface,
                  onTap: () => ref.read(activeLocationFilterProvider.notifier).state =
                      locId == l.id ? null : l.id,
                ),
              ),
            for (final t in tags)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _SecondaryChip(
                  label: '#${t.name}',
                  icon: Icons.label_outline,
                  selected: tagId == t.id,
                  surface: surface,
                  onTap: () => ref.read(activeTagFilterProvider.notifier).state =
                      tagId == t.id ? null : t.id,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryChip extends StatelessWidget {
  const _SecondaryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.surface,
    required this.onTap,
  });
  final String label;
  final IconData icon;
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? surface.green : surface.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: selected ? Colors.white : surface.muted),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : surface.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
