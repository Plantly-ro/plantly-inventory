# Play Store listing — Plantly Inventory

Store metadata in the [Fastlane *supply*](https://docs.fastlane.tools/actions/supply/)
layout, understood by `fastlane supply`, Triple-T's *gradle-play-publisher*, and the
`r0adkll/upload-google-play` GitHub Action. Locales: `en-US` (default) and `ro`.

```
metadata/android/<locale>/
  title.txt                 # app name (≤30 chars)
  short_description.txt      # ≤80 chars
  full_description.txt       # ≤4000 chars
  changelogs/18.txt          # "what's new" for versionCode 18 (≤500 chars)
  images/
    icon.png                 # 512×512 (hi-res icon)
    featureGraphic.png       # 1024×500
    phoneScreenshots/1..5    # 2160×3780, framed marketing shots
```

## Building the release artifact

```bash
flutter build appbundle --release   # -> build/app/outputs/bundle/release/app-release.aab
```

Signed with the **upload key** (`android/key.properties` → `~/.secrets/plantly-inventory-upload.jks`,
alias `upload`, SHA-256 `EC:0A:25:…:DF`). Enroll in **Play App Signing** on first upload.
Application ID `ro.plantly.inventory`, versionName `1.0.0`, versionCode `18`.

## Regenerating the graphics

Screenshots are captured from the real Flutter **web** build driven headless, then framed.
Scripts live under the job scratch dir; see the PR description. Feature graphic + slides use
the botanical brand gradient (`#3D7A5F`, `--botanical-500`) and the launcher mark.

> Before final publish, consider replacing the web-derived screenshots with captures from a
> real device (e.g. the Z Fold 7) — pixel-identical by design, but device shots are ideal.

## Manual steps in Play Console (NOT covered by these files)

- **Data safety**: declare *no data collected / no data shared*. The app is offline-only;
  Sentry crash/usage is opt-in AND ships with an empty DSN, so nothing leaves the device by default.
- **Content rating**: complete the IARC questionnaire → expected **Everyone / PEGI 3**.
- **Privacy policy URL**: required. Host the plain-English privacy statement (mirrors the in-app
  *Me → Privacy & data* screen).
- **App category**: Lifestyle (alt: Productivity). Tags: plants, gardening, reminders.
- **Contact email**: a support address.
- **Target audience**: not directed at children.
