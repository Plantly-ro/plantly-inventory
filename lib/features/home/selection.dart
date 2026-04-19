import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Set of currently-selected plant ids across the grid. An empty set
/// means "not in selection mode" — the grid renders normally. A
/// non-empty set switches the grid into checkbox mode and shows the
/// bulk-action bar.
class PlantSelectionController extends StateNotifier<Set<String>> {
  PlantSelectionController() : super(const <String>{});

  bool get isActive => state.isNotEmpty;

  void toggle(String plantId) {
    final next = {...state};
    if (!next.add(plantId)) next.remove(plantId);
    state = next;
  }

  void selectAll(Iterable<String> plantIds) {
    state = {...state, ...plantIds};
  }

  void clear() {
    state = const <String>{};
  }
}

final plantSelectionProvider =
    StateNotifierProvider<PlantSelectionController, Set<String>>((ref) {
  return PlantSelectionController();
});
