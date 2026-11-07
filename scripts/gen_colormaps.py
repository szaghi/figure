"""Generate FIGURE's bundled colormaps, ``third_party/colormaps/<name>.csv``, from their upstream data files.

Every map is a table of 256 RGB samples in [0, 1], one ``r,g,b`` row each, after a few ``#`` comment lines naming its
category, its source and its licence. The native build embeds the tables (``native/CMakeLists.txt``, and
``scripts/fpm_package.py`` for fpm) and ``ip_colormap`` registers each one with ImPlot at its first use. The licence
files are written next to the tables (``LICENSE-<project>.txt``) and installed under ``share/licenses/<project>/``.

The sources are pinned below (URL and SHA-256). Downloaded data is parsed as text, never executed: the Python files
of matplotlib and of the Turbo gist are read with regular expressions.

Usage::

    python3 -I scripts/gen_colormaps.py --download DIR   # fetch the pinned sources into DIR (new or empty)
    python3 -I scripts/gen_colormaps.py --sources DIR    # write third_party/colormaps from them
    python3 -I scripts/gen_colormaps.py --sources DIR --check  # exit 1 if a committed table or licence differs

Standard library only (Python >= 3.11).
"""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "third_party" / "colormaps"
SAMPLES = 256

MPL = "https://raw.githubusercontent.com/matplotlib/matplotlib/v3.11.2"
BIDS = "https://raw.githubusercontent.com/BIDS/colormap/bc549477db0c12b54a5928087552ad2cf274980f"
TURBO = (
    "https://gist.githubusercontent.com/mikhailov-work/ee72ba4191942acecc03fe6da94fc73f/raw/"
    "dccf2856de98e3c60c7f0ac8acf3c33d9726dfb8/turbo_colormap.py"
)
CMOCEAN = "https://raw.githubusercontent.com/matplotlib/cmocean/v4.0.3"
MORELAND = (
    "https://raw.githubusercontent.com/kennethmoreland-com/kennethmoreland-com.github.io/"
    "04f580e28bcbcd2d62d20b069fd16bd5dae64c28/content/color-advice/smooth-cool-warm"
)
PARAVIEW = "https://gitlab.kitware.com/paraview/paraview/-/raw/v6.2.0"
CRAMERI = "https://zenodo.org/records/8409685/files/ScientificColourMaps8.zip?download=1"
APACHE = "https://www.apache.org/licenses/LICENSE-2.0.txt"

