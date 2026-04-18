# PlantlyInventory

> Offline-first, open-source companion plant care tracker. Logs watering / fertilising / repotting / pruning / photos for the plants you actually own, reminds you when each one needs attention, and — when you decide to sell one — exports it in one click as a listing on [plantly.ro](https://plantly.ro) (or any other marketplace via the plugin system).

**Status:** repository bootstrap. The design prototype is runnable and tested; the Flutter application (Phase 1 in [`PLAN.md`](./PLAN.md)) has not been scaffolded yet.

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
| **0** | Visual prototype (this repo) | ✅ landed |
| **1** | Offline Flutter MVP — Drift + care tracking + notifications | scaffolding next |
| **2** | Go sync server + plantly.ro export plugin | planned |
| **3** | Weather + history + reports | planned |
| **4** | Household sharing + E2E encryption | planned |
| **5** | Hosted SaaS + Stripe billing | planned |

See [`PLAN.md`](./PLAN.md) for the complete data model, DDL, sync protocol, threat model, package list, and per-phase verification plan.

## Licence

- **Core app + prototype:** AGPL-3.0-or-later (see [`LICENSE`](./LICENSE)).
- **Plugin SDK + generated Dart API client (Phase 2):** MIT.
- **Species seed data (Phase 1 asset):** CC-BY-SA-4.0.

## Related

- Marketplace: https://github.com/URunDEAD/Pltio (`plantly.ro`)
- This companion app: https://github.com/URunDEAD/PlantlyInventory
