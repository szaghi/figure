"""Measure what redrawing a FIGURE interface costs, in a window and in remote mode (Linux).

Runs ``figure_bench_redraw`` (src/examples) through a list of cases. For each case it records:

- frames per second, and the time per frame in the program's own code and inside ``next_frame`` (from the program);
- CPU time per frame and CPU load (user + system, from the kernel's accounting of the finished process);
- in a window: the split of ``next_frame`` into waiting, rendering and swapping (``FIGURE_DEBUG_REDRAW``);
- in remote mode: the bytes received by a recording WebSocket client, per second and per frame, by message kind and,
  for the frames, by part (vertices, indices, commands); then an offline analysis of the recorded frames: how many are
  identical to the previous one, and what deflate (zlib, levels 1 and 6) and a delta against the previous frame
  followed by deflate would save, with the time deflate takes.

Usage::

    python3 scripts/measure_redraw.py [--program exe/figure_bench_redraw] [--seconds 10] [--only NAME ...]
                                      [--json results.json] [--port PORT] [--connect HOST:PORT]

``--connect`` measures a program already running elsewhere (for example on a cluster node, through an SSH tunnel):
the script records the stream only; CPU and frame counts then come from that program's own output. Results print as
a Markdown table and, with ``--json``, are written for the documentation's charts. Standard library only
(Python >= 3.11). Run from the repository root.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import math
import os
import socket
import struct
import subprocess
import sys
import threading
import time
import zlib
from dataclasses import dataclass, field
from pathlib import Path

HERE = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location("remote_client", HERE / "remote_client.py")
assert _spec is not None and _spec.loader is not None
remote_client = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(remote_client)

WARMUP_S = 3  # seconds not measured: start-up, font atlas, first frames
KEEP_BYTES = 400 << 20  # frames kept for the offline analysis, at most [bytes]


@dataclass
class Case:
    """One measured case: a name and the benchmark's arguments."""

    name: str
    args: list[str]
    remote: bool
    pointer: bool = False  # remote mode: the client moves the pointer every 1/60 s


def default_cases() -> list[Case]:
    """The S11 matrix: every case locally and in remote mode."""
    base = [
        ("idle", ["idle"], False),
        ("interact", ["interact"], True),
        ("live-1", ["live", "--rate", "1"], False),
        ("live-10", ["live", "--rate", "10"], False),
        ("live-60", ["live", "--rate", "60"], False),
        ("bigplot-1e5", ["bigplot", "--points", "100000", "--rate", "10"], False),
        ("bigplot-1e6", ["bigplot", "--points", "1000000", "--rate", "10"], False),
        ("heatmap-256", ["heatmap", "--cells", "256", "--rate", "10"], False),
        ("texture-4k", ["texture", "--rate", "10"], False),
    ]
    cases = [Case(f"{n} local", a, remote=False) for n, a, _ in base]
    cases += [Case(f"{n} remote", a, remote=True, pointer=p) for n, a, p in base]
    return cases


@dataclass
class Stream:
    """What a recording client received."""

    messages: dict[int, int] = field(default_factory=dict)  # bytes by message kind
    counts: dict[int, int] = field(default_factory=dict)  # messages by kind
    inflated: dict[int, int] = field(default_factory=dict)  # bytes by message kind, before deflate
    deflated: int = 0  # messages that came deflated
    vertices: int = 0  # frame bytes in vertex buffers
    indices: int = 0  # frame bytes in index buffers
    commands: int = 0  # frame bytes in draw commands
    headers: int = 0  # frame and list headers
    frames: list[bytes] = field(default_factory=list)  # kept frame messages, in order
    kept: int = 0  # bytes kept
    first: float = 0.0  # time of the first frame
    last: float = 0.0  # time of the last frame


def list_layout(m: bytes, p: int) -> tuple[int, int, int, int, int]:
    """A draw list at `p`: vertex, index and command counts, vertex size (12 compact, 20 float), total bytes."""
    nv, ni, nc, flags = struct.unpack_from("<IIII", m, p)
    stride = 12 if flags & 1 else 20
    return nv, ni, nc, stride, 16 + nv * stride + ni * 2 + (ni % 2) * 2 + nc * 32


