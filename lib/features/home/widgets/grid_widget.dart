import 'package:flutter/material.dart';

import '../../../data/mock_plants.dart';
import '../../../shared/plant_thumb.dart';
import '../../../theme/tokens.dart';
import 'widget_shell.dart';

class GridWidget extends StatelessWidget {
  const GridWidget({
    super.key,
    required this.surface,
    this.onPlantTap,
    this.editing = false,
    this.onMoveUp,
    this.onMoveDown,
    this.onRemove,
  });

  final PlantlySurface surface;
  final void Function(MockPlant)? onPlantTap;
  final bool editing;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onRemove;

  static const _items = <_GridItem>[
    _GridItem(id: 'fern', ok: true),
    _GridItem(id: 'bob', ok: false),
    _GridItem(id: 'suc', ok: true),
    _GridItem(id: 'green', ok: false),
    _GridItem(id: 'pete', ok: true),
    _GridItem(id: 'cala', ok: true),
  ];

  @override
  Widget build(BuildContext context) {
    return WidgetShell(
      surface: surface,
      editing: editing,
      onMoveUp: onMoveUp,
      onMoveDown: onMoveDown,
      onRemove: onRemove,
      title: 'All plants',
      accentLabel: '24',
      accentColor: surface.muted,
      action: 'See all',
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.78,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: _items.map((item) {
          final plant = MockPlants.byId(item.id);
          return _Card(plant: plant, ok: item.ok, surface: surface, onTap: () => onPlantTap?.call(plant));
        }).toList(growable: false),
      ),
    );
  }
}

class _GridItem {
  const _GridItem({required this.id, required this.ok});
  final String id;
  final bool ok;
}

class _Card extends StatelessWidget {
  const _Card({required this.plant, required this.ok, required this.surface, required this.onTap});
  final MockPlant plant;
  final bool ok;
  final PlantlySurface surface;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = ok ? surface.green : surface.terra;
    final soft = ok ? surface.greenSoft : surface.terraSoft;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: surface.surface,
          border: Border.all(color: surface.border),
          borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      color: surface.surfaceAlt,
                      child: PlantThumb(plant: plant, size: 160),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: soft,
                        shape: BoxShape.circle,
                        border: Border.all(color: accent, width: 1.5),
                      ),
                      child: Center(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: surface.text,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.place_outlined, size: 9, color: surface.muted),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          plant.location.split(' ›').first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: surface.muted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
