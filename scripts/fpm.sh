#!/usr/bin/env bash
# Run fpm on FIGURE with the native layer on the link line: lib/ as library directory and the platform libraries of
# the fobos varset of this platform (the single source of the link line), placed by scripts/check_sync.py --fpm-link.
# Usage: scripts/fpm.sh build | test | run --example figure_hello | ...   (any fpm command and options)
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ ! -f "$root/lib/libfigure_native.a" ]]; then
   echo "fpm.sh: lib/libfigure_native.a missing: run scripts/build_native.sh first" >&2
   exit 1
fi
# writes lib/libfigure_platform.a (GNU ld: a linker script adding the platform libraries after fpm's objects) and
# prints what goes in --link-flag (macOS: the platform libraries and frameworks; elsewhere: the varset's lflags)
fpm_link="$(python3 "$root/scripts/check_sync.py" --fpm-link)"
cmd="$1"; shift
exec fpm "$cmd" --link-flag "-L$root/lib $fpm_link" "$@"
