import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/care_types.dart';
import '../../data/database/app_database.dart';
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';
import '../plant_detail/plant_detail_screen.dart';

/// Care-activity dashboard: aggregated counts across the whole
/// collection. Keeps the aggregations in-memory off the already-streamed
/// `recentCareEventsProvider` + `plantsStreamProvider` so no new SQL
/// work per open.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final t = AppLocalizations.of(context);
    final events = ref.watch(recentCareEventsProvider).maybeWhen(
          data: (rows) => rows,
          orElse: () => const <CareEventRow>[],
        );
    final plants = ref.watch(plantsStreamProvider).maybeWhen(
          data: (rows) => rows,
          orElse: () => const <PlantRow>[],
        );
    final types = ref.watch(careTypesProvider);

    final plantsById = {for (final p in plants) p.id: p};
    final now = DateTime.now();
    // Last 30 days window.
    final cutoff = now.subtract(const Duration(days: 30)).millisecondsSinceEpoch;
    final recent = events.where((e) => e.doneAt >= cutoff).toList();

    // Aggregate by type.
    final byType = <String, int>{};
    for (final e in recent) {
      byType.update(e.type, (v) => v + 1, ifAbsent: () => 1);
    }
    final sortedTypes = byType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Per-plant activity.
    final byPlant = <String, int>{};
    for (final e in recent) {
      byPlant.update(e.plantId, (v) => v + 1, ifAbsent: () => 1);
    }
    final topPlants = byPlant.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
          t.statsTitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: surface.text,
            letterSpacing: -0.02 * 22,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          _HeadlineCard(
            surface: surface,
            plants: plants.length,
            events: events.length,
            recent30d: recent.length,
          ),
          const SizedBox(height: 20),
          if (sortedTypes.isNotEmpty) ...[
            _section(t.statsActivityHeader, surface),
            const SizedBox(height: 8),
            _BarList(
              entries: sortedTypes,
              total: recent.length,
              label: (key) => resolveCareType(types, key).label,
              icon: (key) => resolveCareType(types, key).icon,
              surface: surface,
            ),
            const SizedBox(height: 20),
          ],
          if (topPlants.isNotEmpty) ...[
            _section(t.statsTopPlants, surface),
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
                  for (var i = 0; i < topPlants.take(5).length; i++)
                    _TopPlantRow(
                      rank: i + 1,
                      plantId: topPlants[i].key,
                      name: plantsById[topPlants[i].key]?.nickname ?? topPlants[i].key,
                      count: topPlants[i].value,
                      surface: surface,
                      last: i == topPlants.take(5).length - 1,
                    ),
                ],
              ),
            ),
          ] else
            _EmptyState(surface: surface),
        ],
      ),
    );
  }

  Widget _section(String text, PlantlySurface s) => Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: s.green,
          letterSpacing: 0.1 * 11,
        ),
      );
}

class _HeadlineCard extends StatelessWidget {
  const _HeadlineCard({
    required this.surface,
    required this.plants,
    required this.events,
    required this.recent30d,
  });
  final PlantlySurface surface;
  final int plants;
  final int events;
  final int recent30d;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
      ),
      child: Row(
        children: [
          Expanded(child: _Cell(value: '$plants', label: t.statsCellPlants, surface: surface)),
          Container(width: 1, height: 40, color: surface.border),
          Expanded(child: _Cell(value: '$events', label: t.statsCellEvents, surface: surface)),
          Container(width: 1, height: 40, color: surface.border),
          Expanded(child: _Cell(value: '$recent30d', label: t.statsCellLast30, surface: surface)),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.value, required this.label, required this.surface});
  final String value;
  final String label;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: surface.text,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: surface.muted,
            letterSpacing: 0.1 * 10,
          ),
        ),
      ],
    );
  }
}

class _BarList extends StatelessWidget {
  const _BarList({
    required this.entries,
    required this.total,
    required this.label,
    required this.icon,
    required this.surface,
  });
  final List<MapEntry<String, int>> entries;
  final int total;
  final String Function(String key) label;
  final IconData Function(String key) icon;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    final topCount = entries.isEmpty ? 1 : entries.first.value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
      ),
      child: Column(
        children: [
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(icon(entry.key), size: 14, color: surface.green),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 72,
                    child: Text(
                      label(entry.key),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: surface.text, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (_, c) {
                        final w = c.maxWidth * (entry.value / topCount);
                        return Stack(
                          children: [
                            Container(
                              height: 6,
                              decoration: BoxDecoration(color: surface.surfaceAlt, borderRadius: BorderRadius.circular(999)),
                            ),
                            Container(
                              height: 6,
                              width: w,
                              decoration: BoxDecoration(color: surface.green, borderRadius: BorderRadius.circular(999)),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${entry.value}',
                    style: TextStyle(fontSize: 12, color: surface.muted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TopPlantRow extends StatelessWidget {
  const _TopPlantRow({
    required this.rank,
    required this.plantId,
    required this.name,
    required this.count,
    required this.surface,
    required this.last,
  });
  final int rank;
  final String plantId;
  final String name;
  final int count;
  final PlantlySurface surface;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PlantDetailScreen(plantId: plantId)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: surface.border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: surface.greenSoft, shape: BoxShape.circle),
              child: Text(
                '$rank',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: surface.green),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(name,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text)),
            ),
            Text('$count',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: surface.green)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: surface.muted),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.surface});
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
      ),
      alignment: Alignment.center,
      child: Text(
        t.statsEmpty,
        textAlign: TextAlign.center,
        style: TextStyle(color: surface.muted, fontSize: 13),
      ),
    );
  }
}
