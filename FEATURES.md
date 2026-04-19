# PlantlyInventory — feature inventory

Running catalogue of every feature the product could plausibly want,
bucketed by priority. Items already shipped aren't listed — see `TODO.md`
for the "fixed in" history and the P2 queue. Items here are **what's still
missing** on the critical path, or what could land next.

Categories:
- **P0 — Necessary.** Completes Phase 1 on its own terms. User will hit
  the gap within the first hour of real use.
- **P1 — High value.** Noticeably improves daily use once the user has
  a few plants.
- **P2 — Nice to have.** Polish / power-user / niche.
- **Phase 2+.** Explicitly deferred per `PLAN.md` — listed so we don't
  accidentally scope-creep.

Tag key after each item:
- `[data]` — schema / repo work
- `[ui]` — flutter screen / widget
- `[os]` — platform integration
- `[sync]` — Phase 2 concern

---

## P0 — Necessary to close Phase 1

- **Plant grid sort & grouping.** Name / Next-due / Newest / Oldest /
  by Location. Persist the choice per install. `[ui]`
- **Empty-state when the user has zero plants.** Home grid currently
  shows a blank space — new installs after the seed-disable look
  broken. `[ui]`
- **Care-event editing, not just undo.** User watered yesterday but
  typed the wrong amount — today they can only delete + re-add.
  `CareEventRepository.update(id, …)` + long-press Timeline row →
  edit sheet. `[data][ui]`
- **Reminder snackbar undo.** Deleting a plant / pin / photo /
  timeline event is one-tap; none of the snackbars offer Undo.
  Material spec 101. `[ui]`
- **Detach photos when a plant is soft-deleted.** Prevents OR-set
  rows pointing at a tombstoned plant from accumulating, and lets
  the content-addressed store GC unreferenced files. `[data]`
- **Home banner when notification permission is denied.** Me-screen
  chip is discoverable *if* the user navigates there; a persistent
  banner under the Home app-bar is the only honest UI.  `[ui]`
- **Care-type colour + icon in Calendar dot grid.** Today both
  "scheduled" and "done" are a single dot; if a day has both water
  + fertilize the user can't see what kind.  `[ui]`
- **Plant grid card shows next-due type.** Currently only a
  green/terra dot indicating ok/overdue. Small "💧 in 2d" pill. `[ui]`
- **"Me" tab name customisation.** Greeting widget says "Good
  morning" without a name because we don't ask. Prefs field on Me
  screen, hydrated into the greeting. `[ui]`
- **Re-parent a location.** LocationEditSheet supports it; Spaces
  tile doesn't surface a "Move this space under…" action. `[ui]`
- **Species free-text → autocomplete from existing.** Today every
  plant's species is pure free-text; users end up with `"Monstera
  Deliciosa"` vs `"monstera deliciosa"`. Simple dedup-by-lowercase
  in the dropdown. `[ui]`

## P1 — High-value daily features

- **Plant duplication.** "Add another Monstera" → prefill name +
  species + location + care schedules from an existing plant.
  Common for collectors. `[ui]`
- **Watering amount tracking.** `care_events` already has `dose` —
  expose a quick ml/l input on the Done button path, not just the
  Log-event sheet. `[ui]`
- **Fertiliser product lookup.** Store recently-used products as
  suggestions on the Log-event sheet's Product field. `[data][ui]`
- **Swipe actions on plant rows.** Swipe right → Water now, swipe
  left → Snooze. Much faster than tap-through on many plants.
  `[ui]`
- **Multi-select bulk ops.** Long-press a plant card to enter
  selection mode; bulk-add reminder, bulk-mute, bulk-move to
  space. `[ui]`
- **Care statistics per plant.** "You've watered Bob 14× in the
  last 3 months — average 10 days between." `[ui]`
- **Care statistics dashboard.** Me screen → Stats: lifetime events
  by type, 7d / 30d trend, overdue streak, etc. `[ui]`
- **Per-care-type mute (global).** Today per-plant / per-schedule /
  per-location mute lives. Missing: "silence every fertilize
  reminder across the app for a week while you're traveling".
  `[data][ui]`
- **Do-not-disturb window.** Don't fire notifications between
  22:00 and 08:00. `[os]`
- **Reminder preview before saving.** In AddReminderSheet, show
  "Next 3 reminders: Apr 21 08:00, Apr 28 08:00, May 5 08:00"
  before the user taps Save. `[ui]`
- **Plant detail "Water now" FAB.** One-tap most-common action
  instead of scrolling to the Upcoming Care row. `[ui]`
- **Photo annotations.** Add a caption + a tag (e.g. `yellow leaf`,
  `new growth`) to photos. `[data][ui]`
- **Photo reorder.** Plant Detail gallery already supports
  detach; drag to reorder the hero carousel. `[ui]`
- **Location photo gallery.** Today only the *map* photo attaches;
  a location can also have a gallery of ambient photos.
  `[data][ui]`
- **Care-type colour.** Each `CareType` gets a custom colour in
  addition to icon; chips + dot-grid use it. `[data][ui]`
- **Location search filter chips on Home.** `PlantFilter` extends
  to "in Living room", "in Balcony", etc. `[data][ui]`
- **Tag filter chips on Home.** Same pattern, but per-tag.
  `[data][ui]`
