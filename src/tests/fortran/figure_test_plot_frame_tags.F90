!< figure_test_plot_frame_tags, the Fortran plot frame's axis tags (`pf_tag`), as ImPlot's.
program figure_test_plot_frame_tags
!< figure_test_plot_frame_tags, the Fortran plot frame's axis tags (`pf_tag`), as ImPlot's.
!<
!< szaghi/figure#15 P12, step 4. Each case is a plot with tags on its axes, drawn on a few frames first by ImPlot
!< through FIGURE's API (`ip_tag`: FIGURE's `fig_plot_tag` over ImPlot's `TagX`, `TagY`), then by the Fortran frame
!< (`pf_tag`), 40 frames apart. Checked on every frame: the ranges of X1, Y1, Y2 and the plot area, equal to the bit;
!< pictures at FIGURE's oracle rule (|d| <= 2, no pixel failing), on the first frame and the last (a tag wider than
!< the tick labels widens its axis from the frame after it is first drawn). The cases:
!<
!< 1. tags on X1, Y1, an opposite X2 and an opposite Y2: with text and without (the value "%g"), the last item's
!<    colour (after a line), given colours dark and light (white and black text), alpha 0 (no box, the axis's text
!<    colour), a value out of the axis's range (not drawn), a wide tag;
!< 2. a time x axis's tag without text (the date and time as the mouse text labels them).
!<
!< The pictures are `figure_test_plot_frame_tags.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them; a
!< mismatch's .new.png and .diff.png are left for inspection).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ImGuiWindowFlags_NoDecoration
use figure_implot_ref, only : ip_begin_plot, ip_end_plot, ip_line, ip_plot_limits, ip_plot_to_pixels, ip_set_axes, &
                              ip_setup_axes, ip_setup_axes_limits, ip_setup_axis, ip_spec, ip_tag
use figure_plot_frame, only : pf_begin_plot, pf_end_plot, pf_plot_limits, pf_plot_to_pixels, pf_set_axes, &
                              pf_setup_axes, pf_setup_axes_limits, pf_setup_axis, pf_tag
use figure_plot_items, only : pf_line, pf_spec
use figure_testing, only : test_capture, test_compare_image, test_mouse_move

implicit none
integer(int32), parameter :: W = 640_int32      !< Display width [pixels].
integer(int32), parameter :: H = 440_int32      !< Display height [pixels].
integer(int32), parameter :: NCASE = 2_int32    !< Cases.
integer(int32), parameter :: NFMAX = 4_int32    !< Frames per side of a case at most.
integer(int32), parameter :: NP = 201_int32     !< Points of a line.
integer(int32), parameter :: NSTATE = 10_int32  !< Values checked per frame: X1, Y1 ranges, plot area, Y2's range.
real(real64),   parameter :: T0 = 1.6e9_real64  !< The time axis's start [s since the epoch].
real(real64),   parameter :: C1(4) = [0.91_real64, 0.40_real64, 0.30_real64, 1.0_real64] !< A colour.
real(real64),   parameter :: C2(4) = [0.30_real64, 0.62_real64, 0.85_real64, 1.0_real64] !< Another.
real(real64),   parameter :: DARK(4) = [0.1_real64, 0.1_real64, 0.4_real64, 1.0_real64]  !< A dark box.
real(real64),   parameter :: LIGHT(4) = [1.0_real64, 1.0_real64, 0.6_real64, 1.0_real64] !< A light box.
real(real64),   parameter :: CLEAR(4) = [0.5_real64, 0.5_real64, 0.5_real64, 0.0_real64] !< No box.
type(app_object)          :: app                !< Application.
real(real64)              :: xs(NP), ys(NP, 2), ts(NP) !< The lines.
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
   ys(i, 1) = sin(xs(i))
   ys(i, 2) = 100.0_real64 * cos(0.5_real64 * xs(i))
enddo
do c = 1_int32, NCASE
   state = 0.0_real64
   do sd = 1_int32, 2_int32 ! 1 ImPlot, 2 the Fortran frame
      side_fortran = sd == 2_int32
      do f = 1_int32, NFMAX
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_tags: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('plot frame tags', flags=ImGuiWindowFlags_NoDecoration)) call draw_case(c, f)
         call ig_end()
         if (captured(c, f) > 0_int32) call test_capture(picture(c, captured(c, f), side_fortran), s)
      enddo
      do i = 1_int32, 40_int32 ! as the other frame tests: the sides apart
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_tags: next_frame returned false headless'
      enddo
   enddo
   test_passed(c) = state_equal(c)
   do i = 1_int32, 2_int32
      test_passed(c) = pictures_equal(c, i) .and. test_passed(c)
   enddo
enddo
test_passed(1) = test_passed(1) .and. state(5, NFMAX, 1) > state(5, 1, 1) ! the wide tag widened Y1 (ImPlot's side)
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_tags checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   pure function nframes(k) result(n)
   !< A case's frames per side.
   integer(int32), intent(in) :: k !< Case.
   integer(int32)             :: n !< Frames.

   n = NFMAX
   if (k < 0_int32) n = 0_int32
   endfunction nframes

   pure function captured(k, fr) result(n)
   !< The picture taken on a frame (0: none, 1: the last frame's, 2: the first's).
   integer(int32), intent(in) :: k, fr !< Case, frame.
   integer(int32)             :: n     !< Picture.

   n = 0_int32
   if (fr == nframes(k)) n = 1_int32
   if (fr == 1_int32) n = 2_int32
   endfunction captured

   subroutine draw_case(k, fr)
   !< A case's plot on a frame, by the side drawing.
   integer(int32), intent(in) :: k, fr !< Case, frame.
   integer(int32)             :: m     !< Side.
   real(real64)               :: d1, d2 !< An unused range.

   m = merge(2_int32, 1_int32, side_fortran)
   associate(v => state(:, fr, m))
      if (side_fortran) then
         if (.not. pf_begin_plot(merge('##tg1', '##tg2', k == 1_int32), width=600.0_real64, height=400.0_real64)) &
            return
         if (k == 1_int32) then
            call pf_setup_axis('x2')
            call pf_setup_axis('y2')
            call pf_setup_axes_limits(0.0_real64, 10.0_real64, -1.5_real64, 1.5_real64)
            call pf_line('##sine', xs, ys(:, 1), spec=pf_spec(line_color=C1))
            call pf_tag('x1', 2.5_real64)
            call pf_tag('y1', 0.4_real64, color=DARK, text='mark')
            call pf_tag('y1', -0.7_real64, color=LIGHT)
            call pf_tag('y1', 5.0_real64, color=LIGHT, text='out of range')
            call pf_tag('y1', -1.2_real64, color=DARK, text='a wide tag on y1')
            call pf_tag('x1', 7.5_real64, color=CLEAR, text='no box')
            call pf_tag('x2', 0.5_real64, color=LIGHT, text='x2')
            call pf_set_axes('x1', 'y2')
            call pf_line('##cos', xs, ys(:, 2), spec=pf_spec(line_color=C2))
            call pf_tag('y2', 50.0_real64, text='right')
            call pf_plot_limits(d1, d2, v(9), v(10), 'x1', 'y2')
         else
            call pf_setup_axes('', '', xscale='time')
            call pf_setup_axes_limits(T0, ts(NP), -1.5_real64, 1.5_real64)
            call pf_line('##sine', ts, ys(:, 1), spec=pf_spec(line_color=C1))
            call pf_tag('x1', T0 + 129600.0_real64)
            call pf_tag('y1', 0.25_real64, color=DARK)
         endif
         call pf_plot_limits(v(1), v(2), v(3), v(4), 'x1', 'y1')
         call pf_plot_to_pixels(v(1), v(4), v(5), v(6), 'x1', 'y1')
         call pf_plot_to_pixels(v(2), v(3), v(7), v(8), 'x1', 'y1')
         call pf_end_plot()
      else
         if (.not. ip_begin_plot(merge('##tg1', '##tg2', k == 1_int32), width=600.0_real64, height=400.0_real64)) &
            return
         if (k == 1_int32) then
            call ip_setup_axis('x2')
            call ip_setup_axis('y2')
            call ip_setup_axes_limits(0.0_real64, 10.0_real64, -1.5_real64, 1.5_real64)
            call ip_line('##sine', xs, ys(:, 1), spec=ip_spec(line_color=C1))
            call ip_tag('x1', 2.5_real64)
            call ip_tag('y1', 0.4_real64, color=DARK, text='mark')
            call ip_tag('y1', -0.7_real64, color=LIGHT)
            call ip_tag('y1', 5.0_real64, color=LIGHT, text='out of range')
            call ip_tag('y1', -1.2_real64, color=DARK, text='a wide tag on y1')
            call ip_tag('x1', 7.5_real64, color=CLEAR, text='no box')
            call ip_tag('x2', 0.5_real64, color=LIGHT, text='x2')
            call ip_set_axes('x1', 'y2')
            call ip_line('##cos', xs, ys(:, 2), spec=ip_spec(line_color=C2))
            call ip_tag('y2', 50.0_real64, text='right')
            call ip_plot_limits(d1, d2, v(9), v(10), 'x1', 'y2')
         else
            call ip_setup_axes('', '', xscale='time')
            call ip_setup_axes_limits(T0, ts(NP), -1.5_real64, 1.5_real64)
            call ip_line('##sine', ts, ys(:, 1), spec=ip_spec(line_color=C1))
            call ip_tag('x1', T0 + 129600.0_real64)
            call ip_tag('y1', 0.25_real64, color=DARK)
         endif
         call ip_plot_limits(v(1), v(2), v(3), v(4), 'x1', 'y1')
         call ip_plot_to_pixels(v(1), v(4), v(5), v(6), 'x1', 'y1')
         call ip_plot_to_pixels(v(2), v(3), v(7), v(8), 'x1', 'y1')
         call ip_end_plot()
      endif
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
      name = 'figure_test_plot_frame_tags.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_tags.'//trim(tag)//'.implot.png.tmp'
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
endprogram figure_test_plot_frame_tags
