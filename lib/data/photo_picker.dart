import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Thin abstraction over the platform photo picker so tests can inject a
/// fake without pulling in `image_picker`'s platform channels.
abstract class PhotoPicker {
  Future<PickedPhoto?> pickFromGallery();
  Future<PickedPhoto?> pickFromCamera();
  Future<List<PickedPhoto>> pickMultipleFromGallery();
}

class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.mime});
  final Uint8List bytes;
  final String mime;
}

class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker();
  final _picker = ImagePicker();

  @override
  Future<PickedPhoto?> pickFromGallery() async {
    final xfile = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (xfile == null) return null;
    final bytes = await xfile.readAsBytes();
    return PickedPhoto(bytes: bytes, mime: xfile.mimeType ?? 'image/jpeg');
  }

  @override
  Future<PickedPhoto?> pickFromCamera() async {
    final xfile = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1600);
    if (xfile == null) return null;
    final bytes = await xfile.readAsBytes();
    return PickedPhoto(bytes: bytes, mime: xfile.mimeType ?? 'image/jpeg');
  }

  @override
  Future<List<PickedPhoto>> pickMultipleFromGallery() async {
    final xfiles = await _picker.pickMultiImage(maxWidth: 1600);
    final out = <PickedPhoto>[];
    for (final x in xfiles) {
      out.add(PickedPhoto(
        bytes: await x.readAsBytes(),
        mime: x.mimeType ?? 'image/jpeg',
      ));
    }
    return out;
  }
}

final photoPickerProvider = Provider<PhotoPicker>((_) => ImagePickerPhotoPicker());
