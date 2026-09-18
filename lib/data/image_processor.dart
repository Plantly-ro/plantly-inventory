import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shrinks a full-resolution camera capture down to the Phase 1 display
/// size (max 1600px on the long edge, 80% JPEG). A null result means the
/// input was already small enough — callers should keep the original.
abstract class ImageProcessor {
  /// Max long-edge for display-quality images.
  static const int displayMaxPx = 1600;
  /// Max long-edge for list thumbnails.
  static const int thumbnailMaxPx = 320;
  /// Bytes smaller than this are passed through untouched — encoding
  /// cost isn't worth the saving on a 50 KB source.
  static const int passthroughBytes = 200 * 1024;

  Future<Uint8List> toDisplay(Uint8List bytes);
  Future<Uint8List> toThumbnail(Uint8List bytes);
}

class FlutterImageCompressProcessor implements ImageProcessor {
  const FlutterImageCompressProcessor();

  @override
  Future<Uint8List> toDisplay(Uint8List bytes) =>
      _compress(bytes, ImageProcessor.displayMaxPx, 80);

  @override
  Future<Uint8List> toThumbnail(Uint8List bytes) =>
      _compress(bytes, ImageProcessor.thumbnailMaxPx, 75);

  Future<Uint8List> _compress(Uint8List bytes, int maxSide, int quality) async {
    if (bytes.length <= ImageProcessor.passthroughBytes) return bytes;
    final out = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: maxSide,
      minHeight: maxSide,
      quality: quality,
      format: CompressFormat.jpeg,
    );
    return out;
  }
}

/// Pass-through — tests that don't want the native plugin loaded, and web.
class NoopImageProcessor implements ImageProcessor {
  const NoopImageProcessor();

  @override
  Future<Uint8List> toDisplay(Uint8List bytes) async => bytes;

  @override
  Future<Uint8List> toThumbnail(Uint8List bytes) async => bytes;
}

// flutter_image_compress on web needs the `pica` script from a CDN and
// throws without it. image_picker_for_web already downsizes to the picker's
// maxWidth (1600) on a canvas, so passing bytes through is the honest choice.
final imageProcessorProvider = Provider<ImageProcessor>(
  (_) => kIsWeb ? const NoopImageProcessor() : const FlutterImageCompressProcessor(),
);
