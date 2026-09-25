import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../data/user_prefs.dart';
import '../../../l10n/generated/app_localizations.dart';

import '../../../theme/tokens.dart';
import 'widget_shell.dart';

/// Greeting header — shows today's date and a time-of-day-aware
/// salutation. If the user has set a name in Me, we append it; otherwise
/// the greeting is anonymous.
class GreetingWidget extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final now = DateTime.now();
    final date = _formatDate(now, Localizations.localeOf(context).toString());
    final name = ref.watch(userPrefsProvider).userName;
    final base = _timeOfDayGreeting(t, now.hour);
    final greeting = (name != null && name.isNotEmpty) ? '$base, $name' : base;
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
          ],
        ),
      ),
    );
  }

  /// "Monday · January 5" (en) / "luni · 5 ianuarie" (ro) — weekday and
  /// month names come from intl for the active locale.
  String _formatDate(DateTime d, String locale) {
    return '${DateFormat.EEEE(locale).format(d)} · ${DateFormat.MMMMd(locale).format(d)}';
  }

  String _timeOfDayGreeting(AppLocalizations t, int hour) {
    if (hour < 5) return t.homeGreetingStillUp;
    if (hour < 12) return t.homeGreetingMorning;
    if (hour < 18) return t.homeGreetingAfternoon;
    return t.homeGreetingEvening;
  }
}
