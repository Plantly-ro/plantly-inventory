# Play Console checklist — Plantly Inventory (`ro.plantly.inventory`)

What CI does **not** do. Everything below is a one-time (or rarely changing) form in
Play Console → *Grow users / Store presence* and *Policy and programs / App content*.
Answers reflect the code as of 1.0.0 (2026-09-21): offline-first, no account, no ads,
Sentry opt-in **and** shipped with an empty DSN, "Sell on plantly.ro" compiled out
(`PLANTLY_SELL_ENABLED=false`).

Automated by CI (do not hand-edit in the console, it gets overwritten):
store listing texts + graphics for `en-US` and `ro` (`publish-listing` / `publish-production`),
AAB upload, R8 mapping + native debug symbols (deobfuscation files for the uploaded
versionCode), release notes, track rollout.

## 1. Store settings

| Field | Answer |
|---|---|
| App category | **Lifestyle** (alternative: House & Home) |
| Tags | Plants, Gardening, Reminders, Organization |
| Contact email | `admin@plantly.ro` |
| Contact website | `https://plantly.ro` |
| Contact phone | optional — leave empty |
| External marketing | your call (opt-out is fine) |
| Default language | English (United States) — `en-US` |
| Pricing | **Free** (irreversible: a free app can never become paid) |
| Countries | Romania first; add EU/worldwide at will (no legal dependency in the app) |

## 2. Privacy policy

| Field | Answer |
|---|---|
| Privacy policy URL | `https://plantly.ro/app/inventory/privacy` (placeholder — must be live and publicly reachable, no login, before submission; serve `docs/privacy-policy.en.md`, with `/ro` or a language switch for `docs/privacy-policy.ro.md`) |

## 3. App access

| Question | Answer |
|---|---|
| Is any part of the app restricted (login, membership, location, …)? | **All functionality is available without special access** |

No account exists. If "Sell on plantly.ro" is enabled in a future build this becomes
"some functionality is restricted" with a test plantly.ro account.

## 4. Ads

| Question | Answer |
|---|---|
| Does your app contain ads? | **No** |

## 5. Content rating (IARC questionnaire)

Category: **Utility, Productivity, Communication, or Other**. All answers **No**:

| Question | Answer |
|---|---|
| Violence / blood / gore | No |
| Sexuality / nudity | No |
| Language (profanity, crude humour) | No |
| Controlled substances (drugs, alcohol, tobacco) | No |
| Gambling / simulated gambling / real-money | No |
| Fear / horror themes | No |
| Users can interact or exchange content with each other | No |
| Shares the user's current location with other users | No |
| Allows purchase of digital goods | No |
| Contains Nazi symbols / discriminatory content | No |
| Miscellaneous (e.g. sharing personal info with third parties) | No |

Expected result: **Everyone / PEGI 3 / USK 0**.

## 6. Target audience and content

| Question | Answer |
|---|---|
| Target age groups | **18 and over** only |
| Could the store listing unintentionally appeal to children? | **No** |

Selecting 18+ keeps the app out of the Designed-for-Families programme and its extra
requirements. The privacy policy says the same ("intended for users aged 18 and over").

## 7. Data safety

The honest baseline is *nothing collected, nothing shared*: no account, no analytics
SDK, Sentry compiled in but opt-in **and** DSN empty in the published build.
Per Play policy, data sent only after an opt-in still counts as "collected", and the
form must be true for the *next* build too — so declare the two opt-in types now rather
than re-filing the form the day a DSN is configured. Recommended answers:

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (HTTPS) |
| Do you provide a way for users to request that their data is deleted? | **Yes** — e-mail `admin@plantly.ro` (no account, so no account-deletion URL is required) |
| Independent security review | No |

Data types:

| Data type | Collected | Shared | Required / optional | Ephemeral | Purposes |
|---|---|---|---|---|---|
| App info and performance → **Crash logs** | Yes | No | **Optional** (user opts in: Me → Privacy & data) | No | App functionality, Analytics |
| App activity → **App interactions** | Yes | No | **Optional** (user opts in) | No | Analytics |

Declare **no** for every other type — in particular Location, Personal info, Photos and
videos (photos never leave the device; they are picked via the system picker and stored
locally), Files and docs (backups are user-initiated exports through the share sheet,
not collection by us), Device or other IDs (Sentry's random installation id is bundled
into the crash-log declaration; do not tick "Device or other IDs" separately).

Not a Data-safety item but disclosed in the policy: first-launch font download from
Google Fonts (IP address to Google). Bundling the two typefaces in `assets/fonts/` and
setting `GoogleFonts.config.allowRuntimeFetching = false` would make the app genuinely
zero-network — recommended follow-up, not a blocker.

Alternative if you prefer the strict-current-build answer: "No data collected" is also
defensible today because nothing can be transmitted with an empty DSN, but the form
**must** be updated before shipping any build with `SENTRY_DSN` set.

## 8. Other App-content declarations

| Declaration | Answer |
|---|---|
| Government app | No |
| Financial features | None |
| Health apps | Not a health app |
| News app | No |
| COVID-19 contact tracing / status | No |
| Advertising ID | **No** — the app does not use the advertising ID (no ads SDK) |
| Foreground service / full-screen intent | Not used (reminders are ordinary `AlarmManager` notifications) |
| Photo and video permissions | Not requested — uses the Android photo picker |

## 9. Release setup (once)

- Enrol in **Play App Signing** on the first AAB upload (the CI key is the *upload* key).
- Testing requirement: personal developer accounts created after 13 Nov 2023 need 12
  testers for 14 days on closed testing before production. URUNDEAD LABS is an
  organisation account, which is exempt — verify in *Dashboard → Set up your app*.
- `publish-production` commits the **listing before the build starts**, so texts and
  graphics go live (or into review) even if the 25-min build later fails. Either re-run the
  job after the fix, or revert the metadata and run `publish-listing` from `development`.
- *App bundle explorer → Downloads* should list a **ReTrace mapping file** (and *Native
  debug symbols*) for every CI-uploaded versionCode — `tool/play_upload.py` attaches them
  in the same edit as the AAB, so the "no deobfuscation file" warnings must not appear.
  If they do, check the job log for `uploaded proguard deobfuscation file` /
  `warning: no native debug symbols found`.
- If Play refuses the automatic review (`changesNotSentForReview`: unpublished app or a
  console change pending review) the scripts retry as a draft commit and say so in the
  job log — then click **Send for review** in the console.
- After the first `publish-production` run, review the release in *Production → Releases*
  and click **Send for review** if the console asks (managed publishing is off by default,
  so an API commit normally goes straight to review).
- `versionCode` = GitLab pipeline id; `versionName` = `pubspec.yaml` (`1.0.0`). Bump
  `pubspec.yaml`'s `version:` for user-visible version changes; `changelogs/<versionCode>.txt`
  for release-specific notes (else `default.txt`).
