"""Tests for scripts/license-machine-name.sh, which names the Wolfram job container in CI."""

import base64
import os
from pathlib import Path
import subprocess
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "license-machine-name.sh"


def run(license_text=None, encoded=None):
    """Run the script with a license line, given as text or as its base64 form."""
    environment = {key: value for key, value in os.environ.items() if key != "WOLFRAM_MATHPASS_B64"}
    if license_text is not None:
        encoded = base64.b64encode(license_text.encode()).decode()
    if encoded is not None:
        environment["WOLFRAM_MATHPASS_B64"] = encoded
    return subprocess.run(["sh", str(SCRIPT)], capture_output=True, text=True, env=environment, check=False)


class LicenseMachineName(unittest.TestCase):
    def test_default_name_without_a_license_line(self):
        for result in (run(), run(encoded="")):
            self.assertEqual((result.returncode, result.stdout), (0, "parilink-ci\n"))

    def test_name_is_the_first_part_of_the_line(self):
        for text in (
            "build-host\t1234-56789-01234\tAAAA-BBBB-CCCCCC\t1234-567-890:1,2,3\n",
            "build-host\t1234-56789-01234\tAAAA-BBBB-CCCCCC\t1234-567-890:1,2,3",
            "build-host\t1234-56789-01234\tAAAA-BBBB-CCCCCC\t1234-567-890:1,2,3\r\n",
            "\n% a comment\nbuild-host\tid\tkey\tpassword\nother-host\tid\tkey\tpassword\n",
            "host.example.org\tid\tkey\tpassword\n",
            "A1\tid\tkey\tpassword\n",
        ):
            with self.subTest(text=text):
                result = run(text)
                expected = "build-host" if "build-host" in text else text.split("\t")[0]
                self.assertEqual((result.returncode, result.stdout, result.stderr), (0, expected + "\n", ""))

    def test_only_the_name_is_printed(self):
        result = run("build-host\tSECRET-ID\tSECRET-KEY\tSECRET-PASSWORD\n")
        self.assertEqual(result.returncode, 0)
        self.assertNotIn("SECRET", result.stdout + result.stderr)

    def test_a_line_without_a_plain_host_name_is_refused(self):
        for text in (
            "\tid\tkey\tpassword\n",
            "two words\tid\tkey\tpassword\n",
            "-leading-hyphen\tid\tkey\tpassword\n",
            ".leading-dot\tid\tkey\tpassword\n",
            "!server\tid\tkey\tpassword\n",
            "name --privileged\tid\tkey\tpassword\n",
            "name;id\tid\tkey\tpassword\n",
            "name$(id)\tid\tkey\tpassword\n",
            "under_score\tid\tkey\tpassword\n",
            "a" * 64 + "\tid\tkey\tpassword\n",
            "\n\n",
            "% only a comment\n",
        ):
            with self.subTest(text=text):
                result = run(text)
                self.assertEqual((result.returncode, result.stdout), (1, ""))
                self.assertIn("WOLFRAM_MATHPASS_B64", result.stderr)
                self.assertNotIn("password", result.stderr)

    def test_text_that_is_not_base64_is_refused(self):
        result = run(encoded="not base64 !!!")
        self.assertEqual((result.returncode, result.stdout), (1, ""))


if __name__ == "__main__":
    unittest.main()
