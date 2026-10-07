import hashlib
import os
import re
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import web_version_assets as wva  # noqa: E402

REPO = HERE.parent.parent
WEB = REPO / "web"
RID = "0e51ca9a" + format(3141, "x")  # short sha + hex pipeline id, as CI builds it


def write(path: Path, data: str = "x") -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(data, encoding="utf-8")


def make_fixture(root: Path, index_html: str | None = None, bootstrap: str | None = None) -> Path:
    """A miniature `flutter build web` output, using the repo's real index.html
    (base href substituted like the tool does) and bootstrap template."""
    build = root / "web"
    if index_html is None:
        index_html = (WEB / "index.html").read_text(encoding="utf-8").replace("$FLUTTER_BASE_HREF", "/")
    if bootstrap is None:
        bootstrap = (WEB / "flutter_bootstrap.js").read_text(encoding="utf-8")
    write(build / "index.html", index_html)
    write(build / "flutter_bootstrap.js", bootstrap)
    for rel in ("main.dart.js", "flutter.js", "flutter_service_worker.js", "version.json", "manifest.json",
                "favicon.png", "icons/Icon-192.png", "canvaskit/canvaskit.wasm", "canvaskit/chromium/canvaskit.js",
                "assets/FontManifest.json", "assets/fonts/MaterialIcons-Regular.otf", "assets/NOTICES",
                "vendor/sqlite3-2.9.4/sqlite3.wasm", "vendor/drift-2.31.0/drift_worker.js",
                "prototype/index.html", "prototype/components/shared.jsx"):
        write(build / rel, rel)
    return build


class VersionBuildTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp)

    def test_moves_release_files_and_rewrites_index(self):
        build = make_fixture(self.tmp)
        release = wva.version_build(build, RID)

        self.assertEqual(release, build / "v" / RID)
        self.assertEqual(sorted(p.name for p in build.iterdir()),
                         ["favicon.png", "flutter_service_worker.js", "icons", "index.html", "manifest.json",
                          "v", "vendor", "version.json"])
        for rel in ("main.dart.js", "flutter.js", "flutter_bootstrap.js", "canvaskit/canvaskit.wasm",
                    "canvaskit/chromium/canvaskit.js", "assets/FontManifest.json",
                    "assets/fonts/MaterialIcons-Regular.otf", "assets/NOTICES"):
            self.assertTrue((release / rel).is_file(), rel)
            self.assertFalse((build / rel).exists(), rel)
        # the design prototype is dropped, not shipped
        self.assertFalse((build / "prototype").exists())
        self.assertFalse((release / "prototype").exists())
        # vendor stays shared at the root, untouched
        self.assertEqual((build / "vendor/drift-2.31.0/drift_worker.js").read_text(), "vendor/drift-2.31.0/drift_worker.js")

        index = (build / "index.html").read_text(encoding="utf-8")
        self.assertIn(f'<script src="v/{RID}/flutter_bootstrap.js" async></script>', index)
        self.assertNotIn('src="flutter_bootstrap.js"', index)
        # the rest of the shell is untouched
        self.assertIn('<base href="/">', index)
        self.assertIn('href="manifest.json"', index)

    def test_refuses_second_run(self):
        build = make_fixture(self.tmp)
        wva.version_build(build, RID)
        with self.assertRaisesRegex(wva.VersioningError, "already versioned"):
            wva.version_build(build, RID)

    def test_rejects_bad_release_ids(self):
        build = make_fixture(self.tmp)
        for bad in ("", "main", "../x", "0E51CA9A", "abc", "0e51ca9a/x", "a" * 41):
            with self.assertRaises(wva.VersioningError, msg=bad):
                wva.version_build(build, bad)
        self.assertFalse((build / "v").exists())

    def test_refuses_stock_bootstrap(self):
        build = make_fixture(self.tmp, bootstrap="/* stock */ _flutter.loader.load();")
        with self.assertRaisesRegex(wva.VersioningError, "custom template"):
            wva.version_build(build, RID)
        self.assertTrue((build / "main.dart.js").is_file(), "nothing may move on refusal")

    def test_requires_exactly_one_bootstrap_tag(self):
        for html, n in (("<html><body></body></html>", 0),
                        ('<script src="flutter_bootstrap.js"></script><script src="flutter_bootstrap.js"></script>', 2)):
            root = self.tmp / str(n)
            build = make_fixture(root, index_html=html)
            with self.assertRaisesRegex(wva.VersioningError, f"found {n}"):
                wva.version_build(build, RID)

    def test_dangling_index_reference_fails(self):
        html = ('<html><head><base href="/"><link rel="stylesheet" href="assets/app.css"></head>'
                '<body><script src="flutter_bootstrap.js" async></script></body></html>')
        build = make_fixture(self.tmp, index_html=html)
        write(build / "assets/app.css")
        with self.assertRaisesRegex(wva.VersioningError, "assets/app.css"):
            wva.version_build(build, RID)

    def test_cli(self):
        build = make_fixture(self.tmp)
        self.assertEqual(wva.main([str(build), RID]), 0)
        self.assertEqual(wva.main([str(build), RID]), 1)


