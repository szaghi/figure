"""Run the benchmark scenes of #15 P2, record a baseline, compare a run with it.

Runs ``figure_bench_scenes`` (src/tests/figure_bench_scenes.F90) once per scene and per run. Each run of a scene
prints the time of every measured frame and of the scene's own calls in it (the UI, up to the draw data); this script
reduces them to the scene's statistics:

- per run: the median and the 99th percentile of the frame time and of the UI time [ms] (the rest of a frame is
  ``next_frame``'s: Dear ImGui's render, the rasterization in a window, the swap);
- over the runs (``--runs``, default 5): the median of those, and the spread, the largest minus the smallest.

``--mode window`` runs the scenes in a window (vsync and lazy redraw off); ``headless`` (the default) without one: no
rasterization, the UI's cost alone. The OpenGL renderer of a window run is read by ``glxinfo -B`` in the same
environment and recorded with the results; on WSL it is llvmpipe unless ``GALLIUM_DRIVER=d3d12``, and a window run on
llvmpipe is refused unless ``--allow-llvmpipe``.

A run either becomes a baseline or is compared with one (both in ``--file``, default docs/data/bench-scenes.json,
under a ``--label`` such as ``wsl-gnu-window``):

- ``--write LABEL``: record the run as the baseline LABEL; refused if LABEL exists (a baseline is never overwritten:
  new numbers get a new label);
- ``--compare LABEL``: compare the run with the baseline LABEL (#15 §4, "at least the same speed"). The gate is the
  medians: a scene fails when its median frame time or median UI time is worse than the baseline's by more than the
  baseline's spread, taken at least ``--floor-rel`` of the baseline's value (default 0.05) and ``--floor-ms``
  (default 0.05 ms): five runs of a scene of a tenth of a millisecond can agree to the microsecond, which no later run
  repeats (the clock's and the scheduler's jitter); exit status 1 if any fails. The 99th percentiles are reported, not
  gated: one worse than the baseline's by more than its spread, taken at least ``--p99-floor-rel`` (default 0.20) and
  ``--floor-ms``, is a warning (window-mode percentiles carry the compositor's jitter: the first reruns of the
  baselines, 2026-11-20, left the 5-run spread on 9 of 280 statistics, mostly window p99). Faster is never a failure. A scene measured over
  other frames (or another warm-up, when the baseline records it) than the baseline's is not compared: it fails as
  not comparable (a 99th percentile over 30 frames is not one over 300). A scene measured over fewer than 300 frames
  (``FRAMES``) records ``p99_valid: false`` and a ``p99_note``: its ``_p99`` values are about the largest frame time.

``--json FILE`` also writes the run (every run's statistics) to FILE. ``--scenes a,b`` runs those only; ``--frames``
and ``--warmup`` override the scene's defaults (300 measured frames after 30, except the largest scenes: 30 after 3,
see ``FRAMES``; ``SKIP`` leaves ``line1e8`` out of a window). A run of a scene that fails is run again once
(``RETRIES``), and counted in the scene's ``retries``.

Usage::

    python3 scripts/bench_scenes.py [--program exe/figure_bench_scenes] [--mode headless|window] [--runs 5]
                                    [--scenes a,b] [--compiler NAME] [--file docs/data/bench-scenes.json]
                                    (--write LABEL | --compare LABEL) [--json FILE] [--allow-llvmpipe]
                                    [--floor-rel 0.05] [--floor-ms 0.05] [--p99-floor-rel 0.20]

Standard library only (Python >= 3.11). Run from the repository root.
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import platform
import statistics
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_FILE = ROOT / "docs" / "data" / "bench-scenes.json"
SCENES = (
    "widgets", "table", "line100", "line1e4", "line1e5", "line1e6", "line1e7", "line1e8", "scatter1e6",
    "heatmap256", "heatmap512", "heatmap1024", "heatmap4096", "field512", "field1024", "field4096", "surface256",
    "editor10k",
)
# measured frames and warm-up frames of the scenes that do not take the default (300 after 30), by mode: line1e8 takes
# about 1.4 s and 14 GB a frame headless with ImPlot today (#15 G1: "where the baseline cannot"); in a window the
# largest scenes take 0.5 to 0.9 s a frame (line1e7 520 ms, heatmap4096 840 ms, scatter1e6 600 ms on the WSL box):
# 300 frames, five runs, would be hours a mode
FRAMES = {
    "headless": {"line1e8": (30, 3)},
    "window": {"line1e7": (30, 3), "scatter1e6": (30, 3), "heatmap4096": (30, 3)},
}
DEFAULT_FRAMES = (300, 30)
P99_FRAMES = 300  # frames a 99th percentile needs (#15 P2): fewer, and a scene's record says what its '_p99' is
# scenes not run in a mode, with the reason
SKIP = {"window": {"line1e8": "8 GB of vertices a frame for the GPU: the baseline cannot draw it in a window"}}
RETRIES = 1  # a scene's run that fails is run again once (a window closed under a long frame once, 2026-11-20)


def percentile(values: list[float], q: float) -> float:
    """The q-th percentile (0-100) of values, linear between the closest ranks (NumPy's default)."""
    v = sorted(values)
    pos = (len(v) - 1) * q / 100.0
    lo = int(pos)
    hi = min(lo + 1, len(v) - 1)
    return v[lo] + (v[hi] - v[lo]) * (pos - lo)


def p99_valid(frames: int) -> bool:
    """Whether a 99th percentile over `frames` frames is the one #15 P2 asks for (at least 300 frames)."""
    return frames >= P99_FRAMES


def p99_note(frames: int) -> str:
    """What the '_p99' statistics are over fewer than 300 frames."""
    kind = "the largest frame time" if frames <= 100 else "a 99th percentile of few frames"
    return (f"over {frames} frames, not the {P99_FRAMES} #15 P2 asks for: the '_p99' values are {kind}, the time a "
            "frame takes per FRAMES' reason; compare them as such")


@dataclass
class RunStats:
    """One run of one scene: the statistics of its frames [ms]."""

    frames: int
    frame_median: float
    frame_p99: float
    ui_median: float
    ui_p99: float


@dataclass
class SceneStats:
    """A scene over the runs: the median of each statistic and its spread (largest minus smallest) [ms]."""

    runs: list[RunStats] = field(default_factory=list)
    retries: int = 0  # runs that failed and were run again
    warmup: int = 0  # frames not measured before each run's measured ones

    def summary(self) -> dict[str, float | int]:
        """The scene's record: medians and spreads of the four statistics, the frames per run."""
        frames = self.runs[0].frames
        out: dict[str, float | int | str] = {"frames": frames, "runs": len(self.runs), "retries": self.retries,
                                           "warmup": self.warmup}
        for key in ("frame_median", "frame_p99", "ui_median", "ui_p99"):
            vals = [getattr(r, key) for r in self.runs]
            out[key] = round(statistics.median(vals), 4)
            out[f"{key}_spread"] = round(max(vals) - min(vals), 4)
        out["p99_valid"] = p99_valid(frames)
        if not out["p99_valid"]:
            out["p99_note"] = p99_note(frames)
        return out


def run_scene(program: Path, scene: str, mode: str, frames: int, warmup: int) -> RunStats:
    """Run one scene once and reduce its frames."""
    cmd = [str(program), scene, "--frames", str(frames), "--warmup", str(warmup)]
    if mode == "window":
        cmd.append("--window")
    proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, check=False)  # noqa: S603
    if proc.returncode != 0:
        msg = f"{' '.join(cmd)}: exit status {proc.returncode}\n{proc.stdout[-2000:]}{proc.stderr[-2000:]}"
        raise RuntimeError(msg)
    t_frame, t_ui = [], []
    for line in proc.stdout.splitlines():
        words = line.split()
        if len(words) == 3 and words[0] == "t":
            t_frame.append(float(words[1]))
            t_ui.append(float(words[2]))
    if len(t_frame) != frames:
        msg = f"{scene}: {len(t_frame)} frames printed, {frames} expected"
        raise RuntimeError(msg)
    return RunStats(frames, statistics.median(t_frame), percentile(t_frame, 99.0), statistics.median(t_ui),
                    percentile(t_ui, 99.0))


