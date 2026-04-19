import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/database/app_database.dart' as db;
import '../../data/image_processor.dart';
import '../../data/mock_plants.dart';
import '../../data/photo_picker.dart';
import '../../data/providers.dart';
import '../../shared/plant_thumb.dart';
import '../../theme/tokens.dart';
import '../export/export_dialog.dart';
import '../home/home_providers.dart';
import 'add_reminder_sheet.dart';
import 'log_event_sheet.dart';
import 'propagate_dialog.dart';

/// Port of `PlantDetail` in `web/prototype/components/screens.jsx`.
class PlantDetailScreen extends ConsumerWidget {
  const PlantDetailScreen({super.key, required this.plantId});
  final String plantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final plant = MockPlants.byId(plantId);

    final attachedAsync = ref.watch(attachedPhotosProvider(plantId));

    return Scaffold(
      backgroundColor: surface.bg,
      appBar: AppBar(
        backgroundColor: surface.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: surface.text),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_a_photo_outlined, color: surface.text),
            tooltip: 'Add photos',
            onPressed: () async {
              final picker = ref.read(photoPickerProvider);
              final picked = await picker.pickMultipleFromGallery();
              if (picked.isEmpty) return;
              // Shrink before hashing: the hash changes after compression,
              // which is the desired behaviour — a 20 MB camera capture
              // and its 600 KB display-resize are semantically different
              // images as far as the content-addressed store is concerned.
              final processor = ref.read(imageProcessorProvider);
              final photos = ref.read(photoRepositoryProvider);
              final joins = ref.read(plantPhotoRepositoryProvider);
              for (final p in picked) {
                final shrunk = await processor.toDisplay(p.bytes);
                final sha = await photos.saveBytes(shrunk, mime: 'image/jpeg');
                await joins.attach(plantId, sha);
              }
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz, color: surface.text),
            onSelected: (value) async {
              if (value == 'propagate') {
                final child = await PropagateDialog.show(
                  context,
                  parentId: plantId,
                  parentName: plant.name,
                );
                if (child != null && context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => PlantDetailScreen(plantId: child.id)),
                  );
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'propagate', child: Text('Propagate')),
            ],
          ),
        ],
      ),
      body: ListView(
        children: [
          AspectRatio(
            aspectRatio: 1.3,
            child: Container(
              color: surface.surfaceAlt,
              child: attachedAsync.when(
                loading: () => Center(child: PlantThumb(plant: plant, size: 280)),
                error: (_, _) => Center(child: PlantThumb(plant: plant, size: 280)),
                data: (shas) => shas.isEmpty
                    ? Center(child: PlantThumb(plant: plant, size: 280))
                    : _HeroPhoto(sha: shas.first, ref: ref, fallback: plant),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plant.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: PlantlyTokens.text2xl,
                    fontWeight: FontWeight.w800,
                    color: surface.text,
                    letterSpacing: -0.02 * PlantlyTokens.text2xl,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  plant.latin,
                  style: TextStyle(
                    fontSize: 13,
                    color: surface.muted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 12, color: surface.muted),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        plant.location,
                        style: TextStyle(fontSize: 12, color: surface.muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Acquired ${plant.acquired}',
                  style: TextStyle(fontSize: 12, color: surface.muted),
                ),
                if (plant.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in plant.tags)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: surface.greenSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '#$tag',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: surface.green,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          _SectionLabel(text: 'UPCOMING CARE', surface: surface),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _UpcomingCare(surface: surface, plantId: plantId),
          ),
          const SizedBox(height: 16),
          _SectionLabel(text: 'TIMELINE', surface: surface),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _Timeline(surface: surface, plantId: plantId),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: _ExportCTA(
              surface: surface,
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => ExportDialog(plant: plant),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPhoto extends StatelessWidget {
  const _HeroPhoto({required this.sha, required this.ref, required this.fallback});
  final String sha;
  final WidgetRef ref;
  final MockPlant fallback;

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(photoRepositoryProvider);
    return FutureBuilder(
      future: repo.byHash(sha),
      builder: (context, snap) {
        final path = snap.data?.localPath;
        if (path != null) {
          final file = File(path);
          if (file.existsSync()) {
            return Image.file(file, fit: BoxFit.cover, width: double.infinity);
          }
        }
        return Center(child: PlantThumb(plant: fallback, size: 280));
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.surface});
  final String text;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
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
}

class _UpcomingCare extends ConsumerWidget {
  const _UpcomingCare({required this.surface, required this.plantId});
  final PlantlySurface surface;
  final String plantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(schedulesForPlantProvider(plantId));
    return Container(
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
      ),
      clipBehavior: Clip.antiAlias,
      child: schedulesAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(14),
          child: Text('$e', style: TextStyle(color: surface.terra, fontSize: 12)),
        ),
        data: (schedules) {
          if (schedules.isEmpty) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'No reminders yet — tap below to add one.',
                    style: TextStyle(fontSize: 12, color: surface.muted),
                  ),
                ),
                _AddReminderButton(surface: surface, plantId: plantId, leadingDivider: true),
              ],
            );
          }
          return Column(
            children: [
              for (var i = 0; i < schedules.length; i++)
                _UpcomingRowView(
                  schedule: schedules[i],
                  plantId: plantId,
                  surface: surface,
                  last: i == schedules.length - 1,
                ),
              _AddReminderButton(surface: surface, plantId: plantId, leadingDivider: true),
            ],
          );
        },
      ),
    );
  }
}

