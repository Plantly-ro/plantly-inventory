import 'url_strategy_stub.dart' if (dart.library.js_interop) 'url_strategy_web.dart' as impl;

/// Web: switch from `/#/…` to real path URLs (`/plants/<id>`) so the browser
/// back button, bookmarks and the Caddy `try_files … /index.html` fallback
/// all agree. No-op on io. Call before `runApp`.
void configureUrlStrategy() => impl.configureUrlStrategy();
