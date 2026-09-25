import os
import struct
import sys
import tempfile
import unittest
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
sys.path.insert(0, HERE)

import play_listing  # noqa: E402
from fakes import FakeService, fake_media  # noqa: E402

REPO_METADATA = os.path.join(os.path.dirname(os.path.dirname(HERE)), "android", "fastlane", "metadata", "android")


def png_bytes(width, height):
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return play_listing.PNG_SIGNATURE + chunk(b"IHDR", ihdr) + chunk(b"IEND", b"")


def write(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    mode = "wb" if isinstance(data, bytes) else "w"
    with open(path, mode, **({} if isinstance(data, bytes) else {"encoding": "utf-8"})) as fh:
        fh.write(data)


def make_locale(root, name, *, title="Plantly Inventory", short="short", full="full", images=True, shots=2, changelog="notes"):
    d = os.path.join(root, name)
    write(os.path.join(d, "title.txt"), title + "\n")
    if changelog is not None:
        write(os.path.join(d, "changelogs", "default.txt"), changelog)
    write(os.path.join(d, "short_description.txt"), short)
    write(os.path.join(d, "full_description.txt"), full)
    if images:
        write(os.path.join(d, "images", "icon.png"), png_bytes(512, 512))
        write(os.path.join(d, "images", "featureGraphic.png"), png_bytes(1024, 500))
        for i in range(shots):
            write(os.path.join(d, "images", "phoneScreenshots", f"{i + 1}_shot.png"), png_bytes(1080, 1920))
    return d


class LoadAndValidateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = self.tmp.name

    def tearDown(self):
        self.tmp.cleanup()

    def test_loads_locales_in_sorted_order_with_language_mapping(self):
        make_locale(self.root, "ro")
        make_locale(self.root, "en-US")
        listings = play_listing.load_metadata(self.root)
        self.assertEqual([l.dir_name for l in listings], ["en-US", "ro"])
        self.assertEqual([l.language for l in listings], ["en-US", "ro"])
        self.assertEqual(listings[0].texts["title"], "Plantly Inventory")
        self.assertEqual([os.path.basename(p) for p in listings[0].images["phoneScreenshots"]], ["1_shot.png", "2_shot.png"])
        self.assertEqual(play_listing.validate(listings), [])

    def test_text_limits(self):
        make_locale(self.root, "en-US", title="x" * 31, short="s" * 81, full="f" * 4001)
        errors = play_listing.validate(play_listing.load_metadata(self.root))
        self.assertEqual(len(errors), 3)
        self.assertTrue(any("title.txt is 31 chars (max 30)" in e for e in errors))
        self.assertTrue(any("short_description.txt is 81 chars (max 80)" in e for e in errors))
        self.assertTrue(any("full_description.txt is 4001 chars (max 4000)" in e for e in errors))

    def test_missing_text_file_is_an_error(self):
        d = make_locale(self.root, "en-US")
        os.remove(os.path.join(d, "short_description.txt"))
        errors = play_listing.validate(play_listing.load_metadata(self.root))
        self.assertEqual(errors, ["[en-US] missing or empty short_description.txt"])

    def test_image_dimension_rules(self):
        d = make_locale(self.root, "en-US", shots=1)
        write(os.path.join(d, "images", "icon.png"), png_bytes(512, 513))
        write(os.path.join(d, "images", "featureGraphic.png"), png_bytes(1024, 501))
        write(os.path.join(d, "images", "phoneScreenshots", "2_tall.png"), png_bytes(1000, 2500))
        errors = play_listing.validate(play_listing.load_metadata(self.root))
        joined = "\n".join(errors)
        self.assertIn("icon is 512x513 (need 512x512)", joined)
        self.assertIn("featureGraphic is 1024x501 (need 1024x500)", joined)
        self.assertIn("2_tall.png is 1000x2500 (long side > 2x short side)", joined)

    def test_screenshot_count_and_bounds(self):
        d = make_locale(self.root, "en-US", shots=1)
        errors = play_listing.validate(play_listing.load_metadata(self.root))
        self.assertIn("[en-US] 1 phone screenshots (need 2-8)", errors)
        write(os.path.join(d, "images", "phoneScreenshots", "2_big.png"), png_bytes(3841, 3841))
        errors = play_listing.validate(play_listing.load_metadata(self.root))
        self.assertTrue(any("2_big.png is 3841x3841 (sides must be 320-3840 px)" in e for e in errors))

    def test_non_png_file_is_reported_not_crashed(self):
        d = make_locale(self.root, "en-US")
        write(os.path.join(d, "images", "icon.png"), b"not a png at all, definitely not")
        errors = play_listing.validate(play_listing.load_metadata(self.root))
        self.assertTrue(any("not a PNG/JPEG file" in e for e in errors))

    def test_skip_images_ignores_image_problems(self):
        d = make_locale(self.root, "en-US", shots=0)
        os.remove(os.path.join(d, "images", "icon.png"))
        listings = play_listing.load_metadata(self.root)
        self.assertNotEqual(play_listing.validate(listings), [])
        self.assertEqual(play_listing.validate(listings, skip_images=True), [])

    def test_locale_without_images_dir_is_text_only(self):
        make_locale(self.root, "ro", images=False)
        listings = play_listing.load_metadata(self.root)
        self.assertEqual(listings[0].images, {})
        self.assertEqual(play_listing.validate(listings), [])

    def test_image_size_reads_jpeg_sof(self):
        # SOI, APP0 (len 16), SOF0 (len 17: precision, height=200, width=100, ...)
        jpeg = b"\xff\xd8" + b"\xff\xe0" + struct.pack(">H", 16) + b"\x00" * 14
        jpeg += b"\xff\xc0" + struct.pack(">H", 17) + b"\x08" + struct.pack(">HH", 200, 100) + b"\x00" * 10
        path = os.path.join(self.root, "a.jpg")
        write(path, jpeg)
        self.assertEqual(play_listing.image_size(path), (100, 200))

    def test_changelog_default_required_and_limit_enforced(self):
        d = make_locale(self.root, "en-US", changelog=None)
        errors = play_listing.validate(play_listing.load_metadata(self.root))
        self.assertEqual(errors, ["[en-US] missing changelogs/default.txt"])
        write(os.path.join(d, "changelogs", "default.txt"), "ok")
        write(os.path.join(d, "changelogs", "4242.txt"), "ș" * 501)  # code points, not bytes
        errors = play_listing.validate(play_listing.load_metadata(self.root))
        self.assertEqual(errors, ["[en-US] changelogs/4242.txt is 501 chars (max 500)"])
        write(os.path.join(d, "changelogs", "4242.txt"), "ș" * 500)
        self.assertEqual(play_listing.validate(play_listing.load_metadata(self.root)), [])

    def test_image_size_skips_jpeg_fill_bytes(self):
        jpeg = b"\xff\xd8" + b"\xff\xff\xff\xe0" + struct.pack(">H", 16) + b"\x00" * 14
        jpeg += b"\xff\xff\xc2" + struct.pack(">H", 17) + b"\x08" + struct.pack(">HH", 300, 150) + b"\x00" * 10
        path = os.path.join(self.root, "fill.jpg")
        write(path, jpeg)
        self.assertEqual(play_listing.image_size(path), (150, 300))

    def test_truncated_headers_raise_validation_error(self):
        png = os.path.join(self.root, "short.png")
        write(png, play_listing.PNG_SIGNATURE + b"\x00\x00\x00\x0dIHDR\x00\x01")
        with self.assertRaises(play_listing.ValidationError):
            play_listing.image_size(png)
        jpg = os.path.join(self.root, "short.jpg")
        write(jpg, b"\xff\xd8\xff\xc0\x00")
        with self.assertRaises(play_listing.ValidationError):
            play_listing.image_size(jpg)

    @unittest.skipUnless(os.path.isdir(REPO_METADATA), "repo metadata not present")
    def test_repo_metadata_is_valid(self):
        listings = play_listing.load_metadata(REPO_METADATA)
        self.assertEqual([l.language for l in listings], ["en-US", "ro"])
        self.assertEqual(play_listing.validate(listings), [])
        self.assertEqual(len(listings[0].images["phoneScreenshots"]), 5)


class PushTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = self.tmp.name
        make_locale(self.root, "en-US", shots=2)
        make_locale(self.root, "ro", shots=3)
        self.listings = play_listing.load_metadata(self.root)

    def tearDown(self):
        self.tmp.cleanup()

    def test_push_updates_listings_replaces_images_and_commits_one_edit(self):
        svc = FakeService()
        play_listing.push(svc, "ro.plantly.inventory", self.listings, media_factory=fake_media)
        names = svc.names()
        self.assertEqual(names[0], "edits.insert")
        self.assertEqual(names[-1], "edits.commit")
        self.assertEqual(names.count("edits.listings.patch"), 2)
        # per locale: 3 deleteall; uploads = 1 icon + 1 feature + shots
        self.assertEqual(names.count("edits.images.deleteall"), 6)
        self.assertEqual(names.count("edits.images.upload"), (2 + 2) + (2 + 3))
        # every call is scoped to the same edit
        edit_ids = {kw["editId"] for n, kw in svc.calls if "editId" in kw}
        self.assertEqual(edit_ids, {"edit-1"})

        update_bodies = svc.kwargs("edits.listings.patch")
        self.assertEqual(update_bodies[0]["language"], "en-US")
        self.assertEqual(
            update_bodies[0]["body"],
            {"language": "en-US", "title": "Plantly Inventory", "shortDescription": "short", "fullDescription": "full"},
        )
        self.assertEqual(update_bodies[1]["language"], "ro")

        # deleteall precedes upload for each image type, and screenshots keep filename order
        ro_uploads = [kw for kw in svc.kwargs("edits.images.upload") if kw["language"] == "ro"]
        self.assertEqual([kw["imageType"] for kw in ro_uploads], ["icon", "featureGraphic"] + ["phoneScreenshots"] * 3)
        shot_paths = [os.path.basename(kw["media_body"]["path"]) for kw in ro_uploads if kw["imageType"] == "phoneScreenshots"]
        self.assertEqual(shot_paths, ["1_shot.png", "2_shot.png", "3_shot.png"])
        self.assertEqual(ro_uploads[0]["media_body"]["mimetype"], "image/png")
        first_delete = names.index("edits.images.deleteall")
        first_upload = names.index("edits.images.upload")
        self.assertLess(first_delete, first_upload)

    def test_skip_images_sends_no_image_calls(self):
        svc = FakeService()
        play_listing.push(svc, "ro.plantly.inventory", self.listings, skip_images=True, media_factory=fake_media)
        self.assertEqual(
            svc.names(), ["edits.insert", "edits.listings.patch", "edits.listings.patch", "edits.commit"]
        )

    def test_failure_mid_images_discards_the_edit_without_commit(self):
        svc = FakeService(results={"edits.images.upload": [None, RuntimeError("upload boom")]})
        with self.assertRaises(RuntimeError):
            play_listing.push(svc, "ro.plantly.inventory", self.listings, media_factory=fake_media)
        names = svc.names()
        self.assertEqual(names.count("edits.images.upload"), 2)
        self.assertEqual(names[-1], "edits.delete")
        self.assertNotIn("edits.commit", names)

    def test_missing_listing_is_created_with_update_after_patch_404(self):
        class NotFound(Exception):
            class resp:
                status = 404

        svc = FakeService(results={"edits.listings.patch": [NotFound("Listing for language 'en-US' not found."), {}]})
        play_listing.push(svc, "ro.plantly.inventory", self.listings, skip_images=True, media_factory=fake_media)
        names = svc.names()
        self.assertEqual(names.count("edits.listings.patch"), 2)
        self.assertEqual(names.count("edits.listings.update"), 1)
        created = svc.kwargs("edits.listings.update")[0]
        self.assertEqual(created["language"], "en-US")
        self.assertEqual(created["body"]["title"], "Plantly Inventory")
        self.assertEqual(names[-1], "edits.commit")

    def test_patch_error_other_than_not_found_still_aborts(self):
        svc = FakeService(results={"edits.listings.patch": RuntimeError("quota exceeded")})
        with self.assertRaises(RuntimeError):
            play_listing.push(svc, "ro.plantly.inventory", self.listings, skip_images=True, media_factory=fake_media)
        self.assertNotIn("edits.listings.update", svc.names())
        self.assertEqual(svc.names()[-1], "edits.delete")

    def test_commit_retries_as_draft_when_play_refuses_auto_review(self):
        refusal = RuntimeError(
            "Changes cannot be sent for review automatically. Please set the query parameter "
            "changesNotSentForReview to true."
        )
        svc = FakeService(results={"edits.commit": [refusal, {"id": "edit-1"}]})
        play_listing.push(svc, "ro.plantly.inventory", self.listings, skip_images=True, media_factory=fake_media)
        commits = svc.kwargs("edits.commit")
        self.assertEqual(len(commits), 2)
        self.assertNotIn("changesNotSentForReview", commits[0])
        self.assertIs(commits[1]["changesNotSentForReview"], True)
        self.assertNotIn("edits.delete", svc.names())

    def test_unrelated_commit_error_is_not_retried(self):
        svc = FakeService(results={"edits.commit": RuntimeError("quota exceeded")})
        with self.assertRaises(RuntimeError):
            play_listing.push(svc, "ro.plantly.inventory", self.listings, skip_images=True, media_factory=fake_media)
        self.assertEqual(svc.names().count("edits.commit"), 1)
        self.assertEqual(svc.names()[-1], "edits.delete")

    def test_flag_commits_as_draft_first_time(self):
        svc = FakeService()
        play_listing.push(
            svc, "ro.plantly.inventory", self.listings, skip_images=True,
            changes_not_sent_for_review=True, media_factory=fake_media,
        )
        commits = svc.kwargs("edits.commit")
        self.assertEqual(len(commits), 1)
        self.assertIs(commits[0]["changesNotSentForReview"], True)

    def test_failure_discards_the_edit_and_reraises(self):
        svc = FakeService(results={"edits.listings.patch": RuntimeError("boom")})
        with self.assertRaises(RuntimeError):
            play_listing.push(svc, "ro.plantly.inventory", self.listings, media_factory=fake_media)
        self.assertEqual(svc.names(), ["edits.insert", "edits.listings.patch", "edits.delete"])
        self.assertNotIn("edits.commit", svc.names())


class MainTests(unittest.TestCase):
    def test_dry_run_needs_no_credentials_and_exits_zero(self):
        def explode(_path):
            raise AssertionError("build_service must not be called in --dry-run")

        original = play_listing.play_api.build_service
        play_listing.play_api.build_service = explode
        try:
            with tempfile.TemporaryDirectory() as root:
                make_locale(root, "en-US")
                rc = play_listing.main(["--package", "p", "--metadata-dir", root, "--dry-run"])
        finally:
            play_listing.play_api.build_service = original
        self.assertEqual(rc, 0)

    def test_flag_is_passed_through_main(self):
        svc = FakeService()
        original = play_listing.play_api.build_service
        play_listing.play_api.build_service = lambda _path: svc
        try:
            with tempfile.TemporaryDirectory() as root:
                make_locale(root, "en-US")
                rc = play_listing.main([
                    "--package", "p", "--metadata-dir", root, "--credentials", "x.json",
                    "--skip-images", "--changes-not-sent-for-review",
                ])
        finally:
            play_listing.play_api.build_service = original
        self.assertEqual(rc, 0)
        self.assertIs(svc.kwargs("edits.commit")[0]["changesNotSentForReview"], True)

    def test_validation_failure_exits_two(self):
        with tempfile.TemporaryDirectory() as root:
            make_locale(root, "en-US", title="x" * 31)
            rc = play_listing.main(["--package", "p", "--metadata-dir", root, "--dry-run"])
        self.assertEqual(rc, 2)

    def test_missing_metadata_dir_exits_two(self):
        rc = play_listing.main(["--package", "p", "--metadata-dir", "/nonexistent/x", "--dry-run"])
        self.assertEqual(rc, 2)

    def test_real_run_without_credentials_exits_two(self):
        with tempfile.TemporaryDirectory() as root:
            make_locale(root, "en-US")
            rc = play_listing.main(["--package", "p", "--metadata-dir", root])
        self.assertEqual(rc, 2)


if __name__ == "__main__":
    unittest.main()