def split_frame(m: bytes, st: Stream) -> None:
    """Add a frame message's parts to the totals."""
    nlists = struct.unpack_from("<I", m, 9)[0]
    p = 13
    st.headers += 13
    for _ in range(nlists):
        nv, ni, nc, stride, n = list_layout(m, p)
        st.headers += 16
        st.vertices += nv * stride
        st.indices += ni * 2 + (ni % 2) * 2
        st.commands += nc * 32
        p += n


def record(ws: remote_client.WebSocket, st: Stream, stop: threading.Event, warm: threading.Event) -> None:
    """Receive until the server closes or `stop` is set; count from `warm` on."""
    ws.s.settimeout(1.0)
    while not stop.is_set():
        try:
            m = ws.recv()
        except TimeoutError:
            continue
        except (EOFError, OSError):
            return
        if not warm.is_set():
            continue
        wire = len(m)
        if m[0] == 6:  # deflated: counted as sent, analysed inflated
            m = zlib.decompress(m[1:])
            st.deflated += 1
        kind = m[0]
        st.messages[kind] = st.messages.get(kind, 0) + wire
        st.inflated[kind] = st.inflated.get(kind, 0) + len(m)
        st.counts[kind] = st.counts.get(kind, 0) + 1
        if kind == 1:
            now = time.monotonic()
            if not st.first:
                st.first = now
            st.last = now
            split_frame(m, st)
            if st.kept + len(m) <= KEEP_BYTES:
                st.frames.append(m)
                st.kept += len(m)


def move_pointer(ws: remote_client.WebSocket, stop: threading.Event) -> None:
    """The remote user: the pointer circles over the interface, 60 events per second."""
    k = 0
    while not stop.is_set():
        x = 640.0 + 400.0 * math.cos(0.05 * k)
        y = 400.0 + 300.0 * math.sin(0.07 * k)
        try:
            ws.send(f"m:{x:.1f},{y:.1f}")
        except OSError:
            return
        k += 1
        time.sleep(1.0 / 60.0)


def lists_of(m: bytes) -> list[bytes]:
    """The draw lists of a frame message, each as its bytes (header, vertices, indices, commands)."""
    nlists = struct.unpack_from("<I", m, 9)[0]
    p, out = 13, []
    for _ in range(nlists):
        n = list_layout(m, p)[4]
        out.append(m[p : p + n])
        p += n
    return out


def analyse(frames: list[bytes]) -> dict[str, float]:
    """Identical frames and lists, deflate and delta+deflate savings, over the kept frames."""
    if len(frames) < 2:
        return {}
    same = 0
    list_bytes = list_same = 0
    prev_lists: list[bytes] = []
    raw = z1 = z6 = zd = 0
    t1 = t6 = 0.0
    prev = b""
    for m in frames:
        raw += len(m)
        if m == prev:
            same += 1
        lists = lists_of(m)
        for k, chunk in enumerate(lists):  # a list equal to the previous frame's list of the same rank
            list_bytes += len(chunk)
            if k < len(prev_lists) and chunk == prev_lists[k]:
                list_same += len(chunk)
        prev_lists = lists
        t = time.perf_counter()
        z1 += len(zlib.compress(m, 1))
        t1 += time.perf_counter() - t
        t = time.perf_counter()
        z6 += len(zlib.compress(m, 6))
        t6 += time.perf_counter() - t
        if prev and len(prev) == len(m):  # delta: XOR with the previous frame of the same size, then deflate
            d = (int.from_bytes(m, "little") ^ int.from_bytes(prev, "little")).to_bytes(len(m), "little")
            zd += len(zlib.compress(d, 1))
        else:
            zd += len(zlib.compress(m, 1))
        prev = m
    mb = raw / 1.0e6
    return {
        "analysed_frames": len(frames),
        "identical_frames": same / len(frames),
        "identical_list_bytes": list_same / max(list_bytes, 1),
        "deflate1_ratio": raw / z1,
        "deflate6_ratio": raw / z6,
        "delta_deflate1_ratio": raw / zd,
        "deflate1_ms_per_mb": 1000.0 * t1 / mb,
        "deflate6_ms_per_mb": 1000.0 * t6 / mb,
    }


