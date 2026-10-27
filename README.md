# PARILink

[![CI](https://github.com/WolframInstitute/PARILink/actions/workflows/ci.yml/badge.svg)](https://github.com/WolframInstitute/PARILink/actions/workflows/ci.yml)
[![Release](https://github.com/WolframInstitute/PARILink/actions/workflows/release.yml/badge.svg)](https://github.com/WolframInstitute/PARILink/actions/workflows/release.yml)

PARILink connects Wolfram Language to [PARI/GP](https://pari.math.u-bordeaux.fr/)
for number theory.

[Documentation](https://www.wolframcloud.com/obj/wolframinstitute/PARILink)
· [Cloud resource](https://www.wolframcloud.com/obj/wolframinstitute/DeployedResources/Paclet/WolframInstitute/PARILink/index.html)
· [Releases](https://github.com/WolframInstitute/PARILink/releases)

## Requirements

- Wolfram Language 15.0 or later

The paclet includes PARI/GP 2.19.0 and its number-theory
data. No separate GP installation is needed.

| System | Processors |
| --- | --- |
| macOS 13 or later | Apple Silicon, Intel |
| Linux with glibc 2.35 or later | ARM64, x86-64 |
| Windows 10 or later | x86-64 |

Version 0.1.0 requires a separate GP installation. See the
[compatibility report](docs/compatibility.md) for function coverage.

## Install

Install the latest release from Wolfram Cloud:

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

Versioned paclets and SHA-256 checksums are also on
[GitHub Releases](https://github.com/WolframInstitute/PARILink/releases).

Load the package:

```wolfram
Needs["WolframInstitute`PARILink`"];
```

## Examples

Start GP:

```wolfram
session = StartPARISession[];
```

To use your own GP 2.17 or later, set `"Executable" -> "/path/to/gp"` when
starting a session, or set the `PARILINK_GP` environment variable.

Find the Galois group of a quintic:

```wolfram
polynomial = PARIEvaluate[session, "x^5 - x - 1"];
```

```wolfram
Last[PARICall[session, "polgalois", polynomial]]
```

Returns `"S5"`, the symmetric group on five letters.

Count points on an elliptic curve over the field with 101 elements:

```wolfram
curve = PARICall[session, "ellinit", {0, 0, 0, -1, 0}, 101,
	"ReturnType" -> "Object"];
```

```wolfram
PARICall[session, "ellcard", curve]
```

Returns `104`, including the point at infinity.

Compute Fourier coefficients of a weight 2, level 11 newform:

```wolfram
form = PARIEvaluate[session, "mfeigenbasis(mfinit([11,2],0))[1]",
	"ReturnType" -> "Object"];
```

```wolfram
PARICall[session, "mfcoefs", form, 10]
```

Returns `{0, 1, -2, -1, 2, 1, 2, -2, 0, -2, -2}` (degrees 0 through 10).

Close GP and release its objects:

```wolfram
DeleteObject[session];
```

## Values

| GP result | Wolfram Language result |
| --- | --- |
| Integers, rationals, exact complex numbers, strings | Copied values |
| Vectors and matrices | Lists |
| Other values | `PARIObject` |

Use `"ReturnType" -> "Object"` to reuse a GP structure in later calls.
`Normal[object]` copies a supported retained value. Mutable lists and maps
remain objects; copy their contents with `Vec` or `Mat`.

## Errors

- GP evaluation errors return `Failure` and leave the session usable.
- Timeouts, interruptions, and lost connections stop the session.

See [PARICall](docs/en/Symbols/PARICall.md) for time limits and output options.

## Development

To use a source checkout, load its paclet directory before `Needs`:

```wolfram
PacletDirectoryLoad["/path/to/PARILink/PARILink"];
```

```bash
make all
```

```bash
make test-pari
```

Build the bundled runtime for local development:

```bash
make runtime stage-runtime
```

Build and publishing instructions: [CONTRIBUTING.md](CONTRIBUTING.md).
Security reports: [SECURITY.md](SECURITY.md).

## License

PARILink code uses the [MIT License](LICENSE). PARI/GP is separately licensed;
see [third-party notices](THIRD_PARTY_NOTICES.md).
