---
title: Screenshots and videos
---

# Screenshots and videos

A FIGURE program records its own window when the environment variable `FIGURE_CAPTURE` is set: after rendering,
every frame is read back from the GPU and written to an image file. Nothing changes in the program. The recordings
are exact (the window's own pixels, no screen recorder, no other windows, no compression before you choose one) and
reproducible: during a capture the real mouse and keyboard are ignored, the frame clock is fixed and the program's
input comes from a script. Every picture of this documentation is made this way.

```bash
FIGURE_CAPTURE=shot_ FIGURE_CAPTURE_FROM=10 FIGURE_CAPTURE_FRAMES=1 exe/figure_hello   # one screenshot: shot_00000.ppm
convert shot_00000.ppm hello.png                                                    # ImageMagick, to PNG
```

## Variables

Window mode only (`app%init`); headless and remote modes ignore them.

| Variable | Effect |
|---|---|
| `FIGURE_CAPTURE=<prefix>` | write every frame to `<prefix>NNNNN.ppm` (binary PPM, RGB, top row first), numbered from `00000` |
| `FIGURE_CAPTURE_FROM=<n>` | skip the first `n` frames (default 0): Dear ImGui sizes windows in the first frames |
| `FIGURE_CAPTURE_FRAMES=<n>` | after `n` frames written, `app%next_frame()` returns `.false.`: the program ends as if its window were closed |
| `FIGURE_CAPTURE_FPS=<f>` | the frame time Dear ImGui sees, `1/f` seconds (default 30): animations advance by frames, not by wall-clock time |
| `FIGURE_CAPTURE_INPUT=<file>` | replay a script of mouse and keyboard input (below) |

While capturing, lazy redraw is off (every frame is drawn), the content scale is 1 (sizes in pixels do not depend on
the display), and the events of the real mouse and keyboard do not reach Dear ImGui; closing the window still ends the
program.

## Input scripts

One event per line, at the frame given first (counted from 0, skipped frames included); `#` starts a comment.

| Event | Meaning |
|---|---|
| `<frame> move <x> <y> [<n>]` | the pointer glides to `(x, y)` (pixels from the top-left corner of the window) over `n` frames (default 1) |
| `<frame> down [left\|right\|middle]` | a mouse button is pressed (default `left`) |
| `<frame> up [left\|right\|middle]` | a mouse button is released |
| `<frame> wheel <dx> <dy>` | the wheel turns; positive `dy` away from the user (zoom in, in a plot) |
| `<frame> text <characters>` | characters are typed, the rest of the line |
| `<frame> key <name> [down\|up]` | a key is pressed and released, or only pressed or released, by the names of `test_key`: `a`-`z`, `0`-`9`, `f1`-`f12`, `enter`, `tab`, `backspace`, `delete`, `escape`, `space`, the arrows, `home`, `end`, `pageup`, `pagedown`, `ctrl`, `shift`, `alt`, `super` |
| `<frame> close` | the window's close button is clicked: a quit request (see [`set_confirm_quit`](menus#ask-before-quitting)) |

With a script, Dear ImGui draws its own mouse cursor, so the pointer shows in the frames. A malformed line is
reported on standard error and skipped. To find coordinates, take one screenshot first and read them from the image.
This script ticks the "animate" check box of `figure_hello` and drags its frequency slider:

```text
0   move 600 400
5   move 37 126 20       # glide to the check box in 20 frames
28  down
30  up
45  move 157 80 20       # to the slider's grab
70  down
72  move 420 80 40       # drag it
115 up
```

```bash
FIGURE_CAPTURE=f_ FIGURE_CAPTURE_INPUT=hello.input FIGURE_CAPTURE_FRAMES=150 exe/figure_hello
ffmpeg -framerate 30 -i f_%05d.ppm -c:v libx264 -pix_fmt yuv420p -crf 24 hello.mp4
```

## Save an image from the program

`app%save_image(path, xmin, ymin, xmax, ymax)` writes a rectangle of the window as a PNG file, at the screen's
resolution, when the current frame is rendered: a plot, a panel, the whole window. The rectangle is in logical pixels,
as `ig_item_rect` gives it for the widget drawn last (after `ip_end_plot` or `ip_end_subplots`: the plot or the grid).
`app%image_result(path, done)` reports the outcome once, on a later frame: `done` with the file written, or
`FIG_ERR_FAILED` with the reason (the file cannot be written).

```fortran
if (ip_begin_plot('history')) then
   call ip_line('x', t, x)
   call ip_end_plot()
endif
call ig_item_rect(r(1), r(2), r(3), r(4))                     ! the plot just drawn
if (save_now) call app%save_image('history.png', r(1), r(2), r(3), r(4), stat=stat)
call app%image_result(written, done, stat=stat)               ! every frame: done once, after the write
```

- Ask for it on a frame where no menu or popup covers the rectangle: they would be in the picture. A menu item that
  saves is picked on a frame where its menu is still drawn: ask on the next frame.
- **Window mode only.** In remote and headless modes there are no pixels on the program's side: `FIG_ERR_STATE`.
  (A browser's own screenshot, or the data, are the alternatives there.)
- One image at a time: a request replaces the previous one if that one has not been reported yet (its file may
  still have been written). Wait for `done` before asking for the next.

## The documentation's recordings

`scripts/docs_media.py` records every `docs/media/<name>.rec`: a header of `#!` lines (the program, the number of
frames, the poster frame, optional size, quality and style) followed by an input script. It runs the program with the
variables above and `FIGURE_STYLE=seal` (the default [style](styles), set explicitly), crops the frames to
what differs from the window background, and writes
`docs/public/media/<name>.png` and, for animations, `<name>.mp4`. Pages show them with the `<Media>` component.

```bash
bash docs/examples/build.sh && fobis build --mode examples-gnu   # the programs
GALLIUM_DRIVER=d3d12 python3 scripts/docs_media.py                # all recordings (or name some)
```

A recording with `#! remote <width> <height>` starts the program with `--remote` and takes the picture with a
headless Chromium instead ([Remote UI](remote)).
