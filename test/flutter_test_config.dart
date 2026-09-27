import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';

import 'helpers/tolerant_golden_comparator.dart';

/// Global flutter_test config — loaded automatically by flutter_test before
/// any test runs.
///
/// Drift's default `DynamicLibrary.open('libsqlite3.so')` only works when an
/// unversioned `libsqlite3.so` sits on the loader's search path. That holds on
/// Debian/Ubuntu with `libsqlite3-dev`, but not on hosts that only ship the
/// runtime `libsqlite3.so.0` (Debian without -dev), and not on NixOS where
/// nothing lives on the default dlopen path at all. Rather than pin one
/// distro's path (the old hard-coded `/usr/lib/x86_64-linux-gnu/...` broke the
/// whole Drift suite when this box moved from Debian to NixOS — see issue #6),
/// probe a list of candidates and use the first that actually loads.
///
/// Set `PLANTLY_SQLITE3` to an absolute path or soname to force a specific
/// library — this is the intended escape hatch for hosts (e.g. NixOS) where the
/// library lives at a non-standard, store-specific path. Point it at the
/// system sqlite, e.g. `${pkgs.sqlite.out}/lib/libsqlite3.so`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (Platform.isLinux) {
    open.overrideFor(OperatingSystem.linux, _openSqlite3);
  }
  // Tests routinely open a fresh in-memory AppDatabase per setUp. Drift
  // warns about multiple instances to catch production misuse; not
  // applicable in tests where each executor is isolated.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  await loadAppFonts();
  // `flutter test` installs a LocalFileComparator for the current test file
  // before this runs; wrap it so CI (a different SDK patch) tolerates text
  // shaping drift while local runs stay exact. See the class doc.
  if (goldenFileComparator case final LocalFileComparator local) {
    goldenFileComparator = TolerantGoldenFileComparator(
      local,
      tolerance: TolerantGoldenFileComparator.toleranceFromEnvironment(),
    );
  }
  await testMain();
}

/// Register the bundled typefaces (Inter, Plus Jakarta Sans) plus Material
/// Icons with the test font manager so goldens render real glyphs instead
/// of flutter_test's Ahem boxes. Reads the TTFs straight from `assets/fonts/`
/// (cwd is the package root under `flutter test`), and MaterialIcons from
/// the SDK cache — skipped silently if the SDK layout is unexpected.
Future<void> loadAppFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    var any = false;
    for (final p in paths) {
      final f = File(p);
      if (!f.existsSync()) continue;
      any = true;
      loader.addFont(f.readAsBytes().then((b) => ByteData.sublistView(b)));
    }
    if (any) await loader.load();
  }

  await load('Inter', [
    'assets/fonts/Inter-Regular.ttf',
    'assets/fonts/Inter-Italic.ttf',
    'assets/fonts/Inter-Medium.ttf',
    'assets/fonts/Inter-SemiBold.ttf',
    'assets/fonts/Inter-SemiBoldItalic.ttf',
    'assets/fonts/Inter-Bold.ttf',
    'assets/fonts/Inter-ExtraBold.ttf',
  ]);
  await load('PlusJakartaSans', [
    'assets/fonts/PlusJakartaSans-Bold.ttf',
    'assets/fonts/PlusJakartaSans-ExtraBold.ttf',
  ]);

  final roots = <String>[
    if (Platform.environment['FLUTTER_ROOT'] case final r? when r.isNotEmpty) r,
    // <sdk>/bin/cache/dart-sdk/bin/dart → <sdk>
    File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path,
  ];
  for (final root in roots) {
    final icons = '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
    if (File(icons).existsSync()) {
      await load('MaterialIcons', [icons]);
      break;
    }
  }
}

DynamicLibrary _openSqlite3() {
  final override = Platform.environment['PLANTLY_SQLITE3'];
  final candidates = <String>[
    if (override != null && override.isNotEmpty) override,
    'libsqlite3.so', // Debian/Ubuntu with -dev; default dlopen search path
    'libsqlite3.so.0', // Debian/Ubuntu runtime-only (no -dev)
    '/usr/lib/x86_64-linux-gnu/libsqlite3.so.0', // Debian multiarch fallback
  ];

  final errors = <String>[];
  for (final candidate in candidates) {
    try {
      return DynamicLibrary.open(candidate);
    } on ArgumentError catch (e) {
      errors.add('  $candidate -> ${e.message}');
    }
  }

  throw StateError(
    'Could not load libsqlite3 for the Drift test suite. Tried:\n'
    '${errors.join('\n')}\n'
    'Set PLANTLY_SQLITE3 to the absolute path of your system libsqlite3 '
    '(e.g. on NixOS: \${pkgs.sqlite.out}/lib/libsqlite3.so).',
  );
}