def cpu_seconds(pid: int) -> float:
    """CPU time (user + system) a running process has used so far [s]."""
    fields = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()
    return (int(fields[11]) + int(fields[12])) / os.sysconf("SC_CLK_TCK")


def free_port() -> int:
    """A port nobody listens on now."""
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def connect_stream(
    host: str, port: int, case: Case, st: Stream, stop: threading.Event, warm: threading.Event
) -> list[threading.Thread]:
    """Open the recording client, send the canvas size, start recording (and the pointer)."""
    end = time.monotonic() + 15.0
    while True:
        try:
            ws = remote_client.WebSocket(port) if host == "127.0.0.1" else remote_websocket(host, port)
            break
        except (remote_client.ProtocolError, OSError):
            if time.monotonic() > end:
                raise
            time.sleep(0.2)
    ws.send("s:1280,800")
    threads = [threading.Thread(target=record, args=(ws, st, stop, warm), daemon=True)]
    if case.pointer:
        threads.append(threading.Thread(target=move_pointer, args=(ws, stop), daemon=True))
    for t in threads:
        t.start()
    return threads


def remote_websocket(host: str, port: int) -> remote_client.WebSocket:
    """A WebSocket to another host (remote_client connects to 127.0.0.1 only)."""
    original = remote_client.socket.create_connection
    remote_client.socket.create_connection = lambda addr, timeout=None: original((host, addr[1]), timeout=timeout)
    try:
        return remote_client.WebSocket(port)
    finally:
        remote_client.socket.create_connection = original


class GpuSampler:
    """Mean utilisation of GPU 0 (nvidia-smi, every 0.5 s) while running; on WSL it includes the Windows desktop."""

    def __init__(self) -> None:
        self.samples: list[float] = []
        self.proc: subprocess.Popen | None = None

    def start(self) -> None:
        """Start sampling (nothing if nvidia-smi is missing)."""
        try:
            self.proc = subprocess.Popen(
                ["nvidia-smi", "-i", "0", "--query-gpu=utilization.gpu", "--format=csv,noheader,nounits", "-lms", "500"],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
            )
        except OSError:
            return
        threading.Thread(target=self._read, daemon=True).start()

    def _read(self) -> None:
        assert self.proc is not None and self.proc.stdout is not None
        for line in self.proc.stdout:
            try:
                self.samples.append(float(line))
            except ValueError:
                pass

    def stop(self) -> float | None:
        """Stop; the mean utilisation [%] or None."""
        if self.proc is not None:
            self.proc.terminate()
            self.proc.wait()
        return sum(self.samples) / len(self.samples) if self.samples else None


def parse_bench(out: str) -> dict[str, float]:
    """The benchmark's last line: frames, seconds, app_ms, figure_ms, updates."""
    for line in out.splitlines():
        if line.startswith("bench ") and not line.startswith("bench warm"):
            return {k: float(v) for k, v in (kv.split("=") for kv in line.split()[2:])}
    return {}


def parse_redraw(err: str, skip: int) -> dict[str, float]:
    """Sum FIGURE_DEBUG_REDRAW's per-second lines after the first `skip` (the warm-up): wait, build, render, swap
    [ms] and frames."""
    tot = {"wait": 0.0, "build": 0.0, "render": 0.0, "swap": 0.0, "frames": 0.0}
    lines = [line for line in err.splitlines() if line.startswith("figure redraw:")]
    for line in lines[skip:]:
        for kv in line.split():
            if "=" in kv:
                k, v = kv.split("=", 1)
                if k in tot:
                    tot[k] += float(v.removesuffix("ms"))
    return tot


