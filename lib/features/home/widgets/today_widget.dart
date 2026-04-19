import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart' as db;
import '../../../data/mock_plants.dart';
import '../../../data/providers.dart';
import '../../../theme/tokens.dart';
import 'plant_row.dart';
import 'swipe_row.dart';
import 'widget_shell.dart';

class TodayWidget extends ConsumerWidget {
  const TodayWidget({
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
  final void Function(String plantId)? onPlantTap;
  final void Function(String name, String action)? onLogCare;
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

    final now = DateTime.now().millisecondsSinceEpoch;
    final today = async.maybeWhen(
      data: (rows) => rows
          .where((s) =>
              s.nextDueAt != null &&
              s.nextDueAt! >= now &&
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
      title: 'Due today',
      accentLabel: '${today.length}',
      accentColor: surface.green,
      child: async.when(
        loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text('$e', style: TextStyle(color: surface.terra)),
        data: (_) {
          if (today.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surface.surface,
                border: Border.all(color: surface.border),
                borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
              ),
              alignment: Alignment.center,
              child: Text(
                'All caught up for today.',
                style: TextStyle(fontSize: 12, color: surface.muted),
              ),
            );
          }
          return PlantRowGroup(
            surface: surface,
            rows: [
              for (var i = 0; i < today.length; i++)
                _todayRow(today[i], plantsById, i == today.length - 1),
            ],
          );
        },
      ),
    );
  }

  Widget _todayRow(
    db.CareScheduleRow schedule,
    Map<String, db.PlantRow> plantsById,
    bool last,
  ) {
    final plant = plantsById[schedule.plantId];
    final title = plant?.nickname ?? schedule.plantId;
    final swatch = MockPlants.byId(schedule.plantId);
    final action = _verb(schedule.type);
    return Consumer(
      builder: (context, ref, _) {
        return SwipeRow(
          key: ValueKey('today-${schedule.id}'),
          surface: surface,
          onDone: () async {
            await ref.read(careEventRepositoryProvider).record(
                  plantId: schedule.plantId,
                  type: schedule.type,
                );
            if (context.mounted) onLogCare?.call(title, action);
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
            subtitle: action,
            subtitleIcon: _iconFor(schedule.type),
            subtitleColor: surface.muted,
            first: false,
            last: last,
            onTap: () => onPlantTap?.call(schedule.plantId),
            trailing: _CheckButton(
              surface: surface,
              onPressed: () async {
                await ref.read(careEventRepositoryProvider).record(
                      plantId: schedule.plantId,
                      type: schedule.type,
                    );
                if (context.mounted) onLogCare?.call(title, action);
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

class _CheckButton extends StatelessWidget {
  const _CheckButton({required this.surface, required this.onPressed});
  final PlantlySurface surface;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface.greenSoft,
      borderRadius: BorderRadius.circular(PlantlyTokens.radius),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(PlantlyTokens.radius),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(Icons.check, size: 16, color: surface.green),
        ),
      ),
    );
  }
}
