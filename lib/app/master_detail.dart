import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/home_providers.dart';
import '../features/home/home_screen.dart';
import '../features/locations/location_detail_screen.dart';
import '../features/locations/locations_screen.dart';
import '../features/me/me_screen.dart';
import '../features/plant_detail/plant_detail_screen.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/tokens.dart';
import 'breakpoints.dart';
import 'navigation.dart';

/// Desktop two-pane layout: a fixed-width master list on the left, the
/// selected item (or an empty-state hint) on the right. The router keeps
/// one page per section (`/` and `/plants/:id` share a page key), so
/// selecting only rebuilds the detail pane — the list keeps its scroll
/// position and edit state.
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

/// `/` and `/plants/:id` on desktop.
class HomeMasterDetail extends StatelessWidget {
  const HomeMasterDetail({super.key, this.selectedPlantId});
  final String? selectedPlantId;

  @override
  Widget build(BuildContext context) {
    final id = selectedPlantId;
    return MasterDetailScaffold(
      master: const HomeScreen(),
      detail: id == null ? null : PlantDetailScreen(key: ValueKey('plant-$id'), plantId: id),
      emptyIcon: Icons.eco_outlined,
      emptyText: AppLocalizations.of(context).shellSelectPlant,
    );
  }
}

/// `/spaces` and `/spaces/:id` on desktop.
class SpacesMasterDetail extends StatelessWidget {
  const SpacesMasterDetail({super.key, this.selectedLocationId});
  final String? selectedLocationId;

  @override
  Widget build(BuildContext context) {
    final id = selectedLocationId;
    return MasterDetailScaffold(
      master: const LocationsScreen(),
      detail: id == null ? null : LocationDetailScreen(key: ValueKey('space-$id'), locationId: id),
      emptyIcon: Icons.place_outlined,
      emptyText: AppLocalizations.of(context).shellSelectSpace,
    );
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
