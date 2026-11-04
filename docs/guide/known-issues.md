---
title: Known issues
---

# Known issues

## Unique labels

Dear ImGui identifies widgets by their label within a window: two widgets with the same label are one widget. Use
`'label##suffix'` to repeat a visible text ([Widgets](widgets#labels-and-identifiers)). Labels are passed verbatim,
trailing blanks included: pass `trim(...)` of a fixed-length buffer.

## Docking is not enabled yet

FIGURE is built from Dear ImGui's docking branch (cimgui `1.93.1WIPdock`), and the docking functions and constants
are in the [raw bindings](raw-bindings) (`igDockSpace`, `igSetNextWindowDockID`, `ImGuiDockNodeFlags_*`, ...).
Docking itself is still off: the switch to enable it, and a Fortran API, are step S2 of the [roadmap](roadmap).
Multi-viewports (windows dragged out of the main window) are not planned: remote and headless modes cannot support
them.

The cimgui tag `1.93dock`, pinned before, was generated from Dear ImGui's master branch despite its name (its
`imgui` submodule points to master): it had no docking at all.

## nvfortran 26.9: internal compiler error on `size`

A local variable named `size` in one procedure and the intrinsic `size()` called in another procedure of the same
module make nvfortran 26.9 fail with "ILM file: can't find intrinsic size" (an internal compiler error). The code is
legal Fortran. FIGURE names such locals `extent`; avoid naming a local `size` in modules of your own built with
nvfortran 26.9 if you hit the same error.

## Text input

`igInputText` needs a C buffer and a resize callback; it is not bound. Numeric input (`ig_input`, `real64`) is.

## Synthetic input is internal

`fig_input_mouse`, used for [headless tests](testing), lives in the internal module `figure_c_native` and takes C
kinds. A public testing module is planned for v0.1.0 (step S10 of the [roadmap](roadmap)).

## A name shared with fortplot

`lazy-fortran/fortplot` has a public procedure named `figure`. A program that uses both libraries cannot have the
module `figure` and that procedure under the same name in one scope: rename one on import, for example
`use fortplot, only : fp_figure => figure`.

## Platforms

Linux is built and tested locally; macOS (arm64) and Windows (MSYS2 UCRT64) are built and tested by CI (the
`Platforms` workflow), where the headless tests pass with FoBiS and fpm. No window has been opened on either yet: the
tests need no display, and the windowed path (SDL video, the OpenGL context, the GL loader) is unverified there. On WSL2, set `GALLIUM_DRIVER=d3d12`, or Mesa renders in
software ([Installation](install#wsl2-wslg)).

## First build needs the network

The native build downloads cimgui, cimplot and SDL3 (CMake `FetchContent`) the first time, and every FoBiS mode runs
it first (a few seconds when nothing changed).
