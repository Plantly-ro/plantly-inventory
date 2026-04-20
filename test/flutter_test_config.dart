import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:sqlite3/open.dart';

/// Global flutter_test config — loaded automatically by flutter_test before
/// any test runs. On this Debian box the bare `libsqlite3.so` symlink is
/// missing (only `libsqlite3.so.0` is installed), so Drift's default
/// `DynamicLibrary.open('libsqlite3.so')` fails. Point it at the shipped
/// versioned library.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (Platform.isLinux) {
    open.overrideFor(OperatingSystem.linux, () {
      return DynamicLibrary.open('/usr/lib/x86_64-linux-gnu/libsqlite3.so.0');
    });
  }
  // Tests routinely open a fresh in-memory AppDatabase per setUp. Drift
  // warns about multiple instances to catch production misuse; not
  // applicable in tests where each executor is isolated.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  await testMain();
}
