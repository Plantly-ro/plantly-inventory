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


class RolloutUpdateTests(unittest.TestCase):
    """`--rollout-update`: edit the staged release in place, no upload."""

    STAGED = {"versionCodes": ["3001"], "status": "inProgress", "userFraction": 0.2, "releaseNotes": [{"language": "ro", "text": "n"}]}
    LIVE = {"versionCodes": ["2882"], "status": "completed"}

    def test_widen_keeps_notes_and_other_releases(self):
        out = play_upload.apply_rollout_update([self.LIVE, self.STAGED], 0.5)
        self.assertEqual(out[0], self.LIVE)
        self.assertEqual(out[1], {**self.STAGED, "userFraction": 0.5})
        self.assertEqual(self.STAGED["userFraction"], 0.2, "input must not be mutated")

    def test_complete_drops_user_fraction_and_the_superseded_completed_release(self):
        out = play_upload.apply_rollout_update([self.LIVE, self.STAGED], play_upload.COMPLETE)
        self.assertEqual(out, [{"versionCodes": ["3001"], "status": "completed", "releaseNotes": self.STAGED["releaseNotes"]}])

    def test_no_staged_release_is_an_error(self):
        with self.assertRaises(ValueError):
            play_upload.apply_rollout_update([self.LIVE], 0.5)

    def test_version_code_picks_the_release_explicitly(self):
        other = {"versionCodes": ["3002"], "status": "inProgress", "userFraction": 0.1}
        with self.assertRaises(ValueError):  # ambiguous without --version-code
            play_upload.apply_rollout_update([self.STAGED, other], 0.5)
        out = play_upload.apply_rollout_update([self.STAGED, other], 0.5, version_code=3002)
        self.assertEqual(out[1]["userFraction"], 0.5)
        self.assertEqual(out[0], self.STAGED)
        with self.assertRaises(ValueError):
            play_upload.apply_rollout_update([self.STAGED], 0.5, version_code=9)

    def test_lowering_the_fraction_is_refused(self):
        with self.assertRaises(ValueError):
            play_upload.apply_rollout_update([self.STAGED], 0.1)
        with self.assertRaises(ValueError):
            play_upload.apply_rollout_update([self.STAGED], 0.2)

    def _args(self, *extra):
        return play_upload.parse_args(["--package", "ro.plantly.inventory", "--credentials", "/tmp/sa.json", *extra])

    def test_run_rollout_update_reads_track_updates_it_and_commits(self):
        svc = FakeService(results={"edits.tracks.get": {"track": "production", "releases": [self.LIVE, dict(self.STAGED)]}})
        rc = play_upload.run_rollout_update(svc, self._args("--track", "production", "--rollout-update", "0.5"))
        self.assertEqual(rc, 0)
        self.assertEqual(svc.names(), ["edits.insert", "edits.tracks.get", "edits.tracks.update", "edits.commit"])
        (get,) = svc.kwargs("edits.tracks.get")
        self.assertEqual((get["track"], get["editId"]), ("production", "edit-1"))
        (update,) = svc.kwargs("edits.tracks.update")
        self.assertEqual(update["track"], "production")
        self.assertEqual(update["body"]["releases"][1]["status"], "inProgress")
        self.assertEqual(update["body"]["releases"][1]["userFraction"], 0.5)
        self.assertEqual(update["body"]["releases"][0], self.LIVE)

    def test_run_rollout_update_complete(self):
        svc = FakeService(results={"edits.tracks.get": {"releases": [self.LIVE, dict(self.STAGED)]}})
        play_upload.run_rollout_update(svc, self._args("--track", "production", "--rollout-update", "complete"))
        (update,) = svc.kwargs("edits.tracks.update")
        self.assertEqual(update["body"], {"releases": [{"versionCodes": ["3001"], "status": "completed", "releaseNotes": self.STAGED["releaseNotes"]}]})
        self.assertEqual(svc.names()[-1], "edits.commit")

    def test_run_rollout_update_without_staged_release_discards_the_edit(self):
        svc = FakeService(results={"edits.tracks.get": {"releases": [self.LIVE]}})
        with self.assertRaises(ValueError):
            play_upload.run_rollout_update(svc, self._args("--track", "production", "--rollout-update", "0.5"))
        self.assertEqual(svc.names(), ["edits.insert", "edits.tracks.get", "edits.delete"])

    def test_rollout_update_values(self):
        for text in ("complete", "completed", "1", "1.0", "100%"):
            self.assertEqual(self._args("--rollout-update", text).rollout_update, play_upload.COMPLETE)
        self.assertEqual(self._args("--rollout-update", "0.5").rollout_update, 0.5)
        for bad in ("0", "1.5", "-0.1", "half"):
            with self.assertRaises(SystemExit):
                self._args("--rollout-update", bad)

    def test_rollout_update_is_exclusive_with_upload_flags(self):
        with self.assertRaises(SystemExit):  # --aab required for an upload
            self._args()
        with self.assertRaises(SystemExit):
            self._args("--aab", "a", "--rollout-update", "0.5")
        with self.assertRaises(SystemExit):
            self._args("--rollout", "0.2", "--rollout-update", "0.5")


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

    def test_rollout_flag_is_the_staged_rollout_body_ci_sends_for_production(self):
        # publish-production: PLAY_ROLLOUT="0.2" → `--rollout 0.2`
        svc = self._run("--track", "production", "--release-notes-dir", self.root, "--rollout", "0.2")
        (release,) = svc.kwargs("edits.tracks.update")[0]["body"]["releases"]
        self.assertEqual(release["status"], "inProgress")
        self.assertEqual(release["userFraction"], 0.2)
        self.assertEqual(release["versionCodes"], ["777"])
        self.assertEqual([n["language"] for n in release["releaseNotes"]], ["en-US", "ro"])

    def test_empty_rollout_means_completed(self):
        # PLAY_ROLLOUT="" → the flag is not passed at all → status completed, no userFraction
        svc = self._run("--track", "production", "--release-notes-dir", self.root)
        (release,) = svc.kwargs("edits.tracks.update")[0]["body"]["releases"]
        self.assertEqual(release["status"], "completed")
        self.assertNotIn("userFraction", release)

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

    # --- draft app (never published) -----------------------------------------

    DRAFT_APP_REFUSAL = RuntimeError(
        '<HttpError 400 when requesting .../edits/edit-1:commit returned "Only releases with status '
        'draft may be created on draft app.". Details: "[{\'message\': \'Only releases with status '
        'draft may be created on draft app.\', \'domain\': \'androidpublisher\'}]">'
    )

    def test_draft_app_refusal_restages_release_as_draft_and_commits_once_more(self):
        write(os.path.join(self.root, "ro", "changelogs", "777.txt"), "RO 777")
        svc = self._run(
            "--track", "production", "--user-fraction", "0.2", "--release-notes-dir", self.root,
            results={"edits.commit": [self.DRAFT_APP_REFUSAL, {"id": "edit-1"}]},
        )
        self.assertEqual(
            svc.names(),
            ["edits.insert", "edits.bundles.upload", "edits.tracks.update", "edits.commit", "edits.tracks.update", "edits.commit"],
        )
        first, second = svc.kwargs("edits.tracks.update")
        self.assertEqual(first["body"]["releases"][0]["status"], "inProgress")
        self.assertEqual(second["editId"], "edit-1")
        self.assertEqual(second["track"], "production")
        (release,) = second["body"]["releases"]
        self.assertEqual(release["status"], "draft")
        self.assertNotIn("userFraction", release)
        self.assertEqual(release["versionCodes"], ["777"])
        self.assertEqual(release["releaseNotes"], first["body"]["releases"][0]["releaseNotes"])
        self.assertEqual(len(svc.kwargs("edits.commit")), 2)
        self.assertNotIn("edits.delete", svc.names())
        self.assertIn("app is unpublished — committing the release as a draft", svc.stderr)

    def test_draft_app_refusal_is_matched_case_insensitively(self):
        self.assertTrue(play_upload.is_draft_app_refusal(RuntimeError("ONLY RELEASES WITH STATUS DRAFT MAY BE CREATED ON DRAFT APP")))
        self.assertFalse(play_upload.is_draft_app_refusal(RuntimeError("status draft is fine")))
        self.assertFalse(play_upload.is_draft_app_refusal(RuntimeError("Please set changesNotSentForReview")))

    def test_unrelated_commit_error_does_not_restage_and_discards_the_edit(self):
        svc = FakeService(results={
            "edits.bundles.upload": {"versionCode": 777},
            "edits.commit": RuntimeError("HttpError 500 backend error"),
        })
        with self.assertRaises(RuntimeError), contextlib.redirect_stderr(io.StringIO()):
            play_upload.run(svc, self._args(), media_factory=fake_media, root=self.repo.name)
        self.assertEqual(
            svc.names(), ["edits.insert", "edits.bundles.upload", "edits.tracks.update", "edits.commit", "edits.delete"]
        )

    def test_draft_app_fallback_is_attempted_only_once(self):
        svc = FakeService(results={
            "edits.bundles.upload": {"versionCode": 777},
            "edits.commit": self.DRAFT_APP_REFUSAL,  # keeps failing even after the draft re-stage
        })
        with self.assertRaises(RuntimeError), contextlib.redirect_stderr(io.StringIO()):
            play_upload.run(svc, self._args(), media_factory=fake_media, root=self.repo.name)
        self.assertEqual(svc.names().count("edits.tracks.update"), 2)
        self.assertEqual(svc.names().count("edits.commit"), 2)
        self.assertEqual(svc.names()[-1], "edits.delete")

    def test_explicit_status_draft_commits_first_time_with_one_tracks_update(self):
        svc = self._run("--track", "production", "--status", "draft")
        self.assertEqual(svc.names(), ["edits.insert", "edits.bundles.upload", "edits.tracks.update", "edits.commit"])
        (update,) = svc.kwargs("edits.tracks.update")
        self.assertEqual(update["body"]["releases"][0]["status"], "draft")
        self.assertNotIn("app is unpublished", svc.stderr)

    def test_explicit_status_draft_refused_again_is_not_retried(self):
        svc = FakeService(results={
            "edits.bundles.upload": {"versionCode": 777},
            "edits.commit": self.DRAFT_APP_REFUSAL,
        })
        with self.assertRaises(RuntimeError), contextlib.redirect_stderr(io.StringIO()):
            play_upload.run(svc, self._args("--status", "draft"), media_factory=fake_media, root=self.repo.name)
        self.assertEqual(svc.names(), ["edits.insert", "edits.bundles.upload", "edits.tracks.update", "edits.commit", "edits.delete"])

    def test_parse_args_defaults_to_auto_detection(self):
        args = self._args()
        self.assertEqual(args.mapping, play_upload.AUTO)
        self.assertEqual(args.native_symbols, play_upload.AUTO)

    def test_user_fraction_must_be_in_open_interval(self):
        for flag in ("--user-fraction", "--rollout"):
            for bad in ("0", "1", "1.5", "-0.1"):
                with self.assertRaises(SystemExit):
                    play_upload.parse_args(["--package", "p", "--aab", "a", "--credentials", "c", flag, bad])


if __name__ == "__main__":
    unittest.main()
