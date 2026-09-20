import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'upload_image_prep.dart';

UploadImagePreparer createUploadImagePreparer() => const CanvasUploadImagePreparer();

/// Browser: decode via `createImageBitmap`, draw scaled onto a canvas,
/// re-encode with `toBlob('image/jpeg', 0.85)`. No CDN scripts involved
/// (flutter_image_compress's web path needs one, which is why it's not used).
class CanvasUploadImagePreparer implements UploadImagePreparer {
  const CanvasUploadImagePreparer();

  @override
  Future<Uint8List> prepare(Uint8List bytes) async {
    final blob = web.Blob([bytes.toJS].toJS);
    final bitmap = await web.window.createImageBitmap(blob).toDart;
    try {
      final w = bitmap.width;
      final h = bitmap.height;
      final longest = w > h ? w : h;
      final scale = longest > UploadImagePreparer.maxSide ? UploadImagePreparer.maxSide / longest : 1.0;
      final tw = (w * scale).round().clamp(1, 1 << 15);
      final th = (h * scale).round().clamp(1, 1 << 15);
      final canvas = web.HTMLCanvasElement()
        ..width = tw
        ..height = th;
      final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
      ctx.drawImage(bitmap, 0, 0, tw.toDouble(), th.toDouble());
      var quality = UploadImagePreparer.quality / 100;
      Uint8List out = bytes;
      for (var attempt = 0; attempt < 3; attempt++) {
        out = await _encode(canvas, quality);
        if (out.length <= UploadImagePreparer.maxBytes) break;
        quality -= 0.15;
      }
      return out;
    } finally {
      bitmap.close();
    }
  }

  Future<Uint8List> _encode(web.HTMLCanvasElement canvas, double quality) async {
    final completer = Completer<web.Blob?>();
    canvas.toBlob(
      ((web.Blob? b) => completer.complete(b)).toJS,
      'image/jpeg',
      quality.toJS,
    );
    final blob = await completer.future;
    if (blob == null) throw StateError('canvas.toBlob returned null');
    final buffer = await blob.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  }
}
