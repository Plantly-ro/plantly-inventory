# Plantly Inventory — Privacy Policy

**Effective date:** 7 October 2026
**Controller:** URUNDEAD LABS S.R.L., Romania (CUI 54762154) — contact: admin@plantly.ro
*Română: see [privacy-policy.ro.md](privacy-policy.ro.md).*

## The short version

Plantly Inventory is an offline-first plant care app. On Android it works without an account: your plants, photos, notes, reminders and care history are stored **only on your device**, with no advertising and no tracking. Nothing leaves your phone unless you explicitly send it somewhere (a backup, a link you open), you switch on the optional crash and usage reporting (**off by default**), or you turn on **Inventory Cloud**.

**Inventory Cloud** is an optional paid service. When you sign in with your plantly.ro account and have an active plan, your collection is synced to that account so it is backed up and available on your other devices and in the browser. The **web version** (inventory.plantly.ro) is part of Inventory Cloud: it always works with your plantly.ro account and your synced collection.

## What the app stores on your device

- Plants, spaces (rooms), tags, care schedules and care history
- Photos you attach and the notes or captions you write
- Reminder and notification settings, quiet hours, theme and language
- Your two privacy toggles (crash reports, anonymous usage)
- If you use Inventory Cloud: your plantly.ro sign-in session and which collection this device is linked to

All of this lives in the app's private storage (in the web version: this browser's storage for the site). Without Inventory Cloud we cannot see it, and we do not process any of it on a server. Uninstalling the app removes it; in a browser, clearing the site's data does.

## What leaves your device — and when

**Without Inventory Cloud: nothing, by default.** The cases below only happen when you trigger them:

- **Backups and exports** (JSON, ZIP with photos, CSV, iCal). Created on your device and handed to the app you choose through the system share sheet or file picker (in the browser: downloaded as a file). Where they go is up to you. JSON and ZIP backups are **not encrypted**: the passphrase you choose only signs the file so that tampering is detected on import — anyone who gets the file can read it, so keep it private.
- **Links you open.** Some screens can open plantly.ro in your browser, which then applies plantly.ro's own [privacy policy](https://plantly.ro/privacy).
- **Plant data arriving by link.** The app can receive plant details through a `plantlyinventory://import` or `plantly.ro/app/inventory/import` link, for example from Plantly Assistant or plantly.ro. The data travels inside the link and is processed only on your device; nothing is sent back.

**Notifications** are scheduled locally by the operating system. There is no push server. The web version does not show system notifications; reminders appear in the app and the calendar.

## Inventory Cloud (optional)

