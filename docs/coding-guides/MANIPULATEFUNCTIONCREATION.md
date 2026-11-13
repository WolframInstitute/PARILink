# Manipulate Function Creation

The following detailed instructions define a task, not a self-contained style guide: they tell an LLM how to take one or more existing, standalone Wolfram Language functions and build from them a `Manipulate[...]` interactive that lets a user explore those functions' arguments and options with controls. Here the functions already exist and the `Manipulate` is the deliverable. These instructions assume that a separate body of Wolfram Language coding conventions and refactoring guidance (@WOLFRAMCODINGGUIDE.md), and a separate body of visualization styling guidance (@WOLFRAMVISUALIZATION.md), are provided elsewhere, and that all of these may reach the LLM concatenated together into one larger prompt rather than as separate files. Below, these are referred to simply as "the coding conventions" (naming, patterns, error handling, options, tests, and code formatting rules, including numbered "Rule N" references) and "the visualization guidance" (styling, titling, labeling, legend, font, and color rules). What follows restates neither, apart from the few rules this task needs stated in full (such as the label rule in Stage 5); it explains how to apply them to the specific problem of wrapping an existing function in a `Manipulate`, and assumes both are present in the LLM's context alongside it.

**The deliverable is a function that returns the `Manipulate`, and that function is deliverable-quality code in the full sense @WOLFRAMCODINGGUIDE.md defines.** A bare `Manipulate[...]` expression typed into a notebook cell is not reusable: it cannot be called from a package, cannot take options, and cannot be tested. The deliverable is therefore an *explorer function*, a public function whose result is the `Manipulate`, written under the coding conventions' "Writing New Code" methodology: naming (Rule 1), usage messages (Rule 2), specific patterns and the required catch-all fall-through (Rule 3), scoping (Rule 4), options handling (Rule 5), bulletproofing via `Confirm`/`Enclose` (Rule 6), functional control flow (Rule 7), no mutation (Rule 9), composition and style (Rules 10-13), and tests (Rule 15), including the coding conventions' Code Quality Checklist and its non-negotiable rules (no em dashes, no box-drawing or decorative-arrow characters, dark-mode-safe colors).

---

## Core Concept: A Manipulate Is a Function Call with Controls Attached

The body of a `Manipulate`, with its controls held fixed, is just the body of a function whose arguments are the control variables. Creating a `Manipulate` runs that observation backwards. Given a function

```wl
f[u1_, u2_, ..., opts : OptionsPattern[]]
```

the `Manipulate` that explores it is

```wl
Manipulate[
	f[u1, u2, ..., someOption -> u3],
	{{u1, u1Initial, "Label 1"}, u1Min, u1Max},
	{{u2, u2Initial, "Label 2"}, u2Min, u2Max},
	{{u3, u3Initial, "Label 3"}, {value1, value2, ...}}
]
```

The function does all the computing; the `Manipulate` contributes only the controls, their ranges and initial values, and the interactive surface. Everything in these instructions follows from keeping that division of labor clean: the `Manipulate` body is a single call to the provided function, and the work of this task is choosing, for each argument and option, whether it becomes a control, and if so what kind of control, over what range, starting where, with what label.

---

## The Governing Constraints

These constraints override any convenience elsewhere in these instructions.

1. **The body is a call, never a reimplementation.** The `Manipulate` body calls the provided function. It never copies, inlines, or "simplifies" the function's own body, and never re-derives part of its computation alongside it. If the function cannot do what the interactive needs (it lacks an option, or it computes something the interactive must vary that it does not expose), that is a gap in the function, reported as a question or fixed in the function itself under the coding conventions, not patched over inside the `Manipulate`.
2. **Every control maps to something the function actually accepts.** A control's value reaches the function either as a positional argument the function's patterns accept, or as an option the function declares in `Options[f]`. Passing an option the function does not declare does not silently do nothing; with an `OptionsPattern[]`-based function it fires `OptionValue::nodef` on every evaluation. Check `Options[f]` before wiring any option to a control.
3. **The initial state reproduces the function's own defaults.** With every control at its initial value, the `Manipulate` must display exactly what the function returns when called with those argument values and no options. Every option-backed control's initial value is that option's default from `Options[f]`, not a value that merely looked nicer; a deliberate departure is allowed only with a stated reason in the design note.
4. **Every option the function accepts stays reachable.** The explorer function must let a caller fix, at call time, any option the wrapped function accepts, not just the ones turned into controls, so that `fooExplorer[PlotStyle -> StandardRed]` explores `foo` with that style held fixed. It is satisfied by splicing the wrapped function's option set into the explorer's own (Stage 6).

Before delivering, check the explorer against these four constraints directly, independent of the stage-by-stage methodology.

---

## Inputs You Will Receive

- One or more Wolfram Language function definitions, ideally with usage messages and `Options[...]` declarations. The most useful usage messages carry exactly the information this task needs: documented typical ranges for each argument, the meaning and default of each option, and example calls.
- (Optional) A description of what the user wants to explore: which parameters matter, what audience the interactive is for, what ranges are interesting.
- (Optional) Context: whether the functions live in a paclet (and its context name), where the explorer function will live, and whether the resulting `Manipulate` must work in a notebook opened in a fresh kernel, in the Wolfram Cloud, or in a CDF/Player environment.

## Output You Must Produce

1. **The explorer function**: a public function, conforming to the coding conventions, whose result is the `Manipulate`. Its own options include every option of the wrapped function (as fixed, non-manipulated settings), a declared `SaveDefinitions` option, and a single `"ManipulateOptions"` option for all other panel-level settings; it checks that every `.wl`-loaded dependency is defined before building the `Manipulate` (Stage 6).
2. A **control mapping table**: for every argument and option of the wrapped function, whether it became a control (and which control type, range, step, initial value, and label), a fixed explorer option, or an explorer argument, and why.
3. A concise **design note**: the explorer boundary decision (Stage 2), every range and initial value and where it came from, performance measures taken (Stage 7), how definitions reach a fresh kernel (Stage 9), and any visualization corrections.
4. A **detailed usage message** for the explorer function, documenting its dependencies (every function, `.wl` file, and paclet that must be loaded before it is called), every control (label, range, initial value, step), and every option, with several example calls (Stage 11).
5. **Tests** (Stage 12), in a test file that loads exactly the dependencies the usage message lists: the explorer returns a `Manipulate`; a corner sweep of the wrapped function over every control's extremes and initial value produces no `Failure` and no message; fixed options pass through; `SaveDefinitions` reaches the `Manipulate` and rejects a non-boolean value; a misspelled panel setting returns a `Failure` naming it; calling the explorer before a dependency is loaded returns a `Failure`; and the two scope-boundary cases the coding conventions require.
6. Targeted questions for any genuine ambiguity: a positional argument with no documented range and no obvious domain, an option whose valid values cannot be determined, a function too slow to explore interactively at any reasonable setting.

---

## Methodology

### Stage 1: Inventory the Function

Read everything the function exposes before deciding anything:

