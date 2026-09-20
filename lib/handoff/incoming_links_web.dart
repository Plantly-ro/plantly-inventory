import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'incoming_links.dart';

IncomingLinks createIncomingLinks() => HashIncomingLinks();
void disposeIncomingLinks(IncomingLinks links) {
  if (links is HashIncomingLinks) links.dispose();
}

/// Web: the page URL at startup (`/#/import?d=…`) plus every `hashchange`.
/// The fragment never reaches the server, so the payload stays out of logs.
class HashIncomingLinks implements IncomingLinks {
  HashIncomingLinks() {
    _listener = ((web.Event _) {
      _controller.add(Uri.parse(web.window.location.href));
    }).toJS;
    web.window.addEventListener('hashchange', _listener);
  }

  final _controller = StreamController<Uri>.broadcast();
  late final JSFunction _listener;

  @override
  Future<Uri?> initial() async => Uri.parse(web.window.location.href);

  @override
  Stream<Uri> get stream => _controller.stream;

  @override
  void consume() {
    final loc = web.window.location;
    if (loc.hash.isEmpty) return;
    web.window.history.replaceState(null, '', loc.pathname + loc.search);
  }

  void dispose() {
    web.window.removeEventListener('hashchange', _listener);
    _controller.close();
  }
}
