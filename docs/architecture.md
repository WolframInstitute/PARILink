# Design

PARILink connects Wolfram Language to PARI/GP. It follows GAPLink's explicit
sessions, structured function arguments, and session-owned objects. It has no
dependency on PureMath or GAPLink.

## Initial choices

These choices implement the requested standalone link. They can be revisited
without exposing the process protocol to callers.

- Run GP as a separate process, started only by `StartPARISession`. This avoids
  introducing a native library and PARI's stack lifetime into the Wolfram kernel.
- Select an explicit executable, `PARILINK_GP`, the bundled GP, then an existing
  installation. Explicit overrides never silently fall back to another program.
  Starting a session locates the bundled data and restores GP's execute permission
  if archive extraction removed it. Loading the package does neither.
- Start with `-f -q`, disable the break loop and color, and ignore `.gprc`.
  User startup code must not change the link's protocol or produce side effects.
- Keep one process per session. Objects belong to that session and Wolfram
  kernel. Closing or losing a session invalidates its objects.
- Evaluate user code at top level so its variables and closures do not capture
  bridge locals. Retained objects occupy reusable list slots, which also allow
  GP functions to update them by reference. Mutable lists and maps stay objects.
- Read requests through GP's script parser; `eval` mishandles inline declarations.
  Each request uses a temporary UTF-8 file, removed after completion or failure.
- Transfer integers and fractions as decimal strings, and text as UTF-8 bytes
  inside JSON. Decode with `ImportString` and `FromDigits`, never `ToExpression`.
- Convert exact complex numbers, vectors, and matrices recursively. Copying
  preserves values, not PARI type identity or vector orientation. Lists sent to
  GP are vectors, including nested lists; use GP's `Mat` or retained objects
  when matrix identity matters.
- Keep polynomials, modular values, number-field data, approximate numbers,
  and other unsupported values as `PARIObject`. Approximate numbers are not
  silently rounded to machine precision. `"ReturnType" -> "Object"` also keeps
  otherwise convertible results in GP.
- Bound automatic container conversion and response size. Large results remain
  objects; runaway output stops the session. Timeouts and interrupted requests
  stop the session rather than risking consumption of a late response.
- Give every response a unique request marker. Ordinary GP output is collected
  separately and can be printed, captured, or discarded. GP errors are
  `Failure` values containing the original error, and leave a synchronized
  session usable. This protocol is not a sandbox for untrusted GP code.
- Use one project script for checks and tests. PacletPage builds the markdown
  documentation, checks the archive, and provides the publishing entry point.
  Building and publishing are separate actions; builds must remain offline.
- Cache intermediate documentation with PacletPage. Runtime, source, guide,
  and tooling changes invalidate it; every build still creates and load-checks
  a fresh archive. CI caches GP and the pinned tools and uses one main kernel
  per tested GP version.
- Run CI on pushes and pull requests. Release tags use the successful `main`
  build for the same commit before PacletPage publishes its archive and
  documentation, without rebuilding. Only a `vX.Y.Z`
  tag matching the paclet version and a clean commit on `main` can publish.
  GitHub receives the same archive and a checksum after the site checks pass.

## Scope and verification

The initial target is PARI/GP 2.17 or newer with Wolfram Language 15 or newer.
Live tests use GP 2.17.4 and 2.19.0 on Linux x86-64 and macOS ARM64. See the
[compatibility report](compatibility.md) for the upstream sweep and exclusions.
Version 0.2.0 adds native runtime and final-archive checks for Windows x86-64,
macOS Intel and ARM64, and Linux x86-64 and ARM64. These checks run GP with an
empty search path, exercise all bundled data packages, and test the bridge's
exact values, Unicode strings, and request files with spaces in their paths.

## Bundled runtime

`scripts/runtime.json` pins PARI, GMP, and five data packages by SHA-256.
`make runtime` compiles GP and GMP on the target platform, runs GMP's tests,
and rejects dependencies outside the operating system. GMP and the thread
runtime are linked statically; GP supports parallel operations without another
installation. Intel builds use baseline x86-64 instructions with GMP's runtime
CPU selection. macOS targets 13.0; Linux builds use Ubuntu 22.04 (glibc 2.35).

One paclet contains all five executables and one copy of the data. Data files
are uncompressed at build time so GP never needs an external gzip program to
read them. Source archives, build scripts, and licenses accompany the binaries,
including downloads from Wolfram Cloud.

CI caches each compiled runtime separately. A single Linux job assembles the
runtimes, evaluates documentation, and builds the paclet with PacletPage. Every
platform then runs its GP from that exact archive. Release tags require the
whole CI run to pass and reuse the archive, documentation, and sources.

PureMath can install the released paclet through its existing library dialog;
runtime discovery, data, and platform packaging remain PARILink's responsibility.

## References

- [PARI/GP manual](https://pari.math.u-bordeaux.fr/doc.html)
- [GP error handling](https://pari.math.u-bordeaux.fr/dochtml/html/Programming_in_GP__control_statements.html#iferr)
- [GAPLink design](../../GAPLink/docs/architecture.md)
- [PureMath's external libraries](../../PureMath/docs/research/ExternalLibraries/ExternalMathematicsLibraries.md)
- [PacletPage](https://github.com/WolframInstitute/PacletPage)
