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

### Marketplace integration flags (all targets)

| dart-define | Default | Effect |
|---|---|---|
| `PLANTLY_HOST` | `https://plantly.ro` | Marketplace API + web origin (`/api/v1`). Point at a preview, e.g. `https://development.agent-khepri.urundead.win`. |
| `PLANTLY_SELL_ENABLED` | `false` | **"Sell on plantly.ro"** (`plantly_ro` export plugin, marketplace category search, Me → Plantly account). Off = the local draft dialog only, no network from the export path. The Assistant/marketplace **import** link handling (`/#/import?d=…`, `plantlyinventory://import`) is always on. |

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
