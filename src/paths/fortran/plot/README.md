# The Fortran path's plot seam (szaghi/figure#15 P10-P12)

The plot seam is `figure_implot` as a whole: on the Fortran path a plot's frame (P10), its items (P11) and its
subplots, links and drag tools (P12) are drawn by Fortran together, since an item draws into its frame. The current
implementation, over ImPlot, is `src/paths/imgui/plot/figure_implot.F90`; its path-independent part (where an item's
arrays are read, the scratch, the decimation's buffers) is `src/lib/figure_plot_series.F90`, used by both.

The Fortran frame grows here under its own module names (`figure_plot_frame`, ...), so `$PATH_FORTRAN` keeps the
current `figure_implot` until the Fortran one can replace it: every 2-D plot golden and recording equal on the
Fortran path. Its tests (`src/tests/fortran/`) draw the same plot with ImPlot and with the Fortran frame, in one
program, and compare the two pictures (`test_compare_image`, threshold 2).

**Ticks (the owner's choice (a), 2026-11-22):** the frame places ticks as ImPlot's `Locator_Default` does (the major
count from the axis length, `NiceNum`, ten labelled minors per major, the labels thinned when they overflow), so the
goldens stay. foresight's locator (gnuplot's: the step from the range alone) gives other ticks on every axis probed;
adopting it later is its own change, with regenerated goldens. Labels: foresight's printf formatter, checked equal to
C's `%g` on the labels the goldens show.

## Status

- 2026-11-22, the skeleton (`figure_plot_frame`): a plot's begin and end with ImPlot's layout (padding, tick label
  sizes, the plot rectangle), two linear axes with given limits, ImPlot's ticks and `%g` labels (foresight's
  `c_real`), grid, tick marks, frame and plot backgrounds, border, ImPlot's automatic colours, and a line (ImPlot's
  segment quads, clipped). `figure_test_plot_frame` compares it with ImPlot on four plots (gfortran, nvfortran, ifx):
  equal at threshold 2, no pixel failing; the anti-aliased line pixels differ by 1 at most (ImPlot normalises a
  segment with the SSE `rsqrtss` estimate, the frame with `1/sqrt`). Not yet: auto-fit, pan and zoom, hover, legend,
  title and axis labels, more axes, scales, the style's line colours (ImPlot's colormaps), several plots open, the
  style variables of a theme, labels without an allocation per label.

## What the current seam calls, to replace

The ImPlot functions `figure_implot` calls (76, through `figure_cimplot`) and the native C++ that calls ImPlot for it
(`native/*.cpp`), by the step that replaces them. Checked off as the Fortran seam takes each over.

### P10, the frame

- [ ] Plot begin and end: `ImPlot_BeginPlot`; `fig_plot_end` and `fig_plot_state` (`figure_native.cpp`: `EndPlot`,
      `SetupLock`, `GetCurrentPlot`); the scope record's ends (`figure_scope.cpp`)
- [ ] Axes: `ImPlot_SetupAxes`, `ImPlot_SetupAxis`, `ImPlot_SetAxes`
- [ ] Limits: `ImPlot_SetupAxisLimits`, `ImPlot_SetupAxesLimits`, `ImPlot_SetNextAxisToFit`, `ImPlot_GetPlotLimits`;
      constraints: `fig_plot_axis_constraints` (`SetupAxisLimitsConstraints`, `SetupAxisZoomConstraints`)
- [ ] Scales: `ImPlot_SetupAxisScale_PlotScale` (linear, log, symlog, time); `fig_plot_x_transform`
- [ ] Ticks and labels: `ImPlot_SetupAxisTicks_doublePtr`, `ImPlot_SetupAxisFormat_Str`
- [ ] Legend: `ImPlot_SetupLegend`, `ImPlot_IsLegendEntryHovered`, `ImPlot_BeginLegendPopup`,
      `ImPlot_EndLegendPopup`, `ImPlot_HideNextItem`
- [ ] Queries: `ImPlot_GetPlotSize`, `ImPlot_IsPlotHovered`, `ImPlot_GetPlotMousePos`, `ImPlot_PlotToPixels_double`,
      `ImPlot_PixelsToPlot_Float`
- [ ] Pan, zoom, box select: `ImPlot_GetPlotSelection`, `ImPlot_IsPlotSelected`, `ImPlot_CancelPlotSelection`; the
      context menus
- [ ] Colormaps: `fig_colormap`, `fig_colormap_count`, `fig_colormap_name`, `fig_colormap_stops`, `fig_load_colormap`
      (`figure_colormap.cpp`: `AddColormap`, `GetColormap*`, `SampleColormap`); `ImPlot_PushColormap_PlotColormap`,
      `ImPlot_PopColormap`, `ImPlot_SampleColormap`, `ImPlot_GetColormapCount`; the colour scale
      `ImPlot_ColormapScale`, `fig_colormap_legend`; `fig_gradient_edit`
- [ ] Styles: `ImPlotStyle` (`figure_style_generated.cpp`, `figure_theme.cpp`, `figure_native.cpp`: `GetStyle`,
      `StyleColorsAuto`, `IsColorAuto`, `GetStyleColorName`, `ShowStyleEditor`)
- [ ] Drop targets: `fig_dnd_plot_target` (`figure_dnd.cpp`: `BeginDragDropTargetPlot`, `...Axis`, `...Legend`)
- [ ] Drawing in a plot: `figure_canvas.cpp` (`GetPlotDrawList`, `PushPlotClipRect`, `PopPlotClipRect`)

### P11, the items

- [ ] Lines, scatter, stairs, stems, shaded: `ImPlot_PlotLine_*`, `ImPlot_PlotScatter_*`, `ImPlot_PlotStairs_*`,
      `ImPlot_PlotStems_*`, `ImPlot_PlotShaded_*`
- [ ] Bars and groups, error bars, infinite lines: `ImPlot_PlotBars_*`, `ImPlot_PlotBarGroups_*`,
      `ImPlot_PlotErrorBars_*`, `ImPlot_PlotInfLines_*`
- [ ] Pies, bubbles, digital, text: `ImPlot_PlotPieChart_*`, `ImPlot_PlotBubbles_*`, `ImPlot_PlotDigital_*`,
      `ImPlot_PlotText`
- [ ] Heatmaps, histograms, images, fields: `ImPlot_PlotHeatmap_*`, `ImPlot_PlotHistogram_*`,
      `ImPlot_PlotHistogram2D_*`, `ImPlot_PlotImage`, `fig_field_image` (`figure_field.cpp`), `fig_texture_sampling`
- [ ] Item colour and annotations: `ImPlot_GetLastItemColor`, `fig_plot_annotation` (`Annotation`)

### P12, subplots, links, drag tools, tags

- [ ] Subplots and aligned plots: `ImPlot_BeginSubplots`, `ImPlot_EndSubplots`, `ImPlot_BeginAlignedPlots`,
      `ImPlot_EndAlignedPlots`, `fig_aligned_open`
- [ ] Linked axes: `fig_plot_link` (`figure_plot_links.cpp`: `SetupAxisLinks`)
- [ ] Drag tools: `ImPlot_DragLineX`, `ImPlot_DragLineY`, `ImPlot_DragPoint`, `ImPlot_DragRect`
- [ ] Axis tags: `fig_plot_tag` (`TagX`, `TagY`)

The 3-D plots (`figure_implot3d`, ImPlot3D) are P13; they share only `figure_plot_series` and the colormaps with the
2-D seam (`figure_plot3d.cpp` and `figure_view3d.cpp` read ImPlot's colormaps).
