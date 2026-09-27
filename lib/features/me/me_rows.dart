import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Row primitives of the Me screen, shared with the Cloud section/screen.

/// Small uppercase-ish green section header.
class MeSectionLabel extends StatelessWidget {
  const MeSectionLabel({super.key, required this.text, required this.surface});
  final String text;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: surface.green,
          letterSpacing: 0.1 * 11,
        ),
      ),
    );
  }
}

/// Icon + label + value row with an optional chevron/tap.
class MeActionRow extends StatelessWidget {
  const MeActionRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.surface,
    this.valueColor,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final PlantlySurface surface;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface.surface,
      borderRadius: BorderRadius.circular(PlantlyTokens.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PlantlyTokens.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: surface.border),
            borderRadius: BorderRadius.circular(PlantlyTokens.radius),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: surface.green),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text)),
                    Text(
                      value,
                      style: TextStyle(fontSize: 12, color: valueColor ?? surface.muted),
                    ),
                  ],
                ),
              ),
              if (onTap != null) Icon(Icons.chevron_right, color: surface.muted),
            ],
          ),
        ),
      ),
    );
  }
}
