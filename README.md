# PARILink

PARILink connects Wolfram Language to [PARI/GP](https://pari.math.u-bordeaux.fr/)
for number theory.

## Requirements

- Wolfram Language 15.0 or later
- PARI/GP 2.17 or later

Uses an existing GP installation. Tested on macOS Apple silicon with GP 2.17.4
and 2.19.0. See the [compatibility report](docs/compatibility.md).

## Load from source

```wolfram
PacletDirectoryLoad["/path/to/PARILink/PARILink"];
```

```wolfram
Needs["WolframInstitute`PARILink`"];
```

## Examples

Start GP:

```wolfram
session = StartPARISession[];
```

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

```bash
make all
```

```bash
make test-pari
```

Build and publishing instructions: [CONTRIBUTING.md](CONTRIBUTING.md).
Security reports: [SECURITY.md](SECURITY.md).

## License

PARILink code uses the [MIT License](LICENSE). PARI/GP is separately licensed;
see [third-party notices](THIRD_PARTY_NOTICES.md).
