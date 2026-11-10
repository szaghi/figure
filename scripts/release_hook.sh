#!/usr/bin/env bash
# FIGURE's release hook, run by scripts/release.sh (the FoBiS scaffold's): the docs' version strings (the status lines,
# the fpm tags, the roadmap's section; scripts/check_docs.py, VERSIONED) follow the release.
#   release_hook.sh --check vX.Y.Z   can they be written? (the roadmap needs '## vX.Y.Z — in progress')
#   release_hook.sh vX.Y.Z           write them; print the files changed (committed with the release)
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
if [[ "${1:-}" == --check ]]; then
   python3 scripts/check_docs.py --bump "${2:?usage: release_hook.sh --check vX.Y.Z}" --dry-run > /dev/null
else
   python3 scripts/check_docs.py --bump "${1:?usage: release_hook.sh vX.Y.Z}"
fi