# local file name -> URL (SHA-256 in SHA256SUMS)
PINS: dict[str, str] = {
    "matplotlib-_cm_listed.py": f"{MPL}/lib/matplotlib/_cm_listed.py",
    "matplotlib-LICENSE": f"{MPL}/LICENSE/LICENSE",
    "bids-colormaps.py": f"{BIDS}/colormaps.py",
    "bids-LICENSE.txt": f"{BIDS}/LICENSE.txt",
    "turbo_colormap.py": TURBO,
    "apache-LICENSE-2.0.txt": APACHE,
    "cmocean-LICENSE.txt": f"{CMOCEAN}/LICENSE.txt",
    "cmocean-thermal-rgb.txt": f"{CMOCEAN}/cmocean/rgb/thermal-rgb.txt",
    "cmocean-haline-rgb.txt": f"{CMOCEAN}/cmocean/rgb/haline-rgb.txt",
    "cmocean-deep-rgb.txt": f"{CMOCEAN}/cmocean/rgb/deep-rgb.txt",
    "cmocean-balance-rgb.txt": f"{CMOCEAN}/cmocean/rgb/balance-rgb.txt",
    "cmocean-curl-rgb.txt": f"{CMOCEAN}/cmocean/rgb/curl-rgb.txt",
    "smooth-cool-warm-table-float-0256.csv": f"{MORELAND}/smooth-cool-warm-table-float-0256.csv",
    "paraview-Copyright.txt": f"{PARAVIEW}/Copyright.txt",
    "ScientificColourMaps8.zip": CRAMERI,
}
SHA256: dict[str, str] = {}  # filled from SHA256SUMS below
SHA256SUMS = """
cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30  apache-LICENSE-2.0.txt
b7478d10e2ccfdb22128867e137f16f55b687e9c225065e91bcbd6bb9e6c0352  bids-colormaps.py
30419703377136667f2c8a426d396874a8dadf53699d277fc8ad759d05092799  bids-LICENSE.txt
8abbfe7ac4753be904b0c15534882da94ca22b63e25a468c0654637977b7c1cd  cmocean-balance-rgb.txt
6267de01c3995a94889a95d07c97d3d796ef25b1daa2db8a5d110f3224a9e770  cmocean-curl-rgb.txt
040df9fb34f8aa0aef581d38bc5c39c5bd96810608e6a9cdfd9ecc3fda1160c3  cmocean-deep-rgb.txt
8f54ed333074adf75a689d12d6a92ff75066f441013e1148361570f393389214  cmocean-haline-rgb.txt
ca2993ffcd19156051e2ff594e934976bffc4d71b56a59dfc998e236eb0ce7f7  cmocean-LICENSE.txt
98b285203ca06e1aadcead34cbf247957c24e480bee5f187a20c1aafe3c81f47  cmocean-thermal-rgb.txt
ddad3698f5129ceb1792a445371286c08bc9080298e657b3054aea19c9659ef9  matplotlib-_cm_listed.py
5a1a81ea301728c8bba2933da832c0cd62229daf20893a024ab3d53244468dbc  matplotlib-LICENSE
b2f3586bd6e306aa6bd487c6cc76ab25f9b4d97338b0ba69f9784aba448524a5  paraview-Copyright.txt
fe8ccf8e26d87b6703e96e4da1a6872f14a79e725c7025bc9db034898b8fc02c  ScientificColourMaps8.zip
00cda60a7c371e32689a86b6b1d99c9591343425fee6128ca5cde2ef450bfd01  smooth-cool-warm-table-float-0256.csv
22e1c5b7ee9c402302af328ec5a3089f3cf896acb0df3392760c5ce2191e0499  turbo_colormap.py
"""  # fmt: skip

# The licence of Fabio Crameri's Scientific colour maps 8.0.1, as printed in the archive's +LICENCE.pdf (one file, the
# same in every map's folder); transcribed here because the archive carries it only as a PDF.
CRAMERI_LICENCE = """\
Scientific colour maps, version 8.0.1 (Fabio Crameri, https://doi.org/10.5281/zenodo.8409685), from +LICENCE.pdf:

The Scientific colour maps are licensed under a MIT License

Copyright (c) 2023, Fabio Crameri

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
documentation files (the "Software"), to deal in the Software without restriction, including without limitation the
rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit
persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
"""

# name -> (category, source description, licence file stem)
MAPS: dict[str, tuple[str, str, str]] = {
    "cividis": ("sequential", "matplotlib v3.11.2, lib/matplotlib/_cm_listed.py (_cividis_data); designed by J. R. "
                "Nunez, C. R. Anderton and R. S. Renslow (PNNL), contributed to matplotlib by its author (PR 9871)",
                "matplotlib"),
    "inferno": ("sequential", "matplotlib v3.11.2, _cm_listed.py (_inferno_data), equal to BIDS/colormap "
                "colormaps.py (CC0; N. J. Smith and S. van der Walt)", "matplotlib, mpl-colormaps"),
    "magma": ("sequential", "matplotlib v3.11.2, _cm_listed.py (_magma_data), equal to BIDS/colormap colormaps.py "
              "(CC0; N. J. Smith and S. van der Walt)", "matplotlib, mpl-colormaps"),
    "turbo": ("sequential", "matplotlib v3.11.2, _cm_listed.py (_turbo_data), equal to Google's turbo_colormap.py "
              "(A. Mikhailov, Apache-2.0)", "matplotlib, turbo"),
    "thermal": ("sequential", "cmocean v4.0.3, cmocean/rgb/thermal-rgb.txt (K. M. Thyng)", "cmocean"),
    "haline": ("sequential", "cmocean v4.0.3, cmocean/rgb/haline-rgb.txt (K. M. Thyng)", "cmocean"),
    "deep": ("sequential", "cmocean v4.0.3, cmocean/rgb/deep-rgb.txt (K. M. Thyng)", "cmocean"),
    "batlow": ("sequential", "Scientific colour maps 8.0.1, batlow/batlow.txt (F. Crameri)", "crameri"),
    "cool-warm": ("diverging", "K. Moreland, smooth-cool-warm-table-float-0256.csv, ParaView's 'Cool to Warm'",
                  "paraview"),
    "balance": ("diverging", "cmocean v4.0.3, cmocean/rgb/balance-rgb.txt (K. M. Thyng)", "cmocean"),
    "curl": ("diverging", "cmocean v4.0.3, cmocean/rgb/curl-rgb.txt (512 rows, resampled linearly to 256 as "
             "cmocean does; K. M. Thyng)", "cmocean"),
    "vik": ("diverging", "Scientific colour maps 8.0.1, vik/vik.txt (F. Crameri)", "crameri"),
    "roma": ("diverging", "Scientific colour maps 8.0.1, roma/roma.txt (F. Crameri)", "crameri"),
    "romaO": ("cyclic", "Scientific colour maps 8.0.1, romaO/romaO.txt (F. Crameri)", "crameri"),
}  # fmt: skip

