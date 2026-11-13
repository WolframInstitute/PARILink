# Changelog

## Unreleased

### Changed

- License PARILink under the GNU General Public License, version 2 or later, as PARI/GP
  is. Versions up to 0.2.1 stay under the MIT license.
- Give `Failure["InvalidArguments", ...]` and the message `Name::args` for a call that
  used to stay unevaluated, such as `PARIEvaluate[]`, `PARICall[session, 1]` or
  `session[1]`. Calls that gave a `Failure` before give the same one.
- Follow the Wolfram Language coding guides in the kernel, the tests, the scripts and the
  programs under `tests/`, and check them with `make style`.
- Return small results sooner: during the first 20 ms of a request, check for GP's answer
  every few milliseconds instead of every 10 ms.
- Read text from GP about four times faster.
- Shorten the README to installation, a quick start and links.
- Let CI and publishing take the Wolfram license from a license line in the
  `WOLFRAM_MATHPASS_B64` secret. Without it they use the entitlement as before. Publishing
  goes on when `CloudConnect` prints a message and still connects.

### Fixed

- `PARIEvaluate` and `PARICall` give `Failure["PARIInvalidSession", ...]` for a session of
  another form, such as `PARISession[1]`, in place of an unevaluated internal expression.
- `DeleteObject` gives `Failure["PARIInvalidObject", ...]` for an object of another form,
  in place of `$Failed` and the message `DeleteObject::nim`.
- `StartPARISession["Executable" -> ""]` gives its `Failure` without messages.
- The display of a session or an object holds its status or GP type as text, in place of
  an unevaluated call that computes it.
- The bundled GP restores its execute permission only when it is missing, so that GP
  starts from a paclet that the user may run but not change.

## 0.2.1 - 2026-10-28

- Restore bundled runtime files before PacletPage verifies the release build.
- Test release restoration in a clean checkout before publishing the verified artifact.

## 0.2.0 - 2026-10-28 (not published)

- Bundle GP 2.19.0 with GMP and data for Galois groups, number fields, and elliptic curves.
- Build runtimes for Windows x86-64, macOS Intel and Apple Silicon, and Linux x86-64 and ARM64.
- Select the bundled runtime automatically while preserving executable overrides.
- Restore executable permissions after installation and locate data relative to the paclet.
- Check the final archive on each platform without GP or other tools on the search path.
- Include third-party licenses, corresponding sources, and build instructions in the paclet.
- Continue publishing PacletPage's verified archive only from release tags.

## 0.1.0 - 2026-10-19

- Add explicit PARI/GP sessions and structured function evaluation.
- Preserve exact values and retain other values as session-owned objects.
- Separate GP output from results and stop sessions after lost synchronization.
- Add offline and live GP tests, and a PacletPage documentation workflow.
- Publish cloud installation instructions and verify both GP versions on Linux x86-64 and macOS ARM64.
- Add CI for both GP versions and publish verified PacletPage builds only from release tags.
- Reuse CI artifacts for releases, cache GP and build tools, and build unchanged documentation incrementally.
- Require scoped commit subjects and validate pull request titles and new commits in CI.
- Prevent user variables and closures from capturing GP bridge state.
- Support multiline scripts and inline declarations with GP's script parser.
- Support in-place operations on retained values and reuse released storage.
- Retain mutable GP lists and maps; copy their contents explicitly with `Vec` or `Mat`.
- Stop sessions promptly when GP abandons a request without returning a result.
- Enforce request deadlines even when a kernel timer is delayed.
- Add `StackLimit` at session startup and allow parallel worker stacks to grow.
- Expand integration coverage across GP types and mathematical function families.
- Add a reproducible comparison against PARI's upstream regression suites.
