import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/home_dashboard.dart';
import '../features/home/home_providers.dart';
import '../features/locations/location_detail_screen.dart';
import '../features/locations/locations_screen.dart';
import '../features/me/me_screen.dart';
import '../features/plant_detail/plant_detail_screen.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/tokens.dart';
import 'breakpoints.dart';
import 'navigation.dart';

/// Desktop two-pane layout: a fixed-width master list on the left, the
/// selected item (or an empty-state hint) on the right. Used by Me only
/// (settings shape); Home and Spaces are full-width pages (§0). The router
/// keeps one page per section (`/me` and `/me/:section` share a page key),
/// so selecting only rebuilds the detail pane — the list keeps its scroll
/// position.
class MasterDetailScaffold extends ConsumerWidget {
  const MasterDetailScaffold({
    super.key,
    required this.master,
    required this.detail,
    required this.emptyIcon,
    required this.emptyText,
  });

  final Widget master;
  final Widget? detail;
  final IconData emptyIcon;
  final String emptyText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    return Material(
      color: surface.bg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: Breakpoints.masterPaneWidth, child: master),
          VerticalDivider(width: 1, thickness: 1, color: surface.border),
          Expanded(
            child: detail ??
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(emptyIcon, size: 40, color: surface.border),
                      const SizedBox(height: 12),
                      Text(emptyText, style: TextStyle(fontSize: 14, color: surface.muted)),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

/// `/` and `/plants/:id` on desktop (DESKTOP-POLISH §0): the dashboard
/// uses the whole content column, and a selected plant swaps it for the
/// full-width two-column detail. The router keeps both URLs on one page
/// key, so this is an in-place swap without a transition.
class HomeDesktopPage extends StatelessWidget {
  const HomeDesktopPage({super.key, this.selectedPlantId});
  final String? selectedPlantId;

  @override
  Widget build(BuildContext context) {
    final id = selectedPlantId;
    if (id == null) return const HomeDashboard();
    return PlantDetailScreen(key: ValueKey('plant-$id'), plantId: id);
  }
}

/// `/spaces` and `/spaces/:id` on desktop — same shape as [HomeDesktopPage].
class SpacesDesktopPage extends StatelessWidget {
  const SpacesDesktopPage({super.key, this.selectedLocationId});
  final String? selectedLocationId;

  @override
  Widget build(BuildContext context) {
    final id = selectedLocationId;
    if (id == null) return const LocationsScreen();
    return LocationDetailScreen(key: ValueKey('space-$id'), locationId: id);
  }
}

/// `/me` and `/me/:section` on desktop.
class MeMasterDetail extends StatelessWidget {
  const MeMasterDetail({super.key, this.section});
  final String? section;

  @override
  Widget build(BuildContext context) {
    final s = section;
    final screen = s == null ? null : meSectionScreen(s);
    return MasterDetailScaffold(
      master: const MeScreen(),
      detail: screen == null ? null : KeyedSubtree(key: ValueKey('me-$s'), child: screen),
      emptyIcon: Icons.person_outline,
      emptyText: AppLocalizations.of(context).shellSelectSection,
    );
  }
}
