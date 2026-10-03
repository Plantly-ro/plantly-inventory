import 'package:flutter/material.dart';

import 'breakpoints.dart';

/// Density knobs a widget can read when it wants to render differently on
/// desktop (`Theme.of(context).extension<PlantlyDensity>()`); absent on
/// phone/tablet, so `?.` reads fall back to the mobile numbers.
@immutable
class PlantlyDensity extends ThemeExtension<PlantlyDensity> {
  const PlantlyDensity({
    required this.bodySize,
    required this.rowMinHeight,
    required this.tableRowHeight,
  });

  const PlantlyDensity.desktop()
      : bodySize = 14,
        rowMinHeight = 40,
        tableRowHeight = 44;

  final double bodySize;
  final double rowMinHeight;
  final double tableRowHeight;

  @override
  PlantlyDensity copyWith({double? bodySize, double? rowMinHeight, double? tableRowHeight}) {
    return PlantlyDensity(
      bodySize: bodySize ?? this.bodySize,
      rowMinHeight: rowMinHeight ?? this.rowMinHeight,
      tableRowHeight: tableRowHeight ?? this.tableRowHeight,
    );
  }

  @override
  PlantlyDensity lerp(PlantlyDensity? other, double t) {
    if (other == null) return this;
    return PlantlyDensity(
      bodySize: lerpDouble(bodySize, other.bodySize, t),
      rowMinHeight: lerpDouble(rowMinHeight, other.rowMinHeight, t),
      tableRowHeight: lerpDouble(tableRowHeight, other.tableRowHeight, t),
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

/// Desktop flavour of the app theme: compact density, 14 px body, visible
/// hover/focus tints for pointer users, persistent scrollbars. Colours and
/// typefaces are inherited from [base] so light/dark stay in sync.
ThemeData desktopTheme(ThemeData base) {
  final scheme = base.colorScheme;
  final tt = base.textTheme;
  const density = PlantlyDensity.desktop();
  return base.copyWith(
    visualDensity: VisualDensity.compact,
    textTheme: tt.copyWith(
      bodyLarge: tt.bodyLarge?.copyWith(fontSize: density.bodySize),
      bodyMedium: tt.bodyMedium?.copyWith(fontSize: density.bodySize),
    ),
    hoverColor: scheme.primary.withValues(alpha: 0.06),
    focusColor: scheme.primary.withValues(alpha: 0.12),
    listTileTheme: base.listTileTheme.copyWith(dense: true, minVerticalPadding: 6),
    scrollbarTheme: ScrollbarThemeData(
      thumbVisibility: const WidgetStatePropertyAll(true),
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(3),
      thumbColor: WidgetStatePropertyAll(scheme.onSurface.withValues(alpha: 0.25)),
    ),
    extensions: [...base.extensions.values, density],
  );
}

/// Sits in `MaterialApp.builder` (above the root navigator, so dialogs and
/// side sheets inherit it too) and swaps in [desktopTheme] at the desktop
/// breakpoint. Phone/tablet pass through untouched.
class DesktopThemeScope extends StatelessWidget {
  const DesktopThemeScope({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!context.isDesktop) return child;
    return Theme(data: desktopTheme(Theme.of(context)), child: child);
  }
}
