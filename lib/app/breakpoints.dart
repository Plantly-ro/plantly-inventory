import 'package:flutter/widgets.dart';

/// Which shell the window gets (CLOUD-SYNC-CONTRACT §5).
enum FormFactor { phone, tablet, desktop }

/// The one place that knows the width thresholds. Everything adaptive in
/// the app asks [BreakpointContext] (`context.isDesktop` & co.) instead of
/// comparing pixels itself, so the numbers can move without a grep.
abstract final class Breakpoints {
  /// `< 720` → phone: today's bottom-nav UI, untouched.
  static const double tablet = 720;

  /// `≥ 1100` → desktop: persistent side nav, master–detail, side sheets.
  static const double desktop = 1100;

  /// Desktop content column is centred and never wider than this.
  static const double contentMaxWidth = 1280;

  static const double sideNavWidth = 240;
  static const double railWidth = 72;

  /// Master pane (plants / spaces / me list) on desktop — spec says 360–420.
  static const double masterPaneWidth = 400;

  /// Right-side sheets that replace modal bottom sheets on desktop.
  static const double sideSheetWidth = 480;

  /// Window width from which the desktop gutters grow from 24 to 32 px.
  static const double wideGutterFrom = 1440;

  static FormFactor forWidth(double width) {
    if (width >= desktop) return FormFactor.desktop;
    if (width >= tablet) return FormFactor.tablet;
    return FormFactor.phone;
  }

  /// Window-based (not parent-constraint-based) on purpose: a 480 px side
  /// sheet on a desktop window must still behave like desktop.
  static FormFactor of(BuildContext context) => forWidth(MediaQuery.sizeOf(context).width);

  static double gutterFor(double width) => width >= wideGutterFrom ? 32 : 24;
}

/// Column count for the home grids. Phone keeps its fixed [phone] count
/// (any orientation — the prototype layout is the contract there); tablet
/// and desktop panes grow with the available [width] so a 2-up phone grid
/// doesn't turn into two giant tiles on an 800 px surface.
///
/// [maxColumns] caps the wide-surface count (a 4-tile stat row should not
/// spread into 7 slots on a 1232 px column); phone ignores it.
int adaptiveColumns(
  BuildContext context,
  double width, {
  required int phone,
  required double minTileWidth,
  int? maxColumns,
}) {
  if (!context.isWide) return phone;
  final fit = (width / minTileWidth).floor();
  final clamped = maxColumns == null ? fit : (fit > maxColumns ? maxColumns : fit);
  return clamped < phone ? phone : clamped;
}

extension BreakpointContext on BuildContext {
  FormFactor get formFactor => Breakpoints.of(this);
  bool get isPhone => formFactor == FormFactor.phone;
  bool get isTablet => formFactor == FormFactor.tablet;
  bool get isDesktop => formFactor == FormFactor.desktop;

  /// Tablet or desktop — the shell provides navigation, screens drop theirs.
  bool get isWide => formFactor != FormFactor.phone;
}
