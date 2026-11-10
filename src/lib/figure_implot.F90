!< figure_implot, ImPlot plots with Fortran arrays.
module figure_implot
!< figure_implot, ImPlot plots with Fortran arrays.
!<
!< Every drawing procedure of this module refuses a call from a task (`FIG_ERR_STATE`): see processes.md; and a call
!< with no frame open, a usage error (`FIG_ERR_STATE`, `<procedure>: no frame open`). Every begin/end and push/pop
!< pair registers in the scope record of the frame, which checks each end before Dear ImGui sees it: a wrong end is
!< refused and reported by `app%next_frame` (`app%set_checks`; errors.md, "Pairing and frames").
!<
!< `ip_begin_plot` returns true when the plot is visible: then declare its axes and items and close it with
!< `ip_end_plot` (only in that case). Items (`ip_line`, `ip_scatter`, `ip_bars`, `ip_shaded`, `ip_error_bars`) take
!< `real(real32)` or `real(real64)` arrays of any stride (a matrix row `y(i,:)`, `y(::2)`, a component of an array of
!< derived types `runs%cl`), read in place during the call: they go to ImPlot's `float*` or `double*` items with
!< ImPlot's byte stride (`ImPlotSpec::Stride`). ImPlot has one stride for all the arrays of an item: an array whose
!< stride differs from the ordinates' is copied, laid out at their stride. Abscissae may be `integer(int32)` or
!< `integer(int64)` (iteration counters): ImPlot reads x and y of one type, so they are converted into a temporary.
!< The items' array dummies are ASYNCHRONOUS: nvfortran then passes strided sections in place instead of copying them
!< before the call (what each compiler passes: plots.md, "Data in place"). The stride helpers' dummies are too:
!< without it nvfortran copies at the inner call, and the address given to ImPlot is that of a freed temporary.
!<
!< Every item takes an optional `spec`, built by `ip_spec` from ImPlot's defaults (automatic colours, no markers):
!<
!<```fortran
!< call ip_line('residual', it, res, spec=ip_spec(line_color=[1.0_real64, 0.0_real64, 0.0_real64, 1.0_real64], &
!<                                               line_weight=2.0_real64, marker=ImPlotMarker_Circle))
!<```
use, intrinsic :: iso_c_binding, only : c_bool, c_char, c_double, c_f_pointer, c_float, c_int, c_intptr_t, c_loc, c_null_char, &
                                         c_null_ptr, c_ptr
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use, intrinsic :: ieee_arithmetic, only : ieee_is_finite, ieee_is_nan
use figure_base, only : cstr, figure_check, figure_draw_refused, figure_fail, figure_refused, figure_scope_open, &
                        figure_scope_refused, figure_usage_error, format_refused, FORMAT_REAL, SCOPE_PLOT, SCOPE_SUBPLOTS
use figure_c_native, only : FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_OK, fig_colormap, fig_colormap_count, &
                            fig_colormap_name, fig_load_colormap, fig_texture_sampling, fig_plot_annotation, &
                            fig_colormap_legend, fig_plot_end, fig_plot_state, fig_plot_axis_constraints, fig_plot_tag, &
                            fig_field_image
use figure_cimgui, only : im_vec2, im_vec4, igGetFrameCount, igIsMousePosValid
use figure_texture, only : texture_object, texture_ref
use figure_cimplot, only : figure_ImPlotSpec_default, im_plot_spec, ImPlot_BeginPlot,             &
                           ImPlot_PlotBars_doublePtrdoublePtr, ImPlot_PlotBars_FloatPtrFloatPtr,                   &
                           ImPlot_PlotLine_doublePtrdoublePtr, ImPlot_PlotLine_FloatPtrFloatPtr,                   &
                           ImPlot_PlotLine_doublePtrInt, ImPlot_PlotLine_FloatPtrInt,                               &
                           ImPlot_PlotScatter_doublePtrdoublePtr, ImPlot_PlotScatter_FloatPtrFloatPtr,             &
                           ImPlot_PlotShaded_doublePtrdoublePtrdoublePtr, ImPlot_PlotShaded_doublePtrdoublePtrInt, &
                           ImPlot_PlotShaded_FloatPtrFloatPtrFloatPtr, ImPlot_PlotShaded_FloatPtrFloatPtrInt,      &
                           ImPlot_SetupAxes, ImPlot_ColormapScale, ImPlot_PlotHeatmap_doublePtr,                   &
                           ImPlot_PlotHeatmap_FloatPtr, ImPlot_PlotImage, ImPlot_PopColormap,                       &
                           ImPlot_PushColormap_PlotColormap, im_plot_point, im_plot_rect, ImPlot_GetPlotLimits,     &
                           ImPlot_GetPlotSize, ImPlot_SetupAxesLimits, ImPlot_SetupAxisScale_PlotScale,             &
                           ImPlot_SetupAxisFormat_Str, ImPlot_BeginSubplots, ImPlot_EndSubplots,                    &
                           ImPlot_SetNextAxisToFit, ImPlot_GetColormapCount, ImPlot_SetupAxis, ImPlot_SetAxes,     &
                           ImPlot_SetupAxisLimits, ImPlot_SetupAxisTicks_doublePtr, ImPlot_SetupLegend
use figure_cimplot, only : im_plot_range, ImPlot_IsPlotHovered, ImPlot_GetPlotMousePos, ImPlot_PlotToPixels_double,    &
                           ImPlot_PixelsToPlot_Float, ImPlot_IsPlotSelected, ImPlot_GetPlotSelection,                  &
                           ImPlot_CancelPlotSelection, ImPlot_DragRect, ImPlot_PlotText, ImPlot_PlotInfLines_doublePtr, &
                           ImPlot_PlotInfLines_FloatPtr, ImPlot_PlotStairs_doublePtrdoublePtr,                          &
                           ImPlot_PlotStairs_FloatPtrFloatPtr, ImPlot_PlotStems_doublePtrdoublePtr,                     &
                           ImPlot_PlotStems_FloatPtrFloatPtr, ImPlot_PlotHistogram_doublePtr,                           &
                           ImPlot_PlotHistogram_FloatPtr, ImPlot_PlotHistogram2D_doublePtr,                             &
                           ImPlot_PlotHistogram2D_FloatPtr
use figure_cimplot, only : ImPlot_DragLineX, ImPlot_DragLineY, ImPlot_DragPoint, ImPlot_GetLastItemColor,           &
                           ImPlot_SampleColormap,                                                                       &
                           ImPlot_PlotErrorBars_doublePtrdoublePtrdoublePtrdoublePtr,                                   &
                           ImPlot_PlotErrorBars_doublePtrdoublePtrdoublePtrInt,                                         &
                           ImPlot_PlotErrorBars_FloatPtrFloatPtrFloatPtrFloatPtr,                                       &
                           ImPlot_PlotErrorBars_FloatPtrFloatPtrFloatPtrInt
use figure_cimplot_enums, only : ImAxis_X1, ImAxis_X2, ImAxis_X3, ImAxis_Y1, ImAxis_Y2, ImAxis_Y3, ImAxis_COUNT,      &
                                 ImPlotScale_Linear, ImPlotScale_Time, ImPlotScale_Log10, ImPlotScale_SymLog,         &
                                 ImPlotAxisFlags_Opposite, ImPlotAxisFlags_Invert, ImPlotAxisFlags_Lock,              &
                                 ImPlotAxisFlags_NoGridLines, ImPlotLegendFlags_None, ImPlotLegendFlags_Outside,      &
                                 ImPlotLegendFlags_Horizontal, ImPlotLocation_Center, ImPlotLocation_North,           &
                                 ImPlotLocation_South, ImPlotLocation_West, ImPlotLocation_East,                      &
                                 ImPlotLocation_NorthWest, ImPlotLocation_NorthEast, ImPlotLocation_SouthWest,        &
                                 ImPlotLocation_SouthEast, ImPlotSubplotFlags_LinkAllX,                               &
                                 ImPlotSubplotFlags_LinkAllY, ImPlotSubplotFlags_None,                                &
                                 ImPlotAxisFlags_AutoFit, ImPlotAxisFlags_None, ImPlotCond_Always, ImPlotCond_Once,     &
                                 ImPlotFlags_Equal, ImPlotFlags_None,                                              &
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
use figure_cimplot_enums, only : ImPlotInfLinesFlags_Horizontal, ImPlotTextFlags_Vertical, ImPlotStairsFlags_PreStep,   &
                                 ImPlotStairsFlags_Shaded, ImPlotStemsFlags_Horizontal, ImPlotHistogramFlags_Horizontal, &
                                 ImPlotHistogramFlags_Cumulative, ImPlotHistogramFlags_Density,                        &
                                 ImPlotHistogramFlags_NoOutliers, ImPlotBin_Sqrt, ImPlotBin_Sturges, ImPlotBin_Rice,    &
                                 ImPlotBin_Scott

implicit none
private
public :: ip_begin_plot, ip_end_plot, ip_setup_axes, ip_begin_subplots, ip_end_subplots

character(len=128), allocatable :: subplots_seen(:)  !< Titles of the subplot figures drawn so far.
integer(int32)                  :: fits_pending = 0  !< Plots of a new subplot figure still to fit to their data.
integer(int64), public          :: plot_copies = 0   !< Arrays the items copied because ImPlot could not read them in
                                                     !< place (strides, integer abscissae): `test_plot_copies`.
integer(int64), public          :: plot_stride = 0   !< Byte stride given to ImPlot for the last item: `test_plot_stride`.
public :: ip_bars, ip_line, ip_scatter, ip_shaded
public :: ip_colormap_scale, ip_heatmap, ip_image, ip_plot_limits, ip_plot_size, ip_setup_axes_limits
public :: ip_colormap, ip_colormap_names, ip_load_colormap
public :: ip_error_bars, ip_annotation, ip_drag_line_x, ip_drag_line_y, ip_drag_point
public :: ip_contour, ip_contour_lines, ip_contour_levels
public :: ip_colormap_legend, ip_colormap_legend_edit, ip_field_image
public :: ip_spec, plot_spec_object
public :: ip_setup_axis, ip_set_axes, ip_setup_axis_limits, ip_setup_axis_ticks, ip_setup_axis_constraints
public :: ip_setup_legend
public :: ip_plot_hovered, ip_plot_mouse, ip_plot_to_pixels, ip_pixels_to_plot, ip_plot_selection, ip_cancel_selection
public :: ip_drag_rect, ip_tag, ip_inf_lines, ip_text, ip_stairs, ip_stems, ip_histogram, ip_histogram2d
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
   !< The C struct is private so that a spec always starts from ImPlot's defaults: a zeroed one would draw nothing
   !< (line weight 0, marker size 0).
   type(im_plot_spec), private :: c !< `ImPlotSpec`, as passed to ImPlot.
endtype plot_spec_object

interface ip_line
   !< Line through the points (x(i), y(i)); or through y(i) at uniformly spaced x, from a vector or from a row of a
   !< matrix. Arrays of any stride are read in place (plots.md, "Data in place"); x may be `int32` or `int64`.
   module procedure ip_line_r32, ip_line_r64, ip_line_values_r32, ip_line_values_r64, ip_line_row_r32, ip_line_row_r64
   module procedure ip_line_i32_r32, ip_line_i64_r32, ip_line_i32_r64, ip_line_i64_r64
endinterface ip_line

interface ip_scatter
   !< Markers at the points (x(i), y(i)).
   module procedure ip_scatter_r32, ip_scatter_r64
   module procedure ip_scatter_i32_r32, ip_scatter_i64_r32, ip_scatter_i32_r64, ip_scatter_i64_r64
endinterface ip_scatter

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

interface ip_error_bars
   !< Vertical error bars at the points (x(i), y(i)): from y(i) - err(i) to y(i) + err(i), or to y(i) + err_high(i).
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

type :: buffer_r32
   !< A scratch array of the items (single precision): the temporary of an array ImPlot cannot read in place.
   real(real32), allocatable :: v(:) !< Values, at the item's stride.
endtype buffer_r32

type :: buffer_r64
   !< A scratch array of the items (double precision): the temporary of an array ImPlot cannot read in place.
   real(real64), allocatable :: v(:) !< Values, at the item's stride.
endtype buffer_r64

type :: series_r32
   !< Where ImPlot reads the arrays of one item (single precision): one address per array and the byte stride they
   !< share (ImPlot applies one stride to all the arrays of an item); an array copied is read from its slot's scratch.
   type(c_ptr)    :: p(4) = c_null_ptr !< Addresses: 1 x, 2 y (sets the stride), 3-4 the other ordinates.
   integer(int64) :: stride = 4_int64  !< Stride of every array [bytes].
endtype series_r32

type :: series_r64
   !< Where ImPlot reads the arrays of one item (double precision): one address per array and the byte stride they
   !< share (ImPlot applies one stride to all the arrays of an item); an array copied is read from its slot's scratch.
   type(c_ptr)    :: p(4) = c_null_ptr !< Addresses: 1 x, 2 y (sets the stride), 3-4 the other ordinates.
   integer(int64) :: stride = 8_int64  !< Stride of every array [bytes].
endtype series_r64

! The items' scratch, one array per slot and precision, kept from item to item (an item's arrays are read by ImPlot
! during the call, and items are drawn by the main thread only): `scratch_reserve_*`, `scratch_age`.
type(buffer_r32), target :: scratch_r32(4)          !< Single precision.
type(buffer_r64), target :: scratch_r64(4)          !< Double precision.
integer(int32)           :: scratch_frame = -1_int32 !< Dear ImGui frame of the last copy into the scratch; -1: none kept.

interface series_lead
   !< Place the array that sets an item's stride.
   module procedure lead_r32, lead_r64
endinterface series_lead

interface series_put
   !< Place another array of an item, at its stride.
   module procedure put_r32, put_r64, put_i32_r32, put_i64_r32, put_i32_r64, put_i64_r64
endinterface series_put

interface series_spec
   !< The C spec of an item with its stride.
   module procedure spec_stride_r32, spec_stride_r64
endinterface series_spec

interface scratch_copy
   !< Copy an item's array into its slot's scratch at the item's stride (integer abscissae converted).
   module procedure copy_r32, copy_r64, copy_i32_r32, copy_i64_r32, copy_i32_r64, copy_i64_r64
endinterface scratch_copy

