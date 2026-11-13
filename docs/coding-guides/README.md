# Coding guides

Three guides set the standard for Wolfram Language code in this repository.

| Guide | Governs |
| --- | --- |
| [WOLFRAMCODINGGUIDE.md](WOLFRAMCODINGGUIDE.md) | Names, usage messages, patterns, scoping, options, error handling, control flow, formatting and tests |
| [WOLFRAMVISUALIZATION.md](WOLFRAMVISUALIZATION.md) | Plots and other visual output |
| [MANIPULATEFUNCTIONCREATION.md](MANIPULATEFUNCTIONCREATION.md) | Building a `Manipulate` around a function that exists |

Read the coding guide before you write or change kernel code, a script, a program under
`tests/` or a test. PARILink has no plotting function and no `Manipulate` today. Read the
other two guides before you add one.

The three files are kept as received on 2026-11-13. Do not edit them here. When a new
version arrives, replace the files, run `make style`, and update this page where a rule
changed. `.gitattributes` leaves their whitespace alone, so the files stay byte for byte
as they came.

## How the repository applies the guides

The guides were written for any project. This section says how their rules apply here,
and what was decided where a guide leaves a choice.

### Arguments and failures

- **Catch-all.** Every public function ends with one definition for any other arguments:
  `Name[___] := invalidArgumentsFailure[Name]`. The helper issues the inherited message
  `Name::args` and gives `Failure["InvalidArguments", ...]`, as Rule 3 of the coding guide
  asks. The sequence has no name, because a named `args___` that is never used draws a
  lint warning. No file defines its own `::args` message.
- **Earlier failures stay.** A call that gave a `Failure` before the guides gives the same
  `Failure` now, with the same tag and data and without a message: an option that is not
  valid gives `"PARIInvalidOption"`, a session that is not known `"PARIInvalidSession"`, a
  function name that is not a GP identifier `"PARIInvalidFunction"`, and a value that
  cannot be sent `"PARIUnsupportedValue"`. Only a call that used to stay unevaluated, such
  as `PARIEvaluate[]` or `PARICall[session, 1]`, now gives the `"InvalidArguments"`
  failure. Do not turn one of the earlier failures into another, and do not add a message
  to it.
- **Session and object handles.** `PARISession[...]` and `PARIObject[...]` stay as they
  are: each is the handle of something that lives in GP. They have no definition, so they
  need no catch-all. A property request that is not one name, such as `session[1]`, gives
  the `"InvalidArguments"` failure.
- **Predicates.** PARILink has no public predicate. A helper whose name ends in `Q` ends
  with `nameQ[___] := False`.
- **Failed computations.** A call that matches a definition and then cannot finish gives
  a `Failure` through `Enclose` and a confirmation. PARILink keeps its own failure tags,
  such as `"PARITimeout"`. A helper builds the `Failure` with `pariFailure`, and the
  caller writes `Confirm[helper[...]]` inside `Enclose[..., innerFailure]`, which gives
  the helper's own `Failure` back. No function gives a bare `$Failed`.
- **Cost.** A request to GP takes milliseconds, so `Enclose` and `Confirm` cost nothing
  that shows. Keep them out of code that runs once for each element of a large value,
  such as the encoding of a long list.

### Names

- Arguments, pattern names and local variables have at least three letters and say what
  they hold: `timeConstraint`, `sessionID` and `objectData`, not `t`, `id` and `d`.
- The check does not look at iterator variables or the parameters of `Function`. Name
  those with words too.
- A file-level value starts with `$`, such as `$pariSessions`.
- Helpers start with `pari`. Helpers shared between files are declared with
  `PackageScoped`.
- Options that PARILink coins have string names, such as `"Executable"` and `"Output"`.
  Options that exist in the System context keep their symbols, such as `TimeConstraint`.
  The coding guide prefers symbols for new options. The names here are part of the public
  API, and a new option symbol would need a collision check, an export and a usage
  message.

### Code

- **`With`.** Use `Module` for computation. A `With` may hold one or two short constants
  in one list, or values that must be put into held code, such as the boxes that
  `MakeBoxes` gives.
- **`Part`.** A position computed from data is fine. A fixed position, such as
  `pair[[1]]`, is not: use a named pattern, `First`, `Last`, `Rest` or `Most`.
- **Equality.** Use `===` and `=!=` for exact values. Keep `==` for numbers that may be
  approximate. No program checks this; a reviewer does.
- **Loops.** Reading from GP until a response is complete is `NestWhile` over an explicit
  state: what was read, and whether the marker of the response has arrived.
