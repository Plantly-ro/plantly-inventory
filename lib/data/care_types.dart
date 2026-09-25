import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers.dart';

/// One entry in the user-editable care-type registry. `key` is the raw
/// string persisted in `care_events.type` / `care_schedules.type` — it's
/// stable across sessions so the DB schema never needs a migration when
/// a user renames a type. `label` is what the UI renders.
///
/// Built-in types (`water`, `fertilize`, `mist`, `repot`, `prune`,
/// `rotate`) can be renamed or hidden but their `key` stays so older
/// care events / schedules keep resolving to them.
class CareType {
  const CareType({
    required this.key,
    required this.label,
    required this.iconCode,
    required this.defaultIntervalDays,
    this.colorValue,
    this.builtin = false,
  });

  final String key;
  final String label;
  /// Material icon codepoint (e.g. `Icons.water_drop_outlined.codePoint`).
  final int iconCode;
  /// Starting interval when the user adds a reminder of this type. Stored
  /// as days — UI lets the user re-express as minutes/hours/days/months.
  final double defaultIntervalDays;
  /// ARGB32 colour used as the chip fill for this type in Upcoming Care,
  /// Calendar dots, Timeline icons. Null falls back to the per-theme
  /// green/terra palette.
  final int? colorValue;
  final bool builtin;

  IconData get icon => kCareIconByCodePoint[iconCode] ?? Icons.notifications_active_outlined;
  Color? get color => colorValue == null ? null : Color(colorValue!);

  CareType copyWith({
    String? label,
    int? iconCode,
    double? defaultIntervalDays,
    int? colorValue,
    bool? clearColor,
  }) =>
      CareType(
        key: key,
        label: label ?? this.label,
        iconCode: iconCode ?? this.iconCode,
        defaultIntervalDays: defaultIntervalDays ?? this.defaultIntervalDays,
        colorValue: (clearColor ?? false) ? null : (colorValue ?? this.colorValue),
        builtin: builtin,
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'icon': iconCode,
        'days': defaultIntervalDays,
        'builtin': builtin,
        if (colorValue != null) 'color': colorValue,
      };

  factory CareType.fromJson(Map<String, dynamic> m) => CareType(
        key: m['key'] as String,
        label: m['label'] as String,
        iconCode: (m['icon'] as num).toInt(),
        defaultIntervalDays: (m['days'] as num).toDouble(),
        colorValue: (m['color'] as num?)?.toInt(),
        builtin: (m['builtin'] as bool?) ?? false,
      );
}

/// Static palette of icons available for care types. All entries are
/// `const IconData` references so the Flutter icon tree-shaker keeps
/// their glyphs even when a codePoint is decoded from prefs at runtime.
const List<IconData> kCareIconPalette = <IconData>[
  Icons.water_drop_outlined,
  Icons.eco_outlined,
  Icons.bubble_chart_outlined,
  Icons.local_florist_outlined,
  Icons.content_cut_outlined,
  Icons.light_mode_outlined,
  Icons.wb_sunny_outlined,
  Icons.bug_report_outlined,
  Icons.air,
  Icons.thermostat_outlined,
  Icons.spa_outlined,
  Icons.grass_outlined,
  Icons.handyman_outlined,
  Icons.clean_hands_outlined,
  Icons.notifications_active_outlined,
  Icons.medical_services_outlined,
];

/// Lookup-by-codepoint from [kCareIconPalette]. `CareType.icon` hits
/// this instead of `IconData(codepoint, fontFamily: 'MaterialIcons')`
/// so release builds don't trip the non-const-IconData tree-shake guard.
final Map<int, IconData> kCareIconByCodePoint = {
  for (final icon in kCareIconPalette) icon.codePoint: icon,
};

/// Defaults applied on first launch (or whenever prefs is empty).
final List<CareType> kBuiltInCareTypes = [
  CareType(key: 'water', label: 'Water', iconCode: Icons.water_drop_outlined.codePoint, defaultIntervalDays: 7, builtin: true),
  CareType(key: 'fertilize', label: 'Fertilize', iconCode: Icons.eco_outlined.codePoint, defaultIntervalDays: 30, builtin: true),
  CareType(key: 'mist', label: 'Mist', iconCode: Icons.bubble_chart_outlined.codePoint, defaultIntervalDays: 3, builtin: true),
  CareType(key: 'repot', label: 'Repot', iconCode: Icons.local_florist_outlined.codePoint, defaultIntervalDays: 365, builtin: true),
  CareType(key: 'prune', label: 'Prune', iconCode: Icons.content_cut_outlined.codePoint, defaultIntervalDays: 90, builtin: true),
  CareType(key: 'rotate', label: 'Rotate', iconCode: Icons.light_mode_outlined.codePoint, defaultIntervalDays: 14, builtin: true),
];

