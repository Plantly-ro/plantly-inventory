import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/providers.dart';

/// Do-not-disturb window (local time). When enabled and the scheduled
/// time falls between [startHour]:[startMinute] and
/// [endHour]:[endMinute], the notification is pushed to the window's
/// end. Range crosses midnight iff `end <= start`.
class DndSettings {
  const DndSettings({
    required this.enabled,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  final bool enabled;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  static const disabled = DndSettings(
    enabled: false,
    startHour: 22,
    startMinute: 0,
    endHour: 8,
    endMinute: 0,
  );

  TimeOfDay get start => TimeOfDay(hour: startHour, minute: startMinute);
  TimeOfDay get end => TimeOfDay(hour: endHour, minute: endMinute);

  /// Test whether [when] (local time) is inside the quiet window.
  bool containsLocal(DateTime when) {
    if (!enabled) return false;
    final mins = when.hour * 60 + when.minute;
    final s = startHour * 60 + startMinute;
    final e = endHour * 60 + endMinute;
    if (s == e) return false;
    if (s < e) return mins >= s && mins < e;
    // Window wraps midnight.
    return mins >= s || mins < e;
  }

  /// Push [when] forward to the next moment outside the quiet window.
  /// Used by ReminderSync so muted-hour reminders fire at the window's
  /// end instead of being silently dropped.
  DateTime pushPastWindow(DateTime when) {
    if (!containsLocal(when)) return when;
    final end = DateTime(when.year, when.month, when.day, endHour, endMinute);
    if (end.isAfter(when)) return end;
    // If the end is earlier in the day (wraps midnight), push to tomorrow.
    return end.add(const Duration(days: 1));
  }

  DndSettings copyWith({
    bool? enabled,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
  }) =>
      DndSettings(
        enabled: enabled ?? this.enabled,
        startHour: startHour ?? this.startHour,
        startMinute: startMinute ?? this.startMinute,
        endHour: endHour ?? this.endHour,
        endMinute: endMinute ?? this.endMinute,
      );
}

class DndController extends StateNotifier<DndSettings> {
  DndController(this._prefs) : super(DndSettings.disabled) {
    _load();
  }
  static const _kEnabled = 'plantly_dnd_enabled';
  static const _kStart = 'plantly_dnd_start';
  static const _kEnd = 'plantly_dnd_end';
  final Future<SharedPreferences> _prefs;

  Future<void> _load() async {
    final p = await _prefs;
    final enabled = p.getBool(_kEnabled) ?? false;
    final startRaw = p.getInt(_kStart) ?? (22 * 60);
    final endRaw = p.getInt(_kEnd) ?? (8 * 60);
    state = DndSettings(
      enabled: enabled,
      startHour: startRaw ~/ 60,
      startMinute: startRaw % 60,
      endHour: endRaw ~/ 60,
      endMinute: endRaw % 60,
    );
  }

  Future<void> setEnabled(bool v) async {
    state = state.copyWith(enabled: v);
    (await _prefs).setBool(_kEnabled, v);
  }

  Future<void> setStart(TimeOfDay t) async {
    state = state.copyWith(startHour: t.hour, startMinute: t.minute);
    (await _prefs).setInt(_kStart, t.hour * 60 + t.minute);
  }

  Future<void> setEnd(TimeOfDay t) async {
    state = state.copyWith(endHour: t.hour, endMinute: t.minute);
    (await _prefs).setInt(_kEnd, t.hour * 60 + t.minute);
  }
}

final dndSettingsProvider =
    StateNotifierProvider<DndController, DndSettings>((ref) {
  return DndController(ref.watch(sharedPreferencesProvider.future));
});
