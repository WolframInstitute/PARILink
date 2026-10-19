# Repository rules

- Read `docs/architecture.md` before changing sessions, conversion, or builds.
- PARILink is independent of PureMath and other consumers.
- Loading the paclet must not start GP, install software, or access the network.
- Keep process and protocol details out of the public API.
- Preserve exact values. Keep values without a lossless mapping in PARI.
- Never evaluate returned GP text as Wolfram Language code.
- Invalidate a session after a timeout, interruption, or malformed response.
- Keep tests requiring GP separate from tests that do not need it.
- Use tabs in Wolfram Language, short public usage messages, and plain prose.
- Use PacletPage for documentation and publishing, without a second release pipeline.
- Use Conventional Commits with a subject of at most 72 characters. Keep each commit focused and include tests with behavior changes.
- Run `make all` and `make test-pari` for behavior changes. Update `CHANGELOG.md`.
