"""Shared Android Publisher API plumbing for the tool/play_*.py scripts.

Kept import-light on purpose: the google client libraries are only imported
inside `build_service()`, so the scripts' pure logic (validation, planning,
request bodies) is unit-testable with a fake service and no pip installs.
"""

SCOPE = "https://www.googleapis.com/auth/androidpublisher"
# A release AAB with bundled TFLite models is ~250 MB. Uploading it as one
# request tripped httplib2's default 60 s socket timeout ("The read operation
# timed out") — so: generous per-request timeout, chunked resumable upload,
# and retries on every call.
HTTP_TIMEOUT_S = 300
CHUNK_SIZE = 16 * 1024 * 1024
RETRIES = 5


def build_service(credentials_path: str):
    """Authenticated `androidpublisher` v3 service with the tuned transport."""
    import google_auth_httplib2
    import httplib2
    from google.oauth2 import service_account
    from googleapiclient.discovery import build

    creds = service_account.Credentials.from_service_account_file(credentials_path, scopes=[SCOPE])
    transport = httplib2.Http(timeout=HTTP_TIMEOUT_S)
    # Resumable uploads answer each chunk with "308 Resume Incomplete"; httplib2 treats 308
    # as a redirect and raises RedirectMissingLocation unless it is excluded (this is what
    # googleapiclient.http.build_http() does for its default transport).
    transport.redirect_codes = transport.redirect_codes - {308}
    http = google_auth_httplib2.AuthorizedHttp(creds, http=transport)
    return build("androidpublisher", "v3", http=http, cache_discovery=False)


def file_media(path: str, mimetype: str, resumable: bool = False):
    """`MediaFileUpload` factory (lazy import so tests can substitute it)."""
    from googleapiclient.http import MediaFileUpload

    if resumable:
        return MediaFileUpload(path, mimetype=mimetype, resumable=True, chunksize=CHUNK_SIZE)
    return MediaFileUpload(path, mimetype=mimetype)


def load_release_notes(metadata_dir, version_code, locale_map, max_chars: int = 500):
    """Build the `releaseNotes` list for a track release from a fastlane metadata dir.

    Per locale dir: `changelogs/<versionCode>.txt`, falling back to
    `changelogs/default.txt`; locales with neither are skipped. Raises
    `ValueError` on a note over Play's 500-char limit.
    """
    import os

    notes = []
    for dir_name in sorted(os.listdir(metadata_dir)):
        locale_dir = os.path.join(metadata_dir, dir_name)
        if not os.path.isdir(locale_dir):
            continue
        language = locale_map.get(dir_name, dir_name)
        candidates = [
            os.path.join(locale_dir, "changelogs", f"{version_code}.txt"),
            os.path.join(locale_dir, "changelogs", "default.txt"),
        ]
        for path in candidates:
            if os.path.isfile(path):
                with open(path, encoding="utf-8") as fh:
                    text = fh.read().strip()
                if len(text) > max_chars:
                    raise ValueError(f"{path}: release notes are {len(text)} chars (max {max_chars})")
                if text:
                    notes.append({"language": language, "text": text})
                break
    return notes
