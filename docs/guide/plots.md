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
| `ip_setup_axes(xlabel, ylabel [, auto_fit] [, xlog] [, ylog] [, xformat] [, yformat] [, stat])` | Axis labels. Call it right after `ip_begin_plot`, before any item. The axes fit the data on first use, then follow the user's pan and zoom; with `auto_fit=.true.` they refit to the data every frame (a history that grows while the program runs) and the user cannot pan or zoom them. `xlog=.true.`/`ylog=.true.`: a base-10 logarithmic axis (residual histories, spectra); values <= 0 are not shown on it. `xformat`/`yformat`: a C `printf` format of the tick labels (`'%.4f'`, `'%.2e'`, `'%g s'`), for values whose default labels look alike; checked ([Formats](#formats)). |
| `ip_setup_axes_limits(xmin, xmax, ymin, ymax [, always])` | Initial axis ranges, applied on first use (the user pans and zooms afterwards), or every frame with `always=.true.`. Right after `ip_begin_plot`. |
| `ip_plot_limits(xmin, xmax, ymin, ymax)` | The axis ranges as the user has panned and zoomed them, this frame. After the `ip_setup_*` calls (it ends the setup phase). |
| `ip_plot_size(width, height)` | The size of the plot's data area [pixels], e.g. to compute an image at the screen's resolution. |
| `ip_line(label, x, y [, spec] [, stat])` | A line through `(x(i), y(i))`. `label` is the legend entry. |
| `ip_end_plot()` | Only when `ip_begin_plot` returned `.true.`. |

