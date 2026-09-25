import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/app_database.dart';
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';

/// Plant grid sort modes. Serialised by index into SharedPreferences so
/// the user's choice persists across restarts.
enum PlantSort {
  nameAZ,
  nameZA,
  nextDue,
  newestAdded,
  oldestAdded,
  byLocation,
}

extension PlantSortLabel on PlantSort {
  /// Localized label — looks up [AppLocalizations] for the current context.
  String label(BuildContext context) {
    final l = AppLocalizations.of(context);
    return switch (this) {
      PlantSort.nameAZ => l.homeSortNameAZ,
      PlantSort.nameZA => l.homeSortNameZA,
      PlantSort.nextDue => l.homeSortNextDue,
      PlantSort.newestAdded => l.homeSortNewest,
      PlantSort.oldestAdded => l.homeSortOldest,
      PlantSort.byLocation => l.homeSortBySpace,
    };
  }
}

class PlantSortController extends StateNotifier<PlantSort> {
  PlantSortController(this._prefs) : super(PlantSort.nameAZ) {
    _load();
  }
  static const _key = 'plantly_plant_sort';
  final Future<SharedPreferences> _prefs;

  Future<void> _load() async {
    final prefs = await _prefs;
    final i = prefs.getInt(_key);
    if (i != null && i >= 0 && i < PlantSort.values.length) {
      state = PlantSort.values[i];
    }
  }

  Future<void> set(PlantSort next) async {
    state = next;
    final prefs = await _prefs;
    await prefs.setInt(_key, next.index);
  }
}

final plantSortProvider =
    StateNotifierProvider<PlantSortController, PlantSort>((ref) {
  return PlantSortController(ref.watch(sharedPreferencesProvider.future));
});

/// Apply [sort] to [plants]. [earliestDueByPlantId] is the pre-computed
/// nearest `next_due_at` per plant (for the `nextDue` mode), and
/// [locationNameById] maps the location id onto its display name (for
/// the `byLocation` mode).
List<PlantRow> sortPlants({
  required List<PlantRow> plants,
  required PlantSort sort,
  required Map<String, int> earliestDueByPlantId,
  required Map<String, String> locationNameById,
}) {
  final copy = [...plants];
  int locationCompare(PlantRow a, PlantRow b) {
    final an = a.locationId == null ? 'zzz' : (locationNameById[a.locationId] ?? 'zzz');
    final bn = b.locationId == null ? 'zzz' : (locationNameById[b.locationId] ?? 'zzz');
    return an.toLowerCase().compareTo(bn.toLowerCase());
  }
  switch (sort) {
    case PlantSort.nameAZ:
      copy.sort((a, b) => a.nickname.toLowerCase().compareTo(b.nickname.toLowerCase()));
      break;
    case PlantSort.nameZA:
      copy.sort((a, b) => b.nickname.toLowerCase().compareTo(a.nickname.toLowerCase()));
      break;
    case PlantSort.nextDue:
      const sentinel = 1 << 62;
      copy.sort((a, b) =>
          (earliestDueByPlantId[a.id] ?? sentinel).compareTo(earliestDueByPlantId[b.id] ?? sentinel));
      break;
    case PlantSort.newestAdded:
      copy.sort((a, b) => (b.acquiredAt ?? 0).compareTo(a.acquiredAt ?? 0));
      break;
    case PlantSort.oldestAdded:
      copy.sort((a, b) {
        final ax = a.acquiredAt;
        final bx = b.acquiredAt;
        if (ax == null && bx == null) return 0;
        if (ax == null) return 1;
        if (bx == null) return -1;
        return ax.compareTo(bx);
      });
      break;
    case PlantSort.byLocation:
      copy.sort(locationCompare);
      break;
  }
  return copy;
}
