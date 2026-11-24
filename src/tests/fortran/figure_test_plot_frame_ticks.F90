!< figure_test_plot_frame_ticks, the Fortran plot frame's tick formats and ticks given, as ImPlot's.
program figure_test_plot_frame_ticks
!< figure_test_plot_frame_ticks, the Fortran plot frame's tick formats and ticks given, as ImPlot's.
!<
!< szaghi/figure#15 P10 (what P10-P12 left, night 2026-11-23 step 01). Each case is a plot drawn on a few frames first
!< by ImPlot through FIGURE's API (`ip_setup_axes`' `xformat`/`yformat`, `ip_setup_axis`' `format`: ImPlot's
!< `SetupAxisFormat`; `ip_setup_axis_ticks`: `SetupAxisTicks`), then by the Fortran frame (`pf_*`), 40 frames apart,
!< the pointer resting on the plot from the second frame (the mouse text labels the values in the axes' formats).
!< Checked on every frame: the ranges of X1 and Y1 (and Y2), the plot area's corners, equal to the bit; pictures at
!< FIGURE's oracle rule (|d| <= 2, no pixel failing) on the first frame and the last. The cases:
!<
!< 1. formats on linear axes: X1 `%.2f s`, Y1 `%+.1e`, an X2 whose format is longer than ImPlot's `FormatSpec[16]`
!<    (`%.1f metres per s`, kept whole: native/patches/implot-0003), a Y2 in `%.1a`; tags without text follow the
!<    formats;
!< 2. formats on a symlog X1 (`%.1f`) and a log Y1 (`%.0e`), a tag; a Y2 in `%.105f` (a precision of three digits,
!<    the labels cut at ImPlot's 31 characters);
!< 3. ticks given: X1's labelled in two calls (they add up: a label longer than ImPlot's 32-byte buffer, taken whole,
!<    one with trailing blanks, an empty one, a value out of the range, one at 1e30), Y1's labelled by its format
!<    (`value now is %.3f`: its conversion past ImPlot's 15 characters),
!<    Y2's labelled "%g" (given before its format) while its tag and mouse text take the format set after;
!< 4. a time X1 with ticks given (labelled by its format, `%.0f`, not as dates), the mouse text and a tag still dates.
!<
!< The pictures are `figure_test_plot_frame_ticks.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them; a
!< mismatch's .new.png and .diff.png are left for inspection).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ImGuiWindowFlags_NoDecoration
use figure_implot_ref, only : ip_begin_plot, ip_end_plot, ip_line, ip_plot_limits, ip_plot_to_pixels, ip_set_axes, &
                              ip_setup_axes, ip_setup_axes_limits, ip_setup_axis, ip_setup_axis_limits, &
                              ip_setup_axis_ticks, ip_spec, ip_tag
use figure_plot_frame, only : pf_begin_plot, pf_end_plot, pf_plot_limits, pf_plot_to_pixels, pf_set_axes, &
                              pf_setup_axes, pf_setup_axes_limits, pf_setup_axis, pf_setup_axis_limits,   &
                              pf_setup_axis_ticks, pf_tag
use figure_plot_items, only : pf_line, pf_spec
use figure_testing, only : test_capture, test_compare_image, test_mouse_move

implicit none
integer(int32), parameter :: W = 640_int32      !< Display width [pixels].
integer(int32), parameter :: H = 440_int32      !< Display height [pixels].
integer(int32), parameter :: NCASE = 4_int32    !< Cases.
integer(int32), parameter :: NFMAX = 4_int32    !< Frames per side of a case.
integer(int32), parameter :: NP = 201_int32     !< Points of a line.
integer(int32), parameter :: NSTATE = 10_int32  !< Values checked per frame: X1, Y1 ranges, plot area, Y2's range.
real(real64),   parameter :: T0 = 1.6e9_real64  !< The time axis's start [s since the epoch].
real(real64),   parameter :: C1(4) = [0.91_real64, 0.40_real64, 0.30_real64, 1.0_real64] !< A colour.
real(real64),   parameter :: C2(4) = [0.30_real64, 0.62_real64, 0.85_real64, 1.0_real64] !< Another.
real(real64),   parameter :: XT(6) = [1.0_real64, 2.5_real64, 4.0_real64, 6.0_real64, 20.0_real64, 1.0e30_real64] !< X1's
                                                                                                        !< ticks.
real(real64),   parameter :: YT(4) = [-1.25_real64, -0.5_real64, 0.125_real64, 1.0_real64] !< Y1's ticks.
real(real64),   parameter :: Y2T(3) = [-1.0_real64, 0.0_real64, 1.0_real64] !< Y2's ticks.
type(app_object)          :: app                !< Application.
real(real64)              :: xs(NP), ys(NP, 3), ts(NP), ss(NP), ls(NP) !< The lines.
real(real64)              :: tt(5)              !< The time axis's ticks.
character(len=48)         :: xl(6)              !< X1's tick labels.
real(real64)              :: state(NSTATE, NFMAX, 2) !< Per frame and side.
logical                   :: test_passed(NCASE) !< Per-case outcome.
logical                   :: side_fortran       !< Drawing with the Fortran frame.
integer(int32)            :: c, f, s, sd, i     !< Case, frame, status, side, counter.
character(len=16)         :: keep               !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do i = 1_int32, NP
   xs(i) = real(i - 1_int32, real64) * 0.05_real64
   ts(i) = T0 + real(i - 1_int32, real64) * 1800.0_real64
   ss(i) = (xs(i) - 5.0_real64) * 20.0_real64
   ls(i) = 10.0_real64**((xs(i) - 5.0_real64) * 0.5_real64)
   ys(i, 1) = sin(xs(i))
   ys(i, 2) = 100.0_real64 * cos(0.5_real64 * xs(i))
   ys(i, 3) = 0.8_real64 * cos(1.7_real64 * xs(i))
enddo
do i = 1_int32, 5_int32
   tt(i) = T0 + real(i - 1_int32, real64) * 80000.0_real64
enddo
xl(1) = 'one'
xl(2) = 'two and a half   '
xl(3) = 'a label longer than thirty-one characters, whole'
xl(4) = ''
xl(5) = 'out of range'
xl(6) = 'far'
do c = 1_int32, NCASE
   state = 0.0_real64
   do sd = 1_int32, 2_int32 ! 1 ImPlot, 2 the Fortran frame
      side_fortran = sd == 2_int32
      do f = 1_int32, NFMAX
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_ticks: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('plot frame ticks', flags=ImGuiWindowFlags_NoDecoration)) call draw_case(c, f)
         call ig_end()
         if (captured(f) > 0_int32) call test_capture(picture(c, captured(f), side_fortran), s)
         if (f == 1_int32) call test_mouse_move(330.0_real64, 230.0_real64) ! resting on the plot from frame 2
      enddo
      call test_mouse_move(-100.0_real64, -100.0_real64)
      do i = 1_int32, 40_int32 ! as the other frame tests: the sides apart
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_ticks: next_frame returned false headless'
      enddo
   enddo
   test_passed(c) = state_equal(c)
   do i = 1_int32, 2_int32
      test_passed(c) = pictures_equal(c, i) .and. test_passed(c)
   enddo
enddo
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_ticks checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   pure function captured(fr) result(n)
   !< The picture taken on a frame (0: none, 1: the last frame's, 2: the first's).
   integer(int32), intent(in) :: fr !< Frame.
   integer(int32)             :: n  !< Picture.

   n = 0_int32
   if (fr == NFMAX) n = 1_int32
   if (fr == 1_int32) n = 2_int32
   endfunction captured

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
      call ip_setup_axes('time', 'value', xformat='%.2f s', yformat='%+.1e')
      call ip_setup_axis('x2', format='%.1f metres per s')
      call ip_setup_axis('y2', format='%.1a')
      call ip_setup_axes_limits(0.0_real64, 10.0_real64, -1.5_real64, 1.5_real64)
      call ip_setup_axis_limits('x2', 0.0_real64, 20.0_real64)
      call ip_setup_axis_limits('y2', -50.0_real64, 150.0_real64)
      call ip_line('##sine', xs, ys(:, 1), spec=ip_spec(line_color=C1))
      call ip_tag('x1', 2.5_real64)
      call ip_tag('y1', 0.4_real64)
      call ip_set_axes('x2', 'y2')
      call ip_line('##cos', xs, ys(:, 2), spec=ip_spec(line_color=C2))
      call ip_tag('y2', 50.0_real64)
      call ip_plot_limits(d1, d2, v(9), v(10), 'x2', 'y2')
   case (2_int32)
      call ip_setup_axes('', '', xscale='symlog', yscale='log', xformat='%.1f', yformat='%.0e')
      call ip_setup_axis('y2', format='%.105f')
      call ip_setup_axes_limits(-100.0_real64, 100.0_real64, 1.0e-3_real64, 1.0e3_real64)
      call ip_line('##exp', ss, ls, spec=ip_spec(line_color=C1))
      call ip_tag('y1', 2.0_real64)
   case (3_int32)
      call ip_setup_axes('', '', yformat='value now is %.3f')
      call ip_setup_axis('y2')
      call ip_setup_axis_ticks('y2', Y2T)
      call ip_setup_axis('y2', format='%.2e')
      call ip_setup_axes_limits(0.0_real64, 10.0_real64, -1.5_real64, 1.5_real64)
      call ip_setup_axis_limits('y2', -1.5_real64, 1.5_real64)
      call ip_setup_axis_ticks('x1', XT(1:3), xl(1:3))
      call ip_setup_axis_ticks('x1', XT(4:6), xl(4:6))
      call ip_setup_axis_ticks('y1', YT)
      call ip_line('##sine', xs, ys(:, 1), spec=ip_spec(line_color=C1))
      call ip_set_axes('x1', 'y2')
      call ip_line('##cos', xs, ys(:, 3), spec=ip_spec(line_color=C2))
      call ip_tag('y2', 0.3_real64)
      call ip_tag('x1', 7.0_real64)
      call ip_plot_limits(d1, d2, v(9), v(10), 'x1', 'y2')
   case default
      call ip_setup_axes('', '', xscale='time', xformat='%.0f', yformat='%.2f')
      call ip_setup_axes_limits(T0, ts(NP), -1.5_real64, 1.5_real64)
      call ip_setup_axis_ticks('x1', tt)
      call ip_line('##sine', ts, ys(:, 1), spec=ip_spec(line_color=C1))
      call ip_tag('x1', T0 + 129600.0_real64)
      call ip_tag('y1', 0.25_real64)
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
      call pf_setup_axes('time', 'value', xformat='%.2f s', yformat='%+.1e')
      call pf_setup_axis('x2', format='%.1f metres per s')
      call pf_setup_axis('y2', format='%.1a')
      call pf_setup_axes_limits(0.0_real64, 10.0_real64, -1.5_real64, 1.5_real64)
      call pf_setup_axis_limits('x2', 0.0_real64, 20.0_real64)
      call pf_setup_axis_limits('y2', -50.0_real64, 150.0_real64)
      call pf_line('##sine', xs, ys(:, 1), spec=pf_spec(line_color=C1))
      call pf_tag('x1', 2.5_real64)
      call pf_tag('y1', 0.4_real64)
      call pf_set_axes('x2', 'y2')
      call pf_line('##cos', xs, ys(:, 2), spec=pf_spec(line_color=C2))
      call pf_tag('y2', 50.0_real64)
      call pf_plot_limits(d1, d2, v(9), v(10), 'x2', 'y2')
   case (2_int32)
      call pf_setup_axes('', '', xscale='symlog', yscale='log', xformat='%.1f', yformat='%.0e')
      call pf_setup_axis('y2', format='%.105f')
      call pf_setup_axes_limits(-100.0_real64, 100.0_real64, 1.0e-3_real64, 1.0e3_real64)
      call pf_line('##exp', ss, ls, spec=pf_spec(line_color=C1))
      call pf_tag('y1', 2.0_real64)
   case (3_int32)
      call pf_setup_axes('', '', yformat='value now is %.3f')
      call pf_setup_axis('y2')
      call pf_setup_axis_ticks('y2', Y2T)
      call pf_setup_axis('y2', format='%.2e')
      call pf_setup_axes_limits(0.0_real64, 10.0_real64, -1.5_real64, 1.5_real64)
      call pf_setup_axis_limits('y2', -1.5_real64, 1.5_real64)
      call pf_setup_axis_ticks('x1', XT(1:3), xl(1:3))
      call pf_setup_axis_ticks('x1', XT(4:6), xl(4:6))
      call pf_setup_axis_ticks('y1', YT)
      call pf_line('##sine', xs, ys(:, 1), spec=pf_spec(line_color=C1))
      call pf_set_axes('x1', 'y2')
      call pf_line('##cos', xs, ys(:, 3), spec=pf_spec(line_color=C2))
      call pf_tag('y2', 0.3_real64)
      call pf_tag('x1', 7.0_real64)
      call pf_plot_limits(d1, d2, v(9), v(10), 'x1', 'y2')
   case default
      call pf_setup_axes('', '', xscale='time', xformat='%.0f', yformat='%.2f')
      call pf_setup_axes_limits(T0, ts(NP), -1.5_real64, 1.5_real64)
      call pf_setup_axis_ticks('x1', tt)
      call pf_line('##sine', ts, ys(:, 1), spec=pf_spec(line_color=C1))
      call pf_tag('x1', T0 + 129600.0_real64)
      call pf_tag('y1', 0.25_real64)
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

   t = '##tk'//achar(iachar('0') + k)
   endfunction title

   function state_equal(k) result(ok)
   !< Both sides' state equal on every frame.
   integer(int32), intent(in) :: k  !< Case.
   logical                    :: ok !< Equal.
   integer(int32)             :: fr !< Frame.

   ok = .true.
   do fr = 1_int32, NFMAX
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
      name = 'figure_test_plot_frame_ticks.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_ticks.'//trim(tag)//'.implot.png.tmp'
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
endprogram figure_test_plot_frame_ticks
