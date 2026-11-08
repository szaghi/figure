"""Measure the idle CPU cost of a FIGURE program (Linux only).

Launches the program, waits for it to settle, then reads its CPU time (user + system, from ``/proc/<pid>/stat``)
at the start and end of a measuring window, and terminates it. Nobody must touch the window meanwhile: the result is
the cost of lazy redraw with no input.

Usage::

    python3 scripts/measure_idle.py [--warmup S] [--seconds S] [--env VAR=value ...] -- program [args ...]

Example (WSLg, GPU rendering)::

    python3 scripts/measure_idle.py --seconds 60 --env GALLIUM_DRIVER=d3d12 -- exe/examples/figure_hello

Resolution: the kernel counts CPU time in clock ticks (usually 10 ms), i.e. 0.1% of one core over a 10 s window;
use 60 s or more to resolve the sub-percent costs of an idle lazy loop. The report also tells whether the process
renders on the GPU through WSL's D3D12 (``libd3d12`` mapped) or in software (llvmpipe), because the latter makes
every frame cost CPU. Standard library only (Python >= 3.11).
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import time
from pathlib import Path

TICKS_PER_SECOND = os.sysconf("SC_CLK_TCK")


def cpu_seconds(pid: int) -> float:
    """Return the CPU time consumed so far by a process.

    Parameters
    ----------
    pid : int
        Process id.

    Returns
    -------
    float
        User plus system time [s].
    """
    stat = Path(f"/proc/{pid}/stat").read_text()
    # the command name may contain blanks: split after its closing parenthesis
    fields = stat.rsplit(")", 1)[1].split()
    return (int(fields[11]) + int(fields[12])) / TICKS_PER_SECOND


def renderer(pid: int) -> str:
    """Guess the OpenGL renderer of a process from the libraries it maps.

    Parameters
    ----------
    pid : int
        Process id.

    Returns
    -------
    str
        ``"d3d12 (WSL GPU)"``, ``"mesa (llvmpipe or native driver)"`` or ``"unknown"``.
    """
    maps = Path(f"/proc/{pid}/maps").read_text()
    if "libd3d12.so" in maps:
        return "d3d12 (WSL GPU)"
    if "libgallium" in maps:
        return "mesa (llvmpipe or native driver)"
    return "unknown"


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse the command line.

    Parameters
    ----------
    argv : list[str]
        Arguments, without the script name.

    Returns
    -------
    argparse.Namespace
        Options and the command to run.
    """
    parser = argparse.ArgumentParser(
        description="Measure the idle CPU cost of a FIGURE program."
    )
    parser.add_argument(
        "--warmup",
        type=float,
        default=4.0,
        help="seconds to wait before measuring (default 4)",
    )
    parser.add_argument(
        "--seconds",
        type=float,
        default=10.0,
        help="length of the measuring window (default 10)",
    )
    parser.add_argument(
        "--env",
        action="append",
        default=[],
        metavar="VAR=value",
        help="extra environment",
    )
    parser.add_argument(
        "command", nargs=argparse.REMAINDER, help="program and arguments, after --"
    )
    args = parser.parse_args(argv)
    if args.command and args.command[0] == "--":
        args.command = args.command[1:]
    if not args.command:
        parser.error("missing the program to run (after --)")
    return args


def main(argv: list[str]) -> int:
    """Run the measurement and print the report.

    Parameters
    ----------
    argv : list[str]
        Arguments, without the script name.

    Returns
    -------
    int
        Exit status: 0 on success, 1 if the program exited before the end of the measurement.
    """
    args = parse_args(argv)
    env = dict(os.environ)
    for assignment in args.env:
        name, _, value = assignment.partition("=")
        env[name] = value
    proc = subprocess.Popen(
        args.command, env=env, stdout=subprocess.DEVNULL
    )  # stderr inherited
    try:
        time.sleep(args.warmup)
        if proc.poll() is not None:
            print(
                f"measure_idle: the program exited during warm-up (status {proc.returncode})",
                file=sys.stderr,
            )
            return 1
        gl = renderer(proc.pid)
        cpu0, wall0 = cpu_seconds(proc.pid), time.monotonic()
        time.sleep(args.seconds)
        if proc.poll() is not None:
            print(
                f"measure_idle: the program exited while measuring (status {proc.returncode})",
                file=sys.stderr,
            )
            return 1
        cpu1, wall1 = cpu_seconds(proc.pid), time.monotonic()
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=5.0)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
    span = wall1 - wall0
    resolution = 100.0 / (TICKS_PER_SECOND * span)
    print(f"renderer: {gl}")
    print(
        f"idle CPU: {100.0 * (cpu1 - cpu0) / span:.2f}% of one core over {span:.1f} s (resolution {resolution:.2f}%)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
