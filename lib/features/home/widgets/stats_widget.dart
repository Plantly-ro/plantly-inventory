import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/tokens.dart';
import 'widget_shell.dart';

/// Port of `widgetRegistry.stats.render` — four tiles in a 2×2 grid.
class StatsWidget extends StatelessWidget {
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

  static const _tiles = <_Stat>[
    _Stat('2', 'Overdue', Icons.water_drop_outlined, urgent: true),
    _Stat('3', 'Due today', Icons.check, urgent: false),
    _Stat('24', 'Plants', Icons.eco_outlined, urgent: false),
    _Stat('6', 'Spaces', Icons.place_outlined, urgent: false),
  ];

  @override
  Widget build(BuildContext context) {
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
        children: _tiles.map((t) => _TileView(t, surface)).toList(growable: false),
      ),
    );
  }
}

class _Stat {
  const _Stat(this.value, this.label, this.icon, {required this.urgent});
  final String value;
  final String label;
  final IconData icon;
  final bool urgent;
}

class _TileView extends StatelessWidget {
  const _TileView(this.tile, this.surface);
  final _Stat tile;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    final accent = tile.urgent ? surface.terra : surface.green;
    final soft = tile.urgent ? surface.terraSoft : surface.greenSoft;
    return Container(
      padding: const EdgeInsets.all(PlantlyTokens.space3),
      decoration: BoxDecoration(
        color: surface.surface,
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
    );
  }
}
