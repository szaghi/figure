# FIGURE: plan

## Design decisions

| Topic | Decision |
|---|---|
| Paradigm | Immediate mode (Dear ImGui + ImPlot). No widget objects, handle tables, lifetime contracts or callbacks: the cost centre of retained-mode bindings (wxFortran, gtk-fortran, qt-fortran) does not exist. |
| Boundary | C ABI only. cimgui/cimplot functions whose arguments are scalars, pointers or `ImVec2_c` are bound directly (`figure_c_native`); functions taking larger structs by value (e.g. `ImPlotSpec_c`) go through the glue (`native/figure_native.cpp`). |
| Platform | SDL3 (window, input, clipboard, high DPI, native file dialogs via XDG portals) + OpenGL 3. GL calls of the glue are loaded through SDL: no link dependency on libGL/opengl32. |
| Builds | Native layer: CMake (`scripts/build_native.sh`), static, pinned versions. Fortran: FoBiS primary, fpm mirrored; neither compiles C++. `scripts/check_sync.py` keeps them aligned. |
| Redraw | Lazy by default: sleep until input or `max_wait`; `app%request_frames(n)` for animation and live data. |
| Testing | Headless contexts (no window, no GPU) driven by synthetic input, frame by frame: runs in CI without Xvfb. |

Pinned set (a matched triple, verified to compile with g++ 16.2): cimgui `1.93dock` (Dear ImGui v1.93.0), cimplot
`v1.1` (ImPlot 1.2 WIP, generated against that cimgui), SDL `release-3.4.20`.

## Milestones

### M1: spike: build chain and first widgets: **done on Linux (X11 via WSLg)**
- [x] Native layer: CMake, pinned FetchContent, static libfigure_native.a + libSDL3.a.
- [x] Fortran: `figure_app` (loop, lazy redraw), `figure_imgui` (begin/end, button, checkbox, slider i32/r32/r64,
      input, text, same line, separator, demo window, next-window placement, item rect), `figure_implot` (plot,
      axes, line).
- [x] Headless test (button click, checkbox toggle, plot) passes: gfortran 16.2 (release and -fcheck=all),
      nvfortran 26.9, fpm.
- [x] FoBiS modes (tests/examples/static, gnu and nvf) and fpm.toml in sync (`fobis rule --ex sync`).
- [x] `figure_hello` runs in a window on Linux (WSLg, SDL3 X11 driver): widgets and ImPlot render correctly.
- [x] Native layer rebuilt with Wayland and DBus (2026-11-04); the full FoBiS/fpm test matrix passes on it.
- [x] Idle CPU with lazy redraw, explained (2026-11-04, WSLg, `GALLIUM_DRIVER=d3d12`). The 2.6% measured first was
      software rendering (llvmpipe). `FIGURE_DEBUG_REDRAW=1` shows exactly 2 frames/s idle, every one ended by the
      `max_wait` timeout, no spurious events after startup (X11 and Wayland); per frame, UI build + render < 1 ms
      and swap 3-8 ms wall time. Idle CPU of a one-window program, 60 s samples (`scripts/measure_idle.py`):
      `max_wait` 0.5 s: 0.37%, 2 s: 0.15%, 5 s: 0.13% of one core, i.e. ~1.5 ms CPU per idle frame on a
      ~0.08% floor; `figure_hello` 0.40%; lazy redraw off (vsync, 60 frames/s): 37%. **Default `max_wait` kept
      at 0.5 s**: raising it saves ~0.2% of one core and makes un-signalled live data refresh 4x slower.

### M2: generated raw layer: **done (2026-11-04), glue for struct-by-value functions to do**
- `scripts/gen_bindings.py` writes `src/lib/figure_cim{gui,plot}{,_enums}.F90` and `docs/guide/raw-bindings.md`.
  cimgui: 354 direct, 10 glue, 49 skipped (variadic, callbacks) of 413 public functions; cimplot: 96 / 278 / 27 of 401
  (the 278 are mostly the ImPlot items, `ImPlotSpec` by value). `--check` and `--check-symbols` run in CI
  (`makecoverage`): drift, and every bound name defined in `libfigure_native.a`.
- Original spec: generate `figure_c_native`-style interfaces and enum parameters from cimgui/cimplot `definitions.json` and
  `structs_and_enums.json`; classify each function: direct bind(C) or glue. Enum values generated, never hand-copied.
- Generator output committed and checked for drift in CI.

