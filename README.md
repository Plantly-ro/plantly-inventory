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

Releases are built and published by GitLab CI (`.gitlab-ci.yml`); every Play job is a
manual click in the pipeline view (▶ on the job).

| Branch | Job | What ships |
|---|---|---|
| `development`, `main` | `publish-internal` (manual) | signed AAB → Play **internal** track (Inventory Cloud + Play Billing ON, like every Play build since 1.1.0), `versionName 1.1.0-internal.<pipeline iid>`, release notes from `android/fastlane/metadata/internal/<locale>/changelogs/`, 100 % of the testers list. See *Internal testing* below |
| `development` | `publish-listing` (manual) | store listing texts + graphics only, no build |
| `main` | `publish-production` (manual) | listing push (validated first, fails fast) → build (Inventory Cloud + Play Billing ON) → AAB → **production** as a **staged rollout to 20 %** (`PLAY_ROLLOUT: "0.2"`; set it to an empty string in the Run-job form for an immediate 100 %). Widen or finish the rollout later — see *Staged rollout* below |

- `versionCode` = the CI pipeline id (`--build-number=$CI_PIPELINE_ID`) for **both** tracks — one instance-wide monotonic counter, so an internal build can never outrank a later production build (production 1.0.0 = 2882; the job refuses to build if the id is not above `PLAY_VERSION_CODE_MIN`). `versionName` = `version:` in `pubspec.yaml`, unless the job sets `PLAY_BUILD_NAME` (`publish-internal` does).
- Compile-time flags: `INVENTORY_ANDROID_DART_DEFINES` (space-separated `--dart-define=K=V`, see *Marketplace integration flags*). **Cloud is on in all Play builds since 1.1.0:** both `publish-internal` and `publish-production` set it to `--dart-define=PLANTLY_CLOUD_ENABLED=true --dart-define=PLANTLY_PLAY_BILLING_ENABLED=true` in their own `variables:` (the app itself stays free; Inventory Cloud is the paid add-on bought in-app via Play Billing, included in Plantly Pro). Override per run in the Run-job form (an empty string = feature defaults: cloud OFF, billing OFF, sell OFF).
- Release notes: `changelogs/default.txt` applies to every build; add `changelogs/<versionCode>.txt` to override for one build (≤500 chars). The internal track reads `android/fastlane/metadata/internal/` instead of the store-listing tree; `lint-tools` validates both.
- Scripts: `tool/play_listing.py` (listing; `--dry-run` validates without credentials) and `tool/play_upload.py` (AAB + deobfuscation files + track; `--rollout-update` edits a staged rollout). Tests: `python3 -m unittest discover -s tool/tests` (stdlib only; `lint-tools` runs them on every push).
- Store listing push from CI (`publish-listing`, or the first step of `publish-production`) is sometimes auto-cancelled by the next pipeline on the branch; the same push works from a workstation with the SA key: `python3 tool/play_listing.py --package ro.plantly.inventory --credentials ~/.secrets/plantly-play-publisher-inventory.json --metadata-dir android/fastlane/metadata/android` (`--dry-run` first).

### Staged rollout (production)

`publish-production` ships with `status: inProgress`, `userFraction 0.2`. Play serves the new versionCode to 20 % of users; everyone else keeps the previous release until the rollout is widened. Without a rebuild:

```bash
SA=~/.secrets/plantly-play-publisher-inventory.json
python3 tool/play_upload.py --package ro.plantly.inventory --credentials "$SA" --track production --rollout-update 0.5       # widen to 50 %
python3 tool/play_upload.py --package ro.plantly.inventory --credentials "$SA" --track production --rollout-update complete  # 100 %
```

