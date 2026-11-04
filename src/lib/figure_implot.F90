!< figure_implot, ImPlot plots with Fortran arrays.
module figure_implot
!< figure_implot, ImPlot plots with Fortran arrays.
!<
!< `ip_begin_plot` returns true when the plot is visible: then declare its axes and items and close it with
!< `ip_end_plot` (only in that case). Items (`ip_line`, `ip_scatter`, `ip_bars`, `ip_shaded`) take `real(real32)` or
!< `real(real64)` arrays, read in place, without copies, during the call: they go straight to ImPlot's `float*` or
!< `double*` items (ImPlot is templated on the element type). A non-contiguous actual argument (e.g. a matrix row
!< `y(i,:)`) is copied by the compiler into a temporary.
!<
!< Every item takes an optional `spec`, built by `ip_spec` from ImPlot's defaults (automatic colours, no markers):
!<
!<```fortran
!< call ip_line('residual', it, res, spec=ip_spec(line_color=[1.0_real64, 0.0_real64, 0.0_real64, 1.0_real64], &
!<                                               line_weight=2.0_real64, marker=ImPlotMarker_Circle))
!<```
use, intrinsic :: iso_c_binding, only : c_double, c_float, c_int, c_loc, c_null_ptr, c_ptr
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use figure_base, only : cstr, figure_check, figure_fail
use figure_c_native, only : FIG_ERR_ARGUMENT, FIG_OK
use figure_cimgui, only : im_vec2, im_vec4
use figure_cimplot, only : figure_ImPlotSpec_default, im_plot_spec, ImPlot_BeginPlot, ImPlot_EndPlot,             &
                           ImPlot_PlotBars_doublePtrdoublePtr, ImPlot_PlotBars_FloatPtrFloatPtr,                   &
                           ImPlot_PlotLine_doublePtrdoublePtr, ImPlot_PlotLine_FloatPtrFloatPtr,                   &
                           ImPlot_PlotScatter_doublePtrdoublePtr, ImPlot_PlotScatter_FloatPtrFloatPtr,             &
                           ImPlot_PlotShaded_doublePtrdoublePtrdoublePtr, ImPlot_PlotShaded_doublePtrdoublePtrInt, &
                           ImPlot_PlotShaded_FloatPtrFloatPtrFloatPtr, ImPlot_PlotShaded_FloatPtrFloatPtrInt,      &
                           ImPlot_SetupAxes
use figure_cimplot_enums, only : ImPlotAxisFlags_None, ImPlotFlags_None,                                          &
                                 ImPlotMarker_None, ImPlotMarker_Auto, ImPlotMarker_Circle, ImPlotMarker_Square,  &
                                 ImPlotMarker_Diamond, ImPlotMarker_Up, ImPlotMarker_Down, ImPlotMarker_Left,     &
                                 ImPlotMarker_Right, ImPlotMarker_Cross, ImPlotMarker_Plus, ImPlotMarker_Asterisk, &
                                 ImPlotMarker_Vertical, ImPlotMarker_Horizontal,                                   &
                                 ImPlotItemFlags_None, ImPlotItemFlags_NoLegend, ImPlotItemFlags_NoFit,           &
                                 ImPlotLineFlags_Segments, ImPlotLineFlags_Loop, ImPlotLineFlags_SkipNaN,         &
                                 ImPlotLineFlags_NoClip, ImPlotLineFlags_Shaded, ImPlotScatterFlags_NoClip,       &
                                 ImPlotBarsFlags_Horizontal

implicit none
private
public :: ip_begin_plot, ip_end_plot, ip_setup_axes
public :: ip_bars, ip_line, ip_scatter, ip_shaded
public :: ip_spec, plot_spec_object
! ImPlot's marker and item-flag constants (values generated from the cimplot metadata), for `ip_spec`
public :: ImPlotMarker_None, ImPlotMarker_Auto, ImPlotMarker_Circle, ImPlotMarker_Square, ImPlotMarker_Diamond
public :: ImPlotMarker_Up, ImPlotMarker_Down, ImPlotMarker_Left, ImPlotMarker_Right, ImPlotMarker_Cross
public :: ImPlotMarker_Plus, ImPlotMarker_Asterisk, ImPlotMarker_Vertical, ImPlotMarker_Horizontal
public :: ImPlotItemFlags_None, ImPlotItemFlags_NoLegend, ImPlotItemFlags_NoFit
public :: ImPlotLineFlags_Segments, ImPlotLineFlags_Loop, ImPlotLineFlags_SkipNaN, ImPlotLineFlags_NoClip
public :: ImPlotLineFlags_Shaded, ImPlotScatterFlags_NoClip, ImPlotBarsFlags_Horizontal

type :: plot_spec_object
   !< Style of a plot item: colours, line weight, markers, flags. Build it with `ip_spec`.
   !<
   !< The C struct is private so that a spec always starts from ImPlot's defaults: a zeroed one would draw nothing
   !< (line weight 0, marker size 0).
   type(im_plot_spec), private :: c !< `ImPlotSpec`, as passed to ImPlot.
endtype plot_spec_object

interface ip_line
   !< Line through the points (x(i), y(i)).
   module procedure ip_line_r32, ip_line_r64
endinterface ip_line

interface ip_scatter
   !< Markers at the points (x(i), y(i)).
   module procedure ip_scatter_r32, ip_scatter_r64
endinterface ip_scatter

interface ip_bars
   !< Bars of height y(i) centred at x(i).
   module procedure ip_bars_r32, ip_bars_r64
endinterface ip_bars

interface ip_shaded
   !< Area between two curves y1(x) and y2(x), or between a curve y(x) and the line y = yref.
   module procedure ip_shaded_r32, ip_shaded_r64, ip_shaded_ref_r32, ip_shaded_ref_r64
endinterface ip_shaded

contains
   ! plots

   function ip_begin_plot(title, width, height) result(visible)
   !< Begin a plot; if true, declare its content and call `ip_end_plot`.
   character(len=*), intent(in)           :: title   !< Title (also the plot id; '##id' hides it).
   real(real64),     intent(in), optional :: width   !< Width [pixels] (default: full width).
   real(real64),     intent(in), optional :: height  !< Height [pixels] (default: ImPlot's).
   logical                                :: visible !< Plot visible.
   type(im_vec2)                          :: extent  !< Size (named so: a local `size` crashes nvfortran 26.9).

   extent = im_vec2(-1.0_c_float, 0.0_c_float)
   if (present(width)) extent%x = real(width, c_float)
   if (present(height)) extent%y = real(height, c_float)
   visible = logical(ImPlot_BeginPlot(cstr(title), extent, ImPlotFlags_None))
   endfunction ip_begin_plot

   subroutine ip_end_plot()
   !< End the plot (only after `ip_begin_plot` returned true).
   call ImPlot_EndPlot()
   endsubroutine ip_end_plot

   subroutine ip_setup_axes(xlabel, ylabel)
   !< Axis labels (call right after `ip_begin_plot`).
   character(len=*), intent(in) :: xlabel !< X label.
   character(len=*), intent(in) :: ylabel !< Y label.

   call ImPlot_SetupAxes(cstr(xlabel), cstr(ylabel), ImPlotAxisFlags_None, ImPlotAxisFlags_None)
   endsubroutine ip_setup_axes

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