Unlike `ig_begin`/`ig_end`, the plot pair is conditional: call `ip_end_plot` inside the `if` (an `ip_end_plot` after
a false begin, or with another scope innermost, is refused and reported: [Pairing and frames](errors#pairing-and-frames)).
A title that starts with `##` hides the title and keeps the identifier:

<<< @/examples/snippets/tut03_plots-untitled.F90{fortran}

The user can pan (drag), zoom (wheel, or drag a box with the right button), autofit (double-click), and hide a line
by clicking its legend entry; these are ImPlot's interactions, kept by ImPlot from frame to frame.

## Items

Every item is generic over `real(real32)` and `real(real64)` (all its arrays of the same kind; the abscissae may also
be `integer(int32)` or `integer(int64)`), reads arrays of any stride in place ([Data in place](#data-in-place)), takes
a legend `label`, an optional [`spec`](#item-style) and an optional [`stat`](errors).

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

Fields are items too: `ip_heatmap` colours the cells of a 2D array through a colormap, and `ip_colormap_scale` draws
its colour bar ([Heatmaps](images#heatmaps)); the colormap is chosen by name with `ip_colormap`, among the bundled
scientific maps, ImPlot's own and the user's ([Colormaps](colormaps)).

### Formats

Labels of numbers take a C `printf` format: the tick labels (`ip_setup_axes`' `xformat` and `yformat`), the values in
a heatmap's cells and on its colour bar (`label_format` of `ip_heatmap`, `ip_colormap_scale`,
`ip_colormap_legend`), and the number widgets (`ig_input`, `ig_drag`, `ig_slider`, `ig_slider_angle`,
`ig_drag_range`: [Numbers](widgets#numbers)). The plots print reals, and FIGURE checks the format before Dear ImGui or
ImPlot uses it:

- **exactly one conversion of a real:** `f` or `F` (fixed point), `e` or `E` (exponent), `g` or `G` (the shorter of
  the two), `a` or `A` (hexadecimal);
- before the conversion letter, optional **flags** (`-` left-justified, `+` sign always, a blank for a positive
  sign, `#`, `0` zero-padded), a **width** and a **precision** (`.` and digits), all as digits, never `*`;
- **any other text** around it, and any number of `%%` (a percent sign).

| Format | Prints 1234.5678 as | Resembles Fortran's |
|---|---|---|
| `'%.2f'` | `1234.57` | `F0.2` |
| `'%10.3f'` | `  1234.568` | `F10.3` |
| `'%.3e'` | `1.235e+03` | `ES10.3` |
| `'%g'` | `1234.57` | `G0` (6 significant digits) |
| `'T = %.1f K'` | `T = 1234.6 K` | `'T = ', F0.1, ' K'` |
| `'%.0f%%'` | `1235%` | `F0.0, '%'` |

Refused with `FIG_ERR_ARGUMENT` (`stat` absent: `error stop`), nothing drawn: a conversion of an integer or of
text (`'%d'`, `'%i'`, `'%s'`), `%n`, `*` (`'%*f'`, `'%.*f'`), a length modifier (`'%lf'`, `'%Lg'`), no conversion
(`'no conversion'`, `''`) or more than one (`'%f %f'`), a `%` at the end. One exception, kept from v0.3.0:
`ip_colormap_legend` takes a `label_format` without conversion as text, printed as it is, and `''` as its default
([Colormaps](colormaps#a-colour-scale-legend)). The message names the procedure, the
argument and the format: `ip_setup_axes: xformat '%s' is not a format of a real: one conversion %f, %e, %g or %a (or
%F, %E, %G, %A) expected, with optional flags, width and precision` ([Errors](errors)).

The number widgets take a format of their value's family: a real's as above, and for `int32` and `int64` values one
conversion `d`, `i` or `u` under the same rules (`'%5d'`, `'%d cells'`); an `int64`'s is written as an `int32`'s,
and FIGURE adds the length modifier C needs (`'%lld'`). A conversion longer than 24 characters is refused too (Dear
ImGui copies it into a buffer of 32 bytes).

C's formatter reads the value as the format says, and a format that does not match it is undefined behaviour: before
v0.3.1 a `'%d'` given for a real printed a wrong label, and a `'%n'` for a heatmap's labels stopped the program
(`%n in writable segment detected`, glibc on Linux). The same in every mode: **window**,
**headless** and **remote**.

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

## Data in place

The items (`ip_line`, `ip_scatter`, `ip_bars`, `ip_shaded`, `ip_error_bars`) read the program's arrays where they are,
during the call, and keep no pointer to them afterwards. They go to ImPlot's `float*` or `double*` items with ImPlot's
byte stride (`ImPlotSpec::Stride`), so an array does not have to be contiguous:

| What the program passes | Stride ImPlot reads with | Copied by FIGURE |
|---|---|---|
| a whole array, `a(1:n)`, a matrix column `a(:, j)` | the element size | nothing |
| `a(::2)`, a matrix row `a(i, :)`, `q(1, :, k)`, `runs%cl` (a component of an array of derived types) | the distance between two elements [bytes] | nothing, when `x` and the ordinates have the same stride |
| `x` and `y` with different strides (`ip_line(label, t, history(i, :))`) | the stride of `y` | `x`, laid out at the stride of `y` |
| integer abscissae, `integer(int32)` or `integer(int64)` (`ip_line(label, runs%iter, runs%cl)`) | the stride of `y` | `x`, converted to the kind of `y` |
| a reversed section, `a(n:1:-1)` (negative stride) | the element size | every array of the item |

The ordinates (`y`, `y1`, `err` ...) set the stride: ImPlot has one stride for all the arrays of an item, so an array
whose stride differs is copied, once per call, into a temporary laid out at the ordinates' stride (as large as the
ordinates' span: `n` times the stride). An item copies at most its abscissae when the ordinates share a stride. Integer
abscissae are always converted (ImPlot reads `x` and `y` of one type); the ordinates stay in place. `test_plot_copies()`
counts the arrays FIGURE copied and `test_plot_stride()` gives the stride of the last item ([Testing](testing)).

**What arrives is the compiler's choice.** A Fortran compiler may copy a non-contiguous actual argument into a
contiguous temporary before the call, and then FIGURE reads that copy (contiguous, nothing more to copy):

| Actual argument | gfortran 16.2 | nvfortran 26.9 | ifx 2025.3 |
|---|---|---|---|
| `a(::2)`, `a(i, :)`, `q(1, :, k)`, `a(n:1:-1)` | in place | copied by the compiler | in place |
| `runs%cl` (a component of an array of derived types) | copied by the compiler | copied by the compiler | in place |

(measured with `figure_test_plot_data`, which probes the compiler and prints what it passed in place). The plot is
the same in every case; the cost is not.

**Measured cost** of one `ip_line` per frame, headless, gfortran 16.2 `-O2`, i9-13900KF (`ip_setup_axes_limits` fixed,
so ImPlot draws every point):

| Data | 100 000 points [ms/frame] | 1 000 000 points [ms/frame] |
|---|---|---|
| contiguous `x`, `y` | 0.60 | 7.3 |
| `x(::2)`, `y(::2)`, read in place with a stride | 0.69 | 7.8–8.2 |
| integer `x` (converted), contiguous `y` | 0.62 | 7.8–8.3 |
| contiguous `x`, `y(::2)` (`x` copied at the stride of `y`) | 0.77 | 8.9–9.5 |
| `runs%t`, `runs%cl` (both copied by gfortran into temporaries) | 0.76 | 11.4–11.7 |
| `x(::2)`, `y(::2)` packed by the program into buffers allocated once | 0.71 | 9.6–10.0 |

ImPlot's own work dominates: a stride costs about 7 % over contiguous data, a copy made by FIGURE 20 %, the compiler's
temporaries of a derived type's components 55 % (allocated and freed at every call). Over a few hundred thousand
points, decimate before plotting ([Performance](performance#large-data)).

::: warning Changed in v0.4.0
Until v0.3.1 the items' arrays were `contiguous` dummies: every non-contiguous actual argument (`a(i, :)`, `a(::2)`,
`runs%cl`) was copied by the compiler at every call, and integer abscissae did not compile. From v0.4.0 the dummies
are assumed-shape without `contiguous` and `target`, the stride goes to ImPlot, and `ip_line`, `ip_scatter`,
`ip_bars`, `ip_shaded` and `ip_error_bars` accept `integer(int32)` and `integer(int64)` abscissae. Every v0.3.1 call
compiles and draws as before. `ip_line(label, y, row)` stays: it reads a row of a contiguous matrix in place on every
compiler, where `ip_line(label, y(row, :))` depends on the compiler.
:::

What it does not do:
- integer ordinates: `y` is `real(real32)` or `real(real64)`;
- abscissae of one real kind and ordinates of the other: both `real(real32)` or both `real(real64)`;
- the fields (`ip_heatmap`, `ip_contour`) are rank-2 and keep their contract: a contiguous field is read in place, a
  section of one is copied by the compiler.

`real(real32)`/`real(real64)` passed as `float`/`double` rely on being the same types as `real(c_float)`/
`real(c_double)`, true on every compiler FIGURE supports; their addresses are passed with `c_loc` of their first
element, the stride from the addresses of the first two.

Series of different sizes are an error (`FIG_ERR_ARGUMENT`, message `<item>: the series have different sizes`, see
[Error handling](errors)): nothing is drawn. Empty series draw nothing and are not an error.

Modes: the same in window, headless and remote mode (the data become vertices on the CPU). Threads: a task does not
draw (`FIG_ERR_STATE`, see [processes](processes)). Example: [Plot the history a solver keeps, in place](/manual/cookbook#plot-the-history-a-solver-keeps-in-place).

## Several plots in one figure

<<< @/examples/snippets/cb_subplots-subplots.F90{fortran}

<Media name="cb_subplots" video alt="A drag history and a moment history in one figure; zooming one with the wheel zooms the other" caption="docs/examples/src/cb_subplots.F90: linked x axes, and tick labels printed with '%.4f'" />

| Procedure | Notes |
|---|---|
| `ip_begin_subplots(title, rows, cols [, width] [, height] [, link_x] [, link_y])` → `logical`, `ip_end_subplots()` | A grid of plots; the plots inside it (`ip_begin_plot`/`ip_end_plot`) fill the cells row by row. End only after a true begin. |

- `link_x` (`link_y`): the plots share the x (y) range, so panning or zooming one moves all.
- The first time a figure is drawn its plots fit to their data; linked axes then take the range of the last plot
  (the common abscissa, in practice). ImPlot itself gives linked axes no initial fit.
- Size as `ip_begin_plot`: a negative `height` fills the space left; the default is 300 pixels per row.

## Error bars, annotations and drag tools

| Procedure | Notes |
|---|---|
| `ip_error_bars(label, x, y, err [, err_high] [, spec] [, stat])` | Vertical error bars (`PlotErrorBars`) at `(x(i), y(i))`, from `y(i) - err(i)` to `y(i) + err(i)`, or to `y(i) + err_high(i)` when given (asymmetric). Generic over `real(real32)` and `real(real64)`, read in place as the other items. The whisker width is `ip_spec(size=)` [pixels]. |
| `ip_annotation(x, y, text [, color] [, offset] [, stat])` | A text (`Annotation`) at the plot point `(x, y)`, drawn when the plot ends, over the items, kept inside the plot area. Without `color`: the text alone in the plot's text colour; with it: in a box of that colour (RGBA in [0, 1]), the text black or white for contrast. `offset`: `[dx, dy]` [pixels], x right, y down, with a leader line to the point; a zero component centres the text on the point along that axis (the default). |
| `ip_drag_line_x(id, x [, color] [, thickness] [, stat])` → `logical` | A vertical line at `x` that the user drags along x (`DragLineX`). `x` (`real(real64)`) is updated in place; `.true.` in the frames it moves. `thickness` [pixels], default 1. |
| `ip_drag_line_y(id, y [, color] [, thickness] [, stat])` → `logical` | A horizontal line at `y`, dragged along y (`DragLineY`). |
| `ip_drag_point(id, x, y [, color] [, radius] [, stat])` → `logical` | A point dragged in both directions (`DragPoint`); `radius` [pixels], default 4. |

<<< @/examples/snippets/cb_contour-probes.F90{fortran}

<<< @/examples/snippets/cb_contour-profile.F90{fortran}

<Media name="cb_contour" video alt="Three plots. Top left: two vortices as a heatmap with black contour lines labelled with their values. Top right: the same lines coloured by value around a circular hole marked NaN, a white vertical line and a white point. The vertical line is dragged left to x = 1.1 and the profile plot below, the field along that line with error bars on nine samples, gets a gap where the line crosses the hole. Then the point is dragged into the hole, its label reads 'inside the body', and on to the right vortex, where it reads g = -0.484." caption="docs/examples/src/cb_contour.F90: contour lines, a drag line choosing the profile, a drag point with an annotation" />

- Call them between `ip_begin_plot` and `ip_end_plot`, after the setup (`ip_setup_axes*`).
- `id` tells the drag tools of one plot apart: any integer, unique among them. The drag tools are not items: they
  have no legend entry, but their positions take part in fitting the axes.
- A drag tool only moves its variable; constraints are the program's: clamp the value when the result is `.true.`,
  as the example does. Without `color`, a drag tool is drawn in the style's text colour.
- An annotation is not an item either: no legend entry, and it does not take part in fitting the axes.
- Statuses: `FIG_ERR_ARGUMENT` for a colour without 4 components, an offset without 2, error-bar arrays of
  different sizes; `FIG_ERR_STATE` for `ip_annotation` outside a plot, and for any of them from a
  [task](processes#tasks). `stat` is optional (absent: `error stop` with the message).
- Modes: the same in **window**, **headless** and **remote** mode. In headless mode the drag tools answer synthetic
  input (`test_drag`, [Testing](testing)); in remote mode the browser's pointer drags them.

## Contour lines

ImPlot has no contour lines: FIGURE computes them in Fortran (marching squares) and draws them as ImPlot line
segments.

| Procedure | Notes |
|---|---|
| `ip_contour(label, f, x0, x1, y0, y1 [, levels] [, nlevels] [, colormap] [, color] [, labels] [, line_weight] [, stat])` | The contour lines of the field `f(i, j)` in the current plot. `f` is `real(real32)` or `real(real64)`, read in place (any array, sections too). The segments are computed at every call and drawn as one line item per level, with one legend entry, `label`. |
| `ip_contour_lines(f, x0, x1, y0, y1, levels, x, y, first)` | The same segments without drawing them, a `pure` subroutine (no GUI needed): `x(:)`, `y(:)` (`real(real64)`, allocatable) hold the segments' ends in pairs, level `k`'s from `first(k)` to `first(k+1) - 1` (`integer(int64)`, allocatable, `size(levels) + 1`). |
| `ip_contour_levels(f [, count])` → `real(real64)` array | About `count` (default 10) levels at round numbers strictly inside the finite range of `f`: the multiples of a step of 1, 2, 2.5 or 5 times a power of ten, the smallest such step not below the range over `count`. None for a constant field, one with no finite value, or `count < 1`. `pure`. |

<<< @/examples/snippets/cb_contour-contour.F90{fortran}

- **Sampling.** `f(i, j)` is the value at `x = x0 + (i - 1) (x1 - x0) / (size(f, 1) - 1)` and
  `y = y0 + (j - 1) (y1 - y0) / (size(f, 2) - 1)`: `x0`, `x1`, `y0`, `y1` are the positions of the first and last
  samples, as in a node-based grid. A [heatmap](images#heatmaps) takes the outer edges of its cells instead: to lay
  the lines over a heatmap of the same array, give the heatmap bounds half a spacing beyond the samples, as above.
  The grid is uniform along each axis; curvilinear and unstructured grids are not supported.
- **Levels.** `levels` (`real(real64)`, any order) or, without it, `ip_contour_levels(f, nlevels)`; `nlevels` < 1
  is refused.
- **Colours.** With `colormap` (an id from [`ip_colormap`](colormaps)) each level takes the map's colour at its
  value placed in the field's finite range, as a heatmap of `f` with the same map and no fixed scale colours it;
  with `color` (RGBA in [0, 1]) every level has that colour; with neither, the item's automatic colour.
  `line_weight` [pixels].
- **Labels.** `labels=.true.` writes each level's value in a box of its colour on one of its segments (an
  annotation, drawn when the plot ends). The segment is taken part-way through the level's segments, a different
  fraction for each level, so the labels of nearby levels fall apart; they can still overlap where lines crowd.
- **The algorithm.** Each cell of four neighbouring samples is cut by a level where linear interpolation along an
  edge gives it; a value equal to the level counts as above it. A saddle cell (two opposite corners above, the other
  two below) is resolved by its centre value, the mean of its corners: the corners on the centre's side are joined.
  A shared edge gives the same point in both its cells, so closed lines close.
- **Holes.** A cell with a NaN or an infinite corner is skipped: undefined regions (a body in a flow field, cells
  outside a domain) leave holes, not lines to spurious values.
- **Cost.** `ip_contour` visits every cell for every level at each call. For a large field that does not change,
  compute the segments once with `ip_contour_lines` and draw each level with `ip_line` and
  `ip_spec(flags=ImPlotLineFlags_Segments)`.
- Statuses: `FIG_ERR_ARGUMENT` for a colour without 4 components, a colormap that is not registered, `nlevels` < 1,
  or a level with more segment ends than a C `int` counts; `FIG_ERR_STATE` from a [task](processes#tasks).
- Modes: the same in **window**, **headless** and **remote** mode.
- Not done: filled contours (bands between levels: a heatmap of a discrete colormap, `ip_colormap(name, levels)`,
  shows them), smoothing of the lines, labels following the lines' direction.

## Not bound yet

Other items (stems, stairs, histograms, text, ...) and axis setup beyond labels, limits, log scales and
tick formats (time and symmetric-log scales, tick positions) are not wrapped yet. Their raw interfaces are generated ([Raw bindings](raw-bindings)); see the [roadmap](roadmap).
