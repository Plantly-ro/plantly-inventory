import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
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
    this.padInner = true,
    this.onMoveUp,
    this.onMoveDown,
    this.onRemove,
  });

  final PlantlySurface surface;
  final bool editing;
  final bool padInner;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onRemove;

  // Deterministic pick per day — using the day-of-year modulo the tip
  // count keeps the card stable all day, then rotates at midnight.
  // Copy lives in the ARB files (homeTipNTitle / homeTipNBody).
  static List<_Tip> _tips(AppLocalizations t) => [
        _Tip(Icons.water_drop_outlined, t.homeTip1Title, t.homeTip1Body),
        _Tip(Icons.wb_sunny_outlined, t.homeTip2Title, t.homeTip2Body),
        _Tip(Icons.eco_outlined, t.homeTip3Title, t.homeTip3Body),
        _Tip(Icons.air, t.homeTip4Title, t.homeTip4Body),
        _Tip(Icons.local_florist_outlined, t.homeTip5Title, t.homeTip5Body),
        _Tip(Icons.cleaning_services_outlined, t.homeTip6Title, t.homeTip6Body),
        _Tip(Icons.bubble_chart_outlined, t.homeTip7Title, t.homeTip7Body),
      ];

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tips = _tips(t);
    final now = DateTime.now();
    final dayOfYear = _dayOfYear(now);
    final tip = tips[dayOfYear % tips.length];
    return WidgetShell(
      surface: surface,
      editing: editing,
      padInner: padInner,
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
                    t.tipOfTheDay,
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
