import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/clock.dart';
import '../../data/care_types.dart';
import '../../data/database/app_database.dart' as db;
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/care_type_labels.dart';
import '../../shared/assignee_initial.dart';
import '../../shared/relative_days.dart';
import '../../theme/tokens.dart';
import '../collections/read_only_banner.dart';
import '../home/home_providers.dart';
import 'day_detail_sheet.dart';
import '../../app/side_sheet.dart';
import '../../app/navigation.dart';

void showDayDetail(BuildContext context, DateTime day) {
  showAdaptiveSheet(
    context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DayDetailSheet(day: day),
  );
}

enum CalendarView { week, month, year }

String _localeOf(BuildContext context) =>
    Localizations.localeOf(context).toString();

/// First day of the week as a `DateTime.weekday` value (Monday = 1 … Sunday
/// = 7), taken from the Material locale so an en_US device gets a
/// Sunday-first grid while ro_RO stays Monday-first.
int _firstWeekdayOf(BuildContext context) {
  final index = MaterialLocalizations.of(
    context,
  ).firstDayOfWeekIndex; // 0 = Sunday
  return index == 0 ? DateTime.sunday : index;
}

/// Midnight of the first day of the week containing [d]. Calendar
/// arithmetic (`DateTime(y, m, d - n)`): subtracting a `Duration` across a
/// spring-forward lands at 23:00 of the previous date.
DateTime weekStartOf(DateTime d, int firstWeekday) {
  return addCalendarDays(d, -((d.weekday - firstWeekday + 7) % 7));
}

/// First and last day (local midnights) of the week containing [d] — the
/// week view's title range. The last day is the 7th calendar day, also in a
/// DST week (`start + Duration(days: 6)` read "Oct 25–30").
(DateTime start, DateTime end) weekRangeOf(DateTime d, int firstWeekday) {
  final start = weekStartOf(d, firstWeekday);
  return (start, addCalendarDays(start, 6));
}

/// The calendar anchor moved by one [v] period in [direction] (±1).
DateTime stepCalendarAnchor(DateTime d, CalendarView v, int direction) {
  switch (v) {
    case CalendarView.week:
      return addCalendarDays(d, 7 * direction);
    case CalendarView.month:
      // DateTime normalises month 0 / 13 into the neighbouring year.
      return DateTime(d.year, d.month + direction, 1);
    case CalendarView.year:
      return DateTime(d.year + direction, d.month, 1);
  }
}

/// Relative "when" copy for a reminder due at [due], seen at [now]:
/// ("24 min overdue", urgent) / ("restant de 24 de minute", urgent). Under
/// an hour / within today it counts minutes / hours; beyond that CALENDAR
/// days (`calendarDaysBetween`) — the same count Plant detail and Home
/// show, so Oct 12 is "in 5 days" on Oct 7 at any time of day. Plural
/// forms (one/few/other) come from the ARB so Romanian gets "2 zile" vs
/// "20 de zile" right. Exposed for unit tests.
(String label, bool urgent) upcomingDueLabel(AppLocalizations t, DateTime now, DateTime due) {
  final d = due.difference(now);
  if (d.isNegative) {
    final hrs = -d.inHours;
    final mins = -d.inMinutes;
    if (hrs >= 24) return (t.detailOverdueDays(calendarDaysBetween(due, now)), true);
    if (hrs > 0) return (t.calOverdueHours(hrs), true);
    return (t.calOverdueMinutes(mins > 0 ? mins : 1), true);
  }
  if (d.inMinutes < 60) return (t.calInMinutes(d.inMinutes), d.inMinutes < 30);
  final days = calendarDaysBetween(now, due);
  if (days == 0) return (t.calInHours(d.inHours), false);
  if (days == 1) return (t.detailDueTomorrow, false);
  return (t.detailDueInDays(days), false);
}

