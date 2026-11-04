#!/usr/bin/env python3
"""FIGURE 'seal' mark: a window and its plot drafted with a brush, signed with a carved vermilion seal.

The brush draws a window the way calligraphy writes the character 口: the left side, then the title bar folding
down into the right side, then the floor. Inside, a thin stroke traces a plot. The bottom-right corner is not drawn:
the seal is pressed there, closing the frame where a window keeps its resize grip, and it is carved in white relief
(shubun) with a seal-script monogram, so the picture is signed by who made it: Fortran.

Brush engine (from round 1): a centreline sampled by arc length, offset along its normal by a half-width that follows
the brush pressure, with a pressed, rounded entry and a dry tapered exit. Python 3 stdlib only.
Writes, in docs/public: logo.svg (light pages), logo-dark.svg (dark pages), favicon.svg (16 px, on a paper tile).

Usage: python3 docs/brand/marks.py [output directory, default docs/public]
"""

import math
import pathlib
import random
import sys

HERE = (
    pathlib.Path(sys.argv[1])
    if len(sys.argv) > 1
    else pathlib.Path(__file__).resolve().parent.parent / "public"
)

INK = "#16130f"  # sumi: warm black
PAPER = "#f6f2ea"  # washi (the dark mark's ink, the favicon tile)
SHU = "#c8321e"  # vermilion seal (light)
SHU_DARK = "#d9442c"  # vermilion seal on ink (slightly lifted)


def f(v):
    return f"{v:.2f}".rstrip("0").rstrip(".")


