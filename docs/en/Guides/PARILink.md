---
Template: Guide
Name: PARILink
Title: PARI/GP Number Theory
Context: WolframInstitute`PARILink`
Paclet: WolframInstitute/PARILink
URI: WolframInstitute/PARILink/guide/PARILink
Keywords: [PARI, GP, number theory]
---

## Abstract

PARILink connects Wolfram Language to PARI/GP. The paclet includes GP 2.19.0
and its number-theory data. An external GP 2.17 or newer can also be selected.
Explicit sessions support factorization, number fields, elliptic curves, and
other GP computations. Exact values can be copied; other values remain in GP.

## Functions

- `StartPARISession` starts a GP process.
- `PARISession` represents a session and its process lifetime.
- `PARICall` calls a named GP function with structured arguments.
- `PARIEvaluate` evaluates GP source code.
- `PARIObject` retains a GP value for further computation.
