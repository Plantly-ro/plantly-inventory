import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Decodes [provider] at the size it is displayed at instead of the photo's
/// full resolution (a 4000×3000 camera shot in a 1080×830 px slot decoded
/// to ~48 MB of pixels; QA measured 13.7 MB for one tile).
///
/// The target is computed from the image's intrinsic size at decode time,
/// so the aspect ratio is kept and the box is covered ([cover], for
/// `BoxFit.cover`) or contained (other fits) without upscaling. A
/// non-finite [width] / [height] means "unbounded" — only the other side
/// constrains. Never upscales: smaller images decode as they are.
class SizedImageProvider extends ImageProvider<SizedImageKey> {
  const SizedImageProvider(this.provider, {required this.width, required this.height, this.cover = true});

  final ImageProvider provider;

  /// Physical pixels (logical size × devicePixelRatio).
  final double width;
  final double height;
  final bool cover;

  @override
  Future<SizedImageKey> obtainKey(ImageConfiguration configuration) {
    // Keep a synchronous inner key synchronous (as ResizeImage does): an
    // async hop here would show the placeholder for one frame per build.
    Completer<SizedImageKey>? completer;
    SynchronousFuture<SizedImageKey>? result;
    provider.obtainKey(configuration).then((Object key) {
      final k = SizedImageKey._(key, width, height, cover);
      if (completer == null) {
        result = SynchronousFuture<SizedImageKey>(k);
      } else {
        completer.complete(k);
      }
    });
    if (result != null) return result!;
    completer = Completer<SizedImageKey>();
    return completer.future;
  }

  @override
  ImageStreamCompleter loadImage(SizedImageKey key, ImageDecoderCallback decode) {
    Future<ui.Codec> decodeSized(ui.ImmutableBuffer buffer, {ui.TargetImageSizeCallback? getTargetSize}) {
      return decode(buffer, getTargetSize: (int iw, int ih) => targetSize(iw, ih, width: width, height: height, cover: cover));
    }

    return provider.loadImage(key._inner, decodeSized);
  }

  /// The decode size for an [iw]×[ih] image shown in a [width]×[height]
  /// (physical px) box. Public for tests.
  @visibleForTesting
  static ui.TargetImageSize targetSize(int iw, int ih, {required double width, required double height, required bool cover}) {
    if (iw <= 0 || ih <= 0) return const ui.TargetImageSize();
    final sx = width.isFinite && width > 0 ? width / iw : double.nan;
    final sy = height.isFinite && height > 0 ? height / ih : double.nan;
    final double scale;
    if (sx.isNaN && sy.isNaN) {
      return const ui.TargetImageSize();
    } else if (sx.isNaN) {
      scale = sy;
    } else if (sy.isNaN) {
      scale = sx;
    } else {
      scale = cover ? math.max(sx, sy) : math.min(sx, sy);
    }
    if (scale >= 1) return const ui.TargetImageSize();
    return ui.TargetImageSize(
      width: math.max(1, (iw * scale).ceil()),
      height: math.max(1, (ih * scale).ceil()),
    );
  }
}

/// Cache key: the inner provider's key + the decode box.
@immutable
class SizedImageKey {
  const SizedImageKey._(this._inner, this._width, this._height, this._cover);
  final Object _inner;
  final double _width;
  final double _height;
  final bool _cover;

  @override
  bool operator ==(Object other) =>
      other is SizedImageKey &&
      other._inner == _inner &&
      other._width == _width &&
      other._height == _height &&
      other._cover == _cover;

  @override
  int get hashCode => Object.hash(_inner, _width, _height, _cover);
}

/// [image] sized for a box of [constraints] (logical) at the ambient
/// devicePixelRatio, or [image] itself when neither side is bounded.
/// Box sizes are bucketed up to 64 physical px so a resize animation
/// doesn't decode a new copy per frame.
ImageProvider sizedForBox(BuildContext context, ImageProvider image, BoxConstraints constraints, {required BoxFit fit}) {
  final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
  double bucket(double v) => v.isFinite ? ((v * dpr) / 64).ceil() * 64.0 : double.infinity;
  final w = bucket(constraints.maxWidth);
  final h = bucket(constraints.maxHeight);
  if (!w.isFinite && !h.isFinite) return image;
  if (w == 0 || h == 0) return image;
  return SizedImageProvider(image, width: w, height: h, cover: fit == BoxFit.cover || fit == BoxFit.fill);
}
