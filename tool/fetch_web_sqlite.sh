#!/usr/bin/env bash
# Fetches the web sqlite3/drift binaries into web/vendor/. Reproducible source
# for the two files committed in this repo; re-run after bumping the sqlite3 or
# drift versions in pubspec.lock (update the versions below to match).
#
# The version is part of the PATH (web/vendor/<pkg>-<version>/…) on purpose:
# Caddy serves /vendor/* as immutable (cached for a year by browsers and the
# Cloudflare edge), so a different file MUST get a different URL. A bump
# therefore also means: update the two paths in
# lib/data/database/web_db_assets.dart, delete the old vendor dirs, and
# regenerate tool/web_vendor.sha256 (ledger step below; it refuses to change
# the digest of an already-recorded path) — the lint-tools
# tests (tool/tests/test_web_version_assets.py) fail until all three agree.
#
# Pinned (pubspec.lock, 2026-09-18):
#   sqlite3 2.9.4  -> sqlite3.wasm    sha256 922a76b182b6af69b030c8e2fdd3283ecc8e827248b20e4b1f3f3db170b52117
#   drift   2.31.0 -> drift_worker.js sha256 f0a9b87085f732fd7b6ee7eb34d3858c556f05d221eb1febfc443649cd365752
set -euo pipefail

cd "$(dirname "$0")/.."

sqlite3_version="2.9.4"
drift_version="2.31.0"
wasm_out="web/vendor/sqlite3-${sqlite3_version}/sqlite3.wasm"
worker_out="web/vendor/drift-${drift_version}/drift_worker.js"

wasm_url="https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-${sqlite3_version}/sqlite3.wasm"
worker_url="https://github.com/simolus3/drift/releases/download/drift-${drift_version}/drift_worker.js"

mkdir -p "$(dirname "$wasm_out")" "$(dirname "$worker_out")"

curl -fL --max-time 300 -o "$wasm_out" "$wasm_url"
# WebAssembly magic "\0asm".
[ "$(dd if="$wasm_out" bs=1 skip=1 count=3 2>/dev/null)" = "asm" ] || {
  echo "ERROR: $wasm_out is not a wasm module" >&2
  exit 1
}
echo "sqlite3.wasm OK: $(stat -c%s "$wasm_out") bytes"

curl -fL --max-time 300 -o "$worker_out" "$worker_url"
[ "$(stat -c%s "$worker_out")" -gt 10240 ] || {
  echo "ERROR: $worker_out is implausibly small" >&2
  exit 1
}
echo "drift_worker.js OK: $(stat -c%s "$worker_out") bytes"

# Refresh the immutability ledger (refuses to change an existing path's digest).
# shellcheck source=tool/web_vendor_ledger.sh
. tool/web_vendor_ledger.sh
web_vendor_ledger_update
