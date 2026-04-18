# CLAUDE.md — PlantlyInventory

Durable brief for Claude sessions. Read this first. If `PLAN.md` disagrees with this file, `PLAN.md` is the architectural source of truth — update this file to match.

## One-paragraph summary

PlantlyInventory is an **offline-first, Flutter-based companion plant care tracker** for owners of houseplants. It is not a marketplace — plantly.ro already is — but it **exports** any plant to plantly.ro as a listing when the owner decides to sell. The first tangible deliverable in this repository is a **clickable HTML/React design prototype** (this is what you see when you run `npm start`). The Flutter app is the next phase (see `PLAN.md`, Phase 1). Everything else — sync server, plugins, hosted SaaS — is phased work described in `PLAN.md`.

## Repository map

```
PlantlyInventory/
├── PLAN.md                         # architectural plan — single source of truth
├── CLAUDE.md                       # this file
├── README.md                       # user-facing quickstart
├── LICENSE                         # AGPL-3.0-or-later
│
├── pubspec.yaml                    # Flutter app — Phase 1
├── analysis_options.yaml           # flutter_lints ruleset
├── lib/
│   ├── main.dart                   # ProviderScope → PlantlyApp → HomeScreen
│   └── theme/
│       └── tokens.dart             # mechanical port of design-system/colors_and_type.css
├── test/widget_test.dart           # Flutter widget tests (greeting + stats + theme toggle)
├── android/ ios/ web/ linux/ macos/ windows/   # flutter create output
│
├── package.json                    # Node dev deps (http-server, Playwright). No bundler.
├── playwright.config.ts            # Playwright config — starts the prototype dev server
├── .github/workflows/web-ci.yml    # (pending — PAT lacks workflow scope)
├── web/
│   ├── index.html  manifest.json  favicon.png  icons/   # Flutter web entry (Phase 1)
│   └── prototype/                  # the clickable design prototype (React via in-browser Babel)
│       ├── index.html              # entry point (copied verbatim from the Claude Design handoff)
│       ├── components/             # shared.jsx, widgets.jsx, screens.jsx — loaded by index.html
│       ├── design-system/          # colors_and_type.css, logo.svg, leaf-mark.svg
│       ├── _exploration/           # designer's earlier variations — NOT loaded by index.html
│       ├── DESIGN_BUNDLE_README.md # the handoff bundle's own README
│       └── DESIGN_CHAT.md          # the design-session chat transcript (provenance)
└── tests/e2e/                      # Playwright — for the design prototype (not the Flutter app)
    ├── prototype.spec.ts           # functional e2e
    ├── visual.spec.ts              # visual-regression screenshots
    ├── helpers.ts                  # shared waitForProtoReady / waitForFontsReady
    └── visual.spec.ts-snapshots/   # committed baselines
```

Phase 1 data-layer files (`lib/data/`, `lib/sync/`, `lib/features/*/...`, `integration_test/`, `l10n/`) land as the port progresses per PLAN.md §"Critical files".

## Running the Flutter app locally

```bash
export PATH="$HOME/flutter/bin:$PATH"   # if Flutter was installed to $HOME/flutter
flutter pub get
flutter test                             # widget tests (greeting + stats + theme toggle)
flutter analyze                          # static analysis — must be clean
# flutter run -d chrome                  # needs Chrome installed (flutter doctor)
# flutter build apk --debug              # needs Android SDK (flutter doctor)
```

Toolchain notes for this box (as of Phase 1 scaffold):
- `flutter doctor` reports Android SDK / Chrome / Linux desktop toolchain missing. `flutter test` and `flutter analyze` still work (pure Dart VM). APK and web builds need those installed.
- Flutter SDK is at `$HOME/flutter` (cloned `-b stable`, shallow). Upgrade with `flutter upgrade`.

## Running the prototype locally

```bash
npm install
npm start     # http://localhost:4173/
```

Open the URL in any Chromium-based browser. The prototype fetches React / ReactDOM / `@babel/standalone` from unpkg on first load — you need internet. Google Fonts (Inter + Plus Jakarta Sans) are also pulled from `fonts.googleapis.com`; the layout works without them but glyphs fall back to system sans.

## Running tests

```bash
npm install
npx playwright install --with-deps chromium   # one-off per machine
npm test                                       # runs both prototype.spec.ts and visual.spec.ts
npm run test:headed                            # watch it execute
npm run test:ui                                # Playwright's interactive UI
npm run test:update-snapshots                  # regenerate visual baselines
```

CI runs the same thing on Linux Chromium; visual snapshots in `tests/e2e/visual.spec.ts-snapshots/` are generated on Linux so contributors on macOS/Windows should expect anti-aliasing diffs locally. Use `npm run test:update-snapshots` + commit only if the baseline is intentionally changing; otherwise trust CI.

## What is the prototype vs. what is "the product"

- **The prototype** (`web/prototype/`) is **what the user approved**. It is the pixel-level reference for how the Phase 1 Flutter app should look. It was produced by claude.ai/design during an iterative session — the chat transcript is preserved at `web/prototype/DESIGN_CHAT.md`. The design bundle's own instructions for a coding agent are at `web/prototype/DESIGN_BUNDLE_README.md` — those instructions end with *"recreate them pixel-perfectly in whatever technology makes sense for the target codebase."* In our case, that target is **Flutter**.
- **Phase 1 of the product** (per `PLAN.md`) is a Flutter + Drift offline MVP that ports the prototype's screens into native Flutter widgets. Phase 1 has not been scaffolded yet — this repository deliberately does **not** contain a `pubspec.yaml` until Flutter is installed on a dev machine and a human runs `flutter create` against this directory.

## Widget → Flutter mapping (for when Phase 1 starts)

