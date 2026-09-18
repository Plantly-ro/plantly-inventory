#!/usr/bin/env python3
"""Upload a signed Android App Bundle to a Google Play track.

Version-robust alternative to a Gradle publisher plugin: talks to the Android
Publisher API directly, so it is unaffected by AGP/Gradle version drift. Meant
to run in CI after `flutter build appbundle --release`, authenticated with a
Play publisher service-account JSON.

    python3 tool/play_upload.py \
        --package ro.plantly.assistant \
        --aab build/app/outputs/bundle/release/app-release.aab \
        --credentials "$PLAY_SA_JSON" \
        --track internal

Requires: google-api-python-client, google-auth (pip-installed in the CI job).
The bundle's versionCode is read from the upload response, so it need not be
passed in. Exits non-zero on any API failure.
"""
import argparse
import sys

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

SCOPE = "https://www.googleapis.com/auth/androidpublisher"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--package", required=True, help="applicationId / Play package name")
    ap.add_argument("--aab", required=True, help="path to the signed .aab")
    ap.add_argument("--credentials", required=True, help="path to the SA JSON")
    ap.add_argument("--track", default="internal", help="internal|alpha|beta|production")
    ap.add_argument("--status", default="completed", help="release status")
    args = ap.parse_args()

    creds = service_account.Credentials.from_service_account_file(
        args.credentials, scopes=[SCOPE]
    )
    service = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)
    edits = service.edits()

    edit_id = edits.insert(body={}, packageName=args.package).execute()["id"]

    media = MediaFileUpload(args.aab, mimetype="application/octet-stream", resumable=True)
    bundle = edits.bundles().upload(
        packageName=args.package, editId=edit_id, media_body=media
    ).execute()
    version_code = bundle["versionCode"]
    print(f"uploaded AAB versionCode={version_code}")

    edits.tracks().update(
        packageName=args.package,
        editId=edit_id,
        track=args.track,
        body={
            "releases": [
                {"versionCodes": [str(version_code)], "status": args.status}
            ]
        },
    ).execute()

    edits.commit(packageName=args.package, editId=edit_id).execute()
    print(f"committed: {args.package} versionCode {version_code} -> {args.track} ({args.status})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
