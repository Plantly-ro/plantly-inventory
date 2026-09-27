import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/tolerant_golden_comparator.dart';

/// 4×4 opaque PNG: [base] everywhere except the pixels in [odd], which are
/// painted red. 16 pixels total, so each odd pixel is 1/16 = 6.25 %.
Future<Uint8List> _png({Set<int> odd = const {}, Color base = Colors.white}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 4, 4), Paint()..color = base);
  for (final i in odd) {
    canvas.drawRect(Rect.fromLTWH((i % 4).toDouble(), (i ~/ 4).toDouble(), 1, 1), Paint()..color = Colors.red);
  }
  final image = await recorder.endRecording().toImage(4, 4);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  test('diffRatio is the differing-pixel fraction', () async {
    final a = await _png();
    final one = await _png(odd: {5});
    final three = await _png(odd: {0, 7, 15});
    expect(await TolerantGoldenFileComparator.diffRatio(a, a), 0.0);
    expect(await TolerantGoldenFileComparator.diffRatio(one, a), closeTo(1 / 16, 1e-9));
    expect(await TolerantGoldenFileComparator.diffRatio(three, a), closeTo(3 / 16, 1e-9));
  });

  test('toleranceFromEnvironment: explicit > CI default > 0', () {
    expect(TolerantGoldenFileComparator.toleranceFromEnvironment({}), 0.0);
    expect(TolerantGoldenFileComparator.toleranceFromEnvironment({'CI': 'true'}), 0.02);
    expect(TolerantGoldenFileComparator.toleranceFromEnvironment({'CI': 'true', 'PLANTLY_GOLDEN_TOLERANCE': '0.1'}), 0.1);
    expect(TolerantGoldenFileComparator.toleranceFromEnvironment({'PLANTLY_GOLDEN_TOLERANCE': 'nope'}), 0.0);
  });

  group('compare against a golden on disk', () {
    late Directory dir;
    late LocalFileComparator local;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('plantly-golden-');
      // basedir = the directory of the "test file" the comparator is built for.
      local = LocalFileComparator(Uri.file('${dir.path}/x_test.dart'));
      await File('${dir.path}/g.png').writeAsBytes(await _png());
    });
    tearDown(() => dir.delete(recursive: true));

    test('tolerance 0 stays exact: one pixel fails', () async {
      final c = TolerantGoldenFileComparator(local, tolerance: 0);
      expect(await c.compare(await _png(), Uri.parse('g.png')), isTrue);
      await expectLater(c.compare(await _png(odd: {5}), Uri.parse('g.png')), throwsA(isA<FlutterError>()));
    });

    test('one pixel (6.25 %) passes at 0.1 and fails at 0.05', () async {
      final candidate = await _png(odd: {5});
      expect(await TolerantGoldenFileComparator(local, tolerance: 0.1).compare(candidate, Uri.parse('g.png')), isTrue);
      await expectLater(
        TolerantGoldenFileComparator(local, tolerance: 0.05).compare(candidate, Uri.parse('g.png')),
        throwsA(isA<FlutterError>()),
      );
    });
  });
}