The script opens an edit, takes the track's single `inProgress` release (or `--version-code <id>` when there are several), rewrites `userFraction` / `status` and commits; lowering a fraction is refused (halt from Play Console instead). Equivalent by hand: Play Console → *Production → Releases → Manage rollout → Update rollout / Complete rollout*. The pip deps are the same as CI's (`google-api-python-client google-auth google-auth-httplib2`).
- Deobfuscation: release builds are R8-minified, so `play_upload.py` attaches the R8 mapping (`build/app/outputs/mapping/release/mapping.txt`, `deobfuscationFileType=proguard`) to the uploaded versionCode in the same edit — CI passes `--mapping` explicitly so a missing mapping fails the job; the mapping is also kept as a job artifact next to the AAB. Native debug symbols (`--native-symbols`, `nativeCode`) are auto-detected: AGP's `native-debug-symbols.zip` if the release buildType ever sets `ndk { debugSymbolLevel }`, else a zip of `build/app/intermediates/merged_native_libs/release/out/lib/<abi>/*.so` (silences Play's "no debug symbols" warning; Flutter's `.so`s are already stripped, so it does not add real native symbolication). `--mapping none` / `--native-symbols none` skip either.
- Store metadata layout, console-only items and CI variables: [`android/fastlane/README.md`](android/fastlane/README.md), [`docs/play-console-checklist.md`](docs/play-console-checklist.md).
- Privacy policy (en/ro): [`docs/privacy-policy.en.md`](docs/privacy-policy.en.md), [`docs/privacy-policy.ro.md`](docs/privacy-policy.ro.md) — to be hosted at `https://plantly.ro/app/inventory/privacy`.

### Internal testing (Inventory Cloud + in-app subscription)

The internal track builds with the same flags as production (`PLANTLY_CLOUD_ENABLED` +
`PLANTLY_PLAY_BILLING_ENABLED` on, since 1.1.0) and is where a release is exercised with
licence-tester (free) purchases before `publish-production` is clicked.

**Run it**

1. GitLab → *Build → Pipelines* → the latest green pipeline on `development` (or `main`) → stage *publish* → ▶ `publish-internal`.
   CLI: `glab ci run -b development` then `glab ci view` and play the job, or
   `curl -X POST -H "PRIVATE-TOKEN: $GITLAB_TOKEN" https://gitlab.urundead.win/api/v4/projects/13/jobs/<job id>/play`
   (job id from `GET /projects/13/pipelines/<pipeline id>/jobs?scope[]=manual`).
2. Optional per-run overrides in the *Run job* form (highest precedence):
   `INVENTORY_ANDROID_DART_DEFINES` (e.g. add `--dart-define=PLANTLY_HOST=https://development.agent-khepri.urundead.win` to point at the preview backend, or an empty string for the production defaults), `PLAY_BUILD_NAME`, `PLAY_UPLOAD_EXTRA_ARGS`.
3. ~10 min later the job log ends with `committed: ro.plantly.inventory versionCode <id> -> internal (completed)`; the AAB + R8 mapping are job artifacts for a week. `resource_group: play-upload` queues a second click behind a running one.
4. Play Console → *Testing → Internal testing* shows the release within a few minutes (no review for internal releases).

**Who can install** — only accounts on the internal testers list: Play Console → *Testing → Internal testing → Testers* → email list **"Testers"** (max 100). Add the Google account that is signed in on the test phone. The same accounts should also be on *Monetise → Monetisation setup → Licence testing* (**Testers** list, response *RESPOND_NORMALLY*) so that purchases are test purchases.

**Opt-in link** — Play Console → *Testing → Internal testing → Testers* tab → *How testers join your test* → *Copy link*; it has the shape `https://play.google.com/apps/internaltest/<id>`. Each tester opens it once with their listed Google account, taps *Become a tester*, then installs/updates **Plantly Inventory** from the Play Store (the version string shows `1.1.0-internal.<iid>`; a sideloaded build of the same package must be uninstalled first). Allow a few minutes after the tester is added or the release is committed.

**Test-purchase flow** (licence testers are never charged; Play test subscriptions renew on a compressed clock — monthly ≈ 5 min, yearly ≈ 30 min — and auto-cancel after a few renewals)