def renderer(mode: str) -> str:
    """The OpenGL renderer a window gets in this environment (``glxinfo -B``); 'none' headless."""
    if mode == "headless":
        return "none (headless: no rasterization)"
    try:
        out = subprocess.run(["glxinfo", "-B"], capture_output=True, text=True, check=False, timeout=30).stdout  # noqa: S607
    except (OSError, subprocess.TimeoutExpired) as err:
        return f"unknown ({err})"
    for line in out.splitlines():
        if "OpenGL renderer string" in line:
            return line.split(":", 1)[1].strip()
    return "unknown (glxinfo printed no renderer)"


def machine() -> str:
    """The machine: the system, the CPU model and its hardware threads."""
    cpu = platform.processor() or platform.machine()
    cpuinfo = Path("/proc/cpuinfo")
    if cpuinfo.is_file():
        for line in cpuinfo.read_text().splitlines():
            if line.startswith("model name"):
                cpu = line.split(":", 1)[1].strip()
                break
    return f"{platform.system()} {platform.release()}, {cpu}, {os.cpu_count()} hardware threads"


def measure(program: Path, scenes: list[str], mode: str, runs: int, frames: int | None,
            warmup: int | None) -> dict[str, SceneStats]:
    """Every scene `runs` times, the runs interleaved (scene after scene, then again) so that a slow minute of the
    machine spreads over the scenes instead of biasing one."""
    out = {s: SceneStats() for s in scenes}
    for k in range(runs):
        for s in scenes:
            nf, nw = FRAMES[mode].get(s, DEFAULT_FRAMES)
            out[s].warmup = nw if warmup is None else warmup
            for attempt in range(RETRIES + 1):
                try:
                    stats = run_scene(program, s, mode, frames or nf, nw if warmup is None else warmup)
                    break
                except RuntimeError as err:
                    if attempt == RETRIES:
                        raise
                    out[s].retries += 1
                    print(f"run {k + 1}/{runs} {s}: failed, run again: {str(err).splitlines()[0]}", flush=True)
            out[s].runs.append(stats)
            print(f"run {k + 1}/{runs} {s}: frame median {stats.frame_median:.3f} ms, p99 {stats.frame_p99:.3f} ms; "
                  f"UI median {stats.ui_median:.3f} ms, p99 {stats.ui_p99:.3f} ms", flush=True)
    return out


