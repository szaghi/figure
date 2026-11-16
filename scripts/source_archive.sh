#!/usr/bin/env bash
# Write figure-<version>-sources.tar.gz: FIGURE's tracked files and every source its native build would download (SDL3,
# cimplot, cimplot3d, miniz) under third_party/fetched/, so that a machine with no network (a cluster's node) builds it:
# scripts/build_native.sh finds third_party/fetched/ and downloads nothing; scripts/install.sh --source <unpacked tree>
# installs it (FoBiS must be installed there).
#
# Usage: scripts/source_archive.sh [OUTDIR]   (default: the repository root)
# Needs the fetched sources in build/native/_deps/ (run scripts/build_native.sh, or its configure step, first) and git.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
outdir="$(cd "${1:-$root}" && pwd)"
version="$(tr -d ' \n' < "$root/VERSION")"
name="figure-$version-sources"
deps="$root/build/native/_deps"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT

mkdir -p "$work/$name"
# the tracked files as they are in the tree (in the release workflow, the tag's checkout: the tag itself)
(cd "$root" && git ls-files -z | tar --null -T - -c) | tar -x -C "$work/$name"
for dep in sdl3 cimplot cimplot3d miniz; do
   [[ -d "$deps/$dep-src" ]] || { echo "source_archive.sh: $deps/$dep-src missing: run scripts/build_native.sh" >&2; exit 1; }
   mkdir -p "$work/$name/third_party/fetched/$dep"
   (cd "$deps/$dep-src" && tar -c --exclude=.git .) | tar -x -C "$work/$name/third_party/fetched/$dep"
done
tar -C "$work" -czf "$outdir/$name.tar.gz" "$name"
echo "source_archive.sh: $outdir/$name.tar.gz ($(du -h "$outdir/$name.tar.gz" | cut -f1))"
