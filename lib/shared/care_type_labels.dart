import 'package:flutter/widgets.dart';

import '../data/care_types.dart';
import '../l10n/generated/app_localizations.dart';

/// Single source of truth for how a [CareType] is rendered as text.
///
/// The six built-ins (`water`, `fertilize`, `mist`, `repot`, `prune`,
/// `rotate`) are seeded with English labels in `kBuiltInCareTypes`, so
/// rendering `ct.label` raw leaks English on a Romanian device ("Water
/// acum"). Built-ins are identified by their stable `key` + `builtin`
/// flag — never by comparing the English label — and get localized copy
/// UNLESS the user renamed them, in which case their label wins. Custom
/// types always show their own label.
///
/// Three grammatical forms exist because Romanian needs them:
///   - [careTypeLabel]      noun      "Water"   / "Udare"
///   - [careTypeVerb]       imperative "Water"  / "Udă"   (FAB, reminders)
///   - [careTypePastLabel]  past      "Watered" / "Udată" (timeline, chips)
///
/// [appLocalizationsForPlatform] resolves an [AppLocalizations] without a
/// `BuildContext` for code that runs outside the widget tree (local
/// notification scheduling).

/// True when [ct] is a built-in whose label the user has NOT customised —
/// i.e. it still carries the seeded English default (or, defensively, the
/// current locale's noun, so an editor round-trip never counts as a
/// rename).
bool careTypeUsesDefaultLabel(AppLocalizations t, CareType ct) {
  if (!ct.builtin) return false;
  final seeded = _seededLabel(ct.key);
  if (seeded == null) return false;
  return ct.label == seeded || ct.label == _noun(t, ct.key);
}

/// Seeded English label for a built-in key; null for anything custom.
String? _seededLabel(String key) {
  for (final b in kBuiltInCareTypes) {
    if (b.key == key) return b.label;
  }
  return null;
}

/// Canonical label to persist from the care-type editor: if the user typed
/// (or left) the localized default name for a built-in, store the seeded
/// English default so the type keeps localizing (and keeps its verb / past
/// forms) instead of being treated as a rename.
String canonicalCareTypeLabel(AppLocalizations t, CareType ct, String typed) {
  if (!ct.builtin) return typed;
  final seeded = _seededLabel(ct.key);
  if (seeded == null) return typed;
  return typed == _noun(t, ct.key) ? seeded : typed;
}

/// Localized noun for a care type ("Water" / "Udare").
String careTypeLabel(AppLocalizations t, CareType ct) =>
    careTypeUsesDefaultLabel(t, ct) ? _noun(t, ct.key)! : ct.label;

/// Localized imperative for a care type ("Water" / "Udă") — used where the
/// copy tells the user to do the thing now (FAB, Home rows, notifications).
String careTypeVerb(AppLocalizations t, CareType ct) =>
    careTypeUsesDefaultLabel(t, ct) ? _verb(t, ct.key)! : ct.label;

/// Localized past tense for a logged event ("Watered" / "Udată" — the
/// plant is feminine in Romanian). Custom types fall back to their label.
String careTypePastLabel(AppLocalizations t, CareType ct) {
  if (ct.key.isEmpty) return t.homeCareDoneGeneric;
  return careTypeUsesDefaultLabel(t, ct) ? _past(t, ct.key)! : ct.label;
}

/// Key-based conveniences for call sites that hold the registry + a raw
/// `care_events.type` / `care_schedules.type` string.
String careKeyLabel(AppLocalizations t, List<CareType> types, String key) =>
    careTypeLabel(t, resolveCareType(types, key));

String careKeyVerb(AppLocalizations t, List<CareType> types, String key) =>
    careTypeVerb(t, resolveCareType(types, key));

String careKeyPastLabel(AppLocalizations t, List<CareType> types, String key) =>
    careTypePastLabel(t, resolveCareType(types, key));

/// Icon for a raw `care_events.type` / `care_schedules.type` key: the
/// registry entry's (user-editable) icon, or [kUnknownCareTypeIcon] for a
/// key that isn't registered.
IconData careKeyIcon(List<CareType> types, String key) => resolveCareType(types, key).icon;

String? _noun(AppLocalizations t, String key) => switch (key) {
      'water' => t.careTypeWater,
      'fertilize' => t.careTypeFertilize,
      'mist' => t.careTypeMist,
      'repot' => t.careTypeRepot,
      'prune' => t.careTypePrune,
      'rotate' => t.careTypeRotate,
      _ => null,
    };

String? _verb(AppLocalizations t, String key) => switch (key) {
      'water' => t.homeCareWater,
      'fertilize' => t.homeCareFertilize,
      'mist' => t.homeCareMist,
      'repot' => t.homeCareRepot,
      'prune' => t.homeCarePrune,
      'rotate' => t.homeCareRotate,
      _ => null,
    };

String? _past(AppLocalizations t, String key) => switch (key) {
      'water' => t.detailPastWater,
      'fertilize' => t.detailPastFertilize,
      'mist' => t.detailPastMist,
      'repot' => t.detailPastRepot,
      'prune' => t.detailPastPrune,
      'rotate' => t.detailPastRotate,
      _ => null,
    };

/// The locale `MaterialApp` would resolve right now, computed without a
/// `BuildContext`. The app sets no `locale:` override and no custom
/// `localeResolutionCallback`, so this mirrors the framework's default
/// (`basicLocaleListResolution` over the platform's preferred locales).
Locale resolveAppLocale() => basicLocaleListResolution(
      WidgetsBinding.instance.platformDispatcher.locales,
      AppLocalizations.supportedLocales,
    );

/// [AppLocalizations] for [resolveAppLocale] — for notification titles and
/// anything else built outside the widget tree.
AppLocalizations appLocalizationsForPlatform() => lookupAppLocalizations(resolveAppLocale());
