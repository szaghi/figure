#!/usr/bin/env bash
# Prove that FIGURE builds as a plain fpm dependency: write the self-contained package (scripts/fpm_package.py) and a
# separate consumer project (scripts/fpm_consumer/) depending on it, then `fpm run` the consumer's headless test.
#
# Usage: scripts/fpm_consumer.sh [--sdl-prefix DIR] [-- FPM_OPTIONS...]
#   --sdl-prefix DIR  SDL3 is not a system package here: take its headers and library from DIR (DIR/include,
#                     DIR/lib; the repository root after scripts/build_native.sh). Otherwise the system's SDL3.
# Needs build/native/_deps (scripts/build_native.sh, or only its CMake configure step, fetches the sources).
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sdl=""
fpm_opts=()
while [[ $# -gt 0 ]]; do
   case "$1" in
      --sdl-prefix) sdl="$(cd "$2" && pwd)"; shift 2 ;;
      --) shift; fpm_opts=("$@"); break ;;
      -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
      *) echo "fpm_consumer.sh: unknown option $1" >&2; exit 2 ;;
   esac
done
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
python3 "$root/scripts/fpm_package.py" "$work/figure"
cp -R "$root/scripts/fpm_consumer" "$work/consumer"
sed -i.bak "s#FIGURE_PACKAGE#../figure#" "$work/consumer/fpm.toml" && rm -f "$work/consumer/fpm.toml.bak" # fpm wants it relative
if [[ -n "$sdl" ]]; then
   export FPM_CFLAGS="${FPM_CFLAGS:-} -I$sdl/include" FPM_CXXFLAGS="${FPM_CXXFLAGS:-} -I$sdl/include"
   export FPM_LDFLAGS="${FPM_LDFLAGS:-} -L$sdl/lib -pthread"
fi
cd "$work/consumer"
fpm run --profile release ${fpm_opts[@]+"${fpm_opts[@]}"} | tee "$work/run.log"
grep -q '^consumer: ok' "$work/run.log"
