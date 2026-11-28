"""Check that the Fortran path's programs link none of the C++ libraries above Dear ImGui (szaghi/figure#15 G2).

The Fortran path (the ``-fortran`` modes of fobos) draws its plots, 3-D plots, gizmos, gradient editor and code editor
in Fortran; its programs must link Dear ImGui, SDL3, the backends and FIGURE's own native glue only. This check reads
the symbols each program defines (``nm --defined-only``) and fails on any that one of these libraries defines in the
native archive (``lib/libfigure_native.a``, its members' global text and data symbols; weak symbols, which template
instantiations share, are left out):

  - ImPlot: ``implot.cpp.o``, ``implot_items.cpp.o``, ``implot_demo.cpp.o``, ``cimplot.cpp.o``;
  - ImPlot3D: ``implot3d.cpp.o``, ``implot3d_items.cpp.o``, ``implot3d_meshes.cpp.o``, ``implot3d_demo.cpp.o``,
    ``cimplot3d.cpp.o``;
  - ImGuizmo: ``ImGuizmo.cpp.o``; ImGradient: ``ImGradient.cpp.o``;
  - TextEditor (ImGuiColorTextEdit): ``TextEditor.cpp.o``, ``TextDiff.cpp.o``.

The only programs allowed to link some are the side-by-side tests of ``src/tests/fortran``, whose oracle is the C++
library itself, through a reference module (the current path's module under another name). A program is exempt by
the reference modules its source uses, and only for the libraries each one needs:

  - ``figure_implot_ref``: ImPlot, ImPlot3D (the plot side makes both contexts) and ImGradient (its ``ip_colormap``
    and ``ig_gradient_edit`` live in figure_colormap.cpp, beside the C++ gradient editor);
  - ``figure_implot3d_ref``: ImPlot3D, and ImPlot (the plot side, which makes ImPlot3D's context);
  - ``figure_view3d_gizmos_ref``: ImGuizmo;
  - ``figure_editor_ref``: TextEditor;
  - ``figure_markdown_ref``: none of them (imgui_rich_md is not checked here).

Usage::

    python3 scripts/check_fortran_path_symbols.py [DIR_OR_PROGRAM ...]   # default: exe and exe/examples
    python3 scripts/check_fortran_path_symbols.py --self-test

Run it after building a ``-fortran`` mode (``tests-gnu-fortran``, ``examples-gnu-fortran``, ...): a directory is
scanned for executable files (not recursively). Exit status 0 when every program is clean or exempt, 1 otherwise (each
program and the libraries it links printed), 2 when nothing was checked or the archive is missing. ``--self-test`` runs
the decisions on built-in symbol tables. Standard library only (Python >= 3.11).
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ARCHIVE = ROOT / "lib" / "libfigure_native.a"
SOURCES = ("src/tests", "src/examples", "docs/examples/src")  # where a program's source is found by its name
LIBRARIES: dict[str, tuple[str, ...]] = {
    "ImPlot": ("implot.cpp.o", "implot_items.cpp.o", "implot_demo.cpp.o", "cimplot.cpp.o"),
    "ImPlot3D": ("implot3d.cpp.o", "implot3d_items.cpp.o", "implot3d_meshes.cpp.o", "implot3d_demo.cpp.o",
                 "cimplot3d.cpp.o"),
    "ImGuizmo": ("ImGuizmo.cpp.o",),
    "ImGradient": ("ImGradient.cpp.o",),
    "TextEditor": ("TextEditor.cpp.o", "TextDiff.cpp.o"),
}
# reference module -> the libraries a side-by-side test using it may link (the module docstring gives the reasons)
REFERENCES: dict[str, frozenset[str]] = {
    "figure_implot_ref": frozenset({"ImPlot", "ImPlot3D", "ImGradient"}),
    "figure_implot3d_ref": frozenset({"ImPlot", "ImPlot3D"}),
    "figure_view3d_gizmos_ref": frozenset({"ImGuizmo"}),
    "figure_editor_ref": frozenset({"TextEditor"}),
    "figure_markdown_ref": frozenset(),
}
GLOBAL = set("TDBR")  # nm's global text, data, bss, read-only data
PROGRAM = re.compile(r"^\s*program\s+(\w+)", re.I | re.M)
USE = re.compile(r"^\s*use\s*(?:,\s*\w+\s*)?(?:::)?\s*(\w+)", re.I | re.M)


def owners(archive_nm: str) -> dict[str, str]:
    """Symbol -> library, from ``nm --defined-only -A`` of the archive (``archive:member:value type name``)."""
    member_lib = {m: lib for lib, members in LIBRARIES.items() for m in members}
    out: dict[str, str] = {}
    for line in archive_nm.splitlines():
        head, _, rest = line.rpartition(":")
        member = head.rpartition(":")[2] if head else ""
        fields = rest.split()
        if len(fields) != 3 or fields[1] not in GLOBAL or member not in member_lib:
            continue
        out[fields[2]] = member_lib[member]
    return out


def linked(program_nm: str, symbol_owner: dict[str, str]) -> set[str]:
    """The libraries a program's defined symbols (``nm --defined-only`` of it) come from."""
    found: set[str] = set()
    for line in program_nm.splitlines():
        fields = line.split()
        if len(fields) == 3 and fields[2] in symbol_owner:
            found.add(symbol_owner[fields[2]])
    return found


