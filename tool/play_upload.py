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
`--rollout 0.2` (alias `--user-fraction`) makes the release a staged rollout
(`status: inProgress`, 20 % of users) instead of the default `completed` (100 %).
Raise or finish it later without a rebuild:

    python3 tool/play_upload.py --package ro.plantly.inventory --credentials sa.json \
        --track production --rollout-update 0.5        # widen to 50 %
    python3 tool/play_upload.py ... --track production --rollout-update complete  # 100 %

`--rollout-update` opens an edit, finds the track's single `inProgress` release
(or the one named by `--version-code`), rewrites its `userFraction` / `status`
and commits — no AAB, mapping or release notes involved. Play Console → Production
→ the release's "Manage rollout" does the same by hand.
`--status draft` stages the release without rolling it out. An app that has never
been published ("draft app") only accepts draft releases: if Play rejects the
commit with "Only releases with status draft may be created on draft app", the
script re-stages the same versionCode (and release notes) as `draft`, commits
once more and tells you on stderr — then send it for review from Play Console.

Release builds are R8-minified, so the script also attaches deobfuscation files
to the uploaded versionCode (before the edit is committed) — without them Play
Console warns and crash stacks stay obfuscated:

* `--mapping PATH`         R8 mapping (`deobfuscationFileType=proguard`). Default
                           `auto` = `build/app/outputs/mapping/release/mapping.txt`
                           under the repo root when present, else a warning.
* `--native-symbols PATH`  native debug symbols (`deobfuscationFileType=nativeCode`).
                           A `.zip` is uploaded as-is; a directory of `<abi>/*.so`
                           is zipped first. Default `auto` = AGP's
                           `build/app/outputs/native-debug-symbols/release/native-debug-symbols.zip`
                           (only produced with `ndk { debugSymbolLevel = ... }`),
                           falling back to the merged libs dir
                           `build/app/intermediates/merged_native_libs/release/out/lib`.

`auto` skips with a warning when nothing is found; an explicit path that is
missing/unreadable is fatal (before any edit is opened). `none` disables either.

