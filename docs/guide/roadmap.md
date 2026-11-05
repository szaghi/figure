---
title: Roadmap
---

# Roadmap

The plan to the first release, v0.1.0, is tracked step by step in
[issue #1](https://github.com/szaghi/figure/issues/1): each step with its tasks, its checks, the documentation and the
pictures it updates, and a log of the work. This page summarises it, after the milestones already done.

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
  (`src/examples/figure_bench_texture.F90`): about 100 frames/s with a new 3840 x 2160 image every frame
  ([measurements](images#speed-a-new-4k-image-every-frame)).

## M4: platforms and CI — done

- GitHub Actions: `ci.yml` (Linux, gfortran, coverage, from the FoBiS scaffold) and `platforms.yml`: macOS (gfortran
  and Apple clang), Windows (MSYS2 UCRT64 gfortran), Linux with nvfortran. Each builds the native layer, checks the
  platform's link line against SDL's, builds and runs the headless tests with FoBiS and fpm, and builds the examples.
- Green on all four (2026-11-04): Linux gfortran (with coverage), Linux nvfortran, macOS 14 arm64, Windows MSYS2
  UCRT64; on macOS and Windows the headless and layout tests also pass through fpm, so the generated glue passes and
  returns structs correctly on those ABIs.
- Platform link lines in fobos varsets (`--varset macos|windows`), checked against `lib/pkgconfig/sdl3.pc`; fpm reads
  them through `scripts/fpm.sh` ([Other platforms](install#other-platforms)).

## M5: remote and web — remote done, WebAssembly to try

- Remote UI: done ([Remote UI](remote)). `app%init_remote` serves the interface to a web browser over a built-in
  WebSocket server; the program needs no display or GPU and stays native (OpenMP, MPI, GPU), e.g. on a cluster node
  reached through an SSH tunnel. Tested end to end on every CI platform.
- Experiment, **deferred**: the whole application compiled to WebAssembly with a patched flang and Emscripten SDL3
  (no OpenMP, no MPI there).

## Documentation with real pictures — done

- Frame capture with scripted input (`FIGURE_CAPTURE`, [Screenshots and videos](capture)); every picture of this
  site is a recording of the program it describes, made by `scripts/docs_media.py`.
- Found by the pictures: a growing history ran off its plot; `ip_setup_axes(..., auto_fit)` refits the axes every
  frame.
- The brand: the seal mark (a window and its plot drafted with a brush, signed with a vermilion seal carved with F),
  the site's palette, and `app%set_style` with `seal` as FIGURE's default [style](styles).

## v0.1.0 — in progress

The scope of the first release, step by step in [issue #1](https://github.com/szaghi/figure/issues/1):

- **Licence:** MIT; the third-party notices: done.
- **Docking:** the docking branch of Dear ImGui; windows dock into one another as tabs and splits, and programs set
  layouts ([Docking](docking)): done.
- **Themes, fully customisable** ([Styles](styles)): done.
  - every colour and size of Dear ImGui and ImPlot from Fortran;
  - themes as files, embedded, with a curated set (`seal`, `seal-light`, `paper`, `high-contrast`, colour-blind-safe
    line colours);
  - `load_style` and `save_style`;
  - fonts, with a bundled default;
  - window flags and scoped style changes;
  - a recorded theme gallery.
- **Testing:** a public testing module for synthetic input ([Headless testing](testing)): done.
- **Performance:** the cost of continuous redraw measured locally and in remote mode (`scripts/measure_redraw.py`);
  remote frames skipped when unchanged, capped at 60 per second with one frame at most queued, sent with 12-byte
  vertices and deflated when the link is the bottleneck; the [Performance](performance) guide: done.
- **Remote security:** an access token in the URL, random by default ([Remote UI](remote#access-token)): done.
- **fpm:** FIGURE usable as a dependency of other fpm projects: a self-contained package (fpm compiles the native
  layer itself, SDL3 from the system), published for each release as the tag `vX.Y.Z-fpm`
  ([FIGURE as an fpm dependency](install#figure-as-an-fpm-dependency)): done, first published with v0.1.0.
- **Documentation:** every page checked against the code, every recording regenerated, the changelog, the README: in
  progress.
- **Release v0.1.0:** the tag, the GitHub release, the `v0.1.0-fpm` package.
