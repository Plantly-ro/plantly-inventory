import 'package:flutter/material.dart';

import '../../../data/mock_plants.dart';
import '../../../shared/plant_thumb.dart';
import '../../../theme/tokens.dart';

class PlantRow extends StatelessWidget {
  const PlantRow({
    super.key,
    required this.plant,
    required this.surface,
    required this.subtitle,
    required this.subtitleIcon,
    required this.subtitleColor,
    required this.trailing,
    required this.first,
    required this.last,
    this.onTap,
  });

  final MockPlant plant;
  final PlantlySurface surface;
  final String subtitle;
  final IconData subtitleIcon;
  final Color subtitleColor;
  final Widget trailing;
  final bool first;
  final bool last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(bottom: BorderSide(color: surface.border)),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: PlantlyTokens.space3 + 2,
          vertical: 11,
        ),
        child: Row(
          children: [
            PlantPhotoThumb(
              plantId: plant.id,
              fallback: plant,
              size: 44,
              borderRadius: BorderRadius.circular(PlantlyTokens.radius),
            ),
            const SizedBox(width: PlantlyTokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plant.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: surface.text,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(subtitleIcon, size: 11, color: subtitleColor),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: subtitleColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class PlantRowGroup extends StatelessWidget {
  const PlantRowGroup({super.key, required this.surface, required this.rows});
  final PlantlySurface surface;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: rows),
    );
  }
}
