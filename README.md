# PlantlyInventory

> Offline-first, open-source companion plant care tracker. Logs watering / fertilising / repotting / pruning / photos for the plants you actually own, reminds you when each one needs attention, and — when you decide to sell one — exports it in one click as a listing on [plantly.ro](https://plantly.ro) (or any other marketplace via the plugin system).

**Status:** Phase 1 feature-complete — the Flutter app ships in English + Romanian with plant tracking, reminders, care types, calendar, photo gallery, and encrypted backup. Prototype in `web/prototype/` remains the visual reference.

## Quickstart — run the design prototype

```bash
npm install
npm start        # http://localhost:4173/
```

The prototype is the approved visual reference for the Phase 1 Flutter port. It shows:

- a **customizable widget-based home** (reorder / add / remove widgets; four presets: Grouped, Dashboard, Feed, Minimal)
- **Plant detail** with upcoming care (Done / Snooze) and full timeline
- **Week calendar** with a weather-driven "skip Saturday watering" suggestion
- the **plantly.ro export dialog** (title / description / price / category / location / ≤6 photos)
- **light + dark** themes

See [`CLAUDE.md`](./CLAUDE.md) for the repo map, the prototype → Flutter widget mapping, and the "what to do in the next session" checklist.

## Tests

```bash
npm install                                        # if you skipped the quickstart
npx playwright install --with-deps chromium      # one-off
npm test                                           # headless
npm run test:ui                                    # interactive
```

The suite covers:

- **Functional e2e** (`tests/e2e/prototype.spec.ts`): widget customization + localStorage persistence, plant-detail navigation, export dialog flow (Save draft / Post now), calendar rain suggestion, theme toggle.
- **Visual regression** (`tests/e2e/visual.spec.ts`): pixel diff against committed baselines for home / plant detail / calendar / export dialog.

## Phases (from `PLAN.md`)

| Phase | Scope | Status |
|---|---|---|
| **0** | Visual prototype (this repo) | landed |
| **1** | Offline Flutter MVP — Drift + care tracking + notifications | feature-complete |
| **2** | Go sync server + plantly.ro export plugin | planned |
| **3** | Weather + history + reports | planned |
| **4** | Household sharing + E2E encryption | planned |
| **5** | Hosted SaaS + Stripe billing | planned |

See [`PLAN.md`](./PLAN.md) for the complete data model, DDL, sync protocol, threat model, package list, and per-phase verification plan.

## Privacy

PlantlyInventory is offline-first by design. Plant data, photos, care events, and schedules live entirely on your device in a local SQLite database. Nothing is sent to a server unless you explicitly ask for it:

- **Backups** (JSON or ZIP) only leave the device via the share sheet when you tap Export.
- **Notifications** fire locally via the OS alarm system. We do not use a push server.
- **Crash reports** and **anonymous usage analytics** are off by default. The first-run onboarding and the Me → Privacy & data screen let you opt in. Even then, releases from this repository ship with no Sentry DSN configured — so without a forked build that supplies one, no events ever leave the device.
- **plantly.ro export** sends only the fields you review in the Export dialog, never the full database.

See `lib/features/me/privacy_screen.dart` for the user-facing statement and `lib/services/telemetry.dart` for the consent gating.

## Release (Android / Google Play)

Releases are built and published by GitLab CI (`.gitlab-ci.yml`); the only manual step is
the click on `publish-production`.

| Branch | Job | What ships |
|---|---|---|
| `development` | `publish-internal` (automatic) | signed AAB → Play **internal** track, release notes from `android/fastlane/metadata/android/<locale>/changelogs/` |
| `development` | `publish-listing` (manual) | store listing texts + graphics only, no build |
| `main` | `publish-production` (manual) | listing push (validated first, fails fast) → build → AAB → **production**, 100 % rollout; set `PLAY_UPLOAD_EXTRA_ARGS="--user-fraction 0.2"` in the Run-job form for a staged rollout. While the app is still unpublished Play only accepts draft releases — the script falls back to `status: draft` automatically; send it for review in Play Console |

- `versionCode` = the CI pipeline id (`--build-number=$CI_PIPELINE_ID`); `versionName` = `version:` in `pubspec.yaml`.
- Release notes: `changelogs/default.txt` applies to every build; add `changelogs/<versionCode>.txt` to override for one build (≤500 chars).
- Scripts: `tool/play_listing.py` (listing; `--dry-run` validates without credentials) and `tool/play_upload.py` (AAB + deobfuscation files + track). Tests: `python3 -m unittest discover -s tool/tests` (stdlib only; `lint-tools` runs them on every push).
- Deobfuscation: release builds are R8-minified, so `play_upload.py` attaches the R8 mapping (`build/app/outputs/mapping/release/mapping.txt`, `deobfuscationFileType=proguard`) to the uploaded versionCode in the same edit — CI passes `--mapping` explicitly so a missing mapping fails the job; the mapping is also kept as a job artifact next to the AAB. Native debug symbols (`--native-symbols`, `nativeCode`) are auto-detected: AGP's `native-debug-symbols.zip` if the release buildType ever sets `ndk { debugSymbolLevel }`, else a zip of `build/app/intermediates/merged_native_libs/release/out/lib/<abi>/*.so` (silences Play's "no debug symbols" warning; Flutter's `.so`s are already stripped, so it does not add real native symbolication). `--mapping none` / `--native-symbols none` skip either.
- Store metadata layout, console-only items and CI variables: [`android/fastlane/README.md`](android/fastlane/README.md), [`docs/play-console-checklist.md`](docs/play-console-checklist.md).
- Privacy policy (en/ro): [`docs/privacy-policy.en.md`](docs/privacy-policy.en.md), [`docs/privacy-policy.ro.md`](docs/privacy-policy.ro.md) — to be hosted at `https://plantly.ro/app/inventory/privacy`.

## Release (Web / inventory.plantly.ro)

The Flutter **web** build is deployed as static files to the plantly-prod host and
served by its Caddy at `https://inventory.plantly.ro` (TLS via Cloudflare). The host
side (Caddy site block, read-only volume, release-dir layout, first-time steps) lives
in the quadlets repo, `plantly-prod/README.md` § *Inventory web*.

| Branch | Job | What ships |
|---|---|---|
| every branch | `build-web` | `flutter build web --release --no-web-resources-cdn --dart-define=PLANTLY_APP_VERSION=<pubspec version> $INVENTORY_WEB_DART_DEFINES` → artifact `build/web/` |
| `main` | `deploy-web-prod` (automatic, after `build-web`) | `ci/prod/deploy-web.sh`: tar `build/web` over ssh → extract into `/var/lib/plantly/inventory-web/releases/<short-sha>/` → write `.deployed-commit` → flip the `current` symlink atomically → verify (on-host via Caddy with the Host header + public URL) → auto-rollback of the symlink on verify failure → keep the last 3 releases → append to the quadlets `DEPLOYED.md` ledger |

- `INVENTORY_WEB_DART_DEFINES` (optional, unprotected project CI variable): extra
  space-separated `--dart-define=K=V` flags for `build-web`, e.g.
  `--dart-define=PLANTLY_CLOUD_ENABLED=true` when Inventory Cloud goes live on web.
  Unset = compile-time defaults (cloud OFF, sell OFF).
- Verify: `/version.json`, `/`, `/flutter_bootstrap.js` and the SPA fallback must be
  200 through Caddy on the host; the public URL (`INVENTORY_WEB_VERIFY_URL`, default
  `https://inventory.plantly.ro`, `skip` to disable) must be 200 too — a DNS/connect
  failure only warns (hostname not live yet), any other status rolls back.
- Rollback by hand: `sudo ln -sfn releases/<sha> /var/lib/plantly/inventory-web/current.tmp && sudo mv -T /var/lib/plantly/inventory-web/current.tmp /var/lib/plantly/inventory-web/current`
  (relative target on purpose — the dir is bind-mounted into the caddy container).
- Prod is a curated release line: ship via a `Promote:` MR `development` → `main`.
- The web app calls plantly.ro's API cross-origin, so `https://inventory.plantly.ro`
  must be in the monolith's `ALLOWED_ORIGINS`.

Required **protected** CI variables on this project (same values as `plantly.ro/web/frontend`;
`main` is a protected branch so they are only exposed there):

| Variable | Type | Purpose |
|---|---|---|
| `PROD_DEPLOY_SSH_KEY` | file | private key for `$PROD_SSH_USER@$PROD_SSH_HOST` (needs passwordless sudo for `tar`/`ln`/`mv`/`rm` under `/var/lib/plantly/inventory-web`) |
| `PROD_SSH_HOST` | var | plantly-prod LAN address (the runner is LAN-homed; the host is not reachable from the mesh) |
| `PROD_SSH_USER` | var | deploy user on the host |
| `DEPLOY_LEDGER_TOKEN` | var | GitLab PAT (scope `api`, Maintainer on quadlets project 34) used by `ci/prod/ledger_append.py`; missing/broken → deploy stays live but the job exits 3 |

Without `PROD_SSH_HOST`/`PROD_SSH_USER` the `deploy-web-prod` job is not created at all
(rules gate), so pipelines on forks or before first-time setup are unaffected.

### Local release signing

Release builds are signed with a keystore referenced via `android/key.properties`. That file is **not committed** — copy `android/key.properties.example` and fill in your own values, then run:

```bash
flutter build appbundle --release     # or: flutter build apk --split-per-abi --release
```

Without `key.properties`, the release build falls back to the Flutter debug keystore so `flutter run --release` still works on contributor machines. Details: https://docs.flutter.dev/deployment/android#signing-the-app

## Web build

The same app runs in the browser with real persistence:

```bash
flutter build web --release --no-web-resources-cdn   # self-hosts CanvasKit (works under COEP)
python3 -m http.server 8099 --bind 127.0.0.1 --directory build/web
```

- **Database** — Drift on `web/sqlite3.wasm` + `web/drift_worker.js` (pinned to the `sqlite3` / `drift` versions in `pubspec.lock`; re-fetch with `tool/fetch_web_sqlite.sh` after bumping either). Storage is OPFS when the page is served with `Cross-Origin-Opener-Policy: same-origin` + `Cross-Origin-Embedder-Policy: require-corp`, IndexedDB otherwise. The two backends are separate stores; drift sticks with whichever one already holds the database, so *adding* the headers later is safe, but *removing* them hides the OPFS data — never remove the headers once shipped.
- **Photos** — bytes live in IndexedDB (`plantly_inventory_photos`), content-addressed by sha256 like the on-disk store.
- **Backup / iCal / CSV export** — browser download instead of the OS share sheet. Import uses the browser file picker.
- **Not available on web** — scheduled OS notifications (the Me screen and onboarding say so; in-app reminders and the calendar still work) and image re-compression (the picker already downsizes to 1600px).

### Web access gate (subscription-only web)

The browser build is the **Inventory Cloud surface** (`WEB-ACCESS-POLICY`, apps-integration repo):
using it needs a plantly.ro account with an active `inventory_cloud` entitlement (own plan or
included in Plantly Pro). Android stays free and local-first; only web is gated.

- `PlantlyFeatures.cloudEnabled` is **forced on when `kIsWeb`** — the `PLANTLY_CLOUD_ENABLED`
  define is ignored on web (still honoured on Android/iOS/desktop).
- `lib/cloud/web_access.dart` derives `webAccessProvider` (`checking` / `closedSignedOut` /
  `closedNotEntitled` / `closedUnreachable` / `open`) from the existing session + entitlement
  providers; the router (`lib/app/router.dart`, top-level `redirect`) sends every route to
  `/gate` (`lib/features/gate/web_access_gate.dart`) while closed — except `/auth/callback`,
  `/join` and `/import`, whose payloads `HandoffListener` parks — and resumes the parked URL
  once it opens. Off web the provider is always `open`.
- Re-checks: on sign-in, every 15 min, on tab focus / visibility (if the last check is > 1 min
  old) and via the gate's "I already subscribed — check again". A lapse returns to the gate
  **without touching local data**.
- Offline: an entitled check cached ≤ 24 h keeps the app usable with a "no connection" banner;
  older / none → the gate with a retry. 401/403 never open it.
- The subscribe CTA points at `<PLANTLY_HOST>/account/subscription?product=inventory_cloud`
  (same tab); prices come from `GET /api/v1/subscriptions/plans?product=inventory_cloud`
  (fixed EUR copy when that fails). The Android card uses the official Play badges bundled in
  `assets/badges/` (RO + EN, unmodified).
- `web/index.html` carries `<meta name="robots" content="noindex">`: the app is not a landing
  page (that is `plantly.ro/app/inventory`).

### Marketplace integration flags (all targets)

| dart-define | Default | Effect |
|---|---|---|
| `PLANTLY_HOST` | `https://plantly.ro` | Marketplace API + web origin (`/api/v1`). Point at a preview, e.g. `https://development.agent-khepri.urundead.win`. |
| `PLANTLY_SELL_ENABLED` | `false` | **"Sell on plantly.ro"** (`plantly_ro` export plugin, marketplace category search, Me → Plantly account). Off = the local draft dialog only, no network from the export path. The Assistant/marketplace **import** link handling (`/#/import?d=…`, `plantlyinventory://import`) is always on. |
| `PLANTLY_CLOUD_ENABLED` | `false` (**always `true` on web**) | Cloud backup & sync (Me → Cloud, collection link, sync runner). Ignored on web — see *Web access gate*. |
| `PLANTLY_PLAY_BILLING_ENABLED` | `false` | Google Play in-app purchase of Inventory Cloud (Android only; irrelevant on web). |
| `PLANTLY_FACEBOOK_LOGIN_ENABLED` | `false` | Shows **"Continue with Facebook"** on the plantly.ro login sheet. Off while the Meta app is unpublished. Only the entry button is gated: Google + email/password stay, and the OAuth callback/deep link is provider-agnostic, so sessions already obtained via Facebook keep working. |

```bash
# selling ON against the dev preview
flutter build web --release --no-web-resources-cdn \
  --dart-define=PLANTLY_HOST=https://development.agent-khepri.urundead.win \
  --dart-define=PLANTLY_SELL_ENABLED=true
```

## Licence

- **Core app + prototype:** AGPL-3.0-or-later (see [`LICENSE`](./LICENSE)).
- **Plugin SDK + generated Dart API client (Phase 2):** MIT.
- **Species seed data (Phase 1 asset):** CC-BY-SA-4.0.

## Related

- Marketplace: https://github.com/URunDEAD/Pltio (`plantly.ro`)
- This companion app: https://github.com/URunDEAD/PlantlyInventory
