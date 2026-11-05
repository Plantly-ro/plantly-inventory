# PlantlyInventory — Companion Plant Tracker for plantly.ro

## Context

plantly.ro (codebase: `~/Desktop/Pltio`) is a deliberately minimal Romanian plant marketplace — plants are modelled as generic `posts` (title ≤64ch, description ≤2000ch, price in lei, county/city, up to 6 photos, category). It has **no care tracking, no calendar, no weather, no species database, no inventory graph, no per-plant history.** Sellers who actually own many plants have no tool for managing them before/after listing.

**PlantlyInventory** is a separate, open-source companion app for plant owners. It is care-tracking-first and marketplace-second: users keep a rich local inventory (photos, watering/fertilizing history, propagations, locations, reminders), and can one-click export any plant as a plantly.ro listing when ready to sell.

**Operating model**
- **OSS + self-host**: full functionality with zero cloud dependency. App runs standalone; sync server is optional and shipped as docker-compose.
- **Future hosted tier (monetization)**: same codebase runs multi-tenant. Users who don't want to self-host pay for managed sync + storage + premium plugins.
- **Plugin-based marketplace export**: plantly.ro is the first export plugin; OLX/eBay/others slot in the same way without forking.

**Non-goals**: replacing plantly.ro, replacing social plant apps (Planta, Greg), or competing with botanical reference apps (PictureThis).

**Repo**: `https://github.com/Plantly-ro/plantly-inventory` (public, AGPL-3.0).

---

## Locked decisions

| Area | Choice | Rationale |
|---|---|---|
| Client | **Flutter** (web + Android + iOS + desktop, single codebase) | User requirement |
| Offline behaviour | **Offline-first, server-optional** | App usable with zero backend; sync is opt-in |
| Multi-tenancy | `tenant_id` on every synced row from day 1; single-user UX ships first | Avoids schema rewrite when household + SaaS arrive |
| Pltio coupling | **Agnostic core + `ExportPlugin` interface**; plantly.ro is first plugin | Broader OSS audience, monetizable plugin tier later |
| Photos | **MinIO/S3-compatible** on the server; filesystem-fallback config flag; on-device thumbnails | Blobs-in-DB scales poorly; matches Pltio stack |
| Local DB | **Drift** (SQLite, FTS5, OPFS on web) | Type-safe, web-capable, proper joins for inventory graph |
| Sync protocol | **HLC + per-field LWW, op-log on the wire**, OR-Set semantics for tags/photo-links | Multi-device today, household later, no CRDT lock-in |
| Sync server | **Go** (matches Pltio; single static binary); OpenAPI → generated Dart client | Self-host ergonomics, long-term domain alignment with Pltio |
| Server DB | **Postgres, always** | RLS, `jsonb`, `LISTEN/NOTIFY`; single engine across self-host + SaaS |
| Pltio auth | User logs into plantly.ro via the plugin; JWT stored in `flutter_secure_storage` | Pltio has no API-key system; JWT flow is the only option |
| Licence | **AGPL-3.0** core, MIT for plugin SDK + generated Dart client | Protects hosted tier, lowers 3rd-party plugin friction |

---

## Schema non-negotiables (v1, before sync ships)

Every synced entity carries: `id` (ULID), `tenant_id`, `updated_hlc`, `deleted_at` (tombstone), `device_id`. An `sync_ops` op-log table exists from v1. **Deferring any of these = full schema rewrite when Phase 2 lands.** Photos are stored as **content-addressed refs** (`sha256`) with a `plant_photos` OR-Set join table — never per-plant blob paths.

---

## Package list (pinned majors, versions final during scaffold)

### Flutter (`pubspec.yaml`)
```yaml
dependencies:
  flutter: sdk
  # state + routing
  flutter_riverpod: ^2.5
  go_router: ^14
  # local DB
  drift: ^2.19
  drift_flutter: ^0.2
  sqlite3_flutter_libs: ^0.5
  # HTTP + codegen
  dio: ^5.5
  retrofit: ^4.2
  # images
  file_selector: ^1.0
  flutter_image_compress: ^2.3
  crypto: ^3.0                  # SHA-256 for content-addressing
  exif: ^3.3
  # storage + secrets
  flutter_secure_storage: ^9.2
  path_provider: ^2.1
  # notifications + time
  flutter_local_notifications: ^17.2
  timezone: ^0.9
  # i18n
  intl: ^0.19
  # platform glue
  package_info_plus: ^8
  # web-only extras
  web: ^1.0                     # File System Access API on web
  # utilities
  collection: ^1.18
  ulid: ^2.0
  freezed_annotation: ^2.4
  json_annotation: ^4.9
dev_dependencies:
  build_runner: ^2.4
  drift_dev: ^2.19
  freezed: ^2.5
  json_serializable: ^6.8
  retrofit_generator: ^9
  flutter_test: sdk
  integration_test: sdk
  mocktail: ^1.0
  flutter_lints: ^4
```

### Go sync server (`go.mod`)
```
github.com/go-chi/chi/v5
github.com/jackc/pgx/v5
github.com/sqlc-dev/sqlc           # generate
github.com/golang-jwt/jwt/v5
github.com/minio/minio-go/v7
github.com/oklog/ulid/v2
github.com/rs/cors
github.com/prometheus/client_golang
golang.org/x/time/rate
github.com/getkin/kin-openapi      # schema validation
github.com/pressly/goose/v3        # migrations
```

