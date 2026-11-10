"""Write FIGURE as a self-contained fpm package: a plain ``fpm build`` compiles everything but SDL3.

fpm has no build hooks, so it cannot run CMake. This script lays out, in OUTDIR, everything fpm needs to compile the
native layer itself, next to the Fortran library:

- ``src/fortran/``: the Fortran library (src/lib);
- ``src/native/``: FIGURE's C++ glue (native/), with the files CMake generates at configure time (the browser page,
  the themes, the colormaps and the font, embedded) written here by the same rules;
- ``src/cimgui/`` (with ``imgui/``), ``src/cimplot/`` (with ``implot/``), ``src/miniz/``: the pinned third-party sources,
  copied from CMake's fetched tree (build/native/_deps, so run scripts/build_native.sh first), only the files FIGURE
  compiles; Dear ImGui's ``imconfig.h`` carries the two settings CMake passes as definitions, so no compiler flag is
  needed; miniz is compiled through a small wrapper that sets its options;
- ``src/stb/``: ``stb_image_write.h``, vendored in the repository (third_party/stb), included by figure_remote.cpp;
- the licences of everything copied (``LICENSES/``), and ``fpm.toml``.

SDL3 comes from the system (a package: libsdl3-dev, Homebrew's sdl3, MSYS2's SDL3), found by the compiler and linker
like any system library (on macOS with Homebrew: ``CPATH`` and ``LIBRARY_PATH`` set to its prefix).

Usage::

    python3 scripts/fpm_package.py OUTDIR [--version X.Y.Z] [--fetch [CACHE]]

``--fetch`` takes the third-party sources from the network instead of CMake's tree: the pins (cimgui and cimplot git
tags, miniz's archive and SHA-256) are read from native/CMakeLists.txt, so both builds use the same versions, and
CACHE (default: a temporary directory) keeps the downloads. Publishing needs no CMake and no SDL build that way.

Then ``cd OUTDIR && fpm build``, or depend on it from another fpm project. Standard library only; run from anywhere.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEPS = ROOT / "build" / "native" / "_deps"

IMGUI_FILES = [
    "imgui.cpp", "imgui_draw.cpp", "imgui_widgets.cpp", "imgui_tables.cpp", "imgui_demo.cpp",
    "imgui.h", "imgui_internal.h", "imconfig.h", "imstb_rectpack.h", "imstb_textedit.h", "imstb_truetype.h",
    "LICENSE.txt",
    "backends/imgui_impl_sdl3.cpp", "backends/imgui_impl_sdl3.h",
    "backends/imgui_impl_opengl3.cpp", "backends/imgui_impl_opengl3.h", "backends/imgui_impl_opengl3_loader.h",
]  # fmt: skip
IMPLOT_FILES = ["implot.cpp", "implot_items.cpp", "implot_demo.cpp", "implot.h", "implot_internal.h", "LICENSE"]
NATIVE_FILES = [
    "figure_native.cpp", "figure_native.h", "figure_process.cpp", "figure_task.cpp", "figure_scope.cpp", "figure_canvas.cpp",
    "figure_files.cpp",
    "figure_remote.cpp", "figure_colormap.cpp", "figure_field.cpp", "figure_view3d.cpp", "figure_view3d.h",
    "figure_remote.h", "figure_theme.cpp", "figure_theme.h", "figure_style.h", "figure_glue_generated.cpp", "figure_style_generated.cpp",
]  # fmt: skip

IMCONFIG_ADDITION = """
//---- FIGURE (scripts/fpm_package.py): what native/CMakeLists.txt passes as definitions, for builds without flags.
// cimgui and cimplot were generated with these settings: their C structs must match the C++ ones bit for bit.
#ifndef IMGUI_DISABLE_OBSOLETE_FUNCTIONS
#define IMGUI_DISABLE_OBSOLETE_FUNCTIONS 1
#endif
#undef NDEBUG // cimgui's cimconfig.h: Dear ImGui's assertions stay on
"""

MINIZ_WRAPPER = """// FIGURE (scripts/fpm_package.py): miniz with the options native/CMakeLists.txt sets (deflate and zlib streams only,
// mz_ names only), for builds without flags. The library itself is miniz.c.inc, unmodified.
#define MINIZ_NO_ARCHIVE_APIS
#define MINIZ_NO_STDIO
#define MINIZ_NO_TIME
#define MINIZ_NO_ZLIB_COMPATIBLE_NAMES
#include "miniz.c.inc"
"""

MANIFEST = """# FIGURE as a self-contained fpm package, written by scripts/fpm_package.py from the repository at {commit}.
# Do not edit: regenerate. fpm compiles the native layer itself (Dear ImGui, ImPlot, cimgui, cimplot, miniz and
# FIGURE's glue, all in src/); SDL3 comes from the system.
name = "figure"
version = "{version}"
license = "MIT"
author = "Stefano Zaghi"
maintainer = "stefano.zaghi@cnr.it"
description = "FIGURE, Fortran Immediate-mode GUI for User interfaces, Rendering and Exploration"
homepage = "https://github.com/szaghi/figure"

