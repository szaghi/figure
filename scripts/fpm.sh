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
# fpm relinks a program when its own objects change, not when a library on its link line does: a test, example or app
# binary older than the native layer (rebuilt by scripts/build_native.sh) would still run the old native code. Such
# binaries are removed, so that fpm links them again (after check_sync.py, which may have rewritten the last).
if [[ -d "$root/build" ]]; then
   for native in "$root"/lib/libfigure_native.a "$root"/lib/libSDL3.a "$root"/lib/libfigure_platform.a; do
      [[ -f "$native" ]] || continue
      stale="$(find "$root/build" -mindepth 3 -maxdepth 3 -type f -perm -u+x \
                    \( -path '*/test/*' -o -path '*/example/*' -o -path '*/app/*' \) ! -newer "$native" -print -delete)"
      [[ -z "$stale" ]] || echo "fpm.sh: $(printf '%s\n' "$stale" | wc -l | tr -d ' ') binaries older than" \
                                "lib/${native##*/} removed: fpm links them again" >&2
   done
fi
cmd="$1"; shift
exec fpm "$cmd" --link-flag "-L$root/lib $fpm_link" "$@"
