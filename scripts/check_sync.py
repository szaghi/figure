"""Check that fobos (the primary build) and fpm.toml describe the same FIGURE build, and print link flags for fpm.

Checked:
  - fpm.toml ``[build] link`` is the platform-independent part of the native link line: ``figure_native SDL3``;
  - every fobos platform varset (``[varset:linux|macos|windows]``) starts its ``$NATIVE_LIBS`` with those two;
  - the varset of the platform this runs on covers the static link line SDL reports for it
    (``lib/pkgconfig/sdl3.pc``, written by the native build): every ``-l`` library and every framework (checked only
    when the native layer is built);
  - every program under src/examples/ and src/tests/ is declared in fpm.toml (fobos discovers them by itself);
  - every program declared in fpm.toml exists.

``--link-flags [PLATFORM]`` prints instead the platform's native link line: the varset's ``$NATIVE_LIBS`` as ``-l``
options, in order (``figure_native SDL3`` first), then its ``$NATIVE_LFLAGS``, for scripts/fpm.sh and for linking a
program by hand. PLATFORM defaults to the current one.

Exit status 0 when in sync, 1 otherwise (each discrepancy printed). Standard library only (Python >= 3.11).
"""

from __future__ import annotations

import argparse
import configparser
import re
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROGRAM_RE = re.compile(r"^\s*program\s+\w+", re.IGNORECASE | re.MULTILINE)
COMMON_LIBS = ["figure_native", "SDL3"]
PLATFORMS = ("linux", "macos", "windows")


def current_platform() -> str:
    """Return the platform name of the fobos varsets for the running system.

    Returns
    -------
    str
        ``linux``, ``macos`` or ``windows``.
    """
    if sys.platform == "darwin":
        return "macos"
    if sys.platform in ("win32", "cygwin", "msys"):
        return "windows"
    return "linux"


def fobos_varsets(fobos: Path) -> dict[str, dict[str, list[str]]]:
    """Return the native link settings of each platform varset of the fobos file.

    Parameters
    ----------
    fobos : Path
        The fobos file.

    Returns
    -------
    dict[str, dict[str, list[str]]]
        Platform -> ``{"libs": [...], "lflags": [...]}``.
    """
    parser = configparser.ConfigParser(interpolation=None)
    parser.optionxform = str  # keep the case of the keys
    parser.read(fobos)
    varsets: dict[str, dict[str, list[str]]] = {}
    for platform in PLATFORMS:
        section = f"varset:{platform}"
        if parser.has_section(section):
            varsets[platform] = {
                "libs": parser[section].get("$NATIVE_LIBS", "").split(),
                "lflags": parser[section].get("$NATIVE_LFLAGS", "").split(),
            }
    return varsets


def sdl_static_link(pc: Path) -> tuple[set[str], set[str]]:
    """Return the libraries and frameworks of SDL's static link line.

    Parameters
    ----------
    pc : Path
        SDL's pkg-config file (``lib/pkgconfig/sdl3.pc``).

    Returns
    -------
    tuple[set[str], set[str]]
        Library names (``-lX``, ``-pthread`` as ``pthread``) and framework names.
    """
    tokens: list[str] = []
    for line in pc.read_text(encoding="utf-8").splitlines():
        if line.startswith(("Libs:", "Libs.private:")):
            tokens += line.split(":", 1)[1].split()
    libs: set[str] = set()
    frameworks: set[str] = set()
    for i, tok in enumerate(tokens):
        if tok.startswith("-l"):
            libs.add(tok[2:])
        elif tok == "-pthread":
            libs.add("pthread")
        elif tok.startswith(("-Wl,-framework,", "-Wl,-weak_framework,")):
            frameworks.add(tok.rsplit(",", 1)[1])
        elif tok in ("-framework", "-weak_framework") and i + 1 < len(tokens):
            frameworks.add(tokens[i + 1])
    return libs, frameworks


def frameworks_of(lflags: list[str]) -> set[str]:
    """Return the frameworks named in linker flags (``-framework X``)."""
    return {
        lflags[i + 1]
        for i, f in enumerate(lflags[:-1])
        if f in ("-framework", "-weak_framework")
    }


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


def link_flags(platform: str) -> int:
    """Print the platform's native link line (``$NATIVE_LIBS`` as ``-l`` options, then ``$NATIVE_LFLAGS``).

    Parameters
    ----------
    platform : str
        Platform name of the varset.

    Returns
    -------
    int
        Exit status: 0, or 1 if the fobos file has no varset for the platform.
    """
    varsets = fobos_varsets(ROOT / "fobos")
    if platform not in varsets:
        print(f"check_sync: fobos has no [varset:{platform}]", file=sys.stderr)
        return 1
    v = varsets[platform]
    # the whole line, figure_native and SDL3 first: fpm places --link-flag before its own [build] link libraries,
    # and GNU ld resolves static archives (Windows import libraries too) left to right
    print(" ".join([f"-l{lib}" for lib in v["libs"]] + v["lflags"]))
    return 0


def check() -> int:
    """Run the checks.

    Returns
    -------
    int
        Exit status: 0 in sync, 1 otherwise.
    """
    errors: list[str] = []
    manifest = tomllib.loads((ROOT / "fpm.toml").read_text(encoding="utf-8"))

    fpm_libs = manifest.get("build", {}).get("link", [])
    if fpm_libs != COMMON_LIBS:
        errors.append(f"fpm.toml [build] link must be {COMMON_LIBS}, it is {fpm_libs}")
    varsets = fobos_varsets(ROOT / "fobos")
    for platform in PLATFORMS:
        if platform not in varsets:
            errors.append(f"fobos has no [varset:{platform}]")
        elif varsets[platform]["libs"][:2] != COMMON_LIBS:
            errors.append(
                f"fobos [varset:{platform}] $NATIVE_LIBS must start with {' '.join(COMMON_LIBS)}"
            )

    platform = current_platform()
    pc = ROOT / "lib" / "pkgconfig" / "sdl3.pc"
    if pc.exists() and platform in varsets:
        libs, frameworks = sdl_static_link(pc)
        missing_libs = sorted(libs - set(varsets[platform]["libs"]))
        missing_fw = sorted(frameworks - frameworks_of(varsets[platform]["lflags"]))
        if missing_libs:
            errors.append(
                f"[varset:{platform}] $NATIVE_LIBS lacks {missing_libs}, needed by SDL ({pc.name})"
            )
        if missing_fw:
            errors.append(
                f"[varset:{platform}] $NATIVE_LFLAGS lacks frameworks {missing_fw}, needed by SDL"
            )
    else:
        print(
            f"check_sync: {pc.relative_to(ROOT)} not built: the {platform} link line is not checked against SDL"
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
        print(
            f"check_sync: fobos and fpm.toml are in sync ({platform} link line covers SDL's)"
        )
    return 1 if errors else 0


def main(argv: list[str]) -> int:
    """Check, or print the link flags of a platform.

    Parameters
    ----------
    argv : list[str]
        Arguments, without the script name.

    Returns
    -------
    int
        Exit status.
    """
    parser = argparse.ArgumentParser(
        description="Check fobos/fpm.toml sync; print fpm link flags."
    )
    parser.add_argument(
        "--link-flags",
        nargs="?",
        const="",
        metavar="PLATFORM",
        help="print the extra linker flags of a platform varset (default: the current platform)",
    )
    args = parser.parse_args(argv)
    if args.link_flags is not None:
        return link_flags(args.link_flags or current_platform())
    return check()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
