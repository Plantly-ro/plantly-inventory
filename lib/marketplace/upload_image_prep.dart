import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'upload_image_prep_io.dart' if (dart.library.js_interop) 'upload_image_prep_web.dart' as platform;

/// Downscales a stored photo for upload (CONTRACT §5: ≤1600 px longest side,
/// JPEG q85, ≤ 2 MiB). The platform halves differ — a native codec on io, a
/// canvas re-encode in the browser — but the contract is the same.
abstract class UploadImagePreparer {
  static const int maxSide = 1600;
  static const int quality = 85;
  static const int maxBytes = 2 * 1024 * 1024;

  /// Returns JPEG bytes fit for upload. Implementations may return the input
  /// untouched when it is already small enough.
  Future<Uint8List> prepare(Uint8List bytes);
}

/// Test double — passes bytes through.
class PassthroughUploadImagePreparer implements UploadImagePreparer {
  const PassthroughUploadImagePreparer();

  @override
  Future<Uint8List> prepare(Uint8List bytes) async => bytes;
}

final uploadImagePreparerProvider =
    Provider<UploadImagePreparer>((_) => platform.createUploadImagePreparer());
