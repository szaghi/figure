---
title: Screenshots and videos
---

# Screenshots and videos

A FIGURE program records its own frames when the environment variable `FIGURE_CAPTURE` is set: every frame drawn is
written to an image file. Nothing changes in the program. The recordings are exact (the program's own pixels, no
screen recorder, no other windows, no compression before you choose one) and reproducible: during a capture the real
mouse and keyboard are ignored, the frame clock is fixed and the program's input comes from a script. Every picture of
this documentation is made this way.

```bash
FIGURE_CAPTURE=shot_ FIGURE_CAPTURE_FROM=10 FIGURE_CAPTURE_FRAMES=1 exe/examples/figure_hello  # shot_00000.ppm
convert shot_00000.ppm hello.png                                                                 # ImageMagick, to PNG
```

## Three modes, two renderers

| Mode | Where the pixels come from |
|---|---|
| window (`app%init`) | the GPU: the frame the OpenGL 3 backend drew, read back from the back buffer |
| headless (`app%init_headless`) | FIGURE's CPU renderer: the frame's draw data rasterized on the CPU |
| remote (`app%init_remote`) | FIGURE's CPU renderer, on the program's side (whatever the browser shows) |

The CPU renderer (`native/figure_swrast.cpp`) draws Dear ImGui's draw data as the OpenGL 3 backend asks a GPU to:
the same triangles, scissor rectangles, texture filters (linear, or a texture's own nearest filter around its image),
blending and 8-bit frame buffer. It needs no GPU, no display, no Mesa and no library beyond FIGURE's own, so the same
program records its frames on a laptop, a CI runner or a cluster node, in any of the three modes. The same applies to
`app%save_image` (below) and to [`test_capture`](testing#pictures-as-tests).

`FIGURE_CAPTURE_HEADLESS=1` runs a window program (`app%init`) in headless mode for its capture: no window is opened,
SDL is not started, and the frames come from the CPU renderer, at the window's size. This is how
`scripts/docs_media.py --check` renders the documentation's recordings in CI-like conditions.

```bash
FIGURE_CAPTURE=shot_ FIGURE_CAPTURE_HEADLESS=1 FIGURE_CAPTURE_FROM=10 FIGURE_CAPTURE_FRAMES=1 exe/examples/figure_hello
```

In that mode `app%set_icon` gives FIGURE's title bar its icon, as in the window; the system's file dialogs are refused as in
any headless program, and `set_size_limits` does nothing.

### The CPU renderer and the GPU

The renderer was measured against an RTX 4070 (through Mesa's d3d12 driver) on the docs' recordings (#7, S1):

- **Where they differ:** by 1 or 2 levels (of 255) on a channel, at anti-aliased edges (text, plot lines) and in
  blended pixels: the GPU blends and filters in fixed point, the renderer in single precision. No edge, row or texel
  moves. The documentation's recordings, each rendered both ways from the same program (a window on the GPU, and
  `FIGURE_CAPTURE_HEADLESS`): 68 of 80 posters agree within 2 levels everywhere; 3 differ by one pixel of a plot line
  (a pixel centre within 1/256 pixel of an edge, which the two round apart); the other 9 draw what a task or a solver
  process produced by the wall clock, which a headless run, faster per frame, reaches at another frame.
- **Ties:** a pixel centre exactly on an edge shared by two triangles belongs to one of them by the image's top-left
  rule (Direct3D's, and that GPU's). OpenGL's rule is top-left in its own y-up coordinates: Mesa's llvmpipe follows
  it, and its pictures differ from the GPU's by one row of pixels where an edge falls on a pixel centre (heatmap
  cells, the first row of an image drawn with nearest filtering). A native OpenGL driver on a GPU may do either; that
  was not measured.
- **Not drawn:** a program's own draw callback (`ImDrawList::AddCallback` through the raw bindings) runs on the GPU in
  a window and is skipped by the CPU renderer. FIGURE's own callbacks only set the texture filter, which the renderer
  follows.
- **Speed:** a frame of 1400 x 860 pixels of the documentation's scenes takes 0.7 to 1.7 ms on 8 threads (median of
  30 frames), 0.8 to 6.7 ms on one: about 1 ns a pixel drawn, more for a large texture sampled on every pixel.
  `FIGURE_RENDER_THREADS=<n>` sets the threads (default: the machine's, at most 8); the picture does not depend on it.

### Determinism

A headless picture depends only on the program and on FIGURE:

- the same frame rendered twice, or on 1 thread and on 7, is the same file (`figure_test_pixels`);
- the same program built with gfortran, nvfortran or ifx gives the same pictures;
- headless and remote modes give the same pictures, and a window program run with `FIGURE_CAPTURE_HEADLESS` gives
  the pictures of the same program written for headless mode;
- the native layer is compiled with `-ffp-contract=off` (no fused multiply-add: GCC and Clang contract by default
  where the processor has FMA, on aarch64 and on x86-64 built for a recent processor). Without it a build with FMA
  moved an axis of a plot by one pixel row: Dear ImGui's and ImPlot's layout arithmetic rounds differently, upstream of
  any renderer. The fpm package sets the same with pragmas.

What can still differ between platforms: the C library's `sin`, `cos`, `log10` and `pow` (rounded corners, circles,
tick positions). macOS and Windows were not measured; [Pictures as tests](testing#pictures-as-tests) allows a
per-platform tolerance where one is measured.

## Variables

Every mode: a window's frames come from the GPU, headless and remote modes' from the CPU renderer.

| Variable | Effect |
|---|---|
| `FIGURE_CAPTURE=<prefix>` | write every frame to `<prefix>NNNNN.ppm` (binary PPM, RGB, top row first), numbered from `00000` |
| `FIGURE_CAPTURE_FROM=<n>` | skip the first `n` frames (default 0): Dear ImGui sizes windows in the first frames |
| `FIGURE_CAPTURE_FRAMES=<n>` | after `n` frames written, `app%next_frame()` returns `.false.`: the program ends as if its window were closed |
| `FIGURE_CAPTURE_FPS=<f>` | the frame time Dear ImGui sees, `1/f` seconds (default 30): animations advance by frames, not by wall-clock time |
| `FIGURE_CAPTURE_INPUT=<file>` | replay a script of mouse and keyboard input (below) |
| `FIGURE_CAPTURE_HEADLESS=1` | `app%init` starts headless mode instead of a window (with `FIGURE_CAPTURE` only) |
| `FIGURE_RENDER_THREADS=<n>` | the CPU renderer's threads, 1-64 (any time, not only in a capture) |

While capturing, lazy redraw is off (every frame is drawn), the content scale is 1 (sizes in pixels do not depend on
the display), and the events of the real mouse and keyboard do not reach Dear ImGui; closing the window still ends the
program. Nothing of the user's is read or written, so a recording does not depend on earlier runs: the `ini_file` of
`app%init` is ignored and the [file browser](frame-loop#figure-s-file-browser) keeps its recent folders in memory. In
remote mode the browser's input still reaches the program, with the fixed clock and the script: the recording is of
the session.

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
| `<frame> drop <x> <y> <path>` | a file or folder is dropped on the window at `(x, y)` |
| `<frame> close` | the window's close button is clicked: a quit request (see [`set_confirm_quit`](menus#ask-before-quitting)) |
| `<frame> wait` | the script holds until the program's [tasks](processes#tasks) and [processes](processes#processes) are done. First the program waits, drawing nothing, until no task runs and no process is alive; then frames are drawn but not counted, not written and without scripted input, at a frame time of 10 µs (animations and notifications do not move), until no task and no process has been busy for 10 frames, so that the program has taken their results (at most 600 s in all). The events after it follow on the next counted frame, which shows the work done. A `wait` listed first at its frame holds that frame itself: `0 wait` makes the work a program starts before its first frame (a file read at the start) done when frame 0 is drawn |

`wait` makes a recording of a program that works by the wall clock the same on any machine and under any load: a
solver run with F5, a file read by a task. A task is busy until its procedure returns, a process until it has exited
and its output has ended and been taken.

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
FIGURE_CAPTURE=f_ FIGURE_CAPTURE_INPUT=hello.input FIGURE_CAPTURE_FRAMES=150 exe/examples/figure_hello
ffmpeg -framerate 30 -i f_%05d.ppm -c:v libx264 -pix_fmt yuv420p -crf 24 hello.mp4
```

## Save an image from the program

`app%save_image(path, xmin, ymin, xmax, ymax)` writes a rectangle of the window as a PNG file, at the screen's
resolution, when the current frame is rendered: a plot, a panel, the whole window. The rectangle is in logical pixels,
as `ig_item_rect` gives it for the widget drawn last (after `ip_end_plot` or `ip_end_subplots`: the plot or the grid).
`app%image_result(path, done)` reports the outcome once, on a later frame: `done` with the file written, or
`FIG_ERR_FAILED` with the reason (the file cannot be written).

<<< @/examples/snippets/cb_save_image-save.F90{fortran}

The whole program, with its Save button: `docs/examples/src/cb_save_image.F90`.

- Ask for it on a frame where no menu or popup covers the rectangle: they would be in the picture. A menu item that
  saves is picked on a frame where its menu is still drawn: ask on the next frame.
- **Every mode.** In a window the pixels are the GPU's; in headless and remote modes the CPU renderer draws the frame
  on the program's side (what a browser shows in remote mode is the same frame, drawn by the browser).
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
python3 scripts/docs_media.py --headless                          # all recordings (or name some), by the CPU renderer
python3 scripts/docs_media.py --check                             # each poster against the CPU renderer's
python3 scripts/docs_media.py --update                            # accept the pictures --check wrote
GALLIUM_DRIVER=d3d12 python3 scripts/docs_media.py cb_editor      # in a window, on the GPU: to compare, not to commit
```

`--headless` records with `FIGURE_CAPTURE_HEADLESS=1`: no window opens, no display or GPU is needed, and the
pictures are the CPU renderer's, the ones `--check` compares with. Every picture of the site is recorded so: the
documentation pass of v0.5.0 recorded them all again in one pass, the GPU's and llvmpipe's of earlier releases
replaced.
`--check` renders each recording headless (`FIGURE_CAPTURE_HEADLESS=1`) with the CPU renderer, crops its poster the
same way and compares it with the committed one by [`test_compare_image`](testing#pictures-as-tests)'s rule: a channel
may differ by 2 levels, no pixel by more. A header line `#! mask x y w h` leaves a rectangle of the poster out (a
clock, anything drawn from the wall time), `#! check threshold=N max_failed=M` changes the tolerance, and
`#! check.linux`, `#! check.darwin`, `#! check.win32` change it on one platform only, where a difference was measured
there. `#! fresh /tmp/<folder>` removes a folder before the program starts, so that what it writes there (the tutorial's
`--examples /tmp/figure-studio`) does not depend on the recordings run before it. A failure writes `docs/public/media/<name>.new.png` and `<name>.diff.png` (failed pixels red, those within the
tolerance dark red, masked ones blue); `--update` makes each `.new.png` the poster. Remote recordings are not checked.

**In CI:** the Checks workflow runs `--check` on every push, in the toolchain image of `ci.yml` (gfortran 16.2, the
compiler the recordings are made with), after the examples are built; on a failure it keeps the `.new.png` and
`.diff.png` pictures as an artifact. A change that changes a picture is committed with the new poster (`--update`, after
looking at the `.new.png`), and its commit says why.

**Recordings of programs that work by the clock.** A recording whose program runs a process or a task (the solver of
the tutorial, a file read in the background) waits for its result before the poster frame: the script leaves the
frames it needs, and the program shows the same picture once the work is done, however long it took. What depends on
the wall time itself (a run's duration, a clock) is left out with `#! mask`.

A recording with `#! remote <width> <height>` starts the program with `--remote` and takes the picture with a
headless Chromium instead ([Remote UI](remote)).

A video shows what the user did, not only what the program drew: the program's back buffer has no pointer, so the
recorder draws one where the script puts it (the glide of `move` replayed), ringed while a button is held; with
`#! keys` it also captions each key chord at the bottom of the video for 1.5 s (`ctrl+s`, `down`, `f5`), so a viewer
sees what was pressed (`#! pointer no` leaves the pointer out). The poster is the program's frame as drawn, without
them. With `SDL_VIDEO_DRIVER=offscreen` in the environment SDL draws into memory and no window appears: the
recordings of v0.4.0 were made so, on the GPU or in software.
