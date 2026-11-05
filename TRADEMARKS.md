# Trademark policy

The source code in this repository is licensed under the GNU Affero General Public
License v3.0 or later (see [`LICENSE`](./LICENSE)). **That licence covers the code only.**

## What is a trademark here

The following are trademarks of **URUNDEAD LABS S.R.L.** (Romania) and are *not*
licensed under the AGPL or any other open-source licence:

- the names **Plantly**, **Plantly Inventory**, **Plantly Cloud** / **Inventory Cloud**,
  **Plantly Pro** and **plantly.ro**;
- the Plantly leaf logo, launcher icons (`assets/launcher/`), feature graphic and
  store screenshots (`android/fastlane/metadata/`);
- the application id `ro.plantly.inventory` and the `plantlyinventory://` URL scheme as
  identifiers of the official app;
- the domain names `plantly.ro` and `inventory.plantly.ro`.

These files are kept in the repository so that the official app can be built
reproducibly from source, not to grant permission to reuse them.

## What you may do

- Build and run the app from source for yourself, your household or your organisation,
  including with the Plantly branding, as long as you do not redistribute it.
- Describe your fork or contribution truthfully as "based on Plantly Inventory" or
  "a fork of Plantly Inventory", with a link to this repository.
- Refer to the Plantly name in articles, reviews, tutorials, package descriptions and
  compatibility statements ("works with plantly.ro").

## What you must do if you redistribute a modified version

If you distribute a modified build — on an app store, as an APK/IPA, as a hosted web
app or in any other form — you **must rebrand** it:

1. Use a different app name and a different application id / bundle id
   (`ro.plantly.inventory` must not be reused — it would collide with the official app
   on users' devices and in app stores).
2. Replace the launcher icons, feature graphic, store screenshots and any other
   Plantly artwork.
3. Do not use the `plantlyinventory://` scheme for your own deep links in a way that
   intercepts links intended for the official app.
4. Do not present your build as the official Plantly Inventory app, as endorsed by
   URUNDEAD LABS S.R.L., or as published by plantly.ro.
5. Keep the copyright and licence notices intact (required by the AGPL anyway) and
   add your own.

A rebranded fork may still talk to the plantly.ro API through the documented
integration points (the marketplace export plugin, the import link handler, Inventory
Cloud sync) — the service's Terms of Service apply to that use, not this document.

## Unmodified redistribution

Redistributing *unmodified* official builds (for example mirroring the APK) under the
Plantly name is allowed as long as the build is byte-identical to one published by
URUNDEAD LABS S.R.L., you say where it came from, and you stop on request.

## Questions and permissions

For anything not covered here, or to ask for an explicit permission (for example a
community edition that keeps a reference to Plantly in its name), write to
support@plantly.ro.

This policy may be updated; the version in the `main` branch of the official repository
is the current one.
