import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/database/app_database.dart' as db;
import '../../data/providers.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';
import '../plant_detail/plant_detail_screen.dart';

/// Weekly calendar — upcoming schedules + care events already recorded,
/// pivoted by the day they fall on (Mon → Sun of the currently-visible week).
/// Swipe the top chevrons to move between weeks.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  // Anchor = Monday of the currently-displayed week.
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = _mondayOf(DateTime.now());
  }

  static DateTime _mondayOf(DateTime d) {
    final stripped = DateTime(d.year, d.month, d.day);
    return stripped.subtract(Duration(days: stripped.weekday - DateTime.monday));
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;

    final schedulesAsync = ref.watch(allSchedulesProvider);
    final eventsAsync = ref.watch(recentCareEventsProvider);
    final plantsById = ref.watch(plantsStreamProvider).maybeWhen(
          data: (rows) => {for (final p in rows) p.id: p},
          orElse: () => const <String, db.PlantRow>{},
        );

    final weekDays = <_DayBucket>[
      for (var i = 0; i < 7; i++) _DayBucket(date: _weekStart.add(Duration(days: i))),
    ];
    final weekEnd = _weekStart.add(const Duration(days: 7));

    // Populate buckets with schedules due this week.
    schedulesAsync.whenData((schedules) {
      for (final s in schedules) {
        if (s.nextDueAt == null) continue;
        final due = DateTime.fromMillisecondsSinceEpoch(s.nextDueAt!, isUtc: true).toLocal();
        final day = DateTime(due.year, due.month, due.day);
        if (day.isBefore(_weekStart) || !day.isBefore(weekEnd)) continue;
        final idx = day.difference(_weekStart).inDays;
        weekDays[idx].scheduled.add(s);
      }
    });

    // And any events already recorded this week, so the user can see "oh,
    // I already did that on Tuesday."
    eventsAsync.whenData((events) {
      for (final e in events) {
        final done = DateTime.fromMillisecondsSinceEpoch(e.doneAt, isUtc: true).toLocal();
        final day = DateTime(done.year, done.month, done.day);
        if (day.isBefore(_weekStart) || !day.isBefore(weekEnd)) continue;
        final idx = day.difference(_weekStart).inDays;
        weekDays[idx].done.add(e);
      }
    });

    final today = DateTime.now();
    final todayStripped = DateTime(today.year, today.month, today.day);
    final isCurrentWeek =
        !todayStripped.isBefore(_weekStart) && todayStripped.isBefore(weekEnd);
    final rangeLabel = _rangeLabel(_weekStart, weekEnd.subtract(const Duration(days: 1)));
    final titleLabel = isCurrentWeek
        ? 'This week'
        : todayStripped.isBefore(_weekStart)
            ? 'Upcoming week'
            : 'Past week';

    return Scaffold(
      backgroundColor: surface.bg,
      appBar: AppBar(
        backgroundColor: surface.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: surface.text),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rangeLabel.toUpperCase(),
              style: TextStyle(fontSize: 11, color: surface.muted, fontWeight: FontWeight.w500, letterSpacing: 0.08 * 11),
            ),
            Text(
              titleLabel,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: surface.text,
                letterSpacing: -0.02 * 22,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Previous week',
            onPressed: () => setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7))),
            icon: Icon(Icons.arrow_back_ios_new, size: 18, color: surface.text),
          ),
          if (!isCurrentWeek)
            IconButton(
              tooltip: 'This week',
              onPressed: () => setState(() => _weekStart = _mondayOf(DateTime.now())),
              icon: Icon(Icons.today_outlined, color: surface.text),
            ),
          IconButton(
            tooltip: 'Next week',
            onPressed: () => setState(() => _weekStart = _weekStart.add(const Duration(days: 7))),
            icon: Icon(Icons.arrow_forward_ios, size: 18, color: surface.text),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Container(
            decoration: BoxDecoration(
              color: surface.surface,
              border: Border.all(color: surface.border),
              borderRadius: BorderRadius.circular(PlantlyTokens.radius2xl),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < weekDays.length; i++)
                  _DayRow(
                    bucket: weekDays[i],
                    isToday: weekDays[i].date == todayStripped,
                    plantsById: plantsById,
                    surface: surface,
                    last: i == weekDays.length - 1,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _rangeLabel(DateTime from, DateTime to) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (from.month == to.month) {
      return '${months[from.month - 1]} ${from.day}–${to.day}';
    }
    return '${months[from.month - 1]} ${from.day} – ${months[to.month - 1]} ${to.day}';
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
    required this.last,
  });
  final _DayBucket bucket;
  final bool isToday;
  final Map<String, db.PlantRow> plantsById;
  final PlantlySurface surface;
  final bool last;

  @override
  Widget build(BuildContext context) {
    const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekday = weekdayNames[bucket.date.weekday - DateTime.monday];

    return Container(
      decoration: BoxDecoration(
        color: isToday ? surface.greenSoft : null,
        border: last ? null : Border(bottom: BorderSide(color: surface.border)),
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
                  style: GoogleFonts.plusJakartaSans(
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
                      'TODAY',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: surface.green),
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
                    'Clear',
                    style: TextStyle(fontSize: 12, color: surface.muted, fontStyle: FontStyle.italic),
                  ),
                for (final s in bucket.scheduled) ...[
                  _ScheduleRow(
                    schedule: s,
                    plantName: plantsById[s.plantId]?.nickname ?? s.plantId,
                    plantId: s.plantId,
                    surface: surface,
                  ),
                  const SizedBox(height: 5),
                ],
                for (final e in bucket.done) ...[
                  _DoneRow(
                    event: e,
                    plantName: plantsById[e.plantId]?.nickname ?? e.plantId,
                    plantId: e.plantId,
                    surface: surface,
                  ),
                  const SizedBox(height: 5),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.schedule,
    required this.plantName,
    required this.plantId,
    required this.surface,
  });
  final db.CareScheduleRow schedule;
  final String plantName;
  final String plantId;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(PlantlyTokens.radius),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PlantDetailScreen(plantId: plantId)),
        );
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
            Icon(_iconFor(schedule.type), size: 13, color: surface.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                plantName,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: surface.text),
              ),
            ),
            Text(
              _verb(schedule.type).toLowerCase(),
              style: TextStyle(fontSize: 11, color: surface.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoneRow extends StatelessWidget {
  const _DoneRow({
    required this.event,
    required this.plantName,
    required this.plantId,
    required this.surface,
  });
  final db.CareEventRow event;
  final String plantName;
  final String plantId;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(PlantlyTokens.radius),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PlantDetailScreen(plantId: plantId)),
        );
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
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: surface.text),
              ),
            ),
            Text(
              _pastTense(event.type).toLowerCase(),
              style: TextStyle(fontSize: 11, color: surface.muted),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _iconFor(String type) {
  switch (type) {
    case 'fertilize':
      return Icons.eco_outlined;
    case 'rotate':
      return Icons.light_mode_outlined;
    case 'mist':
      return Icons.bubble_chart_outlined;
    case 'repot':
      return Icons.local_florist_outlined;
    case 'prune':
      return Icons.content_cut_outlined;
    case 'water':
      return Icons.water_drop_outlined;
    default:
      return Icons.notifications_active_outlined;
  }
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
      return type.isEmpty ? 'Care' : '${type[0].toUpperCase()}${type.substring(1)}';
  }
}

String _pastTense(String type) {
  switch (type) {
    case 'water':
      return 'Watered';
    case 'fertilize':
      return 'Fertilized';
    case 'mist':
      return 'Misted';
    case 'repot':
      return 'Repotted';
    case 'prune':
      return 'Pruned';
    case 'rotate':
      return 'Rotated';
    default:
      return type.isEmpty ? 'Logged' : '${type[0].toUpperCase()}${type.substring(1)}';
  }
}
