import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/mock_plants.dart';
import '../../data/providers.dart';
import '../../theme/tokens.dart';
import '../calendar/calendar_screen.dart';
import '../plant_detail/plant_detail_screen.dart';
import '../search/search_screen.dart';
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
      body: SafeArea(
        child: bootstrap.when(
          loading: () => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: surface.green),
                const SizedBox(height: 12),
                Text('Opening your garden…', style: TextStyle(color: surface.muted)),
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
                  padding: const EdgeInsets.only(top: 6, bottom: 24),
                  children: [
                    for (var i = 0; i < layout.length; i++)
                      _renderWidget(layout[i], i, layout.length, surface),
                    if (_editing) _EditPanel(surface: surface, current: layout),
                  ],
                ),
              ),
              _TabBar(
                surface: surface,
                onCalendar: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CalendarScreen()),
                  );
                },
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

  void _openPlantDetail(MockPlant plant) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlantDetailScreen(plantId: plant.id)),
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
                editing ? '✓ Done' : '✎ Customize home',
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
    final available = WidgetRegistry.entries.entries
        .where((e) => !current.contains(e.key))
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(PlantlyTokens.space5, 0, PlantlyTokens.space5, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('ADD WIDGET', surface.green, surface),
          const SizedBox(height: 8),
          if (available.isEmpty)
            Text(
              'All widgets are on the home screen.',
              style: TextStyle(fontSize: 12, color: surface.muted),
            )
          else
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 4.2,
              children: [
                for (final e in available)
                  _AddButton(entry: e.value, surface: surface, onTap: () {
                    ref.read(homeLayoutProvider.notifier).add(e.key);
                  }),
              ],
            ),
          const SizedBox(height: 16),
          _sectionLabel('OR START FROM A PRESET', surface.muted, surface),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(entry.icon, size: 14, color: surface.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: surface.text),
                ),
              ),
              Text('+', style: TextStyle(color: surface.green, fontSize: 16, fontWeight: FontWeight.w800)),
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
  const _TabBar({required this.surface, required this.onCalendar});
  final PlantlySurface surface;
  final VoidCallback onCalendar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border(top: BorderSide(color: surface.border)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
      child: Row(
        children: [
          _TabIcon(icon: Icons.home_outlined, label: 'Home', active: true, surface: surface),
          _TabIcon(icon: Icons.calendar_today_outlined, label: 'Calendar', onTap: onCalendar, surface: surface),
          _TabIcon(icon: Icons.place_outlined, label: 'Spaces', surface: surface),
          _TabIcon(icon: Icons.person_outline, label: 'Me', surface: surface),
        ],
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
    return Expanded(
      child: InkWell(
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
      ),
    );
  }
}
