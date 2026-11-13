# Wolfram Language Visualization Guide: Styling, Options, and Layout

This guide governs how Wolfram Language visualizations are built and styled: which options to reach for, how to arrange titles, legends, and labels, which fonts to use and when, and how to place embellishments so a figure reads cleanly at a glance. It complements @WOLFRAMCODINGGUIDE.md, which governs code structure, naming, and error handling. The non-negotiable rules there (no em dashes, no box-drawing or decorative arrows, dark-mode-safe colors) apply here too, since every example in this guide is source code.

Use this guide any time you are building a `Plot`, `ListPlot`, chart, `Graphics`, `Graph`, or any other visual output, and any time you are asked to improve, restyle, or clean up an existing visualization.

---

## Guiding Principles

1. **Legibility first.** A viewer should understand what a figure shows without reading the surrounding text. Every visualization needs a title or clear axis/frame labels; nothing should rely on a caption living elsewhere.
2. **Every figure works in both themes.** Wolfram notebooks and many deployment surfaces (web, dark-mode PDFs) render in both light and dark backgrounds. A figure that hard-codes `White` or `Black` breaks in one of the two. See "Color" below.
3. **Consistency across a document.** When producing multiple figures for the same deliverable, fix a font stack, a color palette, and a sizing convention once, and reuse it. Don't let each figure invent its own style.
4. **Say only what needs saying.** Add a legend only when there is more than one series to distinguish. Add gridlines only when the viewer needs to read off approximate values. Every embellishment should answer a question the bare data cannot.
5. **Prefer built-in options over `Epilog` hacks.** If a chart function has a native option for what you want (`ChartLabels`, `PlotLegends`, `FrameTicks`), use it before reaching for manually placed `Text` or `Inset` primitives. Manual placement is for the cases native options cannot reach.

---

## Choosing the Right Function

Pick the function whose contract already matches the data shape; don't force a general `Graphics` build when a specialized chart function exists.

