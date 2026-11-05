"""Draw the performance guide's charts from docs/data/performance.json, inline in docs/guide/performance.md.

Each chart is an inline SVG between ``<!-- chart:NAME -->`` and ``<!-- /chart:NAME -->`` in the page, replaced in
place, so the page shows what the data file holds and nothing stale. Colours and text follow the site's light and
dark themes through CSS classes (docs/.vitepress/theme/custom.css, ``.perf-chart``); every mark carries a tooltip
(an SVG ``<title>``) with its exact value, and the page gives the same numbers as tables.

Usage::

    python3 scripts/perf_charts.py [--check]

``--check`` exits 1 if the page is not what the data would draw (for CI and the docs gate). Standard library only.
Run from the repository root.
"""

from __future__ import annotations

import json
import math
import re
import sys
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "docs" / "data" / "performance.json"
PAGE = ROOT / "docs" / "guide" / "performance.md"

WIDTH = 640  # [px] of the drawing; the SVG scales to the column (about 610 px wide on the site)
LABEL_W = 215  # room for the case names
ROW_H = 28  # one case per row
TOP = 36  # room for the legend (and the axis labels at the bottom)
BOTTOM = 50  # tick labels, then the unit


def bars(rows: list[dict], key: str, unit: str) -> str:
    """Horizontal bars of `key` (a linear scale from 0), one series, value at the bar's end."""
    vmax = max(r[key] for r in rows)
    step = nice_step(vmax)
    xmax = step * math.ceil(vmax / step)
    plot_w = WIDTH - LABEL_W - 60
    h = 12 + ROW_H * len(rows) + BOTTOM
    out = [svg_open(h, f"{key} per case")]
    for t in range(int(round(xmax / step)) + 1):  # grid and axis labels
        x = LABEL_W + plot_w * t * step / xmax
        out.append(f'<line class="grid" x1="{x:.1f}" y1="8" x2="{x:.1f}" y2="{h - BOTTOM + 4}"/>')
        out.append(f'<text class="axis" x="{x:.1f}" y="{h - BOTTOM + 20}" text-anchor="middle">{fmt(t * step)}</text>')
    out.append(
        f'<text class="axis" x="{LABEL_W + plot_w / 2:.1f}" y="{h - 6}" text-anchor="middle">{escape(unit)}</text>'
    )
    for i, r in enumerate(rows):
        y = 12 + ROW_H * i
        w = max(plot_w * r[key] / xmax, 2.0)
        out.append(f'<text class="label" x="{LABEL_W - 10}" y="{y + 14}" text-anchor="end">{escape(r["case"])}</text>')
        out.append(
            f'<path class="s-now" d="{bar_path(LABEL_W, y + 6, w, 12)}"><title>{escape(r["case"])}: '
            f"{fmt(r[key])} {escape(unit)}</title></path>"
        )
        out.append(f'<text class="value" x="{LABEL_W + w + 6:.1f}" y="{y + 16}">{fmt(r[key])}</text>')
    out.append("</svg>")
    return "\n".join(out)


def dots(rows: list[dict], series: list[tuple[str, str, str]]) -> str:
    """One row per case, a dot per series on a logarithmic bytes/s scale, joined by a thin line."""
    lo, hi = 0, 9  # 1 byte/s to 1 GB/s
    plot_w = WIDTH - LABEL_W - 30
    h = TOP + ROW_H * len(rows) + BOTTOM
    out = [svg_open(h, "bytes per second per case, logarithmic")]
    lx = LABEL_W
    for key, cls, name in series:  # the legend, above the plot
        out.append(f'<circle class="{cls}" cx="{lx + 6}" cy="14" r="5"/>')
        out.append(f'<text class="legend" x="{lx + 16}" y="18">{escape(name)}</text>')
        lx += 34 + 7.6 * len(name)
    for e, label in ((0, "1 B/s"), (3, "1 KB/s"), (6, "1 MB/s"), (9, "1 GB/s")):
        x = LABEL_W + plot_w * (e - lo) / (hi - lo)
        out.append(f'<line class="grid" x1="{x:.1f}" y1="{TOP - 6}" x2="{x:.1f}" y2="{h - BOTTOM + 4}"/>')
        out.append(f'<text class="axis" x="{x:.1f}" y="{h - BOTTOM + 20}" text-anchor="middle">{label}</text>')
    for i, r in enumerate(rows):
        y = TOP + ROW_H * i + 10
        out.append(f'<text class="label" x="{LABEL_W - 10}" y="{y + 4}" text-anchor="end">{escape(r["case"])}</text>')
        xs = [(xpos(r[k] * 1e6, lo, hi, plot_w), k, cls, name) for k, cls, name in series if r.get(k) is not None]
        out.append(
            f'<line class="link" x1="{min(x for x, *_ in xs):.1f}" y1="{y}" x2="{max(x for x, *_ in xs):.1f}" y2="{y}"/>'
        )
        for x, k, cls, name in xs:
            out.append(
                f'<circle class="{cls} ring" cx="{x:.1f}" cy="{y}" r="5"><title>{escape(r["case"])}, {escape(name)}: '
                f"{rate(r[k] * 1e6)}</title></circle>"
            )
    out.append("</svg>")
    return "\n".join(out)


