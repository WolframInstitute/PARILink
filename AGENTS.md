# Repository rules

- Read `docs/architecture.md` before changing sessions, conversion, or builds.
- PARILink is independent of the projects that use it.
- Loading the paclet must not start GP, install software, or access the network.
- Keep process and protocol details out of the public API.
- Preserve exact values. Keep values without a lossless mapping in PARI.
- Never evaluate returned GP text as Wolfram Language code.
- Invalidate a session after a timeout, interruption, or malformed response.
- Keep tests requiring GP separate from tests that do not need it.
- Use plain prose in documentation, comments, and error descriptions.
- Use PacletPage for documentation and publishing, without a second release pipeline.
- Use `type(scope): short description` with a required scope and at most 72 characters. Keep each commit focused and include tests with behavior changes.
- Publish only from a matching release tag after CI passes. Use PacletPage's verified archive.
- Run `make all` and `make test-pari` for behavior changes. Update `CHANGELOG.md`.

## Wolfram code

Every Wolfram Language file follows the [coding guides](docs/coding-guides/README.md): the
kernel, the tests, the scripts and the programs under `tests/`. Read the coding guide, and
the page on how PARILink applies it, before you write code. The pre-commit hook and CI run
`make style` and refuse code that breaks a rule. The rules that matter most:

- Name arguments and local variables with full words that say what they hold.
- Write a usage message for every function and parameter, public or private.
- Give every argument a specific pattern. End every public function with
  `Name[___] := invalidArgumentsFailure[Name]`, and a predicate with `NameQ[___] := False`.
- Give a `Failure` through `Enclose` and a confirmation when a computation cannot finish.
  Keep PARILink's failure tags. Never give `$Failed`, and never use `Return`.
- Use `Module`, `Table`, `Map`, `Fold` and `NestWhile`. Do not write `For`, `Do`, `While`
  or `AppendTo`.
- Indent with tabs.

Work in this order:

1. Read the whole file and its tests. For a refactor, note every input form, result and
   message that callers and tests rely on.
2. Choose names, then write the usage messages, then the definitions.
3. Update the tests in the same change. Test the catch-all (`"InvalidArguments"`, with
   `Name::args` as the expected message) and a call that matches and fails.
4. Run the commands below until they report nothing.

```bash
make style-fix FILES="<files>"   # tabs, spacing, brackets, message strings
make style FILES="<files>"       # every rule the program can decide
make lint FILES="<files>"        # CodeInspector and the style check
make test FILES="<test files>"
```

The check cannot see a name that says nothing, a usage message that no longer matches the
patterns, or `==` between exact values. Read the code once more for those, with the
checklist at the end of the coding guide.

A refactor keeps behavior. Do not rename a public symbol, an option or a property without
a request. Waive a rule only where the guide's own exception applies, with
`(* allow RuleName: reason *)` on the line before.
