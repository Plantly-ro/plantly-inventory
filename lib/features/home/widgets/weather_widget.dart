import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import 'widget_shell.dart';

/// Phase-1 "tip of the day" card. Previously hardcoded "TIMIȘOARA · 19°C"
/// with a fake rain forecast — honest weather needs a provider (Phase 2).
/// The key in `WidgetRegistry` is still `weather` so saved layouts that
/// reference it keep working.
class WeatherWidget extends StatelessWidget {
  const WeatherWidget({
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

  // Deterministic pick per day — using the day-of-year modulo the tip
  // count keeps the card stable all day, then rotates at midnight.
  static const _tips = <_Tip>[
    _Tip(Icons.water_drop_outlined, 'Check soil moisture before watering',
        'Most houseplants prefer the top 2–3 cm to dry out between waterings.'),
    _Tip(Icons.wb_sunny_outlined, 'Rotate toward the light',
        'A quarter turn each week keeps growth even and upright.'),
    _Tip(Icons.eco_outlined, 'Feed lightly in growing season',
        'Dilute fertiliser to half-strength to avoid root burn on sensitive species.'),
    _Tip(Icons.air, 'Watch for pests after seasonal change',
        'Thrips and spider mites love warm, dry indoor air — check leaf undersides.'),
    _Tip(Icons.local_florist_outlined, 'Repot when roots circle the pot',
        'Go up one pot size only — oversized pots hold too much moisture.'),
    _Tip(Icons.cleaning_services_outlined, 'Wipe dust off leaves',
        'Clean leaves photosynthesise better and let you spot pests early.'),
    _Tip(Icons.bubble_chart_outlined, 'Humidity helps aroids + calatheas',
        'Group plants or run a pebble tray — easier than misting all day.'),
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dayOfYear = _dayOfYear(now);
    final tip = _tips[dayOfYear % _tips.length];
    return WidgetShell(
      surface: surface,
      editing: editing,
      onMoveUp: onMoveUp,
      onMoveDown: onMoveDown,
      onRemove: onRemove,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PlantlyTokens.radius2xl),
          gradient: LinearGradient(
            colors: [surface.greenDeep, surface.green],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(PlantlyTokens.radius + 2),
              ),
              child: Icon(tip.icon, size: 22, color: Colors.white),
            ),
            const SizedBox(width: PlantlyTokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TIP OF THE DAY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.85),
                      letterSpacing: 0.08 * 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tip.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tip.body,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static int _dayOfYear(DateTime d) {
    return d.difference(DateTime(d.year)).inDays;
  }
}

class _Tip {
  const _Tip(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}
