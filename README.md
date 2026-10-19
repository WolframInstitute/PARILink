# PARILink

PARILink connects Wolfram Language to [PARI/GP](https://pari.math.u-bordeaux.fr/)
for number theory. It follows GAPLink's explicit sessions and retained objects,
with exact value conversion and a PacletPage documentation workflow.

This is an initial source release. It requires Wolfram Language 15 or newer
and an existing PARI/GP 2.17 or newer installation. Live tests currently cover
macOS ARM64 with GP 2.17.4. Platform runtime bundles and PureMath method dispatch
are future work.

## Use from source

Register the paclet directory in this checkout and load its context:

```wl
PacletDirectoryLoad["/path/to/PARILink/PARILink"];
Needs["WolframInstitute`PARILink`"];
```

Start a session, factor an integer, and compute a quadratic class number:

```wl
session = StartPARISession[];
PARICall[session, "factor", 360]
(* {{2, 3}, {3, 2}, {5, 1}} *)

PARICall[session, "qfbclassno", -23]
(* 3 *)
```

GP polynomials stay in their session and can be passed to further calls:

```wl
polynomial = PARIEvaluate[session, "x^3-x-1"];
PARICall[session, "nfdisc", polynomial]
(* -23 *)

DeleteObject[polynomial];
DeleteObject[session];
```

Loading PARILink starts no process and installs nothing. `StartPARISession[]`
finds `gp` through `PARILINK_GP`, the executable search path, or common macOS
installation locations. To select it explicitly, use
`StartPARISession["Executable" -> "/path/to/gp"]`.

## Values and errors

| Value | Behavior |
| --- | --- |
| Integers, rationals, exact complex numbers | Converted without rounding |
| Strings | UTF-8; embedded null characters are rejected |
| Wolfram lists | Sent as GP vectors, recursively |
| GP vectors, columns, lists, matrices | Copied as lists; matrix rows are preserved |
| Polynomials, modular values, approximate numbers, other types | Kept as `PARIObject` |

Use `"ReturnType" -> "Object"` to keep any result in GP, or
`"ReturnType" -> "String"` for its GP display text. `Normal[object]` copies a
supported value. Values without a lossless mapping return a `Failure`;
approximate values are never silently reduced to machine precision.
`object["String"]` gives GP's display text without parsing it as Wolfram code.

Copying preserves values, not GP type identity or column orientation. Lists
sent to GP remain vectors; use GP's `Mat` or retained objects for matrices.
Containers over 10,000 entries or 32 levels deep remain objects. Retained
objects belong to one session; release them with `DeleteObject` or close the
session to release them all.

Both evaluation functions accept `TimeConstraint -> 30` and
`"Output" -> "Print"`. Use `"Capture"` to get an association with `"Result"`,
`"StandardOutput"`, and `"StandardError"`, or `"Discard"` to suppress output.
GP errors return `Failure["PARIError", ...]` with `"PARIError"` and
`"PARIMessage"` details. Capture mode also attaches output to a failure.
A normal GP error leaves the session usable. A timeout, interruption, process
exit, malformed response, or response over the output limit stops it.

`PARICall` transfers arguments as data. `PARIEvaluate` executes GP source code
with the permissions of the GP process; use it only for code you intend to run.

## Development

```sh
make all          # source checks and tests without GP
make test-pari    # integration tests against the installed GP
make deps         # fetch pinned documentation tools
make build        # PacletPage builds docs and checks a local paclet archive
```

`make build` runs PacletPage in offline dry-run mode and does not publish.
Documentation examples require GP. Generated notebooks and archives are ignored
by Git. `make docs` builds only the documentation.

Publishing uses the same PacletPage pipeline:

```sh
PARILINK_PUBLISH_ACCOUNT=account@example.com make publish
```

This command publishes through the specified Wolfram Cloud account. No public
archive or PureMath installer entry is provided by this checkout yet.
See [the design](docs/architecture.md) and [contribution notes](CONTRIBUTING.md).

PARILink is MIT licensed. PARI/GP is separately licensed; see
[third-party notices](THIRD_PARTY_NOTICES.md).
