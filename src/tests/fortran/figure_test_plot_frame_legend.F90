!< figure_test_plot_frame_legend, the Fortran plot frame's legend popups, scrolling, sorting and context menu, as ImPlot's.
program figure_test_plot_frame_legend
!< figure_test_plot_frame_legend, the Fortran plot frame's legend popups, scrolling, sorting and context menu, as
!< ImPlot's.
!<
!< szaghi/figure#15 P10 (what P10-P12 left, night 2026-11-23 step 03). Each case is a plot drawn first by ImPlot through
!< FIGURE's API (`ip_*`; the legend's sorting, which FIGURE's API cannot ask for, through cimplot's `SetupLegend`),
!< then by the Fortran frame (`pf_*`), 40 frames apart, with the same scripted input (figure_testing). Checked on every
!< frame: the ranges of X1 and Y1, the plot area's corners, the first entry's `legend_hovered` and the popup's
!< `begin_legend_popup`, equal; pictures at FIGURE's oracle rule (|d| <= 2, no pixel failing) on two frames. The cases:
!<
!< 1. a legend entry's popup (`ip_begin_legend_popup`/`pf_begin_legend_popup`): the pointer on the entry, a right
!<    click opens it (a text in it), a click away closes it;
!< 2. a legend of 40 entries taller than the plot (clamped: scrollable), the wheel over it down three steps, up one;
!< 3. a horizontal legend outside, south, wider than the frame: the wheel scrolls it sideways;
!< 4. the legend sorted by label (`ImPlotLegendFlags_Sort`: `strcmp`, upper case first, a hidden `##` part counted);
!< 5. sorted and reversed (`ImPlotLegendFlags_Reverse`), horizontal;
!< 6. the legend's context menu (a right click on the legend off its entries): its picture, then 'SE' and 'H'
!<    clicked (the legend moves south-east, in a row), a click away closes it.
!<
!< The pictures are `figure_test_plot_frame_legend.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them; a
!< mismatch's .new.png and .diff.png are left for inspection).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ig_text, ip_begin_plot,    &
                   ip_end_plot, ip_line, ip_plot_limits, ip_plot_to_pixels, ip_setup_axes_limits, ip_setup_legend, &
                   ip_spec, ip_legend_hovered, ip_begin_legend_popup, ip_end_legend_popup,                      &
                   ImGuiWindowFlags_NoDecoration
use figure_cimplot, only : ImPlot_SetupLegend
use figure_cimplot_enums, only : ImPlotLegendFlags_Horizontal, ImPlotLegendFlags_Reverse, ImPlotLegendFlags_Sort, &
                                 ImPlotLocation_NorthWest
use figure_plot_frame, only : pf_begin_plot, pf_end_plot, pf_plot_limits, pf_plot_to_pixels, pf_setup_axes_limits, &
                              pf_setup_legend, pf_legend_hovered, pf_begin_legend_popup, pf_end_legend_popup
use figure_plot_items, only : pf_line, pf_spec
use figure_testing, only : test_capture, test_click, test_compare_image, test_item_click, test_mouse_button, &
                           test_mouse_move, test_wheel

implicit none
integer(int32), parameter :: W = 640_int32      !< Display width [pixels].
integer(int32), parameter :: H = 440_int32      !< Display height [pixels].
integer(int32), parameter :: NCASE = 6_int32    !< Cases.
integer(int32), parameter :: NFMAX = 20_int32   !< Frames per side of a case at most.
integer(int32), parameter :: NP = 101_int32     !< Points of a line.
integer(int32), parameter :: NL = 40_int32      !< Lines.
integer(int32), parameter :: NSTATE = 10_int32  !< Values checked per frame.
type(app_object)          :: app                !< Application.
real(real64)              :: xs(NP), ys(NP, NL) !< The lines.
real(real64)              :: col(4, NL)         !< Their colours.
character(len=40)         :: lab(NL)            !< Their labels.
real(real64)              :: state(NSTATE, NFMAX, 2) !< Per frame and side.
real(real64)              :: rx0, ry0           !< The plot area's top-left corner on ImPlot's first frame [pixels].
logical                   :: test_passed(NCASE) !< Per-case outcome.
logical                   :: side_fortran       !< Drawing with the Fortran frame.
integer(int32)            :: c, f, s, sd, i, k  !< Case, frame, status, side, counters.
character(len=16)         :: keep               !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do k = 1_int32, NL
   do i = 1_int32, NP
      xs(i) = real(i - 1_int32, real64) * 0.1_real64
      ys(i, k) = sin(xs(i) + 0.15_real64 * real(k, real64)) * (1.0_real64 - 0.02_real64 * real(k, real64))
   enddo
   col(:, k) = [0.2_real64 + 0.6_real64 * modulo(0.37_real64 * real(k, real64), 1.0_real64), &
                0.3_real64 + 0.5_real64 * modulo(0.61_real64 * real(k, real64), 1.0_real64), &
                0.9_real64 - 0.6_real64 * modulo(0.23_real64 * real(k, real64), 1.0_real64), 1.0_real64]
enddo
rx0 = 0.0_real64
ry0 = 0.0_real64
do c = 1_int32, NCASE
   state = 0.0_real64
   call labels(c)
   do sd = 1_int32, 2_int32 ! 1 ImPlot, 2 the Fortran frame
      side_fortran = sd == 2_int32
      do f = 1_int32, nframes(c)
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_legend: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('plot frame legend', flags=ImGuiWindowFlags_NoDecoration)) call draw_case(c, f)
         call ig_end()
         if (captured(c, f) > 0_int32) call test_capture(picture(c, captured(c, f), side_fortran), s)
         call pointer(c, f)
      enddo
      call test_mouse_move(-100.0_real64, -100.0_real64)
      do i = 1_int32, 40_int32 ! as the other frame tests: the sides apart
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_legend: next_frame returned false headless'
      enddo
   enddo
   test_passed(c) = state_equal(c)
   do i = 1_int32, 2_int32
      test_passed(c) = pictures_equal(c, i) .and. test_passed(c)
   enddo
   if (c == 1_int32) test_passed(1) = test_passed(1) .and. any(state(10, :, 1) > 0.5_real64) .and. & ! the popup
                                      any(state(9, :, 1) > 0.5_real64) .and. state(10, NFMAX, 1) < 0.5_real64 ! opened
enddo
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_legend checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   pure function nframes(k) result(n)
   !< A case's frames per side.
   integer(int32), intent(in) :: k !< Case.
   integer(int32)             :: n !< Frames.

   select case (k)
   case (1_int32, 2_int32, 3_int32)
      n = 14_int32
   case (6_int32)
      n = NFMAX
   case default
      n = 3_int32
   endselect
   endfunction nframes

   pure function captured(k, fr) result(n)
   !< The picture taken on a frame (0: none, 1: the last frame's, 2: a middle one's).
   integer(int32), intent(in) :: k, fr !< Case, frame.
   integer(int32)             :: n     !< Picture.

   n = 0_int32
   if (fr == nframes(k)) n = 1_int32
   select case (k)
   case (1_int32, 2_int32, 3_int32)
      if (fr == 8_int32) n = 2_int32
   case (6_int32)
      if (fr == 6_int32) n = 2_int32
   case default
      if (fr == 1_int32) n = 2_int32
   endselect
   endfunction captured

   subroutine labels(k)
   !< A case's labels.
   integer(int32), intent(in) :: k !< Case.
   integer(int32)             :: j !< Counter.

   do j = 1_int32, NL
      write(lab(j), '(A,I2.2)') 'series ', j
   enddo
   select case (k)
   case (1_int32)
      lab(1) = 'sine'
      lab(2) = 'shifted'
      lab(3) = 'third'
   case (3_int32)
      do j = 1_int32, 12_int32
         write(lab(j), '(A,I2.2,A)') 'a long label number ', j, ' here'
      enddo
   case (4_int32, 5_int32)
      lab(1) = 'delta'
      lab(2) = 'alpha'
      lab(3) = 'Charlie'
      lab(4) = 'bravo'
      lab(5) = 'alpha##2'
      lab(6) = 'echo'
   case (6_int32)
      lab(1) = 'b'
      lab(2) = 'a long label here'
   case default
   endselect
   endsubroutine labels

   pure function nlines(k) result(n)
   !< A case's lines.
   integer(int32), intent(in) :: k !< Case.
   integer(int32)             :: n !< Lines.

   select case (k)
   case (1_int32)
      n = 3_int32
   case (2_int32)
      n = NL
   case (3_int32)
      n = 12_int32
   case (6_int32)
      n = 2_int32
   case default
      n = 6_int32
   endselect
   endfunction nlines

   subroutine pointer(k, fr)
   !< A case's input after a frame, the same on both sides.
   integer(int32), intent(in) :: k, fr !< Case, frame.

   select case (k)
   case (1_int32) ! the popup
      if (fr == 1_int32) call test_mouse_move(rx0 + 35.0_real64, ry0 + 21.0_real64)
      if (fr == 3_int32) call test_mouse_button(.true., 'right')
      if (fr == 4_int32) call test_mouse_button(.false., 'right')
      if (fr == 9_int32) call test_click(620.0_real64, 428.0_real64)
   case (2_int32) ! scrolling down a column
      if (fr == 1_int32) call test_mouse_move(rx0 + 40.0_real64, ry0 + 80.0_real64)
      if (fr == 3_int32 .or. fr == 5_int32 .or. fr == 7_int32) call test_wheel(-1.0_real64)
      if (fr == 10_int32) call test_wheel(1.0_real64)
   case (3_int32) ! scrolling a row sideways
      if (fr == 1_int32) call test_mouse_move(320.0_real64, 386.0_real64)
      if (fr == 3_int32 .or. fr == 5_int32 .or. fr == 7_int32) call test_wheel(-1.0_real64)
      if (fr == 10_int32) call test_wheel(1.0_real64)
   case (6_int32) ! the legend's context menu
      if (fr == 1_int32) call test_mouse_move(rx0 + 90.0_real64, ry0 + 20.0_real64)
      if (fr == 2_int32) call test_mouse_button(.true., 'right')
      if (fr == 3_int32) call test_mouse_button(.false., 'right')
      if (fr == 7_int32) call test_item_click('SE')
      if (fr == 12_int32) call test_item_click('H')
      if (fr == 16_int32) call test_click(620.0_real64, 428.0_real64)
   case default
   endselect
   endsubroutine pointer

   subroutine draw_case(k, fr)
   !< A case's plot on a frame, by the side drawing.
   integer(int32), intent(in) :: k, fr !< Case, frame.
   integer(int32)             :: j     !< Line.
   real(real64)               :: x0, y0 !< The plot area's corner.
   integer(int32)             :: m     !< Side (a variable: nvfortran 26.9 fails on a merge in the section).

   m = merge(2_int32, 1_int32, side_fortran)
   associate(v => state(:, fr, m))
      if (side_fortran) then
         if (.not. pf_begin_plot(title(k), width=600.0_real64, height=merge(300.0_real64, 400.0_real64, &
                                                                             k == 2_int32))) return
         call pf_setup_axes_limits(0.0_real64, 10.0_real64, -1.5_real64, 1.5_real64)
         select case (k)
         case (3_int32)
            call pf_setup_legend('s', outside=.true., horizontal=.true.)
         case (4_int32)
            call pf_setup_legend(sort=.true.)
         case (5_int32)
            call pf_setup_legend(horizontal=.true., sort=.true., reverse=.true.)
         case default
         endselect
         do j = 1_int32, nlines(k)
            call pf_line(trim(lab(j)), xs, ys(:, j), spec=pf_spec(line_color=col(:, j)))
         enddo
         v(9) = merge(1.0_real64, 0.0_real64, pf_legend_hovered(trim(lab(1))))
         if (pf_begin_legend_popup(trim(lab(1)))) then
            v(10) = 1.0_real64
            call ig_text('the first line')
            call pf_end_legend_popup()
         endif
         call pf_plot_limits(v(1), v(2), v(3), v(4), 'x1', 'y1')
         call pf_plot_to_pixels(v(1), v(4), v(5), v(6), 'x1', 'y1')
         call pf_plot_to_pixels(v(2), v(3), v(7), v(8), 'x1', 'y1')
         call pf_end_plot()
      else
         if (.not. ip_begin_plot(title(k), width=600.0_real64, height=merge(300.0_real64, 400.0_real64, &
                                                                             k == 2_int32))) return
         call ip_setup_axes_limits(0.0_real64, 10.0_real64, -1.5_real64, 1.5_real64)
         select case (k)
         case (3_int32)
            call ip_setup_legend('s', outside=.true., horizontal=.true.)
         case (4_int32)
            call ImPlot_SetupLegend(ImPlotLocation_NorthWest, ImPlotLegendFlags_Sort)
         case (5_int32)
            call ImPlot_SetupLegend(ImPlotLocation_NorthWest, ior(ImPlotLegendFlags_Horizontal, &
                                                                  ior(ImPlotLegendFlags_Sort, ImPlotLegendFlags_Reverse)))
         case default
         endselect
         do j = 1_int32, nlines(k)
            call ip_line(trim(lab(j)), xs, ys(:, j), spec=ip_spec(line_color=col(:, j)))
         enddo
         v(9) = merge(1.0_real64, 0.0_real64, ip_legend_hovered(trim(lab(1))))
         if (ip_begin_legend_popup(trim(lab(1)))) then
            v(10) = 1.0_real64
            call ig_text('the first line')
            call ip_end_legend_popup()
         endif
         call ip_plot_limits(v(1), v(2), v(3), v(4), 'x1', 'y1')
         call ip_plot_to_pixels(v(1), v(4), v(5), v(6), 'x1', 'y1')
         call ip_plot_to_pixels(v(2), v(3), v(7), v(8), 'x1', 'y1')
         if (fr == 1_int32 .and. k == 1_int32) then ! the plot area's corner, for the pointer's targets
            call ip_plot_to_pixels(0.0_real64, 1.5_real64, x0, y0, 'x1', 'y1')
            rx0 = x0
            ry0 = y0
         endif
         call ip_end_plot()
      endif
   endassociate
   endsubroutine draw_case

   pure function title(k) result(t)
   !< A case's plot title (its ID).
   integer(int32), intent(in) :: k !< Case.
   character(len=5)           :: t !< Title.

   t = '##lg'//achar(iachar('0') + k)
   endfunction title

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
      name = 'figure_test_plot_frame_legend.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_legend.'//trim(tag)//'.implot.png.tmp'
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
endprogram figure_test_plot_frame_legend
