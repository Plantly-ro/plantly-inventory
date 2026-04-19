import 'package:flutter/material.dart';

import '../data/photo_picker.dart';
import '../theme/tokens.dart';

enum PhotoSourceChoice { cameraOne, galleryMulti, galleryOne }

/// Bottom-sheet chooser between Camera and Gallery. Returns `null` if
/// the user dismisses.
Future<PhotoSourceChoice?> showPhotoSourceSheet(
  BuildContext context, {
  required PlantlySurface surface,
  bool multi = true,
}) async {
  return showModalBottomSheet<PhotoSourceChoice>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        decoration: BoxDecoration(
          color: surface.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(PlantlyTokens.radius2xl)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(color: surface.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            _Option(
              surface: surface,
              icon: Icons.camera_alt_outlined,
              label: 'Take photo',
              subtitle: 'Open the camera',
              onTap: () => Navigator.of(ctx).pop(PhotoSourceChoice.cameraOne),
            ),
            const SizedBox(height: 8),
            _Option(
              surface: surface,
              icon: Icons.photo_library_outlined,
              label: multi ? 'Choose from gallery' : 'Choose one from gallery',
              subtitle: multi ? 'Select multiple images' : 'Pick a single image',
              onTap: () => Navigator.of(ctx).pop(
                multi ? PhotoSourceChoice.galleryMulti : PhotoSourceChoice.galleryOne,
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Convenience for single-photo flows (e.g. location map) — handles the
/// chooser + picker call + returns the raw bytes or null.
Future<PickedPhoto?> pickSinglePhotoWithSource(
  BuildContext context,
  PhotoPicker picker,
  PlantlySurface surface,
) async {
  final choice = await showPhotoSourceSheet(context, surface: surface, multi: false);
  switch (choice) {
    case null:
      return null;
    case PhotoSourceChoice.cameraOne:
      return picker.pickFromCamera();
    case PhotoSourceChoice.galleryOne:
    case PhotoSourceChoice.galleryMulti:
      return picker.pickFromGallery();
  }
}

/// Convenience for multi-photo flows (e.g. Plant Detail gallery add).
Future<List<PickedPhoto>> pickMultiPhotoWithSource(
  BuildContext context,
  PhotoPicker picker,
  PlantlySurface surface,
) async {
  final choice = await showPhotoSourceSheet(context, surface: surface, multi: true);
  switch (choice) {
    case null:
      return const [];
    case PhotoSourceChoice.cameraOne:
      final one = await picker.pickFromCamera();
      return one == null ? const [] : [one];
    case PhotoSourceChoice.galleryMulti:
      return picker.pickMultipleFromGallery();
    case PhotoSourceChoice.galleryOne:
      final one = await picker.pickFromGallery();
      return one == null ? const [] : [one];
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.surface,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final PlantlySurface surface;
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface.surface,
      borderRadius: BorderRadius.circular(PlantlyTokens.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PlantlyTokens.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: surface.border),
            borderRadius: BorderRadius.circular(PlantlyTokens.radius),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: surface.greenSoft, borderRadius: BorderRadius.circular(9)),
                child: Icon(icon, color: surface.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text)),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: surface.muted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: surface.muted),
            ],
          ),
        ),
      ),
    );
  }
}
