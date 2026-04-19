import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'widgets/activity_widget.dart';
import 'widgets/greeting_widget.dart';
import 'widgets/grid_widget.dart';
import 'widgets/overdue_widget.dart';
import 'widgets/quicklog_widget.dart';
import 'widgets/stats_widget.dart';
import 'widgets/today_widget.dart';
import 'widgets/weather_widget.dart';

/// Mirror of `widgetRegistry` in `web/prototype/components/widgets.jsx`.
/// Each key maps to a renderer closure; `CustomHome` composes a layout
/// by looking each key up in this map.
class WidgetRegistry {
  WidgetRegistry._();

  static const defaultLayout = <String>[
    'greeting',
    'stats',
    'overdue',
    'today',
    'grid',
    'activity',
  ];

  static const presets = <LayoutPreset>[
    LayoutPreset('Grouped', ['greeting', 'overdue', 'today', 'grid']),
    LayoutPreset('Dashboard', ['greeting', 'stats', 'weather', 'today', 'activity']),
    LayoutPreset('Feed', ['greeting', 'overdue', 'today', 'activity']),
    LayoutPreset('Minimal', ['greeting', 'quicklog', 'today']),
  ];

  static final Map<String, WidgetEntry> entries = {
    'greeting': WidgetEntry(
      key: 'greeting',
      label: 'Greeting',
      icon: Icons.person_outline,
      render: (p) => GreetingWidget(
        surface: p.surface,
        editing: p.editing,
        onMoveUp: p.onMoveUp,
        onMoveDown: p.onMoveDown,
        onRemove: p.onRemove,
      ),
    ),
    'stats': WidgetEntry(
      key: 'stats',
      label: 'Stats row',
      icon: Icons.eco_outlined,
      render: (p) => StatsWidget(
        surface: p.surface,
        editing: p.editing,
        onMoveUp: p.onMoveUp,
        onMoveDown: p.onMoveDown,
        onRemove: p.onRemove,
      ),
    ),
    'weather': WidgetEntry(
      key: 'weather',
      label: 'Weather',
      icon: Icons.wb_sunny_outlined,
      render: (p) => WeatherWidget(
        surface: p.surface,
        editing: p.editing,
        onMoveUp: p.onMoveUp,
        onMoveDown: p.onMoveDown,
        onRemove: p.onRemove,
      ),
    ),
    'overdue': WidgetEntry(
      key: 'overdue',
      label: 'Overdue',
      icon: Icons.water_drop_outlined,
      render: (p) => OverdueWidget(
        surface: p.surface,
        editing: p.editing,
        onMoveUp: p.onMoveUp,
        onMoveDown: p.onMoveDown,
        onRemove: p.onRemove,
        onPlantTap: p.onPlantTap,
        onLogCare: (name) => p.onToast?.call('Logged care for $name'),
      ),
    ),
    'today': WidgetEntry(
      key: 'today',
      label: 'Due today',
      icon: Icons.check,
      render: (p) => TodayWidget(
        surface: p.surface,
        editing: p.editing,
        onMoveUp: p.onMoveUp,
        onMoveDown: p.onMoveDown,
        onRemove: p.onRemove,
        onPlantTap: p.onPlantTap,
        onLogCare: (name, action) => p.onToast?.call('${action}ed $name'),
      ),
    ),
    'grid': WidgetEntry(
      key: 'grid',
      label: 'All plants (grid)',
      icon: Icons.home_outlined,
      render: (p) => GridWidget(
        surface: p.surface,
        editing: p.editing,
        onMoveUp: p.onMoveUp,
        onMoveDown: p.onMoveDown,
        onRemove: p.onRemove,
        onPlantTap: p.onPlantTap,
      ),
    ),
    'activity': WidgetEntry(
      key: 'activity',
      label: 'Recent activity',
      icon: Icons.calendar_today_outlined,
      render: (p) => ActivityWidget(
        surface: p.surface,
        editing: p.editing,
        onMoveUp: p.onMoveUp,
        onMoveDown: p.onMoveDown,
        onRemove: p.onRemove,
      ),
    ),
    'quicklog': WidgetEntry(
      key: 'quicklog',
      label: 'Quick log',
      icon: Icons.add,
      render: (p) => QuickLogWidget(
        surface: p.surface,
        editing: p.editing,
        onMoveUp: p.onMoveUp,
        onMoveDown: p.onMoveDown,
        onRemove: p.onRemove,
        onLog: (action) => p.onToast?.call('$action logged'),
      ),
    ),
  };
}

class WidgetRenderParams {
  const WidgetRenderParams({
    required this.surface,
    required this.editing,
    this.onMoveUp,
    this.onMoveDown,
    this.onRemove,
    this.onPlantTap,
    this.onToast,
  });
  final PlantlySurface surface;
  final bool editing;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onRemove;
  /// Navigates to the plant detail screen for [plantId]. Must be the real
  /// `plants.id`, never a MockPlant stand-in's id.
  final void Function(String plantId)? onPlantTap;
  final void Function(String)? onToast;
}

class WidgetEntry {
  WidgetEntry({
    required this.key,
    required this.label,
    required this.icon,
    required this.render,
  });
  final String key;
  final String label;
  final IconData icon;
  final Widget Function(WidgetRenderParams params) render;
}

class LayoutPreset {
  const LayoutPreset(this.name, this.keys);
  final String name;
  final List<String> keys;
}
