"""Profile a benchmark scene on two builds with callgrind: the instructions by role, and their ratios.

szaghi/figure#16 §5.2. Runs ``figure_bench_scenes SCENE`` (src/tests/figure_bench_scenes.F90) under valgrind's
callgrind on two programs, the candidate (``--program``, e.g. the Fortran path's) and the reference (``--against``,
e.g. the current path's), reads each profile with ``callgrind_annotate`` (self cost per function, every function) and
sums the instructions executed (Ir) by role, the first matching ``BUCKETS`` entry naming a function's role:

- ``scene``: the scene's own data (libm's sin and cos, the program's procedures): left out of ``render``;
- ``submission``: primitives handed to a draw list (figure_core's ``core_draw_*``, figure_drawlist, the plot items'
  ``prim_*``, Dear ImGui's ``ImDrawList`` primitives; ``c_associated``, which ifx calls as a function, from
  figure_core's per-primitive checks);
- ``transform``: values mapped to pixels; ``colour``: colormaps; ``getter``: the data read; ``item``: the items'
  loops (ImPlot's templates ``RenderPrimitives*`` inline their getter, transform and submission: their cost is all
  here); ``frame``: the plot frame and FIGURE's per-frame item bookkeeping; ``imgui``: the rest of Dear ImGui;
  ``libc``: memory copies and allocation; ``other``.

Instruction counts are deterministic (the same build and scene give the same count), unlike times, which depend on
the machine's load: a change's effect on Ir is exact, and #16 asks for both measures to agree in direction (D5).

``--build gnu|nvf|ifx`` builds both programs first (``fobis build --mode tests-<c>-fortran`` and ``tests-<c>``, with
``--force-compile``: the modes share exe/obj, and an incremental build mixes their objects) and keeps them under
``--out`` (default build/profile); the compiler must be on PATH. ``--frames`` and ``--warmup`` default to the scene's
``FRAMES`` entry (30 after 2, fewer for the largest scenes: callgrind runs about 50 times slower than the program).

``--net`` subtracts the start-up: each program runs twice, over N and 2N measured frames, and the report is the
difference, the cost of N frames alone (per function, so per role too). The default counts the whole run, start-up
included, which is a small share of the large scenes and most of the smallest ones (line100: 16.6 M instructions in
all over 30 frames).

Writes a Markdown table to standard output (``--markdown FILE`` too) and, with ``--json FILE``, the counts per bucket
and per function (the 25 largest of each program). ``--self-test`` checks the parsing and the buckets on fixed text.

Usage::

    python3 scripts/profile_scene.py SCENE (--build gnu|nvf|ifx | --program P --against Q) [--frames N]
                                     [--warmup N] [--net] [--out DIR] [--json FILE] [--markdown FILE]
    python3 scripts/profile_scene.py --self-test

Standard library only (Python >= 3.11), valgrind and callgrind_annotate on PATH. Run from the repository root.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FRAMES = {"line1e7": (3, 1), "line1e8": (2, 1), "scatter1e6": (3, 1), "heatmap4096": (2, 1), "field4096": (3, 1)}
DEFAULT_FRAMES = (30, 2)
# a function's role: the first pattern matching its name (without template arguments and parameters)
BUCKETS: tuple[tuple[str, str], ...] = (
    ("scene", r"^(__)?(sin|cos|sincos|exp)(_fma|_avx2|_sse\d)?$|^_ZGV|^__fd_(sin|cos|sincos|exp)|^__svml_|"
              r"^__mth_i_d(sin|cos|exp)|^__libm_(sin|cos|sincos|exp)|field_values|figure_bench_scenes|^MAIN__$|^main$"),
    ("submission", r"core_draw_|(_MOD_|_mp_|core_)v2_?$|c_associated|ImDrawList|figure_drawlist|(_MOD_|_mp_|drawlist_)dl_|put_vtx|"
                   r"put_tri|prim_(line|quad|rect)|"
                   r"Prim(Reserve|Unreserve|QuadUV|Rect|RectUV|WriteVtx)"),
    ("transform", r"map_pixel|transform_|Transformer|plot_transform"),
    ("colour", r"(^|_)cm_|[Cc]olormap"),
    ("getter", r"coordinate|(_MOD_|_mp_|items_)point_?$|Getter|Indexer"),
    ("item", r"RenderPrimitives|Renderer[A-Z]|render_|markers_|figure_plot_items|figure_plot3d_items|Plot(Line|Scatter|"
             r"Heatmap|Image|Bars|Shaded)"),
    ("frame", r"figure_items::|plot_frame|plot3d_frame|ImPlot|ImPlot3D"),
    ("imgui", r"ImGui|ImFont|ImDraw|ImVector|^ig[A-Z]|imgui|figure_core"),
    ("libc", r"^(__)?mem(cpy|move|set|cmp)|malloc|^free$|^_int_|strlen|^__libc|^_dl_|do_lookup_x"),
)
ORDER = tuple(b for b, _ in BUCKETS) + ("other",)
_COMPILED = tuple((b, re.compile(p)) for b, p in BUCKETS)
_LINE = re.compile(r"^\s*([\d,]+)\s+\(\s*[\d.]+%\)\s+(.*)$")


def short_name(entry: str) -> str:
    """A function's name from a callgrind_annotate entry ``file:function [object]``: the file and the object dropped,
    a C++ name without its template arguments, parameters and return type."""
    if entry.endswith("]") and " [" in entry:
        entry = entry.rsplit(" [", 1)[0]
    m = re.match(r"^([^:\s]*):(.*)$", entry)
    name = m.group(2) if m else entry
    name = re.split(r"[<(]", name, maxsplit=1)[0].strip()
    return name.rsplit(" ", 1)[-1]


def bucket(name: str) -> str:
    """The role of a function (``BUCKETS``), 'other' when none matches."""
    for b, pat in _COMPILED:
        if pat.search(name):
            return b
    return "other"


def parse_annotate(text: str) -> tuple[int, dict[str, int]]:
    """The program's total Ir and the self Ir per function from callgrind_annotate's output: the function list only
    (a build with line information gets its sources annotated after it, whose counts must not be summed again)."""
    total = 0
    funcs: dict[str, int] = {}
    for line in text.splitlines():
        if line.startswith("--") and funcs:
            break  # the end of the function list
        m = _LINE.match(line)
        if not m:
            continue
        ir = int(m.group(1).replace(",", ""))
        what = m.group(2).strip()
        if what.startswith("PROGRAM TOTALS"):
            total = ir
            continue
        name = short_name(what)
        funcs[name] = funcs.get(name, 0) + ir
    return total, funcs


def by_bucket(funcs: dict[str, int]) -> dict[str, int]:
    """The functions' Ir summed by role, every role present."""
    out = dict.fromkeys(ORDER, 0)
    for name, ir in funcs.items():
        out[bucket(name)] += ir
    return out


