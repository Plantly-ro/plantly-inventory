import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../cloud/collections.dart';
import '../features/collections/collection_switcher.dart';
import '../features/home/add_plant_sheet.dart';
import '../features/home/home_providers.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/tokens.dart';
import 'breakpoints.dart';
import 'navigation.dart';
import 'shortcuts.dart';
import 'side_sheet.dart';

/// Adaptive chrome around the routed content (`ShellRoute` builder).
///
/// * phone   — passes [child] through untouched; screens keep today's
///             bottom tab bar / FAB / back chevrons.
/// * tablet  — 72 px [NavigationRail] (labels on the selected item) with an
///             "Add plant" FAB in the leading slot.
/// * desktop — 240 px side nav (logo, sections, primary "Add plant"),
///             content column centred at ≤ 1280 px with 24–32 px gutters.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.location,
    required this.shellNavigatorKey,
    required this.child,
  });

  /// Current `GoRouterState.uri.path` — drives the selected nav item.
  final String location;
  final GlobalKey<NavigatorState> shellNavigatorKey;
  final Widget child;

  static int sectionIndexFor(String path) {
    if (path == AppRoutes.calendar) return 1;
    if (path == AppRoutes.spaces || path.startsWith('/spaces/')) return 2;
    if (path == AppRoutes.me || path.startsWith('/me/')) return 3;
    return 0;
  }

  static const List<String> _sectionPaths = [AppRoutes.home, AppRoutes.calendar, AppRoutes.spaces, AppRoutes.me];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.formFactor;
    if (ff == FormFactor.phone) return child;

    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final t = AppLocalizations.of(context);
    final selected = sectionIndexFor(location);
    final width = MediaQuery.sizeOf(context).width;
    // Viewer of a shared collection (MULTI-USER-V2 §3): no primary add action.
    final canEdit = ref.watch(canEditActiveCollectionProvider);

    void select(int i) => context.go(_sectionPaths[i]);
    void addPlant() => showAdaptiveSheet<void>(
          context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const AddPlantSheet(),
        );

    final items = <_NavItem>[
      _NavItem(Icons.home_outlined, Icons.home, t.navHome),
      _NavItem(Icons.calendar_today_outlined, Icons.calendar_today, t.navCalendar),
      _NavItem(Icons.place_outlined, Icons.place, t.navSpaces),
      _NavItem(Icons.person_outline, Icons.person, t.navMe),
    ];

    final Widget body;
    if (ff == FormFactor.tablet) {
      body = Row(
        children: [
          NavigationRail(
            minWidth: Breakpoints.railWidth,
            backgroundColor: surface.surface,
            indicatorColor: surface.greenSoft,
            selectedIconTheme: IconThemeData(color: surface.green),
            unselectedIconTheme: IconThemeData(color: surface.muted),
            selectedLabelTextStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: surface.green),
            unselectedLabelTextStyle: TextStyle(fontSize: 11, color: surface.muted),
            labelType: NavigationRailLabelType.selected,
            selectedIndex: selected,
            onDestinationSelected: select,
            leading: canEdit ? Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: FloatingActionButton.small(
                heroTag: 'shell-add-plant',
                backgroundColor: surface.green,
                foregroundColor: Colors.white,
                tooltip: t.addPlant,
                onPressed: addPlant,
                child: const Icon(Icons.add),
              ),
            ) : null,
            destinations: [
              for (final it in items)
                NavigationRailDestination(
                  icon: Icon(it.icon),
                  selectedIcon: Icon(it.selectedIcon),
                  label: Text(it.label),
                ),
            ],
          ),
          VerticalDivider(width: 1, thickness: 1, color: surface.border),
          Expanded(child: child),
        ],
      );
    } else {
      final gutter = Breakpoints.gutterFor(width);
      body = Row(
        children: [
          _SideNav(items: items, selected: selected, surface: surface, onSelect: select, onAddPlant: canEdit ? addPlant : null),
          VerticalDivider(width: 1, thickness: 1, color: surface.border),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: Breakpoints.contentMaxWidth),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return AppShortcuts(
      shellNavigatorKey: shellNavigatorKey,
      child: Material(color: surface.bg, child: body),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.selectedIcon, this.label);
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _SideNav extends StatelessWidget {
  const _SideNav({
    required this.items,
    required this.selected,
    required this.surface,
    required this.onSelect,
    required this.onAddPlant,
  });
  final List<_NavItem> items;
  final int selected;
  final PlantlySurface surface;
  final ValueChanged<int> onSelect;
  /// Null hides the primary add-plant button (read-only collection).
  final VoidCallback? onAddPlant;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(
      width: Breakpoints.sideNavWidth,
      color: surface.surface,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: surface.green,
                  borderRadius: BorderRadius.circular(PlantlyTokens.radius),
                ),
                child: const Icon(Icons.eco, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plantly',
                      style: TextStyle(
                        fontFamily: PlantlyFonts.plusJakartaSans,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: surface.text,
                        letterSpacing: -0.02 * 17,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'Inventory',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: surface.muted, height: 1.1),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Shared collections (§3): hidden with 0/1 collection.
          CollectionSwitcherDropdown(surface: surface),
          const SizedBox(height: 20),
          if (onAddPlant != null) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: surface.green,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radius)),
              ),
              onPressed: onAddPlant,
              icon: const Icon(Icons.add, size: 18),
              label: Text(t.addPlant, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 20),
          ],
          for (var i = 0; i < items.length; i++) ...[
            _SideNavTile(item: items[i], active: i == selected, surface: surface, onTap: () => onSelect(i)),
            const SizedBox(height: 2),
          ],
        ],
      ),
    );
  }
}

class _SideNavTile extends StatelessWidget {
  const _SideNavTile({required this.item, required this.active, required this.surface, required this.onTap});
  final _NavItem item;
  final bool active;
  final PlantlySurface surface;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? surface.green : surface.muted;
    return Material(
      color: active ? surface.greenSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(PlantlyTokens.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PlantlyTokens.radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(active ? item.selectedIcon : item.icon, size: 20, color: color),
              const SizedBox(width: 12),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  color: active ? surface.text : surface.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
