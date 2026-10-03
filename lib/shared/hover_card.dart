import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Pointer/keyboard affordance for tappable cards and rows (DESKTOP-POLISH
/// §7). Wraps [child] in an [InkWell] that owns the tap, the click cursor
/// and the focus node, and paints a hover tint (`green` α .06 + a
/// `botanical300` border, 120 ms) plus a 2 px green focus ring *over* the
/// child — no layout change, and nothing is painted while idle, so phone
/// output stays byte-identical.
///
/// The child must not carry its own `InkWell`/`GestureDetector` for the
/// same tap: pass `onTap`/`onLongPress` here instead. `Enter`/`Space`
/// activate through the ink well's default [ActivateIntent] handling.
class HoverCard extends StatefulWidget {
  const HoverCard({
    super.key,
    required this.surface,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius = PlantlyTokens.radiusXl,
    this.enabled = true,
  });

  final PlantlySurface surface;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Corner radius of the child's own decoration, so the overlay follows it.
  final double borderRadius;

  /// `false` turns the hover/focus visuals off (the tap still works) —
  /// e.g. while a card is in bulk-selection mode and draws its own state.
  final bool enabled;

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);
    final s = widget.surface;
    // Only keyboard focus gets the ring; a mouse click leaves focus on the
    // card too and a ring after every click reads as a bug.
    final keyboardFocus = _focused && FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    final show = widget.enabled && (_hovered || keyboardFocus);
    final BoxDecoration? overlay = !show
        ? null
        : BoxDecoration(
            borderRadius: radius,
            color: _hovered ? s.green.withValues(alpha: 0.06) : null,
            border: Border.all(
              color: keyboardFocus ? s.green : PlantlyTokens.botanical300,
              width: keyboardFocus ? 2 : 1,
            ),
          );
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        borderRadius: radius,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        onHover: (v) => setState(() => _hovered = v),
        onFocusChange: (v) => setState(() => _focused = v),
        // Passthrough: the child must see the parent's constraints (a grid
        // cell is tight), otherwise a Column-bearing card shrinks to its
        // content — the phone stat tiles lost their background that way.
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            widget.child,
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  decoration: overlay,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
