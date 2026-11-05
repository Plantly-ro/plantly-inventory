# Contributing to Plantly Inventory

Thanks for helping. Issues and pull requests are welcome in **English or Romanian**
(scrie în română dacă îți e mai la îndemână — răspundem în aceeași limbă).

Before you start, please read [`CODE_OF_CONDUCT.md`](./CODE_OF_CONDUCT.md). Security
issues go through [`SECURITY.md`](./SECURITY.md), not the public tracker.

## Project layout in one minute

- `lib/` — the Flutter app (Riverpod + go_router + Drift). `lib/features/<area>/` holds
  screens, `lib/data/` the database and repositories, `lib/cloud/` + `lib/sync/` the
  Inventory Cloud client, `lib/marketplace/` the plantly.ro API client,
  `lib/plugins/` the export plugin system, `lib/config/` the compile-time flags.
- `test/` — Dart tests (unit, widget, goldens under `test/goldens/`).
- `tool/` — release tooling (Play upload / listing, web asset versioning) + its tests.
- `web/prototype/` + `tests/e2e/` — the original HTML design prototype and its Playwright
  suite (visual reference only; the Flutter app is what ships).
- `android/fastlane/metadata/` — store listing texts, changelogs and screenshots.
- `docs/` — privacy policy and Play Console checklist.
- `CLAUDE.md`, `PLAN.md`, `FEATURES.md`, `TODO.md` — repo map, design plan and
  feature inventory. They are working documents; the README is the public entry point.

## Development setup

| Tool | Version |
|---|---|
| Flutter | **3.44.0** stable (what CI pins — `env.FLUTTER_VERSION` in `.github/workflows/ci.yml`). A newer stable generally works for day-to-day development; goldens may differ on another engine. |
| Dart | bundled with Flutter (`sdk: ^3.11.5` in `pubspec.yaml`) |
| JDK | 17 (Android builds; AGP 8.11) |
| Python | 3.10+ (release tooling tests only, stdlib) |
| Node | 20+ (design prototype + Playwright only) |

```bash
git clone https://github.com/Plantly-ro/plantly-inventory.git
cd plantly-inventory
flutter pub get
flutter run            # or: flutter run -d chrome
```

Generated files are **committed** so a fresh clone builds without codegen:

- Drift schema: `lib/data/database/*.g.dart` — regenerate with
  `dart run build_runner build --delete-conflicting-outputs` after changing tables.
- Localisations: `lib/l10n/generated/` — regenerate with `flutter gen-l10n` after editing
  `lib/l10n/app_en.arb` / `app_ro.arb`. Every new user-visible string needs both
  languages.

Compile-time feature flags (`--dart-define=…`) are documented in the README under
*Marketplace integration flags*. Defaults are cloud OFF, sell OFF, billing OFF; you do not
need any backend to work on the app.

## Running the checks

Everything CI runs you can run locally:

```bash
flutter analyze --no-fatal-infos                 # must be clean (warnings/errors fail CI)
flutter test --reporter=expanded                 # unit + widget + golden tests
python3 -m unittest discover -s tool/tests       # release tooling
python3 tool/play_listing.py --package ro.plantly.inventory --dry-run   # store metadata sanity
flutter build web --release --no-web-resources-cdn                        # web build
flutter build appbundle --release                # Android (unsigned → debug keystore)
```

Golden tests (`test/goldens/`) are rendered on Linux with the pinned Flutter version in
CI. If you change UI that a golden covers, update it with the same version:

```bash
flutter test --update-goldens test/goldens
```

Commit the updated PNGs with the change and say so in the PR. When a golden fails in CI,
the `test` job uploads the diff images (`test/**/failures/`) as a workflow artifact.

Formatting: `dart format` is not yet enforced (the codebase predates a one-time format
pass). Please do not reformat files you are not otherwise changing.

## Branches and pull requests

- `development` is the integration branch and the default target for PRs.
- `main` is the curated release line; it only receives *Promote* merges from
  `development` by the maintainers.
- Work on a branch in your fork (`feature/<topic>`, `fix/<topic>`), open a PR against
  `development`. Keep PRs focused; several small PRs beat one large one.
- CI (`.github/workflows/ci.yml`) runs on every PR and on pushes to `development` /
  `main`: analyze → test + lint-tools → build-web, build-android. All jobs must pass.
- Fill in the PR template. Link the issue you are fixing if there is one.
- Reviews: a maintainer reviews and merges. We squash-merge or merge as appropriate;
  keep commit messages descriptive (`area: what changed`).

### Licensing of contributions (DCO)

