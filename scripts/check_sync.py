"""Check that fobos (the primary build) and fpm.toml describe the same FIGURE build.

Checked:
  - the native link libraries: fobos ``$NATIVE_LIBS`` == fpm.toml ``[build] link`` (same order);
  - every program under src/examples/ and src/tests/ is declared in fpm.toml (fobos discovers them by itself);
  - every program declared in fpm.toml exists.

Exit status 0 when in sync, 1 otherwise (each discrepancy printed). Standard library only (Python >= 3.11).
"""

from __future__ import annotations

import configparser
import re
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROGRAM_RE = re.compile(r"^\s*program\s+\w+", re.IGNORECASE | re.MULTILINE)


def fobos_native_libs(fobos: Path) -> list[str]:
    """Return the ``$NATIVE_LIBS`` list of the fobos file.

    Parameters
    ----------
    fobos : Path
        The fobos file.

    Returns
    -------
    list[str]
        Library names, in link order.
    """
    parser = configparser.ConfigParser(interpolation=None)
    parser.optionxform = str  # keep the case of the keys
    parser.read(fobos)
    for section in parser.sections():
        if "$NATIVE_LIBS" in parser[section]:
            return parser[section]["$NATIVE_LIBS"].split()
    return []


def program_sources(*dirs: Path) -> set[str]:
    """Return the sources (relative to the root) under ``dirs`` that contain a main program.

    Parameters
    ----------
    *dirs : Path
        Directories to scan.

    Returns
    -------
    set[str]
        POSIX paths relative to the repository root.
    """
    found: set[str] = set()
    for d in dirs:
        for f in sorted(d.glob("*.[Ff]90")):
            if PROGRAM_RE.search(f.read_text(encoding="utf-8", errors="replace")):
                found.add(f.relative_to(ROOT).as_posix())
    return found


def fpm_programs(manifest: dict) -> set[str]:
    """Return the example and test program sources declared in fpm.toml.

    Parameters
    ----------
    manifest : dict
        The parsed fpm.toml.

    Returns
    -------
    set[str]
        POSIX paths relative to the repository root.
    """
    declared: set[str] = set()
    for kind in ("example", "test", "executable"):
        for entry in manifest.get(kind, []):
            declared.add(f"{entry['source-dir']}/{entry['main']}")
    return declared


def main() -> int:
    """Run the checks.

    Returns
    -------
    int
        Exit status: 0 in sync, 1 otherwise.
    """
    errors: list[str] = []
    manifest = tomllib.loads((ROOT / "fpm.toml").read_text(encoding="utf-8"))

    fobos_libs = fobos_native_libs(ROOT / "fobos")
    fpm_libs = manifest.get("build", {}).get("link", [])
    if fobos_libs != fpm_libs:
        errors.append(
            f"link libraries differ: fobos $NATIVE_LIBS={fobos_libs} fpm.toml [build] link={fpm_libs}"
        )

    on_disk = program_sources(ROOT / "src" / "examples", ROOT / "src" / "tests")
    declared = fpm_programs(manifest)
    errors.extend(
        f"program not declared in fpm.toml: {p}" for p in sorted(on_disk - declared)
    )
    errors.extend(
        f"fpm.toml declares a missing program: {p}" for p in sorted(declared - on_disk)
    )

    for e in errors:
        print(f"check_sync: {e}", file=sys.stderr)
    if not errors:
        print("check_sync: fobos and fpm.toml are in sync")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