- **Calling forms**: every `DownValues` pattern. Note each argument's pattern (`_?NumericQ`, `_Integer?Positive`, `_String`, `{_?NumericQ, _?NumericQ}`, `True | False`, ...), because the pattern decides the control type (Stage 3) and constrains the range (Stage 4). Note the catch-all fall-through, which is what the `Manipulate` will display if a control ever produces a value the patterns reject.
- **Options**: `Options[f]`. Separate the options the function itself declares or corrects (listed before any spliced-in `Options[Inner]`) from the large pass-through set it inherits from an inner function; only the former are normally candidates for controls.
- **Usage message**: documented typical ranges ("`frequency` is typically between 0.1 and 5"), option meanings, and example calls. These are the primary source for ranges and initial values in Stage 4.
- **Output type**: evaluate a representative call and note its head. `Graphics`, `Graphics3D`, `Legended[Graphics[...], ...]`, `Grid`, `Labeled`, a number, a formula. The output type governs `Locator` behavior, plot-range stability (Stage 7), and whether 3D rotation is preserved across updates.
- **Cost**: time a call at representative and extreme argument values with `RepeatedTiming` (or `AbsoluteTiming` for slow calls). The cost governs every performance decision in Stage 7.
- **Dependencies**: the function's context, whether it is defined in a paclet, a `.wl` file, or a notebook, and what helper symbols and data it relies on. This governs Stage 9.

Flag anything genuinely unclear as a question rather than guessing silently.

### Stage 2: Decide the Explorer Boundary and What Becomes a Control

Decide what the interactive explores:

- **One function**: one explorer.
- **A family of per-panel functions plus a combining function**: wrap the combining function, so a single set of controls drives every panel. Where a small auxiliary view of one panel helps the user read the controls, it may instead be placed in the control area as a `Dynamic[...]` annotation next to the controls it depends on (see "Dynamic Objects in the Control Area" in the Advanced Manipulate Functionality tutorial), but the main content area remains a single call.
- **Several unrelated functions**: separate explorers. Do not combine unrelated functions into one `Manipulate` behind a popup that switches between them; that is several interactives sharing a frame, not one.

Then classify every argument and option of the wrapped function into exactly one of three roles:

- **Control**: a scalar or small-structure value the user benefits from varying continuously or by choice: every positional numeric, boolean, enumerated, color, or point argument, and the handful of options the function itself declares that change what the figure shows.
- **Explorer argument**: a value the user supplies once and does not vary interactively, typically data (a list of points, a dataset, a string of text, an image, a graph). These become positional arguments of the explorer function and are injected into the held `Manipulate` body (Stage 6). A data argument is never turned into a `Locator` cloud or an `InputField` just because the function takes it positionally, unless the purpose of the interactive is precisely to edit that data.
- **Fixed explorer option**: everything else. The whole pass-through option set of an inner function (`Options[Plot]`'s dozens of options) is never turned into controls; it stays reachable as fixed explorer options (Governing Constraint 4).

Prefer few controls. Each control should correspond to a question a user would actually ask of the figure; a `Manipulate` with twenty sliders is a parameter dump, not an explanation.

### Stage 3: Map Each Argument Pattern to a Control Specification

The control type follows from the set of values the argument accepts. `Manipulate` chooses a control automatically from the form of the specification; override it with `ControlType` (inside the specification, `{u, ..., ControlType -> type}`, or as the shorthand `{u, ..., type}`) only when the automatic choice is wrong for the purpose.

| Argument accepts | Control specification | Control produced |
| --- | --- | --- |
| A real number (`_?NumericQ`, `_Real`) | `{{u, init, "Label"}, min, max}` | Manipulator (slider with value and animation panel) |
| An integer (`_Integer`) | `{{u, init, "Label"}, min, max, 1}` | Discrete manipulator, step 1 |
| An exact rational in a fixed lattice | `{{u, init, "Label"}, min, max, step}` with exact `min` and `step` | Discrete manipulator producing exact rationals |
| `True` or `False` (a boolean option tested with `TrueQ`) | `{{u, init, "Label"}, {True, False}}` | Checkbox |
| One of a small fixed set (an enumerated option such as `Filling`, a choice of function) | `{{u, init, "Label"}, {v1 -> "Label 1", v2 -> "Label 2", ...}}` | Setter bar for few elements, popup menu for more |
| A color | `{{u, StandardBlue, "Label"}, StandardBlue}` or `{..., ColorSetter}` | Color slider, or color setter swatch |
| A point `{x, y}` in a free 2D range | `{{u, {x0, y0}, "Label"}, {xMin, yMin}, {xMax, yMax}}` | 2D slider |
| A point `{x, y}` in the coordinates of the output graphic | `{{u, {x0, y0}}, Locator}` | Draggable locator in the graphic |
| A list of points in the output graphic | `{{u, {{x1, y1}, ...}}, Locator}`, optionally `LocatorAutoCreate -> True` | One locator per point; with `LocatorAutoCreate`, points can be added and deleted |
| An interval `{low, high}` | `{{u, {low0, high0}, "Label"}, min, max, ControlType -> IntervalSlider}` | Interval slider |
| A string | `{{u, "initial text", "Label"}}` | Input field |
| A value with no natural control | `{{u, init, "Label"}, ControlType -> InputField}` | Input field accepting an expression; use only when nothing better fits |

Points to observe while mapping:

- **An integer argument must get an explicit step.** Without a step, a slider produces real numbers between integers (7.34...), every one of which fails an `_Integer` pattern and lands in the function's catch-all fall-through, so the pane shows a `Failure` almost everywhere along the slider. The step `1` is what makes `Manipulate` behave like `Table` here.
- **The range endpoints must satisfy the pattern.** A slider `{u, 0, 3}` on an argument `u_?Positive` reaches `0` at its left end, which the pattern rejects. Start the range at the smallest value the pattern accepts and the computation supports.
- **`Locator` coordinates refer to the first graphic in the output**, or run from 0 to 1 across the whole output when there is no graphic. Use a `Locator` control only when the function returns a graphic whose coordinate system is the one the point lives in; wrap-only outputs such as `Legended[Graphics[...], ...]` keep the graphic first and work, while a `Grid` of several graphics makes the mapping ambiguous. A `Locator` needs an initial value; its range can be taken from the graphic or given explicitly as `{{u, init}, {xMin, yMin}, {xMax, yMax}, Locator}`.
- **Only one multipoint `Locator` per `Manipulate`.** A `Manipulate` may have any number of single-point `Locator` controls, or exactly one whose value is a list of points, never both; mixing them generates a warning.
- **Discrete choices carry labels in the specification**, `{v1 -> "Label 1", ...}`, so the control shows words rather than raw symbols (`Axis`, `Bottom`) or function heads (`Sin`, `Cos`), and those labels follow the label rule in Stage 5.
- **One variable may have two linked controls** (`{u, {list}}` and `{u, min, max}` together give a popup and a slider driving the same value). Use this only when both access styles are genuinely useful.

### Stage 4: Choose Ranges, Initial Values, and Steps

For every control, choose its range from the first of these sources that applies, and record which one in the mapping table:

1. **The function's usage message.** A documented typical range ("`amplitude` is typically between 0 and 3") is exactly the range the function's author intended a user to explore. When a function was written from an earlier interactive, its documented range is usually that interactive's slider range, so using it restores the original.
2. **The argument's pattern or documented domain.** A probability in `[0, 1]`, a positive count, an index bounded by the length of a data argument.
3. **Domain knowledge** of what the function computes: a phase over one period `{0, 2 Pi}`, a frequency range that shows a handful of cycles over the plotted interval, a sample count whose upper end still evaluates quickly (Stage 7).
4. **None of the above**: ask a targeted question rather than inventing a range.

Initial values:

- An option-backed control starts at the option's default from `Options[f]` (Governing Constraint 3).
- A positional-argument control starts at the value used in the usage message's first example call, or failing that at a representative value inside the range.
- **The initial state must show something meaningful.** A `Manipulate` whose initial values produce an empty or degenerate figure (a Lissajous figure with both amplitudes at their default left-hand value of zero, a polygon with coincident vertices) tells the user nothing until they guess which slider to move. Never accept `Manipulate`'s implicit default of starting at `min` without checking what it shows; give every control an explicit initial value via `{{u, init, "Label"}, ...}`.

Interdependent controls, where one control's valid range depends on another (an index `k` that must not exceed a count `n`):

- Make the dependent range refer to the other control: `{{k, 1, "Index"}, 1, n, 1}`. `Manipulate` then narrows the slider as `n` changes.
- `Manipulate` deliberately does not reset `k` when `n` drops below it; the slider shows an out-of-range indicator and `k` keeps its old value. Clamp the value at the call rather than assigning to the control variable: `f[n, Min[k, n]]`. An assignment such as `If[k > n, k = n]` inside the body works, but it mutates a tracked variable during evaluation and retriggers the update (see Stage 8); the clamp is side-effect-free.
- If the function itself validates the relationship with `Confirm` and returns a `Failure` on violation, the clamp is what keeps that `Failure` from ever reaching the pane during normal use.

### Stage 5: Name and Label

- **Name the explorer for what it explores**: `<FunctionName>Explorer` (`PlotSinusoidExplorer`), checked against ``NameQ["System`" <> name]`` per the coding conventions' naming rule.
- **Name control variables with descriptive `lowerCamelCase` names, matching the wrapped function's own parameter names** (`amplitude`, `frequency`, `sampleCount`), never single letters. Control variables are localized by `Manipulate` (it builds a `DynamicModule` with them as local variables), so descriptive names cost nothing, and they make the body read as the function call it is.
- **Do not reuse a name the explorer itself binds.** The explorer injects values into the held `Manipulate` body with `With` (Stage 6), and `With` substitutes lexically: a control variable that shares a name with one of the explorer's own pattern variables or `With` bindings is replaced before `Manipulate` ever sees it.
- **Give every control an explicit label**, the third element of `{{u, init, "Label"}, ...}`. Without one, `Manipulate` labels the control with the bare variable name. Label text uses plain words rather than a code identifier (a variable named `stringlength` is labeled "String Length", never "stringlength"); is put in Title Case by passing it through `Capitalize[label, "TitleCase"]` as the final step (there is no bare `TitleCase` function), which also normalizes whatever casing the text started in and leaves minor words and acronyms such as "of" and "RMS" as they should be; includes units where the quantity has them ("Frequency (Hz)"); and leaves genuine math notation, such as a single-letter variable `x`, in its usual lowercase form, applying that exemption by hand, since `Capitalize` cannot tell a math variable from a word.
- **Group related controls** when there are more than a few: `Delimiter` between groups, a short heading string or `Style[heading, Bold]` before each group (headings are labels and follow the same Title Case rule), and `ControlPlacement -> Left` when the control column would otherwise push the content area off screen. For arbitrary layouts (controls in a `Row`, collapsible groups in `OpenerView`), wrap each specification in `Control[...]`; without the `Control` wrapper, a specification inside a layout construct is just a list and its variable is treated as global. Use these layout constructs sparingly: they roughly double the size of the specification and are worth it only when the default stacked layout is genuinely hard to use.

### Stage 6: Design the Explorer Signature

The explorer function takes the wrapped function's data arguments (Stage 2's explorer arguments) as positional arguments and accepts options, and returns the `Manipulate`. Its shape:

