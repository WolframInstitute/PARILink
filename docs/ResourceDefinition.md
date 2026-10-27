---
Template: Paclet
ResourceType: Paclet
Name: WolframInstitute/PARILink
Context: WolframInstitute`PARILink`
Paclet: WolframInstitute/PARILink
Description: Connect Wolfram Language to PARI/GP for number theory
ContributedBy: Wolfram Institute
Keywords: [PARI, GP, number theory, exact arithmetic]
MainGuide: Documentation/English/Guides/PARILink.nb
License: MIT
WolframVersion: 15.0+
Categories: [Number Theory]
---

## Details & Options

- Includes PARI/GP 2.19.0 and its number-theory data; no separate GP installation is needed.
- Loading the paclet starts no process and installs nothing.
- Exact values are converted; other values remain in the owning GP session.
- Includes runtimes for Windows x86-64, macOS Intel and Apple Silicon, and Linux x86-64 and ARM64.
- PARI/GP, GMP, and their source and license files are included separately from PARILink's MIT-licensed code.

## Usage

[StartPARISession]() starts GP. [PARICall]() calls a named function with structured
arguments, and [PARIEvaluate]() evaluates GP source code. [PARISession]() owns
the process and its retained [PARIObject]() values.

## Basic Examples

Factor an integer and close the session:

```wl
WithCleanup[
 session = StartPARISession[],
 PARICall[session, "factor", 360],
 DeleteObject[session]
]
```
