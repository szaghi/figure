"""Record the screenshots and animations of the documentation from the real programs.

Each docs/media/<name>.rec is one recording: a header of "#!" lines, then the input script that the native layer
replays (see FIGURE_CAPTURE_INPUT in native/figure_native.cpp):

    #! program build/docs-examples/bin/tut02_widgets   the program, from the repository root (required)
    #! args    --flag value                            its arguments
    #! frames  180                                     frames to record (required)
    #! from    0                                       frames to skip before recording (default 0)
    #! poster  150                                     the recorded frame saved as the still image (default: last)
    #! video   no                                      a still image only (default: yes when frames > 1)
    #! crop    x y w h                                 a fixed crop [pixels] (default: the content's bounding box)
    #! scale   960                                     width of the video and poster [pixels] (default: the crop's)
    #! crf     24                                      H.264 quality, lower is better and larger (default 24)
    #! style   seal                                    the program's style, through FIGURE_STYLE (default seal)
    #! gif     640                                     also an animated GIF of the video, this wide (for the README:
                                                       GitHub plays no repository video there)
    #! remote  1100 700                                remote mode: the program is started with "--remote PORT" and
                                                       a headless Chromium (CHROME, or puppeteer's) draws the page
                                                       at this size; the still gets a browser bar (no input script)
    0 move 300 120
    ...

The program runs in a real window, on the GPU, with the capture of the native layer: no screen recorder, the frames
are the program's own back buffer, at a fixed frame time, with only the scripted input. Each recording is cropped to
the bounding box of everything that is not the window background (over all its frames, plus a margin), then written
to docs/public/media/<name>.png (the poster) and, for animations, docs/public/media/<name>.mp4 (H.264, no audio).

Usage: python3 scripts/docs_media.py [name ...]          (default: every docs/media/*.rec)
Needs: the programs built (bash docs/examples/build.sh; fobis build --mode examples-gnu), ffmpeg and ImageMagick.
On WSLg set GALLIUM_DRIVER=d3d12 for the GPU (the default, llvmpipe, works too, slower).
"""

from __future__ import annotations

import os
import shlex
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RECS = ROOT / "docs" / "media"
OUT = ROOT / "docs" / "public" / "media"
STYLE = "seal"  # FIGURE's own style: the documentation's pictures match its pages
BACKGROUND = {  # the window background of each style (apply_style in native/figure_native.cpp)
    "dark": "#1a1a1c",
    "classic": "#1a1a1c",
    "light": "#cccccc",
    "seal": "#14120f",
    "seal-light": "#e6e0d4",
    "paper": "#ffffff",
    "high-contrast": "#000000",
}
MARGIN = 12  # pixels around the content
FPS = 30


class MediaError(Exception):
    """A recording failed."""


def parse(rec: Path) -> tuple[dict[str, str], str]:
    """Header fields and the input script of a recording."""
    header: dict[str, str] = {}
    script = []
    for line in rec.read_text().splitlines():
        if line.startswith("#!"):
            key, _, value = line[2:].strip().partition(" ")
            header[key] = value.strip()
        else:
            script.append(line)
    for key in ("program", "frames"):
        if key not in header:
            msg = f"{rec.name}: missing '#! {key}'"
            raise MediaError(msg)
    return header, "\n".join(script) + "\n"


