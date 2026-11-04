---
title: 4. A live computation
---

# 4. A live computation

A Jacobi iteration for $-u'' = 0$ on $(0, 1)$, $u(0) = 0$, $u(1) = 1$, advancing a few iterations per frame while
the solution and the convergence history are plotted, and the panel stays responsive.

<<< @/examples/snippets/tut04_live.F90{fortran}

## Advancing inside the loop

<<< @/examples/snippets/tut04_live-advance.F90{fortran}

The computation runs in the frame loop: `steps` iterations per frame, then the frame is drawn. With lazy redraw the
loop would go to sleep three frames after the last input, and the computation with it; `request_frames(1)` in every
frame that advanced keeps it drawing. When `running` turns `.false.` (converged, history full, or unchecked by the
user), the calls stop and the loop goes back to sleep.

The number of iterations per frame is the trade-off between progress and responsiveness: the frame is drawn only
after them. With vsync on, the loop draws at most at the display rate.

## Plotting what has been computed

<<< @/examples/snippets/tut04_live-plots.F90{fortran}

`iterations(1:iter)` and `residual(1:iter)` are contiguous sections of fixed-size arrays: no copy, no reallocation
per frame. With `iter = 0` the line is empty, which is not an error.

::: tip What you learned
A computation inside the frame loop, and `request_frames`. Reference: [Lazy redraw](/guide/frame-loop#lazy-redraw).
For data that changes outside the loop, see the [cookbook](../cookbook#refresh-data-that-changes-on-its-own).
:::

Next: [5. Testing without a display](./05-headless).
