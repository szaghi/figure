---
title: Plots
---

# Plots

`figure_implot` binds [ImPlot](https://github.com/epezent/implot) (1.2 WIP): lines, markers, bars and shaded areas of
`real(real32)` or `real(real64)` arrays, styled with `ip_spec`.

## A plot

<<< @/examples/snippets/tut03_plots-plot.F90{fortran}

| Procedure | Notes |
|---|---|
| `ip_begin_plot(title [, width] [, height] [, equal]) → logical` | `.true.` when the plot is visible. `title` is also the identifier: unique within the window. Default size: full width, ImPlot's default height. A negative `height` fills the space left in the window. `equal=.true.`: one unit spans as many pixels on x as on y (maps, the complex plane). |
| `ip_setup_axes(xlabel, ylabel [, auto_fit] [, xlog] [, ylog])` | Axis labels. Call it right after `ip_begin_plot`, before any item. The axes fit the data on first use, then follow the user's pan and zoom; with `auto_fit=.true.` they refit to the data every frame (a history that grows while the program runs) and the user cannot pan or zoom them. `xlog=.true.`/`ylog=.true.`: a base-10 logarithmic axis (residual histories, spectra); values <= 0 are not shown on it. |
| `ip_setup_axes_limits(xmin, xmax, ymin, ymax [, always])` | Initial axis ranges, applied on first use (the user pans and zooms afterwards), or every frame with `always=.true.`. Right after `ip_begin_plot`. |
| `ip_plot_limits(xmin, xmax, ymin, ymax)` | The axis ranges as the user has panned and zoomed them, this frame. After the `ip_setup_*` calls (it ends the setup phase). |
| `ip_plot_size(width, height)` | The size of the plot's data area [pixels], e.g. to compute an image at the screen's resolution. |
| `ip_line(label, x, y [, spec] [, stat])` | A line through `(x(i), y(i))`. `label` is the legend entry. |
| `ip_end_plot()` | Only when `ip_begin_plot` returned `.true.`. |

Unlike `ig_begin`/`ig_end`, the plot pair is conditional: call `ip_end_plot` inside the `if`. A title that starts
with `##` hides the title and keeps the identifier:

<<< @/examples/snippets/tut03_plots-untitled.F90{fortran}

The user can pan (drag), zoom (wheel, or drag a box with the right button), autofit (double-click), and hide a line
by clicking its legend entry; these are ImPlot's interactions, kept by ImPlot from frame to frame.

## Items

Every item is generic over `real(real32)` and `real(real64)` (all its arrays of the same kind), takes a legend
`label`, an optional [`spec`](#item-style) and an optional [`stat`](errors).

| Procedure | Draws |
|---|---|
| `ip_line(label, x, y [, spec] [, stat])` | a line through `(x(i), y(i))` |
| `ip_line(label, y [, xscale] [, xstart] [, spec] [, stat])` | a line through `y(i)` at `x = xstart + (i - 1) xscale` (defaults 1 and 0) |
| `ip_line(label, y, row [, xscale] [, xstart] [, spec] [, stat])` | a line through the row `row` of the matrix `y`, read in place with a stride (no copy) |
| `ip_scatter(label, x, y [, spec] [, stat])` | markers at `(x(i), y(i))` (a circle when `spec` sets no marker) |
| `ip_bars(label, x, y, bar_size [, spec] [, stat])` | bars of height `y(i)` centred at `x(i)`, `bar_size` wide in x units (`real(real64)`, required: ImPlot has no default for it) |
| `ip_shaded(label, x, y1, y2 [, spec] [, stat])` | the area between the curves `y1(x)` and `y2(x)` |
| `ip_shaded(label, x, y, yref [, spec] [, stat])` | the area between the curve `y(x)` and the line `y = yref` (`real(real64)`) |

<<< @/examples/snippets/cb_items-items.F90{fortran}

<Media name="cb_items" alt="One plot with a blue band, a red line with markers, green bars and a red area to zero" caption="The items above, drawn by docs/examples/src/cb_items.F90" />

The two `ip_shaded` forms are told apart by the fourth argument: an array (`y2`) or a scalar (`yref`). Items are
drawn in the order they are called, each above the previous ones.

## Item style

`ip_spec(...)` returns a `plot_spec_object`: ImPlot's defaults (colours from the colormap, no markers on lines),
with the properties you pass overridden. Build it once, outside the loop, or inline in the call.

<<< @/examples/snippets/cb_items-spec.F90{fortran}

| Argument | Type | Meaning |
|---|---|---|
| `line_color` | `real(real64)`, 4 values | line colour, RGBA in [0, 1] (absent: automatic) |
| `line_weight` | `real(real64)` | line weight [pixels]: lines, bar edges, marker outlines |
| `fill_color` | `real(real64)`, 4 values | fill colour of bars and shaded areas, RGBA |
| `fill_alpha` | `real(real64)` | alpha multiplier of the fill colours |
| `marker` | `integer(int32)` | marker shape: `ImPlotMarker_None`, `_Circle`, `_Square`, `_Diamond`, `_Up`, `_Down`, `_Left`, `_Right`, `_Cross`, `_Plus`, `_Asterisk`, `_Vertical`, `_Horizontal`, `_Auto` |
| `marker_size` | `real(real64)` | marker radius [pixels] |
| `marker_line_color`, `marker_fill_color` | `real(real64)`, 4 values | marker outline and fill colours, RGBA |
| `size` | `real(real64)` | error-bar whisker and digital-bar size [pixels] |
| `flags` | `integer(int32)` | `ImPlotItemFlags_NoLegend`, `_NoFit`, and the item's own: `ImPlotLineFlags_Segments`, `_Loop`, `_SkipNaN`, `_NoClip`, `_Shaded`; `ImPlotScatterFlags_NoClip`; `ImPlotBarsFlags_Horizontal`; combine with `ior` |
| `stat` | `integer(int32)`, out | `FIG_ERR_ARGUMENT` when a colour does not have 4 values |

The constants are ImPlot's own names, exported by `figure`; their values are generated from the cimplot metadata.
`plot_spec_object` has no public components: a spec always starts from ImPlot's defaults, never from zeros (a
zero line weight would draw nothing).

## Arrays: the zero-copy contract

`ip_line` is generic: `x` and `y` are `real(real32)` or `real(real64)` (both of the same kind), declared
`contiguous, intent(in)`, and passed to ImPlot's `float*` or `double*` item through the generated glue
([Raw bindings](raw-bindings)). The arrays are read in place during the call, and nothing keeps a pointer to them
afterwards:

- a contiguous array or array section (a whole array, `a(1:n)`, a matrix column `a(:, j)`) is passed without any
  copy;
- a non-contiguous section (a matrix row `a(i, :)`, `a(1:n:2)`) is copied by the compiler into a contiguous
  temporary, every call. A matrix row with uniform abscissae is better passed whole, `ip_line(label, a, i)`: ImPlot
  reads it in place with a stride ([cookbook](/manual/cookbook#plot-the-rows-of-a-matrix)).

`real(real32)`/`real(real64)` passed as `float`/`double` rely on being the same types as `real(c_float)`/
`real(c_double)`, true on every compiler FIGURE supports; their addresses are passed with `c_loc`.

Series of different sizes are an error (`FIG_ERR_ARGUMENT`, message `<item>: the series have different sizes`, see
[Error handling](errors)): nothing is drawn. Empty series draw nothing and are not an error.

## Not bound yet

Other items (error bars, stems, stairs, histograms, text, ...) and axis setup beyond labels, limits and log scales
(time and symmetric-log scales, ticks) are not wrapped yet. Their raw interfaces are generated ([Raw bindings](raw-bindings)),
([roadmap](roadmap)). In-place rows exist for `ip_line` only; the same `ImPlotSpec` stride serves the other items when
they need it.
