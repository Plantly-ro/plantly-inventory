{{flutter_js}}
{{flutter_build_config}}

// Plantly Inventory loader (custom flutter_bootstrap.js template).
// Marker checked by tool/web_version_assets.py: plantly-release-relative-loader
//
// Flutter web file names are not content-hashed, and Cloudflare rewrites
// Cache-Control on .js to a 4h browser TTL, so after a deploy returning
// browsers could run a stale main.dart.js / canvaskit / asset manifest mix.
// The CI post-build step (tool/web_version_assets.py) therefore moves every
// build output except index.html & co. under /v/<release>/ and points
// index.html at /v/<release>/flutter_bootstrap.js. Everything below is
// resolved relative to THIS script's own URL, so each release only ever
// loads its own files (and still works unversioned for a plain
// `flutter build web` / `flutter run`, where this script sits at the root).
(function () {
  "use strict";
  var self = document.currentScript;
  var releaseBase = new URL(".", (self && self.src) || document.baseURI).href;
  var config = {
    entrypointBaseUrl: releaseBase, // main.dart.js
    assetBase: releaseBase, // assets/ (AssetManifest, FontManifest, fonts, images)
    // Glyph-fallback fonts (emoji, symbols) from our own origin instead of
    // https://fonts.gstatic.com/s/ — see tool/fetch_web_fallback_fonts.sh.
    // Version-pinned upstream paths under /vendor/, shared by all releases.
    fontFallbackBaseUrl: new URL("vendor/fallback-fonts/", document.baseURI).href,
  };
  // --no-web-resources-cdn (CI) bundles CanvasKit; keep it per-release too.
  if (_flutter.buildConfig && _flutter.buildConfig.useLocalCanvasKit) {
    config.canvasKitBaseUrl = releaseBase + "canvaskit/";
  }
  _flutter.loader.load({ config: config });
})();
