import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/providers.dart';
import '../../theme/tokens.dart';
import '../calendar/calendar_screen.dart';
import '../plant_detail/plant_detail_screen.dart';
import '../../l10n/generated/app_localizations.dart';
import '../locations/locations_screen.dart';
import '../search/search_screen.dart';
import '../me/me_screen.dart';
import 'add_plant_sheet.dart';
import 'home_providers.dart';
import 'widget_registry.dart';

/// Port of `CustomHome` in `web/prototype/components/screens.jsx`.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final layout = ref.watch(homeLayoutProvider);
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;

    // The DB needs one round-trip to open, load the device id, and seed the
    // fixture plants on first launch — show a lightweight loader until then.
    final bootstrap = ref.watch(appContextProvider);

    return Scaffold(
      backgroundColor: surface.bg,
      floatingActionButton: bootstrap.hasValue
          ? FloatingActionButton(
              backgroundColor: surface.green,
              foregroundColor: Colors.white,
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const AddPlantSheet(),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: bootstrap.hasValue
          ? _TabBar(
              surface: surface,
              onCalendar: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CalendarScreen()),
                );
              },
              onMe: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MeScreen()),
                );
              },
            )
          : null,
      body: SafeArea(
        child: bootstrap.when(
          loading: () => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: surface.green),
                const SizedBox(height: 12),
                Text(AppLocalizations.of(context).openingGarden, style: TextStyle(color: surface.muted)),
              ],
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to open local database.\n$e',
              style: TextStyle(color: surface.terra),
            ),
          ),
          data: (_) => Column(
            children: [
              _EditToggleBar(
                editing: _editing,
                surface: surface,
                onTap: () => setState(() => _editing = !_editing),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 6, bottom: 96),
                  children: [
                    for (var i = 0; i < layout.length; i++)
                      _renderWidget(layout[i], i, layout.length, surface),
                    if (_editing) _EditPanel(surface: surface, current: layout),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _renderWidget(String key, int index, int total, PlantlySurface surface) {
    final entry = WidgetRegistry.entries[key];
    if (entry == null) return const SizedBox.shrink();
    return entry.render(
      WidgetRenderParams(
        surface: surface,
        editing: _editing,
        onMoveUp: () => ref.read(homeLayoutProvider.notifier).move(index, -1),
        onMoveDown: () => ref.read(homeLayoutProvider.notifier).move(index, 1),
        onRemove: () => ref.read(homeLayoutProvider.notifier).remove(index),
        onPlantTap: _openPlantDetail,
        onToast: _toast,
      ),
    );
  }

  void _openPlantDetail(String plantId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlantDetailScreen(plantId: plantId)),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1800)));
  }
}

class _EditToggleBar extends StatelessWidget {
  const _EditToggleBar({required this.editing, required this.surface, required this.onTap});
  final bool editing;
  final PlantlySurface surface;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.search, color: surface.muted),
            tooltip: 'Search plants',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
          const Spacer(),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: editing ? surface.green : surface.surface,
                border: Border.all(color: editing ? surface.green : surface.border),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                editing
                    ? '✓ ${AppLocalizations.of(context).doneBtn}'
                    : '✎ ${AppLocalizations.of(context).customizeHome}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: editing ? Colors.white : surface.muted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditPanel extends ConsumerWidget {
  const _EditPanel({required this.surface, required this.current});
  final PlantlySurface surface;
  final List<String> current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Every widget that isn't currently on the home screen.
    final available = WidgetRegistry.entries.entries
        .where((e) => !current.contains(e.key))
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(PlantlyTokens.space5, 0, PlantlyTokens.space5, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionLabel('ADD WIDGET', surface.green, surface),
          const SizedBox(height: 8),
          if (available.isEmpty)
            _FullPanel(surface: surface)
          else
            // Single-column list of full-width taps — was a 2-col grid before
            // with a 4.2 aspect ratio which made hit-targets tiny on phones.
            Column(
              children: [
                for (final e in available) ...[
                  _AddButton(
                    entry: e.value,
                    surface: surface,
                    onTap: () => ref.read(homeLayoutProvider.notifier).add(e.key),
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          const SizedBox(height: 16),
          _sectionLabel('PRESETS', surface.muted, surface),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final p in WidgetRegistry.presets)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _PresetChip(
                      preset: p,
                      surface: surface,
                      onTap: () => ref.read(homeLayoutProvider.notifier).applyPreset(p),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: surface.muted,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: Icon(Icons.restart_alt, size: 14, color: surface.muted),
              label: Text(
                'Reset to default',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: surface.muted),
              ),
              onPressed: () => ref.read(homeLayoutProvider.notifier).reset(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, Color color, PlantlySurface surface) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.1 * 11,
      ),
    );
  }
}

class _FullPanel extends StatelessWidget {
  const _FullPanel({required this.surface});
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(PlantlyTokens.radius),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: surface.green),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Every widget is already on your home screen. Apply a preset below to reshuffle.',
              style: TextStyle(fontSize: 12, color: surface.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.entry, required this.surface, required this.onTap});
  final WidgetEntry entry;
  final PlantlySurface surface;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface.surface,
      borderRadius: BorderRadius.circular(PlantlyTokens.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PlantlyTokens.radius),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PlantlyTokens.radius),
            border: Border.all(color: surface.border, style: BorderStyle.solid),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: surface.greenSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(entry.icon, size: 14, color: surface.green),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.label,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: surface.text),
                ),
              ),
              Text('+ Add',
                  style: TextStyle(color: surface.green, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.preset, required this.surface, required this.onTap});
  final LayoutPreset preset;
  final PlantlySurface surface;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: surface.border),
          ),
          child: Text(
            preset.name,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: surface.text),
          ),
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.surface, required this.onCalendar, required this.onMe});
  final PlantlySurface surface;
  final VoidCallback onCalendar;
  final VoidCallback onMe;

  @override
  Widget build(BuildContext context) {
    // Leaves a gap in the middle so the docked FAB doesn't sit on any tab.
    return Container(
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border(top: BorderSide(color: surface.border)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(child: _TabIcon(icon: Icons.home_outlined, label: 'Home', active: true, surface: surface)),
            Expanded(child: _TabIcon(icon: Icons.calendar_today_outlined, label: 'Calendar', onTap: onCalendar, surface: surface)),
            const SizedBox(width: 72),
            Expanded(
              child: _TabIcon(
                icon: Icons.place_outlined,
                label: 'Spaces',
                surface: surface,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LocationsScreen()),
                ),
              ),
            ),
            Expanded(child: _TabIcon(icon: Icons.person_outline, label: 'Me', surface: surface, onTap: onMe)),
          ],
        ),
      ),
    );
  }
}

class _TabIcon extends StatelessWidget {
  const _TabIcon({
    required this.icon,
    required this.label,
    required this.surface,
    this.active = false,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final PlantlySurface surface;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? surface.green : surface.muted;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
