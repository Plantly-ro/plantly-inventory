import 'package:flutter/material.dart';

import '../../../data/mock_plants.dart';
import '../../../theme/tokens.dart';
import 'plant_row.dart';
import 'widget_shell.dart';

class OverdueWidget extends StatelessWidget {
  const OverdueWidget({
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
  final void Function(MockPlant)? onLogCare;
  final bool editing;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onRemove;

  static const _items = <_OverdueItem>[
    _OverdueItem(plantId: 'bob', subtitle: '2d late', icon: Icons.water_drop_outlined),
    _OverdueItem(plantId: 'green', subtitle: 'Fertilize', icon: Icons.eco_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return WidgetShell(
      surface: surface,
      editing: editing,
      onMoveUp: onMoveUp,
      onMoveDown: onMoveDown,
      onRemove: onRemove,
      title: 'Overdue',
      accentLabel: '${_items.length}',
      accentColor: surface.terra,
      child: PlantRowGroup(
        surface: surface,
        rows: [
          for (var i = 0; i < _items.length; i++)
            _row(context, _items[i], i == _items.length - 1),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, _OverdueItem item, bool last) {
    final plant = MockPlants.byId(item.plantId);
    return PlantRow(
      plant: plant,
      surface: surface,
      subtitle: item.subtitle,
      subtitleIcon: item.icon,
      subtitleColor: surface.terra,
      first: false,
      last: last,
      onTap: () => onPlantTap?.call(plant),
      trailing: _DoneButton(
        surface: surface,
        onPressed: () => onLogCare?.call(plant),
      ),
    );
  }
}

class _OverdueItem {
  const _OverdueItem({required this.plantId, required this.subtitle, required this.icon});
  final String plantId;
  final String subtitle;
  final IconData icon;
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.surface, required this.onPressed});
  final PlantlySurface surface;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        backgroundColor: surface.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PlantlyTokens.radiusMd),
        ),
      ),
      onPressed: onPressed,
      child: const Text('Done'),
    );
  }
}
