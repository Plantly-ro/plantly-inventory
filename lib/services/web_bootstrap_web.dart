import 'dart:async';
import 'dart:js_interop';
import 'dart:math';

import 'package:web/web.dart' as web;

import '../sync/hlc.dart';
import '../sync/sync_tabs_web.dart' show listenForTabReload;

/// Ask the browser to mark this origin's storage as persistent. Without it
/// OPFS/IndexedDB are "best-effort" and evictable under pressure (Safari
/// purges after 7 days without a visit). Best-effort: browsers may deny or
/// not implement it, and the app works either way.
///
/// Also claims this tab's HLC lane ([HlcClock.lane]) before any clock is
/// built: every tab of the install shares one device id and one database —
/// and listens for the "reload" another tab sends after moving the link.
Future<void> initWebPlatform() async {
  try {
    await web.window.navigator.storage.persist().toDart;
  } catch (_) {
    // Unsupported or denied — nothing to do.
  }
  HlcClock.defaultLane = await claimHlcLane();
  listenForTabReload();
}

/// Never completed: a claimed lane lock is held until the tab goes away.
final Completer<void> _laneHeld = Completer<void>();

/// The first free `plantly-hlc-lane-<n>` Web Lock (held for the tab's
/// lifetime, so an open tab's lane is never handed to another tab; a closed
/// tab's lane is reused). Without Web Locks: a random lane — a collision
/// then needs two tabs, the same lane AND the same millisecond.
Future<int> claimHlcLane() async {
  try {
    final locks = web.window.navigator.locks;
    for (var lane = 0; lane < HlcClock.laneCount; lane++) {
      final granted = Completer<bool>();
      var abandoned = false;
      locks.request(
        'plantly-hlc-lane-$lane',
        web.LockOptions(ifAvailable: true),
        ((web.Lock? lock) {
          // A grant that arrives after we moved on is handed straight back.
          if (lock == null || abandoned) {
            if (!granted.isCompleted) granted.complete(false);
            return null;
          }
          granted.complete(true);
          return _laneHeld.future.toJS;
        }).toJS,
      );
      // `ifAvailable` answers at once, but a tab still booting can take a
      // few seconds to run the callback — wait generously, never leak.
      final ok = await granted.future.then<bool?>((v) => v).timeout(const Duration(seconds: 15), onTimeout: () {
        abandoned = true;
        return null;
      });
      if (ok == null) break; // Web Locks not answering: don't hold up the boot
      if (ok) return lane;
    }
  } catch (_) {
    // No Web Locks (very old browser / insecure context).
  }
  return Random().nextInt(HlcClock.laneCount);
}
