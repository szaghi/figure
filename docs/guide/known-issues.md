---
title: Known issues
---

# Known issues

## Unique labels

Dear ImGui identifies widgets by their label within a window: two widgets with the same label are one widget. Use
`'label##suffix'` to repeat a visible text ([Widgets](widgets#labels-and-identifiers)). Labels are passed verbatim,
trailing blanks included: pass `trim(...)` of a fixed-length buffer.

## No multi-viewports

[Docking](docking) is on, but windows cannot be dragged out of the main window into windows of their own
(Dear ImGui's multi-viewports): remote and headless modes cannot have them. (Note for the history: the cimgui tag
`1.93dock`, pinned until S1, was generated from Dear ImGui's master branch despite its name, and had no docking.)

## nvfortran 26.9: internal compiler error on `size`

A local variable named `size` in one procedure and the intrinsic `size()` called in another procedure of the same
module make nvfortran 26.9 fail with "ILM file: can't find intrinsic size" (an internal compiler error). The code is
legal Fortran. FIGURE names such locals `extent`; avoid naming a local `size` in modules of your own built with
nvfortran 26.9 if you hit the same error.

## nvfortran: `-Munixlogical`

FIGURE's nvfortran modes compile and link with `-Munixlogical`, so that `.true.` passed to C is 1, the value of a C
`bool` (nvfortran's default is -1); the counterpart of ifx's `-fpscomp logicals`. Measured with nvfortran 26.9:

- **Compile and link with it, or neither:** besides the logical values of the code it compiles, the option selects
  at the link the run-time library's own (it adds `f90alt.o`). Code compiled with it but linked without it, or the
  reverse, gets `select type` wrong: no `type is` matches, while `same_type_as` says the type is the same. fobos
  passes it to both (`$CNVF` and the nvfortran modes' `lflags`); fpm passes `--flag` to both.
- **A program of yours** need not use it: FIGURE built with it works in a program compiled and linked without it
  (each side reads the other's `.true.` as true). If you use it, use it for the whole program, at the link too.
- **`execute_command_line(..., wait=.true.)`** in code compiled with it does not wait: the command runs
  asynchronously. Leave `wait` out (waiting is its default).
- **fpm:** `--flag` replaces fpm's own nvfortran flags, `-Mbackslash` among them: pass
  `--flag "-Mbackslash -Munixlogical -mp"` (`-mp` for [tasks](#tasks)), as in
  [Installation](install#the-fortran-library-with-fpm).

## gfortran: a section of a deferred-length character array

A section of a deferred-length allocatable character array (`character(len=:), allocatable :: names(:)`, as
`ip_colormap_names` returns), passed to an assumed-shape dummy argument, arrives from the array's first element:
`call show(names(3:4))` sees `names(1:2)`. Seen with gfortran 15.2 and 16.2, at every optimisation level; nvfortran
26.9 passes the section right, and so does gfortran for a fixed-length array. Copy the section into a fixed-length
array first (`own = names(k:k + 15)`, as `docs/examples/src/gallery.F90` does), or pass the elements one by one.

## gfortran: an array constructor of deferred-length strings

An array constructor with a type-spec whose values are deferred-length character variables,
`[character(len=512) :: path, dir, '--pace']` with `character(len=:), allocatable :: path, dir`, is given too little
memory and written past its end: the program crashes later, in an unrelated allocation (`corrupted size vs.
prev_size`). Seen with gfortran 16.2 (valgrind reports the write in the constructor). The arguments of
`process_object%start` are the usual victim: fill a fixed-length array element by element instead, as
`docs/examples/src/tut11_run.F90` does.

## Text input

`ig_input_text` edits a `character` variable, whose length is the field's capacity: a longer text is cut at it. Text
of any length goes in a `text_buffer_object`, edited by `ig_input_text_multiline`
([Multi-line text](widgets#multi-line-text)), which is a plain field: no line numbers, no syntax highlighting, no
search, and Dear ImGui goes through the whole text on every frame (a log that grows without end belongs in a
[log view](processes#the-log-view)).

## The clipboard and drops

- **Remote mode, copy:** the browser's clipboard is written only where the browser allows it: a secure context
  (`localhost`, `https`), and in some browsers (Safari) only within a click or a key. Elsewhere the copy stays in the
  program on the server, and the page's status line says so ([Remote UI](remote#the-clipboard-and-drops)).
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

## A name shared with fortplot

`lazy-fortran/fortplot` has a public procedure named `figure`. A program that uses both libraries cannot have the
module `figure` and that procedure under the same name in one scope: rename one on import, for example
`use fortplot, only : fp_figure => figure`.

## Platforms

Linux is built and tested locally; macOS (arm64) and Windows (MSYS2 UCRT64) are built and tested by CI (the
`Platforms` workflow), where the headless tests pass with FoBiS and fpm and `figure_hello` is opened in a real window,
its frames captured and checked ([Verified platforms](install#verified-platforms-and-compilers)). What CI does not
show:

- **Input in a window:** the checked frames are drawn with the capture's scripted input, not the system's mouse and
  keyboard; typing, the clipboard and drops in a window are untried on macOS and Windows.
- **Windows' OpenGL:** the runner has no GPU, so CI renders with Mesa's software `opengl32.dll`; a vendor's driver
  is not exercised.

On WSL2, set `GALLIUM_DRIVER=d3d12`, or Mesa renders in software ([Installation](install#wsl2-wslg)).

## Intel ifx

Built and tested with ifx 2026.2 locally and with ifx 2026.1 in CI (`setup-fortran`'s newest Intel release, from
Intel's apt repository), on Linux only: ifx on Windows is untested (FIGURE's Windows build is MSYS2's MinGW, ifx
works with MSVC), and Intel ships no ifx for macOS.

- **`-fpscomp logicals`:** FIGURE's ifx modes compile with it, so that `.true.` passed to C is 1
  ([Intel ifx](install#intel-ifx)). fpm does not add it for ifx: pass `--flag "-fpscomp logicals"` to `fpm build`,
  `fpm test` or `fpm run`, also for a project that depends on FIGURE; without it ifx warns (#5472) and passes
  `.true.` as -1 to Dear ImGui.
- **The installer** does not take ifx ([below](#the-one-line-installer)): build with FoBiS (`figure-static-ifx`) or fpm.

## The window's frame drawn by FIGURE

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

## The file browser

FIGURE's file browser ([File dialogs](frame-loop#figure-s-file-browser)) is drawn by FIGURE, not by the system:

- **No desktop integration:** the system's bookmarks, network locations, thumbnails and search are not shown; the
  places are the home folder, the working directory, the roots and FIGURE's own recent folders.
- **A folder is read on the main thread** when it is entered or read again: a folder of very many entries on a slow
  network file system pauses the interface while it is read. It is not watched: a file written meanwhile appears
  after Refresh.
- **One settings file for every program:** the recent folders are shared by all the programs built with FIGURE.
- **Tab completion** is case-sensitive on every platform.

### File names on Windows

The browser lists and returns names in UTF-8 on every platform (it reads Windows' folders with the wide-character
API). gfortran's `open` on Windows passes the name to the C library in the system's code page, so a path with
non-ASCII characters returned by the browser may not open there; names in ASCII are not affected.

## The system's file dialogs on Linux

The system's dialogs (`app%open_file_dialog`, `save_file_dialog`, `open_folder_dialog`) are shown on Linux by the
desktop portal, another process reached over D-Bus, or by `zenity`. The portal draws on the user's desktop, not on the
program's display: a program in window mode with no display of its own (`DISPLAY` and `WAYLAND_DISPLAY` unset, SDL's
`offscreen` driver, a [capture](capture)) can still open a dialog on the desktop of the session it runs in. Tests and
recordings never click the system's dialogs; they drive [FIGURE's file browser](frame-loop#figure-s-file-browser),
which is drawn into the program's own frames. A program can ask for the browser through the same calls with
`prefer='figure'`.

## Processes

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

## Tasks

[Tasks](processes#tasks) run Fortran procedures on SDL threads:

- **nvfortran's I/O runtime is thread-safe only with `-mp`:** without it, Fortran I/O from two threads at once
  (formatted, list-directed, internal `write` to a string included) fails at random (`FIO-F-222 ... unbalanced
  parentheses in format string`) or crashes; compile the code a task runs, and the program, with `-mp` (OpenMP: FoBiS
  `openmp = True`). Measured with nvfortran 26.9: 8 tasks writing to strings fail in most runs without `-mp`, in none
  with it. gfortran's I/O is thread-safe with no flag.
- **Drawing from a task** is refused at FIGURE's container entry points only (the list is in
  [Tasks](processes#tasks)); a lone widget called from a task outside any container is not caught.
- **`recursive` procedures:** two tasks may run the same procedure at the same time; a procedure not declared
  `recursive` then stops a program built with gfortran's `-fcheck=recursion` (in `-fcheck=all`): declare the task's
  procedures `recursive`. FIGURE's entry points that refuse a task's drawing calls are `recursive` themselves, so the
  refusal happens in such a build too.
- **No preemption:** a task with no safe point (`h%cancelled()`) cannot be stopped; its object's end waits for it.

## 3-D views

[3-D views](view3d) are rendered on the CPU, into an image:

- **Remote mode, while the camera moves, shows JPEG images:** an image changing frame after frame goes as a JPEG
  (quality 75), so the browser shows its artefacts (blur around edges and grid lines, banding in smooth gradients)
  until the camera has been still for 150 ms, when the exact image replaces it. `init_remote(lossy=.false.)` sends
  every render exact: `4 * width * height` bytes, a quarter of that while moving, which an SSH tunnel to a cluster
  node cannot carry at more than a few renders a second ([Changing images](remote#changing-images)).
- **A slow link still limits the frame rate:** a 1600x1000 view zoomed in on a grid sends about 118 KB per JPEG, 7
  MB/s at 60 frames a second; below that FIGURE sends only the newest frame and image, fewer per second.
- **Large meshes:** above a million triangles a render takes tens of milliseconds (`threads=4` halves it), and the
  camera moves at that rate.
- **The image has the view's size in logical pixels:** on a display scaled 2x it is magnified.

## The one-line installer

What [the installer](install#the-one-line-installer) does not cover:

- **Windows:** it runs on Linux and macOS only. On Windows, build under MSYS2 UCRT64 by hand
  ([Other platforms](install#other-platforms)).
- **Compilers:** gfortran and nvfortran only; any other `--fc` (Intel ifx included) is refused. nvfortran itself is
  not installed: `--deps` installs only packages of the distribution (`apt-get`, `dnf`) or of Homebrew, and only
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

## First build needs the network

The native build downloads cimgui, cimplot, SDL3 and miniz (CMake `FetchContent`) the first time, and every FoBiS mode runs
it first (a few seconds when nothing changed).
