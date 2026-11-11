!< cb_trajectory, cookbook: a trajectory in 3-D, growing while the solver runs, turned with the mouse (ImPlot3D).
program cb_trajectory
!< cb_trajectory, cookbook: a trajectory in 3-D, growing while the solver runs, turned with the mouse (ImPlot3D). The
!< solver is the Lorenz system, three steps of fourth-order Runge-Kutta a frame; the path is kept as the columns of a
!< matrix and drawn from its rows, in place. With `--test`, headless: the path drawn, read in place, the view turned by
!< a right drag.
use, intrinsic :: iso_fortran_env, only : int32, int64, output_unit, real64
use figure, only : app_object, ig_begin, ig_end, ig_set_next_window, ig_text, ip3_begin_plot, ip3_end_plot, ip3_line, &
                   ip3_scatter, ip3_setup_axes, ip3_spec, ImPlot3DMarker_Circle
use figure_cimgui, only : im_vec2
use figure_cimplot3d, only : ImPlot3D_PlotToPixels_double
use figure_testing, only : test_drawn_extent, test_mouse_button, test_mouse_move, test_next_frame, test_plot_copies, &
                           test_plot_stride

implicit none
integer(int32), parameter :: NMAX = 6000_int32 !< Points kept.
real(real64),   parameter :: RED(4) = [0.93_real64, 0.33_real64, 0.24_real64, 1.0_real64] !< The path's colour.
type(app_object)          :: app               !< Application.
real(real64), target      :: path(3, NMAX)     !< The positions, a column each: path(1, :) x, (2) y, (3) z.
integer(int32)            :: n = 1_int32       !< Points so far.
real(real64)              :: pixel(2)          !< Where the plot shows the point (0, 0, 25) [pixels].
logical                   :: drawn = .false.   !< The path was drawn in its colour (the test's last frame).
character(len=16)         :: arg               !< `--test`: headless.

path(:, 1) = [1.0_real64, 1.0_real64, 20.0_real64]
call get_command_argument(1, arg)
if (trim(arg) == '--test') then
   call app%init_headless(720_int32, 560_int32)
   call test()
else
   call app%init('FIGURE: a trajectory in 3-D', 720_int32, 560_int32)
   do while (app%next_frame())
      call advance(3_int32)
      call draw()
   enddo
endif
call app%destroy()

contains
   subroutine advance(steps)
   !< `steps` steps of the Lorenz system (sigma 10, rho 28, beta 8/3), dt = 0.01, fourth-order Runge-Kutta.
   integer(int32), intent(in) :: steps          !< Steps.
   real(real64),   parameter  :: DT = 0.01_real64 !< Time step.
   real(real64)               :: k1(3), k2(3), k3(3), k4(3) !< Stages.
   integer(int32)             :: k              !< Counter.

   do k = 1_int32, steps
      if (n == NMAX) return
      k1 = rate(path(:, n))
      k2 = rate(path(:, n) + 0.5_real64 * DT * k1)
      k3 = rate(path(:, n) + 0.5_real64 * DT * k2)
      k4 = rate(path(:, n) + DT * k3)
      path(:, n + 1) = path(:, n) + DT / 6.0_real64 * (k1 + 2.0_real64 * (k2 + k3) + k4)
      n = n + 1_int32
   enddo
   endsubroutine advance

   pure function rate(p) result(dp)
   !< The Lorenz system's right-hand side.
   real(real64), intent(in) :: p(3)  !< Position.
   real(real64)             :: dp(3) !< Its rate.

   dp = [10.0_real64 * (p(2) - p(1)), p(1) * (28.0_real64 - p(3)) - p(2), p(1) * p(2) - 8.0_real64 / 3.0_real64 * p(3)]
   endfunction rate

   subroutine draw()
   !< The window: the path as a line, its last point as a marker, the count below.
   type(im_vec2) :: q    !< A projection.
   real(real64)  :: e(4) !< The path's extent [pixels] (the test).

   call ig_set_next_window(10.0_real64, 10.0_real64, 700.0_real64, 540.0_real64)
   if (ig_begin('Lorenz')) then
      if (ip3_begin_plot('trajectory', height=-30.0_real64)) then
         call ip3_setup_axes('x', 'y', 'z', auto_fit=.true., elevation=15.0_real64, azimuth=-45.0_real64)
         call ip3_scatter('now', path(1, n:n), path(2, n:n), path(3, n:n), &
                          spec=ip3_spec(marker=ImPlot3DMarker_Circle, marker_size=5.0_real64))
         call ip3_line('path', path(1, 1:n), path(2, 1:n), path(3, 1:n), &      ! rows: read in place
                       spec=ip3_spec(line_color=RED, line_weight=1.5_real64))
         q = ImPlot3D_PlotToPixels_double(0.0_real64, 0.0_real64, 25.0_real64)
         pixel = [real(q%x, real64), real(q%y, real64)]
         call ip3_end_plot()
      endif
      call ig_text('points: '//itoa(n)//'   (right drag: turn; left drag: pan; wheel: zoom)')
      if (trim(arg) == '--test') call test_drawn_extent(RED, e(1), e(2), e(3), e(4), drawn)
   endif
   call ig_end()
   endsubroutine draw

   pure function itoa(i) result(s)
   !< An integer as text.
   integer(int32), intent(in) :: i !< The integer.
   character(len=:), allocatable :: s !< Its digits.
   character(len=12)          :: b !< Buffer.

   write(b, '(I0)') i
   s = trim(b)
   endfunction itoa

   subroutine frames(k)
   !< `k` frames of the solver and the window.
   integer(int32), intent(in) :: k !< Frames.
   integer(int32)             :: i !< Counter.

   do i = 1_int32, k
      if (.not. app%next_frame()) exit
      call advance(3_int32)
      call draw()
   enddo
   endsubroutine frames

   subroutine test()
   !< 200 frames of the solver: the path drawn in its colour, read in place; then a right drag turns the view.
   real(real64)   :: before(2) !< The pixel of (0, 0, 25) before the drag.
   integer(int64) :: c0       !< Copies before the last frame.
   integer(int32) :: k        !< Step.

   call frames(199_int32)
   c0 = test_plot_copies()
   call frames(1_int32)
   write(output_unit, '(A,I0,A,L1)') 'points: ', n, ', path drawn: ', drawn
   write(output_unit, '(A,I0,A,I0,A)') 'rows read in place: stride ', test_plot_stride(), ' bytes, ', &
                                       test_plot_copies() - c0, ' copies'
   before = pixel
   call test_mouse_move(360.0_real64, 280.0_real64)   ! a right drag across the plot turns the box
   call test_next_frame()
   call test_next_frame()
   call test_mouse_button(.true., 'right')
   call test_next_frame()
   do k = 1_int32, 4_int32
      call test_mouse_move(360.0_real64 + 30.0_real64 * k, 280.0_real64)
      call test_next_frame()
   enddo
   call test_mouse_button(.false., 'right')
   call frames(12_int32)
   write(output_unit, '(A,L1)') 'turned by a right drag: ', norm2(pixel - before) > 10.0_real64
   endsubroutine test
endprogram cb_trajectory
