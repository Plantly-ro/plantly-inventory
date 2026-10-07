#!/usr/bin/env bash
# Prod deploy of the Plantly Inventory WEB build → https://inventory.plantly.ro
# Runs in the deploy-web-prod CI job on main (needs the build-web artifact).
#
# Flow: preflight -> ship (tar over ssh) -> extract into releases/<id> ->
#       flip `current` symlink atomically -> verify (read-only) -> prune ->
#       ledger. Verify failure re-points `current` at the previous release.
#
# Host side (quadlets repo, plantly-prod/README.md § Inventory web):
#   /var/lib/plantly/inventory-web/releases/<id>/   extracted build/web (id = short sha + hex pipeline id)
#   /var/lib/plantly/inventory-web/current -> releases/<id>  (RELATIVE:
#       the dir is bind-mounted into the caddy container at /srv/inventory-web,
#       so an absolute target would dangle there)
#   /var/lib/plantly/inventory-web/.deployed-commit
# Caddy serves `current` for Host inventory.plantly.ro (named-host block on :80
# behind the Cloudflare tunnel) and answers /healthz itself.
#
# Same conventions/variables as plantly.ro/web/frontend ci/prod/deploy.sh:
# push-based over ssh from the LAN-homed runner, protected vars
# PROD_DEPLOY_SSH_KEY (file) / PROD_SSH_HOST / PROD_SSH_USER / DEPLOY_LEDGER_TOKEN.
set -euo pipefail

: "${CI_COMMIT_SHORT_SHA:?}" "${CI_COMMIT_SHA:?}" "${CI_PIPELINE_ID:?}"
: "${PROD_SSH_HOST:?}" "${PROD_SSH_USER:?}" "${PROD_DEPLOY_SSH_KEY:?}"

# GitLab writes file-type variables world-readable; ssh refuses such keys
chmod 600 "$PROD_DEPLOY_SSH_KEY"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${INVENTORY_WEB_BUILD_DIR:-build/web}"
ROOT="${INVENTORY_WEB_ROOT:-/var/lib/plantly/inventory-web}"
# Release id = short sha + pipeline id (hex): MUST match the id build-web
# passed to tool/web_version_assets.py. The pipeline part matters because the
# release's /v/<id>/ URLs are served immutable — a new pipeline on the same
# commit (e.g. other INVENTORY_WEB_DART_DEFINES) is a different build and must
# never reuse a URL. Retrying this job inside the same pipeline keeps the id
# (same artifact, same bytes).
REL_ID="${CI_COMMIT_SHORT_SHA}$(printf '%x' "$CI_PIPELINE_ID")"
REL="releases/${REL_ID}"                     # relative to $ROOT, also the symlink target
KEEP="${INVENTORY_WEB_KEEP_RELEASES:-3}"
SITE_HOST="${INVENTORY_WEB_HOST:-inventory.plantly.ro}"
# Public base URL for the through-the-edge check. Empty or "skip" disables it;
# a DNS/connect failure (curl code 000) only warns (hostname not live yet),
# any other non-200 is a real failure.
VERIFY_URL="${INVENTORY_WEB_VERIFY_URL-https://inventory.plantly.ro}"
SSH_OPTS="-i $PROD_DEPLOY_SSH_KEY -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10"
TARGET="$PROD_SSH_USER@$PROD_SSH_HOST"

rssh() { # run a command on the prod host (SC2029: client-side expansion intended)
  # shellcheck disable=SC2086,SC2029
  ssh $SSH_OPTS "$TARGET" "$@"
}
log() { echo "==> $*"; }
code() { curl -s -o /dev/null --max-time 15 -w '%{http_code}' "$@" || true; }
# on-host request to Caddy with the site's Host header (bypasses tunnel + DNS)
hcode() { rssh "curl -s -o /dev/null --max-time 10 -w '%{http_code}' -H 'Host: $SITE_HOST' 'http://127.0.0.1$1'" || true; }
hbody() { rssh "curl -s --max-time 10 -H 'Host: $SITE_HOST' 'http://127.0.0.1$1'" || true; }

# ---------- 1. preflight ----------
log "preflight: build artifact"
# build-web versions the output (tool/web_version_assets.py): release files
# live under v/<REL_ID>/, which must match $REL so Caddy's
# /v/<id>/ -> releases/<id>/ fallback (old tabs) finds them.
VPATH="v/${REL_ID}"
for f in index.html version.json "$VPATH/flutter_bootstrap.js" "$VPATH/main.dart.js"; do
  [ -s "$BUILD_DIR/$f" ] || { echo "preflight: $BUILD_DIR/$f missing or empty (is the build-web artifact attached and versioned as $REL_ID = short sha + hex pipeline id?)" >&2; exit 1; }
done
grep -q "src=\"$VPATH/flutter_bootstrap.js\"" "$BUILD_DIR/index.html" || {
  echo "preflight: $BUILD_DIR/index.html does not load $VPATH/flutter_bootstrap.js" >&2; exit 1; }
