import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'page_reload_stub.dart' if (dart.library.js_interop) 'page_reload_web.dart' as platform;

/// Reload the browser app at its root (web) — every in-memory provider,
/// cache and the router start over. No-op off web. Tests override.
final pageReloaderProvider = Provider<void Function()>((_) => platform.reloadAppRoot);
