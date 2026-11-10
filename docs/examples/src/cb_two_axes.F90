!< cb_two_axes, cookbook: two quantities with different scales in one plot, a residual on a log axis and force
!< coefficients on a second, linear one, over the same iterations.
program cb_two_axes
!< cb_two_axes, cookbook: two quantities with different scales in one plot, a residual on a log axis and force
!< coefficients on a second, linear one, over the same iterations.
!<
!< The residual falls over eight decades: on Y1, logarithmic. The lift and drag coefficients settle near 0.8 and 0.05:
!< on Y2, linear, on the right. The legend sits outside the plot area. `cb_two_axes --check` opens no window: it draws
!< the plot headless and prints the range each y axis fitted to and the labels of Y2's ticks.
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : app_object, ig_begin, ig_end, ig_set_next_window, ip_begin_plot, ip_end_plot, ip_line, &
                   ip_plot_limits, ip_set_axes, ip_setup_axis, ip_setup_legend
use figure_testing, only : test_plot_tick
implicit none
integer(int32), parameter     :: N = 600_int32 !< Iterations.
type(app_object)              :: app           !< Application.
real(real64)                  :: it(N)         !< Iteration.
real(real64)                  :: residual(N)   !< Residual, from 1 to about 1e-8.
real(real64)                  :: cl(N)         !< Lift coefficient.
real(real64)                  :: cd(N)         !< Drag coefficient.
character(len=16)             :: arg           !< First argument.
logical                       :: check         !< --check: headless, print the ranges.
real(real64)                  :: y1(2), y2(2)  !< Ranges of Y1 and Y2.
real(real64)                  :: xr(2)         !< Range of x.
character(len=:), allocatable :: label         !< A tick label.
character(len=:), allocatable :: labels        !< Y2's tick labels.
integer(int32)                :: count         !< Ticks.
integer(int32)                :: frame         !< Frame counter.
integer(int32)                :: k             !< Counter.
!run cb_two_axes ./cb_two_axes --check
do k = 1_int32, N
   it(k) = real(k, real64)
   residual(k) = 10.0_real64**(-8.0_real64 * real(k, real64) / real(N, real64)) * &
                 (1.0_real64 + 0.3_real64 * sin(real(k, real64) / 6.0_real64))
   cl(k) = 0.8_real64 + 0.3_real64 * exp(-real(k, real64) / 90.0_real64) * cos(real(k, real64) / 15.0_real64)
   cd(k) = 0.05_real64 + 0.04_real64 * exp(-real(k, real64) / 120.0_real64)
enddo
call get_command_argument(1, arg)
check = trim(arg) == '--check'
if (check) then
   call app%init_headless(900_int32, 520_int32)
else
   call app%init('FIGURE: two axes', 900_int32, 520_int32)
endif
frame = 0_int32
labels = ''
do while (app%next_frame())
   frame = frame + 1_int32
   call ig_set_next_window(10.0_real64, 10.0_real64, 880.0_real64, 500.0_real64)
   if (ig_begin('Convergence')) then
      !region axes
      if (ip_begin_plot('Convergence', height=-1.0_real64)) then
         call ip_setup_axis('x1', label='iteration')
         call ip_setup_axis('y1', label='residual', scale='log')
         call ip_setup_axis('y2', label='coefficient', format='%.2f') ! on the right, no grid lines
         call ip_setup_legend('e', outside=.true.)
         call ip_line('residual', it, residual)                       ! on X1, Y1
         call ip_set_axes('x1', 'y2')                                 ! the next items on Y2
         call ip_line('cl', it, cl)
         call ip_line('cd', it, cd)
         if (check .and. frame == 3_int32) call measure()             ! --check: what the axes show
         call ip_end_plot()
      endif
      !endregion axes
   endif
   call ig_end()
   if (check .and. frame == 3_int32) exit
enddo
call app%destroy()
if (check) then
   write(output_unit, '(A,ES9.2,A,ES9.2)') 'Y1 (log), fitted to the residual:     ', y1(1), ' to ', y1(2)
   write(output_unit, '(A,F9.4,A,F9.4)')   'Y2 (linear), fitted to cl and cd:     ', y2(1), ' to ', y2(2)
   write(output_unit, '(A)')               "Y2's tick labels ('%.2f'):"//labels
endif

contains
   subroutine measure()
   !< The ranges the y axes fitted to and Y2's tick labels (inside the plot, after the items).
   call ip_plot_limits(xr(1), xr(2), y1(1), y1(2), yaxis='y1')
   call ip_plot_limits(xr(1), xr(2), y2(1), y2(2), yaxis='y2')
   call test_plot_tick('y2', 1_int32, label, count)
   do k = 1_int32, count
      call test_plot_tick('y2', k, label)
      labels = labels//' '//label
   enddo
   endsubroutine measure
endprogram cb_two_axes
