import os
import sys
import tempfile
import unittest

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

    def tearDown(self):
        self.tmp.cleanup()

    def _run(self, *extra):
        svc = FakeService(results={"edits.bundles.upload": {"versionCode": 777}})
        args = play_upload.parse_args(
            ["--package", "ro.plantly.inventory", "--aab", "/tmp/app.aab", "--credentials", "/tmp/sa.json", *extra]
        )
        rc = play_upload.run(svc, args, media_factory=fake_media)
        self.assertEqual(rc, 0)
        return svc

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
            play_upload.run(svc, args, media_factory=fake_media)
        self.assertEqual(svc.names(), ["edits.insert", "edits.bundles.upload", "edits.delete"])

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

    def test_user_fraction_must_be_in_open_interval(self):
        for bad in ("0", "1", "1.5", "-0.1"):
            with self.assertRaises(SystemExit):
                play_upload.parse_args(
                    ["--package", "p", "--aab", "a", "--credentials", "c", "--user-fraction", bad]
                )


if __name__ == "__main__":
    unittest.main()
