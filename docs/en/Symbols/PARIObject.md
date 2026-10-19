---
Template: Symbol
Name: PARIObject
Context: WolframInstitute`PARILink`
Paclet: WolframInstitute/PARILink
URI: WolframInstitute/PARILink/ref/PARIObject
Keywords: [GP, object, exact arithmetic]
SeeAlso: [PARICall, PARIEvaluate, PARISession]
RelatedGuides: [PARILink]
---

## Usage

`PARIObject[...]` represents a value retained in a PARI/GP session.

`object["property"]` gives a property of *object*.

## Details & Options

- Evaluation automatically retains values without a lossless Wolfram mapping.
  `"ReturnType" -> "Object"` explicitly retains the entire result.
- Properties are `"Type"`, `"Session"`, `"String"`, and `"Properties"`.
- `"Type"` is the GP type, such as `"t_POL"`. `"String"` requests GP's display text.
- `Normal[object]` copies a supported value; otherwise it returns a `Failure`.
- Exact integer, rational, complex, string, vector, and matrix values can be
  copied. Columns become lists and matrix results become lists of rows.
- Approximate values remain in GP to preserve their precision.
- `DeleteObject[object]` releases a retained value. Closing the session releases
  all its values. Released objects cannot be used again.
- Objects cannot be passed to another session or Wolfram kernel.
- `Normal` and `"String"` requests use a 30-second limit. Use `PARICall` with
  an explicit `TimeConstraint` for a computation that needs a different limit.

## Basic Examples

Retain a polynomial and compute its number-field discriminant:

```wl
WithCleanup[
 session = StartPARISession[],
 polynomial = PARIEvaluate[session, "x^3-x-1"];
 {polynomial["Type"], PARICall[session, "nfdisc", polynomial]},
 DeleteObject[session]
]
```

## Scope

Retain an elliptic curve over a finite field and count its points:

```wl
WithCleanup[
 session = StartPARISession[],
 curve = PARIEvaluate[session, "ellinit([0,0,0,-1,0],7)", "ReturnType" -> "Object"];
 PARICall[session, "ellcard", curve],
 DeleteObject[session]
]
```
