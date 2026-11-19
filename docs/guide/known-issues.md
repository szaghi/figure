---
title: Known issues
---

# Known issues

What does not work today, and what to do instead. Find the area in the table: a row says what fails, the way around
it, and since when; its link leads to the section with the details and the evidence (the versions, the date checked,
the test or the canary that watches it). **Since** is the release that brought the feature, or, for a compiler's
defect, the compiler versions it was seen with. The compiler defects FIGURE works around are watched by
[`figure_test_canaries`](testing#canaries), which fails once a defect is gone.

| Area | What does not work | Workaround | Since |
|---|---|---|---|
| nvfortran | [A derived-type local named `size`, set by a constructor: internal compiler error](#nvfortran-26-9-internal-compiler-error-on-size) | Name it otherwise (`extent`) | nvfortran 26.9 |
| nvfortran | [`-Munixlogical` at the compile but not the link (or the reverse): `select type` matches no type; with it, `execute_command_line(wait=.true.)` does not wait](#nvfortran-munixlogical) | Both or neither; leave `wait` out | nvfortran 26.9 |
| nvfortran | [`char(i)` of a variable, assigned to a deferred-length string, has length `i`](#nvfortran-char-i-of-a-variable) | A fixed-length buffer | nvfortran 26.9 |
| nvfortran | [`select case` on a deferred-length function result matches no case](#nvfortran-select-case-on-a-function-result-of-deferred-length) | Select on a variable holding the result | nvfortran 26.9 |
| nvfortran | [`system_clock` reads the wall clock: an interval jumps when the system steps its time](#nvfortran-system-clock-is-the-wall-clock) | `figure_time()` | nvfortran 26.9 |
| gfortran | [A section of a deferred-length character array arrives as other elements (nvfortran: a strided one)](#gfortran-a-section-of-a-deferred-length-character-array) | Copy it into a fixed-length array | gfortran 15.2, nvfortran 26.9 |
| gfortran | [An array constructor of deferred-length strings with a type-spec writes past its memory](#gfortran-an-array-constructor-of-deferred-length-strings) | Fill a fixed-length array element by element | gfortran 16.2 |
| gfortran | [A component of an allocatable array, passed to a `bind(C)` assumed-shape dummy, corrupts the caller's descriptor](#gfortran-a-component-passed-to-a-bind-c-assumed-shape-dummy) | A contiguous copy (FIGURE's own calls are not affected) | gfortran 15.2 |
| gfortran, nvfortran | [A component of an array of derived types (`runs%cl`) passed to a plot item is copied at every call](#strided-plot-data-copied-by-the-compiler) | Columns, contiguous arrays, `ip_line(label, y, row)` | gfortran 16.2, nvfortran 26.9 |
| ifx | [Untested on Windows, absent on macOS; fpm does not add `-fpscomp logicals`](#intel-ifx) | `--flag "-fpscomp logicals"` to fpm | v0.3.0 |
| macOS, Windows | [Input, vendor OpenGL drivers and floating-point traps in a window not exercised by CI](#platforms) | None | v0.1.0 |
| Window | [`decorations='figure'`: no snap layouts, no full-screen button, no window menu; no icon on some systems](#the-window-s-frame-drawn-by-figure) | The system's frame; `stat` on `set_icon` | v0.3.0 |
| Linux | [The system's file dialogs open on the session's desktop, not on the program's display](#the-system-s-file-dialogs-on-linux) | `prefer='figure'` | v0.2.0 |
| Remote mode | [Chords a browser keeps (ctrl+w, ctrl+t, ctrl+tab) never reach the program; f5, f11, alt chords act in the browser too](#shortcuts-in-a-browser) | Other ctrl chords; the action in a menu | v0.2.0 |
| Remote mode | [A link's tab is blocked as a pop-up on a slow connection or by a strict blocker](#links-in-a-browser) | Allow pop-ups for the page | v0.4.0 |
| Remote mode, WSLg | [A copy reaches the browser's clipboard only in a secure context; no drops in remote mode, none from Windows' Explorer under WSLg](#the-clipboard-and-drops) | `localhost` or `https`; FIGURE's file browser | v0.3.0 |
| Widgets | [Two widgets with the same label in a window are one widget](#unique-labels) | `'label##suffix'` | v0.1.0 |
| Docking | [Windows cannot be dragged out of the main window](#no-multi-viewports) | None | v0.1.0 |
| Text | [A `character` field cuts the text at its length; the multi-line field has no line numbers, highlighting or search](#text-input) | `text_buffer_object`; a log view for a growing log | v0.2.0 |
| Plots | [`ip_field_image` does not see values rewritten in place](#a-field-changed-in-place) | `changed=.true.` on that frame | v0.4.0 |
| Plots | [ImPlot's digital bars drew nothing with Dear ImGui 1.93](#implot-s-digital-signals) | Patched by FIGURE | v0.7.0 |
| 3-D plots | [No depth buffer (crossing surfaces drawn in the wrong order), no lighting, picking only on linear axes, every vertex sent in remote mode](#implot3d) | `view3d_object` for meshes that cross | v0.5.0 |
| 3-D views | [JPEG artefacts in remote mode while the camera moves; above a million triangles a render takes tens of milliseconds](#_3-d-views) | `init_remote(lossy=.false.)` | v0.3.0 |
| Gizmos | [Coarse drags at grazing angles, single precision, the mouse taken one frame late, no undo](#gizmos) | Turn the camera so the axis lies across the screen | v0.5.0 |
| Images | [PNG and JPEG only; no colour management, no EXIF orientation](#images-read-from-files) | Rotate in the program | v0.5.0 |
| Pictures | [The CPU renderer differs from a GPU by 1 or 2 levels at edges, runs no draw callbacks, and differs across platforms where the program's arithmetic does](#pictures-without-a-gpu) | Goldens made by the CPU renderer; per-platform masks | v0.5.0 |
| Testing | [Text, images and plot items have no path; items with one label in one id scope share an id](#items-found-by-path) | `##` ids | v0.5.0 |
| Preferences | [No window position on Wayland; theme files, the style editor's changes and fonts not kept; a message box waits for an open popup](#preferences-and-the-window-s-place) | `destroy` at the end; ask after the popup closes | v0.5.0 |
| File browser | [No desktop integration; a folder read on the main thread; one list of recent folders for every program](#the-file-browser) | None | v0.3.0 |
| File browser | [On Windows a non-ASCII name it returns may not open with gfortran's `open`](#file-names-on-windows) | ASCII names | v0.3.0 |
| Processes | [`p%kill` leaves the child's own children; a detached child's exit code is unknown; a crashed program cannot kill its children](#processes) | `force=.true.` on Windows; `p%killed()` | v0.3.0 |
| Tasks | [nvfortran's I/O is thread-safe only with `-mp`; the raw bindings are not checked from a task; no preemption](#tasks) | `-mp`; `recursive` procedures; `h%cancelled()` | v0.3.0 |
| Code editor | [Fallback symbols off the grid; deleting text in a marked line removes its mark; one mark per line](#the-code-editor) | Mark again after each change | v0.5.0 |
| Markdown | [No LaTeX, images from URLs, Mermaid, highlighting or footnotes; `_text_` is underlined; the whole text parsed every frame](#markdown) | `*text*` for italic; a long manual in several documents | v0.5.0 |
| fortplot | [fortplot's procedure `figure` and the module `figure` in one scope](#a-name-shared-with-fortplot) | Rename on import | v0.1.0 |
| Installer | [Not on Windows; gfortran, nvfortran and ifx only; packages for apt-get, dnf and Homebrew only](#the-one-line-installer) | MSYS2 UCRT64 by hand; packages by hand | v0.3.0 |
| Build | [The first native build downloads SDL3, cimplot, cimplot3d and miniz](#first-build-needs-the-network) | The release's sources archive (since v0.7.0) | v0.1.0 |

## Compilers

### nvfortran 26.9: a derived-type local named `size` stops the compiler {#nvfortran-26-9-internal-compiler-error-on-size}

A local variable of a derived type named `size`, given a value by a structure constructor (`size = vec2(w, h)`), makes
nvfortran 26.9 fail with "ILM file: can't find intrinsic size" (an internal compiler error), at any optimisation
level. The code is legal Fortran (`size` is not reserved); gfortran 16.2 and ifx 2026.2 compile it. Setting the
components one by one (`size%x = w`) compiles, and so does an integer local named `size`; the intrinsic `size()` need
not be called anywhere. FIGURE names such locals `extent`; do the same in modules of your own built with nvfortran 26.9.
**Reduced 2026-11-16** to a module of 13 lines (#4), re-run that day at `-O0` and `-O2` with the three compilers,
the two workarounds included. No canary: the defect is a build failure, which a test cannot
report.

### nvfortran: `-Munixlogical` on one side of the link breaks `select type`; `wait` does not wait {#nvfortran-munixlogical}

FIGURE's nvfortran modes compile and link with `-Munixlogical`, so that `.true.` passed to C is 1, the value of a C
`bool` (nvfortran's default is -1); the counterpart of ifx's `-fpscomp logicals`. Measured with nvfortran 26.9:

- **Compile and link with it, or neither** (#4, N1; no canary: the defect is in how a program is built, which a test
  built one way cannot see): besides the logical values of the code it compiles, the option selects
  at the link the run-time library's own (it adds `f90alt.o`). Code compiled with it but linked without it, or the
  reverse, gets `select type` wrong: no `type is` matches, while `same_type_as` says the type is the same. fobos
  passes it to both (`$CNVF` and the nvfortran modes' `lflags`); fpm passes `--flag` to both.
- **A program of yours** need not use it: FIGURE built with it works in a program compiled and linked without it
  (each side reads the other's `.true.` as true). If you use it, use it for the whole program, at the link too.
- **`execute_command_line(..., wait=.true.)`** in code compiled with it does not wait: the command runs
  asynchronously. Leave `wait` out (waiting is its default). Checked 2026-11-12 (nvfortran 26.9), and by the canary
  [`figure_test_canaries`](testing#canaries) on every nvfortran run of the tests.
- **fpm:** `--flag` replaces fpm's own nvfortran flags, `-Mbackslash` among them: pass
  `--flag "-Mbackslash -Munixlogical -mp"` (`-mp` for [tasks](#tasks)), as in
  [Installation](install#the-fortran-library-with-fpm).

### nvfortran: `char(i)` of a variable has length `i` {#nvfortran-char-i-of-a-variable}

`g = char(i)`, with `i` a variable and `g` a deferred-length string, gives `g` the length `i` with nvfortran 26.9 (`len(g)`
is 206 for `i = 206`), where the standard gives 1; `char(206)` with a constant is right. gfortran 16.2 and ifx 2026.2
give 1. FIGURE's UTF-8 helpers build the character in a fixed-length buffer (`utf8` in `docs/examples/src/gallery.F90`
and `src/tests/figure_test_text.F90`). Checked 2026-11-12; canary: [`figure_test_canaries`](testing#canaries).

### nvfortran: `select case` on a deferred-length function result matches no case {#nvfortran-select-case-on-a-function-result-of-deferred-length}

In a module that has a character parameter array built with a typed array constructor
(`character(len=8), parameter :: NAMES(3) = [character(len=8) :: 'Controls', 'Plots', 'Log']`), nvfortran 26.9 takes
the selector of `select case (f(...))` as empty when `f` returns `character(len=:), allocatable`: no case but `('')`
(or `default`) matches. Any optimisation level; gfortran 16.2 and ifx 2026.2 are right; the untyped constructor
(`['Controls', 'Plots   ', 'Log     ']`) or no such parameter avoids it. **Workaround:** assign the result to a variable
and select on the variable (`name = app%layout()`, then `select case (name)`, as `src/tests/figure_test_app.F90` does).
Checked 2026-11-16 (nvfortran 26.9, ifx 2026.2 and gfortran 16.2 at `-O0` and `-O2`, the untyped constructor
included); canary: [`figure_test_canaries`](testing#canaries) (#4).

### nvfortran: `system_clock` jumps with the wall clock {#nvfortran-system-clock-is-the-wall-clock}

nvfortran's `system_clock` (26.9, any integer kind) reads `gettimeofday`, the wall clock, not a monotonic clock:
when the system steps its time, an interval measured with it jumps by the step. WSL2 steps it often (measured: +2.56 s
every 32 s against the monotonic clock), which made FIGURE's own lazy-loop test fail one run in twenty under nvfortran.
gfortran's `system_clock` with an `int64` count is monotonic. To time a frame, a wait or a task under any compiler,
use [`figure_time()`](frame-loop#time) (from v0.5.0): seconds on a monotonic clock, the same under every compiler and
on every thread; FIGURE's own tests time with it.

### gfortran: a section of a deferred-length character array arrives as other elements {#gfortran-a-section-of-a-deferred-length-character-array}

A section of a deferred-length allocatable character array (`character(len=:), allocatable :: names(:)`, as
`ip_colormap_names` returns), passed to an assumed-shape dummy argument, arrives from the array's first element:
`call show(names(3:4))` sees `names(1:2)`. Seen with gfortran 15.2 and 16.2, at every optimisation level. nvfortran
26.9 passes a contiguous section right but not a strided one: `names(2:6:2)` arrives as blank strings. Both
compilers pass a section of a fixed-length array right (checked 2026-11-12: gfortran 16.2 still wrong; nvfortran 26.9
right for `names(3:4)`, a segmentation fault for `names(2:4:2)` at `-O0`; ifx 2026.2 right; canary:
[`figure_test_canaries`](testing#canaries), #4 Bug A). Copy the section into a fixed-length array first
(`own = names(k:k + 15)`, as `docs/examples/src/gallery.F90` does), or pass the elements one by one: this holds for
every `items` argument (`ig_combo`, `ig_list_box`).

### gfortran: an array constructor of deferred-length strings writes past its memory {#gfortran-an-array-constructor-of-deferred-length-strings}

An array constructor with a type-spec whose values are deferred-length character variables,
`[character(len=512) :: path, dir, '--pace']` with `character(len=:), allocatable :: path, dir`, is given too little
memory and written past its end: the program crashes later, in an unrelated allocation (`corrupted size vs.
prev_size`). Seen with gfortran 16.2 (valgrind reports the write in the constructor). The arguments of
`process_object%start` are the usual victim: fill a fixed-length array element by element instead, as
`docs/examples/src/tut12_run.F90` does. Checked 2026-11-12: gfortran 16.2 still aborts (`malloc(): corrupted top
size`); nvfortran 26.9 and ifx 2026.2 are right. Canary: [`figure_test_canaries`](testing#canaries), which runs
the case in a child process (#4 Bug B), not on Windows: there such a child can hang instead of ending (it did on CI,
2026-11-15), so the canary says "not probed".

### gfortran: a component passed to a `bind(C)` assumed-shape dummy corrupts the caller's array {#gfortran-a-component-passed-to-a-bind-c-assumed-shape-dummy}

A component of an allocatable array of derived type (`runs%cl`), passed to a `bind(C)` procedure's assumed-shape dummy
(a C descriptor), corrupts the caller's array descriptor with gfortran 15.2 and 16.2 (#4, Bug C). FIGURE is not
affected: its calls pass no such dummies, and its raw bindings are internal. A program that writes its own `bind(C)`
interfaces beside FIGURE's, with assumed-shape dummies, should pass a contiguous copy of such a component. No canary:
FIGURE has no workaround to remove.

### gfortran and nvfortran: plot data from a component of an array of derived types is copied {#strided-plot-data-copied-by-the-compiler}

The plot items read strided arrays in place ([Data in place](plots#data-in-place)), but a compiler may copy a
non-contiguous actual argument into a temporary before the call, at every call. The items' array dummies are
`asynchronous` (v0.5.0): gfortran 16.2 and nvfortran 26.9 then pass strided sections (`a(::2)`, `a(i, :)`) in place and
copy a component of an array of derived types (`runs%cl`); ifx 2026.2 passes both in place (measured 2026-11-12;
`figure_test_plot_data` checks it on every compiler of the tests). The plot is the same; the copy costs time (at a million points, `runs%t` and
`runs%cl` add about 55 % to the item with gfortran). Workarounds: `ip_line(label, y, row)` reads a row of a matrix in
place on every compiler; series stored as columns or contiguous arrays are never copied; a buffer the program fills
once per update and reuses avoids the allocation of the compiler's temporaries.

### Intel ifx: untested on Windows, absent on macOS; fpm does not add `-fpscomp logicals` {#intel-ifx}

Built and tested with ifx 2026.2 locally and with ifx 2026.1 in CI (`setup-fortran`'s newest Intel release, from
Intel's apt repository), on Linux only: ifx on Windows is untested (FIGURE's Windows build is MSYS2's MinGW, ifx
works with MSVC), and Intel ships no ifx for macOS.

- **`-fpscomp logicals`:** FIGURE's ifx modes compile with it, so that `.true.` passed to C is 1
  ([Intel ifx](install#intel-ifx)). fpm does not add it for ifx: pass `--flag "-fpscomp logicals"` to `fpm build`,
  `fpm test` or `fpm run`, also for a project that depends on FIGURE; without it ifx warns (#5472) and passes
  `.true.` as -1 to Dear ImGui.
- **The installer** takes ifx since v0.7.0 (`--intel`, Linux): its `.pc` and its CMake target add `-fpscomp logicals`
  to a program's compile line ([The one-line installer](install#the-one-line-installer)).

## Platforms and browsers

### macOS and Windows: input, vendor OpenGL drivers and traps in a window not exercised {#platforms}

Linux is built and tested locally; macOS (arm64) and Windows (MSYS2 UCRT64) are built and tested by CI (the
`Platforms` workflow), where the headless tests pass with FoBiS and fpm and `figure_hello` is opened in a real window,
its frames captured and checked ([Verified platforms](install#verified-platforms-and-compilers)). What CI does not
show:

- **Input in a window:** the checked frames are drawn with the capture's scripted input, not the system's mouse and
  keyboard; typing, the clipboard and drops in a window are untried on macOS and Windows.
- **Windows' OpenGL:** the runner has no GPU, so CI renders with Mesa's software `opengl32.dll`; a vendor's driver
  is not exercised.
- **Floating-point traps in a window:** CI opens `figure_hello` built with `-ffpe-trap=invalid,zero,overflow` on
  Windows (Mesa's llvmpipe) only; on Apple silicon gfortran's traps turn any exception into `SIGILL`, and AppKit's own
  event handling raises them, outside FIGURE's calls: the program stops in the system's frameworks (2026-11-14). FIGURE holds the floating-point environment around its calls into
  the driver and the window system, which raise flags with the exceptions masked.

On WSL2, set `GALLIUM_DRIVER=d3d12`, or Mesa renders in software ([Installation](install#wsl2-wslg)).

### FIGURE's window frame: no snap layouts, full-screen button or window menu {#the-window-s-frame-drawn-by-figure}

With `decorations='figure'` ([Frame loop](frame-loop#the-window-s-frame)) the system draws no frame, and what its
frame does beyond moving, resizing and the three buttons is lost:

- **Windows 11's snap layouts** (the layout menu shown when the pointer rests on the maximize button) do not appear:
  Windows shows them only for a system frame or a maximize button it can identify (`HTMAXBUTTON`), and SDL's hit test
  cannot report one. Whether snapping by dragging the window to a screen edge still works is unchecked: CI does not
  drag windows.
- **macOS's full-screen button:** the bar's buttons are close, minimize and maximize (zoom); there is no green
  full-screen button, and the traffic-light colours are not used (the palette's are).
- **Window menu:** the system's window menu (right-click on the title bar, Alt + Space on Windows) is not shown.
- **Linux:** under X11 and Wayland the window manager moves and resizes the window through SDL; a double-click on the
  bar is FIGURE's own, at Dear ImGui's double-click time. Under WSLg the frame is FIGURE's alone, which is the point
  of the option there.
- **No window icon on some systems:** a Wayland compositor without the `xdg-toplevel-icon` protocol and SDL's
  offscreen driver have no window icons: `app%set_icon` returns `FIG_ERR_FAILED` there (a stop without `stat`), and
  the icon shows in the bar only. Pass `stat` to `set_icon`.
- **A window over the bar:** a floating Dear ImGui window dragged over the title bar is drawn above it, but the hit
  test still treats the bar's empty part as the drag area. Dock spaces and side bars start below the bar.

CI draws the bar in a real window on Linux, macOS and Windows and checks its pixels; moving, resizing, snapping and
the buttons' actions there are driven by the system and are not exercised by CI.

### Linux: the system's file dialogs open on the desktop, not on the program's display {#the-system-s-file-dialogs-on-linux}

The system's dialogs (`app%open_file_dialog`, `save_file_dialog`, `open_folder_dialog`) are shown on Linux by the
desktop portal, another process reached over D-Bus, or by `zenity`. The portal draws on the user's desktop, not on the
program's display: a program in window mode with no display of its own (`DISPLAY` and `WAYLAND_DISPLAY` unset, SDL's
`offscreen` driver, a [capture](capture)) can still open a dialog on the desktop of the session it runs in. Tests and
recordings never click the system's dialogs; they drive [FIGURE's file browser](frame-loop#figure-s-file-browser),
which is drawn into the program's own frames. A program can ask for the browser through the same calls with
`prefer='figure'`.

### Remote mode: some key chords never reach the program, others act in the browser too {#shortcuts-in-a-browser}

In [remote mode](remote) the keys come from the browser, which keeps some chords for itself
([Shortcuts](menus#shortcuts)):

- **Never delivered to a page** (Chrome, Edge; Firefox keeps most of them too): ctrl+w, ctrl+t, ctrl+n,
  ctrl+shift+w, ctrl+shift+t, ctrl+shift+n, ctrl+tab, ctrl+shift+tab (closing and opening tabs and windows). A
  program's `ig_shortcut('ctrl+w')` never fires in remote mode; bind another chord, or offer the action in a menu too.
- **Delivered, and acted on by the browser as well:** FIGURE's page stops the browser's own action for the chords
  with ctrl (cmd on a Mac) other than ctrl+c, ctrl+v and ctrl+x, and for tab. The function keys and the alt chords
  reach the program **and** the browser: f5 also reloads the page (the program goes on; the page reconnects), f11
  switches the browser to full screen, f3 and f7 may start the browser's search or caret browsing, alt+left goes
  back. Prefer ctrl chords for actions a remote user takes often.
- **The system's chords** (alt+tab, cmd+tab, cmd+space, the window manager's) never reach the browser, as in window
  mode.

### Remote mode: a link's tab can be blocked as a pop-up {#links-in-a-browser}

In [remote mode](remote) a click on an `ig_text_link_url` reaches the program, which sends the URL back to the page;
the page opens it with `window.open`, a new tab ([Links](widgets#links)). A browser lets a page open a tab only
shortly after the user's click (a few seconds in Chrome and Firefox), so on a slow connection, or with a strict
pop-up blocker, the tab is blocked: the page then shows "the browser blocked opening ...: allow pop-ups for this page".
Allow pop-ups for the page's address once, or copy the link with a right click on it ("Copy Link", into the browser's
clipboard where [the browser allows it](#the-clipboard-and-drops)). A `file://` URL names a file of the browser's
machine, not of the machine the program runs on.

### Remote mode and WSLg: the clipboard and drops are limited {#the-clipboard-and-drops}

- **Remote mode, copy:** the browser's clipboard is written only where the browser allows it: a secure context
  (`localhost`, `https`), and in some browsers (Safari) only within a click or a key. Elsewhere the copy stays in the
  program on the server, and the page's status line says so for 8 seconds, beside the frame counter
  ([Remote UI](remote#the-clipboard-and-drops)).
- **Remote mode, paste:** the program sees the browser's clipboard only through a paste (ctrl+v, cmd+v) in the page;
  a button that pastes reads the program's own clipboard. If a browser sends no paste event within 200 ms of the
  key, the key goes alone and pastes the program's own clipboard.
- **Remote mode, drops:** none: a browser gives a page the contents of dropped files, not paths on the server.
- **Window mode, drops:** they come from the system through SDL. Under WSLg, dragging from Windows' Explorer onto a
  Linux window is not delivered (WSLg does not carry drag and drop between Windows and Linux); drop from a Linux file
  manager, or open with the [file browser](frame-loop#figure-s-file-browser). Dropped text is not reported, only
  files and folders.
- **Untested:** drops and the system clipboard in a window on macOS and Windows have not been tried (CI opens a window
  there, see [Platforms](#platforms), but drops nothing on it); the tests check the remote clipboard's messages with a
  client of their own, not a browser's permissions.

## Features

### Two widgets with the same label in a window are one widget {#unique-labels}

Dear ImGui identifies widgets by their label within a window: two widgets with the same label are one widget. Use
`'label##suffix'` to repeat a visible text ([Widgets](widgets#labels-and-identifiers)). Labels are passed verbatim,
trailing blanks included: pass `trim(...)` of a fixed-length buffer.

### Windows cannot be dragged out of the main window (no multi-viewports) {#no-multi-viewports}

[Docking](docking) is on, but windows cannot be dragged out of the main window into windows of their own
(Dear ImGui's multi-viewports): remote and headless modes cannot have them. (Note for the history: the cimgui tag
`1.93dock`, pinned until S1, was generated from Dear ImGui's master branch despite its name, and had no docking.)

### Text fields: a `character` field cuts at its length; the multi-line field is plain {#text-input}

`ig_input_text` edits a `character` variable, whose length is the field's capacity: a longer text is cut at it. Text
of any length goes in a `text_buffer_object`, edited by `ig_input_text_multiline`
([Multi-line text](widgets#multi-line-text)), which is a plain field: no line numbers, no syntax highlighting, no
search, and Dear ImGui goes through the whole text on every frame (a log that grows without end belongs in a
[log view](processes#the-log-view)).

### A field rewritten in place keeps its old colours {#a-field-changed-in-place}

`ip_field_image` colours a field again when its arguments change (the array's address or shape, the range, the
colormap, the scale, the NaN colour), not when its values do: FIGURE does not read the whole array every frame to
find out. A program that rewrites the array in place (a time step) passes `changed=.true.` on that frame
([Fields](plots#fields)); without it the plot keeps the old colours. A strided section passed as the field is copied
by the compiler into a temporary at every call: its address may change from call to call, and the field is then
coloured on every frame (correct, but slower): pass a contiguous array.

### Digital signals draw only through FIGURE's patch of ImPlot {#implot-s-digital-signals}

FIGURE patches one line of ImPlot (`native/patches/implot-0001-digital-rect-order.patch`): `PlotDigital` gives
`AddRectFilled` its corners with the top below the bottom, and Dear ImGui 1.93's anti-aliased `AddRectFilled` returns
at once for a negative height, so every digital bar was missing (`ip_digital`, [Grouped bars and digital
signals](plots#grouped-bars-and-digital-signals)). The patch orders the corners. Found and checked 2026-11-16
(ImPlot `72de278`, Dear ImGui `cf53467`); `src/tests/figure_test_plot_links.F90` fails without it. A program on the
raw layer (`ImPlot_PlotDigital_*`) gets the fix too. The report for ImPlot is the owner's to file (#8).

### 3-D plots: no depth buffer, no lighting, heavy in remote mode {#implot3d}

The [3-D plots](plots#_3-d-plots) are ImPlot3D's, which draws every primitive as Dear ImGui triangles:

- **Back-to-front drawing, no depth buffer.** ImPlot3D sorts the triangles and segments of a plot by the depth of
  their centres, each frame, and draws the farthest first. Where two surfaces cross, or a long triangle lies beside a
  short one, the order is wrong over part of their overlap: a surface shows through another, a line is hidden where it
  passes in front (the golden picture of `figure_test_plot3d` shows a transparent mesh crossing a surface). Plots
  without intersections (a trajectory, probes, one surface) are drawn right; meshes that cross belong to
  [`view3d_object`](view3d), which has a depth buffer.
  A small item on a large one is the same case: a marker lying on an image of the floor (`ip3_image`) is hidden,
  the floor's two triangles having centres nearer the eye (checked 2026-11-16, the picking example of
  [3-D plots](plots#_3-d-plots)).
- **Picking on log axes.** `ip3_mouse_ray` gives the ray in the box's transformed space: on a log or symlog axis it is
  not a straight line in plot units; pick on linear axes.
- **Remote bandwidth.** In remote mode every vertex of every plot goes to the browser each frame, as for any widget:
  a surface of 100 × 100 with its grid lines is about 65 000 vertices (39 208 for the fill, 26 328 for the lines,
  measured), some 1 MB a frame before deflate, against one image for a `view3d_object`. Keep remote 3-D plots near
  10⁴ primitives, or draw the surface without its lines (`ImPlot3DSurfaceFlags_NoLines`).
- **No lighting.** Surfaces and meshes have flat colours (a colormap, or one colour); a body of one colour reads as
  its outline: give it edges (`line_color`) or a translucent fill.
- **Cost.** Every frame ImPlot3D projects and sorts every primitive on the CPU: a surface of 200 × 200 is 40 000
  quads to sort per frame.
- **FIGURE patches ImPlot3D** in one place (`third_party/implot3d/patches/0001-no-mouse-position.patch`): with no
  mouse position (headless and remote modes before the first move, a window the pointer has left) its input handling
  tested the position against the box and overflowed, a trap under `-ffpe-trap=invalid,overflow`.

### 3-D views: JPEG while the camera moves in remote mode; large meshes render slowly {#_3-d-views}

[3-D views](view3d) are rendered on the CPU, into an image:

- **Remote mode, while the camera moves, shows JPEG images:** an image changing frame after frame goes as a JPEG
  (quality 75), so the browser shows its artefacts (blur around edges and grid lines, banding in smooth gradients)
  until the camera has been still for 150 ms, when the exact image replaces it. `init_remote(lossy=.false.)` sends
  every render exact: `4 * width * height` bytes, a quarter of that while moving, which an SSH tunnel to a cluster
  node cannot carry at more than a few renders a second ([Changing images](remote#changing-images)).
- **A slow link still limits the frame rate:** a 1600x1000 view zoomed in on a grid sends about 118 KB per JPEG, 7
  MB/s at 60 frames a second; below that FIGURE sends only the newest frame and image, fewer per second.
- **Large meshes:** above a million triangles a render takes tens of milliseconds, and the camera moves at that rate.
  The image is drawn in blocks of 16 rows by whichever of the `threads` (up to 16) is free. Measured on a grid of 6.5
  million triangles and 6.6 million grid-line segments (xall_figure, 956x687, 2026-11-14): 25 ms a render on 4
  threads and 19 ms on 16 without the grid lines, 132 and 124 ms with them; the segments read two vertices each, so
  more threads gain little there. While the camera moves the half-size renders leave the grid lines out (the render
  at the end of the move draws them).
- **The image has the view's size in logical pixels:** on a display scaled 2x it is magnified.

### Gizmos: coarse at grazing angles, single precision, the mouse taken one frame late {#gizmos}

The [view cube and the gizmos](view3d#gizmos) are ImGuizmo's, and the [gradient editor](colormaps#editing-a-colormap)
its ImGradient, with FIGURE's glue:

- **Precision at grazing angles.** A drag along an axis moves the matrix by the mouse's motion over the sine of the
  angle φ between the axis and the line of sight: at 30° a pixel is worth 2 pixels' worth of world at that depth, at
  12° about 5 (measured, `figure_test_gizmo`: 1.87, 2.69 and 4.32 at 30°, 20° and 12°, against 1/sin φ = 2.00, 2.92,
  4.81, the rest the perspective's gain as the point comes toward the eye). Below a few degrees the arrow is hidden
  (ImGuizmo's limit: its projection shorter than 0.02 in clip units, a twentieth of its full length on a 400-pixel
  view, about 3°); a plane handle seen
  edge-on likewise. An arrow shorter than about 12 pixels on the screen lies inside the centre square, which moves
  the point in the screen's plane instead. Turn the camera (the view cube) so that the axis lies across the screen,
  or move in the plane of the two other axes.
- **Single precision.** ImGuizmo computes in `real(real32)`: a moved matrix comes back rounded to about 10⁻⁷ of the
  scene's size (FIGURE moves the world so that the camera's target is at the origin first; a matrix not moved is not
  touched). A gizmo far from the target, many scene sizes away, is placed more coarsely.
- **The gizmos' rays use a wider depth range than the view.** ImGuizmo casts the mouse's ray from the point at clip
  depth 0 and mirrors an intersection that falls behind it; with the view's own near and far planes, which hug the
  meshes, that point lies inside the scene, and an arrow pointing toward the eye dragged the wrong way. FIGURE gives
  the gizmos the view's projection with the depth range [d/1000, 1000 d] (d the camera's distance): the same pixels,
  the ray's origin near the eye. `v%projection_matrix` is the view's own.
- **A gizmo takes the mouse one frame late:** from the frame after the pointer reaches a handle (the view's own item
  must not be hovered when ImGuizmo looks); a press in the same frame as the pointer's arrival orbits the view. The
  view cube takes it at once (its rectangle is known).
- **No callbacks, no undo:** the program keeps the matrix before a drag if it wants to go back.
- **The cube's faces have no letters**, only the axis colours (red x, green y, blue z); the cube's motion is
  ImGuizmo's 40-frame turn (the last frame landing on the face: FIGURE's patch). Autodesk holds a US patent on
  this kind of view cube (US7782319B2), which ImGuizmo's authors consider defensive; FIGURE ships ImGuizmo's code as
  it is.
- **The gradient editor:** a stop moves by the mouse's motion over the row's whole width (ImGradient's rule), a
  little faster than its square, which spans the width less one square; stops may cross each other (the map takes
  them by position); two editors of one map edit the same stops, each with its own selection.
- **FIGURE patches ImGuizmo** in three places (`third_party/ImGuizmo/patches/`): `BeginFrameState` (the per-frame
  state of `BeginFrame` without the full-screen window it opens, which would have been a window of every program);
  the view cube's last frame of a turn landing on its target (it stopped 1.3·10⁻⁴ short); ImGradient's selection and
  moved point kept per editor and its press taken by an item (they were statics shared by every editor, and a drag
  moved the window).

### Images from files: PNG and JPEG only, no colour management or orientation {#images-read-from-files}

`fig_read_image` and `tex%load` read PNG and JPEG only, with no colour management (a PNG's gamma and an ICC profile
are ignored) and no EXIF orientation (a photograph stored sideways comes out sideways): rotate it in the program
(`rgba(:, j, i)` for a transpose) or in an image editor. stb_image checks neither PNG's CRCs nor zlib's checksum,
and decodes a JPEG cut short with the missing part filled in, so a file that decodes is not proven intact
([Reading images](images#limits)).

### Pictures without a GPU: differences from a GPU and across platforms {#pictures-without-a-gpu}

Headless and remote modes draw their pictures (`save_image`, `FIGURE_CAPTURE`, `test_capture`) with FIGURE's CPU
renderer ([Screenshots and videos](capture#three-modes-two-renderers)):

- **Differences from the GPU:** 1 or 2 levels (of 255) at anti-aliased edges and blends. Measured against an RTX 4070
  on the documentation's 80 recordings: no other difference except single pixels of a plot line where a pixel centre
  falls within 1/256 pixel of an edge and the two round the other way (one pixel, by up to 155 levels, in each of 3
  recordings). A golden made by the CPU renderer is compared with the CPU renderer's pictures, so this does not touch
  tests; a picture read back from a window differs from one rendered headless by these.
- **Ties:** pixel centres on an edge go by the image's top-left rule (Direct3D's, that GPU's). Mesa's llvmpipe uses
  OpenGL's and draws one row of pixels differently there (the first row of an image drawn with nearest filtering,
  heatmap cell edges); a native OpenGL GPU driver was not measured.
- **Programs that wait on the wall clock:** a recording made headless (`FIGURE_CAPTURE_HEADLESS`) draws its frames
  faster than a window does, so what a task or a process has produced by a given frame differs: a progress bar, a
  log, a plot fitted to data that arrived later. Such a recording is deterministic in each mode, not across them.
- **Draw callbacks:** a program's own `ImDrawList` callback (raw bindings) is not run by the CPU renderer.
- **Other platforms:** the CPU renderer draws the same pixels on macOS (arm64, Apple clang, gfortran 16) and Windows
  (MSYS2 UCRT64, gfortran) as on Linux (on CI, run 43868894311, 2026-11-16: of the documentation's 101 recordings,
  2 skipped everywhere, 91 pass on macOS with its overrides and 8 more skipped there, all 99 others on Windows with
  its own; 77 have no per-platform override, the five v0.7.0 adds among them); what differs is the program's own arithmetic, FIGURE's title bar on macOS, a path shown natively on
  Windows, and one glyph on macOS:
  - the C library's maths (glibc on Linux, not elsewhere) and, on arm64, multiply-adds the compiler may fuse move
    what a program computes: a rounded border or a plotted value by a pixel (5 and 104 pixels in two recordings, the
    same counts on macOS and Windows; 62 in a third on macOS), a fractal by much more (the Mandelbrot example: 44443
    pixels on macOS, 30727 on Windows);
  - FIGURE's title bar (`decorations='figure'`) has its buttons on the left on macOS, the menus after them: every
    picture of a window with it differs there (about 1400 pixels), and an input script that clicks the bar or its
    menus at fixed coordinates plays something else;
  - one glyph: in `tut13_field` the `7` of a value is drawn differently on macOS in about one run in three (12
    pixels, its top-left edge, by up to 25 levels; run 43702518123, 2026-11-15), where Linux draws the same text alike
    after three atlas histories and under full load. Its cause is not found; 32 pixels are allowed there, and since
    v0.7.0 a picture that fails keeps the font atlas it was drawn with (`FIGURE_CAPTURE_ATLAS`,
    [Variables](capture#variables)), uploaded by CI, for the next time it happens.

  The studio tutorials wrote their example cases with POSIX shell commands, which `cmd.exe` refuses, so v0.6.0 did not
  compare their pictures on Windows; since v0.7.0 they use [FIGURE's file API](frame-loop#files-and-folders) and
  `process_object`, and their recordings are compared on Windows too: masked where a case's native path
  (`D:\tmp\figure-studio\plate`) or the drives are shown (run 43744364220).

  `docs_media.py --check` gives such a recording a per-platform mask, tolerance or skip (`#! mask.darwin`,
  `#! check.win32 max_failed=N`, `#! check.darwin skip`), each with the number measured; a program's own golden
  check can leave out the bar where the close button is left of the menus (`test_frame_rect`, as tutorial part 25
  does).
- **Speed:** about 1 ns a pixel drawn per thread; a 1400 x 860 frame of the documentation's scenes takes 0.7 to 1.7 ms
  on 8 threads, 0.8 to 6.7 ms on one, more with a large texture sampled on every pixel.

### Items found by path: text, images and plot items have no path; a shared label is a shared id {#items-found-by-path}

A path names items that have an id: text, separators, progress bars, images and plot items are not items, and are
found only through a widget with a label. Items with the same label in one id scope share one id (an id conflict,
`test_id_conflicts`): no path tells them apart, give them `##` ids. The items are recorded in every mode from the
first frame (since v0.6.0; v0.5.0 recorded window and remote programs only from their first path call, which found
nothing); `test_record_items(.false.)` stops it. A value is read from the glyphs drawn: a character cut by a clip rectangle is not read ([Finding items by path](testing#finding-items-by-path)).

### Preferences: no window position on Wayland, no theme file or fonts kept {#preferences-and-the-window-s-place}

`app%open_prefs` restores the window's size and maximized state everywhere, its position only where the system lets a
program place its window: Wayland does not (the compositor places it), and a position off every display (a monitor
unplugged since) is skipped. The preferences keep the style set by `set_style`, not a theme file, the style editor's
changes or the fonts; a program that ends without `destroy` loses what changed after the last 30-second save
([Preferences](frame-loop#preferences)). A message box waits, not drawn, while one of the program's popups is open
(Dear ImGui keeps one popup per level): ask it after the popup closes ([Message boxes](menus#message-boxes)).

### FIGURE's file browser: no desktop integration, folders read on the main thread {#the-file-browser}

FIGURE's file browser ([File dialogs](frame-loop#figure-s-file-browser)) is drawn by FIGURE, not by the system:

- **No desktop integration:** the system's bookmarks, network locations, thumbnails and search are not shown; the
  places are the home folder, the working directory, the roots and FIGURE's own recent folders.
- **A folder is read on the main thread** when it is entered or read again: a folder of very many entries on a slow
  network file system pauses the interface while it is read. It is not watched: a file written meanwhile appears
  after Refresh.
- **One settings file for every program:** the recent folders are shared by all the programs built with FIGURE.
- **Tab completion** is case-sensitive on every platform.

#### Windows: non-ASCII names from the browser may not open {#file-names-on-windows}

The browser lists and returns names in UTF-8 on every platform (it reads Windows' folders with the wide-character
API). gfortran's `open` on Windows passes the name to the C library in the system's code page, so a path with
non-ASCII characters returned by the browser may not open there; names in ASCII are not affected.

### Processes: a kill stops the program started, not its children {#processes}

[Processes](processes) are started without a shell, through SDL3's process API (captured) or a double fork (detached,
POSIX):

- **Killing a tree:** `p%kill` stops the program started, not the programs it started (`sh -c 'a; b'` leaves `a`
  running; on Windows `cmd /c` leaves its children). A captured child that ended while one of its own children holds
  the pipe is read for 0.1 s more, then FIGURE stops reading.
- **Windows:** a polite kill is a close request to the child's windows or console, which a console program may
  ignore: use `force=.true.` (TerminateProcess). Windows has no `sh`: write `['cmd', '/c', '...']` for a command line.
- **Exit codes:** a detached child's exit code is not known (its parent is the system's init, not the program); after
  a kill, a captured child's exit code is the negative signal number on POSIX (-15, -9) and 1 on Windows: test
  `p%killed()` instead.
- **A crashed program** (killed by a signal) cannot kill its captured children; they end when they next write to the
  closed pipe, or by themselves.
- **No init to reap a detached child:** a detached child belongs to the system's init, which reaps it when it ends.
  In a container whose first process is not an init (Docker without `--init`, GitHub's job containers, whose first
  process is `tail -f /dev/null`), nothing reaped it: the ended child stayed a zombie, and until v0.7.0
  `p%running()` stayed true forever (a loop waiting for it never ended). FIGURE now reaps it itself where the
  program is that first process, and counts a zombie as ended where another process holds it (Linux, from
  `/proc`). Found 2026-11-16: it hung the documentation's CI job on `tut17_tested`; `figure_test_process` runs the
  case as PID 1 of a new namespace (`unshare -rpf`, where the system allows it).

### Tasks: nvfortran's I/O needs `-mp`; the raw bindings are not checked {#tasks}

[Tasks](processes#tasks) run Fortran procedures on SDL threads:

- **nvfortran's I/O runtime is thread-safe only with `-mp`:** without it, Fortran I/O from two threads at once
  (formatted, list-directed, internal `write` to a string included) fails at random (`FIO-F-222 ... unbalanced
  parentheses in format string`) or crashes; compile the code a task runs, and the program, with `-mp` (OpenMP: FoBiS
  `openmp = True`). Measured with nvfortran 26.9: 8 tasks writing to strings fail in most runs without `-mp`, in none
  with it. gfortran's I/O is thread-safe with no flag.
- **Drawing from a task** is refused at every drawing procedure of FIGURE: containers, widgets, plot items, styles,
  menus, tables, the 3-D view (the rule and its statuses are in [Tasks](processes#tasks)). The raw bindings
  (`figure_cimgui`, `figure_cimplot`: Dear ImGui's and ImPlot's own functions) are not checked: one called from a
  task races with the main thread. Before v0.3.0 a widget outside any container was not checked either: in a test
  (`ig_text` from a task, gfortran 16.2, Linux) the worker failed an assertion of Dear ImGui's font rasterizer
  (SIGABRT) in four runs of five and hit a segmentation fault in the fifth.
- **Why Dear ImGui's context is not thread-local** (studied for v0.3.0, not adopted). Dear ImGui and ImPlot reach
  their context through one global pointer each (`GImGui`, `GImPlot`); both can be made `thread_local` through
  Dear ImGui's configuration header, so that a worker thread has no context at all. Measured on Linux (gfortran 16.2,
  GCC's C++, the native layer rebuilt so): the test suite passes, and a frame of 300 text lines and a plot of 4000
  points costs 0.130 to 0.134 ms against 0.129 to 0.131 ms (within the noise; every access becomes a TLS access,
  `__tls_get_addr` at 579 call sites of `imgui.cpp` alone in the static library). It does not make the failure
  clean:
  - Dear ImGui dereferences the context without a check in 642 places (`ImGuiContext& g = *GImGui`) and ImPlot in
    113; only a few entry points assert it (`GetIO`, `GetStyle`, `NewFrame`). A widget called from a worker is then
    a null-pointer access: in the same test, a segmentation fault in the worker in five runs of five, after which the
    task never ended. A crash in place of a race, not FIGURE's refusal with `FIG_ERR_STATE`.
  - FIGURE cannot turn it into its refusal where it matters: its widget procedures call cimgui directly, and so do
    the raw bindings (`figure_cimgui`, `figure_cimplot`). A refusal needs a check in every one of them, which FIGURE
    can do without a thread-local context: it already knows a worker thread (the check of its container entry points).
  - The cost on the other platforms is not measured: MinGW's GCC implements `thread_local` by emulation (a function
    call, `__emutls_get_address`, at each access), and Apple's clang through a thread-local variable thunk; FIGURE's
    CI builds there but cannot be measured from Linux.

  FIGURE therefore checks in each of its drawing procedures (since v0.3.0): a call that reads a thread-local marker
  of the worker threads, about 1.5 ns on the main thread (gfortran 16.2, Linux); a frame of 300 text lines and a plot
  takes 0.128 to 0.130 ms with the checks, as without them.
- **`recursive` procedures:** two tasks may run the same procedure at the same time; a procedure not declared
  `recursive` then stops a program built with gfortran's `-fcheck=recursion` (in `-fcheck=all`): declare the task's
  procedures `recursive`. FIGURE's entry points that refuse a task's drawing calls are `recursive` themselves, so the
  refusal happens in such a build too.
- **No preemption:** a task with no safe point (`h%cancelled()`) cannot be stopped; its object's end waits for it.

### Code editor: fallback symbols off the grid; a deletion removes a line's mark {#the-code-editor}

The [code editor](editor) is ImGuiColorTextEdit (the goossens fork) with FIGURE's glue:

- **Symbols of the fallback font keep their own width.** The editor places each character on a grid of IBM Plex
  Mono's advance; `ρ`, `∞`, `∇` come from Noto Sans Math, whose glyphs are narrower or wider than the grid, and may
  touch the next character. The columns after them stay aligned.
- **Deleting text in a marked line removes its mark** (the fork's rule): mark again after each change, as a validator
  on `ed%draw`'s result does. Typing in the line keeps it.
- **A mark per line.** A second mark on a line joins the messages and keeps the gravest severity.
- **The fork's options not exposed:** word wrap, line folding, the minimap, several cursors made by the program,
  squiggles under part of a line, a context menu of the program's. They are reached through FIGURE's glue when a
  program needs one.
- **FIGURE patches the fork in two places** (`third_party/ImGuiColorTextEdit/patches/`, re-applied at the fork's
  head 9f812a0 in v0.6.0; checked 2026-11-15):
  - its marker list, renumbered after a deletion, stored the new numbers in a `bool`, so the third mark and those
    after it took the second one's colour once any character was deleted;
  - `cursorWidth` had no initial value, and a fresh editor's first frame sized itself from whatever the heap held: a
    NaN or a huge width, a `SIGFPE` at the second frame in a program built with `-ffpe-trap=invalid` (found by
    xall_figure's GUI tests, intermittently). It starts at 1 pixel; `figure_test_editor` draws a fresh editor twice
    under traps with its heap filled with `0x7F` bytes (Linux).

### Markdown: no LaTeX, images from URLs or Mermaid; `_text_` underlines {#markdown}

[Markdown](widgets#markdown) is imgui_rich_md's, with md4c's parser, vendored with FIGURE's glue:

- **Not supported:** LaTeX formulas (`$...$` and `$$...$$` stay text: imgui_rich_md's formulas need MicroTeX and
  FreeType), images from URLs (`![](https://...)` draws nothing: no download is made), Mermaid diagrams (a
  ` ```mermaid ` block is shown as code), syntax highlighting in code blocks, files included into a page (`![[file]]`,
  imgui_rich_md's transclusions: the text is drawn as it is), wikilinks (`[[page]]` is text), footnotes, raw HTML
  beyond the tags listed in [Markdown](widgets#markdown). Image files are PNG or JPEG only (FIGURE's decoder).
- **`_text_` is underlined,** not italic (md4c's underline extension, which imgui_rich_md turns on): `*text*` is
  italic.
- **Images are read relative to the working directory,** not to the file `md%load` read: write their paths from where
  the program runs, or give absolute ones. Each image is read and uploaded once, on its first draw, and kept until the
  application ends.
- **Every frame parses the whole text** (md4c, then the layout of what it finds), for `ig_markdown` and a document
  alike; `ig_markdown` also copies its text across the C boundary each frame, a document keeps its own. A page of a few
  screens is cheap; a manual of hundreds of pages belongs in several documents.
- **The table of contents lists the headings of levels 1 to 3;** deeper ones are reached by scrolling, and by the
  search.
- **A table sized by its content** (`SizingStretchProp`, imgui_rich_md's tables) computes 0 / 0 in Dear ImGui on its first
  frame, before its columns have widths ([ocornut/imgui#8718](https://github.com/ocornut/imgui/issues/8718), open).
  FIGURE patches that line (`native/patches/imgui-0001-stretch-weight-zero-sum.patch`, [THIRD_PARTY.md](https://github.com/szaghi/figure/blob/main/THIRD_PARTY.md)):
  each column then starts with the same weight, and a program built with `-ffpe-trap=invalid` does not stop, in
  Markdown or in its own `ig_begin_table(..., flags=ImGuiTableFlags_SizingStretchProp)`. Since v0.6.0; v0.5.0 held the
  traps while Markdown was drawn, and a program's own table stopped.
- **FIGURE patches imgui_rich_md** in one line (`third_party/imgui_rich_md/patches/0001-figure-stb-image.patch`): its
  images are decoded by FIGURE's copy of stb_image, not by a second one of its own.

### fortplot's procedure `figure` clashes with the module `figure` {#a-name-shared-with-fortplot}

`lazy-fortran/fortplot` has a public procedure named `figure`. A program that uses both libraries cannot have the
module `figure` and that procedure under the same name in one scope: rename one on import, for example
`use fortplot, only : fp_figure => figure`.

## Installing and building

### The one-line installer: not on Windows, three compilers, apt-get, dnf and Homebrew only {#the-one-line-installer}

What [the installer](install#the-one-line-installer) does not cover:

- **Windows:** it runs on Linux and macOS only. On Windows, build under MSYS2 UCRT64 by hand
  ([Other platforms](install#other-platforms)).
- **Compilers:** gfortran, nvfortran and (since v0.7.0, Linux) ifx; any other `--fc` is refused. nvfortran and ifx
  are not installed: `--deps` installs only packages of the distribution (`apt-get`, `dnf`) or of Homebrew, and only
  gfortran among the Fortran compilers.
- **Distributions:** the package command is written for `apt-get` (Debian, Ubuntu) and `dnf` (Fedora, RHEL). Elsewhere
  the script names the missing `pkg-config` modules and stops: install their development packages by hand.
- **Run-time packages:** file dialogs need an XDG desktop portal or `zenity` at run time
  ([Linux packages](install#linux-packages)); the installer neither checks nor installs them.
- **`PKG_CONFIG_PATH`:** the script does not edit shell start-up files; when `pkg-config` does not already search
  the prefix, it prints the `export` line to add.
- **Network:** a build needs GitHub (the release and the native layer's sources) and, when FoBiS is missing, PyPI.
- **Tested on fresh runners** (`Installer` workflow: Ubuntu with `--deps`, macOS with Homebrew); other systems are
  untested.

### The first native build needs the network {#first-build-needs-the-network}

The native build downloads SDL3, cimplot, cimplot3d and miniz (CMake `FetchContent`) the first time (Dear ImGui and
cimgui are in the repository), and every FoBiS mode runs it first (a few seconds when nothing changed). A machine with
no network builds from the release's sources archive instead, which holds them all
([Building without network](install#building-without-network), since v0.7.0).
