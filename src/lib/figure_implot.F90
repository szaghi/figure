!< figure_implot, ImPlot plots with Fortran arrays.
module figure_implot
!< figure_implot, ImPlot plots with Fortran arrays.
!<
!< `ip_begin_plot` returns true when the plot is visible: then declare its axes and items and close it with
!< `ip_end_plot` (only in that case). Arrays are read in place, without copies, during the call: `real(real64)` is
!< passed straight to the C `double*` (the bind(C) interfaces reject at compile time a platform where the two kinds
!< differ). A non-contiguous actual argument (e.g. a matrix row `y(i,:)`) is copied by the compiler into a temporary.
use, intrinsic :: iso_c_binding, only : c_float, c_int
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure_base, only : cstr, figure_check, figure_fail
use figure_c_native, only : FIG_ERR_ARGUMENT, im_vec2, fig_plot_line, ImPlot_BeginPlot, ImPlot_EndPlot, ImPlot_SetupAxes

implicit none
private
public :: ip_begin_plot, ip_end_plot, ip_setup_axes, ip_line

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
   visible = logical(ImPlot_BeginPlot(cstr(title), extent, 0_c_int))
   endfunction ip_begin_plot

   subroutine ip_end_plot()
   !< End the plot (only after `ip_begin_plot` returned true).
   call ImPlot_EndPlot()
   endsubroutine ip_end_plot

   subroutine ip_setup_axes(xlabel, ylabel)
   !< Axis labels (call right after `ip_begin_plot`).
   character(len=*), intent(in) :: xlabel !< X label.
   character(len=*), intent(in) :: ylabel !< Y label.

   call ImPlot_SetupAxes(cstr(xlabel), cstr(ylabel), 0_c_int, 0_c_int)
   endsubroutine ip_setup_axes

   subroutine ip_line(label, x, y, stat)
   !< Line through the points (x(i), y(i)).
   character(len=*), intent(in)              :: label !< Legend label.
   real(real64),     intent(in), contiguous  :: x(:)  !< Abscissae.
   real(real64),     intent(in), contiguous  :: y(:)  !< Ordinates.
   integer(int32),   intent(out), optional   :: stat  !< Status.

   if (size(x) /= size(y)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip_line: x and y have different sizes', stat)
      return
   endif
   call figure_check(fig_plot_line(label, len(label, c_int), x, y, int(size(x), c_int)), stat)
   endsubroutine ip_line
endmodule figure_implot
