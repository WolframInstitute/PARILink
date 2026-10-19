---
Template: Symbol
Name: PARIEvaluate
Context: WolframInstitute`PARILink`
Paclet: WolframInstitute/PARILink
URI: WolframInstitute/PARILink/ref/PARIEvaluate
Keywords: [GP, evaluation, number theory]
SeeAlso: [PARICall, StartPARISession, PARIObject]
RelatedGuides: [PARILink]
---

## Usage

`PARIEvaluate[session, code]` evaluates the GP source string *code* in *session*.

## Details & Options

- *code* is GP source, not Wolfram Language source.
- Definitions and GP settings persist in the session.
- This executes code with the GP process's permissions. Use `PARICall` to
  transfer data arguments without interpolating them into source code.
- Options are the same as `PARICall`: `TimeConstraint`, `"ReturnType"`, and `"Output"`.
- Exact supported values are copied. Other values are retained as `PARIObject`.
- A GP error returns `Failure["PARIError", ...]` with `"PARIError"` and
  `"PARIMessage"` details. The session remains usable after a normal GP error.
- A timeout or loss of synchronization stops the session and invalidates its objects.

## Basic Examples

Find the class number of a quadratic number field:

```wl
WithCleanup[
 session = StartPARISession[],
 PARIEvaluate[session, "bnfinit(x^2+23).no"],
 DeleteObject[session]
]
```

## Options

Capture printed output separately from the result:

```wl
WithCleanup[
 session = StartPARISession[],
 PARIEvaluate[session, "print(\"working\");2+3", "Output" -> "Capture"],
 DeleteObject[session]
]
```
