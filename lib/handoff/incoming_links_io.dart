import 'package:app_links/app_links.dart';

import 'incoming_links.dart';

IncomingLinks createIncomingLinks() => AppLinksIncomingLinks();
void disposeIncomingLinks(IncomingLinks links) {}

/// io: `app_links` — Android intent-filters for `plantlyinventory://import`
/// and `https://plantly.ro/app/inventory/import` (AndroidManifest.xml).
class AppLinksIncomingLinks implements IncomingLinks {
  AppLinksIncomingLinks({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();
  final AppLinks _appLinks;

  @override
  Future<Uri?> initial() async {
    try {
      return await _appLinks.getInitialLink();
    } catch (_) {
      // Desktop hosts without the plugin — no launch link.
      return null;
    }
  }

  @override
  Stream<Uri> get stream => _appLinks.uriLinkStream;
}
