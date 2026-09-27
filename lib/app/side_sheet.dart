import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/home_providers.dart';
import '../theme/tokens.dart';
import 'breakpoints.dart';

/// Drop-in for `showModalBottomSheet`: identical bottom sheet on phone and
/// tablet (same defaults, same arguments), a 480 px right-side sheet on
/// desktop. The [builder] content is unchanged — sheets keep their own
/// rounded header/handle; on desktop that sits flush at the top of the panel.
///
/// Sheets close themselves with `Navigator.of(context).pop(result)` exactly
/// as before: the side sheet is a route on the root navigator, so the
/// nearest navigator from inside the panel is the right one.
Future<T?> showAdaptiveSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  Color? backgroundColor,
  ShapeBorder? shape,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useSafeArea = false,
}) {
  if (!context.isDesktop) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: backgroundColor,
      shape: shape,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useSafeArea: useSafeArea,
      builder: builder,
    );
  }
  return showSideSheet<T>(context, builder: builder, barrierDismissible: isDismissible);
}

/// Right-anchored modal panel (desktop). Slides in from the right; the
/// barrier click and `Esc` (via the route's default `DismissIntent`
/// handling) close it.
Future<T?> showSideSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double width = Breakpoints.sideSheetWidth,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: PlantlyTokens.durFast,
    pageBuilder: (ctx, _, _) => SideSheetPanel(width: width, child: Builder(builder: builder)),
    transitionBuilder: (ctx, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: PlantlyTokens.easeOutSoft,
        reverseCurve: PlantlyTokens.easeIn,
      );
      return SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
        child: child,
      );
    },
  );
}

/// The panel chrome for [showSideSheet]. Full height, fixed [width], app
/// background colour, rounded on the window side. Content gets bounded
/// constraints (so `Expanded` / `DraggableScrollableSheet` children work)
/// but is not stretched, so `mainAxisSize: min` sheets hug the top.
class SideSheetPanel extends ConsumerWidget {
  const SideSheetPanel({super.key, required this.width, required this.child});
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    return Align(
      alignment: Alignment.centerRight,
      child: SafeArea(
        child: Material(
          color: surface.bg,
          elevation: 12,
          shadowColor: Colors.black.withValues(alpha: 0.4),
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(PlantlyTokens.radius2xl)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: width,
            height: double.infinity,
            child: FocusScope(
              autofocus: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [Flexible(child: child)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
