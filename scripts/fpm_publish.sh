#!/usr/bin/env bash
# Publish FIGURE's self-contained fpm package for a release: tag vX.Y.Z-fpm, so that another fpm project can write
#    figure = { git = "https://github.com/szaghi/figure", tag = "vX.Y.Z-fpm" }
#
# The package (scripts/fpm_package.py, sources fetched at their pins) becomes one commit with no parent: the tag
# carries only the package, not the repository's history, and no branch points to it.
#
# Usage: scripts/fpm_publish.sh vX.Y.Z [--remote URL] [--dry-run]
#   (default)     push the tag to this repository's origin (in CI, with the checkout's credentials)
#   --remote URL  push it to URL instead, straight from the package's own repository (this repository's tags are not
#                 touched): a test against a local bare repository, for example
#   --dry-run     write the package commit and stop before pushing; prints where it is
# The commit's author is git's user.name/user.email (in CI: the github-actions bot).
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tag="${1:-}"
[[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "fpm_publish.sh: usage: fpm_publish.sh vX.Y.Z [--remote URL] [--dry-run]" >&2; exit 2; }
shift
remote=""
dry=0
while [[ $# -gt 0 ]]; do
   case "$1" in
      --remote) remote="$2"; shift 2 ;;
      --dry-run) dry=1; shift ;;
      *) echo "fpm_publish.sh: unknown option $1" >&2; exit 2 ;;
   esac
done
fpm_tag="$tag-fpm"
work="$(mktemp -d)"
[[ $dry -eq 1 ]] || trap 'rm -rf "$work"' EXIT
python3 "$root/scripts/fpm_package.py" "$work/package" --version "${tag#v}" --fetch "$work/sources"
source_commit="$(git -C "$root" rev-parse --short=12 HEAD)"
# the package's own repository does not inherit this repository's local config: carry the identity over
name="$(git -C "$root" config user.name || true)"
email="$(git -C "$root" config user.email || true)"
[[ -n "$name" && -n "$email" ]] || { echo "fpm_publish.sh: set git's user.name and user.email (the commit's author)" >&2; exit 1; }
export GIT_AUTHOR_NAME="$name" GIT_AUTHOR_EMAIL="$email" GIT_COMMITTER_NAME="$name" GIT_COMMITTER_EMAIL="$email"
cd "$work/package"
git init --quiet
git checkout --quiet -b fpm-package
git add --all
git -c commit.gpgsign=false commit --quiet -m "figure $tag: self-contained fpm package" \
   -m "Written by scripts/fpm_package.py from $source_commit (tag $tag). Use it as
   figure = { git = \"https://github.com/szaghi/figure\", tag = \"$fpm_tag\" }"
git -c tag.gpgsign=false tag "$fpm_tag"
if [[ $dry -eq 1 ]]; then
   echo "fpm_publish.sh: dry run: tag $fpm_tag in $work/package (not pushed)"
elif [[ -n "$remote" ]]; then
   git push --quiet "$remote" "refs/tags/$fpm_tag"
   echo "fpm_publish.sh: pushed $fpm_tag to $remote"
else
   # through this repository: its origin carries the credentials (actions/checkout sets them up)
   git -C "$root" fetch --quiet "$work/package" "refs/tags/$fpm_tag:refs/tags/$fpm_tag"
   git -C "$root" push --quiet origin "refs/tags/$fpm_tag"
   echo "fpm_publish.sh: pushed $fpm_tag to origin"
fi