/// "Sep 21–27" / "21–27 sept." when the week sits in one month, otherwise
/// "Sep 28 – Oct 4" / "28 sept. – 4 oct.". Whether the day precedes the month
/// is read off the locale's own MMMd pattern instead of being hard-coded.
String weekRangeLabel(String locale, DateTime from, DateTime to) {
  final fmt = DateFormat.MMMd(locale);
  if (from.month == to.month) {
    final month = DateFormat.MMM(locale).format(from);
    final pattern = fmt.pattern ?? '';
    if (pattern.startsWith('d')) return '${from.day}–${to.day} $month';
    if (pattern.startsWith('M')) return '$month ${from.day}–${to.day}';
  }
  return '${fmt.format(from)} – ${fmt.format(to)}';
}

/// Calendar with Week / Month / Year toggles, plus an "Upcoming" shortcut
/// list pinned at the top so users always see their next reminders even
/// when the current visible period is empty.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  CalendarView _view = CalendarView.week;
  late DateTime _anchor;

  @override
  void initState() {
    super.initState();
    _anchor = ref.read(clockProvider)();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark
        ? PlantlySurface.dark
        : PlantlySurface.light;
    final t = AppLocalizations.of(context);

    final schedulesAsync = ref.watch(allSchedulesProvider);
    final eventsAsync = ref.watch(recentCareEventsProvider);
    final plantsAsync = ref.watch(plantsStreamProvider);
    final types = ref.watch(careTypesProvider);
    // Only filter out schedules whose plant is missing once the plants
    // stream has actually produced data — otherwise a slow first load
    // hides everything until the DB finishes opening.
    final plantsById = plantsAsync.maybeWhen(
      data: (rows) => {for (final p in rows) p.id: p},
      orElse: () => const <String, db.PlantRow>{},
    );
    final plantsLoaded = plantsAsync.hasValue;

    final schedules = schedulesAsync.maybeWhen(
      data: (r) => r,
      orElse: () => const <db.CareScheduleRow>[],
    );
    final events = eventsAsync.maybeWhen(
      data: (r) => r,
      orElse: () => const <db.CareEventRow>[],
    );

    // "Upcoming" list — next 10 schedules globally, regardless of view.
    final now = ref.watch(clockProvider)();
    final nowMs = now.millisecondsSinceEpoch;
    final upcoming = [
      for (final s in schedules)
        if (s.nextDueAt != null &&
            (!plantsLoaded || plantsById.containsKey(s.plantId)))
          s,
    ]..sort((a, b) => (a.nextDueAt ?? 0).compareTo(b.nextDueAt ?? 0));
    final upcomingNext10 = upcoming.take(10).toList();
    final firstOverdueOrToday = upcoming
        .where((s) => s.nextDueAt! <= nowMs + 86400000)
        .length;

    return Scaffold(
      backgroundColor: surface.bg,
      appBar: AppBar(
        backgroundColor: surface.bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: adaptiveBackButton(context, surface),
        title: Text(
          _titleFor(context, _view, _anchor),
          style: TextStyle(
            fontFamily: PlantlyFonts.plusJakartaSans,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: surface.text,
            letterSpacing: -0.02 * 20,
          ),
        ),
        actions: [
          IconButton(
            tooltip: t.calPrevious,
            onPressed: () =>
                setState(() => _anchor = stepCalendarAnchor(_anchor, _view, -1)),
            icon: Icon(Icons.arrow_back_ios_new, size: 18, color: surface.text),
          ),
          IconButton(
            tooltip: t.calendarToday,
            onPressed: () =>
                setState(() => _anchor = ref.read(clockProvider)()),
            icon: Icon(Icons.today_outlined, color: surface.text),
          ),
          IconButton(
            tooltip: t.calendarNext,
            onPressed: () => setState(() => _anchor = stepCalendarAnchor(_anchor, _view, 1)),
            icon: Icon(Icons.arrow_forward_ios, size: 18, color: surface.text),
          ),
        ],
      ),
      body: Column(
        children: [
          const ReadOnlyBanner(),
          // View toggle row.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: SegmentedButton<CalendarView>(
              segments: [
                ButtonSegment(
                  value: CalendarView.week,
                  label: Text(t.calendarWeek),
                ),
                ButtonSegment(
                  value: CalendarView.month,
                  label: Text(t.calendarMonth),
                ),
                ButtonSegment(
                  value: CalendarView.year,
                  label: Text(t.calendarYear),
                ),
              ],
              selected: {_view},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _view = s.first),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                if (upcomingNext10.isNotEmpty) ...[
                  _sectionLabel(
                    '${t.calendarUpcoming}${firstOverdueOrToday > 0 ? '  ·  $firstOverdueOrToday' : ''}',
                    surface,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: surface.surface,
                      border: Border.all(color: surface.border),
                      borderRadius: BorderRadius.circular(
                        PlantlyTokens.radiusXl,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var i = 0; i < upcomingNext10.length; i++)
                          _UpcomingScheduleRow(
                            now: now,
                            schedule: upcomingNext10[i],
                            plantName:
                                plantsById[upcomingNext10[i].plantId]
                                    ?.nickname ??
                                upcomingNext10[i].plantId,
                            surface: surface,
                            types: types,
                            last: i == upcomingNext10.length - 1,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                if (_view == CalendarView.week)
                  _WeekView(
                    now: now,
                    anchor: _anchor,
                    schedules: schedules,
                    events: events,
                    plantsById: plantsById,
                    plantsLoaded: plantsLoaded,
                    surface: surface,
                    types: types,
                  )
                else if (_view == CalendarView.month)
                  _MonthView(
                    now: now,
                    anchor: _anchor,
                    schedules: schedules,
                    events: events,
                    plantsById: plantsById,
                    plantsLoaded: plantsLoaded,
                    surface: surface,
                  )
                else
                  _YearView(
                    anchor: _anchor,
                    schedules: schedules,
                    plantsById: plantsById,
                    plantsLoaded: plantsLoaded,
                    surface: surface,
                    onMonthTap: (month) => setState(() {
                      _anchor = DateTime(_anchor.year, month, 1);
                      _view = CalendarView.month;
                    }),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _titleFor(BuildContext context, CalendarView v, DateTime d) {
    final locale = _localeOf(context);
    switch (v) {
      case CalendarView.week:
        final (start, end) = weekRangeOf(d, _firstWeekdayOf(context));
        return weekRangeLabel(locale, start, end);
      case CalendarView.month:
        return DateFormat.yMMM(locale).format(d);
      case CalendarView.year:
        return DateFormat.y(locale).format(d);
    }
  }

  Widget _sectionLabel(String text, PlantlySurface surface) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: surface.green,
        letterSpacing: 0.1 * 11,
      ),
    ),
  );
}

class _WeekView extends StatelessWidget {
  const _WeekView({
    required this.now,
    required this.anchor,
    required this.schedules,
    required this.events,
    required this.plantsById,
    required this.plantsLoaded,
    required this.surface,
    required this.types,
  });
  final DateTime now;
  final DateTime anchor;
  final List<db.CareScheduleRow> schedules;
  final List<db.CareEventRow> events;
  final Map<String, db.PlantRow> plantsById;
  final bool plantsLoaded;
  final PlantlySurface surface;
  final List<CareType> types;

  @override
  Widget build(BuildContext context) {
    final weekStart = weekStartOf(anchor, _firstWeekdayOf(context));
    // Calendar arithmetic, not Duration: a DST week is 167h or 169h long,
    // so +Duration(days: n) and difference().inDays misplace days.
    final weekEnd = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + 7,
    );
    final days = <_DayBucket>[
      for (var i = 0; i < 7; i++)
        _DayBucket(
          date: DateTime(weekStart.year, weekStart.month, weekStart.day + i),
        ),
    ];
    int dayIndex(DateTime day) => DateTime.utc(day.year, day.month, day.day)
        .difference(
          DateTime.utc(weekStart.year, weekStart.month, weekStart.day),
        )
        .inDays;

    for (final s in schedules) {
      if (s.nextDueAt == null) continue;
      if (plantsLoaded && !plantsById.containsKey(s.plantId)) continue;
      final due = DateTime.fromMillisecondsSinceEpoch(
        s.nextDueAt!,
        isUtc: true,
      ).toLocal();
      final day = DateTime(due.year, due.month, due.day);
      if (day.isBefore(weekStart) || !day.isBefore(weekEnd)) continue;
      days[dayIndex(day)].scheduled.add(s);
    }
    for (final e in events) {
      final done = DateTime.fromMillisecondsSinceEpoch(
        e.doneAt,
        isUtc: true,
      ).toLocal();
      final day = DateTime(done.year, done.month, done.day);
      if (day.isBefore(weekStart) || !day.isBefore(weekEnd)) continue;
      days[dayIndex(day)].done.add(e);
    }

    final today = now;
    final todayStripped = DateTime(today.year, today.month, today.day);
    return Container(
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(PlantlyTokens.radius2xl),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < days.length; i++)
            _DayRow(
              bucket: days[i],
              isToday: days[i].date == todayStripped,
              plantsById: plantsById,
              surface: surface,
              types: types,
              last: i == days.length - 1,
            ),
        ],
      ),
    );
  }
}

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.now,
    required this.anchor,
    required this.schedules,
    required this.events,
    required this.plantsById,
    required this.plantsLoaded,
    required this.surface,
  });
  final DateTime now;
  final DateTime anchor;
  final List<db.CareScheduleRow> schedules;
  final List<db.CareEventRow> events;
  final Map<String, db.PlantRow> plantsById;
  final bool plantsLoaded;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(anchor.year, anchor.month, 1);
    final daysInMonth = DateTime(anchor.year, anchor.month + 1, 0).day;
    // Pad to the locale's first day of the week.
    final firstWeekday = _firstWeekdayOf(context);
    final leadingBlanks = (first.weekday - firstWeekday + 7) % 7;
    final gridCells = leadingBlanks + daysInMonth;
    final totalCells = ((gridCells + 6) ~/ 7) * 7;

    final counts = List<int>.filled(daysInMonth, 0);
    final done = List<int>.filled(daysInMonth, 0);
    for (final s in schedules) {
      if (s.nextDueAt == null) continue;
      if (plantsLoaded && !plantsById.containsKey(s.plantId)) continue;
      final d = DateTime.fromMillisecondsSinceEpoch(
        s.nextDueAt!,
        isUtc: true,
      ).toLocal();
      if (d.year != anchor.year || d.month != anchor.month) continue;
      counts[d.day - 1]++;
    }
    for (final e in events) {
      final d = DateTime.fromMillisecondsSinceEpoch(
        e.doneAt,
        isUtc: true,
      ).toLocal();
      if (d.year != anchor.year || d.month != anchor.month) continue;
      done[d.day - 1]++;
    }

    final today = now;
    // intl's narrow weekday symbols are Sunday-first; rotate to firstWeekday.
    final narrow = DateFormat.E(_localeOf(context)).dateSymbols.NARROWWEEKDAYS;
    final dayLabels = [
      for (var i = 0; i < 7; i++) narrow[(firstWeekday + i) % 7],
    ];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(PlantlyTokens.radius2xl),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final lbl in dayLabels)
                Expanded(
                  child: Center(
                    child: Text(
                      lbl,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: surface.muted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var r = 0; r < totalCells / 7; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: _MonthCell(
                      cellIndex: r * 7 + c,
                      leadingBlanks: leadingBlanks,
                      daysInMonth: daysInMonth,
                      counts: counts,
                      done: done,
                      anchor: anchor,
                      today: today,
                      surface: surface,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.cellIndex,
    required this.leadingBlanks,
    required this.daysInMonth,
    required this.counts,
    required this.done,
    required this.anchor,
    required this.today,
    required this.surface,
  });
  final int cellIndex;
  final int leadingBlanks;
  final int daysInMonth;
  final List<int> counts;
  final List<int> done;
  final DateTime anchor;
  final DateTime today;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    final day = cellIndex - leadingBlanks + 1;
    if (day < 1 || day > daysInMonth) {
      return const AspectRatio(aspectRatio: 1, child: SizedBox.shrink());
    }
    final isToday =
        today.year == anchor.year &&
        today.month == anchor.month &&
        today.day == day;
    final count = counts[day - 1];
    final doneCount = done[day - 1];
    return AspectRatio(
      aspectRatio: 1,
      child: InkWell(
        onTap: () {
          showAdaptiveSheet(
            context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) =>
                DayDetailSheet(day: DateTime(anchor.year, anchor.month, day)),
          );
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isToday ? surface.greenSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: isToday ? Border.all(color: surface.green) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$day',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                  color: isToday ? surface.green : surface.text,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  if (count > 0)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: surface.terra,
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (doneCount > 0) ...[
                    if (count > 0) const SizedBox(width: 3),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: surface.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _YearView extends StatelessWidget {
  const _YearView({
    required this.anchor,
    required this.schedules,
    required this.plantsById,
    required this.plantsLoaded,
    required this.surface,
    required this.onMonthTap,
  });
  final DateTime anchor;
  final List<db.CareScheduleRow> schedules;
  final Map<String, db.PlantRow> plantsById;
  final bool plantsLoaded;
  final PlantlySurface surface;
  final ValueChanged<int> onMonthTap;

  @override
  Widget build(BuildContext context) {
    final year = anchor.year;
    // Count schedules per month.
    final counts = List<int>.filled(12, 0);
    for (final s in schedules) {
      if (s.nextDueAt == null) continue;
      if (plantsLoaded && !plantsById.containsKey(s.plantId)) continue;
      final d = DateTime.fromMillisecondsSinceEpoch(
        s.nextDueAt!,
        isUtc: true,
      ).toLocal();
      if (d.year != year) continue;
      counts[d.month - 1]++;
    }
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (var m = 1; m <= 12; m++)
          InkWell(
            onTap: () => onMonthTap(m),
            borderRadius: BorderRadius.circular(PlantlyTokens.radius),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: surface.surface,
                borderRadius: BorderRadius.circular(PlantlyTokens.radius),
                border: Border.all(color: surface.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat.MMM(
                      _localeOf(context),
                    ).format(DateTime(year, m)),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: surface.text,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${counts[m - 1]}',
                        style: TextStyle(
                          fontFamily: PlantlyFonts.plusJakartaSans,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: counts[m - 1] > 0
                              ? surface.green
                              : surface.muted,
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 16, color: surface.muted),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _UpcomingScheduleRow extends StatelessWidget {
  const _UpcomingScheduleRow({
    required this.now,
    required this.schedule,
    required this.plantName,
    required this.surface,
    required this.types,
    required this.last,
  });
  final DateTime now;
  final db.CareScheduleRow schedule;
  final String plantName;
  final PlantlySurface surface;
  final List<CareType> types;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final ct = resolveCareType(types, schedule.type);
    final due = DateTime.fromMillisecondsSinceEpoch(
      schedule.nextDueAt!,
      isUtc: true,
    ).toLocal();
    final (whenLabel, urgent) = upcomingDueLabel(t, now, due);
    return InkWell(
      onTap: () {
        openPlant(context, schedule.plantId);
      },
      child: Container(
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(bottom: BorderSide(color: surface.border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: urgent ? surface.terraSoft : surface.greenSoft,
                borderRadius: BorderRadius.circular(PlantlyTokens.radius),
              ),
              child: Icon(
                ct.icon,
                size: 14,
                color: urgent ? surface.terra : surface.green,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plantName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: surface.text,
                    ),
                  ),
                  Text(
                    '${careTypeVerb(t, ct)} · $whenLabel',
                    style: TextStyle(
                      fontSize: 11,
                      color: urgent ? surface.terra : surface.muted,
                    ),
                  ),
                ],
              ),
            ),
            AssigneeChip(
              userId: schedule.assigneeUserId,
              tenantId: schedule.tenantId,
              surface: surface,
              size: 18,
              padLeft: 0,
            ),
            if (schedule.assigneeUserId != null) const SizedBox(width: 6),
            Text(
              DateFormat.MMMd(_localeOf(context)).format(due),
              style: TextStyle(
                fontSize: 11,
                color: surface.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayBucket {
  _DayBucket({required this.date});
  final DateTime date;
  final List<db.CareScheduleRow> scheduled = [];
  final List<db.CareEventRow> done = [];
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.bucket,
    required this.isToday,
    required this.plantsById,
    required this.surface,
    required this.types,
    required this.last,
  });
  final _DayBucket bucket;
  final bool isToday;
  final Map<String, db.PlantRow> plantsById;
  final PlantlySurface surface;
  final List<CareType> types;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    // "MON" / "LUN" — intl abbreviations carry a trailing dot in ro; drop it
    // for the stacked label.
    final weekday = DateFormat.E(
      _localeOf(context),
    ).format(bucket.date).replaceAll('.', '');

    return InkWell(
      onTap: () => showDayDetail(context, bucket.date),
      child: Container(
        decoration: BoxDecoration(
          color: isToday ? surface.greenSoft : null,
          border: last
              ? null
              : Border(bottom: BorderSide(color: surface.border)),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 56,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weekday.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isToday ? surface.green : surface.muted,
                      letterSpacing: 0.1 * 11,
                    ),
                  ),
                  Text(
                    bucket.date.day.toString(),
                    style: TextStyle(
                      fontFamily: PlantlyFonts.plusJakartaSans,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isToday ? surface.green : surface.text,
                      letterSpacing: -0.02 * 22,
                      height: 1,
                    ),
                  ),
                  if (isToday)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        t.commonTodayLabel.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: surface.green,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (bucket.scheduled.isEmpty && bucket.done.isEmpty)
                    Text(
                      t.calDayFree,
                      style: TextStyle(
                        fontSize: 12,
                        color: surface.muted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  for (final s in bucket.scheduled) ...[
                    _ScheduleChip(
                      schedule: s,
                      plantName: plantsById[s.plantId]?.nickname ?? s.plantId,
                      plantId: s.plantId,
                      surface: surface,
                      types: types,
                    ),
                    const SizedBox(height: 5),
                  ],
                  for (final e in bucket.done) ...[
                    _DoneChip(
                      event: e,
                      plantName: plantsById[e.plantId]?.nickname ?? e.plantId,
                      plantId: e.plantId,
                      surface: surface,
                      types: types,
                    ),
                    const SizedBox(height: 5),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleChip extends StatelessWidget {
  const _ScheduleChip({
    required this.schedule,
    required this.plantName,
    required this.plantId,
    required this.surface,
    required this.types,
  });
  final db.CareScheduleRow schedule;
  final String plantName;
  final String plantId;
  final PlantlySurface surface;
  final List<CareType> types;

  @override
  Widget build(BuildContext context) {
    final ct = resolveCareType(types, schedule.type);
    return InkWell(
      borderRadius: BorderRadius.circular(PlantlyTokens.radius),
      onTap: () {
        openPlant(context, plantId);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: surface.surfaceAlt,
          borderRadius: BorderRadius.circular(PlantlyTokens.radius),
          border: Border.all(color: surface.border),
        ),
        child: Row(
          children: [
            Icon(ct.icon, size: 13, color: surface.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                plantName,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: surface.text,
                ),
              ),
            ),
            Text(
              careTypeInlineLabel(AppLocalizations.of(context), ct, careTypeLabel(AppLocalizations.of(context), ct)),
              style: TextStyle(fontSize: 11, color: surface.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoneChip extends StatelessWidget {
  const _DoneChip({
    required this.event,
    required this.plantName,
    required this.plantId,
    required this.surface,
    required this.types,
  });
  final db.CareEventRow event;
  final String plantName;
  final String plantId;
  final PlantlySurface surface;
  final List<CareType> types;

  @override
  Widget build(BuildContext context) {
    final ct = resolveCareType(types, event.type);
    return InkWell(
      borderRadius: BorderRadius.circular(PlantlyTokens.radius),
      onTap: () {
        openPlant(context, plantId);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: surface.greenSoft,
          borderRadius: BorderRadius.circular(PlantlyTokens.radius),
          border: Border.all(color: surface.border),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, size: 13, color: surface.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                plantName,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: surface.text,
                ),
              ),
            ),
            Text(
              careTypeInlineLabel(AppLocalizations.of(context), ct, careTypePastLabel(AppLocalizations.of(context), ct)),
              style: TextStyle(fontSize: 11, color: surface.muted),
            ),
          ],
        ),
      ),
    );
  }
}
