---
layout: home

hero:
  name: FIGURE
  text: Immediate-mode GUIs from Fortran
  tagline: Fortran Immediate-mode GUI for User interfaces, Rendering and Exploration. Dear ImGui widgets and ImPlot plots, declared every frame from ordinary Fortran variables, on SDL3 and OpenGL 3.
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

## Status

FIGURE is a spike: milestone M1 of the [roadmap](./guide/roadmap) is done on Linux, the API is small and unstable.
VERSION is the placeholder `0.0.0` and the licence is not decided yet.

## Quick start

<<< @/examples/snippets/tut01_window-loop.F90{fortran}

```bash
scripts/build_native.sh                                   # native layer into lib/ (once)
fobis build --mode examples-gnu && exe/figure_hello       # the example program
fobis build --mode tests-gnu && exe/figure_test_headless  # the headless test: no display needed
```

## Authors

- Stefano Zaghi — [@szaghi](https://github.com/szaghi)
