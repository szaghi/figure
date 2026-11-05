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
- Every iteration is a frame: `next_frame` delivers the input queued before it, then `draw_panel` declares the
  panel, and `ig_item_rect` (inside it) records where the button is.
- `test_click(x, y)`, from the module `figure_testing`, queues a click there after the first frame: the move, a
  frame with the pointer resting on the button, the press and the release reach the panel over the next four frames,
  as a real click would, and `ig_button` returns `.true.` once. Leave a test enough frames after its last input.
- The program checks the count and stops with an error otherwise, so a test runner sees the failure in the exit
  status.

`figure_testing` also drags, types, presses keys and turns the wheel: see
[Headless testing](/guide/testing#synthetic-input).

::: tip What you learned
Headless mode, synthetic input, and an interface written so that it can be tested. Reference:
[Headless testing](/guide/testing).
:::
