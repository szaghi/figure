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
- 2026-11-22, per-plot state and the fit (P10 steps 1 and 2): the frame keeps a table of plots keyed by their title's
  ID (`core_get_id`, ImPlot's `Window->GetID`), integer handles, each with its six axes (range, flags, limits and
  their condition, the fit), its items (keyed by ImPlot's item ID: the label hashed with the seed `plot.ID - 1` by
  `figure_plot_hash`, Dear ImGui's CRC32c checked equal to `core_get_id`; the colour given or assigned once from the
  colormap, the plot's own colour counter) and the frame it was last begun on; several plots one after another in a
  frame, none nested. A table grows to 256 plots (256 items a plot), then the least recently drawn one not drawn on
  this frame makes room (ImPlot keeps everything: below the cap nothing differs). Limits `once` (the default, as
  `ip_setup_*_limits`) and `always`; the fit of `SetupFinish`/`EndPlot`: an axis without limits fits on the plot's
  first frame, `auto_fit` every frame, `pf_set_next_axis_to_fit`/`pf_set_next_axes_to_fit` on the next plot, the
  items extending the range while the plot is drawn and the fit applied at `pf_end_plot` (shown from the next frame,
  ImPlot's lag), `FitPadding` 0, a degenerate range widened to +-0.5, locked ends kept, an axis with no data not fit
  (`fig_plot_end`); `equal` (`ImPlotFlags_Equal`: `SetupFinish`'s and `EndPlot`'s aspect rules); `pf_plot_limits`.
  `figure_test_plot_frame_state` compares 9 cases with ImPlot, the ranges of every frame equal to the bit and the
  pictures at threshold 2 (gfortran, nvfortran, ifx). Not yet: axis labels and the axes X2, X3, Y2, Y3 (the state
  holds them), `SetAxes`, limits' constraints, `FitPadding` and the other ImPlot style variables of a theme, the
  automatic colours of FIGURE's own styles (their colormaps are registered by the native layer: the colormap
  registry, step 7), the item ID pushed on Dear ImGui's ID stack (figure_core has no `PushOverrideID`).
- 2026-11-22, title, axis labels, the six axes and the legend (P10 steps 3 and 4): the title above the plot (`##`
  hides the rest, `AddTextCentered`), axis labels (x: `AddText` beyond the tick labels; y: `AddTextVertical`, glyph
  by glyph from the font's baked glyphs through figure_core's new `core_font_glyph`, UTF-8 decoded), each in the layout
  of `SetupFinish` (`PadAndDatumAxesX`/`Y`); the axes X1-X3 and Y1-Y3 with `ip_setup_axis`'s flags (secondary axes
  opposite and without grid lines by default, `opposite`, `no_grid`, `invert`, `lock`, `auto_fit`), `pf_set_axes`,
  the minor tick marks and axis lines of a side's second and third axes, `equal` per pair; the legend
  (`pf_setup_legend`: compass point, outside, horizontal), its entries in first-drawn order, `##` labels without one,
  `LegendBg`/`LegendBorder` and ImPlot's paddings, an outside legend's room from the frame after; each entry a button
  on the item's ID after the legend's own, as ImPlot: a click hides or shows the item (`pf_hide_next_item`, once or
  always, as `ip_hide_next_item`), a hover tints the entry, doubles the item's line weight on the next frame and
  highlights its axis where its direction has more than one; `pf_legend_hovered`. `figure_test_plot_frame_labels`
  compares 12 cases with ImPlot (title, `##` title, labels with a non-ASCII character, a long y label, a second y
  axis, an inverted top x axis and a left third y axis, the legend at four places inside and outside, clicks, hover),
  ranges and `legend_hovered` of every frame equal, pictures at threshold 2 with no pixel failing (gfortran,
  nvfortran, ifx). A line twice as thick (a hovered item) is sensitive to ImPlot's `rsqrtss` normal: one edge pixel
  differed by 48 on one curve (see the test's header). Not yet: the mouse text and the axes' hover (the pointer on the
  plot area), the legend's scrolling, sorting and context menu, tick formats, `TickLabelsInside`, `Foreground`.
- 2026-11-22, scales (P10 step 5): `figure_plot_locators`, ImPlot's `Locator_Default`, `Locator_Log10`
  (`CalcLogarithmicExponents`, `AddTicksLogarithmic`), `Locator_SymLog` (`CalcSymLogPixel`), `Locator_Time` (units,
  steps, the formats of `TimeFormatLevel0/1/1First`, `FormatDateTime`, UTC through a Fortran `gmtime`/`timegm`,
  ImPlot's `AddTime`, `FloorTime`, `TimeLabelSame`, years by `NiceNum`) and the transforms (log10 of max(v, DBL_MIN),
  2 asinh(v/2)); checked first standalone against ImPlot's own C++ on 25 ranges (a scratch harness: every tick's
  value to 17 digits, major, level, label and label size equal, gfortran, nvfortran, ifx), then in the frame:
  `pf_setup_axis(scale=)`, `pf_setup_axes(xscale=, yscale=)`, points through the transform, the scales' constraints
  in the fit, two label levels on time axes. `pow`, `log10`, `asinh`, `sinh` are bound from the C library (glibc's
  `pow(10, e)` is not correctly rounded at e = 23, 210; nvfortran's own differ) and the sums of products are split
  (nvfortran -O2 makes FMAs). `figure_test_plot_frame_scales` compares 9 cases with ImPlot (log y over decades, log x,
  symlog across zero and within [-1, 1], log y with values <= 0, a log y2, time axes over hours, months, 30 years):
  ranges of every frame equal, pictures at threshold 2 with no pixel failing (three compilers). Not yet: tick formats
  (`SetupAxisFormat`), custom ticks, local time and ImPlot's time style options (`UseLocalTime`, `UseISO8601`,
  `Use24HourClock`: the locator takes the last two, the frame passes ImPlot's defaults).
- 2026-11-22, colormaps (P10 step 7): `figure_plot_colormaps`, a registry as ImPlot's `ImPlotColormapData` (ids in
  ImPlot's order: its 16 maps, their keys copied from implot.cpp; then the maps registered at run time; keys and
  tables, `ImMixU32` steps of a continuous map, `LerpTable`), FIGURE's names (`ip_colormap`'s rules: ImPlot's maps,
  the 14 bundled ones from `figure_plot_colormaps_bundled`, generated by `scripts/gen_plot_colormaps.py` from
  third_party/colormaps, `<name>_r`, `<name>|<levels>`), the style's map and a push/pop stack. The style's line
  colours come from FIGURE's style state through a new native accessor, `fig_style_lines` (native/figure_native.cpp,
  bound in src/lib/figure_c_native.F90: FIGURE's own state, not ImPlot's, with a change counter): the frame's
  automatic colours are the style's (seal's eight, Deep for the themes without lines). `pf_colormap`,
  `pf_colormap_scale` (`ColormapScale`: `RenderColorBar` through figure_core's new `core_draw_rect_filled_multicolor`,
  the ticks of the linear locator with a label format, `CalcTextColor` marks, the label by `AddTextVertical`).
  `figure_test_plot_frame_colors` compares 10 cases with ImPlot (seal's automatic colours and legend over nine lines,
  'dark', seal again; colour bars: Viridis, Deep, a reversed range, a label format without a label, inferno,
  Viridis in 6 bands, cool-warm_r): pictures at threshold 2, no pixel failing (the bars pixel-exact), three
  compilers. Not yet: user maps (`ip_load_colormap`), edited maps (`ig_gradient_edit`), `ip_colormap_legend`, the
  pushes FIGURE's items make (heatmaps, pies: P11).
