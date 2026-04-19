import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_plants.dart';
import '../data/providers.dart';
import '../theme/tokens.dart';

/// Static gradient+leaf stand-in used when no attached photo is available
/// (e.g. Propagate dialog preview, or the fallback behind PlantPhotoThumb).
class PlantThumb extends StatelessWidget {
  const PlantThumb({super.key, required this.plant, this.size = 100});
  final MockPlant plant;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [plant.swatch, PlantlyTokens.botanical700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.1),
      ),
      alignment: Alignment.bottomCenter,
      padding: EdgeInsets.only(bottom: size * 0.12),
      child: Icon(
        Icons.eco,
        size: size * 0.45,
        color: Colors.white.withValues(alpha: 0.8),
      ),
    );
  }
}

/// Stream-backed plant thumbnail. Renders the first attached photo when
/// one exists; falls back to the gradient stub. Used by Home grid cards,
/// plant rows, and the Plant Detail hero's carousel dots.
///
/// The widget fills whatever constraints the parent provides (BoxFit.cover
/// on the image, `SizedBox.expand` on the stub). Callers that don't have
/// bounded constraints can pass [stubSize] to size the fallback gracefully.
class PlantPhotoThumb extends ConsumerWidget {
  const PlantPhotoThumb({
    super.key,
    required this.plantId,
    required this.fallback,
    this.size,
    this.stubSize = 120,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String plantId;
  final MockPlant fallback;
  /// When non-null + finite, the widget constrains itself to this square.
  /// When null, the widget fills its parent (for `Positioned.fill`
  /// or tight parent constraints).
  final double? size;
  /// Only used to size the gradient fallback stub. Never propagated to
  /// the image (which always uses [fit]).
  final double stubSize;
  final BoxFit fit;
  final BorderRadiusGeometry? borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shas = ref.watch(attachedPhotosProvider(plantId)).maybeWhen(
          data: (list) => list,
          orElse: () => const <String>[],
        );
    final content = shas.isEmpty
        ? _Fallback(fallback: fallback, stubSize: _stubSize())
        : _FirstPhoto(sha: shas.first, fit: fit, fallback: fallback, stubSize: _stubSize());
    final clipped = borderRadius == null
        ? content
        : ClipRRect(borderRadius: borderRadius!, child: content);
    final fixedSize = size;
    if (fixedSize != null && fixedSize.isFinite) {
      return SizedBox(width: fixedSize, height: fixedSize, child: clipped);
    }
    return clipped;
  }

  double _stubSize() {
    final s = size;
    if (s != null && s.isFinite) return s;
    return stubSize;
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.fallback, required this.stubSize});
  final MockPlant fallback;
  final double stubSize;

  @override
  Widget build(BuildContext context) {
    return Center(child: PlantThumb(plant: fallback, size: stubSize));
  }
}

class _FirstPhoto extends ConsumerWidget {
  const _FirstPhoto({
    required this.sha,
    required this.fit,
    required this.fallback,
    required this.stubSize,
  });

  final String sha;
  final BoxFit fit;
  final MockPlant fallback;
  final double stubSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(photoRepositoryProvider);
    return FutureBuilder(
      future: repo.byHash(sha),
      builder: (context, snap) {
        final path = snap.data?.localPath;
        if (path != null && File(path).existsSync()) {
          return Image.file(
            File(path),
            fit: fit,
            width: double.infinity,
            height: double.infinity,
          );
        }
        return _Fallback(fallback: fallback, stubSize: stubSize);
      },
    );
  }
}
