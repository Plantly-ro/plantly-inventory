import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import 'widget_shell.dart';

class ActivityWidget extends StatelessWidget {
  const ActivityWidget({
    super.key,
    required this.surface,
    this.editing = false,
    this.onMoveUp,
    this.onMoveDown,
    this.onRemove,
  });

  final PlantlySurface surface;
  final bool editing;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onRemove;

  static const _items = <_ActivityItem>[
    _ActivityItem(when: '7:12', plant: 'Fern spray', event: 'Misted', icon: Icons.water_drop_outlined),
    _ActivityItem(when: 'Yesterday', plant: 'Fiddle fig', event: 'Rotated 90°', icon: Icons.light_mode_outlined),
    _ActivityItem(when: 'Apr 16', plant: 'Hens & chicks', event: 'Watered (50ml)', icon: Icons.water_drop_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return WidgetShell(
      surface: surface,
      editing: editing,
      onMoveUp: onMoveUp,
      onMoveDown: onMoveDown,
      onRemove: onRemove,
      title: 'Recent activity',
      action: 'View all',
      child: Container(
        decoration: BoxDecoration(
          color: surface.surface,
          border: Border.all(color: surface.border),
          borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          children: [
            for (var i = 0; i < _items.length; i++)
              _row(_items[i], i == _items.length - 1),
          ],
        ),
      ),
    );
  }

  Widget _row(_ActivityItem item, bool last) {
    return Container(
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: surface.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: surface.greenSoft, shape: BoxShape.circle),
            child: Icon(item.icon, size: 14, color: surface.green),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.plant,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: surface.text, height: 1.25),
                ),
                Text(
                  item.event,
                  style: TextStyle(fontSize: 11.5, color: surface.muted),
                ),
              ],
            ),
          ),
          Text(
            item.when,
            style: TextStyle(fontSize: 11, color: surface.muted, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _ActivityItem {
  const _ActivityItem({
    required this.when,
    required this.plant,
    required this.event,
    required this.icon,
  });
  final String when;
  final String plant;
  final String event;
  final IconData icon;
}
