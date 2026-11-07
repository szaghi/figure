#!/usr/bin/env bash
# Compile every documentation example against the current library sources, run the headless ones, and regenerate
# what the pages include from them.
#
#   docs/examples/src/*.F90    example programs (hand-written), with marker comments:
#                                !run ID COMMAND                    a run shown in the pages (headless programs only)
#                                !region NAME ... !endregion NAME   a part of the program included on its own
#   docs/examples/snippets/    generated: each source without the markers, and <source>-<region>.F90, dedented
#   docs/examples/output/      generated: <ID>.txt, "$ COMMAND" then its output (standard output and error)
#
# Every program is compiled and linked; only the programs with a !run marker are run (they use init_headless: no
# display, no GPU). Windowed programs are compiled and linked, not run.
#
# The library is compiled from src/lib/ by FoBiS command-line options, not by a fobos mode: the modes of fobos run
# the native build (pre_build) every time, while here the native layer must already be in lib/ (scripts/build_native.sh).
#
# Usage: bash docs/examples/build.sh            (FC=... for another gfortran; build products in build/docs-examples)
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
ex=$root/docs/examples
build=$root/build/docs-examples # git-ignored
fc=${FC:-gfortran}

for lib in figure_native SDL3; do
   if [[ ! -f "$root/lib/lib$lib.a" ]]; then
      echo "docs/examples/build.sh: lib/lib$lib.a missing: run scripts/build_native.sh first" >&2
      exit 1
   fi
done
rm -rf -- "$build"
mkdir -p "$build/src" "$ex/snippets" "$ex/output"
rm -f -- "$ex"/snippets/*.F90 "$ex"/output/*.txt

# snippets: the whole source and each region, without the markers, dedented
markers='^ *(!run |!region |!endregion )'
dedent() { awk '{l[NR]=$0; if ($0 ~ /[^ ]/) {match($0, /^ */); if (m == "" || RLENGTH < m) m = RLENGTH}}
                END {for (i = 1; i <= NR; i++) print substr(l[i], m + 1)}' "$1"; }
for src in "$ex"/src/*.F90; do
   file=$(basename "$src"); name=${file%.*}
   grep -Ev "$markers" "$src" > "$ex/snippets/$file" || true
   for region in $(sed -n 's/^ *!region \([A-Za-z0-9_-]*\).*/\1/p' "$src"); do
      awk -v r="$region" '$1 == "!endregion" && $2 == r {on = 0}
                          on && $0 !~ /^ *(!run |!region |!endregion )/ {print}
                          $1 == "!region" && $2 == r {on = 1}' "$src" > "$build/region"
      dedent "$build/region" > "$ex/snippets/$name-$region.F90"
   done
done

# programs: the library sources and the examples in one FoBiS build, with the flags of fobos (template-gnu, -O2)
ext_libs=()
for lib in figure_native SDL3 stdc++ dl pthread m; do ext_libs+=(--ext-libs "$lib"); done # fobos $NATIVE_LIBS
cp "$root"/src/lib/*.F90 "$root"/src/lib/*.inc "$ex"/src/*.F90 "$build/src/" # the .inc: included by figure.F90
(cd "$build" && fobis build --compiler gnu --fc "$fc" --src src --build-dir bin --mod-dir mod --obj-dir obj \
                     --cflags "-c -std=f2018 -ffree-line-length-132 -fimplicit-none -O2" \
                     --lib-dir "$root/lib" "${ext_libs[@]}" --jobs 1) \
   > "$build/build.log" 2>&1 || { cat "$build/build.log"; echo "docs/examples/build.sh: build failed" >&2; exit 1; }
for src in "$ex"/src/*.F90; do
   name=$(basename "$src" .F90)
   [[ -x "$build/bin/$name" ]] || { cat "$build/build.log"; echo "docs/examples/build.sh: $name not built" >&2; exit 1; }
   echo "built $name"
done

# runs of the headless programs
run() { # run ID COMMAND
   local id=$1; shift
   {
      printf '$ %s\n' "$*"
      (cd "$build/bin" && env -i PATH="$build/bin:/usr/bin:/bin" LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}" LC_ALL=C \
                          GFORTRAN_UNBUFFERED_PRECONNECTED=y GFORTRAN_ERROR_BACKTRACE=0 bash -c "$*" 2>&1) || printf '[exit status %d]\n' "$?"
   } > "$ex/output/$id.txt"
   echo "ran $id"
}
for src in "$ex"/src/*.F90; do
   while IFS= read -r line; do
      line=${line#*"!run "}
      run "${line%% *}" "${line#* }"
   done < <(grep -E '^ *!run ' "$src" || true)
done
