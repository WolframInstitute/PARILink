# Contributing

Read [AGENTS.md](AGENTS.md) and [the design](docs/architecture.md) before editing.

The paclet lives in `PARILink/`. Its public API has five symbols; process and
protocol code belongs under `Kernel/Internal/`. GP's bridge is the resource
`Resources/GP/startup.gp`. Keep it independent of PureMath.

Use tabs in Wolfram Language, short usage messages, and exact conversions.
Return meaningful `Failure` values and retain values without a lossless
mapping. New conversion code must never evaluate returned text as Wolfram code.

Run `make all` and `make test-pari` after behavior changes. Tests in
`PARILink/Tests/` need no GP; `Tests/Integration/` uses a real executable and
must exercise process lifetime and recovery. Release every process and retained
object created by examples and tests.

Author documentation in `docs/en/`. Each public symbol needs a reference page
and guide entry. Use double-backtick Markdown delimiters around inline Wolfram
context names. `make deps` fetches pinned build tools; `make build` uses
PacletPage to evaluate examples, build notebooks, and check the archive. Do not
add separate archive, HTML, or cloud upload scripts.

Update `CHANGELOG.md` when behavior changes. A distributable runtime needs
platform verification and PARI/GP's license and corresponding source before
PureMath can advertise it as installable.
