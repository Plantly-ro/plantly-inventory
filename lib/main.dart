import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme/tokens.dart';

void main() {
  runApp(const ProviderScope(child: PlantlyApp()));
}

/// Theme mode notifier — mirrors the prototype's light/dark toggle in
/// `web/prototype/index.html` (body.light class + __edit_mode_set_keys
/// postMessage). Phase 1 replaces localStorage with a Drift-backed prefs
/// store; the provider API stays the same.
final themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.light);

class PlantlyApp extends ConsumerWidget {
  const PlantlyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'PlantlyInventory',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: const HomeScreen(),
    );
  }

  ThemeData _buildTheme(Brightness b) {
    final surface = b == Brightness.light ? PlantlySurface.light : PlantlySurface.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      scaffoldBackgroundColor: surface.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: PlantlyTokens.botanical500,
        brightness: b,
      ),
      textTheme: GoogleFonts.interTextTheme(
        b == Brightness.light
            ? ThemeData.light().textTheme
            : ThemeData.dark().textTheme,
      ),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final surface =
        mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    return Scaffold(
      backgroundColor: surface.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: PlantlyTokens.space5,
            vertical: PlantlyTokens.space4,
          ),
          children: [
            GreetingWidget(surface: surface),
            const SizedBox(height: PlantlyTokens.space4),
            StatsWidget(surface: surface),
            const SizedBox(height: PlantlyTokens.space6),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () {
                  ref.read(themeModeProvider.notifier).state =
                      mode == ThemeMode.dark
                          ? ThemeMode.light
                          : ThemeMode.dark;
                },
                child: Text(
                  mode == ThemeMode.dark
                      ? 'Use light theme'
                      : 'Use dark theme',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Greeting widget — port of `widgetRegistry.greeting.render` in
/// `web/prototype/components/widgets.jsx`.
class GreetingWidget extends StatelessWidget {
  const GreetingWidget({super.key, required this.surface});
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: surface.greenSoft,
            borderRadius: BorderRadius.circular(PlantlyTokens.radius3xl),
          ),
          alignment: Alignment.center,
          child: Text(
            'AM',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: surface.green,
            ),
          ),
        ),
        const SizedBox(width: PlantlyTokens.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Friday · April 18',
                style: TextStyle(
                  fontSize: PlantlyTokens.textXs,
                  color: surface.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Good morning, Ana',
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
    );
  }
}

class StatTile {
  const StatTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.urgent,
  });
  final String value;
  final String label;
  final IconData icon;
  final bool urgent;
}

/// Stats row — port of `widgetRegistry.stats.render`.
class StatsWidget extends StatelessWidget {
  const StatsWidget({super.key, required this.surface});
  final PlantlySurface surface;

  static const tiles = <StatTile>[
    StatTile(
      value: '2',
      label: 'Overdue',
      icon: Icons.water_drop_outlined,
      urgent: true,
    ),
    StatTile(
      value: '3',
      label: 'Due today',
      icon: Icons.check,
      urgent: false,
    ),
    StatTile(
      value: '24',
      label: 'Plants',
      icon: Icons.eco_outlined,
      urgent: false,
    ),
    StatTile(
      value: '6',
      label: 'Spaces',
      icon: Icons.place_outlined,
      urgent: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: tiles
          .map((t) => StatTileView(tile: t, surface: surface))
          .toList(growable: false),
    );
  }
}

class StatTileView extends StatelessWidget {
  const StatTileView({super.key, required this.tile, required this.surface});
  final StatTile tile;
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
