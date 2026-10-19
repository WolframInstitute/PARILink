---
Template: Symbol
Name: PARICall
Context: WolframInstitute`PARILink`
Paclet: WolframInstitute/PARILink
URI: WolframInstitute/PARILink/ref/PARICall
Keywords: [GP, function, number theory]
SeeAlso: [StartPARISession, PARIEvaluate, PARIObject]
RelatedGuides: [PARILink]
---

## Usage

`PARICall[session, name, args]` calls the GP function *name* with arguments *args*.

## Details & Options

- *name* must be a GP identifier string. Use `PARIEvaluate` for source expressions.
- Integers, rationals, exact complex numbers, strings, and lists are supported
  arguments. `True` and `False` are sent as 1 and 0.
- A `PARIObject` can be passed only to its owning session.
- Lists become GP vectors. Nested lists do not implicitly become GP matrices.
- Approximate numbers and symbolic Wolfram expressions are unsupported inputs.
- Strings are transferred as UTF-8 data; embedded null characters are unsupported.
- `TimeConstraint -> 30` bounds an evaluation in seconds; `Infinity` removes it.
- `"ReturnType" -> Automatic` copies exact supported values. `"Object"` retains
  the entire result in GP; `"String"` returns its GP display text.
- `"Output" -> "Print"` forwards GP output. `"Capture"` returns `"Result"`,
  `"StandardOutput"`, and `"StandardError"`; `"Discard"` returns only the result.
- Errors return `Failure`. In capture mode, GP errors also contain the captured output.

## Basic Examples

Compute a factorization, a totient, and a quadratic class number:

```wl
WithCleanup[
 session = StartPARISession[],
 {PARICall[session, "factor", 360],
  PARICall[session, "eulerphi", 360],
  PARICall[session, "qfbclassno", -23]},
 DeleteObject[session]
]
```

## Scope

Preserve an exact complex number:

```wl
WithCleanup[
 session = StartPARISession[],
 PARICall[session, "conj", 1/3 + I/7],
 DeleteObject[session]
]
```
