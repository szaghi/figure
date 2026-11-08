---
layout: home

hero:
  name: FIGURE
  text: Immediate-mode GUIs from Fortran
  tagline: Fortran Immediate-mode GUI for User interfaces, Rendering and Exploration. Dear ImGui widgets and ImPlot plots, declared every frame from ordinary Fortran variables, on SDL3 and OpenGL 3.
  image:
    light: /logo.svg
    dark: /logo-dark.svg
    alt: the FIGURE logo, a window and its plot drafted with a brush, signed with a vermilion seal carved with an F
  actions:
    - theme: brand
      text: Tutorial
      link: /manual/tutorial/01-first-window
    - theme: alt
      text: Install
      link: /guide/install
    - theme: alt
      text: Reference
      link: /guide/features
    - theme: alt
      text: API
      link: /api/
    - theme: alt
      text: View on GitHub
      link: https://github.com/szaghi/figure

features:
  - title: Immediate mode
    details: The UI is a block of code run every frame. A widget call draws the widget and returns what the user did with it this frame; there is no widget tree to build, update or tear down.
    link: /guide/why
    linkText: Why immediate mode
  - title: No handles, no callbacks, no target
    details: Widget values are your own variables, updated in place. Nothing is registered, nothing is stored across calls, and no actual argument needs the target attribute.
    link: /guide/widgets
    linkText: Widgets
  - title: Plots of Fortran arrays
    details: Lines, scatter, bars, shaded areas, heatmaps and GPU textures, read from real32 or real64 arrays in place, without copies.
    link: /guide/plots
    linkText: Plots
  - title: Lazy redraw
    details: Once the UI settles, the loop sleeps until input arrives or a refresh period elapses; request_frames keeps it drawing while a computation advances.
    link: /guide/frame-loop
    linkText: The frame loop
  - title: In a web browser
    details: init_remote serves the same interface to a browser, behind an access token. No display or GPU on the program's side, a cluster node through an SSH tunnel; unchanged frames are not sent.
    link: /guide/remote
    linkText: Remote UI
  - title: Forms, menus and dialogs
    details: Text and numeric fields bound to your variables, drop-down lists, tables, tabs; menu bars and keyboard shortcuts; popups, modals and the system's file dialogs.
    link: /guide/menus
    linkText: Menus and popups
  - title: Docking and themes
    details: Windows dock into one another as tabs and splits, layouts saved and loaded at run time. Seven built-in styles, every colour and size by name, theme files, fonts.
    link: /guide/styles
    linkText: Styles
  - title: Built with it
    details: Tools for a CFD solver, a run checker following hundreds of history files and two input editors, each in a window or a browser.
    link: /guide/showcase
    linkText: Showcase
  - title: Headless tests
    details: init_headless creates the contexts without a window or a GPU; the figure_testing module clicks, drags and types frame by frame, so UI logic is tested in CI as is.
    link: /guide/testing
    linkText: Headless testing
  - title: FoBiS and fpm
    details: Fortran calls C only, through bind(C). The native layer is built by CMake for FoBiS, or compiled by fpm itself from the package each release publishes (vX.Y.Z-fpm).
    link: /guide/install
    linkText: Install
---

## See it running

<Media name="hello" video alt="figure_hello: a check box starts the animation, a slider changes the frequency of the plotted wave, a button counts clicks" caption="exe/examples/figure_hello: a check box, a slider and a button bound to Fortran variables, and a plot of a Fortran array" />

<div class="fig-gallery">
<Media name="mandelbrot" video alt="The Mandelbrot explorer zooming about 175 times into the seahorse valley" caption="An explorer: ImPlot zooms, Fortran computes the image, a texture shows it" />
<Media name="tut04_live" video alt="A Jacobi iteration converging while its solution and residual history are plotted" caption="A live computation: the solver runs inside the frame loop" />
<Media name="cb_items" alt="One plot with a shaded band, a line, markers, bars and an area to zero" caption="Lines, scatter, bars and shaded areas in one plot" />
<Media name="remote" alt="The same interface drawn by a web browser at localhost:8080" caption="Remote mode: the program on a cluster node, the UI in a browser" />
<Media name="gallery-cycle" video alt="One program switching through the seven built-in styles" caption="Seven built-in styles, or a theme file of your own" />
<Media name="cb_dock" video alt="A window dragged by its title bar docks as a tab" caption="Docking: the user rearranges the windows" />
</div>

Every picture on this site is a recording of the program it describes, made by `scripts/docs_media.py`: the frames
are the program's own back buffer, captured with `FIGURE_CAPTURE` and driven by a scripted mouse, in FIGURE's default
[style](./guide/styles), `seal`.

## Status

FIGURE v0.2.0 is released (2026-11-06). It grew from its first application outside this repository, tools for a CFD
solver ([showcase](./guide/showcase)): forms, menus and dialogs, docking layouts, icons and workspace toolbars, plots
for live checks. CI runs on Linux, macOS and Windows with gfortran and on Linux with nvfortran and Intel ifx, and
opens a real window on the three systems. The API can still change before v1.0 ([roadmap](./guide/roadmap)). FIGURE
is released under the MIT licence.

## Quick start

<<< @/examples/snippets/tut01_window-loop.F90{fortran}

```bash
scripts/build_native.sh                                       # native layer into lib/ (once)
fobis build --mode examples-gnu && exe/examples/figure_hello  # the example program
fobis build --mode tests-gnu && exe/figure_test_headless      # the headless test: no display needed
```

## Authors

- Stefano Zaghi — [@szaghi](https://github.com/szaghi)
