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


def make_locale(root, name, *, title="Plantly Inventory", short="short", full="full", images=True, shots=2):
    d = os.path.join(root, name)
    write(os.path.join(d, "title.txt"), title + "\n")
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
        self.assertEqual(names.count("edits.listings.update"), 2)
        # per locale: 3 deleteall; uploads = 1 icon + 1 feature + shots
        self.assertEqual(names.count("edits.images.deleteall"), 6)
        self.assertEqual(names.count("edits.images.upload"), (2 + 2) + (2 + 3))
        # every call is scoped to the same edit
        edit_ids = {kw["editId"] for n, kw in svc.calls if "editId" in kw}
        self.assertEqual(edit_ids, {"edit-1"})

        update_bodies = svc.kwargs("edits.listings.update")
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
            svc.names(), ["edits.insert", "edits.listings.update", "edits.listings.update", "edits.commit"]
        )

    def test_failure_discards_the_edit_and_reraises(self):
        svc = FakeService(results={"edits.listings.update": RuntimeError("boom")})
        with self.assertRaises(RuntimeError):
            play_listing.push(svc, "ro.plantly.inventory", self.listings, media_factory=fake_media)
        self.assertEqual(svc.names(), ["edits.insert", "edits.listings.update", "edits.delete"])
        self.assertNotIn("edits.commit", svc.names())


class MainTests(unittest.TestCase):
    def test_dry_run_needs_no_credentials_and_exits_zero(self):
        with tempfile.TemporaryDirectory() as root:
            make_locale(root, "en-US")
            rc = play_listing.main(["--package", "p", "--metadata-dir", root, "--dry-run"])
        self.assertEqual(rc, 0)

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
