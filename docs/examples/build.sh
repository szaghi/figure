#!/usr/bin/env bash
# Compile every documentation example against the current library sources, run the headless ones, and regenerate
# what the pages include from them.
#
#   docs/examples/src/*.F90    example programs (hand-written), with marker comments:
#                                !run ID COMMAND                    a run shown in the pages (headless programs only)
#                                !run-exit STATUS ID COMMAND        a run that ends with exit status STATUS on purpose
#                                !region NAME ... !endregion NAME   a part of the program included on its own
#   docs/examples/snippets/    generated: each source without the markers, and <source>-<region>.F90, dedented
#   docs/examples/output/      generated: <ID>.txt, "$ COMMAND" then its output (standard output and error)
#
# Every program is compiled and linked; only the programs with a !run marker are run (they use init_headless: no
# display, no GPU). Windowed programs are compiled and linked, not run.
#
# Every run is a test: a !run must exit with status 0 (a --test or --check self-test that fails, a crash), a
# !run-exit with STATUS (an example that demonstrates an error exit, e.g. an error stop: its output ends with
# "[exit status STATUS]"). Any other status fails the build, after every run: the script names each such run and its
# output file, which is written all the same, and exits with status 1. Nothing a failed run printed reaches the pages
# unnoticed.
#
# The library is compiled from src/lib/ (and the current path's src/paths/imgui/) by FoBiS command-line options, not by
# a fobos mode: the modes of fobos run the native build (pre_build) every time, while here the native layer must already
# be in lib/ (scripts/build_native.sh).
#
# Usage: bash docs/examples/build.sh [--varset linux|macos|windows] [--path imgui|fortran] [--compiler gnu|nvf|ifx]
#   (FC=... for another gfortran; build products in build/docs-examples). The varset of fobos gives the native link line
#   ($NATIVE_LIBS, $NATIVE_LFLAGS), as for the fobos modes: linux by default. --path fortran builds the programs on the
#   Fortran path (szaghi/figure#15 §2: its seams, fobos' $PATH_FORTRAN, as the -fortran modes), so that
#   `docs_media.py --check` compares its pictures; the default is the current path (imgui). --compiler nvf or ifx builds
#   them with nvfortran or ifx and the flags of fobos' tests-nvf / tests-ifx modes (with --path fortran: of the
#   -fortran modes, -Mnofma, -fp-model precise), FC naming the compiler's binary (default nvfortran, ifx). A build
#   other than the default one (gnu, imgui) writes the snippets and the runs' outputs under build/docs-examples/pages,
#   not into docs/examples/: the pages show the default build's, and the runs still fail the build on a bad status.
set -euo pipefail
varset=linux
path=imgui
compiler=gnu
while [[ $# -gt 0 ]]; do
   case $1 in
      --varset) varset=${2:?build.sh: --varset needs a name}; shift 2 ;;
      --path) path=${2:?build.sh: --path needs imgui or fortran}; shift 2 ;;
      --compiler) compiler=${2:?build.sh: --compiler needs gnu, nvf or ifx}; shift 2 ;;
      *) echo "docs/examples/build.sh: unknown option $1" >&2; exit 2 ;;
   esac
done

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
ex=$root/docs/examples
build=$root/build/docs-examples # git-ignored
# the compiler and its flags: fobos' templates and modes (tests-gnu, tests-nvf, tests-ifx; the -fortran ones on the
# Fortran path)
case $compiler in
   gnu) fc=${FC:-gfortran}; fobis_compiler=gnu; cflags="-c -std=f2018 -ffree-line-length-132 -fimplicit-none -O2"
        extra_lflags="" ;;
   nvf) fc=${FC:-nvfortran}; fobis_compiler=nvfortran; cflags="-c -Mstandard -Mfree -Munixlogical -O2"
        [[ $path == fortran ]] && cflags="$cflags -Mnofma"
        extra_lflags="-Munixlogical" ;;
   ifx) fc=${FC:-ifx}; fobis_compiler=intel_nextgen; cflags="-c -stand f18 -free -fpscomp logicals -O2"
        [[ $path == fortran ]] && cflags="$cflags -fp-model precise"
        extra_lflags="" ;;
   *) echo "docs/examples/build.sh: --compiler gnu, nvf or ifx, not $compiler" >&2; exit 2 ;;
