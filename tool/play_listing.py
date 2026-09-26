#!/usr/bin/env python3
"""Push the Play store listing from a fastlane `metadata/android/` tree.

One Android Publisher edit: per locale `edits.listings.patch` (title, short
and full description — patch, so a console-set promo video survives), then — unless `--skip-images` — `edits.images.deleteall`
+ `upload` for the icon, feature graphic and phone screenshots (in filename
order), then `edits.commit`.

    python3 tool/play_listing.py \
        --package ro.plantly.inventory \
        --credentials "$PLAY_SA_JSON" \
        --metadata-dir android/fastlane/metadata/android

`--dry-run` validates the tree and prints the plan without touching the API
(no credentials needed) — CI runs it on every push so a bad listing fails
long before the 25-minute AAB build. Validation (Play's limits): title ≤30,
short description ≤80, full description ≤4000 chars; `changelogs/default.txt`
present and every changelog ≤500 chars; icon 512×512 PNG;
feature graphic 1024×500; 2–8 phone screenshots, each 320–3840 px with the
long side at most twice the short side. Exit 2 on validation errors.
"""
import argparse
import os
import struct
import sys
from dataclasses import dataclass, field

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import play_api  # noqa: E402

# fastlane locale dir → Play language code. Unlisted dirs pass through unchanged.
LOCALE_MAP = {"en-US": "en-US", "ro": "ro"}
TEXT_LIMITS = {"title": 30, "shortDescription": 80, "fullDescription": 4000}
TEXT_FILES = {
    "title": "title.txt",
    "shortDescription": "short_description.txt",
    "fullDescription": "full_description.txt",
}
# Play imageType enum values, uploaded in this order.
IMAGE_TYPES = ("icon", "featureGraphic", "phoneScreenshots")
EXACT_SIZES = {"icon": (512, 512), "featureGraphic": (1024, 500)}
SCREENSHOTS_MIN, SCREENSHOTS_MAX = 2, 8
SCREENSHOT_SIDE_MIN, SCREENSHOT_SIDE_MAX = 320, 3840
CHANGELOG_LIMIT = 500
IMAGE_EXTS = (".png", ".jpg", ".jpeg")

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


class ValidationError(Exception):
    pass


@dataclass
class LocaleListing:
    dir_name: str
    language: str
    texts: dict = field(default_factory=dict)  # api field -> text
    images: dict = field(default_factory=dict)  # imageType -> [paths]
    changelogs: dict = field(default_factory=dict)  # file name -> text


def image_size(path: str):
    """(width, height) from the PNG IHDR or JPEG SOF header, without Pillow."""
    try:
        with open(path, "rb") as fh:
            head = fh.read(32)
            if head.startswith(PNG_SIGNATURE):
                if head[12:16] != b"IHDR":
                    raise ValidationError(f"{path}: malformed PNG (no IHDR)")
                return struct.unpack(">II", head[16:24])
            if head[:2] == b"\xff\xd8":
                fh.seek(2)
                while True:
                    byte = fh.read(1)
                    if byte != b"\xff":
                        break
                    # markers may be preceded by any number of 0xFF fill bytes
                    while byte == b"\xff":
                        byte = fh.read(1)
                    if not byte:
                        break
                    marker = byte[0]
                    if marker in (0xC0, 0xC1, 0xC2):
                        fh.read(3)
                        height, width = struct.unpack(">HH", fh.read(4))
                        return width, height
                    if marker == 0xD9:  # EOI
                        break
                    (seg_len,) = struct.unpack(">H", fh.read(2))
                    fh.seek(seg_len - 2, os.SEEK_CUR)
                raise ValidationError(f"{path}: malformed JPEG (no SOF)")
    except struct.error as exc:
        raise ValidationError(f"{path}: truncated image header ({exc})") from exc
    raise ValidationError(f"{path}: not a PNG/JPEG file")


def _read_text(path: str) -> str:
    with open(path, encoding="utf-8") as fh:
        return fh.read().strip()


