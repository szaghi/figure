!< figure_implot, 2-D plots with Fortran arrays, on the Fortran path: drawn by the Fortran plot frame.
module figure_implot
!< figure_implot, 2-D plots with Fortran arrays, on the Fortran path: drawn by the Fortran plot frame.
!<
!< The Fortran path's implementation of the plot seam (szaghi/figure#15, the seam's switch): the same module name,
!< public API (`ip_*`, `plot_spec_object`, ImPlot's constants), statuses and messages as the current path's
!< (src/paths/imgui/plot/figure_implot.F90, over ImPlot), each procedure checking its arguments as there, in the same
!< order, then drawing with the Fortran plot frame (src/paths/fortran/plot/: figure_plot_frame, figure_plot_items,
!< figure_plot_tools, figure_plot_colorbar, figure_plot_colormaps, figure_plot_style), which reproduces ImPlot's
!< pictures and behaviour (README there). What the current path asks of the native layer is here the frame's:
!<
!< - the scope record's plot entries (native/figure_scope.cpp): the frame's plots, subplots, aligned groups and legend
!<   popups are snapshot, recovered and closed through `fig_scope_plot_hooks` (`pf_open_ids`, `pf_recover_to`,
!<   `pf_end_*`), registered at the first entry point;
!< - the style: FIGURE's ImPlot style (themes, `ip_set_style_*`, `ip_push_style_*`) still lives in the native layer's
!<   ImPlot context, and `ps_refresh` brings it into the frame's (figure_plot_style) whenever it changed
!<   (`fig_generations`), at each entry point: a push inside a plot reaches the next item;
!< - the colormaps: the frame's registry (figure_plot_colormaps). Until the 3-D seam's switch, `ip_colormap` and
!<   `ip_load_colormap` also register in the native one, which the 3-D views (`view3d_object`, native) read: the same
!<   names in the same order, so the same ids; the statuses and messages of those two are the native layer's. The
!<   gradient editor (`ig_gradient_edit`) is figure_gradient_edit's (P14), its edits made in the frame's registry and
!<   given to the native one (`fig_colormap_set_stops`);
!< - `fig_plot_end`, `fig_plot_state`, `fig_plot_axis_constraints`, `fig_plot_x_transform`, `fig_plot_annotation`,
!<   `fig_plot_tag`, `fig_plot_link`, `fig_aligned_open`, `fig_dnd_plot_target`, `fig_colormap_legend`,
!<   `fig_field_image`, `fig_texture_sampling`: the frame's `pf_*` (their native refusals, which the frame stops on,
!<   are checked here first, with the native messages);
!< - figure_canvas's `'plot'` layer and figure_testing's plot queries: figure_plot_hooks (this path's).
!<
!< `test_plot_copies` and `test_plot_stride` count what the current path copies and the stride it gives ImPlot
!< (figure_plot_series' counters, kept as there: the frame itself reads every array in place, any stride), and
!< `plot_decimated`, `plot_kept`, `plot_cache_builds`, `plot_cache_hits` are the frame's (figure_plot_items).
!<
!< Every drawing procedure of this module refuses a call from a task (`FIG_ERR_STATE`): see processes.md; and a call
!< with no frame open, a usage error (`FIG_ERR_STATE`, `<procedure>: no frame open`). Every begin/end and push/pop
!< pair registers in the scope record of the frame, which checks each end before the frame sees it: a wrong end is
!< refused and reported by `app%next_frame` (`app%set_checks`; errors.md, "Pairing and frames").
!<
!< `ip_begin_plot` returns true when the plot is visible: then declare its axes and items and close it with
!< `ip_end_plot` (only in that case). Items (`ip_line`, `ip_scatter`, `ip_bars`, `ip_shaded`, `ip_error_bars`) take
!< `real(real32)` or `real(real64)` arrays of any stride (a matrix row `y(i,:)`, `y(::2)`, a component of an array of
!< derived types `runs%cl`), read in place during the call. Abscissae may be `integer(int32)` or `integer(int64)`
!< (iteration counters). The items' array dummies are ASYNCHRONOUS, as on the current path.
!<
!< Every item takes an optional `spec`, built by `ip_spec` from ImPlot's defaults (automatic colours, no markers):
!<
!<```fortran
!< call ip_line('residual', it, res, spec=ip_spec(line_color=[1.0_real64, 0.0_real64, 0.0_real64, 1.0_real64], &
!<                                               line_weight=2.0_real64, marker=ImPlotMarker_Circle))
!<```
use, intrinsic :: iso_c_binding, only : c_associated, c_char, c_double, c_f_pointer, c_float, c_funloc, c_int, c_loc, c_ptr
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use, intrinsic :: ieee_arithmetic, only : ieee_is_finite, ieee_is_nan
use figure_base, only : figure_check, figure_draw_refused, figure_fail, figure_refused, figure_scope_open, &
                        figure_scope_refused, figure_usage_error, format_refused, FORMAT_REAL, SCOPE_PLOT, SCOPE_SUBPLOTS, &
                        SCOPE_ALIGNED, SCOPE_LEGEND_POPUP
use figure_c_native, only : FIG_ERR_ARGUMENT, FIG_ERR_FAILED, FIG_ERR_STATE, FIG_OK, fig_colormap, fig_colormap_stops, &
                            fig_colormap_set_stops, fig_load_colormap
use figure_cimplot, only : ImPlot_GetColormapCount
use figure_core, only : core_end_popup
use figure_plot_series, only : plot_copies, plot_stride, series_gap
use figure_texture, only : texture_object
use figure_plot_colorbar, only : pf_colormap_legend, pf_colormap_legend_edit
use figure_plot_cmap_ids, only : cm_frame_id, cm_frame_id_set
use figure_plot_scope, only : plot_path_ready
use figure_plot_colormaps, only : cm_colormap, cm_gradient_get, cm_gradient_size, cm_gradient_slot, cm_list_count, &
                                  cm_list_name, cm_load, cm_push, cm_sample, cm_stops
use figure_gradient_edit, only : gz_gradient_edit
use figure_plot_frame, only : pf_aligned_open, pf_annotation, pf_begin_aligned, pf_begin_legend_popup, pf_begin_plot, &
                              pf_begin_subplots, pf_cancel_selection, pf_colormap_scale, pf_drop_target, pf_end_aligned, &
                              pf_end_legend_popup, pf_end_plot, pf_end_subplots, pf_hide_next_item, pf_last_item_color,   &
                              pf_legend_hovered, pf_link_axis, pf_open_ids, pf_pixels_to_plot, pf_plot_hovered,          &
                              pf_plot_limits, pf_plot_mouse, pf_plot_selection, pf_plot_size, pf_plot_state,             &
                              pf_plot_to_pixels, pf_recover_to, pf_set_axes, pf_setup_axes, pf_setup_axes_limits,         &
                              pf_setup_axis, pf_setup_axis_constraints, pf_setup_axis_limits, pf_setup_axis_ticks,        &
                              pf_setup_legend, pf_tag
use figure_plot_items, only : plot_item_spec, pf_spec, pf_bar_groups, pf_bars, pf_bubbles, pf_cache_next_item,       &
                              pf_digital, pf_error_bars, pf_field_image, pf_heatmap, pf_histogram, pf_histogram2d,     &
                              pf_image, pf_inf_lines, pf_line, pf_line_device, pf_pie_chart, pf_scatter, pf_set_decimation, &
                              pf_shaded, pf_stairs, pf_stems, pf_text, plot_cache_builds, plot_cache_hits,              &
                              plot_decimated, plot_kept, pf_last_decimated, PF_LINE_SEGMENTS
use figure_plot_style, only : ps_refresh
use figure_plot_tools, only : pf_drag_line_x, pf_drag_line_y, pf_drag_point, pf_drag_rect
use figure_cimplot_enums, only : ImAxis_X1, ImAxis_X2, ImAxis_X3, ImAxis_Y1, ImAxis_Y2, ImAxis_Y3,                     &
                                 ImPlotScale_Linear, ImPlotScale_Time, ImPlotScale_Log10, ImPlotScale_SymLog,         &
                                 ImPlotMarker_None, ImPlotMarker_Auto, ImPlotMarker_Circle, ImPlotMarker_Square,  &
                                 ImPlotMarker_Diamond, ImPlotMarker_Up, ImPlotMarker_Down, ImPlotMarker_Left,     &
                                 ImPlotMarker_Right, ImPlotMarker_Cross, ImPlotMarker_Plus, ImPlotMarker_Asterisk, &
                                 ImPlotMarker_Vertical, ImPlotMarker_Horizontal,                                   &
                                 ImPlotItemFlags_None, ImPlotItemFlags_NoLegend, ImPlotItemFlags_NoFit,           &
                                 ImPlotLineFlags_Segments, ImPlotLineFlags_Loop, ImPlotLineFlags_SkipNaN,         &
                                 ImPlotLineFlags_NoClip, ImPlotLineFlags_Shaded, ImPlotScatterFlags_NoClip,       &
                                 ImPlotBarsFlags_Horizontal,                                                       &
                                 ImPlotColormap_Deep, ImPlotColormap_Dark, ImPlotColormap_Pastel, ImPlotColormap_Paired, &
                                 ImPlotColormap_Viridis, ImPlotColormap_Plasma, ImPlotColormap_Hot, ImPlotColormap_Cool, &
                                 ImPlotColormap_Pink, ImPlotColormap_Jet, ImPlotColormap_Twilight, ImPlotColormap_RdBu,  &
                                 ImPlotColormap_BrBG, ImPlotColormap_PiYG, ImPlotColormap_Spectral, ImPlotColormap_Greys
use figure_cimplot_enums, only : ImPlotInfLinesFlags_Horizontal, ImPlotStairsFlags_PreStep,                           &
                                 ImPlotStairsFlags_Shaded, ImPlotStemsFlags_Horizontal, ImPlotHistogramFlags_Horizontal, &
                                 ImPlotHistogramFlags_Cumulative, ImPlotHistogramFlags_Density,                        &
                                 ImPlotHistogramFlags_NoOutliers, ImPlotBin_Sqrt, ImPlotBin_Sturges, ImPlotBin_Rice,    &
                                 ImPlotBin_Scott

implicit none
private
public :: ip_begin_plot, ip_end_plot, ip_setup_axes, ip_begin_subplots, ip_end_subplots
public :: ip_bars, ip_line, ip_scatter, ip_shaded, ip_bubbles, ip_pie_chart
public :: ip_colormap_scale, ip_heatmap, ip_image, ip_plot_limits, ip_plot_size, ip_setup_axes_limits
public :: ip_colormap, ip_colormap_names, ip_load_colormap, ip_colormap_stops, ig_gradient_edit
public :: ip_error_bars, ip_annotation, ip_drag_line_x, ip_drag_line_y, ip_drag_point
public :: ip_contour, ip_contour_lines, ip_contour_levels
public :: ip_colormap_legend, ip_colormap_legend_edit, ip_field_image
public :: ip_spec, plot_spec_object
public :: ip_setup_axis, ip_set_axes, ip_setup_axis_limits, ip_setup_axis_ticks, ip_setup_axis_constraints
public :: ip_setup_legend
public :: ip_plot_hovered, ip_plot_mouse, ip_plot_to_pixels, ip_pixels_to_plot, ip_plot_selection, ip_cancel_selection
public :: ip_drop_target
public :: ip_link_axis, ip_begin_aligned, ip_end_aligned, ip_legend_hovered, ip_begin_legend_popup
public :: ip_end_legend_popup, ip_hide_next_item, ip_digital, ip_bar_groups
public :: ip_set_decimation, ip_cache_next_item, ip_line_device
public :: ip_drag_rect, ip_tag, ip_inf_lines, ip_text, ip_stairs, ip_stems, ip_histogram, ip_histogram2d
! the frame's counters, as the current path's module has them (tests: `use figure_implot`)
public :: plot_decimated, plot_kept, plot_cache_builds, plot_cache_hits
! ImPlot's marker and item-flag constants (values generated from the cimplot metadata), for `ip_spec`
public :: ImPlotMarker_None, ImPlotMarker_Auto, ImPlotMarker_Circle, ImPlotMarker_Square, ImPlotMarker_Diamond
public :: ImPlotMarker_Up, ImPlotMarker_Down, ImPlotMarker_Left, ImPlotMarker_Right, ImPlotMarker_Cross
public :: ImPlotMarker_Plus, ImPlotMarker_Asterisk, ImPlotMarker_Vertical, ImPlotMarker_Horizontal
public :: ImPlotItemFlags_None, ImPlotItemFlags_NoLegend, ImPlotItemFlags_NoFit
public :: ImPlotLineFlags_Segments, ImPlotLineFlags_Loop, ImPlotLineFlags_SkipNaN, ImPlotLineFlags_NoClip
public :: ImPlotLineFlags_Shaded, ImPlotScatterFlags_NoClip, ImPlotBarsFlags_Horizontal
public :: ImPlotStairsFlags_PreStep, ImPlotStairsFlags_Shaded, ImPlotStemsFlags_Horizontal, ImPlotInfLinesFlags_Horizontal
public :: ImPlotHistogramFlags_Horizontal, ImPlotHistogramFlags_Cumulative, ImPlotHistogramFlags_Density
public :: ImPlotHistogramFlags_NoOutliers
! ImPlot's binning rules, for `ip_histogram` and `ip_histogram2d`
public :: ImPlotBin_Sqrt, ImPlotBin_Sturges, ImPlotBin_Rice, ImPlotBin_Scott
! ImPlot's colormaps, for `ip_heatmap` and `ip_colormap_scale` (by name, with the bundled ones: `ip_colormap`)
public :: ImPlotColormap_Deep, ImPlotColormap_Dark, ImPlotColormap_Pastel, ImPlotColormap_Paired, ImPlotColormap_Viridis
public :: ImPlotColormap_Plasma, ImPlotColormap_Hot, ImPlotColormap_Cool, ImPlotColormap_Pink, ImPlotColormap_Jet
public :: ImPlotColormap_Twilight, ImPlotColormap_RdBu, ImPlotColormap_BrBG, ImPlotColormap_PiYG, ImPlotColormap_Spectral
public :: ImPlotColormap_Greys

type :: plot_spec_object
   !< Style of a plot item: colours, line weight, markers, flags. Build it with `ip_spec`.
   !<
   !< The style is private so that a spec always starts from ImPlot's defaults: a zeroed one would draw nothing (line
   !< weight 0, marker size 0).
   type(plot_item_spec), private :: s !< The frame's item style (figure_plot_items).
endtype plot_spec_object

interface ip_line
   !< Line through the points (x(i), y(i)); or through y(i) at uniformly spaced x, from a vector or from a row of a
   !< matrix. Arrays of any stride are read in place (plots.md, "Data in place"); x may be `int32` or `int64`.
   module procedure ip_line_r32, ip_line_r64, ip_line_values_r32, ip_line_values_r64, ip_line_row_r32, ip_line_row_r64
   module procedure ip_line_i32_r32, ip_line_i64_r32, ip_line_i32_r64, ip_line_i64_r64
endinterface ip_line

interface ip_line_device
   !< A line through (x(i), y(i)) of arrays that live on a device (FUNDAL's `dev_alloc`, OpenACC device memory):
   !< decimated there, only the points kept copied to the host.
   module procedure ip_line_device_r32, ip_line_device_r64
endinterface ip_line_device

interface ip_scatter
   !< Markers at the points (x(i), y(i)).
   module procedure ip_scatter_r32, ip_scatter_r64
   module procedure ip_scatter_i32_r32, ip_scatter_i64_r32, ip_scatter_i32_r64, ip_scatter_i64_r64
endinterface ip_scatter

interface ip_digital
   !< A digital signal: y(i) at x(i), drawn as bars of the signal's height in a band at the bottom of the plot.
   module procedure ip_digital_r32, ip_digital_r64
endinterface ip_digital

interface ip_bar_groups
   !< Items in groups of bars: `values(g, i)`, item i in group g.
   module procedure ip_bar_groups_r32, ip_bar_groups_r64
endinterface ip_bar_groups

interface ip_bars
   !< Bars of height y(i) centred at x(i).
   module procedure ip_bars_r32, ip_bars_r64
   module procedure ip_bars_i32_r32, ip_bars_i64_r32, ip_bars_i32_r64, ip_bars_i64_r64
endinterface ip_bars

interface ip_field_image
   !< A field through a colormap, kept as a texture: `real32` or `real64`.
   module procedure ip_field_image_r32, ip_field_image_r64
endinterface ip_field_image

interface ip_heatmap
   !< A 2D field f(i, j) as coloured cells: i along x, j along y, j = 1 at the bottom.
   module procedure ip_heatmap_r32, ip_heatmap_r64
endinterface ip_heatmap

interface ip_bubbles
   !< Circles at the points (x(i), y(i)) of radius radii(i), in plot units along both axes (`PlotBubbles`).
   module procedure ip_bubbles_r32, ip_bubbles_r64
endinterface ip_bubbles

interface ip_pie_chart
   !< A pie chart: one slice per value, labelled in the legend, centred at (x, y) with a radius in plot units.
   module procedure ip_pie_chart_r32, ip_pie_chart_r64
endinterface ip_pie_chart

interface ip_error_bars
   !< Error bars at the points (x(i), y(i)): from y(i) - err(i) to y(i) + err(i), or to y(i) + err_high(i); along x
   !< with `horizontal=.true.`.
   module procedure ip_error_bars_r32, ip_error_bars_r64
   module procedure ip_error_bars_i32_r32, ip_error_bars_i64_r32, ip_error_bars_i32_r64, ip_error_bars_i64_r64
endinterface ip_error_bars

interface ip_contour
   !< Contour lines of a 2D field f(i, j), sampled at uniformly spaced points, i along x, j along y.
   module procedure ip_contour_r32, ip_contour_r64
endinterface ip_contour

interface ip_contour_lines
   !< The segments of the contour lines of a 2D field (marching squares), without drawing them.
   module procedure ip_contour_lines_r32, ip_contour_lines_r64
endinterface ip_contour_lines

interface ip_contour_levels
   !< Contour levels at round numbers ("nice" steps: 1, 2, 2.5 or 5 times a power of ten) inside a field's range.
   module procedure ip_contour_levels_r32, ip_contour_levels_r64
endinterface ip_contour_levels

interface ip_shaded
   !< Area between two curves y1(x) and y2(x), or between a curve y(x) and the line y = yref.
   module procedure ip_shaded_r32, ip_shaded_r64, ip_shaded_ref_r32, ip_shaded_ref_r64
   module procedure ip_shaded_i32_r32, ip_shaded_i64_r32, ip_shaded_i32_r64, ip_shaded_i64_r64
   module procedure ip_shaded_ref_i32_r32, ip_shaded_ref_i64_r32, ip_shaded_ref_i32_r64, ip_shaded_ref_i64_r64
endinterface ip_shaded

interface ip_stairs
   !< A staircase through the points (x(i), y(i)): y(i) held until x(i+1). Arrays read in place (plots.md, "Data in
   !< place"); x may be `int32` or `int64`.
   module procedure ip_stairs_r32, ip_stairs_r64
   module procedure ip_stairs_i32_r32, ip_stairs_i64_r32, ip_stairs_i32_r64, ip_stairs_i64_r64
endinterface ip_stairs

interface ip_stems
   !< Stems from y = ref to the points (x(i), y(i)), each with a marker.
   module procedure ip_stems_r32, ip_stems_r64
   module procedure ip_stems_i32_r32, ip_stems_i64_r32, ip_stems_i32_r64, ip_stems_i64_r64
endinterface ip_stems

interface ip_inf_lines
   !< Lines across the whole plot at given x (or y) values: `real32`, `real64`, `int32` or `int64` positions.
   module procedure ip_inf_lines_r32, ip_inf_lines_r64, ip_inf_lines_i32, ip_inf_lines_i64
endinterface ip_inf_lines

interface ip_histogram
   !< A histogram of values: bars as high as the values in each bin.
   module procedure ip_histogram_r32, ip_histogram_r64
endinterface ip_histogram

interface ip_histogram2d
   !< A 2-D histogram of points: cells coloured by how many points fall in each.
   module procedure ip_histogram2d_r32, ip_histogram2d_r64
endinterface ip_histogram2d

interface in_line
   !< Whether an array's elements are adjacent in memory.
   module procedure in_line_r32, in_line_r64
endinterface in_line

character(len=2), parameter :: AXIS_NAMES(0:5) = ['x1', 'x2', 'x3', 'y1', 'y2', 'y3'] !< ImAxis names, as the frame takes
                                                                                         !< them.

interface finite_value
   !< `ieee_is_finite` inline (see `finite_value_r32`).
   module procedure finite_value_r32, finite_value_r64
endinterface finite_value

contains
   elemental function finite_value_r32(x) result(yes)
   !< `ieee_is_finite` for the per-element loops (szaghi/figure#16 S2): a NaN fails `x == x` (a quiet comparison, no
   !< FPE under traps), then an infinity fails `abs(x) <= huge(x)` (compared only when not a NaN); inline on the three
   !< compilers, where `ieee_is_finite` is a library call on ifx (and nvfortran).
   real(real32), intent(in) :: x   !< Value.
   logical                  :: yes !< Finite.

   yes = x == x
   if (yes) yes = abs(x) <= huge(x)
   endfunction finite_value_r32

   elemental function finite_value_r64(x) result(yes)
   !< `finite_value_r32` in double precision.
   real(real64), intent(in) :: x   !< Value.
   logical                  :: yes !< Finite.

   yes = x == x
   if (yes) yes = abs(x) <= huge(x)
   endfunction finite_value_r64

   ! plots

   recursive function ip_begin_plot(title, width, height, equal) result(visible)
   !< Begin a plot; if true, declare its content and call `ip_end_plot`.
   character(len=*), intent(in)           :: title   !< Title (also the plot id; '##id' hides it).
   real(real64),     intent(in), optional :: width   !< Width [pixels] (default: full width).
   real(real64),     intent(in), optional :: height  !< Height [pixels] (default: ImPlot's).
   logical,          intent(in), optional :: equal   !< Same scale on both axes (one unit = as many pixels on x and y).
   logical                                :: visible !< Plot visible.

   visible = .false.
   if (refused('ip_begin_plot')) return ! a task does not draw
   visible = pf_begin_plot(title, width, height, equal) ! (a new subplot figure's first-draw fit: the frame's)
   call figure_scope_open(SCOPE_PLOT, 'ip_begin_plot', title, visible)
   endfunction ip_begin_plot

   recursive function ip_begin_subplots(title, rows, cols, width, height, link_x, link_y) result(visible)
   !< A grid of `rows` x `cols` plots in one figure; when true, declare the plots (`ip_begin_plot`/`ip_end_plot`, one
   !< per cell, row by row), then `ip_end_subplots`. `link_x`/`link_y`: the plots share the x (y) range, so zooming one
   !< zooms all. Size as `ip_begin_plot` (a negative `height` fills the space left). The first time a figure is drawn,
   !< its plots fit to their data; linked axes take the range of the last plot (the common abscissa, in practice).
   character(len=*), intent(in)           :: title   !< Title (also the id; '##id' hides it).
   integer(int32),   intent(in)           :: rows    !< Rows of plots.
   integer(int32),   intent(in)           :: cols    !< Columns of plots.
   real(real64),     intent(in), optional :: width   !< Width [pixels] (default: full width).
   real(real64),     intent(in), optional :: height  !< Height [pixels] (default: 300 per row).
   logical,          intent(in), optional :: link_x  !< Share the x range.
   logical,          intent(in), optional :: link_y  !< Share the y range.
   logical                                :: visible !< The figure is drawn.

   visible = .false.
   if (refused('ip_begin_subplots')) return ! a task does not draw
   visible = pf_begin_subplots(title, rows, cols, width, height, link_x, link_y)
   call figure_scope_open(SCOPE_SUBPLOTS, 'ip_begin_subplots', title, visible)
   endfunction ip_begin_subplots

   recursive subroutine ip_end_subplots()
   !< End the grid of plots (only after `ip_begin_subplots` returned true).

   if (figure_scope_refused(SCOPE_SUBPLOTS, 'ip_end_subplots')) return ! a task, no frame, or not the innermost scope
   call ps_refresh()
   call pf_end_subplots()
   endsubroutine ip_end_subplots

   recursive subroutine ip_end_plot()
   !< End the plot (only after `ip_begin_plot` returned true).

   if (figure_scope_refused(SCOPE_PLOT, 'ip_end_plot')) return ! a task, no frame, or not the innermost scope
   call ps_refresh()
   call pf_end_plot() ! (no fit of an axis that has no data, as fig_plot_end: the frame's)
   endsubroutine ip_end_plot

   recursive subroutine ip_setup_axes(xlabel, ylabel, auto_fit, xlog, ylog, xformat, yformat, xscale, yscale, stat)
   !< Labels of the axes X1 and Y1 (call right after `ip_begin_plot`, before any item); with `auto_fit=.true.` both
   !< axes fit the data every frame (data that grows while the user watches), instead of once on first use.
   !< `xscale`/`yscale`: `'linear'` (default), `'log'` (base 10: values <= 0 are not shown), `'symlog'` (symmetric
   !< log: linear within [-1, 1], logarithmic beyond, both signs) or `'time'` (x only: UNIX seconds, labelled as dates
   !< and times). `xlog`/`ylog` (deprecated, kept from v0.3): `.true.` is `'log'`. `xformat`/`yformat`: a C printf
   !< format of the tick labels (`'%.6f'`, `'%.2e'`, `'%g s'`), checked: one conversion `f`, `e`, `g` or `a`, with
   !< optional flags, width and precision, and any `%%`. Statuses: `FIG_ERR_ARGUMENT` for any other format, an unknown
   !< scale, `'time'` on y, or `xlog` and `xscale` that disagree (nothing is set up); `FIG_ERR_STATE` outside a plot,
   !< after its setup is over (an item, `ip_set_axes`, `ip_plot_limits`), or from a task; `stat` absent: `error stop`
   !< with the message (a usage error: as `app%set_checks` says).
   character(len=*), intent(in)            :: xlabel   !< X label.
   character(len=*), intent(in)            :: ylabel   !< Y label.
   logical,          intent(in),  optional :: auto_fit !< Fit the axes to the data every frame (default: first use only).
   logical,          intent(in),  optional :: xlog     !< Logarithmic x axis (deprecated: `xscale='log'`).
   logical,          intent(in),  optional :: ylog     !< Logarithmic y axis (deprecated: `yscale='log'`).
   character(len=*), intent(in),  optional :: xformat  !< printf format of the x tick labels (one real).
   character(len=*), intent(in),  optional :: yformat  !< printf format of the y tick labels (one real).
   character(len=*), intent(in),  optional :: xscale   !< Scale of x: 'linear', 'log', 'symlog', 'time'.
   character(len=*), intent(in),  optional :: yscale   !< Scale of y: 'linear', 'log', 'symlog'.
   integer(int32),   intent(out), optional :: stat     !< Status.
   integer(c_int)                          :: sx       !< ImPlotScale of x (-1: unknown).
   integer(c_int)                          :: sy       !< ImPlotScale of y (-1: unknown).

   if (refused('ip_setup_axes', stat)) return ! a task does not draw
   if (present(xformat)) then
      if (format_refused('ip_setup_axes', 'xformat', xformat, FORMAT_REAL, stat)) return
   endif
   if (present(yformat)) then
      if (format_refused('ip_setup_axes', 'yformat', yformat, FORMAT_REAL, stat)) return
   endif
   if (.not. scale_given_ok('ip_setup_axes', 'x', xlog, xscale, sx, stat)) return
   if (.not. scale_given_ok('ip_setup_axes', 'y', ylog, yscale, sy, stat)) return
   if (sy == ImPlotScale_Time) then
      call figure_fail(FIG_ERR_ARGUMENT, "ip_setup_axes: yscale 'time' is refused: ImPlot labels time on x axes only", &
                       stat)
      return
   endif
   if (setup_refused('ip_setup_axes', stat)) return
   call pf_setup_axes(xlabel, ylabel, auto_fit, scale_name(sx), scale_name(sy), xformat, yformat) ! ('linear': as it is)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_setup_axes

   recursive subroutine ip_setup_axes_limits(xmin, xmax, ymin, ymax, always, stat)
   !< Initial ranges of the axes X1 and Y1 (call right after `ip_begin_plot`): applied on first use only, so the user
   !< can pan and zoom afterwards, or every frame with `always=.true.`. Statuses: `FIG_ERR_STATE` outside a plot, after
   !< its setup is over, or from a task.
   real(real64),   intent(in)            :: xmin   !< Left end of the x axis.
   real(real64),   intent(in)            :: xmax   !< Right end of the x axis.
   real(real64),   intent(in)            :: ymin   !< Bottom end of the y axis.
   real(real64),   intent(in)            :: ymax   !< Top end of the y axis.
   logical,        intent(in), optional  :: always !< Enforce every frame (default: first use only).
   integer(int32), intent(out), optional :: stat   !< Status.

   if (refused('ip_setup_axes_limits', stat)) return ! a task does not draw
   if (setup_refused('ip_setup_axes_limits', stat)) return
   call pf_setup_axes_limits(xmin, xmax, ymin, ymax, always)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_setup_axes_limits

   recursive subroutine ip_setup_axis(axis, label, scale, auto_fit, format, opposite, invert, lock, no_grid, stat)
   !< Set up one axis of the plot being declared (`SetupAxis`): `axis` is `'x1'`, `'x2'`, `'x3'`, `'y1'`, `'y2'` or
   !< `'y3'`. X1 and Y1 always exist; X2, X3, Y2 and Y3 exist on the frames this is called for them. Call it right
   !< after `ip_begin_plot`, before any item, every frame. `scale`: `'linear'` (default), `'log'`, `'symlog'`,
   !< `'time'` (x axes only). The secondary axes (2 and 3) are drawn on the opposite side (top, right) without grid
   !< lines unless `opposite`/`no_grid` say otherwise. `lock`: the user cannot pan or zoom it. Statuses:
   !< `FIG_ERR_ARGUMENT` for an unknown axis or scale, `'time'` on a y axis, a bad format (nothing set up);
   !< `FIG_ERR_STATE` outside a plot, after its setup is over, or from a task.
   character(len=*), intent(in)            :: axis     !< 'x1', 'x2', 'x3', 'y1', 'y2', 'y3'.
   character(len=*), intent(in),  optional :: label    !< Label (default: none).
   character(len=*), intent(in),  optional :: scale    !< 'linear' (default), 'log', 'symlog', 'time'.
   logical,          intent(in),  optional :: auto_fit !< Fit the data every frame (default: first use only).
   character(len=*), intent(in),  optional :: format   !< printf format of the tick labels (one real).
   logical,          intent(in),  optional :: opposite !< Ticks and label on the opposite side (default: axes 2, 3).
   logical,          intent(in),  optional :: invert   !< Values grow leftwards (x) or downwards (y).
   logical,          intent(in),  optional :: lock     !< No pan or zoom by the user.
   logical,          intent(in),  optional :: no_grid  !< No grid lines (default: axes 2, 3).
   integer(int32),   intent(out), optional :: stat     !< Status.
   integer(c_int)                          :: code     !< ImAxis.
   integer(c_int)                          :: sc       !< ImPlotScale.

   if (refused('ip_setup_axis', stat)) return ! a task does not draw
   code = axis_index(axis)
   if (code < 0_c_int) then
      call figure_fail(FIG_ERR_ARGUMENT, "ip_setup_axis: unknown axis '"//axis//"' ('x1', 'x2', 'x3', 'y1', 'y2' "// &
                       "or 'y3')", stat)
      return
   endif
   if (present(format)) then
      if (format_refused('ip_setup_axis', 'format', format, FORMAT_REAL, stat)) return
   endif
   if (.not. scale_given_ok('ip_setup_axis', '', scale=scale, code=sc, stat=stat)) return
   if (sc == ImPlotScale_Time .and. code >= ImAxis_Y1) then
      call figure_fail(FIG_ERR_ARGUMENT, "ip_setup_axis: scale 'time' on axis '"//axis//"' is refused: ImPlot "// &
                       'labels time on x axes only', stat)
      return
   endif
   if (setup_refused('ip_setup_axis', stat)) return
   call pf_setup_axis(AXIS_NAMES(code), label, scale_name(sc), auto_fit, format, opposite, invert, lock, no_grid)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_setup_axis

   recursive subroutine ip_set_axes(x, y, stat)
   !< The axes the next items of the plot being declared use (`SetAxes`), until the next call or the plot's end (each
   !< plot starts on X1 and Y1): `x` one of `'x1'`, `'x2'`, `'x3'`, `y` one of `'y1'`, `'y2'`, `'y3'`, each set up
   !< (`ip_setup_axis`) on this frame. It ends the setup: call every `ip_setup_*` first. Statuses: `FIG_ERR_ARGUMENT`
   !< for a name that is not an axis of its direction; `FIG_ERR_STATE` outside a plot, for an axis not set up, from a
   !< task.
   character(len=*), intent(in)            :: x    !< 'x1', 'x2' or 'x3'.
   character(len=*), intent(in)            :: y    !< 'y1', 'y2' or 'y3'.
   integer(int32),   intent(out), optional :: stat !< Status.
   integer(c_int)                          :: cx   !< ImAxis of x.
   integer(c_int)                          :: cy   !< ImAxis of y.

   if (refused('ip_set_axes', stat)) return ! a task does not draw
   if (.not. pair_ok('ip_set_axes', 'x', x, 'y', y, cx, cy, stat)) return
   if (axis_refused('ip_set_axes', x, cx, .false., stat)) return
   if (axis_refused('ip_set_axes', y, cy, .false., stat)) return
   call pf_set_axes(AXIS_NAMES(cx), AXIS_NAMES(cy))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_set_axes

   recursive subroutine ip_setup_axis_limits(axis, vmin, vmax, always, stat)
   !< Initial range of one axis (`SetupAxisLimits`), applied on first use only (the user pans and zooms afterwards),
   !< or every frame with `always=.true.`. After `ip_setup_axis` for that axis, before any item. Statuses:
   !< `FIG_ERR_ARGUMENT` for an unknown axis, a NaN end, `vmin >= vmax`; `FIG_ERR_STATE` outside a plot, after its
   !< setup is over, for an axis not set up, from a task.
   character(len=*), intent(in)            :: axis   !< 'x1', 'x2', 'x3', 'y1', 'y2', 'y3'.
   real(real64),     intent(in)            :: vmin   !< Lower end [axis units].
   real(real64),     intent(in)            :: vmax   !< Upper end [axis units].
   logical,          intent(in),  optional :: always !< Enforce every frame (default: first use only).
   integer(int32),   intent(out), optional :: stat   !< Status.
   integer(c_int)                          :: code   !< ImAxis.

   if (refused('ip_setup_axis_limits', stat)) return ! a task does not draw
   if (.not. range_ok('ip_setup_axis_limits', 'vmin', vmin, 'vmax', vmax, stat)) return
   if (axis_refused('ip_setup_axis_limits', axis, code, .true., stat)) return
   call pf_setup_axis_limits(AXIS_NAMES(code), vmin, vmax, always)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_setup_axis_limits

   recursive subroutine ip_setup_axis_ticks(axis, values, labels, stat)
   !< Ticks of one axis at the given values instead of the automatic ones (`SetupAxisTicks`), labelled `labels` (as
   !< given, trailing blanks dropped) or, without them, by the axis's format. After `ip_setup_axis` (and its `format`)
   !< for that axis, before any item. Statuses: `FIG_ERR_ARGUMENT` for an unknown axis, a NaN or infinite value,
   !< labels not one per value, more values than a C `int` counts; `FIG_ERR_STATE` outside a plot, after its setup is
   !< over, for an axis not set up, from a task.
   character(len=*), intent(in)            :: axis      !< 'x1', 'x2', 'x3', 'y1', 'y2', 'y3'.
   real(real64),     intent(in)            :: values(:) !< Positions [axis units].
   character(len=*), intent(in),  optional :: labels(:) !< One label per value.
   integer(int32),   intent(out), optional :: stat      !< Status.
   integer(c_int)                          :: code      !< ImAxis.
   integer(int64)                          :: n         !< Values.

   if (refused('ip_setup_axis_ticks', stat)) return ! a task does not draw
   n = size(values, kind=int64)
   if (n > int(huge(1_c_int), int64)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_setup_axis_ticks: more values than a C int counts', stat)
      return
   endif
   if (.not. all(ieee_is_finite(values))) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_setup_axis_ticks: values must be finite', stat)
      return
   endif
   if (present(labels)) then
      if (size(labels, kind=int64) /= n) then
         call figure_fail(FIG_ERR_ARGUMENT, 'ip_setup_axis_ticks: labels must be one per value', stat)
         return
      endif
   endif
   if (axis_refused('ip_setup_axis_ticks', axis, code, .true., stat)) return
   call pf_setup_axis_ticks(AXIS_NAMES(code), values, labels) ! (labels without their trailing blanks)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_setup_axis_ticks

   recursive subroutine ip_setup_axis_constraints(axis, vmin, vmax, zoom_min, zoom_max, stat)
   !< Bounds the user cannot pan or zoom one axis past (`SetupAxisLimitsConstraints`, `SetupAxisZoomConstraints`):
   !< the range stays within [`vmin`, `vmax`], its width within [`zoom_min`, `zoom_max`]; an end not given keeps its
   !< bound (none, or the scale's: a log axis stays above 0). After `ip_setup_axis` (and its `scale`) for that axis,
   !< before any item, every frame. Statuses: `FIG_ERR_ARGUMENT` for an unknown axis, a NaN, `vmin >= vmax`,
   !< `zoom_min > zoom_max`, a negative zoom width, `vmin <= 0` on a log axis; `FIG_ERR_STATE` outside a plot, after
   !< its setup is over, for an axis not set up, from a task.
   character(len=*), intent(in)            :: axis     !< 'x1', 'x2', 'x3', 'y1', 'y2', 'y3'.
   real(real64),     intent(in),  optional :: vmin     !< Lowest value shown [axis units].
   real(real64),     intent(in),  optional :: vmax     !< Highest value shown [axis units].
   real(real64),     intent(in),  optional :: zoom_min !< Narrowest range [axis units].
   real(real64),     intent(in),  optional :: zoom_max !< Widest range [axis units].
   integer(int32),   intent(out), optional :: stat     !< Status.
   integer(c_int)                          :: code     !< ImAxis.
   integer(c_int)                          :: given    !< Ends given (bits).
   real(c_double)                          :: v(4)     !< Their values.
   integer(int32)                          :: on(6)    !< Axes set up.
   integer(int32)                          :: sc(6)    !< Their scales.
   integer(int32)                          :: state    !< Plot state.

   if (refused('ip_setup_axis_constraints', stat)) return ! a task does not draw
   given = 0_c_int
   v = 0.0_c_double
   if (.not. bound_ok('vmin', vmin, 1_c_int, 1_int32)) return
   if (.not. bound_ok('vmax', vmax, 2_c_int, 2_int32)) return
   if (.not. bound_ok('zoom_min', zoom_min, 4_c_int, 3_int32)) return
   if (.not. bound_ok('zoom_max', zoom_max, 8_c_int, 4_int32)) return
   if (iand(given, 3_c_int) == 3_c_int .and. .not. v(1) < v(2)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_setup_axis_constraints: vmin must be below vmax', stat)
      return
   endif
   if ((iand(given, 4_c_int) /= 0_c_int .and. v(3) < 0.0_c_double) .or. &
       (iand(given, 8_c_int) /= 0_c_int .and. v(4) < 0.0_c_double)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_setup_axis_constraints: a zoom width must not be negative', stat)
      return
   endif
   if (iand(given, 12_c_int) == 12_c_int .and. v(3) > v(4)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_setup_axis_constraints: zoom_min must not be above zoom_max', stat)
      return
   endif
   if (axis_refused('ip_setup_axis_constraints', axis, code, .true., stat)) return
   state = pf_plot_state(on, sc)
   if (sc(code + 1) == ImPlotScale_Log10 .and. iand(given, 1_c_int) /= 0_c_int .and. v(1) <= 0.0_c_double) then
      call figure_fail(FIG_ERR_ARGUMENT, "ip_setup_axis_constraints: vmin must be above 0 on the log axis '"// &
                       axis//"'", stat)
      return
   endif
   call constraints(AXIS_NAMES(code), iand(given, 1_c_int) /= 0_c_int, iand(given, 2_c_int) /= 0_c_int, &
                    iand(given, 4_c_int) /= 0_c_int, iand(given, 8_c_int) /= 0_c_int, v)
   call figure_check(FIG_OK, stat)

   contains
      function bound_ok(name, b, bit, slot) result(ok)
      !< Take an optional bound: false (refused, reported) for a NaN.
      character(len=*),       intent(in) :: name !< Its argument name.
      real(real64), optional, intent(in) :: b    !< The bound.
      integer(c_int),         intent(in) :: bit  !< Its bit in `given`.
      integer(int32),         intent(in) :: slot !< Its place in `v`.
      logical                            :: ok   !< Not refused.

      ok = .true.
      if (.not. present(b)) return
      if (ieee_is_nan(b)) then
         call figure_fail(FIG_ERR_ARGUMENT, 'ip_setup_axis_constraints: '//name//' is NaN', stat)
         ok = .false.
         return
      endif
      given = ior(given, bit)
      v(slot) = real(b, c_double)
      endfunction bound_ok
   endsubroutine ip_setup_axis_constraints

   subroutine constraints(axis, h1, h2, h3, h4, v)
   !< `pf_setup_axis_constraints` with the bounds given (`h1`..`h4`: vmin, vmax, zoom_min, zoom_max, their values in v).
   character(len=*), intent(in) :: axis           !< Axis.
   logical,          intent(in) :: h1, h2, h3, h4 !< Given.
   real(c_double),   intent(in) :: v(4)           !< Values.

   call bounds(merge(1, 0, h1) + 2 * merge(1, 0, h2) + 4 * merge(1, 0, h3) + 8 * merge(1, 0, h4))
   contains
      subroutine bounds(mask)
      !< The call, each bound present when its bit is set.
      integer, intent(in) :: mask !< Bits.

      select case (mask)
      case (0)
         call pf_setup_axis_constraints(axis)
      case (1)
         call pf_setup_axis_constraints(axis, vmin=v(1))
      case (2)
         call pf_setup_axis_constraints(axis, vmax=v(2))
      case (3)
         call pf_setup_axis_constraints(axis, vmin=v(1), vmax=v(2))
      case (4)
         call pf_setup_axis_constraints(axis, zoom_min=v(3))
      case (5)
         call pf_setup_axis_constraints(axis, vmin=v(1), zoom_min=v(3))
      case (6)
         call pf_setup_axis_constraints(axis, vmax=v(2), zoom_min=v(3))
      case (7)
         call pf_setup_axis_constraints(axis, vmin=v(1), vmax=v(2), zoom_min=v(3))
      case (8)
         call pf_setup_axis_constraints(axis, zoom_max=v(4))
      case (9)
         call pf_setup_axis_constraints(axis, vmin=v(1), zoom_max=v(4))
      case (10)
         call pf_setup_axis_constraints(axis, vmax=v(2), zoom_max=v(4))
      case (11)
         call pf_setup_axis_constraints(axis, vmin=v(1), vmax=v(2), zoom_max=v(4))
      case (12)
         call pf_setup_axis_constraints(axis, zoom_min=v(3), zoom_max=v(4))
      case (13)
         call pf_setup_axis_constraints(axis, vmin=v(1), zoom_min=v(3), zoom_max=v(4))
      case (14)
         call pf_setup_axis_constraints(axis, vmax=v(2), zoom_min=v(3), zoom_max=v(4))
      case default
         call pf_setup_axis_constraints(axis, vmin=v(1), vmax=v(2), zoom_min=v(3), zoom_max=v(4))
      endselect
      endsubroutine bounds
   endsubroutine constraints

   recursive subroutine ip_setup_legend(location, outside, horizontal, stat)
   !< Where the plot's legend goes (`SetupLegend`): `location` a compass point, `'n'`, `'ne'`, `'e'`, `'se'`, `'s'`,
   !< `'sw'`, `'w'`, `'nw'` (default, ImPlot's) or `'c'` (centre); `outside=.true.` puts it outside the plot area, on
   !< that side, and the plot area shrinks to make room; `horizontal=.true.` lays the entries out in a row. Right
   !< after `ip_begin_plot`, before any item. Statuses: `FIG_ERR_ARGUMENT` for an unknown location; `FIG_ERR_STATE`
   !< outside a plot, after its setup is over, from a task.
   character(len=*), intent(in),  optional :: location   !< Compass point: 'n', 'ne', 'e', 'se', 's', 'sw', 'w', 'nw',
                                                         !< 'c' (default 'nw').
   logical,          intent(in),  optional :: outside    !< Outside the plot area (default: inside).
   logical,          intent(in),  optional :: horizontal !< Entries in a row (default: a column).
   integer(int32),   intent(out), optional :: stat       !< Status.

   if (refused('ip_setup_legend', stat)) return ! a task does not draw
   if (present(location)) then
      select case (trim(location))
      case ('n', 'ne', 'e', 'se', 's', 'sw', 'w', 'nw', 'c')
      case default
         call figure_fail(FIG_ERR_ARGUMENT, "ip_setup_legend: unknown location '"//location//"' ('n', 'ne', 'e', "// &
                          "'se', 's', 'sw', 'w', 'nw' or 'c')", stat)
         return
      endselect
   endif
   if (setup_refused('ip_setup_legend', stat)) return
   if (present(location)) then
      call pf_setup_legend(trim(location), outside, horizontal)
   else
      call pf_setup_legend(outside=outside, horizontal=horizontal)
   endif
   call figure_check(FIG_OK, stat)
   endsubroutine ip_setup_legend

   recursive subroutine ip_plot_limits(xmin, xmax, ymin, ymax, xaxis, yaxis, stat)
   !< Axis ranges of the current plot, as the user has panned and zoomed them (between `ip_begin_plot` and
   !< `ip_end_plot`; ends the setup phase: call `ip_setup_*` before): of the axes the items use now (X1 and Y1, or
   !< those of the last `ip_set_axes`), or of `xaxis` (`'x1'`, `'x2'`, `'x3'`) and `yaxis` (`'y1'`, `'y2'`, `'y3'`).
   !< Statuses: `FIG_ERR_ARGUMENT` for a name that is not an axis of its direction; `FIG_ERR_STATE` outside a plot,
   !< for an axis not set up, from a task (the limits are then 0).
   real(real64),     intent(out)           :: xmin   !< Left end of the x axis.
   real(real64),     intent(out)           :: xmax   !< Right end of the x axis.
   real(real64),     intent(out)           :: ymin   !< Bottom end of the y axis.
   real(real64),     intent(out)           :: ymax   !< Top end of the y axis.
   character(len=*), intent(in),  optional :: xaxis  !< 'x1', 'x2' or 'x3' (default: the current one).
   character(len=*), intent(in),  optional :: yaxis  !< 'y1', 'y2' or 'y3' (default: the current one).
   integer(int32),   intent(out), optional :: stat   !< Status.
   integer(c_int)                          :: cx     !< ImAxis of x (-1: the current one).
   integer(c_int)                          :: cy     !< ImAxis of y (-1: the current one).

   xmin = 0.0_real64
   xmax = 0.0_real64
   ymin = 0.0_real64
   ymax = 0.0_real64
   if (refused('ip_plot_limits', stat)) return ! a task does not draw
   if (axes_refused('ip_plot_limits', xaxis, yaxis, cx, cy, stat)) return
   if (cx >= 0_c_int .and. cy >= 0_c_int) then
      call pf_plot_limits(xmin, xmax, ymin, ymax, AXIS_NAMES(cx), AXIS_NAMES(cy))
   elseif (cx >= 0_c_int) then
      call pf_plot_limits(xmin, xmax, ymin, ymax, xaxis=AXIS_NAMES(cx))
   elseif (cy >= 0_c_int) then
      call pf_plot_limits(xmin, xmax, ymin, ymax, yaxis=AXIS_NAMES(cy))
   else
      call pf_plot_limits(xmin, xmax, ymin, ymax)
   endif
   call figure_check(FIG_OK, stat)
   endsubroutine ip_plot_limits

   recursive subroutine ip_plot_size(width, height)
   !< Size of the current plot's data area [pixels] (between `ip_begin_plot` and `ip_end_plot`).
   real(real64), intent(out) :: width  !< Width [pixels].
   real(real64), intent(out) :: height !< Height [pixels].
   integer(int32)            :: on(6)  !< Axes set up.
   integer(int32)            :: sc(6)  !< Their scales.

   width = 0.0_real64
   height = 0.0_real64
   if (refused('ip_plot_size')) return ! a task does not draw
   if (pf_plot_state(on, sc) == 0_int32) return ! (ImPlot's GetPlotSize outside a plot asserts: here 0)
   call pf_plot_size(width, height)
   endsubroutine ip_plot_size

   ! item style

   function ip_spec(line_color, line_weight, fill_color, fill_alpha, marker, marker_size, marker_line_color, &
                    marker_fill_color, size, flags, stat) result(spec)
   !< Item style: ImPlot's defaults, with the given properties overridden. Colours are RGBA in [0, 1]; an absent
   !< colour stays automatic (from the colormap).
   real(real64),   intent(in), optional  :: line_color(:)        !< Line colour, RGBA.
   real(real64),   intent(in), optional  :: line_weight          !< Line weight [pixels] (lines, bar edges, markers).
   real(real64),   intent(in), optional  :: fill_color(:)        !< Fill colour, RGBA (bars, shaded areas).
   real(real64),   intent(in), optional  :: fill_alpha           !< Alpha multiplier of the fill colours.
   integer(int32), intent(in), optional  :: marker               !< Marker shape (`ImPlotMarker_*`).
   real(real64),   intent(in), optional  :: marker_size          !< Marker radius [pixels].
   real(real64),   intent(in), optional  :: marker_line_color(:) !< Marker outline colour, RGBA.
   real(real64),   intent(in), optional  :: marker_fill_color(:) !< Marker fill colour, RGBA.
   real(real64),   intent(in), optional  :: size                 !< Error-bar whisker and digital-bar size [pixels].
   integer(int32), intent(in), optional  :: flags                !< Item flags (`ImPlotItemFlags_*`, the item's own).
   integer(int32), intent(out), optional :: stat                 !< Status: `FIG_ERR_ARGUMENT` for a colour of size /= 4.
   type(plot_spec_object)                :: spec                 !< Item style.

   if (.not. (rgba_ok(line_color) .and. rgba_ok(fill_color) .and. rgba_ok(marker_line_color) .and. &
              rgba_ok(marker_fill_color))) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_spec: a colour needs 4 components (RGBA)', stat)
      return
   endif
   spec%s = pf_spec(line_color, line_weight, fill_color, fill_alpha, marker, marker_size, marker_line_color, &
                    marker_fill_color, size, flags)
   call figure_check(FIG_OK, stat)
   endfunction ip_spec

   recursive subroutine ip_line_r32(label, x, y, spec, stat)
   !< Line through the points (x(i), y(i)), single precision; read in place with any stride (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   real(real32),           intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),           intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_line', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_line', stat)) return
   call acct_lead_r32(s, y)
   call acct_put_r32(s, x)
   if (outside_plot('ip_line', stat)) return
   pf_last_decimated = .false.
   call pf_line(label, x, y, spec=item_spec(spec))
   call acct_item(s, 4_int64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_line_r32

   recursive subroutine ip_line_i32_r32(label, x, y, spec, stat)
   !< Line through the points (x(i), y(i)), single precision, abscissae `integer(int32)`: converted into one temporary,
   !< the ordinates read in place (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   integer(int32),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),           intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_line', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_line', stat)) return
   call acct_lead_r32(s, y)
   call acct_put_int(size(x, kind=int64))
   if (outside_plot('ip_line', stat)) return
   pf_last_decimated = .false.
   call pf_line(label, x, y, spec=item_spec(spec))
   call acct_item(s, 4_int64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_line_i32_r32

   recursive subroutine ip_line_i64_r32(label, x, y, spec, stat)
   !< Line through the points (x(i), y(i)), single precision, abscissae `integer(int64)`: converted into one temporary,
   !< the ordinates read in place (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   integer(int64),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),           intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_line', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_line', stat)) return
   call acct_lead_r32(s, y)
   call acct_put_int(size(x, kind=int64))
   if (outside_plot('ip_line', stat)) return
   pf_last_decimated = .false.
   call pf_line(label, x, y, spec=item_spec(spec))
   call acct_item(s, 4_int64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_line_i64_r32

   recursive subroutine ip_scatter_r32(label, x, y, spec, stat)
   !< Markers at the points (x(i), y(i)), single precision; read in place with any stride (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   real(real32),           intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),           intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_scatter', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_scatter', stat)) return
   call acct_lead_r32(s, y)
   call acct_put_r32(s, x)
   if (outside_plot('ip_scatter', stat)) return
   call pf_scatter(label, x, y, spec=item_spec(spec))
   plot_stride = s
   call figure_check(FIG_OK, stat)
   endsubroutine ip_scatter_r32

   recursive subroutine ip_scatter_i32_r32(label, x, y, spec, stat)
   !< Markers at the points (x(i), y(i)), single precision, abscissae `integer(int32)`: converted into one temporary,
   !< the ordinates read in place (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   integer(int32),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),           intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_scatter', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_scatter', stat)) return
   call acct_lead_r32(s, y)
   call acct_put_int(size(x, kind=int64))
   if (outside_plot('ip_scatter', stat)) return
   call pf_scatter(label, x, y, spec=item_spec(spec))
   plot_stride = s
   call figure_check(FIG_OK, stat)
   endsubroutine ip_scatter_i32_r32

   recursive subroutine ip_scatter_i64_r32(label, x, y, spec, stat)
   !< Markers at the points (x(i), y(i)), single precision, abscissae `integer(int64)`: converted into one temporary,
   !< the ordinates read in place (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   integer(int64),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),           intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_scatter', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_scatter', stat)) return
   call acct_lead_r32(s, y)
   call acct_put_int(size(x, kind=int64))
   if (outside_plot('ip_scatter', stat)) return
   call pf_scatter(label, x, y, spec=item_spec(spec))
   plot_stride = s
   call figure_check(FIG_OK, stat)
   endsubroutine ip_scatter_i64_r32

   recursive subroutine ip_bars_r32(label, x, y, bar_size, spec, stat)
   !< Bars of height y(i) centred at x(i), `bar_size` wide (in x units), single precision; read in place with any stride
   !< (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label    !< Legend label.
   real(real32),           intent(in), target, asynchronous :: x(:)     !< Bar positions.
   real(real32),           intent(in), target, asynchronous :: y(:)     !< Bar heights.
   real(real64),           intent(in)                       :: bar_size !< Bar width [x units].
   type(plot_spec_object), intent(in), optional             :: spec     !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat     !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_bars', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_bars', stat)) return
   call acct_lead_r32(s, y)
   call acct_put_r32(s, x)
   if (outside_plot('ip_bars', stat)) return
   call pf_bars(label, x, y, bar_size, spec=item_spec(spec))
   plot_stride = s
   call figure_check(FIG_OK, stat)
   endsubroutine ip_bars_r32

   recursive subroutine ip_bars_i32_r32(label, x, y, bar_size, spec, stat)
   !< Bars of height y(i) centred at x(i), `bar_size` wide (in x units), single precision, abscissae `integer(int32)`:
   !< converted into one temporary, the ordinates read in place (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label    !< Legend label.
   integer(int32),         intent(in), target, asynchronous :: x(:)     !< Bar positions.
   real(real32),           intent(in), target, asynchronous :: y(:)     !< Bar heights.
   real(real64),           intent(in)                       :: bar_size !< Bar width [x units].
   type(plot_spec_object), intent(in), optional             :: spec     !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat     !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_bars', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_bars', stat)) return
   call acct_lead_r32(s, y)
   call acct_put_int(size(x, kind=int64))
   if (outside_plot('ip_bars', stat)) return
   call pf_bars(label, x, y, bar_size, spec=item_spec(spec))
   plot_stride = s
   call figure_check(FIG_OK, stat)
   endsubroutine ip_bars_i32_r32

   recursive subroutine ip_bars_i64_r32(label, x, y, bar_size, spec, stat)
   !< Bars of height y(i) centred at x(i), `bar_size` wide (in x units), single precision, abscissae `integer(int64)`:
   !< converted into one temporary, the ordinates read in place (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label    !< Legend label.
   integer(int64),         intent(in), target, asynchronous :: x(:)     !< Bar positions.
   real(real32),           intent(in), target, asynchronous :: y(:)     !< Bar heights.
   real(real64),           intent(in)                       :: bar_size !< Bar width [x units].
   type(plot_spec_object), intent(in), optional             :: spec     !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat     !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_bars', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_bars', stat)) return
   call acct_lead_r32(s, y)
   call acct_put_int(size(x, kind=int64))
   if (outside_plot('ip_bars', stat)) return
   call pf_bars(label, x, y, bar_size, spec=item_spec(spec))
   plot_stride = s
   call figure_check(FIG_OK, stat)
   endsubroutine ip_bars_i64_r32

   recursive subroutine ip_line_r64(label, x, y, spec, stat)
   !< Line through the points (x(i), y(i)), double precision; read in place with any stride (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   real(real64),           intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),           intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_line', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_line', stat)) return
   call acct_lead_r64(s, y)
   call acct_put_r64(s, x)
   if (outside_plot('ip_line', stat)) return
   pf_last_decimated = .false.
   call pf_line(label, x, y, spec=item_spec(spec))
   call acct_item(s, 8_int64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_line_r64

   recursive subroutine ip_line_i32_r64(label, x, y, spec, stat)
   !< Line through the points (x(i), y(i)), double precision, abscissae `integer(int32)`: converted into one temporary,
   !< the ordinates read in place (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   integer(int32),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),           intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_line', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_line', stat)) return
   call acct_lead_r64(s, y)
   call acct_put_int(size(x, kind=int64))
   if (outside_plot('ip_line', stat)) return
   pf_last_decimated = .false.
   call pf_line(label, x, y, spec=item_spec(spec))
   call acct_item(s, 8_int64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_line_i32_r64

   recursive subroutine ip_line_i64_r64(label, x, y, spec, stat)
   !< Line through the points (x(i), y(i)), double precision, abscissae `integer(int64)`: converted into one temporary,
   !< the ordinates read in place (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   integer(int64),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),           intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_line', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_line', stat)) return
   call acct_lead_r64(s, y)
   call acct_put_int(size(x, kind=int64))
   if (outside_plot('ip_line', stat)) return
   pf_last_decimated = .false.
   call pf_line(label, x, y, spec=item_spec(spec))
   call acct_item(s, 8_int64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_line_i64_r64

   recursive subroutine ip_scatter_r64(label, x, y, spec, stat)
   !< Markers at the points (x(i), y(i)), double precision; read in place with any stride (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   real(real64),           intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),           intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_scatter', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_scatter', stat)) return
   call acct_lead_r64(s, y)
   call acct_put_r64(s, x)
   if (outside_plot('ip_scatter', stat)) return
   call pf_scatter(label, x, y, spec=item_spec(spec))
   plot_stride = s
   call figure_check(FIG_OK, stat)
   endsubroutine ip_scatter_r64

   recursive subroutine ip_scatter_i32_r64(label, x, y, spec, stat)
   !< Markers at the points (x(i), y(i)), double precision, abscissae `integer(int32)`: converted into one temporary,
   !< the ordinates read in place (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   integer(int32),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),           intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_scatter', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_scatter', stat)) return
   call acct_lead_r64(s, y)
   call acct_put_int(size(x, kind=int64))
   if (outside_plot('ip_scatter', stat)) return
   call pf_scatter(label, x, y, spec=item_spec(spec))
   plot_stride = s
   call figure_check(FIG_OK, stat)
   endsubroutine ip_scatter_i32_r64

   recursive subroutine ip_scatter_i64_r64(label, x, y, spec, stat)
   !< Markers at the points (x(i), y(i)), double precision, abscissae `integer(int64)`: converted into one temporary,
   !< the ordinates read in place (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   integer(int64),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),           intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_scatter', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_scatter', stat)) return
   call acct_lead_r64(s, y)
   call acct_put_int(size(x, kind=int64))
   if (outside_plot('ip_scatter', stat)) return
   call pf_scatter(label, x, y, spec=item_spec(spec))
   plot_stride = s
   call figure_check(FIG_OK, stat)
   endsubroutine ip_scatter_i64_r64

   recursive subroutine ip_bars_r64(label, x, y, bar_size, spec, stat)
   !< Bars of height y(i) centred at x(i), `bar_size` wide (in x units), double precision; read in place with any stride
   !< (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label    !< Legend label.
   real(real64),           intent(in), target, asynchronous :: x(:)     !< Bar positions.
   real(real64),           intent(in), target, asynchronous :: y(:)     !< Bar heights.
   real(real64),           intent(in)                       :: bar_size !< Bar width [x units].
   type(plot_spec_object), intent(in), optional             :: spec     !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat     !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_bars', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_bars', stat)) return
   call acct_lead_r64(s, y)
   call acct_put_r64(s, x)
   if (outside_plot('ip_bars', stat)) return
   call pf_bars(label, x, y, bar_size, spec=item_spec(spec))
   plot_stride = s
   call figure_check(FIG_OK, stat)
   endsubroutine ip_bars_r64

   recursive subroutine ip_bars_i32_r64(label, x, y, bar_size, spec, stat)
   !< Bars of height y(i) centred at x(i), `bar_size` wide (in x units), double precision, abscissae `integer(int32)`:
   !< converted into one temporary, the ordinates read in place (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label    !< Legend label.
   integer(int32),         intent(in), target, asynchronous :: x(:)     !< Bar positions.
   real(real64),           intent(in), target, asynchronous :: y(:)     !< Bar heights.
   real(real64),           intent(in)                       :: bar_size !< Bar width [x units].
   type(plot_spec_object), intent(in), optional             :: spec     !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat     !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_bars', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_bars', stat)) return
   call acct_lead_r64(s, y)
   call acct_put_int(size(x, kind=int64))
   if (outside_plot('ip_bars', stat)) return
   call pf_bars(label, x, y, bar_size, spec=item_spec(spec))
   plot_stride = s
   call figure_check(FIG_OK, stat)
   endsubroutine ip_bars_i32_r64

   recursive subroutine ip_bars_i64_r64(label, x, y, bar_size, spec, stat)
   !< Bars of height y(i) centred at x(i), `bar_size` wide (in x units), double precision, abscissae `integer(int64)`:
   !< converted into one temporary, the ordinates read in place (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label    !< Legend label.
   integer(int64),         intent(in), target, asynchronous :: x(:)     !< Bar positions.
   real(real64),           intent(in), target, asynchronous :: y(:)     !< Bar heights.
   real(real64),           intent(in)                       :: bar_size !< Bar width [x units].
   type(plot_spec_object), intent(in), optional             :: spec     !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat     !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_bars', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_bars', stat)) return
   call acct_lead_r64(s, y)
   call acct_put_int(size(x, kind=int64))
   if (outside_plot('ip_bars', stat)) return
   call pf_bars(label, x, y, bar_size, spec=item_spec(spec))
   plot_stride = s
   call figure_check(FIG_OK, stat)
   endsubroutine ip_bars_i64_r64

   recursive subroutine ip_digital_r64(label, x, y, spec, stat)
   !< A digital signal (`PlotDigital`): y(i) at x(i), held to x(i+1), drawn in a band of its own at the bottom of the
   !< plot whatever the y axis (0 and 1 as low and high; larger values as taller steps), double precision; read in place with
   !< any stride (plots.md, "Data in place"). The y axis does not fit it; the x axis does. `spec`'s `size` is the
   !< band's height [pixels].
   character(len=*),       intent(in)                       :: label !< Legend label.
   real(real64),               intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),               intent(in), target, asynchronous :: y(:)  !< Values.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_digital', stat)) return ! a task does not draw
   if (plot_refused('ip_digital', .false., stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_digital', stat)) return
   call acct_lead_r64(s, y)
   call acct_put_r64(s, x)
   if (outside_plot('ip_digital', stat)) return
   call pf_digital(label, x, y, spec=item_spec(spec))
   plot_stride = s
   call figure_check(FIG_OK, stat)
   endsubroutine ip_digital_r64

   recursive subroutine ip_digital_r32(label, x, y, spec, stat)
   !< A digital signal (`PlotDigital`): y(i) at x(i), held to x(i+1), drawn in a band of its own at the bottom of the
   !< plot whatever the y axis (0 and 1 as low and high; larger values as taller steps), single precision; read in place with
   !< any stride (plots.md, "Data in place"). The y axis does not fit it; the x axis does. `spec`'s `size` is the
   !< band's height [pixels].
   character(len=*),       intent(in)                       :: label !< Legend label.
   real(real32),               intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),               intent(in), target, asynchronous :: y(:)  !< Values.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_digital', stat)) return ! a task does not draw
   if (plot_refused('ip_digital', .false., stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_digital', stat)) return
   call acct_lead_r32(s, y)
   call acct_put_r32(s, x)
   if (outside_plot('ip_digital', stat)) return
   call pf_digital(label, x, y, spec=item_spec(spec))
   plot_stride = s
   call figure_check(FIG_OK, stat)
   endsubroutine ip_digital_r32

   recursive subroutine ip_stairs_r32(label, x, y, spec, stat)
   !< A staircase through the points (x(i), y(i)) (`PlotStairs`): y(i) held from x(i) to x(i+1) (with
   !< `ImPlotStairsFlags_PreStep` in the spec, from x(i-1) to x(i)), single precision; read in place with any
   !< stride (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   real(real32),           intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),           intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_stairs', stat)) return ! a task does not draw
   if (plot_refused('ip_stairs', .false., stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_stairs', stat)) return
   call acct_lead_r32(s, y)
   call acct_put_r32(s, x)
   if (outside_plot('ip_stairs', stat)) return
   pf_last_decimated = .false.
   call pf_stairs(label, x, y, spec=item_spec(spec))
   call acct_item(s, 4_int64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_stairs_r32

   recursive subroutine ip_stairs_i32_r32(label, x, y, spec, stat)
   !< A staircase through the points (x(i), y(i)) (`PlotStairs`): y(i) held from x(i) to x(i+1) (with
   !< `ImPlotStairsFlags_PreStep` in the spec, from x(i-1) to x(i)), single precision, abscissae `integer(int32)`:
   !< converted into one temporary, the ordinates read in place (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   integer(int32),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),           intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_stairs', stat)) return ! a task does not draw
   if (plot_refused('ip_stairs', .false., stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_stairs', stat)) return
   call acct_lead_r32(s, y)
   call acct_put_int(size(x, kind=int64))
   if (outside_plot('ip_stairs', stat)) return
   pf_last_decimated = .false.
   call pf_stairs(label, x, y, spec=item_spec(spec))
   call acct_item(s, 4_int64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_stairs_i32_r32

   recursive subroutine ip_stairs_i64_r32(label, x, y, spec, stat)
   !< A staircase through the points (x(i), y(i)) (`PlotStairs`): y(i) held from x(i) to x(i+1) (with
   !< `ImPlotStairsFlags_PreStep` in the spec, from x(i-1) to x(i)), single precision, abscissae `integer(int64)`:
   !< converted into one temporary, the ordinates read in place (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   integer(int64),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),           intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_stairs', stat)) return ! a task does not draw
   if (plot_refused('ip_stairs', .false., stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_stairs', stat)) return
   call acct_lead_r32(s, y)
   call acct_put_int(size(x, kind=int64))
   if (outside_plot('ip_stairs', stat)) return
   pf_last_decimated = .false.
   call pf_stairs(label, x, y, spec=item_spec(spec))
   call acct_item(s, 4_int64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_stairs_i64_r32

   recursive subroutine ip_stairs_r64(label, x, y, spec, stat)
   !< A staircase through the points (x(i), y(i)) (`PlotStairs`): y(i) held from x(i) to x(i+1) (with
   !< `ImPlotStairsFlags_PreStep` in the spec, from x(i-1) to x(i)), double precision; read in place with any
   !< stride (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   real(real64),           intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),           intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_stairs', stat)) return ! a task does not draw
   if (plot_refused('ip_stairs', .false., stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_stairs', stat)) return
   call acct_lead_r64(s, y)
   call acct_put_r64(s, x)
   if (outside_plot('ip_stairs', stat)) return
   pf_last_decimated = .false.
   call pf_stairs(label, x, y, spec=item_spec(spec))
   call acct_item(s, 8_int64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_stairs_r64

   recursive subroutine ip_stairs_i32_r64(label, x, y, spec, stat)
   !< A staircase through the points (x(i), y(i)) (`PlotStairs`): y(i) held from x(i) to x(i+1) (with
   !< `ImPlotStairsFlags_PreStep` in the spec, from x(i-1) to x(i)), double precision, abscissae `integer(int32)`:
   !< converted into one temporary, the ordinates read in place (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   integer(int32),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),           intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_stairs', stat)) return ! a task does not draw
   if (plot_refused('ip_stairs', .false., stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_stairs', stat)) return
   call acct_lead_r64(s, y)
   call acct_put_int(size(x, kind=int64))
   if (outside_plot('ip_stairs', stat)) return
   pf_last_decimated = .false.
   call pf_stairs(label, x, y, spec=item_spec(spec))
   call acct_item(s, 8_int64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_stairs_i32_r64

   recursive subroutine ip_stairs_i64_r64(label, x, y, spec, stat)
   !< A staircase through the points (x(i), y(i)) (`PlotStairs`): y(i) held from x(i) to x(i+1) (with
   !< `ImPlotStairsFlags_PreStep` in the spec, from x(i-1) to x(i)), double precision, abscissae `integer(int64)`:
   !< converted into one temporary, the ordinates read in place (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   integer(int64),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),           intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_stairs', stat)) return ! a task does not draw
   if (plot_refused('ip_stairs', .false., stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_stairs', stat)) return
   call acct_lead_r64(s, y)
   call acct_put_int(size(x, kind=int64))
   if (outside_plot('ip_stairs', stat)) return
   pf_last_decimated = .false.
   call pf_stairs(label, x, y, spec=item_spec(spec))
   call acct_item(s, 8_int64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_stairs_i64_r64

   recursive subroutine ip_stems_r32(label, x, y, ref, spec, stat)
   !< A stem from y = ref to each point (x(i), y(i)), with a marker at its end (`PlotStems`), single precision;
   !< read in place with any stride (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   real(real32),           intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),           intent(in), target, asynchronous :: y(:)  !< Ordinates.
   real(real64),           intent(in), optional             :: ref   !< Base of the stems [y units] (default 0).
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_stems', stat)) return ! a task does not draw
   if (plot_refused('ip_stems', .false., stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_stems', stat)) return
   call acct_lead_r32(s, y)
   call acct_put_r32(s, x)
   if (outside_plot('ip_stems', stat)) return
   call pf_stems(label, x, y, ref, spec=item_spec(spec))
   plot_stride = s
   call figure_check(FIG_OK, stat)
   endsubroutine ip_stems_r32

   recursive subroutine ip_stems_i32_r32(label, x, y, ref, spec, stat)
   !< A stem from y = ref to each point (x(i), y(i)), with a marker at its end (`PlotStems`), single precision,
   !< abscissae `integer(int32)`: converted into one temporary, the ordinates read in place (plots.md, "Data in
   !< place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   integer(int32),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),           intent(in), target, asynchronous :: y(:)  !< Ordinates.
   real(real64),           intent(in), optional             :: ref   !< Base of the stems [y units] (default 0).
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_stems', stat)) return ! a task does not draw
   if (plot_refused('ip_stems', .false., stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_stems', stat)) return
   call acct_lead_r32(s, y)
   call acct_put_int(size(x, kind=int64))
   if (outside_plot('ip_stems', stat)) return
   call pf_stems(label, x, y, ref, spec=item_spec(spec))
   plot_stride = s
   call figure_check(FIG_OK, stat)
   endsubroutine ip_stems_i32_r32

   recursive subroutine ip_stems_i64_r32(label, x, y, ref, spec, stat)
   !< A stem from y = ref to each point (x(i), y(i)), with a marker at its end (`PlotStems`), single precision,
   !< abscissae `integer(int64)`: converted into one temporary, the ordinates read in place (plots.md, "Data in
   !< place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   integer(int64),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),           intent(in), target, asynchronous :: y(:)  !< Ordinates.
   real(real64),           intent(in), optional             :: ref   !< Base of the stems [y units] (default 0).
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_stems', stat)) return ! a task does not draw
   if (plot_refused('ip_stems', .false., stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_stems', stat)) return
   call acct_lead_r32(s, y)
   call acct_put_int(size(x, kind=int64))
   if (outside_plot('ip_stems', stat)) return
   call pf_stems(label, x, y, ref, spec=item_spec(spec))
   plot_stride = s
   call figure_check(FIG_OK, stat)
   endsubroutine ip_stems_i64_r32

   recursive subroutine ip_stems_r64(label, x, y, ref, spec, stat)
   !< A stem from y = ref to each point (x(i), y(i)), with a marker at its end (`PlotStems`), double precision;
   !< read in place with any stride (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   real(real64),           intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),           intent(in), target, asynchronous :: y(:)  !< Ordinates.
   real(real64),           intent(in), optional             :: ref   !< Base of the stems [y units] (default 0).
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_stems', stat)) return ! a task does not draw
   if (plot_refused('ip_stems', .false., stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_stems', stat)) return
   call acct_lead_r64(s, y)
   call acct_put_r64(s, x)
   if (outside_plot('ip_stems', stat)) return
   call pf_stems(label, x, y, ref, spec=item_spec(spec))
   plot_stride = s
   call figure_check(FIG_OK, stat)
   endsubroutine ip_stems_r64

   recursive subroutine ip_stems_i32_r64(label, x, y, ref, spec, stat)
   !< A stem from y = ref to each point (x(i), y(i)), with a marker at its end (`PlotStems`), double precision,
   !< abscissae `integer(int32)`: converted into one temporary, the ordinates read in place (plots.md, "Data in
   !< place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   integer(int32),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),           intent(in), target, asynchronous :: y(:)  !< Ordinates.
   real(real64),           intent(in), optional             :: ref   !< Base of the stems [y units] (default 0).
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_stems', stat)) return ! a task does not draw
   if (plot_refused('ip_stems', .false., stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_stems', stat)) return
   call acct_lead_r64(s, y)
   call acct_put_int(size(x, kind=int64))
   if (outside_plot('ip_stems', stat)) return
   call pf_stems(label, x, y, ref, spec=item_spec(spec))
   plot_stride = s
   call figure_check(FIG_OK, stat)
   endsubroutine ip_stems_i32_r64

   recursive subroutine ip_stems_i64_r64(label, x, y, ref, spec, stat)
   !< A stem from y = ref to each point (x(i), y(i)), with a marker at its end (`PlotStems`), double precision,
   !< abscissae `integer(int64)`: converted into one temporary, the ordinates read in place (plots.md, "Data in
   !< place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   integer(int64),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),           intent(in), target, asynchronous :: y(:)  !< Ordinates.
   real(real64),           intent(in), optional             :: ref   !< Base of the stems [y units] (default 0).
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_stems', stat)) return ! a task does not draw
   if (plot_refused('ip_stems', .false., stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_stems', stat)) return
   call acct_lead_r64(s, y)
   call acct_put_int(size(x, kind=int64))
   if (outside_plot('ip_stems', stat)) return
   call pf_stems(label, x, y, ref, spec=item_spec(spec))
   plot_stride = s
   call figure_check(FIG_OK, stat)
   endsubroutine ip_stems_i64_r64

   recursive subroutine ip_line_values_r32(label, y, xscale, xstart, spec, stat)
   !< Line through y(i) at x = xstart + (i - 1) xscale, single precision; read in place with any stride (plots.md,
   !< "Data in place").
   character(len=*),       intent(in)                       :: label  !< Legend label.
   real(real32),           intent(in), target, asynchronous :: y(:)   !< Ordinates.
   real(real64),           intent(in), optional             :: xscale !< Spacing of the abscissae (default 1).
   real(real64),           intent(in), optional             :: xstart !< First abscissa (default 0).
   type(plot_spec_object), intent(in), optional             :: spec   !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat   !< Status.
   integer(int64)                                           :: s      !< The stride ImPlot would read [bytes].

   if (refused('ip_line', stat)) return ! a task does not draw
   if (.not. series_ok(size(y, kind=int64), size(y, kind=int64), 'ip_line', stat)) return
   call acct_lead_r32(s, y)
   if (outside_plot('ip_line', stat)) return
   pf_last_decimated = .false.
   call pf_line(label, y, xscale, xstart, spec=item_spec(spec))
   call acct_item(s, 4_int64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_line_values_r32

   recursive subroutine ip_line_values_r64(label, y, xscale, xstart, spec, stat)
   !< Line through y(i) at x = xstart + (i - 1) xscale, double precision; read in place with any stride (plots.md,
   !< "Data in place").
   character(len=*),       intent(in)                       :: label  !< Legend label.
   real(real64),           intent(in), target, asynchronous :: y(:)   !< Ordinates.
   real(real64),           intent(in), optional             :: xscale !< Spacing of the abscissae (default 1).
   real(real64),           intent(in), optional             :: xstart !< First abscissa (default 0).
   type(plot_spec_object), intent(in), optional             :: spec   !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat   !< Status.
   integer(int64)                                           :: s      !< The stride ImPlot would read [bytes].

   if (refused('ip_line', stat)) return ! a task does not draw
   if (.not. series_ok(size(y, kind=int64), size(y, kind=int64), 'ip_line', stat)) return
   call acct_lead_r64(s, y)
   if (outside_plot('ip_line', stat)) return
   pf_last_decimated = .false.
   call pf_line(label, y, xscale, xstart, spec=item_spec(spec))
   call acct_item(s, 8_int64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_line_values_r64

   recursive subroutine ip_line_row_r32(label, y, row, xscale, xstart, spec, stat)
   !< Line through the row `row` of `y`, y(row, j) at x = xstart + (j - 1) xscale, read in place (no copy),
   !< single precision.
   character(len=*),       intent(in)                     :: label  !< Legend label.
   real(real32),           intent(in), contiguous, target :: y(:,:) !< Matrix; its row `row` is plotted.
   integer(int32),         intent(in)                     :: row    !< Row to plot, in 1..size(y, 1).
   real(real64),           intent(in), optional           :: xscale !< Spacing of the abscissae (default 1).
   real(real64),           intent(in), optional           :: xstart !< First abscissa (default 0).
   type(plot_spec_object), intent(in), optional           :: spec   !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat   !< Status.

   if (refused('ip_line', stat)) return ! a task does not draw
   if (.not. row_ok(size(y, 1, kind=int64), size(y, 2, kind=int64), storage_size(y, kind=int64), row, stat)) return
   if (outside_plot('ip_line', stat)) return
   pf_last_decimated = .false.
   call pf_line(label, y, row, xscale, xstart, spec=item_spec(spec))
   if (pf_last_decimated) plot_stride = 4_int64 ! (not decimated: ImPlot's spec, the stride not
                                                                            ! recorded)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_line_row_r32

   recursive subroutine ip_line_row_r64(label, y, row, xscale, xstart, spec, stat)
   !< Line through the row `row` of `y`, y(row, j) at x = xstart + (j - 1) xscale, read in place (no copy),
   !< double precision.
   character(len=*),       intent(in)                     :: label  !< Legend label.
   real(real64),           intent(in), contiguous, target :: y(:,:) !< Matrix; its row `row` is plotted.
   integer(int32),         intent(in)                     :: row    !< Row to plot, in 1..size(y, 1).
   real(real64),           intent(in), optional           :: xscale !< Spacing of the abscissae (default 1).
   real(real64),           intent(in), optional           :: xstart !< First abscissa (default 0).
   type(plot_spec_object), intent(in), optional           :: spec   !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat   !< Status.

   if (refused('ip_line', stat)) return ! a task does not draw
   if (.not. row_ok(size(y, 1, kind=int64), size(y, 2, kind=int64), storage_size(y, kind=int64), row, stat)) return
   if (outside_plot('ip_line', stat)) return
   pf_last_decimated = .false.
   call pf_line(label, y, row, xscale, xstart, spec=item_spec(spec))
   if (pf_last_decimated) plot_stride = 8_int64 ! (not decimated: ImPlot's spec, the stride not
                                                                            ! recorded)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_line_row_r64

   recursive subroutine ip_line_device_r32(label, x, y, spec, stat)
   !< Line through the points (x(i), y(i)) of two contiguous `real(real32)` arrays on a device, decimated there
   !< (`ip_line_device`, double precision).
   character(len=*),       intent(in)                     :: label !< Legend label.
   real(real32),           intent(in), target             :: x(:)  !< Abscissae, on the device.
   real(real32),           intent(in), target             :: y(:)  !< Ordinates, on the device.
   type(plot_spec_object), intent(in), optional           :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat  !< Status.
   integer(int32)                                         :: ierr  !< FUNDAL's status.

   if (refused('ip_line_device', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_line_device', stat)) return
   if (outside_plot('ip_line_device', stat)) return
   call pf_line_device(label, x, y, spec=item_spec(spec), ierr=ierr)
   if (ierr /= 0_int32) then
      call figure_fail(FIG_ERR_FAILED, 'ip_line_device: a copy from the device failed', stat)
      return
   endif
   call figure_check(FIG_OK, stat)
   endsubroutine ip_line_device_r32

   recursive subroutine ip_line_device_r64(label, x, y, spec, stat)
   !< Line through the points (x(i), y(i)) of two contiguous `real(real64)` arrays on a device: FUNDAL's `dev_alloc`
   !< (or OpenACC device memory, as `deviceptr`), the program's, only read. The series is decimated where it lives, by
   !< kernels written with FUNDAL (OpenACC with nvfortran, FUNDAL's CPU mode elsewhere: the device is then the host),
   !< and only the points kept, at most 64 a pixel column, are copied to the host (plots.md, "Series on a device"). A
   !< series that is not decimated (unsorted abscissae, too few points, markers, `ip_set_decimation(.false.)`) is
   !< copied whole, then drawn as `ip_line`. Statuses: `FIG_ERR_ARGUMENT` (sizes), `FIG_ERR_STATE` (outside a plot,
   !< from a task), `FIG_ERR_FAILED` (a copy from the device failed).
   character(len=*),       intent(in)                     :: label !< Legend label.
   real(real64),           intent(in), target             :: x(:)  !< Abscissae, on the device.
   real(real64),           intent(in), target             :: y(:)  !< Ordinates, on the device.
   type(plot_spec_object), intent(in), optional           :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat  !< Status.
   integer(int32)                                         :: ierr  !< FUNDAL's status.

   if (refused('ip_line_device', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_line_device', stat)) return
   if (outside_plot('ip_line_device', stat)) return
   call pf_line_device(label, x, y, spec=item_spec(spec), ierr=ierr)
   if (ierr /= 0_int32) then
      call figure_fail(FIG_ERR_FAILED, 'ip_line_device: a copy from the device failed', stat)
      return
   endif
   call figure_check(FIG_OK, stat)
   endsubroutine ip_line_device_r64

   recursive subroutine ip_shaded_r32(label, x, y1, y2, spec, stat)
   !< Area between the curves y1(x) and y2(x), single precision; read in place with any stride (plots.md, "Data in
   !< place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   real(real32),           intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),           intent(in), target, asynchronous :: y1(:) !< First curve.
   real(real32),           intent(in), target, asynchronous :: y2(:) !< Second curve.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_shaded', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y1, kind=int64), 'ip_shaded', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y2, kind=int64), 'ip_shaded', stat)) return
   call acct_lead_r32(s, y1)
   call acct_put_r32(s, x)
   call acct_put_r32(s, y2)
   if (outside_plot('ip_shaded', stat)) return
   pf_last_decimated = .false.
   call pf_shaded(label, x, y1, y2, spec=item_spec(spec))
   call acct_item(s, 4_int64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_shaded_r32

   recursive subroutine ip_shaded_i32_r32(label, x, y1, y2, spec, stat)
   !< Area between the curves y1(x) and y2(x), single precision, abscissae `integer(int32)`: converted into one
   !< temporary, the ordinates read in place (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   integer(int32),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),           intent(in), target, asynchronous :: y1(:) !< First curve.
   real(real32),           intent(in), target, asynchronous :: y2(:) !< Second curve.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_shaded', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y1, kind=int64), 'ip_shaded', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y2, kind=int64), 'ip_shaded', stat)) return
   call acct_lead_r32(s, y1)
   call acct_put_int(size(x, kind=int64))
   call acct_put_r32(s, y2)
   if (outside_plot('ip_shaded', stat)) return
   pf_last_decimated = .false.
   call pf_shaded(label, x, y1, y2, spec=item_spec(spec))
   call acct_item(s, 4_int64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_shaded_i32_r32

   recursive subroutine ip_shaded_i64_r32(label, x, y1, y2, spec, stat)
   !< Area between the curves y1(x) and y2(x), single precision, abscissae `integer(int64)`: converted into one
   !< temporary, the ordinates read in place (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   integer(int64),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),           intent(in), target, asynchronous :: y1(:) !< First curve.
   real(real32),           intent(in), target, asynchronous :: y2(:) !< Second curve.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_shaded', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y1, kind=int64), 'ip_shaded', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y2, kind=int64), 'ip_shaded', stat)) return
   call acct_lead_r32(s, y1)
   call acct_put_int(size(x, kind=int64))
   call acct_put_r32(s, y2)
   if (outside_plot('ip_shaded', stat)) return
   pf_last_decimated = .false.
   call pf_shaded(label, x, y1, y2, spec=item_spec(spec))
   call acct_item(s, 4_int64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_shaded_i64_r32

   recursive subroutine ip_shaded_ref_r32(label, x, y, yref, spec, stat)
   !< Area between the curve y(x) and the line y = yref, single precision; read in place with any stride (plots.md,
   !< "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   real(real32),           intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),           intent(in), target, asynchronous :: y(:)  !< Curve.
   real(real64),           intent(in)                       :: yref  !< Reference line (-huge/+huge: to the plot edge).
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_shaded', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_shaded', stat)) return
   call acct_lead_r32(s, y)
   call acct_put_r32(s, x)
   if (outside_plot('ip_shaded', stat)) return
   pf_last_decimated = .false.
   call pf_shaded(label, x, y, yref, spec=item_spec(spec))
   call acct_item(s, 4_int64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_shaded_ref_r32

   recursive subroutine ip_shaded_ref_i32_r32(label, x, y, yref, spec, stat)
   !< Area between the curve y(x) and the line y = yref, single precision, abscissae `integer(int32)`: converted into
   !< one temporary, the ordinates read in place (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   integer(int32),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),           intent(in), target, asynchronous :: y(:)  !< Curve.
   real(real64),           intent(in)                       :: yref  !< Reference line (-huge/+huge: to the plot edge).
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_shaded', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_shaded', stat)) return
   call acct_lead_r32(s, y)
   call acct_put_int(size(x, kind=int64))
   if (outside_plot('ip_shaded', stat)) return
   pf_last_decimated = .false.
   call pf_shaded(label, x, y, yref, spec=item_spec(spec))
   call acct_item(s, 4_int64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_shaded_ref_i32_r32

   recursive subroutine ip_shaded_ref_i64_r32(label, x, y, yref, spec, stat)
   !< Area between the curve y(x) and the line y = yref, single precision, abscissae `integer(int64)`: converted into
   !< one temporary, the ordinates read in place (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   integer(int64),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),           intent(in), target, asynchronous :: y(:)  !< Curve.
   real(real64),           intent(in)                       :: yref  !< Reference line (-huge/+huge: to the plot edge).
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_shaded', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_shaded', stat)) return
   call acct_lead_r32(s, y)
   call acct_put_int(size(x, kind=int64))
   if (outside_plot('ip_shaded', stat)) return
   pf_last_decimated = .false.
   call pf_shaded(label, x, y, yref, spec=item_spec(spec))
   call acct_item(s, 4_int64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_shaded_ref_i64_r32

   recursive subroutine ip_shaded_r64(label, x, y1, y2, spec, stat)
   !< Area between the curves y1(x) and y2(x), double precision; read in place with any stride (plots.md, "Data in
   !< place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   real(real64),           intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),           intent(in), target, asynchronous :: y1(:) !< First curve.
   real(real64),           intent(in), target, asynchronous :: y2(:) !< Second curve.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_shaded', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y1, kind=int64), 'ip_shaded', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y2, kind=int64), 'ip_shaded', stat)) return
   call acct_lead_r64(s, y1)
   call acct_put_r64(s, x)
   call acct_put_r64(s, y2)
   if (outside_plot('ip_shaded', stat)) return
   pf_last_decimated = .false.
   call pf_shaded(label, x, y1, y2, spec=item_spec(spec))
   call acct_item(s, 8_int64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_shaded_r64

   recursive subroutine ip_shaded_i32_r64(label, x, y1, y2, spec, stat)
   !< Area between the curves y1(x) and y2(x), double precision, abscissae `integer(int32)`: converted into one
   !< temporary, the ordinates read in place (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   integer(int32),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),           intent(in), target, asynchronous :: y1(:) !< First curve.
   real(real64),           intent(in), target, asynchronous :: y2(:) !< Second curve.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_shaded', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y1, kind=int64), 'ip_shaded', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y2, kind=int64), 'ip_shaded', stat)) return
   call acct_lead_r64(s, y1)
   call acct_put_int(size(x, kind=int64))
   call acct_put_r64(s, y2)
   if (outside_plot('ip_shaded', stat)) return
   pf_last_decimated = .false.
   call pf_shaded(label, x, y1, y2, spec=item_spec(spec))
   call acct_item(s, 8_int64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_shaded_i32_r64

   recursive subroutine ip_shaded_i64_r64(label, x, y1, y2, spec, stat)
   !< Area between the curves y1(x) and y2(x), double precision, abscissae `integer(int64)`: converted into one
   !< temporary, the ordinates read in place (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   integer(int64),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),           intent(in), target, asynchronous :: y1(:) !< First curve.
   real(real64),           intent(in), target, asynchronous :: y2(:) !< Second curve.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_shaded', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y1, kind=int64), 'ip_shaded', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y2, kind=int64), 'ip_shaded', stat)) return
   call acct_lead_r64(s, y1)
   call acct_put_int(size(x, kind=int64))
   call acct_put_r64(s, y2)
   if (outside_plot('ip_shaded', stat)) return
   pf_last_decimated = .false.
   call pf_shaded(label, x, y1, y2, spec=item_spec(spec))
   call acct_item(s, 8_int64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_shaded_i64_r64

   recursive subroutine ip_shaded_ref_r64(label, x, y, yref, spec, stat)
   !< Area between the curve y(x) and the line y = yref, double precision; read in place with any stride (plots.md,
   !< "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   real(real64),           intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),           intent(in), target, asynchronous :: y(:)  !< Curve.
   real(real64),           intent(in)                       :: yref  !< Reference line (-huge/+huge: to the plot edge).
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_shaded', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_shaded', stat)) return
   call acct_lead_r64(s, y)
   call acct_put_r64(s, x)
   if (outside_plot('ip_shaded', stat)) return
   pf_last_decimated = .false.
   call pf_shaded(label, x, y, yref, spec=item_spec(spec))
   call acct_item(s, 8_int64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_shaded_ref_r64

   recursive subroutine ip_shaded_ref_i32_r64(label, x, y, yref, spec, stat)
   !< Area between the curve y(x) and the line y = yref, double precision, abscissae `integer(int32)`: converted into
   !< one temporary, the ordinates read in place (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   integer(int32),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),           intent(in), target, asynchronous :: y(:)  !< Curve.
   real(real64),           intent(in)                       :: yref  !< Reference line (-huge/+huge: to the plot edge).
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_shaded', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_shaded', stat)) return
   call acct_lead_r64(s, y)
   call acct_put_int(size(x, kind=int64))
   if (outside_plot('ip_shaded', stat)) return
   pf_last_decimated = .false.
   call pf_shaded(label, x, y, yref, spec=item_spec(spec))
   call acct_item(s, 8_int64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_shaded_ref_i32_r64

   recursive subroutine ip_shaded_ref_i64_r64(label, x, y, yref, spec, stat)
   !< Area between the curve y(x) and the line y = yref, double precision, abscissae `integer(int64)`: converted into
   !< one temporary, the ordinates read in place (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   integer(int64),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),           intent(in), target, asynchronous :: y(:)  !< Curve.
   real(real64),           intent(in)                       :: yref  !< Reference line (-huge/+huge: to the plot edge).
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   integer(int64)                                           :: s     !< The stride ImPlot would read [bytes].

   if (refused('ip_shaded', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_shaded', stat)) return
   call acct_lead_r64(s, y)
   call acct_put_int(size(x, kind=int64))
   if (outside_plot('ip_shaded', stat)) return
   pf_last_decimated = .false.
   call pf_shaded(label, x, y, yref, spec=item_spec(spec))
   call acct_item(s, 8_int64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_shaded_ref_i64_r64

   recursive subroutine ip_error_bars_r32(label, x, y, err, err_high, spec, horizontal, stat)
   !< Error bars at the points (x(i), y(i)), from y(i) - err(i) to y(i) + err(i); with `err_high`, to y(i) +
   !< err_high(i); with `horizontal=.true.`, along x instead, from x(i) - err(i), single precision; read in place
   !< with any stride (plots.md, "Data in place").
   character(len=*),       intent(in)                                 :: label       !< Legend label.
   real(real32),           intent(in), target, asynchronous           :: x(:)        !< Abscissae.
   real(real32),           intent(in), target, asynchronous           :: y(:)        !< Ordinates.
   real(real32),           intent(in), target, asynchronous           :: err(:)      !< Error below (and above) [y units, or x].
   real(real32),           intent(in), target, optional, asynchronous :: err_high(:) !< Error above [y units, or x].
   type(plot_spec_object), intent(in), optional                       :: spec        !< Style (default: ImPlot's).
   logical,                intent(in), optional                       :: horizontal  !< Bars along x (`err` in x units).
   integer(int32),         intent(out), optional                      :: stat        !< Status.
   integer(int64)                                                     :: s           !< The stride ImPlot would read [bytes].

   if (refused('ip_error_bars', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_error_bars', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(err, kind=int64), 'ip_error_bars', stat)) return
   if (present(err_high)) then
      if (.not. series_ok(size(x, kind=int64), size(err_high, kind=int64), 'ip_error_bars', stat)) return
   endif
   call acct_lead_r32(s, y)
   call acct_put_r32(s, x)
   call acct_put_r32(s, err)
   plot_stride = s
   if (outside_plot('ip_error_bars', stat)) return
   if (present(err_high)) then ! (an absent optional array passed on: ifx and nvfortran crash)
      call acct_put_r32(s, err_high)
      call pf_error_bars(label, x, y, err, err_high, spec=item_spec(spec), horizontal=horizontal)
   else
      call pf_error_bars(label, x, y, err, spec=item_spec(spec), horizontal=horizontal)
   endif
   call figure_check(FIG_OK, stat)
   endsubroutine ip_error_bars_r32

   recursive subroutine ip_error_bars_i32_r32(label, x, y, err, err_high, spec, horizontal, stat)
   !< Error bars at the points (x(i), y(i)), from y(i) - err(i) to y(i) + err(i); with `err_high`, to y(i) +
   !< err_high(i); with `horizontal=.true.`, along x instead, from x(i) - err(i), single precision, abscissae
   !< `integer(int32)`: converted into one temporary, the ordinates read in
   !< place (plots.md, "Data in place").
   character(len=*),       intent(in)                                 :: label       !< Legend label.
   integer(int32),         intent(in), target, asynchronous           :: x(:)        !< Abscissae.
   real(real32),           intent(in), target, asynchronous           :: y(:)        !< Ordinates.
   real(real32),           intent(in), target, asynchronous           :: err(:)      !< Error below (and above) [y units, or x].
   real(real32),           intent(in), target, optional, asynchronous :: err_high(:) !< Error above [y units, or x].
   type(plot_spec_object), intent(in), optional                       :: spec        !< Style (default: ImPlot's).
   logical,                intent(in), optional                       :: horizontal  !< Bars along x (`err` in x units).
   integer(int32),         intent(out), optional                      :: stat        !< Status.
   integer(int64)                                                     :: s           !< The stride ImPlot would read [bytes].

   if (refused('ip_error_bars', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_error_bars', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(err, kind=int64), 'ip_error_bars', stat)) return
   if (present(err_high)) then
      if (.not. series_ok(size(x, kind=int64), size(err_high, kind=int64), 'ip_error_bars', stat)) return
   endif
   call acct_lead_r32(s, y)
   call acct_put_int(size(x, kind=int64))
   call acct_put_r32(s, err)
   plot_stride = s
   if (outside_plot('ip_error_bars', stat)) return
   if (present(err_high)) then ! (an absent optional array passed on: ifx and nvfortran crash)
      call acct_put_r32(s, err_high)
      call pf_error_bars(label, x, y, err, err_high, spec=item_spec(spec), horizontal=horizontal)
   else
      call pf_error_bars(label, x, y, err, spec=item_spec(spec), horizontal=horizontal)
   endif
   call figure_check(FIG_OK, stat)
   endsubroutine ip_error_bars_i32_r32

   recursive subroutine ip_error_bars_i64_r32(label, x, y, err, err_high, spec, horizontal, stat)
   !< Error bars at the points (x(i), y(i)), from y(i) - err(i) to y(i) + err(i); with `err_high`, to y(i) +
   !< err_high(i); with `horizontal=.true.`, along x instead, from x(i) - err(i), single precision, abscissae
   !< `integer(int64)`: converted into one temporary, the ordinates read in
   !< place (plots.md, "Data in place").
   character(len=*),       intent(in)                                 :: label       !< Legend label.
   integer(int64),         intent(in), target, asynchronous           :: x(:)        !< Abscissae.
   real(real32),           intent(in), target, asynchronous           :: y(:)        !< Ordinates.
   real(real32),           intent(in), target, asynchronous           :: err(:)      !< Error below (and above) [y units, or x].
   real(real32),           intent(in), target, optional, asynchronous :: err_high(:) !< Error above [y units, or x].
   type(plot_spec_object), intent(in), optional                       :: spec        !< Style (default: ImPlot's).
   logical,                intent(in), optional                       :: horizontal  !< Bars along x (`err` in x units).
   integer(int32),         intent(out), optional                      :: stat        !< Status.
   integer(int64)                                                     :: s           !< The stride ImPlot would read [bytes].

   if (refused('ip_error_bars', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_error_bars', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(err, kind=int64), 'ip_error_bars', stat)) return
   if (present(err_high)) then
      if (.not. series_ok(size(x, kind=int64), size(err_high, kind=int64), 'ip_error_bars', stat)) return
   endif
   call acct_lead_r32(s, y)
   call acct_put_int(size(x, kind=int64))
   call acct_put_r32(s, err)
   plot_stride = s
   if (outside_plot('ip_error_bars', stat)) return
   if (present(err_high)) then ! (an absent optional array passed on: ifx and nvfortran crash)
      call acct_put_r32(s, err_high)
      call pf_error_bars(label, x, y, err, err_high, spec=item_spec(spec), horizontal=horizontal)
   else
      call pf_error_bars(label, x, y, err, spec=item_spec(spec), horizontal=horizontal)
   endif
   call figure_check(FIG_OK, stat)
   endsubroutine ip_error_bars_i64_r32

   recursive subroutine ip_error_bars_r64(label, x, y, err, err_high, spec, horizontal, stat)
   !< Error bars at the points (x(i), y(i)), from y(i) - err(i) to y(i) + err(i); with `err_high`, to y(i) +
   !< err_high(i); with `horizontal=.true.`, along x instead, from x(i) - err(i), double precision; read in place
   !< with any stride (plots.md, "Data in place").
   character(len=*),       intent(in)                                 :: label       !< Legend label.
   real(real64),           intent(in), target, asynchronous           :: x(:)        !< Abscissae.
   real(real64),           intent(in), target, asynchronous           :: y(:)        !< Ordinates.
   real(real64),           intent(in), target, asynchronous           :: err(:)      !< Error below (and above) [y units, or x].
   real(real64),           intent(in), target, optional, asynchronous :: err_high(:) !< Error above [y units, or x].
   type(plot_spec_object), intent(in), optional                       :: spec        !< Style (default: ImPlot's).
   logical,                intent(in), optional                       :: horizontal  !< Bars along x (`err` in x units).
   integer(int32),         intent(out), optional                      :: stat        !< Status.
   integer(int64)                                                     :: s           !< The stride ImPlot would read [bytes].

   if (refused('ip_error_bars', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_error_bars', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(err, kind=int64), 'ip_error_bars', stat)) return
   if (present(err_high)) then
      if (.not. series_ok(size(x, kind=int64), size(err_high, kind=int64), 'ip_error_bars', stat)) return
   endif
   call acct_lead_r64(s, y)
   call acct_put_r64(s, x)
   call acct_put_r64(s, err)
   plot_stride = s
   if (outside_plot('ip_error_bars', stat)) return
   if (present(err_high)) then ! (an absent optional array passed on: ifx and nvfortran crash)
      call acct_put_r64(s, err_high)
      call pf_error_bars(label, x, y, err, err_high, spec=item_spec(spec), horizontal=horizontal)
   else
      call pf_error_bars(label, x, y, err, spec=item_spec(spec), horizontal=horizontal)
   endif
   call figure_check(FIG_OK, stat)
   endsubroutine ip_error_bars_r64

   recursive subroutine ip_error_bars_i32_r64(label, x, y, err, err_high, spec, horizontal, stat)
   !< Error bars at the points (x(i), y(i)), from y(i) - err(i) to y(i) + err(i); with `err_high`, to y(i) +
   !< err_high(i); with `horizontal=.true.`, along x instead, from x(i) - err(i), double precision, abscissae
   !< `integer(int32)`: converted into one temporary, the ordinates read in
   !< place (plots.md, "Data in place").
   character(len=*),       intent(in)                                 :: label       !< Legend label.
   integer(int32),         intent(in), target, asynchronous           :: x(:)        !< Abscissae.
   real(real64),           intent(in), target, asynchronous           :: y(:)        !< Ordinates.
   real(real64),           intent(in), target, asynchronous           :: err(:)      !< Error below (and above) [y units, or x].
   real(real64),           intent(in), target, optional, asynchronous :: err_high(:) !< Error above [y units, or x].
   type(plot_spec_object), intent(in), optional                       :: spec        !< Style (default: ImPlot's).
   logical,                intent(in), optional                       :: horizontal  !< Bars along x (`err` in x units).
   integer(int32),         intent(out), optional                      :: stat        !< Status.
   integer(int64)                                                     :: s           !< The stride ImPlot would read [bytes].

   if (refused('ip_error_bars', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_error_bars', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(err, kind=int64), 'ip_error_bars', stat)) return
   if (present(err_high)) then
      if (.not. series_ok(size(x, kind=int64), size(err_high, kind=int64), 'ip_error_bars', stat)) return
   endif
   call acct_lead_r64(s, y)
   call acct_put_int(size(x, kind=int64))
   call acct_put_r64(s, err)
   plot_stride = s
   if (outside_plot('ip_error_bars', stat)) return
   if (present(err_high)) then ! (an absent optional array passed on: ifx and nvfortran crash)
      call acct_put_r64(s, err_high)
      call pf_error_bars(label, x, y, err, err_high, spec=item_spec(spec), horizontal=horizontal)
   else
      call pf_error_bars(label, x, y, err, spec=item_spec(spec), horizontal=horizontal)
   endif
   call figure_check(FIG_OK, stat)
   endsubroutine ip_error_bars_i32_r64

   recursive subroutine ip_error_bars_i64_r64(label, x, y, err, err_high, spec, horizontal, stat)
   !< Error bars at the points (x(i), y(i)), from y(i) - err(i) to y(i) + err(i); with `err_high`, to y(i) +
   !< err_high(i); with `horizontal=.true.`, along x instead, from x(i) - err(i), double precision, abscissae
   !< `integer(int64)`: converted into one temporary, the ordinates read in
   !< place (plots.md, "Data in place").
   character(len=*),       intent(in)                                 :: label       !< Legend label.
   integer(int64),         intent(in), target, asynchronous           :: x(:)        !< Abscissae.
   real(real64),           intent(in), target, asynchronous           :: y(:)        !< Ordinates.
   real(real64),           intent(in), target, asynchronous           :: err(:)      !< Error below (and above) [y units, or x].
   real(real64),           intent(in), target, optional, asynchronous :: err_high(:) !< Error above [y units, or x].
   type(plot_spec_object), intent(in), optional                       :: spec        !< Style (default: ImPlot's).
   logical,                intent(in), optional                       :: horizontal  !< Bars along x (`err` in x units).
   integer(int32),         intent(out), optional                      :: stat        !< Status.
   integer(int64)                                                     :: s           !< The stride ImPlot would read [bytes].

   if (refused('ip_error_bars', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_error_bars', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(err, kind=int64), 'ip_error_bars', stat)) return
   if (present(err_high)) then
      if (.not. series_ok(size(x, kind=int64), size(err_high, kind=int64), 'ip_error_bars', stat)) return
   endif
   call acct_lead_r64(s, y)
   call acct_put_int(size(x, kind=int64))
   call acct_put_r64(s, err)
   plot_stride = s
   if (outside_plot('ip_error_bars', stat)) return
   if (present(err_high)) then ! (an absent optional array passed on: ifx and nvfortran crash)
      call acct_put_r64(s, err_high)
      call pf_error_bars(label, x, y, err, err_high, spec=item_spec(spec), horizontal=horizontal)
   else
      call pf_error_bars(label, x, y, err, spec=item_spec(spec), horizontal=horizontal)
   endif
   call figure_check(FIG_OK, stat)
   endsubroutine ip_error_bars_i64_r64

   recursive subroutine ip_bubbles_r32(label, x, y, radii, spec, stat)
   !< Circles at the points (x(i), y(i)) of radius radii(i) (`PlotBubbles`), single precision: the radius is in plot
   !< units along both axes (a circle on equal axes; an ellipse where their scales differ), filled with the item's fill colour
   !< (`ip_spec(fill_color=..., fill_alpha=...)`) and outlined with its line colour. Read in place with any stride
   !< (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label    !< Legend label.
   real(real32),       intent(in), target, asynchronous :: x(:)     !< Abscissae.
   real(real32),       intent(in), target, asynchronous :: y(:)     !< Ordinates.
   real(real32),       intent(in), target, asynchronous :: radii(:) !< Radii [plot units].
   type(plot_spec_object), intent(in), optional             :: spec     !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat     !< Status.
   integer(int64)                                           :: s        !< The stride ImPlot would read [bytes].

   if (refused('ip_bubbles', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_bubbles', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(radii, kind=int64), 'ip_bubbles', stat)) return
   call acct_lead_r32(s, y)
   call acct_put_r32(s, x)
   call acct_put_r32(s, radii)
   if (outside_plot('ip_bubbles', stat)) return
   call pf_bubbles(label, x, y, radii, spec=item_spec(spec))
   plot_stride = s
   call figure_check(FIG_OK, stat)
   endsubroutine ip_bubbles_r32

   recursive subroutine ip_bubbles_r64(label, x, y, radii, spec, stat)
   !< Circles at the points (x(i), y(i)) of radius radii(i) (`PlotBubbles`), double precision: the radius is in plot
   !< units along both axes (a circle on equal axes; an ellipse where their scales differ), filled with the item's fill colour
   !< (`ip_spec(fill_color=..., fill_alpha=...)`) and outlined with its line colour. Read in place with any stride
   !< (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label    !< Legend label.
   real(real64),       intent(in), target, asynchronous :: x(:)     !< Abscissae.
   real(real64),       intent(in), target, asynchronous :: y(:)     !< Ordinates.
   real(real64),       intent(in), target, asynchronous :: radii(:) !< Radii [plot units].
   type(plot_spec_object), intent(in), optional             :: spec     !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat     !< Status.
   integer(int64)                                           :: s        !< The stride ImPlot would read [bytes].

   if (refused('ip_bubbles', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_bubbles', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(radii, kind=int64), 'ip_bubbles', stat)) return
   call acct_lead_r64(s, y)
   call acct_put_r64(s, x)
   call acct_put_r64(s, radii)
   if (outside_plot('ip_bubbles', stat)) return
   call pf_bubbles(label, x, y, radii, spec=item_spec(spec))
   plot_stride = s
   call figure_check(FIG_OK, stat)
   endsubroutine ip_bubbles_r64

   recursive subroutine ip_pie_chart_r32(labels, values, x, y, radius, label_format, angle0, normalize, colormap, &
                                       spec, stat)
   !< A pie chart (`PlotPieChart`), single precision: one slice per value, its label in the legend, centred at (x, y) with
   !< `radius`, all in plot units (equal axes keep it round: `ip_begin_plot(..., equal=.true.)`). The slices start at
   !< `angle0` degrees (default 90, the top) and go clockwise. Each slice shows its value with `label_format`, a C
   !< printf format of one real (default `'%.1f'`; `''` shows none). Values summing to 1 or more make a full circle;
   !< below 1, the slices are fractions of one and the circle is partial, unless `normalize=.true.`, which always makes
   !< a full circle. The slices' colours are the colormap's, in order: the plot's, or `colormap` (`ip_colormap`); a
   !< spec's colours do not apply to them. Statuses: `FIG_ERR_ARGUMENT` for labels not one per value, a radius not
   !< above 0, a value below 0 or not finite, a format refused, a colormap not registered; `FIG_ERR_STATE` from a task.
   character(len=*),       intent(in)            :: labels(:)    !< One label per slice (trailing blanks are not shown).
   real(real32),       intent(in)            :: values(:)    !< Slice values (0 or more).
   real(real64),           intent(in)            :: x            !< Centre's abscissa [plot units].
   real(real64),           intent(in)            :: y            !< Centre's ordinate [plot units].
   real(real64),           intent(in)            :: radius       !< Radius [plot units].
   character(len=*),       intent(in), optional  :: label_format !< printf format of a slice's value (default '%.1f').
   real(real64),           intent(in), optional  :: angle0       !< Where the first slice starts [degrees].
   logical,                intent(in), optional  :: normalize    !< Always a full circle (default `.false.`).
   integer(int32),         intent(in), optional  :: colormap     !< The slices' colours (default: the plot's colormap).
   type(plot_spec_object), intent(in), optional  :: spec         !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional :: stat         !< Status.
   integer(int64)                                :: n            !< Slices.
   integer(c_int)                                :: cmap         !< The colormap's id.

   if (refused('ip_pie_chart', stat)) return ! a task does not draw
   if (present(colormap)) then
      if (.not. colormap_ok('ip_pie_chart', colormap, cmap, stat)) return
   endif
   n = size(values, kind=int64)
   if (size(labels, kind=int64) /= n) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_pie_chart: labels must be one per value', stat)
      return
   endif
   if (.not. (radius > 0.0_real64)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_pie_chart: the radius must be above 0', stat)
      return
   endif
   if (n > int(huge(0_c_int), int64)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_pie_chart: more slices than a C int counts', stat)
      return
   endif
   if (.not. all(values >= 0.0_real32 .and. values <= huge(1.0_real32))) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_pie_chart: a value is below 0 or not finite', stat)
      return
   endif
   if (present(label_format)) then
      if (len(label_format) > 0) then
         if (format_refused('ip_pie_chart', 'label_format', label_format, FORMAT_REAL, stat)) return
      endif
   endif
   if (outside_plot('ip_pie_chart', stat)) then
      if (present(colormap)) call cm_push_left(cm_frame_id(int(cmap, int32))) ! the current path's: pushed, then refused (notes)
      return
   endif
   if (n > 0_int64) then
      if (present(colormap)) then
         call pf_pie_chart(labels, values, x, y, radius, label_format, angle0, normalize, cm_frame_id(int(cmap, int32)), &
                           spec=item_spec(spec))
      else
         call pf_pie_chart(labels, values, x, y, radius, label_format, angle0, normalize, spec=item_spec(spec))
      endif
   endif
   call figure_check(FIG_OK, stat)
   endsubroutine ip_pie_chart_r32

   recursive subroutine ip_pie_chart_r64(labels, values, x, y, radius, label_format, angle0, normalize, colormap, &
                                       spec, stat)
   !< A pie chart (`PlotPieChart`), double precision: one slice per value, its label in the legend, centred at (x, y) with
   !< `radius`, all in plot units (equal axes keep it round: `ip_begin_plot(..., equal=.true.)`). The slices start at
   !< `angle0` degrees (default 90, the top) and go clockwise. Each slice shows its value with `label_format`, a C
   !< printf format of one real (default `'%.1f'`; `''` shows none). Values summing to 1 or more make a full circle;
   !< below 1, the slices are fractions of one and the circle is partial, unless `normalize=.true.`, which always makes
   !< a full circle. The slices' colours are the colormap's, in order: the plot's, or `colormap` (`ip_colormap`); a
   !< spec's colours do not apply to them. Statuses: `FIG_ERR_ARGUMENT` for labels not one per value, a radius not
   !< above 0, a value below 0 or not finite, a format refused, a colormap not registered; `FIG_ERR_STATE` from a task.
   character(len=*),       intent(in)            :: labels(:)    !< One label per slice (trailing blanks are not shown).
   real(real64),       intent(in)            :: values(:)    !< Slice values (0 or more).
   real(real64),           intent(in)            :: x            !< Centre's abscissa [plot units].
   real(real64),           intent(in)            :: y            !< Centre's ordinate [plot units].
   real(real64),           intent(in)            :: radius       !< Radius [plot units].
   character(len=*),       intent(in), optional  :: label_format !< printf format of a slice's value (default '%.1f').
   real(real64),           intent(in), optional  :: angle0       !< Where the first slice starts [degrees].
   logical,                intent(in), optional  :: normalize    !< Always a full circle (default `.false.`).
   integer(int32),         intent(in), optional  :: colormap     !< The slices' colours (default: the plot's colormap).
   type(plot_spec_object), intent(in), optional  :: spec         !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional :: stat         !< Status.
   integer(int64)                                :: n            !< Slices.
   integer(c_int)                                :: cmap         !< The colormap's id.

   if (refused('ip_pie_chart', stat)) return ! a task does not draw
   if (present(colormap)) then
      if (.not. colormap_ok('ip_pie_chart', colormap, cmap, stat)) return
   endif
   n = size(values, kind=int64)
   if (size(labels, kind=int64) /= n) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_pie_chart: labels must be one per value', stat)
      return
   endif
   if (.not. (radius > 0.0_real64)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_pie_chart: the radius must be above 0', stat)
      return
   endif
   if (n > int(huge(0_c_int), int64)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_pie_chart: more slices than a C int counts', stat)
      return
   endif
   if (.not. all(values >= 0.0_real64 .and. values <= huge(1.0_real64))) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_pie_chart: a value is below 0 or not finite', stat)
      return
   endif
   if (present(label_format)) then
      if (len(label_format) > 0) then
         if (format_refused('ip_pie_chart', 'label_format', label_format, FORMAT_REAL, stat)) return
      endif
   endif
   if (outside_plot('ip_pie_chart', stat)) then
      if (present(colormap)) call cm_push_left(cm_frame_id(int(cmap, int32))) ! the current path's: pushed, then refused (notes)
      return
   endif
   if (n > 0_int64) then
      if (present(colormap)) then
         call pf_pie_chart(labels, values, x, y, radius, label_format, angle0, normalize, cm_frame_id(int(cmap, int32)), &
                           spec=item_spec(spec))
      else
         call pf_pie_chart(labels, values, x, y, radius, label_format, angle0, normalize, spec=item_spec(spec))
      endif
   endif
   call figure_check(FIG_OK, stat)
   endsubroutine ip_pie_chart_r64

   recursive subroutine ip_heatmap_r32(label, f, xmin, xmax, ymin, ymax, scale_min, scale_max, label_format, colormap, spec, &
                             stat)
   !< The field f(i, j) as coloured cells over [xmin, xmax] x [ymin, ymax], read in place (no copy, no transpose):
   !< cell (i, j) spans the i-th of size(f, 1) columns along x and the j-th of size(f, 2) rows along y, j = 1 at the
   !< bottom. Single precision.
   character(len=*),       intent(in)                     :: label        !< Legend label.
   real(real32),           intent(in), contiguous, target :: f(:,:)       !< Field: f(i, j), i along x, j along y.
   real(real64),           intent(in)                     :: xmin         !< Left edge of the first column.
   real(real64),           intent(in)                     :: xmax         !< Right edge of the last column.
   real(real64),           intent(in)                     :: ymin         !< Bottom edge of row 1.
   real(real64),           intent(in)                     :: ymax         !< Top edge of the last row.
   real(real64),           intent(in), optional           :: scale_min    !< Value at the bottom of the colormap.
   real(real64),           intent(in), optional           :: scale_max    !< Value at the top (both or none; none: data).
   character(len=*),       intent(in), optional           :: label_format !< printf format of one real, printing each value in
                                                                           !< its cell (checked: FIG_ERR_ARGUMENT).
   integer(int32),         intent(in), optional           :: colormap     !< Colormap (`ip_colormap`; default: Viridis).
   type(plot_spec_object), intent(in), optional           :: spec         !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat         !< Status.
   integer(c_int)                                         :: cmap         !< The colormap's id.

   if (refused('ip_heatmap', stat)) return ! a task does not draw
   if (.not. field_ok(size(f, 1, kind=int64), size(f, 2, kind=int64), present(scale_min), present(scale_max), stat)) return
   if (.not. colormap_ok('ip_heatmap', colormap, cmap, stat)) return
   if (present(label_format)) then
      if (format_refused('ip_heatmap', 'label_format', label_format, FORMAT_REAL, stat)) return
   endif
   if (outside_plot('ip_heatmap', stat)) then
      call cm_push_left(cm_frame_id(int(cmap, int32))) ! the current path's: pushed, then refused (notes)
      return
   endif
   call pf_heatmap(label, f, xmin, xmax, ymin, ymax, scale_min, scale_max, label_format, cm_frame_id(int(cmap, int32)), &
                   spec=item_spec(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_heatmap_r32

   recursive subroutine ip_heatmap_r64(label, f, xmin, xmax, ymin, ymax, scale_min, scale_max, label_format, colormap, spec, &
                             stat)
   !< The field f(i, j) as coloured cells over [xmin, xmax] x [ymin, ymax], read in place (no copy, no transpose):
   !< cell (i, j) spans the i-th of size(f, 1) columns along x and the j-th of size(f, 2) rows along y, j = 1 at the
   !< bottom. Double precision.
   character(len=*),       intent(in)                     :: label        !< Legend label.
   real(real64),           intent(in), contiguous, target :: f(:,:)       !< Field: f(i, j), i along x, j along y.
   real(real64),           intent(in)                     :: xmin         !< Left edge of the first column.
   real(real64),           intent(in)                     :: xmax         !< Right edge of the last column.
   real(real64),           intent(in)                     :: ymin         !< Bottom edge of row 1.
   real(real64),           intent(in)                     :: ymax         !< Top edge of the last row.
   real(real64),           intent(in), optional           :: scale_min    !< Value at the bottom of the colormap.
   real(real64),           intent(in), optional           :: scale_max    !< Value at the top (both or none; none: data).
   character(len=*),       intent(in), optional           :: label_format !< printf format of one real, printing each value in
                                                                           !< its cell (checked: FIG_ERR_ARGUMENT).
   integer(int32),         intent(in), optional           :: colormap     !< Colormap (`ip_colormap`; default: Viridis).
   type(plot_spec_object), intent(in), optional           :: spec         !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat         !< Status.
   integer(c_int)                                         :: cmap         !< The colormap's id.

   if (refused('ip_heatmap', stat)) return ! a task does not draw
   if (.not. field_ok(size(f, 1, kind=int64), size(f, 2, kind=int64), present(scale_min), present(scale_max), stat)) return
   if (.not. colormap_ok('ip_heatmap', colormap, cmap, stat)) return
   if (present(label_format)) then
      if (format_refused('ip_heatmap', 'label_format', label_format, FORMAT_REAL, stat)) return
   endif
   if (outside_plot('ip_heatmap', stat)) then
      call cm_push_left(cm_frame_id(int(cmap, int32))) ! the current path's: pushed, then refused (notes)
      return
   endif
   call pf_heatmap(label, f, xmin, xmax, ymin, ymax, scale_min, scale_max, label_format, cm_frame_id(int(cmap, int32)), &
                   spec=item_spec(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_heatmap_r64

   recursive subroutine ip_image(label, tex, xmin, xmax, ymin, ymax, spec, stat)
   !< A texture over [xmin, xmax] x [ymin, ymax], pixel row 1 at ymin (plot convention: y up).
   character(len=*),       intent(in)            :: label !< Legend label.
   type(texture_object),   intent(in)            :: tex   !< Texture.
   real(real64),           intent(in)            :: xmin  !< Left edge.
   real(real64),           intent(in)            :: xmax  !< Right edge.
   real(real64),           intent(in)            :: ymin  !< Bottom edge (pixel row 1).
   real(real64),           intent(in)            :: ymax  !< Top edge (last pixel row).
   type(plot_spec_object), intent(in), optional  :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional :: stat  !< Status.

   if (refused('ip_image', stat)) return ! a task does not draw
   if (.not. tex%is_initialized()) then
      call figure_fail(FIG_ERR_STATE, 'ip_image: the texture is not initialized', stat)
      return
   endif
   if (outside_plot('ip_image', stat)) return
   call pf_image(label, tex, xmin, xmax, ymin, ymax, spec=item_spec(spec)) ! (the texture's own filter: the frame's)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_image

   recursive subroutine ip_colormap_scale(label, scale_min, scale_max, width, height, label_format, colormap, stat)
   !< A colour bar for [scale_min, scale_max], next to a heatmap (outside `ip_begin_plot`/`ip_end_plot`). Statuses:
   !< `FIG_ERR_ARGUMENT` for a colormap id that is not registered, or a `label_format` that is not a printf format of
   !< one real.
   character(len=*), intent(in)            :: label        !< Label (also the widget id).
   real(real64),     intent(in)            :: scale_min    !< Value at the bottom.
   real(real64),     intent(in)            :: scale_max    !< Value at the top.
   real(real64),     intent(in),  optional :: width        !< Width [pixels] (default: ImPlot's).
   real(real64),     intent(in),  optional :: height       !< Height [pixels] (default: ImPlot's).
   character(len=*), intent(in),  optional :: label_format !< printf format of one real, the tick labels (default '%g').
   integer(int32),   intent(in),  optional :: colormap     !< Colormap (`ip_colormap`; default: Viridis).
   integer(int32),   intent(out), optional :: stat         !< Status.
   integer(c_int)                          :: cmap         !< The colormap's id.

   if (refused('ip_colormap_scale', stat)) return ! a task does not draw
   if (.not. colormap_ok('ip_colormap_scale', colormap, cmap, stat)) return
   if (present(label_format)) then
      if (format_refused('ip_colormap_scale', 'label_format', label_format, FORMAT_REAL, stat)) return
   endif
   call pf_colormap_scale(label, scale_min, scale_max, width, height, label_format, cm_frame_id(int(cmap, int32)))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_colormap_scale

   recursive subroutine ip_colormap_legend(id, colormap, vmin, vmax, levels, horizontal, width, height, label_format, &
                                           scale, stat)
   !< A colour-scale legend: a bar coloured by `colormap` from `vmin` to `vmax` (bottom to top, or left to right with
   !< `horizontal=.true.`), with ticks and their values on its right (or below). An item of the current window, outside
   !< a plot: beside any plot (`ig_same_line`), above or below it, or in any window. With `levels`: that many bands of
   !< equal width, each the map's colour at its centre (as `ip_colormap(name, levels)` colours a field), the ticks at the
   !< bands' edges, labelled with the digits they need to show the edge (`label_format`'s precision raised, up to 6
   !< decimals for `%f` or 7 significant digits for `%e` and `%g`: 87.5 with `'%.0f'`, as `ip_contour` labels it);
   !< without: a continuous bar, ticks at round values (a step of 1, 2, 2.5 or 5 times a power of ten) about every 40
   !< pixels (100 horizontal), labelled with `label_format` as it is. `scale` (`'linear'`, `'log'`, `'symlog'`) puts
   !< the ticks where `ip_field_image` with that scale puts the values' colours: decades on `'log'`, 0 and the signed
   !< decades on `'symlog'` (thinned to the room their labels need), band edges equally spaced in the scale.
   !< `vmin > vmax` turns the scale over. Sizes [pixels]: positive given, negative the space left in the window, absent
   !< the default (vertical: 300 long, as wide as the bar and the labels; horizontal: the space left, as tall as the bar
   !< and a line of labels). The user cannot change the range: `ip_colormap_legend_edit` is the same legend, dragged
   !< and scrolled. Statuses: `FIG_ERR_ARGUMENT` for a colormap that is not registered, equal or non-finite
   !< `vmin`/`vmax`, ends not above 0 on `'log'`, an unknown scale, `levels` outside [2, 256], a `label_format` with
   !< a conversion that is not one of a real (a format without conversion is text, printed as it is; `''` is the
   !< default); `FIG_ERR_STATE` outside a window and from a task. The same in every mode.
   character(len=*), intent(in)            :: id           !< Widget id, unique in the window (not shown).
   integer(int32),   intent(in)            :: colormap     !< Colormap (`ip_colormap`).
   real(real64),     intent(in)            :: vmin         !< Value at the bottom (left).
   real(real64),     intent(in)            :: vmax         !< Value at the top (right).
   integer(int32),   intent(in), optional  :: levels       !< Discrete bands, in [2, 256] (default: continuous).
   logical,          intent(in), optional  :: horizontal   !< Horizontal bar (default: vertical).
   real(real64),     intent(in), optional  :: width        !< Width [pixels].
   real(real64),     intent(in), optional  :: height       !< Height [pixels].
   character(len=*), intent(in), optional  :: label_format !< printf format of one real, the values, or text
                                                           !< (default, and '': '%g').
   character(len=*), intent(in), optional  :: scale        !< 'linear' (default), 'log', 'symlog'.
   integer(int32),   intent(out), optional :: stat         !< Status.
   real(real64)                            :: range(2)     !< The range (unchanged: not interactive).
   logical                                 :: changed      !< Unused.

   call legend('ip_colormap_legend', id, colormap, vmin, vmax, levels, horizontal, width, height, label_format, scale, &
               .false., range, changed, stat)
   endsubroutine ip_colormap_legend

   recursive function ip_colormap_legend_edit(id, colormap, vmin, vmax, levels, horizontal, width, height, label_format, &
                                              scale, stat) result(changed)
   !< `ip_colormap_legend` whose range the user changes (ImPlotExtra.jl's `colorbar!`): dragging along the bar moves
   !< [vmin, vmax] with the pointer, the mouse wheel over it zooms the range about the value under the pointer (10% a
   !< step; wheel up narrows it), both in the scale's space (on `'log'` the range moves by factors and stays positive).
   !< `vmin` and `vmax` are updated in place; true on the frame they changed: pass them to `ip_field_image`, which
   !< colours the field again. The wheel is the legend's while the pointer is over it (a scrolling window does not
   !< scroll). The program keeps its own reset (a button setting vmin and vmax back). Arguments, statuses and modes as
   !< `ip_colormap_legend`; on a failure the range is unchanged and the result false.
   character(len=*), intent(in)            :: id           !< Widget id, unique in the window (not shown).
   integer(int32),   intent(in)            :: colormap     !< Colormap (`ip_colormap`).
   real(real64),     intent(inout)         :: vmin         !< Value at the bottom (left); updated by the user.
   real(real64),     intent(inout)         :: vmax         !< Value at the top (right); updated by the user.
   integer(int32),   intent(in), optional  :: levels       !< Discrete bands, in [2, 256] (default: continuous).
   logical,          intent(in), optional  :: horizontal   !< Horizontal bar (default: vertical).
   real(real64),     intent(in), optional  :: width        !< Width [pixels].
   real(real64),     intent(in), optional  :: height       !< Height [pixels].
   character(len=*), intent(in), optional  :: label_format !< printf format of one real, the values, or text
                                                           !< (default, and '': '%g').
   character(len=*), intent(in), optional  :: scale        !< 'linear' (default), 'log', 'symlog'.
   integer(int32),   intent(out), optional :: stat         !< Status.
   logical                                 :: changed      !< The user changed the range on this frame.
   real(real64)                            :: range(2)     !< The range after this frame's input.

   call legend('ip_colormap_legend_edit', id, colormap, vmin, vmax, levels, horizontal, width, height, label_format, &
               scale, .true., range, changed, stat)
   if (changed) then
      vmin = range(1)
      vmax = range(2)
   endif
   endfunction ip_colormap_legend_edit

   recursive subroutine legend(caller, id, colormap, vmin, vmax, levels, horizontal, width, height, label_format, scale, &
                               interactive, range, changed, stat)
   !< The legend of `ip_colormap_legend` and `ip_colormap_legend_edit`: arguments checked, then drawn natively.
   character(len=*), intent(in)            :: caller       !< The procedure, for the messages.
   character(len=*), intent(in)            :: id           !< Widget id.
   integer(int32),   intent(in)            :: colormap     !< Colormap.
   real(real64),     intent(in)            :: vmin         !< Value at the bottom (left).
   real(real64),     intent(in)            :: vmax         !< Value at the top (right).
   integer(int32),   intent(in), optional  :: levels       !< Bands.
   logical,          intent(in), optional  :: horizontal   !< Horizontal bar.
   real(real64),     intent(in), optional  :: width        !< Width [pixels].
   real(real64),     intent(in), optional  :: height       !< Height [pixels].
   character(len=*), intent(in), optional  :: label_format !< printf format, or text.
   character(len=*), intent(in), optional  :: scale        !< Scale name.
   logical,          intent(in)            :: interactive  !< Dragged and scrolled by the user.
   real(real64),     intent(out)           :: range(2)     !< The range after this frame's input.
   logical,          intent(out)           :: changed      !< The user changed it.
   integer(int32),   intent(out), optional :: stat         !< Status.
   integer(c_int)                          :: code         !< Scale: 0 linear, 1 log, 2 symlog.
   real(real64)                            :: lo, hi       !< The range, edited.
   character(len=12)                       :: text         !< A number, printed.

   range = [vmin, vmax]
   changed = .false.
   if (refused(caller, stat)) return ! a task does not draw
   if (present(label_format)) then
      ! as documented since v0.3.0: '' is the default format, a text without conversion is printed as it is
      if (format_refused(caller, 'label_format', label_format, FORMAT_REAL, stat, text=.true.)) return
   endif
   if (.not. field_scale_ok(caller, scale, code, stat)) return
   if (present(levels)) then
      if (levels < 2_int32 .or. levels > 256_int32) then
         call figure_fail(FIG_ERR_ARGUMENT, caller//': levels must be in [2, 256]', stat)
         return
      endif
   endif
   ! fig_colormap_legend's refusals, its messages (ip_colormap_legend's for both)
   if (colormap < 0_int32 .or. colormap >= int(ImPlot_GetColormapCount(), int32)) then
      write(text, '(I0)') colormap
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_colormap_legend: the colormap '//trim(text)//' is not registered (see '// &
                       'ip_colormap)', stat)
      return
   endif
   if (.not. ieee_is_finite(vmin) .or. .not. ieee_is_finite(vmax) .or. vmin == vmax) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_colormap_legend: vmin and vmax must be finite and different', stat)
      return
   endif
   if (code == 1_c_int .and. (vmin <= 0.0_real64 .or. vmax <= 0.0_real64)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_colormap_legend: a log scale needs vmin and vmax above 0', stat)
      return
   endif
   if (interactive) then
      lo = vmin
      hi = vmax
      changed = pf_colormap_legend_edit(id, cm_frame_id(colormap), lo, hi, levels, horizontal, width, height, legend_format(), &
                                        scale)
      if (changed) range = [lo, hi]
   else
      call pf_colormap_legend(id, cm_frame_id(colormap), vmin, vmax, levels, horizontal, width, height, legend_format(), scale)
   endif
   call figure_check(FIG_OK, stat)
   contains
      function legend_format() result(f)
      !< The labels' format: the given one, '' (the default) when absent.
      character(len=:), allocatable :: f !< Format.

      f = ''
      if (present(label_format)) f = label_format
      endfunction legend_format
   endsubroutine legend

   ! fields through a colormap

   recursive subroutine ip_field_image_r32(label, f, x0, x1, y0, y1, colormap, vmin, vmax, scale, nan_color, changed, &
                                           range, stat)
   !< The field f(i, j) through a colormap, as one image over [x0, x1] x [y0, y1] of the current plot: value (i, j) is
   !< the pixel in the i-th of size(f, 1) columns along x and the j-th of size(f, 2) rows along y, j = 1 at y0 (read
   !< in place, column-major as Fortran stores it). Coloured into a texture kept between frames (cached by the label's
   !< id) and coloured again only when `changed` is true or the array (address, shape), `vmin`, `vmax`, `colormap`,
   !< `scale` or `nan_color` differ from the last colouring; a texture not drawn for 10 s is released. Single
   !< precision. See plots.md, "Fields".
   character(len=*), intent(in)                     :: label        !< Legend label (also the cache's id).
   real(real32),     intent(in), contiguous, target :: f(:,:)       !< Field: f(i, j), i along x, j along y.
   real(real64),     intent(in)                     :: x0           !< Left edge of the first column [plot units].
   real(real64),     intent(in)                     :: x1           !< Right edge of the last column [plot units].
   real(real64),     intent(in)                     :: y0           !< Bottom edge of row 1 [plot units].
   real(real64),     intent(in)                     :: y1           !< Top edge of the last row [plot units].
   integer(int32),   intent(in), optional           :: colormap     !< Colormap (`ip_colormap`; default: Viridis).
   real(real64),     intent(in), optional           :: vmin         !< Value at the colormap's bottom (default: the
                                                                    !< smallest finite value, positive on 'log').
   real(real64),     intent(in), optional           :: vmax         !< Value at its top (default: the largest).
   character(len=*), intent(in), optional           :: scale        !< 'linear' (default), 'log', 'symlog'.
   real(real64),     intent(in), optional           :: nan_color(:) !< Colour of NaN and infinite values (and of values
                                                                    !< <= 0 on 'log'), RGBA in [0, 1] (default:
                                                                    !< transparent).
   logical,          intent(in), optional           :: changed      !< The values changed since the last frame
                                                                    !< (default: false; FIGURE cannot see a change in
                                                                    !< place).
   real(real64),     intent(out), optional          :: range(2)     !< The range the colours were computed for.
   integer(int32),   intent(out), optional          :: stat         !< Status.

   if (.not. field_checked('ip_field_image', size(f, 1, kind=int64), size(f, 2, kind=int64), x0, x1, y0, y1, colormap, &
                           vmin, vmax, scale, nan_color, range, stat)) return
   if (size(f, 1) == 0 .or. size(f, 2) == 0) then ! nothing to draw
      call figure_check(FIG_OK, stat)
      return
   endif
   call pf_field_image(label, f, x0, x1, y0, y1, field_cmap(colormap), vmin, vmax, scale, nan_color, changed, range)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_field_image_r32

   recursive subroutine ip_field_image_r64(label, f, x0, x1, y0, y1, colormap, vmin, vmax, scale, nan_color, changed, &
                                           range, stat)
   !< The field f(i, j) through a colormap, as `ip_field_image_r32`; double precision.
   character(len=*), intent(in)                     :: label        !< Legend label (also the cache's id).
   real(real64),     intent(in), contiguous, target :: f(:,:)       !< Field: f(i, j), i along x, j along y.
   real(real64),     intent(in)                     :: x0           !< Left edge of the first column [plot units].
   real(real64),     intent(in)                     :: x1           !< Right edge of the last column [plot units].
   real(real64),     intent(in)                     :: y0           !< Bottom edge of row 1 [plot units].
   real(real64),     intent(in)                     :: y1           !< Top edge of the last row [plot units].
   integer(int32),   intent(in), optional           :: colormap     !< Colormap (`ip_colormap`; default: Viridis).
   real(real64),     intent(in), optional           :: vmin         !< Value at the colormap's bottom (default: the
                                                                    !< smallest finite value, positive on 'log').
   real(real64),     intent(in), optional           :: vmax         !< Value at its top (default: the largest).
   character(len=*), intent(in), optional           :: scale        !< 'linear' (default), 'log', 'symlog'.
   real(real64),     intent(in), optional           :: nan_color(:) !< Colour of NaN and infinite values (and of values
                                                                    !< <= 0 on 'log'), RGBA in [0, 1] (default:
                                                                    !< transparent).
   logical,          intent(in), optional           :: changed      !< The values changed since the last frame
                                                                    !< (default: false).
   real(real64),     intent(out), optional          :: range(2)     !< The range the colours were computed for.
   integer(int32),   intent(out), optional          :: stat         !< Status.

   if (.not. field_checked('ip_field_image', size(f, 1, kind=int64), size(f, 2, kind=int64), x0, x1, y0, y1, colormap, &
                           vmin, vmax, scale, nan_color, range, stat)) return
   if (size(f, 1) == 0 .or. size(f, 2) == 0) then ! nothing to draw
      call figure_check(FIG_OK, stat)
      return
   endif
   call pf_field_image(label, f, x0, x1, y0, y1, field_cmap(colormap), vmin, vmax, scale, nan_color, changed, range)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_field_image_r64

   recursive function field_checked(caller, nx, ny, x0, x1, y0, y1, colormap, vmin, vmax, scale, nan_color, range, &
                                    stat) result(ok)
   !< `ip_field_image`'s arguments checked (as the current path's, in its order); `range` set to 0 first.
   character(len=*), intent(in)            :: caller       !< The procedure, for the messages.
   integer(int64),   intent(in)            :: nx           !< size(f, 1).
   integer(int64),   intent(in)            :: ny           !< size(f, 2).
   real(real64),     intent(in)            :: x0           !< Left edge.
   real(real64),     intent(in)            :: x1           !< Right edge.
   real(real64),     intent(in)            :: y0           !< Bottom edge.
   real(real64),     intent(in)            :: y1           !< Top edge.
   integer(int32),   intent(in), optional  :: colormap     !< Colormap.
   real(real64),     intent(in), optional  :: vmin         !< Colormap bottom.
   real(real64),     intent(in), optional  :: vmax         !< Colormap top.
   character(len=*), intent(in), optional  :: scale        !< Scale name.
   real(real64),     intent(in), optional  :: nan_color(:) !< NaN colour.
   real(real64),     intent(out), optional :: range(2)     !< The range applied.
   integer(int32),   intent(out), optional :: stat         !< Status.
   logical                                 :: ok           !< Drawable.
   integer(c_int)                          :: cmap         !< Colormap id.
   integer(c_int)                          :: code         !< Scale code.

   ok = .false.
   if (present(range)) range = 0.0_real64
   if (refused(caller, stat)) return ! a task does not draw
   if (plot_refused(caller, .false., stat)) return
   if (.not. colormap_ok(caller, colormap, cmap, stat)) return
   if (.not. field_scale_ok(caller, scale, code, stat)) return
   if (.not. ieee_is_finite(x0) .or. .not. ieee_is_finite(x1) .or. .not. ieee_is_finite(y0) .or. &
       .not. ieee_is_finite(y1) .or. x0 == x1 .or. y0 == y1) then
      call figure_fail(FIG_ERR_ARGUMENT, caller//': the edges must be finite, x0 /= x1 and y0 /= y1', stat)
      return
   endif
   if (nx > 16384_int64 .or. ny > 16384_int64) then
      call figure_fail(FIG_ERR_ARGUMENT, caller//': a field of at most 16384 values a side (a texture)', stat)
      return
   endif
   if (present(vmin)) then
      if (.not. ieee_is_finite(vmin)) then
         call figure_fail(FIG_ERR_ARGUMENT, caller//': vmin must be finite', stat)
         return
      endif
   endif
   if (present(vmax)) then
      if (.not. ieee_is_finite(vmax)) then
         call figure_fail(FIG_ERR_ARGUMENT, caller//': vmax must be finite', stat)
         return
      endif
   endif
   if (present(vmin) .and. present(vmax)) then
      if (vmin == vmax) then
         call figure_fail(FIG_ERR_ARGUMENT, caller//': vmin and vmax must differ', stat)
         return
      endif
   endif
   if (code == 1_c_int) then
      if (present(vmin)) then
         if (vmin <= 0.0_real64) then
            call figure_fail(FIG_ERR_ARGUMENT, caller//": a log scale needs vmin above 0", stat)
            return
         endif
      endif
      if (present(vmax)) then
         if (vmax <= 0.0_real64) then
            call figure_fail(FIG_ERR_ARGUMENT, caller//": a log scale needs vmax above 0", stat)
            return
         endif
      endif
   endif
   if (present(nan_color)) then
      if (size(nan_color) /= 4) then
         call figure_fail(FIG_ERR_ARGUMENT, caller//': nan_color needs 4 components (RGBA)', stat)
         return
      endif
      if (any(.not. (nan_color >= 0.0_real64 .and. nan_color <= 1.0_real64))) then
         call figure_fail(FIG_ERR_ARGUMENT, caller//': nan_color components must be in [0, 1]', stat)
         return
      endif
   endif
   ok = .true.
   endfunction field_checked

   function field_cmap(colormap) result(cm)
   !< A field's colormap, the frame's: the given one, or ImPlot's Viridis.
   integer(int32), intent(in), optional :: colormap !< Colormap.
   integer(int32)                       :: cm       !< Map.

   cm = int(ImPlotColormap_Viridis, int32)
   if (present(colormap)) cm = cm_frame_id(colormap)
   endfunction field_cmap

   function field_scale_ok(caller, scale, code, stat) result(ok)
   !< The scale of a field or a legend: 0 linear (also when absent), 1 log, 2 symlog; false (reported,
   !< `FIG_ERR_ARGUMENT`) for any other name ('time' included: a field has no time scale).
   character(len=*), intent(in)            :: caller !< The procedure.
   character(len=*), intent(in),  optional :: scale  !< 'linear', 'log', 'symlog'.
   integer(c_int),   intent(out)           :: code   !< Scale code.
   integer(int32),   intent(out), optional :: stat   !< Status, on a refusal.
   logical                                 :: ok     !< Not refused.

   ok = .true.
   code = 0_c_int
   if (.not. present(scale)) return
   select case (trim(scale))
   case ('linear')
      code = 0_c_int
   case ('log')
      code = 1_c_int
   case ('symlog')
      code = 2_c_int
   case default
      ok = .false.
      call figure_fail(FIG_ERR_ARGUMENT, caller//": unknown scale '"//scale//"' ('linear', 'log' or 'symlog')", stat)
   endselect
   endfunction field_scale_ok

   ! colormaps by name

   recursive function ip_colormap(name, levels, stat) result(id)
   !< The colormap `name` as an ImPlot id, for the `colormap` argument of `ip_heatmap` and `ip_colormap_scale`: a
   !< bundled map (`'cividis'`, `'batlow'`, `'cool-warm'`, ...), one of ImPlot's own (`'Viridis'`, `'Jet'`, ...) or a
   !< map loaded with `ip_load_colormap`; names are case-sensitive, their trailing blanks ignored (`ip_colormap_names`
   !< lists them). `<name>_r` is the map reversed; `levels` gives that many discrete bands of equal width, each
   !< coloured as the map at its centre. A map is registered with ImPlot (`AddColormap`) at its first use, and the same
   !< id is returned after; ids hold for the application's life (a new `init` registers the maps again). Statuses:
   !< `FIG_ERR_ARGUMENT` for an unknown name or `levels` outside [2, 256], `FIG_ERR_STATE` before `init*` and from a
   !< task; the id is then -1 (and `ip_heatmap` refuses it). The same in every mode.
   character(len=*), intent(in)            :: name   !< Colormap name; `<name>_r`: reversed.
   integer(int32),   intent(in),  optional :: levels !< Discrete bands, in [2, 256] (default: continuous).
   integer(int32),   intent(out), optional :: stat   !< Status.
   integer(int32)                          :: id     !< ImPlot colormap id (-1 on a failure).
   integer(c_int)                          :: n      !< Bands (0: continuous).
   integer(c_int)                          :: c_id   !< The native id (ImPlot3D's registry, until the 3-D switch).
   integer(c_int)                          :: s      !< The native status.
   character(len=12)                       :: text   !< A number, printed.

   id = -1_int32
   if (figure_refused('ip_colormap', stat)) return ! the registry belongs to the main thread
   n = 0_c_int
   if (present(levels)) then
      if (levels < 2_int32 .or. levels > 256_int32) then
         write(text, '(I0)') levels
         call figure_fail(FIG_ERR_ARGUMENT, 'ip_colormap: levels must be in [2, 256], got '//trim(text), stat)
         return
      endif
      n = int(levels, c_int)
   endif
   c_id = -1_c_int
   s = fig_colormap(name, len_trim(name, c_int), n, c_id) ! the native refusals and messages; the map registered there
   if (s /= FIG_OK) then                                  ! too (ImPlot3D's surfaces, until the 3-D switch)
      call figure_check(s, stat)
      return
   endif
   id = int(c_id, int32) ! the native registry's id (ImPlot3D's, the 3-D views', as on the current path) ...
   if (n > 0_c_int) then ! ... the frame's map recorded for it
      call cm_frame_id_set(id, cm_colormap(name(1:len_trim(name)), int(n, int32)))
   else
      call cm_frame_id_set(id, cm_colormap(name(1:len_trim(name))))
   endif
   call figure_check(FIG_OK, stat)
   endfunction ip_colormap

   recursive subroutine ip_load_colormap(name, file, stat)
   !< Read a colormap from `file` and register it under `name` for `ip_colormap`. The file is a CSV table, one colour a
   !< row, `r, g, b` (or `x, r, g, b`, with `x` a position: resampled to 256 uniform positions), separated by commas,
   !< semicolons, blanks or tabs, components in [0, 1] (or [0, 255] when one exceeds 1), `#` comments and a header line
   !< allowed; or a ParaView JSON preset (a file of ParaView's "Export" of presets, or one preset): the one whose
   !< `Name` is `name`, or the only one, its `RGBPoints` sampled at 256 positions in its `ColorSpace` (RGB, Lab,
   !< Diverging, HSV or Step). The map is kept for the program's life. Statuses: `FIG_ERR_FAILED` if the file cannot be
   !< read, `FIG_ERR_ARGUMENT` if it is malformed (the message gives the line) or the name is taken (a map, or the
   !< reverse of one: ImPlot cannot replace a colormap), empty, holds `|` or starts with `'FIGURE '`; `FIG_ERR_STATE`
   !< from a task. The same in every mode, before `init*` too.
   character(len=*), intent(in)            :: name !< Name to register the map under.
   character(len=*), intent(in)            :: file !< CSV table or ParaView JSON preset.
   integer(int32),   intent(out), optional :: stat !< Status.
   integer(int32)                          :: st   !< The frame's status.
   character(len=:), allocatable           :: err  !< ... its message.
   integer(c_int)                          :: s    !< The native status.

   if (figure_refused('ip_load_colormap', stat)) return ! the registry belongs to the main thread
   s = fig_load_colormap(name, len_trim(name, c_int), file, len_trim(file, c_int)) ! the native refusals and messages;
   if (s /= FIG_OK) then                                                           ! the map there too (until the 3-D
      call figure_check(s, stat)                                                   ! switch, and the gradient editor)
      return
   endif
   call cm_load(name, file, st, err)
   if (st /= 0_int32) then
      call figure_fail(int(st, c_int), err, stat)
      return
   endif
   call figure_check(FIG_OK, stat)
   endsubroutine ip_load_colormap

   recursive function ig_gradient_edit(id, colormap, width, height, stat) result(changed)
   !< A gradient editor of the colormap named `colormap` (ImGuizmo's ImGradient): the map's strip, its stops below it
   !< (a square each, of the stop's colour), and on their right the selected stop's colour and a Remove button. A stop
   !< dragged along the strip moves, a double click on the stops' row adds one there (the map's colour at that point),
   !< a click selects one, whose colour the colour button changes (Dear ImGui's picker) and Remove removes (a map keeps
   !< two). Each change resamples the map from its stops, linearly between them and constant beyond the first and the
   !< last: its table (256 colours for a bundled or loaded map, its keys for one of ImPlot's) and every variant
   !< registered (`<name>_r`, discrete levels), so heatmaps, fields, legends and 3-D views drawn with it show the new
   !< colours from this frame on (fields and views are coloured again). True on the frame the map changed. The stops
   !< are those `ip_colormap_stops` gives; the edit lasts for the program's life. An item of the current window.
   !< Sizes [pixels]: `width` positive given, else the space left plus it (default 0: all of it); `height` the strip
   !< and the stops' row (default: two rows of a frame). Statuses: `FIG_ERR_ARGUMENT` for an unknown name, a reversed
   !< (`_r`) or discrete map or a qualitative one (Deep, Dark, Pastel, Paired: lists of colours); `FIG_ERR_STATE`
   !< outside a frame and from a task. The same in every mode.
   character(len=*), intent(in)            :: id       !< Widget id, unique in the window (not shown).
   character(len=*), intent(in)            :: colormap !< Colormap name (`ip_colormap_names`).
   real(real64),     intent(in),  optional :: width    !< Width [pixels].
   real(real64),     intent(in),  optional :: height   !< Height [pixels].
   integer(int32),   intent(out), optional :: stat     !< Status.
   logical                                 :: changed  !< The map changed on this frame.
   real(real32)                            :: w        !< Width.
   real(real32)                            :: h        !< Height.
   integer(int32)                          :: st       !< Status.
   character(len=:), allocatable           :: err      !< Message.

   changed = .false.
   if (refused('ig_gradient_edit', stat)) return
   w = 0.0_real32
   if (present(width)) w = real(width, real32)
   h = 0.0_real32
   if (present(height)) h = real(height, real32)
   call gz_gradient_edit(id, colormap(1:len_trim(colormap)), w, h, changed, st, err) ! figure_gradient_edit's widget
   if (st /= FIG_OK) then
      call figure_fail(int(st, c_int), err, stat)
      return
   endif
   if (changed) call edited(colormap(1:len_trim(colormap))) ! its stops to the native registry
   call figure_check(FIG_OK, stat)
   endfunction ig_gradient_edit

   subroutine edited(name)
   !< The stops the gradient editor gave a map (the frame's registry, `cm_gradient_slot`, in the editor's order), given
   !< to the native registry (`fig_colormap_set_stops`), which the 3-D views' colouring reads.
   character(len=*), intent(in)  :: name     !< The map.
   real(real32),     allocatable :: s(:,:)   !< Stops.
   real(c_double),   allocatable :: pos(:)   !< Positions.
   real(c_double),   allocatable :: rgb(:)   !< Colours.
   integer(int32)                :: g, n, k  !< Slot, stops, counter.
   integer(int32)                :: st       !< Status.
   integer(c_int)                :: c, s_    !< Changed, status.
   character(len=:), allocatable :: err      !< Message.

   g = cm_gradient_slot(name, st, err)
   if (st /= FIG_OK) return
   n = cm_gradient_size(g)
   allocate(s(4, n), pos(n), rgb(3 * n))
   call cm_gradient_get(g, s)
   do k = 1_int32, n
      pos(k) = real(s(4, k), c_double)
      rgb(3 * k - 2:3 * k) = real(s(1:3, k), c_double)
   enddo
   s_ = fig_colormap_set_stops(name, len(name, c_int), pos, rgb, int(n, c_int), c)
   endsubroutine edited

   recursive subroutine ip_colormap_stops(name, positions, colours, stat)
   !< The stops of the colormap `name`, sorted by position: as `ig_gradient_edit` shows and edits them. A map not
   !< edited yet has stops derived from its colours: every key of a short table (ImPlot's own maps, a CSV of up to 16
   !< rows), else some of its 256 colours, each the farthest from the last between which the map is linear within 2
   !< levels of 0-255 per channel (10 to 21 stops for the bundled maps). A CSV file of the rows `x, r, g, b` written
   !< from them is read back by `ip_load_colormap` as the same map. Statuses as `ig_gradient_edit` (`FIG_ERR_STATE`
   !< before `init*` and from a task); on a failure the arrays have size 0.
   character(len=*),          intent(in)            :: name         !< Colormap name.
   real(real64), allocatable, intent(out)           :: positions(:) !< Positions, in [0, 1].
   real(real64), allocatable, intent(out)           :: colours(:,:) !< Colours, `colours(:, k)` RGB in [0, 1].
   integer(int32),            intent(out), optional :: stat         !< Status.
   integer(c_int)                                   :: n            !< Stops.
   integer(c_int)                                   :: status       !< Native status.
   real(c_double)                                   :: p(1)         !< Probe.
   real(c_double)                                   :: q(3)         !< Probe.
   integer(int32)                                   :: st           !< The frame's status.
   character(len=:), allocatable                    :: err          !< ... its message.
   real(real64), allocatable                        :: pos(:)       !< The stops' positions, until all is read.
   real(real64), allocatable                        :: rgb(:,:)     !< Their colours, until all is read.

   allocate(positions(0), colours(3, 0))
   if (figure_refused('ip_colormap_stops', stat)) return
   n = 0_c_int
   status = fig_colormap_stops(name, len_trim(name, c_int), p, q, 0_c_int, n) ! the native refusals and messages
   if (status /= FIG_OK) then
      call figure_check(status, stat)
      return
   endif
   call cm_stops(name, pos, rgb, st, err) ! the frame's stops (the same, edits included)
   if (st /= 0_int32) then
      call figure_fail(int(st, c_int), err, stat)
      return
   endif
   call move_alloc(pos, positions)
   call move_alloc(rgb, colours)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_colormap_stops

   recursive subroutine ip_colormap_names(names)
   !< The names `ip_colormap` knows: the bundled maps (alphabetical), ImPlot's own (in ImPlot's order), then the maps
   !< loaded with `ip_load_colormap` (in load order); reversed and discrete maps are not listed. From a task: none.
   character(len=:), allocatable, intent(out) :: names(:) !< Names (as long as the longest).
   integer(int32)                             :: n        !< Names.
   integer(int32)                             :: longest  !< The longest one.
   integer(int32)                             :: i        !< Counter.

   n = 0_int32
   if (.not. figure_refused('ip_colormap_names')) n = cm_list_count()
   longest = 1_int32
   do i = 1_int32, n
      longest = max(longest, len(cm_list_name(i), kind=int32))
   enddo
   allocate(character(len=longest) :: names(n))
   do i = 1_int32, n
      names(i) = cm_list_name(i)
   enddo
   endsubroutine ip_colormap_names

   ! annotations and drag tools

   recursive subroutine ip_annotation(x, y, text, color, offset, stat)
   !< A text at the point (x, y) of the current plot (between `ip_begin_plot` and `ip_end_plot`), drawn when the plot
   !< ends, over its items and kept inside the plot area. Without `color`: the text alone, in the plot's text colour; with
   !< it: in a box of that colour, the text black or white for contrast. `offset` moves it [pixels] from the point, with a
   !< leader line to it (x right, y down); a zero component centres it on the point along that axis (the default).
   !< Statuses: `FIG_ERR_ARGUMENT` for a colour of size /= 4 or an offset of size /= 2, `FIG_ERR_STATE` outside a plot
   !< and from a task.
   real(real64),     intent(in)            :: x         !< Abscissa [plot units].
   real(real64),     intent(in)            :: y         !< Ordinate [plot units].
   character(len=*), intent(in)            :: text      !< Text (UTF-8).
   real(real64),     intent(in), optional  :: color(:)  !< Box colour, RGBA in [0, 1] (default: no box).
   real(real64),     intent(in), optional  :: offset(:) !< Offset [pixels], (x right, y down) (default: centred).
   integer(int32),   intent(out), optional :: stat      !< Status.
   integer(int32)                          :: on(6)     !< Axes set up.
   integer(int32)                          :: sc(6)     !< Their scales.

   if (refused('ip_annotation', stat)) return ! a task does not draw
   if (.not. rgba_ok(color)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_annotation: a colour needs 4 components (RGBA)', stat)
      return
   endif
   if (present(offset)) then
      if (size(offset) /= 2) then
         call figure_fail(FIG_ERR_ARGUMENT, 'ip_annotation: the offset needs 2 components (x, y)', stat)
         return
      endif
   endif
   if (pf_plot_state(on, sc) == 0_int32) then ! fig_plot_annotation's refusal
      call figure_fail(FIG_ERR_STATE, 'ip_annotation: no plot is being declared (between ip_begin_plot and '// &
                       'ip_end_plot)', stat)
      return
   endif
   call pf_annotation(x, y, text, color, offset) ! (colour and offset as floats, as the native layer passes them)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_annotation

   recursive function ip_drag_line_x(id, x, color, thickness, stat) result(moved)
   !< A vertical line at `x` in the current plot that the user drags along x (between `ip_begin_plot` and
   !< `ip_end_plot`): `x` is updated in place, and the result is true in the frames it moves. `id` tells the drag
   !< tools of a plot apart (any integer, unique in the plot). Statuses: `FIG_ERR_ARGUMENT` for a colour of size /= 4,
   !< `FIG_ERR_STATE` outside a plot (a usage error, from v0.4.0) and from a task.
   integer(int32),   intent(in)            :: id        !< Id, unique among the plot's drag tools.
   real(real64),     intent(inout), target :: x         !< Position [plot units].
   real(real64),     intent(in), optional  :: color(:)  !< Colour, RGBA in [0, 1] (default: the text colour).
   real(real64),     intent(in), optional  :: thickness !< Line thickness [pixels] (default 1).
   integer(int32),   intent(out), optional :: stat      !< Status.
   logical                                 :: moved     !< Moved by the user in this frame.

   moved = .false.
   if (refused('ip_drag_line_x', stat)) return ! a task does not draw
   if (.not. drag_ok('ip_drag_line_x', color, stat)) return
   if (plot_refused('ip_drag_line_x', .false., stat)) return
   moved = pf_drag_line_x(id, x, color, thickness)
   call figure_check(FIG_OK, stat)
   endfunction ip_drag_line_x

   recursive function ip_drag_line_y(id, y, color, thickness, stat) result(moved)
   !< A horizontal line at `y` in the current plot that the user drags along y: as `ip_drag_line_x`.
   integer(int32),   intent(in)            :: id        !< Id, unique among the plot's drag tools.
   real(real64),     intent(inout), target :: y         !< Position [plot units].
   real(real64),     intent(in), optional  :: color(:)  !< Colour, RGBA in [0, 1] (default: the text colour).
   real(real64),     intent(in), optional  :: thickness !< Line thickness [pixels] (default 1).
   integer(int32),   intent(out), optional :: stat      !< Status.
   logical                                 :: moved     !< Moved by the user in this frame.

   moved = .false.
   if (refused('ip_drag_line_y', stat)) return ! a task does not draw
   if (.not. drag_ok('ip_drag_line_y', color, stat)) return
   if (plot_refused('ip_drag_line_y', .false., stat)) return
   moved = pf_drag_line_y(id, y, color, thickness)
   call figure_check(FIG_OK, stat)
   endfunction ip_drag_line_y

   recursive function ip_drag_point(id, x, y, color, radius, stat) result(moved)
   !< A point at (x, y) in the current plot that the user drags: as `ip_drag_line_x`, both coordinates updated.
   integer(int32),   intent(in)            :: id       !< Id, unique among the plot's drag tools.
   real(real64),     intent(inout), target :: x        !< Abscissa [plot units].
   real(real64),     intent(inout), target :: y        !< Ordinate [plot units].
   real(real64),     intent(in), optional  :: color(:) !< Colour, RGBA in [0, 1] (default: the text colour).
   real(real64),     intent(in), optional  :: radius   !< Radius [pixels] (default 4).
   integer(int32),   intent(out), optional :: stat     !< Status.
   logical                                 :: moved    !< Moved by the user in this frame.

   moved = .false.
   if (refused('ip_drag_point', stat)) return ! a task does not draw
   if (.not. drag_ok('ip_drag_point', color, stat)) return
   if (plot_refused('ip_drag_point', .false., stat)) return
   moved = pf_drag_point(id, x, y, color, radius)
   call figure_check(FIG_OK, stat)
   endfunction ip_drag_point

   ! reading a plot: the pointer, conversions, the box selection

   recursive function ip_plot_hovered(stat) result(hovered)
   !< Whether the pointer is over the data area of the plot being declared (`IsPlotHovered`), on this frame. Between
   !< `ip_begin_plot` and `ip_end_plot`; it ends the setup. Statuses: `FIG_ERR_STATE` outside a plot, from a task.
   integer(int32), intent(out), optional :: stat    !< Status.
   logical                               :: hovered !< The pointer is over the plot area.

   hovered = .false.
   if (refused('ip_plot_hovered', stat)) return ! a task does not draw
   if (plot_refused('ip_plot_hovered', .false., stat)) return
   hovered = pf_plot_hovered()
   call figure_check(FIG_OK, stat)
   endfunction ip_plot_hovered

   recursive subroutine ip_plot_mouse(x, y, xaxis, yaxis, stat)
   !< The pointer's position in plot units (`GetPlotMousePos`), on the axes the items use now or on `xaxis`/`yaxis`:
   !< wherever the pointer is (`ip_plot_hovered` tells whether it is over the plot); `-huge(1.0_real64)` for both when
   !< there is no pointer (no mouse event yet). Between `ip_begin_plot` and `ip_end_plot`; it ends the setup.
   !< Statuses: `FIG_ERR_ARGUMENT` for a name that is not an axis of its direction; `FIG_ERR_STATE` outside a plot,
   !< for an axis not set up, from a task (x and y are then 0).
   real(real64),     intent(out)           :: x     !< Abscissa [x axis units].
   real(real64),     intent(out)           :: y     !< Ordinate [y axis units].
   character(len=*), intent(in),  optional :: xaxis !< 'x1', 'x2' or 'x3' (default: the current one).
   character(len=*), intent(in),  optional :: yaxis !< 'y1', 'y2' or 'y3' (default: the current one).
   integer(int32),   intent(out), optional :: stat  !< Status.
   integer(c_int)                          :: cx    !< ImAxis of x (-1: the current one).
   integer(c_int)                          :: cy    !< ImAxis of y (-1: the current one).

   x = 0.0_real64
   y = 0.0_real64
   if (refused('ip_plot_mouse', stat)) return ! a task does not draw
   if (axes_refused('ip_plot_mouse', xaxis, yaxis, cx, cy, stat)) return
   if (cx >= 0_c_int .and. cy >= 0_c_int) then ! (no pointer: -huge for both, the frame's)
      call pf_plot_mouse(x, y, AXIS_NAMES(cx), AXIS_NAMES(cy))
   elseif (cx >= 0_c_int) then
      call pf_plot_mouse(x, y, xaxis=AXIS_NAMES(cx))
   elseif (cy >= 0_c_int) then
      call pf_plot_mouse(x, y, yaxis=AXIS_NAMES(cy))
   else
      call pf_plot_mouse(x, y)
   endif
   call figure_check(FIG_OK, stat)
   endsubroutine ip_plot_mouse

   recursive subroutine ip_plot_to_pixels(x, y, px, py, xaxis, yaxis, stat)
   !< The display pixel of the plot point (x, y) (`PlotToPixels`), on the axes the items use now or on
   !< `xaxis`/`yaxis`: where `test_click` aims, where `ig_draw_*` draw on the window's layer. Between `ip_begin_plot`
   !< and `ip_end_plot`; it ends the setup. Statuses: `FIG_ERR_ARGUMENT` for a NaN coordinate or a name that is not an
   !< axis of its direction; `FIG_ERR_STATE` outside a plot, for an axis not set up, from a task (px and py are then 0).
   real(real64),     intent(in)            :: x     !< Abscissa [x axis units].
   real(real64),     intent(in)            :: y     !< Ordinate [y axis units].
   real(real64),     intent(out)           :: px    !< Abscissa [pixels], right from the display's left edge.
   real(real64),     intent(out)           :: py    !< Ordinate [pixels], down from the display's top edge.
   character(len=*), intent(in),  optional :: xaxis !< 'x1', 'x2' or 'x3' (default: the current one).
   character(len=*), intent(in),  optional :: yaxis !< 'y1', 'y2' or 'y3' (default: the current one).
   integer(int32),   intent(out), optional :: stat  !< Status.
   integer(c_int)                          :: cx    !< ImAxis of x (-1: the current one).
   integer(c_int)                          :: cy    !< ImAxis of y (-1: the current one).

   px = 0.0_real64
   py = 0.0_real64
   if (refused('ip_plot_to_pixels', stat)) return ! a task does not draw
   if (ieee_is_nan(x) .or. ieee_is_nan(y)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_plot_to_pixels: x and y must not be NaN', stat)
      return
   endif
   if (axes_refused('ip_plot_to_pixels', xaxis, yaxis, cx, cy, stat)) return
   if (cx >= 0_c_int .and. cy >= 0_c_int) then
      call pf_plot_to_pixels(x, y, px, py, AXIS_NAMES(cx), AXIS_NAMES(cy))
   elseif (cx >= 0_c_int) then
      call pf_plot_to_pixels(x, y, px, py, xaxis=AXIS_NAMES(cx))
   elseif (cy >= 0_c_int) then
      call pf_plot_to_pixels(x, y, px, py, yaxis=AXIS_NAMES(cy))
   else
      call pf_plot_to_pixels(x, y, px, py)
   endif
   call figure_check(FIG_OK, stat)
   endsubroutine ip_plot_to_pixels

   recursive subroutine ip_pixels_to_plot(px, py, x, y, xaxis, yaxis, stat)
   !< The plot point at the display pixel (px, py) (`PixelsToPlot`), on the axes the items use now or on
   !< `xaxis`/`yaxis`: the inverse of `ip_plot_to_pixels`. Between `ip_begin_plot` and `ip_end_plot`; it ends the
   !< setup. Statuses: `FIG_ERR_ARGUMENT` for a NaN pixel or a name that is not an axis of its direction;
   !< `FIG_ERR_STATE` outside a plot, for an axis not set up, from a task (x and y are then 0).
   real(real64),     intent(in)            :: px    !< Abscissa [pixels], right from the display's left edge.
   real(real64),     intent(in)            :: py    !< Ordinate [pixels], down from the display's top edge.
   real(real64),     intent(out)           :: x     !< Abscissa [x axis units].
   real(real64),     intent(out)           :: y     !< Ordinate [y axis units].
   character(len=*), intent(in),  optional :: xaxis !< 'x1', 'x2' or 'x3' (default: the current one).
   character(len=*), intent(in),  optional :: yaxis !< 'y1', 'y2' or 'y3' (default: the current one).
   integer(int32),   intent(out), optional :: stat  !< Status.
   integer(c_int)                          :: cx    !< ImAxis of x (-1: the current one).
   integer(c_int)                          :: cy    !< ImAxis of y (-1: the current one).
   real(real64)                            :: fx    !< px as ImPlot takes it (a float).
   real(real64)                            :: fy    !< py, the same.

   x = 0.0_real64
   y = 0.0_real64
   if (refused('ip_pixels_to_plot', stat)) return ! a task does not draw
   if (ieee_is_nan(px) .or. ieee_is_nan(py)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_pixels_to_plot: px and py must not be NaN', stat)
      return
   endif
   if (axes_refused('ip_pixels_to_plot', xaxis, yaxis, cx, cy, stat)) return
   fx = real(real(px, c_float), real64) ! ImPlot_PixelsToPlot_Float: the pixel as a float
   fy = real(real(py, c_float), real64)
   if (cx >= 0_c_int .and. cy >= 0_c_int) then
      call pf_pixels_to_plot(fx, fy, x, y, AXIS_NAMES(cx), AXIS_NAMES(cy))
   elseif (cx >= 0_c_int) then
      call pf_pixels_to_plot(fx, fy, x, y, xaxis=AXIS_NAMES(cx))
   elseif (cy >= 0_c_int) then
      call pf_pixels_to_plot(fx, fy, x, y, yaxis=AXIS_NAMES(cy))
   else
      call pf_pixels_to_plot(fx, fy, x, y)
   endif
   call figure_check(FIG_OK, stat)
   endsubroutine ip_pixels_to_plot

   recursive function ip_plot_selection(xmin, xmax, ymin, ymax, xaxis, yaxis, stat) result(selected)
   !< The box the user is dragging with the right button (ImPlot's box selection, `IsPlotSelected`,
   !< `GetPlotSelection`): true on the frames the box is drawn, with its extent in plot units on the axes the items use
   !< now or on `xaxis`/`yaxis` (a locked axis spans its whole range). When the button is released ImPlot zooms to
   !< the box; a program that takes the box as its own window calls `ip_cancel_selection` on the frame it takes it.
   !< Between `ip_begin_plot` and `ip_end_plot`; it ends the setup. Statuses: `FIG_ERR_ARGUMENT` for a name that is not
   !< an axis of its direction; `FIG_ERR_STATE` outside a plot, for an axis not set up, from a task (the extent is 0).
   real(real64),     intent(out)           :: xmin     !< Left end [x axis units] (0 without a box).
   real(real64),     intent(out)           :: xmax     !< Right end [x axis units].
   real(real64),     intent(out)           :: ymin     !< Bottom end [y axis units].
   real(real64),     intent(out)           :: ymax     !< Top end [y axis units].
   character(len=*), intent(in),  optional :: xaxis    !< 'x1', 'x2' or 'x3' (default: the current one).
   character(len=*), intent(in),  optional :: yaxis    !< 'y1', 'y2' or 'y3' (default: the current one).
   integer(int32),   intent(out), optional :: stat     !< Status.
   logical                                 :: selected !< A box is being dragged.
   integer(c_int)                          :: cx       !< ImAxis of x (-1: the current one).
   integer(c_int)                          :: cy       !< ImAxis of y (-1: the current one).

   selected = .false.
   xmin = 0.0_real64
   xmax = 0.0_real64
   ymin = 0.0_real64
   ymax = 0.0_real64
   if (refused('ip_plot_selection', stat)) return ! a task does not draw
   if (axes_refused('ip_plot_selection', xaxis, yaxis, cx, cy, stat)) return
   if (cx >= 0_c_int .and. cy >= 0_c_int) then
      selected = pf_plot_selection(xmin, xmax, ymin, ymax, AXIS_NAMES(cx), AXIS_NAMES(cy))
   elseif (cx >= 0_c_int) then
      selected = pf_plot_selection(xmin, xmax, ymin, ymax, xaxis=AXIS_NAMES(cx))
   elseif (cy >= 0_c_int) then
      selected = pf_plot_selection(xmin, xmax, ymin, ymax, yaxis=AXIS_NAMES(cy))
   else
      selected = pf_plot_selection(xmin, xmax, ymin, ymax)
   endif
   call figure_check(FIG_OK, stat)
   endfunction ip_plot_selection

   recursive subroutine ip_cancel_selection(stat)
   !< End the box the user is dragging (`CancelPlotSelection`) without the zoom ImPlot applies on release: the
   !< program keeps the box (`ip_plot_selection` on this frame) as its own choice. Nothing happens without a box.
   !< Between `ip_begin_plot` and `ip_end_plot`; it ends the setup. Statuses: `FIG_ERR_STATE` outside a plot, from a
   !< task.
   integer(int32), intent(out), optional :: stat !< Status.

   if (refused('ip_cancel_selection', stat)) return ! a task does not draw
   if (plot_refused('ip_cancel_selection', .false., stat)) return
   call pf_cancel_selection()
   call figure_check(FIG_OK, stat)
   endsubroutine ip_cancel_selection

   ! marks in a plot: a rectangle the user drags, tags, text

   recursive function ip_drag_rect(id, xmin, xmax, ymin, ymax, color, stat) result(moved)
   !< A rectangle [xmin, xmax] x [ymin, ymax] in the current plot that the user drags (`DragRect`): by its centre to
   !< move it, by a corner or an edge to resize it; the four values are updated in place and the result is true in the
   !< frames it changes. An edge dragged past the opposite one crosses it while the button is held; the values are put
   !< in order when it is released. A rectangle of no width and no height cannot be grabbed. `id` as the other drag
   !< tools. Statuses: `FIG_ERR_ARGUMENT` for a colour of size /= 4 or a NaN; `FIG_ERR_STATE` outside a plot, from a
   !< task.
   integer(int32),   intent(in)            :: id       !< Id, unique among the plot's drag tools.
   real(real64),     intent(inout), target :: xmin     !< Left edge [plot units].
   real(real64),     intent(inout), target :: xmax     !< Right edge [plot units].
   real(real64),     intent(inout), target :: ymin     !< Bottom edge [plot units].
   real(real64),     intent(inout), target :: ymax     !< Top edge [plot units].
   real(real64),     intent(in), optional  :: color(:) !< Colour, RGBA in [0, 1] (default: the text colour).
   integer(int32),   intent(out), optional :: stat     !< Status.
   logical                                 :: moved    !< Moved or resized by the user in this frame.

   moved = .false.
   if (refused('ip_drag_rect', stat)) return ! a task does not draw
   if (.not. drag_ok('ip_drag_rect', color, stat)) return
   if (ieee_is_nan(xmin) .or. ieee_is_nan(xmax) .or. ieee_is_nan(ymin) .or. ieee_is_nan(ymax)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_drag_rect: an edge is NaN', stat)
      return
   endif
   if (plot_refused('ip_drag_rect', .false., stat)) return
   moved = pf_drag_rect(id, xmin, xmax, ymin, ymax, color) ! (the edges put in order once released: the frame's)
   call figure_check(FIG_OK, stat)
   endfunction ip_drag_rect

   recursive function ip_drop_target(type, payload, axis, legend, x, y, stat) result(dropped)
   !< Make the plot being declared a target of drag and drop for payloads of type `type` (as `ig_drop_target`): true
   !< on the frame one is dropped, `payload` then holding it and (x, y) the point it was dropped at, in plot units.
   !< With `axis` (`'x1'`, ..., `'y3'`) only that axis receives it, with `legend` only the legend. Call it after the
   !< plot's items, before `ip_end_plot`, every frame. Statuses: `FIG_ERR_ARGUMENT` for a bad type (as
   !< `ig_drag_source`), an unknown axis or both `axis` and `legend`; `FIG_ERR_STATE` outside a plot, for an axis not
   !< set up, or from a task.
   character(len=*),              intent(in)              :: type    !< Type accepted (1 to 32 characters).
   character(len=:), allocatable, intent(inout)           :: payload !< The payload dropped (unchanged otherwise).
   character(len=*),              intent(in),    optional :: axis    !< Only this axis receives (default: the plot).
   logical,                       intent(in),    optional :: legend  !< Only the legend receives (default: false).
   real(real64),                  intent(inout), optional :: x       !< Abscissa of the drop [plot units].
   real(real64),                  intent(inout), optional :: y       !< Ordinate of the drop [plot units].
   integer(int32),                intent(out),   optional :: stat    !< Status.
   logical                                                :: dropped !< A payload was dropped this frame.
   integer(c_int)                                         :: code    !< ImAxis.
   logical                                                :: leg     !< The legend receives.

   dropped = .false.
   if (refused('ip_drop_target', stat)) return ! a task does not draw
   leg = .false.
   if (present(legend)) leg = legend
   code = 0_c_int
   if (present(axis)) then
      if (leg) then
         call figure_fail(FIG_ERR_ARGUMENT, 'ip_drop_target: give axis or legend, not both', stat)
         return
      endif
      if (axis_refused('ip_drop_target', axis, code, .false., stat)) return
   else
      if (plot_refused('ip_drop_target', .false., stat)) return
   endif
   if (len(type) < 1 .or. len(type) > 32) then ! fig_dnd_plot_target's refusals
      call figure_fail(FIG_ERR_ARGUMENT, "ip_drop_target: type '"//type//"' must have 1 to 32 characters", stat)
      return
   endif
   if (type(1:1) == '_') then
      call figure_fail(FIG_ERR_ARGUMENT, "ip_drop_target: type '"//type//"' starts with '_' (Dear ImGui's own types)", &
                       stat)
      return
   endif
   if (present(axis)) then
      dropped = pf_drop_target(type, payload, axis=AXIS_NAMES(code), x=x, y=y)
   else
      dropped = pf_drop_target(type, payload, legend=leg, x=x, y=y)
   endif
   call figure_check(FIG_OK, stat)
   endfunction ip_drop_target

   recursive subroutine ip_link_axis(axis, group, stat)
   !< Link `axis` (`'x1'`..`'y3'`) of the plot being set up to the group `group` (`SetupAxisLinks`): every plot linked
   !< to a group shows the same range, and a pan or a zoom in any of them moves all. FIGURE keeps the group's range;
   !< a new group takes the range its first plot fits on its first frame. Call it in the setup, after
   !< `ip_setup_axes`/`ip_setup_axis`, every frame. Statuses: `FIG_ERR_ARGUMENT` for an unknown axis or an empty group
   !< name; `FIG_ERR_STATE` outside a plot, after its setup is over, for an axis not set up, from a task.
   character(len=*), intent(in)            :: axis  !< 'x1', 'x2', 'x3', 'y1', 'y2', 'y3'.
   character(len=*), intent(in)            :: group !< The group's name (any text, not empty).
   integer(int32),   intent(out), optional :: stat  !< Status.
   integer(c_int)                          :: code  !< ImAxis.

   if (refused('ip_link_axis', stat)) return ! a task does not draw
   if (axis_refused('ip_link_axis', axis, code, .true., stat)) return
   if (len_trim(group) == 0) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_link_axis: the group has no name', stat)
      return
   endif
   call pf_link_axis(AXIS_NAMES(code), group)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_link_axis

   recursive function ip_begin_aligned(group, horizontal, stat) result(open)
   !< Begin a group of aligned plots (`BeginAlignedPlots`): the plots begun until `ip_end_aligned` have their plot areas
   !< start and end at the same pixels, whatever the width of their tick labels (stacked plots: the same left and right
   !< edges; `horizontal=.true.`, side by side: the same top and bottom). When true, close it with `ip_end_aligned`.
   !< One group at a time. Statuses: `FIG_ERR_STATE` inside another group, outside a frame or from a task.
   character(len=*), intent(in)            :: group      !< The group's id.
   logical,          intent(in),  optional :: horizontal !< Plots side by side (default: stacked).
   integer(int32),   intent(out), optional :: stat       !< Status.
   logical                                 :: open       !< The group is open: begin its plots, then end it.

   open = .false.
   if (refused('ip_begin_aligned', stat)) return ! a task does not draw
   if (pf_aligned_open()) then
      call figure_usage_error('ip_begin_aligned: a group of aligned plots is open (ImPlot aligns one group at a time)', &
                              stat)
      return
   endif
   open = pf_begin_aligned(group, horizontal)
   call figure_scope_open(SCOPE_ALIGNED, 'ip_begin_aligned', group, open)
   call figure_check(FIG_OK, stat)
   endfunction ip_begin_aligned

   recursive subroutine ip_end_aligned(stat)
   !< End a group of aligned plots (only after `ip_begin_aligned` returned true).
   integer(int32), intent(out), optional :: stat !< Status: `FIG_ERR_STATE` for an end with no group open.

   if (figure_scope_refused(SCOPE_ALIGNED, 'ip_end_aligned', stat=stat)) return
   call pf_end_aligned()
   if (present(stat)) stat = FIG_OK
   endsubroutine ip_end_aligned

   recursive function ip_legend_hovered(label, stat) result(hovered)
   !< True while the pointer is on the legend entry of the item `label` (`IsLegendEntryHovered`): a program shows more
   !< about the item then (a tooltip). After the item, before `ip_end_plot`. Statuses: `FIG_ERR_STATE` outside a plot
   !< or from a task.
   character(len=*), intent(in)            :: label   !< The item's label.
   integer(int32),   intent(out), optional :: stat    !< Status.
   logical                                 :: hovered !< The entry is hovered.

   hovered = .false.
   if (refused('ip_legend_hovered', stat)) return ! a task does not draw
   if (plot_refused('ip_legend_hovered', .false., stat)) return
   hovered = pf_legend_hovered(label)
   call figure_check(FIG_OK, stat)
   endfunction ip_legend_hovered

   recursive function ip_begin_legend_popup(label, button, stat) result(open)
   !< A popup of the legend entry of the item `label` (`BeginLegendPopup`), opened by a click of `button` (`'right'`,
   !< default, `'left'` or `'middle'`) on the entry: when true, draw its contents (widgets), then
   !< `ip_end_legend_popup`. After the item, before `ip_end_plot`. Statuses: `FIG_ERR_ARGUMENT` for an unknown button;
   !< `FIG_ERR_STATE` outside a plot or from a task.
   character(len=*), intent(in)            :: label  !< The item's label.
   character(len=*), intent(in),  optional :: button !< 'right' (default), 'left' or 'middle'.
   integer(int32),   intent(out), optional :: stat   !< Status.
   logical                                 :: open   !< The popup is open: draw it, then end it.

   open = .false.
   if (refused('ip_begin_legend_popup', stat)) return ! a task does not draw
   if (present(button)) then
      select case (button)
      case ('left', 'right', 'middle')
      case default
         call figure_fail(FIG_ERR_ARGUMENT, "ip_begin_legend_popup: button must be 'left', 'right' or 'middle'", stat)
         return
      endselect
   endif
   if (plot_refused('ip_begin_legend_popup', .false., stat)) return
   open = pf_begin_legend_popup(label, button)
   call figure_scope_open(SCOPE_LEGEND_POPUP, 'ip_begin_legend_popup', label, open)
   call figure_check(FIG_OK, stat)
   endfunction ip_begin_legend_popup

   recursive subroutine ip_end_legend_popup(stat)
   !< End a legend entry's popup (only after `ip_begin_legend_popup` returned true).
   integer(int32), intent(out), optional :: stat !< Status: `FIG_ERR_STATE` for an end with no popup open.

   if (figure_scope_refused(SCOPE_LEGEND_POPUP, 'ip_end_legend_popup', stat=stat)) return
   call pf_end_legend_popup()
   if (present(stat)) stat = FIG_OK
   endsubroutine ip_end_legend_popup

   recursive subroutine ip_set_decimation(enabled, stat)
   !< Decimate the long line-like series of the items drawn after it (the default) or draw every point of them.
   !< `ip_line`, `ip_stairs` and `ip_shaded` with more than 256 points per pixel column of the plot on average (sorted
   !< abscissae, no markers) draw, per sixteenth of a column of more than 64 points, its first, last, lowest and highest
   !< points (M4): at most 64 points a column whatever the series' length. The picture stays close to the full one,
   !< anti-aliasing apart (plots.md, "Long series"); `enabled=.false.` draws every point, as v0.8.0 did, for an exact picture. A
   !< setting of the program, kept until changed, in every mode. Statuses: `FIG_ERR_STATE` from a task.
   logical,        intent(in)            :: enabled !< Decimate (`.true.`, the default) or draw every point.
   integer(int32), intent(out), optional :: stat    !< Status.

   if (figure_refused('ip_set_decimation', stat)) return ! a task does not draw
   call pf_set_decimation(enabled)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_set_decimation

   recursive subroutine ip_cache_next_item(changed, stat)
   !< The next `ip_line`, `ip_stairs` or `ip_shaded` keeps what its decimation computes of its data between frames,
   !< and `changed` says whether the program changed the values since that item's last frame (as `ip_field_image`'s
   !< `changed`). Unchanged data then cost each frame a few operations per pixel column, not a pass over every point:
   !< panning and zooming a series of 10**8 points stay interactive. A new address, size, stride or kind of an array
   !< rebuilds the cache whatever `changed` says; values changed in place with `changed=.false.` are drawn as they
   !< were. Without this call (the default) every frame decimates from the data. The cache is released 10 s after its
   !< last use (plots.md, "Long series"). Statuses: `FIG_ERR_STATE` from a task.
   logical,        intent(in)            :: changed !< The values changed since the item's last frame.
   integer(int32), intent(out), optional :: stat    !< Status.

   if (figure_refused('ip_cache_next_item', stat)) return ! a task does not draw
   call pf_cache_next_item(changed)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_cache_next_item

   recursive subroutine ip_hide_next_item(hidden, always, stat)
   !< Hide (default) or show the next item (`HideNextItem`): its legend entry stays, greyed while hidden, and a click
   !< on it shows it again. The first time the item is drawn only, unless `always=.true.`: then on this frame, whatever
   !< the user did (the program decides, every frame it calls it). Before the item, inside a plot. Statuses:
   !< `FIG_ERR_STATE` outside a plot or from a task.
   logical,        intent(in),  optional :: hidden !< Hidden (default true) or shown.
   logical,        intent(in),  optional :: always !< On this frame (default: the item's first frame only).
   integer(int32), intent(out), optional :: stat   !< Status.

   if (refused('ip_hide_next_item', stat)) return ! a task does not draw
   if (plot_refused('ip_hide_next_item', .false., stat)) return
   call pf_hide_next_item(hidden, always)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_hide_next_item

   recursive subroutine ip_bar_groups_r32(labels, values, group_size, shift, horizontal, stacked, colormap, spec, stat)
   !< Items in groups of bars (`PlotBarGroups`), single precision: `values(g, i)` is item i in group g, group g centred at
   !< x = g - 1 (0, 1, ...; `shift` moves them all), the items of a group side by side in `group_size` (a fraction of
   !< the unit, in (0, 1], default 0.67) or, `stacked=.true.`, on top of each other (negative values below 0);
   !< `horizontal=.true.`: along y. `labels(i)` names item i (its legend entry; trailing blanks dropped). The items take
   !< the colours of `colormap` (an id of `ip_colormap`) in order, default the plot's line colours; `spec`'s
   !< `fill_color` paints them all. Statuses: `FIG_ERR_ARGUMENT` for `size(labels)` not `size(values, 2)`, no values,
   !< `group_size` outside (0, 1], an unknown colormap; `FIG_ERR_STATE` outside a plot or from a task.
   character(len=*),       intent(in)            :: labels(:)    !< One per item.
   real(real32),               intent(in)            :: values(:, :) !< values(group, item).
   real(real64),           intent(in),  optional :: group_size   !< Width of a group [x units] (default 0.67).
   real(real64),           intent(in),  optional :: shift        !< Shift of every group [x units] (default 0).
   logical,                intent(in),  optional :: horizontal   !< Groups along y (default: along x).
   logical,                intent(in),  optional :: stacked      !< Items stacked (default: side by side).
   integer(int32),         intent(in),  optional :: colormap     !< The items' colours (default: the plot's).
   type(plot_spec_object), intent(in),  optional :: spec         !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional :: stat         !< Status.
   integer(c_int)                                :: cmap         !< Colormap id.
   character(len=24)                             :: t1, t2       !< Numbers, printed.

   if (refused('ip_bar_groups', stat)) return ! a task does not draw
   if (size(labels) /= size(values, 2)) then
      write(t1, '(I0)') size(labels)
      write(t2, '(I0)') size(values, 2)
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_bar_groups: '//trim(t1)//' labels for '//trim(t2)// &
                       ' items (size(values, 2))', stat)
      return
   endif
   if (size(values) == 0) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_bar_groups: no values', stat)
      return
   endif
   if (present(group_size)) then
      if (.not. (group_size > 0.0_real64 .and. group_size <= 1.0_real64)) then
         call figure_fail(FIG_ERR_ARGUMENT, 'ip_bar_groups: group_size must be in (0, 1]', stat)
         return
      endif
   endif
   if (present(colormap)) then
      if (.not. colormap_ok('ip_bar_groups', colormap, cmap, stat)) return
   endif
   if (plot_refused('ip_bar_groups', .false., stat)) return
   plot_stride = 4_int64 ! (the values copied contiguous, item by item)
   if (present(colormap)) then
      call pf_bar_groups(labels, values, group_size, shift, horizontal, stacked, cm_frame_id(int(cmap, int32)), &
                         spec=item_spec(spec))
   else
      call pf_bar_groups(labels, values, group_size, shift, horizontal, stacked, spec=item_spec(spec))
   endif
   call figure_check(FIG_OK, stat)
   endsubroutine ip_bar_groups_r32

   recursive subroutine ip_bar_groups_r64(labels, values, group_size, shift, horizontal, stacked, colormap, spec, stat)
   !< Items in groups of bars (`PlotBarGroups`), double precision: `values(g, i)` is item i in group g, group g centred at
   !< x = g - 1 (0, 1, ...; `shift` moves them all), the items of a group side by side in `group_size` (a fraction of
   !< the unit, in (0, 1], default 0.67) or, `stacked=.true.`, on top of each other (negative values below 0);
   !< `horizontal=.true.`: along y. `labels(i)` names item i (its legend entry; trailing blanks dropped). The items take
   !< the colours of `colormap` (an id of `ip_colormap`) in order, default the plot's line colours; `spec`'s
   !< `fill_color` paints them all. Statuses: `FIG_ERR_ARGUMENT` for `size(labels)` not `size(values, 2)`, no values,
   !< `group_size` outside (0, 1], an unknown colormap; `FIG_ERR_STATE` outside a plot or from a task.
   character(len=*),       intent(in)            :: labels(:)    !< One per item.
   real(real64),               intent(in)            :: values(:, :) !< values(group, item).
   real(real64),           intent(in),  optional :: group_size   !< Width of a group [x units] (default 0.67).
   real(real64),           intent(in),  optional :: shift        !< Shift of every group [x units] (default 0).
   logical,                intent(in),  optional :: horizontal   !< Groups along y (default: along x).
   logical,                intent(in),  optional :: stacked      !< Items stacked (default: side by side).
   integer(int32),         intent(in),  optional :: colormap     !< The items' colours (default: the plot's).
   type(plot_spec_object), intent(in),  optional :: spec         !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional :: stat         !< Status.
   integer(c_int)                                :: cmap         !< Colormap id.
   character(len=24)                             :: t1, t2       !< Numbers, printed.

   if (refused('ip_bar_groups', stat)) return ! a task does not draw
   if (size(labels) /= size(values, 2)) then
      write(t1, '(I0)') size(labels)
      write(t2, '(I0)') size(values, 2)
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_bar_groups: '//trim(t1)//' labels for '//trim(t2)// &
                       ' items (size(values, 2))', stat)
      return
   endif
   if (size(values) == 0) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_bar_groups: no values', stat)
      return
   endif
   if (present(group_size)) then
      if (.not. (group_size > 0.0_real64 .and. group_size <= 1.0_real64)) then
         call figure_fail(FIG_ERR_ARGUMENT, 'ip_bar_groups: group_size must be in (0, 1]', stat)
         return
      endif
   endif
   if (present(colormap)) then
      if (.not. colormap_ok('ip_bar_groups', colormap, cmap, stat)) return
   endif
   if (plot_refused('ip_bar_groups', .false., stat)) return
   plot_stride = 8_int64 ! (the values copied contiguous, item by item)
   if (present(colormap)) then
      call pf_bar_groups(labels, values, group_size, shift, horizontal, stacked, cm_frame_id(int(cmap, int32)), &
                         spec=item_spec(spec))
   else
      call pf_bar_groups(labels, values, group_size, shift, horizontal, stacked, spec=item_spec(spec))
   endif
   call figure_check(FIG_OK, stat)
   endsubroutine ip_bar_groups_r64

   recursive subroutine ip_tag(axis, value, color, text, stat)
   !< A tag on an axis of the current plot (`TagX`, `TagY`): a box at `value` over the axis, holding `text` or, without
   !< it, the value labelled as the axis labels its ticks (its format). Drawn when the plot ends, over the axis's tick
   !< labels. Default colour: that of the last item drawn (a tag after a line marks the line's last value). `axis` is
   !< one of `'x1'`..`'x3'`, `'y1'`..`'y3'`, set up on this frame. Statuses: `FIG_ERR_ARGUMENT` for an unknown axis, a
   !< colour of size /= 4 or a NaN value; `FIG_ERR_STATE` outside a plot, for an axis not set up, from a task.
   character(len=*), intent(in)            :: axis     !< 'x1', 'x2', 'x3', 'y1', 'y2', 'y3'.
   real(real64),     intent(in)            :: value    !< Position [axis units].
   real(real64),     intent(in), optional  :: color(:) !< Box colour, RGBA in [0, 1] (default: the last item's).
   character(len=*), intent(in), optional  :: text     !< Text (UTF-8; default: the value, in the axis's format).
   integer(int32),   intent(out), optional :: stat     !< Status.
   integer(c_int)                          :: code     !< ImAxis.

   if (refused('ip_tag', stat)) return ! a task does not draw
   if (.not. rgba_ok(color)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_tag: a colour needs 4 components (RGBA)', stat)
      return
   endif
   if (ieee_is_nan(value)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_tag: the value is NaN', stat)
      return
   endif
   if (axis_refused('ip_tag', axis, code, .false., stat)) return
   call pf_tag(AXIS_NAMES(code), value, color, text) ! (no colour: the last item's)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_tag

   recursive subroutine ip_text(text, x, y, offset, vertical, stat)
   !< A text centred on the plot point (x, y) of the current plot (`PlotText`), in the plot's inlay text colour, clipped
   !< to the plot area; `offset` moves it [pixels] (x right, y down), `vertical=.true.` writes it bottom to top. Not
   !< an item: no legend entry; it takes part in fitting the axes. Statuses: `FIG_ERR_ARGUMENT` for a NaN coordinate
   !< or an offset of size /= 2; `FIG_ERR_STATE` outside a plot, from a task.
   character(len=*), intent(in)            :: text      !< Text (UTF-8).
   real(real64),     intent(in)            :: x         !< Abscissa [plot units].
   real(real64),     intent(in)            :: y         !< Ordinate [plot units].
   real(real64),     intent(in), optional  :: offset(:) !< Offset [pixels], (x right, y down) (default: none).
   logical,          intent(in), optional  :: vertical  !< Written bottom to top (default: horizontal).
   integer(int32),   intent(out), optional :: stat      !< Status.

   if (refused('ip_text', stat)) return ! a task does not draw
   if (present(offset)) then
      if (size(offset) /= 2) then
         call figure_fail(FIG_ERR_ARGUMENT, 'ip_text: the offset needs 2 components (x, y)', stat)
         return
      endif
   endif
   if (ieee_is_nan(x) .or. ieee_is_nan(y)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_text: x and y must not be NaN', stat)
      return
   endif
   if (plot_refused('ip_text', .false., stat)) return
   if (outside_plot('ip_text', stat)) return
   call pf_text(text, x, y, offset, vertical)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_text

   ! more items: stairs, stems, infinite lines, histograms

   recursive subroutine ip_inf_lines_r32(label, values, horizontal, spec, stat)
   !< Lines across the whole plot (`PlotInfLines`): vertical at x = values(i), or horizontal at y = values(i) with
   !< `horizontal=.true.`, single precision; read in place with any stride (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label      !< Legend label.
   real(real32),           intent(in), target, asynchronous :: values(:)  !< Positions [x units; y units when horizontal].
   logical,                intent(in), optional             :: horizontal !< Horizontal lines (default: vertical).
   type(plot_spec_object), intent(in), optional             :: spec       !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat       !< Status.
   integer(int64)                                           :: s          !< The stride ImPlot would read [bytes].

   if (refused('ip_inf_lines', stat)) return ! a task does not draw
   if (plot_refused('ip_inf_lines', .false., stat)) return
   if (.not. series_ok(size(values, kind=int64), size(values, kind=int64), 'ip_inf_lines', stat)) return
   call acct_lead_r32(s, values)
   if (outside_plot('ip_inf_lines', stat)) return
   call pf_inf_lines(label, values, horizontal, spec=item_spec(spec))
   plot_stride = s
   call figure_check(FIG_OK, stat)
   endsubroutine ip_inf_lines_r32

   recursive subroutine ip_inf_lines_r64(label, values, horizontal, spec, stat)
   !< Lines across the whole plot (`PlotInfLines`): vertical at x = values(i), or horizontal at y = values(i) with
   !< `horizontal=.true.`, double precision; read in place with any stride (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label      !< Legend label.
   real(real64),           intent(in), target, asynchronous :: values(:)  !< Positions [x units; y units when horizontal].
   logical,                intent(in), optional             :: horizontal !< Horizontal lines (default: vertical).
   type(plot_spec_object), intent(in), optional             :: spec       !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat       !< Status.
   integer(int64)                                           :: s          !< The stride ImPlot would read [bytes].

   if (refused('ip_inf_lines', stat)) return ! a task does not draw
   if (plot_refused('ip_inf_lines', .false., stat)) return
   if (.not. series_ok(size(values, kind=int64), size(values, kind=int64), 'ip_inf_lines', stat)) return
   call acct_lead_r64(s, values)
   if (outside_plot('ip_inf_lines', stat)) return
   call pf_inf_lines(label, values, horizontal, spec=item_spec(spec))
   plot_stride = s
   call figure_check(FIG_OK, stat)
   endsubroutine ip_inf_lines_r64

   recursive subroutine ip_inf_lines_i32(label, values, horizontal, spec, stat)
   !< Lines across the whole plot (`PlotInfLines`) at integer positions (iterations): vertical at x = values(i), or
   !< horizontal with `horizontal=.true.`; converted to double precision into one temporary.
   character(len=*),       intent(in)               :: label      !< Legend label.
   integer(int32),         intent(in), asynchronous :: values(:)  !< Positions [x units; y units when horizontal].
   logical,                intent(in), optional     :: horizontal !< Horizontal lines (default: vertical).
   type(plot_spec_object), intent(in), optional     :: spec       !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional    :: stat       !< Status.
   integer(int64)                                           :: s          !< The stride ImPlot would read [bytes].

   if (refused('ip_inf_lines', stat)) return ! a task does not draw
   if (plot_refused('ip_inf_lines', .false., stat)) return
   if (.not. series_ok(size(values, kind=int64), size(values, kind=int64), 'ip_inf_lines', stat)) return
   s = 8_int64
   call acct_put_int(size(values, kind=int64))
   if (outside_plot('ip_inf_lines', stat)) return
   call pf_inf_lines(label, values, horizontal, spec=item_spec(spec))
   plot_stride = s
   call figure_check(FIG_OK, stat)
   endsubroutine ip_inf_lines_i32

   recursive subroutine ip_inf_lines_i64(label, values, horizontal, spec, stat)
   !< Lines across the whole plot (`PlotInfLines`) at integer positions (iterations): vertical at x = values(i), or
   !< horizontal with `horizontal=.true.`; converted to double precision into one temporary.
   character(len=*),       intent(in)               :: label      !< Legend label.
   integer(int64),         intent(in), asynchronous :: values(:)  !< Positions [x units; y units when horizontal].
   logical,                intent(in), optional     :: horizontal !< Horizontal lines (default: vertical).
   type(plot_spec_object), intent(in), optional     :: spec       !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional    :: stat       !< Status.
   integer(int64)                                           :: s          !< The stride ImPlot would read [bytes].

   if (refused('ip_inf_lines', stat)) return ! a task does not draw
   if (plot_refused('ip_inf_lines', .false., stat)) return
   if (.not. series_ok(size(values, kind=int64), size(values, kind=int64), 'ip_inf_lines', stat)) return
   s = 8_int64
   call acct_put_int(size(values, kind=int64))
   if (outside_plot('ip_inf_lines', stat)) return
   call pf_inf_lines(label, values, horizontal, spec=item_spec(spec))
   plot_stride = s
   call figure_check(FIG_OK, stat)
   endsubroutine ip_inf_lines_i64

   recursive subroutine ip_histogram_r32(label, values, bins, vmin, vmax, bar_scale, max_count, spec, stat)
   !< A histogram of `values` (`PlotHistogram`): `bins` bars over [vmin, vmax] (default: the range of the finite
   !< values), each as high as the values that fall in its bin, single precision. NaN and infinite values are left out (a
   !< temporary of the finite ones); a strided array is copied contiguous (ImPlot passes the item's stride on to the
   !< bars it draws from its own counts). Flags in the spec: `ImPlotHistogramFlags_Horizontal`, `_Cumulative`,
   !< `_Density`, `_NoOutliers`.
   character(len=*),       intent(in)            :: label     !< Legend label.
   real(real32),           intent(in), target    :: values(:) !< Values.
   integer(int32),         intent(in),  optional :: bins      !< A count > 0, or a rule: `ImPlotBin_Sqrt`,
                                                              !< `ImPlotBin_Sturges` (default), `ImPlotBin_Rice`,
                                                              !< `ImPlotBin_Scott`.
   real(real64),           intent(in),  optional :: vmin      !< Left end of the first bin [values units] (with `vmax`).
   real(real64),           intent(in),  optional :: vmax      !< Right end of the last bin [values units] (with `vmin`).
   real(real64),           intent(in),  optional :: bar_scale !< Bar width over bin width (default 1).
   real(real64),           intent(out), optional :: max_count !< Height of the tallest bar (a count, or a density).
   type(plot_spec_object), intent(in),  optional :: spec      !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional :: stat      !< Status.
   integer(c_int)                                :: nb        !< Bins.
   integer(int64)                                :: n         !< Finite values.

   if (present(max_count)) max_count = 0.0_real64
   if (refused('ip_histogram', stat)) return ! a task does not draw
   if (.not. bins_ok('ip_histogram', 'bins', bins, nb, stat)) return
   if (.not. ends_ok('ip_histogram', 'vmin', vmin, 'vmax', vmax, stat)) return
   if (plot_refused('ip_histogram', .false., stat)) return
   if (.not. series_ok(size(values, kind=int64), size(values, kind=int64), 'ip_histogram', stat)) return
   n = count(finite_value(values))
   if (.not. (n == size(values, kind=int64) .and. in_line(values))) plot_copies = plot_copies + 1_int64
   if (n == 0_int64) then
      call figure_check(FIG_OK, stat) ! nothing to count: no item
      return
   endif
   plot_stride = int(storage_size(values) / 8, int64)
   if (outside_plot('ip_histogram', stat)) return
   call pf_histogram(label, values, bins, vmin, vmax, bar_scale, max_count, spec=item_spec(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_histogram_r32

   recursive subroutine ip_histogram_r64(label, values, bins, vmin, vmax, bar_scale, max_count, spec, stat)
   !< A histogram of `values` (`PlotHistogram`): `bins` bars over [vmin, vmax] (default: the range of the finite
   !< values), each as high as the values that fall in its bin, double precision. NaN and infinite values are left out (a
   !< temporary of the finite ones); a strided array is copied contiguous (ImPlot passes the item's stride on to the
   !< bars it draws from its own counts). Flags in the spec: `ImPlotHistogramFlags_Horizontal`, `_Cumulative`,
   !< `_Density`, `_NoOutliers`.
   character(len=*),       intent(in)            :: label     !< Legend label.
   real(real64),           intent(in), target    :: values(:) !< Values.
   integer(int32),         intent(in),  optional :: bins      !< A count > 0, or a rule: `ImPlotBin_Sqrt`,
                                                              !< `ImPlotBin_Sturges` (default), `ImPlotBin_Rice`,
                                                              !< `ImPlotBin_Scott`.
   real(real64),           intent(in),  optional :: vmin      !< Left end of the first bin [values units] (with `vmax`).
   real(real64),           intent(in),  optional :: vmax      !< Right end of the last bin [values units] (with `vmin`).
   real(real64),           intent(in),  optional :: bar_scale !< Bar width over bin width (default 1).
   real(real64),           intent(out), optional :: max_count !< Height of the tallest bar (a count, or a density).
   type(plot_spec_object), intent(in),  optional :: spec      !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional :: stat      !< Status.
   integer(c_int)                                :: nb        !< Bins.
   integer(int64)                                :: n         !< Finite values.

   if (present(max_count)) max_count = 0.0_real64
   if (refused('ip_histogram', stat)) return ! a task does not draw
   if (.not. bins_ok('ip_histogram', 'bins', bins, nb, stat)) return
   if (.not. ends_ok('ip_histogram', 'vmin', vmin, 'vmax', vmax, stat)) return
   if (plot_refused('ip_histogram', .false., stat)) return
   if (.not. series_ok(size(values, kind=int64), size(values, kind=int64), 'ip_histogram', stat)) return
   n = count(finite_value(values))
   if (.not. (n == size(values, kind=int64) .and. in_line(values))) plot_copies = plot_copies + 1_int64
   if (n == 0_int64) then
      call figure_check(FIG_OK, stat) ! nothing to count: no item
      return
   endif
   plot_stride = int(storage_size(values) / 8, int64)
   if (outside_plot('ip_histogram', stat)) return
   call pf_histogram(label, values, bins, vmin, vmax, bar_scale, max_count, spec=item_spec(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_histogram_r64

   recursive subroutine ip_histogram2d_r32(label, x, y, xbins, ybins, xmin, xmax, ymin, ymax, colormap, max_count, &
                                         spec, stat)
   !< A 2-D histogram of the points (x(i), y(i)) (`PlotHistogram2D`): `xbins` x `ybins` cells over [xmin, xmax] x
   !< [ymin, ymax] (default: the range of the finite points), coloured through `colormap` by how many points fall in
   !< each, single precision; read in place with any stride (plots.md, "Data in place"). Points with a NaN or infinite
   !< coordinate are left out (temporaries of the finite ones). Flags in the spec: `ImPlotHistogramFlags_Density`,
   !< `_NoOutliers`.
   character(len=*),       intent(in)                       :: label     !< Legend label.
   real(real32),           intent(in), target, asynchronous :: x(:)      !< Abscissae.
   real(real32),           intent(in), target, asynchronous :: y(:)      !< Ordinates.
   integer(int32),         intent(in),  optional            :: xbins     !< Bins along x: a count > 0 or an `ImPlotBin_*` rule
                                                                         !< (default `ImPlotBin_Sturges`).
   integer(int32),         intent(in),  optional            :: ybins     !< Bins along y: the same.
   real(real64),           intent(in),  optional            :: xmin      !< Left end [x units] (with `xmax`).
   real(real64),           intent(in),  optional            :: xmax      !< Right end [x units] (with `xmin`).
   real(real64),           intent(in),  optional            :: ymin      !< Bottom end [y units] (with `ymax`).
   real(real64),           intent(in),  optional            :: ymax      !< Top end [y units] (with `ymin`).
   integer(int32),         intent(in),  optional            :: colormap  !< Colormap (`ip_colormap`; default: Viridis).
   real(real64),           intent(out), optional            :: max_count !< Points in the fullest cell (a count, or a density).
   type(plot_spec_object), intent(in),  optional            :: spec      !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat      !< Status.
   integer(int64)                                           :: s         !< The stride ImPlot would read [bytes].
   integer(c_int)                                           :: nbx       !< Bins along x.
   integer(c_int)                                           :: nby       !< Bins along y.
   integer(c_int)                                           :: cmap      !< Colormap id.
   integer(int64)                                           :: n         !< Finite points.

   if (present(max_count)) max_count = 0.0_real64
   if (refused('ip_histogram2d', stat)) return ! a task does not draw
   if (.not. bins_ok('ip_histogram2d', 'xbins', xbins, nbx, stat)) return
   if (.not. bins_ok('ip_histogram2d', 'ybins', ybins, nby, stat)) return
   if (.not. ends_ok('ip_histogram2d', 'xmin', xmin, 'xmax', xmax, stat)) return
   if (.not. ends_ok('ip_histogram2d', 'ymin', ymin, 'ymax', ymax, stat)) return
   if (.not. colormap_ok('ip_histogram2d', colormap, cmap, stat)) return
   if (plot_refused('ip_histogram2d', .false., stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_histogram2d', stat)) return
   n = count(finite_value(x) .and. finite_value(y))
   if (n == size(x, kind=int64)) then
      call acct_lead_r32(s, y)
      call acct_put_r32(s, x)
   else
      s = int(storage_size(x) / 8, int64)
      plot_copies = plot_copies + 2_int64
   endif
   if (n == 0_int64) then
      call figure_check(FIG_OK, stat) ! nothing to count: no item
      return
   endif
   plot_stride = s
   if (outside_plot('ip_histogram2d', stat)) return
   call pf_histogram2d(label, x, y, xbins, ybins, xmin, xmax, ymin, ymax, cm_frame_id(int(cmap, int32)), max_count, &
                       spec=item_spec(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_histogram2d_r32

   recursive subroutine ip_histogram2d_r64(label, x, y, xbins, ybins, xmin, xmax, ymin, ymax, colormap, max_count, &
                                         spec, stat)
   !< A 2-D histogram of the points (x(i), y(i)) (`PlotHistogram2D`): `xbins` x `ybins` cells over [xmin, xmax] x
   !< [ymin, ymax] (default: the range of the finite points), coloured through `colormap` by how many points fall in
   !< each, double precision; read in place with any stride (plots.md, "Data in place"). Points with a NaN or infinite
   !< coordinate are left out (temporaries of the finite ones). Flags in the spec: `ImPlotHistogramFlags_Density`,
   !< `_NoOutliers`.
   character(len=*),       intent(in)                       :: label     !< Legend label.
   real(real64),           intent(in), target, asynchronous :: x(:)      !< Abscissae.
   real(real64),           intent(in), target, asynchronous :: y(:)      !< Ordinates.
   integer(int32),         intent(in),  optional            :: xbins     !< Bins along x: a count > 0 or an `ImPlotBin_*` rule
                                                                         !< (default `ImPlotBin_Sturges`).
   integer(int32),         intent(in),  optional            :: ybins     !< Bins along y: the same.
   real(real64),           intent(in),  optional            :: xmin      !< Left end [x units] (with `xmax`).
   real(real64),           intent(in),  optional            :: xmax      !< Right end [x units] (with `xmin`).
   real(real64),           intent(in),  optional            :: ymin      !< Bottom end [y units] (with `ymax`).
   real(real64),           intent(in),  optional            :: ymax      !< Top end [y units] (with `ymin`).
   integer(int32),         intent(in),  optional            :: colormap  !< Colormap (`ip_colormap`; default: Viridis).
   real(real64),           intent(out), optional            :: max_count !< Points in the fullest cell (a count, or a density).
   type(plot_spec_object), intent(in),  optional            :: spec      !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat      !< Status.
   integer(int64)                                           :: s         !< The stride ImPlot would read [bytes].
   integer(c_int)                                           :: nbx       !< Bins along x.
   integer(c_int)                                           :: nby       !< Bins along y.
   integer(c_int)                                           :: cmap      !< Colormap id.
   integer(int64)                                           :: n         !< Finite points.

   if (present(max_count)) max_count = 0.0_real64
   if (refused('ip_histogram2d', stat)) return ! a task does not draw
   if (.not. bins_ok('ip_histogram2d', 'xbins', xbins, nbx, stat)) return
   if (.not. bins_ok('ip_histogram2d', 'ybins', ybins, nby, stat)) return
   if (.not. ends_ok('ip_histogram2d', 'xmin', xmin, 'xmax', xmax, stat)) return
   if (.not. ends_ok('ip_histogram2d', 'ymin', ymin, 'ymax', ymax, stat)) return
   if (.not. colormap_ok('ip_histogram2d', colormap, cmap, stat)) return
   if (plot_refused('ip_histogram2d', .false., stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_histogram2d', stat)) return
   n = count(finite_value(x) .and. finite_value(y))
   if (n == size(x, kind=int64)) then
      call acct_lead_r64(s, y)
      call acct_put_r64(s, x)
   else
      s = int(storage_size(x) / 8, int64)
      plot_copies = plot_copies + 2_int64
   endif
   if (n == 0_int64) then
      call figure_check(FIG_OK, stat) ! nothing to count: no item
      return
   endif
   plot_stride = s
   if (outside_plot('ip_histogram2d', stat)) return
   call pf_histogram2d(label, x, y, xbins, ybins, xmin, xmax, ymin, ymax, cm_frame_id(int(cmap, int32)), max_count, &
                       spec=item_spec(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_histogram2d_r64

   recursive subroutine ip_contour_r32(label, f, x0, x1, y0, y1, levels, nlevels, colormap, color, labels, line_weight, &
                                       stat)
   !< Contour lines of the field f(i, j), sampled at x = x0 .. x1 (i = 1 .. size(f, 1)) and y = y0 .. y1 (j = 1 ..
   !< size(f, 2)), uniformly spaced, read in place: as `ip_contour_r64`. Single precision.
   character(len=*), intent(in)            :: label       !< Legend label (one entry for every level).
   real(real32),     intent(in)            :: f(:,:)      !< Field: f(i, j), i along x, j along y.
   real(real64),     intent(in)            :: x0          !< Abscissa of f(1, :).
   real(real64),     intent(in)            :: x1          !< Abscissa of f(size(f, 1), :).
   real(real64),     intent(in)            :: y0          !< Ordinate of f(:, 1).
   real(real64),     intent(in)            :: y1          !< Ordinate of f(:, size(f, 2)).
   real(real64),     intent(in), optional  :: levels(:)   !< Levels (default: `ip_contour_levels(f, nlevels)`).
   integer(int32),   intent(in), optional  :: nlevels     !< Automatic levels wanted, about (default 10).
   integer(int32),   intent(in), optional  :: colormap    !< Colour each level from this colormap (`ip_colormap`).
   real(real64),     intent(in), optional  :: color(:)    !< One colour for every level, RGBA in [0, 1].
   logical,          intent(in), optional  :: labels      !< Label each level with its value (default: no).
   real(real64),     intent(in), optional  :: line_weight !< Line weight [pixels] (default: ImPlot's).
   integer(int32),   intent(out), optional :: stat        !< Status.
   real(real64), allocatable, target       :: xs(:)       !< Segment ends, x.
   real(real64), allocatable, target       :: ys(:)       !< Segment ends, y.
   integer(int64), allocatable             :: first(:)    !< First end of each level.
   real(real64), allocatable               :: lev(:)      !< Levels drawn.
   real(real64)                            :: fmin, fmax  !< Finite range of the field.
   logical                                 :: found       !< The field has finite values.
   integer(c_int)                          :: cmap        !< Colormap id.

   if (refused('ip_contour', stat)) return ! a task does not draw
   if (.not. contour_ok(nlevels, colormap, color, cmap, stat)) return
   if (present(levels)) then
      lev = levels
   else
      lev = ip_contour_levels(f, nlevels)
   endif
   call ip_contour_lines(f, x0, x1, y0, y1, lev, xs, ys, first)
   call finite_range_r32(f, fmin, fmax, found)
   if (outside_plot('ip_contour', stat)) return
   call contour_draw(label, lev, xs, ys, first, fmin, fmax, present(colormap), cmap, color, labels, line_weight, stat)
   endsubroutine ip_contour_r32

   recursive subroutine ip_contour_r64(label, f, x0, x1, y0, y1, levels, nlevels, colormap, color, labels, line_weight, &
                                       stat)
   !< Contour lines of the field f(i, j), sampled at x = x0 .. x1 (i = 1 .. size(f, 1)) and y = y0 .. y1 (j = 1 ..
   !< size(f, 2)), uniformly spaced, read in place (between `ip_begin_plot` and `ip_end_plot`). The segments are
   !< computed every call (`ip_contour_lines`, marching squares) and drawn as one ImPlot line item per level, with one
   !< legend entry (`label`). Levels: `levels`, or about `nlevels` round numbers inside the field's range
   !< (`ip_contour_levels`). Colours: from `colormap`, the level's value placed in the field's finite range (as a heatmap
   !< of the field with the same colormap colours it); or `color` for every level; or the item's automatic colour.
   !< `labels=.true.`: each level's value in a box of its colour on one of its segments (an annotation, drawn when the
   !< plot ends), the segments chosen part-way through each level's list so that labels of nearby levels fall apart.
   !< Non-finite values (NaN, infinities) leave holes: a cell with one is skipped. A field with fewer than 2 points
   !< along an axis has no lines. Statuses: `FIG_ERR_ARGUMENT` for a colour of size /= 4, a colormap that is not
   !< registered, `nlevels` < 1, or a level with more segments than a C int counts; `FIG_ERR_STATE` from a task.
   !< Double precision.
   character(len=*), intent(in)            :: label       !< Legend label (one entry for every level).
   real(real64),     intent(in)            :: f(:,:)      !< Field: f(i, j), i along x, j along y.
   real(real64),     intent(in)            :: x0          !< Abscissa of f(1, :).
   real(real64),     intent(in)            :: x1          !< Abscissa of f(size(f, 1), :).
   real(real64),     intent(in)            :: y0          !< Ordinate of f(:, 1).
   real(real64),     intent(in)            :: y1          !< Ordinate of f(:, size(f, 2)).
   real(real64),     intent(in), optional  :: levels(:)   !< Levels (default: `ip_contour_levels(f, nlevels)`).
   integer(int32),   intent(in), optional  :: nlevels     !< Automatic levels wanted, about (default 10).
   integer(int32),   intent(in), optional  :: colormap    !< Colour each level from this colormap (`ip_colormap`).
   real(real64),     intent(in), optional  :: color(:)    !< One colour for every level, RGBA in [0, 1].
   logical,          intent(in), optional  :: labels      !< Label each level with its value (default: no).
   real(real64),     intent(in), optional  :: line_weight !< Line weight [pixels] (default: ImPlot's).
   integer(int32),   intent(out), optional :: stat        !< Status.
   real(real64), allocatable, target       :: xs(:)       !< Segment ends, x.
   real(real64), allocatable, target       :: ys(:)       !< Segment ends, y.
   integer(int64), allocatable             :: first(:)    !< First end of each level.
   real(real64), allocatable               :: lev(:)      !< Levels drawn.
   real(real64)                            :: fmin, fmax  !< Finite range of the field.
   logical                                 :: found       !< The field has finite values.
   integer(c_int)                          :: cmap        !< Colormap id.

   if (refused('ip_contour', stat)) return ! a task does not draw
   if (.not. contour_ok(nlevels, colormap, color, cmap, stat)) return
   if (present(levels)) then
      lev = levels
   else
      lev = ip_contour_levels(f, nlevels)
   endif
   call ip_contour_lines(f, x0, x1, y0, y1, lev, xs, ys, first)
   call finite_range_r64(f, fmin, fmax, found)
   if (outside_plot('ip_contour', stat)) return
   call contour_draw(label, lev, xs, ys, first, fmin, fmax, present(colormap), cmap, color, labels, line_weight, stat)
   endsubroutine ip_contour_r64

   pure subroutine ip_contour_lines_r32(f, x0, x1, y0, y1, levels, x, y, first)
   !< The contour lines of f at `levels`, as segments: as `ip_contour_lines_r64`. Single precision.
   real(real32),                intent(in)  :: f(:,:)    !< Field: f(i, j), i along x, j along y.
   real(real64),                intent(in)  :: x0        !< Abscissa of f(1, :).
   real(real64),                intent(in)  :: x1        !< Abscissa of f(size(f, 1), :).
   real(real64),                intent(in)  :: y0        !< Ordinate of f(:, 1).
   real(real64),                intent(in)  :: y1        !< Ordinate of f(:, size(f, 2)).
   real(real64),                intent(in)  :: levels(:) !< Levels.
   real(real64),   allocatable, intent(out) :: x(:)      !< Segment ends, x: (x(2s-1), y(2s-1)) to (x(2s), y(2s)).
   real(real64),   allocatable, intent(out) :: y(:)      !< Segment ends, y.
   integer(int64), allocatable, intent(out) :: first(:)  !< Ends of level k: first(k) .. first(k+1)-1.
   integer(int64)                           :: n         !< Ends.
   integer(int32)                           :: pass      !< 1: count, 2: fill.
   integer(int32)                           :: i, j, k   !< Counters.
   integer(int32)                           :: m         !< Segments in a cell.
   real(real64)                             :: sx(4), sy(4) !< A cell's segments.
   real(real64)                             :: dx, dy    !< Spacing.

   allocate(first(size(levels) + 1))
   allocate(x(0), y(0))
   first = 1_int64
   if (size(f, 1) < 2 .or. size(f, 2) < 2) return
   dx = (x1 - x0) / real(size(f, 1) - 1, real64)
   dy = (y1 - y0) / real(size(f, 2) - 1, real64)
   do pass = 1_int32, 2_int32
      n = 0_int64
      do k = 1_int32, size(levels, kind=int32)
         first(k) = n + 1_int64
         if (.not. finite_value(levels(k))) cycle
         do j = 1_int32, size(f, 2, kind=int32) - 1_int32
            do i = 1_int32, size(f, 1, kind=int32) - 1_int32
               call cell_segments(real([f(i, j), f(i + 1, j), f(i + 1, j + 1), f(i, j + 1)], real64), levels(k),      &
                                  x0 + (i - 1) * dx, x0 + i * dx, y0 + (j - 1) * dy, y0 + j * dy, m, sx, sy)
               if (pass == 2_int32 .and. m > 0_int32) then
                  x(n + 1:n + 2 * m) = sx(1:2 * m)
                  y(n + 1:n + 2 * m) = sy(1:2 * m)
               endif
               n = n + 2_int64 * m
            enddo
         enddo
      enddo
      first(size(levels) + 1) = n + 1_int64
      if (pass == 1_int32) then
         deallocate(x, y)
         allocate(x(n), y(n))
      endif
   enddo
   endsubroutine ip_contour_lines_r32

   pure subroutine ip_contour_lines_r64(f, x0, x1, y0, y1, levels, x, y, first)
   !< The contour lines of f at `levels`, as segments, without drawing them (no GUI needed): marching squares on the
   !< cells of four neighbouring samples, f sampled at x = x0 .. x1 and y = y0 .. y1 (uniformly spaced). Level k's
   !< segments join (x(e), y(e)) to (x(e+1), y(e+1)) for e = first(k), first(k) + 2, ... < first(k+1). A line crosses
   !< a cell's edge where linear interpolation of the edge's two values gives the level (a value equal to the level
   !< counts as above it); in a saddle cell (two opposite corners above, the others below) the cell's centre value, the
   !< mean of its corners, decides which corners the lines join. A shared edge gives its point exactly the same in both
   !< cells: closed lines close. Cells with a non-finite corner are skipped (holes); so are non-finite levels.
   !< Double precision.
   real(real64),                intent(in)  :: f(:,:)    !< Field: f(i, j), i along x, j along y.
   real(real64),                intent(in)  :: x0        !< Abscissa of f(1, :).
   real(real64),                intent(in)  :: x1        !< Abscissa of f(size(f, 1), :).
   real(real64),                intent(in)  :: y0        !< Ordinate of f(:, 1).
   real(real64),                intent(in)  :: y1        !< Ordinate of f(:, size(f, 2)).
   real(real64),                intent(in)  :: levels(:) !< Levels.
   real(real64),   allocatable, intent(out) :: x(:)      !< Segment ends, x: (x(2s-1), y(2s-1)) to (x(2s), y(2s)).
   real(real64),   allocatable, intent(out) :: y(:)      !< Segment ends, y.
   integer(int64), allocatable, intent(out) :: first(:)  !< Ends of level k: first(k) .. first(k+1)-1.
   integer(int64)                           :: n         !< Ends.
   integer(int32)                           :: pass      !< 1: count, 2: fill.
   integer(int32)                           :: i, j, k   !< Counters.
   integer(int32)                           :: m         !< Segments in a cell.
   real(real64)                             :: sx(4), sy(4) !< A cell's segments.
   real(real64)                             :: dx, dy    !< Spacing.

   allocate(first(size(levels) + 1))
   allocate(x(0), y(0))
   first = 1_int64
   if (size(f, 1) < 2 .or. size(f, 2) < 2) return
   dx = (x1 - x0) / real(size(f, 1) - 1, real64)
   dy = (y1 - y0) / real(size(f, 2) - 1, real64)
   do pass = 1_int32, 2_int32
      n = 0_int64
      do k = 1_int32, size(levels, kind=int32)
         first(k) = n + 1_int64
         if (.not. finite_value(levels(k))) cycle
         do j = 1_int32, size(f, 2, kind=int32) - 1_int32
            do i = 1_int32, size(f, 1, kind=int32) - 1_int32
               call cell_segments([f(i, j), f(i + 1, j), f(i + 1, j + 1), f(i, j + 1)], levels(k),                    &
                                  x0 + (i - 1) * dx, x0 + i * dx, y0 + (j - 1) * dy, y0 + j * dy, m, sx, sy)
               if (pass == 2_int32 .and. m > 0_int32) then
                  x(n + 1:n + 2 * m) = sx(1:2 * m)
                  y(n + 1:n + 2 * m) = sy(1:2 * m)
               endif
               n = n + 2_int64 * m
            enddo
         enddo
      enddo
      first(size(levels) + 1) = n + 1_int64
      if (pass == 1_int32) then
         deallocate(x, y)
         allocate(x(n), y(n))
      endif
   enddo
   endsubroutine ip_contour_lines_r64

   pure function ip_contour_levels_r32(f, count) result(levels)
   !< About `count` levels at round numbers strictly inside the finite range of f: as `ip_contour_levels_r64`.
   real(real32),   intent(in)           :: f(:,:)    !< Field.
   integer(int32), intent(in), optional :: count     !< Levels wanted, about (default 10).
   real(real64), allocatable            :: levels(:) !< Levels, increasing.
   real(real64)                         :: fmin      !< Smallest finite value.
   real(real64)                         :: fmax      !< Largest finite value.
   logical                              :: found     !< f has finite values.

   call finite_range_r32(f, fmin, fmax, found)
   levels = nice_levels(fmin, fmax, found, count)
   endfunction ip_contour_levels_r32

   pure function ip_contour_levels_r64(f, count) result(levels)
   !< About `count` levels at round numbers strictly inside the finite range [fmin, fmax] of f (NaNs and infinities
   !< ignored): the multiples of a step of 1, 2, 2.5 or 5 times a power of ten, the smallest such step not below
   !< (fmax - fmin) / count. None for a constant field, one without finite values, or `count` < 1. Double precision.
   real(real64),   intent(in)           :: f(:,:)    !< Field.
   integer(int32), intent(in), optional :: count     !< Levels wanted, about (default 10).
   real(real64), allocatable            :: levels(:) !< Levels, increasing.
   real(real64)                         :: fmin      !< Smallest finite value.
   real(real64)                         :: fmax      !< Largest finite value.
   logical                              :: found     !< f has finite values.

   call finite_range_r64(f, fmin, fmax, found)
   levels = nice_levels(fmin, fmax, found, count)
   endfunction ip_contour_levels_r64

   pure subroutine cell_segments(v, level, xl, xr, yb, yt, m, sx, sy)
   !< Marching squares in one cell: the segments of the contour line at `level` through the cell with corner values
   !< v = (bottom-left, bottom-right, top-right, top-left). An edge is crossed when its ends lie on opposite sides of
   !< the level (a value equal to it is above); its point is interpolated from the edge's left (bottom) end, so a shared
   !< edge gives the same point in both cells. A saddle (four edges crossed) is resolved by the centre value, the mean
   !< of the corners: the corners on its side are joined through the centre. A non-finite corner: no segments.
   real(real64),   intent(in)  :: v(4)   !< Corner values: bottom-left, bottom-right, top-right, top-left.
   real(real64),   intent(in)  :: level  !< Level.
   real(real64),   intent(in)  :: xl     !< Left abscissa.
   real(real64),   intent(in)  :: xr     !< Right abscissa.
   real(real64),   intent(in)  :: yb     !< Bottom ordinate.
   real(real64),   intent(in)  :: yt     !< Top ordinate.
   integer(int32), intent(out) :: m      !< Segments: 0, 1 or 2.
   real(real64),   intent(out) :: sx(4)  !< Segment ends, x: (sx(1), sy(1)) to (sx(2), sy(2)), then 3 to 4.
   real(real64),   intent(out) :: sy(4)  !< Segment ends, y.
   integer(int32), parameter   :: LO(4) = [1_int32, 2_int32, 4_int32, 1_int32] !< Edges' first corners: bottom, right,
   integer(int32), parameter   :: HI(4) = [2_int32, 3_int32, 3_int32, 4_int32] !< top, left; and their second ones.
   real(real64)                :: cx(4)  !< Corner abscissae.
   real(real64)                :: cy(4)  !< Corner ordinates.
   real(real64)                :: ex(4)  !< Crossing points on the edges, x.
   real(real64)                :: ey(4)  !< Crossing points on the edges, y.
   real(real64)                :: t      !< Position along an edge.
   logical                     :: up(4)  !< Corners at or above the level.
   integer(int32)              :: e(4)   !< Crossed edges.
   integer(int32)              :: ne     !< Their number.
   integer(int32)              :: k      !< Counter.

   m = 0_int32
   sx = 0.0_real64
   sy = 0.0_real64
   if (.not. all(finite_value(v))) return ! a hole (and no ordered comparison with a NaN: an FPE under traps)
   up = v >= level
   cx = [xl, xr, xr, xl]
   cy = [yb, yb, yt, yt]
   ex = 0.0_real64
   ey = 0.0_real64
   ne = 0_int32
   e = 0_int32
   do k = 1_int32, 4_int32
      if (up(LO(k)) .neqv. up(HI(k))) then
         t = (level - v(LO(k))) / (v(HI(k)) - v(LO(k)))
         ex(k) = cx(LO(k)) + t * (cx(HI(k)) - cx(LO(k)))
         ey(k) = cy(LO(k)) + t * (cy(HI(k)) - cy(LO(k)))
         ne = ne + 1_int32
         e(ne) = k
      endif
   enddo
   if (ne == 2_int32) then
      m = 1_int32
      sx(1:2) = ex(e(1:2))
      sy(1:2) = ey(e(1:2))
   elseif (ne == 4_int32) then ! a saddle
      m = 2_int32
      if (up(1) .eqv. (0.25_real64 * v(1) + 0.25_real64 * v(2) + 0.25_real64 * v(3) + 0.25_real64 * v(4) >= level)) then
         e = [1_int32, 2_int32, 3_int32, 4_int32] ! bottom-left and top-right joined: the other two corners cut off
      else
         e = [1_int32, 4_int32, 2_int32, 3_int32] ! bottom-right and top-left joined: bottom-left and top-right cut off
      endif
      sx = ex(e)
      sy = ey(e)
   endif
   endsubroutine cell_segments

   pure subroutine finite_range_r32(f, fmin, fmax, found)
   !< The smallest and largest finite values of f (0, 0 and found false if none).
   real(real32), intent(in)  :: f(:,:) !< Field.
   real(real64), intent(out) :: fmin   !< Smallest finite value.
   real(real64), intent(out) :: fmax   !< Largest finite value.
   logical,      intent(out) :: found  !< f has finite values.
   integer(int64)            :: i, j   !< Counters.

   fmin = 0.0_real64
   fmax = 0.0_real64
   found = .false.
   do j = 1_int64, size(f, 2, kind=int64)
      do i = 1_int64, size(f, 1, kind=int64)
         if (.not. finite_value(f(i, j))) cycle
         if (.not. found) then
            fmin = real(f(i, j), real64)
            fmax = fmin
            found = .true.
         endif
         fmin = min(fmin, real(f(i, j), real64))
         fmax = max(fmax, real(f(i, j), real64))
      enddo
   enddo
   endsubroutine finite_range_r32

   pure subroutine finite_range_r64(f, fmin, fmax, found)
   !< The smallest and largest finite values of f (0, 0 and found false if none).
   real(real64), intent(in)  :: f(:,:) !< Field.
   real(real64), intent(out) :: fmin   !< Smallest finite value.
   real(real64), intent(out) :: fmax   !< Largest finite value.
   logical,      intent(out) :: found  !< f has finite values.
   integer(int64)            :: i, j   !< Counters.

   fmin = 0.0_real64
   fmax = 0.0_real64
   found = .false.
   do j = 1_int64, size(f, 2, kind=int64)
      do i = 1_int64, size(f, 1, kind=int64)
         if (.not. finite_value(f(i, j))) cycle
         if (.not. found) then
            fmin = f(i, j)
            fmax = fmin
            found = .true.
         endif
         fmin = min(fmin, f(i, j))
         fmax = max(fmax, f(i, j))
      enddo
   enddo
   endsubroutine finite_range_r64

   pure function nice_levels(fmin, fmax, found, count) result(levels)
   !< About `count` levels at multiples of a round step strictly inside (fmin, fmax) (see `ip_contour_levels_r64`).
   real(real64),   intent(in)           :: fmin      !< Smallest value.
   real(real64),   intent(in)           :: fmax      !< Largest value.
   logical,        intent(in)           :: found     !< The range exists.
   integer(int32), intent(in), optional :: count     !< Levels wanted (default 10).
   real(real64), allocatable            :: levels(:) !< Levels, increasing.
   real(real64), parameter              :: STEPS(5) = [1.0_real64, 2.0_real64, 2.5_real64, 5.0_real64, 10.0_real64]
   real(real64)                         :: raw       !< (fmax - fmin) / count.
   real(real64)                         :: p         !< A power of ten.
   real(real64)                         :: step      !< The step.
   integer(int32)                       :: n         !< Levels wanted.
   integer(int32)                       :: k         !< Counter.
   integer(int64)                       :: k0, k1    !< Multiples of the step around the range.
   integer(int64)                       :: q         !< Counter.

   allocate(levels(0))
   n = 10_int32
   if (present(count)) n = count
   if (.not. found .or. n < 1_int32 .or. .not. fmax > fmin) return
   if (.not. ieee_is_finite(fmax - fmin)) return
   raw = (fmax - fmin) / real(n, real64)
   p = 10.0_real64**floor(log10(raw))
   step = STEPS(5) * p
   do k = 4_int32, 1_int32, -1_int32
      if (raw <= STEPS(k) * p * (1.0_real64 + 1.0e-12_real64)) step = STEPS(k) * p
   enddo
   if (max(abs(fmin), abs(fmax)) / step > 1.0e15_real64) then ! multiples beyond an integer: uniform levels instead
      levels = [(fmin + (fmax - fmin) * real(k, real64) / real(n + 1, real64), k = 1_int32, n)]
      return
   endif
   k0 = floor(fmin / step, int64)
   k1 = ceiling(fmax / step, int64)
   levels = pack([(real(q, real64) * step, q = k0, k1)], [(real(q, real64) * step > fmin .and. &
                                                            real(q, real64) * step < fmax, q = k0, k1)])
   endfunction nice_levels

   function contour_ok(nlevels, colormap, color, cmap, stat) result(ok)
   !< Whether ip_contour's options are valid; the colormap id to draw with.
   integer(int32), intent(in), optional  :: nlevels  !< Automatic levels wanted.
   integer(int32), intent(in), optional  :: colormap !< Colormap id.
   real(real64),   intent(in), optional  :: color(:) !< One colour, RGBA.
   integer(c_int), intent(out)           :: cmap     !< The colormap id (Viridis when absent).
   integer(int32), intent(out), optional :: stat     !< Status, on a failure.
   logical                               :: ok       !< Valid.

   ok = .false.
   cmap = int(ImPlotColormap_Viridis, c_int)
   if (.not. rgba_ok(color)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_contour: a colour needs 4 components (RGBA)', stat)
      return
   endif
   if (present(nlevels)) then
      if (nlevels < 1_int32) then
         call figure_fail(FIG_ERR_ARGUMENT, 'ip_contour: nlevels must be 1 or more', stat)
         return
      endif
   endif
   if (present(colormap)) then
      if (.not. colormap_ok('ip_contour', colormap, cmap, stat)) return
   endif
   ok = .true.
   endfunction contour_ok

   subroutine contour_draw(label, lev, xs, ys, first, fmin, fmax, by_map, cmap, color, labels, line_weight, stat)
   !< Draw contour segments, one line item per level, all under `label`.
   character(len=*), intent(in)            :: label       !< Legend label.
   real(real64),     intent(in)            :: lev(:)      !< Levels.
   real(real64),     intent(in), target    :: xs(:)       !< Segment ends, x.
   real(real64),     intent(in), target    :: ys(:)       !< Segment ends, y.
   integer(int64),   intent(in)            :: first(:)    !< First end of each level.
   real(real64),     intent(in)            :: fmin        !< Field's finite range: the colormap's bottom ...
   real(real64),     intent(in)            :: fmax        !< ... and top.
   logical,          intent(in)            :: by_map      !< Colour from the colormap.
   integer(c_int),   intent(in)            :: cmap        !< Colormap id.
   real(real64),     intent(in), optional  :: color(:)    !< One colour, RGBA.
   logical,          intent(in), optional  :: labels      !< Write the levels' values.
   real(real64),     intent(in), optional  :: line_weight !< Line weight [pixels].
   integer(int32),   intent(out), optional :: stat        !< Status.
   type(plot_item_spec)                    :: c           !< Line style.
   real(real64)                            :: v(4)        !< A colormap colour, or the last item's.
   real(real64)                            :: lc(4)       !< The given line colour.
   integer(int64)                          :: n           !< Ends of a level.
   integer(int64)                          :: e           !< An end: the first of the level's middle segment.
   integer(int32)                          :: k           !< Counter.
   integer(int32)                          :: col, j      !< A packed colour, a channel.
   real(real64)                            :: t           !< Position in the colormap.
   logical                                 :: write_text  !< Labels wanted.

   do k = 1_int32, size(lev, kind=int32)
      if (first(k + 1) - first(k) > int(huge(0_c_int), int64)) then
         call figure_fail(FIG_ERR_ARGUMENT, 'ip_contour: a level has more segment ends than a C int can count', stat)
         return
      endif
   enddo
   write_text = .false.
   if (present(labels)) write_text = labels
   lc = 0.0_real64
   if (present(color)) lc = real(real(color, c_float), real64) ! ImVec4 floats, as the spec holds them
   do k = 1_int32, size(lev, kind=int32)
      n = first(k + 1) - first(k)
      if (n < 2_int64) cycle
      if (by_map) then
         t = 0.5_real64
         if (fmax > fmin) t = min(1.0_real64, max(0.0_real64, (lev(k) - fmin) / (fmax - fmin)))
         col = cm_sample(cm_frame_id(int(cmap, int32)), real(t, real32)) ! SampleColormap: ColorConvertU32ToFloat4 of the sample
         do j = 1_int32, 4_int32
            v(j) = real(real(iand(ishft(col, -8_int32 * (j - 1_int32)), 255_int32), real32) * &
                        (1.0_real32 / 255.0_real32), real64)
         enddo
         c = pf_spec(line_color=v, line_weight=line_weight, flags=int(PF_LINE_SEGMENTS, int32))
      elseif (present(color)) then
         c = pf_spec(line_color=lc, line_weight=line_weight, flags=int(PF_LINE_SEGMENTS, int32))
      else
         c = pf_spec(line_weight=line_weight, flags=int(PF_LINE_SEGMENTS, int32))
      endif
      call pf_line(label, xs(first(k):first(k) + n - 1_int64), ys(first(k):first(k) + n - 1_int64), spec=c)
      if (write_text) then ! on a segment part-way through the level's list (rows bottom to top), by level: apart
         e = first(k) + 2_int64 * int(real(n / 2_int64, real64) * (k - 0.5_real64) / size(lev), int64)
         v = pf_last_item_color()
         call pf_annotation(0.5_c_double * (xs(e) + xs(e + 1)), 0.5_c_double * (ys(e) + ys(e + 1)), level_text(lev(k)), &
                            color=v, clamp=.false.)
      endif
   enddo
   call figure_check(FIG_OK, stat)
   endsubroutine contour_draw

   pure function level_text(v) result(text)
   !< A level's value, short: 0.25, -3, 1.5e+06.
   real(real64), intent(in)      :: v    !< Value.
   character(len=:), allocatable :: text !< Text.
   character(len=32)             :: buf  !< Buffer.
   integer                       :: i    !< Last character kept.

   if (v == 0.0_real64) then
      text = '0'
      return
   endif
   if (abs(v) >= 1.0e-3_real64 .and. abs(v) < 1.0e6_real64) then
      write(buf, '(F32.6)') v
      buf = adjustl(buf)
      i = len_trim(buf)
      do while (buf(i:i) == '0')
         i = i - 1
      enddo
      if (buf(i:i) == '.') i = i - 1
      text = buf(1:i)
   else
      write(buf, '(ES12.3)') v
      text = trim(adjustl(buf))
   endif
   endfunction level_text

   recursive function drag_ok(caller, color, stat) result(ok)
   !< Whether a drag tool can be drawn: not from a task, a colour of 4 components if given.
   character(len=*), intent(in)            :: caller   !< The entry point.
   real(real64),     intent(in), optional  :: color(:) !< Colour, RGBA.
   integer(int32),   intent(out), optional :: stat     !< Status, on a failure.
   logical                                 :: ok       !< Drawable.

   ok = .false.
   if (figure_refused(caller, stat)) return ! a task does not draw
   if (.not. rgba_ok(color)) then
      call figure_fail(FIG_ERR_ARGUMENT, caller//': a colour needs 4 components (RGBA)', stat)
      return
   endif
   ok = .true.
   endfunction drag_ok

   function colormap_ok(caller, colormap, cmap, stat) result(ok)
   !< The colormap id to draw with (default ImPlot's Viridis); false, with `FIG_ERR_ARGUMENT`, if it is not registered.
   character(len=*),         intent(in)            :: caller   !< Calling procedure, for the message.
   integer(int32), optional, intent(in)            :: colormap !< Colormap id, if given.
   integer(c_int),           intent(out)           :: cmap     !< The id to use.
   integer(int32),           intent(out), optional :: stat     !< Status, on a failure.
   logical                                         :: ok       !< Usable.
   character(len=12)                               :: text     !< The id, printed.

   cmap = int(ImPlotColormap_Viridis, c_int) ! perceptually uniform: not the line colours ImPlot's current map holds
   if (present(colormap)) cmap = int(colormap, c_int)
   ok = cmap >= 0_c_int .and. cmap < ImPlot_GetColormapCount() ! (the ids are the native registry's: frame_cmap)
   if (.not. ok) then
      write(text, '(I0)') cmap
      call figure_fail(FIG_ERR_ARGUMENT, caller//': the colormap '//trim(text)//' is not registered (see ip_colormap)', &
                       stat)
   endif
   endfunction colormap_ok

   pure function axis_index(name) result(code)
   !< ImAxis of an axis name: 'x1', 'x2', 'x3', 'y1', 'y2', 'y3' ('x' and 'y': x1 and y1); -1 for any other.
   character(len=*), intent(in) :: name !< Axis name.
   integer(c_int)               :: code !< ImAxis, or -1.

   select case (trim(name))
   case ('x', 'x1')
      code = ImAxis_X1
   case ('x2')
      code = ImAxis_X2
   case ('x3')
      code = ImAxis_X3
   case ('y', 'y1')
      code = ImAxis_Y1
   case ('y2')
      code = ImAxis_Y2
   case ('y3')
      code = ImAxis_Y3
   case default
      code = -1_c_int
   endselect
   endfunction axis_index

   function scale_given_ok(caller, prefix, log, scale, code, stat) result(ok)
   !< The scale asked by a `log` flag (v0.3) and a `scale` name: its ImPlotScale in `code`; false (reported,
   !< `FIG_ERR_ARGUMENT`) for an unknown name or a flag and a name that disagree.
   character(len=*), intent(in)            :: caller !< The procedure.
   character(len=*), intent(in)            :: prefix !< 'x', 'y' (`xscale`, `xlog`) or '' (`scale`).
   logical,          intent(in),  optional :: log    !< Logarithmic (deprecated flag).
   character(len=*), intent(in),  optional :: scale  !< 'linear', 'log', 'symlog', 'time'.
   integer(c_int),   intent(out)           :: code   !< ImPlotScale.
   integer(int32),   intent(out), optional :: stat   !< Status, on a refusal.
   logical                                 :: ok     !< Not refused.

   ok = .false.
   code = ImPlotScale_Linear
   if (present(scale)) then
      select case (trim(scale))
      case ('linear')
         code = ImPlotScale_Linear
      case ('log')
         code = ImPlotScale_Log10
      case ('symlog')
         code = ImPlotScale_SymLog
      case ('time')
         code = ImPlotScale_Time
      case default
         call figure_fail(FIG_ERR_ARGUMENT, caller//': unknown '//prefix//"scale '"//scale//"' ('linear', 'log', "// &
                          "'symlog' or 'time')", stat)
         return
      endselect
   endif
   if (present(log)) then
      if (present(scale) .and. (log .neqv. code == ImPlotScale_Log10)) then
         call figure_fail(FIG_ERR_ARGUMENT, caller//': '//prefix//'log and '//prefix//"scale '"//scale//"' disagree "// &
                          '(give '//prefix//'scale only: '//prefix//'log is deprecated)', stat)
         return
      endif
      if (log) code = ImPlotScale_Log10
   endif
   ok = .true.
   endfunction scale_given_ok

   recursive function plot_refused(caller, setup, stat) result(refused)
   !< True (a usage error reported, `FIG_ERR_STATE`) with no plot being declared or, when `setup`, with its setup over.
   character(len=*), intent(in)            :: caller  !< The procedure.
   logical,          intent(in)            :: setup   !< The call is part of the setup.
   integer(int32),   intent(out), optional :: stat    !< Status, on a refusal.
   logical                                 :: refused !< Refused: return.
   integer(int32)                          :: on(6)   !< Axes set up.
   integer(int32)                          :: sc(6)   !< Their scales.
   integer(int32)                          :: state   !< 0 no plot, 1 setup open, 2 setup over.

   refused = .true.
   state = pf_plot_state(on, sc)
   if (state == 0_int32) then
      call figure_usage_error(caller//': no plot is being declared (call it between a true ip_begin_plot and '// &
                              'ip_end_plot)', stat)
      return
   endif
   if (setup .and. state == 2_int32) then
      call figure_usage_error(caller//': the setup of the plot is over (call the ip_setup_* procedures before the '// &
                              'first item, ip_set_axes and ip_plot_limits)', stat)
      return
   endif
   refused = .false.
   endfunction plot_refused

   recursive function setup_refused(caller, stat) result(refused)
   !< True (a usage error reported) outside a plot or after its setup is over: the ImPlot setup calls assert there.
   character(len=*), intent(in)            :: caller  !< The procedure.
   integer(int32),   intent(out), optional :: stat    !< Status, on a refusal.
   logical                                 :: refused !< Refused: return.

   refused = plot_refused(caller, .true., stat)
   endfunction setup_refused

   recursive function axis_refused(caller, axis, code, setup, stat) result(refused)
   !< True (reported) for an unknown axis name (`FIG_ERR_ARGUMENT`), no plot being declared, its setup over when
   !< `setup`, or an axis not set up on this frame (usage errors, `FIG_ERR_STATE`). `code`: the axis's ImAxis.
   character(len=*), intent(in)            :: caller  !< The procedure.
   character(len=*), intent(in)            :: axis    !< Axis name.
   integer(c_int),   intent(out)           :: code    !< ImAxis.
   logical,          intent(in)            :: setup   !< The call is part of the setup.
   integer(int32),   intent(out), optional :: stat    !< Status, on a refusal.
   logical                                 :: refused !< Refused: return.
   integer(int32)                          :: on(6)   !< Axes set up.
   integer(int32)                          :: sc(6)   !< Their scales.
   integer(int32)                          :: state   !< Plot state.

   refused = .true.
   code = axis_index(axis)
   if (code < 0_c_int) then
      call figure_fail(FIG_ERR_ARGUMENT, caller//": unknown axis '"//axis//"' ('x1', 'x2', 'x3', 'y1', 'y2' or "// &
                       "'y3')", stat)
      return
   endif
   if (plot_refused(caller, setup, stat)) return
   state = pf_plot_state(on, sc)
   if (on(code + 1_c_int) == 0_int32) then
      call figure_usage_error(caller//": axis '"//trim(axis)//"' is not set up (call ip_setup_axis('"//trim(axis)// &
                              "') first, on every frame)", stat)
      return
   endif
   refused = .false.
   endfunction axis_refused

   function pair_ok(caller, xname, x, yname, y, cx, cy, stat) result(ok)
   !< The ImAxis of an x axis name `x` (argument `xname`, skipped when '') and of a y axis name `y`; false (reported,
   !< `FIG_ERR_ARGUMENT`) for a name that is not an axis of its direction.
   character(len=*), intent(in)            :: caller !< The procedure.
   character(len=*), intent(in)            :: xname  !< Argument name of x ('': no x).
   character(len=*), intent(in)            :: x      !< X axis name.
   character(len=*), intent(in)            :: yname  !< Argument name of y ('': no y).
   character(len=*), intent(in)            :: y      !< Y axis name.
   integer(c_int),   intent(inout)         :: cx     !< ImAxis of x (unchanged without x).
   integer(c_int),   intent(inout)         :: cy     !< ImAxis of y (unchanged without y).
   integer(int32),   intent(out), optional :: stat   !< Status, on a refusal.
   logical                                 :: ok     !< Not refused.

   ok = .false.
   if (len(xname) > 0) then
      cx = axis_index(x)
      if (cx < ImAxis_X1 .or. cx > ImAxis_X3) then
         call figure_fail(FIG_ERR_ARGUMENT, caller//': '//xname//" '"//x//"' is not an x axis ('x1', 'x2' or 'x3')", &
                          stat)
         return
      endif
   endif
   if (len(yname) > 0) then
      cy = axis_index(y)
      if (cy < ImAxis_Y1 .or. cy > ImAxis_Y3) then
         call figure_fail(FIG_ERR_ARGUMENT, caller//': '//yname//" '"//y//"' is not a y axis ('y1', 'y2' or 'y3')", &
                          stat)
         return
      endif
   endif
   ok = .true.
   endfunction pair_ok

   function range_ok(caller, lo_name, lo, hi_name, hi, stat) result(ok)
   !< False (reported, `FIG_ERR_ARGUMENT`) for a NaN end or `lo >= hi`.
   character(len=*), intent(in)            :: caller  !< The procedure.
   character(len=*), intent(in)            :: lo_name !< Name of the lower end.
   real(real64),     intent(in)            :: lo      !< Lower end.
   character(len=*), intent(in)            :: hi_name !< Name of the upper end.
   real(real64),     intent(in)            :: hi      !< Upper end.
   integer(int32),   intent(out), optional :: stat    !< Status, on a refusal.
   logical                                 :: ok      !< Not refused.

   ok = .false.
   if (ieee_is_nan(lo) .or. ieee_is_nan(hi)) then
      call figure_fail(FIG_ERR_ARGUMENT, caller//': '//lo_name//' and '//hi_name//' must not be NaN', stat)
      return
   endif
   if (.not. lo < hi) then
      call figure_fail(FIG_ERR_ARGUMENT, caller//': '//lo_name//' must be below '//hi_name, stat)
      return
   endif
   ok = .true.
   endfunction range_ok

   recursive function axes_refused(caller, xaxis, yaxis, cx, cy, stat) result(refused)
   !< The ImAxis of an optional x axis name and y axis name (-1, the current axes, when absent); true (reported) for a
   !< name that is not an axis of its direction (`FIG_ERR_ARGUMENT`), no plot being declared or an axis not set up
   !< (usage errors, `FIG_ERR_STATE`).
   character(len=*), intent(in)            :: caller  !< The procedure.
   character(len=*), intent(in),  optional :: xaxis   !< 'x1', 'x2' or 'x3'.
   character(len=*), intent(in),  optional :: yaxis   !< 'y1', 'y2' or 'y3'.
   integer(c_int),   intent(out)           :: cx      !< ImAxis of x (-1: the current one).
   integer(c_int),   intent(out)           :: cy      !< ImAxis of y (-1: the current one).
   integer(int32),   intent(out), optional :: stat    !< Status, on a refusal.
   logical                                 :: refused !< Refused: return.

   refused = .true.
   cx = -1_c_int ! IMPLOT_AUTO: the current axes
   cy = -1_c_int
   if (present(xaxis)) then
      if (.not. pair_ok(caller, 'xaxis', xaxis, '', '', cx, cy, stat)) return
      if (axis_refused(caller, xaxis, cx, .false., stat)) return
   endif
   if (present(yaxis)) then
      if (.not. pair_ok(caller, '', '', 'yaxis', yaxis, cx, cy, stat)) return
      if (axis_refused(caller, yaxis, cy, .false., stat)) return
   endif
   if (.not. (present(xaxis) .or. present(yaxis))) then
      if (plot_refused(caller, .false., stat)) return
   endif
   refused = .false.
   endfunction axes_refused

   function bins_ok(caller, name, bins, nb, stat) result(ok)
   !< The bins of a histogram: a count > 0 or an `ImPlotBin_*` rule (default Sturges'), in `nb`; false (reported,
   !< `FIG_ERR_ARGUMENT`) for any other value.
   character(len=*), intent(in)            :: caller !< The procedure.
   character(len=*), intent(in)            :: name   !< The argument's name.
   integer(int32),   intent(in),  optional :: bins   !< Bins given.
   integer(c_int),   intent(out)           :: nb     !< Bins: a count, or a rule (negative).
   integer(int32),   intent(out), optional :: stat   !< Status, on a refusal.
   logical                                 :: ok     !< Not refused.

   ok = .true.
   nb = ImPlotBin_Sturges
   if (.not. present(bins)) return
   nb = int(bins, c_int)
   if (nb == 0_c_int .or. nb < ImPlotBin_Scott) then
      call figure_fail(FIG_ERR_ARGUMENT, caller//': '//name//' must be a count above 0 or an ImPlotBin_* rule', stat)
      ok = .false.
   endif
   endfunction bins_ok

   function ends_ok(caller, lo_name, lo, hi_name, hi, stat) result(ok)
   !< Two optional ends of a range: both or neither, not NaN, `lo < hi`; false (reported, `FIG_ERR_ARGUMENT`) otherwise.
   character(len=*), intent(in)            :: caller  !< The procedure.
   character(len=*), intent(in)            :: lo_name !< Name of the lower end.
   real(real64),     intent(in),  optional :: lo      !< Lower end.
   character(len=*), intent(in)            :: hi_name !< Name of the upper end.
   real(real64),     intent(in),  optional :: hi      !< Upper end.
   integer(int32),   intent(out), optional :: stat    !< Status, on a refusal.
   logical                                 :: ok      !< Not refused.

   ok = .false.
   if (present(lo) .neqv. present(hi)) then
      call figure_fail(FIG_ERR_ARGUMENT, caller//': give both '//lo_name//' and '//hi_name//', or neither', stat)
      return
   endif
   if (present(lo)) then
      if (.not. range_ok(caller, lo_name, lo, hi_name, hi, stat)) return
   endif
   ok = .true.
   endfunction ends_ok

   function in_line_r32(a) result(contiguous_)
   !< Whether an array's elements are adjacent in memory (its stride is its element size).
   real(real32), intent(in), target :: a(:)        !< Array.
   logical                          :: contiguous_ !< Adjacent.

   contiguous_ = .true.
   if (size(a) > 1) contiguous_ = series_gap(c_loc(a(1)), c_loc(a(2))) == storage_size(a, kind=int64) / 8_int64
   endfunction in_line_r32

   function in_line_r64(a) result(contiguous_)
   !< Whether an array's elements are adjacent in memory (its stride is its element size).
   real(real64), intent(in), target :: a(:)        !< Array.
   logical                          :: contiguous_ !< Adjacent.

   contiguous_ = .true.
   if (size(a) > 1) contiguous_ = series_gap(c_loc(a(1)), c_loc(a(2))) == storage_size(a, kind=int64) / 8_int64
   endfunction in_line_r64

   recursive function outside_plot(caller, stat) result(refused)
   !< True (a usage error reported) when no plot is being declared: ImPlot's items need one (with its assertions off,
   !< as in the 'report' and 'recover' checks modes, an item outside a plot dereferences a null plot).
   character(len=*), intent(in)            :: caller  !< The procedure.
   integer(int32),   intent(out), optional :: stat    !< Status, on a refusal.
   logical                                 :: refused !< Refused: return.
   integer(int32)                          :: on(6)   !< Axes enabled (unused).
   integer(int32)                          :: sc(6)   !< Axes' scales (unused).

   refused = pf_plot_state(on, sc) == 0_int32
   if (refused) call figure_usage_error(caller//': no plot is being declared (call it between a true ip_begin_plot '// &
                                        'and ip_end_plot)', stat)
   endfunction outside_plot

   function series_ok(nx, ny, item, stat) result(ok)
   !< Whether two series can be plotted together: same size, and a size ImPlot's `int` count holds.
   integer(int64),   intent(in)            :: nx   !< Size of the first series.
   integer(int64),   intent(in)            :: ny   !< Size of the second series.
   character(len=*), intent(in)            :: item !< Item name, for the message.
   integer(int32),   intent(out), optional :: stat !< Status.
   logical                                 :: ok   !< Plottable.

   ok = .false.
   if (nx /= ny) then
      call figure_fail(FIG_ERR_ARGUMENT, item//': the series have different sizes', stat)
   elseif (nx > int(huge(0_c_int), int64)) then
      call figure_fail(FIG_ERR_ARGUMENT, item//': more points than a C int can count', stat)
   else
      ok = .true.
   endif
   endfunction series_ok

   function field_ok(nx, ny, has_min, has_max, stat) result(ok)
   !< Whether a field can be drawn as a heatmap: a cell count ImPlot's `int` holds, and both scale ends or none.
   integer(int64), intent(in)            :: nx      !< size(f, 1).
   integer(int64), intent(in)            :: ny      !< size(f, 2).
   logical,        intent(in)            :: has_min !< scale_min given.
   logical,        intent(in)            :: has_max !< scale_max given.
   integer(int32), intent(out), optional :: stat    !< Status.
   logical                               :: ok      !< Drawable.

   ok = .false.
   if (has_min .neqv. has_max) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_heatmap: give both scale_min and scale_max, or neither', stat)
   elseif (nx * ny > int(huge(0_c_int), int64)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_heatmap: more cells than a C int can count', stat)
   else
      ok = .true.
   endif
   endfunction field_ok

   function row_ok(rows, cols, bits, row, stat) result(ok)
   !< Whether a matrix row can be plotted in place: the row exists, and ImPlot's `int` count and byte stride hold it.
   integer(int64), intent(in)            :: rows !< size(y, 1).
   integer(int64), intent(in)            :: cols !< size(y, 2): points.
   integer(int64), intent(in)            :: bits !< storage_size of an element [bits].
   integer(int32), intent(in)            :: row  !< Row to plot.
   integer(int32), intent(out), optional :: stat !< Status.
   logical                               :: ok   !< Plottable.

   ok = .false.
   if (row < 1_int32 .or. int(row, int64) > rows) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_line: row out of range', stat)
   elseif (cols > int(huge(0_c_int), int64)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_line: more points than a C int can count', stat)
   elseif (rows * bits / 8_int64 > int(huge(0_c_int), int64)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_line: row stride beyond a C int (bytes)', stat)
   else
      ok = .true.
   endif
   endfunction row_ok

   pure function rgba_ok(color) result(ok)
   !< Whether an optional colour is absent or has 4 components.
   real(real64), intent(in), optional :: color(:) !< Colour, RGBA.
   logical                            :: ok       !< Acceptable.

   ok = .true.
   if (present(color)) ok = size(color) == 4
   endfunction rgba_ok

   ! the Fortran path's own: its entry, the scope record's hooks, the counters of the current path

   recursive function refused(caller, stat) result(r)
   !< `figure_draw_refused` (a task, no frame open); when not refused, the path made ready (`plot_path_ready`).
   character(len=*), intent(in)            :: caller !< The entry point.
   integer(int32),   intent(out), optional :: stat   !< Status, on a refusal.
   logical                                 :: r      !< Refused: return.

   r = figure_draw_refused(caller, stat)
   if (.not. r) call plot_path_ready()
   endfunction refused

   function item_spec(spec) result(s)
   !< The frame's style of an item: the given one, or ImPlot's defaults.
   type(plot_spec_object), intent(in), optional :: spec !< Style.
   type(plot_item_spec)                         :: s    !< The frame's.

   if (present(spec)) then
      s = spec%s
   else
      s = plot_item_spec()
   endif
   endfunction item_spec

   pure function scale_name(code) result(name)
   !< The frame's name of an ImPlotScale ('linear' leaves an axis's scale as it is, as `SetupAxisScale` is called for
   !< the others only).
   integer(c_int), intent(in)    :: code !< ImPlotScale.
   character(len=:), allocatable :: name !< Name.

   select case (code)
   case (ImPlotScale_Log10)
      name = 'log'
   case (ImPlotScale_SymLog)
      name = 'symlog'
   case (ImPlotScale_Time)
      name = 'time'
   case default
      name = 'linear'
   endselect
   endfunction scale_name

   subroutine cm_push_left(cmap)
   !< The current path's `PushColormap` before a refusal for an item outside a plot (`ip_heatmap`, `ip_pie_chart`):
   !< ImPlot's map stack keeps it, so the program's later items take their colours from it; mirrored (the notes of
   !< the switch).
   integer(int32), intent(in) :: cmap !< Map.

   call cm_push(cmap)
   endsubroutine cm_push_left

   ! test_plot_copies and test_plot_stride: what the current path copies (figure_plot_series' series_lead, series_put)
   ! and the stride it gives ImPlot, counted without copying (the frame reads every array in place)

   subroutine acct_lead_r32(s, a)
   !< `series_lead`: the item's stride from its ordinates (a positive multiple of the element size within a C int,
   !< else a copy, contiguous).
   integer(int64), intent(out)                        :: s    !< The item's stride [bytes].
   real(real32),   intent(in), target, asynchronous   :: a(:) !< Array.
   integer(int64)                                     :: g    !< Its stride [bytes].

   s = storage_size(a, kind=int64) / 8_int64
   if (size(a) == 0) return
   g = s
   if (size(a) > 1) g = series_gap(c_loc(a(1)), c_loc(a(2)))
   if (g > 0_int64 .and. mod(g, s) == 0_int64 .and. g <= int(huge(0_c_int), int64)) then
      s = g
   else
      plot_copies = plot_copies + 1_int64
   endif
   endsubroutine acct_lead_r32

   subroutine acct_lead_r64(s, a)
   !< `series_lead`, double precision.
   integer(int64), intent(out)                        :: s    !< The item's stride [bytes].
   real(real64),   intent(in), target, asynchronous   :: a(:) !< Array.
   integer(int64)                                     :: g    !< Its stride [bytes].

   s = storage_size(a, kind=int64) / 8_int64
   if (size(a) == 0) return
   g = s
   if (size(a) > 1) g = series_gap(c_loc(a(1)), c_loc(a(2)))
   if (g > 0_int64 .and. mod(g, s) == 0_int64 .and. g <= int(huge(0_c_int), int64)) then
      s = g
   else
      plot_copies = plot_copies + 1_int64
   endif
   endsubroutine acct_lead_r64

   subroutine acct_put_r32(s, a)
   !< `series_put`: another array read in place at the item's stride, else copied.
   integer(int64), intent(in)                         :: s    !< The item's stride [bytes].
   real(real32),   intent(in), target, asynchronous   :: a(:) !< Array.

   if (size(a) <= 1) return
   if (series_gap(c_loc(a(1)), c_loc(a(2))) == s) return
   plot_copies = plot_copies + 1_int64
   endsubroutine acct_put_r32

   subroutine acct_put_r64(s, a)
   !< `series_put`, double precision.
   integer(int64), intent(in)                         :: s    !< The item's stride [bytes].
   real(real64),   intent(in), target, asynchronous   :: a(:) !< Array.

   if (size(a) <= 1) return
   if (series_gap(c_loc(a(1)), c_loc(a(2))) == s) return
   plot_copies = plot_copies + 1_int64
   endsubroutine acct_put_r64

   subroutine acct_put_int(n)
   !< `series_put` of integer abscissae: converted, a copy.
   integer(int64), intent(in) :: n !< Values.

   if (n > 0_int64) plot_copies = plot_copies + 1_int64
   endsubroutine acct_put_int

   subroutine acct_item(s, es)
   !< The stride given to ImPlot for a line-like item (`series_spec` after `series_decimate`): the element size when
   !< decimated (the kept points' buffers), else the item's.
   integer(int64), intent(in) :: s  !< The item's stride [bytes].
   integer(int64), intent(in) :: es !< Element size [bytes].

   if (pf_last_decimated) then
      plot_stride = es
   else
      plot_stride = s
   endif
   endsubroutine acct_item
endmodule figure_implot
