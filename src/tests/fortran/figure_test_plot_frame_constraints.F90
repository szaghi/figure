!< figure_test_plot_frame_constraints, the Fortran plot frame's axis limit constraints, as ImPlot's.
program figure_test_plot_frame_constraints
!< figure_test_plot_frame_constraints, the Fortran plot frame's axis limit constraints, as ImPlot's.
!<
!< szaghi/figure#15 P10 (what P10-P12 left, night 2026-11-23 step 02). Each case is a plot drawn first by ImPlot
!< through FIGURE's API (`ip_setup_axis_constraints`: FIGURE's `fig_plot_axis_constraints` over ImPlot's
!< `ConstraintRange` and `ConstraintZoom`), then by the Fortran frame (`pf_setup_axis_constraints`), 40 frames apart,
!< with the same scripted input (figure_testing: the wheel, a drag). Checked on every frame: the ranges of X1, Y1 and
!< Y2 and the plot area's corners, equal to the bit; pictures at FIGURE's oracle rule (|d| <= 2, no pixel failing)
!< on the first frame and the last. The cases:
!<
!< 1. X1 within [0, 10] and at most 8 wide (its first fit to [0, 10] shrunk about its centre), Y1 at least 1.5 tall:
!<    the wheel in (Y1 stops at 1.5), the wheel out (X1 stops at 8), a pan past X1's minimum (ImPlot's `SetMin` stops
!<    at 0 then keeps the size at 8, `SetMax` follows the pointer: the range narrows);
!< 2. a log Y1 within [1e-2, 1e4] and a symlog X1 within [-50, 50], their data wider: the fit takes only the values
!<    within the constraints (`ExtendFit`); the wheel out stops at them;
!< 3. a log X1 then set up again as 'linear' (FIGURE's API leaves the scale: still log) within [1, 1000]; a Y2 at
!<    most 10 tall (its fit shrunk about its centre), at least 0.25; the wheel in and out over the plot.
!<
!< The pictures are `figure_test_plot_frame_constraints.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them;
!< a mismatch's .new.png and .diff.png are left for inspection).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ImGuiWindowFlags_NoDecoration
use figure_implot_ref, only : ip_begin_plot, ip_end_plot, ip_line, ip_plot_limits, ip_plot_to_pixels, ip_set_axes, &
                              ip_setup_axes, ip_setup_axes_limits, ip_setup_axis, ip_setup_axis_constraints, ip_spec
use figure_plot_frame, only : pf_begin_plot, pf_end_plot, pf_plot_limits, pf_plot_to_pixels, pf_set_axes, &
                              pf_setup_axes, pf_setup_axes_limits, pf_setup_axis, pf_setup_axis_constraints
use figure_plot_items, only : pf_line, pf_spec
use figure_testing, only : test_capture, test_compare_image, test_drag, test_mouse_move, test_wheel

implicit none
integer(int32), parameter :: W = 640_int32      !< Display width [pixels].
integer(int32), parameter :: H = 440_int32      !< Display height [pixels].
integer(int32), parameter :: NCASE = 3_int32    !< Cases.
integer(int32), parameter :: NF = 20_int32      !< Frames per side of a case.
integer(int32), parameter :: NP = 201_int32     !< Points of a line.
integer(int32), parameter :: NSTATE = 10_int32  !< Values checked per frame: X1, Y1 ranges, plot area, Y2's range.
real(real64),   parameter :: C1(4) = [0.91_real64, 0.40_real64, 0.30_real64, 1.0_real64] !< A colour.
real(real64),   parameter :: C2(4) = [0.30_real64, 0.62_real64, 0.85_real64, 1.0_real64] !< Another.
type(app_object)          :: app                !< Application.
real(real64)              :: xs(NP), ys(NP), ss(NP), ls(NP), lx(NP), y2(NP) !< The lines.
real(real64)              :: state(NSTATE, NF, 2) !< Per frame and side.
logical                   :: test_passed(NCASE) !< Per-case outcome.
logical                   :: side_fortran       !< Drawing with the Fortran frame.
integer(int32)            :: c, f, s, sd, i     !< Case, frame, status, side, counter.
character(len=16)         :: keep               !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do i = 1_int32, NP
   xs(i) = real(i - 1_int32, real64) * 0.05_real64
   ys(i) = sin(xs(i))
   ss(i) = (xs(i) - 5.0_real64) * 20.0_real64
   ls(i) = 10.0_real64**((xs(i) - 4.0_real64) * 1.0_real64)
   lx(i) = 10.0_real64**((xs(i) - 2.5_real64) * 0.65_real64)
   y2(i) = 50.0_real64 + 50.0_real64 * cos(0.7_real64 * xs(i))
enddo
do c = 1_int32, NCASE
   state = 0.0_real64
   do sd = 1_int32, 2_int32 ! 1 ImPlot, 2 the Fortran frame
      side_fortran = sd == 2_int32
      do f = 1_int32, NF
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_constraints: next_frame returned false'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('plot frame constraints', flags=ImGuiWindowFlags_NoDecoration)) call draw_case(c, f)
         call ig_end()
         if (captured(f) > 0_int32) call test_capture(picture(c, captured(f), side_fortran), s)
         call pointer(c, f)
      enddo
      call test_mouse_move(-100.0_real64, -100.0_real64)
      do i = 1_int32, 40_int32 ! as the other frame tests: the sides apart
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_constraints: next_frame returned false'
      enddo
   enddo
   test_passed(c) = state_equal(c)
   do i = 1_int32, 2_int32
      test_passed(c) = pictures_equal(c, i) .and. test_passed(c)
   enddo
   if (c == 1_int32) test_passed(1) = test_passed(1) .and. bites() ! the constraints bit (ImPlot's side)
enddo
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_constraints checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   pure function captured(fr) result(n)
   !< The picture taken on a frame (0: none, 1: the last frame's, 2: the first's).
   integer(int32), intent(in) :: fr !< Frame.
   integer(int32)             :: n  !< Picture.

   n = 0_int32
   if (fr == NF) n = 1_int32
   if (fr == 1_int32) n = 2_int32
   endfunction captured

   function bites() result(ok)
   !< Case 1's constraints hold on ImPlot's side on every frame: X1 within [0, 10] and at most 8 wide, Y1 at least 1.5
   !< tall.
   logical        :: ok !< Held.
   integer(int32) :: fr !< Frame.

   ok = .true.
   do fr = 1_int32, NF
      associate(v => state(:, fr, 1))
         ok = ok .and. v(1) >= 0.0_real64 .and. v(2) <= 10.0_real64 .and. v(2) - v(1) <= 8.0_real64 + 1.0e-12_real64 &
              .and. v(4) - v(3) >= 1.5_real64 - 1.0e-12_real64
      endassociate
   enddo
   if (.not. ok) write(output_unit, '(A)') 'case 1: the constraints did not hold on ImPlot''s side'
   if (.not. ok) write(output_unit, '(4ES24.16)') state(1:4, :, 1)
   endfunction bites

   subroutine pointer(k, fr)
   !< A case's input after a frame, the same on both sides.
   integer(int32), intent(in) :: k, fr !< Case, frame.

   if (fr == 1_int32) call test_mouse_move(330.0_real64, 200.0_real64)
   select case (fr)
   case (2_int32, 3_int32, 4_int32, 5_int32, 6_int32, 7_int32)
      call test_wheel(1.0_real64)
   case (8_int32, 9_int32, 10_int32, 11_int32, 12_int32, 13_int32)
      call test_wheel(-1.0_real64)
   case (14_int32)
      if (k == 1_int32) call test_drag(330.0_real64, 200.0_real64, 590.0_real64, 200.0_real64)
   case (19_int32)
      call test_mouse_move(-100.0_real64, -100.0_real64)
   case default
   endselect
   endsubroutine pointer

   subroutine draw_case(k, fr)
   !< A case's plot on a frame, by the side drawing.
   integer(int32), intent(in) :: k, fr !< Case, frame.

   if (side_fortran) then
      call draw_fortran(k, state(:, fr, 2))
   else
      call draw_implot(k, state(:, fr, 1))
   endif
   endsubroutine draw_case

   subroutine draw_implot(k, v)
   !< A case's plot by ImPlot (FIGURE's API).
   integer(int32), intent(in)    :: k    !< Case.
   real(real64),   intent(inout) :: v(:) !< State.
   real(real64)                  :: d1, d2 !< An unused range.

   if (.not. ip_begin_plot(title(k), width=600.0_real64, height=400.0_real64)) return
   select case (k)
   case (1_int32)
      call ip_setup_axis_constraints('x1', vmin=0.0_real64, vmax=10.0_real64, zoom_max=8.0_real64)
      call ip_setup_axis_constraints('y1', zoom_min=1.5_real64)
      call ip_line('##sine', xs, ys, spec=ip_spec(line_color=C1))
   case (2_int32)
      call ip_setup_axes('', '', xscale='symlog', yscale='log')
      call ip_setup_axis_constraints('x1', vmin=-50.0_real64, vmax=50.0_real64)
      call ip_setup_axis_constraints('y1', vmin=1.0e-2_real64, vmax=1.0e4_real64)
      call ip_line('##exp', ss, ls, spec=ip_spec(line_color=C1))
   case default
      call ip_setup_axes('', '', xscale='log')
      call ip_setup_axis('x1', scale='linear')
      call ip_setup_axis('y2')
      call ip_setup_axis_constraints('x1', vmin=1.0_real64, vmax=1000.0_real64)
      call ip_setup_axis_constraints('y2', zoom_min=0.25_real64, zoom_max=10.0_real64)
      call ip_line('##sine', lx, ys, spec=ip_spec(line_color=C1))
      call ip_set_axes('x1', 'y2')
      call ip_line('##cos', lx, y2, spec=ip_spec(line_color=C2))
      call ip_plot_limits(d1, d2, v(9), v(10), 'x1', 'y2')
   endselect
   call ip_plot_limits(v(1), v(2), v(3), v(4), 'x1', 'y1')
   call ip_plot_to_pixels(v(1), v(4), v(5), v(6), 'x1', 'y1')
   call ip_plot_to_pixels(v(2), v(3), v(7), v(8), 'x1', 'y1')
   call ip_end_plot()
   endsubroutine draw_implot

   subroutine draw_fortran(k, v)
   !< A case's plot by the Fortran frame.
   integer(int32), intent(in)    :: k    !< Case.
   real(real64),   intent(inout) :: v(:) !< State.
   real(real64)                  :: d1, d2 !< An unused range.

   if (.not. pf_begin_plot(title(k), width=600.0_real64, height=400.0_real64)) return
   select case (k)
   case (1_int32)
      call pf_setup_axis_constraints('x1', vmin=0.0_real64, vmax=10.0_real64, zoom_max=8.0_real64)
      call pf_setup_axis_constraints('y1', zoom_min=1.5_real64)
      call pf_line('##sine', xs, ys, spec=pf_spec(line_color=C1))
   case (2_int32)
      call pf_setup_axes('', '', xscale='symlog', yscale='log')
      call pf_setup_axis_constraints('x1', vmin=-50.0_real64, vmax=50.0_real64)
      call pf_setup_axis_constraints('y1', vmin=1.0e-2_real64, vmax=1.0e4_real64)
      call pf_line('##exp', ss, ls, spec=pf_spec(line_color=C1))
   case default
      call pf_setup_axes('', '', xscale='log')
      call pf_setup_axis('x1', scale='linear')
      call pf_setup_axis('y2')
      call pf_setup_axis_constraints('x1', vmin=1.0_real64, vmax=1000.0_real64)
      call pf_setup_axis_constraints('y2', zoom_min=0.25_real64, zoom_max=10.0_real64)
      call pf_line('##sine', lx, ys, spec=pf_spec(line_color=C1))
      call pf_set_axes('x1', 'y2')
      call pf_line('##cos', lx, y2, spec=pf_spec(line_color=C2))
      call pf_plot_limits(d1, d2, v(9), v(10), 'x1', 'y2')
   endselect
   call pf_plot_limits(v(1), v(2), v(3), v(4), 'x1', 'y1')
   call pf_plot_to_pixels(v(1), v(4), v(5), v(6), 'x1', 'y1')
   call pf_plot_to_pixels(v(2), v(3), v(7), v(8), 'x1', 'y1')
   call pf_end_plot()
   endsubroutine draw_fortran

   pure function title(k) result(t)
   !< A case's plot title (its ID).
   integer(int32), intent(in) :: k !< Case.
   character(len=5)           :: t !< Title.

   t = '##cn'//achar(iachar('0') + k)
   endfunction title

   function state_equal(k) result(ok)
   !< Both sides' state equal on every frame.
   integer(int32), intent(in) :: k  !< Case.
   logical                    :: ok !< Equal.
   integer(int32)             :: fr !< Frame.

   ok = .true.
   do fr = 1_int32, NF
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
      name = 'figure_test_plot_frame_constraints.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_constraints.'//trim(tag)//'.implot.png.tmp'
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
endprogram figure_test_plot_frame_constraints