def load_metadata(metadata_dir: str, locale_map=LOCALE_MAP):
    """Read every locale dir under `metadata_dir` into LocaleListing objects."""
    if not os.path.isdir(metadata_dir):
        raise ValidationError(f"metadata dir not found: {metadata_dir}")
    listings = []
    for dir_name in sorted(os.listdir(metadata_dir)):
        locale_dir = os.path.join(metadata_dir, dir_name)
        if not os.path.isdir(locale_dir):
            continue
        listing = LocaleListing(dir_name=dir_name, language=locale_map.get(dir_name, dir_name))
        for api_field, file_name in TEXT_FILES.items():
            path = os.path.join(locale_dir, file_name)
            if os.path.isfile(path):
                listing.texts[api_field] = _read_text(path)
        images_dir = os.path.join(locale_dir, "images")
        if os.path.isdir(images_dir):
            for image_type in IMAGE_TYPES:
                if image_type == "phoneScreenshots":
                    shots_dir = os.path.join(images_dir, "phoneScreenshots")
                    if os.path.isdir(shots_dir):
                        listing.images[image_type] = [
                            os.path.join(shots_dir, name)
                            for name in sorted(os.listdir(shots_dir))
                            if name.lower().endswith(IMAGE_EXTS)
                        ]
                else:
                    for ext in IMAGE_EXTS:
                        path = os.path.join(images_dir, image_type + ext)
                        if os.path.isfile(path):
                            listing.images[image_type] = [path]
                            break
        changelog_dir = os.path.join(locale_dir, "changelogs")
        if os.path.isdir(changelog_dir):
            for name in sorted(os.listdir(changelog_dir)):
                if name.endswith(".txt"):
                    listing.changelogs[name] = _read_text(os.path.join(changelog_dir, name))
        listings.append(listing)
    if not listings:
        raise ValidationError(f"no locale dirs under {metadata_dir}")
    return listings


def validate(listings, skip_images: bool = False):
    """Return a list of human-readable problems (empty = valid)."""
    errors = []
    for listing in listings:
        tag = f"[{listing.dir_name}]"
        for api_field, limit in TEXT_LIMITS.items():
            text = listing.texts.get(api_field)
            if not text:
                errors.append(f"{tag} missing or empty {TEXT_FILES[api_field]}")
            elif len(text) > limit:
                errors.append(f"{tag} {TEXT_FILES[api_field]} is {len(text)} chars (max {limit})")
        # release notes are attached by play_upload.py after the 25-min build —
        # catch a bad note here instead.
        if "default.txt" not in listing.changelogs:
            errors.append(f"{tag} missing changelogs/default.txt")
        for name, text in listing.changelogs.items():
            if len(text) > CHANGELOG_LIMIT:
                errors.append(f"{tag} changelogs/{name} is {len(text)} chars (max {CHANGELOG_LIMIT})")
        if skip_images or not listing.images:
            continue
        for image_type, expected in EXACT_SIZES.items():
            paths = listing.images.get(image_type)
            if not paths:
                errors.append(f"{tag} missing images/{image_type}.png")
                continue
            try:
                size = image_size(paths[0])
            except ValidationError as exc:
                errors.append(f"{tag} {exc}")
                continue
            if size != expected:
                errors.append(f"{tag} {image_type} is {size[0]}x{size[1]} (need {expected[0]}x{expected[1]})")
        shots = listing.images.get("phoneScreenshots", [])
        if not SCREENSHOTS_MIN <= len(shots) <= SCREENSHOTS_MAX:
            errors.append(
                f"{tag} {len(shots)} phone screenshots (need {SCREENSHOTS_MIN}-{SCREENSHOTS_MAX})"
            )
        for path in shots:
            try:
                w, h = image_size(path)
            except ValidationError as exc:
                errors.append(f"{tag} {exc}")
                continue
            short, long = min(w, h), max(w, h)
            if short < SCREENSHOT_SIDE_MIN or long > SCREENSHOT_SIDE_MAX:
                errors.append(f"{tag} {os.path.basename(path)} is {w}x{h} (sides must be 320-3840 px)")
            elif long > 2 * short:
                errors.append(f"{tag} {os.path.basename(path)} is {w}x{h} (long side > 2x short side)")
    return errors


