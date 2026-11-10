---
title: Performance
---

# Performance

An immediate-mode interface rebuilds every frame from the program's state. What does that cost, and how do you keep it
low? This page answers with measurements: every number below was measured with `scripts/measure_redraw.py` running
`src/examples/figure_bench_redraw.F90` (the data is in `docs/data/performance.json`, the charts are drawn from it by
`scripts/perf_charts.py`). They are one machine's numbers (WSL2/WSLg, x86-64 with 16 hardware threads, RTX 4070
through D3D12, gfortran 16.2), so read the ratios, not the absolute values.

## In a window

<!-- chart:cpu -->
<svg class="perf-chart" viewBox="0 0 640 342" width="100%" role="img" aria-label="cpu_ms_per_frame per case" xmlns="http://www.w3.org/2000/svg">
<line class="grid" x1="215.0" y1="8" x2="215.0" y2="296"/>
<text class="axis" x="215.0" y="312" text-anchor="middle">0</text>
<line class="grid" x1="306.2" y1="8" x2="306.2" y2="296"/>
<text class="axis" x="306.2" y="312" text-anchor="middle">10</text>
<line class="grid" x1="397.5" y1="8" x2="397.5" y2="296"/>
<text class="axis" x="397.5" y="312" text-anchor="middle">20</text>
<line class="grid" x1="488.8" y1="8" x2="488.8" y2="296"/>
<text class="axis" x="488.8" y="312" text-anchor="middle">30</text>
<line class="grid" x1="580.0" y1="8" x2="580.0" y2="296"/>
<text class="axis" x="580.0" y="312" text-anchor="middle">40</text>
<text class="axis" x="397.5" y="336" text-anchor="middle">ms of CPU per frame</text>
<text class="label" x="205" y="26" text-anchor="end">idle</text>
<path class="s-now" d="M215.0,18.0 H227.5 Q231.5,18.0 231.5,22.0 V26.0 Q231.5,30.0 227.5,30.0 H215.0 Z"><title>idle: 1.81 ms of CPU per frame</title></path>
<text class="value" x="237.5" y="28">1.81</text>
<text class="label" x="205" y="54" text-anchor="end">pointer moving</text>
<path class="s-now" d="M215.0,46.0 H219.2 Q223.2,46.0 223.2,50.0 V54.0 Q223.2,58.0 219.2,58.0 H215.0 Z"><title>pointer moving: 0.90 ms of CPU per frame</title></path>
<text class="value" x="229.2" y="56">0.90</text>
<text class="label" x="205" y="82" text-anchor="end">live data, 10 updates/s</text>
<path class="s-now" d="M215.0,74.0 H230.1 Q234.1,74.0 234.1,78.0 V82.0 Q234.1,86.0 230.1,86.0 H215.0 Z"><title>live data, 10 updates/s: 2.09 ms of CPU per frame</title></path>
<text class="value" x="240.1" y="84">2.09</text>
<text class="label" x="205" y="110" text-anchor="end">live data, 60 updates/s</text>
<path class="s-now" d="M215.0,102.0 H227.2 Q231.2,102.0 231.2,106.0 V110.0 Q231.2,114.0 227.2,114.0 H215.0 Z"><title>live data, 60 updates/s: 1.77 ms of CPU per frame</title></path>
<text class="value" x="237.2" y="112">1.77</text>
<text class="label" x="205" y="138" text-anchor="end">100 000-point line, 10/s</text>
<path class="s-now" d="M215.0,130.0 H255.3 Q259.3,130.0 259.3,134.0 V138.0 Q259.3,142.0 255.3,142.0 H215.0 Z"><title>100 000-point line, 10/s: 4.85 ms of CPU per frame</title></path>
<text class="value" x="265.3" y="140">4.85</text>
<text class="label" x="205" y="166" text-anchor="end">1 000 000-point line, 10/s</text>
<path class="s-now" d="M215.0,158.0 H510.6 Q514.6,158.0 514.6,162.0 V166.0 Q514.6,170.0 510.6,170.0 H215.0 Z"><title>1 000 000-point line, 10/s: 32.8 ms of CPU per frame</title></path>
<text class="value" x="520.6" y="168">32.8</text>
<text class="label" x="205" y="194" text-anchor="end">256² heatmap, 10/s</text>
<path class="s-now" d="M215.0,186.0 H246.1 Q250.1,186.0 250.1,190.0 V194.0 Q250.1,198.0 246.1,198.0 H215.0 Z"><title>256² heatmap, 10/s: 3.85 ms of CPU per frame</title></path>
<text class="value" x="256.1" y="196">3.85</text>
<text class="label" x="205" y="222" text-anchor="end">512² heatmap, 10/s</text>
<path class="s-now" d="M215.0,214.0 H294.3 Q298.3,214.0 298.3,218.0 V222.0 Q298.3,226.0 294.3,226.0 H215.0 Z"><title>512² heatmap, 10/s: 9.13 ms of CPU per frame</title></path>
<text class="value" x="304.3" y="224">9.13</text>
<text class="label" x="205" y="250" text-anchor="end">512² texture, 10/s</text>
<path class="s-now" d="M215.0,242.0 H233.8 Q237.8,242.0 237.8,246.0 V250.0 Q237.8,254.0 233.8,254.0 H215.0 Z"><title>512² texture, 10/s: 2.50 ms of CPU per frame</title></path>
<text class="value" x="243.8" y="252">2.50</text>
<text class="label" x="205" y="278" text-anchor="end">3840×2160 texture, 10/s</text>
<path class="s-now" d="M215.0,270.0 H376.8 Q380.8,270.0 380.8,274.0 V278.0 Q380.8,282.0 376.8,282.0 H215.0 Z"><title>3840×2160 texture, 10/s: 18.2 ms of CPU per frame</title></path>
<text class="value" x="386.8" y="280">18.2</text>
</svg>
<!-- /chart:cpu -->

