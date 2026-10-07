import 'dart:async';

/// Browser tests only: the root test/flutter_test_config.dart is VM-only
/// (sqlite library path, golden comparator on dart:io).
Future<void> testExecutable(FutureOr<void> Function() testMain) async => testMain();
