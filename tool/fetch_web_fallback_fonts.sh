#!/usr/bin/env bash
# Mirrors the CanvasKit FALLBACK fonts the web build may need into
# web/vendor/fallback-fonts/, so the browser never talks to fonts.gstatic.com
# (privacy: same reason the app bundles Inter / Plus Jakarta Sans / Roboto in
# assets/fonts and the Android build makes no font requests at all).
#
# How it fits together:
#   * The Flutter web engine downloads a glyph-fallback font whenever text
#     contains a code point the app's own fonts lack, from
#     `<fontFallbackBaseUrl><path>` with <path> taken from the SDK's
#     engine/src/flutter/lib/web_ui/lib/src/engine/font_fallback_data.dart
#     (e.g. notocoloremoji/v32/<hash>.0.woff2). The default base is
#     https://fonts.gstatic.com/s/.
#   * web/flutter_bootstrap.js points fontFallbackBaseUrl at /vendor/fallback-fonts/
#     on our own origin. Families mirrored here keep working (emoji in plant
#     names/notes, ✓ ★ ☀ style symbols); anything else (CJK, rare scripts)
#     gets a 404 from our origin and renders as tofu — never a third-party hit.
#   * Paths are copied verbatim (they carry the upstream version + content
#     hash), so /vendor/* can be served immutable.
#
# Refetching is safe: the ledger step refuses to change the digest of a path
# it already knows (tool/web_vendor_ledger.sh). Re-run after a Flutter bump if the lint-tools test
# (tool/tests/test_web_version_assets.py) says the SDK's fallback table no
# longer lists these paths: update FAMILIES/paths below from the new
# font_fallback_data.dart, delete stale dirs, re-run.
# Verified identical for Flutter 3.44.0 (CI pin) and 3.47.x (local).
set -euo pipefail

cd "$(dirname "$0")/.."

out="web/vendor/fallback-fonts"
base="https://fonts.gstatic.com/s"

# Every shard of each mirrored family (a family is only useful complete).
paths=(
  # Noto Color Emoji — 12 shards, ~2.0 MB total
  notocoloremoji/v32/Yq6P-KqIXTD0t4D9z1ESnKM3-HpFabsE4tq3luCC7p-aXxcn.0.woff2
  notocoloremoji/v32/Yq6P-KqIXTD0t4D9z1ESnKM3-HpFabsE4tq3luCC7p-aXxcn.1.woff2
  notocoloremoji/v32/Yq6P-KqIXTD0t4D9z1ESnKM3-HpFabsE4tq3luCC7p-aXxcn.2.woff2
  notocoloremoji/v32/Yq6P-KqIXTD0t4D9z1ESnKM3-HpFabsE4tq3luCC7p-aXxcn.3.woff2
  notocoloremoji/v32/Yq6P-KqIXTD0t4D9z1ESnKM3-HpFabsE4tq3luCC7p-aXxcn.4.woff2
  notocoloremoji/v32/Yq6P-KqIXTD0t4D9z1ESnKM3-HpFabsE4tq3luCC7p-aXxcn.5.woff2
  notocoloremoji/v32/Yq6P-KqIXTD0t4D9z1ESnKM3-HpFabsE4tq3luCC7p-aXxcn.6.woff2
  notocoloremoji/v32/Yq6P-KqIXTD0t4D9z1ESnKM3-HpFabsE4tq3luCC7p-aXxcn.7.woff2
  notocoloremoji/v32/Yq6P-KqIXTD0t4D9z1ESnKM3-HpFabsE4tq3luCC7p-aXxcn.8.woff2
  notocoloremoji/v32/Yq6P-KqIXTD0t4D9z1ESnKM3-HpFabsE4tq3luCC7p-aXxcn.9.woff2
  notocoloremoji/v32/Yq6P-KqIXTD0t4D9z1ESnKM3-HpFabsE4tq3luCC7p-aXxcn.10.woff2
  notocoloremoji/v32/Yq6P-KqIXTD0t4D9z1ESnKM3-HpFabsE4tq3luCC7p-aXxcn.11.woff2
)

# Families whose remaining shards are looked up from the SDK table, so the
# list above stays readable. Noto Sans (Latin/Greek/Cyrillic extensions beyond
# Inter), Noto Sans Symbols + Symbols 2 (dingbats, arrows, misc symbols).
sdk_families=(notosans notosanssymbols notosanssymbols2)

flutter_root="${FLUTTER_ROOT:-$(dirname "$(dirname "$(readlink -f "$(command -v flutter)")")")}"
table="$flutter_root/engine/src/flutter/lib/web_ui/lib/src/engine/font_fallback_data.dart"
[ -f "$table" ] || { echo "ERROR: $table not found (set FLUTTER_ROOT)" >&2; exit 1; }
for fam in "${sdk_families[@]}"; do
  while IFS= read -r p; do paths+=("$p"); done < <(grep -oE "'${fam}/v[0-9]+/[^']+'" "$table" | tr -d "'")
done

rm -rf "$out"
for p in "${paths[@]}"; do
  grep -q "'$p'" "$table" || { echo "ERROR: $p is not in $table (Flutter bump? see header)" >&2; exit 1; }
  mkdir -p "$out/$(dirname "$p")"
  curl -fsSL --max-time 120 -o "$out/$p" "$base/$p"
  # woff2 magic "wOF2"
  [ "$(head -c4 "$out/$p")" = "wOF2" ] || { echo "ERROR: $out/$p is not woff2" >&2; exit 1; }
done
# Licence travels with the fonts (all Noto families: SIL OFL 1.1).
# Pinned commit: /vendor/ is immutable, so the licence text must not drift either.
curl -fsSL --max-time 60 -o "$out/OFL.txt" https://raw.githubusercontent.com/google/fonts/5e8a3ba899557829a76cfdac30fa512bda91d7ca/ofl/notosans/OFL.txt
grep -q "SIL Open Font License" "$out/OFL.txt" || { echo "ERROR: OFL.txt download looks wrong" >&2; exit 1; }
echo "mirrored ${#paths[@]} files: $(du -sh "$out" | cut -f1)"

# Refresh the immutability ledger (refuses to change an existing path's digest).
# shellcheck source=tool/web_vendor_ledger.sh
. tool/web_vendor_ledger.sh
web_vendor_ledger_update
