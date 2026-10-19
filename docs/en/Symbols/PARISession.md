---
Template: Symbol
Name: PARISession
Context: WolframInstitute`PARILink`
Paclet: WolframInstitute/PARILink
URI: WolframInstitute/PARILink/ref/PARISession
Keywords: [GP, session, process]
SeeAlso: [StartPARISession, PARICall, PARIEvaluate, PARIObject]
RelatedGuides: [PARILink]
---

## Usage

`PARISession[...]` represents a running or closed PARI/GP session.

`session["property"]` gives a property of *session*.

## Details & Options

- Create sessions with `StartPARISession`, not by constructing the head directly.
- Properties are `"Status"`, `"Version"`, `"Executable"`, and `"Properties"`.
- Status is `"Ready"`, `"Busy"`, `"Stopped"`, or `"Closed"`.
- `DeleteObject[session]` closes a session and invalidates all of its objects.
  Repeated deletion of a known closed session returns `Null`.
- Sessions belong to the Wolfram kernel that created them. They cannot be
  transferred between kernels or restored from saved notebook output.
- Timeouts, interruptions, process exits, and malformed responses stop a session.
  Start a new session to continue after one of these failures.
- A normal GP evaluation error leaves the session usable.

## Basic Examples

Inspect a session's properties:

```wl
WithCleanup[
 session = StartPARISession[],
 session["Properties"],
 DeleteObject[session]
]
```
