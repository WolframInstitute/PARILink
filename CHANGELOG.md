# Changelog

## Unreleased

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

## 0.1.0

- Add explicit PARI/GP sessions and structured function evaluation.
- Preserve exact values and retain other values as session-owned objects.
- Separate GP output from results and stop sessions after lost synchronization.
- Add offline and live GP tests, and a PacletPage documentation workflow.
