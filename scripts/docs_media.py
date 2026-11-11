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
    #! crf     26                                      H.264 quality, lower is better and larger (default 26)
    #! style   seal                                    the program's style, through FIGURE_STYLE (default seal)
    #! gif     640                                     also an animated GIF of the video, this wide (for the README:
                                                       GitHub plays no repository video there)
    #! keys                                            a caption of each key chord pressed, at the bottom of the
                                                       video, for 1.5 s (``ctrl+s``, ``down``, ``f5``)
    #! pointer no                                      no pointer drawn (default: the pointer is drawn in a video
                                                       once the script moves it, ringed while a button is held)
    #! remote  1100 700                                remote mode: the program is started with its args, then
                                                       "--remote PORT", and a headless Chromium (CHROME, or
                                                       puppeteer's) draws the page at this size; the still gets a
                                                       browser bar (no input script)
    #! mask    x y w h                                 --check: a rectangle of the poster [pixels] left out (a clock,
                                                       anything drawn from the wall time); one line each
    #! check   threshold=2 max_failed=0                --check's tolerance (the defaults shown); ``#! check.linux``,
                                                       ``check.darwin``, ``check.win32``: for that platform only,
                                                       where a difference was measured there
    0 move 300 120
    ...

The program runs in a real window, on the GPU, with the capture of the native layer: no screen recorder, the frames
are the program's own back buffer, at a fixed frame time, with only the scripted input. Each recording is cropped to
the bounding box of everything that is not the window background (over all its frames, plus a margin), then written
to docs/public/media/<name>.png (the poster) and, for animations, docs/public/media/<name>.mp4 (H.264, no audio).
The program's back buffer has no pointer: in a video the recorder draws it where the script puts it (the native
layer's glide replayed), with a ring while a button is held, and, with ``#! keys``, a caption of each key chord, so
that a viewer sees what was pressed. The poster is the program's frame as it is, without them.