---

## Data model — DDL

### Client (Drift, SQLite)

```sql
-- common: every synced table has id, tenant_id, updated_hlc, deleted_at, device_id

CREATE TABLE species (
  id TEXT PRIMARY KEY,            -- ULID
  tenant_id TEXT NOT NULL,
  scientific_name TEXT NOT NULL,
  common_names_json TEXT NOT NULL, -- {"en":[...], "ro":[...]}
  default_care_json TEXT,          -- {water_days: 7, light: "bright_indirect", ...}
  is_seed INTEGER NOT NULL DEFAULT 0,
  updated_hlc TEXT NOT NULL,
  deleted_at INTEGER,
  device_id TEXT NOT NULL
);

CREATE TABLE locations (
  id TEXT PRIMARY KEY,
  tenant_id TEXT NOT NULL,
  parent_id TEXT REFERENCES locations(id),
  name TEXT NOT NULL,
  kind TEXT NOT NULL,              -- home|room|zone|shelf|outdoor_bed
  light TEXT,                      -- direct|bright_indirect|medium|low
  humidity_min INTEGER, humidity_max INTEGER,
  temp_min_c REAL, temp_max_c REAL,
  is_outdoor INTEGER NOT NULL DEFAULT 0,
  lat REAL, lon REAL,              -- for outdoor weather lookup
  updated_hlc TEXT NOT NULL,
  deleted_at INTEGER,
  device_id TEXT NOT NULL
);

CREATE TABLE plants (
  id TEXT PRIMARY KEY,
  tenant_id TEXT NOT NULL,
  nickname TEXT NOT NULL,
  species_id TEXT REFERENCES species(id),
  location_id TEXT REFERENCES locations(id),
  status TEXT NOT NULL,            -- alive|propagated|gifted|dead|sold
  acquired_at INTEGER,
  source TEXT,                     -- bought|gift|propagation|wild
  notes TEXT,
  pot_size_cm INTEGER,
  updated_hlc TEXT NOT NULL,
  deleted_at INTEGER,
  device_id TEXT NOT NULL
);
CREATE INDEX idx_plants_tenant ON plants(tenant_id);
CREATE INDEX idx_plants_location ON plants(tenant_id, location_id);
CREATE INDEX idx_plants_status ON plants(tenant_id, status);

CREATE TABLE photos (
  sha256 TEXT PRIMARY KEY,         -- content address
  tenant_id TEXT NOT NULL,
  width INTEGER, height INTEGER,
  mime TEXT NOT NULL,
  bytes INTEGER NOT NULL,
  taken_at INTEGER,
  exif_json TEXT,
  local_path TEXT,                 -- on-device location
  remote_state TEXT NOT NULL DEFAULT 'local', -- local|uploading|synced
  updated_hlc TEXT NOT NULL,
  deleted_at INTEGER,
  device_id TEXT NOT NULL
);

-- OR-Set join: both add and remove carry HLC; remove wins only if remove_hlc > add_hlc for same (plant,photo)
CREATE TABLE plant_photos (
  id TEXT PRIMARY KEY,             -- ULID
  tenant_id TEXT NOT NULL,
  plant_id TEXT NOT NULL,
  photo_sha TEXT NOT NULL,
  display_order INTEGER NOT NULL DEFAULT 0,
  added_hlc TEXT NOT NULL,
  removed_hlc TEXT,                -- null = still present
  device_id TEXT NOT NULL,
  UNIQUE(tenant_id, plant_id, photo_sha, added_hlc)
);

CREATE TABLE tags (
  id TEXT PRIMARY KEY,
  tenant_id TEXT NOT NULL,
  name TEXT NOT NULL,
  color TEXT,
  updated_hlc TEXT NOT NULL,
  deleted_at INTEGER,
  device_id TEXT NOT NULL,
  UNIQUE(tenant_id, name)
);
CREATE TABLE plant_tags (          -- OR-Set, same pattern
  id TEXT PRIMARY KEY,
  tenant_id TEXT NOT NULL,
  plant_id TEXT NOT NULL,
  tag_id TEXT NOT NULL,
  added_hlc TEXT NOT NULL,
  removed_hlc TEXT,
  device_id TEXT NOT NULL
);

CREATE TABLE care_events (
  id TEXT PRIMARY KEY,
  tenant_id TEXT NOT NULL,
  plant_id TEXT NOT NULL,
  type TEXT NOT NULL,              -- water|fertilize|repot|prune|treat|observe|photo|mist|rotate
  done_at INTEGER NOT NULL,
  notes TEXT,
  dose TEXT,                       -- "1/4 tsp NPK 10-10-10"
  product TEXT,
  photo_sha TEXT,
  updated_hlc TEXT NOT NULL,
  deleted_at INTEGER,
  device_id TEXT NOT NULL
);
CREATE INDEX idx_care_events_plant_done ON care_events(tenant_id, plant_id, done_at DESC);

CREATE TABLE care_schedules (
  id TEXT PRIMARY KEY,
  tenant_id TEXT NOT NULL,
  plant_id TEXT NOT NULL,
  type TEXT NOT NULL,
  base_interval_days REAL NOT NULL,
  current_interval_days REAL NOT NULL,
  last_done_at INTEGER,
  next_due_at INTEGER,
  snooze_count INTEGER NOT NULL DEFAULT 0,
  recent_events_json TEXT NOT NULL DEFAULT '[]', -- rolling window for adaptive algo
  enabled INTEGER NOT NULL DEFAULT 1,
  updated_hlc TEXT NOT NULL,
  deleted_at INTEGER,
  device_id TEXT NOT NULL,
  UNIQUE(tenant_id, plant_id, type)
);
CREATE INDEX idx_schedules_due ON care_schedules(tenant_id, enabled, next_due_at);

CREATE TABLE inventory_transactions (
  id TEXT PRIMARY KEY,
  tenant_id TEXT NOT NULL,
  type TEXT NOT NULL,              -- acquisition|propagation|cutting|gift|death|sale
  parent_plant_id TEXT,            -- for propagation/cutting
  child_plant_id TEXT,             -- for propagation/cutting
  plant_id TEXT,                   -- for acquisition/gift/death/sale
  counterparty TEXT,
  at INTEGER NOT NULL,
  notes TEXT,
  amount_minor INTEGER,            -- price in minor units if sale
  currency TEXT,
  updated_hlc TEXT NOT NULL,
  deleted_at INTEGER,
  device_id TEXT NOT NULL
);

CREATE TABLE weather_snapshots (   -- local-only cache, not synced
  location_id TEXT NOT NULL,
  day INTEGER NOT NULL,            -- yyyymmdd
  payload_json TEXT NOT NULL,
  fetched_at INTEGER NOT NULL,
  PRIMARY KEY(location_id, day)
);

CREATE TABLE plugin_exports (
  id TEXT PRIMARY KEY,
  tenant_id TEXT NOT NULL,
  plant_id TEXT NOT NULL,
  plugin_id TEXT NOT NULL,         -- 'plantly_ro'
  remote_id TEXT,                  -- Pltio post id
  status TEXT NOT NULL,            -- draft|queued|posted|failed|sold
  last_synced_at INTEGER,
  response_json TEXT,
  updated_hlc TEXT NOT NULL,
  deleted_at INTEGER,
  device_id TEXT NOT NULL
);

-- FTS5 index over plants + notes + tag names, refreshed by Drift triggers
CREATE VIRTUAL TABLE plants_fts USING fts5(
  plant_id UNINDEXED,
  tenant_id UNINDEXED,
  nickname,
  scientific_name,
  common_names,
  notes,
  tag_names,
  location_name,
  tokenize = 'unicode61 remove_diacritics 2'
);

-- op-log: the wire format
CREATE TABLE sync_ops (
  seq INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id TEXT NOT NULL,
  entity TEXT NOT NULL,            -- 'plants', 'care_events', ...
  entity_id TEXT NOT NULL,
  field TEXT NOT NULL,             -- '*' for whole-row on create, '__tombstone__' for delete
  value_json TEXT,
  hlc TEXT NOT NULL,
  device_id TEXT NOT NULL,
  pushed_at INTEGER                -- null = not yet pushed
);
CREATE INDEX idx_sync_ops_tenant_pending ON sync_ops(tenant_id, pushed_at) WHERE pushed_at IS NULL;
```