Inventory Cloud only starts when you sign in with a plantly.ro account (with your plantly.ro credentials, Google or another sign-in offered on plantly.ro) and your account has an active Inventory Cloud plan (also included in Plantly Pro). Your plantly.ro account itself is covered by the [plantly.ro privacy policy](https://plantly.ro/privacy).

**What is synced.** While sync is on, the app sends to your plantly.ro account the changes you make to your collection: plants, spaces, tags, care schedules, care events, inventory entries, notes, and the photos attached to them. Each change carries the plantly.ro user who made it and a technical device identifier. Photos are stored in a **private** storage bucket (Cloudflare R2, operated for plantly.ro) and are only reachable through short-lived links issued to members of the collection — they are never public.

**Devices.** So you can see and disconnect them in Me → Cloud → Devices, each synced device reports its name (on a computer, its network name (hostname); on phones, the platform label such as "Android"; in the browser, "Browser"), platform, app version and when it was last seen.

**Shared collections.** If you share a collection, the people you invite (with an invite code or link you create) can see — and, if you give them that role, edit — its plants, photos and history, including which member made each change. You can remove members or delete the collection at any time; members keep the copy already on their devices.

**Subscriptions.** On Android you can subscribe through **Google Play Billing**. Google processes the payment under its own privacy policy; we never see your card details. Google receives only a one-way hashed identifier of your plantly.ro account (so a purchase can be matched to the right account), never your name or e-mail. While you are signed in, the app sends the purchase token and product to plantly.ro to confirm the plan. On plantly.ro, subscriptions are handled by plantly.ro (payments via Stripe) under the plantly.ro privacy policy.

**Notices.** We may notify you in your plantly.ro account (notification bell, and push if you use the plantly.ro app) about your collections — for example when someone joins a collection you share, or before cloud data is removed after a plan lapses. We also e-mail you about that removal if your plantly.ro e-mail settings allow it.

**Retention and deletion.**
- Turning sync off on a device ("Unlink this device") or signing out stops syncing; it does not delete anything, on the device or in your account.
- **Sync history.** The cloud copy of a collection is a history of changes. Deleting a plant or photo in the app removes it from every synced device, but earlier values stay in that history until the whole collection is deleted as described below.
- **Deleting a collection.** When the owner deletes a collection, every member loses access at once, and its cloud data — sync history and photos — is erased automatically by our daily clean-up, normally within about 24 hours.
- **Plan lapses.** If the owner's plan lapses, syncing stops, but the collection can still be downloaded for 30 days. After about 83 days without an active plan the owner is warned in the plantly.ro account (and by e-mail if allowed); the collection's cloud data, including photos, is deleted **no earlier than 90 days** after the lapse and **never without that warning**. Reactivating before then cancels the deletion. Members of a shared collection rely on the owner's plan: when it lapses this way, their access to the cloud copy ends too.
- Data on your devices is never deleted by any of this; members keep the copy already on their devices.
- To have cloud data erased sooner, e-mail admin@plantly.ro.

## Optional crash reports and usage statistics

Under **Me → Privacy & data** there are two switches, both **off** until you turn them on:

- **Crash reports** — if the app crashes, the error message and stack trace are sent so we can fix the bug.
- **Anonymous usage** — a short event name (for example the screen or feature used) with a few category tags, so we know which features matter.

When enabled, reports go to Sentry (Functional Software, Inc.), a crash-reporting service acting as our processor, and are kept for 90 days by default. Each report also carries technical context: app version, device model, OS version, language, time zone and a random installation identifier created by the reporting library, not tied to your name, e-mail or any account. Reports **never** contain plant data, photos, text you typed, contacts or precise location.

The version published on Google Play ships **without a reporting endpoint configured**, so at present nothing is transmitted even with the switches on. If a future update enables reporting, the switches will govern it and this policy will be updated. You can turn either option off at any time; the change is immediate.

## Selling on plantly.ro (not enabled in this release)

An optional "Sell on plantly.ro" feature exists in the code but is **disabled** in this release. If a future update enables it, it will require a plantly.ro account and will publish only the listing you compose and review (title, description, price, category, location, up to six photos) on plantly.ro, under plantly.ro's privacy policy — nothing else from your collection. We will update this policy and the in-app privacy screen first.

## Permissions

- **Notifications** — to show your care reminders.
- **Run at start-up** — to re-schedule reminders after a reboot.
- **Internet** — only for the cases listed above (Inventory Cloud sign-in and sync, Google Play subscriptions, opt-in reports, links you open).
- Photos are picked through the system photo picker or taken with your camera app; the app itself requests no camera permission and does not scan your gallery.

## Children

Plantly Inventory is intended for users aged 18 and over. It does not knowingly collect personal data from anyone, including children.

## Your rights

For data that stays on your device, you exercise access, correction, deletion and portability yourself: export a backup, edit or delete entries, or uninstall the app. For Inventory Cloud data, the same in-app tools apply to your synced collection, and you can also write to admin@plantly.ro to access, export or erase the cloud copy or to close your plantly.ro account. To have optional crash or usage reports deleted, e-mail admin@plantly.ro. You may also complain to your data protection authority (in Romania: ANSPDCP).

## Changes to this policy

Updates are published here with a new effective date; material changes are also mentioned in the app's release notes.

## Contact

URUNDEAD LABS S.R.L. — admin@plantly.ro
