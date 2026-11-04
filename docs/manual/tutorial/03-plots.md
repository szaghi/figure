---
title: 3. Plots
---

# 3. Plots

The first three vibration modes of a string, one per column of a matrix.

<<< @/examples/snippets/tut03_plots.F90{fortran}

## A plot

<<< @/examples/snippets/tut03_plots-plot.F90{fortran}

- `ip_begin_plot` begins a plot 300 pixels high, full width; it returns `.true.` when the plot is visible, and only
  then are its items declared and `ip_end_plot` called.
- `ip_setup_axes` labels the axes; it comes before the items.
- `ip_line(label, x, y)` draws a line; `label` is its legend entry. `modes(:, k)` is a column, contiguous: ImPlot
  reads it in place, without a copy.

In the window, drag to pan, use the wheel to zoom, double-click to fit, click a legend entry to hide its line.

## A plot without title

<<< @/examples/snippets/tut03_plots-untitled.F90{fortran}

The title is also the plot's identifier: `'##first mode'` keeps an identifier and shows no title.

::: tip What you learned
Plots, axes, lines, and why columns are cheaper than rows. Reference: [Plots](/guide/plots).
:::

Next: [4. A live computation](./04-live).
