import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/providers.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';

/// "Me" tab — settings surface. Phase 1 only wires the theme toggle; more
/// preferences (notifications, backup, sync, localisation) land as the
/// corresponding features ship.
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final plants = ref.watch(plantsStreamProvider).maybeWhen(
          data: (rows) => rows.length,
          orElse: () => null,
        );
    final locations = ref.watch(locationsStreamProvider).maybeWhen(
          data: (rows) => rows.length,
          orElse: () => null,
        );

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
          'Me',
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
          _StatCard(surface: surface, plants: plants, locations: locations),
          const SizedBox(height: 20),
          _SectionLabel(text: 'APPEARANCE', surface: surface),
          const SizedBox(height: 8),
          _ThemeToggleRow(mode: mode, surface: surface),
          const SizedBox(height: 20),
          _SectionLabel(text: 'ABOUT', surface: surface),
          const SizedBox(height: 8),
          _ReadOnlyRow(
            label: 'App',
            value: 'PlantlyInventory · Phase 1',
            icon: Icons.info_outline,
            surface: surface,
          ),
          const SizedBox(height: 8),
          _ReadOnlyRow(
            label: 'License',
            value: 'AGPL-3.0-or-later',
            icon: Icons.description_outlined,
            surface: surface,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.surface, required this.plants, required this.locations});
  final PlantlySurface surface;
  final int? plants;
  final int? locations;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
      ),
      child: Row(
        children: [
          Expanded(child: _StatCol(label: 'PLANTS', value: plants?.toString() ?? '…', surface: surface)),
          Container(width: 1, height: 40, color: surface.border),
          Expanded(child: _StatCol(label: 'SPACES', value: locations?.toString() ?? '…', surface: surface)),
        ],
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  const _StatCol({required this.label, required this.value, required this.surface});
  final String label;
  final String value;
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

class _ThemeToggleRow extends ConsumerWidget {
  const _ThemeToggleRow({required this.mode, required this.surface});
  final ThemeMode mode;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = mode == ThemeMode.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(PlantlyTokens.radius),
      ),
      child: Row(
        children: [
          Icon(isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined, color: surface.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text),
                ),
                Text(
                  isDark ? 'Dark' : 'Light',
                  style: TextStyle(fontSize: 12, color: surface.muted),
                ),
              ],
            ),
          ),
          Switch(
            value: isDark,
            activeThumbColor: surface.green,
            onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 2),
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

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.surface,
  });
  final String label;
  final String value;
  final IconData icon;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(PlantlyTokens.radius),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: surface.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text),
                ),
                Text(value, style: TextStyle(fontSize: 12, color: surface.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
