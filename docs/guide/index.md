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

## Status

FIGURE is at milestone M1 of its [roadmap](roadmap): the build chain and a first set of widgets and plots, verified
on Linux (WSL2/WSLg, X11 and Wayland). The API is small and will change. VERSION is the placeholder `0.0.0`; the
licence is not decided yet.

What exists today:

- the application loop: a window, the frame loop, lazy redraw, headless mode for tests;
- widgets: windows, buttons, check boxes, sliders (`int32`, `real32`, `real64`), a numeric input, text, layout
  helpers, the Dear ImGui demo window;
- plots: line plots of `real(real64)` arrays, with axis labels.

The [feature map](features) lists every public procedure.

## What it is not, yet

macOS and Windows are target platforms but not yet built or tested (milestone M4); text input, images, heatmaps and
docking are not available (see [Known issues](known-issues) and the [roadmap](roadmap)).

## Where to start

1. [Install](install) the native layer and build the library.
2. Follow the [tutorial](/manual/): from a first window to a headless test.
3. Look up a task in the [cookbook](/manual/cookbook), a procedure in the [reference](features) or the
   [API](/api/).

## Authors

- Stefano Zaghi — [@szaghi](https://github.com/szaghi)
