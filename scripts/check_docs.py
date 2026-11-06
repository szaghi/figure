"""Check that the feature map (docs/guide/features.md) lists every public procedure of FIGURE, and that README.md's
example is the compiled one.

The public API is what ``use figure`` and ``use figure_testing`` export: the module procedures and types named in
their ``public`` statements (constants, the ``ImGui*``/``ImPlot*``/``FIG_*``/``ICON_*`` names, are documented by
family), and the type-bound procedures of the public types (``app%init``, ``tex%update``, ...). Each must appear in
the feature map as code (``name`` or ``app%name``). Exits 1 and lists what is missing.

README.md's first ```fortran block must equal docs/examples/src/readme.F90, which docs/examples/build.sh compiles.

Usage: python3 scripts/check_docs.py. Standard library only; run from anywhere.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "src" / "lib"
FEATURES = ROOT / "docs" / "guide" / "features.md"
CONSTANT = re.compile(r"^(ImGui|ImPlot|FIG_|ICON_)")
TYPES = {"app_object": "app", "texture_object": "tex"}  # public types and the variable name the docs use


def public_names(module: Path) -> list[str]:
    """Names in a module's public statements (continuation lines joined)."""
    text = re.sub(r"&\s*\n\s*", " ", module.read_text())
    names: list[str] = []
    for line in text.splitlines():
        m = re.match(r"\s*public\s*::\s*(.*)", line, re.I)
        if m:
            names += [n.strip() for n in m.group(1).split("!")[0].split(",") if n.strip()]
    return names


def type_bound(module: Path, type_name: str) -> list[str]:
    """The public type-bound procedures of a derived type (procedure statements inside its definition)."""
    text = module.read_text()
    m = re.search(rf"type\s*(?:,[^:]*)?::\s*{type_name}\b(.*?)endtype", text, re.S | re.I)
    if not m:
        return []
    return [
        b.group(1)
        for b in re.finditer(r"^\s*procedure[^:]*::\s*(\w+)", m.group(1), re.M | re.I)
        if "private" not in b.group(0).lower()
    ]


def main() -> int:
    """Report public procedures missing from the feature map."""
    doc = FEATURES.read_text()
    code = set(re.findall(r"`([^`]+)`", doc))
    words = {w for c in code for w in re.findall(r"[\w%]+", c)}
    missing: list[str] = []
    for module in ("figure.F90", "figure_testing.F90"):
        for name in public_names(LIB / module):
            if not CONSTANT.match(name) and name not in words:
                missing.append(f"not in docs/guide/features.md: {name} ({module})")
    for type_name, var in TYPES.items():
        for f in LIB.glob("*.F90"):
            for proc in type_bound(f, type_name):
                if f"{var}%{proc}" not in words:
                    missing.append(f"not in docs/guide/features.md: {var}%{proc} ({f.name})")
    readme = (ROOT / "README.md").read_text()
    block = re.search(r"```fortran\n(.*?)```", readme, re.S)
    example = (ROOT / "docs" / "examples" / "src" / "readme.F90").read_text()
    if not block or block.group(1) != example:
        missing.append("README.md: its fortran block differs from docs/examples/src/readme.F90 (the compiled one)")
    for m in missing:
        print(f"check_docs: {m}", file=sys.stderr)
    if not missing:
        print("check_docs: the feature map lists every public procedure; README.md's example is the compiled one")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
