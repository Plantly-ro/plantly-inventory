import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../data/providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/tokens.dart';
import '../../locations/locations_screen.dart';
import '../../search/search_screen.dart';
import '../filter.dart';
import 'widget_shell.dart';

/// Live 2×2 stats grid: overdue, due today, plants, spaces.
class StatsWidget extends ConsumerWidget {
  const StatsWidget({
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dueAsync = ref.watch(dueBeforeEodProvider);
    final plantsAsync = ref.watch(plantsStreamProvider);
    final locsAsync = ref.watch(locationsStreamProvider);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final alivePlantIds = plantsAsync.maybeWhen(
      data: (rows) => {for (final p in rows) p.id},
      orElse: () => <String>{},
    );
    final overdue = dueAsync.maybeWhen(
      data: (rows) => rows
          .where((s) =>
              s.nextDueAt != null &&
              s.nextDueAt! < nowMs &&
              alivePlantIds.contains(s.plantId))
          .length,
      orElse: () => null,
    );
    final today = dueAsync.maybeWhen(
      data: (rows) => rows
          .where((s) =>
              s.nextDueAt != null &&
              s.nextDueAt! >= nowMs &&
              alivePlantIds.contains(s.plantId))
          .length,
      orElse: () => null,
    );
    final plants = plantsAsync.maybeWhen(data: (r) => r.length, orElse: () => null);
    final spaces = locsAsync.maybeWhen(data: (r) => r.length, orElse: () => null);

    final t = AppLocalizations.of(context);
    final tiles = <_Stat>[
      _Stat(_fmt(overdue), t.statOverdue, Icons.water_drop_outlined, urgent: (overdue ?? 0) > 0, filter: PlantFilter.overdue),
      _Stat(_fmt(today), t.statDueToday, Icons.check, urgent: false, filter: PlantFilter.dueToday),
      _Stat(_fmt(plants), t.statPlants, Icons.eco_outlined, urgent: false, filter: PlantFilter.all),
      _Stat(_fmt(spaces), t.statSpaces, Icons.place_outlined, urgent: false),
    ];

    return WidgetShell(
      surface: surface,
      editing: editing,
      onMoveUp: onMoveUp,
      onMoveDown: onMoveDown,
      onRemove: onRemove,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.75,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: tiles
            .map((tile) => _TileView(
                  tile,
                  surface,
                  onTap: () {
                    if (tile.filter == null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LocationsScreen()),
                      );
                    } else {
                      ref.read(activeFilterProvider.notifier).state = tile.filter!;
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SearchScreen()),
                      );
                    }
                  },
                ))
            .toList(growable: false),
      ),
    );
  }

  String _fmt(int? v) => v == null ? '…' : '$v';
}

class _Stat {
  const _Stat(this.value, this.label, this.icon, {required this.urgent, this.filter});
  final String value;
  final String label;
  final IconData icon;
  final bool urgent;
  final PlantFilter? filter;
}

class _TileView extends StatelessWidget {
  const _TileView(this.tile, this.surface, {required this.onTap});
  final _Stat tile;
  final PlantlySurface surface;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = tile.urgent ? surface.terra : surface.green;
    final soft = tile.urgent ? surface.terraSoft : surface.greenSoft;
    return Material(
      color: surface.surface,
      borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
        child: Container(
          padding: const EdgeInsets.all(PlantlyTokens.space3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
            border: Border.all(color: surface.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(tile.icon, size: 15, color: accent),
              ),
              const Spacer(),
              Text(
                tile.value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: PlantlyTokens.text2xl,
                  fontWeight: FontWeight.w800,
                  color: surface.text,
                  height: 1,
                ),
              ),
              Text(
                tile.label,
                style: TextStyle(
                  fontSize: 11,
                  color: surface.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