# ---------------------------------------------------------------------------------------------------------- centrelines
def resample(pts, n):
    """Resample a polyline at n+1 points equally spaced in arc length."""
    acc = [0.0]
    for a, b in zip(pts, pts[1:]):
        acc.append(acc[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    total = acc[-1]
    out, j = [], 0
    for i in range(n + 1):
        s = total * i / n
        while j < len(acc) - 2 and acc[j + 1] < s:
            j += 1
        u = (s - acc[j]) / max(acc[j + 1] - acc[j], 1e-9)
        a, b = pts[j], pts[j + 1]
        out.append((a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u))
    return out


def bezier(p0, p1, p2, p3, n=60):
    pts = []
    for i in range(n + 1):
        t = i / n
        c = ((1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t**2, t**3)
        pts.append(
            (
                sum(k * p[0] for k, p in zip(c, (p0, p1, p2, p3))),
                sum(k * p[1] for k, p in zip(c, (p0, p1, p2, p3))),
            )
        )
    return pts


def fold(a, corner, b, r, n=80):
    """Two straight runs a->corner->b joined by a tight rounded turn of radius ~r (the brush's folded corner)."""

    def toward(p, q, d):
        L = math.hypot(q[0] - p[0], q[1] - p[1])
        return (p[0] + (q[0] - p[0]) * d / L, p[1] + (q[1] - p[1]) * d / L)

    c0 = toward(corner, a, r)
    c1 = toward(corner, b, r)
    turn = bezier(
        c0, toward(c0, corner, r * 0.55), toward(c1, corner, r * 0.55), c1, 12
    )
    return resample([a] + turn + [b], n)


def curve(fn, x0, x1, n=90):
    return [(x0 + (x1 - x0) * i / n, fn(x0 + (x1 - x0) * i / n)) for i in range(n + 1)]


# ---------------------------------------------------------------------------------------------------------- the brush
def outline(pts, width, lean=0.08, bias=None, nub=(0.75, 1.15)):
    """Filled outline of a stroke: width(t) is the full width along t in [0,1], bias(t) extra ink on the right-hand
    (outer) edge. The entry is the brush landing on its side: the head carries a nub `nub` = (back, out) half-widths
    behind the start and out past the right-hand edge (up-left on a horizontal, the shoulder of a vertical)."""
    n = len(pts) - 1
    left, right = [], []
    for i, (x, y) in enumerate(pts):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, n)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        nx, ny = -dy / L, dx / L
        t = i / n
        h = width(t) / 2
        e = bias(t) if bias else 0.0
        left.append((x + nx * h * (1 + lean), y + ny * h * (1 + lean)))
        right.append((x - nx * (h * (1 - lean) + e), y - ny * (h * (1 - lean) + e)))
    d = "M" + " L".join(f"{f(x)},{f(y)}" for x, y in left)
    d += " L" + " L".join(f"{f(x)},{f(y)}" for x, y in reversed(right))
    # the head: from the right edge out to the nub, then a full round back to the left edge
    x0, y0 = pts[0]
    h0 = width(0) / 2
    tx, ty = pts[1][0] - x0, pts[1][1] - y0
    L = math.hypot(tx, ty)
    tx, ty = tx / L, ty / L
    lx, ly = left[0]
    rx, ry = right[0]
    N = (x0 + (-tx * nub[0] + ty * nub[1]) * h0, y0 + (-ty * nub[0] - tx * nub[1]) * h0)
    q = ((rx + N[0]) / 2 - tx * h0 * 0.25, (ry + N[1]) / 2 - ty * h0 * 0.25)
    c1 = (N[0] - tx * h0 * 0.55, N[1] - ty * h0 * 0.55)
    c2 = (lx - tx * h0 * 1.15, ly - ty * h0 * 1.15)
    d += (
        f" Q{f(q[0])},{f(q[1])} {f(N[0])},{f(N[1])}"
        f" C{f(c1[0])},{f(c1[1])} {f(c2[0])},{f(c2[1])} {f(lx)},{f(ly)} Z"
    )
    return d


def profile(
    w, dry=0.35, press=0.22, breath=0.10, knots=(), exit_pow=0.8, exit_from=0.55
):
    """Pressure along the stroke: a pressed landing, a breathing body, optional pauses (knots: (t, gain, width)),
    and a taper that only starts after exit_from, running dry to `dry` times the width."""

    def width(t):
        v = 1.0 + press * math.exp(-((t / 0.05) ** 2))
        v *= 1.0 - breath + breath * math.cos(1.4 * math.pi * t)
        for tk, g, s in knots:
            v *= 1.0 + g * math.exp(-(((t - tk) / s) ** 2))
        if t > exit_from:
            u = (t - exit_from) / (1 - exit_from)
            v *= 1 - (1 - dry) * u**exit_pow
        return w * v

    return width


# ---------------------------------------------------------------------------------------------------------- the seal
def worn_rect(x, y, w, h, jitter, r, rnd, m=5):
    """A rectangle whose sides are gentle polylines and whose corners are slightly rounded (worn stone)."""
    sides = [
        ((x + r, y), (x + w - r, y)),
        ((x + w, y + r), (x + w, y + h - r)),
        ((x + w - r, y + h), (x + r, y + h)),
        ((x, y + h - r), (x, y + r)),
    ]
    corners = [(x + w, y), (x + w, y + h), (x, y + h), (x, y)]
    d = ""
    for k, ((a, b), c) in enumerate(zip(sides, corners)):
        for j in range(m + 1):
            u = j / m
            px = a[0] + (b[0] - a[0]) * u
            py = a[1] + (b[1] - a[1]) * u
            if 0 < j < m:
                ex, ey = (b[1] - a[1]), -(b[0] - a[0])
                L = math.hypot(ex, ey)
                e = rnd.uniform(-jitter, jitter)
                px += ex / L * e
                py += ey / L * e
            d += ("M" if not d else " L") + f"{f(px)},{f(py)}"
        nxt = sides[(k + 1) % 4][0]
        d += f" Q{f(c[0])},{f(c[1])} {f(nxt[0])},{f(nxt[1])}"
    return d + " Z"


def carved(bars, rnd, jitter, r):
    """The monogram: a union of carved bars (x, y, w, h), each with chisel-worn edges."""
    return " ".join(worn_rect(x, y, w, h, jitter, r, rnd, m=3) for x, y, w, h in bars)


def mono_F(x, y, s, k, mid=0.53):
    """Seal-script 'F' in an s x s field with stroke k, squared as a carved name is: a stem the full height, a top
    bar the full width, a shorter middle bar. No hook on the top bar: at 64 px a hook closes the F into a P."""
    return [
        (x, y, k, s),  # stem
        (x, y, s, k),  # top bar, to the field's right edge
        (x, y + s * mid - k / 2, s * 0.70, k),
    ]  # middle bar


def chips(x, y, s, rnd, n, size):
    """Wear of the stone: a few small chips bitten out of the seal's edge, as an old hanko prints."""
    out = []
    for _ in range(n):
        side = rnd.randrange(4)
        u = rnd.uniform(0.15, 0.85) * s
        px, py = [(x + u, y), (x + s, y + u), (x + u, y + s), (x, y + u)][side]
        r = rnd.uniform(0.5, 1.0) * size
        pts = []
        for j in range(5):
            a = 2 * math.pi * j / 5 + rnd.uniform(-0.4, 0.4)
            rr = r * rnd.uniform(0.6, 1.1)
            pts.append((px + rr * math.cos(a), py + rr * math.sin(a)))
        out.append("M" + " L".join(f"{f(p)},{f(q)}" for p, q in pts) + " Z")
    return " ".join(out)


def rotate_d(cx, cy, deg):
    return f"rotate({f(deg)} {f(cx)} {f(cy)})"


# ---------------------------------------------------------------------------------------------------------- assembly
def svg(strokes, seal_d, cut_d, rot, ink, shu, label, bg=None):
    tile = f'<rect width="64" height="64" rx="12" fill="{bg}"/>' if bg else ""
    ink_paths = "".join(f'<path d="{d}"/>' for d in strokes)
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="256" height="256" role="img" '
        f'aria-label="{label}">'
        f'<defs><mask id="carve" maskUnits="userSpaceOnUse" x="0" y="0" width="64" height="64">'
        f'<rect width="64" height="64" fill="#fff"/><path d="{cut_d}" fill="#000"/></mask></defs>'
        f"{tile}"
        f'<g fill="{ink}">{ink_paths}</g>'
        f'<g transform="{rot}"><path d="{seal_d}" fill="{shu}" mask="url(#carve)"/></g>'
        f"</svg>\n"
    )


def window_strokes(bold=1.0, plot=True):
    """The frame strokes and the plot of the window, in the 64 x 64 field, written in the order of 口."""
    # 1. left side (竖): pressed at the top, a faint inward bow, still wet at the foot where the floor crosses it
    left = resample(bezier((11.0, 18.6), (10.2, 30.0), (10.2, 42.0), (11.0, 53.0)), 60)
    s1 = outline(left, profile(3.1 * bold, dry=0.8, press=0.25, breath=0.08))
    # 2. title bar folding into the right side (横折): rising slightly to the right as a written horizontal does,
    #    thinning as the brush travels, a pressed shoulder at the fold, then a lighter, dry run down the right side
    a, c, e = (6.6, 13.4), (53.2, 11.0), (52.4, 37.5)
    top = fold(a, c, e, r=1.0, n=140)
    l1 = math.hypot(c[0] - a[0], c[1] - a[1])
    tc = l1 / (
        l1 + math.hypot(e[0] - c[0], e[1] - c[1])
    )  # where the fold sits along the stroke

    def tb(t):
        u = min(t / tc, 1.0)
        heavy = 7.2 * bold * (1.0 - 0.10 * math.sin(math.pi * u) - 0.22 * u**3)
        side = 3.0 * bold
        blend = 1 / (
            1 + math.exp(-(t - tc - 0.02) / 0.03)
        )  # the brush lifts just after the fold
        v = heavy * (1 - blend) + side * blend
        v *= 1 + 0.10 * math.exp(-((t / 0.04) ** 2))
        if t > 0.78:
            v *= 1 - 0.78 * ((t - 0.78) / 0.22) ** 0.9  # dry exit just above the seal
        return v

    def shoulder(t):  # the pause at the corner pushes ink outwards
        return 0.7 * bold * math.exp(-(((t - tc + 0.01) / 0.025) ** 2))

    s2 = outline(top, tb, lean=0.04, bias=shoulder)
    # 3. the floor (横): rises to the right, crosses the left side's foot, runs dry before the seal
    floor = resample(bezier((8.4, 53.4), (19.0, 53.6), (31.0, 52.8), (40.0, 51.6)), 70)
    s3 = outline(
        floor, profile(3.2 * bold, dry=0.2, press=0.2, breath=0.1, exit_from=0.4)
    )
    out = [s1, s2, s3]
    if plot:
        out.append(plot_stroke(bold))
    return out


def plot_stroke(bold=1.0, cycles=1.0):
    """The plot: a damped oscillation inside the window, a probe settling (round 1's curve, now framed)."""
    x0, x1 = 17.0, 46.5
    pts = curve(
        lambda x: (
            31.5 + 8.5 * math.exp(-0.05 * (x - x0)) * math.cos(0.29 * cycles * (x - x0))
        ),
        x0,
        x1,
    )
    return outline(
        resample(pts, 90),
        profile(2.5 * bold, dry=0.25, press=0.25, breath=0.12, exit_from=0.5),
    )


def main():
    label = "FIGURE: a window holding a plot, drafted with a brush and signed with a vermilion seal carved F"
    sx, sy, ss = 43.0, 42.0, 18.0
    seal_d = worn_rect(sx, sy, ss, ss, 0.28, 1.4, random.Random(11))
    m = 2.7  # the red margin: about one stroke, as a carved name fills its stone
    cut = carved(
        mono_F(sx + m + 0.2, sy + m, ss - 2 * m, 2.3, mid=0.52),
        random.Random(3),
        0.16,
        0.25,
    )
    cut += " " + chips(sx, sy, ss, random.Random(5), 3, 0.9)
    rot = rotate_d(sx + ss / 2, sy + ss / 2, -2.0)
    strokes = window_strokes()
    (HERE / "logo.svg").write_text(svg(strokes, seal_d, cut, rot, INK, SHU, label))
    (HERE / "logo-dark.svg").write_text(
        svg(strokes, seal_d, cut, rot, PAPER, SHU_DARK, label)
    )
    # favicon: the same window, heavier, no plot detail beyond one swing; a bigger seal carved F
    fsx, fsy, fss = 34.5, 33.5, 27.0
    fseal = worn_rect(fsx, fsy, fss, fss, 0.15, 2.0, random.Random(11))
    fm = 5.0
    fcut = carved(
        mono_F(fsx + fm + 0.4, fsy + fm, fss - 2 * fm, 4.6, mid=0.56),
        random.Random(3),
        0.05,
        0.3,
    )
    frot = rotate_d(fsx + fss / 2, fsy + fss / 2, -2.0)
    (HERE / "favicon.svg").write_text(
        svg(
            window_strokes(bold=1.6, plot=False),
            fseal,
            fcut,
            frot,
            INK,
            SHU,
            "FIGURE",
            bg=PAPER,
        )
    )


if __name__ == "__main__":
    main()