- **`Quiet`.** Name the messages a computation is expected to give, as in
  `Quiet[..., {$CharacterEncoding::utf8}]`. A call that asks about the paclet, a file or a
  process, or uses the streams of a process, quiets every message with `Quiet[..., All]`:
  whatever it reports, the step did not work and the caller gets a `Failure`.
- **Width.** A line has at most 200 characters, and breaks near 150. A tab counts as
  four characters.

### Tests

- A paclet test file starts with `PacletDirectoryLoad[DirectoryName[$TestFileName, 2]]`
  and then `Needs`, so that `TestReport` can run the file alone. The number is the count
  of folders from the file up to the paclet folder: 2 in `PARILink/Tests`, 3 in
  `PARILink/Tests/Integration`. A file under `tests/` loads the scripts with
  `Get[FileNameJoin[{DirectoryName[$TestFileName, 2], "scripts", "run.wls"}]]["Load"]`.
- A test names a package-scoped helper in full, such as
  `` WolframInstitute`PARILink`PackageScope`pariEncode ``. A file that uses one helper
  many times may give it a short name at the top.
- In a test run, `LogError` and some other short names belong to the testing framework,
  which comes first on the context path. A test that stops a script step without logging
  an error replaces `` PARILink`Scripts`PackageScope`failTask ``.
- Each public function has a test of its catch-all, which expects the tag
  `"InvalidArguments"` and the message `Name::args`, and a test of a call that matches
  and fails, which expects the tag of that failure. The third identical message in one
  test brings `General::stop`, so keep to two invalid calls per test.
- Tests that need GP live in `PARILink/Tests/Integration`. All other tests run without
  GP.
- A test does not print.

### Scripts and programs

- The scripts are one package, `` PARILink`Scripts` ``, which `scripts/run.wls` loads.
  `scripts/project.wls` runs one command, and `scripts/commands.wl` lists the commands.
- A step that must hold is written `RequireOrLog[value, test, message]`. When it fails it
  logs an error and stops the command, and the script exits with status 1.
- Every exported command ends with the same catch-all as a public function.
- The programs under `tests/`, such as `tests/Installed.wls`, run on their own. They follow
  the same rules, and give a `Failure` through `Enclose` before they exit with status 1.

## How the rules are enforced

`make style` checks every Wolfram Language file in the kernel, the paclet tests, the
scripts and `tests/`. `make check` and `make lint` run the same check, so the pre-commit
hook and CI run it too. Each report names the rule, says what to do and cites the guide
section.

```bash
make style                                        # every file
make style FILES="PARILink/Kernel/Session.wl"
make style-fix FILES="..."                        # apply the mechanical fixes
```

`make style-fix` rewrites what a program can decide: tabs for indentation, spaces around
operators and after commas, comment spacing, closing brackets that should start a line,
statements that share a line, message strings with raw newlines or long lines, and the
first lines of a paclet test file. It writes a file only when the fixed text parses to
the same code.

The check cannot judge whether a name is clear, whether a usage message is true or
whether a pattern is as specific as it could be. A reviewer reads for those, with the
checklist at the end of the coding guide.

### Waiving a rule

A rule that needs judgment can be waived for one line with a comment on the line before
it, or on the same line:

```wolfram
(* allow BarePattern: node is any value that the JSON of a response can hold *)
```

The comment names one or more rules, then a colon, then the reason. A waiver without a
reason, for an unknown rule, for a rule that cannot be waived, or that waives nothing is
an error. The table below says which rules can be waived. Keep waivers rare: `make style`
counts them, and a reviewer reads each one.

Fix the code when the rule fits. A waiver is for the guide's own exceptions only:

- an argument that is truly any expression, such as a node of a response
  (`BarePattern`);
- a function for which every argument sequence is valid, such as one that logs its
  arguments (`MissingCatchAll`);
