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

## Fixed in v0.5.12-phase1 (2026-04-19, photo annotations + reorder + location gallery schema)

- [x] **Photo captions.** Schema v6 adds `plant_photos.caption`.
      Pencil button on the Plant Detail carousel opens a dialog
      (caption, clear, save). Overlay renders at the bottom of the
      current slide.
- [x] **Photo reorder.** Drag-to-reorder screen invoked from a
      swap-vert button in the carousel (appears only when >1
      photo). `PlantPhotoRepository.reorder` writes `display_order`
      so the PageView picks up the new sequence on rebuild.
- [x] **Location photo table** (schema v6). `LocationPhotos` OR-set
      table + `LocationPhotoRepository` (attach / detach / set
      caption / watch). Backed up via `BackupService`.

## Fixed in v0.5.11-phase1 (2026-04-19, P1 finishing touches)

- [x] **Swipe actions on Overdue/Today rows.**
      New `SwipeRow` wrapper with Dismissible semantics but
      `confirmDismiss: false` — swipe right logs the care event,
      swipe left snoozes 1 day. Backgrounds colour-code the action.
- [x] **Pull-to-refresh on Home.** `RefreshIndicator` wraps the
      main ListView; onRefresh calls `ReminderSync.syncFromDatabase()`
      to give users an explicit way to force-resync OS notifications.
- [x] **Reminder presets in AddReminderSheet.** Horizontal chip row
      with 6 one-tap templates (Daily / Every other day / Weekly /
      Mondays 09:00 / Bi-weekly / Monthly). "Mondays 09:00" uses
      the `fixed` recurrence mode + an anchor date for the next
      Monday.

## Fixed in v0.5.10-phase1 (2026-04-19, P1 completion)

- [x] **Location + tag filter chips on Home.** Compound filter:
      status (All/Overdue/Due today) × location × tag. Each chip
      toggles its dimension independently. Implementation uses
      the existing `PlantFilter` enum plus two new
      `StateProvider<String?>` for location and tag.
- [x] **Global per-care-type mute.** Prefs-backed
      `mutedCareTypesProvider` (set of type keys). `ReminderSync`
      now takes a snapshot callback that reads the set on every
      sync. Toggle exposed on each row in the Care Types screen.
- [x] **Stats dashboard (Me → Stats).** Headline card (plants /
      total events / last 30d), activity by care type (bar list),
      top 5 plants in the last 30 days. Derived purely in-memory
      from already-streamed providers.

## Fixed in v0.5.9-phase1 (2026-04-19, P1 sweep)

- [x] **Plant duplication.** Overflow → "Duplicate plant" copies
      nickname, species, location, notes, tags, and care schedules
      (with fresh first-due dates).
- [x] **"Water now" FAB on Plant Detail.** One-tap most-common action.
- [x] **Reminder preview.** AddReminderSheet shows the next 1–3
      firings before Save so the user can sanity-check the
      interval + mode combination.
- [x] **Do-not-disturb window.** Me → Notifications: toggle with
      start + end time pickers. `NotificationService.syncAll`
      pushes any event falling inside the quiet hours to the
      window's end.
- [x] **Recently-used products.** LogEventSheet surfaces the last
      10 product values as tappable chips that fill the Product
      field.
- [x] **Care-type colour.** `CareType.colorValue` (prefs-backed);
      8-colour palette + "Default" in the Care Types edit sheet.
- [x] **CSV export.** Me → Backup: single CSV with both plants
      and care events, share-sheeted out.
- [x] **Per-plant stats card.** Plant Detail gets a STATS section
      showing total events, last care-type + days-ago, and average
      interval for the most-frequent type.

## Fixed in v0.5.8-phase1 (2026-04-19, P0 sweep + editing + polish)

- [x] **Plant grid sort** — name A–Z / Z–A / next due / newest /
      oldest / by space. Persisted in `plantly_plant_sort`.
- [x] **Home first-run callout** when the user has zero plants:
      "Tap the + button to add your first plant." Removes the
      empty-screen confusion.
- [x] **Home notification-permission banner** when the OS denied
      the perm — tap to retry.
- [x] **Next-due pill on every grid card.** Black 60% chip with
      the care-type icon + short relative label (e.g. `💧 in 2d`).
- [x] **Schedule editing.** Long-press an Upcoming Care row →
      `EditReminderSheet`: interval + unit + recurrence mode +
      next-due + delete. Resets adaptive window so the user's
      change is authoritative.
- [x] **Care-event editing.** Tap a Timeline row → `EditEventSheet`
      (type / when / product / dose / notes).
      `CareEventRepository.edit`.
