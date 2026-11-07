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
- **Untested:** drops and the system clipboard in a window on macOS and Windows have not been tried (no window is
  opened there yet, see [Platforms](#platforms)); the tests check the remote clipboard's messages with a client of
  their own, not a browser's permissions.

## A name shared with fortplot

`lazy-fortran/fortplot` has a public procedure named `figure`. A program that uses both libraries cannot have the
module `figure` and that procedure under the same name in one scope: rename one on import, for example
`use fortplot, only : fp_figure => figure`.

## Platforms

Linux is built and tested locally; macOS (arm64) and Windows (MSYS2 UCRT64) are built and tested by CI (the
`Platforms` workflow), where the headless tests pass with FoBiS and fpm. No window has been opened on either yet: the
tests need no display, and the windowed path (SDL video, the OpenGL context, the GL loader) is unverified there. On WSL2, set `GALLIUM_DRIVER=d3d12`, or Mesa renders in
software ([Installation](install#wsl2-wslg)).

## The window's frame drawn by FIGURE

With `decorations='figure'` ([Frame loop](frame-loop#the-window-s-frame)) the system draws no frame, and what its
frame does beyond moving, resizing and the three buttons is lost:

- **Windows 11's snap layouts** (the layout menu shown when the pointer rests on the maximize button) do not appear:
  Windows shows them only for a system frame or a maximize button it can identify (`HTMAXBUTTON`), and SDL's hit test
  cannot report one. Whether snapping by dragging the window to a screen edge still works is to be checked on
  Windows (S11).
- **macOS's full-screen button:** the bar's buttons are close, minimize and maximize (zoom); there is no green
  full-screen button, and the traffic-light colours are not used (the palette's are).
- **Window menu:** the system's window menu (right-click on the title bar, Alt + Space on Windows) is not shown.
- **Linux:** under X11 and Wayland the window manager moves and resizes the window through SDL; a double-click on the
  bar is FIGURE's own, at Dear ImGui's double-click time. Under WSLg the frame is FIGURE's alone, which is the point
  of the option there.
- **A window over the bar:** a floating Dear ImGui window dragged over the title bar is drawn above it, but the hit
  test still treats the bar's empty part as the drag area. Dock spaces and side bars start below the bar.

The windowed path on each platform is to be verified by the windowed CI runs (issue #3, S11).

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
