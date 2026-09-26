import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';

/// Status filter: mirrors the top-row chips.
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

/// Optional secondary filter: limit plants to one location. `null` =
/// no location restriction.
final activeLocationFilterProvider = StateProvider<String?>((_) => null);

/// Optional secondary filter: limit plants to one tag. `null` = no
/// tag restriction. Uses the tag's id (not name).
final activeTagFilterProvider = StateProvider<String?>((_) => null);

/// Plants matching every active filter. Intentionally a derived
/// provider so GridWidget can just watch the output.
final filteredPlantsProvider = Provider<AsyncValue<List<PlantRow>>>((ref) {
  final filter = ref.watch(activeFilterProvider);
  final locationId = ref.watch(activeLocationFilterProvider);
  final tagId = ref.watch(activeTagFilterProvider);
  final plants = ref.watch(plantsStreamProvider);
  final schedules = ref.watch(dueBeforeEodProvider);
  // Plant ids carrying the selected tag — null when no tag filter.
  final tagPlantIds = tagId == null
      ? null
      : ref.watch(_plantsWithTagProvider(tagId)).maybeWhen(
            data: (ids) => ids.toSet(),
            orElse: () => const <String>{},
          );
  return plants.when(
    loading: () => const AsyncLoading(),
    error: AsyncError.new,
    data: (rows) {
      Iterable<PlantRow> applied = rows;
      if (locationId != null) {
        applied = applied.where((p) => p.locationId == locationId);
      }
      if (tagPlantIds != null) {
        applied = applied.where((p) => tagPlantIds.contains(p.id));
      }
      if (filter != PlantFilter.all) {
        return schedules.when(
          loading: () => AsyncData(applied.toList(growable: false)),
          error: (_, _) => AsyncData(applied.toList(growable: false)),
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
              applied.where((p) => matchingIds.contains(p.id)).toList(growable: false),
            );
          },
        );
      }
      return AsyncData(applied.toList(growable: false));
    },
  );
});

/// Live set of plant ids whose live tag-attachments include [tagId].
final _plantsWithTagProvider =
    StreamProvider.family<List<String>, String>((ref, tagId) {
  final ctx = ref.watch(appContextProvider).requireValue;
  final stream = ctx.db.select(ctx.db.plantTags).watch();
  return stream.map((rows) {
    // Keep the OR-set semantics: a (plant, tag) is live if its max
    // added_hlc outranks every removed_hlc.
    final grouped = <String, List<PlantTagRow>>{};
    for (final r in rows) {
      if (r.tenantId != ctx.opLog.tenantId) continue;
      if (r.tagId != tagId) continue;
      grouped.putIfAbsent(r.plantId, () => []).add(r);
    }
    final out = <String>[];
    for (final entry in grouped.entries) {
      final live = entry.value.where((r) => r.removedHlc == null).toList();
      if (live.isEmpty) continue;
      final maxAdd = live.map((r) => r.addedHlc).reduce((a, b) => a.compareTo(b) > 0 ? a : b);
      final tombs = entry.value.where((r) => r.removedHlc != null).map((r) => r.removedHlc!).toList();
      final maxTomb = tombs.isEmpty ? null : tombs.reduce((a, b) => a.compareTo(b) > 0 ? a : b);
      if (maxTomb == null || maxAdd.compareTo(maxTomb) > 0) out.add(entry.key);
    }
    return out;
  });
});
