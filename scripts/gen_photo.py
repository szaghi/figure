"""Write ``docs/examples/data/schlieren.jpg``, the photograph of the cookbook's "Show a photograph beside a field".

A synthetic schlieren picture, not a photograph of an experiment: the bow shock ahead of a cylinder in a supersonic
stream, grey levels like a density gradient's, with film grain, vignetting and a sepia tint, 360 x 240 pixels, JPEG
of quality 85. FIGURE's own picture (MIT, as FIGURE): no third-party image is bundled.

Usage::

    python3 -I scripts/gen_photo.py [OUT]   # default: docs/examples/data/schlieren.jpg

Needs Pillow (the JPEG encoder); deterministic for a given Pillow (fixed seed).
"""

from __future__ import annotations

import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
W, H = 360, 240
R = 34.0  # the cylinder's radius [px]
CX, CY = 230.0, 120.0  # its centre [px]
STANDOFF = 0.42 * R  # the shock's stand-off distance [px]
# the shock's hyperbola: x_s(y) = -(R + d) - (sqrt(1 + (y / B)^2) - 1) A
A, B = 55.0, 38.0


def grey(i: int, j: int, rng: random.Random) -> int:
    """The grey level of pixel (i, j), before the blur and the tint."""
    x, y = i - CX, j - CY
    r = math.hypot(x, y)
    if r <= R:
        v = 18.0 + 6.0 * r / R  # the model, dark
    else:
        dist = x - (-(R + STANDOFF) - (math.sqrt(1.0 + (y / B) ** 2) - 1.0) * A)
        v = 128.0 + 95.0 * math.exp(-((dist / 2.2) ** 2)) * (1.0 if dist < 0 else 0.7)
        if dist > 0:
            v -= 30.0 * math.exp(-dist / 18.0) * math.exp(-((y / 70.0) ** 2))
        if x > 0:  # expansion fans and the wake
            v += 22.0 * math.sin(3.0 * math.atan2(y, x)) * math.exp(-(r - R) / 25.0)
            v -= 18.0 * math.exp(-((y / (0.8 * R)) ** 2)) * (1.0 - math.exp(-x / 40.0))
    vignette = 1.0 - 0.35 * ((i - W / 2) ** 2 + (j - H / 2) ** 2) / ((W / 2) ** 2 + (H / 2) ** 2)
    return max(0, min(255, int(v * vignette + rng.gauss(0.0, 5.0))))


def main() -> int:
    """Write the picture."""
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "docs" / "examples" / "data" / "schlieren.jpg"
    rng = random.Random(7)
    img = Image.new("L", (W, H))
    px = img.load()
    for j in range(H):
        for i in range(W):
            px[i, j] = grey(i, j, rng)
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    red = img.point(lambda g: min(255, int(g * 1.06 + 6)))
    blue = img.point(lambda g: int(g * 0.86))
    Image.merge("RGB", [red, img, blue]).save(out, quality=85, optimize=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
