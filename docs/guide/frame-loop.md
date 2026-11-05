---
title: Frame loop and redraw
---

# Frame loop and redraw

## The application

A program has one `app_object`. Its life is one loop:

<<< @/examples/snippets/tut01_window-loop.F90{fortran}

- `init(title, width, height [, vsync] [, stat])` opens a resizable window and creates the Dear ImGui and ImPlot
  contexts, with the `seal` style, docking and keyboard navigation enabled. `vsync` (default `.true.`) synchronizes the buffer
  swap with the display refresh. A second `init` without `destroy` fails with `FIG_ERR_STATE`; a non-positive size
  with `FIG_ERR_ARGUMENT`.
- `init_headless(width, height [, stat])` creates the contexts on a virtual display, without window or GPU: see
  [Headless testing](testing).
- `destroy()` closes the window and destroys the contexts. It is safe in any state, also without a previous `init`
  and inside an open frame.

Window positions and sizes are not saved between runs: FIGURE turns off Dear ImGui's `imgui.ini`, so a layout left in
the working directory by an earlier run never overrides what the program sets with `ig_set_next_window`. To keep the
layout, name the file: `app%init(title, width, height, ini_file='my_tool.ini')`. Dear ImGui reads it at the first
frame and rewrites it while the program runs. Headless mode never uses one.

## next_frame

`next_frame([stat])` is the only call that advances time. Each call:

1. renders the frame opened by the previous call, if any, and presents it;
2. processes input, sleeping first if [lazy redraw](#lazy-redraw) says so;
3. opens the next frame and returns `.true.`, or returns `.false.` if the user closed the window.

Between two calls the program declares the interface: widget calls, plot calls, and its own computation. Widgets
return what happened in the frame they belong to: `ig_button` is `.true.` on the frame it is clicked, and the input
that clicked it was processed by the `next_frame` that opened the frame.

When `next_frame` returns `.false.`, no frame is open: leave the loop and call `destroy`. In headless mode
`next_frame` returns `.false.` only after `app%quit()` or a `test_quit()` (there is no window to close): the program
decides how many frames to run.

`app%quit()` ends the loop from the program: the next `next_frame` returns `.false.`, in every mode. With
`app%set_confirm_quit(.true.)` the window's close button no longer ends the loop: `app%quit_requested()` reports the
request, once, and the program answers it, typically with a "Discard changes?" dialog
([Ask before quitting](menus#ask-before-quitting)). In remote mode closing the browser's tab never ends the program.

## Lazy redraw

Lazy redraw is on by default. After the last input event, FIGURE draws three more frames (Dear ImGui settles in a few
frames); then `next_frame` sleeps until an input event arrives or `max_wait` seconds elapse, whichever comes first.
The timeout is a periodic refresh: it lets data the program changes on its own (a computation, a file it reads)
appear without input.

| Call | Effect |
|---|---|
| `app%set_lazy(.true., max_wait=s)` | sleep at most `s` seconds once the UI settles (default 0.5 s) |
| `app%set_lazy(.false.)` | never sleep: draw continuously, at the display rate with vsync |
| `app%request_frames(n)` | draw at least `n` more frames without waiting for input |

`set_lazy` without `max_wait` sets it back to 0.5 s. `request_frames(n)` raises the count of frames still to draw to
`n` (it never lowers it): call `request_frames(1)` in every frame in which something is changing, such as an
animation or a computation that advances inside the loop, and the loop keeps drawing; stop calling it and the next
`next_frame` sleeps again (the three-frame tail follows input events, not `request_frames`).

<<< @/examples/snippets/tut04_live-advance.F90{fortran}

Choose between them by who changes the data:

- data changed inside the loop, every frame: `request_frames(1)` in those frames (chapter 4 of the
  [tutorial](/manual/tutorial/04-live));
- data changed outside the loop's knowledge, at its own pace: `max_wait` equal to the refresh period you want
  ([cookbook](/manual/cookbook#refresh-data-that-changes-on-its-own));
- continuous animation regardless of input: `set_lazy(.false.)`
  ([cookbook](/manual/cookbook#redraw-continuously)).

### What idle costs

With lazy redraw on and no input, a FIGURE program draws `1 / max_wait` frames per second: exactly 2 frames/s with
the default 0.5 s, each one ended by the timeout, with no spurious events after startup (checked with
[`FIGURE_DEBUG_REDRAW`](#redraw-diagnostics) on X11 and Wayland). Measured on one machine (WSL2/WSLg, RTX 4070
through `GALLIUM_DRIVER=d3d12`, SDL 3.4.20), 60 s samples of a one-window program:

| Configuration | Idle CPU, one core |
|---|---|
| `max_wait` 0.5 s (default) | 0.37% |
| `max_wait` 2 s | 0.15% |
| `max_wait` 5 s | 0.13% |
| `figure_hello`, default | 0.40% |
| lazy redraw off (vsync, 60 frames/s) | 37% |

That is about 1.5 ms of CPU per idle frame, on a floor of about 0.08%. These are measurements on that machine, not
guarantees: the cost per frame depends on the platform, the driver and the interface. With software rendering
(llvmpipe, the WSLg default without `GALLIUM_DRIVER=d3d12`) every frame costs much more.

The default `max_wait` is 0.5 s: a longer one saves about 0.2% of one core and makes data that changes without
`request_frames` appear correspondingly later. What a frame costs with live data, large plots and fields, in a window
and in remote mode: [Performance](performance).

### Redraw diagnostics

Set `FIGURE_DEBUG_REDRAW` (any value) before running a program: in window mode (not headless), `init` reads it, and
from then on the glue prints one line per second to standard error. The format, with illustrative values (a second
with some mouse motion):

```text
figure redraw: 1.02 s frames=5 timeouts=1 wait=960.3ms build=0.6ms render=0.3ms swap=24.1ms events: 0x400=3
```

| Field | Meaning |
|---|---|
| `1.02 s` | length of the interval the line covers (at least 1 s: a line is printed at the first frame after it) |
| `frames` | frames drawn |
| `timeouts` | sleeps that ended by `max_wait`, without an event |
| `wait` | time spent waiting for and polling events |
| `build` | from opening the frame to the end of `ImGui::Render`: the program's code between two `next_frame` calls and the ImGui calls |
| `render` | OpenGL drawing of the frame |
| `swap` | `SDL_GL_SwapWindow`, wall time (includes the wait for vsync) |
| `events: 0xTYPE=COUNT` | events received, by SDL event type code, in hexadecimal |

The event codes are SDL3's `SDL_EventType` values, defined in `SDL_events.h`: for example `0x100` quit, `0x202` and
following window events, `0x300` key down, `0x400` mouse motion.

### Measuring idle cost

`scripts/measure_idle.py` (Linux) runs a program, waits for it to settle, measures its CPU time over a window, then
terminates it; nobody must touch the window meanwhile.

```bash
python3 scripts/measure_idle.py [--warmup S] [--seconds S] [--env VAR=value ...] -- program [args]
python3 scripts/measure_idle.py --seconds 60 --env GALLIUM_DRIVER=d3d12 -- exe/figure_hello
```

It reports the renderer (the WSL GPU through D3D12, or Mesa software rendering) and the idle CPU as a percentage of
one core, with its resolution. The kernel counts CPU time in clock ticks, usually 10 ms: use windows of 60 s or more
(the default is 10 s, after a 4 s warm-up) to resolve sub-percent costs.

## File dialogs

The system's own dialogs, to choose a file to open, where to save, or a folder:

<<< @/examples/snippets/cb_open-open.F90{fortran}

| Procedure | Notes |
|---|---|
| `app%open_file_dialog(id [, filters] [, default_path] [, stat])` | Choose an existing file. |
| `app%save_file_dialog(id [, filters] [, default_path] [, stat])` | Choose where to save: a new or an existing file. |
| `app%open_folder_dialog(id [, default_path] [, stat])` | Choose a folder. |
| `app%file_dialog_result(id, path, done [, cancelled] [, stat])` | The answer: `done` once the user answered, then `path`, or `cancelled`. |

- **Asynchronous.** The dialog does not block the program: the interface keeps drawing, and the answer arrives on a
  later frame. Poll `file_dialog_result` every frame; it is `done` once per answer, with nothing to report before or
  after. `id` is any text: it names the dialog whose answer is read.
- **Filters** are entries `'name|pattern'`, the pattern being extensions separated by `;`: `'Input files|input;inp'`,
  `'All files|*'`. Platforms may let the user ignore them.
- **Window mode only.** In remote and headless modes there is no desktop to show a dialog on: the calls return
  `FIG_ERR_STATE`, and the program asks for the path in a text field instead, as above.
- **Platforms.** SDL3 shows the platform's dialog: Windows' and macOS' own; on Linux the desktop portal or `zenity`
  ([run-time needs](install#linux-packages)). A dialog that cannot be shown answers `done` with `FIG_ERR_FAILED` and
  the reason.

## Content scale

`content_scale()` returns the display content scale FIGURE read at `init` (1 on standard displays, 2 on most high-DPI
ones; 1 in headless mode). FIGURE applies it at `init`: the window is created `width * scale` by `height * scale`,
and the Dear ImGui style (spacing, fonts) is scaled by it. Positions and sizes the program passes
(`ig_set_next_window`, button and plot sizes) are not scaled: multiply them by `content_scale()` to keep their
proportion to the window ([cookbook](/manual/cookbook#size-in-proportion-to-the-display-scale)).

## Styles

The colours and sizes of the interface: see [Styles](styles).