- [x] **Camera capture option.** `PhotoSourceSheet` chooser between
      gallery and camera; wired into Plant Detail's add-photo button
      and Location Detail's map picker.
- [x] **Undo snackbars.** Delete plant → snackbar with Undo that
      calls new `PlantRepository.restoreFromSoftDelete`. Delete
      timeline event → snackbar with Undo that re-records the same
      event verbatim.
- [x] **Photo + tag cascade on plant soft-delete.** `plant_photos`
      and `plant_tags` OR-set rows now get a `removed_hlc` stamp
      when the plant is soft-deleted, so the gallery / chips drop
      cleanly.
- [x] **Backup includes `inventory_transactions`** — previously
      silently omitted; restore would lose every
      propagate/gift/sale/death record.
- [x] **Backup includes user preferences** — `plantly_care_types`,
      `plantly_layout`, `plantly_theme`, `plantly_plant_sort` —
      so custom types + home layout + sort round-trip.
- [x] **Notifications dashboard** — Me → Muted reminders: lists
      every muted plant / schedule / location with an unmute
      button per row. Plus a permission-status card at the top.

## Fixed in v0.5.7-phase1 (2026-04-19, locations + pins + mute)

- [x] **Location expansion.** `LocationEditSheet` covers every
      user-editable field: name, kind, parent (with cycle guard),
      outdoor flag, light level (4-option dropdown), humidity
      min/max, temp min/max, notes. Replaces the old minimal
      create-only dialog.
- [x] **Location detail screen.** Tapping a Spaces tile opens it;
      shows metadata chips (kind, outdoor, light, humidity, temp,
      muted), notes, the plants-in-this-space list, and the map
      card.
- [x] **Map + plant pins.** Schema v5 adds
      `locations.map_photo_sha` + `plants.pin_x / pin_y`. Users can
      attach any image as a room layout; tap to place the next
      unplaced plant, drag to reposition, long-press a pin to
      remove. Tapping a pin outside of edit mode goes to the plant
      detail. Map box locks to a 4:3 aspect so the image never
      takes up the whole screen.
- [x] **Per-plant / per-schedule / per-location notification mute.**
      Schema v5 adds `notifications_muted` on `plants`,
      `care_schedules`, and `locations`. `ReminderSync` now filters
      each axis. UI:
        * Bell icon on every Upcoming Care row (per-schedule).
        * Plant Detail overflow → "Mute all notifications"
          (per-plant).
        * Location Detail overflow → "Mute notifications"
          (per-location — applies to every plant in that space).

## Fixed in v0.5.6-phase1 (2026-04-19, reminders + search + calendar + settings)

- [x] **Search by tags.** `SearchRepository.search` now unions FTS5
      matches on nickname+notes with a tag-name prefix scan joined via
      `plant_tags`. Typing `variegated` finds every plant with that tag.
- [x] **Reminder units.** `AddReminderSheet` gets a
      SegmentedButton for **min / hr / day / mo**; intervals are stored
      as fractional days so EWMA stays numeric.
- [x] **Recurrence mode.** Schema v4 adds `recurrence_mode` to
      `care_schedules`. Options: **After I mark it done** (existing
      adaptive reschedule), **On a fixed schedule** (anchored cadence —
      completion doesn't shift the next date), **Just once**
      (auto-disables after first event).
- [x] **Editable care types for reminders + events.** New
      `CareTypesController` persists a user-editable list in
      SharedPreferences; Built-ins (water / fertilize / mist / repot /
      prune / rotate) can be renamed, have their default interval or
      icon changed, or hidden. Users can add custom types that show up
      everywhere: Add reminder, Log event, Calendar, Activity,
      Quick-log.
- [x] **Settings → Care types** screen reached from Me tab.
- [x] **Hierarchical location picker.** Unified `pickLocation()` from
      `lib/shared/location_picker.dart` renders the location tree
      indented by depth. Wired into Add-plant sheet, Edit-plant sheet,
      and Plant Detail's "Move to space" overflow action.
- [x] **Calendar Week / Month / Year views** with an always-visible
      "UPCOMING" strip at the top so users never see an empty screen.
      Month view is a dot-grid (terra dot = scheduled, green dot =
      done). Year view = 12 month tiles with per-month counts; tap a
      month to zoom in.
- [x] **Stats tiles are interactable.** Overdue / Due today / Plants
      route to Search (with pre-applied filter); Spaces opens the
      Locations tab. Every Home tap target now does something.

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