def describe_plan(package: str, listings, skip_images: bool):
    lines = [f"listing plan for {package}:"]
    for listing in listings:
        lines.append(f"  {listing.dir_name} -> language {listing.language}")
        for api_field in TEXT_LIMITS:
            text = listing.texts.get(api_field, "")
            preview = text.splitlines()[0][:60] if text else ""
            lines.append(f"    {api_field}: {len(text)} chars  \"{preview}\"")
        notes = ", ".join(f"{n} ({len(t)} chars)" for n, t in listing.changelogs.items())
        lines.append(f"    changelogs: {notes or 'none'}")
        if skip_images:
            lines.append("    images: skipped (--skip-images)")
            continue
        if not listing.images:
            lines.append("    images: none in metadata (Play keeps the current ones)")
            continue
        for image_type in IMAGE_TYPES:
            paths = listing.images.get(image_type, [])
            names = ", ".join(os.path.basename(p) for p in paths)
            lines.append(f"    {image_type}: deleteall + upload {len(paths)} ({names})")
    lines.append("  commit edit")
    return "\n".join(lines)


def _is_listing_not_found(exc: Exception) -> bool:
    """`edits.listings.patch` on a language without a listing -> HTTP 404
    "Listing for language 'xx' not found." (googleapiclient HttpError)."""
    status = getattr(getattr(exc, "resp", None), "status", None)
    return status == 404 or "not found" in str(exc).lower()


def push(
    service,
    package: str,
    listings,
    skip_images: bool = False,
    changes_not_sent_for_review: bool = False,
    media_factory=play_api.file_media,
):
    """Apply the listing inside one edit; deletes the edit if anything fails."""
    edits = service.edits()
    edit_id = edits.insert(body={}, packageName=package).execute(num_retries=play_api.RETRIES)["id"]
    try:
        for listing in listings:
            body = {"language": listing.language, **listing.texts}
            # patch, not update: update replaces the whole Listing and would null
            # a promo `video` set in the console. patch 404s for a language that
            # has no listing yet (fresh app record) -> create it with update.
            try:
                edits.listings().patch(
                    packageName=package, editId=edit_id, language=listing.language, body=body
                ).execute(num_retries=play_api.RETRIES)
                print(f"listing updated: {listing.language}")
            except Exception as exc:
                if not _is_listing_not_found(exc):
                    raise
                edits.listings().update(
                    packageName=package, editId=edit_id, language=listing.language, body=body
                ).execute(num_retries=play_api.RETRIES)
                print(f"listing created: {listing.language}")
            if skip_images or not listing.images:
                continue
            for image_type in IMAGE_TYPES:
                paths = listing.images.get(image_type, [])
                if not paths:
                    continue
                edits.images().deleteall(
                    packageName=package, editId=edit_id, language=listing.language, imageType=image_type
                ).execute(num_retries=play_api.RETRIES)
                for path in paths:
                    mimetype = "image/png" if path.lower().endswith(".png") else "image/jpeg"
                    edits.images().upload(
                        packageName=package,
                        editId=edit_id,
                        language=listing.language,
                        imageType=image_type,
                        media_body=media_factory(path, mimetype),
                    ).execute(num_retries=play_api.RETRIES)
                print(f"images replaced: {listing.language}/{image_type} x{len(paths)}")
        play_api.commit_edit(edits, package, edit_id, changes_not_sent_for_review)
    except Exception:
        play_api.discard_edit(edits, package, edit_id)
        raise
    print(f"committed listing for {package} ({', '.join(l.language for l in listings)})")
    return edit_id


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--package", required=True, help="applicationId / Play package name")
    ap.add_argument("--credentials", help="path to the SA JSON (required unless --dry-run)")
    ap.add_argument("--metadata-dir", default="android/fastlane/metadata/android")
    ap.add_argument("--dry-run", action="store_true", help="validate and print the plan; no API calls")
    ap.add_argument("--skip-images", action="store_true", help="texts only; leave images untouched")
    ap.add_argument(
        "--changes-not-sent-for-review",
        action="store_true",
        help="commit as a draft (send for review from Play Console); auto-retried on Play's refusal anyway",
    )
    args = ap.parse_args(argv)

    try:
        listings = load_metadata(args.metadata_dir)
    except ValidationError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    errors = validate(listings, skip_images=args.skip_images)
    if errors:
        print("listing validation failed:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 2
    print(describe_plan(args.package, listings, args.skip_images))
    if args.dry_run:
        print("dry run: no API calls made")
        return 0
    if not args.credentials:
        print("error: --credentials is required without --dry-run", file=sys.stderr)
        return 2
    service = play_api.build_service(args.credentials)
    push(
        service,
        args.package,
        listings,
        skip_images=args.skip_images,
        changes_not_sent_for_review=args.changes_not_sent_for_review,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
