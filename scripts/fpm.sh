#!/usr/bin/env bash
# Run fpm on FIGURE with the native layer on the link line: lib/ as library directory, plus the platform libraries of
# the fobos varset of this platform (scripts/check_sync.py --link-flags), the single source of the link line.
# Usage: scripts/fpm.sh build | test | run --example figure_hello | ...   (any fpm command and options)
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ ! -f "$root/lib/libfigure_native.a" ]]; then
   echo "fpm.sh: lib/libfigure_native.a missing: run scripts/build_native.sh first" >&2
   exit 1
fi
native_link="$(python3 "$root/scripts/check_sync.py" --link-flags)"
cmd="$1"; shift
exec fpm "$cmd" --link-flag "-L$root/lib $native_link" "$@"