### Server (Postgres, `goose` migrations)

Mirrors the client schema with:
- `tenant_id UUID NOT NULL` on every row.
- Postgres row-level security:
  ```sql
  ALTER TABLE plants ENABLE ROW LEVEL SECURITY;
  CREATE POLICY plants_tenant_isolation ON plants
    USING (tenant_id = current_setting('app.current_tenant')::uuid);
  ```
- `sync_ops` is the ingest log (append-only, unique `(tenant_id, device_id, hlc)`).
- `LISTEN/NOTIFY` channel `sync:{tenant_id}` for push-based delta fanout (web push / WebSocket).
- Foreign keys deferred to soft-validation (ops arrive out-of-order).
- Trigram indexes (`pg_trgm`) on `nickname`, `notes` for server-side search in the hosted tier.
- `photos` table in server tracks MinIO object existence + ref-count across plants.

---

## Sync API contract (OpenAPI sketch)

Base: `/api/v1`. All requests auth via `Authorization: Bearer <app_jwt>` (not Pltio JWT — those are separate). Tenant inferred from JWT claims.

```yaml
# Auth
POST /auth/register              { email, password }                      -> { app_jwt, tenant_id, refresh_token }
POST /auth/login                 { email, password }                      -> { app_jwt, tenant_id, refresh_token }
POST /auth/refresh               { refresh_token }                        -> { app_jwt, refresh_token }
POST /auth/logout                                                          -> 204

# Sync
POST /sync/push
  body: { device_id, ops: [ { entity, entity_id, field, value, hlc } ], last_seen_server_hlc }
  -> { accepted: N, rejected: [ {op_index, reason} ], server_hlc, fresh_ops: [...] }

GET  /sync/pull?since_hlc=...&device_id=...&limit=500
  -> { ops: [...], server_hlc, has_more }

GET  /sync/stream    (Server-Sent Events; hosted only, not self-host v1)
  event: op                      data: { ... single op ... }
  event: heartbeat               data: { server_hlc }

# Photos
POST /photos/upload-url          { sha256, bytes, mime }                  -> { url, method, headers, expires_at }
HEAD /photos/{sha256}                                                      -> 200 if exists, 404 otherwise
GET  /photos/{sha256}?variant=thumb|display|original                       -> 302 signed imgproxy URL
DELETE /photos/{sha256}                                                    -> 204 (refcount→0 only)

# Plugin proxy (optional; avoids CORS on web)
POST /plugins/plantly_ro/login   { username, password }                   -> { pltio_jwt, expires_at }
POST /plugins/plantly_ro/post    multipart: draft.json + images[]         -> { pltio_post_id, url }

# Admin + ops (hosted tier)
GET  /health                                                               -> { db, minio, uptime }
GET  /metrics                    (Prometheus, bearer-protected)
GET  /tenant/me                                                            -> { plan, quotas, usage }
```

