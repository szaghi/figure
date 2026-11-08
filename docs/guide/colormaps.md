---
title: Colormaps
---

# Colormaps

A **colormap** turns a value into a colour: a [heatmap](images#heatmaps) colours each cell of a field with it, and
its colour bar (`ip_colormap_scale`) shows the scale. FIGURE bundles the maps that scientific plotting has settled on
(matplotlib's, cmocean's, ParaView's Cool to Warm, Fabio Crameri's), knows ImPlot's own, and loads the user's from a
CSV table or a ParaView preset. All of them are chosen **by name**, reversed or cut into discrete bands.
[Contour lines](plots#contour-lines) take their colours from a colormap too, each level the colour of its value.

<Media name="colormaps" alt="Four windows of vertical colour bars, each labelled with its colormap's name. Sequential: cividis, inferno, magma, batlow, thermal, haline, deep, turbo. Diverging: cool-warm, balance, curl, vik, roma. Cyclic: romaO, whose two ends have the same colour. Below, ImPlot's own sixteen: the qualitative Deep, Dark, Pastel and Paired in separate blocks of colour, then Viridis, Plasma, Hot, Cool, Pink, Jet, Twilight, RdBu, BrBG, PiYG, Spectral and Greys." caption="docs/examples/src/gallery.F90 (run with colormaps): every colormap FIGURE knows, from ip_colormap_names" />

## Procedures

| Procedure | Notes |
|---|---|
| `ip_colormap(name [, levels] [, stat])` → `integer(int32)` | the ImPlot id of the map `name`, for the `colormap` argument of `ip_heatmap` and `ip_colormap_scale`; `<name>_r` reversed, `levels` discrete bands; -1 on a failure |
| `ip_load_colormap(name, file [, stat])` | read a map from a CSV table or a ParaView JSON preset and register it as `name` |
| `ip_colormap_names(names)` | the names `ip_colormap` knows, `character(len=:), allocatable :: names(:)` |

<<< @/examples/snippets/cb_colormap-diverging.F90{fortran}

**Names.** Names are case-sensitive: the bundled maps are in lower case (`'cividis'`, `'cool-warm'`, and Crameri's
`'romaO'`), ImPlot's own keep ImPlot's names (`'Viridis'`, `'Jet'`; the constants `ImPlotColormap_*` are their ids),
a loaded map keeps the name it was given. So `'deep'` is cmocean's sequential map and `'Deep'` ImPlot's qualitative
one. `ip_colormap_names` lists the bundled maps (alphabetical), then ImPlot's sixteen (in ImPlot's order), then the
loaded ones (in load order); reversed and discrete maps are not listed.

<<< @/examples/snippets/cb_colormap-names.F90{fortran}

**Registration.** A map is registered with ImPlot (`AddColormap`) at its first use: `ip_colormap` called again with
the same name and levels returns the same id. ImPlot keeps its colormaps for the life of its context and cannot
replace one, so an id holds until `app%destroy`; after a new `init*` the maps are registered again at their next use,
possibly under other ids. Ask `ip_colormap` every frame (the lookup is cheap) rather than keeping an id across an
`app%destroy`.

**The default.** `ip_heatmap` and `ip_colormap_scale` without `colormap` use ImPlot's Viridis, perceptually uniform:
not ImPlot's current colormap, which holds the style's line colours. An id that is not registered (-1, a stale one)
is refused with `FIG_ERR_ARGUMENT`.

::: warning Changed in v0.3.0
Up to v0.2.0, heatmaps and the colour scale without `colormap` took ImPlot's current colormap: with FIGURE's
[styles](styles), the style's line colours, a few distinct hues that do not order values. From v0.3.0 they default
to Viridis, so a heatmap drawn by v0.2.0 code changes colours. Code that wants a given map passes it:
`colormap=ip_colormap('Viridis')`, or any other name.
:::

## The bundled maps

Each is a table of 256 RGB samples, embedded in the library at build time.

| Kind | Name | From |
|---|---|---|
| sequential | `cividis` | matplotlib; designed for colour-vision deficiency (Nuñez, Anderton and Renslow) |
| sequential | `inferno`, `magma` | matplotlib (Smith and van der Walt) |
| sequential | `batlow` | Crameri's Scientific colour maps |
| sequential | `thermal`, `haline`, `deep` | cmocean (Thyng): temperature, salinity, depth |
| sequential | `turbo` | Google (Mikhailov), through matplotlib: a rainbow, smoother than Jet but not uniform |
| diverging | `cool-warm` | Moreland's table of ParaView's "Cool to Warm" |
| diverging | `balance`, `curl` | cmocean |
| diverging | `vik`, `roma` | Crameri's Scientific colour maps |
| cyclic | `romaO` | Crameri's Scientific colour maps: the two ends meet |

ImPlot's own are Viridis, Plasma, Hot, Cool, Pink, Jet, Twilight (cyclic), Greys; the diverging RdBu, BrBG, PiYG and
Spectral; and the qualitative Deep, Dark, Pastel and Paired, which are lists of distinct colours for categories, not
scales.

## How to choose

- **A quantity from low to high** (temperature, density, a residual's magnitude): a sequential map. `cividis`,
  `batlow`, `inferno`, `magma` and Viridis change lightness evenly from one end to the other, so equal steps of value
  look like equal steps of colour, and they keep their order in greyscale and for the common colour-vision
  deficiencies.
- **A quantity with a meaningful zero or reference** (vorticity, a velocity component, a difference from a baseline):
  a diverging map, with the reference at its centre: give `scale_min = -scale_max`. `cool-warm`, `balance`, `vik`.
- **An angle or a phase** (wind direction, the phase of a wave): a cyclic map, whose ends meet, so that 359° and 1°
  look alike: `romaO`, Twilight.
- **Categories** (zones, materials, the rank that owns a cell): a qualitative map with `levels` equal to the number of
  categories, or Deep.

The Scientific colour maps page of Fabio Crameri and the cmocean documentation discuss each map's use.

## Why not Jet

<Media name="colormaps-jet" alt="Two plots of the same smooth bump, a Gaussian peak centred near (0.45, 0.55). On the left, in Jet, the bump shows a sharp cyan ring and a bright yellow ring around a red core, although the field has no edges. On the right, in cividis, the same bump brightens smoothly from dark blue to yellow, with no rings." caption="docs/examples/src/gallery.F90 (run with jet): one smooth field in Jet and in cividis" />

Jet (and other rainbows) changes lightness unevenly: it is darkest at its blue end, brightest in its yellow and cyan
bands, darker again at the red end. The eye reads lightness as value, so a smooth field shows bands and edges where
the data have none (the rings above), and the highest values look darker than those below them. Printed in
greyscale, or seen with a red-green deficiency, the order of the colours is lost. Jet stays available (`'Jet'`, for
comparison with older pictures); FIGURE never uses it by default.

## Discrete levels

`levels` cuts the map into that many bands of equal width, each with the map's colour at the band's centre, and no
blending between them (ImPlot's qualitative kind): a heatmap then shows its contours as the edges between bands, and
the colour bar shows the bands. `levels` is in [2, 256]. A diverging map with an even number of levels puts its
reference value on an edge between two bands, with an odd number in the middle of one. Bands of a qualitative map
(Deep) take its colours in order.

Reversed and discrete maps are registered under derived names: `'<name>_r'` and `'<name>|<levels>'`.

## A colour-scale legend

| Procedure | Notes |
|---|---|
| `ip_colormap_legend(id, colormap, vmin, vmax [, levels] [, horizontal] [, width] [, height] [, label_format] [, stat])` | A bar coloured by `colormap` from `vmin` to `vmax`, with ticks and their values: vertical (`vmin` at the bottom, values on the right) or `horizontal=.true.` (`vmin` at the left, values below). |

<<< @/examples/snippets/cb_legend-legend.F90{fortran}

<Media name="cb_legend" alt="A field drawn in eight bands of a diverging map from blue to red, with yellow contour lines at -0.5, 0 and 0.5; on its right a vertical legend of the same eight bands, their edges labelled -1, -0.75, ... 1; below, a horizontal continuous legend of the same map, labelled -1.0, -0.5, 0.0, 0.5, 1.0; above, the colour editor's picker open on a yellow" caption="docs/examples/src/cb_legend.F90" />

- **An item of the window**, not of a plot: put it beside a plot (`ig_same_line`), above or below it, in a side bar,
  in any window. `id` tells legends of one window apart and is not shown.
- **Discrete levels.** With `levels`, the bar has that many bands of equal width, each the map's colour at its centre:
  the colours a heatmap drawn with `ip_colormap(name, levels)` takes ([Discrete levels](#discrete-levels)); the ticks
  mark the bands' edges. Without `levels`, the bar is continuous and the ticks fall on round values (steps of 1, 2,
  2.5 or 5 times a power of ten), about every 40 pixels (100 when horizontal). Pass the continuous map's id with
  `levels`, as the example does: the bands are computed from it.
- **The scale** runs from `vmin` to `vmax`, the values a heatmap's `scale_min` and `scale_max` map to the colormap's
  ends; `vmin > vmax` turns it over.
- **Sizes** [pixels]: positive, given; negative, the space left in the window; absent, the default: vertical, 300
  long and as wide as the bar (a field's height) and the longest label; horizontal, the space left and as tall as the
  bar and a line of labels. `label_format` is a C `printf` format (default `'%g'`).
- **Band edges are labelled with their values.** With `levels`, an edge's label takes the digits it needs to show
  the edge's value: `label_format`'s precision is raised until the number printed is the edge (to 6 decimals for
  `%f`, as a contour line's label of `ip_contour`; 7 significant digits for `%e` and `%g`). With `'%.0f'` and bands
  of 87.5, the edges read 87.5 beside contour lines labelled 87.5, not 88; round edges keep the format's digits
  (`'%.0f'`: 100). The text around the number is kept (`'%.0f K'`). A format with no `f`, `e` or `g` conversion is
  used as it is. The continuous bar's ticks, at round values, use `label_format` unchanged.
- Bands and the bar sit on whole pixels, so neighbouring bands share their edge with no seam.
- Unlike `ip_colormap_scale` (ImPlot's `ColormapScale`, vertical only, continuous colours), the legend is horizontal
  or vertical and shows discrete levels as bands.
- Statuses: `FIG_ERR_ARGUMENT` for a colormap that is not registered, `vmin` equal to `vmax` or either not finite,
  `levels` outside [2, 256]; `FIG_ERR_STATE` outside a frame and from a [task](processes#tasks).
- Modes: the same in **window**, **headless** and **remote** mode.

## User maps

<<< @/examples/snippets/cb_colormap-load.F90{fortran}

<<< @/examples/snippets/cb_colormap-reversed.F90{fortran}

`ip_load_colormap(name, file [, stat])` reads one of two formats, told apart by the first character of the file (`[`
or `{`: JSON):

- **A CSV table**: one colour a row, `r, g, b`, separated by commas, semicolons, blanks or tabs. Components are in
  [0, 1], or in [0, 255] when one of them exceeds 1. `#` starts a comment, and a first line that is not numeric is a
  header (skipped). With four numbers a row, `x, r, g, b`, the first is the position of the colour (non-decreasing),
  and the map is resampled linearly to 256 uniform positions. From 2 to 65536 rows; the rows are the map's colours,
  first at the bottom of the scale.
- **A ParaView preset** in JSON, as ParaView's "Export" of presets writes it (an array of presets) or one preset: the
  preset whose `Name` is `name`, or the only one. Its `RGBPoints` (`x, r, g, b`, ...) are sampled at 256 uniform
  positions over their range, interpolated in its `ColorSpace` as ParaView does: `RGB`, `Lab` (`Lab/CIEDE2000` is
  interpolated in Lab), `Diverging` (Moreland's method), `HSV` (the shorter way round the hue circle) or `Step`
  (each colour up to the next point).

A loaded map is kept for the program's life, across `app%destroy` and a new `init*`, and may be loaded before
`init*`. Its name must be new: neither a map `ip_colormap` knows nor the reverse of one (ImPlot cannot replace a
colormap), not empty, without `|`, and not starting with `'FIGURE '` (the prefix of the style's own line colours).

**What is not read.** From a ParaView preset, only `Name`, `ColorSpace` and `RGBPoints`: the colour of NaNs, the
opacity points, the annotations and an indexed preset (`IndexedColors`, refused) are not. A `\u` escape in a JSON
string is read as `?`.

## Statuses and modes

| Status | When |
|---|---|
| `FIG_ERR_ARGUMENT` | `ip_colormap`: an unknown name, `levels` outside [2, 256]; `ip_load_colormap`: a malformed file (the message gives the line), a name taken or not allowed, a preset name not in a file of several; `ip_heatmap`, `ip_colormap_scale`: a colormap id that is not registered |
| `FIG_ERR_FAILED` | `ip_load_colormap`: the file cannot be read |
| `FIG_ERR_STATE` | `ip_colormap` before `init*`; any of the three from a [task](processes#tasks) |

`stat` is optional: absent, a failure stops the program with the message (`error stop`); present, it receives the
status, and `figure_last_error` the message ([Error handling](errors)).

<<< @/examples/snippets/cb_colormap-unknown.F90{fortran}

<<< @/examples/output/cb_colormap.txt{text}

**Modes.** The same in **window**, **headless** and **remote** mode: the colours are computed by the program, and
the remote client receives the drawn cells.

**Memory.** ImPlot expands a continuous map of 256 colours into a lookup table of 65026 entries, about 254 KiB per
map registered (a discrete map: its levels only). Registered at their first use, maps the program never asks for
cost nothing.

## Licences

The bundled tables keep their upstream licences, all permissive: CC0 and the matplotlib licence (cividis, inferno,
magma, turbo; turbo also Apache-2.0), MIT (cmocean, Crameri's), BSD-3-Clause (ParaView's Cool to Warm). The licence
files are installed under `share/licenses/` and must travel with a program built with FIGURE; [THIRD_PARTY.md](https://github.com/szaghi/figure/blob/main/THIRD_PARTY.md)
gives each source, its version and what a distribution must carry. The tables are written by `scripts/gen_colormaps.py`
from the pinned sources.
