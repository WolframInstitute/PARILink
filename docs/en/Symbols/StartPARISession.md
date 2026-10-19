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

- Requires PARI/GP 2.17 or newer and Wolfram Language 15 or newer.
- Loading the paclet does not start GP. The function does not install it.
- With `"Executable" -> Automatic`, `PARILINK_GP` takes precedence over the
  executable search path and common macOS installation locations.
- `TimeConstraint -> 30` limits the startup handshake in seconds.
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