- 2026-11-22, input (P10 step 8): ImPlot's `UpdateInput` in the frame: the plot's and the axes' buttons (Dear ImGui's
  `ButtonBehavior`, ImPlot's IDs and flags, in ImPlot's order), the pan by the mouse's delta (`SetMin`/`SetMax`, the
  pan locks, `equal`), the wheel's zoom about the pointer (`ZoomRate` 0.1, the wheel taken from the window:
  `SetKeyOwner`), the box (right drag; Alt, Shift; confirmed, cancelled by a left click or `pf_cancel_selection`),
  the double click's fit, the menus' latch; drawn: an axis hovered or held, the box, the crosshairs, the mouse text
  (south-east, values rounded to the ticks' precision, the extra axes in parentheses, time axes' cursor format), the
  axis side switch; the context menus (plot, axes, legend: FIGURE's widgets of src/lib where they pass ImPlot's
  arguments, figure_core wrappers elsewhere); the items' ID stack (`PushOverrideID` of the items' ID, as ImPlot);
  the queries `pf_plot_hovered`, `pf_plot_mouse`, `pf_plot_to_pixels`, `pf_pixels_to_plot`, `pf_plot_selection`,
  `pf_cancel_selection`. Shared code: figure_core's input, ID and widget wrappers; `figure_io_input` (io.MouseDelta,
  MouseWheel, MouseDragMaxDistanceSqr, KeyMods, DragDropActive) and `igSetKeyOwner` added to the generated glue
  (scripts/gen_bindings.py). `figure_test_plot_frame_input` compares 8 cases with ImPlot under the same synthetic
  input (pan, wheel zoom, box and cancel, double-click fit, axis-only pan and zoom, mouse text on log and y2 axes,
  an axis hovered, the context menu and its Crosshairs): the state of every frame (ranges, hover, pointer,
  selection) equal to the bit, pictures at threshold 2 (three compilers). Not yet: the time axes' pickers in their
  menu, `GetPlotSize`, `ImPlotInputMap` other than the default.