```wl
Options[fooExplorer] = Flatten[{SaveDefinitions -> True, "ManipulateOptions" -> {}, Options[foo]}]

fooExplorer[data_List, opts : OptionsPattern[]] :=
	Enclose @ Module[{saveDefinitions, manipulateOptions, unknownPanelOptions, figureOptions},
		ConfirmAssert[DownValues[foo] =!= {},
			"foo is not loaded; load the .wl file that defines it before calling fooExplorer."];
		saveDefinitions = ConfirmMatch[OptionValue[SaveDefinitions], True | False,
			"SaveDefinitions must be True or False."];
		manipulateOptions = ConfirmMatch[OptionValue["ManipulateOptions"], {___?OptionQ},
			"ManipulateOptions must be a list of rules."];
		unknownPanelOptions = Complement[Keys[manipulateOptions], Keys @ Options[Manipulate]];
		ConfirmAssert[unknownPanelOptions === {},
			"ManipulateOptions contains settings that Manipulate does not accept: " <> ToString[unknownPanelOptions, InputForm]];
		figureOptions = FilterRules[
			FilterRules[Flatten[{opts}], Options[foo]],
			Except[{...manipulated option names...}]
		];
		With[{
				fixedData = data,
				fixedFigureOptions = Sequence @@ figureOptions,
				saveDefinitionsSetting = saveDefinitions,
				panelOptions = Sequence @@ manipulateOptions
			},
			Manipulate[
				foo[fixedData, controlVariable1, ..., ManipulatedOption -> controlVariable3, fixedFigureOptions],
				...control specifications...,
				SaveDefinitions -> saveDefinitionsSetting,
				panelOptions
			]
		]
	]
fooExplorer[args___] := (...catch-all fall-through per the coding conventions...)
```

Each part is doing real work:

- **`With` injection.** `Manipulate` has the `HoldAll` attribute, so a local `Module` variable or an `opts` sequence named inside its body is never evaluated into it; the body would refer to a symbol that no longer exists when the front end evaluates it. `With` substitutes the actual values into the held expression before `Manipulate` receives it. Every value computed by the explorer and used inside the `Manipulate` (data arguments, fixed options, panel options, precomputed tables) goes through a `With` binding.
- **`Options[fooExplorer]` splices in `Options[foo]`.** The explorer thereby accepts every option `foo` accepts, as a fixed setting (Governing Constraint 4), with `foo`'s own defaults unchanged.
- **Fixed options are routed with the coding conventions' propagation pattern, `FilterRules[Flatten[{opts}], Options[foo]]`.** The inner `FilterRules` keeps exactly the options `foo` accepts and drops everything else, including the explorer's own options (`SaveDefinitions`, `"ManipulateOptions"`). This is not optional tidiness: `foo` reads its options with `OptionValue`, which fires `OptionValue::nodef` for any option it does not declare, so an unfiltered option would raise a message on every slider move. Filtering by exclusion alone (`Except[{...}]`) is not a substitute, because it passes on every option not explicitly listed. The outer `FilterRules[..., Except[{...}]]` then removes the names of any options that are also controls, so a fixed setting never fights a control for the same option. Placing the manipulated options before `fixedFigureOptions` in the call makes the control win anyway (Wolfram Language functions take the first setting of a repeated option), but filtering keeps the call honest.
- **When the explorer wraps more than one function that takes options** (a combining function plus per-panel functions, Stage 2, or a function plus a helper the body also calls), every call inside the `Manipulate` gets its own filter against its own option set, and `Options[fooExplorer]` splices in every one of those option sets, as in the coding conventions' Rule 5 (`Options[outerFunction] = Flatten[{Options[innerFunction], ...}]`):

  ```wl
  Options[panelsExplorer] = Flatten[{SaveDefinitions -> True, "ManipulateOptions" -> {}, Options[combinePanels], Options[leftPanel]}]
  ...
  	combineOptions = FilterRules[Flatten[{opts}], Options[combinePanels]];
  	leftPanelOptions = FilterRules[Flatten[{opts}], Options[leftPanel]];
  ```

  An option both functions accept reaches both, which is usually what the caller means (an `ImageSize` or a `PlotTheme`); where it is not, state in the usage message which function receives it, or give one of the functions its own String-named option list in the manner of `"ManipulateOptions"`.
