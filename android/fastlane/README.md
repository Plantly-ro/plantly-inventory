# Play Store listing — Plantly Inventory

Store metadata in the [Fastlane *supply*](https://docs.fastlane.tools/actions/supply/)
layout, understood by `fastlane supply`, Triple-T's *gradle-play-publisher*, the
`r0adkll/upload-google-play` GitHub Action — and by our own `tool/play_listing.py` /
`tool/play_upload.py`, which is what CI runs (AAB + R8 mapping / native symbols +
track; see README "Release"). Locales: `en-US` (default) and `ro`.

```
metadata/android/<locale>/
  title.txt                 # app name (≤30 chars)
  short_description.txt      # ≤80 chars
  full_description.txt       # ≤4000 chars
  changelogs/default.txt     # "what's new" for any versionCode (≤500 chars)
  changelogs/<code>.txt      # optional: overrides default.txt for that versionCode only
  images/
    icon.png                 # 512×512 (hi-res icon)
    featureGraphic.png       # 1024×500
    phoneScreenshots/1..5    # 1080×2160 device captures (Pixel 8 emulator, API 35; status/gesture bars cropped, scaled to Play’s 2:1 limit)
```

## What is automated (GitLab CI)

| Job | Branch | Trigger | Does |
|---|---|---|---|
| `lint-tools` | every branch | automatic | unit-tests the scripts + `play_listing.py --dry-run` (validates every file above) |
| `publish-internal` | `development`, `main` | **manual** | signed AAB (cloud + Play Billing ON, like production since 1.1.0; `versionName 1.1.0-internal.<iid>`) → **internal** track, release notes from `../internal/<locale>/changelogs/` (not this tree); playbook in the top-level README § Internal testing |
| `publish-listing` | `development` | **manual** | pushes texts + graphics to the (app-wide) store listing, no build |
| `publish-production` | `main` | **manual** | listing push (fails fast if invalid) → build (cloud + Play Billing ON) → AAB → **production**, staged rollout to 20 % (`PLAY_ROLLOUT: "0.2"`, `""` = 100 %) with release notes; widen with `tool/play_upload.py --rollout-update` (top-level README § Staged rollout) |

Locally:

```bash
python3 tool/play_listing.py --package ro.plantly.inventory --dry-run           # validate + plan
python3 tool/play_listing.py --package ro.plantly.inventory --credentials sa.json   # push
python3 -m unittest discover -s tool/tests                                       # script tests
```

`versionCode` is the CI pipeline id (`--build-number=$CI_PIPELINE_ID`, one counter for both
tracks; production 1.0.0 = 2882); `versionName` comes from `pubspec.yaml` (the internal job
overrides it via `PLAY_BUILD_NAME`). Signed with the **upload key** (CI variables
`PLAY_UPLOAD_KEYSTORE_B64` / `PLAY_KEYSTORE_PASSWORD` / `PLAY_KEY_PASSWORD`, alias
`upload`, SHA-256 `EC:0A:25:…:DF`); the Play API key is `PLAY_SA_JSON`. Enrol in
**Play App Signing** on first upload.

## Regenerating the graphics

Phone screenshots (`1_home` … `5_me`, en-US + ro) are raw `adb exec-out screencap` captures of the
**release APK** (R8-minified) on a Pixel 8 AVD (1080×2400, Android 15), light theme, status bar in
SystemUI demo mode (09:41, wifi, full battery). No frames or marketing text — Play accepts raw
captures. Capture script + emulator setup notes live on the Mac mini build host at
`~/plantly/README-emulator.md` / `~/plantly/capture.sh` (2026-09-21). Feature graphic + icon still
use the botanical brand gradient (`#3D7A5F`, `--botanical-500`) and the launcher mark.

> The `ro` set shows Romanian only where the UI is localized (calendar, filter chips, reminder /
> import sheets); Home, Me, tab bar and plant detail are hardcoded English literals today.

## Console-only items (NOT covered by these files or CI)

Exact answers live in [`docs/play-console-checklist.md`](../../docs/play-console-checklist.md).
Summary:

- **Privacy policy URL** — `https://plantly.ro/app/inventory/privacy`, serving
  [`docs/privacy-policy.en.md`](../../docs/privacy-policy.en.md) / [`.ro.md`](../../docs/privacy-policy.ro.md).
- **Data safety** — declare opt-in *Crash logs* + *App interactions* (optional, not shared);
  everything else "not collected".
- **Content rating** — IARC questionnaire, all "No" → Everyone / PEGI 3.
- **Target audience** — 18+, not appealing to children. **App access** — no restrictions.
- **Ads** — none. **Advertising ID** — not used.
- **Category** Lifestyle · **Contact** `admin@plantly.ro` · **Pricing** free · countries.
- **Play App Signing** enrolment on the first upload.
