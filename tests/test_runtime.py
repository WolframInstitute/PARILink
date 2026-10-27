"""Distribution checks that do not need Wolfram Language or GP."""

import importlib.util
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("runtime", Path(__file__).parents[1] / "scripts/runtime.py")
runtime = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runtime)


class RuntimeTests(unittest.TestCase):
    def test_platforms_and_windows_name(self):
        for os_name, machine, expected in [
            ("Darwin", "arm64", "MacOSX-ARM64"),
            ("Darwin", "x86_64", "MacOSX-x86-64"),
            ("Linux", "aarch64", "Linux-ARM64"),
            ("Linux", "x86_64", "Linux-x86-64"),
            ("Windows", "AMD64", "Windows-x86-64"),
        ]:
            with self.subTest(system=expected), patch.object(runtime.platform, "system", return_value=os_name), \
                    patch.object(runtime.platform, "machine", return_value=machine):
                self.assertEqual(runtime.host_system(), expected)
        self.assertEqual(runtime.executable(Path("runtime"), "Windows-x86-64").name, "gp.exe")
        with patch.object(runtime.platform, "system", return_value="Windows"), \
                patch.object(runtime.platform, "machine", return_value="ARM64"):
            with self.assertRaises(ValueError):
                runtime.host_system()

    def test_archive_paths_and_links_cannot_escape(self):
        for name in ("../outside", "/absolute", "C:/absolute", "a/../../outside", "a\\..\\outside"):
            with self.subTest(name=name), self.assertRaises(ValueError):
                runtime.member_path(name)
        with tempfile.TemporaryDirectory() as work:
            directory = Path(work)
            archive = directory / "bad.tar.gz"
            with tarfile.open(archive, "w:gz") as bundle:
                entry = tarfile.TarInfo("link")
                entry.type = tarfile.SYMTYPE
                entry.linkname = "../outside"
                bundle.addfile(entry)
            with self.assertRaises(ValueError):
                runtime.extract_tar(archive, directory / "extracted")

    def test_extracts_regular_files_and_preserves_executable_permission(self):
        with tempfile.TemporaryDirectory() as work:
            directory = Path(work)
            archive = directory / "runtime.tar.gz"
            with tarfile.open(archive, "w:gz") as bundle:
                entry = tarfile.TarInfo("platform/gp")
                entry.size, entry.mode = 4, 0o755
                bundle.addfile(entry, io.BytesIO(b"test"))
            runtime.extract_tar(archive, directory / "extracted")
            self.assertEqual((directory / "extracted/platform/gp").read_bytes(), b"test")

    def test_tampered_cached_download_is_rejected_without_network_access(self):
        with tempfile.TemporaryDirectory() as work, patch.object(runtime, "SOURCES", Path(work)), \
                patch.object(runtime.subprocess, "run") as download:
            (Path(work) / "source.tar.gz").write_bytes(b"changed")
            with self.assertRaises(ValueError):
                runtime.fetch_one("https://example.invalid/source.tar.gz", "0" * 64)
            download.assert_not_called()

    def test_runtime_metadata_requires_the_right_platform_version_and_license(self):
        with tempfile.TemporaryDirectory() as work:
            directory = Path(work)
            for name in ("gp", "licenses/pari/COPYING", "licenses/gmp/COPYING", "licenses/gmp/COPYING.LESSERv3"):
                path = directory / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("test")
            runtime.write_manifest(directory, "Linux-ARM64")
            runtime.verify_manifest(directory, "Linux-ARM64")
            with self.assertRaises(ValueError):
                runtime.verify_manifest(directory, "Linux-x86-64")
            (directory / "gp").write_text("changed")
            with self.assertRaises(ValueError):
                runtime.verify_manifest(directory, "Linux-ARM64")
            (directory / "gp").write_text("test")
            manifest = json.loads((directory / "runtime.json").read_text())
            del manifest["files"]["licenses/pari/COPYING"]
            (directory / "runtime.json").write_text(json.dumps(manifest))
            with self.assertRaises(ValueError):
                runtime.verify_manifest(directory, "Linux-ARM64")

    def test_external_gmp_and_build_paths_are_rejected(self):
        for system, output in [
            ("MacOSX-ARM64", "gp:\n\t/opt/homebrew/lib/libgmp.dylib (compatibility version 1)\n"),
            ("Linux-ARM64", "(NEEDED) Shared library: [libgmp.so.10]"),
            ("Linux-x86-64", "(RPATH) Library rpath: [/build/lib]"),
            ("Windows-x86-64", "DLL Name: libwinpthread-1.dll"),
        ]:
            with self.subTest(system=system), patch.object(runtime.subprocess, "check_output", return_value=output), \
                    self.assertRaises(ValueError):
                runtime.check_dependencies(Path("gp"), system)


if __name__ == "__main__":
    unittest.main()
