# Contributing

## Requirements

- Wolfram Language 15.0 or later
- `wolframscript` on the executable search path
- Git, Bash, and `make`
- PARI/GP 2.17 or later for integration tests and documentation examples

GP is not needed for `make all` or `make test`. See the
[compatibility report](docs/compatibility.md) for verified versions and platforms.

## Project rules

Read [AGENTS.md](AGENTS.md) and [the design](docs/architecture.md) before editing.

- Keep PARILink independent of PureMath and other consumers.
- Loading the paclet must not start GP, install software, or access the network.
- Keep process and protocol details in `PARILink/Kernel/Internal/`.
- Preserve exact values and retain values without a lossless mapping in GP.
- Never evaluate returned GP text as Wolfram Language code.
- Stop sessions after timeouts, interruptions, or malformed responses.
- Keep GP integration tests separate from tests that need no GP.

## Development

```bash
make check
make test
make test-pari
make all
```

`make all` runs source checks and tests in one Wolfram kernel. To choose the
GP executable for integration tests:

```bash
PARILINK_GP=/path/to/gp make test-pari
```

Tests in `PARILink/Tests/` need no GP. Tests in `Tests/Integration/` use a real
executable. Cover successful calls, failures, and process cleanup. Close every
session created by tests and examples.

`make test-upstream` compares expressions from a local PARI source release with
native GP. It needs Python 3 and a matching GP executable; the
[compatibility report](docs/compatibility.md#reproduce-the-sweep) describes setup.

## Style

- Use UTF-8, LF line endings, tabs in Wolfram Language, and two spaces in GP.
- Use short usage messages, comments, and error descriptions.
- Add a usage message, tests, a reference page, and a guide entry for each public symbol.
- Give each test a clear `TestID`.
- Give each README command its own code block, with expected results in the surrounding prose.
- Update `CHANGELOG.md` when behavior changes.

## Git

Enable the commit-message hook:

```bash
make hooks
```

Use Conventional Commits:

```text
type(optional-scope): short description
```

Keep the subject at most 72 characters. Each commit should cover one coherent
change; include its regression tests when behavior changes. Keep independent
project setup, documentation, and build changes in separate commits.

## Documentation and builds

Author documentation in `docs/en/`. Put inline Wolfram context names inside
double-backtick Markdown delimiters. Use PacletPage for documentation and
publishing; keep the workflow in `scripts/project.wls`.

```bash
make deps
make docs
make build
```

`make deps` fetches pinned tools into `.deps/`. `make docs` evaluates examples
and generates notebooks. `make build` also creates the archive in
`PARILink/build/` and checks that it loads in a fresh kernel. Builds run in
offline dry-run mode after the dependencies are available. Generated notebooks,
caches, and archives are ignored by Git.

## Publishing

Run `make all`, `make test-pari`, and `make build` before publishing. Review the
version in `PARILink/PacletInfo.wl` and the changelog. Both the repository and
the paclet must include the MIT license.

Connect Wolfram Cloud as the publishing account, then run:

```bash
PARILINK_PUBLISH_ACCOUNT=account@example.com make publish
```

This uses PacletPage to publish the resource and documentation site. The initial
source release requires an existing GP installation. Runtime bundles need
platform verification, license files, and corresponding source before PureMath
can advertise them as installable.

## Security

Follow [SECURITY.md](SECURITY.md) to report vulnerabilities privately.
