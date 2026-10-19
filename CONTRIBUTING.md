# Contributing

## Requirements

- Wolfram Language 15.0 or later
- `wolframscript` on the executable search path
- Git, Bash, `make`, and Python 3
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

Use scoped Conventional Commits for commit messages and pull request titles:

```text
type(scope): short description
```

The scope is required, for example `fix(session): preserve exact values` or
`ci(release): publish tagged paclets`. Keep the subject at most 72 characters.
Each commit should cover one coherent change; include its regression tests when
behavior changes. Keep independent setup, documentation, and build changes in
separate commits.

`make all` enables the hook and tests it. CI uses the same validator for new
commits and pull request titles, including Dependabot changes. Existing history
from before the CI policy is exempt. Squash merges should use the checked pull
request title; resolve `fixup!` and `squash!` commits before merging.

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

PacletPage reuses unchanged pages and rebuilds edited pages. Changes to the GP
binary, Wolfram version, kernel, resources, guide navigation, or build tools
invalidate the cache. Removed pages are pruned. Every build still packs a fresh
archive and checks that it loads; only intermediate pages are cached.

For all checks and the build in one Wolfram kernel:

```bash
make ci-build
```

## Continuous integration

[CI](.github/workflows/ci.yml) checks commit messages and repository hygiene on
pushes to `main` and pull requests. The Wolfram Engine 15.0 jobs run source
checks and both test suites with GP 2.17.4 and 2.19.0 on Linux. PacletPage builds the
documentation and paclet with GP 2.19.0, checks every page is present, and loads
the archive in a fresh kernel. Plot viewers are disabled throughout CI.

CI caches compiled GP executables, pinned documentation tools, and PacletPage's
intermediate pages. Cache hits skip GP compilation and dependency fetches.
Checks, tests, and the build share one main kernel per GP version; archive
checks keep their isolated kernels. Tests always run, including on cache hits.

The Wolfram jobs need an on-demand license entitlement. PacletPage's child
kernels use `wolframscript` to obtain their licenses, as in Ruliology. Store
the entitlement as an Actions secret:

```bash
gh secret set WOLFRAMSCRIPT_ENTITLEMENTID --repo WolframInstitute/PARILink
```

Dependabot needs the same entitlement in its own secrets:

```bash
gh secret set WOLFRAMSCRIPT_ENTITLEMENTID --repo WolframInstitute/PARILink --app dependabot
```

Fork pull requests run the commit and repository checks without license secrets.
Before merging one, run the full CI on a reviewed branch in this repository.
Manual CI runs validate and build; they cannot publish.

Protect `main` by requiring pull requests and the `Commit messages`,
`Repository checks`, `Paclet (GP 2.17.4)`, and `Paclet (GP 2.19.0)` checks.
Use squash merges with the pull request title as the commit subject.

## Releases

[Release](.github/workflows/release.yml) runs only when a `vX.Y.Z` tag is pushed.
The tag must match `PARILink/PacletInfo.wl` and point to a commit on `main`.
It finds the `main` CI run for that exact commit and waits for it to pass, then
publishes its verified archive and documentation through PacletPage. No tests,
GP compilation, or documentation builds are repeated during release.
PacletPage checks the archive and source
hashes before deployment. The GitHub release receives the same `.paclet` and
its SHA-256 checksum after the published site's checks pass.

Publishing also needs these Actions secrets. Use the publishing account's
full Wolfram ID for `WOLFRAM_CLOUD_USER`; each command prompts for its value:

```bash
gh secret set WOLFRAM_CLOUD_USER --repo WolframInstitute/PARILink
```

```bash
gh secret set WOLFRAM_CLOUD_PASSWORD --repo WolframInstitute/PARILink
```

Before tagging, update the paclet version, move the changelog entries into that
release, and run `make all`, `make test-pari`, and `make deps build`. Push the
release commit to `main` and wait for CI. Then create and push an annotated tag,
using the version in `PacletInfo.wl`:

```bash
git tag -a v0.1.0 -m "Release v0.1.0"
```

```bash
git push origin v0.1.0
```

`make publish` is the workflow's entry point. It refuses local runs, branch
pushes, manual workflow runs, mismatched tags, and modified checkouts. To retry
a failed release, rerun the original tag workflow; do not move an existing tag.
Build artifacts are retained for 30 days. If one has expired, rerun the original
`main` push CI run before retrying the release.
PacletPage refuses to replace a published version from a different commit.

The paclet requires an existing GP installation. CI does not bundle GP or
publish its build tools. Runtime bundles need platform verification, license
files, and corresponding source before PureMath can advertise them as installable.

## Security

Follow [SECURITY.md](SECURITY.md) to report vulnerabilities privately.
