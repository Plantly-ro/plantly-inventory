import 'dart:ui';

import 'package:flutter/material.dart';

/// Lets a mouse drag (not just the wheel) scroll lists — matters for the
/// horizontal chip rows and plant strips on desktop/web where the default
/// behaviour only accepts touch. Touch devices are unaffected.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.unknown,
      };
}
