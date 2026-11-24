"""Generate the Fortran code editor's code-point tables from ImGuiColorTextEdit's ``TextEditor.cpp``.

The Fortran path's code editor (``src/paths/fortran/editor/``, szaghi/figure#15 P16) classifies code points as the fork
does (``TextEditor::CodePoint``: letters, numbers, white space, identifier starts and continuations, lower and upper
case, wide glyphs, case mapping), so a word, a column or a case change is the same on both paths. This script copies
the fork's 16-bit range tables (FIGURE builds Dear ImGui with 16-bit ``ImWchar``: the fork's 32-bit tables are compiled
out) into the module ``figure_code_unicode_tables`` (``src/paths/fortran/editor/figure_code_unicode_tables.F90``),
each table a flat ``integer(int32)`` named constant: ``low, high, stride`` per range (``low, high`` for the plain ones,
``low, high, to upper, to lower`` for the case table), in the fork's order.

Usage::

    python3 -I scripts/gen_editor_tables.py          # write the module
    python3 -I scripts/gen_editor_tables.py --check  # exit 1 if the committed module differs

Standard library only (Python >= 3.11).
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "third_party" / "ImGuiColorTextEdit" / "TextEditor.cpp"
OUT = ROOT / "src" / "paths" / "fortran" / "editor" / "figure_code_unicode_tables.F90"
WIDTH = 118
CHUNK = 180  # lines per named constant (the standard's 255 continuation lines)

# (the fork's name, the Fortran name, values per range, what it holds)
TABLES = [
    ("letters16", "LETTERS", 3, "letters (isLetter)"),
    ("lower16", "LOWERS", 3, "lower case letters (isLower)"),
    ("upper16", "UPPERS", 3, "upper case letters (isUpper)"),
    ("numbers16", "NUMBERS", 3, "numbers (isNumber)"),
    ("whitespace16", "WHITESPACES", 3, "white space (isWhiteSpace)"),
    ("xidStart16", "XID_STARTS", 3, "identifier starts (isXidStart)"),
    ("xidContinue16", "XID_CONTINUES", 3, "identifier continuations (isXidContinue)"),
    ("eastAsian16", "EAST_ASIANS", 2, "East Asian code points (isEastAsian)"),
    ("wideGlyph16", "WIDE_GLYPHS", 2, "glyphs two columns wide (getGlyphWidth)"),
    ("case16", "CASES", 4, "case mapping: offsets to upper and to lower case (toUpper, toLower)"),
]


def table(text: str, name: str, per: int) -> list[int]:
    """A table's values, flat, in the fork's order.

    Parameters
    ----------
    text : str
        TextEditor.cpp.
    name : str
        The fork's table name.
    per : int
        Values per range.

    Returns
    -------
    list[int]
        The values.
    """
    match = re.search(r"static \w+ " + re.escape(name) + r"\[\] = \{(.*?)\n\};", text, re.S)
    if match is None:
        raise ValueError(f"TextEditor.cpp: table {name} not found")
    values: list[int] = []
    for entry in re.findall(r"\{([^{}]*)\}", match.group(1)):
        parts = [p.strip() for p in entry.split(",")]
        if len(parts) != per:
            raise ValueError(f"TextEditor.cpp: {name}: {per} values per range expected, got {entry!r}")
        values.extend(int(p, 0) for p in parts)
    return values


def constant(name: str, values: list[int]) -> list[str]:
    """Fortran declarations of a flat table, split in named constants of at most CHUNK lines.

    Parameters
    ----------
    name : str
        The Fortran name.
    values : list[int]
        The values.

    Returns
    -------
    list[str]
        The lines.
    """
    rows: list[str] = []
    row = ""
    for v in values:
        item = f"{v},"
        if len(row) + len(item) + 1 > WIDTH - 10:
            rows.append(row)
            row = ""
        row += (" " if row else "") + item
    rows.append(row)
    chunks = [rows[i : i + CHUNK] for i in range(0, len(rows), CHUNK)]
    out: list[str] = []
    parts = []
    for k, chunk in enumerate(chunks, start=1):
        part = name if len(chunks) == 1 else f"{name}_{k}"
        parts.append(part)
        chunk = [*chunk[:-1], chunk[-1].rstrip(",")]
        out.append(f"integer(int32), parameter :: {part}(*) = [ &")
        out.extend(f"   {r} &" for r in chunk[:-1])
        out.append(f"   {chunk[-1]}]")
    if len(chunks) > 1:
        out.append(f"integer(int32), parameter :: {name}(*) = [{', '.join(parts)}]")
    return out


def generate() -> str:
    """The module's text.

    Returns
    -------
    str
        The module.
    """
    text = SRC.read_text(encoding="utf-8")
    lines = [
        "!< figure_code_unicode_tables, ImGuiColorTextEdit's 16-bit code-point tables (generated: do not edit).",
        "module figure_code_unicode_tables",
        "!< figure_code_unicode_tables, ImGuiColorTextEdit's 16-bit code-point tables (generated: do not edit).",
        "!<",
        "!< Written by scripts/gen_editor_tables.py from third_party/ImGuiColorTextEdit/TextEditor.cpp (szaghi/figure#15",
        "!< P16): each table flat, in the fork's order; per range `low, high, stride` (a code point in the range is in the",
        "!< table when its distance from `low` is a multiple of `stride`), `low, high`, or `low, high, to upper, to lower`",
        "!< (offsets added to the code point; 0 none, 65535 the fork's alternate case). Read by figure_code_unicode.",
        "use, intrinsic :: iso_fortran_env, only : int32",
        "",
        "implicit none",
        "private",
        "public :: " + ", ".join(t[1] for t in TABLES),
        "",
    ]
    for fork, name, per, what in TABLES:
        values = table(text, fork, per)
        lines.append(f"!< {what}: the fork's {fork}, {len(values) // per} ranges.")
        lines.extend(constant(name, values))
        lines.append("")
    lines.append("endmodule figure_code_unicode_tables")
    return "\n".join(lines) + "\n"


def main() -> int:
    """Write or check the module.

    Returns
    -------
    int
        Exit status.
    """
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="exit 1 if the committed module differs")
    args = parser.parse_args()
    text = generate()
    if args.check:
        if not OUT.is_file() or OUT.read_text(encoding="utf-8") != text:
            print(f"gen_editor_tables: {OUT.relative_to(ROOT)} is not current: run python3 scripts/gen_editor_tables.py",
                  file=sys.stderr)
            return 1
        print("gen_editor_tables: the code-point tables are current")
        return 0
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text, encoding="utf-8")
    print(f"gen_editor_tables: wrote {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
