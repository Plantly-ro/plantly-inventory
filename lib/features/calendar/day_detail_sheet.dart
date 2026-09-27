import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/care_types.dart';
import '../../data/database/app_database.dart' as db;
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/care_type_labels.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';
import '../../app/breakpoints.dart';
import '../../app/navigation.dart';
import '../../shared/sheet_chrome.dart';

/// Bottom sheet that zooms into a single calendar day. Lists every
/// schedule due on the date plus every care event already recorded on
/// it. Each row has Done / Snooze actions — completing any scheduled
/// reminder records the event and the stream updates.
class DayDetailSheet extends ConsumerWidget {
  const DayDetailSheet({super.key, required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final types = ref.watch(careTypesProvider);
    final schedules = ref.watch(allSchedulesProvider).maybeWhen(
          data: (rows) => rows,
          orElse: () => const <db.CareScheduleRow>[],
        );
    final events = ref.watch(recentCareEventsProvider).maybeWhen(
          data: (rows) => rows,
          orElse: () => const <db.CareEventRow>[],
        );
    final plantsById = ref.watch(plantsStreamProvider).maybeWhen(
          data: (rows) => {for (final p in rows) p.id: p},
          orElse: () => const <String, db.PlantRow>{},
        );
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final dayScheduled = [
      for (final s in schedules)
        if (s.nextDueAt != null) ...[
          if (() {
            final due = DateTime.fromMillisecondsSinceEpoch(s.nextDueAt!, isUtc: true).toLocal();
            return !due.isBefore(startOfDay) && due.isBefore(endOfDay);
          }())
            s,
        ],
    ];
    final dayDone = [
      for (final e in events) ...[
        if (() {
          final at = DateTime.fromMillisecondsSinceEpoch(e.doneAt, isUtc: true).toLocal();
          return !at.isBefore(startOfDay) && at.isBefore(endOfDay);
        }())
          e,
      ],
    ];
    final today = DateTime.now();
    final isToday = startOfDay == DateTime(today.year, today.month, today.day);
    final t = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();

    // Desktop: rendered inside a right-side panel (see `showAdaptiveSheet`)
    // — full height, no drag handle, no draggable sizing.
    final panel = context.isDesktop;
    final weekday = DateFormat.EEEE(locale).format(day).toUpperCase();
    // Phone: today's frame (10 px, handle, 10 px, title row with its own
    // close). Desktop: SheetChrome's header carries the date + `×`, so the
    // title row is dropped and the body gets the 20 px side padding the
    // list used to bring itself.
    Widget content(BuildContext context, ScrollController? scrollCtrl) => SheetChrome(
        surface: surface,
        title: DateFormat.yMMMMd(locale).format(day),
        subtitle: isToday ? '$weekday · ${t.commonTodayLabel}' : weekday,
        padding: panel ? const EdgeInsets.fromLTRB(20, 0, 20, 0) : const EdgeInsets.only(top: 10),
        handleGap: 10,
        crossAxisAlignment: CrossAxisAlignment.center,
        expand: true,
        children: [
            if (!panel)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        weekday,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isToday ? surface.green : surface.muted,
                          letterSpacing: 0.1 * 11,
                        ),
                      ),
                      Text(
                        DateFormat.yMMMMd(locale).format(day),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: surface.text),
                      ),
                      if (isToday)
                        Text(t.commonTodayLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: surface.green)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.close, color: surface.muted),
                  ),
                ],
              ),
            ),
            if (!panel) const SizedBox(height: 4),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                primary: scrollCtrl == null ? false : null,
                padding: EdgeInsets.fromLTRB(panel ? 0 : 20, 0, panel ? 0 : 20, 24),
                children: [
                  if (dayScheduled.isEmpty && dayDone.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          t.calendarDayEmpty,
                          style: TextStyle(color: surface.muted, fontSize: 13),
                        ),
                      ),
                    ),
                  if (dayScheduled.isNotEmpty) ...[
                    Text(t.calendarDayScheduled,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: surface.green, letterSpacing: 0.1 * 11)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: surface.surface,
                        border: Border.all(color: surface.border),
                        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (var i = 0; i < dayScheduled.length; i++)
                            _ScheduledRow(
                              schedule: dayScheduled[i],
                              plant: plantsById[dayScheduled[i].plantId],
                              types: types,
                              surface: surface,
                              last: i == dayScheduled.length - 1,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (dayDone.isNotEmpty) ...[
                    Text(t.calendarDayDone,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: surface.green, letterSpacing: 0.1 * 11)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: surface.surface,
                        border: Border.all(color: surface.border),
                        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (var i = 0; i < dayDone.length; i++)
                            _DoneRow(
                              event: dayDone[i],
                              plant: plantsById[dayDone[i].plantId],
                              types: types,
                              surface: surface,
                              last: i == dayDone.length - 1,
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
      );

    if (panel) return content(context, null);
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: content,
    );
  }
}

