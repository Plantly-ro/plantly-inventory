#!/usr/bin/env bash
# Fetches the web sqlite3/drift binaries into web/. Reproducible source for
# the two files committed in this repo; re-run after bumping the sqlite3 or
# drift versions in pubspec.lock (the release tags below must match).
#
# Pinned (pubspec.lock, 2026-09-18):
#   sqlite3 2.9.4  -> sqlite3.wasm    sha256 922a76b182b6af69b030c8e2fdd3283ecc8e827248b20e4b1f3f3db170b52117
#   drift   2.31.0 -> drift_worker.js sha256 f0a9b87085f732fd7b6ee7eb34d3858c556f05d221eb1febfc443649cd365752
set -euo pipefail

cd "$(dirname "$0")/.."

wasm_url="https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-2.9.4/sqlite3.wasm"
worker_url="https://github.com/simolus3/drift/releases/download/drift-2.31.0/drift_worker.js"

curl -fL --max-time 300 -o web/sqlite3.wasm "$wasm_url"
# WebAssembly magic "\0asm".
[ "$(dd if=web/sqlite3.wasm bs=1 skip=1 count=3 2>/dev/null)" = "asm" ] || {
  echo "ERROR: web/sqlite3.wasm is not a wasm module" >&2
  exit 1
}
echo "sqlite3.wasm OK: $(stat -c%s web/sqlite3.wasm) bytes"

curl -fL --max-time 300 -o web/drift_worker.js "$worker_url"
[ "$(stat -c%s web/drift_worker.js)" -gt 10240 ] || {
  echo "ERROR: web/drift_worker.js is implausibly small" >&2
  exit 1
}
echo "drift_worker.js OK: $(stat -c%s web/drift_worker.js) bytes"
sha256sum web/sqlite3.wasm web/drift_worker.js