| Case (window mode) | frames/s | CPU per frame | of which the program's own code |
|---|---|---|---|
| idle | 2–8 | 1.8 ms | 0.05 ms |
| pointer moving | 486 (no vsync on WSLg) | 0.9 ms | 0.04 ms |
| live data, 10 updates/s | 9.4 | 2.1 ms | 0.08 ms |
| live data, 60 updates/s | 44 | 1.8 ms | 0.08 ms |
| 100 000-point line, 10 updates/s | 9.0 | 4.9 ms | 2.2 ms |
| 1 000 000-point line, 10 updates/s | 5.2 | 33 ms | 24 ms |
| 256² heatmap, 10 updates/s | 9.0 | 3.9 ms | 1.5 ms |
| 512² heatmap, 10 updates/s | 7.8 | 9.1 ms | 5.7 ms |
| 512² texture, 10 updates/s | 9.3 | 2.5 ms | 0.6 ms |
| 3840 × 2160 texture, 10 updates/s | 6.9 | 18 ms | 17 ms |

"The program's own code" is the time between two `next_frame` calls: the widget and plot calls, and the data update.
Two things follow.

**Redrawing an interface is cheap: about 1–2 ms of CPU.** What costs is data: a plot's points (ImPlot turns each into
triangles every frame) and the pixels you write. So a frame drawn for nothing is not the problem it is in a retained
toolkit, but a frame drawn when nothing changed is still wasted, and [lazy redraw](frame-loop#lazy-redraw) avoids it:

- leave lazy redraw on (the default): an idle window draws twice a second, about 0.4 % of one core;
- data changed by the program inside the loop: `app%request_frames(1)` in each frame where it changed (chapter 4 of
  the [tutorial](/manual/tutorial/04-live));
- data that changes on its own pace: `app%set_lazy(.true., max_wait=s)`, `s` the refresh period you want;
- `app%set_lazy(.false.)` only for real animation: it draws at the display rate, about 37 % of a core idle.

## Computation and the frame loop

FIGURE runs in the program's thread: while the program computes, nothing is drawn and no input is read. Keep each
frame short (16 ms for 60 frames/s, 100 ms still feels responsive) by advancing the computation **a slice per frame**,
as [`tut04_live`](/manual/tutorial/04-live) does: a few iterations, then `next_frame`. Parallelism goes inside the
slice (OpenMP, `do concurrent`, MPI, the GPU), as in the [Mandelbrot explorer](images#an-explorer-the-mandelbrot-set),
which computes its view in parallel between two frames.

Give the user the slice size (iterations per frame, as `tut04_live`'s slider does) or measure it: the frame's cost is
the slice plus the 1–2 ms of the interface. Plots read your arrays each frame without copying them
([Data in place](plots#data-in-place)), so publishing the state every frame costs nothing extra;
what costs is how many points the plots draw.

## Large data

**Lines.** ImPlot's cost grows with the points drawn, about 0.2 ms per 10 000 points here: 100 000 points add 2 ms to
a frame, a million 24 ms. A plot is at most a few thousand pixels wide, so draw at most a few points per pixel: keep
one sample in N, or, to keep spikes visible, the minimum and maximum of each group of N consecutive samples (two
points per group). A million samples shown 1000 pixels wide need 2000 points, not a million.

**Strided data.** Decimating in place costs no copy: `ip_line(label, y(::10), xscale=10 * dx)` reads every tenth
sample with ImPlot's stride. Components of an array of derived types, matrix rows and integer abscissae are read in
place too, on gfortran, nvfortran and ifx alike (from v0.5.0: nvfortran copied every strided section before), with two
exceptions: an item copies `x` when its stride differs from the ordinates' (or converts it when it is an integer), and
gfortran and nvfortran copy a component of an array of derived types before the call. At a million points a stride
costs about 7 % of the item, a copy by FIGURE 20 %, the compiler's temporaries of `runs%t` and `runs%cl` 40 to 60 %
(double at ten million): keep a long series in its own contiguous array. With nvfortran 26.9 at ten million points,
a matrix row went from 139 to 77 ms per item in v0.5.0, contiguous data take 70 ms
([Data in place](plots#data-in-place)).

**Fields: a texture beats a heatmap past a few hundred cells a side.** A heatmap draws each cell as a rectangle of
vertices, which ImPlot rebuilds every frame; a texture is one image the GPU scales. At 512 × 512 the heatmap costs
9.1 ms of CPU per frame against 2.5 ms for the texture, and in remote mode 13.5 MB per frame against 1 MB per update.
Keep heatmaps for small fields, where cell labels and exact cell boundaries matter; above about 256 × 256 draw the
field with [`ip_field_image`](plots#fields): one call colours it through the colormap into a texture, on a linear,
log or symlog scale, and colours it again only when it changes (`changed=.true.`, a new range, colormap or scale).

**Colouring a field.** `ip_field_image` colours a 1024 × 1024 field in about 3 ms (`figure_test_fields`, headless:
the colouring without the GPU upload; linear and log, `real32` and `real64` alike). The upload is that of a
[texture](images#speed-a-new-4k-image-every-frame), about 0.3 ms for a million pixels here (2.2 ms for 3840 × 2160). The colours come from
the colormap's own table, as a heatmap's do. On a log or symlog scale the transform (`log10`, `asinh`) is the cost:
FIGURE colours such fields through a second table, indexed by the value's single-precision bits (the trick of
Julia's ImPlotExtra.jl) and restricted to the range, so the transform runs 65 536 times instead of once per value.
Measured on 1024 × 1024 values (gcc -O2, x86-64), against the same colours computed value by value:

| Scale, range | Per value | Bit table | Largest difference |
|---|---|---|---|
| linear [0, 1] | 1.6 ms | 1.1 ms | 1/255 |
| linear [300, 301] | 1.6 ms | 1.0 ms | 1/255 (ImPlotExtra's unrestricted table: 255/255) |
| log [1e-3, 1e3] | 6.8 ms | 1.4 ms | 1/255 |
| log [1, 2] | 6.8 ms | 1.4 ms | 1/255 (unrestricted: 5/255) |
| symlog [-1e3, 1e3] | 10.4 ms | 1.1 ms | 1/255 |
| symlog [10, 11] | 7.6 ms | 1.2 ms | 1/255 (unrestricted: 26/255) |

The largest difference is per channel, one step of the colormap's own 8-bit table. ImPlotExtra indexes its table by
the top 16 bits of any float, which spreads its 65 536 bins over every float from -inf to +inf: a range far from 0
(300 to 301 K) falls into a few bins. FIGURE's table covers only the range's own floats, so a narrow range gets as
many bins as it has floats. Linear fields stay per value: the table gains 1.2 to 1.6 times there, not worth an
approximation. Fields under 131 072 values are coloured per value on every scale (the table costs 65 536
transforms to build).

## Remote mode

<!-- chart:remote -->
<svg class="perf-chart" viewBox="0 0 640 254" width="100%" role="img" aria-label="bytes per second per case, logarithmic" xmlns="http://www.w3.org/2000/svg">
<circle class="s-first" cx="221" cy="14" r="5"/>
<text class="legend" x="231" y="18">first version</text>
<circle class="s-now" cx="353.8" cy="14" r="5"/>
<text class="legend" x="363.8" y="18">now</text>
<circle class="s-deflated" cx="410.6" cy="14" r="5"/>
<text class="legend" x="420.6" y="18">now, deflated</text>
<line class="grid" x1="215.0" y1="30" x2="215.0" y2="208"/>
<text class="axis" x="215.0" y="224" text-anchor="middle">1 B/s</text>
<line class="grid" x1="346.7" y1="30" x2="346.7" y2="208"/>
<text class="axis" x="346.7" y="224" text-anchor="middle">1 KB/s</text>
<line class="grid" x1="478.3" y1="30" x2="478.3" y2="208"/>
<text class="axis" x="478.3" y="224" text-anchor="middle">1 MB/s</text>
<line class="grid" x1="610.0" y1="30" x2="610.0" y2="208"/>
<text class="axis" x="610.0" y="224" text-anchor="middle">1 GB/s</text>
<text class="label" x="205" y="50" text-anchor="end">idle</text>
<line class="link" x1="215.0" y1="46" x2="449.1" y2="46"/>
<circle class="s-first ring" cx="449.1" cy="46" r="5"><title>idle, first version: 216 KB/s</title></circle>
<circle class="s-now ring" cx="215.0" cy="46" r="5"><title>idle, now: 1 B/s</title></circle>
<text class="label" x="205" y="78" text-anchor="end">pointer moving</text>
<line class="link" x1="482.2" y1="74" x2="540.3" y2="74"/>
<circle class="s-first ring" cx="540.3" cy="74" r="5"><title>pointer moving, first version: 25.8 MB/s</title></circle>
<circle class="s-now ring" cx="499.8" cy="74" r="5"><title>pointer moving, now: 3.08 MB/s</title></circle>
<circle class="s-deflated ring" cx="482.2" cy="74" r="5"><title>pointer moving, now, deflated: 1.23 MB/s</title></circle>
<text class="label" x="205" y="106" text-anchor="end">live data, 10 updates/s</text>
<line class="link" x1="454.2" y1="102" x2="479.7" y2="102"/>
<circle class="s-first ring" cx="479.7" cy="102" r="5"><title>live data, 10 updates/s, first version: 1.07 MB/s</title></circle>
<circle class="s-now ring" cx="471.8" cy="102" r="5"><title>live data, 10 updates/s, now: 709 KB/s</title></circle>
<circle class="s-deflated ring" cx="454.2" cy="102" r="5"><title>live data, 10 updates/s, now, deflated: 282 KB/s</title></circle>
<text class="label" x="205" y="134" text-anchor="end">live data, 60 updates/s</text>
<line class="link" x1="488.3" y1="130" x2="514.3" y2="130"/>
<circle class="s-first ring" cx="514.3" cy="130" r="5"><title>live data, 60 updates/s, first version: 6.62 MB/s</title></circle>
<circle class="s-now ring" cx="505.8" cy="130" r="5"><title>live data, 60 updates/s, now: 4.24 MB/s</title></circle>
<circle class="s-deflated ring" cx="488.3" cy="130" r="5"><title>live data, 60 updates/s, now, deflated: 1.69 MB/s</title></circle>
<text class="label" x="205" y="162" text-anchor="end">100 000-point line, 10/s</text>
<line class="link" x1="527.2" y1="158" x2="598.4" y2="158"/>
<circle class="s-first ring" cx="598.4" cy="158" r="5"><title>100 000-point line, 10/s, first version: 545 MB/s</title></circle>
<circle class="s-now ring" cx="554.6" cy="158" r="5"><title>100 000-point line, 10/s, now: 54.8 MB/s</title></circle>
<circle class="s-deflated ring" cx="527.2" cy="158" r="5"><title>100 000-point line, 10/s, now, deflated: 13 MB/s</title></circle>
<text class="label" x="205" y="190" text-anchor="end">256² heatmap, 10/s</text>
<line class="link" x1="522.0" y1="186" x2="582.9" y2="186"/>
<circle class="s-first ring" cx="582.9" cy="186" r="5"><title>256² heatmap, 10/s, first version: 242 MB/s</title></circle>
<circle class="s-now ring" cx="547.5" cy="186" r="5"><title>256² heatmap, 10/s, now: 37.7 MB/s</title></circle>
<circle class="s-deflated ring" cx="522.0" cy="186" r="5"><title>256² heatmap, 10/s, now, deflated: 9.87 MB/s</title></circle>
</svg>
<!-- /chart:remote -->

| Case (remote mode, same machine) | first version | now | now, deflated |
|---|---|---|---|
| idle | 216 KB/s | 1 byte/s | |
| pointer moving | 25.8 MB/s | 3.1 MB/s | 1.2 MB/s |
| live data, 10 updates/s | 1.07 MB/s | 0.71 MB/s | 0.28 MB/s |
| live data, 60 updates/s | 6.6 MB/s | 4.2 MB/s | 1.7 MB/s |
| 100 000-point line, 10 updates/s | 545 MB/s | 55 MB/s | 13 MB/s |
| 256² heatmap, 10 updates/s | 242 MB/s | 38 MB/s | 9.9 MB/s |

In [remote mode](remote) the CPU stays as low as in a window (the browser draws); the network carries the cost. Every
frame sent is the whole interface as triangles, so the rules above matter more there, and FIGURE adds its own (see
[Bandwidth](remote#bandwidth)):

- an unchanged frame is not sent: an idle interface costs nothing, live data one frame per update;
- frames are capped (`init_remote(max_fps=)`, 60 by default) and one at most is queued: a slow link gets the newest
  frame, never a backlog;
- frames travel with 12-byte vertices, and are deflated when the link is the bottleneck (`compress='auto'`), for
  about 7 ms of CPU per MB.

On a slow link (an SSH tunnel to a cluster node carried about 9 MB/s in these measurements), what you draw decides
the frame rate: live data at 60 updates per second still arrives at 60 frames per second (4.2 MB/s), a 100 000-point
line at 5 frames per second deflated. Decimate lines and use textures for fields, as above, and refresh live data at
the rate you need, not faster (`max_wait`, or `max_fps` for the whole program).

## Measure your own

- `FIGURE_DEBUG_REDRAW=1` prints, once per second, the frames drawn and where the time went (waiting, building,
  rendering): [redraw diagnostics](frame-loop#redraw-diagnostics).
- `scripts/measure_idle.py` measures the CPU of an idle program ([measuring idle cost](frame-loop#measuring-idle-cost)).
- `scripts/measure_redraw.py` runs `figure_bench_redraw` through every case of this page, in a window and in remote
  mode, and prints the tables (`--json` writes them for `scripts/perf_charts.py`). In remote mode it records the
  stream like a browser would and analyses it: identical frames, the share of vertices, deflate's saving. With
  `--connect HOST:PORT --token TOKEN` it records a program served elsewhere, such as one on a cluster node reached
  through an SSH tunnel.

```bash
python3 scripts/measure_redraw.py --env GALLIUM_DRIVER=d3d12 --json results.json
python3 scripts/measure_redraw.py --only "live-10 remote" --compress always
```
