import contextlib
import io
import os
import sys
import tempfile
import unittest
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
sys.path.insert(0, HERE)

import play_api  # noqa: E402
import play_upload  # noqa: E402
from fakes import FakeService, fake_media  # noqa: E402


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)


class ReleaseNotesTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = self.tmp.name

    def tearDown(self):
        self.tmp.cleanup()

    def test_version_specific_wins_over_default_and_missing_locales_are_skipped(self):
        write(os.path.join(self.root, "en-US", "changelogs", "default.txt"), "Default EN\n")
        write(os.path.join(self.root, "en-US", "changelogs", "4242.txt"), "Specific EN")
        write(os.path.join(self.root, "ro", "changelogs", "default.txt"), "Implicit RO")
        write(os.path.join(self.root, "de", "title.txt"), "no changelog here")
        notes = play_api.load_release_notes(self.root, 4242, play_upload.LOCALE_MAP)
        self.assertEqual(
            notes, [{"language": "en-US", "text": "Specific EN"}, {"language": "ro", "text": "Implicit RO"}]
        )

    def test_falls_back_to_default(self):
        write(os.path.join(self.root, "en-US", "changelogs", "default.txt"), "Default EN")
        notes = play_api.load_release_notes(self.root, 99, play_upload.LOCALE_MAP)
        self.assertEqual(notes, [{"language": "en-US", "text": "Default EN"}])

    def test_over_limit_raises(self):
        write(os.path.join(self.root, "en-US", "changelogs", "default.txt"), "x" * 501)
        with self.assertRaises(ValueError):
            play_api.load_release_notes(self.root, 1, play_upload.LOCALE_MAP)

    def test_empty_note_is_omitted(self):
        write(os.path.join(self.root, "en-US", "changelogs", "default.txt"), "  \n")
        self.assertEqual(play_api.load_release_notes(self.root, 1, play_upload.LOCALE_MAP), [])


class BuildReleaseTests(unittest.TestCase):
    def test_completed_by_default(self):
        self.assertEqual(
            play_upload.build_release(123, "completed"), {"versionCodes": ["123"], "status": "completed"}
        )

    def test_user_fraction_forces_in_progress(self):
        release = play_upload.build_release(123, "completed", user_fraction=0.2)
        self.assertEqual(release, {"versionCodes": ["123"], "status": "inProgress", "userFraction": 0.2})

    def test_release_notes_attached(self):
        notes = [{"language": "en-US", "text": "hi"}]
        self.assertEqual(play_upload.build_release(5, "draft", release_notes=notes)["releaseNotes"], notes)


class RunTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = self.tmp.name
        write(os.path.join(self.root, "en-US", "changelogs", "default.txt"), "EN notes")
        write(os.path.join(self.root, "ro", "changelogs", "default.txt"), "RO notes")
        # Repo root for --mapping/--native-symbols auto-detection: empty unless a test plants files.
        self.repo = tempfile.TemporaryDirectory()

    def tearDown(self):
        self.tmp.cleanup()
        self.repo.cleanup()

    def _args(self, *extra):
        return play_upload.parse_args(
            ["--package", "ro.plantly.inventory", "--aab", "/tmp/app.aab", "--credentials", "/tmp/sa.json", *extra]
        )

    def _run(self, *extra, results=None):
        svc = FakeService(results={"edits.bundles.upload": {"versionCode": 777}, **(results or {})})
        stderr = io.StringIO()
        with contextlib.redirect_stderr(stderr):
            rc = play_upload.run(svc, self._args(*extra), media_factory=fake_media, root=self.repo.name)
        self.assertEqual(rc, 0)
        svc.stderr = stderr.getvalue()
        return svc

    def _plant(self, parts, data="x"):
        path = os.path.join(self.repo.name, *parts)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        mode = "wb" if isinstance(data, bytes) else "w"
        with open(path, mode) as fh:
            fh.write(data)
        return path

    def test_default_is_completed_internal_without_notes(self):
        svc = self._run()
        self.assertEqual(svc.names(), ["edits.insert", "edits.bundles.upload", "edits.tracks.update", "edits.commit"])
        upload = svc.kwargs("edits.bundles.upload")[0]
        self.assertEqual(upload["media_body"], {"path": "/tmp/app.aab", "mimetype": "application/octet-stream", "resumable": True})
        update = svc.kwargs("edits.tracks.update")[0]
        self.assertEqual(update["track"], "internal")
        self.assertEqual(update["editId"], "edit-1")
        self.assertEqual(update["body"], {"releases": [{"versionCodes": ["777"], "status": "completed"}]})

    def test_release_notes_dir_attaches_notes_for_uploaded_version_code(self):
        write(os.path.join(self.root, "ro", "changelogs", "777.txt"), "RO 777")
        svc = self._run("--track", "production", "--release-notes-dir", self.root)
        update = svc.kwargs("edits.tracks.update")[0]
        self.assertEqual(update["track"], "production")
        self.assertEqual(
            update["body"]["releases"][0]["releaseNotes"],
            [{"language": "en-US", "text": "EN notes"}, {"language": "ro", "text": "RO 777"}],
        )
        self.assertEqual(update["body"]["releases"][0]["status"], "completed")

    def test_user_fraction_makes_staged_rollout(self):
        svc = self._run("--track", "production", "--user-fraction", "0.2")
        release = svc.kwargs("edits.tracks.update")[0]["body"]["releases"][0]
        self.assertEqual(release["status"], "inProgress")
        self.assertEqual(release["userFraction"], 0.2)

    def test_failure_after_insert_discards_the_edit_without_commit(self):
        svc = FakeService(results={"edits.bundles.upload": RuntimeError("upload boom")})
        args = play_upload.parse_args(["--package", "p", "--aab", "a", "--credentials", "c"])
        with self.assertRaises(RuntimeError):
            play_upload.run(svc, args, media_factory=fake_media, root=self.repo.name)
        self.assertEqual(svc.names(), ["edits.insert", "edits.bundles.upload", "edits.delete"])

    # --- deobfuscation files -------------------------------------------------

    def test_auto_without_build_outputs_skips_with_warning(self):
        svc = self._run()
        self.assertNotIn("edits.deobfuscationfiles.upload", svc.names())
        self.assertIn("warning: no R8 mapping found", svc.stderr)
        self.assertIn("warning: no native debug symbols found", svc.stderr)

    def test_auto_detected_mapping_is_uploaded_for_the_bundle_version_before_commit(self):
        mapping = self._plant(play_upload.DEFAULT_MAPPING, "a.b.c -> d:\n")
        svc = self._run()
        self.assertEqual(
            svc.names(),
            ["edits.insert", "edits.bundles.upload", "edits.deobfuscationfiles.upload", "edits.tracks.update", "edits.commit"],
        )
        (up,) = svc.kwargs("edits.deobfuscationfiles.upload")
        self.assertEqual(up["packageName"], "ro.plantly.inventory")
        self.assertEqual(up["editId"], "edit-1")
        self.assertEqual(up["apkVersionCode"], 777)
        self.assertEqual(up["deobfuscationFileType"], "proguard")
        self.assertEqual(up["media_body"], {"path": mapping, "mimetype": "application/octet-stream", "resumable": True})
        self.assertNotIn("no R8 mapping", svc.stderr)

    def test_explicit_mapping_path_is_used_verbatim(self):
        path = os.path.join(self.root, "custom-mapping.txt")
        write(path, "m")
        svc = self._run("--mapping", path)
        (up,) = svc.kwargs("edits.deobfuscationfiles.upload")
        self.assertEqual(up["media_body"]["path"], path)
        self.assertEqual(up["deobfuscationFileType"], "proguard")

    def test_explicit_missing_mapping_is_fatal_before_any_edit_is_opened(self):
        svc = FakeService(results={"edits.bundles.upload": {"versionCode": 1}})
        with self.assertRaises(FileNotFoundError):
            play_upload.run(svc, self._args("--mapping", "/nonexistent/mapping.txt"), media_factory=fake_media, root=self.repo.name)
        self.assertEqual(svc.names(), [])

    def test_mapping_none_skips_even_when_auto_would_find_one(self):
        self._plant(play_upload.DEFAULT_MAPPING)
        svc = self._run("--mapping", "none", "--native-symbols", "none")
        self.assertNotIn("edits.deobfuscationfiles.upload", svc.names())
        self.assertEqual(svc.stderr, "")

    def test_native_symbols_zip_from_agp_is_uploaded_as_is(self):
        symbols = self._plant(play_upload.DEFAULT_NATIVE_SYMBOLS_ZIP, b"PK\x05\x06" + b"\0" * 18)
        # A merged libs dir also present must lose to the ready-made zip.
        self._plant(play_upload.DEFAULT_NATIVE_LIBS_DIR + ("arm64-v8a", "libapp.so"), b"\x7fELF")
        svc = self._run("--mapping", "none")
        (up,) = svc.kwargs("edits.deobfuscationfiles.upload")
        self.assertEqual(up["deobfuscationFileType"], "nativeCode")
        self.assertEqual(up["apkVersionCode"], 777)
        self.assertEqual(up["media_body"]["path"], symbols)

    def test_native_symbols_dir_is_zipped_with_abi_relative_arcnames_and_cleaned_up(self):
        self._plant(play_upload.DEFAULT_NATIVE_LIBS_DIR + ("arm64-v8a", "libapp.so"), b"\x7fELF-app")
        self._plant(play_upload.DEFAULT_NATIVE_LIBS_DIR + ("armeabi-v7a", "libflutter.so"), b"\x7fELF-flutter")
        self._plant(play_upload.DEFAULT_NATIVE_LIBS_DIR + ("arm64-v8a", "README.txt"), "not a lib")
        seen = {}

        def media(path, mimetype, resumable=False):
            if path.endswith(".zip"):  # the temp symbols zip (the AAB path is never opened)
                with zipfile.ZipFile(path) as zf:
                    seen["names"] = zf.namelist()
                    seen["app"] = zf.read("arm64-v8a/libapp.so")
                seen["path"] = path
            return fake_media(path, mimetype, resumable)

        svc = FakeService(results={"edits.bundles.upload": {"versionCode": 9}})
        with contextlib.redirect_stderr(io.StringIO()):
            play_upload.run(svc, self._args("--mapping", "none"), media_factory=media, root=self.repo.name)
        self.assertEqual(seen["names"], ["arm64-v8a/libapp.so", "armeabi-v7a/libflutter.so"])
        self.assertEqual(seen["app"], b"\x7fELF-app")
        self.assertFalse(os.path.exists(seen["path"]), "temp symbols zip must be removed after upload")
        (up,) = svc.kwargs("edits.deobfuscationfiles.upload")
        self.assertEqual(up["deobfuscationFileType"], "nativeCode")
        self.assertEqual(up["media_body"]["path"], seen["path"])
        self.assertEqual(svc.names()[-1], "edits.commit")

    def test_native_symbols_dir_without_libs_fails_and_discards_the_edit(self):
        empty = os.path.join(self.root, "libs")
        os.makedirs(os.path.join(empty, "arm64-v8a"))
        svc = FakeService(results={"edits.bundles.upload": {"versionCode": 9}})
        with self.assertRaises(FileNotFoundError), contextlib.redirect_stderr(io.StringIO()):
            play_upload.run(svc, self._args("--mapping", "none", "--native-symbols", empty), media_factory=fake_media, root=self.repo.name)
        self.assertEqual(svc.names(), ["edits.insert", "edits.bundles.upload", "edits.delete"])

    def test_both_files_upload_in_order_mapping_then_native(self):
        self._plant(play_upload.DEFAULT_MAPPING)
        self._plant(play_upload.DEFAULT_NATIVE_SYMBOLS_ZIP, b"zip")
        svc = self._run()
        types = [kw["deobfuscationFileType"] for kw in svc.kwargs("edits.deobfuscationfiles.upload")]
        self.assertEqual(types, ["proguard", "nativeCode"])
        names = svc.names()
        self.assertLess(names.index("edits.bundles.upload"), names.index("edits.deobfuscationfiles.upload"))
        self.assertLess(names.index("edits.deobfuscationfiles.upload"), names.index("edits.tracks.update"))

    def test_commit_retries_as_draft_when_play_refuses_auto_review(self):
        refusal = RuntimeError("Please set the query parameter changesNotSentForReview to true.")
        svc = FakeService(results={
            "edits.bundles.upload": {"versionCode": 7},
            "edits.commit": [refusal, {"id": "edit-1"}],
        })
        args = play_upload.parse_args(["--package", "p", "--aab", "a", "--credentials", "c"])
        self.assertEqual(play_upload.run(svc, args, media_factory=fake_media), 0)
        commits = svc.kwargs("edits.commit")
        self.assertEqual(len(commits), 2)
        self.assertNotIn("changesNotSentForReview", commits[0])
        self.assertIs(commits[1]["changesNotSentForReview"], True)
        self.assertNotIn("edits.delete", svc.names())

    def test_changes_not_sent_for_review_flag(self):
        svc = self._run("--changes-not-sent-for-review")
        commits = svc.kwargs("edits.commit")
        self.assertEqual(len(commits), 1)
        self.assertIs(commits[0]["changesNotSentForReview"], True)

    def test_parse_args_defaults_to_auto_detection(self):
        args = self._args()
        self.assertEqual(args.mapping, play_upload.AUTO)
        self.assertEqual(args.native_symbols, play_upload.AUTO)

    def test_user_fraction_must_be_in_open_interval(self):
        for bad in ("0", "1", "1.5", "-0.1"):
            with self.assertRaises(SystemExit):
                play_upload.parse_args(
                    ["--package", "p", "--aab", "a", "--credentials", "c", "--user-fraction", bad]
                )


if __name__ == "__main__":
    unittest.main()
