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
import '../../../shared/relative_days.dart';
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
    this.padInner = true,
    this.onMoveUp,
    this.onMoveDown,
    this.onRemove,
  });

  final PlantlySurface surface;
  /// Navigates to the detail screen. Receives the real `plants.id`.
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
      padInner: padInner,
      onMoveUp: onMoveUp,
      onMoveDown: onMoveDown,
      onRemove: onRemove,
      title: t.homeWidgetOverdue,
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
                t.nothingOverdue,
                style: TextStyle(fontSize: 12, color: surface.muted),
              ),
            );
          }
          return PlantRowGroup(
            surface: surface,
            rows: [
              for (var i = 0; i < overdue.length; i++)
                _overdueRow(t, overdue[i], plantsById, now, i == overdue.length - 1),
            ],
          );
        },
      ),
    );
  }

  Widget _overdueRow(
    AppLocalizations t,
    db.CareScheduleRow schedule,
    Map<String, db.PlantRow> plantsById,
    DateTime now,
    bool last,
  ) {
    final plant = plantsById[schedule.plantId];
    final title = plant?.nickname ?? schedule.plantId;
    final swatch = MockPlants.byId(schedule.plantId);
    // Calendar days, like every other relative date (shared/relative_days.dart);
    // under a day late reads "<action> now".
    final lateMs = now.millisecondsSinceEpoch - schedule.nextDueAt!;
    final daysLate = lateMs < Duration.millisecondsPerDay ? 0 : calendarDaysUntilMs(schedule.nextDueAt!, now).abs();
    return Consumer(
      builder: (context, ref, _) {
        final ct = resolveCareType(ref.watch(careTypesProvider), schedule.type);
        final verb = careTypeVerb(t, ct);
        final subtitle = daysLate > 0 ? t.homeOverdueLate(daysLate, verb) : t.homeDueNow(verb);
        Future<void> logDone() async {
          await ref.read(careEventRepositoryProvider).record(
                plantId: schedule.plantId,
                type: schedule.type,
              );
          if (!context.mounted) return;
          await showCareFeedback(context, type: ct, plantName: title, surface: surface);
          onLogCare?.call(t.homeToastLoggedCare(title));
        }
        return SwipeRow(
          key: ValueKey('overdue-${schedule.id}'),
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
            subtitle: subtitle,
            subtitleIcon: ct.icon,
            subtitleColor: surface.terra,
            first: false,
            last: last,
            onTap: () => onPlantTap?.call(schedule.plantId),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AssigneeChip(userId: schedule.assigneeUserId, tenantId: schedule.tenantId, surface: surface, padLeft: 0),
                if (schedule.assigneeUserId != null && ref.watch(canEditActiveCollectionProvider)) const SizedBox(width: 8),
                if (ref.watch(canEditActiveCollectionProvider))
                  _DoneButton(
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
        // Theme default tap target: 48 dp hit area on touch platforms.
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PlantlyTokens.radiusMd),
        ),
      ),
      onPressed: onPressed,
      child: Text(AppLocalizations.of(context).doneBtn),
    );
  }
}
