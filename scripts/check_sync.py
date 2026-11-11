"""Check that fobos (the primary build) and fpm.toml describe the same FIGURE build, and print link flags for fpm.

Checked:
  - fpm.toml ``[build] link`` is the platform-independent part of the native link line: ``figure_native SDL3``;
  - every fobos platform varset (``[varset:linux|macos|windows]``) starts its ``$NATIVE_LIBS`` with those two;
  - the varset of the platform this runs on covers the static link line SDL reports for it
    (``lib/pkgconfig/sdl3.pc``, written by the native build): every ``-l`` library and every framework (checked only
    when the native layer is built);
  - every program under src/examples/ and src/tests/ is declared in fpm.toml (fobos discovers them by itself);
  - every program declared in fpm.toml exists;
  - the static-library modes (``figure-static-*``) build from ``src/lib/figure_library.F90``, which uses every public
    module (``figure``, ``figure_testing``): FoBiS archives a target and what it uses, so a module left out of that
    root is missing from ``lib/libfigure.a`` and ``lib/mod`` (what ``fobis fetch`` gives a downstream project).

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
FPM_LINK = [*COMMON_LIBS, "figure_platform"]  # fpm.toml [build] link: see fpm_link
PLATFORMS = ("linux", "macos", "windows")
LIBRARY_ROOT = "src/lib/figure_library.F90"
PUBLIC_MODULES = ("figure", "figure_testing")
USE_RE = re.compile(r"^\s*use\s+(\w+)", re.IGNORECASE | re.MULTILINE)


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
    print(" ".join([f"-l{lib}" for lib in v["libs"]] + v["lflags"]))
    return 0


def fpm_link(platform: str) -> int:
    """Prepare fpm's link: write ``lib/libfigure_platform.a`` where needed and print the ``--link-flag`` value.

    fpm places ``--link-flag`` before the object files and its ``[build] link`` libraries after them; GNU ld scans
    each archive once, left to right, so archives given before the objects (the C++ runtime and Windows' import
    libraries) resolve nothing. fpm.toml therefore links ``figure_platform`` last, and with GNU ld (Linux, Windows)
    ``lib/libfigure_platform.a`` is an implicit linker script, ``INPUT(-l...)``, adding the platform's libraries
    there. ld64 (macOS) reads no linker scripts but does not depend on order: there the native build installs a
    real ``libfigure_platform.a`` and the platform's libraries and frameworks go in ``--link-flag``.

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
    extra = [f"-l{lib}" for lib in v["libs"] if lib not in COMMON_LIBS]
    if platform == "macos":
        print(" ".join(extra + v["lflags"]))
        return 0
    script = ROOT / "lib" / "libfigure_platform.a"
    text = (
        f"/* GNU ld implicit linker script, written by scripts/check_sync.py from fobos [varset:{platform}] */\n"
        f"INPUT({' '.join(extra)})\n"
    )
    if (
        not script.exists()
        or script.read_text(encoding="utf-8", errors="replace") != text
    ):
        script.write_text(text, encoding="utf-8")
    print(" ".join(v["lflags"]))
    return 0


def package_sources() -> list[str]:
    """Differences between the C/C++ sources CMake compiles and those scripts/fpm_package.py ships.

    Returns
    -------
    list[str]
        One message per source compiled by one build and not the other (by file name).
    """
    import importlib.util  # noqa: PLC0415 (only this check needs it)

    spec = importlib.util.spec_from_file_location("fpm_package", ROOT / "scripts" / "fpm_package.py")
    assert spec is not None and spec.loader is not None
    pkg = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(pkg)
    files = (*pkg.IMGUI_FILES, *pkg.IMPLOT_FILES, *pkg.NATIVE_FILES, *pkg.EDITOR_FILES, *pkg.GIZMO_FILES,
             *pkg.IMPLOT3D_FILES, *pkg.RICHMD_FILES, *pkg.MD4C_FILES)
    shipped = {Path(f).name for f in files if f.endswith((".cpp", ".c"))}
    shipped |= {"cimgui.cpp", "cimplot.cpp", "cimplot3d.cpp", "miniz.c"}
    cmake = (ROOT / "native" / "CMakeLists.txt").read_text(encoding="utf-8")
    block = re.search(r"add_library\(figure_native STATIC(.*?)\)\n", cmake, re.S)
    compiled = set(re.findall(r"([\w.]+\.(?:cpp|c))\b", block.group(1))) if block else set()
    return [f"compiled by CMake, not shipped by scripts/fpm_package.py: {f}" for f in sorted(compiled - shipped)] + [
        f"shipped by scripts/fpm_package.py, not compiled by CMake: {f}" for f in sorted(shipped - compiled)
    ]


def library_root() -> list[str]:
    """Check that the static-library modes build from the library root and that it uses every public module.

    Returns
    -------
    list[str]
        The discrepancies.
    """
    errors = []
    cfg = configparser.ConfigParser(interpolation=None, strict=False)
    cfg.read(ROOT / "fobos", encoding="utf-8")
    modes = [s for s in cfg.sections() if s.startswith("figure-static-")]
    if not modes:
        errors.append("fobos has no figure-static-* mode")
    for mode in modes:
        target = cfg.get(mode, "target", fallback="")
        if target != LIBRARY_ROOT:
            errors.append(f"fobos [{mode}] target must be {LIBRARY_ROOT} (the library root), it is {target!r}")
    root = ROOT / LIBRARY_ROOT
    used = {m.lower() for m in USE_RE.findall(root.read_text(encoding="utf-8"))} if root.exists() else set()
    errors.extend(
        f"{LIBRARY_ROOT} does not use {m}: lib/libfigure.a would miss it" for m in PUBLIC_MODULES if m not in used
    )
    return errors


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
    if fpm_libs != FPM_LINK:
        errors.append(f"fpm.toml [build] link must be {FPM_LINK}, it is {fpm_libs}")
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

    errors.extend(package_sources())
    errors.extend(library_root())

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
        help="print the native link line of a platform varset (default: the current platform)",
    )
    parser.add_argument(
        "--fpm-link",
        action="store_true",
        help="write lib/libfigure_platform.a if needed and print the --link-flag value for fpm (current platform)",
    )
    args = parser.parse_args(argv)
    if args.fpm_link:
        return fpm_link(current_platform())
    if args.link_flags is not None:
        return link_flags(args.link_flags or current_platform())
    return check()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
