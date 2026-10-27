# Changelog

## 0.2.0 — Unreleased

- Bundle GP 2.19.0 with GMP and data for Galois groups, number fields, and elliptic curves.
- Build runtimes for Windows x86-64, macOS Intel and Apple Silicon, and Linux x86-64 and ARM64.
- Select the bundled runtime automatically while preserving executable overrides.
- Restore executable permissions after installation and locate data relative to the paclet.
- Check the final archive on each platform without GP or other tools on the search path.
- Include third-party licenses, corresponding sources, and build instructions in the paclet.
- Continue publishing PacletPage's verified archive only from release tags.

## 0.1.0 — 2026-10-19

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
