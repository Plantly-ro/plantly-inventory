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

## Release signing (Android)

Release APKs are signed with a keystore referenced via `android/key.properties`. That file is **not committed** — copy `android/key.properties.example` and fill in your own values, then run:

```bash
flutter build apk --split-per-abi --release
```

Without `key.properties`, the release build falls back to the Flutter debug keystore so `flutter run --release` still works on contributor machines. Details: https://docs.flutter.dev/deployment/android#signing-the-app

## Licence

- **Core app + prototype:** AGPL-3.0-or-later (see [`LICENSE`](./LICENSE)).
- **Plugin SDK + generated Dart API client (Phase 2):** MIT.
- **Species seed data (Phase 1 asset):** CC-BY-SA-4.0.

## Related

- Marketplace: https://github.com/URunDEAD/Pltio (`plantly.ro`)
- This companion app: https://github.com/URunDEAD/PlantlyInventory
