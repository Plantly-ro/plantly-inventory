import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart' as db;
import '../../../data/providers.dart';
import '../../../theme/tokens.dart';
import '../../activity/activity_screen.dart';
import 'widget_shell.dart';

/// Live "Recent activity" card — newest 3 care_events with the plant
/// nickname + any product/dose/notes.
class ActivityWidget extends ConsumerWidget {
  const ActivityWidget({
    super.key,
    required this.surface,
    this.editing = false,
    this.onMoveUp,
    this.onMoveDown,
    this.onRemove,
  });

  final PlantlySurface surface;
  final bool editing;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onRemove;

  static const int _limit = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(recentCareEventsProvider);
    final plantsAsync = ref.watch(plantsStreamProvider);
    final plantsById = plantsAsync.maybeWhen(
      data: (rows) => {for (final p in rows) p.id: p},
      orElse: () => const <String, db.PlantRow>{},
    );

    return WidgetShell(
      surface: surface,
      editing: editing,
      onMoveUp: onMoveUp,
      onMoveDown: onMoveDown,
      onRemove: onRemove,
      title: 'Recent activity',
      action: editing ? null : 'View all',
      onAction: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ActivityScreen()),
        );
      },
      child: eventsAsync.when(
        loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text('$e', style: TextStyle(color: surface.terra)),
        data: (events) {
          if (events.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surface.surface,
                border: Border.all(color: surface.border),
                borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
              ),
              alignment: Alignment.center,
              child: Text(
                'Nothing logged yet — tap "Done" on a reminder.',
                style: TextStyle(fontSize: 12, color: surface.muted),
              ),
            );
          }
          final recent = events.take(_limit).toList();
          return Container(
            decoration: BoxDecoration(
              color: surface.surface,
              border: Border.all(color: surface.border),
              borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                for (var i = 0; i < recent.length; i++)
                  _row(recent[i], plantsById, i == recent.length - 1),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _row(db.CareEventRow event, Map<String, db.PlantRow> plantsById, bool last) {
    final plant = plantsById[event.plantId];
    final title = plant?.nickname ?? event.plantId;
    final subtitle = _describe(event);
    final when = _formatRelative(DateTime.fromMillisecondsSinceEpoch(event.doneAt, isUtc: true).toLocal());
    return Container(
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: surface.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
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
            when,
            style: TextStyle(fontSize: 11, color: surface.muted, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  String _describe(db.CareEventRow e) {
    final verb = _past(e.type);
    final parts = <String>[];
    if (e.product != null && e.product!.isNotEmpty) parts.add(e.product!);
    if (e.dose != null && e.dose!.isNotEmpty) parts.add(e.dose!);
    if (e.notes != null && e.notes!.isNotEmpty) parts.add(e.notes!);
    if (parts.isEmpty) return verb;
    return '$verb — ${parts.join(' · ')}';
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

  String _formatRelative(DateTime then) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thenDay = DateTime(then.year, then.month, then.day);
    final daysApart = today.difference(thenDay).inDays;
    if (daysApart == 0) {
      return '${then.hour.toString().padLeft(2, '0')}:${then.minute.toString().padLeft(2, '0')}';
    }
    if (daysApart == 1) return 'Yesterday';
    if (daysApart < 7) return '$daysApart d ago';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[then.month - 1]} ${then.day.toString().padLeft(2, '0')}';
  }
}
