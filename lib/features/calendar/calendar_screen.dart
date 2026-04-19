import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/tokens.dart';
import '../home/home_providers.dart';

/// Port of `CalendarScreen` in `web/prototype/components/screens.jsx`.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;

    final days = <_Day>[
      _Day(name: 'Mon', number: '14', events: [
        _Event(name: 'Bob', icon: Icons.water_drop_outlined),
        _Event(name: 'Ivy', icon: Icons.eco_outlined),
      ]),
      _Day(name: 'Tue', number: '15', events: [
        _Event(name: 'Fern', icon: Icons.water_drop_outlined),
        _Event(name: 'Oak', icon: Icons.water_drop_outlined),
      ]),
      _Day(name: 'Wed', number: '16', events: []),
      _Day(name: 'Thu', number: '17', events: [
        _Event(name: 'Bob', icon: Icons.water_drop_outlined),
        _Event(name: 'Rose', icon: Icons.local_florist_outlined),
      ]),
      _Day(name: 'Fri', number: '18', today: true, events: [
        _Event(name: 'Monty', icon: Icons.water_drop_outlined),
      ]),
      _Day(name: 'Sat', number: '19', events: [
        _Event(name: 'Ivy', icon: Icons.water_drop_outlined, skip: true),
        _Event(name: 'Oak', icon: Icons.eco_outlined),
      ]),
      _Day(name: 'Sun', number: '20', events: [
        _Event(name: 'Fern', icon: Icons.water_drop_outlined),
      ]),
    ];

    return Scaffold(
      backgroundColor: surface.bg,
      appBar: AppBar(
        backgroundColor: surface.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: surface.text),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'APR 14 – 20',
              style: TextStyle(fontSize: 11, color: surface.muted, fontWeight: FontWeight.w500, letterSpacing: 0.08 * 11),
            ),
            Text(
              'This week',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: surface.text,
                letterSpacing: -0.02 * 22,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          _RainBanner(surface: surface),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: surface.surface,
              border: Border.all(color: surface.border),
              borderRadius: BorderRadius.circular(PlantlyTokens.radius2xl),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < days.length; i++)
                  _DayRow(day: days[i], surface: surface, last: i == days.length - 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Day {
  _Day({required this.name, required this.number, required this.events, this.today = false});
  final String name;
  final String number;
  final bool today;
  final List<_Event> events;
}

class _Event {
  const _Event({required this.name, required this.icon, this.skip = false});
  final String name;
  final IconData icon;
  final bool skip;
}

class _RainBanner extends StatelessWidget {
  const _RainBanner({required this.surface});
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
        gradient: LinearGradient(
          colors: [surface.greenDeep, surface.green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(PlantlyTokens.radius),
            ),
            child: const Icon(Icons.water_drop_outlined, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SAT · RAIN EXPECTED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.08 * 11,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Skip outdoor watering — we'll reschedule.",
                  style: TextStyle(fontSize: 13, color: Colors.white),
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radiusMd)),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(const SnackBar(content: Text('Applied rain-day schedule skip')));
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.surface, required this.last});
  final _Day day;
  final PlantlySurface surface;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: day.today ? surface.greenSoft : null,
        border: last ? null : Border(bottom: BorderSide(color: surface.border)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: day.today ? surface.green : surface.muted,
                    letterSpacing: 0.1 * 11,
                  ),
                ),
                Text(
                  day.number,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: day.today ? surface.green : surface.text,
                    letterSpacing: -0.02 * 22,
                    height: 1,
                  ),
                ),
                if (day.today)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'TODAY',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: surface.green),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (day.events.isEmpty)
                  Text(
                    'Clear',
                    style: TextStyle(fontSize: 12, color: surface.muted, fontStyle: FontStyle.italic),
                  ),
                for (final e in day.events) ...[
                  _EventRow(event: e, surface: surface),
                  const SizedBox(height: 5),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.surface});
  final _Event event;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: event.skip ? surface.terraSoft : surface.surfaceAlt,
        borderRadius: BorderRadius.circular(PlantlyTokens.radius),
        border: Border.all(color: surface.border),
      ),
      child: Row(
        children: [
          Icon(event.icon, size: 13, color: event.skip ? surface.terra : surface.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              event.name,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: surface.text,
                decoration: event.skip ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (event.skip)
            Text(
              'SKIP',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: surface.terra,
                letterSpacing: 0.06 * 10,
              ),
            ),
        ],
      ),
    );
  }
}