def allowed(uses: set[str]) -> frozenset[str]:
    """The libraries a program may link, by the reference modules it uses (none for any other program)."""
    out: set[str] = set()
    for module in uses:
        out |= REFERENCES.get(module.lower(), frozenset())
    return frozenset(out)


def verdict(name: str, libs: set[str], uses: set[str]) -> str | None:
    """None for a clean or exempt program, else the message."""
    extra = libs - allowed(uses)
    if not extra:
        return None
    refs = sorted(m for m in uses if m.lower() in REFERENCES)
    why = f" (its references {', '.join(refs)} allow {', '.join(sorted(allowed(uses))) or 'none'})" if refs else ""
    return f"{name}: links {', '.join(sorted(extra))}{why}"


def program_uses() -> dict[str, set[str]]:
    """Program name -> the modules its source file uses (the program's file and its other program units)."""
    out: dict[str, set[str]] = {}
    for where in SOURCES:
        for path in sorted((ROOT / where).rglob("*.F90")):
            text = path.read_text(errors="replace")
            for name in PROGRAM.findall(text):
                out[name.lower()] = {m.lower() for m in USE.findall(text)}
    return out


def nm(path: Path) -> str:
    """``nm --defined-only`` of a file (``-A`` for an archive)."""
    args = ["nm", "--defined-only"] + (["-A"] if path.suffix == ".a" else []) + [str(path)]
    return subprocess.run(args, capture_output=True, text=True, check=False).stdout


def programs(targets: list[str]) -> list[Path]:
    """The executables named, or found in the directories named (not recursively)."""
    out: list[Path] = []
    for t in targets:
        p = Path(t)
        if p.is_dir():
            out += sorted(c for c in p.iterdir() if c.is_file() and os.access(c, os.X_OK) and c.suffix == "")
        elif p.is_file():
            out.append(p)
    return out


