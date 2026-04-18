import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/image_processor.dart';

Uint8List _bytes(int n) => Uint8List(n);

void main() {
  group('NoopImageProcessor', () {
    const proc = NoopImageProcessor();

    test('toDisplay returns the input unchanged', () async {
      final input = _bytes(50 * 1024);
      expect(await proc.toDisplay(input), same(input));
    });

    test('toThumbnail returns the input unchanged', () async {
      final input = _bytes(50 * 1024);
      expect(await proc.toThumbnail(input), same(input));
    });
  });

  group('ImageProcessor contracts', () {
    test('passthrough threshold is documented at 200 KB', () {
      expect(ImageProcessor.passthroughBytes, 200 * 1024);
    });

    test('display max is 1600 (matches PLAN.md)', () {
      expect(ImageProcessor.displayMaxPx, 1600);
    });

    test('thumbnail max fits comfortably on a list row', () {
      expect(ImageProcessor.thumbnailMaxPx, lessThanOrEqualTo(400));
    });
  });
}
