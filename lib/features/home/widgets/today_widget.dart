import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../cloud/collections.dart';
import '../../../data/database/app_database.dart' as db;
import '../../../data/mock_plants.dart';
import '../../../data/providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/tokens.dart';
import '../../../data/care_types.dart';
import '../../../shared/care_feedback.dart';
import '../../../shared/assignee_initial.dart';
import '../../../shared/care_type_labels.dart';
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
    this.padInner = true,
    this.onMoveUp,
    this.onMoveDown,
    this.onRemove,
  });

  final PlantlySurface surface;
  final void Function(String plantId)? onPlantTap;
  /// Called after a care event is recorded, with a localized toast message.
  final void Function(String message)? onLogCare;
  final bool editing;
  final bool padInner;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
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
      padInner: padInner,
      onMoveUp: onMoveUp,
      onMoveDown: onMoveDown,
      onRemove: onRemove,
      title: t.homeWidgetToday,
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
                t.allCaughtUp,
                style: TextStyle(fontSize: 12, color: surface.muted),
              ),
            );
          }
          return PlantRowGroup(
            surface: surface,
            rows: [
              for (var i = 0; i < today.length; i++)
                _todayRow(t, today[i], plantsById, i == today.length - 1),
            ],
          );
        },
      ),
    );
  }

  Widget _todayRow(
    AppLocalizations t,
    db.CareScheduleRow schedule,
    Map<String, db.PlantRow> plantsById,
    bool last,
  ) {
    final plant = plantsById[schedule.plantId];
    final title = plant?.nickname ?? schedule.plantId;
    final swatch = MockPlants.byId(schedule.plantId);
    return Consumer(
      builder: (context, ref, _) {
        final ct = resolveCareType(ref.watch(careTypesProvider), schedule.type);
        final action = careTypeVerb(t, ct);
        Future<void> logDone() async {
          await ref.read(careEventRepositoryProvider).record(
                plantId: schedule.plantId,
                type: schedule.type,
              );
          if (!context.mounted) return;
          await showCareFeedback(context, type: ct, plantName: title, surface: surface);
          onLogCare?.call(t.homeToastActionLogged(action, title));
        }
        return SwipeRow(
          key: ValueKey('today-${schedule.id}'),
          surface: surface,
          onDone: logDone,
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
            subtitleIcon: ct.icon,
            subtitleColor: surface.muted,
            first: false,
            last: last,
            onTap: () => onPlantTap?.call(schedule.plantId),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AssigneeChip(userId: schedule.assigneeUserId, tenantId: schedule.tenantId, surface: surface, padLeft: 0),
                if (schedule.assigneeUserId != null && ref.watch(canEditActiveCollectionProvider)) const SizedBox(width: 8),
                if (ref.watch(canEditActiveCollectionProvider))
                  _CheckButton(
                    surface: surface,
                    onPressed: logDone,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CheckButton extends StatelessWidget {
  const _CheckButton({required this.surface, required this.onPressed});
  final PlantlySurface surface;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // 32 px square; labelled, and padded to a 48 dp hit area on touch
    // platforms by the theme's tap-target size.
    return IconButton(
      tooltip: AppLocalizations.of(context).doneBtn,
      onPressed: onPressed,
      icon: Icon(Icons.check, size: 16, color: surface.green),
      style: IconButton.styleFrom(
        backgroundColor: surface.greenSoft,
        fixedSize: const Size.square(32),
        minimumSize: const Size.square(32),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radius)),
      ),
    );
  }
}
