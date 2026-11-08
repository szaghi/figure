---
title: 16. The studio tested
---

# 16. The studio tested

Chapter 5 tested one button. The studio now tests itself: `tut16_tested --test DIR` draws the studio headless, on a
virtual display with its title bar, and drives it as its user would, with keys, clicks, a drop, the file browser, a
question, a run of the solver and the close button, checking its state after each gesture. It needs no display and no
GPU, so it can run in CI as it is; the documentation's build runs it:

<<< @/examples/output/tut16.txt{text}

<Media name="tut16_tested" video alt="The same gestures in a window: ctrl+o shows the file browser on the example cases broken, channel, fine and plate; a double-click on plate and Choose open it; F5 runs the solver and the Result panel comes forward with the heatmap, its contour lines and the profile, the log and the residuals below; then the 3-D button and Fit show the surface with the body" caption="docs/examples/src/tut16_tested.F90, run as tut16_tested --examples /tmp/figure-studio" />

The whole program: [tut16_tested.F90](https://github.com/szaghi/figure/blob/main/docs/examples/src/tut16_tested.F90).
The test is the studio's own code, `draw_studio`, called by a loop of its own instead of the window's; nothing of the
studio changes for it, except two lines that remember where the title field and the Discard button are.

## A studio without a display

<<< @/examples/snippets/tut16_tested-setup.F90{fortran}

- `init_headless(width, height, decorations='figure')` creates the contexts on a virtual display, without a window
  or a GPU, and draws the title bar FIGURE draws in a window: the frame is tested too
  ([Headless testing](/guide/testing)).
- Every call of `frames(n)` draws `n` frames, as the main loop does; input queued by `figure_testing` reaches the
  studio in those frames. Headless, every frame advances Dear ImGui's clock by 1/60 s, whatever the wall time.

## The frame and the menus

<<< @/examples/snippets/tut16_tested-frame.F90{fortran}

`test_frame_rect(part, ...)` gives a part of the title bar as drawn in the last frame, and `test_frame_hit(x, y)`
what the system is told there (chapter 7): the title drags the window.

## Keys and the file browser

<<< @/examples/snippets/tut16_tested-browser.F90{fortran}

- `test_key('shortcut', down=.true.)` presses the platform's shortcut key, ctrl or cmd on macOS, so the same test
  passes on every system; `test_key('o')` then is ctrl+o ([Synthetic input](/guide/testing#synthetic-input)).
- `test_file_browser(shown, folder, entries)` tells what FIGURE's file browser shows: the folder, the entries in the
  order shown (folders end in `/`); `test_file_browser_rect('entry:plate', ...)` and `'ok'` give the parts to click.
  Two `test_click` in a row are a double-click.
- `app%title()` is the window's title in every mode: a test reads it.

<<< @/examples/snippets/tut16_tested-keys.F90{fortran}

The title field is where the studio drew it (`title_at`, from `ig_item_rect` in `draw_case`); `test_type` types into
the focused field. A test checks what the user would see: the field's text, and the star in the window's title.

## A drop and a question

<<< @/examples/snippets/tut16_tested-drop.F90{fortran}

`test_drop(paths, x, y)` drops files or folders as a file manager would: `app%dropped` reports them in the next
frame. The edit is unsaved, so the studio asks; `test_popup_rect` finds the question open, and a click on Discard
answers it. The path is copied into a fixed-length array first (chapter 11's gfortran workaround).

## The solver, the task, the checks

<<< @/examples/snippets/tut16_tested-run.F90{fortran}

The solver is a real process, and the task a real thread: they run in real time, while the test draws frames as fast
as it can. The test draws frames until the run has ended and the field is read, with a bound, rather than a fixed
number of frames that a slower machine would not meet.

<<< @/examples/snippets/tut16_tested-checks.F90{fortran}

## The close button

<<< @/examples/snippets/tut16_tested-close.F90{fortran}

A click on the title bar's close button, with nothing unsaved, ends the studio: `next_frame` returns `.false.`, in
headless mode as in a window. With an unsaved edit the studio would ask instead, as the drop above did.

## The recordings of this tutorial

Every picture of part two is the studio's own back buffer, recorded in a window by `scripts/docs_media.py` with a
script of input, as a test drives it headless ([Screenshots and videos](/guide/capture)). The recording above is this
script, `docs/media/tut16_tested.rec`:

<<< @/media/tut16_tested.rec{text}

The `#!` lines name the program and its arguments, the frames to record and the one kept as the picture; the other
lines are the input, one event per frame number: `move`, `down`, `up`, `key`, `text`, `wheel`, `drop`, `close`.
`docs_media.py` runs the program with `FIGURE_CAPTURE` and the other `FIGURE_CAPTURE_*` variables, which turn the
capture on, and with `FIGURE_STYLE=seal`, the style of these pages; with `SDL_VIDEO_DRIVER=offscreen` in its
environment SDL draws into memory and no window appears on the screen, which is how this tutorial's recordings were
made. While recording, FIGURE ignores the real mouse and keyboard, fixes the frame time and reads nothing of the
user's (no ini file, no recent folders), so a recording made again gives the same picture.

::: tip What you learned
A whole application tested headless, by its users' gestures: keys and the platform's shortcut key, clicks aimed at
where the program drew, typed text, a drop, FIGURE's file browser, a popup, the title bar; a real process and a real
task waited for with a bound; and how a recording is scripted. Reference: [Headless testing](/guide/testing),
[Screenshots and videos](/guide/capture).
:::

**Next:** [17. The studio on a cluster](./17-remote): the same studio in a web browser.
