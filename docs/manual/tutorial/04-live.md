---
title: 4. A live computation
---

# 4. A live computation

A Jacobi iteration for $-u'' = 0$ on $(0, 1)$, $u(0) = 0$, $u(1) = 1$, advancing a few iterations per frame while
the solution and the convergence history are plotted, and the panel stays responsive.

<<< @/examples/snippets/tut04_live.F90{fortran}

<Media name="tut04_live" video alt="Ticking running starts the Jacobi iteration; the solution becomes a straight line and the residual falls to 1e-10" caption="tut04_live: the solver runs inside the frame loop; raising the iterations per frame speeds it up" />

## Advancing inside the loop

<<< @/examples/snippets/tut04_live-advance.F90{fortran}

The computation runs in the frame loop: `steps` iterations per frame, then the frame is drawn. With [lazy
redraw](/guide/frame-loop#lazy-redraw) the loop would go to sleep a few frames after the last input, and the computation with it; `request_frames(1)` in every
frame that advanced keeps it drawing. When `running` turns `.false.` (converged, history full, or unchecked by the
user), the calls stop and the loop goes back to sleep.

The number of iterations per frame is the trade-off between progress and responsiveness: the frame is drawn only
after them. With vsync on, the loop draws at most at the display rate.

## Plotting what has been computed

<<< @/examples/snippets/tut04_live-plots.F90{fortran}

`iterations(1:iter)` and `residual(1:iter)` are contiguous sections of fixed-size arrays: no copy, no reallocation
per frame. With `iter = 0` the line is empty, which is not an error.

A plot fits its axes to the data once, on first use, and then leaves them to the user (pan, zoom, double-click to
fit again). The solution stays in its first box, $[0, 1] \times [0, 1]$; the convergence history grows every frame,
so `auto_fit=.true.` refits its axes every frame and the newest iterations stay in view.

::: tip What you learned
A computation inside the frame loop, and `request_frames`. Reference: [Lazy redraw](/guide/frame-loop#lazy-redraw).
For data that changes outside the loop, see the [cookbook](../cookbook#refresh-data-that-changes-on-its-own).
:::

Next: [5. Testing without a display](./05-headless).