class _UpcomingRowView extends ConsumerWidget {
  const _UpcomingRowView({
    required this.schedule,
    required this.plantId,
    required this.surface,
    required this.last,
  });
  final db.CareScheduleRow schedule;
  final String plantId;
  final PlantlySurface surface;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (label, whenText, urgent) = _describe(schedule);
    final icon = _iconFor(schedule.type);
    return Container(
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: surface.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: urgent ? surface.terraSoft : surface.greenSoft,
              borderRadius: BorderRadius.circular(PlantlyTokens.radius),
            ),
            child: Icon(icon, size: 16, color: urgent ? surface.terra : surface.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text)),
                Text(
                  whenText,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: urgent ? surface.terra : surface.muted,
                    fontWeight: urgent ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: surface.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radiusMd)),
            ),
            onPressed: () async {
              await ref.read(careEventRepositoryProvider).record(
                    plantId: plantId,
                    type: schedule.type,
                  );
              if (context.mounted) _toast(context, '$label logged');
            },
            child: const Text('Done'),
          ),
          const SizedBox(width: 6),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: surface.surfaceAlt,
              foregroundColor: surface.muted,
              side: BorderSide(color: surface.border),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radiusMd)),
            ),
            onPressed: () async {
              await ref
                  .read(careScheduleRepositoryProvider)
                  .snooze(schedule.id, by: const Duration(days: 3));
              if (context.mounted) _toast(context, 'Snoozed 3 days');
            },
            child: const Text('Snooze'),
          ),
        ],
      ),
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  (String label, String when, bool urgent) _describe(db.CareScheduleRow s) {
    final label = _verb(s.type);
    final due = s.nextDueAt;
    if (due == null) return (label, 'No due date', false);
    final now = DateTime.now().millisecondsSinceEpoch;
    final diffMs = due - now;
    final days = (diffMs / (86400 * 1000)).round();
    if (diffMs < 0) {
      final late = -days;
      return (label, late == 0 ? 'overdue' : '$late day${late == 1 ? '' : 's'} overdue', true);
    }
    if (days == 0) return (label, 'today', true);
    if (days == 1) return (label, 'tomorrow', false);
    return (label, 'in $days days', false);
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
}

class _AddReminderButton extends StatelessWidget {
  const _AddReminderButton({
    required this.surface,
    required this.plantId,
    this.leadingDivider = false,
  });
  final PlantlySurface surface;
  final String plantId;
  final bool leadingDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: leadingDivider ? Border(top: BorderSide(color: surface.border)) : null,
      ),
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => AddReminderSheet(plantId: plantId),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.add_circle_outline, size: 18, color: surface.green),
              const SizedBox(width: 10),
              Text(
                'Add reminder',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: surface.green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Timeline extends ConsumerWidget {
  const _Timeline({required this.surface, required this.plantId});
  final PlantlySurface surface;
  final String plantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(careEventsForPlantProvider(plantId));
    return Container(
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
      ),
      clipBehavior: Clip.antiAlias,
      child: eventsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(14),
          child: Text('$e', style: TextStyle(color: surface.terra, fontSize: 12)),
        ),
        data: (events) {
          final logButton = _LogEventButton(
            surface: surface,
            plantId: plantId,
            leadingDivider: events.isNotEmpty,
          );
          if (events.isEmpty) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'No events yet — log your first watering below.',
                    style: TextStyle(fontSize: 12, color: surface.muted),
                  ),
                ),
                logButton,
              ],
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    for (var i = 0; i < events.length; i++)
                      _timelineRow(events[i], i == events.length - 1),
                  ],
                ),
              ),
              logButton,
            ],
          );
        },
      ),
    );
  }

  Widget _timelineRow(db.CareEventRow event, bool last) {
    final when = _formatDate(DateTime.fromMillisecondsSinceEpoch(event.doneAt, isUtc: true).toLocal());
    final text = _describe(event);
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
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: surface.text))),
          Text(when, style: TextStyle(fontSize: 11, color: surface.muted, fontWeight: FontWeight.w500)),
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

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}';
  }
}

class _LogEventButton extends StatelessWidget {
  const _LogEventButton({
    required this.surface,
    required this.plantId,
    this.leadingDivider = false,
  });
  final PlantlySurface surface;
  final String plantId;
  final bool leadingDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: leadingDivider ? Border(top: BorderSide(color: surface.border)) : null,
      ),
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => LogEventSheet(plantId: plantId),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.note_add_outlined, size: 18, color: surface.green),
              const SizedBox(width: 10),
              Text(
                'Log event',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: surface.green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportCTA extends StatelessWidget {
  const _ExportCTA({required this.surface, required this.onPressed});
  final PlantlySurface surface;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface.surface,
      borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: surface.terra, width: 2, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.open_in_new, size: 16, color: surface.terra),
              const SizedBox(width: 8),
              Text(
                'Post on plantly.ro',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: surface.terra,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