Requires: google-api-python-client, google-auth, google-auth-httplib2 (pip-installed in the CI job).
The bundle's versionCode is read from the upload response, so it need not be
passed in. Exits non-zero on any API failure.
"""
import argparse
import contextlib
import os
import sys
import tempfile
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import play_api  # noqa: E402

# fastlane locale dir → Play language code (same map as play_listing.py).
LOCALE_MAP = {"en-US": "en-US", "ro": "ro"}

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUTO = "auto"
NONE = "none"
# Where `flutter build appbundle --release` leaves the R8 mapping (minifyEnabled in
# android/app/build.gradle.kts).
DEFAULT_MAPPING = ("build", "app", "outputs", "mapping", "release", "mapping.txt")
# AGP's ready-made symbols zip — only written when the release buildType sets
# `ndk { debugSymbolLevel = "SYMBOL_TABLE" | "FULL" }`.
DEFAULT_NATIVE_SYMBOLS_ZIP = ("build", "app", "outputs", "native-debug-symbols", "release", "native-debug-symbols.zip")
# Fallback: the merged per-ABI .so files that went into the bundle. Play accepts a
# zip of `<abi>/lib*.so` as native symbols (and stops warning), though Flutter's
# libapp.so/libflutter.so are already stripped, so symbolication stays limited.
DEFAULT_NATIVE_LIBS_DIR = ("build", "app", "intermediates", "merged_native_libs", "release", "out", "lib")
NATIVE_SYMBOL_SUFFIXES = (".so", ".so.dbg", ".so.sym")


def resolve_optional_file(value, candidates, label: str, root: str = REPO_ROOT):
    """Turn a `--mapping` / `--native-symbols` value into a path (or None).

    `none` → None. `auto` → the first of `candidates` (tuples relative to `root`)
    that exists, else None with a warning on stderr. Anything else is an explicit
    path that must exist and be readable — a missing/unreadable one raises
    `FileNotFoundError` so CI fails before an edit is opened.
    """
    if value is None or value == NONE:
        return None
    if value == AUTO:
        for parts in candidates:
            path = os.path.join(root, *parts)
            if os.path.exists(path) and os.access(path, os.R_OK):
                return path
        looked = ", ".join(os.path.join(*parts) for parts in candidates)
        print(f"warning: no {label} found (looked for {looked}); skipping its upload", file=sys.stderr)
        return None
    if not os.path.exists(value) or not os.access(value, os.R_OK):
        raise FileNotFoundError(f"{label}: {value} is missing or unreadable")
    return value


@contextlib.contextmanager
def native_symbols_zip(path):
    """Yield a zip path for `--native-symbols`: `path` itself when it is a file,
    otherwise a temporary zip of the `<abi>/lib*.so` files under the directory
    (arcnames relative to it, which is the layout Play expects)."""
    if not os.path.isdir(path):
        yield path
        return
    entries = []
    for dirpath, _dirs, files in os.walk(path):
        for name in sorted(files):
            if name.endswith(NATIVE_SYMBOL_SUFFIXES):
                full = os.path.join(dirpath, name)
                entries.append((full, os.path.relpath(full, path)))
    if not entries:
        raise FileNotFoundError(f"native symbols: no {'/'.join(NATIVE_SYMBOL_SUFFIXES)} files under {path}")
    fd, tmp = tempfile.mkstemp(prefix="native-debug-symbols-", suffix=".zip")
    os.close(fd)
    try:
        with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zf:
            for full, arcname in sorted(entries, key=lambda e: e[1]):
                zf.write(full, arcname)
        yield tmp
    finally:
        with contextlib.suppress(OSError):
            os.remove(tmp)


def upload_deobfuscation_file(edits, package, edit_id, version_code, file_type, path, media_factory):
    """`edits.deobfuscationfiles.upload` for the just-uploaded versionCode.

    Same chunked resumable media as the bundle (see play_api.build_service for
    the 308 handling) — a mapping.txt is a few MB, a symbols zip can be much more.
    """
    media = media_factory(path, "application/octet-stream", resumable=True)
    edits.deobfuscationfiles().upload(
        packageName=package,
        editId=edit_id,
        apkVersionCode=version_code,
        deobfuscationFileType=file_type,
        media_body=media,
    ).execute(num_retries=play_api.RETRIES)
    print(f"uploaded {file_type} deobfuscation file for versionCode={version_code}: {path} ({os.path.getsize(path)} bytes)")


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


# `edits.commit` on an app that has never been published (a "draft app") fails with
# HTTP 400 "Only releases with status draft may be created on draft app." for any
# release status other than `draft`. Matched case-insensitively on both fragments
# so minor rewordings still trigger the fallback.
DRAFT_APP_MARKERS = ("status draft", "draft app")
DRAFT = "draft"


def is_draft_app_refusal(exc: BaseException) -> bool:
    text = str(exc).lower()
    return all(marker in text for marker in DRAFT_APP_MARKERS)


def as_draft(release: dict) -> dict:
    """The same release (versionCodes, releaseNotes) with `status: draft` and no rollout fraction."""
    draft = {key: value for key, value in release.items() if key != "userFraction"}
    draft["status"] = DRAFT
    return draft


def update_track(edits, package, edit_id, track, release) -> None:
    update_track_releases(edits, package, edit_id, track, [release])


def update_track_releases(edits, package, edit_id, track, releases) -> None:
    edits.tracks().update(
        packageName=package,
        editId=edit_id,
        track=track,
        body={"releases": releases},
    ).execute(num_retries=play_api.RETRIES)


COMPLETE = "complete"
IN_PROGRESS = "inProgress"


def apply_rollout_update(releases, target, version_code=None):
    """Return a new `releases` list with the staged release widened to `target`
    (a fraction in (0, 1)) or finished (`target == COMPLETE`).

    The release is the one whose versionCodes contain `version_code`, else the
    track's single `inProgress` release. Raises `ValueError` when there is no
    such release, more than one candidate, or a widen would not widen.
    """
    if version_code is not None:
        candidates = [r for r in releases if str(version_code) in r.get("versionCodes", [])]
        if not candidates:
            raise ValueError(f"no release with versionCode {version_code} on this track")
    else:
        candidates = [r for r in releases if r.get("status") == IN_PROGRESS]
        if not candidates:
            raise ValueError("no inProgress (staged) release on this track; pass --version-code to pick one")
        if len(candidates) > 1:
            codes = ", ".join("/".join(r.get("versionCodes", [])) for r in candidates)
            raise ValueError(f"several inProgress releases ({codes}); pass --version-code")
    current = candidates[0]
    updated = {key: value for key, value in current.items() if key != "userFraction"}
    if target == COMPLETE:
        updated["status"] = "completed"
        # A track holds one completed release; the previous one is superseded
        # the moment this rollout finishes, so drop it from the body.
        releases = [r for r in releases if r is current or r.get("status") != "completed"]
    else:
        if current.get("status") == IN_PROGRESS and current.get("userFraction", 0) >= target:
            raise ValueError(
                f"release is already at {current['userFraction'] * 100:g}%; "
                f"--rollout-update must raise the fraction (or be 'complete')"
            )
        updated["status"] = IN_PROGRESS
        updated["userFraction"] = target
    return [updated if r is current else r for r in releases]


def run_rollout_update(service, args) -> int:
    """`--rollout-update`: change the fraction/status of an existing staged release."""
    edits = service.edits()
    edit_id = edits.insert(body={}, packageName=args.package).execute(num_retries=play_api.RETRIES)["id"]
    try:
        track = edits.tracks().get(packageName=args.package, editId=edit_id, track=args.track).execute(
            num_retries=play_api.RETRIES
        )
        releases = apply_rollout_update(track.get("releases", []), args.rollout_update, args.version_code)
        update_track_releases(edits, args.package, edit_id, args.track, releases)
        play_api.commit_edit(edits, args.package, edit_id, args.changes_not_sent_for_review)
    except Exception:
        play_api.discard_edit(edits, args.package, edit_id)
        raise
    if args.rollout_update == COMPLETE:
        rollout = "completed"
    else:
        rollout = f"{IN_PROGRESS} {args.rollout_update * 100:g}%"
    print(f"committed: {args.package} {args.track} rollout -> {rollout}")
    return 0


def commit_release(edits, package, edit_id, track, release, changes_not_sent_for_review=False) -> dict:
    """Commit the edit; on Play's draft-app refusal re-stage the release as a draft and commit once more.

    Returns the release that was actually committed (the draft one after a fallback).
    Any other failure — including one from the single fallback commit — propagates
    unchanged so the caller discards the edit as usual.
    """
    try:
        play_api.commit_edit(edits, package, edit_id, changes_not_sent_for_review)
        return release
    except Exception as exc:
        if release.get("status") == DRAFT or not is_draft_app_refusal(exc):
            raise
        print(
            "app is unpublished — committing the release as a draft; send it for review in Play Console",
            file=sys.stderr,
        )
        draft = as_draft(release)
        update_track(edits, package, edit_id, track, draft)
        play_api.commit_edit(edits, package, edit_id, changes_not_sent_for_review)
        return draft


def run(service, args, media_factory=play_api.file_media, root: str = REPO_ROOT) -> int:
    # Resolve (and fail on explicit-but-missing files) before any edit exists.
    mapping = resolve_optional_file(args.mapping, [DEFAULT_MAPPING], "R8 mapping", root)
    native = resolve_optional_file(
        args.native_symbols, [DEFAULT_NATIVE_SYMBOLS_ZIP, DEFAULT_NATIVE_LIBS_DIR], "native debug symbols", root
    )

    edits = service.edits()
    edit_id = edits.insert(body={}, packageName=args.package).execute(num_retries=play_api.RETRIES)["id"]
    try:
        media = media_factory(args.aab, "application/octet-stream", resumable=True)
        bundle = edits.bundles().upload(
            packageName=args.package, editId=edit_id, media_body=media
        ).execute(num_retries=play_api.RETRIES)
        version_code = bundle["versionCode"]
        print(f"uploaded AAB versionCode={version_code}")

        if mapping:
            upload_deobfuscation_file(edits, args.package, edit_id, version_code, "proguard", mapping, media_factory)
        if native:
            with native_symbols_zip(native) as symbols_zip:
                upload_deobfuscation_file(
                    edits, args.package, edit_id, version_code, "nativeCode", symbols_zip, media_factory
                )

        release_notes = None
        if args.release_notes_dir:
            release_notes = play_api.load_release_notes(args.release_notes_dir, version_code, LOCALE_MAP)
            print(f"release notes: {', '.join(n['language'] for n in release_notes) or 'none found'}")

        release = build_release(version_code, args.status, args.user_fraction, release_notes)
        update_track(edits, args.package, edit_id, args.track, release)

        release = commit_release(
            edits, args.package, edit_id, args.track, release, args.changes_not_sent_for_review
        )
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


def rollout_target(value: str):
    """`--rollout-update` value: a fraction in (0,1), or `complete` / `1` / `100%` for 100 %."""
    text = value.strip().lower()
    if text in (COMPLETE, "completed", "1", "1.0", "100%"):
        return COMPLETE
    try:
        return user_fraction(text)
    except (ValueError, argparse.ArgumentTypeError):
        raise argparse.ArgumentTypeError("must be a fraction strictly between 0 and 1 (e.g. 0.5) or 'complete'")


def parse_args(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--package", required=True, help="applicationId / Play package name")
    ap.add_argument("--aab", help="path to the signed .aab (required unless --rollout-update)")
    ap.add_argument("--credentials", required=True, help="path to the SA JSON")
    ap.add_argument("--track", default="internal", help="internal|alpha|beta|production")
    ap.add_argument(
        "--status",
        default="completed",
        help="release status: completed (default) | draft (stage only; the only status an unpublished "
        "app accepts — auto-applied if Play refuses the commit for that reason) | halted; "
        "ignored with --user-fraction",
    )
    ap.add_argument(
        "--release-notes-dir",
        help="fastlane metadata dir; attaches <locale>/changelogs/<versionCode>.txt or default.txt",
    )
    ap.add_argument(
        "--rollout",
        "--user-fraction",
        dest="user_fraction",
        type=user_fraction,
        help="staged rollout fraction in (0,1): sets status=inProgress with this userFraction "
        "(omit = completed, 100 %%)",
    )
    ap.add_argument(
        "--rollout-update",
        type=rollout_target,
        metavar="FRACTION|complete",
        help="do NOT upload anything: widen the track's staged (inProgress) release to this fraction, "
        "or 'complete' it (100 %%); pick the release with --version-code if there are several",
    )
    ap.add_argument("--version-code", type=int, help="with --rollout-update: the release to change")
    ap.add_argument(
        "--mapping",
        default=AUTO,
        help=f"R8 mapping.txt to attach (deobfuscationFileType=proguard); "
        f"'{AUTO}' (default) = {os.path.join(*DEFAULT_MAPPING)} if present, '{NONE}' = skip",
    )
    ap.add_argument(
        "--native-symbols",
        default=AUTO,
        help=f"native debug symbols zip, or a dir of <abi>/*.so to zip (deobfuscationFileType=nativeCode); "
        f"'{AUTO}' (default) = {os.path.join(*DEFAULT_NATIVE_SYMBOLS_ZIP)} or "
        f"{os.path.join(*DEFAULT_NATIVE_LIBS_DIR)} if present, '{NONE}' = skip",
    )
    ap.add_argument(
        "--changes-not-sent-for-review",
        action="store_true",
        help="commit as a draft (send for review from Play Console); auto-retried on Play's refusal anyway",
    )
    args = ap.parse_args(argv)
    if args.rollout_update is None and not args.aab:
        ap.error("--aab is required (unless --rollout-update)")
    if args.rollout_update is not None and (args.aab or args.user_fraction is not None):
        ap.error("--rollout-update takes no --aab / --rollout: it only edits the existing release")
    return args


def main(argv=None) -> int:
    args = parse_args(argv)
    service = play_api.build_service(args.credentials)
    if args.rollout_update is not None:
        return run_rollout_update(service, args)
    return run(service, args)


if __name__ == "__main__":
    sys.exit(main())
