import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/main.dart';
import 'package:plantly_inventory/theme/tokens.dart';

/// Privacy issue #12 — typefaces must be bundled, never fetched at runtime.
/// Guards against someone re-adding `google_fonts` (which downloads Inter /
/// Plus Jakarta Sans from fonts.gstatic.com on first launch) and against the
/// pubspec `fonts:` block drifting away from the files in assets/fonts/.
void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();

  group('bundled fonts', () {
    test('pubspec has no google_fonts dependency', () {
      expect(pubspec.contains('google_fonts'), isFalse);
    });

    test('pubspec declares both families under flutter.fonts', () {
      expect(pubspec, contains('family: ${PlantlyFonts.inter}'));
      expect(pubspec, contains('family: ${PlantlyFonts.plusJakartaSans}'));
    });

    test('every declared font asset (and its licence) exists on disk', () {
      final assets = RegExp(r'asset: (assets/fonts/\S+\.ttf)')
          .allMatches(pubspec)
          .map((m) => m.group(1)!)
          .toList();
      expect(assets, isNotEmpty);
      for (final a in assets) {
        expect(File(a).existsSync(), isTrue, reason: '$a missing');
        expect(File(a).lengthSync(), greaterThan(10 * 1024), reason: '$a truncated');
      }
      expect(File('assets/fonts/OFL-Inter.txt').existsSync(), isTrue);
      expect(File('assets/fonts/OFL-PlusJakartaSans.txt').existsSync(), isTrue);
    });

    test('no Dart source references google_fonts or Google font hosts', () {
      final offenders = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) {
            final s = f.readAsStringSync();
            return s.contains('google_fonts') ||
                s.contains('GoogleFonts') ||
                s.contains('gstatic') ||
                s.contains('fonts.google');
          })
          .map((f) => f.path)
          .toList();
      expect(offenders, isEmpty);
    });

    test('theme text styles use the bundled Inter family', () {
      for (final b in Brightness.values) {
        final tt = PlantlyApp.buildTheme(b).textTheme;
        expect(tt.bodyMedium?.fontFamily, PlantlyFonts.inter, reason: '$b bodyMedium');
        expect(tt.titleLarge?.fontFamily, PlantlyFonts.inter, reason: '$b titleLarge');
        expect(tt.labelSmall?.fontFamily, PlantlyFonts.inter, reason: '$b labelSmall');
      }
    });
  });
}