def self_test() -> int:
    """The decisions on built-in tables."""
    archive = "\n".join([
        "lib/libfigure_native.a:implot.cpp.o:0000000000000010 T _ZN6ImPlot10CreateContextEv",
        "lib/libfigure_native.a:implot.cpp.o:0000000000000020 W _ZN6ImVec2C2Ev",
        "lib/libfigure_native.a:implot.cpp.o:0000000000000030 t _ZL5local",
        "lib/libfigure_native.a:implot3d.cpp.o:0000000000000010 T _ZN8ImPlot3D10CreateContextEv",
        "lib/libfigure_native.a:ImGuizmo.cpp.o:0000000000000010 T _ZN8ImGuizmo10ManipulateEv",
        "lib/libfigure_native.a:ImGradient.cpp.o:0000000000000010 T _ZN10ImGradient4EditEv",
        "lib/libfigure_native.a:TextEditor.cpp.o:0000000000000010 T _ZN10TextEditor6RenderEv",
        "lib/libfigure_native.a:imgui.cpp.o:0000000000000010 T _ZN5ImGui5BeginEv",
        "lib/libfigure_native.a:figure_native.cpp.o:0000000000000010 T fig_init",
    ])
    own = owners(archive)
    cases = [  # (what, program symbols, uses, expect a failure)
        ("a clean program", "0 T _ZN5ImGui5BeginEv\n0 T fig_init", set(), False),
        ("weak and local symbols are not ImPlot's", "0 W _ZN6ImVec2C2Ev\n0 t _ZL5local", set(), False),
        ("ImPlot in a program of the path", "0 T _ZN6ImPlot10CreateContextEv", set(), True),
        ("TextEditor in a program of the path", "0 T _ZN10TextEditor6RenderEv", {"figure"}, True),
        ("ImPlot, ImPlot3D, ImGradient by figure_implot_ref",
         "0 T _ZN6ImPlot10CreateContextEv\n0 T _ZN8ImPlot3D10CreateContextEv\n0 T _ZN10ImGradient4EditEv",
         {"figure_implot_ref"}, False),
        ("ImGuizmo is not figure_implot_ref's", "0 T _ZN8ImGuizmo10ManipulateEv", {"figure_implot_ref"}, True),
        ("ImPlot by figure_implot3d_ref", "0 T _ZN6ImPlot10CreateContextEv", {"figure_implot3d_ref"}, False),
        ("ImGradient is not figure_implot3d_ref's", "0 T _ZN10ImGradient4EditEv", {"figure_implot3d_ref"}, True),
        ("ImGuizmo by figure_view3d_gizmos_ref", "0 T _ZN8ImGuizmo10ManipulateEv", {"figure_view3d_gizmos_ref"},
         False),
        ("TextEditor by figure_editor_ref", "0 T _ZN10TextEditor6RenderEv", {"figure_editor_ref"}, False),
        ("figure_markdown_ref allows none", "0 T _ZN6ImPlot10CreateContextEv", {"figure_markdown_ref"}, True),
        ("references add up", "0 T _ZN8ImGuizmo10ManipulateEv\n0 T _ZN6ImPlot10CreateContextEv",
         {"figure_implot_ref", "figure_view3d_gizmos_ref"}, False),
    ]
    failed = 0
    for what, syms, uses, expect in cases:
        got = verdict("p", linked(syms, own), uses) is not None
        ok = got == expect
        failed += not ok
        print(f"{'ok' if ok else 'FAIL'}: {what}: expected {'a failure' if expect else 'clean'}, "
              f"got {'a failure' if got else 'clean'}")
    sym_table = {"_ZN6ImPlot10CreateContextEv", "_ZN8ImPlot3D10CreateContextEv", "_ZN8ImGuizmo10ManipulateEv",
                 "_ZN10ImGradient4EditEv", "_ZN10TextEditor6RenderEv"}
    ok = set(own) == sym_table
    failed += not ok
    print(f"{'ok' if ok else 'FAIL'}: the archive's table holds the five libraries' global symbols only")
    uses = {m.lower() for m in USE.findall("use, intrinsic :: iso_c_binding\nuse figure_implot_ref, only : ip_line\n"
                                           "   use figure_editor_ref\n")}
    ok = uses == {"iso_c_binding", "figure_implot_ref", "figure_editor_ref"}
    failed += not ok
    print(f"{'ok' if ok else 'FAIL'}: a source's modules read ({sorted(uses)})")
    print(f"check_fortran_path_symbols --self-test: {'all passed' if not failed else f'{failed} failed'}")
    return 1 if failed else 0


def main(argv: list[str]) -> int:
    """Check the programs named (or found in the directories named)."""
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("targets", nargs="*", help="programs, or directories of programs (default: exe exe/examples)")
    ap.add_argument("--archive", default=str(ARCHIVE), help="the native archive (default: lib/libfigure_native.a)")
    ap.add_argument("--self-test", action="store_true", help="run the decisions on built-in tables, check nothing")
    args = ap.parse_args(argv)
    if args.self_test:
        return self_test()
    archive = Path(args.archive)
    if not archive.is_file():
        print(f"check_fortran_path_symbols: no archive {archive} (scripts/build_native.sh)", file=sys.stderr)
        return 2
    own = owners(nm(archive))
    found = programs(args.targets or [str(ROOT / "exe"), str(ROOT / "exe" / "examples")])
    if not found or not own:
        print("check_fortran_path_symbols: nothing to check (build a -fortran mode first)", file=sys.stderr)
        return 2
    sources = program_uses()
    problems: list[str] = []
    exempt = 0
    for p in found:
        uses = sources.get(p.name.lower(), set())
        libs = linked(nm(p), own)
        message = verdict(p.name, libs, uses)
        if message:
            problems.append(message)
        elif libs:
            exempt += 1
    for m in problems:
        print(f"check_fortran_path_symbols: {m}", file=sys.stderr)
    if not problems:
        print(f"check_fortran_path_symbols: {len(found)} programs, {len(found) - exempt} link none of ImPlot, "
              f"ImPlot3D, ImGuizmo, ImGradient, TextEditor; {exempt} side-by-side tests link their references' only")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
