---
title: "ADR 0001: the Fortran stack"
---

# ADR 0001: the Fortran stack

- **Status:** accepted, 2026-11-20 (decisions K1–K9 taken by the owner that day).
- **Plan:** [szaghi/figure#15](https://github.com/szaghi/figure/issues/15), its steps, gates and logs. This record keeps
  what the plan decided; the issue keeps how each step went.

## Context

FIGURE is about 35.6k lines of Fortran over about 110k lines of C++: Dear ImGui (core and docking), ImPlot, ImPlot3D,
ImGuizmo, ImGuiColorTextEdit, imgui_rich_md, the SDL3 and OpenGL 3 backends, and 16.5k lines of FIGURE's own glue
(`native/`). Seven patches across five vendored libraries wait on their upstreams (#8, #9, #11). A Fortran programmer
can read, debug and patch the Fortran part only.

## Goal

FIGURE built from Fortran, the SDL3 C API, the OpenGL 3 C API and a few single-file C libraries (K1), with no C++
compiler, no CMake for FIGURE itself and no C++ runtime; with the same public API, the same pictures (within the
oracle's tolerance) and at least the same speed, faster where the redesign targets it. Two reasons, the owner's:

1. **Fortran for Fortran programmers:** an ISO-standard language with decades of stability, a mature toolchain, and a
   library its users can read, debug and patch.
2. **No upstream to wait for:** features and optimizations when FIGURE needs them, in code FIGURE owns and can
   redesign, not only patch.

The plan is a **redesign, not a translation**: each layer is rewritten with Fortran's strengths (array descriptors,
kinds, no aliasing, `do concurrent` and OpenACC on the solvers' own data). Upstream behaviour is the reference for
what the GUI does and looks like, not for how it is built. Order: the data path first (where the gains are), the
layers above Dear ImGui second, the core last. Every block must pay for itself: the plan stops at any gate that fails.

## Decisions

General:

- The public API (`ig_*`, `ip_*`, `ip3_*`, the objects) is the outer seam and does not change during the plan, except
  where a step records a reason.
- Parity first where a layer only has to behave the same (interaction, layout); redesign from the start where speed is
  the point (the data path).
- New public features go to the Fortran path only; the current path gets bug fixes only; the docs list every feature
  available on one path only. The data path serves both paths by design.
- No allocation per item per frame in the core and the plot frame.

The design decisions:

| | Decision |
|---|---|
| K1, C libraries | stb_image, stb_image_write, stb_truetype, md4c and miniz stay C. A C library is admitted only if it is small, C99, needs no C++ runtime, is stable and permissively licensed; no new parser of outside data (images, Markdown) is written in Fortran. |
| K2, docking | A tiling tree first: splits, tabs, a tab or window dragged into a split or another node, resizable splitters, the dock builder calls FIGURE makes, the saved layout; a window dragged out becomes an ordinary floating window, with no floating multi-tab dock nodes. Full parity with Dear ImGui only if users ask. |
| K3, renderer | OpenGL 3 and the CPU renderer, behind one renderer interface. SDL_GPU (Metal, Vulkan, Direct3D 12) on demand: when Apple removes OpenGL from macOS or a measurement shows OpenGL limiting FIGURE. |
| K4, format strings | foresight's printf-subset formatter (integer arithmetic, rounding half to even, the same digits on every compiler). Fortran's edit descriptors are processor-dependent (the leading zero of `F0.d`, signed zero, the exponent's layout): the tick labels, and so the pictures, would differ between gfortran, nvfortran and ifx. |
| K5, SDL3 | Built from source and linked statically by default; an opt-in links the system's SDL3 found by pkg-config, its minimum version checked. One CI job covers the opt-in. |
| K6, fonts | stb_truetype (K1); no Fortran font rasterizer. |
| K7, text in the public API | `character(len=*)` only; a program holding a StringiFor `type(string)` passes `s%chars()`. StringiFor stays internal. |
| K8, saved layout | A plain INI of FIGURE's own, read and written by FiNeR, matching K2's tree. Layouts saved by earlier versions are reset once, at the switch, and the release notes say so. |
| K9, foresight's licence | foresight adds MIT to its GPL-3, as the other libraries have it; FIGURE then depends on it directly. |

A decision found during a step is added to the plan as K10, K11, ..., recorded in the step's log before the step
starts.

## The two paths

The current path (Dear ImGui, ImPlot and the other C++ libraries) keeps working, unchanged for users, until the
switch; the Fortran path grows beside it on `main`. There is no long-lived branch.

- Each seam (`figure_core`, the renderer, each layer above Dear ImGui) has two implementations in sibling directories
  under the same module names, e.g. `src/lib/core_imgui/figure_core.F90` and `src/lib/core_fortran/figure_core.F90`;
  a `fobos` mode picks one through its `src` list, with no preprocessor macro.
- The default modes (`tests-gnu`, `examples-gnu`, ..., the fpm package, the installer) build the current path,
  unchanged until the switch.
- The `-fortran` modes (`tests-gnu-fortran`, `tests-nvf-fortran`, `tests-ifx-fortran`, `examples-*-fortran`) build the
  newest path: the layers already ported, the others from the current path. Until the first layer lands each one takes
  its default mode as template, so it builds the same thing.
- CI runs both. The Fortran path is a FoBiS build only; the fpm package ships the current path until the switch.
- Nothing C++ is deleted before the last step: a step that ports a layer leaves the C++ library in place for the
  current path.

## The oracle

FIGURE is a GUI library: what must hold is that it looks almost the same, behaves the same and is at least as fast.
The existing test machinery is the oracle; there is no draw-data diff.

- **Pictures:** `test_compare_image` and `docs_media.py --check`, captured by the deterministic CPU renderer: same
  size, at most `max_failed` pixels (default 0) with a channel differing by more than `threshold` (default 2 on
  0–255), masks for what changes on its own. The defaults hold for every ported layer; a loosening is per test or per
  recording, with its reason in a comment. A redesign that changes pictures regenerates the affected goldens in a
  commit of its own, each diff looked at and listed in the step's log.
- **Behaviour:** `figure_testing`'s scripted input and item table, checks of the program's variables, and the `.rec`
  input scripts: a picture cannot see that a click returned `.true.`.
- **Speed:** the benchmark scenes (`scripts/bench_scenes.py`), each reporting the median and the 99th percentile of the
  frame time and of the UI time over 300 frames (30 for a scene slower than 0.25 s per frame), against baselines
  recorded per compiler and machine. "At least the same speed" is a statement about the medians: a scene fails when
  its median frame time or median UI time is worse than the baseline's by more than the baseline's spread, taken at
  least 5% of the baseline's value and 0.05 ms. The 99th percentiles are reported, not gated: worse by more than the
  spread, taken at least 20%, is a warning (window-mode percentiles carry the compositor's jitter: they failed the
  5-run spread on 9 of 280 statistics in the first reruns). On WSL the OpenGL renderer string is checked first.
- **Coverage** is the real risk: what no test exercises can regress silently on a new layer. It is measured, and its
  gaps closed, before any layer is replaced (`scripts/oracle_coverage.py --check`).

Every step's gate runs on both paths: `run_tests.sh` with gfortran, nvfortran and ifx (the default and `-fortran`
modes), the pictures checked, `check_sync.py`, `check_docs.py`, the benchmark scenes, and CI green on the pushed
commit.

## Design rules for the Fortran code

From FIGURE's history with three compilers (#4):

- **Integer index handles, never stored pointers** to objects in growable arrays (windows, dock nodes, plots, items):
  an allocatable array moves when it grows.
- **Structure of arrays** where loops are hot (vertices, indices, plot data); the vertex type `bind(C)`, handed to
  OpenGL as is.
- **No parameterized derived types; polymorphism only at the API's edges** (callbacks, the renderer interface), never in
  a per-vertex or per-point loop; no finalizer that correctness depends on.
- **Unsigned arithmetic made explicit:** the ID hash (CRC32 with a seed) and packed colours with `ieor`, `ishft`,
  `iand` on 64-bit integers, bit-exact against Dear ImGui's (IDs are stored in layout files).
- **Kinds as the public API has them** (`real32`, `real64`, the integer kinds); generic code over kinds by the
  preprocessor, not `class(*)`.
- **One module per file**, the house conventions; every procedure buildable by gfortran 16.2, nvfortran 26.9 and ifx
  with the flags of `fobos`.
- **No allocation per item per frame** in the core and the plot frame: labels, IDs and `##` suffixes are character
  slices hashed in place, not `type(string)` values.

Found in P3 with nvfortran 26.9, to respect in the layers that hold arrays of `type(string)`: a section of an
assumed-shape dummy array of a derived type with a deferred-length component, assigned to an allocatable
(`inner = items(2:3)`), crashes; copy element by element. Defined output (`DT`) to an internal file is wrong; write
to an external unit or use `%chars()`.

## The sibling libraries

The owner's Fortran libraries are reused where they fit, as ordinary dependencies: their upstream is FIGURE's own
author, so they keep goal 2, and they replace C leaves and hand-written code with tested Fortran.

**Source-passed.** FIGURE compiles each library's sources itself, with its own flags: `fobis fetch` brings the sources
(`fobos` `[dependencies]`, into `src/third_party/`), FIGURE's modes compile them, and `scripts/fpm_package.py` copies
them into the fpm package. The libraries' own `fobos` and `fpm.toml` are never read by FoBiS; the sources track each
library's default branch, never a pinned tag or commit.

**The dependency rule.** Every library a dependency of FIGURE uses is a direct dependency of FIGURE, declared once in
`fobos` and `fpm.toml`, never reached through another library. `scripts/check_sync.py` checks that both name the same
set, unpinned, and that the set is closed under the libraries' `use` statements. The graph (2026-11-20, from the `use`
statements):

```
PENF       → (none)
FACE       → (none)
FUNDAL     → (none)
BeFoR64    → PENF
VecFor     → PENF
MORTIF     → PENF
StringiFor → BeFoR64, FACE, PENF
FiNeR      → PENF, StringiFor
foresight  → BeFoR64, PENF
```

| Library | What it brings | Where it stops |
|---|---|---|
| [PENF](https://github.com/szaghi/PENF) | portable kinds, number to text, endianness; built without `PENF_R16P` (nvfortran has no `real(16)`) | the public API keeps the `int32`, `real32`, `real64` names |
| [FACE](https://github.com/szaghi/FACE) | ANSI colours of terminal text: StringiFor uses it | — |
| [BeFoR64](https://github.com/szaghi/BeFoR64) | base64 of any intrinsic type: the remote mode's WebSocket handshake, images sent as data | — |
| [StringiFor](https://github.com/szaghi/StringiFor) | `type(string)`, UTF-8 throughout: Markdown, the code editor, text input, the remote mode's headers and paths | not in the per-frame label and ID path; not in the public API (K7) |
| [FiNeR](https://github.com/szaghi/FiNeR) | INI files: the saved layout (K8) | — |
| [FUNDAL](https://github.com/szaghi/FUNDAL) | one device-memory API over OpenACC, OpenMP offload and the CPU: the reduction on the device | a device array the program passes stays the program's; FIGURE only reads it |
| [foresight](https://github.com/szaghi/foresight) | `foresight_format` (K4) and `foresight_ticks`: the tick labels, equal on the three compilers | symlog and time locators are FIGURE's |
| [VecFor](https://github.com/szaghi/VecFor) | 3-D vector algebra: the camera, gizmos, view cube, picking rays | not in per-vertex loops; no matrices or quaternions |
| [MORTIF](https://github.com/szaghi/MORTIF) | Morton codes: a candidate spatial order for picking on large meshes | only if picking measures slow |

Not used: FITTER, HASTY, FULL (unchanged since 2020; HASTY and FULL hold `class(*)` values, against the rules above),
FoXy, FLAP, forbear, FURY (no step needs them).

**State after P3 (2026-11-20).** PENF, FACE, BeFoR64, StringiFor and FUNDAL are fetched and compiled by every mode
with gfortran 16.2, nvfortran 26.9 and ifx 2026.2 (FUNDAL in its CPU mode, without its MPI handler), and shipped in the
fpm package; FIGURE's library uses FUNDAL from #15 P6 (`ip_line_device`, `figure_decimate_device`), the others
only in the tests. Arrays of `type(string)` do not hit #4's bug A
(a section of a deferred-length character array taken at the array's first elements, gfortran) on any of the three
compilers. foresight joined on 2026-11-20, once it compiled with nvfortran and ifx under FIGURE's flags (v0.6.2,
szaghi/foresight#2); FiNeR, VecFor and MORTIF join with the steps that need them.

## Consequences

- FIGURE's build gains a fetch step (`fobis fetch`) and a dependency on git for it; the sources archive carries the
  fetched libraries for machines without network.
- Each library is compiled under FIGURE's flags on three compilers: a failure there is fixed in the library, never
  worked around in FIGURE.
- Until the switch, every feature is either on both paths or listed as on one; CI time grows with the second path.
- The plan can stop at any gate (speed, pictures, behaviour): what is ported until then stays usable, and the current
  path stays the default.
