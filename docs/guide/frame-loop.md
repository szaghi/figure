---
title: Frame loop and redraw
---

# Frame loop and redraw

## The application

A program has one `app_object`. Its life is one loop:

<<< @/examples/snippets/tut01_window-loop.F90{fortran}

- `init(title, width, height [, vsync] [, stat] [, ini_file] [, decorations] [, buttons])` opens a resizable window
  (with `decorations='figure'`, a window whose frame FIGURE draws: [below](#the-window-s-frame)) and creates the Dear
  ImGui and ImPlot contexts, with the `seal` style, docking and keyboard navigation enabled. `vsync` (default `.true.`) synchronizes the buffer
  swap with the display refresh. A second `init` without `destroy` fails with `FIG_ERR_STATE`; a non-positive size
  with `FIG_ERR_ARGUMENT`.
- `init_headless(width, height [, stat] [, decorations] [, buttons])` creates the contexts on a virtual display,
  without window or GPU: see [Headless testing](testing).
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

Two kinds of dialog choose a file to open, where to save, or a folder: the **system's own** (window mode only), and
**FIGURE's file browser**, drawn by FIGURE in Dear ImGui, the same in every mode. Both are answered through
`app%file_dialog_result`, so a program switches from one to the other by changing one call:

<<< @/examples/snippets/cb_open-open.F90{fortran}

| Procedure | Notes |
|---|---|
| `app%open_file_dialog(id [, filters] [, default_path] [, stat])` | The system's dialog: choose an existing file. |
| `app%save_file_dialog(id [, filters] [, default_path] [, stat])` | The system's dialog: choose where to save, a new or an existing file. |
| `app%open_folder_dialog(id [, default_path] [, stat])` | The system's dialog: choose a folder. |
| `app%open_file_browser(id [, filters] [, default_path] [, folders] [, stat])` | FIGURE's browser: choose an existing file, or with `folders=.true.` a folder. |
| `app%save_file_browser(id [, filters] [, default_path] [, stat])` | FIGURE's browser: choose where to save; replacing a file is asked first. |
| `app%file_dialog_result(id, path, done [, cancelled] [, stat])` | The answer to either kind: `done` once the user answered, then `path`, or `cancelled`. |

**Which one.** The system's dialog looks like the rest of the desktop and knows its bookmarks, but needs a desktop:
in remote and headless modes it is refused. The browser works everywhere: in [remote mode](remote) it is the way to
choose a file on the machine the program runs on, and in headless tests it is driven like any other part of the
interface ([Testing](testing)). A program that runs in both modes asks for the system's dialog and opens the
browser when it is refused, as above.

**Common rules.**
- **Asynchronous.** Neither blocks the program: the interface keeps drawing, and the answer arrives on a later frame.
  Poll `file_dialog_result` every frame; it is `done` once per answer, with nothing to report before or after. `id`
  is any text: it names the dialog whose answer is read. An `id` whose dialog or browser is still open is refused with
  `FIG_ERR_STATE`.
- **Filters** are entries `'name|pattern'`, the pattern being extensions separated by `;`: `'Input files|input;inp'`,
  `'All files|*'`. The first is in effect when the dialog opens. The system's dialogs may let the user ignore them.
- **Where it starts.** `default_path` is a folder, or a file (a save dialog proposes its name, the browser's open
  selects it); a relative one is taken from the program's working directory, and without one the dialog starts there.
  (On Linux the system's dialog is shown by another process, the desktop portal or `zenity`, which would otherwise
  start from its own directory, the home.)
- **Statuses.** `FIG_ERR_STATE` before `init*`, from a [task](processes#tasks), or for an `id` already open;
  `FIG_ERR_ARGUMENT` for a filter without `|`. The `stat` argument is optional (absent: `error stop` with the
  message).

### The system's dialogs

- **Window mode only.** In remote and headless modes there is no desktop to show a dialog on: the calls return
  `FIG_ERR_STATE`.
- **Platforms.** SDL3 shows the platform's dialog: Windows' and macOS' own; on Linux the desktop portal or `zenity`
  ([run-time needs](install#linux-packages)). A dialog that cannot be shown answers `done` with `FIG_ERR_FAILED` and
  the reason.

### FIGURE's file browser

<Media name="cb_open_browser" alt="A window with Open and Save as buttons. Open shows the file browser over it: on the left the places Home, Working folder and the root; on the right the folder's entries, three case folders first, then the files with their sizes and modification times; the filter shows Xall files, so notes.txt is not listed. A click on the Size header sorts the files by size, a double-click enters the folder cylinder Re100, a click on overset.input and on Open closes the browser, and the window shows the file opened." caption="docs/examples/src/cb_open_browser.F90" />

<<< @/examples/snippets/cb_open_browser-browser.F90{fortran}

A modal drawn by FIGURE (Dear ImGui's popup modal) over the program's windows, in the colours of the
[palette's roles](styles#looks-and-palettes): the accent for folders, the error role for what went wrong.

- **The folder's entries**, folders first, with their sizes (bytes, KiB, MiB, ...) and modification times (local
  time, `YYYY-MM-DD hh:mm`). A click on a column's header sorts by it (again: the other way); folders stay first. Only
  the rows in view are drawn ([list clipper](widgets#lists-and-regions)), so a folder of many thousand files scrolls as fast
  as a short one.
- **A click** selects an entry (a file's name goes into the name field); **a double-click** enters a folder or chooses
  a file. **Open** (**Save**, **Choose**) or Enter in the name field confirms; **Cancel**, the modal's close button or
  Escape cancels.
- **The path field** shows the folder. Type a path and press Enter to go there (a file's path chooses it); **Tab**
  completes the last part of the path to the longest prefix common to the names that start with it, and a single
  folder gets its separator. The arrow goes to the parent folder; the second button reads the folder again.
- **Places** on the left: the home folder, the working directory, the file systems' roots (`/`; the drives on
  Windows) and up to eight **recent folders**, those of the last answers, newest first. The recent folders are kept
  between runs in FIGURE's settings file, `settings.ini` in the folder SDL gives programs for their settings
  (`SDL_GetPrefPath`): `~/.local/share/figure/` on Linux, `~/Library/Application Support/figure/` on macOS,
  `%APPDATA%\figure\` on Windows. The file is shared by every program built with FIGURE. In headless mode and while
  [capturing](capture) the recent folders are kept in memory only: nothing of the user's is read, nothing written.
- **Filters** in a list beside the name field; **hidden files** (names starting with a dot, and on Windows the hidden
  attribute) on request; **a new folder** made in the folder shown (the third button).
- **Saving** takes the name typed (as typed: no extension is added) in the folder shown; an existing file is replaced
  only after the user answers **Replace** to the question; a name that is a folder enters it.
- **Folders** (`folders=.true.`): the files are shown dimmed and cannot be chosen; **Choose** takes the selected folder,
  or the one shown.
- **Errors are shown in the browser,** under the path field, never fatal: a folder that cannot be read (permissions),
  one that vanished meanwhile, a path that does not exist, a folder that cannot be made. The browser stays open.
- **The answer** is an absolute path, in UTF-8, with the platform's separators. Names with spaces and non-ASCII
  characters are listed and returned as they are ([known issues](known-issues#file-names-on-windows) for Fortran's own
  `open` on Windows).
- **One at a time.** Browsers opened together are shown one after the other, in the order opened. Opening one closes
  the program's popups and menus open at that moment, as Dear ImGui does for any modal opened at the top level.

**Modes.** Window and remote: the same browser, listing the files of the machine the program runs on (in remote
mode, the server's, not the browser's computer). Headless: the same, driven by [`figure_testing`](testing); the recent
folders in memory, or in a file a test names (`test_settings_file`).

## The window's frame

`app%init(..., decorations='figure')` opens the window without the system's frame (borderless and resizable) and
FIGURE draws one, in the back buffer with everything else: a title bar on top with the window's icon, the program's
**main menu bar inside it**, the title centred, and the minimize, maximize (restore) and close buttons. The system's
frame stays the default (`decorations='native'`).

<Media name="frame" video alt="A window with FIGURE's title bar: on the left a chart icon in vermilion, then the File and View menus, the title FIGURE: frame centred, and three buttons on the right. The File menu is opened from the bar and its Save item hovered; then the pointer moves along the bar and rests on minimize and on maximize, each lighter when hovered, and on close, which turns red" caption="docs/examples/src/cb_frame.F90: the menus in the bar, the buttons hovered" />

<<< @/examples/snippets/cb_frame-frame.F90{fortran}

| Procedure | Does |
|---|---|
| `app%init(title, width, height [, ...] [, decorations] [, buttons])` | `decorations`: `'native'` (default) or `'figure'`; `buttons`: `'right'` or `'left'` (default: left on macOS, right elsewhere) |
| `app%set_icon(image [, stat])` | the window's icon from an image, `integer(int8) :: image(4, width, height)` (R, G, B, A of pixel (i, j), j = 1 the top row), 1 to 1024 pixels a side |
| `app%set_icon(icon [, stat])` | the window's icon from one `ICON_*` constant |

**The bar** is Dear ImGui's main menu bar: FIGURE opens it at the start of each frame (with the icon), the program's
`ig_begin_main_menu_bar` / `ig_end_main_menu_bar` append its menus to it, and FIGURE closes it at the end of the frame
(with the title and the buttons). A program written for the system's frame needs no change: its menus move into the
title bar, and a dock space or a side bar starts below it. The title (`app%set_title`) is centred in the bar, moved
right of the menus when they reach the centre, and clipped before the buttons; it is dimmed while the window does not
have the keyboard focus.

**The colours** are the [palette's roles](styles#palette-roles) in effect: the bar in the surface colour, the title
and the buttons' marks in the text colour, a hovered button in a mix of the surface toward the text, the close button
in the error colour when hovered. With a style that has no palette, the roles are read from Dear ImGui's colours.

<<< @/examples/snippets/cb_frame-menus.F90{fortran}

**Hit testing.** The system asks the program what each point of a borderless window does
(`SDL_SetWindowHitTest`); FIGURE answers from the rectangles of the last frame drawn:

- the empty part of the bar, the title and the icon drag the window;
- the edges and the corners (6 pixels, times the content scale; a corner takes twice that along each side) resize it;
- the buttons, the menus and everything below the bar are the program's (clicks go to Dear ImGui).

`test_frame_hit(x, y)` (from `figure_testing`) gives the same answer, so a test checks it point by point.

**Interactions.**

- A double-click on the part of the bar that drags toggles maximize. On Windows the system handles the drag area as
  a caption and maximizes on a double-click itself, without sending the clicks to the program, so the window is not
  toggled twice (to be verified on Windows, S11).
- A maximized window has no resize edges.
- Close takes the quit path of the system's close button: the loop ends, or, after `app%set_confirm_quit(.true.)`,
  `app%quit_requested()` returns `.true.` and the program asks first ([Ask before quitting](menus#ask-before-quitting)).
- Minimize and maximize are the window's (`SDL_MinimizeWindow`, `SDL_MaximizeWindow`, `SDL_RestoreWindow`).

**The icon.** `set_icon` sets the window's icon for the task bar or the dock (`SDL_SetWindowIcon`) and the bar's: an
image as given, or an `ICON_*` rendered at 64 x 64 pixels with the bundled icon font, in the palette's text on accent
colour on a rounded square of its accent (the bar shows the glyph in the accent colour). Something other than one
icon is `FIG_ERR_ARGUMENT`; an image of the wrong shape too.

**Modes.**

- **Window:** as above. The Platforms workflow opens `figure_hello --frame` (the example with this frame) in a real
  window on Linux, macOS and Windows and checks its bar in the captured frame
  ([verified platforms](install#verified-platforms-and-compilers)).
- **Headless:** `init_headless(..., decorations='figure')` draws the bar the same way, for tests; the buttons'
  actions are recorded as state (`test_frame_state(minimized, maximized)`), close is a quit request as in a window.
  `set_icon` is refused with `FIG_ERR_STATE` ("set_icon: there is no window in headless mode").
- **Remote:** no frame (the browser's page is the window); `set_icon` is refused with `FIG_ERR_STATE`.

An unknown `decorations` or `buttons` value is `FIG_ERR_ARGUMENT` from `init`. What the system's frame does that this
one does not: [Known issues](known-issues#the-window-s-frame-drawn-by-figure).

## Notifications

| Procedure | Notes |
|---|---|
| `app%notify(text [, kind] [, seconds] [, stat])` | Tell the user something without a dialog: a notification drawn by FIGURE. |
| `app%notifications(list [, kinds] [, shown])` | The notifications kept, the last 100, oldest first. |

A notification tells the user what happened while they looked elsewhere: a run that ended, a check that failed, a
file written. FIGURE draws the notifications after the program's windows, above them:

- in the bottom-right corner of the work area (above a bottom [side bar](docking#a-bar-along-a-side), so a status bar
  stays visible), the newest at the bottom, the older ones stacked above it, 22 times the font size wide, the text
  wrapped;
- each in its kind's [palette role](styles#palette-roles) with its icon, so that the colour is not the only carrier:
  `'info'` (default) the accent and `ICON_INFO`, `'success'` the success colour and `ICON_CIRCLE_CHECK`,
  `'warning'` the warning colour and `ICON_TRIANGLE_ALERT`, `'error'` the error colour and `ICON_CIRCLE_X`;
- for `seconds` (default 5; 0 or less: until clicked), fading out in their last half second; the time is the frame
  time, so in headless mode and in recordings (a fixed frame time) a notification lasts a fixed number of frames;
- a click dismisses one; they take no keyboard focus and do not move.

The last 100 are kept, shown or not: `app%notifications(list, kinds, shown)` gives their texts (padded with blanks to
the longest), their kinds and whether each is still shown, for a "messages" panel or a log. `notify` asks for the
frames that draw it, even with lazy redraw, and for the frames of the fade.

<<< @/examples/snippets/cb_status-notify.F90{fortran}

<Media name="cb_status_end" alt="The run has ended: the status bar reads done, residual 9.88E-08; in the bottom-right corner two notifications are stacked, the warning levels is 0 above and, under it, the newest, Run finished: 240 iterations, residual 9.88E-08, with a check mark" caption="docs/examples/src/cb_status.F90" />

Statuses: `FIG_ERR_STATE` before `init*` and from a [task](processes#tasks) (a task does not draw: the program
notifies when it sees the task done), `FIG_ERR_ARGUMENT` for an unknown kind; `stat` is optional (absent: `error
stop` with the message). The same in window, headless and remote modes.

## Drops

| Procedure | Notes |
|---|---|
| `app%dropped(paths [, x] [, y])` → `logical` | The files and folders dropped on the window since the last frame, and where; `.true.` on that frame only. |

Dropping a case folder or a file on the window is the shortest way to open it. FIGURE collects SDL's drop events while
it waits for the next frame and hands them to that frame: `app%dropped` is `.true.` on the frame after the drop, and
`.false.` on every other one, so a drop is reported once.

- **`paths`** (`character(len=:), allocatable, intent(out) :: paths(:)`): the absolute paths, in the order the system
  gave them, UTF-8, padded with blanks to the longest (pass `trim(paths(k))`). A folder is a path like a file's; the
  program tells them apart (`inquire`, or FIGURE's [file browser](#figure-s-file-browser) for what is inside). Empty
  when nothing was dropped.
- **`x`, `y`**, in pixels: the point of the drop, in the coordinates of `ig_item_rect` and of the mouse. Several files
  dropped at once come together, at one point. The point tells which window or region received the drop: keep the
  rectangle of each region from the frame before (`ig_item_rect` after `ig_end_child`, or after `ig_end` for a
  window's last item) and test the point against them. During a drag the system may not send pointer moves, so
  Dear ImGui's hover state does not follow it: the point is the way.
- Dropped text (a selection dragged from an editor) is not a drop: only files and folders are.

**Modes:** in **window** mode, the system's drag and drop (from a file manager, the desktop, another program);
**headless** mode has none of its own: `test_drop(paths, x, y)` of [figure_testing](testing#synthetic-input) queues
one, in every mode; **remote** mode has none: a browser gives a page the contents of the files dropped on it, never a
path on the server, and the page refuses them (dropped files would otherwise replace the page). The server's files
are opened with [FIGURE's file browser](remote#opening-and-saving-files). No failure status: before `init*` and from
a [task](processes#tasks) the result is `.false.`.

<<< @/examples/snippets/cb_drop-drop.F90{fortran}

<Media name="cb_drop" video alt="Two panes: a case folder dropped on the left one becomes the case; two files dropped on the right one are listed there; then Copy the case path puts the folder's path on the clipboard and the window reads copied, with the path" caption="docs/examples/src/cb_drop.F90" />

## Content scale

`content_scale()` returns the display content scale FIGURE read at `init` (1 on standard displays, 2 on most high-DPI
ones; 1 in headless mode). FIGURE applies it at `init`: the window is created `width * scale` by `height * scale`,
and the Dear ImGui style (spacing, fonts) is scaled by it. Positions and sizes the program passes
(`ig_set_next_window`, button and plot sizes) are not scaled: multiply them by `content_scale()` to keep their
proportion to the window ([cookbook](/manual/cookbook#size-in-proportion-to-the-display-scale)).

## Styles

The colours and sizes of the interface: see [Styles](styles).