- **A default the explorer changes is passed explicitly.** `FilterRules[Flatten[{opts}], Options[foo]]` passes only what the caller typed. When the explorer keeps `foo`'s own defaults, as in the worked example, that is enough, since `foo` applies them itself. When the explorer declares a different default of its own (Stage 7's explicit `PlotRange` for a function whose own default is automatic), resolve it with `OptionValue` into a named local and add it after `opts` inside the `Flatten`, `FilterRules[Flatten[{opts, PlotRange -> plotRange}], Options[foo]]`. `opts` comes first, so a caller's own setting still wins; without the explicit entry, the explorer's default is declared in `Options[fooExplorer]` but never reaches `foo`.
- **Panel options travel in one String-named option, `"ManipulateOptions"`.** Splitting a caller's options between `Manipulate` and the wrapped function by name does not work, because the two share option names: `Manipulate` and `Plot` both accept `Frame`, `FrameLabel`, `LabelStyle`, `BaseStyle`, `ImageMargins`, `Method`, `RotateLabel`, `BaselinePosition`, and `PreserveImageOptions`, with entirely different meanings (`FrameLabel` on a `Manipulate` labels the panel's outer frame, not the plot's axes). Routing every unqualified option to the wrapped function, and every panel option through `"ManipulateOptions" -> {ControlPlacement -> Left, ...}`, removes the ambiguity. The name is a String because the explorer is inventing it: a newly coined Symbol would need a collision check against ``System` `` and the rest of the package, a decision about exporting it, and its own usage message, while a String cannot collide with anything. Symbol names are reserved for options that already exist, such as built-in options. The meaning and default of `"ManipulateOptions"` are documented in the explorer's usage message.
- **Panel options are validated, not filtered.** `FilterRules` is the right tool when one option list is shared among several functions, because an option it drops belongs to some other function. `"ManipulateOptions"` has a single destination, so an entry `Manipulate` does not accept is not meant for anyone else: it is a mistake, usually a typo such as `ControlPlacment -> Left`. Filtering it out would discard it silently and leave the caller wondering why the controls did not move. The explorer instead checks every key against `Options[Manipulate]` and returns a `Failure` whose message names the unknown settings.
- **`SaveDefinitions` is the explorer's own option, not a hidden literal and not part of `"ManipulateOptions"`.** It is declared in `Options[fooExplorer]`, so it is visible, documented, and overridable like any other option, with the Symbol name because `SaveDefinitions` is an existing built-in option of `Manipulate` (the invented-option String rule applies only to names the explorer coins). It is validated as `True | False` per the coding conventions' boolean-option rule. It does not live inside `"ManipulateOptions"`, because a caller passing any panel setting (`"ManipulateOptions" -> {ControlPlacement -> Left}`) replaces that whole list and would silently drop it, bringing back the unevaluated-call failure Stage 9 exists to prevent. It is placed before `panelOptions` in the `Manipulate`, and `Manipulate`, like other functions, uses the first setting of a repeated option, so the dedicated option is authoritative even if a caller also writes `SaveDefinitions` inside `"ManipulateOptions"`; the usage message says that it belongs in its own option. Its default is `True` when the wrapped function is loaded from a `.wl` file or notebook, and `False` when it lives in a paclet (Stage 9).
- **Panel options follow `SaveDefinitions` and precede any further panel defaults the explorer adds** (such as the paclet case's `Initialization`, Stage 9), so a caller can override those defaults through `"ManipulateOptions"`.
- **The dependency check, `ConfirmAssert[DownValues[foo] =!= {}, ...]`, makes a silent failure loud.** If `foo` has not been loaded when the explorer is called, the `Manipulate` would still be built, `SaveDefinitions` would record nothing for `foo`, and the pane would show the unevaluated call with no message, now and in every later session (Stage 9). The check turns that into a `Failure` whose message names what to load. Write one such check for each wrapped function and each helper loaded from a `.wl` file. Omit it for paclet functions, which the explorer's own file loads with `Needs` and which may be autoloaded symbols whose definitions are not yet attached.
- **The `ConfirmMatch` and `ConfirmAssert` checks** are the matched-input runtime checks the coding conventions require: a call that matches the explorer's pattern but carries a malformed `SaveDefinitions` or `"ManipulateOptions"` value, a panel setting `Manipulate` does not accept, or that is made before a dependency is loaded, returns a `Failure` tagged `"ConfirmationFailed"` rather than a broken `Manipulate`.

### Stage 7: Stability and Performance

**Keep the frame still.** When a control changes, the output is regenerated from scratch, and anything automatic in the output can jump:

- An automatic `PlotRange` rescales the axes with every drag, so the curve appears not to change while the axes do; with low-level `Graphics`, an automatic range re-centers on the content, so a moving point appears not to move at all. Fix the plot range to cover the output at every control extreme. If the function exposes `PlotRange` and its default is already fixed (a well-designed function exposes the fixed range its figure was designed for as its `PlotRange` default), nothing more is needed. If its default is automatic, the explorer declares an explicit range as its own default in `Options[fooExplorer]`, listed before the spliced `Options[foo]` so it takes precedence, computed from or chosen to cover the control extremes; resolves it with `OptionValue` and adds it after `opts` in the options passed to `foo`, since a declared default that is never passed does not reach `foo` (Stage 6); documents that choice in the design note and usage message; and leaves it overridable.
- Tick labels that change width (from `0.5` to `-0.25`) shift the plot area. A fixed `ImagePadding`, passed as a fixed option when the function accepts it, prevents this.
- A 3D graphic the user has rotated by hand stays rotated across updates only if the output carries no explicit `ViewPoint` and is not wrapped in further formatting.

**Match the update strategy to the cost measured in Stage 1:**

| Cost per call | Measure |
| --- | --- |
| Well under 0.1 s | None; the default continuous updating is fine. |
| Noticeably sluggish while dragging, under about 1 s | If the function accepts a quality option, give it a `ControlActive[fastValue, slowValue]` setting as a fixed option, for example `PlotPoints -> ControlActive[30, 150]`, so the drag shows a crude preview and the release shows full quality. Built-in plotting functions already lower their quality during a drag through their own `ControlActive` defaults; an explicit setting tunes the trade-off. |
| About 1 s or more | `"ManipulateOptions" -> {ContinuousAction -> False}` by default: the output updates only when the control is released, and the update does not block the front end. |
| Approaching 5 s or more | Also `SynchronousUpdating -> False`. A synchronous update that runs past about five seconds is aborted and the pane shows `$Aborted`. |
| Many seconds even at the cheapest setting | Not a good fit for `Manipulate`; raise it as a question (precompute a table of results, reduce the explored range, or deliver a static figure series instead). |

Also:

- `ParametricPlot` and similar functions draw visibly jagged curves while a slider is being dragged; a fixed `PerformanceGoal -> "Quality"` keeps them smooth, at the cost of speed.
- **Split slow and fast parts.** When one control changes only presentation (a `ViewPoint`, a color) while others change the computation, wrapping the presentation-only option value in `Dynamic` (`ViewPoint -> Dynamic[{2, viewAngle, 2}]`) updates that option without regenerating the output. This works only when the function passes that option through unmodified to its inner call; verify it with a test evaluation rather than assuming.
- **Hoist control-independent work out of the `Manipulate`.** Anything the function computes that does not depend on any control (loading data, building a large table) belongs in the explorer, computed once and injected via `With`, not recomputed on every drag. Mind its size: injected data is saved with the notebook.

### Stage 8: Keep the Body Clean

- **The body is the single function call** (with control values clamped or combined only where Stage 4 requires). No assignments to control variables or globals: a `Manipulate` whose body assigns to a symbol it tracks re-evaluates itself continually and consumes CPU even when nothing changes. Temporary work belongs in a `Module` (inside the function, not the body), whose local variables never retrigger updates.
- **Every input must appear explicitly in the body.** `Manipulate` tracks only symbols that appear lexically in its first argument (`TrackedSymbols -> Full`, the default). A function that reads a global parameter instead of taking it as an argument does not update when that parameter changes; this is one more reason the function must take every varied quantity as an argument or option, never through a global.
- **Do not wrap the body in `Dynamic` or `Refresh`, and do not set `TrackedSymbols`** unless a measured problem requires it; `Manipulate` already wraps its first argument in `Dynamic` with the right tracking.
- **Do not `Quiet` the call.** If some control combination makes the function return a `Failure`, prevent that combination with ranges and clamps (Stages 3 and 4). A `Failure` that can still occur displays as an informative `Failure` box in the pane, which is the correct behavior; silencing it hides a real defect. Messages issued during a `Manipulate` update may go to the Messages window rather than the notebook, so check for them explicitly in the corner sweep (Stage 12) rather than by watching the pane.

### Stage 9: Make the Definitions Travel

A `Manipulate` is evaluated by the front end whenever it is displayed, including after the notebook is closed and reopened in a fresh kernel. If the wrapped function's definition is not present in that kernel, the pane shows the unevaluated call, `foo[1, 1, 0, ...]`, instead of the figure. Choose one mechanism and state it in the design note:

- **The function lives in a paclet**: the explorer's `SaveDefinitions` option defaults to `False`, and the explorer adds `Initialization :> Needs["MyPaclet`"]` as a panel default after `panelOptions`. This loads the current paclet version on first display and keeps the saved notebook small. It requires the paclet to be installed wherever the notebook is opened; a caller who wants to send the notebook to someone without the paclet passes `SaveDefinitions -> True` instead, and the usage message says so. Warn about that choice in the usage message too: `SaveDefinitions` copies definitions recursively, so the notebook can carry a large part of the paclet with it, and the copy is frozen at the version loaded when the explorer was called, so later fixes to the paclet do not reach that notebook.
- **The function is defined in a notebook or a loose `.wl` file**: the explorer's `SaveDefinitions` option defaults to `True` (Stage 6). This stores the definitions of every non-`System`` symbol the body refers to, recursively, inside the `Manipulate` output, and re-establishes them in a fresh kernel. Beware data: any large value reachable from those definitions is saved too.

**`SaveDefinitions` copies only what is already loaded.** It records the definitions present in the kernel at the moment the `Manipulate` output is created and displayed; it does not load anything itself. If a wrapped function or one of its helpers has not been loaded when the explorer is called, nothing is recorded for it, and the saved output displays the unevaluated call in every later session, with no message at the time it was created. This is why the explorer's usage message must list every dependency (Stage 11): that list is exactly what must be loaded for `SaveDefinitions` to capture a working copy. It is also why the explorer checks that each `.wl`-loaded dependency is defined before building the `Manipulate` (Stage 6), so this failure is reported when it happens instead of being discovered later in a saved notebook.

The worked example below uses `SaveDefinitions -> True`, since its function is not in a paclet. Never rely on the definitions happening to be present in the session where the explorer was first evaluated.

### Stage 10: Apply the Visualization Guidance

The output figure's styling belongs to the wrapped function and should already conform to the visualization guidance; the explorer must not override it except through the function's own options.

**The output is always framed, whatever the wrapped function's defaults.** The visualization guidance's "Frame Every Plot" rule applies to the figure inside the `Manipulate` exactly as to a static plot; an explorer is not an "exploratory plot" exempt from it. Render the wrapped function's default output and check it. If it is drawn with crossing axes (`Axes -> True`, `AxesLabel`, `Ticks`) and the function cannot be changed, for example because it belongs to a paclet you may not edit, the explorer frames it through the function's own options, by the same mechanism as an explorer-level `PlotRange` (Stage 7): it declares `Frame -> True`, `Axes -> False`, a `FrameLabel` carrying the same text as the function's `AxesLabel` default, and, when the function sets explicit `Ticks -> {xTicks, yTicks}`, `FrameTicks -> {{yTicks, None}, {xTicks, None}}` (`FrameTicks` lists `{{left, right}, {bottom, top}}`, so the order is swapped, and a two-element `FrameTicks` would repeat the ticks on the top and right edges), as its own defaults in `Options[fooExplorer]`, listed before the spliced `Options[foo]`; resolves them with `OptionValue`; adds them after `opts` in the options passed to `foo`; documents them in the usage message and design note; and tests that they reach the output (Stage 12). These options reach `foo` only if `Options[foo]` declares them (directly or by splicing in `Options[Graphics]` or `Options[Plot]`); when it does not, the output cannot be framed through the function, so record that as a question rather than restyling the output in the explorer. After framing, render the output at the control extremes and confirm that the frame, its labels, and its ticks are present and legible and that nothing the axes conveyed has been lost; if framing breaks the figure, drop the override, keep the function's own output, and record the defect as a question for the function's developer. When the wrapped function can be changed, make it frame its output by default instead, under the coding conventions.

Check the parts the explorer itself adds:

- Control labels, group headings, and discrete-choice labels: plain words, Title Case, units (Stage 5).
- Color controls start at Standard color names (`StandardBlue`), not `Red` or a raw `RGBColor`.
- No hard-coded colors in control-area annotations (`Style["Horizontal", Red]`); use default styling or a `LightDarkSwitched` pair.
- Do not set `Background -> White` or other light-only panel styling through `"ManipulateOptions"`; the default panel follows the notebook theme.
- If the wrapped function's own output does not conform (no `PlotLabel`, a raw-identifier axis label, a hard-coded `RGBColor`), the fix belongs in the function, made under the coding conventions and the visualization guidance; record it as a question or a separate change, not as an explorer-level override.

### Stage 11: Write the Detailed Usage Message

Following the coding conventions' Rule 2 as the baseline, and going well beyond it, the explorer's usage message must let a reader, including an LLM with no access to the body, call it correctly:

- Each calling form, with what it produces.
- **Every control**: its label, what argument or option of the wrapped function it drives, its range, its step if discrete, and its initial value.
- **Every option**: that every option of the wrapped function is accepted and held fixed (not restated one by one); the meaning and default of `SaveDefinitions`, and that it belongs in its own option rather than inside `"ManipulateOptions"`; and the meaning and default of `"ManipulateOptions"`.
- **Several example calls**, each on its own line: the bare call; a call fixing an option of the wrapped function; and a call passing panel settings through `"ManipulateOptions"`.
- **Dependencies**: everything that must already be loaded in the kernel before the explorer is called, so that a reader knows what to load without reading the body or tracing calls. Name each one concretely:
  - every wrapped function, and every helper function it calls that is not built into Wolfram Language, by symbol name;
  - for each of those, where its definition comes from: the `.wl` file to load with `Get` (by file name, and by path when it is fixed), or the paclet and context to load with `Needs` (``Needs["MyPaclet`"]``);
  - any further paclet, context, or data file those functions themselves load or read, since a missing indirect dependency fails exactly like a missing direct one, as an unevaluated call in the pane.

  Use the inventory from Stage 1 to build this list. The test file loads exactly this list and nothing else (Stage 12), so a passing test run in a fresh kernel confirms it is complete.
- **What the output needs when it is reopened later**, which is a separate question from what the explorer needs when it is called, and which depends on the first: with `SaveDefinitions -> True`, the definitions travel inside the `Manipulate` output and nothing needs to be loaded again, but only if every listed dependency was loaded when the explorer was called, since `SaveDefinitions` can copy only definitions that are already in the kernel (Stage 9); with `Initialization :> Needs[...]`, the named paclet must be installed wherever the notebook is opened. State this connection in the usage message itself, so that a user who skips loading a dependency understands why the saved interactive later shows an unevaluated call.

Err on the side of a long, explicit usage message. It is the one place a user, or an LLM generating calls to the explorer, learns what to load, what each control does, and what each option means; a thorough usage message helps everyone who uses the function, and the coding conventions' line-width limits are satisfied by wrapping lines with `\`, not by cutting content.

**This is a deliberate exception to Rule 2's line format.** Rule 2 asks that every line of a usage message start with a calling template. The explorer's usage message still starts each calling form and each example call on its own line with its template, but it also carries explanation lines that have no template of their own: the dependencies, the meaning of `SaveDefinitions`, and the meaning of `"ManipulateOptions"`, as in the worked example. Keep those lines; do not drop them or squeeze them into a template line to satisfy the format.

### Stage 12: Write Tests

A `Manipulate` cannot be dragged in a test, but everything it depends on can be checked. Write `VerificationTest` cases (Rule 15) covering:

- **Loading**: the test file must run on its own in a fresh kernel (Rule 15), so it begins by loading exactly the dependencies the usage message lists (Stage 11), followed by the explorer's own file, and nothing else. For a `.wl` file, locate it relative to the test file with `$TestFileName`, never `Directory[]`: `Get[FileNameJoin[{DirectoryName[$TestFileName], "PlotSinusoid.wl"}]]`. For a paclet, use `PacletDirectoryLoad[DirectoryName[$TestFileName, n]]` and `Needs`, as Rule 15 describes. Because the test file loads only what the usage message lists, a passing run also confirms that the list is complete: a dependency missing from the list is missing from the test kernel, and the explorer's dependency check makes the tests fail.

- **Shape**: `MatchQ[fooExplorer[...], _Manipulate]` for the bare call and for a call with fixed options and panel options.
- **Corner sweep**: call the wrapped function at every combination of each control's minimum, initial value, and maximum (`Tuples`), and confirm that none returns a `Failure` (`NoneTrue[..., FailureQ[...] &]`). This is the test that catches an integer slider with no step, a range endpoint the pattern rejects, or a demo range the function cannot actually handle. For a large number of controls, sweep each control's extremes with the others at their initial values instead of the full product. The sweep must also produce no messages, which the test framework enforces automatically.
- **Pass-through**: a fixed option of the wrapped function reaches it (for graphics output, compare an option value read back from the function's result, or simply confirm the call evaluates without `OptionValue::nodef`).
- **Panel settings**: a misspelled panel setting inside `"ManipulateOptions"` returns a `Failure` whose message names it, and a valid list, including a `RuleDelayed` setting such as `Initialization :> ...`, still gives a `Manipulate`.
- **Explorer-changed defaults**: where the explorer declares a default different from the wrapped function's (Stage 7), a test confirms the value reaches the function, for example by reading the option back from the function's graphic output.
- **`SaveDefinitions`**: the default setting and an explicit `SaveDefinitions -> False` each reach the `Manipulate` (`MemberQ[fooExplorer[...], SaveDefinitions -> value]`; the `Manipulate` is held, so its options can be inspected directly), and a non-boolean value returns a `Failure`.
- **Missing dependency**: calling the explorer while a wrapped function is temporarily undefined, `Block[{foo}, fooExplorer[...]]`, returns a `Failure` tagged `"ConfirmationFailed"` rather than a `Manipulate`. `Block` restores the definition afterwards, so the test does not disturb the tests after it.
- **Scope boundary**, the two cases the coding conventions require: an invalid call caught by the explorer's catch-all fall-through, returning a `Failure` tagged `"InvalidArguments"` with the `::args` message declared as expected; and a matched call that fails at runtime, such as a malformed `"ManipulateOptions"` value, returning a `Failure` tagged `"ConfirmationFailed"`.

### Stage 13: Produce the Control Mapping Table and Design Note

For every argument and option of the wrapped function, state what it became. Example shape:

| Function item | Became | Range, step, initial | Source and notes |
| --- | --- | --- | --- |
| `amplitude_?NumericQ` (argument) | Slider, label "Amplitude" | 0 to 3, continuous, initial 1 | Range from the usage message's documented typical range; initial from its first example call. |
| `n_Integer?Positive` (argument) | Slider, label "Sample Count" | 1 to 50, step 1, initial 10 | Step 1 required by the `_Integer` pattern; minimum 1 required by `Positive`. |
| `"ShowGridLines"` (option, default `True`) | Checkbox, label "Show Grid Lines" | `{True, False}`, initial `True` | Initial value is the option default (Governing Constraint 3). |
| `data_List` (argument) | Explorer argument | none | Data supplied once, not varied interactively (Stage 2). |
| Every other option of the function | Fixed explorer option | function's own defaults | Spliced via `Options[foo]` (Governing Constraint 4). |

Follow the table with the design note: the explorer boundary decision (Stage 2), stability and performance measures with the measured cost that justified them (Stage 7), the definition-transport mechanism (Stage 9), and any question raised about the wrapped function itself.

---

## Worked Example

Input: a function `PlotSinusoid` with this option declaration and usage message (body omitted):

```wl
Options[PlotSinusoid] =
	Flatten[{
		Frame -> True,
		Axes -> False,
		FrameLabel -> {"x", "y"},
		PlotRange -> {-3, 3},
		ImageSize -> 400,
		Options[Plot]
	}]

PlotSinusoid::usage = "PlotSinusoid[amplitude, frequency, phase] plots amplitude Sin[frequency x + phase] \
for x from 0 to 2 Pi. amplitude is typically between 0 and 3; frequency is typically between 0.1 and 5; \
phase may be any real number.\n\
PlotSinusoid[1, 1, 0] plots one full cycle of a unit-amplitude, unit-frequency sinusoid with no phase shift, \
using every option default below.\n\
...";

PlotSinusoid[amplitude_?NumericQ, frequency_?NumericQ, phase_?NumericQ, opts : OptionsPattern[]] := ...
PlotSinusoid[args___] := ...
```

Created:

```wl
Options[PlotSinusoidExplorer] = Flatten[{SaveDefinitions -> True, "ManipulateOptions" -> {}, Options[PlotSinusoid]}]

PlotSinusoidExplorer::usage = "PlotSinusoidExplorer[] gives a Manipulate that explores PlotSinusoid[amplitude, \
frequency, phase] with three sliders: Amplitude from 0 to 3 (initial 1), Frequency from 0.1 to 5 (initial 1), \
and Phase from 0 to 2 Pi (initial 0). The initial display is identical to PlotSinusoid[1, 1, 0].\n\
Dependencies: PlotSinusoidExplorer calls PlotSinusoid, which must be defined before PlotSinusoidExplorer is called, \
by loading the .wl file that defines it with Get. PlotSinusoid uses only built-in functions and loads no paclets, so \
nothing else is required. If PlotSinusoid is not defined when PlotSinusoidExplorer is called, PlotSinusoidExplorer \
returns a Failure saying so instead of a Manipulate.\n\
SaveDefinitions -> True (the default) copies the definition of PlotSinusoid into the Manipulate output, so that a \
notebook containing it works in a fresh kernel without loading anything. SaveDefinitions can copy only definitions \
already present in the kernel when PlotSinusoidExplorer is called, which is why PlotSinusoid must be loaded first. \
SaveDefinitions -> False leaves the definition out, keeping the notebook smaller; the interactive then works only in \
a session where PlotSinusoid has been loaded, and shows the unevaluated call PlotSinusoid[1, 1, 0] instead of a plot \
anywhere else. Give SaveDefinitions as its own option, not inside \"ManipulateOptions\"; if it appears in both \
places, the separate SaveDefinitions option is the one used.\n\
PlotSinusoidExplorer[opts] holds any option of PlotSinusoid fixed while the sliders vary; every option PlotSinusoid \
accepts, including every option of Plot, is accepted and passed through unchanged.\n\
\"ManipulateOptions\" -> {rules} passes panel-level settings, such as ControlPlacement or ContinuousAction, to \
Manipulate itself; it defaults to {}. Every setting in it must be an option of Manipulate; a setting Manipulate does \
not accept, such as a misspelled option name, makes PlotSinusoidExplorer return a Failure naming it rather than \
silently ignoring it. Options that both Plot and Manipulate accept, such as Frame and FrameLabel, \
given directly to PlotSinusoidExplorer always go to the plot; give them inside \"ManipulateOptions\" to apply them \
to the panel instead.\n\
PlotSinusoidExplorer[] gives the explorer with every PlotSinusoid default.\n\
PlotSinusoidExplorer[PlotStyle -> StandardRed] draws the curve in red at every slider setting.\n\
PlotSinusoidExplorer[PlotRange -> All] lets the vertical range follow the curve instead of the fixed {-3, 3}.\n\
PlotSinusoidExplorer[\"ManipulateOptions\" -> {ControlPlacement -> Left}] places the sliders to the left of \
the plot.\n\
PlotSinusoidExplorer[SaveDefinitions -> False] gives a lighter interactive for use only in the current session.";

PlotSinusoidExplorer[opts : OptionsPattern[]] :=
	Enclose @ Module[{saveDefinitions, manipulateOptions, unknownPanelOptions, figureOptions},
		ConfirmAssert[DownValues[PlotSinusoid] =!= {},
			"PlotSinusoid is not loaded; load the .wl file that defines it before calling PlotSinusoidExplorer."];
		saveDefinitions = ConfirmMatch[OptionValue[SaveDefinitions], True | False,
			"SaveDefinitions must be True or False."];
		manipulateOptions = ConfirmMatch[OptionValue["ManipulateOptions"], {___?OptionQ},
			"ManipulateOptions must be a list of rules."];
		unknownPanelOptions = Complement[Keys[manipulateOptions], Keys @ Options[Manipulate]];
		ConfirmAssert[unknownPanelOptions === {},
			"ManipulateOptions contains settings that Manipulate does not accept: " <> ToString[unknownPanelOptions, InputForm]];
		figureOptions = FilterRules[Flatten[{opts}], Options[PlotSinusoid]];
		With[{
				fixedFigureOptions = Sequence @@ figureOptions,
				saveDefinitionsSetting = saveDefinitions,
				panelOptions = Sequence @@ manipulateOptions
			},
			Manipulate[
				PlotSinusoid[amplitude, frequency, phase, fixedFigureOptions],
				{{amplitude, 1, "Amplitude"}, 0, 3},
				{{frequency, 1, "Frequency"}, 0.1, 5},
				{{phase, 0, "Phase"}, 0, 2 Pi},
				SaveDefinitions -> saveDefinitionsSetting,
				panelOptions
			]
		]
	]
PlotSinusoidExplorer[args___] := (
	Message[PlotSinusoidExplorer::args, PlotSinusoidExplorer];
	Failure["InvalidArguments", <|
		"MessageTemplate" -> PlotSinusoidExplorer::args,
		"MessageParameters" -> {PlotSinusoidExplorer}
	|>]
)
```

Tests, in `PlotSinusoidExplorer.wlt`, assuming `PlotSinusoid.wl`, `PlotSinusoidExplorer.wl`, and the test file share one directory:

```wl
(* load exactly the dependencies the usage message lists, then the explorer itself *)
Get[FileNameJoin[{DirectoryName[$TestFileName], "PlotSinusoid.wl"}]]
Get[FileNameJoin[{DirectoryName[$TestFileName], "PlotSinusoidExplorer.wl"}]]

VerificationTest[
	MatchQ[PlotSinusoidExplorer[], _Manipulate],
	True,
	TestID -> "PlotSinusoidExplorer-returns-Manipulate"
]

VerificationTest[
	MatchQ[PlotSinusoidExplorer[PlotStyle -> StandardRed, "ManipulateOptions" -> {ControlPlacement -> Left}], _Manipulate],
	True,
	TestID -> "PlotSinusoidExplorer-accepts-fixed-and-panel-options"
]

(* every combination of each slider's minimum, initial value, and maximum *)
VerificationTest[
	NoneTrue[Tuples[{{0, 1, 3}, {0.1, 1, 5}, {0, 2 Pi}}], FailureQ[PlotSinusoid @@ #] &],
	True,
	TestID -> "PlotSinusoidExplorer-corner-sweep"
]

VerificationTest[
	First @ PlotSinusoidExplorer["oops"],
	"InvalidArguments",
	{PlotSinusoidExplorer::args},
	TestID -> "PlotSinusoidExplorer-invalid-argument-returns-Failure"
]

VerificationTest[
	First @ PlotSinusoidExplorer["ManipulateOptions" -> "bad"],
	"ConfirmationFailed",
	TestID -> "PlotSinusoidExplorer-malformed-ManipulateOptions-returns-Failure"
]

VerificationTest[
	MemberQ[PlotSinusoidExplorer[], SaveDefinitions -> True],
	True,
	TestID -> "PlotSinusoidExplorer-SaveDefinitions-default-True"
]

VerificationTest[
	MemberQ[PlotSinusoidExplorer[SaveDefinitions -> False], SaveDefinitions -> False],
	True,
	TestID -> "PlotSinusoidExplorer-SaveDefinitions-False-reaches-Manipulate"
]

VerificationTest[
	First @ PlotSinusoidExplorer[SaveDefinitions -> "yes"],
	"ConfirmationFailed",
	TestID -> "PlotSinusoidExplorer-non-boolean-SaveDefinitions-returns-Failure"
]

VerificationTest[
	StringContainsQ[PlotSinusoidExplorer["ManipulateOptions" -> {ControlPlacment -> Left}]["Message"], "ControlPlacment"],
	True,
	TestID -> "PlotSinusoidExplorer-misspelled-panel-option-returns-Failure-naming-it"
]

VerificationTest[
	MatchQ[PlotSinusoidExplorer["ManipulateOptions" -> {ControlPlacement -> Left, Initialization :> Null}], _Manipulate],
	True,
	TestID -> "PlotSinusoidExplorer-accepts-valid-panel-options-including-RuleDelayed"
]

(* Block temporarily removes the definition of PlotSinusoid and restores it afterwards *)
VerificationTest[
	First @ Block[{PlotSinusoid}, PlotSinusoidExplorer[]],
	"ConfirmationFailed",
	TestID -> "PlotSinusoidExplorer-unloaded-dependency-returns-Failure"
]
```

Several things are doing real work here:

- **The body is one call to `PlotSinusoid`.** Nothing about the sinusoid is recomputed or restated in the `Manipulate`; the frame, labels, range, and size all come from `PlotSinusoid`'s own defaults.
- **The sliders follow the documented ranges.** Ranges `0` to `3`, `0.1` to `5`, and `0` to `2 Pi`, and initial values `1`, `1`, `0`, are exactly the ranges `PlotSinusoid`'s usage message documents and the values its first example call uses. The initial display is identical to `PlotSinusoid[1, 1, 0]` (Governing Constraint 3).
- **The frame stays still without any explorer-level setting.** `PlotSinusoid` already defaults to `PlotRange -> {-3, 3}`, which covers the amplitude slider's full range, so the axes never rescale during a drag. A caller who passes `PlotRange -> All` gets a rescaling plot, by choice.
- **`fixedFigureOptions` is injected with `With`.** Because `Manipulate` is `HoldAll`, a `Module` variable named inside its body would never be evaluated into it; `With` places the actual option rules into the held body before `Manipulate` receives it, so `PlotSinusoidExplorer[PlotStyle -> StandardRed]` draws red at every slider setting.
- **Fixed options follow the propagation pattern, `FilterRules[Flatten[{opts}], Options[PlotSinusoid]]`.** It keeps every option `PlotSinusoid` accepts, including all of `Plot`'s, and drops `SaveDefinitions` and `"ManipulateOptions"`, since neither is an option of `PlotSinusoid` or `Plot`. None of the three sliders drives an option, so no outer `Except[...]` filter is needed, and since the explorer keeps every `PlotSinusoid` default unchanged, no explorer default has to be added to the list (Stage 6).
- **Panel settings are checked against `Options[Manipulate]`, not filtered.** `PlotSinusoidExplorer["ManipulateOptions" -> {ControlPlacment -> Left}]` returns a `Failure` whose message names `ControlPlacment`, instead of quietly producing a `Manipulate` with its controls in the default place.
- **Panel settings travel separately.** `Frame` and `FrameLabel` are options of both `Plot` and `Manipulate`; sending every unqualified option to `PlotSinusoid` and every panel setting through `"ManipulateOptions"` means `PlotSinusoidExplorer[FrameLabel -> {"t", "y"}]` relabels the plot's axes, never the panel.
- **`SaveDefinitions` is a declared option, defaulting to `True`, so the definition travels.** Without it, the `Manipulate` displays the unevaluated call `PlotSinusoid[1, 1, 0]` in any kernel where `PlotSinusoid` is not defined, including the front end's own on reopening the notebook. Because it is in `Options[PlotSinusoidExplorer]`, a caller sees it and can set `SaveDefinitions -> False`; because it is placed before `panelOptions`, the dedicated option wins over any copy inside `"ManipulateOptions"`. If `PlotSinusoid` lived in a paclet, it would default to `False` and the explorer would add `Initialization :> Needs[...]` (Stage 9).
- **The dependency check guards `SaveDefinitions`.** `SaveDefinitions` silently records nothing for a function that is not loaded. `ConfirmAssert[DownValues[PlotSinusoid] =!= {}, ...]` turns that silent failure into a `Failure` whose message says what to load, before any `Manipulate` is built.
- **No performance measures were needed.** A `PlotSinusoid` call takes a few milliseconds, well under the threshold where `ControlActive` or `ContinuousAction -> False` would help (Stage 7).

Control mapping table:

| Function item | Became | Range, step, initial | Source and notes |
| --- | --- | --- | --- |
| `amplitude_?NumericQ` | Slider, "Amplitude" | 0 to 3, continuous, initial 1 | Usage message's documented typical range; initial from its first example call. The upper end matches the fixed `PlotRange -> {-3, 3}`. |
| `frequency_?NumericQ` | Slider, "Frequency" | 0.1 to 5, continuous, initial 1 | Usage message's documented typical range. |
| `phase_?NumericQ` | Slider, "Phase" | 0 to 2 Pi, continuous, initial 0 | Usage message says any real is valid; one period covers every distinct curve. |
| `Frame`, `PlotRange`, `ImageSize` (options declared by `PlotSinusoid`) | Fixed explorer options | `PlotSinusoid`'s defaults | Not varied: none changes what the figure shows mathematically, and the fixed `PlotRange` is what keeps the frame still. |
| Every option of `Plot` | Fixed explorer options | `Plot`'s defaults | Spliced via `Options[PlotSinusoid]` (Governing Constraint 4). |
| (none in function) | Explorer option `SaveDefinitions -> True` | none | Built-in `Manipulate` option, so Symbol-named; declared rather than hard-coded so it is visible and overridable; default `True` because `PlotSinusoid` is loaded from a `.wl` file (Stages 6 and 9). |
| (none in function) | `"ManipulateOptions" -> {}` | none | Invented panel-settings option, String-named (Stage 6). |

Design note: wrapped the single function `PlotSinusoid` in one explorer (Stage 2); mapped its three numeric arguments to continuous sliders whose ranges and initial values come from its usage message, so the initial display equals `PlotSinusoid[1, 1, 0]`; kept every `PlotSinusoid` and `Plot` option reachable as a fixed setting injected with `With`; routed fixed options to `PlotSinusoid` with `FilterRules[Flatten[{opts}], Options[PlotSinusoid]]`; routed panel settings through the String-named `"ManipulateOptions"` because `Manipulate` and `Plot` share option names, and checked every panel setting against `Options[Manipulate]` so a typo is reported rather than dropped; made the definition travel with a declared `SaveDefinitions` option defaulting to `True`, since `PlotSinusoid` is not in a paclet, and guarded it with a check that `PlotSinusoid` is loaded, since `SaveDefinitions` silently saves nothing otherwise; took no performance measures, since a call costs a few milliseconds; and verified with a corner sweep that no combination of slider extremes and initial values produces a `Failure`.

---

## Required Response Format

This task follows the coding conventions' "Writing New Code" response format, with the control mapping table inserted as its own subsection between the code and the design note.

#### New Code

```wl
(* the explorer function, with its detailed usage message per Stage 11 *)
```

#### Control Mapping Table

The table described in Stage 13.

#### Design Note

The design note described in Stage 13.

#### Tests

```wl
(* VerificationTest cases per Stage 12 *)
```

#### Questions and Assumptions

Targeted questions for any genuine ambiguity, including any gap in the wrapped function that prevented a control from being wired correctly, and any assumption made in its place. Omit this section if there are none.

---

## Final Review and Revision

Before presenting the response in the format above, re-read these instructions in full, `@WOLFRAMCODINGGUIDE.md` in full, and `@WOLFRAMVISUALIZATION.md` in full, and check the explorer, the mapping table, the design note, and the tests against every instruction in all three documents, including the coding conventions' Code Quality Checklist. Confirm in particular that:

- The `Manipulate` body is a single call to the wrapped function and reimplements none of its computation.
- The figure inside the `Manipulate` is framed, with frame labels and no crossing axes, at the initial values and at every control extreme, either by the wrapped function's own defaults or by explorer-declared framing defaults (Stage 10), and a test confirms it.
- Every control drives an argument the function's patterns accept or an option `Options[f]` declares; every integer control has an explicit step; every range endpoint satisfies the argument's pattern.
- With every control at its initial value, the display equals the function's own default output for those arguments, and that output shows something meaningful.
- Every option of the wrapped function is reachable as a fixed explorer option, and panel settings go only through `"ManipulateOptions"`, except `SaveDefinitions`, which is the explorer's own declared option, placed before the panel settings.
- Every wrapped function and helper loaded from a `.wl` file has a `ConfirmAssert` dependency check, and a test exercises it with `Block`.
- Every call inside the `Manipulate` that takes options receives them through `FilterRules[Flatten[{opts, ...explorer-changed defaults...}], Options[thatFunction]]`, `Options[fooExplorer]` splices in the option set of every such function, and every panel setting is checked against `Options[Manipulate]` rather than filtered.
- Every value the explorer computes and uses inside the `Manipulate` is injected with `With`, and no control variable shares a name with one of the explorer's own bindings.
- The definitions reach a fresh kernel by the mechanism stated in the design note.
- The corner sweep and both scope-boundary tests are present and pass.
- The usage message names every dependency that must be loaded before the explorer is called (each function, `.wl` file, and paclet, including indirect ones), and the test file loads exactly those items, and nothing else, before running in a fresh kernel.
- The usage message documents every control's label, range, step, and initial value, every option, and several example calls, and the mapping table and design note describe the code as delivered, not an earlier draft.

Where this review finds a gap, revise before delivering; do not report an unconfirmed gap as a question in place of fixing it.
