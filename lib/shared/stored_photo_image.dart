import 'package:flutter/material.dart';

import 'remote_photo.dart';

/// Renders a photo from the content-addressed store by sha, falling back
/// to [placeholder] while loading or when the blob is missing. The only
/// place the UI touches photo bytes — platform differences (file vs
/// IndexedDB) stay inside [PhotoBlobStore], and cloud-synced rows without
/// local bytes are fetched on first display by [RemotePhoto].
class StoredPhotoImage extends StatelessWidget {
  const StoredPhotoImage({
    super.key,
    required this.sha,
    required this.placeholder,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final String sha;
  final Widget placeholder;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return RemotePhoto(
      sha: sha,
      placeholder: placeholder,
      builder: (context, image) => Image(image: image, fit: fit, width: width, height: height),
    );
  }
}
