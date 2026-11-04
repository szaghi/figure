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

<Media name="cb_field" alt="A heatmap of a Gaussian bump with its colour bar, an image drawn inside the plot and the same image as a widget" caption="docs/examples/src/cb_field.F90: the heatmap, its colour scale, and a texture in the plot and as a widget" />

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

## An explorer: the Mandelbrot set

[`src/examples/figure_mandelbrot.F90`](https://github.com/szaghi/figure/blob/main/src/examples/figure_mandelbrot.F90)
puts the pieces together. ImPlot handles the interaction (drag to pan, wheel or a right-dragged box to zoom,
double-click to fit) on a plot with `equal` axes. Every frame the program reads `ip_plot_limits` and `ip_plot_size`.
When they, or the iteration count, change, it recomputes the image at the plot's resolution (OpenMP, `default(none)`)
and uploads it with `tex%update`; otherwise it only draws the texture again with `ip_image`, so lazy redraw keeps the
window idle.

<Media name="mandelbrot" video alt="Zooming 5000 times into the seahorse valley of the Mandelbrot set, then raising the iterations" caption="figure_mandelbrot: 100 wheel steps into the spiral at -0.743644 + 0.131826 i, every frame recomputed at the plot's resolution" />

```bash
fobis build --mode examples-gnu && exe/figure_mandelbrot      # the example modes build with OpenMP
```

On the development machine (WSL2, RTX 4070 through `GALLIUM_DRIVER=d3d12`, 16 threads) the initial 1210 x 669 view
computes in about 29 ms and uploads in about 3.7 ms; idle, the window costs 0.5% of one core.

## Speed: a new 4K image every frame

`src/examples/figure_bench_texture.F90` measures the path this page is about: a program that shows a new 3840 x 2160
image every frame. Each frame it writes new pixels into the array (fill), hands them to the GPU (`tex%update`), and
renders and presents the window (vsync off, lazy redraw off); 120 frames after 20 of warm-up. For comparison,
[`scripts/bench/wx_bench.f90`](https://github.com/szaghi/figure/blob/main/scripts/bench/wx_bench.f90) runs the same
loop with [wxFortran](https://github.com/jacobwilliams/wxFortran) (built as its README prescribes, wxWidgets 3.3 from
conda-forge): fill its `integer :: rgb(3, w, h)` array, build a `wx_bitmap` from it, draw it scaled in a paint
handler.

| Per frame, mean of two runs | FIGURE | wxFortran |
|---|---|---|
| fill (write the pixel array) | 2.9 ms (`int8` RGBA) | 7.1 ms (default `integer` RGB) |
| hand-off to the toolkit | 2.2 ms (`tex%update`) | 92 ms (`wx_bitmap(rgb)`) |
| draw and present | 4.8 ms (`next_frame`) | 4.0 ms (`draw_bitmap`) |
| **frame rate** | **≈ 100 frames/s** | **≈ 9.5 frames/s** |

Measured on one machine (WSL2/WSLg, x86-64 with 16 hardware threads, RTX 4070 through D3D12, gfortran 16.2 for FIGURE, gfortran 15.3 for
wxFortran's release profile), so the absolute numbers are that machine's; the ratio is what the two designs cost.
FIGURE passes the array to one `glTexSubImage2D`; wxFortran converts it through Fortran temporaries (clamp, reshape,
`int8`), then a `wxImage` and a `wxBitmap`. Building wxFortran's C++ shim with `-O2` (its build passes no optimisation
flag) changed nothing measurable (90-97 ms), so the cost is in the path, not in the flags.

To reproduce: `fobis build --mode examples-gnu && GALLIUM_DRIVER=d3d12 exe/figure_bench_texture 120`; for wxFortran,
copy `scripts/bench/wx_bench.f90` into its `example/` directory and run
`python tools/fpm_wx.py run --profile release --example wx_bench -- 120` in its environment.
