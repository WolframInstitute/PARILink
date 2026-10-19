# Third-party notices

PARILink's source release does not include a PARI/GP executable or library.
It runs an installation supplied by the user as a separate process.

[PARI/GP](https://pari.math.u-bordeaux.fr/) is distributed under the GNU General
Public License, version 2 or later. Its license and source are available from
the [PARI/GP project](https://pari.math.u-bordeaux.fr/download.html).

Development dependencies are fetched into the ignored `.deps/` directory.
They are not packaged in the runtime paclet:

- [PacletPage](https://github.com/WolframInstitute/PacletPage), MIT.
- [MarkdownToNotebook](https://github.com/WolframInstitute/MarkdownToNotebook).
- [WolframParser](https://github.com/sw1sh/WolframParser), MIT.
