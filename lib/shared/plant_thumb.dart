import 'package:flutter/material.dart';

import '../data/mock_plants.dart';
import '../theme/tokens.dart';

/// Stand-in for the `plantThumbs` SVG set in
/// `web/prototype/components/shared.jsx`. Real asset images land when
/// the camera + content-addressed photo store ships (PLAN.md §Phase 1).
class PlantThumb extends StatelessWidget {
  const PlantThumb({super.key, required this.plant, this.size = 100});
  final MockPlant plant;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [plant.swatch, PlantlyTokens.botanical700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.1),
      ),
      alignment: Alignment.bottomCenter,
      padding: EdgeInsets.only(bottom: size * 0.12),
      child: Icon(
        Icons.eco,
        size: size * 0.45,
        color: Colors.white.withValues(alpha: 0.8),
      ),
    );
  }
}
