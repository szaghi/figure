"""Check FIGURE's windowed path: run an example in a real window, capture its frames, check the pixels.

The program (default ``exe/examples/figure_hello``, built by ``fobis build --mode examples-gnu``) is run twice in a
window on the display, with the frame capture of the native layer (``FIGURE_CAPTURE``, see docs/guide/capture.md):
once with the system's frame, once with the frame drawn by FIGURE (``--frame``: ``decorations='figure'``). Each run
must write the frames asked for, and its last frame must

  - have the window's size, 1100 x 700 pixels (or an integer multiple of it, on a display of higher pixel density),
    or less, down to 1000 x 600, when the system clamps the window to a small display (a CI runner's 1024 x 768):
    probes then falling outside the frame are skipped;
  - not be blank: many distinct colours, and none covering nearly the whole frame;
  - show known widgets at known places, in the colours of FIGURE's default style (``seal``): the window background,
    the "Click me" button, the frequency slider's grab and, with ``--frame``, the title bar with its title and the
    close button, on the left on macOS and on the right elsewhere, FIGURE's default (without it: no bar, the
    background).

The last frame of each run is written as ``<out>/<case>.png`` (``native.png``, ``figure.png``), for the CI's artifacts
and for a look by eye. The probes below are measured on figure_hello in the ``seal`` style: update them when either
changes.

Usage: python3 scripts/window_check.py [--program PATH] [--out DIR] [--timeout SECONDS]
Needs a display (Linux: X11 or Wayland, Xvfb included; macOS; Windows) and OpenGL 3; standard library only.
Exit status 0 when every check passes, 1 otherwise (each failure printed).
"""

from __future__ import annotations

import argparse
import os
import struct
import subprocess
import sys
import tempfile
import zlib
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WIDTH, HEIGHT = 1100, 700  # figure_hello's window [logical pixels]
MIN_WIDTH, MIN_HEIGHT = 1000, 600  # the least a window clamped to a small display may keep [pixels]
SKIP, FRAMES = 10, 3  # frames skipped (Dear ImGui sizes its windows in the first ones), frames written
STYLE = "seal"
BACKGROUND = (20, 18, 15)  # seal's window background
TOLERANCE = 6  # per channel, for flat fills


@dataclass(frozen=True)
class Probe:
    """A rectangle of the frame [logical pixels] that must show a colour or ink.

    ``kind`` is ``fill`` (at least ``share`` of the pixels within TOLERANCE of ``colour``) or ``ink`` (at least
    ``share`` of the pixels brighter than ``colour``'s mean by 60: text or a glyph drawn on it).
    """

    name: str
    x: int
    y: int
    w: int
    h: int
    kind: str
    colour: tuple[int, int, int]
    share: float


COMMON = (
    Probe("background (bottom right)", 1065, 670, 30, 25, "fill", BACKGROUND, 0.99),
    Probe("button 'Click me'", 30, 50, 50, 18, "fill", (58, 50, 43), 0.6),
    Probe("button 'Click me', its text", 30, 50, 50, 18, "ink", (58, 50, 43), 0.05),
    Probe("slider grab", 153, 77, 8, 14, "fill", (217, 68, 44), 0.9),
)
CASES = {
    "native": (
        [],
        (*COMMON, Probe("no title bar drawn by FIGURE", 100, 2, 300, 14, "fill", BACKGROUND, 0.99)),
    ),
    "figure": (
        ["--frame"],
        (
            *COMMON,
            Probe("title bar", 100, 2, 300, 14, "fill", (42, 37, 32), 0.99),
            Probe("title bar, the title", 500, 3, 100, 14, "ink", (42, 37, 32), 0.05),
            Probe("title bar, the close button", 8 if sys.platform == "darwin" else 1072, 3, 18, 14, "ink",
                  (42, 37, 32), 0.05),
        ),
    ),
}


def read_ppm(path: Path) -> tuple[int, int, bytes]:
    """Read a binary PPM (P6, 8 bits) as written by the capture.

    Parameters
    ----------
    path : Path
        The file.

    Returns
    -------
    tuple[int, int, bytes]
        Width, height and the RGB bytes, top row first.
    """
    data = path.read_bytes()
    magic, size, depth, pixels = data.split(b"\n", 3)
    w, h = (int(v) for v in size.split())
    if magic != b"P6" or depth != b"255" or len(pixels) != w * h * 3:
        msg = f"{path.name}: not an 8-bit binary PPM of {w}x{h}"
        raise ValueError(msg)
    return w, h, pixels


def write_png(path: Path, w: int, h: int, rgb: bytes) -> None:
    """Write RGB bytes (top row first) as a PNG.

    Parameters
    ----------
    path : Path
        The file.
    w, h : int
        Size [pixels].
    rgb : bytes
        The pixels.
    """

    def chunk(kind: bytes, body: bytes) -> bytes:
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))

    row = w * 3
    raw = b"".join(b"\x00" + rgb[y * row : (y + 1) * row] for y in range(h))
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 6))
        + chunk(b"IEND", b"")
    )


