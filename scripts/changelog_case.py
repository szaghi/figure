"""Give CHANGELOG.md's entries back the case of their first word where it is a name written in lower case.

git-cliff (cliff.toml, the FoBiS scaffold's, not edited here) capitalises each entry's first letter (``upper_first``):
a subject starting with a version, a compiler, a file or a Fortran name comes out as "V0.7.0's pictures", "Nvfortran's
internal error", "Release.yml", "Ig_shortcut". scripts/release_hook.sh runs this after git-cliff has written the file.

    python3 scripts/changelog_case.py [FILE]    rewrite FILE (default CHANGELOG.md); print it when it changed
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ENTRY = re.compile(r"^(- (?:\*\*[^*]+\*\*: )?)(\S+)(.*)$")  # "- [**scope**: ]First rest"
LOWER = {"nvfortran", "gfortran", "ifx", "fpm", "cimgui", "cimplot", "md4c", "llvmpipe"}  # names written lower case


def lowered(word: str) -> bool:
    """Whether `word`, an entry's capitalised first word, is a name written in lower case."""
    token = re.split(r"['’,:;]", word, maxsplit=1)[0]  # "Nvfortran's" -> "Nvfortran"
    if re.match(r"V\d", token):
        return True  # v0.7.0
    if len(token) < 2 or not token[0].isupper() or not any(c.islower() for c in token[1:]):
        return False  # "A", "FIGURE_DEBUG_WAKE", "C++17": as written
    if token.lower() in LOWER:
        return True
    return any(c in token for c in "_.=%") and token[1:].lower() == token[1:]  # ig_shortcut, release.yml, prefer=


def fix(text: str) -> str:
    """The changelog `text` with the first word of each entry lowered where `lowered` says so."""
    out = []
    for line in text.splitlines(keepends=True):
        m = ENTRY.match(line)
        if m and lowered(m.group(2)):
            line = m.group(1) + m.group(2)[0].lower() + m.group(2)[1:] + m.group(3) + line[len(line.rstrip("\n")) :]
        out.append(line)
    return "".join(out)


def main(argv: list[str]) -> int:
    """Rewrite the changelog in place; print its path when it changed."""
    path = Path(argv[0] if argv else "CHANGELOG.md")
    text = path.read_text(encoding="utf-8")
    new = fix(text)
    if new != text:
        path.write_text(new, encoding="utf-8")
        print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
