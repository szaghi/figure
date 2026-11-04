---
title: Heatmaps and images
---

# Heatmaps and images

Two ways to show 2D data: a **heatmap** colours the cells of a field `f(i, j)` through a colormap, inside a plot; a
**texture** is an RGBA image the program composes itself, uploaded to the GPU and drawn in a window (`ig_image`) or in
a plot (`ip_image`). Both read Fortran's column-major arrays as they are: no copy, no transpose.

## Heatmaps

<<< @/examples/snippets/cb_field-field.F90{fortran}

<<< @/examples/snippets/cb_field-heatmap.F90{fortran}

`ip_heatmap(label, f, xmin, xmax, ymin, ymax [, scale_min, scale_max] [, label_format] [, colormap] [, spec] [, stat])`
draws `f(:, :)` (`real(real32)` or `real(real64)`, contiguous) over the rectangle `[xmin, xmax] x [ymin, ymax]`:

- **orientation**: `f(i, j)` is the cell in column `i` (along x, left to right) and row `j` (along y, **bottom to
  top**): the usual layout of a field computed on a grid `x(i), y(j)`. The array is read in place;
- **cells**: `size(f, 1)` columns of width `(xmax - xmin) / size(f, 1)`, `size(f, 2)` rows of height
  `(ymax - ymin) / size(f, 2)`: the bounds are the outer edges of the cells, not the centres of the first and last;
- **colour scale**: `scale_min` maps to the bottom of the colormap, `scale_max` to the top. Give both or neither
  (`FIG_ERR_ARGUMENT` otherwise); with neither, the range of the data, computed by ImPlot every frame;
- **labels**: `label_format` (a printf format, e.g. `'%.2f'`) prints each value in its cell. Off by default: on a
  large field, formatting a string per cell every frame costs far more than drawing the cells;
- **colormap**: `colormap=ImPlotColormap_Viridis` (also `_Plasma`, `_Hot`, `_Cool`, `_Jet`, `_Greys`, `_RdBu`,
  `_BrBG`, `_PiYG`, `_Spectral`, `_Twilight`, `_Pink`, and the qualitative `_Deep`, `_Dark`, `_Pastel`,
  `_Paired`) for this item only; default: the current colormap.

`ip_colormap_scale(label, scale_min, scale_max [, width] [, height] [, label_format] [, colormap])` draws the matching
colour bar. It is a widget of its own: call it outside `ip_begin_plot`/`ip_end_plot`, typically after `ig_same_line`,
with the same scale and colormap as the heatmap. A label starting with `##` is hidden.

## Textures

<<< @/examples/snippets/cb_field-texture.F90{fortran}

A `texture_object` is the one resource FIGURE keeps between frames: the image lives on the GPU, so the program uploads
pixels only when they change, and draws the texture every frame for nothing.

| Procedure | Purpose |
|---|---|
| `tex%init(width, height [, smooth] [, stat])` | create a `width` x `height` texture (after `app%init`); an existing one is destroyed first |
| `tex%update(rgba [, stat])` | upload all the pixels, `integer(int8) :: rgba(4, width, height)`, in place: one GPU upload, no copy |
| `tex%destroy()` | release it; safe in any state. `app%destroy` releases the textures left |
| `tex%width()`, `tex%height()`, `tex%is_initialized()` | size and state |
| `ig_image(tex [, width] [, height])` | the texture in the window, pixel row 1 at the **top** (default size: the texture's) |
| `ip_image(label, tex, xmin, xmax, ymin, ymax [, spec] [, stat])` | the texture in a plot over `[xmin, xmax] x [ymin, ymax]`, pixel row 1 at the **bottom** (`ymin`) |

**Pixels.** `rgba(:, i, j)` holds the red, green, blue and alpha bytes of the pixel in column `i` and row `j`. In
column-major order that is exactly the layout OpenGL expects (channels, then a row, then the next row), so `update`
passes the array to the GPU as it is. Fortran has no unsigned byte: values 128 to 255 are stored as their
two's-complement bit pattern, -128 to -1 (`-1_int8` is 255); `int(v - merge(256, 0, v > 127), int8)` converts a 0-255
integer `v`.

**Orientation.** The same texture shows row 1 at the top in a window (the convention of image files and screens) and
at the bottom in a plot (y grows upwards), as in the example above: build images in whichever order the data has, and
pick the procedure.

**Filtering.** When a texture is drawn larger than its size, each pixel stays a sharp square (nearest filtering): what
a scientific image needs, where a pixel is a measurement. `tex%init(..., smooth=.true.)` blends neighbouring pixels
instead (linear filtering), better for photographs.

**Lifetime.** `texture_object` has no finaliser on purpose: an assignment or a function result would finalise a copy
and destroy the texture the original still uses. Destroy textures explicitly, or let `app%destroy` release them. In
headless mode textures are accepted and checked (sizes, state) but nothing is drawn.