### M3: images and speed
- Textures from contiguous `integer(c_int8_t)` RGBA arrays: one `glTexSubImage2D` upload, no intermediate copies.
- ImPlot heatmaps from Fortran 2D arrays (column-major aware).
- Plot items generic over `real32`/`real64` (ImPlot is templated on the element type): one glue instantiation per
  kind, so `real32` data is never copied into a `real64` temporary.
- Strided series: the `contiguous` dummies make the compiler copy a matrix row `y(i,:)` into a temporary; ImPlot
  takes a byte stride, so pass base address + stride instead (portable stride from Fortran to be designed).
- Port a Mandelbrot explorer and a live plot; benchmark redraw at 4K against wxFortran.

### M4: platforms and CI
- GitHub Actions: Linux (gfortran, nvfortran headless), macOS (gfortran + clang), Windows (MSYS2 MinGW gfortran).
- `check_sync.py` and both builds (FoBiS, fpm) in CI.

### M5: remote and web
- Remote UI: stream ImGui draw lists over WebSocket to a browser (imgui-ws approach), Fortran stays native (OpenMP,
  MPI, GPU); e.g. a GUI for a cluster run.
- Experiment: whole app to WebAssembly with a patched flang (flang-wasm) + Emscripten SDL3; no OpenMP/MPI there.

## Open issues

- **Docking:** cimgui tag `1.93dock` is generated from the *non-docking* Dear ImGui (its `cimgui.h` has no
  `ImGuiConfigFlags_DockingEnable`), so docking is off. Pick a cimgui commit generated from the docking branch, and
  regenerate cimplot against it if needed.
- **nvfortran 26.9 ICE:** a local variable named `size` in one procedure plus the intrinsic `size()` in another
  procedure of the same module: "ILM file: can't find intrinsic size", internal compiler error. Legal Fortran;
  avoided by naming the locals `extent`. Worth a reduced reproducer to NVIDIA.
- **Name check (2026-11-04):** no Fortran project named "figure" on GitHub (`gh search repos`), in the
  fortran-lang.org package index (212 entries) or the legacy fpm-registry index (42); no Dear ImGui binding for
  Fortran found at all. `szaghi/figure` is the owner's own (private, empty, created 2026-11-04). Near names:
  `lazy-fortran/fortplot`, whose public procedure `figure(...)` would clash with `use figure` in the same scope
  (rename on import); `AnonMiraj/fig` (vector graphics). The new fpm registry API was down: unchecked.
- **VERSION** is a placeholder (0.0.0) and the **licence** is undecided (fpm.toml says TBD): both are the author's call.
- SDL3 enables Wayland and DBus only when their development packages are present at configure time
  (`libxkbcommon-dev`, `libegl-dev`, `libdbus-1-dev`; see *Platform setup*): without them it silently builds X11
  only, and without DBus there are no XDG-portal file dialogs. On the WSL box they are installed since 2026-11-04
  and the native layer builds with video drivers `wayland x11` and DBus ON.
- **WSLg (checked 2026-11-04, SDL 3.4.20, Mesa 25.2.8, RTX 4070):** SDL3 picks **X11** by default;
  `SDL_VIDEO_DRIVER=wayland` also works (Mesa EGL prints harmless "failed to get driver name for fd -1" warnings).
  Mesa renders in **software (llvmpipe)** on either driver unless `GALLIUM_DRIVER=d3d12` is set (documented in
  the README; not set by FIGURE). Idle `figure_hello`, 10 s samples after 4 s warm-up:

  | Renderer | X11 | Wayland |
  |---|---|---|
  | llvmpipe (default) | 5.3%, 6.0% | 2.4% |
  | d3d12 (`GALLIUM_DRIVER=d3d12`) | 0.8%, 0.8%, 0.7% | 0.9% |

  (10 s samples resolve only 0.1% and include the startup tail; the 60 s figures under M1 are the reliable ones.)

  Rendering on d3d12 checked by screenshot (`import -window "FIGURE: hello"`): widgets and plot correct.

## Platform setup

Ubuntu 24.04 (SDL3 build dependencies for X11, Wayland and the DBus file-dialog portal):

```sh
sudo apt install libxext-dev libxrandr-dev libxcursor-dev libxi-dev libxfixes-dev libxss-dev libxtst-dev \
                 libwayland-dev libxkbcommon-dev libegl-dev libdbus-1-dev libdecor-0-dev
```
