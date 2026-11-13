# Contributing

## Requirements

- Wolfram Language 15.0 or later
- `wolframscript` on the executable search path
- Git, Bash, `make`, and Python 3
- Bundled GP or an existing PARI/GP 2.17 or later for integration tests

GP is not needed for `make all` or `make test`. See the
[compatibility report](docs/compatibility.md) for verified versions and platforms.

## Project rules

Read [AGENTS.md](AGENTS.md) and [the design](docs/architecture.md) before editing.

- Keep PARILink independent of the projects that use it.
- Loading the paclet must not start GP, install software, or access the network.
- Keep process and protocol details in `PARILink/Kernel/Internal/`.
- Preserve exact values and retain values without a lossless mapping in GP.
- Never evaluate returned GP text as Wolfram Language code.
- Stop sessions after timeouts, interruptions, or malformed responses.
- Keep GP integration tests separate from tests that need no GP.

## Development

To use a source checkout, load its paclet directory before `Needs`:

```wolfram
PacletDirectoryLoad["/path/to/PARILink/PARILink"];
Needs["WolframInstitute`PARILink`"];
```

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
session created by tests and examples. `tests/` holds the tests of the
development scripts and the programs that CI runs. To run some test files only:

```bash
make test FILES="PARILink/Tests/Values.wlt tests/Project.wlt"
```

`make test-upstream` compares expressions from a local PARI source release with
native GP. It needs Python 3 and a matching GP executable; the
[compatibility report](docs/compatibility.md#reproduce-the-sweep) describes setup.

## Style

Wolfram Language code follows the [coding guides](docs/coding-guides/README.md):
the kernel, the tests, the scripts, and the programs under `tests/`. The page
says how PARILink applies them. `make check`, the pre-commit hook, and CI run the
same check:

```bash
make style
make style FILES="PARILink/Kernel/Session.wl"
make style-fix FILES="PARILink/Kernel/Session.wl"
make lint FILES="PARILink/Kernel/Session.wl"
```

`make style-fix` rewrites what a program can decide, such as indentation and
spacing. Read the code once more for what the check cannot judge, such as names.

- Use UTF-8, LF line endings, tabs in Wolfram Language, and two spaces in GP.
- Use plain prose in comments and error descriptions.
- Add a usage message, tests, a reference page, and a guide entry for each public symbol.
- Give each test a clear `TestID`.
- Give each README command its own code block, with expected results in the surrounding prose.
- Update `CHANGELOG.md` when behavior changes.

## Git

Enable the hooks. The commit-message hook checks the subject; the pre-commit
hook lints the staged Wolfram Language files:

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
make runtime stage-runtime
make docs
make build
```

`make runtime` builds GP and GMP for the current platform, checks their native
code, and saves a compressed runtime under `build/runtimes/`. It needs a C
compiler, `make`, `m4`, `curl`, Python 3.9 or later, and tar with xz support.
On Windows, use MSYS2 UCRT64 with GCC and Python. `make stage-runtime` verifies
the runtime and includes the five PARI data packages and corresponding sources.
It does not install anything in the user's paclet directory.

`make deps` fetches pinned tools into `.deps/`. `make docs` evaluates examples
and generates notebooks. `make build` also creates the archive in
`PARILink/build/`, checks that it loads in a fresh kernel, and runs its bundled
GP with an empty search path. Builds run in
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
checks and both test suites with GP 2.17.4 and bundled GP 2.19.0 on Linux.
Native jobs build GP for Windows x86-64, macOS Intel and ARM64, and Linux x86-64
and ARM64. A single PacletPage build contains all five runtimes and one copy
of the data. Each platform tests GP and the bridge from that final archive.
The Linux Wolfram job also installs the archive, tests permission repair, and
runs the integration suite with the executable search path empty.
Plot viewers are disabled throughout CI.

CI caches compiled GP executables, pinned documentation tools, and PacletPage's
intermediate pages. Cache hits skip GP compilation and dependency fetches.
Checks, tests, and the build share one main kernel per GP version; archive
checks keep their isolated kernels. Tests always run, including on cache hits.

The Wolfram jobs take their license from one of two secrets: a license line or
an entitlement. When both are set, they use the license line.

`WOLFRAM_MATHPASS_B64` holds a license line (mathpass) for one machine. With it
the kernel runs offline and spends no Service Credits. The line has four parts
with tabs between them: machine name, MathID, activation key, and password.
Keep it in `.mathpass`, which git ignores, and store it base64-encoded, so that
the tabs survive:

```bash
base64 < .mathpass | tr -d '\n' | gh secret set WOLFRAM_MATHPASS_B64 --repo WolframInstitute/PARILink
```

The kernel knows a machine by its MathID. In a Linux container the MathID comes
from the machine-id and the host name, so CI fixes both.
`.github/actions/wolfram-license` sets the machine-id. The host name is the
machine name at the start of the license line: the `Wolfram license` job reads
it with `scripts/license-machine-name.sh`, and the Wolfram jobs start their
containers under that name. Changing either changes the MathID, and the line
then needs a new password. To get a line for a new machine, leave the secret
unset, so that the container is named `parilink-ci`, and start CI with
`gh workflow run ci.yml --ref main`. The step *Verify Wolfram Engine license*
prints the machine name and the MathID of the container, also when no license
works. Have a password issued for that MathID and your activation key. The same
step prints the license type and its expiry in every run.

Without a license line the jobs use an on-demand license entitlement. PacletPage's
child kernels then use `wolframscript` to obtain their licenses. Store the
entitlement as an Actions secret:

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
`Repository checks`, `Wolfram license`, `Paclet (GP 2.17.4)`, and
`Paclet (GP 2.19.0)` checks.
Also require every `GP runtime` and `Packaged GP` matrix check.
Use squash merges with the pull request title as the commit subject.

## Releases

[Release](.github/workflows/release.yml) publishes only from a `vX.Y.Z` tag,
either when pushed or when the workflow is started manually on that tag.
The tag must match `PARILink/PacletInfo.wl` and point to a commit on `main`.
It finds the `main` CI run for that exact commit and waits for it to pass, then
publishes its verified archive and documentation through PacletPage. GitHub can
list a run late, so `scripts/find-ci-run.sh` looks for it for about five minutes.
No tests, GP compilation, or documentation builds are repeated during release.
PacletPage checks the archive and source
hashes before deployment. The GitHub release receives the same `.paclet` and
the corresponding runtime sources, and SHA-256 checksums after the published
site's checks pass. The cloud renders new pages late, so a failed check is tried
again for up to ten minutes, and the error names each check that still fails.
Source archives and licenses also travel inside the paclet.

Publishing uses the same license secret as CI, and also needs these Actions
secrets. Use the publishing account's
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
runs, mismatched tags, and modified checkouts. To retry
a failed release, rerun the original tag workflow; do not move an existing tag.
Build artifacts are retained for 30 days. If one has expired, rerun the original
`main` push CI run before retrying the release.
PacletPage refuses to replace a published version from a different commit.

Local builds contain the current platform's runtime. Release builds require
all five: `python3 scripts/runtime.py stage --all` refuses missing or damaged
archives, and `PARILINK_REQUIRE_ALL_RUNTIMES=1` makes PacletPage's build and
publication checks enforce the complete bundle. Never substitute a local
single-platform archive for CI's release artifact.

## Security

Follow [SECURITY.md](SECURITY.md) to report vulnerabilities privately.
