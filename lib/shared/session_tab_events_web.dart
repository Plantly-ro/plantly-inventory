import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// `storage` events only reach the OTHER tabs of the origin — exactly the
/// ones that must stop using the session (and the data) another tab dropped.
Stream<void> sessionRemovedInOtherTab() {
  late final StreamController<void> controller;
  final listener = ((web.Event event) {
    final e = event as web.StorageEvent;
    final key = e.key;
    if (key == null || (key == 'plantly_ro/jwt' && e.newValue == null)) controller.add(null);
  }).toJS;
  controller = StreamController<void>.broadcast(
    onListen: () => web.window.addEventListener('storage', listener),
    onCancel: () => web.window.removeEventListener('storage', listener),
  );
  return controller.stream;
}
