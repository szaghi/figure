# HANDOFF 2026-11-04: FIGURE spike (milestone M1)

The session ended because Stefano is restarting WSL (driver update). Nothing is committed: the whole repo is
untracked on `master` (git init only). **Do not commit unless Stefano asks.** Per CLAUDE.md, commit messages carry no
AI co-author trailer.

## 1. What FIGURE is and why it exists

**FIGURE** stands for **F**ortran **I**mmediate-mode **G**UI for **U**ser interfaces, **R**endering and
**E**xploration. Stefano chose the name. The repo is `~/fortran/figure`.

It is a Fortran GUI library built on Dear ImGui + ImPlot (through the C APIs cimgui and cimplot) over SDL3 + OpenGL 3.
Its requirements:
- **Mandatory platforms:** macOS, Windows and GNU/Linux. Web support is desirable.
- **Speed** matters.
- **Builds:** both FoBiS and fpm must be supported and kept in sync. FoBiS is the primary one.
- **Independence:** the project is independent of Jacob Williams' work. Stefano may share it with him later, once it
  is usable.

### Origin: the audit of wxFortran

FIGURE came out of an audit of Jacob Williams' `wxFortran` (https://github.com/jacobwilliams/wxFortran), which wraps
wxWidgets through a C++ shim of opaque handles. The audit is not saved anywhere else, so these are the findings that
drove the design:

1. **Windows is unsupported, and the cause is structural.** wxWidgets has a C++ ABI: conda-forge builds it with
   MSVC, and MinGW gfortran cannot link that. Any toolkit with a C++ public API (wx, Qt, FLTK) repeats the problem.
2. **`bind(..., data=x)` stores a pointer to a dummy argument that has the `target` attribute.** If the actual
   argument has no `target`, the pointer becomes undefined after the call. This is undefined behaviour that nothing
   can detect.
3. **The pixel path makes about 6 copies per frame.** It starts from `integer rgb(3,w,h)` (12 bytes per pixel), then
   makes the reshape, min/max and merge temporaries and the int8 array, then the `wxImage`, the `wxBitmap` and the GC
   bitmap.
4. **Event, status and modifier enums are duplicated by hand** in C++ and in Fortran, so they can drift apart.
5. **About half of the shim is retained-mode lifetime bookkeeping:** the handle table, trackers, ownership and slot
   release. Retained-mode toolkits force this on Fortran, because Fortran has no closures and no RAII.

The conclusion was to change the paradigm, not just the toolkit. Immediate mode removes items 2, 4 (once the bindings
are generated) and 5. Items 1 and 3 are addressed by a C ABI end to end and by uploading textures directly.

**Alternatives that were considered:**
- Second choice: `webview/webview`, an HTML front end over a C ABI. It was rejected on speed, because data crosses as
  JSON.
- Rejected outright: Slint, Flutter, FLTK, Nuklear and raygui.

