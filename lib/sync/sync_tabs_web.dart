import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import 'sync_tabs.dart';

SyncTabs createSyncTabs() {
  try {
    // Web Locks + BroadcastChannel: every evergreen browser; without them
    // each tab simply runs its own runner, as before.
    if (!(web.window.navigator as JSObject).has('locks')) return SyncTabs.single;
    return _WebSyncTabs(web.BroadcastChannel('plantly-sync-tabs'));
  } catch (_) {
    return SyncTabs.single;
  }
}

void disposeSyncTabs(SyncTabs tabs) {
  if (tabs is _WebSyncTabs) tabs.close();
}

/// Re-read localStorage: the previous leader advanced the sync cursor
/// (`PrefsSyncCursor`) behind this tab's prefs cache.
Future<void> onLeadershipGranted() async {
  try {
    await (await SharedPreferences.getInstance()).reload();
  } catch (_) {
    // A stale cursor only means re-pulling ops that apply idempotently.
  }
}

class _WebSyncTabs implements SyncTabs {
  _WebSyncTabs(this._channel) {
    _channel.onmessage = ((web.MessageEvent e) {
      final data = e.data;
      if (data == null || !data.isA<JSString>()) return;
      try {
        final m = SyncTabMessage.fromJson(json.decode((data as JSString).toDart));
        if (m != null) _messages.add(m);
      } catch (_) {
        // Not ours / malformed.
      }
    }).toJS;
  }

  final web.BroadcastChannel _channel;
  final _messages = StreamController<SyncTabMessage>.broadcast();

  @override
  SyncLease acquire(String collectionId) {
    final granted = Completer<void>();
    final hold = Completer<void>();
    final abort = web.AbortController();
    web.window.navigator.locks
        .request(
          'plantly-sync-$collectionId',
          web.LockOptions(signal: abort.signal),
          ((web.Lock? lock) {
            if (!granted.isCompleted) granted.complete();
            return hold.future.toJS;
          }).toJS,
        )
        .toDart
        .catchError((Object _) => null); // aborted while queued
    return SyncLease(
      granted: granted.future,
      onRelease: () {
        if (granted.isCompleted) {
          if (!hold.isCompleted) hold.complete();
        } else {
          abort.abort();
        }
      },
    );
  }

  @override
  Stream<SyncTabMessage> get messages => _messages.stream;

  @override
  void post(SyncTabMessage message) {
    try {
      _channel.postMessage(json.encode(message.toJson()).toJS);
    } catch (_) {
      // Channel closed (tab going away).
    }
  }

  void close() {
    _channel.close();
    unawaited(_messages.close());
  }
}

web.BroadcastChannel? _reloadChannel;

/// Started once at boot (every tab, linked or not): another tab moved the
/// link (re-home, first link, account switch) — reload so this tab's
/// tenant, runner and lists follow instead of writing to the old one.
void listenForTabReload() {
  if (_reloadChannel != null) return;
  try {
    final channel = _reloadChannel = web.BroadcastChannel('plantly-sync-tabs');
    channel.onmessage = ((web.MessageEvent e) {
      final data = e.data;
      if (data == null || !data.isA<JSString>()) return;
      try {
        final m = SyncTabMessage.fromJson(json.decode((data as JSString).toDart));
        if (m?.kind == SyncTabMessageKind.reload) web.window.location.reload();
      } catch (_) {
        // Not ours.
      }
    }).toJS;
  } catch (_) {
    // No BroadcastChannel: tabs pick the change up on their next start.
  }
}
