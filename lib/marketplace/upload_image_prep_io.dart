import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'upload_image_prep.dart';

UploadImagePreparer createUploadImagePreparer() => const NativeUploadImagePreparer();

/// io: flutter_image_compress (libjpeg-turbo on Android). Always re-encodes
/// to JPEG so HEIC/PNG captures upload as JPEG too. Steps quality down if
/// the result is still over the 2 MiB cap (very noisy sources).
class NativeUploadImagePreparer implements UploadImagePreparer {
  const NativeUploadImagePreparer();

  @override
  Future<Uint8List> prepare(Uint8List bytes) async {
    var quality = UploadImagePreparer.quality;
    Uint8List out = bytes;
    for (var attempt = 0; attempt < 3; attempt++) {
      out = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: UploadImagePreparer.maxSide,
        minHeight: UploadImagePreparer.maxSide,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      if (out.length <= UploadImagePreparer.maxBytes) break;
      quality -= 15;
    }
    return out;
  }
}