class RepoWebSourcesTest(unittest.TestCase):
    """The committed web/ sources the CI step relies on."""

    def test_bootstrap_template(self):
        js = (WEB / "flutter_bootstrap.js").read_text(encoding="utf-8")
        self.assertIn(wva.BOOTSTRAP_MARKER, js)
        self.assertTrue(js.startswith("{{flutter_js}}\n{{flutter_build_config}}\n"))
        for key in ("entrypointBaseUrl", "assetBase", "canvasKitBaseUrl", "fontFallbackBaseUrl"):
            self.assertIn(key, js)
        # self-hosted glyph fallback, never the fonts.gstatic.com default
        self.assertIn('fontFallbackBaseUrl: new URL("vendor/fallback-fonts/", document.baseURI)', js)

    def test_index_has_one_bootstrap_tag(self):
        html = (WEB / "index.html").read_text(encoding="utf-8")
        self.assertEqual(len(wva.BOOTSTRAP_TAG_RE.findall(html)), 1)

    def test_vendor_files_are_immutable_by_path(self):
        """Caddy serves /vendor/* immutable: any byte change must come with a
        new path. tool/web_vendor.sha256 is the ledger (regenerated by the
        tool/fetch_web_*.sh scripts) — editing a file in place fails here."""
        ledger = {}
        for line in (REPO / "tool/web_vendor.sha256").read_text(encoding="utf-8").splitlines():
            digest, path = line.split(None, 1)
            ledger[path.strip()] = digest
        on_disk = {str(p.relative_to(REPO)) for p in (WEB / "vendor").rglob("*") if p.is_file()}
        self.assertEqual(set(ledger), on_disk, "web/vendor and tool/web_vendor.sha256 disagree — re-run the fetch script")
        for path, digest in ledger.items():
            self.assertEqual(hashlib.sha256((REPO / path).read_bytes()).hexdigest(), digest, path)

    def test_dart_references_existing_vendor_paths(self):
        dart = (REPO / "lib/data/database/web_db_assets.dart").read_text(encoding="utf-8")
        paths = re.findall(r"'(vendor/[^']+)'", dart)
        self.assertEqual(len(paths), 2, paths)
        for p in paths:
            self.assertTrue((WEB / p).is_file(), p)


RELEASE_ID_EXPR = """${CI_COMMIT_SHORT_SHA}$(printf '%x' "$CI_PIPELINE_ID")"""


