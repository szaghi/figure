!< figure_implot, ImPlot plots with Fortran arrays.
module figure_implot
!< figure_implot, ImPlot plots with Fortran arrays.
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
use figure_base, only : cstr, figure_check, figure_fail
use figure_c_native, only : FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_OK, fig_texture_sampling
use figure_cimgui, only : im_vec2, im_vec4
use figure_texture, only : texture_object, texture_ref
use figure_cimplot, only : figure_ImPlotSpec_default, im_plot_spec, ImPlot_BeginPlot, ImPlot_EndPlot,             &
                           ImPlot_PlotBars_doublePtrdoublePtr, ImPlot_PlotBars_FloatPtrFloatPtr,                   &
                           ImPlot_PlotLine_doublePtrdoublePtr, ImPlot_PlotLine_FloatPtrFloatPtr,                   &
                           ImPlot_PlotLine_doublePtrInt, ImPlot_PlotLine_FloatPtrInt,                               &
                           ImPlot_PlotScatter_doublePtrdoublePtr, ImPlot_PlotScatter_FloatPtrFloatPtr,             &
                           ImPlot_PlotShaded_doublePtrdoublePtrdoublePtr, ImPlot_PlotShaded_doublePtrdoublePtrInt, &
                           ImPlot_PlotShaded_FloatPtrFloatPtrFloatPtr, ImPlot_PlotShaded_FloatPtrFloatPtrInt,      &
                           ImPlot_SetupAxes, ImPlot_ColormapScale, ImPlot_PlotHeatmap_doublePtr,                   &
                           ImPlot_PlotHeatmap_FloatPtr, ImPlot_PlotImage, ImPlot_PopColormap,                       &
                           ImPlot_PushColormap_PlotColormap, im_plot_point, im_plot_rect, ImPlot_GetPlotLimits,     &
                           ImPlot_GetPlotSize, ImPlot_SetupAxesLimits
use figure_cimplot_enums, only : ImPlotAxisFlags_AutoFit, ImPlotAxisFlags_None, ImPlotCond_Always, ImPlotCond_Once,     &
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
public :: ip_begin_plot, ip_end_plot, ip_setup_axes
public :: ip_bars, ip_line, ip_scatter, ip_shaded
public :: ip_colormap_scale, ip_heatmap, ip_image, ip_plot_limits, ip_plot_size, ip_setup_axes_limits
public :: ip_spec, plot_spec_object
! ImPlot's marker and item-flag constants (values generated from the cimplot metadata), for `ip_spec`
public :: ImPlotMarker_None, ImPlotMarker_Auto, ImPlotMarker_Circle, ImPlotMarker_Square, ImPlotMarker_Diamond
public :: ImPlotMarker_Up, ImPlotMarker_Down, ImPlotMarker_Left, ImPlotMarker_Right, ImPlotMarker_Cross
public :: ImPlotMarker_Plus, ImPlotMarker_Asterisk, ImPlotMarker_Vertical, ImPlotMarker_Horizontal
public :: ImPlotItemFlags_None, ImPlotItemFlags_NoLegend, ImPlotItemFlags_NoFit
public :: ImPlotLineFlags_Segments, ImPlotLineFlags_Loop, ImPlotLineFlags_SkipNaN, ImPlotLineFlags_NoClip
public :: ImPlotLineFlags_Shaded, ImPlotScatterFlags_NoClip, ImPlotBarsFlags_Horizontal
! ImPlot's colormaps, for `ip_heatmap` and `ip_colormap_scale`
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

interface ip_shaded
   !< Area between two curves y1(x) and y2(x), or between a curve y(x) and the line y = yref.
   module procedure ip_shaded_r32, ip_shaded_r64, ip_shaded_ref_r32, ip_shaded_ref_r64
endinterface ip_shaded

