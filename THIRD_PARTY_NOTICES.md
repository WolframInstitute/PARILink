# Third-party notices

PARILink's Wolfram Language code uses the MIT License. Its bundled GP program
runs as a separate process and has its own licenses.

[PARI/GP](https://pari.math.u-bordeaux.fr/) is distributed under the GNU General
Public License, version 2 or later. The bundle includes GP 2.19.0 and the
`elldata`, `galpol`, `galdata`, `seadata`, and `nflistdata` packages. These data
packages are also distributed by the PARI group under GPL version 2 or later.

[GMP 6.3.0](https://gmplib.org/) is linked into GP and distributed here under
its GPL version 2 or later option. Its LGPL version 3 or later option is also
described in the included license files.

Windows builds include MinGW-w64 runtime code and winpthreads (permissive
licenses), and GCC runtime code under the GCC Runtime Library Exception.
Their notices accompany the Windows executable.

Each platform's license files are under `Resources/Runtime/<SystemID>/licenses/`.
The matching PARI and GMP source archives and build scripts are included in
`Resources/Runtime/Sources/`. The uncompressed data files are under
`Resources/Runtime/data/`; their original download hashes are recorded in
`data-sources.json`. GitHub releases also attach `PARILink-runtime-sources.tar.gz`,
containing the original sources, data archives, and build scripts.

To rebuild from the paclet's sources, copy the three scripts into a `scripts/`
directory and the two source archives into `build/runtime-sources/`, then run
`bash scripts/build-runtime.sh`. Windows builds use the MSYS2 UCRT64 toolchain;
the installed compiler and package versions are recorded with that runtime.

Development dependencies are fetched into the ignored `.deps/` directory.
They are not packaged in the runtime paclet:

- [PacletPage](https://github.com/WolframInstitute/PacletPage), MIT.
- [MarkdownToNotebook](https://github.com/WolframInstitute/MarkdownToNotebook).
- [WolframParser](https://github.com/sw1sh/WolframParser), MIT.