## What the current seam calls, to replace

The ImPlot functions `figure_implot` calls (76, through `figure_cimplot`) and the native C++ that calls ImPlot for it
(`native/*.cpp`), by the step that replaces them. Checked off as the Fortran seam takes each over.

### P10, the frame

- [x] Plot begin and end, kept between frames: `ImPlot_BeginPlot`; `fig_plot_end` (`figure_native.cpp`: `EndPlot`,
      `SetupLock`, the fit of axes without data dropped)
- [ ] `fig_plot_state` (`GetCurrentPlot`: the axes enabled, their scales); the scope record's ends (`figure_scope.cpp`)
- [x] Axes: `ImPlot_SetupAxes`, `ImPlot_SetupAxis`, `ImPlot_SetAxes`
- [x] Limits and the fit: `ImPlot_SetupAxisLimits`, `ImPlot_SetupAxesLimits`, `ImPlot_SetNextAxisToFit`,
      `ImPlot_GetPlotLimits` (X1, Y1)
- [ ] Constraints: `fig_plot_axis_constraints` (`SetupAxisLimitsConstraints`, `SetupAxisZoomConstraints`)
- [x] Scales: `ImPlot_SetupAxisScale_PlotScale` (linear, log, symlog, time)
- [ ] `fig_plot_x_transform` (the decimation's view of an axis's transform)
- [ ] Ticks and labels: `ImPlot_SetupAxisTicks_doublePtr`, `ImPlot_SetupAxisFormat_Str`
- [x] Legend: `ImPlot_SetupLegend`, `ImPlot_IsLegendEntryHovered`, `ImPlot_HideNextItem`
- [ ] Legend popups: `ImPlot_BeginLegendPopup`, `ImPlot_EndLegendPopup`
- [x] Queries: `ImPlot_IsPlotHovered`, `ImPlot_GetPlotMousePos`, `ImPlot_PlotToPixels_double`,
      `ImPlot_PixelsToPlot_Float`
- [ ] Query not yet: `ImPlot_GetPlotSize`
- [x] Pan, zoom, box select: `ImPlot_GetPlotSelection`, `ImPlot_IsPlotSelected`, `ImPlot_CancelPlotSelection`; the
      context menus (the plot's, the axes', the legend's; a time axis's date and time pickers not yet)
- [x] Colormaps: `fig_colormap` (ImPlot's and the bundled maps, `_r`, `|levels`: `AddColormap`, `GetColormap*`,
      `SampleColormap`); `ImPlot_PushColormap_PlotColormap`, `ImPlot_PopColormap`, `ImPlot_SampleColormap`,
      `ImPlot_GetColormapCount`; the colour scale `ImPlot_ColormapScale`; the style's line colours
      (`fig_style_lines`)
- [ ] Colormaps not yet: `fig_colormap_count`, `fig_colormap_name`, `fig_colormap_stops`, `fig_load_colormap` (user
      maps: CSV, ParaView JSON), `fig_colormap_legend`, `fig_gradient_edit`
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
