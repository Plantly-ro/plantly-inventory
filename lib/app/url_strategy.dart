import 'url_strategy_stub.dart' if (dart.library.js_interop) 'url_strategy_web.dart' as impl;

/// Web: switch from `/#/…` to real path URLs (`/plants/<id>`) so the browser
/// back button, bookmarks and the Caddy `try_files … /index.html` fallback
/// all agree. No-op on io. Call first thing in `main`, before `runApp`.
///
/// Also records the page URL as loaded ([takeLaunchHref]) BEFORE Flutter's
/// browser history takes over: the path strategy re-writes the address bar
/// to `pathname + search` on its first use, dropping the fragment — so a
/// `/join#c=<code>` invite (or any `#…` payload) read later had already
/// lost its code and landed on Home silently.
void configureUrlStrategy() => impl.configureUrlStrategy();

String? _launchHref;

/// Remember the URL the page was opened with (web; first call wins).
void rememberLaunchHref(String href) => _launchHref ??= href;

/// The launch URL recorded by [configureUrlStrategy], once (null after the
/// first call, on io, or when it was never recorded).
String? takeLaunchHref() {
  final href = _launchHref;
  _launchHref = null;
  return href;
}
