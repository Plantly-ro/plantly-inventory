#!/usr/bin/env python3
"""Post-build step for the Flutter web build: one URL space per release.

Flutter web output names (main.dart.js, flutter_bootstrap.js, canvaskit/*,
assets/AssetManifest.bin, the tree-shaken MaterialIcons font, ...) are NOT
content-hashed, and Cloudflare's zone Browser Cache TTL rewrites their
Cache-Control to a 4h max-age. Without this step a returning browser can run
a stale build for hours after a deploy, or mix files of two releases.

    python3 tool/web_version_assets.py build/web <release-id>

moves everything except the ROOT_KEEP entries into build/web/v/<release-id>/
and rewrites index.html's <script src="flutter_bootstrap.js"> to
v/<release-id>/flutter_bootstrap.js. The custom web/flutter_bootstrap.js
resolves main.dart.js, assets/ and canvaskit/ relative to its own URL, so
the only mutable URL left is index.html itself (served no-cache; Cloudflare
does not cache HTML). <release-id> must be the release dir name the deploy
uses (REL_ID = CI_COMMIT_SHORT_SHA + hex CI_PIPELINE_ID; unique per build,
since /v/<id>/ is immutable and a new pipeline on the same commit may build
different bytes): Caddy serves /v/<id>/* from `current` and falls back to
releases/<id>/ so tabs still running the previous release keep loading their
own lazily-fetched files. DROP entries (web/prototype/, the design reference
`flutter build web` copies along with web/) are deleted, not shipped.

/vendor/ stays at the root: its paths are pinned by upstream version (drift
worker, sqlite3.wasm, fallback fonts) and are deliberately shared across
releases (see lib/data/database/web_db_assets.dart).

Stdlib only (runs in the Flutter CI image); tests in
tool/tests/test_web_version_assets.py.
"""
from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path

RELEASES_DIR = "v"
# Copied from web/ by `flutter build web` but not part of the app.
DROP = frozenset({"prototype"})
# Stay at the site root: the uncacheable shell, files other origins/tools
# fetch by fixed URL (PWA manifest + icons, favicon, version.json for the
# deploy verify, the service-worker cleanup script at root scope), and the
# version-pinned vendor tree.
ROOT_KEEP = frozenset({
    "index.html",
    "version.json",
    "manifest.json",
    "favicon.png",
    "icons",
    "flutter_service_worker.js",
    "vendor",
    RELEASES_DIR,
})
# Lowercase hex (short sha + hex pipeline id); also what Caddy matches.
RELEASE_ID_RE = re.compile(r"^[0-9a-f]{7,40}$")
BOOTSTRAP_MARKER = "plantly-release-relative-loader"
BOOTSTRAP_TAG_RE = re.compile(r'(<script\b[^>]*\bsrc=")flutter_bootstrap\.js(")')
# Relative src/href references in index.html that must resolve after the move.
REF_RE = re.compile(r'\b(?:src|href)="([^"]+)"')


class VersioningError(Exception):
    pass


def _check_refs(build_dir: Path, index_html: str) -> None:
    for ref in REF_RE.findall(index_html):
        if ref.startswith(("/", "#", "data:", "$")) or "://" in ref:
            continue
        target = ref.split("?", 1)[0].split("#", 1)[0]
        if not (build_dir / target).exists():
            raise VersioningError(f"index.html references {ref!r}, which does not exist after versioning")


def version_build(build_dir: Path, release_id: str) -> Path:
    """Versions build_dir in place; returns the release dir (build_dir/v/<id>)."""
    if not RELEASE_ID_RE.match(release_id):
        raise VersioningError(f"release id {release_id!r} must match {RELEASE_ID_RE.pattern} (short sha + hex pipeline id)")
    if not build_dir.is_dir():
        raise VersioningError(f"{build_dir} is not a directory")
    if (build_dir / RELEASES_DIR).exists():
        raise VersioningError(f"{build_dir / RELEASES_DIR} already exists — build already versioned?")
    for required in ("index.html", "flutter_bootstrap.js", "main.dart.js"):
        if not (build_dir / required).is_file():
            raise VersioningError(f"{build_dir / required} missing — not a Flutter web build?")

    bootstrap = (build_dir / "flutter_bootstrap.js").read_text(encoding="utf-8")
    if BOOTSTRAP_MARKER not in bootstrap:
        # The stock bootstrap loads main.dart.js/assets relative to <base href>,
        # i.e. from the site root, where they no longer are after the move.
        raise VersioningError("flutter_bootstrap.js is not the custom template from web/flutter_bootstrap.js "
                              f"(marker {BOOTSTRAP_MARKER!r} missing); refusing to move files it cannot find")

    index_path = build_dir / "index.html"
    index_html = index_path.read_text(encoding="utf-8")
    tags = BOOTSTRAP_TAG_RE.findall(index_html)
    if len(tags) != 1:
        raise VersioningError(f"expected exactly one <script src=\"flutter_bootstrap.js\"> in index.html, found {len(tags)}")
    new_index = BOOTSTRAP_TAG_RE.sub(rf"\g<1>{RELEASES_DIR}/{release_id}/flutter_bootstrap.js\g<2>", index_html)

    release_dir = build_dir / RELEASES_DIR / release_id
    release_dir.mkdir(parents=True)
    for entry in sorted(build_dir.iterdir()):
        if entry.name in ROOT_KEEP:
            continue
        if entry.name in DROP:
            shutil.rmtree(entry) if entry.is_dir() else entry.unlink()
            continue
        shutil.move(str(entry), str(release_dir / entry.name))

    _check_refs(build_dir, new_index)
    index_path.write_text(new_index, encoding="utf-8")
    return release_dir


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    parser.add_argument("build_dir", type=Path, help="flutter build web output (build/web)")
    parser.add_argument("release_id", help="release id = deploy release dir name (short sha + hex pipeline id)")
    args = parser.parse_args(argv)
    try:
        release_dir = version_build(args.build_dir, args.release_id)
    except VersioningError as e:
        print(f"web_version_assets: ERROR: {e}", file=sys.stderr)
        return 1
    moved = sorted(p.name for p in release_dir.iterdir())
    kept = sorted(p.name for p in args.build_dir.iterdir())
    print(f"web_version_assets: release {args.release_id}: root keeps {kept}; moved under "
          f"{release_dir.relative_to(args.build_dir)}/: {moved}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
