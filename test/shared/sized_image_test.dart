import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/shared/sized_image.dart';

void main() {
  group('SizedImageProvider.targetSize', () {
    test('cover: the box is covered, aspect kept (4000×3000 in 1080×830)', () {
      final s = SizedImageProvider.targetSize(4000, 3000, width: 1080, height: 830, cover: true);
      // scale = max(1080/4000, 830/3000) = 0.277 → height binds? 0.27 vs 0.2767
      expect(s.width, greaterThanOrEqualTo(1080));
      expect(s.height, greaterThanOrEqualTo(830));
      expect(s.width! * s.height!, lessThan(4000 * 3000 / 10), reason: '>10× fewer pixels');
    });

    test('contain: fits inside the box', () {
      final s = SizedImageProvider.targetSize(4000, 3000, width: 1080, height: 1080, cover: false);
      expect(s.width, 1080);
      expect(s.height, 810);
    });

    test('one side unbounded: the bounded side decides', () {
      final s = SizedImageProvider.targetSize(4000, 3000, width: 1000, height: double.infinity, cover: true);
      expect(s.width, 1000);
      expect(s.height, 750);
    });

    test('never upscales; unbounded box = full size', () {
      expect(SizedImageProvider.targetSize(800, 600, width: 1080, height: 1080, cover: true).width, isNull);
      expect(SizedImageProvider.targetSize(4000, 3000, width: double.infinity, height: double.infinity, cover: true).width, isNull);
    });
  });

  testWidgets('sizedForBox decodes a big image at the box size × devicePixelRatio', (tester) async {
    // 400×300 PNG, shown in a 50×50 box at dpr 2 → decoded ≤ ~128 px tall.
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 400, 300), Paint()..color = const Color(0xFF00FF00));
    final img = await tester.runAsync(() => recorder.endRecording().toImage(400, 300));
    final bytes = await tester.runAsync(() => img!.toByteData(format: ui.ImageByteFormat.png));
    final memory = MemoryImage(Uint8List.view(bytes!.buffer));

    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(devicePixelRatio: 2),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 50,
            height: 50,
            child: Builder(builder: (context) {
              final provider = sizedForBox(context, memory, const BoxConstraints(maxWidth: 50, maxHeight: 50), fit: BoxFit.cover);
              return Image(
                image: provider,
                fit: BoxFit.cover,
                frameBuilder: (context, child, frame, _) => child,
              );
            }),
          ),
        ),
      ),
    ));
    // Decoding happens off the fake clock: let it finish, then rebuild.
    RawImage raw() => tester.widget<RawImage>(find.byType(RawImage));
    for (var i = 0; i < 50 && raw().image == null; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    final image = raw().image;
    expect(image, isNotNull);
    expect(image!.height, lessThanOrEqualTo(128), reason: 'not the 300 px original');
    expect(image.height, greaterThanOrEqualTo(100), reason: 'covers 50 dp × dpr 2');
  });
}
