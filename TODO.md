# PlantlyInventory — TODO

Running list of known bugs and gaps the user will hit. Ordered within each
section by how user-visible the breakage is. Check items off when the fix
ships; append `@PR#N` when opening a PR so drift stays obvious.

When Phase-1 polish is done and none of the P0/P1 items remain, roll
everything still open into `PLAN.md` Phase 2 and delete this file.

---

## P0 — Broken on install (user-reported, 2026-04-19)

- [ ] **Locations: cannot put a plant into a space.** Spaces screen shows
      the hierarchy and lets you create/delete locations, but has no UI
      to assign a plant to one. Add plant → pick location in
      `AddPlantSheet`, and an "Assign plants" action on each
      `_LocationTile` that opens a multi-select of plants. Wire via
      `PlantRepository.setLocation(plantId, locationId)`.
- [ ] **Home plant tiles don't update their photo.** `PlantThumb`
      renders a gradient + eco icon regardless of what the user
      attached. The grid card's `Positioned.fill` should stream
      `plantPhotoRepositoryProvider.watchAttached(plantId).first` and
      render the on-disk file when present, falling back to the gradient
      stub only if none. Same refactor lets Plant Row thumbs update too.
- [ ] **Plant Detail shows only the first photo even after multi-select.**
      `_HeroPhoto` reads `shas.first`. Replace the static hero with a
      horizontally-scrollable gallery (PageView + dots) over every sha
      in the OR-set. Long-press → detach.
- [ ] **FAB overlaps the "Me" tab.** `HomeScreen` uses the default
      `FloatingActionButtonLocation.endFloat`, and the tab bar lives
      inside the body — not `Scaffold.bottomNavigationBar` — so the FAB
      sits on top of the rightmost tab. Either move the tab bar into
      `bottomNavigationBar` and use `centerDocked`, or pin the FAB with
      custom `Padding` above the tab-bar height.
- [ ] **Recent Activity widget is hardcoded.** `ActivityWidget._items`
      is a fixed `["7:12 Fern spray — Misted", …]` list. Make it a
      `ConsumerWidget` over a new `recentCareEventsProvider` (top-N from
      `care_events` joined with `plants.nickname`). Wire the
      `action: 'View all'` to navigate to a full activity screen (or at
      minimum expand the widget inline).
- [ ] **Calendar is a proof of concept.** `CalendarScreen` hardcodes
      `_Day('Mon', '14', …)` rows. Stream the visible week from
      `CareScheduleRepository.watchDueBefore(endOfWeek)` +
      `CareEventRepository` for already-done events, pivot by weekday,
      highlight today based on real `DateTime.now()`. Keep the
      rain-banner design but gate on a real weather provider (or hide
      until one lands — currently dishonestly offers "Apply" on data
      that doesn't exist).
- [ ] **Customising home widgets: only deletion works.** Edit mode lets
      you remove but the Add list appears empty when every widget is
      already on the layout (which is the default). Fix two ways:
      (1) allow adding a second instance of an existing widget, or
      (2) if single-instance is intentional, show the "All widgets are
      on the home screen." placeholder *plus* the presets, and make the
      presets more discoverable. Verify taps on `_AddButton` actually
      mutate state — if layout is watched correctly, the Add panel
      should shrink as items are added.

## P1 — Next-up polish

- [ ] **Stats widget is hardcoded.** "2 / 3 / 24 / 6" never change.
      Wire each tile to a provider: overdue count, due-today count,
      `plants.watchAll().length`, `locations.watchAll().length`.
- [ ] **"See all" on All Plants widget is inert.** Either remove or
      push to a full-grid screen.
- [ ] **Plant Detail still pulls nickname / species / location /
      tags from `MockPlants`.** `PlantDetailScreen` calls
      `MockPlants.byId(plantId)`. Read the live `PlantRow` instead, and
      resolve `location_id` against `locations`. Acquired date should
      come from `PlantRow.acquiredAt`, tags from `plant_tags`.
- [ ] **Android notifications still don't fire.** v0.5.1 stopped the
      crash on past-time schedules but the manifest is missing
      `com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver`
      and `ScheduledNotificationBootReceiver` plus
      `RECEIVE_BOOT_COMPLETED`. Alarm fires → no receiver → silently
      dropped. Also `requestPermissions()` is never called at launch.
- [ ] **Add-plant sheet has no location picker.** New plants are
      locationless. Add a dropdown populated from
      `locationsStreamProvider`.
- [ ] **Export dialog uses `MockPlant` fields.** Wire to the live
      `PlantRow` + attached photos so the plantly.ro draft matches
      reality.
- [ ] **Inventory actions UI: only propagate ships.** Gift / sale /
      death rows in `InventoryTransactionRepository` have no UI — add
      them to the Plant Detail overflow menu mirroring Propagate.
- [ ] **Dark/light theme toggle has no in-app control.** Prototype had
      an edit-mode `postMessage` toggle; the Flutter app defaults to
      light with no visible switch. Surface it on the Me tab when that
      screen lands, or in the edit panel for now.
- [ ] **Edit panel → "Me" tab is a dead link.** Tab icon exists with no
      onTap.

## P2 — i18n, workflows, tech debt

- [ ] **Externalise the remaining English strings.** Plant Detail,
      Calendar, Export Dialog, SearchScreen, the new Add-reminder and
      Log-event sheets — anything with raw `'Done'` / `'Save'` / etc.
      still needs ARB keys + `AppLocalizations.of(context)`.
- [ ] **Location + tag filter chips on Home.** `PlantFilter` only has
      All / Overdue / Due today. Pattern is established — extend with
      per-location and per-tag filters.
- [ ] **CI workflow.** `.github/workflows/web-ci.yml` exists locally
      but was never pushed (PAT missing `workflow` scope). Push with a
      properly-scoped PAT or commit through the GitHub web UI so
      Playwright + `flutter analyze` + `flutter test` run on every PR.
- [ ] **Drift "AppDatabase created multiple times" warning in tests.**
      Cosmetic but log-spammy. Use one shared in-memory executor per
      test suite, or flip `driftRuntimeOptions.dontWarnAboutMultipleDatabases`.
- [ ] **`requestPermissions()` for notifications is never called.** Add
      to `appContextProvider` bootstrap after first launch.
- [ ] **Prototype's `postMessage` edit-mode protocol.** Not ported —
      fine for the Flutter build, but if we ever re-open the prototype
      in Claude Design we lose theme sync. Either drop from docs or add
      a Flutter equivalent.

## Phase 2 (per PLAN.md — not on this TODO)

- Go sync server + MinIO + imgproxy + Caddy stack
- `plantly.ro` `ExportPlugin` concrete implementation
- `POST /sync/push` / `GET /sync/pull` over the existing `sync_ops`
  wire format

---

Last reviewed: 2026-04-19 (after v0.5.2-phase1 ship)
