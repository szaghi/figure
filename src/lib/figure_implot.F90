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
!< `ip_end_plot` (only in that case). Items (`ip_line`, `ip_scatter`, `ip_bars`, `ip_shaded`) take `real(real32)` or
!< `real(real64)` arrays, read in place, without copies, during the call: they go straight to ImPlot's `float*` or
!< `double*` items (ImPlot is templated on the element type). A non-contiguous actual argument (e.g. a matrix row
!< `y(i,:)`) is copied by the compiler into a temporary: `ip_line(label, y, row)` plots a matrix row in place instead.
!<
!< Every item takes an optional `spec`, built by `ip_spec` from ImPlot's defaults (automatic colours, no markers):
!<
!<```fortran
!< call ip_line('residual', it, res, spec=ip_spec(line_color=[1.0_real64, 0.0_real64, 0.0_real64, 1.0_real64], &
!<                                               line_weight=2.0_real64, marker=ImPlotMarker_Circle))
!<```
use, intrinsic :: iso_c_binding, only : c_char, c_double, c_float, c_int, c_loc, c_null_ptr, c_ptr
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use, intrinsic :: ieee_arithmetic, only : ieee_is_finite
use figure_base, only : cstr, figure_check, figure_draw_refused, figure_fail, figure_refused, figure_scope_open, &
                        figure_scope_refused, format_refused, FORMAT_REAL, SCOPE_PLOT, SCOPE_SUBPLOTS
use figure_c_native, only : FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_OK, fig_colormap, fig_colormap_count, &
                            fig_colormap_name, fig_load_colormap, fig_texture_sampling, fig_plot_annotation, &
                            fig_colormap_legend, fig_plot_end
use figure_cimgui, only : im_vec2, im_vec4
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
                           ImPlot_SetNextAxisToFit, ImPlot_GetColormapCount
use figure_cimplot, only : ImPlot_DragLineX, ImPlot_DragLineY, ImPlot_DragPoint, ImPlot_GetLastItemColor,           &
                           ImPlot_SampleColormap,                                                                       &
                           ImPlot_PlotErrorBars_doublePtrdoublePtrdoublePtrdoublePtr,                                   &
                           ImPlot_PlotErrorBars_doublePtrdoublePtrdoublePtrInt,                                         &
                           ImPlot_PlotErrorBars_FloatPtrFloatPtrFloatPtrFloatPtr,                                       &
                           ImPlot_PlotErrorBars_FloatPtrFloatPtrFloatPtrInt
use figure_cimplot_enums, only : ImAxis_X1, ImAxis_Y1, ImPlotScale_Log10, ImPlotSubplotFlags_LinkAllX,                &
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

implicit none
private
public :: ip_begin_plot, ip_end_plot, ip_setup_axes, ip_begin_subplots, ip_end_subplots

character(len=128), allocatable :: subplots_seen(:)  !< Titles of the subplot figures drawn so far.
integer(int32)                  :: fits_pending = 0  !< Plots of a new subplot figure still to fit to their data.
public :: ip_bars, ip_line, ip_scatter, ip_shaded
public :: ip_colormap_scale, ip_heatmap, ip_image, ip_plot_limits, ip_plot_size, ip_setup_axes_limits
public :: ip_colormap, ip_colormap_names, ip_load_colormap
public :: ip_error_bars, ip_annotation, ip_drag_line_x, ip_drag_line_y, ip_drag_point
public :: ip_contour, ip_contour_lines, ip_contour_levels
public :: ip_colormap_legend
public :: ip_spec, plot_spec_object
! ImPlot's marker and item-flag constants (values generated from the cimplot metadata), for `ip_spec`
public :: ImPlotMarker_None, ImPlotMarker_Auto, ImPlotMarker_Circle, ImPlotMarker_Square, ImPlotMarker_Diamond
public :: ImPlotMarker_Up, ImPlotMarker_Down, ImPlotMarker_Left, ImPlotMarker_Right, ImPlotMarker_Cross
public :: ImPlotMarker_Plus, ImPlotMarker_Asterisk, ImPlotMarker_Vertical, ImPlotMarker_Horizontal
public :: ImPlotItemFlags_None, ImPlotItemFlags_NoLegend, ImPlotItemFlags_NoFit
public :: ImPlotLineFlags_Segments, ImPlotLineFlags_Loop, ImPlotLineFlags_SkipNaN, ImPlotLineFlags_NoClip
public :: ImPlotLineFlags_Shaded, ImPlotScatterFlags_NoClip, ImPlotBarsFlags_Horizontal
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
   !< matrix (read in place, with a stride: no copy).
   module procedure ip_line_r32, ip_line_r64, ip_line_values_r32, ip_line_values_r64, ip_line_row_r32, ip_line_row_r64
