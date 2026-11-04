---
title: Known issues
---

# Known issues

## Unique labels

Dear ImGui identifies widgets by their label within a window: two widgets with the same label are one widget. Use
`'label##suffix'` to repeat a visible text ([Widgets](widgets#labels-and-identifiers)). Labels are passed verbatim,
trailing blanks included: pass `trim(...)` of a fixed-length buffer.

## Docking is disabled

The pinned cimgui tag `1.93dock` is, despite its name, generated from the non-docking Dear ImGui: its `cimgui.h` has
no `ImGuiConfigFlags_DockingEnable`. Docking windows into each other is therefore off. Enabling it needs a cimgui
commit generated from the docking branch, and possibly cimplot regenerated against it.

## nvfortran 26.9: internal compiler error on `size`

A local variable named `size` in one procedure and the intrinsic `size()` called in another procedure of the same
module make nvfortran 26.9 fail with "ILM file: can't find intrinsic size" (an internal compiler error). The code is
legal Fortran. FIGURE names such locals `extent`; avoid naming a local `size` in modules of your own built with
nvfortran 26.9 if you hit the same error.

## Text input

`igInputText` needs a C buffer and a resize callback; it is not bound. Numeric input (`ig_input`, `real64`) is.

## Synthetic input is internal

`fig_input_mouse`, used for [headless tests](testing), lives in the internal module `figure_c_native` and takes C
kinds.

## Platforms

Linux is built and tested locally; macOS and Windows only by CI (the `Platforms` workflow), and no window has been
opened on either yet: the headless tests need no display. On WSL2, set `GALLIUM_DRIVER=d3d12`, or Mesa renders in
software ([Installation](install#wsl2-wslg)).

## First build needs the network

The native build downloads cimgui, cimplot and SDL3 (CMake `FetchContent`) the first time, and every FoBiS mode runs
it first (a few seconds when nothing changed).