def svg_open(h: int, label: str) -> str:
    """The SVG element: scales to the column width, labelled for screen readers."""
    return (
        f'<svg class="perf-chart" viewBox="0 0 {WIDTH} {h}" width="100%" role="img" aria-label="{escape(label)}" '
        f'xmlns="http://www.w3.org/2000/svg">'
    )


def bar_path(x: float, y: float, w: float, h: float, r: float = 4.0) -> str:
    """A bar anchored at x, square at the baseline, its data end rounded by r."""
    r = min(r, w / 2, h / 2)
    return (
        f"M{x:.1f},{y:.1f} H{x + w - r:.1f} Q{x + w:.1f},{y:.1f} {x + w:.1f},{y + r:.1f} V{y + h - r:.1f} "
        f"Q{x + w:.1f},{y + h:.1f} {x + w - r:.1f},{y + h:.1f} H{x:.1f} Z"
    )


def xpos(v: float, lo: int, hi: int, plot_w: float) -> float:
    """Position of v [bytes/s] on the logarithmic scale."""
    return LABEL_W + plot_w * (math.log10(max(v, 1.0)) - lo) / (hi - lo)


def nice_step(vmax: float) -> float:
    """A grid step of 1, 2 or 5 times a power of ten giving 3 to 7 lines."""
    p = 10 ** math.floor(math.log10(vmax))
    for m in (1, 2, 5, 10):
        if vmax / (m * p) <= 6:
            return m * p
    return 10 * p


def fmt(v: float) -> str:
    """A number as the page writes it."""
    return f"{v:.0f}" if v >= 100 or v == int(v) else f"{v:.1f}" if v >= 10 else f"{v:.2f}"


def rate(b: float) -> str:
    """Bytes per second, in the largest unit below the value."""
    for unit, scale in (("GB/s", 1e9), ("MB/s", 1e6), ("KB/s", 1e3)):
        if b >= scale:
            return f"{b / scale:.3g} {unit}"
    return f"{b:.0f} B/s"


def render(page: str, data: dict) -> str:
    """The page with every chart region redrawn."""
    charts = {
        "cpu": bars(data["window"], "cpu_ms_per_frame", "ms of CPU per frame"),
        "remote": dots(
            data["remote"],
            [
                ("first_mb_s", "s-first", "first version"),
                ("now_mb_s", "s-now", "now"),
                ("deflated_mb_s", "s-deflated", "now, deflated"),
            ],
        ),
    }
    for name, svg in charts.items():
        pattern = re.compile(rf"(<!-- chart:{name} -->\n)(?:.*?\n)?(<!-- /chart:{name} -->)", re.S)
        if not pattern.search(page):
            msg = f"{PAGE}: no region <!-- chart:{name} --> ... <!-- /chart:{name} -->"
            raise SystemExit(msg)
        page = pattern.sub(lambda m, s=svg: m.group(1) + s + "\n" + m.group(2), page)
    return page


def main(argv: list[str]) -> int:
    """Redraw the charts, or check that they are current."""
    data = json.loads(DATA.read_text())
    page = PAGE.read_text()
    new = render(page, data)
    if "--check" in argv:
        if new != page:
            print("perf_charts: docs/guide/performance.md is not what docs/data/performance.json draws", file=sys.stderr)
            return 1
        print("perf_charts: charts are current")
        return 0
    PAGE.write_text(new)
    print(f"perf_charts: {PAGE.relative_to(ROOT)} redrawn")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
