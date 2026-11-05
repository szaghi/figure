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
    details: ip_line passes real(real64) arrays straight to ImPlot as double*, without copies, for contiguous data.
    link: /guide/plots
    linkText: Plots
  - title: Lazy redraw
    details: Once the UI settles, the loop sleeps until input arrives or a refresh period elapses; request_frames keeps it drawing while a computation advances.
    link: /guide/frame-loop
    linkText: The frame loop
  - title: Headless tests
    details: init_headless creates the contexts without a window or a GPU; synthetic mouse input clicks buttons frame by frame, so UI logic is tested in CI as is.
    link: /guide/testing
    linkText: Headless testing
  - title: C ABI end to end
    details: Fortran calls C functions only, cimgui, cimplot and a small glue layer, through bind(C) interfaces. No C++ ABI crosses the language boundary.
    link: /guide/architecture
    linkText: Architecture
  - title: FoBiS and fpm
    details: A static native layer built once by CMake; the Fortran library built by FoBiS (primary) or fpm, kept in sync by a check script.
    link: /guide/install
    linkText: Install
---

## See it running

<Media name="hello" video alt="figure_hello: a check box starts the animation, a slider changes the frequency of the plotted wave, a button counts clicks" caption="exe/figure_hello: a check box, a slider and a button bound to Fortran variables, and a plot of a Fortran array" />

<div class="fig-gallery">
<Media name="mandelbrot" video alt="The Mandelbrot explorer zooming about 175 times into the seahorse valley" caption="An explorer: ImPlot zooms, Fortran computes the image, a texture shows it" />
<Media name="tut04_live" video alt="A Jacobi iteration converging while its solution and residual history are plotted" caption="A live computation: the solver runs inside the frame loop" />
<Media name="cb_items" alt="One plot with a shaded band, a line, markers, bars and an area to zero" caption="Lines, scatter, bars and shaded areas in one plot" />
<Media name="remote" alt="The same interface drawn by a web browser at localhost:8080" caption="Remote mode: the program on a cluster node, the UI in a browser" />
</div>

Every picture on this site is a recording of the program it describes, made by `scripts/docs_media.py`: the frames
are the program's own back buffer, captured with `FIGURE_CAPTURE` and driven by a scripted mouse, in FIGURE's default
[style](./guide/styles), `seal`.

## Status

FIGURE is approaching its first release, v0.1.0. The milestones M1 to M5 of the [roadmap](./guide/roadmap) are done
except the WebAssembly experiment: widgets, plots, heatmaps and textures, remote mode, CI on Linux, macOS and Windows
with gfortran and on Linux with nvfortran. The API is small and can still change. FIGURE is released under the MIT licence.

## Quick start

<<< @/examples/snippets/tut01_window-loop.F90{fortran}

```bash
scripts/build_native.sh                                   # native layer into lib/ (once)
fobis build --mode examples-gnu && exe/figure_hello       # the example program
fobis build --mode tests-gnu && exe/figure_test_headless  # the headless test: no display needed
```

## Authors

- Stefano Zaghi — [@szaghi](https://github.com/szaghi)
