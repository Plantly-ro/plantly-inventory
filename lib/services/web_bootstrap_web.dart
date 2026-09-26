import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Ask the browser to mark this origin's storage as persistent. Without it
/// OPFS/IndexedDB are "best-effort" and evictable under pressure (Safari
/// purges after 7 days without a visit). Best-effort: browsers may deny or
/// not implement it, and the app works either way.
Future<void> initWebPlatform() async {
  try {
    await web.window.navigator.storage.persist().toDart;
  } catch (_) {
    // Unsupported or denied — nothing to do.
  }
}
