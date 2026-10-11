# shellcheck shell=bash
# Sourced by tool/fetch_web_*.sh — maintains tool/web_vendor.sha256, the
# immutability ledger for web/vendor/ (Caddy serves /vendor/* immutable).
#
# Append-only per path: new paths may appear and old ones may disappear (a
# version bump = new dir, old dir deleted), but a path already in the ledger
# must keep its digest. Different bytes need a new path — refetching must
# never silently change what a cached URL means.
#
# Run from the repo root.
web_vendor_ledger_update() {
  local ledger="tool/web_vendor.sha256" new changed
  new=$(find web/vendor -type f -print0 | sort -z | xargs -0 sha256sum)
  if [ -f "$ledger" ]; then
    changed=$(join -j 2 -o 1.1,2.1,0 <(sort -k2 "$ledger") <(printf '%s\n' "$new" | sort -k2) | awk '$1 != $2 {print $3}')
    if [ -n "$changed" ]; then
      echo "ERROR: these web/vendor paths are in $ledger with a different digest:" >&2
      printf '%s\n' "$changed" | sed 's/^/  /' >&2
      echo "Changed bytes need a NEW path (version/hash in the dir name); restore the old files with" >&2
      echo "  git checkout -- web/vendor" >&2
      echo "and move the new ones to a new path. Ledger left untouched." >&2
      return 1
    fi
  fi
  printf '%s\n' "$new" > "$ledger"
  echo "$ledger updated ($(wc -l < "$ledger") files)"
}
