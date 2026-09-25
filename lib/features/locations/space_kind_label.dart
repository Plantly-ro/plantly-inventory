import '../../l10n/generated/app_localizations.dart';

/// Human label for a `locations.kind` value. Kinds are stored as raw
/// enum strings (`home`, `room`, `zone`, `shelf`, `outdoor_bed`); this is
/// the single place that maps them to localized copy so rows never show
/// the raw key. Unknown kinds fall through to the stored value.
String spaceKindLabel(AppLocalizations t, String kind) {
  return switch (kind) {
    'home' => t.spaceKindHome,
    'room' => t.spaceKindRoom,
    'zone' => t.spaceKindZone,
    'shelf' => t.spaceKindShelf,
    'outdoor_bed' => t.spaceKindOutdoorBed,
    _ => kind,
  };
}

/// Localized label for a `locations.light` value (`bright direct`,
/// `bright indirect`, `medium`, `low`). Unknown values pass through.
String spaceLightLabel(AppLocalizations t, String light) {
  return switch (light) {
    'bright direct' => t.spaceLightBrightDirect,
    'bright indirect' => t.spaceLightBrightIndirect,
    'medium' => t.spaceLightMedium,
    'low' => t.spaceLightLow,
    _ => light,
  };
}
