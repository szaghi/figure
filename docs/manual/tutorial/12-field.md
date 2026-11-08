---
title: 12. The result field
---

# 12. The result field

After a run, the solver leaves the temperature field in the case's `field.dat`. The Result panel reads it and shows
it: a heatmap in a colormap, continuous or in bands, with a colour-scale legend; contour lines over it; a probe line
the user drags, whose temperature profile is plotted beside it, with the spread of the neighbouring columns as error
bars; and a probe point that reads the temperature under it.

<Media name="tut12_field" video alt="F5 runs the solver; when it has converged, the Result panel comes forward: the plate as a heatmap in cividis, dark blue where it is cold, yellow along the hot west side at 100 C, with a cold round body near the middle; labelled contour lines at 10 to 90; a vertical colour bar from 0 to 100 beside it; a white vertical probe line and a white probe point labelled 38.07 C. On the right a plot of the temperature along the probe line, with error bars. The probe line is dragged towards the hot side, to x = 0.292 m, and the profile becomes an arch from 20 to 60 C; the point is moved and reads 23.55 C. The colormap becomes batlow in 8 bands: the heatmap, the legend and the contour lines all step at 12.5, 25, 37.5 C and so on. Then Jet, with a warning mark and the text Jet: not perceptually uniform" caption="docs/examples/src/tut12_field.F90, run as tut12_field --examples /tmp/figure-studio --case /tmp/figure-studio/plate" />

The whole program: [tut12_field.F90](https://github.com/szaghi/figure/blob/main/docs/examples/src/tut12_field.F90).

## Reading the field

<<< @/examples/snippets/tut12_field-load.F90{fortran}

The solver writes a comment line, the grid and the plate's size, then the temperatures row after row; one
list-directed `read` fills `field(nx, ny)` in Fortran's order, `field(i, j)` at x = (i - 1) dx, y = (j - 1) dy. The
studio reads it after a converged run and when a case with a result is opened, then brings the Result panel forward.

## A colormap, continuous or in bands

<<< @/examples/snippets/tut12_field-controls.F90{fortran}

- `ip_colormap(name)` gives a colormap's id by name: FIGURE bundles perceptually uniform maps (`'cividis'`,
  `'batlow'`, the diverging `'cool-warm'`, ...) besides ImPlot's own, which keep their capitalized names (`'Viridis'`,
  `'Jet'`) ([Colormaps](/guide/colormaps)).
- `levels=bands` gives the same map in discrete bands: equal temperature steps become visible as edges, as on a
  printed chart ([Discrete levels](/guide/colormaps#discrete-levels)).
- **Why not Jet:** its lightness rises and falls along the scale, so a smooth field shows bright rings and sharp edges
  it does not have, and its order is lost in greyscale ([Why not Jet](/guide/colormaps#why-not-jet)). The studio
  offers it, and says so next to it with a mark, not only with a colour.

## The heatmap, its legend and its contour lines

<<< @/examples/snippets/tut12_field-heatmap.F90{fortran}

- `ip_heatmap(label, field, xmin, xmax, ymin, ymax, scale_min=, scale_max=, colormap=)` draws `field(i, j)` as
  coloured cells, read in place, `j = 1` at the bottom ([Heatmaps](/guide/images#heatmaps)). Its bounds are the
  cells' outer edges: half a spacing beyond the first and last nodes, so that each cell is centred on its node.
  `equal=.true.` keeps the plate's proportions.
- `ip_contour(label, field, x0, x1, y0, y1, ...)` draws contour lines of the same field, read in place: about ten
  at round values (`nlevels`), or, with bands, at the bands' edges (`levels=`). `labels=.true.` writes each line's
  value on it ([Contour lines](/guide/plots#contour-lines)). A label starting with `##` keeps the lines out of the
  plot's legend.
- `ip_drag_line_x(id, x)` is a vertical line the user drags; `x` changes in place and the function is `.true.` while
  it moves, so the studio clamps it to the plate. `ip_drag_point(id, x, y)` is the same for a point, and
  `ip_annotation(x, y, text)` labels it with the temperature of the nearest node
  ([Error bars, annotations and drag tools](/guide/plots#error-bars-annotations-and-drag-tools)).
- `ip_colormap_legend(id, colormap, vmin, vmax)` is the colour-scale legend beside the plot, continuous or, with
  `levels`, in the same bands with their edges labelled ([A colour-scale legend](/guide/colormaps#a-colour-scale-legend)).

## The profile along the probe line

<<< @/examples/snippets/tut12_field-profile.F90{fortran}

- `ip_line('T', field, i, xscale=dy)` plots the column `i` of the field, `field(i, :)`, against y, read in place:
  no copy of the column is made ([Arrays: the zero-copy contract](/guide/plots#arrays-the-zero-copy-contract)).
- `ip_error_bars(label, y, mean, below, above)` draws asymmetric error bars: at every fourth node, the mean of the
  five columns around the probe line, down to their least and up to their greatest value. Close to the hot side the
  bars are long: the temperature changes fast across the line.
- `'Along x = ... m###profile'`: the text after `###` is the plot's id, so the title changes as the line moves while
  the plot keeps its state (its zoom, its legend).

::: tip What you learned
A field read from the solver's file and shown as a heatmap in a perceptually uniform colormap, continuous or in
bands, with its legend; contour lines; a probe line and a probe point the user drags; a profile read in place from a
column of the field, with asymmetric error bars. Reference: [Heatmaps](/guide/images#heatmaps),
[Colormaps](/guide/colormaps), [Plots](/guide/plots), [Contour lines](/guide/plots#contour-lines).
:::

**Next:** [13. The field in 3-D](./13-view3d): the temperature as a surface, the camera, a cut, picking.
