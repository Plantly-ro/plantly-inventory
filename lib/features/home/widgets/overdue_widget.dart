import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart' as db;
import '../../../data/mock_plants.dart';
import '../../../data/providers.dart';
import '../../../theme/tokens.dart';
import 'plant_row.dart';
import 'swipe_row.dart';
import 'widget_shell.dart';

class OverdueWidget extends ConsumerWidget {
  const OverdueWidget({
    super.key,
    required this.surface,
    this.onPlantTap,
    this.onLogCare,
    this.editing = false,
    this.onMoveUp,
    this.onMoveDown,
    this.onRemove,
  });

  final PlantlySurface surface;
  /// Navigates to the detail screen. Receives the real `plants.id`.
  final void Function(String plantId)? onPlantTap;
  /// Called after a care event is recorded, with the plant's display name.
  final void Function(String name)? onLogCare;
  final bool editing;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dueBeforeEodProvider);
    final plantRows = ref.watch(plantsStreamProvider).maybeWhen(
          data: (r) => r,
          orElse: () => const <db.PlantRow>[],
        );
    final plantsById = {for (final p in plantRows) p.id: p};

    final now = DateTime.now();
    final overdue = async.maybeWhen(
      data: (rows) => rows
          .where((s) =>
              s.nextDueAt != null &&
              s.nextDueAt! < now.millisecondsSinceEpoch &&
              // Drop schedules whose plant got soft-deleted (gift / sale /
              // death) — the plant is gone from plantsById so the row
              // would render as a bare ULID and tap through to "plant no
              // longer in your collection".
              plantsById.containsKey(s.plantId))
          .toList(),
      orElse: () => const <db.CareScheduleRow>[],
    );

    return WidgetShell(
      surface: surface,
      editing: editing,
      onMoveUp: onMoveUp,
      onMoveDown: onMoveDown,
      onRemove: onRemove,
      title: 'Overdue',
      accentLabel: '${overdue.length}',
      accentColor: surface.terra,
      child: async.when(
        loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text('$e', style: TextStyle(color: surface.terra)),
        data: (_) {
          if (overdue.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surface.surface,
                border: Border.all(color: surface.border),
                borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
              ),
              alignment: Alignment.center,
              child: Text(
                'Nothing overdue — nice.',
                style: TextStyle(fontSize: 12, color: surface.muted),
              ),
            );
          }
          return PlantRowGroup(
            surface: surface,
            rows: [
              for (var i = 0; i < overdue.length; i++)
                _overdueRow(overdue[i], plantsById, now, i == overdue.length - 1),
            ],
          );
        },
      ),
    );
  }

  Widget _overdueRow(
    db.CareScheduleRow schedule,
    Map<String, db.PlantRow> plantsById,
    DateTime now,
    bool last,
  ) {
    final plant = plantsById[schedule.plantId];
    final title = plant?.nickname ?? schedule.plantId;
    final swatch = MockPlants.byId(schedule.plantId);
    final daysLate = ((now.millisecondsSinceEpoch - schedule.nextDueAt!) / (86400 * 1000)).floor();
    final subtitle = daysLate > 0 ? '$daysLate d late · ${_verb(schedule.type)}' : '${_verb(schedule.type)} now';
    return Consumer(
      builder: (context, ref, _) {
        return SwipeRow(
          key: ValueKey('overdue-${schedule.id}'),
          surface: surface,
          onDone: () async {
            await ref.read(careEventRepositoryProvider).record(
                  plantId: schedule.plantId,
                  type: schedule.type,
                );
            if (context.mounted) onLogCare?.call(title);
          },
          onSnooze: () async {
            await ref
                .read(careScheduleRepositoryProvider)
                .snooze(schedule.id, by: const Duration(days: 1));
          },
          child: PlantRow(
            plantId: schedule.plantId,
            title: title,
            swatch: swatch,
            surface: surface,
            subtitle: subtitle,
            subtitleIcon: _iconFor(schedule.type),
            subtitleColor: surface.terra,
            first: false,
            last: last,
            onTap: () => onPlantTap?.call(schedule.plantId),
            trailing: _DoneButton(
              surface: surface,
              onPressed: () async {
                await ref.read(careEventRepositoryProvider).record(
                      plantId: schedule.plantId,
                      type: schedule.type,
                    );
                if (context.mounted) onLogCare?.call(title);
              },
            ),
          ),
        );
      },
    );
  }

  String _verb(String type) {
    switch (type) {
      case 'water':
        return 'Water';
      case 'fertilize':
        return 'Fertilize';
      case 'mist':
        return 'Mist';
      case 'repot':
        return 'Repot';
      case 'prune':
        return 'Prune';
      case 'rotate':
        return 'Rotate';
      default:
        return type;
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'fertilize':
        return Icons.eco_outlined;
      case 'rotate':
        return Icons.light_mode_outlined;
      default:
        return Icons.water_drop_outlined;
    }
  }
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.surface, required this.onPressed});
  final PlantlySurface surface;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        backgroundColor: surface.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PlantlyTokens.radiusMd),
        ),
      ),
      onPressed: onPressed,
      child: const Text('Done'),
    );
  }
}