| Data shape | Function |
| --- | --- |
| $y = f(x)$, symbolic expression | `Plot`, `Plot3D`, `ParametricPlot`, `ContourPlot` |
| Discrete $(x, y)$ pairs | `ListPlot`, `ListLinePlot` |
| Time-indexed data | `DateListPlot` |
| Categories vs. magnitude | `BarChart`, `PieChart`, `ChartLabels` |
| Distribution of a single variable | `Histogram`, `SmoothHistogram`, `DistributionChart` |
| Distribution across categories | `BoxWhiskerChart`, `ViolinChart` |
| Matrix / grid of values | `MatrixPlot`, `ArrayPlot`, `ReliefPlot` |
| Network or relational data | `Graph`, `GraphPlot` |
| Free-form composition | `Graphics`, `Graphics3D` (last resort; native options don't reach this need) |

Reserve raw `Graphics` primitives (`Text`, `Line`, `Disk`, ...) for annotation on top of a chart, or for genuinely custom diagrams that no built-in chart type covers. Building an entire chart from primitives forfeits automatic legends, ticks, and accessibility features that the chart functions provide for free.

---

## Titles and Labels

### `PlotLabel` vs. `FrameLabel` vs. `AxesLabel`

- `PlotLabel`: the figure's title, sitting above the plot. Use it for the one-line statement of what the figure shows.
- `FrameLabel`: axis labels attached to a `Frame`.
- `AxesLabel`: axis labels attached to the crossing axes. Not used; see "Frame Every Plot" below.

### Frame Every Plot

**Every figure with quantitative axes is framed: `Frame -> True` with `FrameLabel`, and `Axes -> False`.** This is a rule, not a preference. It applies to every plot, whatever its purpose: a static figure, a quick check, the output inside a `Manipulate`, each panel of a multi-panel figure, and a plot drawn by a function someone else wrote (pass the framing through that function's own options). There is no exception for "exploratory" plots. A frame reads more cleanly than floating axis lines, keeps the plot area fixed while a `Manipulate` redraws, and stays put when the origin is off-figure.

- Put the axis labels in `FrameLabel`, never in `AxesLabel`, and the tick specifications in `FrameTicks`, never in `Ticks`.
- A partial frame, such as `Frame -> {{True, False}, {True, False}}` (left and bottom edges only), satisfies the rule, provided each drawn edge that carries values has its `FrameLabel`.
- Low-level `Graphics` with coordinate meaning (a supply-and-demand diagram drawn from `Line` primitives, a geometric construction with values on its axes) is framed the same way.
- When a plot is centered on a meaningful origin (positive and negative values on both sides of zero), keep the frame and mark the origin with `GridLines -> {{0}, {0}}`, or one of the two, rather than switching to crossing axes.
- Only figures with no coordinate axes are exempt: pie and sector charts, `Graph`/network plots, and schematic diagrams whose positions carry no values.

### Example

```wl
Plot[Sin[x] / x, {x, -10, 10},
	Frame -> True,
	Axes -> False,
	FrameLabel -> {"x", "sinc(x)"},
	PlotLabel -> "Normalized Sinc Function",
	LabelStyle -> Directive[FontFamily -> "Source Sans Pro", 14]
]
```

### Label Placement Rules

- A `FrameLabel` describes the axis, not the units alone: write `"Time (s)"`, not just `"s"`.
- Keep `PlotLabel` to one line. If a second line of context is genuinely needed, use `Row[{"Title", Style["subtitle", Smaller, GrayLevel[0.5]]}, "\n"]` rather than cramming both onto the same visual weight.
- For multi-panel figures (see below), put the shared title on the enclosing `Grid`/`Column`, not repeated on every panel.
- `RotateLabel -> False` keeps a vertical `FrameLabel` horizontal when the axis is short enough that a sideways label would need to be read at an angle; use it when the y-axis label is a short word or symbol.

### Chart-Specific Labeling

`ChartLabels` places category names directly under bars, wedges, or box-whisker groups. Prefer it over a separate legend when there is exactly one series per category, since it removes a lookup step for the viewer:

```wl
BarChart[{28, 35, 19, 42},
	ChartLabels -> {"Q1", "Q2", "Q3", "Q4"},
	ChartStyle -> "Pastel"
]
```

Use `PlotLegends` instead of `ChartLabels` when there are multiple series per category (grouped or stacked bars) - a legend distinguishes series, while `ChartLabels` distinguishes categories, and both can appear together.

---

## Multiple Axes for Multiple Scales (`MultiaxisArrangement`)

`MultiaxisArrangement` is an option to `ListPlot` and `ListLinePlot` (it is not available on `Plot`, `DateListPlot`, or the chart functions) that lets several datasets share one plot while each keeping its own y-axis scale, instead of being forced onto one shared scale.

### When to Use It

Reach for `MultiaxisArrangement` only when the datasets being compared have genuinely different units or orders of magnitude, and a single shared y-scale would flatten the smaller-magnitude series into an unreadable near-flat line against the axis. Typical cases: temperature vs. pressure over the same time base, revenue vs. unit count, a raw signal vs. its cumulative sum.

Multiple axes on one plot are a well-documented dataviz trap: a viewer can easily read a point against the wrong axis, or infer a correlation between two series that is really just an artifact of how the two independent scales happen to line up. Use `MultiaxisArrangement` only when:

- There are no more than two or three distinct scales involved. Beyond that, prefer separate panels via `PlotGrid` (see "Multi-Panel Figures") so each scale gets its own clean frame instead of stacking many axes on the same edge.
- Each axis is color-coded to match the `PlotStyle` of the series it belongs to (via `FrameStyle` and `FrameTicksStyle`, keyed per side), so the association is visible without cross-referencing a legend.
- A shared axis (`MultiaxisArrangement -> None`, the default) has genuinely been tried first and fails to make the smaller-scale series readable.

When only two datasets are involved and the shared-vs-independent-scale question is a close call, consider two stacked single-series panels via `PlotGrid` instead; it avoids the wrong-axis misreading risk entirely, at the cost of a taller figure.

### Values

| Value | Effect |
| --- | --- |
| `None` (default) | All datasets share one y-scale. |
| `All` | Every dataset gets its own independent axis. |
| `{group1, group2, ...}` | Explicit grouping: each `groupI` is a dataset index, or a list of indices sharing one axis; groups are placed on alternating sides automatically. |
| `{Left -> spec, Right -> spec}` | Pins axes to a side. Within `spec`, a flat list of indices (`{1, 2}`) gives each index its own independent axis, all placed on that side; a list of groups (`{{1, 2}}`) shares one axis across that group, placed on that side; a bare index (`3`) gives that one dataset its own axis on that side. |

A dataset left out of every group is not drawn, so double-check that every series index appears somewhere in an explicit spec.

### Example

```wl
ListLinePlot[
	{Range[10], Prime[Range[10]], Range[10] ^ 2},
	MultiaxisArrangement -> {Left -> {{1, 2}}, Right -> 3},
	PlotStyle -> {StandardBlue, StandardBlue, StandardRed},
	PlotLegends -> {"linear", "primes", "squares"},
	Frame -> True,
	Axes -> False,
	FrameStyle -> {{StandardBlue, StandardRed}, {Automatic, Automatic}},
	FrameTicksStyle -> {{StandardBlue, StandardRed}, {Automatic, Automatic}}
]
```

The first two series share one left-hand axis (styled blue, matching their curves); the third series, which grows on a much larger scale, gets its own right-hand axis styled red to match.

---

## Legends

### When to Add One

Add a legend only when a figure has two or more distinguishable series (different colors, dashing, or markers) whose identity is not otherwise obvious from labels on the plot itself. A single-series plot never needs a legend; use `PlotLabel` or `FrameLabel` instead.

### `PlotLegends` (Simplest Path)

For `Plot`, `ListPlot`, and related functions, `PlotLegends` is almost always sufficient and keeps the legend keyed automatically to the plot styles:

```wl
Plot[{Sin[x], Cos[x]}, {x, 0, 2 Pi},
	PlotLegends -> {"sin(x)", "cos(x)"},
	Frame -> True,
	Axes -> False,
	FrameLabel -> {"x", "value"}
]
```

`PlotLegends -> Automatic` uses the expressions themselves as legend text; prefer explicit strings for anything delivered to an audience that should not see raw Wolfram syntax.

### Explicit Legend Constructors

Reach for `LineLegend`, `PointLegend`, `SwatchLegend`, or `BarLegend` when the legend must be built independently of a single plotting call (composited figures, custom colors, `Graphics`-only diagrams, or a continuous `ColorFunction`):

- `LineLegend[{style1, style2, ...}, {"label1", "label2", ...}]`: line-style series.
- `PointLegend[...]`: marker/point series.
- `SwatchLegend[...]`: filled-region series (bar charts, pie charts, area plots).
- `BarLegend[{colorFunction, {min, max}}]`: continuous color scale, for density plots, heat maps, and `ColorFunction`-driven charts.

```wl
DensityPlot[Sin[x] Cos[y], {x, -3, 3}, {y, -3, 3},
	ColorFunction -> "TemperatureMap",
	PlotLegends -> BarLegend[{"TemperatureMap", {-1, 1}}, LegendLabel -> "Value"]
]
```

### Placement

- `LegendLayout -> "Column"` (default) stacks entries vertically; use `"Row"` only when there are two or three short entries and vertical space is scarce.
- Control legend position with `Placed[legend, position]`, e.g. `Placed[legend, Below]` or `Placed[legend, {Right, Top}]`. Default placement (to the right of the plot) is correct for most cases; move it only when the default overlaps data or wastes disproportionate horizontal space.
- Never let a legend overlap plotted data. If default placement causes overlap, either reposition with `Placed` or move the legend outside the plot entirely via `Placed[legend, Outside]` (or by compositing the legend as a separate `Graphics` alongside the plot in a `Row`/`Grid`).
- Keep `LegendMarkerSize` and font size proportional to the plot's own `ImageSize`; a legend rendered at a much larger or smaller scale than the plot itself reads as inconsistent.

---

## Fonts and Typography

### Choosing a Font Family

- Default to a clean sans-serif (`"Source Sans Pro"`, `"Arial"`, or the system default) for labels, titles, and legends in most technical figures. Sans-serif remains legible at small sizes and in raster export.
- Reserve serif fonts (`"Times New Roman"`, `"Latin Modern Roman"`) for figures embedded in a serif-typeset document (a paper, a report matching a serif body font), so the figure's type matches its surrounding text.
- Use a monospace font (`"Courier New"`, `"Source Code Pro"`) only for labels that are themselves code or data identifiers, never for prose titles or axis labels.
- Pick one font family per deliverable and hold it across every figure. Mixing families across a report's figures reads as sloppy even when each figure individually looks fine.

### Setting Fonts Consistently: `BaseStyle` and `LabelStyle`

- `BaseStyle` sets the default style (including font) for the entire graphic, inherited by every text element unless overridden.
- `LabelStyle` sets the style specifically for labels, ticks, and legends, without touching plotted curve/marker styles.
- Prefer setting fonts once via `BaseStyle` or `LabelStyle` over styling every `PlotLabel`, `FrameLabel`, and legend text individually. Individual overrides are for the rare label that must stand out (e.g., a warning annotation in red).

```wl
Plot[Sin[x], {x, 0, 2 Pi},
	Frame -> True,
	Axes -> False,
	FrameLabel -> {"x", "sin(x)"},
	PlotLabel -> "Sine Wave",
	BaseStyle -> {FontFamily -> "Source Sans Pro", FontSize -> 12}
]
```

### Font Size Hierarchy

Maintain a clear size relationship between title, axis labels, and tick labels so the eye reads importance correctly:

| Element | Typical size (relative) | Notes |
| --- | --- | --- |
| `PlotLabel` | Largest (e.g., 16-18pt) | Bold via `FontWeight -> Bold` if it must stand apart from the frame labels |
| `FrameLabel` / `AxesLabel` | Medium (e.g., 13-14pt) | Regular weight is usually sufficient |
| Tick labels | Smallest (e.g., 10-11pt) | Set via `LabelStyle`; ticks should never outweigh the axis label they annotate |
| Legend text | Match `FrameLabel` size | A legend is peer information to the axes, not a subordinate detail |

Avoid setting every text element to the same size; a flat hierarchy makes the title indistinguishable from a tick label and forces the viewer to work out importance from position alone.

### `FontWeight` and `FontColor`

- Use `FontWeight -> Bold` sparingly: the title, or a single callout that must draw the eye first. Bolding everything defeats the purpose.
- Set `FontColor` via `LightDarkSwitched` when it must differ from the theme-default text color (see "Color" below); never hard-code `Black` for label text meant to render in both themes.

---

## Color

### Standard Colors and Dark Mode

Follow @WOLFRAMCODINGGUIDE.md's non-negotiable color rules for every visualization:

- Use Standard color names (`StandardBlue`, `StandardRed`, `StandardGreen`, `StandardOrange`, `StandardYellow`, `StandardPurple`, `StandardGray`) for individual series, markers, and highlight colors, instead of `RGBColor[...]` or `Darker[Blue, 0.4]`.
- Use `LightDarkSwitched[lightValue, darkValue]` for any color that must differ between light and dark themes: text color, background fills, gridline color.
- Never hard-code `Background -> White` on a `Graphics`, `Plot`, chart, or `Graph`. If a solid background is genuinely required for a specific deployment (a fixed-background slide, a PNG dropped into a white document), set it on the `Export` call, not on the graphic expression itself, so the same graphic still renders correctly in-notebook under either theme.

### Palettes for Multiple Series

- For a small number of categorical series (up to about 8), `ColorData["Pastel"]`, `ColorData["Rainbow"]`, or an explicit list of Standard colors all work; pick one palette per deliverable and reuse it across figures so the same category always gets the same color.
- For a continuous scalar mapped to color (`DensityPlot`, `ArrayPlot`, `ColorFunction` on a chart), use a perceptually uniform palette appropriate to the data: sequential (`"TemperatureMap"`, `"SolarColors"`) for data with a natural low-to-high order, diverging (`"TemperatureMap"` centered at zero, `"DarkRainbow"`) for data with a meaningful midpoint (e.g., positive/negative deviation from a baseline).
- Check that categorical palettes remain distinguishable for the most common forms of color vision deficiency; avoid relying on a red/green distinction as the only differentiator between two series. Where two series must be told apart by more than color, add a secondary channel (`PlotMarkers`, dashing via `PlotStyle -> {..., Dashed}`).
- `ColorFunction -> "..."` accepts named gradients directly; prefer these named schemes over constructing a custom `Blend` unless the deliverable has a specific brand palette to match.

### `PlotStyle` vs. `ColorFunction`

- `PlotStyle` assigns a fixed style (color, thickness, dashing) per series; use it for a fixed, small number of named series (each line in a legend gets one `PlotStyle` entry).
- `ColorFunction` maps a coordinate or value to color dynamically; use it for continuous data (surfaces, densities, heat maps) or when color itself encodes a third data dimension beyond `x` and `y`.
- Don't use `ColorFunction` to fake a discrete legend; if there are three named series, three `PlotStyle` entries with `PlotLegends` are clearer than a `ColorFunction` that happens to produce three colors.

---

## Embellishments and Annotations

### `Epilog` and `Prolog`

- `Epilog` draws on top of the finished plot; use it for annotations that must sit above the data (callouts, highlight markers, reference points).
- `Prolog` draws beneath the plot, before axes and data; use it for background shading (e.g., marking a region of interest) that data should render on top of.
- Keep `Epilog`/`Prolog` primitives few and purposeful. A plot cluttered with many small annotations usually means the underlying data should be re-summarized or split across multiple panels instead.

```wl
Plot[Sin[x], {x, 0, 2 Pi},
	Frame -> True,
	Axes -> False,
	Epilog -> {
		StandardRed,
		PointSize[Medium],
		Point[{Pi / 2, 1}],
		Text[Style["max", 11], {Pi / 2, 1}, {-1.4, 0}]
	}
]
```

### `Callout` for Data-Attached Labels

Prefer `Callout[expr, label]` over manually computed `Text` placement when a label needs to attach to a specific data point and avoid overlapping the curve itself; `Callout` handles leader-line placement automatically.

```wl
ListPlot[Callout[#, ToString[#]] & /@ {{1, 5}, {2, 3}, {3, 8}},
	Frame -> True,
	Axes -> False,
	FrameLabel -> {"x", "y"}
]
```

### `Inset` for Composite Figures

Use `Inset[graphic, position, alignment, size]` to place one graphic inside another (an inset zoom panel, a small legend built as its own `Graphics`, a logo). Choose `position` and `alignment` so the inset never overlaps the primary data region; a zoomed inset showing the same data at higher resolution should sit in an empty corner of the plot range, established by checking the data's `PlotRange` first.

### General Placement Guidance

- Text and callouts should never overlap plotted curves, bars, or points. If default placement causes overlap, pass an explicit offset (the second argument to `Text`) rather than accepting the collision.
- Keep annotation font size close to tick label size; an annotation styled at title size competes with the actual title for attention.
- A reference line (a target value, a threshold) is better drawn as a styled `Line`/`InfiniteLine` in `Epilog` with a small adjacent `Text` label than as a legend entry; legend entries are for data series, not fixed reference values.

---

## Sizing, Aspect Ratio, and Padding

- Set `ImageSize` explicitly for any figure destined for a document or presentation, rather than relying on the notebook's default; an unspecified size renders inconsistently across export paths. `ImageSize -> 400` (single-column figure) and `ImageSize -> 600` (full-width figure) are reasonable defaults to standardize on within one deliverable.
- `AspectRatio -> 1` for figures where the x and y axes represent the same physical quantity (a scatter of two comparable measurements, a geographic plot); leave `AspectRatio -> Automatic` (or a wide ratio like `1/GoldenRatio`) for time series and general function plots.
- `PlotRangePadding -> Scaled[0.05]` (or similar) keeps data points near the plot range boundary from being clipped by the frame; the default is usually adequate, but tighten it (`PlotRangePadding -> None`) for tiled/heatmap-style plots (`ArrayPlot`, `MatrixPlot`) where padding introduces a visually confusing border.
- Add `GridLines -> Automatic` (or explicit gridline positions) only when the viewer needs to read approximate values off the axes; omit gridlines from purely illustrative figures where exact readout doesn't matter, since gridlines add visual weight that competes with the data.

---

## Multi-Panel Figures

- Combine related panels into one figure with `PlotGrid`, `GraphicsGrid`, or `GraphicsRow`/`GraphicsColumn`, rather than manually positioning several `Graphics` expressions with `Inset`. See "PlotGrid vs. GraphicsGrid" below to choose between them.
- Fix a single `ImageSize`, `BaseStyle`, and axis-range convention across all panels in a grid, so the panels read as one figure rather than several unrelated plots placed side by side. When using `GraphicsGrid` (which does not align ranges itself), compute a shared `PlotRange` up front so panels stay visually comparable.
- Put the figure's overall title on the enclosing `Column`/`Grid` (e.g., via `Column[{Style["Overall Title", Bold, 16], GraphicsGrid[...]}]`), not repeated identically on every panel.
- When only one panel in a grid needs a legend (because all panels share the same series), place a single shared legend outside the grid rather than repeating it in every panel.

### `PlotGrid` vs. `GraphicsGrid`

Both lay panels out in a grid, but they solve different problems:

- `GraphicsGrid` is a pure layout tool. Each panel keeps whatever `PlotRange`, ticks, and frame it was built with; nothing about the panels' scales is coordinated. Use it when the panels are genuinely unrelated (different quantities, different units) and only need to sit next to each other.
- `PlotGrid` lays panels out **and** aligns their plot ranges to shared x/y scales, so corresponding ticks and gridlines line up across the grid, the way small-multiples panels should. Reach for it whenever the panels show the same or comparable quantities and must be visually compared row-to-row or column-to-column, for example the same measurement across several categories, or several parameter sweeps of the same model.

```wl
sweepPlots = Table[
	Plot[Sin[k x], {x, 0, 2 Pi}, PlotLabel -> "k = " <> ToString[k], Frame -> True, Axes -> False, FrameLabel -> {"x", "sin(k x)"}],
	{k, 1, 4}
]

PlotGrid[Partition[sweepPlots, 2], "AllRows"]
```

`PlotGrid[plots]` takes a two-dimensional list of plots, `{{p11, p12, ...}, {p21, ...}, ...}`, mirroring the grid's rows and columns. The second argument controls which scales are shared:

| Value | Effect |
| --- | --- |
| `All` | Every panel shares one x-scale and one y-scale (fully comparable grid). |
| `"AllRows"` | All rows share one y-scale; x-scales are aligned within each column. |
| `"AllColumns"` | All columns share one x-scale; y-scales are aligned within each row. |
| `"Rows"` (or `Automatic`) | Each row shares its own y-scale independently of the other rows. |
| `"Columns"` | Each column shares its own x-scale independently of the other columns. |
| `"RowsColumns"` | Rows and columns are each internally aligned, without forcing one global scale. |
| `None` | No scale sharing; behaves like a scale-unaware grid layout. |

Prefer `All` or `"AllRows"`/`"AllColumns"` when the deliverable's point is a direct comparison across panels (a viewer should be able to line up a y-value across two rows by eye). Use the per-row/per-column forms (`"Rows"`, `"Columns"`, `"RowsColumns"`) when panels fall into logical groups that are comparable within a group but not across groups, so unrelated groups aren't forced onto a common scale that wastes range on one side.

`PlotGrid` accepts most of the same styling options as `Graphics` (`ImageSize`, `BaseStyle`, `Frame`, `PlotLabel`, `Spacings`), plus grid-specific options: `ItemAspectRatio` and `ItemSize` control individual panel proportions and size independent of the grid's overall `AspectRatio`/`ImageSize`, and `Spacings` controls the gap between rows and columns. Wrap an individual panel in `Labeled[...]` or `Legended[...]` before placing it in the grid to attach a per-panel caption or legend; `PlotGrid` respects these wrappers directly.

---

## Exporting Figures

- Set a resolution appropriate to destination: `ImageResolution -> 150` for on-screen/web use, `ImageResolution -> 300` for print.
- As noted under "Color", set any required solid background at `Export` time (`Export["file.png", graphic, Background -> White]`) rather than baking it into the graphic expression, so the in-notebook version still respects the current theme.
- Export vector formats (`"PDF"`, `"SVG"`, `"EPS"`) for figures headed to a typeset document, so text and lines remain sharp at any final print size; reserve raster formats (`"PNG"`, `"JPEG"`) for web use or when the source contains raster elements (embedded photos, density plots with very fine detail).

---

## Quick-Reference Option Tables

### Universal Styling Options (most `Plot`/`Chart`/`Graphics` functions)

| Option | Purpose | Common values |
| --- | --- | --- |
| `PlotLabel` | Figure title | A string, or `Style[...]` for custom formatting |
| `Frame` | Enclosing box with tick-labeled edges | `True`, `{{True, False}, {True, False}}` for partial frames |
| `FrameLabel` | Axis labels on a framed plot | `{"x label", "y label"}` |
| `LabelStyle` | Font/style for labels, ticks, legends | `Directive[FontFamily -> "...", FontSize -> n]` |
| `BaseStyle` | Default style for the whole graphic | Same as `LabelStyle`, broader scope |
| `ImageSize` | Rendered pixel width (or `{w, h}`) | `360`, `500`, `{600, 400}` |
| `AspectRatio` | Height-to-width ratio | `Automatic`, `1`, `1/GoldenRatio` |
| `PlotLegends` | Automatic per-series legend | `{"a", "b"}`, `Automatic`, `Placed[..., position]` |
| `GridLines` | Reference lines at tick positions | `Automatic`, `None`, explicit list |
| `PlotRangePadding` | Margin beyond the data's own range | `Automatic`, `Scaled[0.05]`, `None` |

### Chart-Specific Options

| Function | Key options |
| --- | --- |
| `BarChart` / `PieChart` | `ChartLabels`, `ChartStyle`, `ChartLegends`, `LabelingFunction` |
| `Histogram` | `"PDF"`/`"Probability"`/`"Count"` binning spec, `ChartStyle` |
| `DateListPlot` | `DateTicksFormat`, `Joined -> True` for a connected time series |
| `Graph` | `VertexLabels`, `EdgeLabels`, `GraphLayout`, `VertexStyle`, `EdgeStyle` |
| `DensityPlot` / `ArrayPlot` | `ColorFunction`, `ColorFunctionScaling`, `PlotLegends -> BarLegend[...]` |
| `PlotGrid` | `shared` scale spec (`All`, `"AllRows"`, `"AllColumns"`, `"Rows"`, `"Columns"`, `"RowsColumns"`, `None`), `ItemAspectRatio`, `ItemSize`, `Spacings` |
| `ListPlot` / `ListLinePlot` | `MultiaxisArrangement` (`None`, `All`, explicit group/side spec) for independent per-series y-scales |

---

## Common Pitfalls Checklist

Run through this list before delivering any visualization:

1. ☐ The figure has a title (`PlotLabel`) or self-explanatory frame labels; a viewer does not need external text to know what it shows.
2. ☐ Every plot with quantitative axes is framed: `Frame -> True`, `FrameLabel` on every framed axis, `Axes -> False`, and no `AxesLabel` or `Ticks` (see "Frame Every Plot"). This holds inside a `Manipulate` and for output drawn by a function the code calls.
3. ☐ No hard-coded `Black`/`White` for anything that must render in both light and dark themes; `LightDarkSwitched` used where a color genuinely needs to differ.
4. ☐ Standard color names used for series colors, not raw `RGBColor` or manually darkened built-ins.
5. ☐ A legend is present only when there is more than one series to distinguish, and it does not overlap plotted data.
6. ☐ Font family is consistent with the rest of the deliverable's figures; font size hierarchy (title > axis label > tick label) is respected.
7. ☐ `ImageSize` and `AspectRatio` set deliberately, not left to notebook defaults, for anything destined outside the notebook.
8. ☐ Annotations (`Epilog`, `Callout`, `Text`) do not overlap the data they annotate.
9. ☐ Gridlines are present only when the viewer needs to read approximate values off the axes.
10. ☐ Any background needed for export is set on the `Export` call, not baked into the graphic.
11. ☐ Multi-panel figures share one font, one color convention, and one axis-range convention across panels.
12. ☐ `MultiaxisArrangement` (if used) has no more than two or three distinct scales, and each axis is color-coded to match its series.
