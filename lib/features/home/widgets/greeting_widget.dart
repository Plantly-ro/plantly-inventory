import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/tokens.dart';
import 'widget_shell.dart';

/// Port of `widgetRegistry.greeting.render` in
/// `web/prototype/components/widgets.jsx`.
class GreetingWidget extends StatelessWidget {
  const GreetingWidget({
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

  @override
  Widget build(BuildContext context) {
    return WidgetShell(
      surface: surface,
      editing: editing,
      onMoveUp: onMoveUp,
      onMoveDown: onMoveDown,
      onRemove: onRemove,
      child: Padding(
        padding: const EdgeInsets.only(bottom: PlantlyTokens.space3),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: surface.greenSoft,
                borderRadius: BorderRadius.circular(PlantlyTokens.radius3xl),
              ),
              alignment: Alignment.center,
              child: Text(
                'AM',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: surface.green,
                ),
              ),
            ),
            const SizedBox(width: PlantlyTokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Friday · April 18',
                    style: TextStyle(
                      fontSize: PlantlyTokens.textXs,
                      color: surface.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Good morning, Ana',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: PlantlyTokens.text2xl,
                      fontWeight: FontWeight.w800,
                      color: surface.text,
                      letterSpacing: -0.02 * PlantlyTokens.text2xl,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: surface.surface,
                border: Border.all(color: surface.border),
                borderRadius: BorderRadius.circular(PlantlyTokens.radius),
              ),
              child: Stack(
                children: [
                  Center(child: Icon(Icons.notifications_outlined, size: 18, color: surface.text)),
                  Positioned(
                    top: 6,
                    right: 7,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: surface.terra,
                        shape: BoxShape.circle,
                        border: Border.all(color: surface.surface, width: 2),
                      ),
                    ),
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