esac
# the pages' snippets and outputs: the default build's only
pages=$ex
[[ $path == imgui && $compiler == gnu ]] || pages=$build/pages

for lib in figure_native SDL3; do
   if [[ ! -f "$root/lib/lib$lib.a" ]]; then
      echo "docs/examples/build.sh: lib/lib$lib.a missing: run scripts/build_native.sh first" >&2
      exit 1
   fi
done
rm -rf -- "$build"
mkdir -p "$build/src" "$pages/snippets" "$pages/output"
rm -f -- "$pages"/snippets/*.F90 "$pages"/output/*.txt

# snippets: the whole source and each region, without the markers, dedented
markers='^ *(!run |!run-exit |!region |!endregion )'
dedent() { awk '{l[NR]=$0; if ($0 ~ /[^ ]/) {match($0, /^ */); if (m == "" || RLENGTH < m) m = RLENGTH}}
                END {for (i = 1; i <= NR; i++) print substr(l[i], m + 1)}' "$1"; }
for src in "$ex"/src/*.F90; do
   file=$(basename "$src"); name=${file%.*}
   grep -Ev "$markers" "$src" > "$pages/snippets/$file" || true
   for region in $(sed -n 's/^ *!region \([A-Za-z0-9_-]*\).*/\1/p' "$src"); do
      awk -v r="$region" '$1 == "!endregion" && $2 == r {on = 0}
                          on && $0 !~ /^ *(!run |!run-exit |!region |!endregion )/ {print}
                          $1 == "!region" && $2 == r {on = 1}' "$src" > "$build/region"
      dedent "$build/region" > "$pages/snippets/$name-$region.F90"
   done
done