# Version-pinned drift worker + sqlite3 wasm (web/vendor/<pkg>-<ver>/), shared
# by all releases; verified below through Caddy like the release files.
VENDOR_FILES=$(cd "$BUILD_DIR" && find vendor -type f \( -name 'drift_worker.js' -o -name 'sqlite3.wasm' \) | sort)
[ "$(printf '%s\n' "$VENDOR_FILES" | grep -c .)" -eq 2 ] || {
  echo "preflight: expected exactly one vendor/*/drift_worker.js and one vendor/*/sqlite3.wasm in $BUILD_DIR, got: ${VENDOR_FILES:-none}" >&2; exit 1; }
echo "build version.json: $(tr -d '\n' < "$BUILD_DIR/version.json")"

log "preflight: host layout + rollback point"
rssh "test -d '$ROOT/releases'" || {
  echo "preflight: $ROOT/releases missing on $PROD_SSH_HOST — do the quadlets first-time step (install -d + deploy.sh + caddy restart)" >&2; exit 1; }
PREV_REL=$(rssh "readlink '$ROOT/current' 2>/dev/null" || true)     # e.g. releases/abcd1234 or empty
PREV_RECORD=$(rssh "cat '$ROOT/.deployed-commit' 2>/dev/null" || true)
if [ -n "$PREV_REL" ]; then
  log "current release: $PREV_REL (${PREV_RECORD:-no .deployed-commit})"
else
  log "no current release yet (first deploy) — nothing to roll back to"
fi
if [ "$PREV_REL" = "$REL" ]; then
  log "note: $REL is already live (retry of this pipeline's job); it will be re-extracted and re-flipped"
fi

# ---------- 2. ship + extract ----------
log "ship: $BUILD_DIR -> $TARGET:$ROOT/$REL"
TARBALL="${CI_PROJECT_DIR:-$PWD}/inventory-web-${REL_ID}.tgz"
tar -C "$BUILD_DIR" -czf "$TARBALL" .
ls -l "$TARBALL"
# Extract into a scratch dir first and move it into place, so a half-extracted
# tree is never visible under releases/<id> (matters for job retries).
rssh "set -e
sudo rm -rf '$ROOT/$REL.tmp'
sudo install -d -m 755 '$ROOT/$REL.tmp'
sudo tar -xzf - -C '$ROOT/$REL.tmp'
sudo chmod -R a+rX '$ROOT/$REL.tmp'
if [ -e '$ROOT/$REL' ]; then sudo mv -T '$ROOT/$REL' '$ROOT/$REL.old'; fi
sudo mv -T '$ROOT/$REL.tmp' '$ROOT/$REL'
sudo rm -rf '$ROOT/$REL.old'
sudo touch '$ROOT/$REL'
test -s '$ROOT/$REL/index.html'" < "$TARBALL"
rm -f "$TARBALL"

# ---------- 3. flip ----------
STAMP=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
RECORD="$CI_COMMIT_SHA $REL_ID $STAMP pipeline=${CI_PIPELINE_ID:-?}"
log "flip: current -> $REL"
rssh "set -e
sudo ln -sfn '$REL' '$ROOT/current.tmp'
sudo mv -T '$ROOT/current.tmp' '$ROOT/current'
printf '%s\n' '$RECORD' | sudo tee '$ROOT/.deployed-commit' >/dev/null
readlink '$ROOT/current'"

# ---------- 4. verify (read-only) ----------
verify() {
  local ok=true c body

  # 4a. on the host through Caddy with the Host header (independent of DNS/tunnel)
  c=$(hcode /version.json)
  if [ "$c" = "200" ]; then echo "ok   direct /version.json -> 200"; else echo "FAIL direct /version.json -> $c"; ok=false; fi
  body=$(hbody /)
  if printf '%s' "$body" | grep -q 'flutter_bootstrap.js'; then
    echo "ok   direct / serves the Flutter shell"
  else
    echo "FAIL direct / does not look like the Flutter index (${body:0:80})"; ok=false
  fi
  # shellcheck disable=SC2086  # VENDOR_FILES: newline list of space-free paths
  for p in "/$VPATH/flutter_bootstrap.js" "/$VPATH/main.dart.js" $(printf '/%s ' $VENDOR_FILES); do
    c=$(hcode "$p")
    if [ "$c" = "200" ]; then echo "ok   direct $p -> 200"; else echo "FAIL direct $p -> $c"; ok=false; fi
  done
  # SPA fallback: unknown path must serve index, not 404
  c=$(hcode /__deploy_probe__)
  if [ "$c" = "200" ]; then echo "ok   direct SPA fallback -> 200"; else echo "FAIL direct SPA fallback -> $c"; ok=false; fi

  # 4b. through Cloudflare (the real user path)
  if [ -z "$VERIFY_URL" ] || [ "$VERIFY_URL" = "skip" ]; then
    echo "skip public verify (INVENTORY_WEB_VERIFY_URL=${VERIFY_URL:-empty})"
  else
    local base="${VERIFY_URL%/}"
    # shellcheck disable=SC2086
    for p in /version.json / "/$VPATH/flutter_bootstrap.js" $(printf '/%s ' $VENDOR_FILES); do
      c=$(code "$base$p")
      case "$c" in
        200) echo "ok   public $base$p -> 200" ;;
        000) echo "WARN public $base$p unreachable (DNS/tunnel not live yet?) — not failing the deploy" ;;
        *)   echo "FAIL public $base$p -> $c"; ok=false ;;
      esac
    done
  fi
  [ "$ok" = "true" ]
}

