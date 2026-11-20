#!/usr/bin/env bash
# Write figure-<version>-sources.tar.gz: FIGURE's tracked files, every source its native build would download (SDL3,
# cimplot, cimplot3d, miniz) under third_party/fetched/, and the Fortran libraries `fobis fetch` put in src/third_party/
# (with the .deps_config.ini FoBiS reads), so that a machine with no network (a cluster's node) builds it:
# scripts/build_native.sh finds third_party/fetched/ and downloads nothing, FoBiS finds the libraries and needs no fetch;
# scripts/install.sh --source <unpacked tree> installs it (FoBiS must be installed there).
#
# Usage: scripts/source_archive.sh [OUTDIR]   (default: the repository root)
# Needs the fetched sources in build/native/_deps/ (run scripts/build_native.sh, or its configure step, first), the
# Fortran libraries in src/third_party/ (run fobis fetch first) and git.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
outdir="$(cd "${1:-$root}" && pwd)"
version="$(tr -d ' \n' < "$root/VERSION")"
name="figure-$version-sources"
deps="$root/build/native/_deps"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT

mkdir -p "$work/$name"
# the tracked files as they are in the tree (in the Sources archive workflow, the tag's checkout: the tag itself)
(cd "$root" && git ls-files -z | tar --null -T - -c) | tar -x -C "$work/$name"
for dep in sdl3 cimplot cimplot3d miniz; do
   [[ -d "$deps/$dep-src" ]] || { echo "source_archive.sh: $deps/$dep-src missing: run scripts/build_native.sh" >&2; exit 1; }
   mkdir -p "$work/$name/third_party/fetched/$dep"
   (cd "$deps/$dep-src" && tar -c --exclude=.git .) | tar -x -C "$work/$name/third_party/fetched/$dep"
done
[[ -f "$root/src/third_party/.deps_config.ini" ]] \
   || { echo "source_archive.sh: src/third_party/ not fetched: run fobis fetch" >&2; exit 1; }
(cd "$root" && tar -c --exclude=.git src/third_party) | tar -x -C "$work/$name"
tar -C "$work" -czf "$outdir/$name.tar.gz" "$name"
echo "source_archive.sh: $outdir/$name.tar.gz ($(du -h "$outdir/$name.tar.gz" | cut -f1))"