[build]
auto-executables = false
auto-examples = false
auto-tests = false
link = ["SDL3"]

[fortran]
implicit-typing = false
implicit-external = false
source-form = "free"

[library]
source-dir = "src"
include-dir = [{include_dirs}]
"""

INCLUDE_DIRS = [
    "src/native", "src/cimgui", "src/cimgui/imgui", "src/cimgui/imgui/backends", "src/cimplot", "src/cimplot/implot",
    "src/miniz", "src/stb",
]  # fmt: skip


def copy(src: Path, dst: Path) -> None:
    """Copy one file, creating its directory."""
    if not src.is_file():
        msg = f"fpm_package: missing {src} (run scripts/build_native.sh first, or use --fetch)"
        raise SystemExit(msg)
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dst)


def pins() -> dict[str, str]:
    """The third-party pins of native/CMakeLists.txt: cimgui and cimplot tags, miniz URL and SHA-256."""
    cmake = (ROOT / "native" / "CMakeLists.txt").read_text()
    found = {
        "cimgui": re.search(r'set\(FIGURE_CIMGUI_TAG\s+"([^"]+)"', cmake),
        "cimplot": re.search(r'set\(FIGURE_CIMPLOT_TAG\s+"([^"]+)"', cmake),
        "miniz_url": re.search(r"FetchContent_Declare\(miniz\s+URL\s+(\S+)", cmake),
        "miniz_sha256": re.search(r"URL_HASH\s+SHA256=([0-9a-f]{64})", cmake),
    }
    missing = [k for k, m in found.items() if m is None]
    if missing:
        msg = f"fpm_package: native/CMakeLists.txt: cannot read the pins {missing}"
        raise SystemExit(msg)
    return {k: m.group(1) for k, m in found.items() if m is not None}


def fetch(cache: Path) -> Path:
    """Download the pinned sources into cache/{cimgui-src,cimplot-src,miniz-src}, as CMake lays them out."""
    p = pins()
    for name, url in (("cimgui", "https://github.com/cimgui/cimgui"), ("cimplot", "https://github.com/cimgui/cimplot")):
        dst = cache / f"{name}-src"
        if not (dst / f"{name}.cpp").is_file():
            shutil.rmtree(dst, ignore_errors=True)
            subprocess.run(
                ["git", "-c", "advice.detachedHead=false", "clone", "--quiet", "--depth", "1", "--branch", p[name], "--recurse-submodules",
                 "--shallow-submodules", url, str(dst)],
                check=True,
            )  # fmt: skip
    dst = cache / "miniz-src"
    if not (dst / "miniz.c").is_file():
        with urllib.request.urlopen(p["miniz_url"], timeout=120) as r:  # noqa: S310 (a pinned https URL)
            data = r.read()
        digest = hashlib.sha256(data).hexdigest()
        if digest != p["miniz_sha256"]:
            msg = f"fpm_package: {p['miniz_url']}: SHA-256 {digest}, expected {p['miniz_sha256']}"
            raise SystemExit(msg)
        dst.mkdir(parents=True, exist_ok=True)
        zipfile.ZipFile(io.BytesIO(data)).extractall(dst)
    return cache


def cmake_embeds(out: Path) -> None:
    """The four files native/CMakeLists.txt generates at configure time, by the same rules."""
    html = (ROOT / "native" / "figure_remote_client.html").read_text()
    (out / "figure_remote_client.inc").write_text(
        "// generated from native/figure_remote_client.html by scripts/fpm_package.py\n"
        f'static const char client_html[] = R"FIGUREHTML({html})FIGUREHTML";\n'
    )
    text = (
        "// generated from themes/*.toml, themes/looks/*.toml and themes/palettes/*.toml by scripts/fpm_package.py\n"
        "struct theme_source { const char *name; const char *text; };\n"
    )
    for array, folder in (("THEMES", ROOT / "themes"), ("LOOKS", ROOT / "themes" / "looks"),
                          ("PALETTES", ROOT / "themes" / "palettes")):
        text += f"const theme_source {array}[] = {{\n"
        for t in sorted(folder.glob("*.toml")):
            text += f'   {{"{t.stem}", R"FIGURETHEME({t.read_text()})FIGURETHEME"}},\n'
        text += "};\n"
    (out / "figure_themes.inc").write_text(text)
    text = (
        "// generated from third_party/colormaps/*.csv by scripts/fpm_package.py\n"
        "struct colormap_source { const char *name; const char *text; };\n"
        "const colormap_source COLORMAPS[] = {\n"
    )
    for t in sorted((ROOT / "third_party" / "colormaps").glob("*.csv")):
        text += f'   {{"{t.stem}", R"FIGURECMAP({t.read_text()})FIGURECMAP"}},\n'
    text += "};\n"
    (out / "figure_colormaps.inc").write_text(text)
    text = (
        "// generated from third_party/fonts/{IBMPlexSans-Regular,IBMPlexMono-Regular,lucide,NotoSansMath-Regular}.ttf"
        " by scripts/fpm_package.py\n"
    )
    for array, ttf in (("plex_sans_ttf", "IBMPlexSans-Regular.ttf"), ("plex_mono_ttf", "IBMPlexMono-Regular.ttf"),
                       ("lucide_ttf", "lucide.ttf"), ("noto_math_ttf", "NotoSansMath-Regular.ttf")):
        font = (ROOT / "third_party" / "fonts" / ttf).read_bytes()
        rows = [",".join(f"0x{b:02x}" for b in font[i : i + 32]) for i in range(0, len(font), 32)]
        text += f"static const unsigned char {array}[] = {{\n" + ",\n".join(rows) + "};\n"
    (out / "figure_font.inc").write_text(text)


def main(argv: list[str]) -> int:
    """Write the package."""
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("outdir", type=Path)
    ap.add_argument("--version", default=None, help="package version (default: the VERSION file, without the v)")
    ap.add_argument("--fetch", nargs="?", const="", default=None, metavar="CACHE",
                    help="download the pinned sources (into CACHE, default a temporary directory)")  # fmt: skip
    a = ap.parse_args(argv)
    deps = DEPS
    tmp = None
    if a.fetch is not None:
        if a.fetch:
            deps = Path(a.fetch).resolve()
            deps.mkdir(parents=True, exist_ok=True)
        else:
            tmp = tempfile.TemporaryDirectory(prefix="figure-fpm-sources-")
            deps = Path(tmp.name)
        fetch(deps)
    try:
        return write(a, deps)
    finally:
        if tmp is not None:
            tmp.cleanup()


def write(a: argparse.Namespace, deps: Path) -> int:
    """Write the package from the sources in deps."""
    out = a.outdir.resolve()
    if out.exists() and any(out.iterdir()):
        if not (out / "fpm.toml").is_file():
            msg = f"fpm_package: {out} is not empty and is not a package written by this script"
            raise SystemExit(msg)
        for child in ("src", "LICENSES", "fpm.toml"):
            p = out / child
            if p.is_dir():
                shutil.rmtree(p)
            elif p.exists():
                p.unlink()
    src = out / "src"
    for f in sorted([*(ROOT / "src" / "lib").glob("*.F90"), *(ROOT / "src" / "lib").glob("*.inc")]):
        copy(f, src / "fortran" / f.name)  # *.inc: figure_icons_public.inc, included by figure.F90
    for f in NATIVE_FILES:
        copy(ROOT / "native" / f, src / "native" / f)
    cmake_embeds(src / "native")
    cimgui = deps / "cimgui-src"
    copy(cimgui / "cimgui.cpp", src / "cimgui" / "cimgui.cpp")
    copy(cimgui / "cimgui.h", src / "cimgui" / "cimgui.h")
    for f in IMGUI_FILES:
        copy(cimgui / "imgui" / f, src / "cimgui" / "imgui" / f)
    with (src / "cimgui" / "imgui" / "imconfig.h").open("a") as h:
        h.write(IMCONFIG_ADDITION)
    cimplot = deps / "cimplot-src"
    copy(cimplot / "cimplot.cpp", src / "cimplot" / "cimplot.cpp")
    copy(cimplot / "cimplot.h", src / "cimplot" / "cimplot.h")
    for f in IMPLOT_FILES:
        copy(cimplot / "implot" / f, src / "cimplot" / "implot" / f)
    miniz = deps / "miniz-src"
    copy(miniz / "miniz.c", src / "miniz" / "miniz.c.inc")
    copy(miniz / "miniz.h", src / "miniz" / "miniz.h")
    (src / "miniz" / "miniz_figure.c").write_text(MINIZ_WRAPPER)
    copy(ROOT / "third_party" / "stb" / "stb_image_write.h", src / "stb" / "stb_image_write.h")
    licences = out / "LICENSES"
    copy(ROOT / "LICENSE.mit.md", licences / "figure.md")
    copy(ROOT / "THIRD_PARTY.md", licences / "THIRD_PARTY.md")
    copy(cimgui / "imgui" / "LICENSE.txt", licences / "imgui.txt")
    copy(cimgui / "LICENSE", licences / "cimgui.txt")
    copy(cimplot / "implot" / "LICENSE", licences / "implot.txt")
    copy(cimplot / "LICENSE", licences / "cimplot.txt")
    copy(miniz / "LICENSE", licences / "miniz.txt")
    copy(ROOT / "third_party" / "stb" / "LICENSE-stb.txt", licences / "stb.txt")
    copy(ROOT / "third_party" / "fonts" / "LICENSE-IBMPlexSans.txt", licences / "ibm-plex.txt")
    copy(ROOT / "third_party" / "fonts" / "LICENSE-IBMPlexMono.txt", licences / "ibm-plex-mono.txt")
    copy(ROOT / "third_party" / "fonts" / "LICENSE-Lucide.txt", licences / "lucide.txt")
    copy(ROOT / "third_party" / "fonts" / "LICENSE-NotoSansMath.txt", licences / "noto-sans-math.txt")
    for lic in sorted((ROOT / "third_party" / "palettes").glob("LICENSE-*.txt")):  # the bundled palettes
        copy(lic, licences / f"palette-{lic.stem.removeprefix('LICENSE-')}.txt")
    for lic in sorted((ROOT / "third_party" / "colormaps").glob("LICENSE-*.txt")):  # the bundled colormaps
        copy(lic, licences / f"colormap-{lic.stem.removeprefix('LICENSE-')}.txt")
    version = a.version or (ROOT / "VERSION").read_text().strip().removeprefix("v")
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        version = "0.0.0"
    head = ROOT / ".git" / "HEAD"
    commit = "an unknown commit"
    if head.is_file():
        ref = head.read_text().strip()
        p = ROOT / ".git" / ref.removeprefix("ref: ") if ref.startswith("ref: ") else None
        commit = (p.read_text().strip() if p and p.is_file() else ref)[:12]
    (out / "fpm.toml").write_text(
        MANIFEST.format(commit=commit, version=version, include_dirs=", ".join(f'"{d}"' for d in INCLUDE_DIRS))
    )
    n = sum(1 for p in src.rglob("*") if p.is_file())
    print(f"fpm_package: {out}: {n} source files")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
