import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/tokens.dart';

/// Header + optional edit-mode controls for each home widget.
/// Matches the `WidgetShell` helper in `web/prototype/components/widgets.jsx`.
class WidgetShell extends StatelessWidget {
  const WidgetShell({
    super.key,
    this.title,
    this.accentLabel,
    this.accentColor,
    this.action,
    this.onAction,
    this.editing = false,
    this.onMoveUp,
    this.onMoveDown,
    this.onRemove,
    required this.surface,
    required this.child,
    this.padInner = true,
  });

  final String? title;
  final String? accentLabel;
  final Color? accentColor;
  final String? action;
  final VoidCallback? onAction;
  final bool editing;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onRemove;
  final PlantlySurface surface;
  final Widget child;

  /// True (phone/tablet): the shell adds the `space5` side gutter and the
  /// `space4` gap below. False (desktop dashboard): the host owns both.
  final bool padInner;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: padInner ? PlantlyTokens.space4 : 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: padInner ? PlantlyTokens.space5 : 0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null) _Header(
                  title: title!,
                  accentLabel: accentLabel,
                  accentColor: accentColor,
                  action: action,
                  onAction: onAction,
                  editing: editing,
                  surface: surface,
                ),
                child,
              ],
            ),
          ),
          if (editing)
            Positioned(
              right: padInner ? PlantlyTokens.space5 : 0,
              top: -6,
              child: _EditControls(
                onMoveUp: onMoveUp,
                onMoveDown: onMoveDown,
                onRemove: onRemove,
                surface: surface,
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.accentLabel,
    required this.accentColor,
    required this.action,
    required this.onAction,
    required this.editing,
    required this.surface,
  });

  final String title;
  final String? accentLabel;
  final Color? accentColor;
  final String? action;
  final VoidCallback? onAction;
  final bool editing;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          // Flexible + ellipsis: localized titles (e.g. "Activitate recentă")
          // plus the uppercase action can outgrow narrow phones.
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: PlantlyFonts.plusJakartaSans, 
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: surface.text,
                letterSpacing: -0.01 * 16,
              ),
            ),
          ),
          if (accentLabel != null) ...[
            const SizedBox(width: PlantlyTokens.space2),
            Text(
              accentLabel!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: accentColor ?? surface.muted,
              ),
            ),
          ],
          const Spacer(),
          if (action != null && !editing)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  action!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: surface.green,
                    letterSpacing: 0.08 * 11,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EditControls extends StatelessWidget {
  const _EditControls({
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
    required this.surface,
  });

  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onRemove;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(PlantlyTokens.radiusMd),
        boxShadow: const [
          BoxShadow(color: Color(0x1F000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            iconSize: 14,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            onPressed: onMoveUp,
            icon: Icon(Icons.expand_less, color: surface.muted),
            tooltip: AppLocalizations.of(context).homeMoveUp,
          ),
          IconButton(
            iconSize: 14,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            onPressed: onMoveDown,
            icon: Icon(Icons.expand_more, color: surface.muted),
            tooltip: AppLocalizations.of(context).homeMoveDown,
          ),
          Container(width: 1, height: 14, color: surface.border),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: surface.terra,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            onPressed: onRemove,
            child: Text(AppLocalizations.of(context).commonRemove),
          ),
        ],
      ),
    );
  }
}
