---
title: Installation
---

# Installation

```bash
curl -fsSL https://github.com/szaghi/figure/releases/latest/download/install.sh | bash -s -- --gnu
```

This builds the latest release with gfortran, installs it into `~/.local` and checks it with a test program. Then
compile any program against it:

```bash
export PKG_CONFIG_PATH=$HOME/.local/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}
gfortran my_program.F90 $(pkg-config --cflags --libs figure) -o my_program
```

FIGURE is always built from source: `.mod` files work only with the compiler, and the compiler version, that wrote
them, so there are no prebuilt binaries. Four routes lead to a usable library:

| Route | Use it when | Section |
|---|---|---|
| The one-line installer | your program is built by anything (Make, CMake, a shell line, FoBiS) and you want FIGURE installed once per compiler, found by `pkg-config` | [The one-line installer](#the-one-line-installer) |
| fpm | your program is an fpm project: fpm compiles FIGURE, native layer included, as one of its dependencies | [FIGURE as an fpm dependency](#figure-as-an-fpm-dependency) |
| FoBiS fetch | your program is a FoBiS project and should pin FIGURE's version in its own fobos | [FIGURE as a FoBiS dependency](#figure-as-a-fobis-dependency) |
| Manual build | you work on FIGURE itself, run its tests and examples, or need a modified FIGURE | [Building from the repository](#building-from-the-repository) |

## The one-line installer

`scripts/install.sh`, attached to every release, works in five stages and stops at the first that fails:

1. **Toolchain.** The Fortran compiler (`--gnu`: `gfortran`; `--nvidia`: `nvfortran`; `--fc FC`: either, by name or
   path), the C and C++ compilers that go with it, CMake 3.24 or newer, `pkg-config`, Python 3.11 or newer, and
   `curl` or `git`. With `--gnu`, the C and C++ compilers are the `gcc` and `g++` beside `gfortran` (on macOS, Apple
   clang, whose C++ runtime the link line uses); with `--nvidia`, `gcc` and `g++` (nvfortran links `libstdc++`);
   `CC` and `CXX`, when both are set, override them. Every version is printed.
2. **System packages.** On Linux, SDL3 enables X11, Wayland (with libdecor) and DBus only when their development
   packages are present when it is configured. The script checks them by their `pkg-config` names, and the missing
   tools with them; if anything is missing, it prints the exact `apt-get` or `dnf` command that installs it and
   stops (exit status 3). **It never runs `sudo` by itself:** run that command, or run the script again with
   `--deps`, which shows the command and then runs it. On macOS, SDL needs only the system's frameworks: `--deps`
   runs `brew install` for missing tools (no `sudo`).
3. **Download and build.** The release (`--tag`, default the latest) is downloaded and built in a temporary
   directory: the native layer with CMake (whose first build downloads Dear ImGui, ImPlot, cimgui, cimplot, SDL3 and
   miniz), then `libfigure.a` with FoBiS. When FoBiS 3.8 or newer is not on `PATH`, it is installed in a private
   virtual environment inside that directory, removed at the end. `--source DIR` builds a local FIGURE tree instead
   (a copy of it: the tree itself is not written).
4. **Install** into `--prefix` (default `~/.local`), under the compiler's tag, such as `gnu-16.2.0` or `nvidia-26.9`
   (table below). Installs for different compilers live side by side; installing the same compiler again replaces
   its previous install.
5. **Proof.** A ten-line program that draws three frames headless is compiled with
   `pkg-config --cflags --libs figure-<tag>` and run; then the compile line for your programs is printed.

| Installed | What |
|---|---|
| `lib/figure/<tag>/` | `libfigure.a`, and the native layer `libfigure_native.a`, `libSDL3.a` (static; on macOS also `libfigure_clang_rt.a`) |
| `include/figure/<tag>/` | the `.mod` files, for this compiler and version only |
| `lib/pkgconfig/figure-<tag>.pc` | this install's flags: `-I` for the modules, then the libraries and the platform's link line |
| `lib/pkgconfig/figure.pc` | a copy of the last install's `.pc`: `pkg-config figure` means the compiler installed last |
| `share/figure/<tag>/` | the licences (FIGURE's and those of the code compiled into the libraries, see [THIRD_PARTY.md](https://github.com/szaghi/figure/blob/main/THIRD_PARTY.md)), the theme files, and `manifest`, the list of every file and directory installed |

| Option | Meaning |
|---|---|
| `--gnu`, `--nvidia`, `--fc FC` | the Fortran compiler (one is required) |
| `--prefix DIR` | where to install (default `~/.local`) |
| `--tag TAG` | the release to build (default the latest) |
| `--source DIR` | build a local FIGURE tree instead of a release |
| `--deps` | run the package command of stage 2, after showing it |
| `--dry-run` | run stages 1 and 2, print the package command, build nothing |
| `--uninstall` | remove what the script installed in `--prefix`: every install, or with a compiler option only that compiler's |
| `--keep` | keep the build directory (a failed stage always keeps it, and prints the path of its log) |
| `--verbose` | show the build's output (otherwise written to the log) |

With two compilers installed, choose one by its `.pc`: `pkg-config --cflags --libs figure-nvidia-26.9`.

To remove an install, run the script with `--uninstall` (and the same `--prefix`):

```bash
curl -fsSL https://github.com/szaghi/figure/releases/latest/download/install.sh | bash -s -- --uninstall
```

It removes exactly the files and directories listed in the manifests, and nothing else in the prefix. What the
installer does not cover is listed in the [known issues](known-issues#the-one-line-installer).

## FIGURE as a FoBiS dependency

A FoBiS project fetches and builds FIGURE with its own fobos (`use=fobos`, the static-library mode of your
compiler: `figure-static-gnu`, `figure-static-nvf` or `figure-static-ifx`), then links the native layer from the
clone's `lib/`:

```ini
[dependencies]
figure = https://github.com/szaghi/figure :: tag=v0.2.0 :: use=fobos :: mode=figure-static-gnu
```

```ini
[gnu]
; ... your mode: FoBiS adds FIGURE's modules and libfigure.a; the native layer and the platform's libraries are yours
lib_dir  = .fobis_deps/figure/lib
ext_libs = figure_native SDL3 stdc++ dl pthread m
```

`fobis fetch` clones the tag and builds it (the mode's `pre_build` runs the native build, with CMake, so the
requirements below apply); `fobis build` then rebuilds nothing that is up to date. `ext_libs` is the Linux link line;
`python3 .fobis_deps/figure/scripts/check_sync.py --link-flags` prints that of the platform it runs on.

## Building from the repository

FIGURE has two layers, built separately:

- the **native layer** (C and C++): Dear ImGui, ImPlot, cimgui, cimplot, miniz, SDL3 and FIGURE's glue, built by CMake
  into
  two static libraries, `lib/libfigure_native.a` and `lib/libSDL3.a`;
- the **Fortran library** (`src/lib`), built by [FoBiS](https://github.com/szaghi/FoBiS) (the primary build) or
  [fpm](https://fpm.fortran-lang.org). Neither compiles C++ in this repository: both only link the native layer.
  For another fpm project, FIGURE can also be [a self-contained fpm package](#figure-as-an-fpm-dependency), where fpm
  compiles the native layer itself.

## Requirements

- A Fortran 2018 compiler. Verified: gfortran 16.2, nvfortran 26.9 and Intel ifx 2026.2 (Linux); the CI's versions
  are in [Verified platforms and compilers](#verified-platforms-and-compilers).
- A C++17 compiler whose C++ runtime is the one the Fortran link line uses: `libstdc++` with gfortran and nvfortran
  on Linux and with MinGW on Windows, `libc++` (Apple clang) on macOS. Verified: g++ 16.2.
- CMake 3.24 or newer; Ninja is used when present.
- Network access for the first native build: CMake downloads the pinned sources.
- FoBiS 3.8 or newer, or fpm.
- Python 3.11 or newer, for the scripts: `check_sync.py` (which `fpm.sh` runs), the remote test's client, the fpm
  package and the measurement and documentation scripts.

Platforms: Linux is verified locally (X11 and Wayland, under WSL2/WSLg). macOS (gfortran with Apple clang) and
Windows (MSYS2 UCRT64 gfortran) are built, tested and opened in a window by the `Platforms` CI workflow (see
[Verified platforms and compilers](#verified-platforms-and-compilers)).

### Linux packages

SDL3 enables its X11, Wayland and DBus support only when their development packages are present when CMake
configures it. Without them it silently builds X11 only, and without DBus there are no XDG-portal file dialogs
([file dialogs](frame-loop#file-dialogs) then need `zenity` at run time). On Ubuntu 24.04:

```bash
sudo apt install libxext-dev libxrandr-dev libxcursor-dev libxi-dev libxfixes-dev libxss-dev libxtst-dev \
                 libwayland-dev libxkbcommon-dev libegl-dev libdbus-1-dev libdecor-0-dev
```

**File dialogs at run time** (`app%open_file_dialog` and the others): SDL3 asks the desktop's XDG portal through DBus
(`xdg-desktop-portal` with a backend such as `xdg-desktop-portal-gtk`, present on most desktops and on WSLg) or, when
there is none, runs `zenity`. Without either, the dialog fails with that reason in its status.

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
fobis build --mode tests-ifx                                  # Intel ifx (after: source /opt/intel/oneapi/setvars.sh)
fobis rule --ex sync                                          # fobos and fpm.toml describe the same build
```

`fobis build --lmodes` lists the modes:

| Mode | Builds |
|---|---|
| `tests-gnu`, `tests-nvf`, `tests-ifx` | the tests: `exe/figure_test_headless`, `figure_test_layout`, `figure_test_remote`, `figure_test_themes` |
| `tests-gnu-debug` | the same with runtime checks and floating-point traps |
| `examples-gnu`, `examples-nvf`, `examples-ifx` | the example programs (`exe/figure_hello`, `exe/figure_mandelbrot`, `exe/figure_bench_texture`, `exe/figure_bench_redraw`), with OpenMP |
| `figure-static-gnu`, `figure-static-nvf`, `figure-static-ifx` | the static library `lib/libfigure.a` (`figure` and `figure_testing`), modules in `lib/mod` |

Two rules matter here: `fobis rule --ex native` builds the native layer, `fobis rule --ex sync` checks fobos against
`fpm.toml`.

::: warning Switching compilers
Test and example modes of every compiler write into `exe/`. Run `rm -rf exe` before trusting a run after a switch:
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
scripts/fpm.sh test --compiler ifx --flag "-fpscomp logicals"
```

With ifx, pass `--flag "-fpscomp logicals"` (here and to an fpm project depending on FIGURE), as fobos does:
[Intel ifx](#intel-ifx).

## FIGURE as an fpm dependency

Another fpm project depends on FIGURE through the package published for each release, the tag `vX.Y.Z-fpm`:

```toml
[dependencies]
figure = { git = "https://github.com/szaghi/figure", tag = "v0.2.0-fpm" }
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

## Verified platforms and compilers

The `Platforms` CI workflow builds the native layer and the Fortran library, runs the headless tests with FoBiS and
with fpm, builds the examples and builds FIGURE as an fpm dependency (`scripts/fpm_consumer.sh`), on:

| Platform | Fortran | C/C++ | fobos varset | A real window |
|---|---|---|---|---|
| Linux (Ubuntu) | gfortran (`ci.yml`), nvfortran 26.9, Intel ifx 2026.1 | g++ | `linux` (default) | Xvfb, Mesa's OpenGL (nvfortran job) |
| macOS (arm64) | gfortran 14 (Homebrew) | Apple clang | `macos` | the runner's display |
| Windows (MSYS2 UCRT64) | gfortran | g++ | `windows` | the runner's display, Mesa's software OpenGL |

**A real window:** `scripts/window_check.py` runs `exe/figure_hello` in a window twice, with the system's frame and
with FIGURE's (`--frame`, [`decorations='figure'`](frame-loop#the-window-s-frame)), captures its frames ([Screenshots
and videos](capture)) and checks the last one: the window's size (or less, down to 1000 x 600, when the system clamps
the window to a small display, as on the macOS runner's 1024 x 768), not blank, and known widgets' pixels (the
background, the "Click me" button, the slider's grab, and FIGURE's title bar with its title and close button, on the
left on macOS). The frames are kept as the workflow's `window-frames-linux`, `-macos` and `-windows` artifacts. Run it
on your own display after `fobis build --mode examples-gnu`:

```bash
python3 scripts/window_check.py --out window-frames   # writes window-frames/native.png and figure.png
```

The Windows runner has no GPU and its own OpenGL is version 1.1: the job places Mesa's `opengl32.dll` (MSYS2's
`mesa` package, software rendering) beside the program. On a Windows machine with a GPU driver nothing is needed.

### Intel ifx

The ifx modes (`tests-ifx`, `examples-ifx`, `figure-static-ifx`) use FoBiS' `intel_nextgen` compiler with
`-stand f18 -free -fpscomp logicals`. Load oneAPI first (`source /opt/intel/oneapi/setvars.sh`); the native layer is
built with `gcc` and `g++` as for gfortran (`CC=gcc CXX=g++ scripts/build_native.sh`): ifx links `libstdc++`.

- **`-fpscomp logicals`:** by default ifx stores `.true.` as -1, also in a `logical(c_bool)`, which C and C++ do not
  accept as a `bool` (ifx warns, #5472, at every logical passed to Dear ImGui). With the option `.true.` is 1 and any
  non-zero value is true. A program compiled without it may still use a FIGURE built with it: each side reads the
  other's `.true.` as true.
- **Threads:** ifx links its thread-safe run-time library by default, so the tasks' Fortran I/O needs no OpenMP
  flag (unlike nvfortran's `-mp`, [Known issues](known-issues#tasks)).

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