GATED = ("frame_median", "ui_median")  # the gate: "at least the same speed" (#15 §4)
REPORTED = ("frame_p99", "ui_p99")     # warnings only


def compare(base: dict, run: dict[str, dict], floor_rel: float, floor_ms: float,
            p99_floor_rel: float = 0.20) -> tuple[list[str], list[str]]:
    """The scenes of `run` worse than `base`: the failures (a median worse by more than the baseline's spread, at
    least `floor_rel` of the baseline's value and `floor_ms`) and the warnings (a 99th percentile worse by more than
    its spread, at least `p99_floor_rel` and `floor_ms`), each with what and by how much."""
    worse: list[str] = []
    warn: list[str] = []
    for scene, now in run.items():
        ref = base["scenes"].get(scene)
        if ref is None:
            worse.append(f"{scene}: not in the baseline")
            continue
        if now["frames"] != ref["frames"] or now.get("warmup", ref.get("warmup")) != ref.get("warmup", now.get("warmup")):
            worse.append(f"{scene}: not comparable: {now['frames']} frames after {now.get('warmup')}, the baseline "
                         f"{ref['frames']} after {ref.get('warmup')} (a 99th percentile depends on the frames)")
            continue
        for keys, rel, out in ((GATED, floor_rel, worse), (REPORTED, p99_floor_rel, warn)):
            for key in keys:
                excess = now[key] - ref[key]
                allowed = max(ref[f"{key}_spread"], rel * ref[key], floor_ms)
                if excess > allowed:
                    out.append(f"{scene}: {key} {now[key]:.3f} ms, baseline {ref[key]:.3f} ms "
                               f"(+{excess:.3f} ms, allowed {allowed:.3f} ms: spread {ref[f'{key}_spread']:.3f} ms)")
    return worse, warn


