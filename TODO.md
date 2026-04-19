# PlantlyInventory — TODO

Running list of known bugs and gaps the user will hit. Ordered within each
section by how user-visible the breakage is. Check items off when the fix
ships; append `@PR#N` when opening a PR so drift stays obvious.

When Phase-1 polish is done and none of the P0/P1 items remain, roll
everything still open into `PLAN.md` Phase 2 and delete this file.

---

## P0 — Broken on install (user-reported, 2026-04-19)

- [x] **Locations: cannot put a plant into a space.** Picker added to
      `AddPlantSheet`; "Add plants / Manage" button on every
      `_LocationTile` opens `AssignPlantsSheet` (full list with per-row
      toggle). Plant Detail overflow now has "Move to space…".
      `PlantRepository.setLocation` wires it.
- [x] **Home plant tiles don't update their photo.** `PlantPhotoThumb`
      streams `attachedPhotosProvider` and renders the first on-disk file,
      falling back to the gradient stub. Used by grid cards, plant rows,
      Spaces tiles, Assign sheet, and Search results.
- [x] **Plant Detail shows only the first photo even after multi-select.**
      Hero replaced with `PageView` carousel + page dots + "n/N" counter.
      Long-press → detach confirm dialog.
- [x] **FAB overlaps the "Me" tab.** Tab bar moved into
      `Scaffold.bottomNavigationBar`; FAB docked with
      `FloatingActionButtonLocation.centerDocked`. Notch carved out
      between Calendar and Spaces.
- [x] **Recent Activity widget is hardcoded.** Now a `ConsumerWidget` over
      `recentCareEventsProvider`; top-3 events with product/dose/notes.
      "View all" opens a full `ActivityScreen` grouped by
      TODAY/YESTERDAY/date. Rows tap through to the plant.
- [x] **Calendar is a proof of concept.** `CalendarScreen` streams real
      schedules + done events, pivots by weekday, highlights today, and
      lets the user step between weeks with chevrons. Rain-banner
      removed (no weather provider yet).
- [x] **Customising home widgets: only deletion works.** Add panel
      rewritten as a single-column list of full-width taps (was a 2-col
      grid with 4.2 aspect ratio — tap targets were tiny). Presets kept;
      "Reset to default" button added.

## P1 — Next-up polish

- [x] **Stats widget is hardcoded.** Wired to `dueBeforeEodProvider`,
      `plantsStreamProvider`, `locationsStreamProvider`.
- [x] **"See all" on All Plants widget is inert.** Now opens
      `SearchScreen` ("Search" label, full plant list implicit via
      the search box).
- [x] **Plant Detail still pulls nickname / species / location / tags
      from `MockPlants`.** Now reads live `PlantRow` + resolves
      `location_id` via `locationByIdProvider`. `acquiredAt` from DB.
      `MockPlants` kept only for the decorative colour swatch on the
      fallback stub.
- [x] **Android notifications still don't fire.** Added
      `ScheduledNotificationReceiver` +
      `ScheduledNotificationBootReceiver` to
      `AndroidManifest.xml`, plus
      `POST_NOTIFICATIONS` + `RECEIVE_BOOT_COMPLETED` permissions.
      Bootstrap `unawaited`s `requestPermissions()` so the prompt
      appears on first launch.
- [x] **Add-plant sheet has no location picker.** Dropdown populated
      from `locationsStreamProvider`, `isExpanded: true`, hint
      "Optional".
- [x] **Export dialog uses `MockPlant` fields.** Now takes `PlantRow`;
      title + description prefilled from `nickname` + `notes`. Photo
      grid streams `attachedPhotosProvider`.
- [x] **Inventory actions UI: only propagate ships.** Overflow menu
      now has Propagate, Move, Gift, Sale, Mark dead. Last three open
      `InventoryActionSheet` which writes the ledger + soft-deletes
      the plant in one DB transaction.
- [x] **Dark/light theme toggle has no in-app control.** New `MeScreen`
      with a theme `Switch`; plant / space counts.
- [x] **"Me" tab is a dead link.** Tab `onMe` pushes `MeScreen`.

## P2 — i18n, workflows, tech debt

- [ ] **Externalise the remaining English strings.** Plant Detail,
      Calendar, Export Dialog, SearchScreen, Add-reminder, Log-event,
      Me screen, Activity screen, Edit-plant, Tag chip dialog,
      Inventory ledger, Quick-log picker, Weather/Tip widget.
- [ ] **Location + tag filter chips on Home.** `PlantFilter` only has
      All / Overdue / Due today — now that real tags exist, extending
      with tag chips is mechanical.
