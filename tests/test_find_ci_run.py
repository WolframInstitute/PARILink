"""Tests for scripts/find-ci-run.sh, which finds the CI run whose archive a release publishes."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "find-ci-run.sh"
COMMIT = "0123456789abcdef0123456789abcdef01234567"

# A stand-in for gh. It writes each call as a line of the file calls, and answers with the line of the file answers
# that has the same number: a run ID, another answer, "error" for a failed command, or nothing.
FAKE_GH = """#!/bin/sh
printf '%s\\n' "$*" >> "$FAKE_GH_DIRECTORY/calls"
count=$(wc -l < "$FAKE_GH_DIRECTORY/calls" | tr -d ' ')
answer=$(sed -n "${count}p" "$FAKE_GH_DIRECTORY/answers")
if [ "$answer" = error ]; then
    echo "HTTP 502: Bad Gateway" >&2
    exit 1
fi
[ -z "$answer" ] || printf '%s\\n' "$answer"
"""


def run(answers, arguments=(COMMIT,), tries="3", wait="0"):
    """Run the script while gh gives the answers in turn. Give the result and the calls of gh."""
    with tempfile.TemporaryDirectory() as directory:
        folder = Path(directory)
        fake = folder / "gh"
        fake.write_text(FAKE_GH)
        fake.chmod(0o755)
        (folder / "answers").write_text("".join(answer + "\n" for answer in answers))
        environment = dict(
            os.environ,
            PATH=directory + os.pathsep + os.environ["PATH"],
            FAKE_GH_DIRECTORY=directory,
            CI_RUN_TRIES=tries,
            CI_RUN_WAIT=wait,
        )
        result = subprocess.run(["sh", str(SCRIPT), *arguments], capture_output=True, text=True, env=environment, check=False)
        calls_file = folder / "calls"
        calls = calls_file.read_text().splitlines() if calls_file.exists() else []
    return result, calls


class FindCIRun(unittest.TestCase):
    def test_the_listed_run_is_printed(self):
        result, calls = run(["4321"])
        self.assertEqual((result.returncode, result.stdout, result.stderr, len(calls)), (0, "4321\n", "", 1))

    def test_gh_is_asked_for_the_ci_runs_of_the_commit_on_main(self):
        result, calls = run(["4321"])
        self.assertTrue(calls[0].startswith(f"run list --workflow ci.yml --branch main --commit {COMMIT} "))

    def test_the_lookup_is_tried_again_until_the_run_is_listed(self):
        result, calls = run(["", "", "4321"])
        self.assertEqual((result.returncode, result.stdout, len(calls)), (0, "4321\n", 3))
        self.assertEqual(result.stderr.count("looking again"), 2)

    def test_a_failed_command_or_an_answer_that_is_not_a_run_counts_as_no_run(self):
        result, calls = run(["error", "null", "4321"])
        self.assertEqual((result.returncode, result.stdout, len(calls)), (0, "4321\n", 3))

    def test_the_lookup_stops_after_the_last_try(self):
        result, calls = run(["", "", "", "4321"])
        self.assertEqual((result.returncode, result.stdout, len(calls)), (1, "", 3))
        self.assertIn(f"no CI run on main was found for {COMMIT}", result.stderr)

    def test_one_commit_is_required(self):
        for arguments in ((), ("",), (COMMIT, "another")):
            with self.subTest(arguments=arguments):
                result, calls = run(["4321"], arguments)
                self.assertEqual((result.returncode, result.stdout, calls), (2, "", []))

    def test_the_settings_are_whole_numbers(self):
        for tries, wait in (("0", "0"), ("two", "0"), ("-1", "0"), ("3", "soon"), ("3", "-5")):
            with self.subTest(tries=tries, wait=wait):
                result, calls = run(["4321"], tries=tries, wait=wait)
                self.assertEqual((result.returncode, calls), (2, []))


if __name__ == "__main__":
    unittest.main()
