#!/usr/bin/env bash
# Prove that FIGURE builds as a plain fpm dependency: a separate consumer project (scripts/fpm_consumer/) depends on
# FIGURE's self-contained package and `fpm run`s its headless test. The package is written here
# (scripts/fpm_package.py, a path dependency), or with --git it is a published one (a git dependency on its tag).
#
# Usage: scripts/fpm_consumer.sh [--sdl-prefix DIR] [--git URL --tag TAG] [-- FPM_OPTIONS...]
#   --git URL --tag TAG  depend on the package published at URL, tag TAG (scripts/fpm_publish.sh: vX.Y.Z-fpm)
#   --sdl-prefix DIR  SDL3 is not a system package here: take its headers and library from DIR (DIR/include,
#                     DIR/lib; the repository root after scripts/build_native.sh). Otherwise the system's SDL3.
# The third-party sources come from build/native/_deps (scripts/build_native.sh) or, without it, from the network.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sdl=""
git_url=""
git_tag=""
fpm_opts=()
while [[ $# -gt 0 ]]; do
   case "$1" in
      --sdl-prefix) sdl="$(cd "$2" && pwd)"; shift 2 ;;
      --) shift; fpm_opts=("$@"); break ;;
      --git) git_url="$2"; shift 2 ;;
      --tag) git_tag="$2"; shift 2 ;;
      -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
      *) echo "fpm_consumer.sh: unknown option $1" >&2; exit 2 ;;
   esac
done
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp -R "$root/scripts/fpm_consumer" "$work/consumer"
if [[ -n "$git_url" ]]; then
   [[ -n "$git_tag" ]] || { echo "fpm_consumer.sh: --git needs --tag" >&2; exit 2; }
   dep="git = \"$git_url\", tag = \"$git_tag\""
else
   fetch=()
   [[ -d "$root/build/native/_deps/cimgui-src" ]] || fetch=(--fetch) # no CMake tree here: download the pinned sources
   python3 "$root/scripts/fpm_package.py" "$work/figure" ${fetch[@]+"${fetch[@]}"}
   dep="path = \"../figure\"" # fpm wants it relative
fi
sed -i.bak "s#path = \"FIGURE_PACKAGE\"#$dep#" "$work/consumer/fpm.toml" && rm -f "$work/consumer/fpm.toml.bak"
grep -q '^figure = ' "$work/consumer/fpm.toml" && grep '^figure = ' "$work/consumer/fpm.toml"
if [[ -n "$sdl" ]]; then
   export FPM_CFLAGS="${FPM_CFLAGS:-} -I$sdl/include" FPM_CXXFLAGS="${FPM_CXXFLAGS:-} -I$sdl/include"
   export FPM_LDFLAGS="${FPM_LDFLAGS:-} -L$sdl/lib -pthread"
fi
cd "$work/consumer"
fpm run --profile release ${fpm_opts[@]+"${fpm_opts[@]}"} | tee "$work/run.log"
grep -q '^consumer: ok' "$work/run.log"
