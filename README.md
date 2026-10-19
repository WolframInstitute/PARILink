# PARILink

PARILink connects Wolfram Language to [PARI/GP](https://pari.math.u-bordeaux.fr/)
for number theory.

## Requirements

- Wolfram Language 15.0 or later
- PARI/GP 2.17 or later

Uses an existing GP installation. Tested on macOS Apple silicon with GP 2.17.4.

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

Factor an integer:

```wolfram
PARICall[session, "factor", 360]
```

Returns `{{2, 3}, {3, 2}, {5, 1}}`.

Compute a quadratic class number:

```wolfram
PARICall[session, "qfbclassno", -23]
```

Returns `3`.

Retain a polynomial:

```wolfram
polynomial = PARIEvaluate[session, "x^3 - x - 1"];
```

Compute its number-field discriminant:

```wolfram
PARICall[session, "nfdisc", polynomial]
```

Returns `-23`.

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

`Normal[object]` copies a supported retained value.

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
