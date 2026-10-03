import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/providers.dart';
import 'widget_registry.dart';

/// Keys mirror the prototype's localStorage contract so a later Drift-backed
/// implementation can re-hydrate state without shape changes.
const _kLayoutKey = 'plantly_layout';
const _kThemeKey = 'plantly_theme';

class HomeLayoutController extends StateNotifier<List<String>> {
  HomeLayoutController(this._prefs) : super(WidgetRegistry.defaultLayout) {
    _load();
  }

  final Future<SharedPreferences> _prefs;

  Future<void> _load() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_kLayoutKey);
    if (raw == null) return;
    try {
      final list = (json.decode(raw) as List).cast<String>();
      if (list.isNotEmpty) state = list;
    } catch (_) {
      // ignore malformed layouts — fall back to the default
    }
  }

  Future<void> _persist() async {
    final prefs = await _prefs;
    await prefs.setString(_kLayoutKey, json.encode(state));
  }

  Future<void> move(int index, int direction) async {
    final target = index + direction;
    if (target < 0 || target >= state.length) return;
    final next = [...state];
    final tmp = next[index];
    next[index] = next[target];
    next[target] = tmp;
    state = next;
    await _persist();
  }

  Future<void> remove(int index) async {
    final next = [...state]..removeAt(index);
    state = next;
    await _persist();
  }

  Future<void> add(String key) async {
    if (state.contains(key)) return;
    state = [...state, key];
    await _persist();
  }

  Future<void> applyPreset(LayoutPreset p) async {
    state = [...p.keys];
    await _persist();
  }

  Future<void> reset() async {
    state = [...WidgetRegistry.defaultLayout];
    await _persist();
  }
}

final homeLayoutProvider =
    StateNotifierProvider<HomeLayoutController, List<String>>((ref) {
  return HomeLayoutController(ref.watch(sharedPreferencesProvider.future));
});

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._prefs) : super(ThemeMode.light) {
    _load();
  }

  final Future<SharedPreferences> _prefs;

  Future<void> _load() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_kThemeKey);
    if (raw == 'dark') state = ThemeMode.dark;
    if (raw == 'light') state = ThemeMode.light;
  }

  Future<void> toggle() async {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await _prefs;
    await prefs.setString(_kThemeKey, state == ThemeMode.dark ? 'dark' : 'light');
  }
}

/// Focus node of the desktop dashboard's inline search field, so the `/`
/// shortcut can focus it from the shell without a widget handle.
final homeSearchFocusProvider = Provider<FocusNode>((ref) {
  final node = FocusNode(debugLabel: 'home-search');
  ref.onDispose(node.dispose);
  return node;
});

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController(ref.watch(sharedPreferencesProvider.future));
});
