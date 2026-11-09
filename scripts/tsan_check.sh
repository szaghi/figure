#!/usr/bin/env bash
# ThreadSanitizer check of the calls a task may make (scripts/tsan_flags.cpp): the native layer's C++ compiled with
# -fsanitize=thread (SDL3, plain C, is not instrumented) in build/tsan, linked with the program, run in headless and
# remote modes. Exits non-zero if ThreadSanitizer reports a data race or the program fails.
#
# Usage: scripts/tsan_check.sh
# The compilers are CMake's defaults; override with CC/CXX (GCC or Clang with ThreadSanitizer). The sources of SDL3,
# cimgui, cimplot and miniz are reused from build/native/_deps when scripts/build_native.sh has fetched them.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="$root/build/tsan"
mkdir -p "$root/build" # a fresh clone has no build/: the configure log goes beside build/tsan
cxx="${CXX:-c++}"
fetched=()
for dep in sdl3 cimgui cimplot miniz; do
   src="$root/build/native/_deps/$dep-src"
   [[ -d "$src" ]] && fetched+=("-DFETCHCONTENT_SOURCE_DIR_${dep^^}=$src")
done
generator=()
command -v ninja > /dev/null && generator=(-G Ninja)
cmake -S "$root/native" -B "$build_dir" ${generator[@]+"${generator[@]}"} -DCMAKE_BUILD_TYPE=RelWithDebInfo \
   -DCMAKE_CXX_FLAGS="-fsanitize=thread" ${fetched[@]+"${fetched[@]}"} > "$build_dir.log" 2>&1 \
   || { cat "$build_dir.log"; exit 1; }
cmake --build "$build_dir" --parallel --target figure_native >> "$build_dir.log" 2>&1 || { cat "$build_dir.log"; exit 1; }
sdl="$(find "$build_dir" -name 'libSDL3.a' | head -n 1)"
"$cxx" -fsanitize=thread -g -O1 -I"$root/native" "$root/scripts/tsan_flags.cpp" -o "$build_dir/tsan_flags" \
   "$build_dir/libfigure_native.a" "$sdl" -ldl -lpthread -lm
status=0
for mode in headless remote; do
   if ! env -u DISPLAY -u WAYLAND_DISPLAY SDL_VIDEO_DRIVER=offscreen TSAN_OPTIONS="halt_on_error=0 exitcode=66" \
      "$build_dir/tsan_flags" "$mode" 2> "$build_dir/tsan_$mode.log"; then
      status=1
   fi
   races=$(grep -c 'WARNING: ThreadSanitizer: data race' "$build_dir/tsan_$mode.log" || true)
   echo "tsan_check $mode: $races data race report(s) (log: build/tsan/tsan_$mode.log)"
   [[ "$races" -eq 0 ]] || status=1
done
exit $status