**Conflict semantics**:
- Field-level LWW by HLC. Tie-break on `(hlc, device_id)` lexicographic.
- OR-Set tables: add/remove carry HLC; final state = present iff any add has `add_hlc > max(remove_hlc for same pair)`.
- Server rejects ops with `hlc` more than 24h ahead of server time (clock-skew protection).

**Rate limits** (per tenant):
- `/sync/push`: 10 req/s, burst 30
- `/sync/pull`: 30 req/s
- `/photos/upload-url`: 5 req/s (plus 500 MB/day free tier)
- `/auth/*`: 5 req/s, `/auth/register` 1 req/min

**Errors**: RFC 7807 problem+json.

---

## Security & threat model

**Assets**: plant photos, care notes, Pltio JWT (grants posting on plantly.ro), app credentials, household membership.

**Threats & mitigations**:
- **Stolen device** → `flutter_secure_storage` (Keychain / Keystore / WebCrypto on web) for Pltio JWT, refresh token, app JWT. On web, keys are non-extractable `CryptoKey` objects.
- **Compromised sync server** (self-host) → client-side **E2E encryption for `notes`, `plugin_exports.response_json`, `weather_snapshots` opt-out**: per-tenant symmetric key derived from user passphrase via Argon2id, kept only on-device; server stores ciphertext. Phase-2 MVP is TLS-only; E2E is Phase 4+ opt-in.
- **Cross-tenant leakage (hosted)** → Postgres RLS enforced at connection level (`SET LOCAL app.current_tenant`); defense-in-depth checks in Go handlers.
- **Replay / stale ops** → server stores `(tenant_id, device_id, hlc)` unique; duplicate pushes are no-ops.
- **Photo exfil via hash-guessing** → MinIO objects require signed imgproxy URLs; `HEAD /photos/{sha}` only confirms existence for the authed tenant.
- **Pltio credential theft** → Pltio JWT never sent to sync server in self-host mode (stored only on device); hosted mode proxies login through server but does NOT store the Pltio JWT server-side (returned to client, discarded from server RAM immediately).
- **Web CSRF** → SameSite=Strict cookies never used; app JWT in Authorization header only.
- **JWT rotation** → app JWT 1h TTL + refresh-token rotation on every refresh; refresh tokens bound to `device_id`.
- **Backup poisoning** → JSON backups signed with HMAC derived from passphrase; import verifies before applying.
- **Abuse (hosted)** → per-tenant rate limits, per-plan photo quotas, email verification, captcha on register.
- **Supply-chain** → Dependabot, `go mod verify`, Flutter `flutter pub audit`, SBOM via `syft`, signed releases (`cosign`).

**Not in threat model (yet)**: malicious plugins (plugin SDK is source-included, compile-time registration), coordinated Sybil abuse on hosted free tier (revisit at scale).

---

## Monetization tiers (hosted SaaS, Phase 5)

| Feature | Self-host | Free | Pro | Household | Nursery |
|---|---|---|---|---|---|
| Plants | ∞ | 25 | ∞ | ∞ | ∞ |
| Devices synced | ∞ | 2 | 5 | 10 | ∞ |
| Photo storage | you host | 500 MB | 20 GB | 50 GB | 500 GB |
| Weather (Open-Meteo) | ✓ | ✓ | ✓ | ✓ | ✓ |
| Premium weather (hourly, pollen, 14-day) | — | — | ✓ | ✓ | ✓ |
| plantly.ro plugin | ✓ | ✓ | ✓ | ✓ | ✓ |
| Premium plugins (OLX, eBay, Shopify) | — | — | ✓ | ✓ | ✓ |
| Household members | — | — | — | 5 | 25 |
| AI plant ID (hosted) | — | 10/mo | 200/mo | 500/mo | 2000/mo |
| PDF reports | ✓ | ✓ | ✓ | ✓ | ✓ |
| Priority support | — | — | email | email | SLA |
| Public plant pages | — | — | ✓ | ✓ | ✓ |
| Price / mo | €0 | €0 | €4 | €9 | €29 |

Stripe products: `plantly_pro`, `plantly_household`, `plantly_nursery` (monthly + annual with 2 months free). Metered billing never — predictable is easier for hobbyists.