def run_case(
    program: str, case: Case, seconds: float, env_extra: dict[str, str], sample_gpu: bool, compress: str | None
) -> dict:
    """Run one case; return its numbers."""
    env = dict(os.environ, **env_extra)
    args = [program, *case.args, "--seconds", str(seconds), "--warmup", str(WARMUP_S)]
    port = 0
    if case.remote:
        port = free_port()
        args += ["--remote", str(port)]
        if compress:
            args += ["--compress", compress]
    else:
        env["FIGURE_DEBUG_REDRAW"] = "1"
    proc = subprocess.Popen(args, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    outputs: dict[str, str] = {}
    gpu = GpuSampler() if sample_gpu and not case.remote else None
    warm = threading.Event()
    cpu_warm: list[float] = [0.0]

    def read_stdout() -> None:
        """Collect stdout; at "bench warm", note the CPU time spent so far and start counting."""
        lines = []
        for line in proc.stdout:
            lines.append(line)
            if line.startswith("bench warm"):
                cpu_warm[0] = cpu_seconds(proc.pid)
                warm.set()
                if gpu is not None:
                    gpu.start()
        outputs["out"] = "".join(lines)

    readers = [
        threading.Thread(target=read_stdout, daemon=True),
        threading.Thread(target=lambda: outputs.__setitem__("err", proc.stderr.read()), daemon=True),
    ]
    for t in readers:
        t.start()
    st = Stream()
    stop = threading.Event()
    threads: list[threading.Thread] = []
    if case.remote:
        try:
            threads = connect_stream("127.0.0.1", port, case, st, stop, warm)
        except (remote_client.ProtocolError, OSError):
            pass  # the program died before serving: its exit status and stderr tell why
    # the child's CPU time (user + system) from the kernel's accounting, as it is reaped, minus the warm-up's
    _, status, usage = os.wait4(proc.pid, 0)
    proc.returncode = os.waitstatus_to_exitcode(status)
    for t in readers:
        t.join()
    ru = usage.ru_utime + usage.ru_stime - cpu_warm[0]
    gpu_load = gpu.stop() if gpu is not None else None
    out, err = outputs.get("out", ""), outputs.get("err", "")
    stop.set()
    for t in threads:
        t.join(timeout=5.0)
    res: dict = {"case": case.name, "exit": proc.returncode}
    res.update(parse_bench(out))
    res["cpu_s"] = ru
    if gpu_load is not None:
        res["gpu_util"] = gpu_load
    frames = res.get("frames", 0.0)
    wall = res.get("seconds", 0.0)
    if frames and wall:
        res["fps"] = frames / wall
        res["cpu_load"] = ru / wall
        res["cpu_ms_per_frame"] = 1000.0 * ru / frames
    if not case.remote:
        rd = parse_redraw(err, WARMUP_S)
        if rd["frames"]:
            for k in ("wait", "build", "render", "swap"):
                res[f"{k}_ms_per_frame"] = rd[k] / rd["frames"]
    else:
        res.update(stream_numbers(st, wall))
    if proc.returncode != 0:
        res["stderr"] = err[-2000:]
    return res


def stream_numbers(st: Stream, wall: float) -> dict:
    """Bytes per second and per frame, by kind and part, and the offline analysis."""
    res: dict = {}
    nframes = st.counts.get(1, 0)
    total = sum(st.messages.values())
    res["frames_received"] = nframes
    res["bytes_total"] = total
    res["bytes_textures"] = st.messages.get(2, 0)
    res["bytes_frames"] = st.messages.get(1, 0)
    if wall:
        res["bytes_per_s"] = total / wall
    if nframes:
        res["bytes_per_frame"] = st.messages.get(1, 0) / nframes
        res["raw_bytes_per_frame"] = st.inflated.get(1, 0) / nframes
        res["deflated_share"] = st.deflated / max(sum(st.counts.values()), 1)
        fb = max(st.inflated.get(1, 0), 1)
        res["share_vertices"] = st.vertices / fb
        res["share_indices"] = st.indices / fb
        res["share_commands"] = st.commands / fb
        res["share_headers"] = st.headers / fb
    res.update(analyse(st.frames))
    return res


def measure_connect(target: str, case: Case, seconds: float) -> dict:
    """Record a stream from a program already running elsewhere (HOST:PORT)."""
    host, port = target.rsplit(":", 1)
    st = Stream()
    stop = threading.Event()
    warm = threading.Event()
    warm.set()
    t0 = time.monotonic()
    threads = connect_stream(host, int(port), case, st, stop, warm)
    time.sleep(seconds)
    stop.set()
    for t in threads:
        t.join(timeout=5.0)
    wall = time.monotonic() - t0
    res: dict = {"case": case.name, "seconds": wall}
    if st.last > st.first:
        res["fps"] = (st.counts.get(1, 1) - 1) / (st.last - st.first)
    res.update(stream_numbers(st, wall))
    return res


def table(results: list[dict]) -> str:
    """The results as a Markdown table."""
    cols = [
        ("case", "case", "{}"),
        ("fps", "frames/s", "{:.1f}"),
        ("cpu_load", "CPU (cores)", "{:.3f}"),
        ("cpu_ms_per_frame", "CPU ms/frame", "{:.2f}"),
        ("app_ms", "app ms/frame", "{:.2f}"),
        ("figure_ms", "next_frame ms", "{:.2f}"),
        ("render_ms_per_frame", "render ms", "{:.2f}"),
        ("gpu_util", "GPU %", "{:.0f}"),
        ("bytes_per_s", "bytes/s", "{:,.0f}"),
        ("bytes_per_frame", "bytes/frame", "{:,.0f}"),
        ("identical_frames", "identical", "{:.0%}"),
        ("identical_list_bytes", "same lists", "{:.0%}"),
        ("deflate1_ratio", "deflate-1 x", "{:.1f}"),
        ("delta_deflate1_ratio", "delta+deflate x", "{:.1f}"),
        ("raw_bytes_per_frame", "bytes/frame inflated", "{:,.0f}"),
        ("deflated_share", "deflated", "{:.0%}"),
    ]
    lines = ["| " + " | ".join(h for _, h, _ in cols) + " |", "|" + "---|" * len(cols)]
    for r in results:
        cells = [fmt.format(r[k]) if k in r else "" for k, _, fmt in cols]
        lines.append("| " + " | ".join(cells) + " |")
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    """Run the cases, print the table, optionally write JSON."""
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("--program", default="exe/figure_bench_redraw")
    ap.add_argument("--seconds", type=float, default=10.0)
    ap.add_argument("--only", nargs="*", default=None, help="case names (or prefixes) to run")
    ap.add_argument("--json", type=Path, default=None)
    ap.add_argument("--connect", default=None, help="HOST:PORT of a program already serving (records only)")
    ap.add_argument("--pointer", action="store_true", help="with --connect: move the pointer")
    ap.add_argument("--compress", default=None, choices=["auto", "always", "never"], help="remote compression")
    ap.add_argument("--gpu", action="store_true", help="sample GPU 0 utilisation (nvidia-smi) in window mode")
    ap.add_argument("--env", nargs="*", default=[], help="VAR=value for the program (e.g. GALLIUM_DRIVER=d3d12)")
    a = ap.parse_args(argv)
    env = dict(kv.split("=", 1) for kv in a.env)
    results = []
    if a.connect:
        c = Case(f"remote {a.connect}", [], remote=True, pointer=a.pointer)
        results.append(measure_connect(a.connect, c, a.seconds))
    else:
        cases = default_cases()
        if a.only:
            cases = [c for c in cases if any(c.name.startswith(o) for o in a.only)]
        for c in cases:
            print(f"measuring {c.name} ...", file=sys.stderr, flush=True)
            results.append(run_case(a.program, c, a.seconds, env, a.gpu, a.compress))
    print(table(results))
    if a.json:
        a.json.write_text(json.dumps(results, indent=1))
    return 0 if all(r.get("exit", 0) == 0 for r in results) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
