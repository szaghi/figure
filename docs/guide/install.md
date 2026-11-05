---
title: Installation
---

# Installation

FIGURE has two layers, built separately:

- the **native layer** (C and C++): Dear ImGui, ImPlot, cimgui, cimplot, SDL3 and FIGURE's glue, built by CMake into
  two static libraries, `lib/libfigure_native.a` and `lib/libSDL3.a`;
- the **Fortran library** (`src/lib`), built by [FoBiS](https://github.com/szaghi/FoBiS) (the primary build) or
  [fpm](https://fpm.fortran-lang.org). Neither compiles C++ in this repository: both only link the native layer.
  For another fpm project, FIGURE can also be [a self-contained fpm package](#figure-as-an-fpm-dependency), where fpm
  compiles the native layer itself.

## Requirements

- A Fortran 2018 compiler. Verified: gfortran 16.2 and nvfortran 26.9 (Linux).
- A C++17 compiler whose C++ runtime is the one the Fortran link line uses: `libstdc++` with gfortran and nvfortran
  on Linux and with MinGW on Windows, `libc++` (Apple clang) on macOS. Verified: g++ 16.2.
- CMake 3.24 or newer; Ninja is used when present.
- Network access for the first native build: CMake downloads the pinned sources.
- FoBiS 3.8 or newer, or fpm.
- Python 3.11 or newer, only for `scripts/check_sync.py` and `scripts/measure_idle.py`.

Platforms: Linux is verified locally (X11 and Wayland, under WSL2/WSLg). macOS (gfortran with Apple clang) and
Windows (MSYS2 UCRT64 gfortran) are built and tested by the `Platforms` CI workflow (see
[Other platforms](#other-platforms)).

### Linux packages

SDL3 enables its X11, Wayland and DBus support only when their development packages are present when CMake
configures it. Without them it silently builds X11 only, and without DBus there are no XDG-portal file dialogs
(FIGURE does not expose file dialogs yet). On Ubuntu 24.04:

```bash
sudo apt install libxext-dev libxrandr-dev libxcursor-dev libxi-dev libxfixes-dev libxss-dev libxtst-dev \
                 libwayland-dev libxkbcommon-dev libegl-dev libdbus-1-dev libdecor-0-dev
```

If you install them after a first native build, rebuild it with `--clean` (the CMake cache keeps the old choice).
SDL3 refuses to configure on Linux without X11 or Wayland headers; a build without any video driver, for the
headless test only, is possible with `scripts/build_native.sh -- -DSDL_UNIX_CONSOLE_BUILD=ON`.

## The native layer

```bash
git clone https://github.com/szaghi/figure
cd figure
scripts/build_native.sh
```

`scripts/build_native.sh [--prefix DIR] [--build-type Release|Debug] [--clean] [-- EXTRA_CMAKE_ARGS...]` configures
`native/CMakeLists.txt` in `build/native`, builds it and installs the libraries into `lib/` (and `figure_native.h`
into `include/`, and the licences of the code compiled into the libraries into `share/licenses/`: see
[THIRD_PARTY.md](https://github.com/szaghi/figure/blob/main/THIRD_PARTY.md)). The C and C++ compilers are CMake's
defaults; choose them with `CC` and `CXX`:

```bash
CC=gcc CXX=g++ scripts/build_native.sh --clean
```

The third-party versions are pinned as a matched set: cimgui `1.93.1WIPdock` (Dear ImGui 1.93.1 WIP, docking branch),
cimplot `v1.1` (ImPlot 1.2 WIP, generated against the same Dear ImGui 1.93 API) and SDL `release-3.4.20`; miniz
`3.0.2` (deflate, for the remote mode) is fetched as a release archive checked by its SHA-256. They are CMake cache variables
(`FIGURE_CIMGUI_TAG`, `FIGURE_CIMPLOT_TAG`, `FIGURE_SDL_TAG`), but do not change one of the three alone: cimplot is
generated against a specific cimgui.

## The Fortran library with FoBiS

Every FoBiS mode runs `scripts/build_native.sh` first (`pre_build = native`): a no-op, a few seconds, once the native
layer is built.

```bash
fobis build --mode tests-gnu && exe/figure_test_headless      # gfortran
fobis build --mode examples-gnu && exe/figure_hello
fobis build --mode tests-nvf                                  # nvfortran
fobis rule --ex sync                                          # fobos and fpm.toml describe the same build
```

`fobis build --lmodes` lists the modes:

| Mode | Builds |
|---|---|
| `tests-gnu`, `tests-nvf` | the headless test, `exe/figure_test_headless` |
| `tests-gnu-debug` | the same with runtime checks and floating-point traps |
| `examples-gnu`, `examples-nvf` | the example programs (`exe/figure_hello`, `exe/figure_mandelbrot`, `exe/figure_bench_texture`), with OpenMP |
| `figure-static-gnu`, `figure-static-nvf` | the static library `lib/libfigure.a`, modules in `lib/mod` |

Two rules: `fobis rule --ex native` builds the native layer, `fobis rule --ex sync` checks fobos against
`fpm.toml`.

::: warning Switching compilers
Test and example modes of both compilers write into `exe/`. Run `rm -rf exe` before trusting a run after a switch:
a stale binary of the other compiler can still be there.
:::

## The Fortran library with fpm

`scripts/fpm.sh` runs fpm with the native layer on the link line. `fpm.toml` links `figure_native`, `SDL3` and
`figure_platform`, after the program's objects; `fpm.sh` first runs `python3 scripts/check_sync.py --fpm-link`, which
makes `lib/libfigure_platform.a` carry the platform libraries of the fobos varset. With GNU ld (Linux, Windows) it is a
one-line linker script, `INPUT(-lstdc++ ...)`: fpm passes `--link-flag` before the objects, where archives (the C++
runtime and Windows' import libraries) would resolve nothing. On macOS, where the linker does not depend on order, it
is an empty archive from the native build and the libraries and frameworks go in `--link-flag`. `fpm.sh` stops if
`lib/libfigure_native.a` is missing.

```bash
scripts/fpm.sh test
scripts/fpm.sh run --example figure_hello
FPM_FC=gfortran scripts/fpm.sh test
```

## FIGURE as an fpm dependency

Another fpm project depends on FIGURE through the package published for each release, the tag `vX.Y.Z-fpm`:

```toml
[dependencies]
figure = { git = "https://github.com/szaghi/figure", tag = "v0.1.0-fpm" }
```

A plain `fpm build` then compiles everything; only SDL3 comes from the system (on macOS fpm also needs
`FPM_CXXFLAGS=-std=c++17`, below).

fpm has no build hooks, so it cannot run CMake. `scripts/fpm_package.py` writes FIGURE as a **self-contained fpm
package** instead: the Fortran library, FIGURE's glue and the pinned Dear ImGui, ImPlot, cimgui, cimplot and miniz
sources (only the files FIGURE compiles, with their licences), and the files CMake generates (the browser page, the
themes and the font, embedded). The sources come from CMake's fetched tree, or with `--fetch` from the network at the
pins of `native/CMakeLists.txt`. For each release tag `vX.Y.Z` the workflow `fpm.yml` runs `scripts/fpm_publish.sh`,
which commits the package (one commit with no parent: the tag carries the package, not the repository's history) and
pushes `vX.Y.Z-fpm`, after testing it as a path dependency and before testing it as a git dependency on Linux, macOS
and Windows.

Between releases, or for a modified FIGURE, write the package yourself and depend on it by path:

```bash
python3 scripts/fpm_package.py ../figure-fpm --fetch
```

```toml
[dependencies]
figure = { path = "../figure-fpm" }
```

SDL3 is the one system library (FIGURE pins and tests SDL 3.4; the package needs SDL 3.2 or later):

| Platform | SDL3 | Notes |
|---|---|---|
| Linux | the distribution's SDL3 development package: `libsdl3-dev` (Debian 13, Ubuntu 25.04 and later), `SDL3-devel` (Fedora) | |
| macOS | `brew install sdl3` | `export CPATH=$(brew --prefix)/include LIBRARY_PATH=$(brew --prefix)/lib FPM_CXXFLAGS=-std=c++17` (Apple clang defaults to C++98, and fpm takes no C++ flags from a manifest); build the C/C++ with Apple clang (`--c-compiler clang --cxx-compiler clang++`), since on macOS fpm links the C++ runtime as libc++ |
| Windows (MSYS2 UCRT64) | `pacman -S mingw-w64-ucrt-x86_64-sdl3` | Winsock is loaded at run time: no other library |

Without a package (Ubuntu 24.04), the static SDL3 the native build installs serves:
`FPM_CXXFLAGS=-I$PWD/include FPM_LDFLAGS="-L$PWD/lib -pthread"`.

`scripts/fpm_consumer.sh` checks the whole route: it writes the package and a separate project
(`scripts/fpm_consumer/`) depending on it, and runs that project's headless test (`--sdl-prefix .` uses the native
build's SDL3). The Platforms workflow runs it on macOS and Windows with the system's SDL3, and on Linux with the
native build's. `scripts/check_sync.py` checks that the package compiles the same C and C++ sources as CMake.

## Use the library

Build the static library, then compile against its modules and link it together with the native layer:

```bash
fobis build --mode figure-static-gnu
gfortran -I figure/lib/mod my_program.F90 figure/lib/libfigure.a \
         -L figure/lib $(python3 figure/scripts/check_sync.py --link-flags) -o my_program
```

`check_sync.py --link-flags` prints the native link line of the platform, in order: `figure_native SDL3` followed
by the platform's libraries (on Linux `stdc++ dl pthread m`); the lists, with macOS's frameworks, are the fobos
varsets (next section). Order matters where the system libraries are archives (Windows' import libraries). In the program, `use figure` gives the
whole public API (see the [feature map](features)).

## Other platforms

The native layer statically links SDL3, whose system dependencies differ by platform. fobos keeps them in one varset
per platform; `linux` is the default, the others are selected with `--varset`:

| Platform | Toolchain | FoBiS |
|---|---|---|
| Linux | gfortran or nvfortran, g++ | `fobis build --mode tests-gnu` |
| macOS | gfortran (Homebrew, `fortran-lang/setup-fortran`), Apple clang | `fobis build --mode tests-gnu --varset macos` |
| Windows | MSYS2 UCRT64: `gcc-fortran`, `cmake`, `ninja`, `python`, `pkgconf` | `fobis build --mode tests-gnu --varset windows` |

The native build installs SDL's own description of its static link line, `lib/pkgconfig/sdl3.pc`.
`fobis rule --ex sync` (`scripts/check_sync.py`) checks that the varset of the platform it runs on covers it: every
library and framework SDL needs must be in the varset. The `Platforms` CI workflow runs that check on macOS and
Windows before linking anything, so a missing system library shows up as a named error, not as an undefined symbol.

SDL is built with only the subsystems FIGURE uses (video, events, OpenGL, file dialogs): audio, game controllers,
haptics, sensors, camera, GPU, render, power and tray are off, which keeps the link line short on every platform.

## WSL2 (WSLg)

Set `GALLIUM_DRIVER=d3d12`, for example in `~/.bashrc`:

```bash
export GALLIUM_DRIVER=d3d12
```

Without it, recent Mesa (seen with 25.2) does not pick the GPU and renders in software (llvmpipe): FIGURE works, but
every frame costs CPU. Check with `glxinfo -B`: the renderer must be `D3D12 (<your GPU>)` with `Accelerated: yes`.
FIGURE does not set the variable itself: it is a property of the machine, and wrong outside WSL.

SDL3 picks the X11 driver by default on WSLg; `SDL_VIDEO_DRIVER=wayland` also works (Mesa EGL prints harmless
"failed to get driver name for fd -1" warnings). To see what a program costs while idle on your machine, and whether
it renders on the GPU, use `scripts/measure_idle.py` (see [Frame loop and redraw](frame-loop#measuring-idle-cost)).

## Build the documentation

```bash
cd docs
npm install
npm run docs:build      # regenerates the API pages with formal, then builds the site
bash examples/build.sh  # compiles every example of the pages, runs the headless ones (from the repository root too)
```
