import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
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
    LayoutPreset(_grouped, ['greeting', 'overdue', 'today', 'grid']),
    LayoutPreset(_dashboard, ['greeting', 'stats', 'weather', 'today', 'activity']),
    LayoutPreset(_feed, ['greeting', 'overdue', 'today', 'activity']),
    LayoutPreset(_minimal, ['greeting', 'quicklog', 'today']),
  ];

  static String _grouped(AppLocalizations t) => t.homePresetGrouped;
  static String _dashboard(AppLocalizations t) => t.homePresetDashboard;
  static String _feed(AppLocalizations t) => t.homePresetFeed;
  static String _minimal(AppLocalizations t) => t.homePresetMinimal;

  static final Map<String, WidgetEntry> entries = {
    'greeting': WidgetEntry(
      key: 'greeting',
      desktopSpan: 12,
      label: (t) => t.homeWidgetGreeting,
      icon: Icons.person_outline,
      render: (p) => GreetingWidget(
        surface: p.surface,
        editing: p.editing,
        padInner: p.padInner,
        onMoveUp: p.onMoveUp,
        onMoveDown: p.onMoveDown,
        onRemove: p.onRemove,
      ),
    ),
    'stats': WidgetEntry(
      key: 'stats',
      desktopSpan: 12,
      label: (t) => t.homeWidgetStats,
      icon: Icons.eco_outlined,
      render: (p) => StatsWidget(
        surface: p.surface,
        editing: p.editing,
        padInner: p.padInner,
        onMoveUp: p.onMoveUp,
        onMoveDown: p.onMoveDown,
        onRemove: p.onRemove,
      ),
    ),
    'weather': WidgetEntry(
      key: 'weather',
      desktopSpan: 6,
      // The key stays `weather` for layout-serialisation compatibility;
      // the widget now shows a rotating care tip until a real weather
      // provider lands in Phase 2.
      label: (t) => t.homeWidgetTip,
      icon: Icons.lightbulb_outline,
      render: (p) => WeatherWidget(
        surface: p.surface,
        editing: p.editing,
        padInner: p.padInner,
        onMoveUp: p.onMoveUp,
        onMoveDown: p.onMoveDown,
        onRemove: p.onRemove,
      ),
    ),
    'overdue': WidgetEntry(
      key: 'overdue',
      desktopSpan: 6,
      label: (t) => t.homeWidgetOverdue,
      icon: Icons.water_drop_outlined,
      render: (p) => OverdueWidget(
        surface: p.surface,
        editing: p.editing,
        padInner: p.padInner,
        onMoveUp: p.onMoveUp,
        onMoveDown: p.onMoveDown,
        onRemove: p.onRemove,
        onPlantTap: p.onPlantTap,
        onLogCare: (message) => p.onToast?.call(message),
      ),
    ),
    'today': WidgetEntry(
      key: 'today',
      desktopSpan: 6,
      label: (t) => t.homeWidgetToday,
      icon: Icons.check,
      render: (p) => TodayWidget(
        surface: p.surface,
        editing: p.editing,
        padInner: p.padInner,
        onMoveUp: p.onMoveUp,
        onMoveDown: p.onMoveDown,
        onRemove: p.onRemove,
        onPlantTap: p.onPlantTap,
        onLogCare: (message) => p.onToast?.call(message),
      ),
    ),
    'grid': WidgetEntry(
      key: 'grid',
      desktopSpan: 12,
      label: (t) => t.homeWidgetGrid,
      icon: Icons.home_outlined,
      render: (p) => GridWidget(
        surface: p.surface,
        editing: p.editing,
        padInner: p.padInner,
        onMoveUp: p.onMoveUp,
        onMoveDown: p.onMoveDown,
        onRemove: p.onRemove,
        onPlantTap: p.onPlantTap,
      ),
    ),
    'activity': WidgetEntry(
      key: 'activity',
      desktopSpan: 12,
      label: (t) => t.homeWidgetActivity,
      icon: Icons.calendar_today_outlined,
      render: (p) => ActivityWidget(
        surface: p.surface,
        editing: p.editing,
        padInner: p.padInner,
        onMoveUp: p.onMoveUp,
        onMoveDown: p.onMoveDown,
        onRemove: p.onRemove,
      ),
    ),
    'quicklog': WidgetEntry(
      key: 'quicklog',
      desktopSpan: 6,
      label: (t) => t.homeWidgetQuickLog,
      icon: Icons.add,
      render: (p) => QuickLogWidget(
        surface: p.surface,
        editing: p.editing,
        padInner: p.padInner,
        onMoveUp: p.onMoveUp,
        onMoveDown: p.onMoveDown,
        onRemove: p.onRemove,
        onLog: (message) => p.onToast?.call(message),
      ),
    ),
  };
}

class WidgetRenderParams {
  const WidgetRenderParams({
    required this.surface,
    required this.editing,
    this.padInner = true,
    this.onMoveUp,
    this.onMoveDown,
    this.onRemove,
    this.onPlantTap,
    this.onToast,
  });
  final PlantlySurface surface;
  final bool editing;
  /// Forwarded to `WidgetShell.padInner`: false when the host already
  /// provides the horizontal gutter (desktop dashboard).
  final bool padInner;
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
    this.desktopSpan = 12,
  });
  final String key;
  /// Columns (of 12) the widget takes in the desktop dashboard grid.
  final int desktopSpan;
  /// Localized label — resolved at render time so it follows the app locale.
  final String Function(AppLocalizations t) label;
  final IconData icon;
  final Widget Function(WidgetRenderParams params) render;
}

class LayoutPreset {
  const LayoutPreset(this.name, this.keys);
  /// Localized preset name — resolved at render time.
  final String Function(AppLocalizations t) name;
  final List<String> keys;
}
