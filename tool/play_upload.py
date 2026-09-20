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
        --track internal

Requires: google-api-python-client, google-auth, google-auth-httplib2 (pip-installed in the CI job).
The bundle's versionCode is read from the upload response, so it need not be
passed in. Exits non-zero on any API failure.
"""
import argparse
import sys

import google_auth_httplib2
import httplib2
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

SCOPE = "https://www.googleapis.com/auth/androidpublisher"
# A release AAB with bundled TFLite models is ~250 MB. Uploading it as one
# request tripped httplib2's default 60 s socket timeout ("The read operation
# timed out") — so: generous per-request timeout, chunked resumable upload,
# and retries on every call.
HTTP_TIMEOUT_S = 300
CHUNK_SIZE = 16 * 1024 * 1024
RETRIES = 5


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
    transport = httplib2.Http(timeout=HTTP_TIMEOUT_S)
    # Resumable uploads answer each chunk with "308 Resume Incomplete"; httplib2 treats 308
    # as a redirect and raises RedirectMissingLocation unless it is excluded (this is what
    # googleapiclient.http.build_http() does for its default transport).
    transport.redirect_codes = transport.redirect_codes - {308}
    http = google_auth_httplib2.AuthorizedHttp(creds, http=transport)
    service = build("androidpublisher", "v3", http=http, cache_discovery=False)
    edits = service.edits()

    edit_id = edits.insert(body={}, packageName=args.package).execute(num_retries=RETRIES)["id"]

    media = MediaFileUpload(
        args.aab, mimetype="application/octet-stream", resumable=True, chunksize=CHUNK_SIZE
    )
    bundle = edits.bundles().upload(
        packageName=args.package, editId=edit_id, media_body=media
    ).execute(num_retries=RETRIES)
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
    ).execute(num_retries=RETRIES)

    edits.commit(packageName=args.package, editId=edit_id).execute(num_retries=RETRIES)
    print(f"committed: {args.package} versionCode {version_code} -> {args.track} ({args.status})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
