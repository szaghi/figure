"""Check that fobos (the primary build) and fpm.toml describe the same FIGURE build, and print link flags for fpm.

Checked:
  - fpm.toml ``[build] link`` is the platform-independent part of the native link line: ``figure_native SDL3``;
  - every fobos platform varset (``[varset:linux|macos|windows]``) starts its ``$NATIVE_LIBS`` with those two;
  - the varset of the platform this runs on covers the static link line SDL reports for it
    (``lib/pkgconfig/sdl3.pc``, written by the native build): every ``-l`` library and every framework (checked only
    when the native layer is built);
  - every program under src/examples/ and src/tests/ is declared in fpm.toml (fobos discovers them by itself);
  - the two paths (szaghi/figure#15 §2): every mode of fobos builds the library from ``src/lib`` and one path's set of
    seam implementations, ``$PATH_IMGUI`` (the current path) or, for the ``-fortran`` modes, ``$PATH_FORTRAN``; each
    set defines every module once (one implementation of each seam); fpm.toml's library is the assembled tree of the
    current path (``[library] source-dir`` is ``build/fpm-lib``, written by ``--fpm-tree``);
  - every program declared in fpm.toml exists;
  - the static-library modes (``figure-static-*``) build from ``src/lib/figure_library.F90``, which uses every public
    module (``figure``, ``figure_testing``): FoBiS archives a target and what it uses, so a module left out of that
    root is missing from ``lib/libfigure.a`` and ``lib/mod`` (what ``fobis fetch`` gives a downstream project).
  - the Fortran libraries (szaghi/figure#15 §6): fobos ``[dependencies]`` and fpm.toml ``[dependencies]`` name the same
    set, each on the same branch and never pinned to a tag or commit; and the set is closed: every module a listed
    library ``use``s (its sources fetched in fobos' ``deps_dir``, the files of fobos' ``$EXCLUDE`` left out) comes
    from a listed library or the compiler (checked only when the libraries are fetched: ``fobis fetch``).

``--fpm-tree`` writes the current path's library, ``src/lib`` and ``$PATH_IMGUI`` in one directory (``build/fpm-lib``,
the source-dir of fpm.toml's library: fpm takes one directory and scans it recursively), for scripts/fpm.sh;
``--path-sources PATH`` prints the library sources of a path (``imgui`` or ``fortran``), one per line, for
docs/examples/build.sh.

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
# a use statement of a library source: `use m`, `use :: m`, `use, intrinsic :: m`, `use, non_intrinsic :: m`
LIB_USE_RE = re.compile(r"^\s*use\b\s*(?:,\s*(\w+)\s*)?(?:::)?\s*(\w+)", re.IGNORECASE | re.MULTILINE)
MODULE_RE = re.compile(r"^\s*module\s+(?!procedure\b|function\b|subroutine\b)(\w+)\s*(?:!.*)?$", re.IGNORECASE | re.MULTILINE)
# modules the compiler provides: the intrinsic ones, OpenMP's and OpenACC's (FUNDAL's backends; `devmodule` is its macro
# naming one of the two, fundal.H)
COMPILER_MODULES = {
    "iso_fortran_env", "iso_c_binding", "ieee_arithmetic", "ieee_exceptions", "ieee_features", "omp_lib", "omp_lib_kinds",
    "openacc", "devmodule",
}  # fmt: skip
LIB_SOURCE_SUFFIXES = (".f90", ".F90", ".inc", ".INC", ".h", ".H")  # sources and the files they include
# the two paths (szaghi/figure#15 §2): the fobos variable naming each path's seam implementations, and the fpm tree
PATH_VARIABLES = {"imgui": "$PATH_IMGUI", "fortran": "$PATH_FORTRAN"}
FPM_TREE = "build/fpm-lib"
PROGRAM_DIRS = ("src/tests", "src/examples")  # what a mode's `src` adds to the library: programs (and their modules)
FORTRAN_SUFFIXES = (".f90", ".F90", ".inc")


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


def implot_ref() -> list[str]:
    """Check the side-by-side tests' reference modules: the current path's plot modules renamed (gen_implot_ref.py).

    Returns
    -------
    list[str]
        The discrepancy, if any.
    """
    sys.path.insert(0, str(ROOT / "scripts"))
    import gen_implot_ref  # noqa: PLC0415 (a sibling script)

    return [
        f"{target.relative_to(ROOT).as_posix()} is not current: run python3 scripts/gen_implot_ref.py"
        for module, target in gen_implot_ref.TARGETS.items()
        if not target.is_file() or target.read_text(encoding="utf-8") != gen_implot_ref.generate(module)
    ]


def editor_generated() -> list[str]:
    """Check the Fortran code editor's generated modules (gen_editor_*.py; szaghi/figure#15 P16).

    Returns
    -------
    list[str]
        The discrepancies.
    """
    sys.path.insert(0, str(ROOT / "scripts"))
    import gen_editor_languages  # noqa: PLC0415 (a sibling script)
    import gen_editor_path  # noqa: PLC0415 (a sibling script)
    import gen_editor_tables  # noqa: PLC0415 (a sibling script)

    errors = []
    for script, target, generate in (
        ("gen_editor_tables.py", gen_editor_tables.OUT, gen_editor_tables.generate),
        ("gen_editor_path.py", gen_editor_path.TARGET, gen_editor_path.generate),
        ("gen_editor_languages.py", gen_editor_languages.OUT, gen_editor_languages.generate),
    ):
        if not target.is_file() or target.read_text(encoding="utf-8") != generate():
            errors.append(f"{target.relative_to(ROOT).as_posix()} is not current: run python3 scripts/{script}")
    return errors


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


def fobos_libraries(fobos: Path) -> tuple[dict[str, dict[str, str]], Path, set[str]]:
    """Return the Fortran libraries of fobos ``[dependencies]``, their directory and the files fobos excludes.

    Parameters
    ----------
    fobos : Path
        The fobos file.

    Returns
    -------
    tuple[dict[str, dict[str, str]], Path, set[str]]
        Library name -> its spec options (``url``, ``branch``, ``tag``, ``rev``, ``semver``, ``src``, ...), the
        ``deps_dir`` (absolute) and the excluded files (``$EXCLUDE``, POSIX paths relative to ``deps_dir``).
    """
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str  # keep the case of the names
    parser.read(fobos, encoding="utf-8")
    libraries: dict[str, dict[str, str]] = {}
    deps_dir = ROOT / ".fobis_deps"
    if parser.has_section("dependencies"):
        for name, spec in parser["dependencies"].items():
            if name == "deps_dir":
                deps_dir = ROOT / spec.strip()
                continue
            parts = [part.strip() for part in spec.split("::")]
            options = {"url": parts[0]}
            for part in parts[1:]:
                key, _, value = part.partition("=")
                options[key.strip()] = value.strip()
            libraries[name] = options
    excluded: set[str] = set()
    for section in parser.sections():
        if "$EXCLUDE" in parser[section]:
            for path in parser[section]["$EXCLUDE"].split():
                full = ROOT / path
                excluded.add(full.relative_to(deps_dir).as_posix() if full.is_relative_to(deps_dir) else path)
    return libraries, deps_dir, excluded


def library_sources(libraries: dict[str, dict[str, str]], deps_dir: Path, excluded: set[str]) -> dict[str, list[Path]]:
    """Return the sources FIGURE compiles of each fetched library: its ``src`` directories, fobos' exclusions left out.

    Parameters
    ----------
    libraries : dict[str, dict[str, str]]
        The libraries of fobos ``[dependencies]``.
    deps_dir : Path
        Where the libraries are, one directory each by name: fobos' ``deps_dir`` (``fobis fetch``) or another.
    excluded : set[str]
        Files fobos excludes (POSIX, relative to ``deps_dir``).

    Returns
    -------
    dict[str, list[Path]]
        Library name -> its source and include files; a library not fetched is missing.
    """
    found: dict[str, list[Path]] = {}
    for name, options in libraries.items():
        root = deps_dir / name
        if not root.is_dir():
            continue
        files: list[Path] = []
        for sub in options.get("src", ".").split(","):
            files += [f for f in sorted((root / sub.strip()).rglob("*"))
                      if f.suffix in LIB_SOURCE_SUFFIXES and f.relative_to(deps_dir).as_posix() not in excluded]  # fmt: skip
        found[name] = files
    return found


def fortran_libraries() -> list[str]:
    """Check the Fortran libraries: the same set in fobos and fpm.toml, never pinned, closed under ``use``.

    Returns
    -------
    list[str]
        The discrepancies.
    """
    errors: list[str] = []
    libraries, deps_dir, excluded = fobos_libraries(ROOT / "fobos")
    manifest = tomllib.loads((ROOT / "fpm.toml").read_text(encoding="utf-8"))
    fpm_deps = manifest.get("dependencies", {})
    errors.extend(f"library in fobos [dependencies], not in fpm.toml: {n}" for n in sorted(set(libraries) - set(fpm_deps)))
    errors.extend(f"library in fpm.toml [dependencies], not in fobos: {n}" for n in sorted(set(fpm_deps) - set(libraries)))
    for name in sorted(set(libraries) & set(fpm_deps)):
        fobos_spec, fpm_spec = libraries[name], fpm_deps[name]
        pins = [k for k in ("tag", "rev", "semver") if k in fobos_spec] + [k for k in ("tag", "rev") if k in fpm_spec]
        if pins:
            errors.append(f"library {name} is pinned ({', '.join(sorted(set(pins)))}): it tracks its default branch")
        if fobos_spec["url"].removesuffix(".git") != str(fpm_spec.get("git", "")).removesuffix(".git"):
            errors.append(f"library {name}: fobos URL {fobos_spec['url']}, fpm.toml git {fpm_spec.get('git')}")
        if "branch" not in fobos_spec or fobos_spec["branch"] != fpm_spec.get("branch"):
            errors.append(
                f"library {name}: fobos branch {fobos_spec.get('branch')}, fpm.toml branch {fpm_spec.get('branch')}"
            )
    sources = library_sources(libraries, deps_dir, excluded)
    missing = sorted(set(libraries) - set(sources))
    if missing:
        print(f"check_sync: {', '.join(missing)} not fetched (fobis fetch): the closure of the libraries is not checked")
        return errors
    defined: set[str] = set()
    used: dict[str, set[str]] = {}
    for name, files in sources.items():
        for f in files:
            text = f.read_text(encoding="utf-8", errors="replace")
            defined |= {m.lower() for m in MODULE_RE.findall(text)}
            for nature, module in LIB_USE_RE.findall(text):
                if nature.lower() != "intrinsic":
                    used.setdefault(module.lower(), set()).add(name)
    for module in sorted(set(used) - defined - COMPILER_MODULES):
        errors.append(
            f"module {module}, used by {', '.join(sorted(used[module]))}, comes from no library of fobos [dependencies]"
            " (the set must be closed: add the library that defines it, here and in fpm.toml)"
        )
    return errors


def fobos_parser() -> configparser.ConfigParser:
    """Return the fobos file parsed (keys' case kept, no interpolation)."""
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    parser.read(ROOT / "fobos", encoding="utf-8")
    return parser


def fobos_variables(parser: configparser.ConfigParser) -> dict[str, str]:
    """Return fobos' ``[common-variables]``, continuation lines joined."""
    if not parser.has_section("common-variables"):
        return {}
    return {k: " ".join(v.split()) for k, v in parser["common-variables"].items()}


def expand(value: str, variables: dict[str, str]) -> list[str]:
    """Return a fobos value as its words, its ``$VARIABLES`` replaced (longest names first, as FoBiS does)."""
    for name in sorted(variables, key=len, reverse=True):
        value = value.replace(name, variables[name])
    return value.split()


def mode_options(parser: configparser.ConfigParser, mode: str) -> dict[str, str]:
    """Return a mode's options, its templates' (recursively) under its own, as FoBiS reads them."""
    options: dict[str, str] = {}
    if parser.has_option(mode, "template"):
        options.update(mode_options(parser, parser.get(mode, "template")))
    options.update({k: v for k, v in parser[mode].items() if k != "template"})
    return options


def path_dirs(path: str) -> list[str]:
    """Return the library directories of a path (``imgui`` or ``fortran``): ``src/lib`` and the path's seams."""
    variables = fobos_variables(fobos_parser())
    return ["src/lib", *(d.rstrip("/") for d in expand(PATH_VARIABLES[path], variables))]


def sources_under(dirs: list[str], excluded: list[str] | None = None) -> list[Path]:
    """Return the Fortran sources and include files under ``dirs`` (recursively), those under ``excluded`` left out."""
    found: list[Path] = []
    for d in dirs:
        for f in sorted((ROOT / d).rglob("*")):
            rel = f.relative_to(ROOT).as_posix()
            if f.is_file() and f.suffix in FORTRAN_SUFFIXES and not any(rel.startswith(f"{x}/") for x in excluded or []):
                found.append(f)
    return found


def path_sources(path: str) -> list[Path]:
    """Return the library sources of a path (``imgui``: the current one; ``fortran``)."""
    return sources_under(path_dirs(path))


def duplicated_modules(files: list[Path]) -> dict[str, list[str]]:
    """Return the modules defined by more than one of ``files``: name -> the files defining it."""
    where: dict[str, list[str]] = {}
    for f in files:
        for m in MODULE_RE.findall(f.read_text(encoding="utf-8", errors="replace")):
            where.setdefault(m.lower(), []).append(f.relative_to(ROOT).as_posix())
    return {m: fs for m, fs in where.items() if len(fs) > 1}


def paths() -> list[str]:
    """Check the two paths: each mode's library is one path's set, defining each module once; fpm's is the current.

    Returns
    -------
    list[str]
        The discrepancies.
    """
    errors: list[str] = []
    parser = fobos_parser()
    variables = fobos_variables(parser)
    missing = [v for v in PATH_VARIABLES.values() if v not in variables]
    if missing:
        return [f"fobos [common-variables] lacks {', '.join(missing)} (the two paths, #15 §2)"]
    sets = {path: set(path_dirs(path)) for path in PATH_VARIABLES}
    modes = parser.get("modes", "modes", fallback="").split() if parser.has_section("modes") else []
    for mode in modes:
        options = mode_options(parser, mode)
        src = [d.rstrip("/") for d in expand(options.get("src", ""), variables)]
        library = {d for d in src if not d.startswith(PROGRAM_DIRS)}
        path = "fortran" if mode.endswith("-fortran") else "imgui"
        if library != sets[path]:
            errors.append(
                f"fobos [{mode}]: its library is {' '.join(sorted(library))}, not src/lib and "
                f"{PATH_VARIABLES[path]} ({' '.join(sorted(sets[path] - {'src/lib'}))})"
            )
        excluded = expand(options.get("exclude_dirs", ""), variables)
        files = sources_under(src, [x.rstrip("/") for x in excluded])
        for module, where in sorted(duplicated_modules(files).items()):
            errors.append(f"fobos [{mode}]: module {module} defined {len(where)} times: {', '.join(where)}")
    for path in PATH_VARIABLES:
        names: dict[str, list[str]] = {}
        for f in path_sources(path):
            names.setdefault(f.name, []).append(f.relative_to(ROOT).as_posix())
        errors.extend(
            f"the {path} path has two files named {n} (an assembled tree is flat): {', '.join(fs)}"
            for n, fs in sorted(names.items()) if len(fs) > 1
        )  # fmt: skip
    manifest = tomllib.loads((ROOT / "fpm.toml").read_text(encoding="utf-8"))
    source_dir = manifest.get("library", {}).get("source-dir")
    if source_dir != FPM_TREE:
        errors.append(f"fpm.toml [library] source-dir must be {FPM_TREE} (the current path's tree), it is {source_dir}")
    return errors


def fpm_tree() -> int:
    """Write the current path's library in one directory (``FPM_TREE``), the source-dir of fpm.toml's library.

    The files are copied (not linked: Windows), each only when it changed; files no longer in the path are removed.

    Returns
    -------
    int
        Exit status: 0, or 1 when the path has two files of the same name.
    """
    tree = ROOT / FPM_TREE
    sources = {f.name: f for f in path_sources("imgui")}
    if len(sources) != len(path_sources("imgui")):
        print("check_sync: the current path has two files of the same name: run check_sync.py", file=sys.stderr)
        return 1
    tree.mkdir(parents=True, exist_ok=True)
    for old in tree.iterdir():
        if old.name not in sources:
            old.unlink()
    for name, f in sources.items():
        dst = tree / name
        data = f.read_bytes()
        if not dst.is_file() or dst.read_bytes() != data:
            dst.write_bytes(data)
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
    errors.extend(paths())
    errors.extend(implot_ref())
    errors.extend(editor_generated())
    errors.extend(fortran_libraries())

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
        "--fpm-tree",
        action="store_true",
        help=f"write the current path's library sources into {FPM_TREE} (fpm.toml's library) for scripts/fpm.sh",
    )
    parser.add_argument(
        "--path-sources",
        choices=sorted(PATH_VARIABLES),
        help="print the library sources of a path, one per line",
    )
    parser.add_argument(
        "--fpm-link",
        action="store_true",
        help="write lib/libfigure_platform.a if needed and print the --link-flag value for fpm (current platform)",
    )
    args = parser.parse_args(argv)
    if args.fpm_tree:
        return fpm_tree()
    if args.path_sources:
        print("\n".join(f.relative_to(ROOT).as_posix() for f in path_sources(args.path_sources)))
        return 0
    if args.fpm_link:
        return fpm_link(current_platform())
    if args.link_flags is not None:
        return link_flags(args.link_flags or current_platform())
    return check()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
