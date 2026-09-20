import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'incoming_links_io.dart' if (dart.library.js_interop) 'incoming_links_web.dart' as platform;

/// Source of URIs the OS / browser hands to the app: the launch link plus
/// links arriving while running. Platform halves: `app_links` on io,
/// `location.hash` + `hashchange` on web.
abstract class IncomingLinks {
  /// The link the app was opened with, if any (consumed once).
  Future<Uri?> initial();

  /// Links arriving while the app is running.
  Stream<Uri> get stream;
}

/// Test double — push URIs with [emit].
class FakeIncomingLinks implements IncomingLinks {
  FakeIncomingLinks({this.initialUri});
  Uri? initialUri;
  final _controller = StreamController<Uri>.broadcast();

  @override
  Future<Uri?> initial() async => initialUri;

  @override
  Stream<Uri> get stream => _controller.stream;

  void emit(Uri uri) => _controller.add(uri);

  Future<void> dispose() => _controller.close();
}

/// Pull the PlantlyExport `d` parameter out of any of the three accepted
/// link forms (CONTRACT §4a), or null when [uri] is not an import link:
///  1. `plantlyinventory://import#d=<d>`
///  2. `https://<host>/app/inventory/import#d=<d>`
///  3. `<inventory web>/#/import?d=<d>`
String? extractImportParam(Uri uri) {
  final fragment = uri.fragment;
  if (uri.scheme == 'plantlyinventory') {
    if (uri.host != 'import' && !uri.path.startsWith('/import') && uri.path != 'import') return null;
    return _paramFromQueryString(fragment) ?? uri.queryParameters['d'];
  }
  if (uri.scheme == 'https' || uri.scheme == 'http') {
    if (uri.path.endsWith('/app/inventory/import')) {
      return _paramFromQueryString(fragment) ?? uri.queryParameters['d'];
    }
    return extractImportParamFromHash(fragment);
  }
  return null;
}

/// Form 3 — the fragment `/import?d=<d>` (with or without the leading `#`).
String? extractImportParamFromHash(String hash) {
  var h = hash.startsWith('#') ? hash.substring(1) : hash;
  if (!h.startsWith('/import')) return null;
  h = h.substring('/import'.length);
  if (h.startsWith('?')) h = h.substring(1);
  return _paramFromQueryString(h);
}

String? _paramFromQueryString(String qs) {
  if (qs.isEmpty) return null;
  try {
    final d = Uri.splitQueryString(qs)['d'];
    return d == null || d.isEmpty ? null : d;
  } on FormatException {
    // base64url never needs percent-decoding, but a stray '%' would throw.
    final m = RegExp(r'(?:^|&)d=([^&]+)').firstMatch(qs);
    return m?.group(1);
  }
}

final incomingLinksProvider = Provider<IncomingLinks>((ref) {
  final links = platform.createIncomingLinks();
  ref.onDispose(() => platform.disposeIncomingLinks(links));
  return links;
});
