import '../../../l10n/generated/app_localizations.dart';

/// Localized imperative label for a built-in care type key (`water` →
/// "Water" / "Udă"). Custom keys fall back to [fallback], or the raw key.
String careVerb(AppLocalizations t, String type, {String? fallback}) {
  return switch (type) {
    'water' => t.homeCareWater,
    'fertilize' => t.homeCareFertilize,
    'mist' => t.homeCareMist,
    'repot' => t.homeCareRepot,
    'prune' => t.homeCarePrune,
    'rotate' => t.homeCareRotate,
    _ => fallback ?? type,
  };
}

/// Localized past-tense / noun label for a logged care event (`water` →
/// "Watered" / "Udare"). Custom keys fall back to a capitalised key.
String carePastLabel(AppLocalizations t, String type) {
  return switch (type) {
    'water' => t.homeCareDoneWater,
    'fertilize' => t.homeCareDoneFertilize,
    'mist' => t.homeCareDoneMist,
    'repot' => t.homeCareDoneRepot,
    'prune' => t.homeCareDonePrune,
    'rotate' => t.homeCareDoneRotate,
    _ => type.isEmpty ? t.homeCareDoneGeneric : '${type[0].toUpperCase()}${type.substring(1)}',
  };
}