def profile(program: Path, scene: str, frames: int, warmup: int, out: Path, label: str) -> tuple[int, dict[str, int]]:
    """Run one program under callgrind, annotate its profile; the total and the self Ir per function."""
    cg = out / f"{label}-{scene}.callgrind"
    env = dict(os.environ, SDL_VIDEO_DRIVER="offscreen", XDG_RUNTIME_DIR="/nonexistent")
    cmd = ["valgrind", "--tool=callgrind", f"--callgrind-out-file={cg}", str(program), scene, "--frames", str(frames),
           "--warmup", str(warmup)]
    proc = subprocess.run(cmd, cwd=ROOT, env=env, capture_output=True, text=True, check=False)  # noqa: S603
    if proc.returncode != 0:
        msg = f"{' '.join(cmd)}: exit status {proc.returncode}\n{proc.stderr[-2000:]}"
        raise RuntimeError(msg)
    ann = subprocess.run(["callgrind_annotate", "--inclusive=no", "--threshold=100", "--auto=no", str(cg)],  # noqa: S607
                         capture_output=True, text=True, check=True).stdout
    (out / f"{label}-{scene}.annotate.txt").write_text(ann)
    return parse_annotate(ann)


def net(program: Path, scene: str, frames: int, warmup: int, out: Path, label: str) -> tuple[int, dict[str, int]]:
    """The cost of `frames` frames alone: a run over 2 * frames minus a run over frames, per function."""
    t1, f1 = profile(program, scene, frames, warmup, out, f"{label}-n")
    t2, f2 = profile(program, scene, 2 * frames, warmup, out, f"{label}-2n")
    diff = {k: f2.get(k, 0) - f1.get(k, 0) for k in set(f1) | set(f2)}
    return t2 - t1, {k: v for k, v in diff.items() if v != 0}


