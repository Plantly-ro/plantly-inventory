import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/tokens.dart';
import 'widget_shell.dart';

/// Greeting header — shows today's date, a time-of-day-aware salutation,
/// and a notification dot. The "AM" avatar is a placeholder until a real
/// account surface lands.
class GreetingWidget extends StatelessWidget {
  const GreetingWidget({
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
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date = _formatDate(now);
    final greeting = _timeOfDayGreeting(now.hour);
    return WidgetShell(
      surface: surface,
      editing: editing,
      onMoveUp: onMoveUp,
      onMoveDown: onMoveDown,
      onRemove: onRemove,
      child: Padding(
        padding: const EdgeInsets.only(bottom: PlantlyTokens.space3),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: surface.greenSoft,
                borderRadius: BorderRadius.circular(PlantlyTokens.radius3xl),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.person_outline, color: surface.green),
            ),
            const SizedBox(width: PlantlyTokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: PlantlyTokens.textXs,
                      color: surface.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    greeting,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: PlantlyTokens.text2xl,
                      fontWeight: FontWeight.w800,
                      color: surface.text,
                      letterSpacing: -0.02 * PlantlyTokens.text2xl,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: surface.surface,
                border: Border.all(color: surface.border),
                borderRadius: BorderRadius.circular(PlantlyTokens.radius),
              ),
              child: Icon(Icons.notifications_outlined, size: 18, color: surface.text),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${days[d.weekday - DateTime.monday]} · ${months[d.month - 1]} ${d.day}';
  }

  String _timeOfDayGreeting(int hour) {
    if (hour < 5) return 'Still up?';
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }
}
