---
title: About FIGURE
---

# About FIGURE

**FIGURE** (Fortran Immediate-mode GUI for User interfaces, Rendering and Exploration) is a Fortran library for
graphical user interfaces: control panels for a computation, live plots of its data, small interactive tools. It
binds [Dear ImGui](https://github.com/ocornut/imgui) and [ImPlot](https://github.com/epezent/implot), through their C
APIs [cimgui](https://github.com/cimgui/cimgui) and [cimplot](https://github.com/cimgui/cimplot), and runs them on
[SDL3](https://github.com/libsdl-org/SDL) and OpenGL 3.

A FIGURE program is one loop. Every iteration declares the whole interface; each widget call draws the widget and
returns what the user did with it during that frame:

<<< @/examples/snippets/tut01_window-loop.F90{fortran}

The state of the interface is the program's own variables: a slider is bound to a `real(real64)` by passing it, and
the slider writes the new value into it when the user drags. See [Why immediate mode](why) for what this changes with
respect to retained-mode toolkits.

<Media name="hello" video alt="figure_hello: a check box starts the animation, a slider changes the frequency of the plotted wave, a button counts clicks" caption="exe/figure_hello, the example of the repository" />

## Status

FIGURE is approaching its first release, v0.1.0: milestones M1 to M5 of the [roadmap](roadmap) are done, except the
WebAssembly experiment. The API is small and can still change.

What exists today:

- the application loop: a window, the frame loop, lazy redraw; headless mode for tests; remote mode, the interface
  in a web browser;
- widgets: windows, buttons, check boxes, sliders (`int32`, `real32`, `real64`), a numeric input, text, layout
  helpers, the Dear ImGui demo window;
- plots of `real(real32)` and `real(real64)` arrays, read in place: lines (also of matrix rows, with a stride),
  scatter, bars, shaded areas, with styles; heatmaps with their colour scale; images (`texture_object`), in a plot
  or as a widget;
- every Dear ImGui and ImPlot function through the generated [raw bindings](raw-bindings);
- CI on Linux, macOS and Windows with gfortran, on Linux with nvfortran; builds with FoBiS and fpm.

The [feature map](features) lists every public procedure.

## What it is not, yet

Text input and multiple viewports are not available, and only part of Dear ImGui's widgets have a Fortran
wrapper (the rest are reachable through the raw bindings). See [Known issues](known-issues) and the
[roadmap](roadmap).

## Where to start

1. [Install](install) the native layer and build the library.
2. Follow the [tutorial](/manual/): from a first window to a headless test.
3. Look up a task in the [cookbook](/manual/cookbook), a procedure in the [reference](features) or the
   [API](/api/).

## Licence

FIGURE is released under the [MIT licence](https://github.com/szaghi/figure/blob/main/LICENSE.mit.md). It compiles
Dear ImGui, ImPlot, cimgui, cimplot and miniz (MIT) and SDL3 (zlib) into its native libraries, and embeds the IBM Plex Sans
font (OFL-1.1);
[THIRD_PARTY.md](https://github.com/szaghi/figure/blob/main/THIRD_PARTY.md) lists them, with what a program built
with FIGURE must carry when it is distributed (the MIT notices; the native build installs them under
`share/licenses/`).

## Authors

- Stefano Zaghi — [@szaghi](https://github.com/szaghi)
