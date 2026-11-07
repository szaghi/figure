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

`ig_input_text` edits a `character` variable, whose length is the field's capacity: a longer text is cut at it.
Multi-line text (`igInputTextMultiline`) has no wrapper yet.

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

## First build needs the network

The native build downloads cimgui, cimplot, SDL3 and miniz (CMake `FetchContent`) the first time, and every FoBiS mode runs
it first (a few seconds when nothing changed).
