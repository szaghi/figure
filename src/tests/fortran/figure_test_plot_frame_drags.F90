!< figure_test_plot_frame_drags, the Fortran plot frame's drag tools (figure_plot_tools), as ImPlot's.
program figure_test_plot_frame_drags
!< figure_test_plot_frame_drags, the Fortran plot frame's drag tools (figure_plot_tools), as ImPlot's.
!<
!< szaghi/figure#15 P12, step 3. Each case is a plot with a vertical and a horizontal drag line, a drag point and a
!< drag rectangle, drawn on a few frames first by ImPlot through FIGURE's API (`ip_drag_line_x`, `ip_drag_line_y`,
!< `ip_drag_point`, `ip_drag_rect`), then by the Fortran frame (`pf_drag_*`), with the same synthetic input at the same
!< frames, 40 frames apart. Checked on every frame: the plot's ranges and plot area, the tools' values and what each
!< returned (moved), equal to the bit; pictures at FIGURE's oracle rule (|d| <= 2, no pixel failing). The cases:
!<
!< 1. the tools drawn (the text colour, given colours, a 3-pixel line, a 6-pixel point) over a line;
!< 2. the vertical line, the horizontal line and the point dragged in turn;
!< 3. the rectangle moved by its centre (its grab circles pictured while the pointer rests in it), resized by a
!<    corner, its top edge dragged past its bottom (unordered while held, in order once released), its left edge
!<    double-clicked (to the plot's limit);
!< 4. a plot with only the tools: its first frame's fit takes their extent; a drag of the vertical line does not pan
!<    the plot.
!<
!< The pictures are `figure_test_plot_frame_drags.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them; a
!< mismatch's .new.png and .diff.png are left for inspection).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ImGuiWindowFlags_NoDecoration
use figure_implot_ref, only : ip_begin_plot, ip_drag_line_x, ip_drag_line_y, ip_drag_point, ip_drag_rect, &
                              ip_end_plot, ip_line, ip_plot_limits, ip_plot_to_pixels, ip_setup_axes_limits, ip_spec
use figure_plot_frame, only : pf_begin_plot, pf_end_plot, pf_plot_limits, pf_plot_to_pixels, pf_setup_axes_limits
use figure_plot_items, only : pf_line, pf_spec
use figure_plot_tools, only : pf_drag_line_x, pf_drag_line_y, pf_drag_point, pf_drag_rect
use figure_testing, only : test_capture, test_compare_image, test_drag, test_mouse_button, test_mouse_move, &
                           test_next_frame

implicit none
integer(int32), parameter :: W = 640_int32      !< Display width [pixels].
integer(int32), parameter :: H = 440_int32      !< Display height [pixels].
integer(int32), parameter :: NCASE = 4_int32    !< Cases.
integer(int32), parameter :: NFMAX = 26_int32   !< Frames per side of a case at most.
integer(int32), parameter :: NP = 201_int32     !< Points of a line.
integer(int32), parameter :: NSTATE = 20_int32  !< Values checked per frame: ranges (4), plot area (4), the lines (2),
                                                !< the point (2), the rectangle (4), moved (4).
real(real64),   parameter :: C1(4) = [0.91_real64, 0.40_real64, 0.30_real64, 1.0_real64] !< A colour.
real(real64),   parameter :: RED(4) = [1.0_real64, 0.15_real64, 0.1_real64, 1.0_real64]  !< The horizontal line's.
real(real64),   parameter :: GREEN(4) = [0.2_real64, 0.85_real64, 0.35_real64, 1.0_real64] !< The rectangle's.
type(app_object)          :: app                !< Application.
real(real64)              :: xs(NP), ys(NP)     !< The line.
real(real64)              :: state(NSTATE, NFMAX, 2) !< Per frame and side.
real(real64)              :: vx, vy, ptx, pty, rx0, rx1, ry0, ry1 !< The tools' values.
logical                   :: test_passed(NCASE) !< Per-case outcome.
logical                   :: side_fortran       !< Drawing with the Fortran frame.
integer(int32)            :: c, f, s, sd, i     !< Case, frame, status, side, counter.
character(len=16)         :: keep               !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do i = 1_int32, NP
   xs(i) = real(i - 1_int32, real64) * 0.05_real64
   ys(i) = sin(xs(i))
enddo
do c = 1_int32, NCASE
   state = 0.0_real64
   do sd = 1_int32, 2_int32 ! 1 ImPlot, 2 the Fortran frame
      side_fortran = sd == 2_int32
      vx = 3.0_real64
      vy = 0.5_real64
      ptx = 7.0_real64
      pty = -0.8_real64
      rx0 = 5.5_real64
      rx1 = 8.5_real64
      ry0 = 0.2_real64
      ry1 = 1.0_real64
      do f = 1_int32, nframes(c)
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_drags: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('plot frame drags', flags=ImGuiWindowFlags_NoDecoration)) call draw_case(c, f)
         call ig_end()
         if (captured(c, f) > 0_int32) call test_capture(picture(c, captured(c, f), side_fortran), s)
         call pointer(c, f)
      enddo
      call test_mouse_move(-100.0_real64, -100.0_real64)
      do i = 1_int32, 40_int32 ! past Dear ImGui's double-click time: the other side's clicks are not a pair
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_drags: next_frame returned false headless'
      enddo
   enddo
   test_passed(c) = state_equal(c)
   do i = 1_int32, 2_int32
      if (any(captured_frames(c) == i)) test_passed(c) = pictures_equal(c, i) .and. test_passed(c)
   enddo
   select case (c)
   case (2_int32, 3_int32) ! the tools moved
      test_passed(c) = test_passed(c) .and. any(state(17:20, 1:nframes(c), 1) > 0.5_real64)
   case (4_int32) ! fitted to the tools, then not panned by the drag
      test_passed(c) = test_passed(c) .and. state(1, 2, 1) == 3.0_real64 .and. state(2, 2, 1) == 8.5_real64 .and. &
                       all(state(1:4, nframes(c), 1) == state(1:4, 2, 1)) .and. state(9, nframes(c), 1) /= 3.0_real64
   case default
   endselect
enddo
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_drags checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   pure function nframes(k) result(n)
   !< A case's frames per side.
   integer(int32), intent(in) :: k !< Case.
   integer(int32)             :: n !< Frames.

   select case (k)
   case (1_int32)
      n = 3_int32
   case (2_int32)
      n = 20_int32
   case (3_int32)
      n = 26_int32
   case default
      n = 10_int32
   endselect
   endfunction nframes

   pure function captured(k, fr) result(n)
   !< The picture taken on a frame (0: none, 1: the last frame's, 2: another).
   integer(int32), intent(in) :: k, fr !< Case, frame.
   integer(int32)             :: n     !< Picture.

   n = 0_int32
   if (fr == nframes(k)) n = 1_int32
   select case (k)
   case (1_int32, 4_int32)
      if (fr == 1_int32) n = 2_int32
   case (2_int32)
      if (fr == 6_int32) n = 2_int32
   case (3_int32)
      if (fr == 4_int32) n = 2_int32
   endselect
   endfunction captured

   pure function captured_frames(k) result(n)
   !< The pictures a case takes.
   integer(int32), intent(in) :: k    !< Case.
   integer(int32)             :: n(2) !< Pictures.

   n = [1_int32, 2_int32]
   if (k < 0_int32) n(2) = 0_int32
   endfunction captured_frames

   function px(v, fr) result(p)
   !< The pixel (rounded) of the abscissa v in ImPlot's plot on frame fr.
   real(real64),   intent(in) :: v  !< Abscissa.
   integer(int32), intent(in) :: fr !< Frame.
   real(real64)               :: p  !< Pixel.

   associate(st => state(:, fr, 1))
      p = real(nint(st(5) + (v - st(1)) / (st(2) - st(1)) * (st(7) - st(5))), real64)
   endassociate
   endfunction px

   function py(v, fr) result(p)
   !< The pixel (rounded) of the ordinate v in ImPlot's plot on frame fr.
   real(real64),   intent(in) :: v  !< Ordinate.
   integer(int32), intent(in) :: fr !< Frame.
   real(real64)               :: p  !< Pixel.

   associate(st => state(:, fr, 1))
      p = real(nint(st(6) + (st(4) - v) / (st(4) - st(3)) * (st(8) - st(6))), real64)
   endassociate
   endfunction py

   subroutine pointer(k, fr)
   !< A case's input on a frame, the same on both sides (the targets from ImPlot's side on that frame).
   integer(int32), intent(in) :: k, fr !< Case, frame.
   real(real64)               :: x, y  !< A target.
   integer(int32)             :: j     !< Counter.

   associate(st => state(:, fr, 1))
      select case (k)
      case (2_int32)
         if (fr == 2_int32) then ! the vertical line
            x = px(st(9), fr)
            y = py(-1.2_real64, fr)
            call test_drag(x, y, x + 60.0_real64, y)
         elseif (fr == 8_int32) then ! the horizontal line
            x = px(1.0_real64, fr)
            y = py(st(10), fr)
            call test_drag(x, y, x, y + 40.0_real64)
         elseif (fr == 14_int32) then ! the point
            x = px(st(11), fr)
            y = py(st(12), fr)
            call test_drag(x, y, x - 50.0_real64, y - 30.0_real64)
         elseif (fr == 19_int32) then
            call away()
         endif
      case (3_int32)
         if (fr == 2_int32) then ! the centre
            x = px(0.5_real64 * (st(13) + st(14)), fr)
            y = py(0.5_real64 * (st(15) + st(16)), fr)
            call test_drag(x, y, x + 40.0_real64, y + 20.0_real64)
         elseif (fr == 8_int32) then ! the corner (x max, y max)
            x = px(st(14), fr)
            y = py(st(16), fr)
            call test_drag(x, y, x + 30.0_real64, y - 25.0_real64)
         elseif (fr == 14_int32) then ! the top edge, past the bottom
            x = px(0.5_real64 * (st(13) + st(14)), fr)
            y = py(st(16), fr)
            call test_drag(x, y, x, py(st(15), fr) + 30.0_real64)
         elseif (fr == 20_int32) then ! a double click on the left edge
            x = px(st(13), fr)
            y = py(0.5_real64 * (st(15) + st(16)), fr)
            call test_mouse_move(x, y)
            do j = 1_int32, 2_int32
               call test_next_frame()
               call test_mouse_button(.true.)
               call test_next_frame()
               call test_mouse_button(.false.)
            enddo
         elseif (fr == 25_int32) then
            call away()
         endif
      case (4_int32)
         if (fr == 3_int32) then
            x = px(st(9), fr)
            y = real(nint(0.5_real64 * (st(6) + st(8))), real64)
            call test_drag(x, y, x + 50.0_real64, y + 10.0_real64)
         elseif (fr == 9_int32) then
            call away()
         endif
      case default
      endselect
   endassociate
   endsubroutine pointer

   subroutine away()
   !< The pointer away from the window.

   call test_mouse_move(-100.0_real64, -100.0_real64)
   endsubroutine away

   subroutine draw_case(k, fr)
   !< A case's plot on a frame, by the side drawing.
   integer(int32), intent(in) :: k, fr !< Case, frame.
   integer(int32)             :: m     !< Side.
   character(len=8)           :: id    !< Plot's ID.

   write(id, '(A,I0)') '##dr', k
   m = merge(2_int32, 1_int32, side_fortran)
   associate(v => state(:, fr, m))
      if (side_fortran) then
         if (.not. pf_begin_plot(trim(id), width=600.0_real64, height=400.0_real64)) return
         if (k /= 4_int32) then
            call pf_setup_axes_limits(0.0_real64, 10.0_real64, -1.5_real64, 1.5_real64)
            call pf_line('##sine', xs, ys, spec=pf_spec(line_color=C1))
         endif
         v(17) = merge(1.0_real64, 0.0_real64, pf_drag_line_x(1_int32, vx))
         v(18) = merge(1.0_real64, 0.0_real64, pf_drag_line_y(2_int32, vy, color=RED, thickness=3.0_real64))
         v(19) = merge(1.0_real64, 0.0_real64, pf_drag_point(3_int32, ptx, pty, radius=6.0_real64))
         v(20) = merge(1.0_real64, 0.0_real64, pf_drag_rect(4_int32, rx0, rx1, ry0, ry1, color=GREEN))
         call pf_plot_limits(v(1), v(2), v(3), v(4))
         call pf_plot_to_pixels(v(1), v(4), v(5), v(6))
         call pf_plot_to_pixels(v(2), v(3), v(7), v(8))
         call pf_end_plot()
      else
         if (.not. ip_begin_plot(trim(id), width=600.0_real64, height=400.0_real64)) return
         if (k /= 4_int32) then
            call ip_setup_axes_limits(0.0_real64, 10.0_real64, -1.5_real64, 1.5_real64)
            call ip_line('##sine', xs, ys, spec=ip_spec(line_color=C1))
         endif
         v(17) = merge(1.0_real64, 0.0_real64, ip_drag_line_x(1_int32, vx))
         v(18) = merge(1.0_real64, 0.0_real64, ip_drag_line_y(2_int32, vy, color=RED, thickness=3.0_real64))
         v(19) = merge(1.0_real64, 0.0_real64, ip_drag_point(3_int32, ptx, pty, radius=6.0_real64))
         v(20) = merge(1.0_real64, 0.0_real64, ip_drag_rect(4_int32, rx0, rx1, ry0, ry1, color=GREEN))
         call ip_plot_limits(v(1), v(2), v(3), v(4))
         call ip_plot_to_pixels(v(1), v(4), v(5), v(6))
         call ip_plot_to_pixels(v(2), v(3), v(7), v(8))
         call ip_end_plot()
      endif
      v(9) = vx
      v(10) = vy
      v(11) = ptx
      v(12) = pty
      v(13) = rx0
      v(14) = rx1
      v(15) = ry0
      v(16) = ry1
   endassociate
   endsubroutine draw_case

   function state_equal(k) result(ok)
   !< Both sides' state equal on every frame.
   integer(int32), intent(in) :: k  !< Case.
   logical                    :: ok !< Equal.
   integer(int32)             :: fr !< Frame.

   ok = .true.
   do fr = 1_int32, nframes(k)
      if (all(state(:, fr, 1) == state(:, fr, 2))) cycle
      ok = .false.
      write(output_unit, '(A,I0,A,I0,A)') 'case ', k, ', frame ', fr, ': ImPlot, frame'
      write(output_unit, '(5ES24.16)') state(:, fr, 1)
      write(output_unit, '(5ES24.16)') state(:, fr, 2)
   enddo
   endfunction state_equal

   function pictures_equal(k, n) result(ok)
   !< A case's n-th pictures of both sides equal at the oracle's rule.
   integer(int32), intent(in) :: k, n !< Case, picture.
   logical                    :: ok   !< Equal.
   integer(int64)             :: nf_  !< Pixels that failed.
   integer(int32)             :: st   !< Status.

   ok = test_compare_image(picture(k, n, .true.), picture(k, n, .false.), threshold=2_int32, max_failed=0_int32, &
                           failed=nf_, stat=st)
   if (.not. ok) write(output_unit, '(A,I0,A,I0,A,I0,A,A)') 'case ', k, ', picture ', n, ': ', nf_, &
                                                            ' pixels failed: ', figure_last_error()
   endfunction pictures_equal

   function picture(k, n, fortran) result(name)
   !< A case's n-th picture: ImPlot's or the Fortran frame's.
   integer(int32), intent(in)    :: k, n    !< Case, picture.
   logical,        intent(in)    :: fortran !< The Fortran frame's.
   character(len=:), allocatable :: name    !< File name.
   character(len=16)             :: tag     !< The case's and picture's numbers.

   write(tag, '(I0,A,I0)') k, '.', n
   if (fortran) then
      name = 'figure_test_plot_frame_drags.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_drags.'//trim(tag)//'.implot.png.tmp'
   endif
   endfunction picture

   subroutine remove_files()
   !< The pictures (a mismatch's .new.png and .diff.png are left for inspection).
   integer(int32) :: unit, ios, k, n, m !< Unit, status, counters.

   do k = 1_int32, NCASE
      do n = 1_int32, 2_int32
         do m = 1_int32, 2_int32
            open(newunit=unit, file=picture(k, n, m == 1_int32), status='old', iostat=ios)
            if (ios == 0) close(unit, status='delete')
         enddo
      enddo
   enddo
   endsubroutine remove_files
endprogram figure_test_plot_frame_drags