contains
   ! plots

   function ip_begin_plot(title, width, height, equal) result(visible)
   !< Begin a plot; if true, declare its content and call `ip_end_plot`.
   character(len=*), intent(in)           :: title   !< Title (also the plot id; '##id' hides it).
   real(real64),     intent(in), optional :: width   !< Width [pixels] (default: full width).
   real(real64),     intent(in), optional :: height  !< Height [pixels] (default: ImPlot's).
   logical,          intent(in), optional :: equal   !< Same scale on both axes (one unit = as many pixels on x and y).
   logical                                :: visible !< Plot visible.
   type(im_vec2)                          :: extent  !< Size (named so: a local `size` crashes nvfortran 26.9).
   integer(c_int)                         :: flags   !< ImPlotFlags.

   extent = im_vec2(-1.0_c_float, 0.0_c_float)
   if (present(width)) extent%x = real(width, c_float)
   if (present(height)) extent%y = real(height, c_float)
   flags = ImPlotFlags_None
   if (present(equal)) then
      if (equal) flags = ior(flags, ImPlotFlags_Equal)
   endif
   visible = logical(ImPlot_BeginPlot(cstr(title), extent, flags))
   endfunction ip_begin_plot

   subroutine ip_end_plot()
   !< End the plot (only after `ip_begin_plot` returned true).
   call ImPlot_EndPlot()
   endsubroutine ip_end_plot

   subroutine ip_setup_axes(xlabel, ylabel, auto_fit)
   !< Axis labels (call right after `ip_begin_plot`); with `auto_fit=.true.` both axes fit the data every frame (data
   !< that grows while the user watches), instead of once on first use.
   character(len=*), intent(in)           :: xlabel   !< X label.
   character(len=*), intent(in)           :: ylabel   !< Y label.
   logical,          intent(in), optional :: auto_fit !< Fit the axes to the data every frame (default: first use only).
   integer(c_int)                         :: flags    !< ImPlotAxisFlags of both axes.

   flags = ImPlotAxisFlags_None
   if (present(auto_fit)) then
      if (auto_fit) flags = ImPlotAxisFlags_AutoFit
   endif
   call ImPlot_SetupAxes(cstr(xlabel), cstr(ylabel), flags, flags)
   endsubroutine ip_setup_axes

   subroutine ip_setup_axes_limits(xmin, xmax, ymin, ymax, always)
   !< Initial axis ranges (call right after `ip_begin_plot`): applied on first use only, so the user can pan and zoom
   !< afterwards, or every frame with `always=.true.`.
   real(real64), intent(in)           :: xmin   !< Left end of the x axis.
   real(real64), intent(in)           :: xmax   !< Right end of the x axis.
   real(real64), intent(in)           :: ymin   !< Bottom end of the y axis.
   real(real64), intent(in)           :: ymax   !< Top end of the y axis.
   logical,      intent(in), optional :: always !< Enforce every frame (default: first use only).
   integer(c_int)                     :: cond   !< ImPlotCond.

   cond = ImPlotCond_Once
   if (present(always)) then
      if (always) cond = ImPlotCond_Always
   endif
   call ImPlot_SetupAxesLimits(real(xmin, c_double), real(xmax, c_double), real(ymin, c_double), real(ymax, c_double), &
                               cond)
   endsubroutine ip_setup_axes_limits

   subroutine ip_plot_limits(xmin, xmax, ymin, ymax)
   !< Axis ranges of the current plot, as the user has panned and zoomed them (between `ip_begin_plot` and
   !< `ip_end_plot`; ends the setup phase: call `ip_setup_axes*` before).
   real(real64), intent(out) :: xmin   !< Left end of the x axis.
   real(real64), intent(out) :: xmax   !< Right end of the x axis.
   real(real64), intent(out) :: ymin   !< Bottom end of the y axis.
   real(real64), intent(out) :: ymax   !< Top end of the y axis.
   type(im_plot_rect)        :: limits !< Limits.

   call ImPlot_GetPlotLimits(-1_c_int, -1_c_int, limits) ! IMPLOT_AUTO: the current axes
   xmin = real(limits%X%Min, real64)
   xmax = real(limits%X%Max, real64)
   ymin = real(limits%Y%Min, real64)
   ymax = real(limits%Y%Max, real64)
   endsubroutine ip_plot_limits

   subroutine ip_plot_size(width, height)
   !< Size of the current plot's data area [pixels] (between `ip_begin_plot` and `ip_end_plot`).
   real(real64), intent(out) :: width  !< Width [pixels].
   real(real64), intent(out) :: height !< Height [pixels].
   type(im_vec2)             :: extent !< Size.

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

   subroutine ip_line_r32(label, x, y, spec, stat)
   !< Line through the points (x(i), y(i)), single precision.
   character(len=*),       intent(in)                     :: label !< Legend label.
   real(real32),           intent(in), contiguous, target :: x(:)  !< Abscissae.
   real(real32),           intent(in), contiguous, target :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional           :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat  !< Status.

   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_line', stat)) return
   call ImPlot_PlotLine_FloatPtrFloatPtr(cstr(label), addr_r32(x), addr_r32(y), int(size(x), c_int), spec_c(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_line_r32

   subroutine ip_scatter_r32(label, x, y, spec, stat)
   !< Markers at the points (x(i), y(i)), single precision.
   character(len=*),       intent(in)                     :: label !< Legend label.
   real(real32),           intent(in), contiguous, target :: x(:)  !< Abscissae.
   real(real32),           intent(in), contiguous, target :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional           :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat  !< Status.

   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_scatter', stat)) return
   call ImPlot_PlotScatter_FloatPtrFloatPtr(cstr(label), addr_r32(x), addr_r32(y), int(size(x), c_int), spec_c(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_scatter_r32

   subroutine ip_bars_r32(label, x, y, bar_size, spec, stat)
   !< Bars of height y(i) centred at x(i), `bar_size` wide (in x units), single precision.
   character(len=*),       intent(in)                     :: label    !< Legend label.
   real(real32),           intent(in), contiguous, target :: x(:)     !< Bar positions.
   real(real32),           intent(in), contiguous, target :: y(:)     !< Bar heights.
   real(real64),           intent(in)                     :: bar_size !< Bar width [x units].
   type(plot_spec_object), intent(in), optional           :: spec     !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat     !< Status.

   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_bars', stat)) return
   call ImPlot_PlotBars_FloatPtrFloatPtr(cstr(label), addr_r32(x), addr_r32(y), int(size(x), c_int), &
                                         real(bar_size, c_double), spec_c(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_bars_r32

   subroutine ip_shaded_r32(label, x, y1, y2, spec, stat)
   !< Area between the curves y1(x) and y2(x), single precision.
   character(len=*),       intent(in)                     :: label !< Legend label.
   real(real32),           intent(in), contiguous, target :: x(:)  !< Abscissae.
   real(real32),           intent(in), contiguous, target :: y1(:) !< First curve.
   real(real32),           intent(in), contiguous, target :: y2(:) !< Second curve.
   type(plot_spec_object), intent(in), optional           :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat  !< Status.

   if (.not. series_ok(size(x, kind=int64), size(y1, kind=int64), 'ip_shaded', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y2, kind=int64), 'ip_shaded', stat)) return
   call ImPlot_PlotShaded_FloatPtrFloatPtrFloatPtr(cstr(label), addr_r32(x), addr_r32(y1), addr_r32(y2), &
                                                   int(size(x), c_int), spec_c(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_shaded_r32

   subroutine ip_shaded_ref_r32(label, x, y, yref, spec, stat)
   !< Area between the curve y(x) and the line y = yref, single precision.
   character(len=*),       intent(in)                     :: label !< Legend label.
   real(real32),           intent(in), contiguous, target :: x(:)  !< Abscissae.
   real(real32),           intent(in), contiguous, target :: y(:)  !< Curve.
   real(real64),           intent(in)                     :: yref  !< Reference line (-huge/+huge: to the plot edge).
   type(plot_spec_object), intent(in), optional           :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat  !< Status.

   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_shaded', stat)) return
   call ImPlot_PlotShaded_FloatPtrFloatPtrInt(cstr(label), addr_r32(x), addr_r32(y), int(size(x), c_int), &
                                              real(yref, c_double), spec_c(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_shaded_ref_r32

   subroutine ip_line_values_r32(label, y, xscale, xstart, spec, stat)
   !< Line through y(i) at x = xstart + (i - 1) xscale, single precision.
   character(len=*),       intent(in)                     :: label  !< Legend label.
   real(real32),           intent(in), contiguous, target :: y(:)   !< Ordinates.
   real(real64),           intent(in), optional           :: xscale !< Spacing of the abscissae (default 1).
   real(real64),           intent(in), optional           :: xstart !< First abscissa (default 0).
   type(plot_spec_object), intent(in), optional           :: spec   !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat   !< Status.

   if (.not. series_ok(size(y, kind=int64), size(y, kind=int64), 'ip_line', stat)) return
   call ImPlot_PlotLine_FloatPtrInt(cstr(label), addr_r32(y), int(size(y), c_int), uniform(xscale, 1.0_real64), &
                                    uniform(xstart, 0.0_real64), spec_c(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_line_values_r32

   subroutine ip_line_row_r32(label, y, row, xscale, xstart, spec, stat)
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

   subroutine ip_heatmap_r32(label, f, xmin, xmax, ymin, ymax, scale_min, scale_max, label_format, colormap, spec, &
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
   character(len=*),       intent(in), optional           :: label_format !< printf format printing each value in its cell.
   integer(int32),         intent(in), optional           :: colormap     !< Colormap (`ImPlotColormap_*`; default: current).
   type(plot_spec_object), intent(in), optional           :: spec         !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat         !< Status.
   real(c_double)                                         :: smin         !< Colormap bottom (0, 0: data range).
   real(c_double)                                         :: smax         !< Colormap top.
   character(kind=c_char, len=:), allocatable, target     :: fmt          !< NUL-terminated label format.
   type(c_ptr)                                            :: pfmt         !< Label format, or null: no labels.
   type(c_ptr)                                            :: p            !< Field address, or null when empty.

   if (.not. field_ok(size(f, 1, kind=int64), size(f, 2, kind=int64), present(scale_min), present(scale_max), stat)) return
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
   if (present(colormap)) call ImPlot_PushColormap_PlotColormap(int(colormap, c_int))
   ! rows = size(f, 2) along y, cols = size(f, 1) along x: ImPlot's row-major cell (r, c) is f(c + 1, r + 1). ImPlot
   ! draws row 0 at bounds_max%y: the y bounds are swapped so that it lands at ymin.
   call ImPlot_PlotHeatmap_FloatPtr(cstr(label), p, int(size(f, 2), c_int), int(size(f, 1), c_int), smin, smax, pfmt, &
                                    im_plot_point(xmin, ymax), im_plot_point(xmax, ymin), spec_c(spec))
   if (present(colormap)) call ImPlot_PopColormap(1_c_int)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_heatmap_r32

   ! items, double precision

   subroutine ip_line_r64(label, x, y, spec, stat)
   !< Line through the points (x(i), y(i)), double precision.
   character(len=*),       intent(in)                     :: label !< Legend label.
   real(real64),           intent(in), contiguous, target :: x(:)  !< Abscissae.
   real(real64),           intent(in), contiguous, target :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional           :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat  !< Status.

   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_line', stat)) return
   call ImPlot_PlotLine_doublePtrdoublePtr(cstr(label), addr_r64(x), addr_r64(y), int(size(x), c_int), spec_c(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_line_r64

   subroutine ip_scatter_r64(label, x, y, spec, stat)
   !< Markers at the points (x(i), y(i)), double precision.
   character(len=*),       intent(in)                     :: label !< Legend label.
   real(real64),           intent(in), contiguous, target :: x(:)  !< Abscissae.
   real(real64),           intent(in), contiguous, target :: y(:)  !< Ordinates.
   type(plot_spec_object), intent(in), optional           :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat  !< Status.

   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_scatter', stat)) return
   call ImPlot_PlotScatter_doublePtrdoublePtr(cstr(label), addr_r64(x), addr_r64(y), int(size(x), c_int), &
                                              spec_c(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_scatter_r64

   subroutine ip_bars_r64(label, x, y, bar_size, spec, stat)
   !< Bars of height y(i) centred at x(i), `bar_size` wide (in x units), double precision.
   character(len=*),       intent(in)                     :: label    !< Legend label.
   real(real64),           intent(in), contiguous, target :: x(:)     !< Bar positions.
   real(real64),           intent(in), contiguous, target :: y(:)     !< Bar heights.
   real(real64),           intent(in)                     :: bar_size !< Bar width [x units].
   type(plot_spec_object), intent(in), optional           :: spec     !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat     !< Status.

   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_bars', stat)) return
   call ImPlot_PlotBars_doublePtrdoublePtr(cstr(label), addr_r64(x), addr_r64(y), int(size(x), c_int), &
                                           real(bar_size, c_double), spec_c(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_bars_r64

   subroutine ip_shaded_r64(label, x, y1, y2, spec, stat)
   !< Area between the curves y1(x) and y2(x), double precision.
   character(len=*),       intent(in)                     :: label !< Legend label.
   real(real64),           intent(in), contiguous, target :: x(:)  !< Abscissae.
   real(real64),           intent(in), contiguous, target :: y1(:) !< First curve.
   real(real64),           intent(in), contiguous, target :: y2(:) !< Second curve.
   type(plot_spec_object), intent(in), optional           :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat  !< Status.

   if (.not. series_ok(size(x, kind=int64), size(y1, kind=int64), 'ip_shaded', stat)) return
   if (.not. series_ok(size(x, kind=int64), size(y2, kind=int64), 'ip_shaded', stat)) return
   call ImPlot_PlotShaded_doublePtrdoublePtrdoublePtr(cstr(label), addr_r64(x), addr_r64(y1), addr_r64(y2), &
                                                      int(size(x), c_int), spec_c(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_shaded_r64

   subroutine ip_shaded_ref_r64(label, x, y, yref, spec, stat)
   !< Area between the curve y(x) and the line y = yref, double precision.
   character(len=*),       intent(in)                     :: label !< Legend label.
   real(real64),           intent(in), contiguous, target :: x(:)  !< Abscissae.
   real(real64),           intent(in), contiguous, target :: y(:)  !< Curve.
   real(real64),           intent(in)                     :: yref  !< Reference line (-huge/+huge: to the plot edge).
   type(plot_spec_object), intent(in), optional           :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat  !< Status.

   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_shaded', stat)) return
   call ImPlot_PlotShaded_doublePtrdoublePtrInt(cstr(label), addr_r64(x), addr_r64(y), int(size(x), c_int), &
                                                real(yref, c_double), spec_c(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_shaded_ref_r64

   subroutine ip_line_values_r64(label, y, xscale, xstart, spec, stat)
   !< Line through y(i) at x = xstart + (i - 1) xscale, double precision.
   character(len=*),       intent(in)                     :: label  !< Legend label.
   real(real64),           intent(in), contiguous, target :: y(:)   !< Ordinates.
   real(real64),           intent(in), optional           :: xscale !< Spacing of the abscissae (default 1).
   real(real64),           intent(in), optional           :: xstart !< First abscissa (default 0).
   type(plot_spec_object), intent(in), optional           :: spec   !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat   !< Status.

   if (.not. series_ok(size(y, kind=int64), size(y, kind=int64), 'ip_line', stat)) return
   call ImPlot_PlotLine_doublePtrInt(cstr(label), addr_r64(y), int(size(y), c_int), uniform(xscale, 1.0_real64), &
                                     uniform(xstart, 0.0_real64), spec_c(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip_line_values_r64

   subroutine ip_line_row_r64(label, y, row, xscale, xstart, spec, stat)
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

   subroutine ip_heatmap_r64(label, f, xmin, xmax, ymin, ymax, scale_min, scale_max, label_format, colormap, spec, &
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
   character(len=*),       intent(in), optional           :: label_format !< printf format printing each value in its cell.
   integer(int32),         intent(in), optional           :: colormap     !< Colormap (`ImPlotColormap_*`; default: current).
   type(plot_spec_object), intent(in), optional           :: spec         !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional          :: stat         !< Status.
   real(c_double)                                         :: smin         !< Colormap bottom (0, 0: data range).
   real(c_double)                                         :: smax         !< Colormap top.
   character(kind=c_char, len=:), allocatable, target     :: fmt          !< NUL-terminated label format.
   type(c_ptr)                                            :: pfmt         !< Label format, or null: no labels.
   type(c_ptr)                                            :: p            !< Field address, or null when empty.

   if (.not. field_ok(size(f, 1, kind=int64), size(f, 2, kind=int64), present(scale_min), present(scale_max), stat)) return
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
   if (present(colormap)) call ImPlot_PushColormap_PlotColormap(int(colormap, c_int))
   ! rows = size(f, 2) along y, cols = size(f, 1) along x: ImPlot's row-major cell (r, c) is f(c + 1, r + 1). ImPlot
   ! draws row 0 at bounds_max%y: the y bounds are swapped so that it lands at ymin.
   call ImPlot_PlotHeatmap_doublePtr(cstr(label), p, int(size(f, 2), c_int), int(size(f, 1), c_int), smin, smax, pfmt, &
                                     im_plot_point(xmin, ymax), im_plot_point(xmax, ymin), spec_c(spec))
   if (present(colormap)) call ImPlot_PopColormap(1_c_int)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_heatmap_r64

   ! images and colour scales

   subroutine ip_image(label, tex, xmin, xmax, ymin, ymax, spec, stat)
   !< A texture over [xmin, xmax] x [ymin, ymax], pixel row 1 at ymin (plot convention: y up).
   character(len=*),       intent(in)            :: label !< Legend label.
   type(texture_object),   intent(in)            :: tex   !< Texture.
   real(real64),           intent(in)            :: xmin  !< Left edge.
   real(real64),           intent(in)            :: xmax  !< Right edge.
   real(real64),           intent(in)            :: ymin  !< Bottom edge (pixel row 1).
   real(real64),           intent(in)            :: ymax  !< Top edge (last pixel row).
   type(plot_spec_object), intent(in), optional  :: spec  !< Style (default: ImPlot's).
   integer(int32),         intent(out), optional :: stat  !< Status.

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

   subroutine ip_colormap_scale(label, scale_min, scale_max, width, height, label_format, colormap)
   !< A colour bar for [scale_min, scale_max], next to a heatmap (outside `ip_begin_plot`/`ip_end_plot`).
   character(len=*), intent(in)           :: label        !< Label (also the widget id).
   real(real64),     intent(in)           :: scale_min    !< Value at the bottom.
   real(real64),     intent(in)           :: scale_max    !< Value at the top.
   real(real64),     intent(in), optional :: width        !< Width [pixels] (default: ImPlot's).
   real(real64),     intent(in), optional :: height       !< Height [pixels] (default: ImPlot's).
   character(len=*), intent(in), optional :: label_format !< printf format of the tick labels (default '%g', ImPlot's).
   integer(int32),   intent(in), optional :: colormap     !< Colormap (`ImPlotColormap_*`; default: current).
   type(im_vec2)                          :: extent       !< Size (0: ImPlot's default).
   integer(c_int)                         :: cmap         !< Colormap, or IMPLOT_AUTO (-1): the current one.

   extent = im_vec2(0.0_c_float, 0.0_c_float)
   if (present(width)) extent%x = real(width, c_float)
   if (present(height)) extent%y = real(height, c_float)
   cmap = -1_c_int
   if (present(colormap)) cmap = int(colormap, c_int)
   if (present(label_format)) then
      call ImPlot_ColormapScale(cstr(label), real(scale_min, c_double), real(scale_max, c_double), extent, &
                                cstr(label_format), 0_c_int, cmap)
   else
      call ImPlot_ColormapScale(cstr(label), real(scale_min, c_double), real(scale_max, c_double), extent, cstr('%g'), &
                                0_c_int, cmap)
   endif
   endsubroutine ip_colormap_scale

   ! private helpers

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
