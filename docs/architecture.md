# Design

PARILink connects Wolfram Language to PARI/GP. It follows GAPLink's explicit
sessions, structured function arguments, and session-owned objects. It has no
dependency on PureMath or GAPLink.

## Initial choices

These choices implement the requested standalone link. They can be revisited
without exposing the process protocol to callers.

- Run GP as a separate process, started only by `StartPARISession`. This avoids
  introducing a native library and PARI's stack lifetime into the Wolfram kernel.
- Use an explicit executable, `PARILINK_GP`, or GP on the executable search path.
  This first source release uses an existing PARI/GP installation. It neither
  downloads nor bundles a runtime. Runtime redistribution needs its own build,
  source, license, and platform checks before it can be advertised.
- Start with `-f -q`, disable the break loop and color, and ignore `.gprc`.
  User startup code must not change the link's protocol or produce side effects.
- Keep one process per session. Objects belong to that session and Wolfram
  kernel. Closing or losing a session invalidates its objects.
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

## Scope and verification

The initial target is PARI/GP 2.17 or newer with Wolfram Language 15 or newer.
Live tests use GP 2.17.4 on macOS ARM64. Linux and Windows are not yet verified.
No platform bundles or public download URLs are claimed by this source release.

The initial number-theory examples cover factorization, quadratic class
numbers, elliptic curves, and number fields. PureMath method dispatch and its
optional installer should be added after a distributable PARILink release is
available; a nonexistent archive must not appear as an installable library.

## References

- [PARI/GP manual](https://pari.math.u-bordeaux.fr/doc.html)
- [GP error handling](https://pari.math.u-bordeaux.fr/dochtml/html/Programming_in_GP__control_statements.html#iferr)
- [GAPLink design](../../GAPLink/docs/architecture.md)
- [PureMath's external libraries](../../PureMath/docs/research/ExternalMathematicsLibraries.md)
- [PacletPage](https://github.com/WolframInstitute/PacletPage)
