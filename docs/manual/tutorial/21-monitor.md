---
title: 21. A sketch and a monitor
---

# 21. A sketch and a monitor

Two pictures the studio draws itself. The Boundaries form starts with a sketch of the plate, its sides coloured and
named by their condition, that the user clicks; and the run's plot becomes a **monitor**: the residual and a quantity
of the solution on two axes, the values under the pointer, and a window of iterations whose mean is read on the axis.

<Media name="tut21_monitor" video alt="F5 runs the plate case. The Monitor plot of the Run panel draws the residual falling on a logarithmic left axis and the plate's mean temperature on a right axis labelled mean T [C], from 40 down to 27. The pointer over the plot writes the iteration, the residual and the mean temperature of the nearest iteration beside it, iteration 92, and tags 92 on the x axis. The left end of the averaging window, a white vertical line at iteration 1, is dragged right; the tag on the right axis, mean 28.502 before, changes with it. In Input, Boundaries: a sketch of the plate in grey with the body as a light disc, west in orange labelled west 100.0 C, east in blue-grey labelled east insulated, south and north in orange at 20.0 C; the pointer on the north side draws it thicker; a click on the east side shades the east row of the table below" caption="docs/examples/src/tut21_monitor.F90, run as tut21_monitor --examples /tmp/figure-studio --case /tmp/figure-studio/plate" />

The whole program: [tut21_monitor.F90](https://github.com/szaghi/figure/blob/main/docs/examples/src/tut21_monitor.F90),
chapter 20's studio with the changes below; its solver is
[tut21_heat.F90](https://github.com/szaghi/figure/blob/main/docs/examples/src/tut21_heat.F90), chapter 11's with one
more number on each line, the plate's mean temperature:

<<< @/examples/snippets/tut21_heat-print.F90{fortran}

## The monitor

<<< @/examples/snippets/tut21_monitor-monitor.F90{fortran}

- **Two y axes.** `ip_setup_axis('y2', ...)` turns on the second y axis, on the right; `ip_set_axes('x1', 'y2')`
  sends the next items to it ([Axes](/guide/plots#axes)). Each axis fits its own items: the residual over several
  decades on a log scale, the temperature in degrees on a linear one. `auto_fit` follows the data every frame (here
  the x axis only while the run goes on, so that the user can zoom a finished run).
- **Integer abscissae.** `steps` holds the iteration numbers as `integer(int32)`; FIGURE converts them for ImPlot,
  which reads `x` and `y` of one type, and reads the ordinates in place
  ([Data in place](/guide/plots#data-in-place)).
- The legend is above the plot area, its entries in a row (`ip_setup_legend`).

## What is under the pointer

<<< @/examples/snippets/tut21_monitor-readout.F90{fortran}

`ip_plot_hovered()` is true while the pointer is over the plot area; `ip_plot_mouse(x, y, xaxis, yaxis)` gives where
it is in the units of the axes named: iterations and residual here ([Reading a plot](/guide/plots#reading-a-plot)).
The studio finds the nearest iteration printed, tags it on the x axis (`ip_tag`, a value in a box on the axis) and
writes the values beside the pointer (`ip_text`, at a point of the plot, `offset` in pixels). Both are drawn in the
axes current when they are called: the text goes back to `y1`, where `y` was read.

## An averaging window

<<< @/examples/snippets/tut21_monitor-window.F90{fortran}

The window's two ends are drag lines, `ip_drag_line_x(id, x)`, which update the variables in place and return `.true.`
while dragged ([Marks in a plot](/guide/plots#marks-in-a-plot)). Until the user moves them they span the whole run.
The mean of the temperature over the window is tagged on the second axis, in the colour of the last item drawn, the
mean temperature's line. A monitor of a real solver averages a lift coefficient this way over its last periods.

## A sketch on a canvas

<<< @/examples/snippets/tut21_monitor-sketch.F90{fortran}

- `ig_canvas(id, width, height, ev)` places an area that takes the mouse; `ev` tells what happened over it on this
  frame: `hovered`, `clicked(1)`, the pointer `mouse` from its top-left corner, its `origin` on the screen and its
  `size` ([Canvas](/guide/canvas)). A width of -1 is the width of the form, less one pixel.
- The primitives draw in screen pixels: the program maps the plate's metres to pixels itself, y up on the plate and
  down on the screen.
- **Hit testing is the program's:** the canvas reports the pointer, and `segment_distance` finds the side within 6
  pixels of it. That side is drawn thicker; a click chooses it, and the table shades its row.
- **Colour is never the only sign:** each side is labelled with its name and its condition, `west 100.0 C`,
  `east insulated`.

## The test

<<< @/examples/snippets/tut21_monitor-monitor_test.F90{fortran}

<<< @/examples/output/tut21.txt{text}

(The `ig_end_tab` line is the report of [chapter 18](./18-checks#the-test-fails-on-any-mistake)'s deliberate mistake.)

::: tip What you learned
A second y axis and items sent to it; integer abscissae; the pointer read in plot units, tagged on an axis and written
beside it; drag lines as an averaging window; a canvas with drawing primitives and the program's own hit testing.
Reference: [Axes](/guide/plots#axes), [Reading a plot](/guide/plots#reading-a-plot),
[Marks in a plot](/guide/plots#marks-in-a-plot), [Canvas](/guide/canvas).
:::

**Next:** [22. The field and its snapshots](./22-player): the field coloured through a colormap in one call, a legend
whose range the user drags, and a player over the snapshots the solver writes.
