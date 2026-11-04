---
title: Roadmap
---

# Roadmap

The milestones of `plans/plan.md`. Only M1 is done; everything after it is planned, not available.

## M1: build chain and first widgets — done on Linux

- Native layer: CMake, pinned sources, static `libfigure_native.a` and `libSDL3.a`.
- Fortran: `figure_app` (loop, lazy redraw), `figure_imgui` (windows, button, check box, sliders for `int32`,
  `real32`, `real64`, numeric input, text, same line, separator, demo window, window placement, item rectangle),
  `figure_implot` (plot, axes, line).
- Headless test (button click, check box toggle, plot) passing with gfortran 16.2 (release and `-fcheck=all`),
  nvfortran 26.9 and fpm.
- FoBiS modes (tests, examples, static library; gnu and nvfortran) and `fpm.toml` in sync.
- `figure_hello` running in a window on Linux (WSLg), X11 and Wayland.
- Idle cost of lazy redraw measured and explained ([Frame loop](frame-loop#what-idle-costs)); default `max_wait`
  kept at 0.5 s.

## M2: generated raw layer — done

- `scripts/gen_bindings.py` generates the `bind(C)` interfaces and the enumeration parameters from cimgui's and
  cimplot's metadata (`definitions.json`, `structs_and_enums.json`) and classifies every public function as direct,
  glue or skipped ([Raw bindings](raw-bindings)). Enumeration values are generated, never copied by hand.
- The output is committed; CI checks it for drift and checks that every bound function is defined in the native
  library (`fobis rule --ex makecoverage`).
- The C++ glue for the functions that pass structs by value (above all the ImPlot items, `ImPlotSpec`) is generated
  too, with `bind(C)` mirror types for the structs, size-checked by `figure_test_layout`.

## M3: images and speed — done

- Textures from contiguous `integer(int8)` RGBA arrays, uploaded without intermediate copies: done
  (`texture_object`, `ig_image`, `ip_image`).
- ImPlot heatmaps from Fortran 2D arrays (column-major aware): done (`ip_heatmap`, read in place, j = 1 at the
  bottom; `ip_colormap_scale`).
- Plot items generic over `real32` and `real64`, so `real32` data is never copied into a `real64` temporary: done
  for `ip_line`, `ip_scatter`, `ip_bars` and `ip_shaded`, with item styles (`ip_spec`).
- Strided series (matrix rows) passed as base address and stride, without the compiler's temporary copy: done for
  `ip_line(label, y, row)` with uniform abscissae (ImPlot applies one stride to x and y, so a contiguous x cannot go
  with a strided row).
- A Mandelbrot explorer (`src/examples/figure_mandelbrot.F90`) and a redraw benchmark at 4K
  (`src/examples/figure_bench_texture.F90`): about 100 frames/s with a new 3840 x 2160 image every frame, about 10x
  wxFortran on the same loop ([measurements](images#speed-a-new-4k-image-every-frame)).

## M4: platforms and CI — written, awaiting its first runs

- GitHub Actions: `ci.yml` (Linux, gfortran, coverage, from the FoBiS scaffold) and `platforms.yml`: macOS (gfortran
  and Apple clang), Windows (MSYS2 UCRT64 gfortran), Linux with nvfortran. Each builds the native layer, checks the
  platform's link line against SDL's, builds and runs the headless tests with FoBiS and fpm, and builds the examples.
- Platform link lines in fobos varsets (`--varset macos|windows`), checked against `lib/pkgconfig/sdl3.pc`; fpm reads
  them through `scripts/fpm.sh` ([Other platforms](install#other-platforms)).

## M5: remote and web — planned

- Remote UI: Dear ImGui draw lists streamed over WebSocket to a browser, the Fortran program staying native (OpenMP,
  MPI, GPU), for example a GUI for a cluster run.
- Experiment: the whole application compiled to WebAssembly with a patched flang and Emscripten SDL3 (no OpenMP, no
  MPI there).

## Open decisions

- Docking: needs a cimgui generated from the docking branch ([Known issues](known-issues#docking-is-disabled)).
- Version and licence: VERSION is the placeholder `0.0.0`, the licence is undecided.
