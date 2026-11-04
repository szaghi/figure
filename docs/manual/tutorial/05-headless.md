---
title: 5. Testing without a display
---

# 5. Testing without a display

The panel is a procedure, `draw_panel`, that an application would call every frame. The test calls the same
procedure in headless mode and clicks its button with synthetic mouse input.

<<< @/examples/snippets/tut05_headless.F90{fortran}

## The test

<<< @/examples/snippets/tut05_headless-test.F90{fortran}

<<< @/examples/output/tut05.txt{text}

- `init_headless(400, 300)` creates the contexts on a virtual 400 x 300 display: no window, no GPU, no display
  server.
- Every iteration is a frame: `next_frame` delivers the input queued in the previous one, then `draw_panel` declares
  the panel, and `ig_item_rect` (inside it) records where the button is.
- `fig_input_mouse(x, y, left_down)` queues a mouse state. A click is hover, press, release, one frame each; the
  press and release frames make `ig_button` return `.true.` once.
- The program checks the count and stops with an error otherwise, so a test runner sees the failure in the exit
  status.

`fig_input_mouse` comes from the internal module `figure_c_native` and takes C kinds; see
[Headless testing](/guide/testing#synthetic-input).

::: tip What you learned
Headless mode, synthetic input, and an interface written so that it can be tested. Reference:
[Headless testing](/guide/testing).
:::