def build(compiler: str, out: Path) -> tuple[Path, Path]:
    """Both programs of a compiler, built clean and copied under `out`: (Fortran path, current path)."""
    progs = []
    for mode, tag in ((f"tests-{compiler}-fortran", "fortran"), (f"tests-{compiler}", "imgui")):
        for f in (ROOT / "exe").glob("*"):
            if f.is_file():
                f.unlink()
        log = out / f"build-{mode}.log"
        with log.open("w") as fh:
            rc = subprocess.run(["fobis", "build", "--mode", mode, "--force-compile"], cwd=ROOT, stdout=fh,  # noqa: S607
                                stderr=subprocess.STDOUT, check=False).returncode
        src = ROOT / "exe" / "figure_bench_scenes"
        if rc != 0 or not src.is_file():
            msg = f"fobis build --mode {mode}: exit status {rc} (see {log})"
            raise RuntimeError(msg)
        dst = out / f"{compiler}-{tag}" / "figure_bench_scenes"
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        progs.append(dst)
    return progs[0], progs[1]


def table(scene: str, frames: int, cand: tuple[int, dict[str, int]], ref: tuple[int, dict[str, int]],
          names: tuple[str, str], net_only: bool = False) -> tuple[str, dict]:
    """The Markdown report and the JSON record of one comparison."""
    bc, br = by_bucket(cand[1]), by_bucket(ref[1])
    rc_, rr = cand[0] - bc["scene"], ref[0] - br["scene"]

    def ratio(a: int, b: int) -> str:
        return f"{a / b:.2f}" if b else ("—" if a == 0 else "∞")

    def mega(v: int) -> str:
        return f"{v / 1e6:,.1f} M"

    what = "the frames alone (start-up subtracted)" if net_only else "the whole run"
    lines = [f"**{scene}**, {frames} measured frames, {what}: instructions (Ir, self cost) by role", "",
             f"| Role | {names[0]} | {names[1]} | ratio |", "|---|---|---|---|"]
    lines += [f"| {b} | {mega(bc[b])} | {mega(br[b])} | {ratio(bc[b], br[b])} |" for b in ORDER if bc[b] or br[b]]
    lines += [f"| **render** (total minus scene) | **{mega(rc_)}** | **{mega(rr)}** | **{ratio(rc_, rr)}** |",
              f"| total | {mega(cand[0])} | {mega(ref[0])} | {ratio(cand[0], ref[0])} |"]
    top = {n: dict(sorted(p[1].items(), key=lambda kv: -kv[1])[:25]) for n, p in zip(names, (cand, ref), strict=True)}
    rec = {"scene": scene, "frames": frames, "net": net_only, "programs": list(names),
           "total": {names[0]: cand[0], names[1]: ref[0]}, "render": {names[0]: rc_, names[1]: rr},
           "buckets": {names[0]: bc, names[1]: br}, "top_functions": top}
    return "\n".join(lines) + "\n", rec


