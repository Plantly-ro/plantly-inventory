import 'package:drift_flutter/drift_flutter.dart' show WasmStorageImplementation;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database/app_database.dart';

/// True when the browser build's database is in memory only (drift's
/// silent fallback): every edit is lost on reload unless it reached the
/// cloud. Always false off web. Rebuilds when the database opens.
final databaseInMemoryProvider = Provider<bool>((ref) {
  final storage = AppDatabase.webStorage;
  void changed() => ref.invalidateSelf();
  storage.addListener(changed);
  ref.onDispose(() => storage.removeListener(changed));
  return storage.value == WasmStorageImplementation.inMemory;
});
