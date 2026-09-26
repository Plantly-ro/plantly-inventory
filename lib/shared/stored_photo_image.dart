import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';

/// Renders a photo from the content-addressed store by sha, falling back
/// to [placeholder] while loading or when the blob is missing. The only
/// place the UI touches photo bytes — platform differences (file vs
/// IndexedDB) stay inside [PhotoBlobStore].
class StoredPhotoImage extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(photoRepositoryProvider);
    return FutureBuilder<ImageProvider?>(
      future: repo.imageFor(sha),
      builder: (context, snap) {
        final image = snap.data;
        if (image == null) return placeholder;
        return Image(image: image, fit: fit, width: width, height: height);
      },
    );
  }
}
