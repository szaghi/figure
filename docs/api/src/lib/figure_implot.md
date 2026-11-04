---
title: figure_implot
---

# figure_implot

> figure_implot, ImPlot plots with Fortran arrays.

 `ip_begin_plot` returns true when the plot is visible: then declare its axes and items and close it with
 `ip_end_plot` (only in that case). Items (`ip_line`, `ip_scatter`, `ip_bars`, `ip_shaded`) take `real(real32)` or
 `real(real64)` arrays, read in place, without copies, during the call: they go straight to ImPlot's `float*` or
 `double*` items (ImPlot is templated on the element type). A non-contiguous actual argument (e.g. a matrix row
 `y(i,:)`) is copied by the compiler into a temporary: `ip_line(label, y, row)` plots a matrix row in place instead.

 Every item takes an optional `spec`, built by `ip_spec` from ImPlot's defaults (automatic colours, no markers):

```fortran
 call ip_line('residual', it, res, spec=ip_spec(line_color=[1.0_real64, 0.0_real64, 0.0_real64, 1.0_real64], &
                                               line_weight=2.0_real64, marker=ImPlotMarker_Circle))
```

**Source**: `src/lib/figure_implot.F90`

**Dependencies**

```mermaid
graph LR
  figure_implot["figure_implot"] --> figure_base["figure_base"]
  figure_implot["figure_implot"] --> figure_c_native["figure_c_native"]
  figure_implot["figure_implot"] --> figure_cimgui["figure_cimgui"]
  figure_implot["figure_implot"] --> figure_cimplot["figure_cimplot"]
  figure_implot["figure_implot"] --> figure_cimplot_enums["figure_cimplot_enums"]
  figure_implot["figure_implot"] --> figure_texture["figure_texture"]
  figure_implot["figure_implot"] --> iso_c_binding["iso_c_binding"]
  figure_implot["figure_implot"] --> iso_fortran_env["iso_fortran_env"]
```

## Contents

