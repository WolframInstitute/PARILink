# PARILink

[![CI](https://github.com/WolframInstitute/PARILink/actions/workflows/ci.yml/badge.svg)](https://github.com/WolframInstitute/PARILink/actions/workflows/ci.yml)
[![Release](https://github.com/WolframInstitute/PARILink/actions/workflows/release.yml/badge.svg)](https://github.com/WolframInstitute/PARILink/actions/workflows/release.yml)

PARILink connects Wolfram Language to [PARI/GP](https://pari.math.u-bordeaux.fr/), a
system for number theory. Use GP's number fields, elliptic curves, modular forms and
L-functions from a Wolfram Language session.

## Install

PARILink needs Wolfram Language 15.0 or later on macOS 13 or later (Apple silicon or
Intel), Linux with glibc 2.35 or later (x86-64 or ARM64) or Windows 10 or later (x86-64).
The paclet includes GP and its number-theory data, so you do not need to install GP
yourself.

```wolfram
PacletInstall[
	ResourceObject[
		"https://www.wolframcloud.com/obj/wolframinstitute/" <>
			"DeployedResources/Paclet/WolframInstitute/PARILink"
	]["PacletFile"],
	ForceVersionInstall -> True,
	"ShowProgress" -> True
];
```

## Quick start

Start GP and factor an integer:

```wolfram
Needs["WolframInstitute`PARILink`"];
session = StartPARISession[];
PARICall[session, "factor", 360]
```

```wolfram
{{2, 3}, {3, 2}, {5, 1}}
```

A value without an exact Wolfram Language form stays in GP as a `PARIObject`, which later
calls can use. Count the points of an elliptic curve over the field with 101 elements:

```wolfram
curve = PARICall[session, "ellinit", {0, 0, 0, -1, 0}, 101, "ReturnType" -> "Object"];
PARICall[session, "ellcard", curve]
```

```wolfram
104
```

Close GP and release its objects:

```wolfram
DeleteObject[session];
```

## Documentation

- [Documentation site](https://www.wolframcloud.com/obj/wolframinstitute/PARILink):
  the guide and every function, with examples.
- [Paclet page](https://www.wolframcloud.com/obj/wolframinstitute/DeployedResources/Paclet/WolframInstitute/PARILink/index.html):
  the published resource.
- [Releases](https://github.com/WolframInstitute/PARILink/releases): the `.paclet` of each
  version, with checksums and the matching PARI and GMP sources.
  [CHANGELOG.md](CHANGELOG.md) lists the changes.
- [Compatibility](docs/compatibility.md): how the link compares with native GP on PARI's
  own test suites.

## Develop

`make help` lists the commands. `make all` checks the source and runs the tests that need
no GP; `make test-pari` runs the tests with GP.

| Read | For |
| --- | --- |
| [CONTRIBUTING.md](CONTRIBUTING.md) | requirements, loading a checkout, tests, runtime builds and releases |
| [docs/architecture.md](docs/architecture.md) | the design and the choices behind it |
| [docs/coding-guides/README.md](docs/coding-guides/README.md) | the Wolfram Language coding guides and the style check |
| [SECURITY.md](SECURITY.md) | reporting a vulnerability, and running GP code safely |
| [AGENTS.md](AGENTS.md) | instructions for coding agents |

## License

PARILink is free software under the [GNU General Public License](LICENSE), version 2 or
any later version, as PARI/GP is. See [COPYRIGHT](COPYRIGHT). Release paclets also contain
GP, GMP and the PARI data packages under their own licenses; see
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