When the port begins, the prototype files map onto the Flutter feature tree like this:

| Prototype file | Flutter destination (see PLAN.md "Critical files") |
|---|---|
| `components/screens.jsx` → `CustomHome` | `lib/features/plants/list.dart` (+ widget system in `lib/features/plants/home_widgets/`) |
| `components/screens.jsx` → `PlantDetail` | `lib/features/plants/detail.dart` |
| `components/screens.jsx` → `CalendarScreen` | `lib/features/calendar/week.dart` |
| `components/screens.jsx` → `ExportDialog` | `lib/plugins/plantly_ro/post_draft_form.dart` |
| `components/widgets.jsx` → `widgetRegistry` entries | individual `Widget` classes under `lib/features/plants/home_widgets/` |
| `components/shared.jsx` → `Icon`, `PhoneFrame`, `plantThumbs` | `lib/theme/icons.dart` + placeholder assets under `assets/plant_thumbs/` |
| `design-system/colors_and_type.css` tokens | `lib/theme/tokens.dart` + `lib/theme/theme.dart` (ColorScheme) |

Every token in the CSS (`--botanical-500: #3D7A5F`, `--terra-500: #C26A3A`, the radius/shadow/motion scales) should land in `lib/theme/tokens.dart` as named constants so the Flutter rewrite doesn't re-invent values.

## Key design decisions locked in the prototype

Do not change these without re-reading the `DESIGN_CHAT.md` transcript:

1. **Widget-based customizable home.** The three exploration variations (Grouped / Dashboard / Feed) are **presets** of a single widget system, not separate screens. Users reorder / add / remove widgets. This was an explicit user decision (`DESIGN_CHAT.md`, "user must be able to build their home page").
2. **Four presets:** Grouped, Dashboard, Feed, Minimal — each maps to a specific `layout` key array. See `components/screens.jsx`, the preset table inside `CustomHome`.
3. **`localStorage` keys:** `plantly_screen`, `plantly_layout`. The Flutter port will replace these with Drift but the *keys* (screen name, layout array) are the app's state surface.
4. **Edit-mode postMessage protocol** (Claude Design's own iframe protocol — preserved so the prototype remains editable in that tool):
   - inbound: `{type:'__activate_edit_mode'}` / `{type:'__deactivate_edit_mode'}` / `{type:'__edit_mode_set_keys', edits:{...}}`
   - outbound: `{type:'__edit_mode_available'}` on mount; `{type:'__edit_mode_set_keys', edits:{theme:'light'|'dark'}}` whenever the user toggles theme.
5. **Themes:** light + dark. Dark is the default (`background: #1a1816`); light (`#efede8`) toggled by setting `body.light`.
6. **Export dialog fields** exactly match plantly.ro's post fields from `PLAN.md` §Context: `title ≤64`, `description ≤2000`, `price` (lei), category, county+city, ≤6 photos.
7. **Bottom-inset fixes.** The designer's last two rounds of work were about the tab-bar FAB being clipped and the export-dialog footer being clipped; both are fixed in the handed-off source — **do not regress them**. The visual-regression tests lock this.

## Next session should

1. **Install Flutter** (current dev box has Node + Go + Python3 but no Flutter/Dart).
2. **Scaffold Flutter at the repo root.** `flutter create` refuses to overwrite a non-empty directory, so use `flutter create --project-name plantly_inventory --org ro.plantly.inventory --platforms=android,ios,web,linux,macos,windows .` from inside the directory (the trailing `.` + identical name permit an in-place scaffold). The prototype, tests, workflows, and docs it generates will sit alongside `web/` / `tests/` / `.github/`; merge any `analysis_options.yaml` / `.gitignore` / `README.md` diffs by hand.
3. Follow `PLAN.md` §"Phase 1 — Offline MVP" to stand up the Drift schema, op-log table, adaptive scheduler, local notifications, and the feature tree — porting visuals from `web/prototype/` one widget at a time. The prototype is the visual contract.
4. Keep the prototype and its tests running — they're the design acceptance gate for the Flutter port. If a Flutter screen diverges visually from `web/prototype/`, the change needs an updated visual baseline *and* a chat-transcript justification.

## What to avoid

- **Don't** convert the prototype into a React build system (Vite/Next/CRA). The design handoff ships with `@babel/standalone` for a reason — it keeps the files diffable against a future Claude Design re-export.
- **Don't** treat the prototype as production code to be optimized. It is a reference artifact. Ship Flutter for production; ship the HTML for design review.
- **Don't** skip the `tenant_id` / `updated_hlc` / `deleted_at` / `device_id` columns on any Flutter `Drift` table, even in the single-user Phase 1. Doing so forces a full schema rewrite when Phase 2 sync lands (locked decision in `PLAN.md`).
- **Don't** couple the Flutter app to plantly.ro directly. The `ExportPlugin` contract (`PLAN.md`, Phase 2) is the only supported marketplace boundary.

## Conventions

- **License:** AGPL-3.0-or-later for the Flutter core + all prototype code. MIT for the `ExportPlugin` SDK and generated Dart API client (Phase 2). CC-BY-SA-4.0 for the species seed (Phase 1 asset).
- **Dart style:** `flutter_lints`; `dart format` on save; no unnecessary comments — only write a comment when the WHY is non-obvious (hidden constraint, invariant, workaround).
- **Testing:**
  - Prototype: Playwright (this repo, today).
  - Flutter unit: `flutter test`.
  - Flutter integration: `flutter test integration_test/` on Chrome + Android emulator.
  - E2E sync (Phase 2): `docker compose up` on a clean VM → two devices → reconcile.
- **Commits:** conventional (`feat:`, `fix:`, `docs:`). Include the Phase number in the body if the commit touches phased work.
