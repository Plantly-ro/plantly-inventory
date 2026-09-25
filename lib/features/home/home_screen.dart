import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/user_prefs.dart';
import '../../theme/tokens.dart';
import '../calendar/calendar_screen.dart';
import '../plant_detail/plant_detail_screen.dart';
import '../../l10n/generated/app_localizations.dart';
import '../locations/locations_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../search/search_screen.dart';
import '../me/me_screen.dart';
import 'add_plant_sheet.dart';
import 'bulk_action_bar.dart';
import 'home_providers.dart';
import 'selection.dart';
import 'widget_registry.dart';

/// Port of `CustomHome` in `web/prototype/components/screens.jsx`.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _editing = false;
  bool _pushedOnboarding = false;

  @override
  Widget build(BuildContext context) {
    final layout = ref.watch(homeLayoutProvider);
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;

    // The DB needs one round-trip to open, load the device id, and seed the
    // fixture plants on first launch — show a lightweight loader until then.
    final bootstrap = ref.watch(appContextProvider);

    // First-run gate: once prefs have loaded and the user hasn't seen the
    // onboarding, push it on the next frame. Guarded by `_pushedOnboarding`
    // so rebuilds don't re-push, and by `loaded` so we don't flash
    // onboarding against the default-false initial state.
    final prefs = ref.watch(userPrefsProvider);
    if (!_pushedOnboarding && prefs.loaded && !prefs.onboardingSeen) {
      _pushedOnboarding = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const OnboardingScreen(), fullscreenDialog: true),
        );
      });
    }

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
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ref.watch(plantSelectionProvider).isNotEmpty)
                  BulkActionBar(surface: surface),
                _TabBar(
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
                ),
              ],
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
          data: (_) {
            final hasPlants = ref.watch(plantsStreamProvider).maybeWhen(
                  data: (rows) => rows.isNotEmpty,
                  orElse: () => true, // assume has plants while loading
                );
            // No banner on web: there's no permission to grant, and the Me
            // screen already says reminders are unavailable there.
            final permDenied = ref.watch(notificationPermissionProvider) == false &&
                ref.watch(notificationServiceProvider).isSupported;
            return Column(
              children: [
                _EditToggleBar(
                  editing: _editing,
                  surface: surface,
                  onDone: () => setState(() => _editing = false),
                ),
                if (permDenied) _NotificationPermissionBanner(surface: surface),
                Expanded(
                  child: GestureDetector(
                    // Long-pressing the home body toggles edit mode —
                    // replaces the old "✎ Customize home" button.
                    onLongPress: () => setState(() => _editing = !_editing),
                    behavior: HitTestBehavior.deferToChild,
                    child: RefreshIndicator(
                    onRefresh: () async {
                      // Drift streams are already live; the pull gesture
                      // is a UX affordance, not a data fetch. Hold for a
                      // short tick so the spinner is visible.
                      await ref.read(reminderSyncProvider).syncFromDatabase();
                      await Future<void>.delayed(const Duration(milliseconds: 250));
                    },
                    color: surface.green,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 6, bottom: 96),
                      children: [
                        if (!hasPlants) _FirstRunCallout(surface: surface),
                        if (!_editing) _EditHint(surface: surface),
                        for (var i = 0; i < layout.length; i++)
                          _renderWidget(layout[i], i, layout.length, surface),
                        if (_editing) _EditPanel(surface: surface, current: layout),
                      ],
                    ),
                  ),
                  ),
                ),
              ],
            );
          },
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
  const _EditToggleBar({required this.editing, required this.surface, required this.onDone});
  final bool editing;
  final PlantlySurface surface;
  final VoidCallback onDone;

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
          if (editing)
            InkWell(
              onTap: onDone,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: surface.green,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '✓ ${AppLocalizations.of(context).doneBtn}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Subtle first-time hint. Shown on Home when not in edit mode so
/// users discover the long-press-to-customize gesture. Vanishes once
/// they've tried it.
class _EditHint extends StatelessWidget {
  const _EditHint({required this.surface});
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    // Would be nicer stored in prefs and dismissed after first long-press,
    // but this is fine for now — low-contrast, not obstructive.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: Row(
        children: [
          Icon(Icons.touch_app_outlined, size: 12, color: surface.muted),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Long-press to customise your home',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: surface.muted, fontStyle: FontStyle.italic),
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
            style: TextStyle(fontFamily: PlantlyFonts.inter, 
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

class _FirstRunCallout extends StatelessWidget {
  const _FirstRunCallout({required this.surface});
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface.greenSoft,
          borderRadius: BorderRadius.circular(PlantlyTokens.radius2xl),
          border: Border.all(color: surface.green),
        ),
        child: Row(
          children: [
            Icon(Icons.eco_outlined, color: surface.green),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No plants yet',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: surface.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap the + button to add your first plant. You can set up reminders once it lands.',
                    style: TextStyle(fontSize: 12, color: surface.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationPermissionBanner extends ConsumerWidget {
  const _NotificationPermissionBanner({required this.surface});
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: surface.terraSoft,
      child: InkWell(
        onTap: () async {
          final ok = await ref.read(notificationServiceProvider).requestPermissions();
          ref.read(notificationPermissionProvider.notifier).state = ok;
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.notifications_off_outlined, size: 16, color: surface.terra),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Notifications are off — reminders won\'t fire. Tap to enable.',
                  style: TextStyle(fontSize: 12, color: surface.terra, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: surface.terra),
            ],
          ),
        ),
      ),
    );
  }
}
