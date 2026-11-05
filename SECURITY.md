# Security policy

## Supported versions

Only the latest release on Google Play and the current `main` / `development` branches
receive security fixes. Older APKs are not patched; please update.

## Reporting a vulnerability

**Please do not open a public issue for security problems.**

Report privately by email to **support@plantly.ro** with the subject line
`[SECURITY] Plantly Inventory` (a dedicated `security@plantly.ro` alias is planned; until
it exists, `support@` is read by the same maintainers). You can also use GitHub's
private vulnerability reporting on this repository if it is enabled
(*Security → Report a vulnerability*).

Include what you can of:

- the affected surface (Android app, web app at inventory.plantly.ro, release tooling
  under `tool/`, a dependency),
- app version (Me → About) or commit hash,
- steps to reproduce or a proof of concept,
- the impact you believe it has (data exposure, account takeover, code execution …).

Reports in English or Romanian are both fine.

## What to expect

- Acknowledgement within **3 working days**.
- An initial assessment and a fix plan within **10 working days** for confirmed issues.
- We will keep you informed and credit you in the release notes if you wish (or keep you
  anonymous if you prefer).
- Please give us a reasonable time to ship a fix before disclosing publicly — Play Store
  rollouts take a few days to reach all users. 90 days from the report is our default
  disclosure window; we are happy to coordinate a different date.

There is no paid bug bounty programme at this time.

## Scope notes

- **Local data** — the app is offline-first; plant data stays on the device. Issues that
  require physical access to an unlocked device are generally out of scope unless they
  bypass an in-app protection (e.g. backup encryption).
- **Inventory Cloud / plantly.ro API** — the backend is not in this repository, but
  vulnerabilities in how this client talks to it (token handling, deep-link / OAuth
  callback parsing, sync conflict handling) are in scope. Server-side findings are also
  welcome at the same address; they are handled by the same team.
- **Dependencies** — if the issue is in a third-party package, please report it upstream
  too; we will pin or patch on our side.
- **Signing material / release pipeline** — the upload keystore and Play service-account
  credentials are never in the repository. If you believe you found such material, tell
  us immediately.