**Web strategy.** There are two routes; details are in M5 of the plan.
- **Remote:** stream ImGui draw lists over WebSocket. This is the imgui-ws approach (https://github.com/ezhangle/imgui-ws),
  and the project looks quiet.
- **WebAssembly:** compile with a patched flang (https://github.com/r-wasm/flang-wasm). Upstream flang has no
  wasm32 support yet, and this route has no OpenMP and no MPI.

## 2. Where things are

**Read first:** `plans/plan.md` has the design decisions, the pinned versions, milestones M1 to M5, the open issues
and the platform setup. `README.md` has the build commands. Everything below is what those files do not say.

The repo layout follows foresight's conventions:
- `src/lib`: the library, one module per file, `.F90`.
- `src/tests` and `src/examples`.
- `scripts/`: `build_native.sh`, `fpm.sh` and `check_sync.py` (ruff-clean, standard library only).
- `native/`: `CMakeLists.txt`, `figure_native.h` and `figure_native.cpp`.

The code follows foresight's style: `!<` documentation comments, joined `endfunction`, and kinds from
`iso_fortran_env` and `iso_c_binding` only, with no PENF dependency on purpose.

Build products are gitignored: `build/`, `exe/`, `mod/`, `obj/`, `lib/`, `include/` and `build_native.log`.

## 3. State at handoff (what was verified)

These steps passed (Linux, WSLg):
- **Native layer:** cimgui `1.93dock` + cimplot `v1.1` + SDL `release-3.4.20`, built with g++ 16.2.0 into
  `lib/libfigure_native.a` and `lib/libSDL3.a`.
- **Headless test, gfortran 16.2:** `exe/figure_test_headless` PASSED with `fobis build --mode tests-gnu`. It clicks
  a button and toggles a checkbox through synthetic mouse input, and draws an ImPlot line.
- **Headless test, gfortran debug:** PASSED with `fobis build --mode tests-gnu-debug`, i.e. with `-fcheck=all`.
- **Headless test, nvfortran 26.9:** PASSED with `fobis build --mode tests-nvf`.
- **Headless test, fpm:** PASSED with `FPM_FC=gfortran scripts/fpm.sh test`.
- **Other builds:** `examples-gnu`, `examples-nvf` and `figure-static-gnu` build. `fobis rule --ex sync` reports
  fobos and fpm.toml as in sync.
- **Real window:** `exe/figure_hello` opened as an 1100x700 window titled "FIGURE: hello". A screenshot showed every
  widget and the ImPlot wave rendering correctly, with no output on stdout or stderr. The screenshot was in the session
  scratchpad, which the reboot will wipe.
- **Idle CPU with lazy redraw:** 2.6% of one core over a 10 s sample. This is not yet explained; see section 4.

**Changed since then:** Stefano installed `libxkbcommon-dev`, `libegl-dev` and `libdbus-1-dev`, then restarted WSL.
The current `lib/libSDL3.a` was built **without** those packages: X11 only, Wayland OFF, DBus OFF.

## 4. Next steps, in order

1. **Rebuild the native layer** so that Wayland and DBus get picked up:
   ```sh
   cd ~/fortran/figure
   export PATH=/opt/gcc/bin/16.2.0/bin:$PATH LD_LIBRARY_PATH=/opt/gcc/bin/16.2.0/lib64
   CC=gcc CXX=g++ scripts/build_native.sh --clean > build_native.log 2>&1
   grep -E 'SDL_(X11|WAYLAND|DBUS|OPENGL) |Video drivers' build_native.log
   ```
   Expect `SDL_WAYLAND ... ON` and `SDL_DBUS ... ON`. If either is still OFF, check
   `pkg-config --modversion wayland-client wayland-egl wayland-cursor egl xkbcommon dbus-1`.
   Then rebuild the Fortran side from clean: `rm -rf mod obj exe && fobis build --mode tests-gnu`, then
   `fobis build --mode examples-gnu`. Rerun `exe/figure_test_headless`.
2. **Run `figure_hello` again** and confirm which video driver SDL picks. With both available, SDL3 prefers Wayland
   on WSLg; if it misbehaves, use `SDL_VIDEO_DRIVER=x11` or `SDL_VIDEO_DRIVER=wayland`. Capture the window to check
   it: `import -window "FIGURE: hello" out.png` (ImageMagick) works on X11. Under Wayland, `import` may not see the
   window.
3. **Explain the idle CPU (2.6%).** The expected cost is about 2 frames per second (`max_wait` defaults to 0.5 s in
   `native/figure_native.cpp`, `fig_begin_frame`).
   - Instrument the glue to count, per second, the events (by type), the frames drawn and the time spent in
     `SDL_GL_SwapWindow`. For example, add `getenv("FIGURE_DEBUG_REDRAW")` and print the counts to stderr.
   - Suspects: spurious X or Wayland events that reset `frames_left = 3`, or an expensive swap under WSLg's D3D12 GL.
   - Then pick the default `max_wait`.
   - Measuring method used in this session: a Python script launches the program, sleeps 4 s, reads `utime+stime`
     from `/proc/<pid>/stat` before and after a 10 s window (divided by `SC_CLK_TCK`), then terminates it. The
     scratchpad copy will be gone; recreate it, or add `scripts/measure_idle.py`.
4. **Check the name for collisions.** This was promised to Stefano and **not done**: search GitHub and the fpm
   registry for "figure" Fortran projects, and report before he creates the remote. The fobos `[project]` already
   says `repository = https://github.com/szaghi/figure`, but that is an assumption to confirm.
5. **Decisions that belong to Stefano. Ask him; never decide them yourself.**
   - The licence: `fpm.toml` says `license = "TBD"`.
   - The version: `VERSION` holds the placeholder `0.0.0`. Never bump versions on your own.
6. **M2: generate the raw layer** (spec in `plans/plan.md`). Generate the bind(C) interfaces and enum parameters from
   `build/native/_deps/cimgui-src/generator/output/{definitions,structs_and_enums}.json` and the cimplot equivalents.
   - Classify each function as direct or glue. A function is direct only if all its arguments are scalars, pointers
     or `ImVec2_c`. Struct-by-value arguments such as `ImPlotSpec_c` go to the glue. Variadic functions (`igText`)
     are skipped; use the `*Unformatted` variants.
   - The generator is Python. Load the python-conventions skill.
   - Commit the generated output and add a drift check.

## 5. Gotchas found in this session (do not rediscover them)

- **cimgui tag `1.93dock` is mislabelled.** Its imgui submodule and its generated `cimgui.h` are the non-docking
  Dear ImGui: `ImGuiConfigFlags_DockingEnable` is absent. Docking is therefore disabled in the glue. If you want
  docking, choose a cimgui commit generated from the docking branch, then check that cimplot `v1.1` still compiles
  against it. The other tags `1.94.2*_conv` date from 2025 and belong to a conversion branch: ignore them.
- **cimplot `v1.1` pins implot at a "1.2 WIP" commit** and was generated against cimgui of about 18 October 2026.
  The triple compiles cleanly with g++ 16.2. Do not bump one of the three alone.
- **nvfortran 26.9 internal compiler error:** "ILM file: can't find intrinsic size". It happens when a local
  variable named `size` sits in one procedure and the intrinsic `size()` is called in another procedure of the same
  module. The code is legal Fortran. The workaround already in place is to name the locals `extent` (in
  `figure_imgui.F90` and `figure_implot.F90`). **Never name a local `size`.** A reduced reproducer for NVIDIA is
  still to be written. The first guesses did *not* reproduce it: an allocatable-character function result passed as
  an actual argument, and a bind(C) struct passed by value.
- **ImGui 1.93 headless mode needs the texture protocol.** `fig_init_headless` sets
  `ImGuiBackendFlags_RendererHasTextures`, and `fig_end_frame` acknowledges texture requests through
  `SetTexID`/`SetStatus`. This replaces the legacy `Fonts->Build()`.
- **SDL3 refuses to configure on Linux without X11 or Wayland headers.** The escape hatch is
  `scripts/build_native.sh -- -DSDL_UNIX_CONSOLE_BUILD=ON`, which gives a headless-only build. The build directory's
  CMake cache keeps the value, so use `--clean` to drop it.
- **FoBiS `-f` means `--fobos`, not force.** To force a rebuild use `--force-compile` or `rm -rf mod obj exe`.
  Switching compilers triggers a full rebuild automatically.
- **Stale binaries can fake a pass.** When nvfortran failed, `./exe/figure_test_headless` still printed PASSED from
  the old gfortran binary. Run `rm -rf exe` before trusting a run on another compiler.
- **Both modes write executables into `exe/`.** `figure-static-*` writes `lib/libfigure.a` and puts `lib/mod` and
  `lib/obj` under `lib/`. That is untidy; consider changing it.
- **Every FoBiS mode has `pre_build = native`**, so each `fobis build` runs `scripts/build_native.sh`. It takes about
  5 s to re-check when nothing changed. The *first* build needs network access (FetchContent).
- **`ig_*` labels must be unique per window.** ImGui identifies widgets by label hash; use `'label##id'` to tell
  identical labels apart.
- **Text input** (`igInputText`) needs a C buffer and a resize callback. It is not bound yet and is not trivial from
  Fortran; plan it in M2 or M3.

## 6. Environment

- **gfortran 16.2:** `export PATH=/opt/gcc/bin/16.2.0/bin:$PATH LD_LIBRARY_PATH=/opt/gcc/bin/16.2.0/lib64`.
  Non-interactive shells do not apply `module load`.
- **nvfortran 26.9:** `/opt/nvidia/hpc_sdk/Linux_x86_64/26.9/compilers/bin`.
- **Build tools:** `fobis` 3.16.0 and `fpm` 0.12.0 in `~/.local/bin`. cmake 3.28.3 and ninja are present. ruff is
  available.
- **Display:** WSLg, with `DISPLAY=:0` and `WAYLAND_DISPLAY=wayland-0`.
- **GPU:** reserved for ADAM (per Stefano's memory note). FIGURE only needs the WSLg GL for its window; do not run
  GPU benchmarks without asking.
- **Original material:** the wxFortran clone was in the session scratchpad and is lost. Re-clone it with
  `git clone --depth 50 https://github.com/jacobwilliams/wxFortran` into a scratch directory if you need to compare
  (for example, the M3 benchmark against its Mandelbrot example).

## 7. Suggested skills

- **fobis:** for any fobos edit, mode or rule, and `pre_build`/`ext_libs` semantics.
- **python-conventions:** before writing the M2 binding generator or touching `scripts/check_sync.py`.
- **fortran-2023-standard:** for interoperability questions such as VALUE on bind(C) derived types, c_loc on
  deferred-length characters, or C_BOOL and logical conversion. Ground answers in the standard, not memory.
- **diagnose:** for the idle-CPU investigation (step 3).
- **tdd:** to grow the headless test suite alongside each new binding, using synthetic input as in
  `src/tests/figure_test_headless.F90`.
- **verbatim-edit:** when regenerating or bulk-editing generated interface files where exact bytes matter.
- **gpu-multithreading** or **openmp-6.0:** later (M3), for running the solver on a worker thread alongside the
  frame loop.
- **semantic-commit:** only when Stefano asks for a commit message. It displays the message; it never commits.