- a `With` that must put several values into held code (`WithBindings`);
- a name that only an internal context has, such as `Internal`InheritedBlock` in a test
  (`QualifiedSymbol`).

### Files not yet converted

Every file is converted. When a new version of a guide adds a rule, a file that cannot be
converted at once may be listed in `scripts/style-legacy.txt`, one repository path per
line. The check counts the issues of a listed file without reporting them. A listed file
with no issues must leave the list, so the list only shrinks.

## Rules

The table is the content of `$StyleRules` in `scripts/style.wl`. Write it again with
`make style-fix`, with no files named, after changing a rule. A test in `tests/Style.wlt`
fails when the table is out of date.

<!-- style-rules:start -->
| Rule | What to do | Source | Applies to | Can be waived |
| --- | --- | --- | --- | --- |
| `SyntaxError` | The file must parse. | coding guide | Kernel, Script, Program, Test, Data | no |
| `TabIndentation` | Indent with tabs, not spaces. | coding guide, Rule 13 | Kernel, Script, Program, Test, Data | no |
| `LineWidth` | Keep lines within 200 characters; break near 150. | coding guide, Rule 13 | Kernel, Script, Program, Test, Data | yes |
| `NonASCIICharacter` | Keep source ASCII: no em dashes, box-drawing characters or decorative arrows; write a character by its long name. | coding guide, non-negotiable rules | Kernel, Script, Program, Test, Data | no |
| `DoubleHyphen` | Use a hyphen, comma, colon or new sentence, not two hyphens as a dash. | coding guide, non-negotiable rules | Kernel, Script, Program, Test, Data | no |
| `CommentSpacing` | Put a space inside each end of a comment: (\* note \*). | coding guide, Rule 11 | Kernel, Script, Program, Test, Data | no |
| `NestedComment` | Keep comment delimiters out of a comment's text. | coding guide, Rule 11 | Kernel, Script, Program, Test, Data | no |
| `OperatorSpacing` | Put one space on each side of an infix operator; keep ? and :: tight. | coding guide, Rule 13 | Kernel, Script, Program, Test, Data | no |
| `CommaSpacing` | Put one space after a comma and none before it. | coding guide, Rule 13 | Kernel, Script, Program, Test, Data | no |
| `CommaPlacement` | End the line with the comma; never start a line with one. | coding guide, Rules 7 and 13 | Kernel, Script, Program, Test, Data | no |
| `SplitOperator` | Keep a binary operator and both operands on one line; name an intermediate value or use the head form, such as Or[...]. | coding guide, Rule 13 | Kernel, Script, Program, Test, Data | no |
| `StatementPerLine` | Write one statement per line: break after each semicolon. | coding guide, Rule 13 | Kernel, Script, Program, Test, Data | no |
| `HangingSemicolon` | Drop the semicolon before a comma or before the closing bracket of a scoping construct; it gives Null. | coding guide, Rule 13 | Kernel, Script, Program, Test | no |
| `TrailingSpan` | Do not end a line with ;;. | coding guide, Rule 13 | Kernel, Script, Program, Test, Data | no |
| `BracketAlignment` | Put the closing bracket of a multi-line expression on its own line, indented like the line that opens it. | coding guide, Rule 13 | Kernel, Script, Program, Test, Data | no |
| `StringLineBreak` | Do not break a string with a raw newline; end the line with \n\ for a new line of text, or with \ to wrap. | coding guide, Rule 2 | Kernel, Script, Program | no |
| `PostfixApplication` | Use prefix or full application, not postfix //. | coding guide, Rule 10 | Kernel, Script, Program, Test | no |
| `InfixApplication` | Write f[a, b], not a ~f~ b. | coding guide, Rule 10 | Kernel, Script, Program, Test | no |
| `PrefixApplication` | Do not apply @ to a parenthesized expression. | coding guide, Rule 10 | Kernel, Script, Program, Test | no |
| `NestedPureFunction` | Do not nest slot functions; write Function[variable, ...] or a named helper. | coding guide, Rule 10 | Kernel, Script, Program, Test | no |
| `HeadComparison` | Use MatchQ[expr, \_head], not a comparison with Head[expr]. | coding guide, Rule 7 | Kernel, Script, Program, Test | no |
| `ApplyAndOr` | Use And[...], Or[...], AllTrue, AnyTrue or NoneTrue, not And @@ or Or @@. | coding guide, Rule 8 | Kernel, Script, Program, Test | yes |
| `ReturnCall` | Do not use Return; let the value fall out, or use Confirm with Enclose. | coding guide, Rule 6 | Kernel, Script, Program, Test | no |
| `ProceduralLoop` | Do not write For, Do or While; use Table, Map, Scan, Fold, Nest or a relative. | coding guide, Rule 7 | Kernel, Script, Program, Test | no |
| `AppendTo` | Build the list with Table, Map, Fold or Reap, not AppendTo or PrependTo. | coding guide, Rule 9 | Kernel, Script, Program, Test | no |
| `ScopeConstruct` | Use Module, Block or With, not Scope or ModuleScope. | coding guide, Rule 4 | Kernel, Script, Program, Test | no |
| `WithBindings` | Use Module for computation; With is for one or two short constants, or for values injected into held code. | coding guide, Rule 4 | Kernel, Script, Program, Test | yes |
| `NestedWith` | Write nested With as one flat With[{a = ...}, {b = ...}, body]. | coding guide, Rule 4 | Kernel, Script, Program, Test | no |
| `UnusedLocal` | Remove a local variable that is never used. | coding guide, Rule 4 | Kernel, Script, Program, Test | no |
| `OptionalArgument` | Do not give a positional argument a default; add a downvalue for the shorter calling form. | coding guide, Rule 3 | Kernel, Script, Program, Test | no |
| `OptionQPattern` | Take options with opts : OptionsPattern[], not \_\_\_?OptionQ. | coding guide, Rule 3 | Kernel, Script, Program, Test | no |
| `UntaggedControl` | Give Quiet the messages it expects, and Catch, Throw, Sow and Reap a tag. | coding guide, Rule 8 | Kernel, Script, Program, Test | no |
| `PartLiteral` | Do not reach into an expression by a fixed position; use a named pattern, First, Last, Rest or Most. | coding guide, Rule 13 | Kernel, Script, Program, Test | yes |
| `BareFailed` | Give a Failure object, not a bare $Failed. | coding guide, Rule 6 | Kernel, Script, Program | yes |
| `OptionValueTest` | Wrap a Boolean option in TrueQ, or validate it with ConfirmMatch, before testing it. | coding guide, Rule 5 | Kernel, Script, Program, Test | no |
| `ClearAtLoad` | Do not Clear, ClearAll or Remove symbols when a file loads. | coding guide, things to avoid | Kernel, Script | no |
| `QualifiedSymbol` | Import the context and use the short name; do not use internal contexts. | coding guide, Rule 14 | Kernel, Script, Program, Test | yes |
| `ShortName` | Name arguments and local variables with full words of at least three letters that say what they hold. | coding guide, Rule 1 | Kernel, Script, Program, Test | no |
| `LocalShadowsFunction` | Do not give an argument or local variable the name of a function in this codebase. | coding guide, Rule 1 | Kernel, Script | no |
| `SystemNameCollision` | Do not define or export a name that System already has. | coding guide, Rule 1 | Kernel, Script | no |
| `ParameterName` | Start the name of a file-level parameter with $. | coding guide, Rule 1 | Kernel, Script | no |
| `MissingUsage` | Give every function and parameter a usage message, public or private. | coding guide, Rule 2 | Kernel, Script | no |
| `UsageFormat` | Start a usage message with the calling template, then say what it gives. | coding guide, Rule 2 | Kernel, Script | no |
| `OwnArgsMessage` | Do not define ::args; every symbol inherits the generic message. | coding guide, Rule 3 | Kernel, Script | no |
| `MissingCatchAll` | End a public function with a catch-all that gives a Failure; a predicate ends with [\_\_\_] := False. | coding guide, Rule 3 | Kernel, Script | yes |
| `BarePattern` | Give each argument a specific pattern, not a bare blank; only a helper's fallback definition may take any argument. | coding guide, Rule 3 | Kernel, Script | yes |
| `HardCodedColor` | Use a Standard color for data and a LightDarkSwitched pair for other colors; never pin a white or black background. | coding guide, non-negotiable rules; visualization guide, Color | Kernel | yes |
| `CrossingAxes` | Frame the plot: use Frame, FrameLabel and FrameTicks, not Axes, AxesLabel and Ticks. | visualization guide, Frame Every Plot | Kernel | yes |
| `UnframedPlot` | Give a plot with quantitative axes Frame -> True and Axes -> False. | visualization guide, Frame Every Plot | Kernel | yes |
| `TestHeader` | Load the paclet with PacletDirectoryLoad[DirectoryName[$TestFileName, n]], then Needs, so that a test file runs on its own. | coding guide, Rule 15 | Test | no |
| `TestPrint` | Do not Print in a test file. | coding guide, Rule 15 | Test | no |
| `MissingTestID` | Give every VerificationTest a TestID. | coding guide, Rule 15 | Test | no |
| `UnknownAllow` | An allow comment names a rule that exists and can be waived, and gives a reason. | coding guides page, Waiving a rule | Kernel, Script, Program, Test, Data | no |
| `UnusedAllow` | Remove an allow comment that waives nothing. | coding guides page, Waiving a rule | Kernel, Script, Program, Test, Data | no |
<!-- style-rules:end -->