def check_frame(w: int, h: int, rgb: bytes, probes: tuple[Probe, ...]) -> list[str]:
    """Check a frame: its size, that it is not blank, and the probes.

    Parameters
    ----------
    w, h : int
        Size [pixels].
    rgb : bytes
        The pixels, top row first.
    probes : tuple[Probe, ...]
        The probes, in logical pixels.

    Returns
    -------
    list[str]
        The failures (empty: the frame passes).
    """
    scale = max(w // WIDTH, 1)
    clamped = MIN_WIDTH <= w <= WIDTH and MIN_HEIGHT <= h <= HEIGHT and (w, h) != (WIDTH, HEIGHT)
    if not clamped and (w != WIDTH * scale or h != HEIGHT * scale):
        return [f"size {w}x{h}, expected {WIDTH}x{HEIGHT} (or a multiple of it, or clamped to a small display)"]
    errors = []
    counts: dict[bytes, int] = {}
    for i in range(0, len(rgb), 3):
        px = rgb[i : i + 3]
        counts[px] = counts.get(px, 0) + 1
    top = max(counts.values())
    if len(counts) < 64 or top > 0.95 * w * h:
        errors.append(f"blank: {len(counts)} colours, the commonest on {100 * top // (w * h)}% of the frame")
    for p in probes:
        if (p.x + p.w) * scale > w or (p.y + p.h) * scale > h:
            print(f"window_check: {p.name}: outside the {w}x{h} frame (window clamped), skipped")
            continue
        hits = total = 0
        for y in range(p.y * scale, (p.y + p.h) * scale):
            for x in range(p.x * scale, (p.x + p.w) * scale):
                r, g, b = rgb[(y * w + x) * 3 : (y * w + x) * 3 + 3]
                total += 1
                if p.kind == "fill":
                    hits += max(abs(r - p.colour[0]), abs(g - p.colour[1]), abs(b - p.colour[2])) <= TOLERANCE
                else:
                    hits += (r + g + b) / 3 > sum(p.colour) / 3 + 60
        if hits < p.share * total:
            errors.append(f"{p.name}: {hits}/{total} pixels match ({p.kind} {p.colour}, {p.share:.0%} needed)")
    return errors


def run_case(program: Path, case: str, out: Path, timeout: float) -> list[str]:
    """Run the program for one case, keep its last frame as a PNG, check it.

    Parameters
    ----------
    program : Path
        The example.
    case : str
        A key of CASES.
    out : Path
        Directory of the PNG.
    timeout : float
        Time allowed to the run [s].

    Returns
    -------
    list[str]
        The failures.
    """
    args, probes = CASES[case]
    with tempfile.TemporaryDirectory() as tmp:
        env = dict(
            os.environ,
            FIGURE_CAPTURE=str(Path(tmp) / "f_"),
            FIGURE_CAPTURE_FROM=str(SKIP),
            FIGURE_CAPTURE_FRAMES=str(FRAMES),
            FIGURE_STYLE=STYLE,
        )
        try:
            run = subprocess.run(
                [str(program), *args], env=env, capture_output=True, text=True, timeout=timeout, check=False
            )
        except subprocess.TimeoutExpired:
            return [f"no end within {timeout:.0f} s"]
        if run.returncode != 0:
            return [f"exit status {run.returncode}: {(run.stdout + run.stderr).strip()[-2000:]}"]
        frames = sorted(Path(tmp).glob("f_*.ppm"))
        if len(frames) != FRAMES:
            return [f"{len(frames)} frames written, {FRAMES} asked"]
        w, h, rgb = read_ppm(frames[-1])
        write_png(out / f"{case}.png", w, h, rgb)
        errors = check_frame(w, h, rgb, probes)
        if not errors:
            print(f"window_check: {case}: ok ({w}x{h}, {len(probes)} probes) -> {out / f'{case}.png'}")
        return errors


def main(argv: list[str]) -> int:
    """Run every case.

    Parameters
    ----------
    argv : list[str]
        Arguments, without the script name.

    Returns
    -------
    int
        Exit status: 0 when every case passes, 1 otherwise.
    """
    parser = argparse.ArgumentParser(description="Run figure_hello in a window, capture and check its frames.")
    parser.add_argument(
        "--program", default=str(ROOT / "exe" / "examples" / "figure_hello"), help="the example to run"
    )
    parser.add_argument("--out", default="window-frames", help="directory of the PNG frames (created)")
    parser.add_argument("--timeout", type=float, default=120.0, help="time allowed to each run [s]")
    args = parser.parse_args(argv)
    program = Path(args.program)
    if not program.exists() and Path(f"{program}.exe").exists():  # Windows
        program = Path(f"{program}.exe")
    if not program.exists():
        print(f"window_check: {program} not found (fobis build --mode examples-gnu)", file=sys.stderr)
        return 1
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    failed = 0
    for case in CASES:
        for e in run_case(program.resolve(), case, out, args.timeout):
            print(f"window_check: {case}: {e}", file=sys.stderr)
            failed += 1
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
