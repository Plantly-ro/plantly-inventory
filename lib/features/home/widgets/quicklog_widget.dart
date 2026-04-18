import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import 'widget_shell.dart';

class QuickLogWidget extends StatelessWidget {
  const QuickLogWidget({
    super.key,
    required this.surface,
    this.onLog,
    this.editing = false,
    this.onMoveUp,
    this.onMoveDown,
    this.onRemove,
  });

  final PlantlySurface surface;
  final void Function(String action)? onLog;
  final bool editing;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final actions = <_Action>[
      _Action('Water', Icons.water_drop_outlined, surface.green, surface.greenSoft),
      _Action('Fertilize', Icons.eco_outlined, surface.green, surface.greenSoft),
      _Action('Mist', Icons.water_drop_outlined, surface.terra, surface.terraSoft),
      _Action('Photo', Icons.camera_alt_outlined, surface.terra, surface.terraSoft),
    ];
    return WidgetShell(
      surface: surface,
      editing: editing,
      onMoveUp: onMoveUp,
      onMoveDown: onMoveDown,
      onRemove: onRemove,
      title: 'Quick log',
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.85,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: actions.map((a) => _Btn(action: a, surface: surface, onTap: () => onLog?.call(a.label))).toList(growable: false),
      ),
    );
  }
}

class _Action {
  const _Action(this.label, this.icon, this.color, this.soft);
  final String label;
  final IconData icon;
  final Color color;
  final Color soft;
}

class _Btn extends StatelessWidget {
  const _Btn({required this.action, required this.surface, required this.onTap});
  final _Action action;
  final PlantlySurface surface;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface.surface,
      borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: surface.border),
            borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: action.soft,
                  borderRadius: BorderRadius.circular(PlantlyTokens.radius),
                ),
                child: Icon(action.icon, size: 16, color: action.color),
              ),
              const SizedBox(height: 6),
              Text(
                action.label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: surface.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