- **Recently-used templates for reminders.** On AddReminderSheet,
  show "Water every 7 days" / "Fertilize monthly" as one-tap
  templates from past schedule history. `[ui]`
- **Pull-to-refresh** on Home, Plant Detail, Activity, Calendar. Not
  strictly needed with Drift streams but users expect it. `[ui]`
- **Recurrence-mode presets in AddReminderSheet.** "Every Monday
  at 9 AM" could auto-fill the fixed schedule. `[ui]`
- **Export to CSV** (plants + events). Easier than JSON for
  spreadsheet nerds. `[ui]`
- **Backup includes `care_types` + home-layout preferences.** Right
  now those live in SharedPreferences and are not round-tripped.
  `[data]`

## P2 — Nice to have

- **Care event notes inline edit.** Long-press a Timeline row →
  edit notes/product/dose. (Partial overlap with P0 care-event
  editing; this is the lightweight variant.) `[ui]`
- **Weight tracking.** New `plant_measurements` table, chart on
  Plant Detail showing height/weight/girth over time. `[data][ui]`
- **Plant health log.** Separate from care events — track
  "yellowing leaves", "pests spotted", "new growth", with optional
  photo. `[data][ui]`
- **Day-cell tap on Calendar Month view filters the list.** Tap
  Tuesday → list of events for that day. `[ui]`
- **Calendar Year view click zoom.** Already implemented — verify
  and polish animation.
- **Accessibility labels.** Every tappable surface needs a semantic
  label. `[ui]`
- **Larger-text mode.** Respect `MediaQuery.textScaler`.  `[ui]`
- **Dark/light colour theme beyond the single `ThemeMode`.** Seed
  colour picker on Me screen. `[ui]`
- **Biometric lock.** Open the app with fingerprint/face before
  showing plants + location photos. `[os]`
- **Smart species defaults.** Picking "Monstera deliciosa" auto-
  fills watering interval. Needs a seed taxonomy table.
  `[data][sync]`
- **OS home-screen widgets.** "Next reminder" tile on Android via
  `flutter_home_widget`. `[os]`
- **Quick-add from a shared photo.** Android "Share → PlantlyInventory"
  picks a photo, opens AddPlantSheet with the image pre-attached. `[os]`
- **Export / import widgets layout.** Same SharedPreferences
  problem as care_types — makes layouts portable.  `[data]`
- **Search history / recent searches.** Small list below the search
  field. `[ui]`
- **Plant-to-plant relationships.** "Propagated from X" is tracked
  in inventory_transactions; expose on Plant Detail's header as a
  breadcrumb link. `[ui]`
- **Care reminder icon drop-zone in the Notification tray.** Swipe
  left on an OS notification → "Mark done" action button that
  calls back into the app via payload.  `[os]`
- **Image pinch-to-zoom on Plant Detail hero + map.** Current
  carousel is non-zoomable.  `[ui]`
- **Plant-level light/humidity override.** Plant can inherit from
  location but override per-plant (location is south-facing but
  this guy is shaded by a curtain). `[data][ui]`
- **Reminder lead time.** "Notify me 1 day before the due time."
  Flag on schedule + adjust the scheduled TZDateTime.
  `[data][os]`
- **Sibling plants on map.** Show a line between parent + propagated
  child on the location map. `[ui]`
- **Event re-categorisation.** Accidentally logged water instead
  of fertilize — let the user change type after-the-fact.
  `[data][ui]`

## Defense-in-depth / tech debt (not user-visible)

- **Photo GC.** Background sweep that deletes `photos` rows (and
  their files) whose SHA no longer appears in any live
  `plant_photos` + `location.map_photo_sha`. `[data]`
- **Drift multi-database test warning.** Cosmetic but log-spammy in
  CI.  `[data]`
- **Backup `currentFormatVersion` bump** when v5 columns become
  mandatory. Right now `_restore` copes via `item.containsKey`, but
  a version bump lets us write upgrade/downgrade paths on purpose.
  `[data]`
- **Op-log compaction.** `sync_ops` grows unbounded; Phase 2 prunes
  on successful push, but Phase 1 has no cleanup. After 1 year of
  daily use the table is tens of thousands of rows. `[data]`
- **Runtime icon tree-shake regressions.** One already bit us.
  Lint guard: static-analyse every `IconData(` call site. `[data]`

## Phase 2 (per PLAN.md — intentionally deferred)

- **Sync server.** Go + MinIO + imgproxy + Caddy; op-log push/pull.
- **Household sharing.** Multi-tenant by `tenant_id`; invite codes;
  per-plant ACL.
- **Plantly.ro `ExportPlugin`.** Posting / drafts / listing status.
- **Species taxonomy seed.** CC-BY-SA-4.0 JSON with default care
  intervals + hardiness zones.
- **Weather provider.** Replaces the "Tip of the day" card; rain
  banner on Calendar.
- **Community tips / advice** surfaced on species pages.
- **AI plant ID via camera.** Nice-to-have overlay on AddPlantSheet.

---

## What's honest today

See `TODO.md` "Fixed in v0.5.x" sections for the shipped record.
**Ignore this file's absence of P0 polish** as a release-blocker:
it's a wish list, not a regression list. Known regressions live on
`TODO.md` P0/P1.

Last reviewed: 2026-04-19 (after v0.5.7-phase1 ship).
