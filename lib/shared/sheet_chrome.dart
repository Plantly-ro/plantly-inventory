import 'package:flutter/material.dart';

import '../app/breakpoints.dart';
import '../theme/tokens.dart';

/// Shared chrome for every sheet opened through `showAdaptiveSheet`
/// (DESKTOP-POLISH §2).
///
/// * phone / tablet — exactly today's bottom-sheet frame: a `surface.bg`
///   container rounded at the top by [topRadius], [padding] inside, the
///   40×4 drag handle centred with [handleGap] below it, then [children]
///   (the sheet's own title stays in there, untouched), then [footer].
///   Byte-identical to the hand-rolled version each sheet had before.
/// * desktop (side sheet) — no radius, no handle. A header (min 56 px,
///   grows for a 2-line title) carries [title] (18 w800, a semantic
///   header) and a `×`; the body scrolls; [footer] is pinned in a
///   64 px bottom bar with a top border.
///
/// [expand] is for sheets that live in a `DraggableScrollableSheet` (the
/// builder gives bounded height and the body holds an `Expanded` list): the
/// column then fills its parent instead of hugging its content, and the
/// desktop body is not wrapped in a scroll view.
class SheetChrome extends StatelessWidget {
  const SheetChrome({
    super.key,
    required this.surface,
    required this.children,
    this.title,
    this.subtitle,
    this.footer,
    this.topRadius = PlantlyTokens.radius2xl,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 20),
    this.handleGap = 14,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.expand = false,
    this.scrollable = false,
  });

  final PlantlySurface surface;

  /// Body widgets. On phone these render after the handle; the sheet's
  /// own title widget belongs here so phone pixels don't move.
  final List<Widget> children;

  /// Desktop header title. Phone ignores it (the title is in [children]).
  final String? title;

  /// Optional desktop-only helper line under the header (13 px muted).
  final String? subtitle;

  /// Primary action. Phone: appended after [children] where it always
  /// was. Desktop: pinned to the bottom bar.
  final Widget? footer;

  final double topRadius;
  final EdgeInsets padding;
  final double handleGap;
  final CrossAxisAlignment crossAxisAlignment;
  final bool expand;

  /// Phone: the body ([children]) scrolls when it does not fit (keyboard
  /// up, large font) while the handle and [footer] stay visible. Desktop
  /// always scrolls unless [expand].
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    if (context.isDesktop) return _desktop(context);
    final handle = [
      Center(
        child: Container(
          height: 4,
          width: 40,
          decoration: BoxDecoration(color: surface.border, borderRadius: BorderRadius.circular(2)),
        ),
      ),
      SizedBox(height: handleGap),
    ];
    final Widget column;
    if (scrollable && !expand) {
      // The body scrolls, the footer stays put: with the keyboard up and a
      // large font the primary action used to scroll out of reach (or,
      // in a non-scrolling sheet, be covered). Content that fits lays out
      // exactly as a plain column (the Flexible hugs it).
      column = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          ...handle,
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: crossAxisAlignment,
                children: children,
              ),
            ),
          ),
          ?footer,
        ],
      );
    } else {
      column = Column(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          ...handle,
          ...children,
          ?footer,
        ],
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: surface.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
      ),
      padding: padding,
      child: column,
    );
  }

  Widget _desktop(BuildContext context) {
    final bodyPadding = EdgeInsets.fromLTRB(padding.left, PlantlyTokens.space4, padding.right, padding.bottom);
    // Stretch regardless of the phone alignment: a side sheet's form rows
    // and lists want the full 480 px, and nothing here needs pixel parity.
    final body = Column(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (subtitle != null) ...[
          Text(subtitle!, style: TextStyle(fontSize: 13, color: surface.muted)),
          const SizedBox(height: PlantlyTokens.space4),
        ],
        ...children,
      ],
    );
    return Container(
      color: surface.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // At least 56 px; a long title (ro copy, long collection
          // names) wraps to a 2nd line and the header grows. One-line
          // titles lay out exactly as in a fixed 56 px bar: the 4 px
          // vertical padding + the 48 px close button = 56.
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: EdgeInsets.fromLTRB(padding.left, 4, padding.right - 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: PlantlyFonts.plusJakartaSans,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: surface.text,
                          letterSpacing: -0.02 * 18,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: surface.muted),
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: surface.border),
          Expanded(
            child: expand
                ? Padding(padding: bodyPadding, child: body)
                : SingleChildScrollView(padding: bodyPadding, child: body),
          ),
          if (footer != null)
            Container(
              height: 64,
              padding: EdgeInsets.symmetric(horizontal: padding.left, vertical: PlantlyTokens.space3),
              decoration: BoxDecoration(
                color: surface.bg,
                border: Border(top: BorderSide(color: surface.border)),
              ),
              child: Align(alignment: Alignment.centerRight, child: footer),
            ),
        ],
      ),
    );
  }
}