class _ScheduledRow extends ConsumerWidget {
  const _ScheduledRow({
    required this.schedule,
    required this.plant,
    required this.types,
    required this.surface,
    required this.last,
  });
  final db.CareScheduleRow schedule;
  final db.PlantRow? plant;
  final List<CareType> types;
  final PlantlySurface surface;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ct = resolveCareType(types, schedule.type);
    final nickname = plant?.nickname ?? schedule.plantId;
    final when = DateTime.fromMillisecondsSinceEpoch(schedule.nextDueAt!, isUtc: true).toLocal();
    final time = '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
    return Container(
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: surface.border)),
      ),
      child: InkWell(
        onTap: () {
          // Close the sheet, then open the plant (desktop: select in place).
          final opener = preparePlantOpener(context);
          Navigator.of(context).pop();
          opener.open(schedule.plantId);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: ct.color ?? surface.greenSoft,
                  borderRadius: BorderRadius.circular(PlantlyTokens.radius),
                ),
                child: Icon(
                  ct.icon,
                  size: 16,
                  color: ct.color == null ? surface.green : Colors.white,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nickname, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text)),
                    Text('${careTypeLabel(AppLocalizations.of(context), ct)} · $time', style: TextStyle(fontSize: 11.5, color: surface.muted)),
                  ],
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: surface.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radiusMd)),
                ),
                onPressed: () async {
                  await ref.read(careEventRepositoryProvider).record(
                        plantId: schedule.plantId,
                        type: schedule.type,
                      );
                },
                child: Text(AppLocalizations.of(context).doneBtn),
              ),
              const SizedBox(width: 6),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: surface.surfaceAlt,
                  foregroundColor: surface.muted,
                  side: BorderSide(color: surface.border),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radiusMd)),
                ),
                onPressed: () => ref
                    .read(careScheduleRepositoryProvider)
                    .snooze(schedule.id, by: const Duration(days: 1)),
                child: Text(AppLocalizations.of(context).snoozeBtn),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoneRow extends StatelessWidget {
  const _DoneRow({
    required this.event,
    required this.plant,
    required this.types,
    required this.surface,
    required this.last,
  });
  final db.CareEventRow event;
  final db.PlantRow? plant;
  final List<CareType> types;
  final PlantlySurface surface;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final ct = resolveCareType(types, event.type);
    final nickname = plant?.nickname ?? event.plantId;
    final when = DateTime.fromMillisecondsSinceEpoch(event.doneAt, isUtc: true).toLocal();
    final time = '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: () {
        final opener = preparePlantOpener(context);
        Navigator.of(context).pop();
        opener.open(event.plantId);
      },
      child: Container(
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: surface.border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: surface.greenSoft, shape: BoxShape.circle),
              child: Icon(Icons.check_circle_outline, size: 18, color: surface.green),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nickname, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text)),
                  Text(
                    '${careTypePastLabel(AppLocalizations.of(context), ct)} · $time${event.product != null && event.product!.isNotEmpty ? ' · ${event.product}' : ''}',
                    style: TextStyle(fontSize: 11.5, color: surface.muted),
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
