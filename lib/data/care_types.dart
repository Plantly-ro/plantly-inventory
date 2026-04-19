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
    this.builtin = false,
  });

  final String key;
  final String label;
  /// Material icon codepoint (e.g. `Icons.water_drop_outlined.codePoint`).
  final int iconCode;
  /// Starting interval when the user adds a reminder of this type. Stored
  /// as days — UI lets the user re-express as minutes/hours/days/months.
  final double defaultIntervalDays;
  final bool builtin;

  IconData get icon => IconData(iconCode, fontFamily: 'MaterialIcons');

  /// Past-tense verb for Timeline / Activity rendering. For custom types
  /// the label itself is the best we can do.
  String get pastTenseLabel {
    if (!builtin) return label;
    switch (key) {
      case 'water':
        return 'Watered';
      case 'fertilize':
        return 'Fertilized';
      case 'mist':
        return 'Misted';
      case 'repot':
        return 'Repotted';
      case 'prune':
        return 'Pruned';
      case 'rotate':
        return 'Rotated';
      default:
        return label;
    }
  }

  CareType copyWith({
    String? label,
    int? iconCode,
    double? defaultIntervalDays,
  }) =>
      CareType(
        key: key,
        label: label ?? this.label,
        iconCode: iconCode ?? this.iconCode,
        defaultIntervalDays: defaultIntervalDays ?? this.defaultIntervalDays,
        builtin: builtin,
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'icon': iconCode,
        'days': defaultIntervalDays,
        'builtin': builtin,
      };

  factory CareType.fromJson(Map<String, dynamic> m) => CareType(
        key: m['key'] as String,
        label: m['label'] as String,
        iconCode: (m['icon'] as num).toInt(),
        defaultIntervalDays: (m['days'] as num).toDouble(),
        builtin: (m['builtin'] as bool?) ?? false,
      );
}

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
