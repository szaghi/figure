"""Write the Fortran path's ``figure_editor`` from the current path's, over the Fortran code editor.

The public API of the code editor and the diff (``code_editor_object``, ``language_object``, ``code_language``,
``code_diff``, ``code_diff_lines``: ``src/lib/figure_editor.F90``) is a thin layer over the native glue's entry points
(``fig_editor_*``, ``fig_code_diff*``, ``native/figure_editor.cpp``). The Fortran code editor
(``src/paths/fortran/editor/``, szaghi/figure#15 P16) gives the same entry points as Fortran module procedures
(``figure_code_editor``, ``figure_code_diff``), so the Fortran path's module is the current path's with its interface
block replaced by ``use`` statements of those modules: this script writes it, so the two never differ in an argument
check, a status, a message or a doc comment.

Until the switch of the editor's seam the module is written as ``figure_editor_fortran``
(``src/tests/fortran/figure_editor_fortran.F90``), which the side-by-side tests use beside ``figure_editor`` (the
C++).

Usage::

    python3 -I scripts/gen_editor_path.py          # write the module
    python3 -I scripts/gen_editor_path.py --check  # exit 1 if the committed module differs

Standard library only (Python >= 3.11).
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "src" / "lib" / "figure_editor.F90"
MODULE = "figure_editor_fortran"
TARGET = ROOT / "src" / "tests" / "fortran" / f"{MODULE}.F90"
HEAD = (
    "!< The editor is ImGuiColorTextEdit (the goossens fork, MIT, vendored in third_party/ImGuiColorTextEdit) with FIGURE's\n"
    "!< own glue (native/figure_editor.cpp): it draws through Dear ImGui only, so window, headless and remote modes show the\n"
    "!< same pixels. Text is UTF-8; lines and columns are numbered from 1, columns in characters. Everything is polled:\n"
)
NEW_HEAD = (
    "!< On the Fortran path (szaghi/figure#15 P16) the editor and the diff are Fortran, the fork's TextEditor and dtl and\n"
    "!< FIGURE's glue ported (src/paths/fortran/editor/): window, headless and remote modes show the same pixels. Written\n"
    "!< by scripts/gen_editor_path.py from the current path's module: do not edit.\n"
    "!< Text is UTF-8; lines and columns are numbered from 1, columns in characters. Everything is polled:\n"
)
USE_AFTER = "use figure_c_native, only : FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_OK\n"


def uses(names: list[str]) -> str:
    """The ``use`` statements of the Fortran entry points.

    Parameters
    ----------
    names : list[str]
        The interface block's procedures.

    Returns
    -------
    str
        The statements, wrapped at 120 columns.
    """
    out = []
    view = ("fig_editor_draw", "fig_editor_line_rect")
    for module, group in (
        ("figure_code_editor", [n for n in names if not n.startswith("fig_code_diff") and n not in view]),
        ("figure_code_view", [n for n in names if n in view]),
        ("figure_code_diff", [n for n in names if n.startswith("fig_code_diff")]),
    ):
        head = f"use {module}, only : "
        line = head
        lines = []
        for k, name in enumerate(group):
            item = name + (", " if k < len(group) - 1 else "")
            if len(line) + len(item) > 116:
                lines.append(line.rstrip() + " &")
                line = " " * len(head)
            line += item
        lines.append(line)
        out.append("\n".join(lines))
    return "\n".join(out) + "\n"


def generate() -> str:
    """The Fortran path's module text.

    Returns
    -------
    str
        The module.
    """
    text = SOURCE.read_text(encoding="utf-8")
    if HEAD not in text:
        raise ValueError(f"{SOURCE.relative_to(ROOT)}: the header paragraph changed: update gen_editor_path.py")
    text = text.replace(HEAD, NEW_HEAD)
    block = re.search(r"\ninterface\n(.*?)\nendinterface\n", text, re.S)
    if block is None:
        raise ValueError(f"{SOURCE.relative_to(ROOT)}: no interface block")
    names = re.findall(r"^\s*(?:function|subroutine)\s+(\w+)\s*\(", block.group(1), re.M)
    text = text[: block.start()] + "\n" + text[block.end() :]
    if USE_AFTER not in text:
        raise ValueError(f"{SOURCE.relative_to(ROOT)}: the figure_c_native use changed: update gen_editor_path.py")
    text = text.replace(USE_AFTER, USE_AFTER + uses(names))
    text = text.replace("\nmodule figure_editor\n", f"\nmodule {MODULE}\n")
    text = text.replace("\nendmodule figure_editor\n", f"\nendmodule {MODULE}\n")
    text = text.replace("!< figure_editor, ", f"!< {MODULE}, ")
    return text


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
        if not TARGET.is_file() or TARGET.read_text(encoding="utf-8") != text:
            print(f"gen_editor_path: {TARGET.relative_to(ROOT)} is not current: run python3 scripts/gen_editor_path.py",
                  file=sys.stderr)
            return 1
        print("gen_editor_path: the Fortran path's figure_editor is current")
        return 0
    TARGET.write_text(text, encoding="utf-8")
    print(f"gen_editor_path: wrote {TARGET.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
