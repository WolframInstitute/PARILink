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

- Requires an existing PARI/GP 2.17 or newer installation. No runtime is bundled.
- Loading the paclet starts no process and installs nothing.
- Exact values are converted; other values remain in the owning GP session.
- Tested on Linux x86-64 and macOS ARM64 with GP 2.17.4 and 2.19.0.

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