endinterface ip_line

interface ip_scatter
   !< Markers at the points (x(i), y(i)).
   module procedure ip_scatter_r32, ip_scatter_r64
endinterface ip_scatter

interface ip_bars
   !< Bars of height y(i) centred at x(i).
   module procedure ip_bars_r32, ip_bars_r64
endinterface ip_bars

interface ip_heatmap
   !< A 2D field f(i, j) as coloured cells: i along x, j along y, j = 1 at the bottom.
   module procedure ip_heatmap_r32, ip_heatmap_r64
endinterface ip_heatmap

interface ip_error_bars
   !< Vertical error bars at the points (x(i), y(i)): from y(i) - err(i) to y(i) + err(i), or to y(i) + err_high(i).
   module procedure ip_error_bars_r32, ip_error_bars_r64
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
endinterface ip_shaded

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

   visible = .false.
   if (figure_draw_refused('ip_begin_plot')) return ! a task does not draw
   extent = im_vec2(-1.0_c_float, 0.0_c_float)
   if (present(width)) extent%x = real(width, c_float)
   if (present(height)) extent%y = real(height, c_float)
   flags = ImPlotFlags_None
   if (present(equal)) then
      if (equal) flags = ior(flags, ImPlotFlags_Equal)
   endif
   if (fits_pending > 0_int32) then                 ! a cell of a subplot figure drawn for the first time
      call ImPlot_SetNextAxisToFit(ImAxis_X1)      ! the axes a plot uses: fitting the unused ones (no data, an
      call ImPlot_SetNextAxisToFit(ImAxis_Y1)      ! empty range) computes inf - inf, an FPE under traps
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

   recursive subroutine ip_setup_axes(xlabel, ylabel, auto_fit, xlog, ylog, xformat, yformat, stat)
   !< Axis labels (call right after `ip_begin_plot`); with `auto_fit=.true.` both axes fit the data every frame (data
   !< that grows while the user watches), instead of once on first use. `xlog`/`ylog`: a base-10 logarithmic axis
   !< (values <= 0 are not shown on it). `xformat`/`yformat`: a C printf format of the tick labels (`'%.6f'`,
   !< `'%.2e'`, `'%g s'`), for values whose default labels look alike (-3781.31, -3781.31, ...), checked: one
   !< conversion `f`, `e`, `g` or `a`, with optional flags, width and precision, and any `%%`. Statuses:
   !< `FIG_ERR_ARGUMENT` for any other format (nothing is set up), `FIG_ERR_STATE` from a task; `stat` absent:
   !< `error stop` with the message.
   character(len=*), intent(in)            :: xlabel   !< X label.
   character(len=*), intent(in)            :: ylabel   !< Y label.
   logical,          intent(in),  optional :: auto_fit !< Fit the axes to the data every frame (default: first use only).
   logical,          intent(in),  optional :: xlog     !< Logarithmic x axis (default: linear).
   logical,          intent(in),  optional :: ylog     !< Logarithmic y axis (default: linear).
   character(len=*), intent(in),  optional :: xformat  !< printf format of the x tick labels (one real).
   character(len=*), intent(in),  optional :: yformat  !< printf format of the y tick labels (one real).
   integer(int32),   intent(out), optional :: stat     !< Status.
   integer(c_int)                          :: flags    !< ImPlotAxisFlags of both axes.

   if (figure_draw_refused('ip_setup_axes', stat)) return ! a task does not draw
   if (present(xformat)) then
      if (format_refused('ip_setup_axes', 'xformat', xformat, FORMAT_REAL, stat)) return
   endif
   if (present(yformat)) then
      if (format_refused('ip_setup_axes', 'yformat', yformat, FORMAT_REAL, stat)) return
   endif
   flags = ImPlotAxisFlags_None
   if (present(auto_fit)) then
      if (auto_fit) flags = ImPlotAxisFlags_AutoFit
   endif
   call ImPlot_SetupAxes(cstr(xlabel), cstr(ylabel), flags, flags)
   if (present(xlog)) then
      if (xlog) call ImPlot_SetupAxisScale_PlotScale(ImAxis_X1, ImPlotScale_Log10)
   endif
   if (present(ylog)) then
      if (ylog) call ImPlot_SetupAxisScale_PlotScale(ImAxis_Y1, ImPlotScale_Log10)
   endif
   if (present(xformat)) call ImPlot_SetupAxisFormat_Str(ImAxis_X1, cstr(xformat))
   if (present(yformat)) call ImPlot_SetupAxisFormat_Str(ImAxis_Y1, cstr(yformat))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_setup_axes

   recursive subroutine ip_setup_axes_limits(xmin, xmax, ymin, ymax, always)
   !< Initial axis ranges (call right after `ip_begin_plot`): applied on first use only, so the user can pan and zoom
   !< afterwards, or every frame with `always=.true.`.
   real(real64), intent(in)           :: xmin   !< Left end of the x axis.
   real(real64), intent(in)           :: xmax   !< Right end of the x axis.
   real(real64), intent(in)           :: ymin   !< Bottom end of the y axis.
   real(real64), intent(in)           :: ymax   !< Top end of the y axis.
   logical,      intent(in), optional :: always !< Enforce every frame (default: first use only).
   integer(c_int)                     :: cond   !< ImPlotCond.

   if (figure_draw_refused('ip_setup_axes_limits')) return ! a task does not draw
   cond = ImPlotCond_Once
   if (present(always)) then
      if (always) cond = ImPlotCond_Always
   endif
   call ImPlot_SetupAxesLimits(real(xmin, c_double), real(xmax, c_double), real(ymin, c_double), real(ymax, c_double), &
                               cond)
   endsubroutine ip_setup_axes_limits

   recursive subroutine ip_plot_limits(xmin, xmax, ymin, ymax)
   !< Axis ranges of the current plot, as the user has panned and zoomed them (between `ip_begin_plot` and
   !< `ip_end_plot`; ends the setup phase: call `ip_setup_axes*` before).
   real(real64), intent(out) :: xmin   !< Left end of the x axis.
   real(real64), intent(out) :: xmax   !< Right end of the x axis.
   real(real64), intent(out) :: ymin   !< Bottom end of the y axis.
   real(real64), intent(out) :: ymax   !< Top end of the y axis.
   type(im_plot_rect)        :: limits !< Limits.

   xmin = 0.0_real64
   xmax = 0.0_real64
   ymin = 0.0_real64
   ymax = 0.0_real64
   if (figure_draw_refused('ip_plot_limits')) return ! a task does not draw
   call ImPlot_GetPlotLimits(-1_c_int, -1_c_int, limits) ! IMPLOT_AUTO: the current axes
   xmin = real(limits%X%Min, real64)
   xmax = real(limits%X%Max, real64)
   ymin = real(limits%Y%Min, real64)
   ymax = real(limits%Y%Max, real64)
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
   !< Line through the points (x(i), y(i)), single precision.
   character(len=*),       intent(in)                     :: label !< Legend label.
   real(real32),           intent(in), contiguous, target :: x(:)  !< Abscissae.
   real(real32),           intent(in), contiguous, target :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional           :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat  !< Status.

   if (figure_draw_refused('ip_line', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_line', stat)) return
   call ImPlot_PlotLine_FloatPtrFloatPtr(cstr(label), addr_r32(x), addr_r32(y), int(size(x), c_int), spec_c(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_line_r32

   recursive subroutine ip_scatter_r32(label, x, y, spec, stat)
   !< Markers at the points (x(i), y(i)), single precision.
   character(len=*),       intent(in)                     :: label !< Legend label.
   real(real32),           intent(in), contiguous, target :: x(:)  !< Abscissae.
   real(real32),           intent(in), contiguous, target :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional           :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat  !< Status.

   if (figure_draw_refused('ip_scatter', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_scatter', stat)) return
   call ImPlot_PlotScatter_FloatPtrFloatPtr(cstr(label), addr_r32(x), addr_r32(y), int(size(x), c_int), spec_c(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_scatter_r32

   recursive subroutine ip_bars_r32(label, x, y, bar_size, spec, stat)
   !< Bars of height y(i) centred at x(i), `bar_size` wide (in x units), single precision.
   character(len=*),       intent(in)                     :: label    !< Legend label.
   real(real32),           intent(in), contiguous, target :: x(:)     !< Bar positions.
   real(real32),           intent(in), contiguous, target :: y(:)     !< Bar heights.
   real(real64),           intent(in)                     :: bar_size !< Bar width [x units].
   type(plot_spec_object), intent(in), optional           :: spec     !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat     !< Status.

   if (figure_draw_refused('ip_bars', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_bars', stat)) return
   call ImPlot_PlotBars_FloatPtrFloatPtr(cstr(label), addr_r32(x), addr_r32(y), int(size(x), c_int), &
                                         real(bar_size, c_double), spec_c(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_bars_r32

   recursive subroutine ip_shaded_r32(label, x, y1, y2, spec, stat)
   !< Area between the curves y1(x) and y2(x), single precision.
   character(len=*),       intent(in)                     :: label !< Legend label.
   real(real32),           intent(in), contiguous, target :: x(:)  !< Abscissae.
   real(real32),           intent(in), contiguous, target :: y1(:) !< First curve.
   real(real32),           intent(in), contiguous, target :: y2(:) !< Second curve.
   type(plot_spec_object), intent(in), optional           :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat  !< Status.

   if (figure_draw_refused('ip_shaded', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y1, kind=int64), 'ip_shaded', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y2, kind=int64), 'ip_shaded', stat)) return
   call ImPlot_PlotShaded_FloatPtrFloatPtrFloatPtr(cstr(label), addr_r32(x), addr_r32(y1), addr_r32(y2), &
                                                   int(size(x), c_int), spec_c(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_shaded_r32

   recursive subroutine ip_shaded_ref_r32(label, x, y, yref, spec, stat)
   !< Area between the curve y(x) and the line y = yref, single precision.
   character(len=*),       intent(in)                     :: label !< Legend label.
   real(real32),           intent(in), contiguous, target :: x(:)  !< Abscissae.
   real(real32),           intent(in), contiguous, target :: y(:)  !< Curve.
   real(real64),           intent(in)                     :: yref  !< Reference line (-huge/+huge: to the plot edge).
   type(plot_spec_object), intent(in), optional           :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat  !< Status.

   if (figure_draw_refused('ip_shaded', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_shaded', stat)) return
   call ImPlot_PlotShaded_FloatPtrFloatPtrInt(cstr(label), addr_r32(x), addr_r32(y), int(size(x), c_int), &
                                              real(yref, c_double), spec_c(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_shaded_ref_r32

   recursive subroutine ip_line_values_r32(label, y, xscale, xstart, spec, stat)
   !< Line through y(i) at x = xstart + (i - 1) xscale, single precision.
   character(len=*),       intent(in)                     :: label  !< Legend label.
   real(real32),           intent(in), contiguous, target :: y(:)   !< Ordinates.
   real(real64),           intent(in), optional           :: xscale !< Spacing of the abscissae (default 1).
   real(real64),           intent(in), optional           :: xstart !< First abscissa (default 0).
   type(plot_spec_object), intent(in), optional           :: spec   !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat   !< Status.

   if (figure_draw_refused('ip_line', stat)) return ! a task does not draw
   if (.not. series_ok(size(y, kind=int64), size(y, kind=int64), 'ip_line', stat)) return
   call ImPlot_PlotLine_FloatPtrInt(cstr(label), addr_r32(y), int(size(y), c_int), uniform(xscale, 1.0_real64), &
                                    uniform(xstart, 0.0_real64), spec_c(spec))
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

   ! items, double precision

   recursive subroutine ip_line_r64(label, x, y, spec, stat)
   !< Line through the points (x(i), y(i)), double precision.
   character(len=*),       intent(in)                     :: label !< Legend label.
   real(real64),           intent(in), contiguous, target :: x(:)  !< Abscissae.
   real(real64),           intent(in), contiguous, target :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional           :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat  !< Status.

   if (figure_draw_refused('ip_line', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_line', stat)) return
   call ImPlot_PlotLine_doublePtrdoublePtr(cstr(label), addr_r64(x), addr_r64(y), int(size(x), c_int), spec_c(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_line_r64

   recursive subroutine ip_scatter_r64(label, x, y, spec, stat)
   !< Markers at the points (x(i), y(i)), double precision.
   character(len=*),       intent(in)                     :: label !< Legend label.
   real(real64),           intent(in), contiguous, target :: x(:)  !< Abscissae.
   real(real64),           intent(in), contiguous, target :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional           :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat  !< Status.

   if (figure_draw_refused('ip_scatter', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_scatter', stat)) return
   call ImPlot_PlotScatter_doublePtrdoublePtr(cstr(label), addr_r64(x), addr_r64(y), int(size(x), c_int), &
                                              spec_c(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_scatter_r64

   recursive subroutine ip_bars_r64(label, x, y, bar_size, spec, stat)
   !< Bars of height y(i) centred at x(i), `bar_size` wide (in x units), double precision.
   character(len=*),       intent(in)                     :: label    !< Legend label.
   real(real64),           intent(in), contiguous, target :: x(:)     !< Bar positions.
   real(real64),           intent(in), contiguous, target :: y(:)     !< Bar heights.
   real(real64),           intent(in)                     :: bar_size !< Bar width [x units].
   type(plot_spec_object), intent(in), optional           :: spec     !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat     !< Status.

   if (figure_draw_refused('ip_bars', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_bars', stat)) return
   call ImPlot_PlotBars_doublePtrdoublePtr(cstr(label), addr_r64(x), addr_r64(y), int(size(x), c_int), &
                                           real(bar_size, c_double), spec_c(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_bars_r64

   recursive subroutine ip_shaded_r64(label, x, y1, y2, spec, stat)
   !< Area between the curves y1(x) and y2(x), double precision.
   character(len=*),       intent(in)                     :: label !< Legend label.
   real(real64),           intent(in), contiguous, target :: x(:)  !< Abscissae.
   real(real64),           intent(in), contiguous, target :: y1(:) !< First curve.
   real(real64),           intent(in), contiguous, target :: y2(:) !< Second curve.
   type(plot_spec_object), intent(in), optional           :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat  !< Status.

   if (figure_draw_refused('ip_shaded', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y1, kind=int64), 'ip_shaded', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y2, kind=int64), 'ip_shaded', stat)) return
   call ImPlot_PlotShaded_doublePtrdoublePtrdoublePtr(cstr(label), addr_r64(x), addr_r64(y1), addr_r64(y2), &
                                                      int(size(x), c_int), spec_c(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_shaded_r64

   recursive subroutine ip_shaded_ref_r64(label, x, y, yref, spec, stat)
   !< Area between the curve y(x) and the line y = yref, double precision.
   character(len=*),       intent(in)                     :: label !< Legend label.
   real(real64),           intent(in), contiguous, target :: x(:)  !< Abscissae.
   real(real64),           intent(in), contiguous, target :: y(:)  !< Curve.
   real(real64),           intent(in)                     :: yref  !< Reference line (-huge/+huge: to the plot edge).
   type(plot_spec_object), intent(in), optional           :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat  !< Status.

   if (figure_draw_refused('ip_shaded', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_shaded', stat)) return
   call ImPlot_PlotShaded_doublePtrdoublePtrInt(cstr(label), addr_r64(x), addr_r64(y), int(size(x), c_int), &
                                                real(yref, c_double), spec_c(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_shaded_ref_r64

   recursive subroutine ip_line_values_r64(label, y, xscale, xstart, spec, stat)
   !< Line through y(i) at x = xstart + (i - 1) xscale, double precision.
   character(len=*),       intent(in)                     :: label  !< Legend label.
   real(real64),           intent(in), contiguous, target :: y(:)   !< Ordinates.
   real(real64),           intent(in), optional           :: xscale !< Spacing of the abscissae (default 1).
   real(real64),           intent(in), optional           :: xstart !< First abscissa (default 0).
   type(plot_spec_object), intent(in), optional           :: spec   !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat   !< Status.

   if (figure_draw_refused('ip_line', stat)) return ! a task does not draw
   if (.not. series_ok(size(y, kind=int64), size(y, kind=int64), 'ip_line', stat)) return
   call ImPlot_PlotLine_doublePtrInt(cstr(label), addr_r64(y), int(size(y), c_int), uniform(xscale, 1.0_real64), &
                                     uniform(xstart, 0.0_real64), spec_c(spec))
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
                                           stat)
   !< A colour-scale legend: a bar coloured by `colormap` from `vmin` to `vmax` (bottom to top, or left to right with
   !< `horizontal=.true.`), with ticks and their values on its right (or below). An item of the current window, outside
   !< a plot: beside any plot (`ig_same_line`), above or below it, or in any window. With `levels`: that many bands of
   !< equal width, each the map's colour at its centre (as `ip_colormap(name, levels)` colours a field), the ticks at the
   !< bands' edges, labelled with the digits they need to show the edge (`label_format`'s precision raised, up to 6
   !< decimals for `%f` or 7 significant digits for `%e` and `%g`: 87.5 with `'%.0f'`, as `ip_contour` labels it);
   !< without: a continuous bar, ticks at round values (a step of 1, 2, 2.5 or 5 times a power of ten) about every 40
   !< pixels (100 horizontal), labelled with `label_format` as it is. `vmin > vmax` turns the scale over. Sizes
   !< [pixels]: positive given, negative the space left in the window, absent the default (vertical: 300 long, as wide
   !< as the bar and the labels; horizontal: the space left, as tall as the bar and a line of labels). Statuses:
   !< `FIG_ERR_ARGUMENT` for a colormap that is not registered, equal or non-finite `vmin`/`vmax`, `levels` outside
   !< [2, 256], a `label_format` with a conversion that is not one of a real (a format without conversion is text,
   !< printed as it is; `''` is the default); `FIG_ERR_STATE` outside a window and from a task. The same in every mode.
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
   integer(int32),   intent(out), optional :: stat         !< Status.
   integer(c_int)                          :: n            !< Bands.
   integer(c_int)                          :: h            !< Horizontal flag.

   if (figure_draw_refused('ip_colormap_legend', stat)) return ! a task does not draw
   if (present(label_format)) then
      ! as documented since v0.3.0: '' is the default format, a text without conversion is printed as it is
      if (format_refused('ip_colormap_legend', 'label_format', label_format, FORMAT_REAL, stat, text=.true.)) return
   endif
   n = 0_c_int
   if (present(levels)) then
      if (levels < 2_int32 .or. levels > 256_int32) then
         call figure_fail(FIG_ERR_ARGUMENT, 'ip_colormap_legend: levels must be in [2, 256]', stat)
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
                                            len(label_format, c_int)), stat)
   else
      call figure_check(fig_colormap_legend(id, len(id, c_int), int(colormap, c_int), real(vmin, c_double),             &
                                            real(vmax, c_double), n, h, real(uniform(width, 0.0_real64), c_float),      &
                                            real(uniform(height, 0.0_real64), c_float), '', 0_c_int), stat)
   endif
   endsubroutine ip_colormap_legend

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

   ! error bars

   recursive subroutine ip_error_bars_r32(label, x, y, err, err_high, spec, stat)
   !< Vertical error bars at the points (x(i), y(i)), from y(i) - err(i) to y(i) + err(i); with `err_high`, to
   !< y(i) + err_high(i) (asymmetric). Read in place. Single precision.
   character(len=*),       intent(in)                               :: label       !< Legend label.
   real(real32),           intent(in), contiguous, target           :: x(:)        !< Abscissae.
   real(real32),           intent(in), contiguous, target           :: y(:)        !< Ordinates.
   real(real32),           intent(in), contiguous, target           :: err(:)      !< Error below (and above) [y units].
   real(real32),           intent(in), contiguous, target, optional :: err_high(:) !< Error above [y units].
   type(plot_spec_object), intent(in), optional                     :: spec        !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional                    :: stat        !< Status.

   if (figure_draw_refused('ip_error_bars', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_error_bars', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(err, kind=int64), 'ip_error_bars', stat)) return
   if (present(err_high)) then
      if (.not. series_ok(size(x, kind=int64), size(err_high, kind=int64), 'ip_error_bars', stat)) return
      call ImPlot_PlotErrorBars_FloatPtrFloatPtrFloatPtrFloatPtr(cstr(label), addr_r32(x), addr_r32(y), addr_r32(err), &
                                                                 addr_r32(err_high), int(size(x), c_int), spec_c(spec))
   else
      call ImPlot_PlotErrorBars_FloatPtrFloatPtrFloatPtrInt(cstr(label), addr_r32(x), addr_r32(y), addr_r32(err), &
                                                            int(size(x), c_int), spec_c(spec))
   endif
   call figure_check(FIG_OK, stat)
   endsubroutine ip_error_bars_r32

   recursive subroutine ip_error_bars_r64(label, x, y, err, err_high, spec, stat)
   !< Vertical error bars at the points (x(i), y(i)), from y(i) - err(i) to y(i) + err(i); with `err_high`, to
   !< y(i) + err_high(i) (asymmetric). Read in place. Double precision.
   character(len=*),       intent(in)                               :: label       !< Legend label.
   real(real64),           intent(in), contiguous, target           :: x(:)        !< Abscissae.
   real(real64),           intent(in), contiguous, target           :: y(:)        !< Ordinates.
   real(real64),           intent(in), contiguous, target           :: err(:)      !< Error below (and above) [y units].
   real(real64),           intent(in), contiguous, target, optional :: err_high(:) !< Error above [y units].
   type(plot_spec_object), intent(in), optional                     :: spec        !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional                    :: stat        !< Status.

   if (figure_draw_refused('ip_error_bars', stat)) return ! a task does not draw
   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_error_bars', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(err, kind=int64), 'ip_error_bars', stat)) return
   if (present(err_high)) then
      if (.not. series_ok(size(x, kind=int64), size(err_high, kind=int64), 'ip_error_bars', stat)) return
      call ImPlot_PlotErrorBars_doublePtrdoublePtrdoublePtrdoublePtr(cstr(label), addr_r64(x), addr_r64(y),          &
                                                                     addr_r64(err), addr_r64(err_high),              &
                                                                     int(size(x), c_int), spec_c(spec))
   else
      call ImPlot_PlotErrorBars_doublePtrdoublePtrdoublePtrInt(cstr(label), addr_r64(x), addr_r64(y), addr_r64(err), &
                                                               int(size(x), c_int), spec_c(spec))
   endif
   call figure_check(FIG_OK, stat)
   endsubroutine ip_error_bars_r64

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
   !< `FIG_ERR_STATE` from a task.
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
   moved = logical(ImPlot_DragPoint(int(id, c_int), c_loc(x), c_loc(y), drag_color(color),                         &
                                    real(uniform(radius, 4.0_real64), c_float), 0_c_int, c_null_ptr, c_null_ptr, c_null_ptr))
   call figure_check(FIG_OK, stat)
   endfunction ip_drag_point

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

   function addr_r32(a) result(p)
   !< Address of a contiguous array for ImPlot; null when empty: `c_loc` needs nonzero size (F2023 18.2.3.7).
   !<
   !< The address stays valid in the caller after the return: `a` is a TARGET dummy whose effective argument (the
   !< caller's CONTIGUOUS, TARGET dummy) is simply contiguous, so the association persists (F2023 15.5.2.5 p9).
   real(real32), intent(in), contiguous, target :: a(:) !< Data.
   type(c_ptr)                                  :: p    !< Address of a(1), or c_null_ptr.

   p = c_null_ptr
   if (size(a) > 0) p = c_loc(a)
   endfunction addr_r32

   function addr_r64(a) result(p)
   !< Address of a contiguous array for ImPlot; null when empty: `c_loc` needs nonzero size (F2023 18.2.3.7).
   !<
   !< The address stays valid in the caller after the return: `a` is a TARGET dummy whose effective argument (the
   !< caller's CONTIGUOUS, TARGET dummy) is simply contiguous, so the association persists (F2023 15.5.2.5 p9).
   real(real64), intent(in), contiguous, target :: a(:) !< Data.
   type(c_ptr)                                  :: p    !< Address of a(1), or c_null_ptr.

   p = c_null_ptr
   if (size(a) > 0) p = c_loc(a)
   endfunction addr_r64

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
