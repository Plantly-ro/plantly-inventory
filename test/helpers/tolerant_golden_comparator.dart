import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden comparator that tolerates a small share of differing pixels.
///
/// The goldens are rendered with the local SDK; CI runs a different Flutter
/// patch release whose text shaping moves a few edge pixels, which the exact
/// [LocalFileComparator] reports as a failure. This wrapper computes the
/// differing-pixel ratio (via [GoldenFileComparator.compareLists]) and passes
/// when it is at or below [tolerance]. Locally the tolerance is 0 by default,
/// so the phone byte-identity guarantee still holds; `--update-goldens` is
/// untouched because [update] delegates to the inner comparator.
class TolerantGoldenFileComparator extends GoldenFileComparator {
  TolerantGoldenFileComparator(this.inner, {required this.tolerance})
      : assert(tolerance >= 0 && tolerance <= 1);

  final LocalFileComparator inner;

  /// Maximum allowed fraction (0..1) of pixels that may differ.
  final double tolerance;

  /// `PLANTLY_GOLDEN_TOLERANCE` when set; otherwise 0.02 on CI (`CI=true`,
  /// which GitLab sets) and 0 locally.
  static double toleranceFromEnvironment([Map<String, String>? env]) {
    final e = env ?? Platform.environment;
    final explicit = double.tryParse(e['PLANTLY_GOLDEN_TOLERANCE'] ?? '');
    if (explicit != null) return explicit.clamp(0.0, 1.0);
    return e['CI'] == 'true' ? 0.02 : 0.0;
  }

  /// Fraction of pixels that differ between two encoded images (1.0 when the
  /// dimensions differ or either fails to decode).
  static Future<double> diffRatio(List<int> test, List<int> master) async {
    final result = await GoldenFileComparator.compareLists(test, master);
    return result.passed ? 0.0 : result.diffPercent;
  }

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    if (tolerance <= 0) return inner.compare(imageBytes, golden);
    // `getGoldenBytes` is protected on LocalFileComparator; resolve the file
    // the same way it does (relative to the test file's directory).
    final file = File.fromUri(inner.basedir.resolveUri(golden));
    if (!file.existsSync()) {
      throw FlutterError('Golden "$golden" could not be compared against non-existent file: ${file.path}');
    }
    final goldenBytes = await file.readAsBytes();
    final result = await GoldenFileComparator.compareLists(imageBytes, goldenBytes);
    if (result.passed || result.diffPercent <= tolerance) {
      if (!result.passed) {
        debugPrint('Golden "$golden": ${(result.diffPercent * 100).toStringAsFixed(2)}% pixels differ '
            '(tolerated, limit ${(tolerance * 100).toStringAsFixed(2)}%).');
      }
      return true;
    }
    final error = await inner.generateFailureOutput(result, golden, inner.basedir);
    throw FlutterError(error);
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) => inner.update(golden, imageBytes);

  @override
  Uri getTestUri(Uri key, int? version) => inner.getTestUri(key, version);
}
