---
title: Plots
---

# Plots

`figure_implot` binds [ImPlot](https://github.com/epezent/implot) (1.2 WIP): line plots of `real(real64)` arrays.

## A plot

<<< @/examples/snippets/tut03_plots-plot.F90{fortran}

| Procedure | Notes |
|---|---|
| `ip_begin_plot(title [, width] [, height]) → logical` | `.true.` when the plot is visible. `title` is also the identifier: unique within the window. Default size: full width, ImPlot's default height. A negative `height` fills the space left in the window. |
| `ip_setup_axes(xlabel, ylabel)` | Axis labels. Call it right after `ip_begin_plot`, before any item. |
| `ip_line(label, x, y [, stat])` | A line through `(x(i), y(i))`. `label` is the legend entry. |
| `ip_end_plot()` | Only when `ip_begin_plot` returned `.true.`. |

Unlike `ig_begin`/`ig_end`, the plot pair is conditional: call `ip_end_plot` inside the `if`. A title that starts
with `##` hides the title and keeps the identifier:

<<< @/examples/snippets/tut03_plots-untitled.F90{fortran}

The user can pan (drag), zoom (wheel, or drag a box with the right button), autofit (double-click), and hide a line
by clicking its legend entry; these are ImPlot's interactions, kept by ImPlot from frame to frame.

## Arrays: the zero-copy contract

`ip_line` declares `x` and `y` as `real(real64), contiguous, intent(in)` and passes them to the C `double*` of the
glue, which hands them to `ImPlot::PlotLine`. The arrays are read in place during the call, and nothing keeps a
pointer to them afterwards:

- a contiguous array or array section (a whole array, `a(1:n)`, a matrix column `a(:, j)`) is passed without any
  copy;
- a non-contiguous section (a matrix row `a(i, :)`, `a(1:n:2)`) is copied by the compiler into a contiguous
  temporary, every call. For large data drawn every frame, store series as columns, or copy rows into a buffer you
  reuse ([cookbook](/manual/cookbook#plot-the-rows-of-a-matrix)).

`real(real64)` passed as `double` relies on the two being the same type; the `bind(C)` interfaces use
`real(c_double)`, so a platform where they differ fails at compile time rather than at run time.

`size(x) /= size(y)` is an error (`FIG_ERR_ARGUMENT`, see [Error handling](errors)): nothing is drawn. An empty pair
of arrays draws nothing and is not an error.

## Not bound yet

Other item types (scatter, bars, shaded areas, heatmaps), axis flags (log scales, limits), `real32` data and strided
series without copies are milestone M3 of the [roadmap](roadmap).
