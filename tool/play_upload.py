#!/usr/bin/env python3
"""Upload a signed Android App Bundle to a Google Play track.

Version-robust alternative to a Gradle publisher plugin: talks to the Android
Publisher API directly, so it is unaffected by AGP/Gradle version drift. Meant
to run in CI after `flutter build appbundle --release`, authenticated with a
Play publisher service-account JSON.

    python3 tool/play_upload.py \
        --package ro.plantly.inventory \
        --aab build/app/outputs/bundle/release/app-release.aab \
        --credentials "$PLAY_SA_JSON" \
        --track internal \
        --release-notes-dir android/fastlane/metadata/android

`--release-notes-dir` attaches "what's new" text per locale from
`<locale>/changelogs/<versionCode>.txt`, falling back to `changelogs/default.txt`.
`--user-fraction 0.2` makes the release a staged rollout (`status: inProgress`,
20 % of users) instead of the default `completed` (100 %); finish it later from
Play Console or by re-running with the same versionCode and no fraction.

Requires: google-api-python-client, google-auth, google-auth-httplib2 (pip-installed in the CI job).
The bundle's versionCode is read from the upload response, so it need not be
passed in. Exits non-zero on any API failure.
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import play_api  # noqa: E402

# fastlane locale dir → Play language code (same map as play_listing.py).
LOCALE_MAP = {"en-US": "en-US", "ro": "ro"}


def build_release(version_code, status: str, user_fraction=None, release_notes=None) -> dict:
    """The `releases[0]` body for `edits.tracks.update`."""
    release = {"versionCodes": [str(version_code)]}
    if user_fraction is not None:
        release["status"] = "inProgress"
        release["userFraction"] = user_fraction
    else:
        release["status"] = status
    if release_notes:
        release["releaseNotes"] = release_notes
    return release


def run(service, args, media_factory=play_api.file_media) -> int:
    edits = service.edits()
    edit_id = edits.insert(body={}, packageName=args.package).execute(num_retries=play_api.RETRIES)["id"]
    try:
        media = media_factory(args.aab, "application/octet-stream", resumable=True)
        bundle = edits.bundles().upload(
            packageName=args.package, editId=edit_id, media_body=media
        ).execute(num_retries=play_api.RETRIES)
        version_code = bundle["versionCode"]
        print(f"uploaded AAB versionCode={version_code}")

        release_notes = None
        if args.release_notes_dir:
            release_notes = play_api.load_release_notes(args.release_notes_dir, version_code, LOCALE_MAP)
            print(f"release notes: {', '.join(n['language'] for n in release_notes) or 'none found'}")

        release = build_release(version_code, args.status, args.user_fraction, release_notes)
        edits.tracks().update(
            packageName=args.package,
            editId=edit_id,
            track=args.track,
            body={"releases": [release]},
        ).execute(num_retries=play_api.RETRIES)

        play_api.commit_edit(edits, args.package, edit_id, args.changes_not_sent_for_review)
    except Exception:
        play_api.discard_edit(edits, args.package, edit_id)
        raise
    rollout = f"{release['status']}" + (
        f" {release['userFraction'] * 100:g}%" if "userFraction" in release else ""
    )
    print(f"committed: {args.package} versionCode {version_code} -> {args.track} ({rollout})")
    return 0


def user_fraction(value: str) -> float:
    fraction = float(value)
    if not 0 < fraction < 1:
        raise argparse.ArgumentTypeError("must be strictly between 0 and 1 (e.g. 0.2)")
    return fraction


def parse_args(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--package", required=True, help="applicationId / Play package name")
    ap.add_argument("--aab", required=True, help="path to the signed .aab")
    ap.add_argument("--credentials", required=True, help="path to the SA JSON")
    ap.add_argument("--track", default="internal", help="internal|alpha|beta|production")
    ap.add_argument("--status", default="completed", help="release status (ignored with --user-fraction)")
    ap.add_argument(
        "--release-notes-dir",
        help="fastlane metadata dir; attaches <locale>/changelogs/<versionCode>.txt or default.txt",
    )
    ap.add_argument(
        "--user-fraction",
        type=user_fraction,
        help="staged rollout fraction in (0,1): sets status=inProgress with this userFraction",
    )
    ap.add_argument(
        "--changes-not-sent-for-review",
        action="store_true",
        help="commit as a draft (send for review from Play Console); auto-retried on Play's refusal anyway",
    )
    return ap.parse_args(argv)


def main(argv=None) -> int:
    args = parse_args(argv)
    service = play_api.build_service(args.credentials)
    return run(service, args)


if __name__ == "__main__":
    sys.exit(main())