def main(argv: list[str]) -> int:
    """Run the scenes; write a baseline, or compare with one."""
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("--program", type=Path, default=ROOT / "exe" / "figure_bench_scenes")
    ap.add_argument("--mode", choices=("headless", "window"), default="headless")
    ap.add_argument("--runs", type=int, default=5)
    ap.add_argument("--scenes", default=",".join(SCENES))
    ap.add_argument("--frames", type=int)
    ap.add_argument("--warmup", type=int)
    ap.add_argument("--compiler", default="unknown", help="the compiler the program was built with (recorded)")
    ap.add_argument("--file", type=Path, default=DEFAULT_FILE)
    what = ap.add_mutually_exclusive_group()
    what.add_argument("--write", metavar="LABEL")
    what.add_argument("--compare", metavar="LABEL")
    ap.add_argument("--json", type=Path, metavar="FILE")
    ap.add_argument("--allow-llvmpipe", action="store_true")
    ap.add_argument("--floor-rel", type=float, default=0.05)
    ap.add_argument("--floor-ms", type=float, default=0.05)
    ap.add_argument("--p99-floor-rel", type=float, default=0.20)
    args = ap.parse_args(argv)
    if not (args.write or args.compare or args.json):
        ap.error("one of --write, --compare, --json is required")

    scenes = [s for s in args.scenes.split(",") if s]
    unknown = [s for s in scenes if s not in SCENES]
    skipped = {s: why for s, why in SKIP.get(args.mode, {}).items() if s in scenes}
    scenes = [s for s in scenes if s not in skipped]
    if unknown or args.runs < 1:
        print(f"bench_scenes: unknown scene {unknown[0]}" if unknown else "bench_scenes: --runs must be >= 1",
              file=sys.stderr)
        return 2
    data = json.loads(args.file.read_text()) if args.file.is_file() else {"baselines": {}}
    if args.write and args.write in data["baselines"]:
        print(f"bench_scenes: the baseline {args.write} exists in {args.file}: a baseline is never overwritten "
              "(give the new numbers a new label)", file=sys.stderr)
        return 2
    if args.compare and args.compare not in data["baselines"]:
        print(f"bench_scenes: no baseline {args.compare} in {args.file}", file=sys.stderr)
        return 2
    gl = renderer(args.mode)
    print(f"bench_scenes: {args.mode}, renderer: {gl}", flush=True)
    if args.mode == "window" and "llvmpipe" in gl.lower() and not args.allow_llvmpipe:
        print("bench_scenes: the window would render on llvmpipe (software); on WSL set GALLIUM_DRIVER=d3d12, or pass "
              "--allow-llvmpipe", file=sys.stderr)
        return 2

    stats = measure(args.program, scenes, args.mode, args.runs, args.frames, args.warmup)
    record = {
        "date": datetime.date.today().isoformat(),
        "machine": machine(),
        "compiler": args.compiler,
        "mode": args.mode,
        "renderer": gl,
        "environment": {k: os.environ[k] for k in ("GALLIUM_DRIVER",) if k in os.environ},
        "program": str(args.program.relative_to(ROOT) if args.program.is_relative_to(ROOT) else args.program),
        "statistics": "per scene: the median over the runs of each run's median and 99th percentile [ms] of the frame "
                      "time and of the UI time (the scene's own calls), and their spread (largest minus smallest)",
        "scenes": {s: st.summary() for s, st in stats.items()},
        "skipped": skipped,
        "per_run": {s: [vars(r) for r in st.runs] for s, st in stats.items()},
    }
    for s, rec in record["scenes"].items():
        tail = "p99" if rec["p99_valid"] else f"max-like ({rec['frames']} frames)"
        print(f"{s:12s} frame {rec['frame_median']:9.3f} ms (spread {rec['frame_median_spread']:.3f}), {tail} "
              f"{rec['frame_p99']:9.3f} ms; UI {rec['ui_median']:9.3f} ms, {tail} {rec['ui_p99']:9.3f} ms")
    if args.json:
        args.json.write_text(json.dumps(record, indent=1) + "\n")
        print(f"bench_scenes: written {args.json}")
    if args.write:
        data.setdefault("tool", "scripts/bench_scenes.py running src/tests/figure_bench_scenes.F90 (#15 P2)")
        data["baselines"][args.write] = record
        args.file.write_text(json.dumps(data, indent=1) + "\n")
        print(f"bench_scenes: baseline {args.write} written to {args.file}")
    if args.compare:
        worse, warn = compare(data["baselines"][args.compare], record["scenes"], args.floor_rel, args.floor_ms,
                              args.p99_floor_rel)
        for w in warn:
            print(f"bench_scenes: warning (p99, not gated): {w}", file=sys.stderr)
        for w in worse:
            print(f"bench_scenes: worse: {w}", file=sys.stderr)
        print(f"bench_scenes: {len(scenes) - len({w.split(':')[0] for w in worse})} of {len(scenes)} scenes within "
              f"the baseline {args.compare} and its spread")
        return 1 if worse else 0
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