def self_test() -> int:
    """The parsing and the buckets on fixed text; 0 if every case holds."""
    cases = {
        "__figure_plot_items_MOD_render_heatmap": "item", "figure_plot_items_render_heatmap_": "item",
        "figure_plot_items_mp_render_heatmap_": "item", "__figure_plot_items_MOD_prim_line": "submission",
        "figure_plot_items_prim_quad_": "submission", "__figure_core_MOD_core_draw_quad_uv": "submission",
        "ImDrawList::PrimQuadUV": "submission", "ImDrawList_PrimQuadUV": "submission",
        "__figure_plot_transform_MOD_map_pixel": "transform", "figure_plot_transform_mp_map_pixel_": "transform",
        "__figure_plot_colormaps_MOD_cm_sample": "colour", "__figure_plot_items_MOD_coordinate": "getter",
        "__figure_plot_items_MOD_point": "getter", "figure_plot_items_point_": "getter",
        "ImPlot::RenderPrimitivesEx": "item", "figure_items::frame_begin": "frame", "__sin_fma": "scene",
        "_ZGVbN2v_sin_sse4": "scene", "field_values.4.isra.0": "scene", "__memcpy_avx_unaligned_erms": "libc",
        "ImFont::RenderText": "imgui", "ImGui::Begin": "imgui", "do_lookup_x": "libc", "_dl_relocate_object": "libc",
        "__fd_sin_4_avx2": "scene", "figure_core_v2_": "submission", "__figure_core_MOD_v2": "submission",
        "__figure_drawlist_MOD_dl_rect_filled": "submission", "figure_drawlist_dl_line_": "submission",
        "check_match": "other", "__libm_sin_l9": "scene", "iso_c_binding_mp_c_associated_ptr_": "submission",
        "figure_plot_items_mp_prim_quad_": "submission", "figure_plot_colormaps_mp_cm_sample_": "colour",
    }
    failures = [f"{n}: {bucket(n)}, expected {b}" for n, b in cases.items() if bucket(n) != b]
    sample = """\
1,483,469,427 (100.0%)  PROGRAM TOTALS
266,014,221 (17.93%)  ???:__figure_plot_items_MOD_render_heatmap [/x/bench]
189,703,936 (12.79%)  ./math/../sysdeps/ieee754/dbl-64/s_sin.c:__sin_fma [/usr/lib/x86_64-linux-gnu/libm.so.6]
108,136,050 ( 7.29%)  ???:ImDrawList::PrimQuadUV(ImVec2 const&, ImVec2 const&, unsigned int) [/x/bench]
475,798,488 (58.05%)  ???:void ImPlot::RenderPrimitivesEx<ImPlot::RendererRectC<ImPlot::GetterHeatmapRowMaj<ImPlot::\
IndexerIdx<double> > > >(ImPlot::RendererRectC<> const&, ImDrawList&, ImRect const&) [/x/bench]

--------------------------------------------------------------------------------
-- Auto-annotated source: src/paths/fortran/plot/figure_plot_items.F90
--------------------------------------------------------------------------------
12,345,678 ( 0.83%)     do idx = 0_int32, rows * cols - 1_int32
"""
    total, funcs = parse_annotate(sample)
    if total != 1483469427:
        failures.append(f"total {total}")
    expect = {"__figure_plot_items_MOD_render_heatmap": 266014221, "__sin_fma": 189703936,
              "ImDrawList::PrimQuadUV": 108136050, "ImPlot::RenderPrimitivesEx": 475798488}
    if funcs != expect:
        failures.append(f"functions {funcs}")
    b = by_bucket(funcs)
    if (b["item"], b["scene"], b["submission"]) != (266014221 + 475798488, 189703936, 108136050):
        failures.append(f"buckets {b}")
    for f in failures:
        print(f"profile_scene: self-test FAILED: {f}", file=sys.stderr)
    print(f"profile_scene: self-test: {'ok' if not failures else f'{len(failures)} failed'}")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    """Profile a scene on two programs; print and write the comparison."""
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("scene", nargs="?")
    src = ap.add_mutually_exclusive_group()
    src.add_argument("--build", choices=("gnu", "nvf", "ifx"))
    src.add_argument("--program", type=Path)
    ap.add_argument("--against", type=Path)
    ap.add_argument("--frames", type=int)
    ap.add_argument("--warmup", type=int)
    ap.add_argument("--net", action="store_true", help="the frames' cost alone, start-up subtracted")
    ap.add_argument("--out", type=Path, default=ROOT / "build" / "profile")
    ap.add_argument("--json", type=Path)
    ap.add_argument("--markdown", type=Path)
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args(argv)
    if args.self_test:
        return self_test()
    if not args.scene or not (args.build or (args.program and args.against)):
        ap.error("a scene and --build, or a scene and --program with --against")
    for tool in ("valgrind", "callgrind_annotate"):
        if shutil.which(tool) is None:
            print(f"profile_scene: {tool} not found", file=sys.stderr)
            return 2
    args.out.mkdir(parents=True, exist_ok=True)
    if args.build:
        prog, against = build(args.build, args.out)
        names = (f"{args.build} Fortran path", f"{args.build} current path")
    else:
        prog, against = args.program, args.against
        names = (f"{prog.parent.name}/{prog.name}", f"{against.parent.name}/{against.name}")
    nf, nw = FRAMES.get(args.scene, DEFAULT_FRAMES)
    nf = args.frames or nf
    nw = nw if args.warmup is None else args.warmup
    tag = args.build or "given"
    run = net if args.net else profile
    cand = run(prog, args.scene, nf, nw, args.out, f"{tag}-candidate")
    ref = run(against, args.scene, nf, nw, args.out, f"{tag}-reference")
    md, rec = table(args.scene, nf, cand, ref, names, args.net)
    print(md, end="")
    if args.markdown:
        args.markdown.write_text(md)
    if args.json:
        args.json.write_text(json.dumps(rec, indent=1) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
