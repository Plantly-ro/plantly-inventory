import 'package:flutter/material.dart';

import 'remote_photo.dart';
import 'sized_image.dart';

/// Renders a photo from the content-addressed store by sha, falling back
/// to [placeholder] while loading or when the blob is missing. The only
/// place the UI touches photo bytes — platform differences (file vs
/// IndexedDB) stay inside [PhotoBlobStore], and cloud-synced rows without
/// local bytes are fetched on first display by [RemotePhoto].
///
/// The photo is decoded at the displayed size × devicePixelRatio
/// ([sizedForBox]), never at the camera's full resolution.
class StoredPhotoImage extends StatelessWidget {
  const StoredPhotoImage({
    super.key,
    required this.sha,
    required this.placeholder,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.semanticLabel,
  });

  final String sha;
  final Widget placeholder;
  final BoxFit fit;
  final double? width;
  final double? height;

  /// Alt text. Null = decorative (thumbnails inside an already-labelled
  /// card/row): left out of the semantics tree rather than exposed as an
  /// unlabeled image.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return RemotePhoto(
      sha: sha,
      placeholder: placeholder,
      builder: (context, image) => LayoutBuilder(
        builder: (context, constraints) {
          // The box the Image will occupy: its own finite width/height
          // where set (tightened by the parent), else the parent's max.
          final box = BoxConstraints(
            maxWidth: width != null && width!.isFinite ? constraints.constrainWidth(width!) : constraints.maxWidth,
            maxHeight: height != null && height!.isFinite ? constraints.constrainHeight(height!) : constraints.maxHeight,
          );
          return Image(
            image: sizedForBox(context, image, box, fit: fit),
            fit: fit,
            width: width,
            height: height,
            semanticLabel: semanticLabel,
            excludeFromSemantics: semanticLabel == null,
          );
        },
      ),
    );
  }
}
