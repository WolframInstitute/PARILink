# PARI/GP compatibility

The sweep compares expressions from PARI's own regression inputs with native GP
of the same version. It covers mathematical results, expected GP errors, printed
output, and retained objects. It does not prove every possible argument, flag,
or combination of settings.

All 32,949 comparable expressions were checked, with no unexplained differences.
Results and output matched exactly in 32,909 cases. The remaining 40 were
process-dependent measurements or newlines from stack-growth warnings.

## Corpus

| Coverage | GP 2.17.4 | GP 2.19.0 |
| --- | ---: | ---: |
| Upstream input files | 262 | 270 |
| Supplemental expressions | 51 | 51 |
| Comparable expressions | 15,921 | 17,028 |
| Exact result/error and output matches | 15,901 | 17,008 |
| Process-dependent differences | 20 | 20 |
| Unexplained differences or unexecuted cases | 0 | 0 |
| Native values | 14,156 | 15,159 |
| Native GP errors | 1,765 | 1,869 |
| Native nonlocal exits checked separately | 2 | 2 |
| Skipped frontend and setup statements | 195 | 198 |
| Named GP catalogue entries | 1,153 | 1,187 |
| Calls present in successful native expressions | 1,146 | 1,180 |

The comparable expressions include both successful values and GP errors.
Matching an error confirms error propagation; it does not establish that the
input has a mathematical result. The nonlocal exits and other boundaries are
described below.

The remaining named entries are `allocatemem` and `quit`, covered by integration
tests, and five interactive functions listed below.

## Environment

Recorded on 2026-10-19 with Wolfram Language 15.0.0 on macOS ARM64, using
PARI/GP 2.17.4 and 2.19.0. The package checks pass 17 tests without GP and
51 integration tests with each GP version. PacletPage builds six reference
and guide pages, and the resulting archive loads in a fresh kernel.

The integration tests include a cyclotomic factorization requiring more than
the default 256 MiB stack limit and parallel calculations requiring worker
stacks to grow. `StackLimit` sets the limit for the main thread and each worker.

## Method

- Read `src/test/in` from the matching [official source release](https://pari.math.u-bordeaux.fr/download.html).
- Start fresh native and linked GP processes for each suite, with the same
  random seed, 256 MiB stack limit, and optional datasets. Native GP starts
  with its stack allocated; linked GP grows from its normal initial size.
  Plotting uses a headless viewer and keeps its files in the suite directory.
- Use two workers for the parallel suite, so its alarm stress test has pending
  tasks to cancel. [GP alarms](https://pari.math.u-bordeaux.fr/dochtml/html/Programming_in_GP__other_specific_functions.html#alarm)
  do not interrupt already-running worker tasks.
- Run the unchanged parallel alarm stress test in a separate session. Native
  GP 2.19.0 can hang when it follows the other parallel operations; that
  interaction is not covered by a successful comparison.
- Compare exact values and printed output. Compare retained values by GP type
  and SHA-256 of their GP text, written through structured calls to scratch files.
  This also checks large objects without exceeding the link's response limit.
- Preserve original file names and line numbers in the generated reports.
- Allow 600 seconds per complete native suite and 120 seconds per linked
  expression. Timing and heap measurements, and newlines accompanying GP
  stack-growth warnings, are reported separately because the processes differ.

The additional cases in [extra.gp](../tests/upstream/extra.gp) cover catalogue
entries without suitable upstream calls, including legacy aliases. Catalogue
references describe the supplied expressions; they are not instrumentation of
every function branch. `make test-pari` separately checks structured argument
passing, mutation, object lifetimes, process exit, and interruption handling.

Symbolic operators and `gp2c`-only entries are excluded from the named catalogue;
operator expressions are still replayed.

## Boundaries

- GP's interactive input, debugger, command history, help prompts, and terminal
  metacommands are outside the session API. `breakpoint`, `dbg_up`, `dbg_down`,
  `dbg_err`, and `input` require that frontend state.
- Plotting calls run without a viewer; interactive rendering is not checked.
- A whole-session `writebin` / `read` round trip would restore private bridge
  variables. Explicit-value binary and text file operations are exercised.
- `default(parisize, ...)` and `default(parisizemax, ...)` can abandon the active
  request. The link returns `Failure["PARIInterrupted", ...]` and stops the session.
  A completed `allocatemem` request leaves the session usable. Configure larger stacks with
  `StartPARISession["StackLimit" -> 1024^3]` before a calculation.
- Both tested GP versions emit a segmentation-fault diagnostic for
  `alginit(1.,1)` and `polinterpolate([1,1],[2,3],Pi)`. These have no native result
  to compare; the link's clean session shutdown is checked separately.

Ordinary GP errors leave a session usable. Timeouts, malformed responses,
nonlocal exits, and excessive output stop it. Automatic conversion retains
containers above 10,000 elements or depth 32; response text is limited to
16,777,216 characters.
Use retained objects and GP operations for larger calculations.

## Reproduce the sweep

Use Python 3, Wolfram Language 15 or newer, a local PARI source tree, and a GP
executable from the same release on a Unix-like system. Use GP's SVG or
PostScript backend for headless plotting. The harness fetches nothing and keeps
its reports and scratch files under the output directory.

```bash
make test-upstream \
  PARI_SOURCE=/path/to/pari-2.19.0 \
  PARILINK_GP=/path/to/gp \
  PARI_DATA=/path/to/pari-data
```

`PARI_DATA` is optional; omitting it uses GP's installed data directory. The
recorded sweep used `elldata`, `galdata`, `galpol`, `nflistdata`, and `seadata`
from the [official packages](https://pari.math.u-bordeaux.fr/packages.html).

Results are in `build/upstream/report.json`, with per-suite expectations,
native input, stdout, and stderr alongside it. Set `UPSTREAM_OUTPUT` to retain
multiple runs. To select suites:

```bash
make test-upstream \
  PARI_SOURCE=/path/to/pari-2.19.0 \
  PARILINK_GP=/path/to/gp \
  UPSTREAM_FILES=parilink-extra
```

The command fails on unmatched results, unexecuted cases, unexplained native
failures, or a native suite timeout. Expected GP errors and clean shutdown after
a native nonlocal error are recorded separately from successful values.

An interrupted replay can continue from its completed-suite checkpoint:

```bash
wolframscript -file tests/upstream/replay.wls build/upstream/manifest.json resume
```

Use a fresh run after changing the package or corpus.

Source archives (SHA-256):

| Release | SHA-256 |
| --- | --- |
| [2.17.4](https://pari.math.u-bordeaux.fr/pub/pari/unix/pari-2.17.4.tar.gz) | `02651d99c391007d384b3fadbc20abc6916b77036f9e496c99e9ce8688ca4b53` |
| [2.19.0](https://pari.math.u-bordeaux.fr/pub/pari/unix/pari-2.19.0.tar.gz) | `f317b9722eb5d9094a60303774f066f3a83e3ec1f170be8546c44d7583f30b6d` |
