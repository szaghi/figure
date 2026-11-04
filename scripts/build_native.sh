#!/usr/bin/env bash
# Build and install FIGURE's native layer (ImGui, ImPlot, cimgui, cimplot, SDL3, glue) into <prefix>/lib.
#
# Usage: scripts/build_native.sh [--prefix DIR] [--build-type Release|Debug] [--clean] [-- EXTRA_CMAKE_ARGS...]
# Default prefix: the repository root (libraries land in lib/, as both fobos and fpm.toml expect).
# The C/C++ compilers are CMake's defaults; override with CC/CXX (they must match the C++ runtime the Fortran link
# line uses: libstdc++ with gfortran/nvfortran on Linux, MinGW's on Windows, libc++ on macOS).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
prefix="$root"
build_type="Release"
clean=0
extra=()
while [[ $# -gt 0 ]]; do
   case "$1" in
      --prefix) prefix="$2"; shift 2 ;;
      --build-type) build_type="$2"; shift 2 ;;
      --clean) clean=1; shift ;;
      --) shift; extra=("$@"); break ;;
      -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
      *) echo "build_native.sh: unknown option $1" >&2; exit 2 ;;
   esac
done

build_dir="$root/build/native"
[[ $clean -eq 1 ]] && rm -rf "$build_dir"
generator=()
command -v ninja > /dev/null && generator=(-G Ninja)
# ${a[@]+"${a[@]}"}: an empty array is "unbound" under set -u in bash < 4.4 (macOS ships bash 3.2)
cmake -S "$root/native" -B "$build_dir" ${generator[@]+"${generator[@]}"} \
   -DCMAKE_BUILD_TYPE="$build_type" -DCMAKE_INSTALL_PREFIX="$prefix" -DCMAKE_INSTALL_LIBDIR=lib ${extra[@]+"${extra[@]}"}
cmake --build "$build_dir" --parallel
cmake --install "$build_dir"