log "verify: read-only gate"
if [ "$(hbody /healthz)" != "ok" ]; then
  cat >&2 <<BANNER
!!! Caddy does not answer Host: $SITE_HOST /healthz on the prod host yet.
!!! Files are in place and \`current\` points at $REL, but the site block from
!!! the quadlets repo (plantly-prod/Caddyfile + caddy.container Volume=) is not
!!! live: run quadlets deploy.sh + \`systemctl restart caddy\` once, then re-run
!!! this job to verify. Nothing was rolled back (nothing serves these files).
BANNER
  exit 1
fi

verify_ok=true
if ! verify; then
  echo "verify failed once — retrying in 10s"
  sleep 10
  verify || verify_ok=false
fi

if [ "$verify_ok" != "true" ]; then
  if [ -n "$PREV_REL" ] && [ "$PREV_REL" != "$REL" ]; then
    echo "!!! verify FAILED — rolling back current -> $PREV_REL" >&2
    rssh "set -e
sudo ln -sfn '$PREV_REL' '$ROOT/current.tmp'
sudo mv -T '$ROOT/current.tmp' '$ROOT/current'
printf '%s\n' '$PREV_RECORD' | sudo tee '$ROOT/.deployed-commit' >/dev/null"
    echo "--- post-rollback verify ---"
    verify || true
    echo "!!! DEPLOY FAILED, current rolled back to $PREV_REL. Release dir $ROOT/$REL left for inspection." >&2
  else
    echo "!!! verify FAILED and there is no previous release to roll back to — removing \`current\` so the site is plainly 'not deployed' rather than half-broken." >&2
    rssh "sudo rm -f '$ROOT/current' '$ROOT/.deployed-commit'"
    echo "!!! DEPLOY FAILED. Release dir $ROOT/$REL left for inspection." >&2
  fi
  exit 1
fi

# ---------- 5. prune ----------
# Keep the newest $KEEP release dirs by mtime (the ship step touches each
# release dir at deploy time — tar -x restores the archive's dir mtime, which
# would make every release look equally old); never remove the live one or the
# rollback point. Non-fatal: a prune hiccup must not fail a verified deploy.
log "prune: keeping the last $KEEP releases (+ current + rollback point)"
rssh "cd '$ROOT/releases' && ls -1t | tail -n +$((KEEP + 1)) | while read -r d; do
  case \"releases/\$d\" in '$REL'|'$PREV_REL') continue ;; esac
  echo \"prune: removing releases/\$d\"; sudo rm -rf -- \"\$d\"
done; ls -1t" || echo "prune failed (non-fatal)" >&2

# ---------- 6. ledger ----------
# Same contract as monolith/frontend: runs after flip+verify+prune, cannot roll
# back the live deploy, but its failure fails the job so it cannot rot silently.
log "ledger: appending deploy record to quadlets DEPLOYED.md"
LEDGER_OK=true
if [ -n "${DEPLOY_LEDGER_TOKEN:-}" ]; then
  python3 "$HERE/ledger_append.py" \
    "inventory-web → CI deploy ${REL_ID} (pipeline ${CI_PIPELINE_ID:-?}, ${CI_COMMIT_TITLE:-}); rollback point ${PREV_REL:-none}" \
    || { echo "ledger append FAILED" >&2; LEDGER_OK=false; }
else
  echo "ledger: DEPLOY_LEDGER_TOKEN unset" >&2
  LEDGER_OK=false
fi

log "deploy complete: $REL live at https://$SITE_HOST (was ${PREV_REL:-none})"

if [ "$LEDGER_OK" != "true" ]; then
  cat >&2 <<'BANNER'
!!! DEPLOY SUCCEEDED AND IS LIVE — do NOT roll back.
!!! Only the DEPLOYED.md ledger append failed (DEPLOY_LEDGER_TOKEN broken or
!!! unset). Failing the job so this cannot rot silently: re-mint the token
!!! (quadlets project 34, api scope, Maintainer), set the CI variable on
!!! plantly-inventory/app, and backfill the ledger line printed above.
BANNER
  exit 3
fi
