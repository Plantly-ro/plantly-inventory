import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../app/url_strategy.dart' show takeLaunchHref;
import 'incoming_links.dart';

IncomingLinks createIncomingLinks() => HashIncomingLinks();
void disposeIncomingLinks(IncomingLinks links) {
  if (links is HashIncomingLinks) links.dispose();
}

/// Web: the page URL at startup (`/import?d=…`, legacy `/#/import?d=…`, or
/// the OAuth return `/#/auth/callback?token=&nonce=`) plus every
/// `hashchange`. The app runs under the path URL strategy, but the server
/// still answers OAuth with a hash route — which lands here as `/` + hash:
/// the fragment never reaches the server, so the token stays out of logs.
class HashIncomingLinks implements IncomingLinks {
  HashIncomingLinks() {
    _listener = ((web.Event _) {
      _controller.add(Uri.parse(web.window.location.href));
    }).toJS;
    web.window.addEventListener('hashchange', _listener);
  }

  final _controller = StreamController<Uri>.broadcast();
  late final JSFunction _listener;

  /// The URL as loaded (fragment intact — see `takeLaunchHref`), else the
  /// current one.
  @override
  Future<Uri?> initial() async => Uri.parse(takeLaunchHref() ?? web.window.location.href);

  @override
  Stream<Uri> get stream => _controller.stream;

  @override
  void consume() {
    final loc = web.window.location;
    if (isImportPath(loc.pathname) || isAuthCallbackPath(loc.pathname)) {
      // Canonical `/import?d=` form (or a path-form `/auth/callback?token=`):
      // drop path + query so a reload / history entry never carries the
      // payload (the router redirects both to Home anyway).
      web.window.history.replaceState(null, '', '/');
      return;
    }
    if (loc.hash.isEmpty) return;
    web.window.history.replaceState(null, '', loc.pathname + loc.search);
  }

  void dispose() {
    web.window.removeEventListener('hashchange', _listener);
    _controller.close();
  }
}
