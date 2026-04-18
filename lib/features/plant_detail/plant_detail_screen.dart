import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/image_processor.dart';
import '../../data/mock_plants.dart';
import '../../data/photo_picker.dart';
import '../../data/providers.dart';
import '../../shared/plant_thumb.dart';
import '../../theme/tokens.dart';
import '../export/export_dialog.dart';
import '../home/home_providers.dart';
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
            tooltip: 'Add photo',
            onPressed: () async {
              final picker = ref.read(photoPickerProvider);
              final picked = await picker.pickFromGallery();
              if (picked == null) return;
              // Shrink before hashing: the hash changes after compression,
              // which is the desired behaviour — a 20 MB camera capture
              // and its 600 KB display-resize are semantically different
              // images as far as the content-addressed store is concerned.
              final processor = ref.read(imageProcessorProvider);
              final shrunk = await processor.toDisplay(picked.bytes);
              final photos = ref.read(photoRepositoryProvider);
              final joins = ref.read(plantPhotoRepositoryProvider);
              final sha = await photos.saveBytes(shrunk, mime: 'image/jpeg');
              await joins.attach(plantId, sha);
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
            child: _UpcomingCare(surface: surface, plant: plant),
          ),
          const SizedBox(height: 16),
          _SectionLabel(text: 'TIMELINE', surface: surface),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _Timeline(surface: surface),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'View all 42 events',
              style: TextStyle(fontSize: 11.5, color: surface.muted),
            ),
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

class _UpcomingCare extends StatelessWidget {
  const _UpcomingCare({required this.surface, required this.plant});
  final PlantlySurface surface;
  final MockPlant plant;

  @override
  Widget build(BuildContext context) {
    final rows = [
      _UpcomingRow(
        icon: Icons.water_drop_outlined,
        label: 'Water',
        when: plant.overdue ? '2 days overdue' : 'in 2 days',
        urgent: plant.overdue,
      ),
      const _UpcomingRow(
        icon: Icons.eco_outlined,
        label: 'Fertilize',
        when: 'in 18 days',
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            _UpcomingRowView(
              row: rows[i],
              surface: surface,
              last: i == rows.length - 1,
            ),
        ],
      ),
    );
  }
}

class _UpcomingRow {
  const _UpcomingRow({
    required this.icon,
    required this.label,
    required this.when,
    this.urgent = false,
  });
  final IconData icon;
  final String label;
  final String when;
  final bool urgent;
}

class _UpcomingRowView extends StatelessWidget {
  const _UpcomingRowView({required this.row, required this.surface, required this.last});
  final _UpcomingRow row;
  final PlantlySurface surface;
  final bool last;

  @override
  Widget build(BuildContext context) {
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
              color: row.urgent ? surface.terraSoft : surface.greenSoft,
              borderRadius: BorderRadius.circular(PlantlyTokens.radius),
            ),
            child: Icon(row.icon, size: 16, color: row.urgent ? surface.terra : surface.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text)),
                Text(
                  row.when,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: row.urgent ? surface.terra : surface.muted,
                    fontWeight: row.urgent ? FontWeight.w600 : FontWeight.w500,
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
            onPressed: () => _toast(context, '${row.label} logged'),
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
            onPressed: () => _toast(context, 'Snoozed 3 days'),
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
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.surface});
  final PlantlySurface surface;

  static const _items = <_TimelineItem>[
    _TimelineItem(when: 'Apr 15', icon: Icons.water_drop_outlined, text: 'Watered'),
    _TimelineItem(when: 'Apr 10', icon: Icons.camera_alt_outlined, text: 'Photo added'),
    _TimelineItem(when: 'Apr 08', icon: Icons.eco_outlined, text: 'Fertilized (NPK 10-10-10, ¼ tsp)'),
    _TimelineItem(when: 'Mar 20', icon: Icons.local_florist_outlined, text: 'Repotted → 20cm terracotta'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          for (var i = 0; i < _items.length; i++)
            _row(_items[i], i == _items.length - 1),
        ],
      ),
    );
  }

  Widget _row(_TimelineItem item, bool last) {
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
            child: Icon(item.icon, size: 14, color: surface.green),
          ),
          const SizedBox(width: 11),
          Expanded(child: Text(item.text, style: TextStyle(fontSize: 13, color: surface.text))),
          Text(item.when, style: TextStyle(fontSize: 11, color: surface.muted, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _TimelineItem {
  const _TimelineItem({required this.when, required this.icon, required this.text});
  final String when;
  final IconData icon;
  final String text;
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