NUMBER = r"([-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)"
TRIPLE = re.compile(rf"\[\s*{NUMBER}\s*,\s*{NUMBER}\s*,\s*{NUMBER}\s*\]")

Table = list[tuple[float, float, float]]


class ColormapError(Exception):
    """A source is missing, changed or malformed."""


def python_list(text: str, var: str) -> Table:
    """The ``[[r, g, b], ...]`` assigned to ``var`` in a Python source, read as text (never executed)."""
    m = re.search(rf"^{re.escape(var)}\s*=\s*\[", text, re.MULTILINE)
    if m is None:
        msg = f"{var}: not found"
        raise ColormapError(msg)
    depth, i = 0, m.end() - 1
    for i in range(m.end() - 1, len(text)):  # noqa: B007 (i is the end of the list)
        depth += {"[": 1, "]": -1}.get(text[i], 0)
        if depth == 0:
            break
    return [(float(a), float(b), float(c)) for a, b, c in TRIPLE.findall(text[m.end() - 1 : i + 1])]


def columns(text: str, first: int = 0, sep: str | None = None) -> Table:
    """Rows of numbers (columns first..first+2), skipping a header line that is not numeric."""
    rows: Table = []
    for line in text.splitlines():
        cells = line.split(sep) if sep else line.split()
        if not cells or not re.fullmatch(NUMBER, cells[0].strip()):
            continue
        rows.append((float(cells[first]), float(cells[first + 1]), float(cells[first + 2])))
    return rows


def resample(rows: Table, n: int) -> Table:
    """Linear interpolation of rows (at uniform positions in [0, 1]) at n uniform positions."""
    m = len(rows)
    out: Table = []
    for k in range(n):
        x = k * (m - 1) / (n - 1)
        i = min(int(x), m - 2)
        w = x - i
        out.append(tuple((1.0 - w) * a + w * b for a, b in zip(rows[i], rows[i + 1], strict=True)))  # type: ignore[misc]
    return out


def read(src: Path, name: str) -> bytes:
    """A downloaded source, checked against its pinned SHA-256."""
    data = (src / name).read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if SHA256.get(name) and digest != SHA256[name]:
        msg = f"{name}: SHA-256 {digest}, pinned {SHA256[name]}"
        raise ColormapError(msg)
    return data


def tables(src: Path) -> dict[str, Table]:
    """Every bundled map, from the sources in src."""
    mpl = read(src, "matplotlib-_cm_listed.py").decode()
    bids = read(src, "bids-colormaps.py").decode()
    turbo = read(src, "turbo_colormap.py").decode()
    t: dict[str, Table] = {}
    for name in ("cividis", "inferno", "magma", "turbo"):
        t[name] = python_list(mpl, f"_{name}_data")
    for name in ("inferno", "magma"):
        if python_list(bids, f"_{name}_data") != t[name]:
            msg = f"{name}: matplotlib's table differs from BIDS/colormap's"
            raise ColormapError(msg)
    if python_list(turbo, "turbo_colormap_data") != t["turbo"]:
        msg = "turbo: matplotlib's table differs from Google's"
        raise ColormapError(msg)
    for name in ("thermal", "haline", "deep", "balance", "curl"):
        rows = columns(read(src, f"cmocean-{name}-rgb.txt").decode())
        t[name] = rows if len(rows) == SAMPLES else resample(rows, SAMPLES)
    t["cool-warm"] = columns(read(src, "smooth-cool-warm-table-float-0256.csv").decode(), first=1, sep=",")
    with zipfile.ZipFile(src / "ScientificColourMaps8.zip") as z:
        read(src, "ScientificColourMaps8.zip")
        for name in ("batlow", "vik", "roma", "romaO"):
            t[name] = columns(z.read(f"{name}/{name}.txt").decode())
    for name, rows in t.items():
        if len(rows) != SAMPLES or not all(0.0 <= v <= 1.0 for row in rows for v in row):
            msg = f"{name}: {len(rows)} rows, expected {SAMPLES} with values in [0, 1]"
            raise ColormapError(msg)
    return t