def bbox(frame: Path, background: str) -> tuple[int, int, int, int] | None:
    """Bounding box (x0, y0, x1, y1) of what differs from the background, None if nothing does."""
    out = subprocess.run(
        [
            "convert",
            str(frame),
            "-bordercolor",
            background,
            "-border",
            "1",
            "-fuzz",
            "2%",
            "-trim",
            "-format",
            "%w %h %X %Y",
            "info:",
        ],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.split()
    w, h, x, y = int(out[0]), int(out[1]), int(out[2]), int(out[3])
    if w <= 1 and h <= 1:
        return None
    return x - 1, y - 1, x - 1 + w, y - 1 + h


def chrome() -> str:
    """A headless Chromium: $CHROME, or the newest one puppeteer installed."""
    if os.environ.get("CHROME"):
        return os.environ["CHROME"]
    found = sorted(
        Path.home().glob(
            ".cache/puppeteer/chrome-headless-shell/*/*/chrome-headless-shell"
        )
    )
    if not found:
        msg = "no headless Chromium: set CHROME"
        raise MediaError(msg)
    return str(found[-1])


def record_remote(name: str, header: dict[str, str]) -> None:
    """Serve the program's UI and take a browser screenshot of it, in a drawn browser window."""
    width, height = (int(v) for v in header["remote"].split())
    port = 18765
    program = ROOT / header["program"]
    server = subprocess.Popen(
        [str(program), "--remote", str(port)],
        cwd=program.parent,
        env=dict(os.environ, FIGURE_STYLE=header.get("style", STYLE)),
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    try:
        # the address to open, with the program's access token: "FIGURE: open http://localhost:PORT/?token=... in ..."
        assert server.stdout is not None
        line = server.stdout.readline()
        if not line.startswith("FIGURE: open "):
            msg = f"{name}: the program did not print its address ({line.strip()!r})"
            raise RuntimeError(msg)
        url = line.split()[2]
        token = url.split("?token=", 1)[1] if "?token=" in url else ""
        with tempfile.TemporaryDirectory(prefix="figure-media-") as tmp:
            shot = Path(tmp) / "page.png"
            subprocess.run(
                [
                    chrome(),
                    "--no-sandbox",
                    "--use-angle=swiftshader",
                    "--enable-unsafe-swiftshader",
                    f"--window-size={width},{height}",
                    "--virtual-time-budget=4000",
                    f"--screenshot={shot}",
                    url,
                ],
                check=True,
                capture_output=True,
                timeout=60,
            )
            bar = 40  # a plain browser bar: three dots and the address
            OUT.mkdir(parents=True, exist_ok=True)
            subprocess.run(
                [
                    "convert",
                    str(shot),
                    "-background",
                    "#2a2520",
                    "-gravity",
                    "north",
                    "-splice",
                    f"0x{bar}",
                    "-fill",
                    "#ff5f57",
                    "-draw",
                    "circle 20,20 26,20",
                    "-fill",
                    "#febc2e",
                    "-draw",
                    "circle 40,20 46,20",
                    "-fill",
                    "#28c840",
                    "-draw",
                    "circle 60,20 66,20",
                    "-fill",
                    "#3a322b",
                    "-draw",
                    f"roundrectangle 90,8 {width - 20},32 12,12",
                    "-fill",
                    "#e9e2d4",
                    "-font",
                    "DejaVu-Sans",
                    "-pointsize",
                    "13",
                    "-gravity",
                    "northwest",
                    "-annotate",
                    "+108+12",
                    "localhost:8080/" + (f"?token={token}" if token else ""),
                    "-bordercolor",
                    "#2a2520",
                    "-border",
                    "1",
                    "-strip",
                    str(OUT / f"{name}.png"),
                ],
                check=True,
            )
    finally:
        server.terminate()
        server.wait(timeout=10)
    print(
        f"{name}: remote, {width}x{height}: {name}.png {(OUT / f'{name}.png').stat().st_size // 1024} KB"
    )


def record(name: str) -> None:
    """Run one recording and write its media."""
    header, script = parse(RECS / f"{name}.rec")
    if "remote" in header:
        record_remote(name, header)
        return
    frames = int(header["frames"])
    poster = int(header.get("poster", frames - 1))
    video = header.get("video", "yes" if frames > 1 else "no") == "yes"
    program = ROOT / header["program"]
    if not program.is_file():
        msg = f"{name}: {program} not built"
        raise MediaError(msg)
    with tempfile.TemporaryDirectory(prefix="figure-media-") as tmp:
        work = Path(tmp)
        (work / "input").write_text(script)
        env = dict(
            os.environ,
            FIGURE_CAPTURE=str(work / "f_"),
            FIGURE_CAPTURE_INPUT=str(work / "input"),
            FIGURE_CAPTURE_FRAMES=str(frames),
            FIGURE_CAPTURE_FROM=header.get("from", "0"),
            FIGURE_CAPTURE_FPS=str(FPS),
            FIGURE_STYLE=header.get("style", STYLE),
        )
        run = subprocess.run(
            [str(program), *shlex.split(header.get("args", ""))],
            env=env,
            cwd=program.parent,
            capture_output=True,
            text=True,
            timeout=300,
            check=False,
        )
        shots = sorted(work.glob("f_*.ppm"))
        if len(shots) != frames:
            msg = f"{name}: {len(shots)} of {frames} frames written (exit {run.returncode}): {run.stderr.strip()}"
            raise MediaError(msg)
        if "crop" in header:
            x, y, w, h = (int(v) for v in header["crop"].split())
        else:  # the union of the content boxes, sampled every few frames
            boxes = [
                b
                for f in shots[:: max(1, frames // 24)] + [shots[-1]]
                if (b := bbox(f, BACKGROUND.get(header.get("style", STYLE), "#000000")))
            ]
            if not boxes:
                msg = f"{name}: the frames are empty"
                raise MediaError(msg)
            w_full, h_full = (
                int(v) for v in shots[0].read_bytes().split(b"\n", 2)[1].split()
            )
            x = max(0, min(b[0] for b in boxes) - MARGIN)
            y = max(0, min(b[1] for b in boxes) - MARGIN)
            w = min(w_full, max(b[2] for b in boxes) + MARGIN) - x
            h = min(h_full, max(b[3] for b in boxes) + MARGIN) - y
        w -= w % 2  # H.264 with yuv420p needs even sizes
        h -= h % 2
        OUT.mkdir(parents=True, exist_ok=True)
        resize = ["-resize", f"{header['scale']}x"] if "scale" in header else []
        subprocess.run(
            [
                "convert",
                str(shots[poster]),
                "-crop",
                f"{w}x{h}+{x}+{y}",
                "+repage",
                *resize,
                "-strip",
                str(OUT / f"{name}.png"),
            ],
            check=True,
        )
        if video:
            subprocess.run(
                [
                    "ffmpeg",
                    "-loglevel",
                    "error",
                    "-y",
                    "-framerate",
                    str(FPS),
                    "-i",
                    str(work / "f_%05d.ppm"),
                    "-vf",
                    f"crop={w}:{h}:{x}:{y}"
                    + (f",scale={header['scale']}:-2" if "scale" in header else ""),
                    "-c:v",
                    "libx264",
                    "-preset",
                    "slow",
                    "-crf",
                    header.get("crf", "24"),
                    "-pix_fmt",
                    "yuv420p",
                    "-movflags",
                    "+faststart",
                    "-an",
                    str(OUT / f"{name}.mp4"),
                ],
                check=True,
            )
            if "gif" in header:  # from the video: 10 frames/s, 64 colours, no dithering (flat UI colours)
                subprocess.run(
                    [
                        "ffmpeg",
                        "-v",
                        "error",
                        "-y",
                        "-i",
                        str(OUT / f"{name}.mp4"),
                        "-vf",
                        f"fps=10,scale={header['gif']}:-1:flags=lanczos,split[a][b];"
                        "[a]palettegen=max_colors=64:stats_mode=diff[p];[b][p]paletteuse=dither=none:diff_mode=rectangle",
                        str(OUT / f"{name}.gif"),
                    ],
                    check=True,
                )
    sizes = ", ".join(
        f"{p.name} {p.stat().st_size // 1024} KB" for p in sorted(OUT.glob(f"{name}.*"))
    )
    print(f"{name}: {frames} frames, {w}x{h}: {sizes}")


def main(names: list[str]) -> int:
    """Record the given recordings, or all of them."""
    for tool in ("ffmpeg", "convert"):
        if not shutil.which(tool):
            print(f"docs_media.py: {tool} not found", file=sys.stderr)
            return 1
    names = names or sorted(p.stem for p in RECS.glob("*.rec"))
    failed = 0
    for name in names:
        try:
            record(name)
        except (
            MediaError,
            subprocess.CalledProcessError,
            subprocess.TimeoutExpired,
        ) as err:
            print(f"docs_media.py: {err}", file=sys.stderr)
            failed += 1
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
