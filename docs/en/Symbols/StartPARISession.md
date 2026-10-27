---
Template: Symbol
Name: StartPARISession
Context: WolframInstitute`PARILink`
Paclet: WolframInstitute/PARILink
URI: WolframInstitute/PARILink/ref/StartPARISession
Keywords: [GP, session, process]
SeeAlso: [PARISession, PARICall, PARIEvaluate]
RelatedGuides: [PARILink]
---

## Usage

`StartPARISession[]` starts a PARI/GP process and returns a `PARISession`.

`StartPARISession["Executable" -> path]` uses the GP executable at *path*.

## Details & Options

- Requires Wolfram Language 15 or newer. Release paclets include GP 2.19.0.
- Loading the paclet does not start GP. Starting a session does not download or install software.
- With `"Executable" -> Automatic`, the search order is `PARILINK_GP`, the
  bundled GP, the executable search path, then common macOS installation locations.
- An explicit executable or environment override must exist; an invalid override returns a `Failure`.
- External GP installations must be version 2.17 or newer. They use their own data directory.
- `TimeConstraint -> 30` limits the startup handshake in seconds.
- `"StackLimit" -> 256 * 1024^2` sets the maximum stack size in bytes for GP's
  main thread and each parallel worker. It must be an integer of at least 8 MiB.
  Use a larger value for memory-intensive work.
- Startup ignores `.gprc`, disables terminal colors, and disables GP's break loop.
- Close a session with `DeleteObject[session]` to release its process and objects.
- Startup and option errors return a `Failure`.

## Basic Examples

Start a session and check its state, then close it:

```wl
WithCleanup[
 session = StartPARISession[],
 session["Status"],
 DeleteObject[session]
]
```
