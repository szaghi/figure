!< cb_plot_window, cookbook: average over a window the user drags, a rectangle across the plot's height whose ends
!< choose the iterations averaged.
program cb_plot_window
!< cb_plot_window, cookbook: average over a window the user drags, a rectangle across the plot's height whose ends
!< choose the iterations averaged.
!<
!< A lift coefficient oscillates and settles. The user drags a rectangle (by its centre to move it, by its left or
!< right edge to resize it); the program averages the samples inside it, draws the mean as a segment over the window
!< and tags it on the y axis. The rectangle spans the plot's height: its top and bottom follow the plot's limits on
!< every frame. `cb_plot_window --check` opens no window: it drags the rectangle 100 iterations to the right with
!< FIGURE's scripted input and prints the window and its mean before and after.
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : app_object, ig_begin, ig_end, ig_set_next_window, ip_begin_plot, ip_drag_rect, ip_end_plot, &
                   ip_line, ip_plot_limits, ip_plot_to_pixels, ip_setup_axes, ip_setup_axes_limits, ip_spec, ip_tag
use figure_testing, only : test_drag
implicit none
integer(int32), parameter :: N = 600_int32                                      !< Iterations.
real(real64),   parameter :: AMBER(4) = [0.96_real64, 0.69_real64, 0.25_real64, 1.0_real64] !< Window colour.
type(app_object)          :: app            !< Application.
real(real64)              :: it(N)          !< Iteration.
real(real64)              :: cl(N)          !< Lift coefficient.
real(real64)              :: x0, x1         !< The window [iterations].
real(real64)              :: ylo, yhi       !< Its bottom and top: the plot's y limits.
real(real64)              :: xa, xb         !< The plot's x limits.
real(real64)              :: mean           !< Mean of cl in the window.
real(real64)              :: px(2), py(2)   !< Drag start and end [pixels].
character(len=16)         :: arg            !< First argument.
character(len=24)         :: text           !< The mean, printed for its tag.
logical                   :: check          !< --check: headless, scripted drag.
integer(int32)            :: first, last    !< Iterations in the window.
integer(int32)            :: frame          !< Frame counter.
integer(int32)            :: k              !< Counter.
do k = 1_int32, N
   it(k) = real(k, real64)
   cl(k) = 0.8_real64 + 0.3_real64 * exp(-real(k, real64) / 150.0_real64) * cos(real(k, real64) / 12.0_real64) + &
           0.01_real64 * sin(real(k, real64) * 1.7_real64)
enddo
x0 = 300.0_real64
x1 = 450.0_real64
call get_command_argument(1, arg)
check = trim(arg) == '--check'
if (check) then
   call app%init_headless(900_int32, 520_int32)
else
   call app%init('FIGURE: average over a window', 900_int32, 520_int32)
endif
frame = 0_int32
do while (app%next_frame())
   frame = frame + 1_int32
   call ig_set_next_window(10.0_real64, 10.0_real64, 880.0_real64, 500.0_real64)
   if (ig_begin('Lift')) then
      if (ip_begin_plot('Lift coefficient', height=-1.0_real64)) then
         call ip_setup_axes('iteration', 'cl')
         call ip_setup_axes_limits(0.0_real64, real(N, real64), 0.4_real64, 1.2_real64)
         call ip_line('cl', it, cl)
         call ip_plot_limits(xa, xb, ylo, yhi)                    ! the window spans the plot's height
         if (ip_drag_rect(1_int32, x0, x1, ylo, yhi, color=AMBER)) then
            x0 = max(x0, 1.0_real64)                               ! kept on the data
            x1 = min(x1, real(N, real64))
         endif
         first = max(1_int32, ceiling(x0))
         last = min(N, floor(x1))
         if (last >= first) then
            mean = sum(cl(first:last)) / real(last - first + 1_int32, real64)
            call ip_line('mean', [x0, x1], [mean, mean], spec=ip_spec(line_color=AMBER, line_weight=2.0_real64))
            write(text, '(A,F6.4)') 'mean ', mean
            call ip_tag('y1', mean, color=AMBER, text=trim(text))
         endif
         if (check .and. frame == 3_int32) call report('before')
         if (check .and. frame == 3_int32) then                    ! --check: drag the centre 100 iterations right
            call ip_plot_to_pixels(0.5_real64 * (x0 + x1), 0.5_real64 * (ylo + yhi), px(1), py(1))
            call ip_plot_to_pixels(0.5_real64 * (x0 + x1) + 100.0_real64, 0.5_real64 * (ylo + yhi), px(2), py(2))
            call test_drag(px(1), py(1), px(2), py(2))
         endif
         if (check .and. frame == 12_int32) call report('after')
         call ip_end_plot()
      endif
   endif
   call ig_end()
   if (check .and. frame == 12_int32) exit
enddo
call app%destroy()

contains
   subroutine report(when)
   !< The window (its iterations) and its mean, for --check.
   character(len=*), intent(in) :: when !< 'before' or 'after' the drag.

   write(output_unit, '(A,A,I0,A,I0,A,F6.4)') when, ' the drag: iterations ', first, ' to ', last, ', mean ', mean
   endsubroutine report
endprogram cb_plot_window
