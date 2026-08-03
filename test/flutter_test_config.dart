import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:sqlite3/open.dart';

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
  await testMain();
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