Usage: python3 scripts/docs_media.py [name ...]          (default: every docs/media/*.rec)
       python3 scripts/docs_media.py --check [name ...]  render each recording headless with FIGURE's CPU renderer
                                                         (FIGURE_CAPTURE_HEADLESS=1: no window, no GPU) and compare
                                                         the poster with the committed one: per channel |d| <= 2, no
                                                         pixel more (the #! check and #! mask lines aside); on a
                                                         failure writes docs/public/media/<name>.new.png and
                                                         <name>.diff.png; exit status 1 if any failed
       python3 scripts/docs_media.py --update [name ...] accept the .new.png pictures --check wrote (each replaces its
                                                         <name>.png; the .diff.png removed)
--check writes no committed file. It is run on demand, not in CI yet: the posters of v0.4.0 were recorded on a GPU
or in software (llvmpipe), not by the CPU renderer, so they fail until the documentation pass (#7 S9) records them
all again with it; remote recordings (a browser's picture) are not checked.
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
from concurrent.futures import ThreadPoolExecutor
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
THRESHOLD = 2  # --check: the largest difference of a channel that passes (0-255), as test_compare_image's default
MAX_FAILED = 0  # --check: pixels allowed to differ by more
FPS = 30
CAPTION_FRAMES = 45  # a key caption stays 1.5 s, or until the next one
CAPTION_FONT = ROOT / "third_party" / "fonts" / "IBMPlexSans-Regular.ttf"
MODIFIERS = ("ctrl", "shift", "alt", "super")
KEY_NAMES = {"escape": "esc", "pageup": "page up", "pagedown": "page down", "backspace": "backspace"}
# the pointer: an arrow, its tip at (0, 0) [pixels], white with a dark outline
ARROW = [(0, 0), (0, 17), (4, 13), (7, 20), (10, 19), (7, 12), (12, 12)]


class MediaError(Exception):
    """A recording failed."""


def parse(rec: Path) -> tuple[dict[str, str], str]:
    """Header fields and the input script of a recording."""
    header: dict[str, str] = {}
    script = []
    for line in rec.read_text().splitlines():
        if line.startswith("#!"):
            key, _, value = line[2:].strip().partition(" ")
            if key == "mask" and "mask" in header:  # several rectangles, one a line
                header[key] += ";" + value.strip()
            else:
                header[key] = value.strip()
        else:
            script.append(line)
    for key in ("program", "frames"):
        if key not in header:
            msg = f"{rec.name}: missing '#! {key}'"
            raise MediaError(msg)
    return header, "\n".join(script) + "\n"


def overlays(script: str, frames: int, first: int) -> list[tuple[tuple[float, float] | None, bool, str]]:
    """For each recorded frame: the pointer [pixels] (None before the script moves it), whether a button is held,
    and the key caption shown ('' none). The pointer replays the native layer's glide (capture_apply_input in
    native/figure_native.cpp): a move to (x, y) over n frames covers 1/n of the way left on each frame."""
    events: list[tuple[int, list[str]]] = []
    for line in script.splitlines():
        words = line.split()
        if len(words) >= 2 and not line.lstrip().startswith("#") and words[0].lstrip("-").isdigit():
            events.append((int(words[0]), words[1:]))
    events.sort(key=lambda e: e[0])
    px = py = gx = gy = 0.0
    glide = 0
    moved = False
    held: set[str] = set()  # mouse buttons
    mods: list[str] = []  # modifier keys held, in the order pressed
    caption, until = "", -1
    out = []
    k = 0
    for frame in range(first + frames):
        if glide > 0:
            px += (gx - px) / glide
            py += (gy - py) / glide
            glide -= 1
        while k < len(events) and events[k][0] <= frame:
            what = events[k][1]
            if what[0] == "move" and len(what) >= 3:
                gx, gy = float(what[1]), float(what[2])
                glide = max(1, int(what[3])) if len(what) >= 4 else 1
                px += (gx - px) / glide
                py += (gy - py) / glide
                glide -= 1
                moved = True
            elif what[0] in ("down", "up"):
                button = what[1] if len(what) >= 2 else "left"
                (held.add if what[0] == "down" else held.discard)(button)
            elif what[0] == "key" and len(what) >= 2:
                name, state = what[1], (what[2] if len(what) >= 3 else "")
                if name in MODIFIERS:
                    if state == "down" and name not in mods:
                        mods.append(name)
                    elif state == "up" and name in mods:
                        mods.remove(name)
                elif state != "up":  # a key pressed (and released), or pressed and held
                    caption = "+".join([*mods, KEY_NAMES.get(name, name)])
                    until = frame + CAPTION_FRAMES
            k += 1
        if frame >= first:
            out.append(((px, py) if moved else None, bool(held), caption if frame < until else ""))
    return out


def annotate(src: Path, dst: Path, crop: tuple[int, int, int, int], pointer: tuple[float, float] | None,
             pressed: bool, caption: str) -> None:
    """One video frame: cropped, with the pointer and the key caption drawn on it."""
    x, y, w, h = crop
    draw: list[str] = []
    if pointer is not None:
        ox, oy = pointer[0] - x, pointer[1] - y
        if pressed:
            draw += ["-fill", "none", "-stroke", "#e8553a", "-strokewidth", "2",
                     "-draw", f"circle {ox:.1f},{oy:.1f} {ox + 11:.1f},{oy:.1f}"]
        pts = " ".join(f"{ox + ax:.1f},{oy + ay:.1f}" for ax, ay in ARROW)
        draw += ["-fill", "#ffffff", "-stroke", "#1a1a1a", "-strokewidth", "1.2", "-draw", f"polygon {pts}"]
    if caption:
        draw += ["-stroke", "none", "-fill", "#f4efe6", "-undercolor", "#000000c0", "-font", str(CAPTION_FONT),
                 "-pointsize", "22", "-gravity", "south", "-annotate", "+0+18", f"  {caption}  "]
    subprocess.run(["convert", str(src), "-crop", f"{w}x{h}+{x}+{y}", "+repage", *draw, str(dst)], check=True)


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
        [str(program), *shlex.split(header.get("args", "")), "--remote", str(port)],
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


def capture(name: str, header: dict[str, str], script: str, work: Path, headless: bool) -> tuple[list[Path],
                                                                                            tuple[int, int, int, int]]:
    """Run the program of a recording with the native layer's capture into `work`: its frames and the crop (x, y, w, h)
    of the poster and the video. `headless`: no window, the frames drawn by FIGURE's CPU renderer."""
    frames = int(header["frames"])
    program = ROOT / header["program"]
    if not program.is_file():
        msg = f"{name}: {program} not built"
        raise MediaError(msg)
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
    if headless:
        env["FIGURE_CAPTURE_HEADLESS"] = "1"
    else:
        env.pop("FIGURE_CAPTURE_HEADLESS", None)
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
        w_full, h_full = (int(v) for v in shots[0].read_bytes().split(b"\n", 2)[1].split())
        x = max(0, min(b[0] for b in boxes) - MARGIN)
        y = max(0, min(b[1] for b in boxes) - MARGIN)
        w = min(w_full, max(b[2] for b in boxes) + MARGIN) - x
        h = min(h_full, max(b[3] for b in boxes) + MARGIN) - y
    w -= w % 2  # H.264 with yuv420p needs even sizes
    h -= h % 2
    return shots, (x, y, w, h)


def write_poster(shot: Path, crop: tuple[int, int, int, int], header: dict[str, str], dst: Path) -> None:
    """The poster: one frame, cropped (and scaled), as a PNG."""
    x, y, w, h = crop
    resize = ["-resize", f"{header['scale']}x"] if "scale" in header else []
    dst.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["convert", str(shot), "-crop", f"{w}x{h}+{x}+{y}", "+repage", *resize, "-strip", str(dst)],
        check=True,
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
    with tempfile.TemporaryDirectory(prefix="figure-media-") as tmp:
        work = Path(tmp)
        shots, (x, y, w, h) = capture(name, header, script, work, headless=False)
        write_poster(shots[poster], (x, y, w, h), header, OUT / f"{name}.png")
        if video:
            marks = overlays(script, frames, int(header.get("from", "0")))
            if header.get("pointer", "yes") == "no":
                marks = [(None, False, c) for _, _, c in marks]
            if "keys" not in header or header["keys"] == "no":
                marks = [(p, b, "") for p, b, _ in marks]
            frames_in, crop_filter = str(work / "f_%05d.ppm"), f"crop={w}:{h}:{x}:{y},"
            if any(p is not None or c for p, _, c in marks):  # drawn on the cropped frames, then encoded
                crop = (x, y, w, h)
                with ThreadPoolExecutor(max_workers=os.cpu_count() or 4) as pool:
                    list(pool.map(lambda i: annotate(shots[i], work / shots[i].name.replace("f_", "a_", 1), crop,
                                                     *marks[i]), range(frames)))
                frames_in, crop_filter = str(work / "a_%05d.ppm"), ""
            subprocess.run(
                [
                    "ffmpeg",
                    "-loglevel",
                    "error",
                    "-y",
                    "-framerate",
                    str(FPS),
                    "-start_number",
                    str(int(shots[0].stem.split("_")[-1])),
                    "-i",
                    frames_in,
                    "-vf",
                    (crop_filter + (f"scale={header['scale']}:-2" if "scale" in header else "null")).rstrip(","),
                    "-c:v",
                    "libx264",
                    "-preset",
                    "slow",
                    "-crf",
                    header.get("crf", "26"),
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
        f"{p.name} {p.stat().st_size // 1024} KB"
        for p in sorted(OUT.glob(f"{name}.*"))
        if not p.name.endswith((".new.png", ".diff.png"))
    )
    print(f"{name}: {frames} frames, {w}x{h}: {sizes}")


def pixels(png: Path) -> tuple[int, int, bytes]:
    """Width, height and RGBA bytes (rows from the top) of a picture."""
    size = subprocess.run(
        ["identify", "-format", "%w %h", str(png)], check=True, capture_output=True, text=True
    ).stdout.split()
    raw = subprocess.run(["convert", str(png), "-depth", "8", "rgba:-"], check=True, capture_output=True).stdout
    return int(size[0]), int(size[1]), raw


def tolerance(header: dict[str, str]) -> tuple[int, int]:
    """--check's threshold and max_failed: the defaults, then "#! check", then "#! check.<this platform>"."""
    values = {"threshold": THRESHOLD, "max_failed": MAX_FAILED}
    for key in ("check", f"check.{sys.platform}"):
        for item in header.get(key, "").split():
            k, _, v = item.partition("=")
            if k not in values or not v.isdigit():
                msg = f"#! {key}: '{item}' is not threshold=N or max_failed=N"
                raise MediaError(msg)
            values[k] = int(v)
    return values["threshold"], values["max_failed"]


def masks(header: dict[str, str]) -> list[tuple[int, int, int, int]]:
    """The rectangles (x, y, w, h) [pixels of the poster] "#! mask" leaves out."""
    out = []
    for part in header.get("mask", "").split(";"):
        if part.strip():
            values = part.split()
            if len(values) != 4 or not all(v.isdigit() for v in values):
                msg = f"#! mask: '{part.strip()}' is not x y w h"
                raise MediaError(msg)
            x, y, w, h = (int(v) for v in values)
            out.append((x, y, w, h))
    return out


def compare(new: Path, ref: Path, threshold: int, max_failed: int, boxes: list[tuple[int, int, int, int]],
            diff: Path) -> tuple[bool, str]:
    """test_compare_image's rule (src/lib/figure_testing.F90): the same size, and at most max_failed pixels outside
    the masks with a channel differing by more than threshold. On a failure, a diff picture (failed pixels red, those
    within the threshold dark red, masked ones blue, the rest the reference faded). The outcome and a summary."""
    w, h, a = pixels(new)
    wr, hr, b = pixels(ref)
    if (w, h) != (wr, hr):
        return False, f"{w}x{h} pixels, the committed poster {wr}x{hr}"
    masked = bytearray(w * h)
    for x, y, mw, mh in boxes:
        for j in range(max(0, y), min(h, y + mh)):
            masked[j * w + max(0, x) : j * w + min(w, x + mw)] = b"\x01" * max(0, min(w, x + mw) - max(0, x))
    failed, worst, where = 0, 0, (0, 0)
    out = bytearray(w * h * 3)
    for k in range(w * h):
        p = 4 * k
        d = max(abs(a[p] - b[p]), abs(a[p + 1] - b[p + 1]), abs(a[p + 2] - b[p + 2]), abs(a[p + 3] - b[p + 3]))
        lum = (3 * b[p] + 6 * b[p + 1] + b[p + 2]) // 10
        if masked[k]:
            out[3 * k : 3 * k + 3] = bytes((lum // 4, lum // 4, 96 + lum // 3))
        elif d > threshold:
            failed += 1
            out[3 * k : 3 * k + 3] = b"\xff\x00\x00"
            if d > worst:
                worst, where = d, (k % w, k // w)
        elif d > 0:
            out[3 * k : 3 * k + 3] = bytes((140, 30, 30))
        else:
            out[3 * k : 3 * k + 3] = bytes((lum // 3, lum // 3, lum // 3))
    if failed <= max_failed:
        return True, f"{failed} pixels over {threshold}"
    subprocess.run(["convert", "-size", f"{w}x{h}", "-depth", "8", "rgb:-", str(diff)], input=bytes(out), check=True)
    return False, f"{failed} pixels differ by more than {threshold} ({max_failed} allowed), the most by {worst} at {where}"


def check(name: str) -> str:
    """Render one recording headless with the CPU renderer and compare its poster with the committed one: 'pass',
    'fail' (the .new.png and .diff.png written beside it) or 'skip'."""
    header, script = parse(RECS / f"{name}.rec")
    new, diff, ref = OUT / f"{name}.new.png", OUT / f"{name}.diff.png", OUT / f"{name}.png"
    if "remote" in header:
        print(f"{name}: skipped (remote: a browser's picture)")
        return "skip"
    if not ref.is_file():
        print(f"{name}: skipped (no committed poster)")
        return "skip"
    frames = int(header["frames"])
    poster = int(header.get("poster", frames - 1))
    threshold, max_failed = tolerance(header)
    with tempfile.TemporaryDirectory(prefix="figure-media-") as tmp:
        work = Path(tmp)
        shots, crop = capture(name, header, script, work, headless=True)
        write_poster(shots[poster], crop, header, work / "poster.png")
        diff.unlink(missing_ok=True)  # an earlier run's: compare writes it again on a failure of the same size
        ok, summary = compare(work / "poster.png", ref, threshold, max_failed, masks(header), diff)
        if ok:
            new.unlink(missing_ok=True)
        else:
            shutil.copyfile(work / "poster.png", new)
    print(f"{name}: {'pass' if ok else 'FAIL'}: {summary}" + ("" if ok else f": see {new.name}, {diff.name}"))
    return "pass" if ok else "fail"


def update(names: list[str]) -> int:
    """Accept the .new.png pictures of --check: each replaces its poster, its .diff.png removed."""
    found = sorted(OUT.glob("*.new.png"))
    if names:
        found = [p for p in found if p.name.removesuffix(".new.png") in names]
    for p in found:
        name = p.name.removesuffix(".new.png")
        p.replace(OUT / f"{name}.png")
        (OUT / f"{name}.diff.png").unlink(missing_ok=True)
        print(f"{name}: {name}.png updated")
    if not found:
        print("docs_media.py: no .new.png to accept")
    return 0


def main(args: list[str]) -> int:
    """Record the given recordings, or all of them; --check compares, --update accepts."""
    mode = args[0] if args and args[0] in ("--check", "--update") else ""
    names = args[1:] if mode else args
    if mode == "--update":
        return update(names)
    for tool in ("ffmpeg", "convert", "identify") if not mode else ("convert", "identify"):
        if not shutil.which(tool):
            print(f"docs_media.py: {tool} not found", file=sys.stderr)
            return 1
    names = names or sorted(p.stem for p in RECS.glob("*.rec"))
    failed = 0
    outcomes: dict[str, int] = {"pass": 0, "fail": 0, "skip": 0}
    for name in names:
        try:
            if mode == "--check":
                outcomes[check(name)] += 1
                continue
            record(name)
        except (
            MediaError,
            subprocess.CalledProcessError,
            subprocess.TimeoutExpired,
        ) as err:
            print(f"docs_media.py: {err}", file=sys.stderr)
            failed += 1
    if mode == "--check":
        print(f"docs_media.py --check: {outcomes['pass']} passed, {outcomes['fail']} failed, {outcomes['skip']} skipped"
              f", {failed} not rendered")
        return 1 if failed or outcomes["fail"] else 0
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