def outputs(src: Path) -> dict[str, str]:
    """The files of third_party/colormaps: the tables and the licences."""
    files: dict[str, str] = {}
    t = tables(src)
    for name, (category, source, licence) in MAPS.items():
        stems = ", ".join(f"LICENSE-{s.strip()}.txt" for s in licence.split(","))
        head = (
            f"# {name}: {category} colormap, {SAMPLES} RGB samples in [0, 1]\n"
            f"# source: {source}\n"
            f"# licence: {stems}\n"
            "# generated by scripts/gen_colormaps.py: do not edit\n"
        )
        files[f"{name}.csv"] = head + "".join(f"{r:.6f},{g:.6f},{b:.6f}\n" for r, g, b in t[name])
    turbo = read(src, "turbo_colormap.py").decode()
    notice = "".join(line + "\n" for line in turbo.splitlines()[:4])
    files["LICENSE-matplotlib.txt"] = read(src, "matplotlib-LICENSE").decode()
    files["LICENSE-mpl-colormaps.txt"] = read(src, "bids-LICENSE.txt").decode()
    files["LICENSE-turbo.txt"] = (
        "Turbo colormap (turbo_colormap.py, https://gist.github.com/mikhailov-work/ee72ba4191942acecc03fe6da94fc73f):\n\n"
        + notice + "\n" + read(src, "apache-LICENSE-2.0.txt").decode()
    )  # fmt: skip
    files["LICENSE-cmocean.txt"] = read(src, "cmocean-LICENSE.txt").decode()
    files["LICENSE-paraview.txt"] = read(src, "paraview-Copyright.txt").decode()
    files["LICENSE-crameri.txt"] = CRAMERI_LICENCE
    return files


def download(dst: Path) -> None:
    """Fetch every pinned source into dst (new or empty)."""
    if dst.exists() and any(dst.iterdir()):
        msg = f"{dst}: not empty"
        raise ColormapError(msg)
    dst.mkdir(parents=True, exist_ok=True)
    for name, url in PINS.items():
        with urllib.request.urlopen(url, timeout=600) as r:  # noqa: S310 (pinned https URLs)
            (dst / name).write_bytes(r.read())
        read(dst, name)
        print(f"gen_colormaps: {name}")


def main(argv: list[str]) -> int:
    """Download, generate or check."""
    for line in SHA256SUMS.split("\n"):
        if line.strip():
            digest, name = line.split()
            SHA256[name] = digest
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("--download", type=Path, metavar="DIR", help="fetch the pinned sources into DIR")
    ap.add_argument("--sources", type=Path, metavar="DIR", help="the downloaded sources")
    ap.add_argument("--check", action="store_true", help="compare with the committed files, write nothing")
    a = ap.parse_args(argv)
    try:
        if a.download:
            download(a.download)
        if a.sources is None:
            return 0
        files = outputs(a.sources)
    except (ColormapError, OSError, KeyError, ValueError) as e:
        print(f"gen_colormaps: {e}", file=sys.stderr)
        return 1
    if a.check:
        stale = [n for n, text in files.items() if not (OUT / n).is_file() or (OUT / n).read_text() != text]
        for n in stale:
            print(f"gen_colormaps: third_party/colormaps/{n} is not current", file=sys.stderr)
        return 1 if stale else 0
    OUT.mkdir(parents=True, exist_ok=True)
    for n, text in files.items():
        (OUT / n).write_text(text)
    print(f"gen_colormaps: {len(MAPS)} tables and {len(files) - len(MAPS)} licences in {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
