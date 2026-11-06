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

FIGURE v0.1.0 is released; v0.2.0 is in progress ([roadmap](roadmap)), driven by its first application outside this
repository, tools for a CFD solver ([showcase](showcase)). The API can still change.

What exists today:

- the application loop: a window, the frame loop, lazy redraw; headless mode for tests; remote mode, the interface
  in a web browser; the window's title, a confirmation before quitting;
- widgets: windows, buttons, check boxes, sliders (`int32`, `real32`, `real64`), numeric fields, text fields bound to
  `character` variables, drop-down lists, tooltips, selectable lines, wrapped and coloured text, child regions,
  collapsing headers, tabs, tables, disabled blocks, the Dear ImGui demo window;
- menus (the main menu bar, a window's), keyboard shortcuts (cmd on macOS), popups and modals; the system's file
  dialogs;
- docking: dock spaces, layouts set by the program, windows that appear later; the user's arrangement saved to a file
  and loaded back while the program runs;
- styles: seven built-in themes, every colour and size by name, theme files, fonts (bundled or from a file) and their
  size, changed at run time;
- plots of `real(real32)` and `real(real64)` arrays, read in place: lines (also of matrix rows, with a stride),
  scatter, bars, shaded areas, with styles; logarithmic axes, tick label formats, subplots with linked axes; heatmaps
  with their colour scale; images (`texture_object`), in a plot or as a widget;
- pictures: a rectangle of the window saved as a PNG by the program; every frame recorded, with scripted input, for
  documentation;
- headless testing with synthetic input (`figure_testing`, in the library);
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
font (OFL-1.1) and the Lucide icons (ISC);
[THIRD_PARTY.md](https://github.com/szaghi/figure/blob/main/THIRD_PARTY.md) lists them, with what a program built
with FIGURE must carry when it is distributed (the MIT notices; the native build installs them under
`share/licenses/`).

## Authors

- Stefano Zaghi — [@szaghi](https://github.com/szaghi)
