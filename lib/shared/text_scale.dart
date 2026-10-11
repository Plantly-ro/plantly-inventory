import 'package:flutter/widgets.dart';

/// Height of one line of [style] (merged over the ambient
/// [DefaultTextStyle], as `Text` does) at the ambient text scale.
///
/// Fixed-ratio tiles (grid aspect ratios) are sized for the default text
/// scale on a ~390 dp phone; a 360 dp phone with Android "font size" 1.3
/// overflowed them. Tiles compute the height their text really needs from
/// this and only grow when the ratio is too short — default-size tiles
/// stay pixel-identical.
///
/// With [text] + [maxWidth]: the height of that text wrapped to [maxWidth]
/// (labels that may break onto a second line at a large font).
double textLineHeight(BuildContext context, TextStyle style, {String text = 'Hg', double maxWidth = double.infinity}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(style)),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: maxWidth);
  final h = painter.height;
  painter.dispose();
  return h;
}
