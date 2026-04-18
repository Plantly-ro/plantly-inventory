import 'package:flutter/material.dart';

import '../../../data/mock_plants.dart';
import '../../../theme/tokens.dart';
import 'plant_row.dart';
import 'widget_shell.dart';

class TodayWidget extends StatelessWidget {
  const TodayWidget({
    super.key,
    required this.surface,
    this.onPlantTap,
    this.onLogCare,
    this.editing = false,
    this.onMoveUp,
    this.onMoveDown,
    this.onRemove,
  });

  final PlantlySurface surface;
  final void Function(MockPlant)? onPlantTap;
  final void Function(MockPlant, String action)? onLogCare;
  final bool editing;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onRemove;

  static const _items = <_TodayItem>[
    _TodayItem(plantId: 'snake', action: 'Water', icon: Icons.water_drop_outlined),
    _TodayItem(plantId: 'cala', action: 'Mist', icon: Icons.water_drop_outlined),
    _TodayItem(plantId: 'fid', action: 'Rotate', icon: Icons.light_mode_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return WidgetShell(
      surface: surface,
      editing: editing,
      onMoveUp: onMoveUp,
      onMoveDown: onMoveDown,
      onRemove: onRemove,
      title: 'Due today',
      accentLabel: '${_items.length}',
      accentColor: surface.green,
      child: PlantRowGroup(
        surface: surface,
        rows: [
          for (var i = 0; i < _items.length; i++)
            _row(_items[i], i == _items.length - 1),
        ],
      ),
    );
  }

  Widget _row(_TodayItem item, bool last) {
    final plant = MockPlants.byId(item.plantId);
    return PlantRow(
      plant: plant,
      surface: surface,
      subtitle: item.action,
      subtitleIcon: item.icon,
      subtitleColor: surface.muted,
      first: false,
      last: last,
      onTap: () => onPlantTap?.call(plant),
      trailing: _CheckButton(
        surface: surface,
        onPressed: () => onLogCare?.call(plant, item.action),
      ),
    );
  }
}

class _TodayItem {
  const _TodayItem({required this.plantId, required this.action, required this.icon});
  final String plantId;
  final String action;
  final IconData icon;
}

class _CheckButton extends StatelessWidget {
  const _CheckButton({required this.surface, required this.onPressed});
  final PlantlySurface surface;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface.greenSoft,
      borderRadius: BorderRadius.circular(PlantlyTokens.radius),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(PlantlyTokens.radius),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(Icons.check, size: 16, color: surface.green),
        ),
      ),
    );
  }
}