contains
   ! plots

   recursive function ip_begin_plot(title, width, height, equal) result(visible)
   !< Begin a plot; if true, declare its content and call `ip_end_plot`.
   character(len=*), intent(in)           :: title   !< Title (also the plot id; '##id' hides it).
   real(real64),     intent(in), optional :: width   !< Width [pixels] (default: full width).
   real(real64),     intent(in), optional :: height  !< Height [pixels] (default: ImPlot's).
   logical,          intent(in), optional :: equal   !< Same scale on both axes (one unit = as many pixels on x and y).
   logical                                :: visible !< Plot visible.
   type(im_vec2)                          :: extent  !< Size (named so: a local `size` crashes nvfortran 26.9).
   integer(c_int)                         :: flags   !< ImPlotFlags.
   integer(c_int)                         :: i       !< Axis (ImAxis).

   visible = .false.
   if (figure_draw_refused('ip_begin_plot')) return ! a task does not draw
   extent = im_vec2(-1.0_c_float, 0.0_c_float)
   if (present(width)) extent%x = real(width, c_float)
   if (present(height)) extent%y = real(height, c_float)
   flags = ImPlotFlags_None
   if (present(equal)) then
      if (equal) flags = ior(flags, ImPlotFlags_Equal)
   endif
   if (fits_pending > 0_int32) then                 ! a cell of a subplot figure drawn for the first time: every axis
      do i = 0_c_int, ImAxis_COUNT - 1_c_int       ! asked to fit; only the axes in use fit, because fitting an axis
         call ImPlot_SetNextAxisToFit(i)           ! with no data (unused, or set up and empty) computes inf - inf,
      enddo                                        ! an FPE under traps: fig_plot_end cancels those (ip_end_plot)
      fits_pending = fits_pending - 1_int32
   endif
   visible = logical(ImPlot_BeginPlot(cstr(title), extent, flags))
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
   real(real64),     intent(in), optional :: height  !< Height [pixels] (default: ImPlot's for one plot per row).
   logical,          intent(in), optional :: link_x  !< Share the x range.
   logical,          intent(in), optional :: link_y  !< Share the y range.
   logical                                :: visible !< The figure is drawn.
   type(im_vec2)                          :: extent  !< Size.
   integer(c_int)                         :: flags   !< ImPlotSubplotFlags.

   visible = .false.
   if (figure_draw_refused('ip_begin_subplots')) return ! a task does not draw
   extent = im_vec2(-1.0_c_float, 300.0_c_float * real(rows, c_float))
   if (present(width)) extent%x = real(width, c_float)
   if (present(height)) extent%y = real(height, c_float)
   flags = ImPlotSubplotFlags_None
   if (present(link_x)) then
      if (link_x) flags = ior(flags, ImPlotSubplotFlags_LinkAllX)
   endif
   if (present(link_y)) then
      if (link_y) flags = ior(flags, ImPlotSubplotFlags_LinkAllY)
   endif
   visible = logical(ImPlot_BeginSubplots(cstr(title), int(rows, c_int), int(cols, c_int), extent, flags, c_null_ptr, &
                                          c_null_ptr))
   call figure_scope_open(SCOPE_SUBPLOTS, 'ip_begin_subplots', title, visible)
   ! ImPlot gives linked axes no initial fit: the first time this figure is drawn, its plots fit to their data (linked
   ! axes then share the range of the last plot fitted)
   if (visible) then
      if (.not. allocated(subplots_seen)) allocate(subplots_seen(0))
      if (.not. any(subplots_seen == title)) then
         subplots_seen = [character(len=128) :: subplots_seen, title]
         fits_pending = rows * cols
      endif
   endif
   endfunction ip_begin_subplots

   recursive subroutine ip_end_subplots()
   !< End the grid of plots (only after `ip_begin_subplots` returned true).
   if (figure_scope_refused(SCOPE_SUBPLOTS, 'ip_end_subplots')) return ! a task, no frame, or not the innermost scope
   call ImPlot_EndSubplots()
   endsubroutine ip_end_subplots

   recursive subroutine ip_end_plot()
   !< End the plot (only after `ip_begin_plot` returned true).
   if (figure_scope_refused(SCOPE_PLOT, 'ip_end_plot')) return ! a task, no frame, or not the innermost scope
   call fig_plot_end() ! ImPlot's EndPlot, without fitting an axis that has no data (an FPE under traps)
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
   integer(c_int)                          :: flags    !< ImPlotAxisFlags of both axes.
   integer(c_int)                          :: sx       !< ImPlotScale of x (-1: unknown).
   integer(c_int)                          :: sy       !< ImPlotScale of y (-1: unknown).

   if (figure_draw_refused('ip_setup_axes', stat)) return ! a task does not draw
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
   flags = ImPlotAxisFlags_None
   if (present(auto_fit)) then
      if (auto_fit) flags = ImPlotAxisFlags_AutoFit
   endif
   call ImPlot_SetupAxes(cstr(xlabel), cstr(ylabel), flags, flags)
   if (sx /= ImPlotScale_Linear) call ImPlot_SetupAxisScale_PlotScale(ImAxis_X1, sx)
   if (sy /= ImPlotScale_Linear) call ImPlot_SetupAxisScale_PlotScale(ImAxis_Y1, sy)
   if (present(xformat)) call ImPlot_SetupAxisFormat_Str(ImAxis_X1, cstr(xformat))
   if (present(yformat)) call ImPlot_SetupAxisFormat_Str(ImAxis_Y1, cstr(yformat))
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
   integer(c_int)                        :: cond   !< ImPlotCond.

   if (figure_draw_refused('ip_setup_axes_limits', stat)) return ! a task does not draw
   if (setup_refused('ip_setup_axes_limits', stat)) return
   cond = ImPlotCond_Once
   if (present(always)) then
      if (always) cond = ImPlotCond_Always
   endif
   call ImPlot_SetupAxesLimits(real(xmin, c_double), real(xmax, c_double), real(ymin, c_double), real(ymax, c_double), &
                               cond)
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
   character(kind=c_char, len=:), allocatable, target :: clabel !< Label, NUL-terminated.
   type(c_ptr)                             :: plabel   !< Its address (null: no label).
   integer(c_int)                          :: code     !< ImAxis.
   integer(c_int)                          :: sc       !< ImPlotScale.
   integer(c_int)                          :: flags    !< ImPlotAxisFlags.
   logical                                 :: aux      !< A secondary axis.

   if (figure_draw_refused('ip_setup_axis', stat)) return ! a task does not draw
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
   aux = code /= ImAxis_X1 .and. code /= ImAxis_Y1
   flags = ImPlotAxisFlags_None
   if (aux) flags = ior(ImPlotAxisFlags_Opposite, ImPlotAxisFlags_NoGridLines)
   call set_flag(flags, ImPlotAxisFlags_Opposite, opposite)
   call set_flag(flags, ImPlotAxisFlags_NoGridLines, no_grid)
   call set_flag(flags, ImPlotAxisFlags_AutoFit, auto_fit)
   call set_flag(flags, ImPlotAxisFlags_Invert, invert)
   call set_flag(flags, ImPlotAxisFlags_Lock, lock)
   plabel = c_null_ptr
   if (present(label)) then
      clabel = cstr(label)
      plabel = c_loc(clabel)
   endif
   call ImPlot_SetupAxis(code, plabel, flags)
   if (sc /= ImPlotScale_Linear) call ImPlot_SetupAxisScale_PlotScale(code, sc)
   if (present(format)) call ImPlot_SetupAxisFormat_Str(code, cstr(format))
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

   if (figure_draw_refused('ip_set_axes', stat)) return ! a task does not draw
   if (.not. pair_ok('ip_set_axes', 'x', x, 'y', y, cx, cy, stat)) return
   if (axis_refused('ip_set_axes', x, cx, .false., stat)) return
   if (axis_refused('ip_set_axes', y, cy, .false., stat)) return
   call ImPlot_SetAxes(cx, cy)
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
   integer(c_int)                          :: cond   !< ImPlotCond.

   if (figure_draw_refused('ip_setup_axis_limits', stat)) return ! a task does not draw
   if (.not. range_ok('ip_setup_axis_limits', 'vmin', vmin, 'vmax', vmax, stat)) return
   if (axis_refused('ip_setup_axis_limits', axis, code, .true., stat)) return
   cond = ImPlotCond_Once
   if (present(always)) then
      if (always) cond = ImPlotCond_Always
   endif
   call ImPlot_SetupAxisLimits(code, real(vmin, c_double), real(vmax, c_double), cond)
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
   real(c_double),         allocatable, target :: v(:)   !< The values, contiguous.
   character(kind=c_char), allocatable, target :: ch(:)  !< The labels, each NUL-terminated, one after the other.
   type(c_ptr),            allocatable, target :: pl(:)  !< Their addresses.
   type(c_ptr)                             :: pv        !< Address of the values.
   type(c_ptr)                             :: pls       !< Address of the label addresses (null: none).
   integer(c_int)                          :: code      !< ImAxis.
   integer(int64)                          :: n         !< Values.
   integer(int64)                          :: k         !< Counter.
   integer(int64)                          :: at        !< Position in `ch`.
   integer(int64)                          :: j         !< Character counter.
   integer(int64)                          :: l         !< Length of a label.

   if (figure_draw_refused('ip_setup_axis_ticks', stat)) return ! a task does not draw
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
   v = real(values, c_double)
   pv = c_null_ptr
   if (n > 0_int64) pv = c_loc(v)
   pls = c_null_ptr
   if (present(labels)) then
      allocate(ch(n * (int(len(labels), int64) + 1_int64) + 1_int64))
      allocate(pl(max(n, 1_int64)))
      at = 1_int64
      do k = 1_int64, n
         l = int(len_trim(labels(k)), int64)
         pl(k) = c_loc(ch(at))
         do j = 1_int64, l
            ch(at + j - 1_int64) = labels(k)(j:j)
         enddo
         ch(at + l) = c_null_char
         at = at + l + 1_int64
      enddo
      if (n > 0_int64) pls = c_loc(pl)
   endif
   call ImPlot_SetupAxisTicks_doublePtr(code, pv, int(n, c_int), pls, .false._c_bool)
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
   integer(c_int)                          :: on(6)    !< Axes set up.
   integer(c_int)                          :: sc(6)    !< Their scales.
   integer(c_int)                          :: state    !< Plot state.

   if (figure_draw_refused('ip_setup_axis_constraints', stat)) return ! a task does not draw
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
   state = fig_plot_state(on, sc)
   if (sc(code + 1) == ImPlotScale_Log10 .and. iand(given, 1_c_int) /= 0_c_int .and. v(1) <= 0.0_c_double) then
      call figure_fail(FIG_ERR_ARGUMENT, "ip_setup_axis_constraints: vmin must be above 0 on the log axis '"// &
                       axis//"'", stat)
      return
   endif
   call fig_plot_axis_constraints(code, given, v)
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
   integer(c_int)                          :: loc        !< ImPlotLocation.
   integer(c_int)                          :: flags      !< ImPlotLegendFlags.

   if (figure_draw_refused('ip_setup_legend', stat)) return ! a task does not draw
   loc = ImPlotLocation_NorthWest
   if (present(location)) then
      select case (trim(location))
      case ('n')
         loc = ImPlotLocation_North
      case ('ne')
         loc = ImPlotLocation_NorthEast
      case ('e')
         loc = ImPlotLocation_East
      case ('se')
         loc = ImPlotLocation_SouthEast
      case ('s')
         loc = ImPlotLocation_South
      case ('sw')
         loc = ImPlotLocation_SouthWest
      case ('w')
         loc = ImPlotLocation_West
      case ('nw')
         loc = ImPlotLocation_NorthWest
      case ('c')
         loc = ImPlotLocation_Center
      case default
         call figure_fail(FIG_ERR_ARGUMENT, "ip_setup_legend: unknown location '"//location//"' ('n', 'ne', 'e', "// &
                          "'se', 's', 'sw', 'w', 'nw' or 'c')", stat)
         return
      endselect
   endif
   if (setup_refused('ip_setup_legend', stat)) return
   flags = ImPlotLegendFlags_None
   call set_flag(flags, ImPlotLegendFlags_Outside, outside)
   call set_flag(flags, ImPlotLegendFlags_Horizontal, horizontal)
   call ImPlot_SetupLegend(loc, flags)
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
   type(im_plot_rect)                      :: limits !< Limits.
   integer(c_int)                          :: cx     !< ImAxis of x (-1: the current one).
   integer(c_int)                          :: cy     !< ImAxis of y (-1: the current one).

   xmin = 0.0_real64
   xmax = 0.0_real64
   ymin = 0.0_real64
   ymax = 0.0_real64
   if (figure_draw_refused('ip_plot_limits', stat)) return ! a task does not draw
   if (axes_refused('ip_plot_limits', xaxis, yaxis, cx, cy, stat)) return
   call ImPlot_GetPlotLimits(cx, cy, limits)
   xmin = real(limits%X%Min, real64)
   xmax = real(limits%X%Max, real64)
   ymin = real(limits%Y%Min, real64)
   ymax = real(limits%Y%Max, real64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_plot_limits

   recursive subroutine ip_plot_size(width, height)
   !< Size of the current plot's data area [pixels] (between `ip_begin_plot` and `ip_end_plot`).
   real(real64), intent(out) :: width  !< Width [pixels].
   real(real64), intent(out) :: height !< Height [pixels].
   type(im_vec2)             :: extent !< Size.

   width = 0.0_real64
   height = 0.0_real64
   if (figure_draw_refused('ip_plot_size')) return ! a task does not draw
   extent = ImPlot_GetPlotSize()
   width = real(extent%x, real64)
   height = real(extent%y, real64)
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

   call figure_ImPlotSpec_default(spec%c)
   if (.not. (rgba_ok(line_color) .and. rgba_ok(fill_color) .and. rgba_ok(marker_line_color) .and. &
              rgba_ok(marker_fill_color))) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_spec: a colour needs 4 components (RGBA)', stat)
      return
   endif
   if (present(line_color)) spec%c%LineColor = rgba(line_color)
   if (present(line_weight)) spec%c%LineWeight = real(line_weight, c_float)
   if (present(fill_color)) spec%c%FillColor = rgba(fill_color)
   if (present(fill_alpha)) spec%c%FillAlpha = real(fill_alpha, c_float)
   if (present(marker)) spec%c%Marker = int(marker, c_int)
   if (present(marker_size)) spec%c%MarkerSize = real(marker_size, c_float)
   if (present(marker_line_color)) spec%c%MarkerLineColor = rgba(marker_line_color)
   if (present(marker_fill_color)) spec%c%MarkerFillColor = rgba(marker_fill_color)
   if (present(size)) spec%c%Size = real(size, c_float)
   if (present(flags)) spec%c%Flags = int(flags, c_int)
   call figure_check(FIG_OK, stat)
   endfunction ip_spec

   ! items, single precision

   recursive subroutine ip_line_r32(label, x, y, spec, stat)
   !< Line through the points (x(i), y(i)), single precision; read in place with any stride (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   real(real32),           intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),           intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   type(series_r32), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_line', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_line', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotLine_FloatPtrFloatPtr(cstr(label), d%p(1), d%p(2), int(size(x), c_int), series_spec(d, spec))
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
   type(series_r32), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_line', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_line', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotLine_FloatPtrFloatPtr(cstr(label), d%p(1), d%p(2), int(size(x), c_int), series_spec(d, spec))
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
   type(series_r32), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_line', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_line', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotLine_FloatPtrFloatPtr(cstr(label), d%p(1), d%p(2), int(size(x), c_int), series_spec(d, spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_line_i64_r32

   recursive subroutine ip_scatter_r32(label, x, y, spec, stat)
   !< Markers at the points (x(i), y(i)), single precision; read in place with any stride (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   real(real32),           intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),           intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   type(series_r32), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_scatter', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_scatter', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotScatter_FloatPtrFloatPtr(cstr(label), d%p(1), d%p(2), int(size(x), c_int), series_spec(d, spec))
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
   type(series_r32), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_scatter', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_scatter', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotScatter_FloatPtrFloatPtr(cstr(label), d%p(1), d%p(2), int(size(x), c_int), series_spec(d, spec))
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
   type(series_r32), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_scatter', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_scatter', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotScatter_FloatPtrFloatPtr(cstr(label), d%p(1), d%p(2), int(size(x), c_int), series_spec(d, spec))
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
   type(series_r32), target                                 :: d        !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_bars', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_bars', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotBars_FloatPtrFloatPtr(cstr(label), d%p(1), d%p(2), int(size(x), c_int), real(bar_size, c_double), &
                                         series_spec(d, spec))
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
   type(series_r32), target                                 :: d        !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_bars', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_bars', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotBars_FloatPtrFloatPtr(cstr(label), d%p(1), d%p(2), int(size(x), c_int), real(bar_size, c_double), &
                                         series_spec(d, spec))
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
   type(series_r32), target                                 :: d        !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_bars', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_bars', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotBars_FloatPtrFloatPtr(cstr(label), d%p(1), d%p(2), int(size(x), c_int), real(bar_size, c_double), &
                                         series_spec(d, spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_bars_i64_r32

   recursive subroutine ip_shaded_r32(label, x, y1, y2, spec, stat)
   !< Area between the curves y1(x) and y2(x), single precision; read in place with any stride (plots.md, "Data in
   !< place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   real(real32),           intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),           intent(in), target, asynchronous :: y1(:) !< First curve.
   real(real32),           intent(in), target, asynchronous :: y2(:) !< Second curve.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   type(series_r32), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_shaded', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y1, kind=int64), 'ip_shaded', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y2, kind=int64), 'ip_shaded', stat)) return
   call series_lead(d, 2, y1)
   call series_put(d, 1, x)
   call series_put(d, 3, y2)
   call ImPlot_PlotShaded_FloatPtrFloatPtrFloatPtr(cstr(label), d%p(1), d%p(2), d%p(3), int(size(x), c_int), &
                                                   series_spec(d, spec))
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
   type(series_r32), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_shaded', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y1, kind=int64), 'ip_shaded', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y2, kind=int64), 'ip_shaded', stat)) return
   call series_lead(d, 2, y1)
   call series_put(d, 1, x)
   call series_put(d, 3, y2)
   call ImPlot_PlotShaded_FloatPtrFloatPtrFloatPtr(cstr(label), d%p(1), d%p(2), d%p(3), int(size(x), c_int), &
                                                   series_spec(d, spec))
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
   type(series_r32), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_shaded', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y1, kind=int64), 'ip_shaded', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y2, kind=int64), 'ip_shaded', stat)) return
   call series_lead(d, 2, y1)
   call series_put(d, 1, x)
   call series_put(d, 3, y2)
   call ImPlot_PlotShaded_FloatPtrFloatPtrFloatPtr(cstr(label), d%p(1), d%p(2), d%p(3), int(size(x), c_int), &
                                                   series_spec(d, spec))
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
   type(series_r32), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_shaded', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_shaded', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotShaded_FloatPtrFloatPtrInt(cstr(label), d%p(1), d%p(2), int(size(x), c_int), real(yref, c_double), &
                                              series_spec(d, spec))
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
   type(series_r32), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_shaded', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_shaded', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotShaded_FloatPtrFloatPtrInt(cstr(label), d%p(1), d%p(2), int(size(x), c_int), real(yref, c_double), &
                                              series_spec(d, spec))
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
   type(series_r32), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_shaded', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_shaded', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotShaded_FloatPtrFloatPtrInt(cstr(label), d%p(1), d%p(2), int(size(x), c_int), real(yref, c_double), &
                                              series_spec(d, spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_shaded_ref_i64_r32

   recursive subroutine ip_error_bars_r32(label, x, y, err, err_high, spec, stat)
   !< Vertical error bars at the points (x(i), y(i)), from y(i) - err(i) to y(i) + err(i); with `err_high`, to y(i) +
   !< err_high(i), single precision; read in place with any stride (plots.md, "Data in place").
   character(len=*),       intent(in)                                 :: label       !< Legend label.
   real(real32),           intent(in), target, asynchronous           :: x(:)        !< Abscissae.
   real(real32),           intent(in), target, asynchronous           :: y(:)        !< Ordinates.
   real(real32),           intent(in), target, asynchronous           :: err(:)      !< Error below (and above) [y units].
   real(real32),           intent(in), target, optional, asynchronous :: err_high(:) !< Error above [y units].
   type(plot_spec_object), intent(in), optional                       :: spec        !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional                      :: stat        !< Status.
   type(series_r32), target                                           :: d           !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_error_bars', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_error_bars', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(err, kind=int64), 'ip_error_bars', stat)) return
   if (present(err_high)) then
      if (.not. series_ok(size(x, kind=int64), size(err_high, kind=int64), 'ip_error_bars', stat)) return
   endif
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call series_put(d, 3, err)
   if (present(err_high)) then
      call series_put(d, 4, err_high)
      call ImPlot_PlotErrorBars_FloatPtrFloatPtrFloatPtrFloatPtr(cstr(label), d%p(1), d%p(2), d%p(3), d%p(4), &
                                                                 int(size(x), c_int), &
                                                                 series_spec(d, spec))
   else
      call ImPlot_PlotErrorBars_FloatPtrFloatPtrFloatPtrInt(cstr(label), d%p(1), d%p(2), d%p(3), &
                                                            int(size(x), c_int), series_spec(d, spec))
   endif
   call figure_check(FIG_OK, stat)
   endsubroutine ip_error_bars_r32

   recursive subroutine ip_error_bars_i32_r32(label, x, y, err, err_high, spec, stat)
   !< Vertical error bars at the points (x(i), y(i)), from y(i) - err(i) to y(i) + err(i); with `err_high`, to y(i) +
   !< err_high(i), single precision, abscissae `integer(int32)`: converted into one temporary, the ordinates read in
   !< place (plots.md, "Data in place").
   character(len=*),       intent(in)                                 :: label       !< Legend label.
   integer(int32),         intent(in), target, asynchronous           :: x(:)        !< Abscissae.
   real(real32),           intent(in), target, asynchronous           :: y(:)        !< Ordinates.
   real(real32),           intent(in), target, asynchronous           :: err(:)      !< Error below (and above) [y units].
   real(real32),           intent(in), target, optional, asynchronous :: err_high(:) !< Error above [y units].
   type(plot_spec_object), intent(in), optional                       :: spec        !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional                      :: stat        !< Status.
   type(series_r32), target                                           :: d           !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_error_bars', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_error_bars', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(err, kind=int64), 'ip_error_bars', stat)) return
   if (present(err_high)) then
      if (.not. series_ok(size(x, kind=int64), size(err_high, kind=int64), 'ip_error_bars', stat)) return
   endif
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call series_put(d, 3, err)
   if (present(err_high)) then
      call series_put(d, 4, err_high)
      call ImPlot_PlotErrorBars_FloatPtrFloatPtrFloatPtrFloatPtr(cstr(label), d%p(1), d%p(2), d%p(3), d%p(4), &
                                                                 int(size(x), c_int), &
                                                                 series_spec(d, spec))
   else
      call ImPlot_PlotErrorBars_FloatPtrFloatPtrFloatPtrInt(cstr(label), d%p(1), d%p(2), d%p(3), &
                                                            int(size(x), c_int), series_spec(d, spec))
   endif
   call figure_check(FIG_OK, stat)
   endsubroutine ip_error_bars_i32_r32

   recursive subroutine ip_error_bars_i64_r32(label, x, y, err, err_high, spec, stat)
   !< Vertical error bars at the points (x(i), y(i)), from y(i) - err(i) to y(i) + err(i); with `err_high`, to y(i) +
   !< err_high(i), single precision, abscissae `integer(int64)`: converted into one temporary, the ordinates read in
   !< place (plots.md, "Data in place").
   character(len=*),       intent(in)                                 :: label       !< Legend label.
   integer(int64),         intent(in), target, asynchronous           :: x(:)        !< Abscissae.
   real(real32),           intent(in), target, asynchronous           :: y(:)        !< Ordinates.
   real(real32),           intent(in), target, asynchronous           :: err(:)      !< Error below (and above) [y units].
   real(real32),           intent(in), target, optional, asynchronous :: err_high(:) !< Error above [y units].
   type(plot_spec_object), intent(in), optional                       :: spec        !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional                      :: stat        !< Status.
   type(series_r32), target                                           :: d           !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_error_bars', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_error_bars', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(err, kind=int64), 'ip_error_bars', stat)) return
   if (present(err_high)) then
      if (.not. series_ok(size(x, kind=int64), size(err_high, kind=int64), 'ip_error_bars', stat)) return
   endif
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call series_put(d, 3, err)
   if (present(err_high)) then
      call series_put(d, 4, err_high)
      call ImPlot_PlotErrorBars_FloatPtrFloatPtrFloatPtrFloatPtr(cstr(label), d%p(1), d%p(2), d%p(3), d%p(4), &
                                                                 int(size(x), c_int), &
                                                                 series_spec(d, spec))
   else
      call ImPlot_PlotErrorBars_FloatPtrFloatPtrFloatPtrInt(cstr(label), d%p(1), d%p(2), d%p(3), &
                                                            int(size(x), c_int), series_spec(d, spec))
   endif
   call figure_check(FIG_OK, stat)
   endsubroutine ip_error_bars_i64_r32

   recursive subroutine ip_line_r64(label, x, y, spec, stat)
   !< Line through the points (x(i), y(i)), double precision; read in place with any stride (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   real(real64),           intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),           intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   type(series_r64), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_line', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_line', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotLine_doublePtrdoublePtr(cstr(label), d%p(1), d%p(2), int(size(x), c_int), series_spec(d, spec))
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
   type(series_r64), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_line', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_line', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotLine_doublePtrdoublePtr(cstr(label), d%p(1), d%p(2), int(size(x), c_int), series_spec(d, spec))
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
   type(series_r64), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_line', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_line', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotLine_doublePtrdoublePtr(cstr(label), d%p(1), d%p(2), int(size(x), c_int), series_spec(d, spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_line_i64_r64

   recursive subroutine ip_scatter_r64(label, x, y, spec, stat)
   !< Markers at the points (x(i), y(i)), double precision; read in place with any stride (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   real(real64),           intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),           intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   type(series_r64), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_scatter', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_scatter', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotScatter_doublePtrdoublePtr(cstr(label), d%p(1), d%p(2), int(size(x), c_int), series_spec(d, spec))
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
   type(series_r64), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_scatter', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_scatter', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotScatter_doublePtrdoublePtr(cstr(label), d%p(1), d%p(2), int(size(x), c_int), series_spec(d, spec))
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
   type(series_r64), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_scatter', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_scatter', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotScatter_doublePtrdoublePtr(cstr(label), d%p(1), d%p(2), int(size(x), c_int), series_spec(d, spec))
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
   type(series_r64), target                                 :: d        !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_bars', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_bars', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotBars_doublePtrdoublePtr(cstr(label), d%p(1), d%p(2), int(size(x), c_int), real(bar_size, c_double), &
                                           series_spec(d, spec))
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
   type(series_r64), target                                 :: d        !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_bars', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_bars', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotBars_doublePtrdoublePtr(cstr(label), d%p(1), d%p(2), int(size(x), c_int), real(bar_size, c_double), &
                                           series_spec(d, spec))
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
   type(series_r64), target                                 :: d        !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_bars', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_bars', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotBars_doublePtrdoublePtr(cstr(label), d%p(1), d%p(2), int(size(x), c_int), real(bar_size, c_double), &
                                           series_spec(d, spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_bars_i64_r64

   recursive subroutine ip_shaded_r64(label, x, y1, y2, spec, stat)
   !< Area between the curves y1(x) and y2(x), double precision; read in place with any stride (plots.md, "Data in
   !< place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   real(real64),           intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),           intent(in), target, asynchronous :: y1(:) !< First curve.
   real(real64),           intent(in), target, asynchronous :: y2(:) !< Second curve.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   type(series_r64), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_shaded', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y1, kind=int64), 'ip_shaded', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y2, kind=int64), 'ip_shaded', stat)) return
   call series_lead(d, 2, y1)
   call series_put(d, 1, x)
   call series_put(d, 3, y2)
   call ImPlot_PlotShaded_doublePtrdoublePtrdoublePtr(cstr(label), d%p(1), d%p(2), d%p(3), int(size(x), c_int), &
                                                      series_spec(d, spec))
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
   type(series_r64), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_shaded', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y1, kind=int64), 'ip_shaded', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y2, kind=int64), 'ip_shaded', stat)) return
   call series_lead(d, 2, y1)
   call series_put(d, 1, x)
   call series_put(d, 3, y2)
   call ImPlot_PlotShaded_doublePtrdoublePtrdoublePtr(cstr(label), d%p(1), d%p(2), d%p(3), int(size(x), c_int), &
                                                      series_spec(d, spec))
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
   type(series_r64), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_shaded', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y1, kind=int64), 'ip_shaded', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y2, kind=int64), 'ip_shaded', stat)) return
   call series_lead(d, 2, y1)
   call series_put(d, 1, x)
   call series_put(d, 3, y2)
   call ImPlot_PlotShaded_doublePtrdoublePtrdoublePtr(cstr(label), d%p(1), d%p(2), d%p(3), int(size(x), c_int), &
                                                      series_spec(d, spec))
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
   type(series_r64), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_shaded', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_shaded', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotShaded_doublePtrdoublePtrInt(cstr(label), d%p(1), d%p(2), int(size(x), c_int), &
                                                real(yref, c_double), &
                                                series_spec(d, spec))
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
   type(series_r64), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_shaded', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_shaded', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotShaded_doublePtrdoublePtrInt(cstr(label), d%p(1), d%p(2), int(size(x), c_int), &
                                                real(yref, c_double), &
                                                series_spec(d, spec))
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
   type(series_r64), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_shaded', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_shaded', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotShaded_doublePtrdoublePtrInt(cstr(label), d%p(1), d%p(2), int(size(x), c_int), &
                                                real(yref, c_double), &
                                                series_spec(d, spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_shaded_ref_i64_r64

   recursive subroutine ip_error_bars_r64(label, x, y, err, err_high, spec, stat)
   !< Vertical error bars at the points (x(i), y(i)), from y(i) - err(i) to y(i) + err(i); with `err_high`, to y(i) +
   !< err_high(i), double precision; read in place with any stride (plots.md, "Data in place").
   character(len=*),       intent(in)                                 :: label       !< Legend label.
   real(real64),           intent(in), target, asynchronous           :: x(:)        !< Abscissae.
   real(real64),           intent(in), target, asynchronous           :: y(:)        !< Ordinates.
   real(real64),           intent(in), target, asynchronous           :: err(:)      !< Error below (and above) [y units].
   real(real64),           intent(in), target, optional, asynchronous :: err_high(:) !< Error above [y units].
   type(plot_spec_object), intent(in), optional                       :: spec        !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional                      :: stat        !< Status.
   type(series_r64), target                                           :: d           !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_error_bars', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_error_bars', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(err, kind=int64), 'ip_error_bars', stat)) return
   if (present(err_high)) then
      if (.not. series_ok(size(x, kind=int64), size(err_high, kind=int64), 'ip_error_bars', stat)) return
   endif
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call series_put(d, 3, err)
   if (present(err_high)) then
      call series_put(d, 4, err_high)
      call ImPlot_PlotErrorBars_doublePtrdoublePtrdoublePtrdoublePtr(cstr(label), d%p(1), d%p(2), d%p(3), d%p(4), &
                                                                     int(size(x), c_int), &
                                                                     series_spec(d, spec))
   else
      call ImPlot_PlotErrorBars_doublePtrdoublePtrdoublePtrInt(cstr(label), d%p(1), d%p(2), d%p(3), &
                                                               int(size(x), c_int), series_spec(d, spec))
   endif
   call figure_check(FIG_OK, stat)
   endsubroutine ip_error_bars_r64

   recursive subroutine ip_error_bars_i32_r64(label, x, y, err, err_high, spec, stat)
   !< Vertical error bars at the points (x(i), y(i)), from y(i) - err(i) to y(i) + err(i); with `err_high`, to y(i) +
   !< err_high(i), double precision, abscissae `integer(int32)`: converted into one temporary, the ordinates read in
   !< place (plots.md, "Data in place").
   character(len=*),       intent(in)                                 :: label       !< Legend label.
   integer(int32),         intent(in), target, asynchronous           :: x(:)        !< Abscissae.
   real(real64),           intent(in), target, asynchronous           :: y(:)        !< Ordinates.
   real(real64),           intent(in), target, asynchronous           :: err(:)      !< Error below (and above) [y units].
   real(real64),           intent(in), target, optional, asynchronous :: err_high(:) !< Error above [y units].
   type(plot_spec_object), intent(in), optional                       :: spec        !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional                      :: stat        !< Status.
   type(series_r64), target                                           :: d           !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_error_bars', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_error_bars', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(err, kind=int64), 'ip_error_bars', stat)) return
   if (present(err_high)) then
      if (.not. series_ok(size(x, kind=int64), size(err_high, kind=int64), 'ip_error_bars', stat)) return
   endif
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call series_put(d, 3, err)
   if (present(err_high)) then
      call series_put(d, 4, err_high)
      call ImPlot_PlotErrorBars_doublePtrdoublePtrdoublePtrdoublePtr(cstr(label), d%p(1), d%p(2), d%p(3), d%p(4), &
                                                                     int(size(x), c_int), &
                                                                     series_spec(d, spec))
   else
      call ImPlot_PlotErrorBars_doublePtrdoublePtrdoublePtrInt(cstr(label), d%p(1), d%p(2), d%p(3), &
                                                               int(size(x), c_int), series_spec(d, spec))
   endif
   call figure_check(FIG_OK, stat)
   endsubroutine ip_error_bars_i32_r64

   recursive subroutine ip_error_bars_i64_r64(label, x, y, err, err_high, spec, stat)
   !< Vertical error bars at the points (x(i), y(i)), from y(i) - err(i) to y(i) + err(i); with `err_high`, to y(i) +
   !< err_high(i), double precision, abscissae `integer(int64)`: converted into one temporary, the ordinates read in
   !< place (plots.md, "Data in place").
   character(len=*),       intent(in)                                 :: label       !< Legend label.
   integer(int64),         intent(in), target, asynchronous           :: x(:)        !< Abscissae.
   real(real64),           intent(in), target, asynchronous           :: y(:)        !< Ordinates.
   real(real64),           intent(in), target, asynchronous           :: err(:)      !< Error below (and above) [y units].
   real(real64),           intent(in), target, optional, asynchronous :: err_high(:) !< Error above [y units].
   type(plot_spec_object), intent(in), optional                       :: spec        !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional                      :: stat        !< Status.
   type(series_r64), target                                           :: d           !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_error_bars', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_error_bars', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(err, kind=int64), 'ip_error_bars', stat)) return
   if (present(err_high)) then
      if (.not. series_ok(size(x, kind=int64), size(err_high, kind=int64), 'ip_error_bars', stat)) return
   endif
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call series_put(d, 3, err)
   if (present(err_high)) then
      call series_put(d, 4, err_high)
      call ImPlot_PlotErrorBars_doublePtrdoublePtrdoublePtrdoublePtr(cstr(label), d%p(1), d%p(2), d%p(3), d%p(4), &
                                                                     int(size(x), c_int), &
                                                                     series_spec(d, spec))
   else
      call ImPlot_PlotErrorBars_doublePtrdoublePtrdoublePtrInt(cstr(label), d%p(1), d%p(2), d%p(3), &
                                                               int(size(x), c_int), series_spec(d, spec))
   endif
   call figure_check(FIG_OK, stat)
   endsubroutine ip_error_bars_i64_r64

   ! items with uniform abscissae, matrix rows, heatmaps

   recursive subroutine ip_line_values_r32(label, y, xscale, xstart, spec, stat)
   !< Line through y(i) at x = xstart + (i - 1) xscale, single precision; read in place with any stride (plots.md,
   !< "Data in place").
   character(len=*),       intent(in)                       :: label  !< Legend label.
   real(real32),           intent(in), target, asynchronous :: y(:)   !< Ordinates.
   real(real64),           intent(in), optional             :: xscale !< Spacing of the abscissae (default 1).
   real(real64),           intent(in), optional             :: xstart !< First abscissa (default 0).
   type(plot_spec_object), intent(in), optional             :: spec   !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat   !< Status.
   type(series_r32), target                                 :: d      !< Where ImPlot reads the array.

   if (figure_draw_refused('ip_line', stat)) return ! a task does not draw
   if (.not. series_ok(size(y, kind=int64), size(y, kind=int64), 'ip_line', stat)) return
   call series_lead(d, 2, y)
   call ImPlot_PlotLine_FloatPtrInt(cstr(label), d%p(2), int(size(y), c_int), uniform(xscale, 1.0_real64), &
                                    uniform(xstart, 0.0_real64), series_spec(d, spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_line_values_r32

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
   type(im_plot_spec)                                     :: c      !< Spec with the row stride.
   type(c_ptr)                                            :: p      !< Address of y(row, 1), or null.

   if (figure_draw_refused('ip_line', stat)) return ! a task does not draw
   if (.not. row_ok(size(y, 1, kind=int64), size(y, 2, kind=int64), storage_size(y, kind=int64), row, stat)) return
   c = spec_c(spec)
   c%Offset = 0_c_int
   c%Stride = int(size(y, 1, kind=int64) * storage_size(y, kind=int64) / 8_int64, c_int) ! bytes between y(row,j), y(row,j+1)
   p = c_null_ptr
   if (size(y, 2) > 0) p = c_loc(y(row, 1))
   call ImPlot_PlotLine_FloatPtrInt(cstr(label), p, int(size(y, 2), c_int), uniform(xscale, 1.0_real64), &
                                    uniform(xstart, 0.0_real64), c)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_line_row_r32

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
   real(c_double)                                         :: smin         !< Colormap bottom (0, 0: data range).
   real(c_double)                                         :: smax         !< Colormap top.
   character(kind=c_char, len=:), allocatable, target     :: fmt          !< NUL-terminated label format.
   type(c_ptr)                                            :: pfmt         !< Label format, or null: no labels.
   type(c_ptr)                                            :: p            !< Field address, or null when empty.
   integer(c_int)                                         :: cmap         !< The colormap's id.

   if (figure_draw_refused('ip_heatmap', stat)) return ! a task does not draw
   if (.not. field_ok(size(f, 1, kind=int64), size(f, 2, kind=int64), present(scale_min), present(scale_max), stat)) return
   if (.not. colormap_ok('ip_heatmap', colormap, cmap, stat)) return
   if (present(label_format)) then
      if (format_refused('ip_heatmap', 'label_format', label_format, FORMAT_REAL, stat)) return
   endif
   smin = 0.0_c_double
   smax = 0.0_c_double
   if (present(scale_min)) smin = real(scale_min, c_double)
   if (present(scale_max)) smax = real(scale_max, c_double)
   pfmt = c_null_ptr
   if (present(label_format)) then
      fmt = cstr(label_format)
      pfmt = c_loc(fmt)
   endif
   p = c_null_ptr
   if (size(f) > 0) p = c_loc(f)
   call ImPlot_PushColormap_PlotColormap(cmap)
   ! rows = size(f, 2) along y, cols = size(f, 1) along x: ImPlot's row-major cell (r, c) is f(c + 1, r + 1). ImPlot
   ! draws row 0 at bounds_max%y: the y bounds are swapped so that it lands at ymin.
   call ImPlot_PlotHeatmap_FloatPtr(cstr(label), p, int(size(f, 2), c_int), int(size(f, 1), c_int), smin, smax, pfmt, &
                                    im_plot_point(xmin, ymax), im_plot_point(xmax, ymin), spec_c(spec))
   call ImPlot_PopColormap(1_c_int)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_heatmap_r32

   recursive subroutine ip_line_values_r64(label, y, xscale, xstart, spec, stat)
   !< Line through y(i) at x = xstart + (i - 1) xscale, double precision; read in place with any stride (plots.md,
   !< "Data in place").
   character(len=*),       intent(in)                       :: label  !< Legend label.
   real(real64),           intent(in), target, asynchronous :: y(:)   !< Ordinates.
   real(real64),           intent(in), optional             :: xscale !< Spacing of the abscissae (default 1).
   real(real64),           intent(in), optional             :: xstart !< First abscissa (default 0).
   type(plot_spec_object), intent(in), optional             :: spec   !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat   !< Status.
   type(series_r64), target                                 :: d      !< Where ImPlot reads the array.

   if (figure_draw_refused('ip_line', stat)) return ! a task does not draw
   if (.not. series_ok(size(y, kind=int64), size(y, kind=int64), 'ip_line', stat)) return
   call series_lead(d, 2, y)
   call ImPlot_PlotLine_doublePtrInt(cstr(label), d%p(2), int(size(y), c_int), uniform(xscale, 1.0_real64), &
                                     uniform(xstart, 0.0_real64), series_spec(d, spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_line_values_r64

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
   type(im_plot_spec)                                     :: c      !< Spec with the row stride.
   type(c_ptr)                                            :: p      !< Address of y(row, 1), or null.

   if (figure_draw_refused('ip_line', stat)) return ! a task does not draw
   if (.not. row_ok(size(y, 1, kind=int64), size(y, 2, kind=int64), storage_size(y, kind=int64), row, stat)) return
   c = spec_c(spec)
   c%Offset = 0_c_int
   c%Stride = int(size(y, 1, kind=int64) * storage_size(y, kind=int64) / 8_int64, c_int) ! bytes between y(row,j), y(row,j+1)
   p = c_null_ptr
   if (size(y, 2) > 0) p = c_loc(y(row, 1))
   call ImPlot_PlotLine_doublePtrInt(cstr(label), p, int(size(y, 2), c_int), uniform(xscale, 1.0_real64), &
                                     uniform(xstart, 0.0_real64), c)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_line_row_r64

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
   real(c_double)                                         :: smin         !< Colormap bottom (0, 0: data range).
   real(c_double)                                         :: smax         !< Colormap top.
   character(kind=c_char, len=:), allocatable, target     :: fmt          !< NUL-terminated label format.
   type(c_ptr)                                            :: pfmt         !< Label format, or null: no labels.
   type(c_ptr)                                            :: p            !< Field address, or null when empty.
   integer(c_int)                                         :: cmap         !< The colormap's id.

   if (figure_draw_refused('ip_heatmap', stat)) return ! a task does not draw
   if (.not. field_ok(size(f, 1, kind=int64), size(f, 2, kind=int64), present(scale_min), present(scale_max), stat)) return
   if (.not. colormap_ok('ip_heatmap', colormap, cmap, stat)) return
   if (present(label_format)) then
      if (format_refused('ip_heatmap', 'label_format', label_format, FORMAT_REAL, stat)) return
   endif
   smin = 0.0_c_double
   smax = 0.0_c_double
   if (present(scale_min)) smin = real(scale_min, c_double)
   if (present(scale_max)) smax = real(scale_max, c_double)
   pfmt = c_null_ptr
   if (present(label_format)) then
      fmt = cstr(label_format)
      pfmt = c_loc(fmt)
   endif
   p = c_null_ptr
   if (size(f) > 0) p = c_loc(f)
   call ImPlot_PushColormap_PlotColormap(cmap)
   ! rows = size(f, 2) along y, cols = size(f, 1) along x: ImPlot's row-major cell (r, c) is f(c + 1, r + 1). ImPlot
   ! draws row 0 at bounds_max%y: the y bounds are swapped so that it lands at ymin.
   call ImPlot_PlotHeatmap_doublePtr(cstr(label), p, int(size(f, 2), c_int), int(size(f, 1), c_int), smin, smax, pfmt, &
                                     im_plot_point(xmin, ymax), im_plot_point(xmax, ymin), spec_c(spec))
   call ImPlot_PopColormap(1_c_int)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_heatmap_r64

   ! images and colour scales

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

   if (figure_draw_refused('ip_image', stat)) return ! a task does not draw
   if (.not. tex%is_initialized()) then
      call figure_fail(FIG_ERR_STATE, 'ip_image: the texture is not initialized', stat)
      return
   endif
   ! ImPlot maps uv0 to (xmin, ymax) and uv1 to (xmax, ymin): v = 1 at the top puts the first uploaded row at ymin
   call fig_texture_sampling(1_c_int, 1_c_int) ! the texture's own filter (nearest unless created smooth)
   call ImPlot_PlotImage(cstr(label), texture_ref(tex), im_plot_point(xmin, ymin), im_plot_point(xmax, ymax), &
                         im_vec2(0.0_c_float, 1.0_c_float), im_vec2(1.0_c_float, 0.0_c_float),                    &
                         im_vec4(1.0_c_float, 1.0_c_float, 1.0_c_float, 1.0_c_float), spec_c(spec))
   call fig_texture_sampling(1_c_int, 0_c_int)
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
   type(im_vec2)                           :: extent       !< Size (0: ImPlot's default).
   integer(c_int)                          :: cmap         !< The colormap's id.

   if (figure_draw_refused('ip_colormap_scale', stat)) return ! a task does not draw
   if (.not. colormap_ok('ip_colormap_scale', colormap, cmap, stat)) return
   if (present(label_format)) then
      if (format_refused('ip_colormap_scale', 'label_format', label_format, FORMAT_REAL, stat)) return
   endif
   extent = im_vec2(0.0_c_float, 0.0_c_float)
   if (present(width)) extent%x = real(width, c_float)
   if (present(height)) extent%y = real(height, c_float)
   if (present(label_format)) then
      call ImPlot_ColormapScale(cstr(label), real(scale_min, c_double), real(scale_max, c_double), extent, &
                                cstr(label_format), 0_c_int, cmap)
   else
      call ImPlot_ColormapScale(cstr(label), real(scale_min, c_double), real(scale_max, c_double), extent, cstr('%g'), &
                                0_c_int, cmap)
   endif
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
   integer(c_int)                          :: n            !< Bands.
   integer(c_int)                          :: h            !< Horizontal flag.
   integer(c_int)                          :: code         !< Scale: 0 linear, 1 log, 2 symlog.
   integer(c_int)                          :: moved        !< C flag of `changed`.
   real(c_double)                          :: r(2)         !< C copy of `range`.

   range = [vmin, vmax]
   changed = .false.
   if (figure_draw_refused(caller, stat)) return ! a task does not draw
   if (present(label_format)) then
      ! as documented since v0.3.0: '' is the default format, a text without conversion is printed as it is
      if (format_refused(caller, 'label_format', label_format, FORMAT_REAL, stat, text=.true.)) return
   endif
   if (.not. field_scale_ok(caller, scale, code, stat)) return
   n = 0_c_int
   if (present(levels)) then
      if (levels < 2_int32 .or. levels > 256_int32) then
         call figure_fail(FIG_ERR_ARGUMENT, caller//': levels must be in [2, 256]', stat)
         return
      endif
      n = int(levels, c_int)
   endif
   h = 0_c_int
   if (present(horizontal)) then
      if (horizontal) h = 1_c_int
   endif
   if (present(label_format)) then
      call figure_check(fig_colormap_legend(id, len(id, c_int), int(colormap, c_int), real(vmin, c_double),             &
                                            real(vmax, c_double), n, h, real(uniform(width, 0.0_real64), c_float),      &
                                            real(uniform(height, 0.0_real64), c_float), label_format,                  &
                                            len(label_format, c_int), code, merge(1_c_int, 0_c_int, interactive), r,   &
                                            moved), stat)
   else
      call figure_check(fig_colormap_legend(id, len(id, c_int), int(colormap, c_int), real(vmin, c_double),             &
                                            real(vmax, c_double), n, h, real(uniform(width, 0.0_real64), c_float),      &
                                            real(uniform(height, 0.0_real64), c_float), '', 0_c_int, code,              &
                                            merge(1_c_int, 0_c_int, interactive), r, moved), stat)
   endif
   if (moved == 1_c_int) then
      range = real(r, real64)
      changed = .true.
   endif
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
   type(c_ptr)                                      :: p            !< Field address.

   p = c_null_ptr
   if (size(f) > 0) p = c_loc(f)
   call field_image('ip_field_image', label, p, 4_c_int, size(f, 1, kind=int64), size(f, 2, kind=int64), x0, x1, y0, y1, &
                    colormap, vmin, vmax, scale, nan_color, changed, range, stat)
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
   type(c_ptr)                                      :: p            !< Field address.

   p = c_null_ptr
   if (size(f) > 0) p = c_loc(f)
   call field_image('ip_field_image', label, p, 8_c_int, size(f, 1, kind=int64), size(f, 2, kind=int64), x0, x1, y0, y1, &
                    colormap, vmin, vmax, scale, nan_color, changed, range, stat)
   endsubroutine ip_field_image_r64

   recursive subroutine field_image(caller, label, p, kind, nx, ny, x0, x1, y0, y1, colormap, vmin, vmax, scale, &
                                    nan_color, changed, range, stat)
   !< `ip_field_image` of either kind: arguments checked, then coloured and drawn natively.
   character(len=*), intent(in)            :: caller       !< The procedure, for the messages.
   character(len=*), intent(in)            :: label        !< Legend label.
   type(c_ptr),      intent(in)            :: p            !< Field address (null when empty).
   integer(c_int),   intent(in)            :: kind         !< 4 or 8.
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
   logical,          intent(in), optional  :: changed      !< Values changed.
   real(real64),     intent(out), optional :: range(2)     !< The range applied.
   integer(int32),   intent(out), optional :: stat         !< Status.
   integer(c_int)                          :: cmap         !< Colormap id.
   integer(c_int)                          :: code         !< Scale code.
   real(c_float)                           :: nanc(4)      !< NaN colour.
   real(c_double)                          :: r(2)         !< Range applied.
   integer(c_int)                          :: again        !< C flag of `changed`.

   if (present(range)) range = 0.0_real64
   if (figure_draw_refused(caller, stat)) return ! a task does not draw
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
   nanc = 0.0_c_float
   if (present(nan_color)) then
      if (size(nan_color) /= 4) then
         call figure_fail(FIG_ERR_ARGUMENT, caller//': nan_color needs 4 components (RGBA)', stat)
         return
      endif
      if (any(.not. (nan_color >= 0.0_real64 .and. nan_color <= 1.0_real64))) then
         call figure_fail(FIG_ERR_ARGUMENT, caller//': nan_color components must be in [0, 1]', stat)
         return
      endif
      nanc = real(nan_color, c_float)
   endif
   if (nx == 0_int64 .or. ny == 0_int64) then ! nothing to draw
      call figure_check(FIG_OK, stat)
      return
   endif
   again = 0_c_int
   if (present(changed)) again = merge(1_c_int, 0_c_int, changed)
   call figure_check(fig_field_image(label, len(label, c_int), p, kind, int(nx, c_int), int(ny, c_int),            &
                                     real(x0, c_double), real(x1, c_double), real(y0, c_double), real(y1, c_double), &
                                     cmap, merge(1_c_int, 0_c_int, present(vmin)), real(uniform(vmin, 0.0_real64),  &
                                     c_double), merge(1_c_int, 0_c_int, present(vmax)),                             &
                                     real(uniform(vmax, 0.0_real64), c_double), code, nanc, again, r), stat)
   if (present(range)) range = real(r, real64)
   endsubroutine field_image

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
   integer(c_int)                          :: c_id   !< The native id.
   character(len=12)                       :: text   !< A number, printed.

   id = -1_int32
   if (figure_refused('ip_colormap', stat)) return ! ImPlot's context belongs to the main thread
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
   call figure_check(fig_colormap(name, len_trim(name, c_int), n, c_id), stat)
   id = int(c_id, int32)
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

   if (figure_refused('ip_load_colormap', stat)) return ! the registry belongs to the main thread
   call figure_check(fig_load_colormap(name, len_trim(name, c_int), file, len_trim(file, c_int)), stat)
   endsubroutine ip_load_colormap

   recursive subroutine ip_colormap_names(names)
   !< The names `ip_colormap` knows: the bundled maps (alphabetical), ImPlot's own (in ImPlot's order), then the maps
   !< loaded with `ip_load_colormap` (in load order); reversed and discrete maps are not listed. From a task: none.
   character(len=:), allocatable, intent(out) :: names(:) !< Names (as long as the longest).
   integer(c_int)                             :: n        !< Names.
   integer(c_int)                             :: longest  !< The longest one [bytes].
   integer(c_int)                             :: i        !< Counter.
   integer(c_int)                             :: m        !< A name's length.
   character(len=1)                           :: probe    !< A buffer for a length alone.

   n = 0_c_int
   if (.not. figure_refused('ip_colormap_names')) n = fig_colormap_count()
   longest = 1_c_int
   do i = 1_c_int, n
      longest = max(longest, fig_colormap_name(i, probe, 0_c_int))
   enddo
   allocate(character(len=longest) :: names(n))
   do i = 1_c_int, n
      names(i) = ''
      m = fig_colormap_name(i, names(i), longest)
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
   real(c_float)                           :: c(4)      !< Box colour.
   real(c_float)                           :: d(2)      !< Offset.

   if (figure_draw_refused('ip_annotation', stat)) return ! a task does not draw
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
   c = 0.0_c_float
   if (present(color)) c = real(color, c_float)
   d = 0.0_c_float
   if (present(offset)) d = real(offset, c_float)
   call figure_check(fig_plot_annotation(real(x, c_double), real(y, c_double), c, d(1), d(2), 1_c_int, text, &
                                         len(text, c_int)), stat)
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
   if (figure_draw_refused('ip_drag_line_x', stat)) return ! a task does not draw
   moved = .false.
   if (.not. drag_ok('ip_drag_line_x', color, stat)) return
   if (plot_refused('ip_drag_line_x', .false., stat)) return
   moved = logical(ImPlot_DragLineX(int(id, c_int), c_loc(x), drag_color(color),                                &
                                    real(uniform(thickness, 1.0_real64), c_float), 0_c_int, c_null_ptr, c_null_ptr, c_null_ptr))
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
   if (figure_draw_refused('ip_drag_line_y', stat)) return ! a task does not draw
   moved = .false.
   if (.not. drag_ok('ip_drag_line_y', color, stat)) return
   if (plot_refused('ip_drag_line_y', .false., stat)) return
   moved = logical(ImPlot_DragLineY(int(id, c_int), c_loc(y), drag_color(color),                                &
                                    real(uniform(thickness, 1.0_real64), c_float), 0_c_int, c_null_ptr, c_null_ptr, c_null_ptr))
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
   if (figure_draw_refused('ip_drag_point', stat)) return ! a task does not draw
   moved = .false.
   if (.not. drag_ok('ip_drag_point', color, stat)) return
   if (plot_refused('ip_drag_point', .false., stat)) return
   moved = logical(ImPlot_DragPoint(int(id, c_int), c_loc(x), c_loc(y), drag_color(color),                         &
                                    real(uniform(radius, 4.0_real64), c_float), 0_c_int, c_null_ptr, c_null_ptr, c_null_ptr))
   call figure_check(FIG_OK, stat)
   endfunction ip_drag_point

   ! reading a plot: the pointer, conversions, the box selection

   recursive function ip_plot_hovered(stat) result(hovered)
   !< Whether the pointer is over the data area of the plot being declared (`IsPlotHovered`), on this frame. Between
   !< `ip_begin_plot` and `ip_end_plot`; it ends the setup. Statuses: `FIG_ERR_STATE` outside a plot, from a task.
   integer(int32), intent(out), optional :: stat    !< Status.
   logical                               :: hovered !< The pointer is over the plot area.

   hovered = .false.
   if (figure_draw_refused('ip_plot_hovered', stat)) return ! a task does not draw
   if (plot_refused('ip_plot_hovered', .false., stat)) return
   hovered = logical(ImPlot_IsPlotHovered())
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
   type(im_plot_point)                     :: p     !< Position.
   integer(c_int)                          :: cx    !< ImAxis of x (-1: the current one).
   integer(c_int)                          :: cy    !< ImAxis of y (-1: the current one).

   x = 0.0_real64
   y = 0.0_real64
   if (figure_draw_refused('ip_plot_mouse', stat)) return ! a task does not draw
   if (axes_refused('ip_plot_mouse', xaxis, yaxis, cx, cy, stat)) return
   if (.not. logical(igIsMousePosValid(c_null_ptr))) then ! no pointer: ImGui's -FLT_MAX would convert to a NaN or an
      x = -huge(1.0_real64)                              ! overflow on a log axis
      y = -huge(1.0_real64)
      call figure_check(FIG_OK, stat)
      return
   endif
   call ImPlot_GetPlotMousePos(cx, cy, p)
   x = real(p%x, real64)
   y = real(p%y, real64)
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
   type(im_vec2)                           :: v     !< Pixel.
   integer(c_int)                          :: cx    !< ImAxis of x (-1: the current one).
   integer(c_int)                          :: cy    !< ImAxis of y (-1: the current one).

   px = 0.0_real64
   py = 0.0_real64
   if (figure_draw_refused('ip_plot_to_pixels', stat)) return ! a task does not draw
   if (ieee_is_nan(x) .or. ieee_is_nan(y)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_plot_to_pixels: x and y must not be NaN', stat)
      return
   endif
   if (axes_refused('ip_plot_to_pixels', xaxis, yaxis, cx, cy, stat)) return
   v = ImPlot_PlotToPixels_double(real(x, c_double), real(y, c_double), cx, cy)
   px = real(v%x, real64)
   py = real(v%y, real64)
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
   type(im_plot_point)                     :: p     !< Point.
   integer(c_int)                          :: cx    !< ImAxis of x (-1: the current one).
   integer(c_int)                          :: cy    !< ImAxis of y (-1: the current one).

   x = 0.0_real64
   y = 0.0_real64
   if (figure_draw_refused('ip_pixels_to_plot', stat)) return ! a task does not draw
   if (ieee_is_nan(px) .or. ieee_is_nan(py)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_pixels_to_plot: px and py must not be NaN', stat)
      return
   endif
   if (axes_refused('ip_pixels_to_plot', xaxis, yaxis, cx, cy, stat)) return
   call ImPlot_PixelsToPlot_Float(real(px, c_float), real(py, c_float), cx, cy, p)
   x = real(p%x, real64)
   y = real(p%y, real64)
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
   type(im_plot_rect)                      :: r        !< Its extent.
   integer(c_int)                          :: cx       !< ImAxis of x (-1: the current one).
   integer(c_int)                          :: cy       !< ImAxis of y (-1: the current one).

   selected = .false.
   xmin = 0.0_real64
   xmax = 0.0_real64
   ymin = 0.0_real64
   ymax = 0.0_real64
   if (figure_draw_refused('ip_plot_selection', stat)) return ! a task does not draw
   if (axes_refused('ip_plot_selection', xaxis, yaxis, cx, cy, stat)) return
   selected = logical(ImPlot_IsPlotSelected())
   if (selected) then
      call ImPlot_GetPlotSelection(cx, cy, r)
      xmin = real(r%X%Min, real64)
      xmax = real(r%X%Max, real64)
      ymin = real(r%Y%Min, real64)
      ymax = real(r%Y%Max, real64)
   endif
   call figure_check(FIG_OK, stat)
   endfunction ip_plot_selection

   recursive subroutine ip_cancel_selection(stat)
   !< End the box the user is dragging (`CancelPlotSelection`) without the zoom ImPlot applies on release: the
   !< program keeps the box (`ip_plot_selection` on this frame) as its own choice. Nothing happens without a box.
   !< Between `ip_begin_plot` and `ip_end_plot`; it ends the setup. Statuses: `FIG_ERR_STATE` outside a plot, from a
   !< task.
   integer(int32), intent(out), optional :: stat !< Status.

   if (figure_draw_refused('ip_cancel_selection', stat)) return ! a task does not draw
   if (plot_refused('ip_cancel_selection', .false., stat)) return
   call ImPlot_CancelPlotSelection()
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
   logical(c_bool), target                 :: held     !< A handle is held.
   real(real64)                            :: t        !< Swap.

   moved = .false.
   if (figure_draw_refused('ip_drag_rect', stat)) return ! a task does not draw
   if (.not. drag_ok('ip_drag_rect', color, stat)) return
   if (ieee_is_nan(xmin) .or. ieee_is_nan(xmax) .or. ieee_is_nan(ymin) .or. ieee_is_nan(ymax)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_drag_rect: an edge is NaN', stat)
      return
   endif
   if (plot_refused('ip_drag_rect', .false., stat)) return
   held = .false._c_bool
   moved = logical(ImPlot_DragRect(int(id, c_int), c_loc(xmin), c_loc(ymin), c_loc(xmax), c_loc(ymax), drag_color(color), &
                                   0_c_int, c_null_ptr, c_null_ptr, c_loc(held)))
   if (.not. logical(held)) then ! released: in order (ImPlot moves each edge on its own)
      if (xmin > xmax) then
         t = xmin
         xmin = xmax
         xmax = t
      endif
      if (ymin > ymax) then
         t = ymin
         ymin = ymax
         ymax = t
      endif
   endif
   call figure_check(FIG_OK, stat)
   endfunction ip_drag_rect

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
   real(c_float)                           :: c(4)     !< Box colour.
   integer(c_int)                          :: code     !< ImAxis.

   if (figure_draw_refused('ip_tag', stat)) return ! a task does not draw
   if (.not. rgba_ok(color)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_tag: a colour needs 4 components (RGBA)', stat)
      return
   endif
   if (ieee_is_nan(value)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_tag: the value is NaN', stat)
      return
   endif
   if (axis_refused('ip_tag', axis, code, .false., stat)) return
   c = [0.0_c_float, 0.0_c_float, 0.0_c_float, -1.0_c_float] ! the last item's colour
   if (present(color)) c = real(color, c_float)
   if (present(text)) then
      call figure_check(fig_plot_tag(code, real(value, c_double), c, text, len(text, c_int), 1_c_int), stat)
   else
      call figure_check(fig_plot_tag(code, real(value, c_double), c, ' ', 0_c_int, 0_c_int), stat)
   endif
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
   type(im_plot_spec)                      :: c         !< Spec: the vertical flag.
   type(im_vec2)                           :: d         !< Offset.

   if (figure_draw_refused('ip_text', stat)) return ! a task does not draw
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
   d = im_vec2(0.0_c_float, 0.0_c_float)
   if (present(offset)) d = im_vec2(real(offset(1), c_float), real(offset(2), c_float))
   call figure_ImPlotSpec_default(c)
   call set_flag(c%Flags, ImPlotTextFlags_Vertical, vertical)
   call ImPlot_PlotText(cstr(text), real(x, c_double), real(y, c_double), d, c)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_text

   ! more items: stairs, stems, infinite lines, histograms

   recursive subroutine ip_stairs_r32(label, x, y, spec, stat)
   !< A staircase through the points (x(i), y(i)) (`PlotStairs`): y(i) held from x(i) to x(i+1) (with
   !< `ImPlotStairsFlags_PreStep` in the spec, from x(i-1) to x(i)), single precision; read in place with any
   !< stride (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label !< Legend label.
   real(real32),           intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),           intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat  !< Status.
   type(series_r32), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_stairs', stat)) return ! a task does not draw
   if (plot_refused('ip_stairs', .false., stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_stairs', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotStairs_FloatPtrFloatPtr(cstr(label), d%p(1), d%p(2), int(size(x), c_int), series_spec(d, spec))
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
   type(series_r32), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_stairs', stat)) return ! a task does not draw
   if (plot_refused('ip_stairs', .false., stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_stairs', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotStairs_FloatPtrFloatPtr(cstr(label), d%p(1), d%p(2), int(size(x), c_int), series_spec(d, spec))
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
   type(series_r32), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_stairs', stat)) return ! a task does not draw
   if (plot_refused('ip_stairs', .false., stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_stairs', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotStairs_FloatPtrFloatPtr(cstr(label), d%p(1), d%p(2), int(size(x), c_int), series_spec(d, spec))
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
   type(series_r64), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_stairs', stat)) return ! a task does not draw
   if (plot_refused('ip_stairs', .false., stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_stairs', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotStairs_doublePtrdoublePtr(cstr(label), d%p(1), d%p(2), int(size(x), c_int), series_spec(d, spec))
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
   type(series_r64), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_stairs', stat)) return ! a task does not draw
   if (plot_refused('ip_stairs', .false., stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_stairs', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotStairs_doublePtrdoublePtr(cstr(label), d%p(1), d%p(2), int(size(x), c_int), series_spec(d, spec))
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
   type(series_r64), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_stairs', stat)) return ! a task does not draw
   if (plot_refused('ip_stairs', .false., stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_stairs', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotStairs_doublePtrdoublePtr(cstr(label), d%p(1), d%p(2), int(size(x), c_int), series_spec(d, spec))
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
   type(series_r32), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_stems', stat)) return ! a task does not draw
   if (plot_refused('ip_stems', .false., stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_stems', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotStems_FloatPtrFloatPtr(cstr(label), d%p(1), d%p(2), &
                                          int(size(x), c_int), uniform(ref, 0.0_real64), series_spec(d, spec))
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
   type(series_r32), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_stems', stat)) return ! a task does not draw
   if (plot_refused('ip_stems', .false., stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_stems', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotStems_FloatPtrFloatPtr(cstr(label), d%p(1), d%p(2), &
                                          int(size(x), c_int), uniform(ref, 0.0_real64), series_spec(d, spec))
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
   type(series_r32), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_stems', stat)) return ! a task does not draw
   if (plot_refused('ip_stems', .false., stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_stems', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotStems_FloatPtrFloatPtr(cstr(label), d%p(1), d%p(2), &
                                          int(size(x), c_int), uniform(ref, 0.0_real64), series_spec(d, spec))
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
   type(series_r64), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_stems', stat)) return ! a task does not draw
   if (plot_refused('ip_stems', .false., stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_stems', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotStems_doublePtrdoublePtr(cstr(label), d%p(1), d%p(2), &
                                            int(size(x), c_int), uniform(ref, 0.0_real64), series_spec(d, spec))
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
   type(series_r64), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_stems', stat)) return ! a task does not draw
   if (plot_refused('ip_stems', .false., stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_stems', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotStems_doublePtrdoublePtr(cstr(label), d%p(1), d%p(2), &
                                            int(size(x), c_int), uniform(ref, 0.0_real64), series_spec(d, spec))
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
   type(series_r64), target                                 :: d     !< Where ImPlot reads the arrays.

   if (figure_draw_refused('ip_stems', stat)) return ! a task does not draw
   if (plot_refused('ip_stems', .false., stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_stems', stat)) return
   call series_lead(d, 2, y)
   call series_put(d, 1, x)
   call ImPlot_PlotStems_doublePtrdoublePtr(cstr(label), d%p(1), d%p(2), &
                                            int(size(x), c_int), uniform(ref, 0.0_real64), series_spec(d, spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_stems_i64_r64

   recursive subroutine ip_inf_lines_r32(label, values, horizontal, spec, stat)
   !< Lines across the whole plot (`PlotInfLines`): vertical at x = values(i), or horizontal at y = values(i) with
   !< `horizontal=.true.`, single precision; read in place with any stride (plots.md, "Data in place").
   character(len=*),       intent(in)                       :: label      !< Legend label.
   real(real32),           intent(in), target, asynchronous :: values(:)  !< Positions [x units; y units when horizontal].
   logical,                intent(in), optional             :: horizontal !< Horizontal lines (default: vertical).
   type(plot_spec_object), intent(in), optional             :: spec       !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional            :: stat       !< Status.
   type(series_r32), target                                 :: d          !< Where ImPlot reads the array.

   if (figure_draw_refused('ip_inf_lines', stat)) return ! a task does not draw
   if (plot_refused('ip_inf_lines', .false., stat)) return
   if (.not. series_ok(size(values, kind=int64), size(values, kind=int64), 'ip_inf_lines', stat)) return
   call series_lead(d, 2, values)
   call ImPlot_PlotInfLines_FloatPtr(cstr(label), d%p(2), &
                                     int(size(values), c_int), inf_spec(series_spec(d, spec), horizontal))
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
   type(series_r64), target                                 :: d          !< Where ImPlot reads the array.

   if (figure_draw_refused('ip_inf_lines', stat)) return ! a task does not draw
   if (plot_refused('ip_inf_lines', .false., stat)) return
   if (.not. series_ok(size(values, kind=int64), size(values, kind=int64), 'ip_inf_lines', stat)) return
   call series_lead(d, 2, values)
   call ImPlot_PlotInfLines_doublePtr(cstr(label), d%p(2), &
                                      int(size(values), c_int), inf_spec(series_spec(d, spec), horizontal))
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
   type(series_r64), target                         :: d          !< Where ImPlot reads the array.

   if (figure_draw_refused('ip_inf_lines', stat)) return ! a task does not draw
   if (plot_refused('ip_inf_lines', .false., stat)) return
   if (.not. series_ok(size(values, kind=int64), size(values, kind=int64), 'ip_inf_lines', stat)) return
   call series_put(d, 2, values)
   call ImPlot_PlotInfLines_doublePtr(cstr(label), d%p(2), &
                                      int(size(values), c_int), inf_spec(series_spec(d, spec), horizontal))
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
   type(series_r64), target                         :: d          !< Where ImPlot reads the array.

   if (figure_draw_refused('ip_inf_lines', stat)) return ! a task does not draw
   if (plot_refused('ip_inf_lines', .false., stat)) return
   if (.not. series_ok(size(values, kind=int64), size(values, kind=int64), 'ip_inf_lines', stat)) return
   call series_put(d, 2, values)
   call ImPlot_PlotInfLines_doublePtr(cstr(label), d%p(2), &
                                      int(size(values), c_int), inf_spec(series_spec(d, spec), horizontal))
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
   real(real32), allocatable, target               :: packed(:) !< The finite values, contiguous, when copied.
   type(c_ptr)                                   :: p         !< Where ImPlot reads them.
   type(im_plot_range)                           :: r         !< Range.
   type(im_plot_spec)                            :: c         !< Spec, stride automatic.
   integer(c_int)                                :: nb        !< Bins.
   integer(int64)                                :: n         !< Finite values.
   real(c_double)                                :: top       !< Tallest bar.
   real(real64)                                  :: sd        !< Standard deviation (Scott's rule).

   if (present(max_count)) max_count = 0.0_real64
   if (figure_draw_refused('ip_histogram', stat)) return ! a task does not draw
   if (.not. bins_ok('ip_histogram', 'bins', bins, nb, stat)) return
   if (.not. ends_ok('ip_histogram', 'vmin', vmin, 'vmax', vmax, stat)) return
   if (plot_refused('ip_histogram', .false., stat)) return
   if (.not. series_ok(size(values, kind=int64), size(values, kind=int64), 'ip_histogram', stat)) return
   n = count(ieee_is_finite(values))
   if (n == size(values, kind=int64) .and. in_line(values)) then
      p = c_null_ptr
      if (n > 0_int64) p = c_loc(values(1))
   else
      packed = pack(values, ieee_is_finite(values))
      p = c_null_ptr
      if (n > 0_int64) p = c_loc(packed)
      plot_copies = plot_copies + 1_int64
   endif
   if (n == 0_int64) then
      call figure_check(FIG_OK, stat) ! nothing to count: no item
      return
   endif
   if (present(vmin)) then
      r = im_plot_range(real(vmin, c_double), real(vmax, c_double))
   else
      r%Min = real(minval(values, mask=ieee_is_finite(values)), c_double)
      r%Max = real(maxval(values, mask=ieee_is_finite(values)), c_double)
      call widen(r)
   endif
   sd = 0.0_real64
   if (nb == ImPlotBin_Scott) then
      if (allocated(packed)) then
         sd = std_dev(real(packed, real64))
      else
         sd = std_dev(real(values, real64))
      endif
   endif
   nb = rule_bins(nb, n, r, sd)
   c = spec_c(spec)
   c%Offset = 0_c_int
   c%Stride = -1_c_int ! IMPLOT_AUTO: the values are contiguous, and the bars ImPlot draws from its counts are too
   plot_stride = int(storage_size(values) / 8, int64)
   top = ImPlot_PlotHistogram_FloatPtr(cstr(label), p, int(n, c_int), nb, uniform(bar_scale, 1.0_real64), r, c)
   if (present(max_count)) max_count = real(top, real64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_histogram_r32

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
   type(series_r32), target                                 :: d         !< Where ImPlot reads the arrays.
   real(real32), allocatable, target                        :: px(:)     !< The finite points' x, when copied.
   real(real32), allocatable, target                        :: py(:)     !< ... and y.
   logical, allocatable                                     :: fin(:)    !< Finite points.
   type(im_plot_rect)                                       :: r         !< Range.
   type(im_plot_spec)                                       :: c         !< Spec.
   integer(c_int)                                           :: nbx       !< Bins along x.
   integer(c_int)                                           :: nby       !< Bins along y.
   integer(c_int)                                           :: cmap      !< Colormap id.
   integer(int64)                                           :: n         !< Finite points.
   real(c_double)                                           :: top       !< Fullest cell.
   real(real64)                                             :: sx        !< Standard deviation of x (Scott's rule).
   real(real64)                                             :: sy        !< ... of y.

   if (present(max_count)) max_count = 0.0_real64
   if (figure_draw_refused('ip_histogram2d', stat)) return ! a task does not draw
   if (.not. bins_ok('ip_histogram2d', 'xbins', xbins, nbx, stat)) return
   if (.not. bins_ok('ip_histogram2d', 'ybins', ybins, nby, stat)) return
   if (.not. ends_ok('ip_histogram2d', 'xmin', xmin, 'xmax', xmax, stat)) return
   if (.not. ends_ok('ip_histogram2d', 'ymin', ymin, 'ymax', ymax, stat)) return
   if (.not. colormap_ok('ip_histogram2d', colormap, cmap, stat)) return
   if (plot_refused('ip_histogram2d', .false., stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_histogram2d', stat)) return
   fin = ieee_is_finite(x) .and. ieee_is_finite(y)
   n = count(fin)
   if (n == size(x, kind=int64)) then
      call series_lead(d, 2, y)
      call series_put(d, 1, x)
   else
      px = pack(x, fin)
      py = pack(y, fin)
      d%stride = int(storage_size(px) / 8, int64)
      if (n > 0_int64) then
         d%p(1) = c_loc(px)
         d%p(2) = c_loc(py)
      endif
      plot_copies = plot_copies + 2_int64
   endif
   if (n == 0_int64) then
      call figure_check(FIG_OK, stat) ! nothing to count: no item
      return
   endif
   ! the range is always given: ImPlot 1.2 WIP computes a missing x range wrong (its minimum twice)
   if (present(xmin)) then
      r%X = im_plot_range(real(xmin, c_double), real(xmax, c_double))
   else
      r%X%Min = real(minval(x, mask=fin), c_double)
      r%X%Max = real(maxval(x, mask=fin), c_double)
      call widen(r%X)
   endif
   if (present(ymin)) then
      r%Y = im_plot_range(real(ymin, c_double), real(ymax, c_double))
   else
      r%Y%Min = real(minval(y, mask=fin), c_double)
      r%Y%Max = real(maxval(y, mask=fin), c_double)
      call widen(r%Y)
   endif
   sx = 0.0_real64
   sy = 0.0_real64
   if (nbx == ImPlotBin_Scott) sx = std_dev(real(pack(x, fin), real64))
   if (nby == ImPlotBin_Scott) sy = std_dev(real(pack(y, fin), real64))
   nbx = rule_bins(nbx, n, r%X, sx)
   nby = rule_bins(nby, n, r%Y, sy)
   c = series_spec(d, spec)
   call ImPlot_PushColormap_PlotColormap(cmap)
   top = ImPlot_PlotHistogram2D_FloatPtr(cstr(label), d%p(1), d%p(2), int(n, c_int), nbx, nby, r, c)
   call ImPlot_PopColormap(1_c_int)
   if (present(max_count)) max_count = real(top, real64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_histogram2d_r32

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
   real(real64), allocatable, target               :: packed(:) !< The finite values, contiguous, when copied.
   type(c_ptr)                                   :: p         !< Where ImPlot reads them.
   type(im_plot_range)                           :: r         !< Range.
   type(im_plot_spec)                            :: c         !< Spec, stride automatic.
   integer(c_int)                                :: nb        !< Bins.
   integer(int64)                                :: n         !< Finite values.
   real(c_double)                                :: top       !< Tallest bar.
   real(real64)                                  :: sd        !< Standard deviation (Scott's rule).

   if (present(max_count)) max_count = 0.0_real64
   if (figure_draw_refused('ip_histogram', stat)) return ! a task does not draw
   if (.not. bins_ok('ip_histogram', 'bins', bins, nb, stat)) return
   if (.not. ends_ok('ip_histogram', 'vmin', vmin, 'vmax', vmax, stat)) return
   if (plot_refused('ip_histogram', .false., stat)) return
   if (.not. series_ok(size(values, kind=int64), size(values, kind=int64), 'ip_histogram', stat)) return
   n = count(ieee_is_finite(values))
   if (n == size(values, kind=int64) .and. in_line(values)) then
      p = c_null_ptr
      if (n > 0_int64) p = c_loc(values(1))
   else
      packed = pack(values, ieee_is_finite(values))
      p = c_null_ptr
      if (n > 0_int64) p = c_loc(packed)
      plot_copies = plot_copies + 1_int64
   endif
   if (n == 0_int64) then
      call figure_check(FIG_OK, stat) ! nothing to count: no item
      return
   endif
   if (present(vmin)) then
      r = im_plot_range(real(vmin, c_double), real(vmax, c_double))
   else
      r%Min = real(minval(values, mask=ieee_is_finite(values)), c_double)
      r%Max = real(maxval(values, mask=ieee_is_finite(values)), c_double)
      call widen(r)
   endif
   sd = 0.0_real64
   if (nb == ImPlotBin_Scott) then
      if (allocated(packed)) then
         sd = std_dev(real(packed, real64))
      else
         sd = std_dev(real(values, real64))
      endif
   endif
   nb = rule_bins(nb, n, r, sd)
   c = spec_c(spec)
   c%Offset = 0_c_int
   c%Stride = -1_c_int ! IMPLOT_AUTO: the values are contiguous, and the bars ImPlot draws from its counts are too
   plot_stride = int(storage_size(values) / 8, int64)
   top = ImPlot_PlotHistogram_doublePtr(cstr(label), p, int(n, c_int), nb, uniform(bar_scale, 1.0_real64), r, c)
   if (present(max_count)) max_count = real(top, real64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_histogram_r64

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
   type(series_r64), target                                 :: d         !< Where ImPlot reads the arrays.
   real(real64), allocatable, target                        :: px(:)     !< The finite points' x, when copied.
   real(real64), allocatable, target                        :: py(:)     !< ... and y.
   logical, allocatable                                     :: fin(:)    !< Finite points.
   type(im_plot_rect)                                       :: r         !< Range.
   type(im_plot_spec)                                       :: c         !< Spec.
   integer(c_int)                                           :: nbx       !< Bins along x.
   integer(c_int)                                           :: nby       !< Bins along y.
   integer(c_int)                                           :: cmap      !< Colormap id.
   integer(int64)                                           :: n         !< Finite points.
   real(c_double)                                           :: top       !< Fullest cell.
   real(real64)                                             :: sx        !< Standard deviation of x (Scott's rule).
   real(real64)                                             :: sy        !< ... of y.

   if (present(max_count)) max_count = 0.0_real64
   if (figure_draw_refused('ip_histogram2d', stat)) return ! a task does not draw
   if (.not. bins_ok('ip_histogram2d', 'xbins', xbins, nbx, stat)) return
   if (.not. bins_ok('ip_histogram2d', 'ybins', ybins, nby, stat)) return
   if (.not. ends_ok('ip_histogram2d', 'xmin', xmin, 'xmax', xmax, stat)) return
   if (.not. ends_ok('ip_histogram2d', 'ymin', ymin, 'ymax', ymax, stat)) return
   if (.not. colormap_ok('ip_histogram2d', colormap, cmap, stat)) return
   if (plot_refused('ip_histogram2d', .false., stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_histogram2d', stat)) return
   fin = ieee_is_finite(x) .and. ieee_is_finite(y)
   n = count(fin)
   if (n == size(x, kind=int64)) then
      call series_lead(d, 2, y)
      call series_put(d, 1, x)
   else
      px = pack(x, fin)
      py = pack(y, fin)
      d%stride = int(storage_size(px) / 8, int64)
      if (n > 0_int64) then
         d%p(1) = c_loc(px)
         d%p(2) = c_loc(py)
      endif
      plot_copies = plot_copies + 2_int64
   endif
   if (n == 0_int64) then
      call figure_check(FIG_OK, stat) ! nothing to count: no item
      return
   endif
   ! the range is always given: ImPlot 1.2 WIP computes a missing x range wrong (its minimum twice)
   if (present(xmin)) then
      r%X = im_plot_range(real(xmin, c_double), real(xmax, c_double))
   else
      r%X%Min = real(minval(x, mask=fin), c_double)
      r%X%Max = real(maxval(x, mask=fin), c_double)
      call widen(r%X)
   endif
   if (present(ymin)) then
      r%Y = im_plot_range(real(ymin, c_double), real(ymax, c_double))
   else
      r%Y%Min = real(minval(y, mask=fin), c_double)
      r%Y%Max = real(maxval(y, mask=fin), c_double)
      call widen(r%Y)
   endif
   sx = 0.0_real64
   sy = 0.0_real64
   if (nbx == ImPlotBin_Scott) sx = std_dev(real(pack(x, fin), real64))
   if (nby == ImPlotBin_Scott) sy = std_dev(real(pack(y, fin), real64))
   nbx = rule_bins(nbx, n, r%X, sx)
   nby = rule_bins(nby, n, r%Y, sy)
   c = series_spec(d, spec)
   call ImPlot_PushColormap_PlotColormap(cmap)
   top = ImPlot_PlotHistogram2D_doublePtr(cstr(label), d%p(1), d%p(2), int(n, c_int), nbx, nby, r, c)
   call ImPlot_PopColormap(1_c_int)
   if (present(max_count)) max_count = real(top, real64)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_histogram2d_r64

   ! contour lines

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

   if (figure_draw_refused('ip_contour', stat)) return ! a task does not draw
   if (.not. contour_ok(nlevels, colormap, color, cmap, stat)) return
   if (present(levels)) then
      lev = levels
   else
      lev = ip_contour_levels(f, nlevels)
   endif
   call ip_contour_lines(f, x0, x1, y0, y1, lev, xs, ys, first)
   call finite_range_r32(f, fmin, fmax, found)
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

   if (figure_draw_refused('ip_contour', stat)) return ! a task does not draw
   if (.not. contour_ok(nlevels, colormap, color, cmap, stat)) return
   if (present(levels)) then
      lev = levels
   else
      lev = ip_contour_levels(f, nlevels)
   endif
   call ip_contour_lines(f, x0, x1, y0, y1, lev, xs, ys, first)
   call finite_range_r64(f, fmin, fmax, found)
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
         if (.not. ieee_is_finite(levels(k))) cycle
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
         if (.not. ieee_is_finite(levels(k))) cycle
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

   ! private helpers

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
   if (.not. all(ieee_is_finite(v))) return ! a hole (and no comparison with a NaN: an FPE under traps)
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
         if (.not. ieee_is_finite(f(i, j))) cycle
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
         if (.not. ieee_is_finite(f(i, j))) cycle
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
   type(im_plot_spec)                      :: c           !< Line spec.
   integer(c_int)                          :: status      !< A label's status (always FIG_OK inside a plot).
   type(im_vec4)                           :: v           !< A colormap colour.
   integer(int64)                          :: n           !< Ends of a level.
   integer(int64)                          :: e           !< An end: the first of the level's middle segment.
   integer(int32)                          :: k           !< Counter.
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
   call figure_ImPlotSpec_default(c)
   c%Flags = int(ImPlotLineFlags_Segments, c_int)
   if (present(line_weight)) c%LineWeight = real(line_weight, c_float)
   if (present(color)) c%LineColor = rgba(color)
   do k = 1_int32, size(lev, kind=int32)
      n = first(k + 1) - first(k)
      if (n < 2_int64) cycle
      if (by_map) then
         t = 0.5_real64
         if (fmax > fmin) t = min(1.0_real64, max(0.0_real64, (lev(k) - fmin) / (fmax - fmin)))
         call ImPlot_SampleColormap(real(t, c_float), cmap, v)
         c%LineColor = v
      endif
      call ImPlot_PlotLine_doublePtrdoublePtr(cstr(label), c_loc(xs(first(k))), c_loc(ys(first(k))), int(n, c_int), c)
      if (write_text) then ! on a segment part-way through the level's list (rows bottom to top), by level: apart
         e = first(k) + 2_int64 * int(real(n / 2_int64, real64) * (k - 0.5_real64) / size(lev), int64)
         call ImPlot_GetLastItemColor(v)
         status = fig_plot_annotation(0.5_c_double * (xs(e) + xs(e + 1)), 0.5_c_double * (ys(e) + ys(e + 1)), &
                                      [v%x, v%y, v%z, v%w], 0.0_c_float, 0.0_c_float, 0_c_int, level_text(lev(k)), &
                                      len(level_text(lev(k)), c_int))
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

   pure function drag_color(color) result(v)
   !< A drag tool's colour: the given one, or ImPlot's automatic colour (IMPLOT_AUTO_COL: alpha -1).
   real(real64), intent(in), optional :: color(:) !< Colour, RGBA.
   type(im_vec4)                      :: v        !< Colour.

   v = im_vec4(0.0_c_float, 0.0_c_float, 0.0_c_float, -1.0_c_float)
   if (present(color)) v = rgba(color)
   endfunction drag_color


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
   ok = cmap >= 0_c_int .and. cmap < ImPlot_GetColormapCount()
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
   integer(c_int)                          :: on(6)   !< Axes set up.
   integer(c_int)                          :: sc(6)   !< Their scales.
   integer(c_int)                          :: state   !< 0 no plot, 1 setup open, 2 setup over.

   refused = .true.
   state = fig_plot_state(on, sc)
   if (state == 0_c_int) then
      call figure_usage_error(caller//': no plot is being declared (call it between a true ip_begin_plot and '// &
                              'ip_end_plot)', stat)
      return
   endif
   if (setup .and. state == 2_c_int) then
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
   integer(c_int)                          :: on(6)   !< Axes set up.
   integer(c_int)                          :: sc(6)   !< Their scales.
   integer(c_int)                          :: state   !< Plot state.

   refused = .true.
   code = axis_index(axis)
   if (code < 0_c_int) then
      call figure_fail(FIG_ERR_ARGUMENT, caller//": unknown axis '"//axis//"' ('x1', 'x2', 'x3', 'y1', 'y2' or "// &
                       "'y3')", stat)
      return
   endif
   if (plot_refused(caller, setup, stat)) return
   state = fig_plot_state(on, sc)
   if (on(code + 1_c_int) == 0_c_int) then
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

   pure function inf_spec(c, horizontal) result(s)
   !< The spec of infinite lines: `c` with ImPlot's horizontal flag set when `horizontal` is true.
   type(im_plot_spec), intent(in)           :: c          !< Spec.
   logical,            intent(in), optional :: horizontal !< Horizontal lines.
   type(im_plot_spec)                       :: s          !< Spec to pass.

   s = c
   if (present(horizontal)) then
      if (horizontal) s%Flags = ior(s%Flags, ImPlotInfLinesFlags_Horizontal)
   endif
   endfunction inf_spec

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

   pure subroutine widen(r)
   !< A range of one value made one unit wide around it: ImPlot divides by the width of a bin.
   type(im_plot_range), intent(inout) :: r !< Range.

   if (r%Max > r%Min) return
   r%Min = r%Min - 0.5_c_double
   r%Max = r%Max + 0.5_c_double
   endsubroutine widen

   pure function rule_bins(nb, n, r, sd) result(bins)
   !< A count of bins: `nb` when it is one, or by its rule over `n` values in the range `r` (ImPlot's formulas,
   !< computed here: ImPlot's Scott rule divides by a zero spread or gives no bin for a narrow range).
   integer(c_int),      intent(in) :: nb   !< A count (> 0) or an `ImPlotBin_*` rule.
   integer(int64),      intent(in) :: n    !< Values.
   type(im_plot_range), intent(in) :: r    !< Range.
   real(real64),        intent(in) :: sd   !< Standard deviation of the values (Scott's rule).
   integer(c_int)                  :: bins !< Bins, at least 1.
   real(real64)                    :: w    !< Bin width (Scott's rule).
   real(real64)                    :: k    !< Bins, as a real.

   if (nb > 0_c_int) then
      bins = nb
      return
   endif
   select case (nb)
   case (ImPlotBin_Sqrt)
      k = ceiling(sqrt(real(n, real64)))
   case (ImPlotBin_Rice)
      k = ceiling(2.0_real64 * real(n, real64)**(1.0_real64 / 3.0_real64))
   case (ImPlotBin_Scott)
      w = 3.49_real64 * sd / real(n, real64)**(1.0_real64 / 3.0_real64)
      k = 1.0_real64
      if (w > 0.0_real64) k = anint(min(real(r%Max - r%Min, real64) / w, 1.0e6_real64))
   case default ! Sturges
      k = ceiling(1.0_real64 + log(real(n, real64)) / log(2.0_real64))
   endselect
   bins = int(max(1.0_real64, min(k, 1.0e6_real64)), c_int)
   endfunction rule_bins

   pure function std_dev(v) result(s)
   !< Standard deviation of values (population: divided by their count; 0 for none).
   real(real64), intent(in) :: v(:) !< Values.
   real(real64)             :: s    !< Standard deviation.
   real(real64)             :: m    !< Mean.

   s = 0.0_real64
   if (size(v) == 0) return
   m = sum(v) / real(size(v), real64)
   s = sqrt(sum((v - m)**2) / real(size(v), real64))
   endfunction std_dev

   function in_line_r32(a) result(contiguous_)
   !< Whether an array's elements are adjacent in memory (its stride is its element size).
   real(real32), intent(in), target :: a(:)        !< Array.
   logical                          :: contiguous_ !< Adjacent.

   contiguous_ = .true.
   if (size(a) > 1) contiguous_ = gap(c_loc(a(1)), c_loc(a(2))) == storage_size(a, kind=int64) / 8_int64
   endfunction in_line_r32

   function in_line_r64(a) result(contiguous_)
   !< Whether an array's elements are adjacent in memory (its stride is its element size).
   real(real64), intent(in), target :: a(:)        !< Array.
   logical                          :: contiguous_ !< Adjacent.

   contiguous_ = .true.
   if (size(a) > 1) contiguous_ = gap(c_loc(a(1)), c_loc(a(2))) == storage_size(a, kind=int64) / 8_int64
   endfunction in_line_r64

   pure subroutine set_flag(flags, flag, on)
   !< Set (`on` true) or clear (`on` false) `flag` in `flags`; unchanged when `on` is absent.
   integer(c_int), intent(inout)        :: flags !< Flags.
   integer(c_int), intent(in)           :: flag  !< The flag.
   logical,        intent(in), optional :: on    !< Set or clear.

   if (.not. present(on)) return
   if (on) then
      flags = ior(flags, flag)
   else
      flags = iand(flags, not(flag))
   endif
   endsubroutine set_flag

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

   pure function uniform(value, default) result(v)
   !< An optional abscissa parameter, or its default, as a C double.
   real(real64), intent(in), optional :: value   !< Given value.
   real(real64), intent(in)           :: default !< Default.
   real(c_double)                     :: v       !< Value to pass.

   v = real(default, c_double)
   if (present(value)) v = real(value, c_double)
   endfunction uniform

   subroutine lead_r32(d, k, a)
   !< Place the array that sets an item's stride (its ordinates) in slot `k`: read in place with its own stride when
   !< that is a positive multiple of the element size within a C int; otherwise (a reversed section, a stride beyond a
   !< C int) copied, contiguous, into the slot's scratch.
   type(series_r32), intent(inout)                    :: d    !< The item's arrays.
   integer(int32),   intent(in)                       :: k    !< Slot.
   real(real32),     intent(in), target, asynchronous :: a(:) !< Array.
   integer(int64)                                     :: es   !< Element size [bytes].
   integer(int64)                                     :: s    !< Its stride [bytes].

   call scratch_age()
   es = storage_size(a, kind=int64) / 8_int64
   d%stride = es
   if (size(a) == 0) return
   s = es
   if (size(a) > 1) s = gap(c_loc(a(1)), c_loc(a(2)))
   if (s > 0_int64 .and. mod(s, es) == 0_int64 .and. s <= int(huge(0_c_int), int64)) then
      d%stride = s
      d%p(k) = c_loc(a(1))
   else
      call scratch_reserve_r32(k, size(a, kind=int64))
      call scratch_copy(a, scratch_r32(k)%v, 1_int64)
      d%p(k) = c_loc(scratch_r32(k)%v)
      plot_copies = plot_copies + 1_int64
   endif
   endsubroutine lead_r32

   subroutine put_r32(d, k, a)
   !< Place an array of an item in slot `k`: read in place when its stride is the item's (set by `series_lead`, which
   !< comes first); otherwise copied at the item's stride into the slot's scratch.
   type(series_r32), intent(inout)                    :: d    !< The item's arrays.
   integer(int32),   intent(in)                       :: k    !< Slot.
   real(real32),     intent(in), target, asynchronous :: a(:) !< Array.
   integer(int64)                                     :: m    !< The item's stride [elements].

   if (size(a) == 0) return
   if (size(a) == 1) then
      d%p(k) = c_loc(a(1))
      return
   endif
   if (gap(c_loc(a(1)), c_loc(a(2))) == d%stride) then
      d%p(k) = c_loc(a(1))
      return
   endif
   m = d%stride / (storage_size(a, kind=int64) / 8_int64)
   call scratch_reserve_r32(k, (size(a, kind=int64) - 1_int64) * m + 1_int64)
   call scratch_copy(a, scratch_r32(k)%v, m)
   d%p(k) = c_loc(scratch_r32(k)%v)
   plot_copies = plot_copies + 1_int64
   endsubroutine put_r32

   subroutine put_i32_r32(d, k, a)
   !< Place integer abscissae of an item in slot `k`: converted to `real(real32)` (ImPlot reads x and y of one type),
   !< into the slot's scratch laid out at the item's stride, so that the ordinates stay in place.
   type(series_r32), intent(inout)            :: d    !< The item's arrays.
   integer(int32),   intent(in)               :: k    !< Slot.
   integer(int32),   intent(in), asynchronous :: a(:) !< Abscissae.
   integer(int64)                             :: m    !< The item's stride [elements].

   if (size(a) == 0) return
   m = d%stride / 4_int64
   call scratch_reserve_r32(k, (size(a, kind=int64) - 1_int64) * m + 1_int64)
   call scratch_copy(a, scratch_r32(k)%v, m)
   d%p(k) = c_loc(scratch_r32(k)%v)
   plot_copies = plot_copies + 1_int64
   endsubroutine put_i32_r32

   subroutine put_i64_r32(d, k, a)
   !< Place integer abscissae of an item in slot `k`: converted to `real(real32)` (ImPlot reads x and y of one type),
   !< into the slot's scratch laid out at the item's stride, so that the ordinates stay in place.
   type(series_r32), intent(inout)            :: d    !< The item's arrays.
   integer(int32),   intent(in)               :: k    !< Slot.
   integer(int64),   intent(in), asynchronous :: a(:) !< Abscissae.
   integer(int64)                             :: m    !< The item's stride [elements].

   if (size(a) == 0) return
   m = d%stride / 4_int64
   call scratch_reserve_r32(k, (size(a, kind=int64) - 1_int64) * m + 1_int64)
   call scratch_copy(a, scratch_r32(k)%v, m)
   d%p(k) = c_loc(scratch_r32(k)%v)
   plot_copies = plot_copies + 1_int64
   endsubroutine put_i64_r32

   function spec_stride_r32(d, spec) result(c)
   !< The C spec to pass: the given one, or ImPlot's defaults, with the item's stride.
   type(series_r32),       intent(in)           :: d    !< The item's arrays.
   type(plot_spec_object), intent(in), optional :: spec !< Style.
   type(im_plot_spec)                           :: c    !< `ImPlotSpec`.

   c = spec_c(spec)
   c%Stride = int(d%stride, c_int)
   plot_stride = d%stride
   endfunction spec_stride_r32

   subroutine lead_r64(d, k, a)
   !< Place the array that sets an item's stride (its ordinates) in slot `k`: read in place with its own stride when
   !< that is a positive multiple of the element size within a C int; otherwise (a reversed section, a stride beyond a
   !< C int) copied, contiguous, into the slot's scratch.
   type(series_r64), intent(inout)                    :: d    !< The item's arrays.
   integer(int32),   intent(in)                       :: k    !< Slot.
   real(real64),     intent(in), target, asynchronous :: a(:) !< Array.
   integer(int64)                                     :: es   !< Element size [bytes].
   integer(int64)                                     :: s    !< Its stride [bytes].

   call scratch_age()
   es = storage_size(a, kind=int64) / 8_int64
   d%stride = es
   if (size(a) == 0) return
   s = es
   if (size(a) > 1) s = gap(c_loc(a(1)), c_loc(a(2)))
   if (s > 0_int64 .and. mod(s, es) == 0_int64 .and. s <= int(huge(0_c_int), int64)) then
      d%stride = s
      d%p(k) = c_loc(a(1))
   else
      call scratch_reserve_r64(k, size(a, kind=int64))
      call scratch_copy(a, scratch_r64(k)%v, 1_int64)
      d%p(k) = c_loc(scratch_r64(k)%v)
      plot_copies = plot_copies + 1_int64
   endif
   endsubroutine lead_r64

   subroutine put_r64(d, k, a)
   !< Place an array of an item in slot `k`: read in place when its stride is the item's (set by `series_lead`, which
   !< comes first); otherwise copied at the item's stride into the slot's scratch.
   type(series_r64), intent(inout)                    :: d    !< The item's arrays.
   integer(int32),   intent(in)                       :: k    !< Slot.
   real(real64),     intent(in), target, asynchronous :: a(:) !< Array.
   integer(int64)                                     :: m    !< The item's stride [elements].

   if (size(a) == 0) return
   if (size(a) == 1) then
      d%p(k) = c_loc(a(1))
      return
   endif
   if (gap(c_loc(a(1)), c_loc(a(2))) == d%stride) then
      d%p(k) = c_loc(a(1))
      return
   endif
   m = d%stride / (storage_size(a, kind=int64) / 8_int64)
   call scratch_reserve_r64(k, (size(a, kind=int64) - 1_int64) * m + 1_int64)
   call scratch_copy(a, scratch_r64(k)%v, m)
   d%p(k) = c_loc(scratch_r64(k)%v)
   plot_copies = plot_copies + 1_int64
   endsubroutine put_r64

   subroutine put_i32_r64(d, k, a)
   !< Place integer abscissae of an item in slot `k`: converted to `real(real64)` (ImPlot reads x and y of one type),
   !< into the slot's scratch laid out at the item's stride, so that the ordinates stay in place.
   type(series_r64), intent(inout)            :: d    !< The item's arrays.
   integer(int32),   intent(in)               :: k    !< Slot.
   integer(int32),   intent(in), asynchronous :: a(:) !< Abscissae.
   integer(int64)                             :: m    !< The item's stride [elements].

   if (size(a) == 0) return
   m = d%stride / 8_int64
   call scratch_reserve_r64(k, (size(a, kind=int64) - 1_int64) * m + 1_int64)
   call scratch_copy(a, scratch_r64(k)%v, m)
   d%p(k) = c_loc(scratch_r64(k)%v)
   plot_copies = plot_copies + 1_int64
   endsubroutine put_i32_r64

   subroutine put_i64_r64(d, k, a)
   !< Place integer abscissae of an item in slot `k`: converted to `real(real64)` (ImPlot reads x and y of one type),
   !< into the slot's scratch laid out at the item's stride, so that the ordinates stay in place.
   type(series_r64), intent(inout)            :: d    !< The item's arrays.
   integer(int32),   intent(in)               :: k    !< Slot.
   integer(int64),   intent(in), asynchronous :: a(:) !< Abscissae.
   integer(int64)                             :: m    !< The item's stride [elements].

   if (size(a) == 0) return
   m = d%stride / 8_int64
   call scratch_reserve_r64(k, (size(a, kind=int64) - 1_int64) * m + 1_int64)
   call scratch_copy(a, scratch_r64(k)%v, m)
   d%p(k) = c_loc(scratch_r64(k)%v)
   plot_copies = plot_copies + 1_int64
   endsubroutine put_i64_r64

   function spec_stride_r64(d, spec) result(c)
   !< The C spec to pass: the given one, or ImPlot's defaults, with the item's stride.
   type(series_r64),       intent(in)           :: d    !< The item's arrays.
   type(plot_spec_object), intent(in), optional :: spec !< Style.
   type(im_plot_spec)                           :: c    !< `ImPlotSpec`.

   c = spec_c(spec)
   c%Stride = int(d%stride, c_int)
   plot_stride = d%stride
   endfunction spec_stride_r64

   subroutine scratch_age()
   !< Free the items' scratch (both precisions) when no item has copied into it in this frame or the one before: a
   !< program that stops plotting reversed or converted data gives the memory back at its next item. A new Dear ImGui
   !< context (its frame count restarted) frees it too.
   integer(int32) :: k   !< Slot.
   integer(int32) :: age !< Frames since the last copy.

   if (scratch_frame < 0_int32) return
   age = int(igGetFrameCount(), int32) - scratch_frame
   if (age == 0_int32 .or. age == 1_int32) return
   do k = 1_int32, 4_int32
      if (allocated(scratch_r32(k)%v)) deallocate(scratch_r32(k)%v)
      if (allocated(scratch_r64(k)%v)) deallocate(scratch_r64(k)%v)
   enddo
   scratch_frame = -1_int32
   endsubroutine scratch_age

   subroutine scratch_reserve_r32(k, n)
   !< Make the scratch of slot `k` (single precision) at least `n` elements long: kept from item to item and from frame
   !< to frame, grown by half again when too short (a series that grows by a point per frame is not reallocated every
   !< frame), freed by `scratch_age`. A temporary allocated and freed by every item can cost the memory's first touch
   !< every frame (nvfortran 26.9 with glibc: 2.4 ms against 1.0 ms to copy 10**6 doubles; plots.md, "Data in place").
   integer(int32), intent(in) :: k !< Slot.
   integer(int64), intent(in) :: n !< Elements needed.
   integer(int64)             :: c !< Capacity [elements].

   c = 0_int64
   if (allocated(scratch_r32(k)%v)) c = size(scratch_r32(k)%v, kind=int64)
   if (c < n) then
      if (allocated(scratch_r32(k)%v)) deallocate(scratch_r32(k)%v)
      allocate(scratch_r32(k)%v(max(n, c + c / 2_int64)))
   endif
   scratch_frame = int(igGetFrameCount(), int32)
   endsubroutine scratch_reserve_r32

   subroutine copy_r32(a, v, m)
   !< Copy `a` into `v` at a stride of `m` elements, v(1), v(1 + m), ... (the elements between left as they are), single
   !< precision. A reversed section of adjacent elements (`a(n:1:-1)`) is read through a contiguous view of its memory:
   !< with the descending unit stride known to the compiler, the copy runs as fast as a contiguous one (nvfortran 26.9
   !< takes twice as long through the section's descriptor).
   real(real32),   intent(in), target, asynchronous :: a(:) !< Array, any stride.
   real(real32),   intent(inout)                    :: v(:) !< Scratch, at least (size(a) - 1) m + 1 elements long.
   integer(int64), intent(in)                       :: m    !< Stride in v [elements].
   real(real32),   pointer, contiguous              :: r(:) !< A reversed section's elements, in memory order.
   integer(int64)                                   :: n    !< Elements.

   n = size(a, kind=int64)
   if (n == 0_int64) return
   if (n > 1_int64) then
      if (gap(c_loc(a(2)), c_loc(a(1))) == storage_size(a, kind=int64) / 8_int64) then
         call c_f_pointer(c_loc(a(n)), r, [n])
         if (m == 1_int64) then
            v(1_int64:n) = r(n:1_int64:-1_int64)
         else
            v(1_int64:(n - 1_int64) * m + 1_int64:m) = r(n:1_int64:-1_int64)
         endif
         return
      endif
   endif
   v(1_int64:(n - 1_int64) * m + 1_int64:m) = a
   endsubroutine copy_r32

   subroutine copy_i32_r32(a, v, m)
   !< Convert `int32` values to `real(real32)` into `v` at a stride of `m` elements.
   integer(int32), intent(in), asynchronous :: a(:) !< Values, any stride.
   real(real32),   intent(inout)            :: v(:) !< Scratch, at least (size(a) - 1) m + 1 elements long.
   integer(int64), intent(in)               :: m    !< Stride in v [elements].
   integer(int64)                           :: n    !< Elements.

   n = size(a, kind=int64)
   if (n > 0_int64) v(1_int64:(n - 1_int64) * m + 1_int64:m) = real(a, real32)
   endsubroutine copy_i32_r32

   subroutine copy_i64_r32(a, v, m)
   !< Convert `int64` values to `real(real32)` into `v` at a stride of `m` elements.
   integer(int64), intent(in), asynchronous :: a(:) !< Values, any stride.
   real(real32),   intent(inout)            :: v(:) !< Scratch, at least (size(a) - 1) m + 1 elements long.
   integer(int64), intent(in)               :: m    !< Stride in v [elements].
   integer(int64)                           :: n    !< Elements.

   n = size(a, kind=int64)
   if (n > 0_int64) v(1_int64:(n - 1_int64) * m + 1_int64:m) = real(a, real32)
   endsubroutine copy_i64_r32

   subroutine scratch_reserve_r64(k, n)
   !< Make the scratch of slot `k` (double precision) at least `n` elements long: kept from item to item and from frame
   !< to frame, grown by half again when too short (a series that grows by a point per frame is not reallocated every
   !< frame), freed by `scratch_age`. A temporary allocated and freed by every item can cost the memory's first touch
   !< every frame (nvfortran 26.9 with glibc: 2.4 ms against 1.0 ms to copy 10**6 doubles; plots.md, "Data in place").
   integer(int32), intent(in) :: k !< Slot.
   integer(int64), intent(in) :: n !< Elements needed.
   integer(int64)             :: c !< Capacity [elements].

   c = 0_int64
   if (allocated(scratch_r64(k)%v)) c = size(scratch_r64(k)%v, kind=int64)
   if (c < n) then
      if (allocated(scratch_r64(k)%v)) deallocate(scratch_r64(k)%v)
      allocate(scratch_r64(k)%v(max(n, c + c / 2_int64)))
   endif
   scratch_frame = int(igGetFrameCount(), int32)
   endsubroutine scratch_reserve_r64

   subroutine copy_r64(a, v, m)
   !< Copy `a` into `v` at a stride of `m` elements, v(1), v(1 + m), ... (the elements between left as they are), double
   !< precision. A reversed section of adjacent elements (`a(n:1:-1)`) is read through a contiguous view of its memory:
   !< with the descending unit stride known to the compiler, the copy runs as fast as a contiguous one (nvfortran 26.9
   !< takes twice as long through the section's descriptor).
   real(real64),   intent(in), target, asynchronous :: a(:) !< Array, any stride.
   real(real64),   intent(inout)                    :: v(:) !< Scratch, at least (size(a) - 1) m + 1 elements long.
   integer(int64), intent(in)                       :: m    !< Stride in v [elements].
   real(real64),   pointer, contiguous              :: r(:) !< A reversed section's elements, in memory order.
   integer(int64)                                   :: n    !< Elements.

   n = size(a, kind=int64)
   if (n == 0_int64) return
   if (n > 1_int64) then
      if (gap(c_loc(a(2)), c_loc(a(1))) == storage_size(a, kind=int64) / 8_int64) then
         call c_f_pointer(c_loc(a(n)), r, [n])
         if (m == 1_int64) then
            v(1_int64:n) = r(n:1_int64:-1_int64)
         else
            v(1_int64:(n - 1_int64) * m + 1_int64:m) = r(n:1_int64:-1_int64)
         endif
         return
      endif
   endif
   v(1_int64:(n - 1_int64) * m + 1_int64:m) = a
   endsubroutine copy_r64

   subroutine copy_i32_r64(a, v, m)
   !< Convert `int32` values to `real(real64)` into `v` at a stride of `m` elements.
   integer(int32), intent(in), asynchronous :: a(:) !< Values, any stride.
   real(real64),   intent(inout)            :: v(:) !< Scratch, at least (size(a) - 1) m + 1 elements long.
   integer(int64), intent(in)               :: m    !< Stride in v [elements].
   integer(int64)                           :: n    !< Elements.

   n = size(a, kind=int64)
   if (n > 0_int64) v(1_int64:(n - 1_int64) * m + 1_int64:m) = real(a, real64)
   endsubroutine copy_i32_r64

   subroutine copy_i64_r64(a, v, m)
   !< Convert `int64` values to `real(real64)` into `v` at a stride of `m` elements.
   integer(int64), intent(in), asynchronous :: a(:) !< Values, any stride.
   real(real64),   intent(inout)            :: v(:) !< Scratch, at least (size(a) - 1) m + 1 elements long.
   integer(int64), intent(in)               :: m    !< Stride in v [elements].
   integer(int64)                           :: n    !< Elements.

   n = size(a, kind=int64)
   if (n > 0_int64) v(1_int64:(n - 1_int64) * m + 1_int64:m) = real(a, real64)
   endsubroutine copy_i64_r64

   function gap(first, second) result(bytes)
   !< Bytes from one address to the next one: the stride of an array, from the addresses of two consecutive elements.
   !< The integer TRANSFER gives for a C address is processor-dependent; gfortran, nvfortran and ifx give the address.
   type(c_ptr), intent(in) :: first  !< Address of a(i).
   type(c_ptr), intent(in) :: second !< Address of a(i + 1).
   integer(int64)          :: bytes  !< Distance [bytes]; negative for a reversed section.

   bytes = int(transfer(second, 0_c_intptr_t) - transfer(first, 0_c_intptr_t), int64)
   endfunction gap

   function spec_c(spec) result(c)
   !< The C spec to pass: the given one, or ImPlot's defaults.
   type(plot_spec_object), intent(in), optional :: spec !< Style.
   type(im_plot_spec)                           :: c    !< `ImPlotSpec`.

   if (present(spec)) then
      c = spec%c
   else
      call figure_ImPlotSpec_default(c)
   endif
   endfunction spec_c

   pure function rgba_ok(color) result(ok)
   !< Whether an optional colour is absent or has 4 components.
   real(real64), intent(in), optional :: color(:) !< Colour, RGBA.
   logical                            :: ok       !< Acceptable.

   ok = .true.
   if (present(color)) ok = size(color) == 4
   endfunction rgba_ok

   pure function rgba(color) result(v)
   !< RGBA colour as an `ImVec4`.
   real(real64), intent(in) :: color(:) !< Colour, RGBA, 4 components.
   type(im_vec4)            :: v        !< Colour.

   v = im_vec4(real(color(1), c_float), real(color(2), c_float), real(color(3), c_float), real(color(4), c_float))
   endfunction rgba
endmodule figure_implot