By submitting a pull request you certify the
[Developer Certificate of Origin 1.1](https://developercertificate.org/): that you
wrote the change or have the right to submit it under the project licence
(AGPL-3.0-or-later), and that you understand it will be distributed under that licence.
Add a `Signed-off-by: Your Name <email>` trailer to your commits (`git commit -s`) to
make that explicit. No CLA, no copyright assignment.

Remember that the Plantly name and logo are trademarks, not part of the licence — see
[`TRADEMARKS.md`](./TRADEMARKS.md).

## Reporting bugs and proposing features

Use the issue templates (*Bug report*, *Feature request*). For bugs, the app version
(Me → About), platform (Android / web / which browser) and reproduction steps matter
most. Attach a backup export only if it contains no data you mind sharing — or send it
privately to support@plantly.ro and reference the issue.

## Release pipeline (maintainers)

Contributors never need signing material; this section documents how official builds are
produced so the process is transparent.

### Continuous integration — `.github/workflows/ci.yml`

Triggers: `pull_request`, `push` to `development` / `main`, `workflow_dispatch`.

| Job | What | Notes |
|---|---|---|
| `analyze` | `flutter analyze --no-fatal-infos` | |
| `test` | `flutter test --reporter=expanded` | goldens included; failure diffs uploaded as artifact |
| `lint-tools` | Python unit tests + `play_listing.py --dry-run` + release-notes check | stdlib only, no Flutter |
| `build-web` | `flutter build web --release` + `tool/web_version_assets.py` | artifact `web-build` (7 days) |
| `build-android` | `flutter build appbundle --release` **unsigned** (debug keystore fallback) | PRs and manual runs only — pushes to `development`/`main` skip it because the release workflow builds the signed variant |

Flutter is installed with `subosito/flutter-action` pinned to `FLUTTER_VERSION`; bump that
one value (and the GitLab `FLUTTER_IMAGE` while it still exists) to move the toolchain.

### Android release — `.github/workflows/release.yml`

Triggers: `workflow_dispatch` (choose the track) or a pushed tag `v*` (always the
**internal** track; production is only reachable through the manual dispatch). Every run
waits for approval in the **`play-release` GitHub environment**, which must be configured
in the repository settings with *required reviewers* (the maintainers) and, ideally,
*deployment branches* restricted to `main` + `development` + `v*` tags. The job cannot
see the secrets below until a reviewer approves the run.

The workflow: validates inputs → optional store-listing push (`push_listing` — tick it for production releases; the
listing is app-wide) → decodes the keystore → `flutter build appbundle --release` with the Play
feature flags → `tool/play_upload.py` to the chosen track with per-locale release notes →
uploads the AAB + R8 mapping as workflow artifacts → scrubs the keystore and
service-account file from the runner (always, even on failure).

Secrets (environment `play-release`):

| Secret | Content |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 upload.jks` — the Play **upload** keystore |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | key alias inside the keystore (`upload` for the official app) |
| `ANDROID_KEY_PASSWORD` | key password |
| `PLAY_SERVICE_ACCOUNT_JSON` | the full JSON key of the Play Console service account with *Release manager* rights on `ro.plantly.inventory` |

Variables (repository or environment level, `vars.*`):

| Variable | Purpose |
|---|---|
| `PLAY_VERSION_CODE_BASE` | **Required.** `versionCode = PLAY_VERSION_CODE_BASE + github.run_number`. Play requires strictly increasing codes across all tracks; set this above the highest versionCode already on Play (the GitLab pipeline-id era ended above 3000) and never lower it. Re-running a run reuses its `run_number`, so re-run only when the previous attempt did not commit the Play edit. |
| `PLAY_VERSION_CODE_MIN` | Optional sanity floor (default `2882`, production 1.0.0); the job refuses to build below it. |

Dispatch inputs: `track` (`internal` / `production`), `rollout` (`auto` = staged 20 % on
production / 100 % on internal, `full` = 100 %, or a fraction in (0,1)), `build_name` (versionName override;
internal defaults to `<pubspec version>-internal.<run_number>`), `push_listing`,
`dart_defines` (default: cloud + billing ON), `extra_upload_args` (e.g. `--status draft`).

Widening or completing a staged production rollout does not need a build:
`python3 tool/play_upload.py --track production --rollout-update 0.5|complete` with the
service-account JSON, see README § *Staged rollout*.

### iOS — `.github/workflows/ios.yml`

`workflow_dispatch` only; runs `flutter build ios --no-codesign` on a macOS runner to
keep the Xcode project compiling. Code signing and TestFlight upload will be added once
the Apple Developer enrollment and an App Store Connect API key exist.

### Legacy GitLab CI

`.gitlab-ci.yml` is kept while the repository is mirrored from the original GitLab
instance (its `publish-*` jobs use the `PLAY_*` protected variables described in the
file). It will be removed when the GitHub pipeline has shipped a production release.
