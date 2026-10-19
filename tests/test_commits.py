"""Exercise the commit-message hook used locally and by CI."""

from pathlib import Path
import subprocess
import tempfile
import unittest


HOOK = Path(__file__).resolve().parents[1] / ".githooks" / "commit-msg"


class CommitMessages(unittest.TestCase):
    def accepts(self, message):
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8") as file:
            file.write(message + "\n")
            file.flush()
            return subprocess.run(
                [str(HOOK), file.name], capture_output=True, check=False
            ).returncode == 0

    def test_scoped_subjects(self):
        for message in (
            "fix(session): preserve exact values",
            "feat(api)!: change retained values",
            "ci(release): publish tagged paclets\n\nExplain the change here.",
            "docs(readme): " + "a" * 58,
        ):
            with self.subTest(message=message):
                self.assertTrue(self.accepts(message))

    def test_invalid_subjects(self):
        for message in (
            "", "commit", "fix: missing scope", "fix(): empty scope",
            "Fix(session): wrong type", "unknown(api): unknown type",
            "fix(session):", "fix(session):  extra space", "fix(session): \t",
            "fix(session): trailing space ", "fix(session):\tmissing space",
            "fix(session):\nbody is not a subject", "fix(bad scope): space",
            "fixup! fix(session): unfinished work", "squash! fix(session): work",
            "Merge arbitrary text", 'Revert "arbitrary text"',
            "docs(readme): " + "a" * 60,
        ):
            with self.subTest(message=message):
                self.assertFalse(self.accepts(message))


if __name__ == "__main__":
    unittest.main()