# programs: the library sources and the examples in one FoBiS build, with the flags of fobos (template-gnu, -O2) and the
# link line of its varset
read_varset() { # read_varset NAME: the value of $NAME in fobos's [varset:$varset] (continuation lines joined)
   awk -v sec="[varset:$varset]" -v key="\$$1" '
      $0 == sec {on = 1; next} /^\[/ {on = 0}
      on && $1 == key && $2 == "=" {sub(/^[^=]*= */, ""); v = $0; cont = 1; next}
      on && cont && /^[ \t]+[^ \t]/ {sub(/^[ \t]+/, ""); v = v " " $0; next}
      {cont = 0}
      END {print v}' "$root/fobos"
}
native_libs=$(read_varset NATIVE_LIBS)
native_lflags=$(read_varset NATIVE_LFLAGS)
[[ -n $native_libs ]] || { echo "docs/examples/build.sh: fobos has no \$NATIVE_LIBS in [varset:$varset]" >&2; exit 1; }
ext_libs=()
for lib in $native_libs; do ext_libs+=(--ext-libs "$lib"); done
lflags=()
native_lflags="$native_lflags${extra_lflags:+ $extra_lflags}"
[[ -n ${native_lflags// /} ]] && lflags=(--lflags "$native_lflags")
# the library of the path: src/lib and its seams (szaghi/figure#15 §2; the current path's, src/paths/imgui/, by
# default, as fpm's tree); the .inc: included by figure.F90
lib_sources=$(python3 "$root/scripts/check_sync.py" --path-sources "$path")
while IFS= read -r f; do cp "$root/${f%$'\r'}" "$build/src/"; done <<< "$lib_sources"
cp "$ex"/src/*.F90 "$build/src/"
# nvfortran 26.9 has no F2018 `stop, quiet=`: the copies stop without it (the run's floating-point note printed)
[[ $compiler == nvf ]] && sed -i -E 's/^( *(error )?stop( [0-9]+)?), quiet=\.true\./\1/' "$build"/src/*.F90
# FUNDAL (szaghi/figure#15 P6: figure_decimate_device, ip_line_device), fetched by `fobis fetch` into src/third_party:
# its sources and the files they include, in its CPU mode; its MPI handler left out (fobos' $EXCLUDE)
fundal=$root/src/third_party/FUNDAL/src/lib
[[ -f $fundal/fundal.F90 ]] || { echo "docs/examples/build.sh: $fundal missing: run fobis fetch first" >&2; exit 1; }
cp "$fundal"/*.F90 "$fundal"/*.INC "$fundal"/*.H "$build/src/"
rm -f "$build/src/fundal_mpih_object.F90"
(cd "$build" && fobis build --compiler "$fobis_compiler" --fc "$fc" --src src --build-dir bin --mod-dir mod --obj-dir obj \
                     --cflags "$cflags" \
                     --lib-dir "$root/lib" "${ext_libs[@]}" ${lflags[@]+"${lflags[@]}"} --jobs 1) \
   > "$build/build.log" 2>&1 || { cat "$build/build.log"; echo "docs/examples/build.sh: build failed" >&2; exit 1; }
for src in "$ex"/src/*.F90; do
   name=$(basename "$src" .F90)
   [[ -x "$build/bin/$name" || -x "$build/bin/$name.exe" ]] || { cat "$build/build.log"; echo "docs/examples/build.sh: $name not built" >&2; exit 1; }
   echo "built $name"
done

# runs of the headless programs
extra_path=""
[[ $varset == windows ]] && extra_path=":$PATH" # MSYS2: the runtime's DLLs (gfortran, the C++ library) are on the PATH
failed=()
# a run that never ends fails after 10 minutes (exit status 124), with its output so far, instead of holding the job
# until the CI's limit (a detached process never seen ended hung the docs job for hours, #12); macOS has no timeout
limit=()
command -v timeout > /dev/null && limit=(timeout -k 10 600)
run() { # run STATUS ID COMMAND: the run's output in output/ID.txt; a status other than STATUS is a failure
   local expect=$1 id=$2 status=0; shift 2
   {
      printf '$ %s\n' "$*"
      (cd "$build/bin" && env -i PATH="$build/bin:/usr/bin:/bin$extra_path" LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}" LC_ALL=C \
                          GFORTRAN_UNBUFFERED_PRECONNECTED=y GFORTRAN_ERROR_BACKTRACE=0 \
                          ${limit[@]+"${limit[@]}"} bash -c "$*" 2>&1 < /dev/null) || status=$?
      if ((status != 0)); then printf '[exit status %d]\n' "$status"; fi
   } > "$pages/output/$id.txt"
   if ((status == expect)); then
      echo "ran $id"
   else
      echo "docs/examples/build.sh: run $id ($*) exited with status $status, not $expect: see $pages/output/$id.txt" >&2
      failed+=("$id")
   fi
}
for src in "$ex"/src/*.F90; do
   while IFS= read -r line; do
      line=${line#"${line%%[! ]*}"} # the marker, without its indentation
      if [[ $line == '!run-exit '* ]]; then
         read -r _ status id cmd <<< "$line"
         [[ $status =~ ^[0-9]+$ && -n $cmd ]] || { echo "docs/examples/build.sh: $src: malformed '$line'" >&2; exit 1; }
      else
         read -r _ id cmd <<< "$line"
         status=0
      fi
      run "$status" "$id" "$cmd"
   done < <(grep -E '^ *!run(-exit)? ' "$src" || true)
done
if ((${#failed[@]} > 0)); then
   echo "docs/examples/build.sh: ${#failed[@]} run(s) failed: ${failed[*]}" >&2
   exit 1
fi