1. In the app: *Me → Plantly account* → sign in with the plantly.ro account; *Me → Cloud* shows the Play plan picker (product `inventory_cloud`, base plans `monthly` / `yearly`) instead of the "available on plantly.ro" copy.
2. Pick a plan → the Play purchase sheet says **"Test card, always approves"** (if it shows a real card, the Google account is not a licence tester or the opt-in step was skipped). Confirm.
3. The app sends the purchase token to the marketplace, which verifies it with Play and grants the `inventory_cloud` entitlement. Verify in the app under `/me/cloud` (status *active*, provider **play**) and on plantly.ro → `/account/subscription` (same subscription listed with provider **play**; Stripe-sourced ones say *stripe*).
4. Sync: link or create a collection, change a plant, confirm it appears on `https://inventory.plantly.ro` (web is always cloud-on) for the same account.
5. Cancel from the app's *Manage subscription* link (Play → *Payments & subscriptions*) or wait for the test auto-cancel; the entitlement should lapse on the next re-check and the app falls back to local-only without touching local data.

Pre-requisites outside this repo: the `inventory_cloud` subscription and both base plans **active** in Play Console (they are), the marketplace's Play RTDN / purchase-verification configured for `ro.plantly.inventory`, and the test account present in both testers lists above.

## Release (Web / inventory.plantly.ro)

The Flutter **web** build is deployed as static files to the plantly-prod host and
served by its Caddy at `https://inventory.plantly.ro` (TLS via Cloudflare). The host
side (Caddy site block, read-only volume, release-dir layout, first-time steps) lives
in the quadlets repo, `plantly-prod/README.md` § *Inventory web*.

| Branch | Job | What ships |
|---|---|---|
| every branch | `build-web` | `flutter build web --release --no-web-resources-cdn --dart-define=PLANTLY_APP_VERSION=<pubspec version> $INVENTORY_WEB_DART_DEFINES` → artifact `build/web/` |
| `main` | `deploy-web-prod` (automatic, after `build-web`) | `ci/prod/deploy-web.sh`: tar `build/web` over ssh → extract into `/var/lib/plantly/inventory-web/releases/<id>/` (id = short sha + hex pipeline id) → write `.deployed-commit` → flip the `current` symlink atomically → verify (on-host via Caddy with the Host header + public URL) → auto-rollback of the symlink on verify failure → keep the last 3 releases → append to the quadlets `DEPLOYED.md` ledger |

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

- **Database** — Drift on `web/vendor/sqlite3-<ver>/sqlite3.wasm` + `web/vendor/drift-<ver>/drift_worker.js` (pinned to the `sqlite3` / `drift` versions in `pubspec.lock`; re-fetch with `tool/fetch_web_sqlite.sh` after bumping either — new version = new path, see `lib/data/database/web_db_assets.dart`). Storage is OPFS when the page is served with `Cross-Origin-Opener-Policy: same-origin` + `Cross-Origin-Embedder-Policy: require-corp`, IndexedDB otherwise. The two backends are separate stores; drift sticks with whichever one already holds the database, so *adding* the headers later is safe, but *removing* them hides the OPFS data — never remove the headers once shipped.
- **Caching / releases** — Flutter's web file names are not content-hashed, so CI runs `tool/web_version_assets.py build/web <id>` after the build (id = short sha + hex pipeline id, unique per build): everything except `index.html`, `version.json`, `manifest.json`, icons, the service-worker stub and `vendor/` moves under `v/<id>/` (`web/prototype/` is dropped), and `web/flutter_bootstrap.js` (custom loader template) loads `main.dart.js`, `assets/` and `canvaskit/` relative to its own URL. Only `index.html` stays mutable (served `no-cache`); `/v/*` and `/vendor/*` are immutable (`tool/web_vendor.sha256` + the fetch scripts refuse to change a recorded vendor path's bytes). A local `flutter build web` without that step still works unversioned.
- **No third-party font requests** — the web engine's default Roboto is bundled (`assets/fonts/Roboto-Regular.ttf`, otherwise it is fetched from fonts.gstatic.com at startup), and glyph-fallback fonts (emoji, symbols, extra Latin/Greek/Cyrillic) are self-hosted under `web/vendor/fallback-fonts/` (`tool/fetch_web_fallback_fonts.sh`); scripts not mirrored (CJK, …) render as tofu instead of calling Google.
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
