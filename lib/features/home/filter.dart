import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';

/// The set of filters a user can apply on the plant grid. Phase 1 ships
/// the three most common — status / location / tag filters plug into the
/// same enum when they land.
enum PlantFilter { all, overdue, dueToday }

extension PlantFilterLabel on PlantFilter {
  /// Localized label — looks up [AppLocalizations] for the current context.
  String label(BuildContext context) {
    final l = AppLocalizations.of(context);
    return switch (this) {
      PlantFilter.all => l.filterAll,
      PlantFilter.overdue => l.filterOverdue,
      PlantFilter.dueToday => l.filterDueToday,
    };
  }
}

final activeFilterProvider = StateProvider<PlantFilter>((_) => PlantFilter.all);

/// Plants filtered by [activeFilterProvider]. Intentionally a derived
/// provider so GridWidget can just watch the output.
final filteredPlantsProvider = Provider<AsyncValue<List<PlantRow>>>((ref) {
  final filter = ref.watch(activeFilterProvider);
  final plants = ref.watch(plantsStreamProvider);
  final schedules = ref.watch(dueBeforeEodProvider);
  return plants.when(
    loading: () => const AsyncLoading(),
    error: AsyncError.new,
    data: (rows) {
      if (filter == PlantFilter.all) return AsyncData(rows);
      return schedules.when(
        loading: () => AsyncData(rows),
        error: (_, _) => AsyncData(rows),
        data: (dueRows) {
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          final matchingIds = switch (filter) {
            PlantFilter.overdue => {
                for (final s in dueRows)
                  if (s.nextDueAt != null && s.nextDueAt! < nowMs) s.plantId,
              },
            PlantFilter.dueToday => {
                for (final s in dueRows)
                  if (s.nextDueAt != null && s.nextDueAt! >= nowMs) s.plantId,
              },
            PlantFilter.all => <String>{},
          };
          return AsyncData(
            rows.where((p) => matchingIds.contains(p.id)).toList(growable: false),
          );
        },
      );
    },
  );
});
