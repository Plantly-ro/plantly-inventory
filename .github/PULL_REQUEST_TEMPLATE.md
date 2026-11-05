<!-- English or Romanian, as you prefer. / Română sau engleză, cum preferi. -->

## What

<!-- One paragraph: what changes and why. Link the issue: "Closes #123". -->

## How to verify

<!-- Steps a reviewer can follow. Which platform(s) did you test on? -->

- [ ] `flutter analyze --no-fatal-infos` is clean
- [ ] `flutter test` passes (goldens updated with the pinned Flutter version if UI changed, and the PNG diff is in this PR)
- [ ] New user-visible strings are in **both** `app_en.arb` and `app_ro.arb` and `lib/l10n/generated/` was regenerated
- [ ] Drift schema change → `*.g.dart` regenerated and a migration added
- [ ] Works offline / without a plantly.ro account (or the PR says why not)

## Screenshots

<!-- Before / after for UI changes; phone + one larger layout if the shell is affected. -->

## Notes for the reviewer

<!-- Trade-offs, follow-ups, anything you are unsure about. -->

---

By opening this PR I certify the [Developer Certificate of Origin](https://developercertificate.org/) for my contribution (`git commit -s`), licensed under AGPL-3.0-or-later. I understand the Plantly name and logo are trademarks (see TRADEMARKS.md).