/// Falls back to the raw key if nothing matches — renders custom/legacy
/// types as their literal name.
CareType resolveCareType(List<CareType> list, String key) {
  for (final t in list) {
    if (t.key == key) return t;
  }
  return CareType(
    key: key,
    label: key.isEmpty ? 'Care' : '${key[0].toUpperCase()}${key.substring(1)}',
    iconCode: Icons.notifications_active_outlined.codePoint,
    defaultIntervalDays: 7,
  );
}

class CareTypesController extends StateNotifier<List<CareType>> {
  CareTypesController(this._prefs) : super(kBuiltInCareTypes) {
    _load();
  }

  static const _key = 'plantly_care_types';
  final Future<SharedPreferences> _prefs;

  Future<void> _load() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final decoded = (json.decode(raw) as List).cast<Map<String, dynamic>>();
      final list = decoded.map(CareType.fromJson).toList();
      if (list.isNotEmpty) state = list;
    } catch (_) {
      // Malformed payload — fall back to defaults on next save.
    }
  }

  Future<void> _persist() async {
    final prefs = await _prefs;
    await prefs.setString(
      _key,
      json.encode([for (final t in state) t.toJson()]),
    );
  }

  Future<void> add(CareType type) async {
    if (state.any((t) => t.key == type.key)) return;
    state = [...state, type];
    await _persist();
  }

  Future<void> update(String key, CareType replacement) async {
    state = [for (final t in state) t.key == key ? replacement : t];
    await _persist();
  }

  Future<void> remove(String key) async {
    state = state.where((t) => t.key != key).toList();
    await _persist();
  }

  Future<void> resetToBuiltIn() async {
    state = kBuiltInCareTypes;
    await _persist();
  }
}

final careTypesProvider =
    StateNotifierProvider<CareTypesController, List<CareType>>((ref) {
  return CareTypesController(ref.watch(sharedPreferencesProvider.future));
});

/// Global per-type mute — a set of care-type keys whose reminders never
/// hit the OS notification tray. Useful for "mute all fertilize
/// reminders while I'm on vacation" without touching per-plant /
/// per-schedule flags.
class MutedTypesController extends StateNotifier<Set<String>> {
  MutedTypesController(this._prefs) : super(const <String>{}) {
    _load();
  }
  static const _key = 'plantly_muted_type_keys';
  final Future<SharedPreferences> _prefs;

  Future<void> _load() async {
    final p = await _prefs;
    final list = p.getStringList(_key);
    if (list != null) state = list.toSet();
  }

  Future<void> setMuted(String key, bool muted) async {
    final next = {...state};
    if (muted) {
      next.add(key);
    } else {
      next.remove(key);
    }
    state = next;
    final p = await _prefs;
    await p.setStringList(_key, next.toList());
  }
}

final mutedCareTypesProvider =
    StateNotifierProvider<MutedTypesController, Set<String>>((ref) {
  return MutedTypesController(ref.watch(sharedPreferencesProvider.future));
});

/// User-chosen care-type key for the Plant Detail quick-action FAB.
/// Default "water" matches the app's muscle memory; users can long-press
/// the FAB to pick any other care type and persist the choice.
class QuickFabTypeController extends StateNotifier<String> {
  QuickFabTypeController(this._prefs) : super('water') {
    _load();
  }
  static const _key = 'plantly_quick_fab_type';
  final Future<SharedPreferences> _prefs;

  Future<void> _load() async {
    final p = await _prefs;
    final stored = p.getString(_key);
    if (stored != null && stored.isNotEmpty) state = stored;
  }

  Future<void> set(String key) async {
    state = key;
    final p = await _prefs;
    await p.setString(_key, key);
  }
}

final quickFabTypeProvider =
    StateNotifierProvider<QuickFabTypeController, String>((ref) {
  return QuickFabTypeController(ref.watch(sharedPreferencesProvider.future));
});