- [plot_spec_object](#plot-spec-object)
- [ip_line](#ip-line)
- [ip_scatter](#ip-scatter)
- [ip_bars](#ip-bars)
- [ip_heatmap](#ip-heatmap)
- [ip_shaded](#ip-shaded)
- [ip_end_plot](#ip-end-plot)
- [ip_setup_axes](#ip-setup-axes)
- [ip_line_r32](#ip-line-r32)
- [ip_scatter_r32](#ip-scatter-r32)
- [ip_bars_r32](#ip-bars-r32)
- [ip_shaded_r32](#ip-shaded-r32)
- [ip_shaded_ref_r32](#ip-shaded-ref-r32)
- [ip_line_values_r32](#ip-line-values-r32)
- [ip_line_row_r32](#ip-line-row-r32)
- [ip_heatmap_r32](#ip-heatmap-r32)
- [ip_line_r64](#ip-line-r64)
- [ip_scatter_r64](#ip-scatter-r64)
- [ip_bars_r64](#ip-bars-r64)
- [ip_shaded_r64](#ip-shaded-r64)
- [ip_shaded_ref_r64](#ip-shaded-ref-r64)
- [ip_line_values_r64](#ip-line-values-r64)
- [ip_line_row_r64](#ip-line-row-r64)
- [ip_heatmap_r64](#ip-heatmap-r64)
- [ip_image](#ip-image)
- [ip_colormap_scale](#ip-colormap-scale)
- [ip_begin_plot](#ip-begin-plot)
- [ip_spec](#ip-spec)
- [series_ok](#series-ok)
- [field_ok](#field-ok)
- [row_ok](#row-ok)
- [uniform](#uniform)
- [addr_r32](#addr-r32)
- [addr_r64](#addr-r64)
- [spec_c](#spec-c)
- [rgba_ok](#rgba-ok)
- [rgba](#rgba)

## Derived Types

### plot_spec_object

Style of a plot item: colours, line weight, markers, flags. Build it with `ip_spec`.

 The C struct is private so that a spec always starts from ImPlot's defaults: a zeroed one would draw nothing
 (line weight 0, marker size 0).

#### Components

| Name | Type | Attributes | Description |
|------|------|------------|-------------|
| `c` | type([im_plot_spec](/api/src/lib/figure_cimplot#im-plot-spec)) |  | `ImPlotSpec`, as passed to ImPlot. |

## Interfaces

### ip_line

Line through the points (x(i), y(i)); or through y(i) at uniformly spaced x, from a vector or from a row of a
 matrix (read in place, with a stride: no copy).

**Module procedures**: [`ip_line_r32`](/api/src/lib/figure_implot#ip-line-r32), [`ip_line_r64`](/api/src/lib/figure_implot#ip-line-r64), [`ip_line_values_r32`](/api/src/lib/figure_implot#ip-line-values-r32), [`ip_line_values_r64`](/api/src/lib/figure_implot#ip-line-values-r64), [`ip_line_row_r32`](/api/src/lib/figure_implot#ip-line-row-r32), [`ip_line_row_r64`](/api/src/lib/figure_implot#ip-line-row-r64)

### ip_scatter

Markers at the points (x(i), y(i)).

**Module procedures**: [`ip_scatter_r32`](/api/src/lib/figure_implot#ip-scatter-r32), [`ip_scatter_r64`](/api/src/lib/figure_implot#ip-scatter-r64)

### ip_bars

Bars of height y(i) centred at x(i).

**Module procedures**: [`ip_bars_r32`](/api/src/lib/figure_implot#ip-bars-r32), [`ip_bars_r64`](/api/src/lib/figure_implot#ip-bars-r64)

### ip_heatmap

A 2D field f(i, j) as coloured cells: i along x, j along y, j = 1 at the bottom.

**Module procedures**: [`ip_heatmap_r32`](/api/src/lib/figure_implot#ip-heatmap-r32), [`ip_heatmap_r64`](/api/src/lib/figure_implot#ip-heatmap-r64)

### ip_shaded

Area between two curves y1(x) and y2(x), or between a curve y(x) and the line y = yref.

**Module procedures**: [`ip_shaded_r32`](/api/src/lib/figure_implot#ip-shaded-r32), [`ip_shaded_r64`](/api/src/lib/figure_implot#ip-shaded-r64), [`ip_shaded_ref_r32`](/api/src/lib/figure_implot#ip-shaded-ref-r32), [`ip_shaded_ref_r64`](/api/src/lib/figure_implot#ip-shaded-ref-r64)

## Subroutines

### ip_end_plot

End the plot (only after `ip_begin_plot` returned true).

```fortran
subroutine ip_end_plot()
```

**Call graph**

```mermaid
flowchart TD
  ip_end_plot["ip_end_plot"] --> ImPlot_EndPlot["ImPlot_EndPlot"]
  style ip_end_plot fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_setup_axes

Axis labels (call right after `ip_begin_plot`).

```fortran
subroutine ip_setup_axes(xlabel, ylabel)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `xlabel` | character(len=*) | in |  | X label. |
| `ylabel` | character(len=*) | in |  | Y label. |

**Call graph**

```mermaid
flowchart TD
  ip_setup_axes["ip_setup_axes"] --> ImPlot_SetupAxes["ImPlot_SetupAxes"]
  ip_setup_axes["ip_setup_axes"] --> cstr["cstr"]
  style ip_setup_axes fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_line_r32

Line through the points (x(i), y(i)), single precision.

```fortran
subroutine ip_line_r32(label, x, y, spec, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Legend label. |
| `x` | real(kind=real32) | in | contiguous, target | Abscissae. |
| `y` | real(kind=real32) | in | contiguous, target | Ordinates. |
| `spec` | type([plot_spec_object](/api/src/lib/figure_implot#plot-spec-object)) | in | optional | Style (default: ImPlot's). |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ip_line_r32["ip_line_r32"] --> ImPlot_PlotLine_FloatPtrFloatPtr["ImPlot_PlotLine_FloatPtrFloatPtr"]
  ip_line_r32["ip_line_r32"] --> addr_r32["addr_r32"]
  ip_line_r32["ip_line_r32"] --> cstr["cstr"]
  ip_line_r32["ip_line_r32"] --> figure_check["figure_check"]
  ip_line_r32["ip_line_r32"] --> series_ok["series_ok"]
  ip_line_r32["ip_line_r32"] --> spec_c["spec_c"]
  style ip_line_r32 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_scatter_r32

Markers at the points (x(i), y(i)), single precision.

```fortran
subroutine ip_scatter_r32(label, x, y, spec, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Legend label. |
| `x` | real(kind=real32) | in | contiguous, target | Abscissae. |
| `y` | real(kind=real32) | in | contiguous, target | Ordinates. |
| `spec` | type([plot_spec_object](/api/src/lib/figure_implot#plot-spec-object)) | in | optional | Style (default: ImPlot's). |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ip_scatter_r32["ip_scatter_r32"] --> ImPlot_PlotScatter_FloatPtrFloatPtr["ImPlot_PlotScatter_FloatPtrFloatPtr"]
  ip_scatter_r32["ip_scatter_r32"] --> addr_r32["addr_r32"]
  ip_scatter_r32["ip_scatter_r32"] --> cstr["cstr"]
  ip_scatter_r32["ip_scatter_r32"] --> figure_check["figure_check"]
  ip_scatter_r32["ip_scatter_r32"] --> series_ok["series_ok"]
  ip_scatter_r32["ip_scatter_r32"] --> spec_c["spec_c"]
  style ip_scatter_r32 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_bars_r32

Bars of height y(i) centred at x(i), `bar_size` wide (in x units), single precision.

```fortran
subroutine ip_bars_r32(label, x, y, bar_size, spec, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Legend label. |
| `x` | real(kind=real32) | in | contiguous, target | Bar positions. |
| `y` | real(kind=real32) | in | contiguous, target | Bar heights. |
| `bar_size` | real(kind=real64) | in |  | Bar width [x units]. |
| `spec` | type([plot_spec_object](/api/src/lib/figure_implot#plot-spec-object)) | in | optional | Style (default: ImPlot's). |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ip_bars_r32["ip_bars_r32"] --> ImPlot_PlotBars_FloatPtrFloatPtr["ImPlot_PlotBars_FloatPtrFloatPtr"]
  ip_bars_r32["ip_bars_r32"] --> addr_r32["addr_r32"]
  ip_bars_r32["ip_bars_r32"] --> cstr["cstr"]
  ip_bars_r32["ip_bars_r32"] --> figure_check["figure_check"]
  ip_bars_r32["ip_bars_r32"] --> series_ok["series_ok"]
  ip_bars_r32["ip_bars_r32"] --> spec_c["spec_c"]
  style ip_bars_r32 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_shaded_r32

Area between the curves y1(x) and y2(x), single precision.

```fortran
subroutine ip_shaded_r32(label, x, y1, y2, spec, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Legend label. |
| `x` | real(kind=real32) | in | contiguous, target | Abscissae. |
| `y1` | real(kind=real32) | in | contiguous, target | First curve. |
| `y2` | real(kind=real32) | in | contiguous, target | Second curve. |
| `spec` | type([plot_spec_object](/api/src/lib/figure_implot#plot-spec-object)) | in | optional | Style (default: ImPlot's). |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ip_shaded_r32["ip_shaded_r32"] --> ImPlot_PlotShaded_FloatPtrFloatPtrFloatPtr["ImPlot_PlotShaded_FloatPtrFloatPtrFloatPtr"]
  ip_shaded_r32["ip_shaded_r32"] --> addr_r32["addr_r32"]
  ip_shaded_r32["ip_shaded_r32"] --> cstr["cstr"]
  ip_shaded_r32["ip_shaded_r32"] --> figure_check["figure_check"]
  ip_shaded_r32["ip_shaded_r32"] --> series_ok["series_ok"]
  ip_shaded_r32["ip_shaded_r32"] --> spec_c["spec_c"]
  style ip_shaded_r32 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_shaded_ref_r32

Area between the curve y(x) and the line y = yref, single precision.

```fortran
subroutine ip_shaded_ref_r32(label, x, y, yref, spec, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Legend label. |
| `x` | real(kind=real32) | in | contiguous, target | Abscissae. |
| `y` | real(kind=real32) | in | contiguous, target | Curve. |
| `yref` | real(kind=real64) | in |  | Reference line (-huge/+huge: to the plot edge). |
| `spec` | type([plot_spec_object](/api/src/lib/figure_implot#plot-spec-object)) | in | optional | Style (default: ImPlot's). |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ip_shaded_ref_r32["ip_shaded_ref_r32"] --> ImPlot_PlotShaded_FloatPtrFloatPtrInt["ImPlot_PlotShaded_FloatPtrFloatPtrInt"]
  ip_shaded_ref_r32["ip_shaded_ref_r32"] --> addr_r32["addr_r32"]
  ip_shaded_ref_r32["ip_shaded_ref_r32"] --> cstr["cstr"]
  ip_shaded_ref_r32["ip_shaded_ref_r32"] --> figure_check["figure_check"]
  ip_shaded_ref_r32["ip_shaded_ref_r32"] --> series_ok["series_ok"]
  ip_shaded_ref_r32["ip_shaded_ref_r32"] --> spec_c["spec_c"]
  style ip_shaded_ref_r32 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_line_values_r32

Line through y(i) at x = xstart + (i - 1) xscale, single precision.

```fortran
subroutine ip_line_values_r32(label, y, xscale, xstart, spec, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Legend label. |
| `y` | real(kind=real32) | in | contiguous, target | Ordinates. |
| `xscale` | real(kind=real64) | in | optional | Spacing of the abscissae (default 1). |
| `xstart` | real(kind=real64) | in | optional | First abscissa (default 0). |
| `spec` | type([plot_spec_object](/api/src/lib/figure_implot#plot-spec-object)) | in | optional | Style (default: ImPlot's). |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ip_line_values_r32["ip_line_values_r32"] --> ImPlot_PlotLine_FloatPtrInt["ImPlot_PlotLine_FloatPtrInt"]
  ip_line_values_r32["ip_line_values_r32"] --> addr_r32["addr_r32"]
  ip_line_values_r32["ip_line_values_r32"] --> cstr["cstr"]
  ip_line_values_r32["ip_line_values_r32"] --> figure_check["figure_check"]
  ip_line_values_r32["ip_line_values_r32"] --> series_ok["series_ok"]
  ip_line_values_r32["ip_line_values_r32"] --> spec_c["spec_c"]
  ip_line_values_r32["ip_line_values_r32"] --> uniform["uniform"]
  style ip_line_values_r32 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_line_row_r32

Line through the row `row` of `y`, y(row, j) at x = xstart + (j - 1) xscale, read in place (no copy),
 single precision.

```fortran
subroutine ip_line_row_r32(label, y, row, xscale, xstart, spec, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Legend label. |
| `y` | real(kind=real32) | in | contiguous, target | Matrix; its row `row` is plotted. |
| `row` | integer(kind=int32) | in |  | Row to plot, in 1..size(y, 1). |
| `xscale` | real(kind=real64) | in | optional | Spacing of the abscissae (default 1). |
| `xstart` | real(kind=real64) | in | optional | First abscissa (default 0). |
| `spec` | type([plot_spec_object](/api/src/lib/figure_implot#plot-spec-object)) | in | optional | Style (default: ImPlot's). |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ip_line_row_r32["ip_line_row_r32"] --> ImPlot_PlotLine_FloatPtrInt["ImPlot_PlotLine_FloatPtrInt"]
  ip_line_row_r32["ip_line_row_r32"] --> cstr["cstr"]
  ip_line_row_r32["ip_line_row_r32"] --> figure_check["figure_check"]
  ip_line_row_r32["ip_line_row_r32"] --> row_ok["row_ok"]
  ip_line_row_r32["ip_line_row_r32"] --> spec_c["spec_c"]
  ip_line_row_r32["ip_line_row_r32"] --> uniform["uniform"]
  style ip_line_row_r32 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_heatmap_r32

The field f(i, j) as coloured cells over [xmin, xmax] x [ymin, ymax], read in place (no copy, no transpose):
 cell (i, j) spans the i-th of size(f, 1) columns along x and the j-th of size(f, 2) rows along y, j = 1 at the
 bottom. Single precision.

```fortran
subroutine ip_heatmap_r32(label, f, xmin, xmax, ymin, ymax, scale_min, scale_max, label_format, colormap, spec, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Legend label. |
| `f` | real(kind=real32) | in | contiguous, target | Field: f(i, j), i along x, j along y. |
| `xmin` | real(kind=real64) | in |  | Left edge of the first column. |
| `xmax` | real(kind=real64) | in |  | Right edge of the last column. |
| `ymin` | real(kind=real64) | in |  | Bottom edge of row 1. |
| `ymax` | real(kind=real64) | in |  | Top edge of the last row. |
| `scale_min` | real(kind=real64) | in | optional | Value at the bottom of the colormap. |
| `scale_max` | real(kind=real64) | in | optional | Value at the top (both or none; none: data). |
| `label_format` | character(len=*) | in | optional | printf format printing each value in its cell. |
| `colormap` | integer(kind=int32) | in | optional | Colormap (`ImPlotColormap_*`; default: current). |
| `spec` | type([plot_spec_object](/api/src/lib/figure_implot#plot-spec-object)) | in | optional | Style (default: ImPlot's). |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ip_heatmap_r32["ip_heatmap_r32"] --> ImPlot_PlotHeatmap_FloatPtr["ImPlot_PlotHeatmap_FloatPtr"]
  ip_heatmap_r32["ip_heatmap_r32"] --> ImPlot_PopColormap["ImPlot_PopColormap"]
  ip_heatmap_r32["ip_heatmap_r32"] --> ImPlot_PushColormap_PlotColormap["ImPlot_PushColormap_PlotColormap"]
  ip_heatmap_r32["ip_heatmap_r32"] --> cstr["cstr"]
  ip_heatmap_r32["ip_heatmap_r32"] --> field_ok["field_ok"]
  ip_heatmap_r32["ip_heatmap_r32"] --> figure_check["figure_check"]
  ip_heatmap_r32["ip_heatmap_r32"] --> spec_c["spec_c"]
  style ip_heatmap_r32 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_line_r64

Line through the points (x(i), y(i)), double precision.

```fortran
subroutine ip_line_r64(label, x, y, spec, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Legend label. |
| `x` | real(kind=real64) | in | contiguous, target | Abscissae. |
| `y` | real(kind=real64) | in | contiguous, target | Ordinates. |
| `spec` | type([plot_spec_object](/api/src/lib/figure_implot#plot-spec-object)) | in | optional | Style (default: ImPlot's). |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ip_line_r64["ip_line_r64"] --> ImPlot_PlotLine_doublePtrdoublePtr["ImPlot_PlotLine_doublePtrdoublePtr"]
  ip_line_r64["ip_line_r64"] --> addr_r64["addr_r64"]
  ip_line_r64["ip_line_r64"] --> cstr["cstr"]
  ip_line_r64["ip_line_r64"] --> figure_check["figure_check"]
  ip_line_r64["ip_line_r64"] --> series_ok["series_ok"]
  ip_line_r64["ip_line_r64"] --> spec_c["spec_c"]
  style ip_line_r64 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_scatter_r64

Markers at the points (x(i), y(i)), double precision.

```fortran
subroutine ip_scatter_r64(label, x, y, spec, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Legend label. |
| `x` | real(kind=real64) | in | contiguous, target | Abscissae. |
| `y` | real(kind=real64) | in | contiguous, target | Ordinates. |
| `spec` | type([plot_spec_object](/api/src/lib/figure_implot#plot-spec-object)) | in | optional | Style (default: ImPlot's). |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ip_scatter_r64["ip_scatter_r64"] --> ImPlot_PlotScatter_doublePtrdoublePtr["ImPlot_PlotScatter_doublePtrdoublePtr"]
  ip_scatter_r64["ip_scatter_r64"] --> addr_r64["addr_r64"]
  ip_scatter_r64["ip_scatter_r64"] --> cstr["cstr"]
  ip_scatter_r64["ip_scatter_r64"] --> figure_check["figure_check"]
  ip_scatter_r64["ip_scatter_r64"] --> series_ok["series_ok"]
  ip_scatter_r64["ip_scatter_r64"] --> spec_c["spec_c"]
  style ip_scatter_r64 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_bars_r64

Bars of height y(i) centred at x(i), `bar_size` wide (in x units), double precision.

```fortran
subroutine ip_bars_r64(label, x, y, bar_size, spec, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Legend label. |
| `x` | real(kind=real64) | in | contiguous, target | Bar positions. |
| `y` | real(kind=real64) | in | contiguous, target | Bar heights. |
| `bar_size` | real(kind=real64) | in |  | Bar width [x units]. |
| `spec` | type([plot_spec_object](/api/src/lib/figure_implot#plot-spec-object)) | in | optional | Style (default: ImPlot's). |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ip_bars_r64["ip_bars_r64"] --> ImPlot_PlotBars_doublePtrdoublePtr["ImPlot_PlotBars_doublePtrdoublePtr"]
  ip_bars_r64["ip_bars_r64"] --> addr_r64["addr_r64"]
  ip_bars_r64["ip_bars_r64"] --> cstr["cstr"]
  ip_bars_r64["ip_bars_r64"] --> figure_check["figure_check"]
  ip_bars_r64["ip_bars_r64"] --> series_ok["series_ok"]
  ip_bars_r64["ip_bars_r64"] --> spec_c["spec_c"]
  style ip_bars_r64 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_shaded_r64

Area between the curves y1(x) and y2(x), double precision.

```fortran
subroutine ip_shaded_r64(label, x, y1, y2, spec, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Legend label. |
| `x` | real(kind=real64) | in | contiguous, target | Abscissae. |
| `y1` | real(kind=real64) | in | contiguous, target | First curve. |
| `y2` | real(kind=real64) | in | contiguous, target | Second curve. |
| `spec` | type([plot_spec_object](/api/src/lib/figure_implot#plot-spec-object)) | in | optional | Style (default: ImPlot's). |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ip_shaded_r64["ip_shaded_r64"] --> ImPlot_PlotShaded_doublePtrdoublePtrdoublePtr["ImPlot_PlotShaded_doublePtrdoublePtrdoublePtr"]
  ip_shaded_r64["ip_shaded_r64"] --> addr_r64["addr_r64"]
  ip_shaded_r64["ip_shaded_r64"] --> cstr["cstr"]
  ip_shaded_r64["ip_shaded_r64"] --> figure_check["figure_check"]
  ip_shaded_r64["ip_shaded_r64"] --> series_ok["series_ok"]
  ip_shaded_r64["ip_shaded_r64"] --> spec_c["spec_c"]
  style ip_shaded_r64 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_shaded_ref_r64

Area between the curve y(x) and the line y = yref, double precision.

```fortran
subroutine ip_shaded_ref_r64(label, x, y, yref, spec, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Legend label. |
| `x` | real(kind=real64) | in | contiguous, target | Abscissae. |
| `y` | real(kind=real64) | in | contiguous, target | Curve. |
| `yref` | real(kind=real64) | in |  | Reference line (-huge/+huge: to the plot edge). |
| `spec` | type([plot_spec_object](/api/src/lib/figure_implot#plot-spec-object)) | in | optional | Style (default: ImPlot's). |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ip_shaded_ref_r64["ip_shaded_ref_r64"] --> ImPlot_PlotShaded_doublePtrdoublePtrInt["ImPlot_PlotShaded_doublePtrdoublePtrInt"]
  ip_shaded_ref_r64["ip_shaded_ref_r64"] --> addr_r64["addr_r64"]
  ip_shaded_ref_r64["ip_shaded_ref_r64"] --> cstr["cstr"]
  ip_shaded_ref_r64["ip_shaded_ref_r64"] --> figure_check["figure_check"]
  ip_shaded_ref_r64["ip_shaded_ref_r64"] --> series_ok["series_ok"]
  ip_shaded_ref_r64["ip_shaded_ref_r64"] --> spec_c["spec_c"]
  style ip_shaded_ref_r64 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_line_values_r64

Line through y(i) at x = xstart + (i - 1) xscale, double precision.

```fortran
subroutine ip_line_values_r64(label, y, xscale, xstart, spec, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Legend label. |
| `y` | real(kind=real64) | in | contiguous, target | Ordinates. |
| `xscale` | real(kind=real64) | in | optional | Spacing of the abscissae (default 1). |
| `xstart` | real(kind=real64) | in | optional | First abscissa (default 0). |
| `spec` | type([plot_spec_object](/api/src/lib/figure_implot#plot-spec-object)) | in | optional | Style (default: ImPlot's). |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ip_line_values_r64["ip_line_values_r64"] --> ImPlot_PlotLine_doublePtrInt["ImPlot_PlotLine_doublePtrInt"]
  ip_line_values_r64["ip_line_values_r64"] --> addr_r64["addr_r64"]
  ip_line_values_r64["ip_line_values_r64"] --> cstr["cstr"]
  ip_line_values_r64["ip_line_values_r64"] --> figure_check["figure_check"]
  ip_line_values_r64["ip_line_values_r64"] --> series_ok["series_ok"]
  ip_line_values_r64["ip_line_values_r64"] --> spec_c["spec_c"]
  ip_line_values_r64["ip_line_values_r64"] --> uniform["uniform"]
  style ip_line_values_r64 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_line_row_r64

Line through the row `row` of `y`, y(row, j) at x = xstart + (j - 1) xscale, read in place (no copy),
 double precision.

```fortran
subroutine ip_line_row_r64(label, y, row, xscale, xstart, spec, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Legend label. |
| `y` | real(kind=real64) | in | contiguous, target | Matrix; its row `row` is plotted. |
| `row` | integer(kind=int32) | in |  | Row to plot, in 1..size(y, 1). |
| `xscale` | real(kind=real64) | in | optional | Spacing of the abscissae (default 1). |
| `xstart` | real(kind=real64) | in | optional | First abscissa (default 0). |
| `spec` | type([plot_spec_object](/api/src/lib/figure_implot#plot-spec-object)) | in | optional | Style (default: ImPlot's). |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ip_line_row_r64["ip_line_row_r64"] --> ImPlot_PlotLine_doublePtrInt["ImPlot_PlotLine_doublePtrInt"]
  ip_line_row_r64["ip_line_row_r64"] --> cstr["cstr"]
  ip_line_row_r64["ip_line_row_r64"] --> figure_check["figure_check"]
  ip_line_row_r64["ip_line_row_r64"] --> row_ok["row_ok"]
  ip_line_row_r64["ip_line_row_r64"] --> spec_c["spec_c"]
  ip_line_row_r64["ip_line_row_r64"] --> uniform["uniform"]
  style ip_line_row_r64 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_heatmap_r64

The field f(i, j) as coloured cells over [xmin, xmax] x [ymin, ymax], read in place (no copy, no transpose):
 cell (i, j) spans the i-th of size(f, 1) columns along x and the j-th of size(f, 2) rows along y, j = 1 at the
 bottom. Double precision.

```fortran
subroutine ip_heatmap_r64(label, f, xmin, xmax, ymin, ymax, scale_min, scale_max, label_format, colormap, spec, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Legend label. |
| `f` | real(kind=real64) | in | contiguous, target | Field: f(i, j), i along x, j along y. |
| `xmin` | real(kind=real64) | in |  | Left edge of the first column. |
| `xmax` | real(kind=real64) | in |  | Right edge of the last column. |
| `ymin` | real(kind=real64) | in |  | Bottom edge of row 1. |
| `ymax` | real(kind=real64) | in |  | Top edge of the last row. |
| `scale_min` | real(kind=real64) | in | optional | Value at the bottom of the colormap. |
| `scale_max` | real(kind=real64) | in | optional | Value at the top (both or none; none: data). |
| `label_format` | character(len=*) | in | optional | printf format printing each value in its cell. |
| `colormap` | integer(kind=int32) | in | optional | Colormap (`ImPlotColormap_*`; default: current). |
| `spec` | type([plot_spec_object](/api/src/lib/figure_implot#plot-spec-object)) | in | optional | Style (default: ImPlot's). |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ip_heatmap_r64["ip_heatmap_r64"] --> ImPlot_PlotHeatmap_doublePtr["ImPlot_PlotHeatmap_doublePtr"]
  ip_heatmap_r64["ip_heatmap_r64"] --> ImPlot_PopColormap["ImPlot_PopColormap"]
  ip_heatmap_r64["ip_heatmap_r64"] --> ImPlot_PushColormap_PlotColormap["ImPlot_PushColormap_PlotColormap"]
  ip_heatmap_r64["ip_heatmap_r64"] --> cstr["cstr"]
  ip_heatmap_r64["ip_heatmap_r64"] --> field_ok["field_ok"]
  ip_heatmap_r64["ip_heatmap_r64"] --> figure_check["figure_check"]
  ip_heatmap_r64["ip_heatmap_r64"] --> spec_c["spec_c"]
  style ip_heatmap_r64 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_image

A texture over [xmin, xmax] x [ymin, ymax], pixel row 1 at ymin (plot convention: y up).

```fortran
subroutine ip_image(label, tex, xmin, xmax, ymin, ymax, spec, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Legend label. |
| `tex` | type([texture_object](/api/src/lib/figure_texture#texture-object)) | in |  | Texture. |
| `xmin` | real(kind=real64) | in |  | Left edge. |
| `xmax` | real(kind=real64) | in |  | Right edge. |
| `ymin` | real(kind=real64) | in |  | Bottom edge (pixel row 1). |
| `ymax` | real(kind=real64) | in |  | Top edge (last pixel row). |
| `spec` | type([plot_spec_object](/api/src/lib/figure_implot#plot-spec-object)) | in | optional | Style (default: ImPlot's). |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ip_image["ip_image"] --> ImPlot_PlotImage["ImPlot_PlotImage"]
  ip_image["ip_image"] --> cstr["cstr"]
  ip_image["ip_image"] --> fig_texture_sampling["fig_texture_sampling"]
  ip_image["ip_image"] --> figure_check["figure_check"]
  ip_image["ip_image"] --> figure_fail["figure_fail"]
  ip_image["ip_image"] --> is_initialized["is_initialized"]
  ip_image["ip_image"] --> spec_c["spec_c"]
  ip_image["ip_image"] --> texture_ref["texture_ref"]
  style ip_image fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_colormap_scale

A colour bar for [scale_min, scale_max], next to a heatmap (outside `ip_begin_plot`/`ip_end_plot`).

```fortran
subroutine ip_colormap_scale(label, scale_min, scale_max, width, height, label_format, colormap)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Label (also the widget id). |
| `scale_min` | real(kind=real64) | in |  | Value at the bottom. |
| `scale_max` | real(kind=real64) | in |  | Value at the top. |
| `width` | real(kind=real64) | in | optional | Width [pixels] (default: ImPlot's). |
| `height` | real(kind=real64) | in | optional | Height [pixels] (default: ImPlot's). |
| `label_format` | character(len=*) | in | optional | printf format of the tick labels (default '%g', ImPlot's). |
| `colormap` | integer(kind=int32) | in | optional | Colormap (`ImPlotColormap_*`; default: current). |

**Call graph**

```mermaid
flowchart TD
  ip_colormap_scale["ip_colormap_scale"] --> ImPlot_ColormapScale["ImPlot_ColormapScale"]
  ip_colormap_scale["ip_colormap_scale"] --> cstr["cstr"]
  style ip_colormap_scale fill:#3e63dd,stroke:#99b,stroke-width:2px
```

## Functions

### ip_begin_plot

Begin a plot; if true, declare its content and call `ip_end_plot`.

**Returns**: `logical`

```fortran
function ip_begin_plot(title, width, height) result(visible)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `title` | character(len=*) | in |  | Title (also the plot id; '##id' hides it). |
| `width` | real(kind=real64) | in | optional | Width [pixels] (default: full width). |
| `height` | real(kind=real64) | in | optional | Height [pixels] (default: ImPlot's). |

**Call graph**

```mermaid
flowchart TD
  ip_begin_plot["ip_begin_plot"] --> ImPlot_BeginPlot["ImPlot_BeginPlot"]
  ip_begin_plot["ip_begin_plot"] --> cstr["cstr"]
  style ip_begin_plot fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_spec

Item style: ImPlot's defaults, with the given properties overridden. Colours are RGBA in [0, 1]; an absent
 colour stays automatic (from the colormap).

**Returns**: type([plot_spec_object](/api/src/lib/figure_implot#plot-spec-object))

```fortran
function ip_spec(line_color, line_weight, fill_color, fill_alpha, marker, marker_size, marker_line_color, marker_fill_color, size, flags, stat) result(spec)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `line_color` | real(kind=real64) | in | optional | Line colour, RGBA. |
| `line_weight` | real(kind=real64) | in | optional | Line weight [pixels] (lines, bar edges, markers). |
| `fill_color` | real(kind=real64) | in | optional | Fill colour, RGBA (bars, shaded areas). |
| `fill_alpha` | real(kind=real64) | in | optional | Alpha multiplier of the fill colours. |
| `marker` | integer(kind=int32) | in | optional | Marker shape (`ImPlotMarker_*`). |
| `marker_size` | real(kind=real64) | in | optional | Marker radius [pixels]. |
| `marker_line_color` | real(kind=real64) | in | optional | Marker outline colour, RGBA. |
| `marker_fill_color` | real(kind=real64) | in | optional | Marker fill colour, RGBA. |
| `size` | real(kind=real64) | in | optional | Error-bar whisker and digital-bar size [pixels]. |
| `flags` | integer(kind=int32) | in | optional | Item flags (`ImPlotItemFlags_*`, the item's own). |
| `stat` | integer(kind=int32) | out | optional | Status: `FIG_ERR_ARGUMENT` for a colour of size /= 4. |

**Call graph**

```mermaid
flowchart TD
  ip_spec["ip_spec"] --> figure_ImPlotSpec_default["figure_ImPlotSpec_default"]
  ip_spec["ip_spec"] --> figure_check["figure_check"]
  ip_spec["ip_spec"] --> figure_fail["figure_fail"]
  ip_spec["ip_spec"] --> rgba["rgba"]
  ip_spec["ip_spec"] --> rgba_ok["rgba_ok"]
  style ip_spec fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### series_ok

Whether two series can be plotted together: same size, and a size ImPlot's `int` count holds.

**Returns**: `logical`

```fortran
function series_ok(nx, ny, item, stat) result(ok)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `nx` | integer(kind=int64) | in |  | Size of the first series. |
| `ny` | integer(kind=int64) | in |  | Size of the second series. |
| `item` | character(len=*) | in |  | Item name, for the message. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ip_bars_r32["ip_bars_r32"] --> series_ok["series_ok"]
  ip_bars_r64["ip_bars_r64"] --> series_ok["series_ok"]
  ip_line_r32["ip_line_r32"] --> series_ok["series_ok"]
  ip_line_r64["ip_line_r64"] --> series_ok["series_ok"]
  ip_line_values_r32["ip_line_values_r32"] --> series_ok["series_ok"]
  ip_line_values_r64["ip_line_values_r64"] --> series_ok["series_ok"]
  ip_scatter_r32["ip_scatter_r32"] --> series_ok["series_ok"]
  ip_scatter_r64["ip_scatter_r64"] --> series_ok["series_ok"]
  ip_shaded_r32["ip_shaded_r32"] --> series_ok["series_ok"]
  ip_shaded_r64["ip_shaded_r64"] --> series_ok["series_ok"]
  ip_shaded_ref_r32["ip_shaded_ref_r32"] --> series_ok["series_ok"]
  ip_shaded_ref_r64["ip_shaded_ref_r64"] --> series_ok["series_ok"]
  series_ok["series_ok"] --> figure_fail["figure_fail"]
  style series_ok fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### field_ok

Whether a field can be drawn as a heatmap: a cell count ImPlot's `int` holds, and both scale ends or none.

**Returns**: `logical`

```fortran
function field_ok(nx, ny, has_min, has_max, stat) result(ok)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `nx` | integer(kind=int64) | in |  | size(f, 1). |
| `ny` | integer(kind=int64) | in |  | size(f, 2). |
| `has_min` | logical | in |  | scale_min given. |
| `has_max` | logical | in |  | scale_max given. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ip_heatmap_r32["ip_heatmap_r32"] --> field_ok["field_ok"]
  ip_heatmap_r64["ip_heatmap_r64"] --> field_ok["field_ok"]
  field_ok["field_ok"] --> figure_fail["figure_fail"]
  style field_ok fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### row_ok

Whether a matrix row can be plotted in place: the row exists, and ImPlot's `int` count and byte stride hold it.

**Returns**: `logical`

```fortran
function row_ok(rows, cols, bits, row, stat) result(ok)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `rows` | integer(kind=int64) | in |  | size(y, 1). |
| `cols` | integer(kind=int64) | in |  | size(y, 2): points. |
| `bits` | integer(kind=int64) | in |  | storage_size of an element [bits]. |
| `row` | integer(kind=int32) | in |  | Row to plot. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ip_line_row_r32["ip_line_row_r32"] --> row_ok["row_ok"]
  ip_line_row_r64["ip_line_row_r64"] --> row_ok["row_ok"]
  row_ok["row_ok"] --> figure_fail["figure_fail"]
  style row_ok fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### uniform

An optional abscissa parameter, or its default, as a C double.

**Attributes**: pure

**Returns**: `real(kind=c_double)`

```fortran
function uniform(value, default) result(v)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `value` | real(kind=real64) | in | optional | Given value. |
| `default` | real(kind=real64) | in |  | Default. |

**Call graph**

```mermaid
flowchart TD
  ip_line_row_r32["ip_line_row_r32"] --> uniform["uniform"]
  ip_line_row_r64["ip_line_row_r64"] --> uniform["uniform"]
  ip_line_values_r32["ip_line_values_r32"] --> uniform["uniform"]
  ip_line_values_r64["ip_line_values_r64"] --> uniform["uniform"]
  style uniform fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### addr_r32

Address of a contiguous array for ImPlot; null when empty: `c_loc` needs nonzero size (F2023 18.2.3.7).

 The address stays valid in the caller after the return: `a` is a TARGET dummy whose effective argument (the
 caller's CONTIGUOUS, TARGET dummy) is simply contiguous, so the association persists (F2023 15.5.2.5 p9).

**Returns**: `type(c_ptr)`

```fortran
function addr_r32(a) result(p)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `a` | real(kind=real32) | in | contiguous, target | Data. |

**Call graph**

```mermaid
flowchart TD
  ip_bars_r32["ip_bars_r32"] --> addr_r32["addr_r32"]
  ip_line_r32["ip_line_r32"] --> addr_r32["addr_r32"]
  ip_line_values_r32["ip_line_values_r32"] --> addr_r32["addr_r32"]
  ip_scatter_r32["ip_scatter_r32"] --> addr_r32["addr_r32"]
  ip_shaded_r32["ip_shaded_r32"] --> addr_r32["addr_r32"]
  ip_shaded_ref_r32["ip_shaded_ref_r32"] --> addr_r32["addr_r32"]
  style addr_r32 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### addr_r64

Address of a contiguous array for ImPlot; null when empty: `c_loc` needs nonzero size (F2023 18.2.3.7).

 The address stays valid in the caller after the return: `a` is a TARGET dummy whose effective argument (the
 caller's CONTIGUOUS, TARGET dummy) is simply contiguous, so the association persists (F2023 15.5.2.5 p9).

**Returns**: `type(c_ptr)`

```fortran
function addr_r64(a) result(p)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `a` | real(kind=real64) | in | contiguous, target | Data. |

**Call graph**

```mermaid
flowchart TD
  ip_bars_r64["ip_bars_r64"] --> addr_r64["addr_r64"]
  ip_line_r64["ip_line_r64"] --> addr_r64["addr_r64"]
  ip_line_values_r64["ip_line_values_r64"] --> addr_r64["addr_r64"]
  ip_scatter_r64["ip_scatter_r64"] --> addr_r64["addr_r64"]
  ip_shaded_r64["ip_shaded_r64"] --> addr_r64["addr_r64"]
  ip_shaded_ref_r64["ip_shaded_ref_r64"] --> addr_r64["addr_r64"]
  style addr_r64 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### spec_c

The C spec to pass: the given one, or ImPlot's defaults.

**Returns**: type([im_plot_spec](/api/src/lib/figure_cimplot#im-plot-spec))

```fortran
function spec_c(spec) result(c)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `spec` | type([plot_spec_object](/api/src/lib/figure_implot#plot-spec-object)) | in | optional | Style. |

**Call graph**

```mermaid
flowchart TD
  ip_bars_r32["ip_bars_r32"] --> spec_c["spec_c"]
  ip_bars_r64["ip_bars_r64"] --> spec_c["spec_c"]
  ip_heatmap_r32["ip_heatmap_r32"] --> spec_c["spec_c"]
  ip_heatmap_r64["ip_heatmap_r64"] --> spec_c["spec_c"]
  ip_image["ip_image"] --> spec_c["spec_c"]
  ip_line_r32["ip_line_r32"] --> spec_c["spec_c"]
  ip_line_r64["ip_line_r64"] --> spec_c["spec_c"]
  ip_line_row_r32["ip_line_row_r32"] --> spec_c["spec_c"]
  ip_line_row_r64["ip_line_row_r64"] --> spec_c["spec_c"]
  ip_line_values_r32["ip_line_values_r32"] --> spec_c["spec_c"]
  ip_line_values_r64["ip_line_values_r64"] --> spec_c["spec_c"]
  ip_scatter_r32["ip_scatter_r32"] --> spec_c["spec_c"]
  ip_scatter_r64["ip_scatter_r64"] --> spec_c["spec_c"]
  ip_shaded_r32["ip_shaded_r32"] --> spec_c["spec_c"]
  ip_shaded_r64["ip_shaded_r64"] --> spec_c["spec_c"]
  ip_shaded_ref_r32["ip_shaded_ref_r32"] --> spec_c["spec_c"]
  ip_shaded_ref_r64["ip_shaded_ref_r64"] --> spec_c["spec_c"]
  spec_c["spec_c"] --> figure_ImPlotSpec_default["figure_ImPlotSpec_default"]
  style spec_c fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### rgba_ok

Whether an optional colour is absent or has 4 components.

**Attributes**: pure

**Returns**: `logical`

```fortran
function rgba_ok(color) result(ok)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `color` | real(kind=real64) | in | optional | Colour, RGBA. |

**Call graph**

```mermaid
flowchart TD
  ip_spec["ip_spec"] --> rgba_ok["rgba_ok"]
  style rgba_ok fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### rgba

RGBA colour as an `ImVec4`.

**Attributes**: pure

**Returns**: type([im_vec4](/api/src/lib/figure_cimgui#im-vec4))

```fortran
function rgba(color) result(v)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `color` | real(kind=real64) | in |  | Colour, RGBA, 4 components. |

**Call graph**

```mermaid
flowchart TD
  ip_spec["ip_spec"] --> rgba["rgba"]
  style rgba fill:#3e63dd,stroke:#99b,stroke-width:2px
```
