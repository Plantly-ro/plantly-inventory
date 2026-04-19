import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/database/app_database.dart' as db;
import '../../data/providers.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';
import '../plant_detail/plant_detail_screen.dart';

/// Full activity log — every care event ever recorded, newest first.
/// Reached via the Recent Activity widget's "View all" action.
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final eventsAsync = ref.watch(recentCareEventsProvider);
    final plantsById = ref.watch(plantsStreamProvider).maybeWhen(
          data: (rows) => {for (final p in rows) p.id: p},
          orElse: () => const <String, db.PlantRow>{},
        );

    return Scaffold(
      backgroundColor: surface.bg,
      appBar: AppBar(
        backgroundColor: surface.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: surface.text),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Activity',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: surface.text,
            letterSpacing: -0.02 * 22,
          ),
        ),
      ),
      body: eventsAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: surface.green)),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('$e', style: TextStyle(color: surface.terra)),
        ),
        data: (events) {
          if (events.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No activity yet.\nLog your first care event on any plant.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: surface.muted, fontSize: 14),
                ),
              ),
            );
          }
          // Group events by "today / yesterday / ISO date" so the list has
          // a skimmable structure as it grows.
          final groups = _groupByDay(events);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              for (final g in groups) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                  child: Text(
                    g.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: surface.green,
                      letterSpacing: 0.1 * 11,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: surface.surface,
                    border: Border.all(color: surface.border),
                    borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < g.events.length; i++)
                        _row(context, g.events[i], plantsById, surface, i == g.events.length - 1),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _row(
    BuildContext context,
    db.CareEventRow event,
    Map<String, db.PlantRow> plantsById,
    PlantlySurface surface,
    bool last,
  ) {
    final plant = plantsById[event.plantId];
    final title = plant?.nickname ?? event.plantId;
    final subtitle = _describe(event);
    final when = DateTime.fromMillisecondsSinceEpoch(event.doneAt, isUtc: true).toLocal();
    final time = '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: plant == null
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PlantDetailScreen(plantId: plant.id)),
              );
            },
      child: Container(
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: surface.border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: surface.greenSoft, shape: BoxShape.circle),
              child: Icon(_iconFor(event.type), size: 14, color: surface.green),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: surface.text, height: 1.25),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11.5, color: surface.muted),
                  ),
                ],
              ),
            ),
            Text(
              time,
              style: TextStyle(fontSize: 11, color: surface.muted, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  String _describe(db.CareEventRow e) {
    final verb = _past(e.type);
    final parts = <String>[];
    if (e.product != null && e.product!.isNotEmpty) parts.add(e.product!);
    if (e.dose != null && e.dose!.isNotEmpty) parts.add(e.dose!);
    if (e.notes != null && e.notes!.isNotEmpty) parts.add(e.notes!);
    return parts.isEmpty ? verb : '$verb — ${parts.join(' · ')}';
  }

  String _past(String type) {
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

  List<_DayGroup> _groupByDay(List<db.CareEventRow> events) {
    final today = _stripTime(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    final buckets = <String, _DayGroup>{};
    for (final e in events) {
      final d = _stripTime(DateTime.fromMillisecondsSinceEpoch(e.doneAt, isUtc: true).toLocal());
      final label = d == today
          ? 'TODAY'
          : d == yesterday
              ? 'YESTERDAY'
              : '${_monthName(d.month)} ${d.day.toString().padLeft(2, '0')}';
      buckets.putIfAbsent(label, () => _DayGroup(label: label, events: [])).events.add(e);
    }
    return buckets.values.toList(growable: false);
  }

  DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);

  String _monthName(int m) =>
      const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];
}

class _DayGroup {
  _DayGroup({required this.label, required this.events});
  final String label;
  final List<db.CareEventRow> events;
}