Free tier exists to convert, not to last: 25-plant ceiling is intentionally below serious hobbyist scale (~60–100 plants).

---

## UX wireframes (text)

### Plant list (home)

```
┌──────────────────────────────────────────────┐
│ ☰  PlantlyInventory           🔍  🔔³  ⚙    │
├──────────────────────────────────────────────┤
│ ▼ Overdue (3)                                │
│  🌱 Monstera "Bob"       💧 2d overdue    → │
│  🌱 Pothos "Green"       🌿 overdue        → │
│ ▼ Due today (2)                              │
│  🌱 Snake plant          💧 today          → │
│ ▼ All plants (42)        [Grid][List][Map]  │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐                │
│  │img │ │img │ │img │ │img │                │
│  │Bob │ │Ivy │ │Fern│ │Oak │                │
│  └────┘ └────┘ └────┘ └────┘                │
├──────────────────────────────────────────────┤
│  🏠 Plants   📅 Calendar   🔍 Search   👤   │
└──────────────────────────────────────────────┘
           ⊕ FAB: new plant
```

### Plant detail

```
┌──────────────────────────────────────────────┐
│ ←  Monstera "Bob"                        ⋮  │
├──────────────────────────────────────────────┤
│ [ hero photo carousel • • ∘ ∘ ∘ ]           │
│                                              │
│ Monstera deliciosa                           │
│ 📍 Living room › South window                │
│ Acquired 2024-03-12 · from Mom               │
│ Tags: #variegated #climber                   │
│                                              │
│ ── Upcoming care ──                          │
│ 💧 Water in 2 days    [Done] [Snooze]       │
│ 🌿 Fertilize in 18d                         │
│                                              │
│ ── Timeline ──                               │
│ Apr 15  💧 Watered                          │
│ Apr 10  📷 Photo added                      │
│ Apr 08  🌿 Fertilized (NPK 10-10-10, ¼ tsp) │
│ Mar 20  🪴 Repotted → 20cm terracotta       │
│ [ view all 42 events ]                      │
│                                              │
│ ┌──────────────────────────────────────┐    │
│ │  📤  Post on plantly.ro              │    │
│ └──────────────────────────────────────┘    │
└──────────────────────────────────────────────┘
```

### plantly.ro post dialog (plugin)

```
┌──────────────────────────────────────────────┐
│ Post "Monstera Bob" on plantly.ro        ✕  │
├──────────────────────────────────────────────┤
│ Title*       [Monstera deliciosa variegata ]│
│              (30/64)                         │
│ Description  [Mature Monstera, 5 leaves,   ]│
│              [propagated from my mother    ]│
│              [plant in 2024...             ]│
│              (142/2000)                      │
│ Price*       [ 250 ] lei                     │
│ Category*    ▼ Indoor Plants › Monsteras    │
│ County       ▼ Timiș County                 │
│ City         [Timișoara              ]      │
│ Photos*      ☑ hero.jpg   ☑ leaf.jpg        │
│              ☑ whole.jpg  ☐ closeup.jpg     │
│              ☐ pot.jpg    (3/6)             │
│                                              │
│ [ Save draft ]     [ Post now ]              │
└──────────────────────────────────────────────┘
```

### Calendar (week view)

```
┌──────────────────────────────────────────────┐
│ ← Apr 14 – 20                     Week ▼    │
├──────────────────────────────────────────────┤
│ Mon 14 │ 💧 Bob    🌿 Ivy                   │
│ Tue 15 │ 💧 Fern   💧 Oak                   │
│ Wed 16 │ (clear)                             │
│ Thu 17 │ 💧 Bob    🪴 Rose                   │
│ Fri 18 │ TODAY ──  💧 Monty                  │
│ Sat 19 │ 💧 Ivy    🌿 Oak    📷 photo day   │
│ Sun 20 │ 💧 Fern                             │
│                                              │
│ ⛅ Sat forecast: rain — suggest skip water  │
│    [apply suggestion]                        │
└──────────────────────────────────────────────┘
```

---

## CI / release pipeline

**GitHub Actions workflows** (`.github/workflows/`):
- `flutter-ci.yml`: on PR + main push — `flutter analyze` → `flutter test` (unit) → `flutter test integration_test` (chromedriver) → `flutter build web --release` → upload artifact.
- `android-build.yml`: on tag `v*` — `flutter build apk --release --split-per-abi` + `appbundle`; sign with repo secrets; upload to Play Internal track via `r0adkll/upload-google-play`.
- `ios-build.yml`: on tag — `flutter build ipa`; TestFlight via `apple-actions/upload-testflight-build`.
- `server-ci.yml`: `go vet` → `go test ./... -race` → `sqlc vet` → build + `docker buildx` multi-arch (amd64, arm64) → push to `ghcr.io/urundead/plantlyinv-server`.
- `openapi-diff.yml`: on PR — run `oasdiff` between base and head; fail if breaking changes without `!breaking` PR label.
- `sbom-sign.yml`: on tag — generate SBOM (`syft`), sign images (`cosign`), attach to release.
- `dependabot.yml`: weekly updates for pub, go, docker, gh-actions.

