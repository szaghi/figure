---
title: Headless testing
---

# Headless testing

`app%init_headless(width, height [, stat])` creates the Dear ImGui and ImPlot contexts on a virtual display of
`width` x `height` pixels, without a window, without OpenGL and without a GPU. The frame loop is the same: widgets
and plots run their full logic (layout, hit testing, state), only nothing is drawn on screen. A headless program needs
no display server: it runs in CI as is, without Xvfb.

Differences from window mode:

- `next_frame` never returns `.false.`: the program decides how many frames to run;
- every frame advances Dear ImGui's clock by 1/60 s, whatever the wall time;
- no `imgui.ini` is read or written;
- `content_scale()` is 1;
- the input is what the program queues.

## Synthetic input

`fig_input_mouse(x, y, left_down)` queues a mouse state: position in pixels and left button pressed (1) or released
(0). The next `next_frame` delivers it, exactly as real input would arrive. A click is three frames: hover, press,
release. To aim at a widget, read its rectangle with `ig_item_rect` right after declaring it.

<<< @/examples/snippets/tut05_headless-test.F90{fortran}

<<< @/examples/output/tut05.txt{text}

`fig_input_mouse` is in the internal module `figure_c_native` (it is not exported by `figure`); its arguments are C
kinds (`real(c_float)`, `integer(c_int)`). It is the interface the repository's own test uses today; it is not yet
part of the stable API.

## Test the interface you ship

Put the interface in a procedure that the application calls every frame, and call the same procedure from the test:
chapter 5 of the [tutorial](/manual/tutorial/05-headless) does this with a module, `draw_panel`, and a state type.

## The repository's test

`src/tests/figure_test_headless.F90` clicks a button, toggles a check box and draws an ImPlot line, headless:

```bash
fobis build --mode tests-gnu && exe/figure_test_headless
fobis build --mode tests-gnu-debug && exe/figure_test_headless   # with -fcheck=all and FPE traps
scripts/fpm.sh test
```

It passes with gfortran 16.2 (release and debug), nvfortran 26.9 and fpm.