- [ ] **Species is stored as free-text in `species_id`.** Should link
      to the `species` table (which is present but unseeded).
- [ ] **CI workflow.** `.github/workflows/web-ci.yml` exists locally
      but was never pushed (PAT missing `workflow` scope).
- [ ] **Drift "AppDatabase created multiple times" warning in tests.**
      Cosmetic but log-spammy.
- [ ] **Search doesn't cover tag names.** FTS5 indexes nickname +
      notes; extending to tag names is a schema-migration job.
- [ ] **Greeting widget user name config** — currently "Good morning"
      without a name. Add a setting on Me screen + read from prefs.
- [ ] **Prototype's `postMessage` edit-mode protocol** is still
      referenced in `CLAUDE.md` but not ported to Flutter.

## Phase 2 (per PLAN.md — not on this TODO)

- Go sync server + MinIO + imgproxy + Caddy stack
- `plantly.ro` `ExportPlugin` concrete implementation
- `POST /sync/push` / `GET /sync/pull` over the existing `sync_ops`
  wire format

---

## Fixed in v0.5.5-phase1 (2026-04-19, mock cleanup sweep)

- [x] **Weather widget** was hardcoded `"TIMIȘOARA · 19°C / Rain
      Saturday…"` without a provider. Now a rotating **Tip of the
      day** card, deterministic by day-of-year so it stays stable
      for a session.
- [x] **Quick-log widget** toast-only. Now opens a plant picker and
      records a real `care_events` row via `CareEventRepository.record`.
- [x] **Plant Detail photo delete** was long-press-only and
      undiscoverable. Added an explicit delete icon in the carousel
      header next to the `n/N` counter.
- [x] **Timeline delete** was missing. Each row now has a delete
      icon + long-press confirm; wired to `CareEventRepository.undo`.
- [x] **Inventory ledger view** on Plant Detail — hidden when empty,
      otherwise shows propagate / gift / sale / death history.
- [x] **Plain "Delete plant"** action in the overflow menu, beside
      Gift / Sale / Mark dead.
- [x] **Export drafts** now persist in SharedPreferences per plant;
      reopening the dialog prefills your last draft.
- [x] **Me screen actions**: Export JSON / Export ZIP (with photos) /
      Import backup (file picker + passphrase) / Download .ics /
      Notifications status chip with retry.
- [x] **Cascade soft-delete of schedules.** Plant soft-delete + every
      inventory close-out (gift / sale / death) now also tombstones
      the plant's care schedules so reminders stop firing.
- [x] **Plant Detail overflow on long nicknames / notes** — nickname
      gets `maxLines: 2`, species and notes get ellipsis.
- [x] **Move-to-space dialog** shows a snackbar confirming the new
      assignment (or removal).

## Fixed in v0.5.4-phase1 (2026-04-19, second sweep)

- [x] **Opening a plant sometimes opened the wrong one.**
      `MockPlants.byId(unknownId)` returned `monsteraBob` whose id is
      `'bob'`, and the home widgets passed `mock.id` to the navigator.
      Result: every newly-added plant opened Bob's detail screen.
      Killed `MockPlant.id` as a nav key — widgets now pass the real
      `PlantRow.id`. `MockPlants.byId` returns a synthesised stub
      with the requested id and a hash-selected swatch.
- [x] **New plants inherited Bob's title + photo** — same root cause
      as above. Home grid / Overdue / Today / Search / Spaces /
      Assign now read the nickname straight from `PlantRow` and the
      location name from `locationsStreamProvider`.
- [x] **Editing plants is not possible.** Pencil icon on Plant Detail
      opens `EditPlantSheet`: nickname, space dropdown, species
      (free-text), notes. `PlantRepository.edit` writes per-field
      op-log entries in one transaction.
- [x] **Adding tags is not possible.** `TagRepository` +
      `PlantTagRepository` (OR-Set), `TagChipInput` on the Plant
      Detail header with remove-chips + an add dialog that
      autocompletes against `allTagsProvider` and ensures unique
      tag names.
- [x] **Schedules for deleted plants linger on home widgets / stats /
      calendar.** Every list now filters `plantsById.containsKey`
      so a gifted / sold / dead plant doesn't leave ghost reminders.
- [x] **First-launch location seed is now idempotent on upgrades.**
      Previously only users who installed a build that included
      seeded locations got them; existing installs stayed empty.
      `seedIfEmpty` now tops-up locations whenever the tenant has
      none, independently of the plants seed.

Last reviewed: 2026-04-19 (after v0.5.5-phase1 ship)