**Release channels**: `main` → nightly Docker + web preview; tag `vX.Y.Z-beta` → beta channel (Play internal + TestFlight beta); tag `vX.Y.Z` → stable (Play production, App Store, docker `:latest`, web).

**Versioning**: SemVer. Client and server versioned independently; client announces `X-App-Version` so server can warn on stale clients.

**Changelog**: `release-drafter` auto-generates from PR labels (`feat`, `fix`, `chore`, `breaking`).

---

## Species seed sourcing

**Source**: GBIF (Global Biodiversity Information Facility) for canonical scientific names + taxonomy; Wikipedia/Wikidata for common names in en + ro; OpenFarm for default care templates where available. All three are CC/open licences compatible with AGPL redistribution.

**Curation**:
- `tools/species_seed/fetch.py` pulls top ~500 houseplants + common outdoor/garden species (ranked by Wikipedia pageviews as a proxy for "what users actually own").
- Manual review for care templates (light, water_days, humidity, temp_range) — GBIF/Wikidata don't carry these; a volunteer-maintained YAML overlay at `tools/species_seed/care_overrides.yaml` fills them.
- Output: `assets/species_seed.json` bundled in the app (est. 200–400 KB gzipped); also optionally served from hosted backend for updates.

**Update cadence**: re-run quarterly; diff published as an in-app "species pack update" (<1 MB download).

**Outside-seed species**: user types a scientific name → app creates a `species` row flagged `is_seed=0` with empty care template; suggestions system (Phase 3) proposes defaults based on genus match to seed.

**Licensing**: seed file is CC-BY-SA 4.0 (GBIF + Wikidata compatible). Documented in `LICENSES/species_seed.md`.

---

## Phased roadmap

