!< figure_implot, ImPlot plots with Fortran arrays.
module figure_implot
!< figure_implot, ImPlot plots with Fortran arrays.
!<
!< `ip_begin_plot` returns true when the plot is visible: then declare its axes and items and close it with
!< `ip_end_plot` (only in that case). Arrays are read in place, without copies, during the call: `real(real32)` and
!< `real(real64)` data go straight to the C `float*` and `double*` items (ImPlot is templated on the element type).
!< A non-contiguous actual argument (e.g. a matrix row `y(i,:)`) is copied by the compiler into a temporary.
use, intrinsic :: iso_c_binding, only : c_float, c_int, c_loc, c_null_ptr, c_ptr
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use figure_base, only : cstr, figure_check, figure_fail
use figure_c_native, only : FIG_ERR_ARGUMENT, FIG_OK
use figure_cimgui, only : im_vec2
use figure_cimplot, only : ImPlot_PlotLine_doublePtrdoublePtr, ImPlot_PlotLine_FloatPtrFloatPtr, &
                           figure_ImPlotSpec_default, im_plot_spec, ImPlot_BeginPlot, ImPlot_EndPlot, ImPlot_SetupAxes
use figure_cimplot_enums, only : ImPlotAxisFlags_None, ImPlotFlags_None

implicit none
private
public :: ip_begin_plot, ip_end_plot, ip_setup_axes, ip_line

interface ip_line
   !< Line through the points (x(i), y(i)), single or double precision.
   module procedure ip_line_r32, ip_line_r64
endinterface ip_line

contains
   function ip_begin_plot(title, width, height) result(visible)
   !< Begin a plot; if true, declare its content and call `ip_end_plot`.
   character(len=*), intent(in)           :: title   !< Title (also the plot id; '##id' hides it).
   real(real64),     intent(in), optional :: width   !< Width [pixels] (default: full width).
   real(real64),     intent(in), optional :: height  !< Height [pixels] (default: ImPlot's).
   logical                                :: visible !< Plot visible.
   type(im_vec2)                          :: extent   !< Size (named so: a local `size` crashes nvfortran 26.9, see plans/plan.md).

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

   function series_ok(nx, ny, item, stat) result(ok)
   !< Whether two series can be plotted together: same size, and a size ImPlot's `int` count holds.
   integer(int64),   intent(in)            :: nx   !< Size of the first series.
   integer(int64),   intent(in)            :: ny   !< Size of the second series.
   character(len=*), intent(in)            :: item !< Item name, for the message.
   integer(int32),   intent(out), optional :: stat !< Status.
   logical                                 :: ok   !< Plottable.

   ok = .false.
   if (nx /= ny) then
      call figure_fail(FIG_ERR_ARGUMENT, item//': x and y have different sizes', stat)
   elseif (nx > int(huge(0_c_int), int64)) then
      call figure_fail(FIG_ERR_ARGUMENT, item//': more points than a C int can count', stat)
   else
      ok = .true.
   endif
   endfunction series_ok

   subroutine ip_line_r32(label, x, y, stat)
   !< Line through the points (x(i), y(i)), single precision.
   character(len=*), intent(in)                    :: label !< Legend label.
   real(real32),     intent(in), contiguous, target :: x(:)  !< Abscissae.
   real(real32),     intent(in), contiguous, target :: y(:)  !< Ordinates.
   integer(int32),   intent(out), optional         :: stat  !< Status.
   type(im_plot_spec)                              :: spec  !< Item style: ImPlot's defaults.
   type(c_ptr)                                     :: px    !< Abscissae address (null when empty).
   type(c_ptr)                                     :: py    !< Ordinates address (null when empty).

   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_line', stat)) return
   px = c_null_ptr
   py = c_null_ptr
   if (size(x) > 0) then ! c_loc of a zero-size array is not allowed
      px = c_loc(x)
      py = c_loc(y)
   endif
   call figure_ImPlotSpec_default(spec)
   call ImPlot_PlotLine_FloatPtrFloatPtr(cstr(label), px, py, int(size(x), c_int), spec)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_line_r32

   subroutine ip_line_r64(label, x, y, stat)
   !< Line through the points (x(i), y(i)), double precision.
   character(len=*), intent(in)                    :: label !< Legend label.
   real(real64),     intent(in), contiguous, target :: x(:)  !< Abscissae.
   real(real64),     intent(in), contiguous, target :: y(:)  !< Ordinates.
   integer(int32),   intent(out), optional         :: stat  !< Status.
   type(im_plot_spec)                              :: spec  !< Item style: ImPlot's defaults.
   type(c_ptr)                                     :: px    !< Abscissae address (null when empty).
   type(c_ptr)                                     :: py    !< Ordinates address (null when empty).

   if (.not. series_ok(size(x, kind=int64), size(y, kind=int64), 'ip_line', stat)) return
   px = c_null_ptr
   py = c_null_ptr
   if (size(x) > 0) then ! c_loc of a zero-size array is not allowed
      px = c_loc(x)
      py = c_loc(y)
   endif
   call figure_ImPlotSpec_default(spec)
   call ImPlot_PlotLine_doublePtrdoublePtr(cstr(label), px, py, int(size(x), c_int), spec)
   call figure_check(FIG_OK, stat)
   endsubroutine ip_line_r64
endmodule figure_implot
