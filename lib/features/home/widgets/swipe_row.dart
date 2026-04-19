import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';

/// Wraps a plant row with horizontal swipe actions:
/// - swipe right (leading action) → [onDone] — records the care event.
/// - swipe left (trailing action) → [onSnooze] — snoozes by 1 day.
///
/// Uses Dismissible with `confirmDismiss: false` so the row bounces
/// back after the gesture — we never actually remove the widget.
/// The swipe just triggers the action, identical to tapping Done /
/// Snooze but quicker for power users.
class SwipeRow extends StatelessWidget {
  const SwipeRow({
    super.key,
    required this.child,
    required this.onDone,
    required this.onSnooze,
    required this.surface,
  });

  final Widget child;
  final Future<void> Function() onDone;
  final Future<void> Function() onSnooze;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: key ?? UniqueKey(),
      background: _Action(
        color: surface.green,
        icon: Icons.check,
        label: 'Done',
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _Action(
        color: surface.terra,
        icon: Icons.snooze,
        label: 'Snooze',
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await onDone();
        } else if (direction == DismissDirection.endToStart) {
          await onSnooze();
        }
        return false;
      },
      child: child,
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  final Color color;
  final IconData icon;
  final String label;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final leading = alignment == Alignment.centerLeft;
    return Container(
      color: color,
      alignment: alignment,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: leading
            ? [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ]
            : [
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Icon(icon, color: Colors.white),
              ],
      ),
    );
  }
}