### Phase 0 — Visual prototype (landed 2026-04-18)
- Clickable HTML/React design prototype under `web/prototype/`, handed off from claude.ai/design (bundle manifest preserved at `web/prototype/DESIGN_BUNDLE_README.md`, chat transcript at `web/prototype/DESIGN_CHAT.md`).
- Screens: customizable widget-based Home (four presets), Plant Detail, Week Calendar, plantly.ro Export dialog. Light + dark themes.
- Dev server: `npm start` serves the prototype at `http://localhost:4173` using `http-server` (no bundler — the design's in-browser Babel pipeline is the handoff contract).
- Test harness: Playwright e2e (`tests/e2e/prototype.spec.ts`) + visual regression (`tests/e2e/visual.spec.ts`) run in CI (`.github/workflows/web-ci.yml`).
- **Purpose:** the prototype is the pixel-perfect reference that the Phase 1 Flutter port must match. See `CLAUDE.md` §"Widget → Flutter mapping" for the file-by-file port plan.
- **Monetization hook:** none — this is a design artifact.

### Phase 1 — Offline MVP (Flutter only, no server)

> Status as of 2026-04-18: **feature-complete** on `main` via PRs #2 → #22.
>
> Every top-line Phase 1 bullet from the roadmap below is ✅. Sub-items that remain open are called out inline.

- ✅ Drift schema (full DDL above) including `sync_ops` + `inventory_transactions`. *(PR #4, #19.)*
- ✅ Plant CRUD *(PR #4 + #5)* with **content-addressed photos** (SHA-256 + sharded on-disk + OR-Set attach/detach + gallery picker UI). *(PR #12.)* ✅ ZIP-with-photos export *(PR #18)*. ✅ Thumbnail + 1600px resize via `flutter_image_compress` *(PR #20)*. OPFS on web still ⏳ (affects web target only).
- ✅ Locations (hierarchical picker). *(PR #7)*
- ✅ Care events (record + undo). *(PR #4 + #11)* Per-plant care schedules wired at runtime — `CareScheduleRepository` + Overdue/Today widgets read real data. *(PR #11.)*
- ✅ **Adaptive schedule algorithm** — EWMA (α=0.3) + snooze-ratio + early-completion + [0.5×, 2× base] clamp. *(PR #5.)* Integrated into the care-event write path. *(PR #11.)*
- ✅ **iCal export** (RFC 5545, UTC-safe against DST). *(PR #9.)*
- ✅ **Local notifications** — `flutter_local_notifications` + `timezone` + Android desugaring + abstract `NotificationService`. *(PR #14.)* ✅ `ReminderEngine` → `NotificationService.syncAll` glue on care-event record / snooze. *(PR #16.)*
- ✅ FTS5 search (unicode61 + remove_diacritics). *(PR #6.)*
- ✅ Filter chips — All / Overdue / Due today. *(PR #17.)* ⏳ Status / location / tag variants extend the same `PlantFilter` enum (mechanical).
- ✅ JSON backup export + import (HMAC-SHA256 signature). *(PR #8.)*
- ✅ ZIP-with-photos export + import. *(PR #18.)*
- ✅ Inventory graph (propagations parent↔child) — `inventory_transactions` table + `InventoryTransactionRepository.propagate` + Plant-Detail overflow menu UI. *(PR #19 + #22.)*
- ✅ i18n: `en`, `ro` from day 1. *(PR #13 + #21.)* ⏳ A few remaining English strings on Plant Detail / Calendar / Export Dialog externalise per-surface.
- Riverpod state + `go_router`.
- i18n: `en`, `ro` from day 1.
- **Monetization hook**: none — this phase builds trust.

### Phase 2 — Sync server + plantly.ro plugin
- Go sync server (chi + sqlc + pgx + Postgres) + MinIO + imgproxy + Caddy; all in docker-compose.
- OpenAPI spec → generated Dart client (`retrofit` + `openapi-generator` for types).
- Op-log push/pull; photo upload by SHA-256 (HEAD probe → skip if exists, else signed PUT to MinIO).
- `ExportPlugin` abstract + compile-time registry.
- `plantly_ro` plugin: login → JWT → categories → post dialog → multipart submit → status sync.
- Web push via self-hosted `ntfy` (topic per device).
- **Monetization hook**: self-hosters run their own; hosted sync tier becomes viable.

### Phase 3 — Weather + history + reports
- Open-Meteo client; per-location daily cache; stale-after-6h banner.
- Care suggestions from forecast ("rain tomorrow → skip outdoor watering"); frost alerts.
- Per-plant history timeline; Markdown export; PDF via `printing` package.
- Dashboard widgets (overdue, upcoming, weather-adjusted suggestions).
- **Monetization hook**: premium weather add-on (hourly, pollen, 14-day) on hosted tier.

### Phase 4 — Household sharing
- Multi-account per `tenant_id`; invite flow (email + one-time code).
- Reminder assignment ("Alex waters the monstera this week").
- Permission tiers (owner/editor/viewer) via Postgres RLS.
- Activity feed across household.
- Opt-in E2E for notes via per-tenant passphrase-derived key.
- **Monetization hook**: Household tier on hosted SaaS.

### Phase 5 — Hosted SaaS
- Multi-tenant registration + tenant-scoped RLS.
- Stripe billing; plan tiers per the matrix above.
- Admin panel (flags, quotas, abuse triage).
- Optional identity bridge with plantly.ro accounts.
- Image CDN via imgproxy + CloudFront/Cloudflare.
- Public plant pages (Pro+) — SEO-indexed read-only profiles.

---

## Critical files

```
PlantlyInventory/
├── pubspec.yaml
├── README.md, LICENSE (AGPL-3.0), LICENSES/  (third-party notices)
├── docker-compose.yml                     # full stack: server+pg+minio+imgproxy+ntfy+caddy
├── docker-compose.selfhost.yml            # minimal: server + pg + fs-photos
├── .github/workflows/                     # flutter-ci, android-build, ios-build,
│                                          # server-ci, openapi-diff, sbom-sign
├── assets/
│   ├── species_seed.json
│   └── fonts/…
├── l10n/   (arb files: app_en.arb, app_ro.arb)
├── lib/
│   ├── main.dart
│   ├── data/
│   │   ├── database/app_database.dart     # Drift schema + FTS5 triggers + sync_ops
│   │   ├── database/migrations/           # versioned
│   │   └── repositories/{plant,care,location,export,photo,species}_repository.dart
│   ├── domain/
│   │   ├── models/                        # freezed: plant, species, location, care_event, schedule, transaction
│   │   └── services/
│   │       ├── adaptive_schedule.dart     # algorithm
│   │       └── reminder_engine.dart
│   ├── sync/
│   │   ├── hlc.dart                       # hybrid-logical-clock
│   │   ├── op_log.dart                    # writer + reader + tombstones
│   │   ├── sync_client.dart               # push/pull against Go server
│   │   ├── or_set.dart                    # add/remove semantics for tags + photos
│   │   └── reconciler.dart                # applies remote ops to local rows
│   ├── plugins/
│   │   ├── export_plugin.dart             # abstract contract (see below)
│   │   ├── registry.dart                  # compile-time Map<String, ExportPlugin>
│   │   └── plantly_ro/
│   │       ├── plantly_ro_plugin.dart
│   │       ├── pltio_api_client.dart      # retrofit + openapi generated
│   │       └── post_draft_form.dart
│   ├── features/
│   │   ├── plants/{list,detail,edit}.dart
│   │   ├── locations/hierarchy_editor.dart
│   │   ├── calendar/{week,month,reminders}.dart
│   │   ├── search/fts_search.dart
│   │   ├── history/{timeline,markdown_export,pdf_export}.dart
│   │   ├── weather/open_meteo.dart        # Phase 3
│   │   ├── inventory/propagation_graph.dart
│   │   └── backup/{export,import}.dart
│   ├── notifications/
│   │   ├── local_notifications.dart
│   │   └── web_push.dart                  # SW + ntfy topic
│   ├── l10n/ (generated)
│   └── theme/
├── server/                                # Phase 2
│   ├── cmd/plantlyinv/main.go
│   ├── internal/
│   │   ├── sync/{oplog.go,hlc.go,fanout.go}
│   │   ├── photos/{minio.go,fs.go,signer.go}
│   │   ├── auth/{jwt.go,refresh.go,register.go}
│   │   ├── tenant/{rls.go,middleware.go}
│   │   ├── plugins/plantly_ro/{proxy.go,client.go}
│   │   └── ratelimit/limiter.go
│   ├── openapi.yaml                       # source of truth
│   ├── migrations/                        # goose
│   └── sqlc.yaml + queries/
├── tools/
│   └── species_seed/                      # fetch.py + care_overrides.yaml
└── integration_test/
    ├── sync_end_to_end_test.dart
    └── pltio_plugin_e2e_test.dart         # against local Pltio stack
```

### Reuse from Pltio
- Multipart + image validation pattern: `~/Desktop/Pltio/backend/internal/posts/handler.go:169–318`.
- imgproxy signing: `~/Desktop/Pltio/backend/internal/storage/s3.go:21–59`.
- Romanian counties/cities list: `~/Desktop/Pltio/frontend/lib/locations.ts`.
- i18n key conventions: `~/Desktop/Pltio/frontend/i18n/locales/{en,ro}.json`.

### `ExportPlugin` contract (Dart)

```dart
abstract class ExportPlugin {
  String get id;                                        // 'plantly_ro'
  PluginManifest get manifest;                          // fields, limits, auth_type
  Future<AuthSession> authenticate(BuildContext ctx);
  Future<void> storeCredentials(AuthSession s);         // flutter_secure_storage
  Future<AuthSession?> loadCredentials();
  Future<ExportPreview> buildPreview(Plant p, ExportDraft d);
  Stream<ExportProgress> submit(ExportDraft d);         // emits %, final remote_id + url
  Future<void> updateStatus(String remoteId, String newStatus); // e.g. mark-sold
  Future<void> revoke();
}
```

---

## Flutter web risks (acknowledged, mitigated)

- **IndexedDB quota** evictable → `navigator.storage.persist()` on first launch; warn on denial.
- **Photos on web** → OPFS (File System Access API), not IndexedDB blobs.
- **Custom service worker** (not Flutter default) for background-sync queue.
- **iOS Safari/PWA**: OPFS recent and flaky → treat iOS-web as read-mostly; prioritise native iOS build.
- **`image_picker` web is lossy** → use `file_selector`.
- **Ship JS, not dart2wasm** (still experimental as of 2026-04).

---

## Verification plan

### Phase 0
- `npm install && npm test` — Playwright runs against `web/prototype/`:
  - Functional: widget reorder / add / remove / preset swap persisted to `localStorage`; plant-card → detail navigation; `Save draft` + `Post now` toasts on the export dialog; calendar rain suggestion + Saturday Skip row; light/dark toggle via edit-mode protocol.
  - Visual: committed baselines for Home / Plant Detail / Calendar / Export Dialog under `tests/e2e/visual.spec.ts-snapshots/` (regenerate with `npm run test:update-snapshots`).

### Phase 1
- `flutter test` — unit tests for: Drift schema, HLC ordering, op-log writes, adaptive scheduler (table-driven), OR-Set resolution, FTS search ranking.
- `flutter test integration_test/` on web + Android: create plant → add 3 photos → log watering → set schedule → receive local notification at `next_due`.
- **Visual parity**: golden-file widget tests for the ported screens must be visually compared against the Phase 0 prototype screenshots under `tests/e2e/visual.spec.ts-snapshots/`. If a Flutter screen diverges, either update the baseline (with design justification in the commit message) or fix the port.
- Manual: export JSON → fresh install → import → verify all entities + photos present; corrupt HMAC → import rejected.
- Resource target: 500 plants + 2000 photos on a Pixel 4a (2019) and Raspberry Pi 4 — cold start <3s, search <100ms.

### Phase 2
- `docker compose up` on clean VM → register account → pair phone + web → edit same plant offline on both → online reconcile → no lost edits, deterministic tag merges.
- Against local Pltio stack (`cd ~/Desktop/Pltio && make up`): login via plugin → post a plant → verify listing at `localhost/posts/{id}` → mark sold from companion → verify Pltio `status='sold'`.
- Load: 10k op-log entries → `/sync/pull` delta under 500ms; 100 concurrent tenants with RLS → no cross-tenant reads.
- Security: `flutter_secure_storage` encrypts Pltio JWT (inspect Keychain/Keystore); RLS blocks `SET LOCAL app.current_tenant` spoof with mismatched JWT claim.

### Phase 3
- Offline → online transition: disable network 24h → weather cache stale banner → reconnect → fresh fetch.
- PDF export: 2-year-old plant with 50 events → file < 10MB, photos embedded.

### Phase 4
- Two accounts in one tenant → invite → assignment round-trip → RLS denies cross-tenant access on spoofed `tenant_id` header.
- E2E encryption: note written on device A with passphrase → device B without passphrase sees ciphertext placeholder; with passphrase → plaintext.

### Phase 5
- Stripe test mode: signup → free tier → upgrade → quotas lift → downgrade → quotas enforced; tenant deletion purges MinIO objects by ref-count.
- Public plant page: Pro user flips toggle → page indexable via `/p/{slug}`; non-Pro toggle hidden.

---

## Licensing

- **AGPL-3.0** for app + server core. Prevents closed-source hosted forks, keeps self-hosting frictionless.
- **MIT** for `lib/plugins/export_plugin.dart` + generated Dart API client + `tools/species_seed/*` tooling. Lowers the barrier for 3rd-party plugin authors.
- Species seed JSON: **CC-BY-SA 4.0** (GBIF + Wikidata compatible).
- Contributor CLA: not required; DCO (`Signed-off-by`) enforced in CI.