class ReleaseIdContractTest(unittest.TestCase):
    """build-web and deploy-web.sh must derive the same per-pipeline id."""

    def test_ci_and_deploy_use_the_same_expression(self):
        ci = (REPO / ".gitlab-ci.yml").read_text(encoding="utf-8")
        self.assertIn(f'python3 tool/web_version_assets.py build/web "{RELEASE_ID_EXPR}"', ci)
        deploy = (REPO / "ci/prod/deploy-web.sh").read_text(encoding="utf-8")
        self.assertIn(f'REL_ID="{RELEASE_ID_EXPR}"', deploy)
        self.assertIn('VPATH="v/${REL_ID}"', deploy)
        self.assertIn('REL="releases/${REL_ID}"', deploy)

    def test_expression_yields_a_valid_unique_id(self):
        import subprocess
        ids = set()
        for pipeline in ("1", "3141", "4294967296"):
            out = subprocess.run(["bash", "-c", f'printf %s "{RELEASE_ID_EXPR}"'], check=True, capture_output=True,
                                 text=True, env={**os.environ, "CI_COMMIT_SHORT_SHA": "0e51ca9a",
                                                     "CI_PIPELINE_ID": pipeline}).stdout
            self.assertRegex(out, wva.RELEASE_ID_RE)
            ids.add(out)
        self.assertEqual(len(ids), 3)


class VendorLedgerScriptTest(unittest.TestCase):
    """tool/web_vendor_ledger.sh: new/removed paths fine, changed digest refused."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp)
        (self.tmp / "tool").mkdir()
        shutil.copy(REPO / "tool/web_vendor_ledger.sh", self.tmp / "tool")
        write(self.tmp / "web/vendor/a-1/a.js", "a1")

    def run_ledger(self):
        import subprocess
        return subprocess.run(["bash", "-c", ". tool/web_vendor_ledger.sh && web_vendor_ledger_update"],
                              cwd=self.tmp, capture_output=True, text=True)

    def ledger(self):
        return (self.tmp / "tool/web_vendor.sha256").read_text(encoding="utf-8")

    def test_append_remove_ok_change_refused(self):
        self.assertEqual(self.run_ledger().returncode, 0)
        self.assertIn("web/vendor/a-1/a.js", self.ledger())
        write(self.tmp / "web/vendor/a-2/a.js", "a2")          # bump: new path
        shutil.rmtree(self.tmp / "web/vendor/a-1")              # old one removed
        self.assertEqual(self.run_ledger().returncode, 0)
        self.assertNotIn("a-1", self.ledger())
        before = self.ledger()
        write(self.tmp / "web/vendor/a-2/a.js", "tampered")    # same path, new bytes
        r = self.run_ledger()
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("web/vendor/a-2/a.js", r.stderr)
        self.assertEqual(self.ledger(), before, "ledger must stay untouched on refusal")


def _flutter_fallback_table() -> Path | None:
    root = os.environ.get("FLUTTER_ROOT")
    if not root:
        exe = shutil.which("flutter")
        if exe:
            root = str(Path(os.path.realpath(exe)).parent.parent)
    if not root:
        return None
    table = Path(root) / "engine/src/flutter/lib/web_ui/lib/src/engine/font_fallback_data.dart"
    return table if table.is_file() else None


class FallbackFontMirrorTest(unittest.TestCase):
    """web/vendor/fallback-fonts must match the SDK's fallback table, or the
    engine asks our origin for paths we don't have (tofu, no privacy leak)."""

    def test_mirror_matches_sdk_table(self):
        table = _flutter_fallback_table()
        if table is None:
            self.skipTest("Flutter SDK engine sources not found (set FLUTTER_ROOT)")
        listed = set(re.findall(r"'([a-z0-9]+/v\d+/[^']+\.woff2)'", table.read_text(encoding="utf-8")))
        mirror = WEB / "vendor/fallback-fonts"
        mirrored = {str(p.relative_to(mirror)) for p in mirror.rglob("*.woff2")}
        self.assertTrue(mirrored, "no fallback fonts mirrored")
        self.assertEqual(mirrored - listed, set(),
                         f"mirrored paths unknown to {table} — Flutter bump? re-run tool/fetch_web_fallback_fonts.sh")
        for family in {p.split("/", 1)[0] for p in mirrored}:
            want = {p for p in listed if p.startswith(family + "/")}
            self.assertEqual(want - mirrored, set(), f"{family} mirrored incompletely")
        self.assertIn("notocoloremoji", {p.split("/", 1)[0] for p in mirrored})


if __name__ == "__main__":
    unittest.main()
