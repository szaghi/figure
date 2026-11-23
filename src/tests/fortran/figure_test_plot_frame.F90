!< figure_test_plot_frame, the Fortran plot frame draws the plots ImPlot draws, to the pixels, headless.
program figure_test_plot_frame
!< figure_test_plot_frame, the Fortran plot frame draws the plots ImPlot draws, to the pixels, headless.
!<
!< szaghi/figure#15 P10's gate on the plot frame's skeleton (figure_plot_frame). Each case is one plot drawn twice in
!< the same window at the same place, on different frames: by ImPlot through FIGURE's API (`ip_begin_plot`,
!< `ip_setup_axes_limits(..., always=.true.)`, `ip_line`, `ip_end_plot`) and by the Fortran frame (`pf_begin_plot`,
!< `pf_setup_axes_limits(..., always=.true.)`, `pf_line`, `pf_end_plot`); the two pictures compared at FIGURE's oracle
!< rule (|d| <= 2 on every channel, no pixel failing). The cases: a sine on [0, 10] x [-1.2, 1.2] (majors and labelled
!< minors on both axes, the zero snapped); wide labels on [1e5, 2e5] x [-0.0013, 0.0021] (the x labels thinned, `%g` of
!< small values); a line leaving the plot (culled and clipped segments) -- these three in FIGURE's default style (seal),
!< the lines of explicit colours (the style's line colours are ImPlot's colormap, not the frame's yet); the sine again
!< in the style `'dark'`, the line of the automatic colour (ImPlot's colormap Deep). One plot ID per case (an ImPlot
!< item keeps the colour it was created with). The pictures are `figure_test_plot_frame.*.png.tmp`, removed at the end
!< (FIGURE_TEST_KEEP=1 keeps them; a mismatch's .new.png and .diff.png are left for inspection).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ip_begin_plot, ip_end_plot, &
                   ip_line, ip_setup_axes_limits, ip_spec, ImGuiWindowFlags_NoDecoration
use figure_plot_frame, only : pf_begin_plot, pf_end_plot, pf_setup_axes_limits
use figure_plot_items, only : pf_line, pf_spec
use figure_testing, only : test_capture, test_compare_image, test_mouse_move

implicit none
integer(int32), parameter :: W = 640_int32      !< Display width [pixels].
integer(int32), parameter :: H = 440_int32      !< Display height [pixels].
integer(int32), parameter :: NCASE = 4_int32    !< Cases.
integer(int32), parameter :: NP = 101_int32     !< Points of a line.
type(app_object)          :: app                !< Application.
real(real64)              :: x(NP), y(NP)       !< The line.
real(real64)              :: lim(4)             !< Its plot's limits.
real(real64)              :: ext(2)             !< Its plot's size [pixels].
real(real64)              :: col(4)             !< Its colour (RGBA; negative: automatic).
logical                   :: test_passed(NCASE) !< Per-case outcome.
integer(int32)            :: c, fr, s           !< Case, frame, status.
integer(int64)            :: nf                 !< Pixels that failed.
character(len=16)         :: keep               !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do c = 1_int32, NCASE
   call case_data(c)
   if (c == 4_int32) call app%set_style('dark') ! ImPlot's own line colours (the automatic colour: Deep)
   do fr = 1_int32, 6_int32 ! frames 1-3 ImPlot's, 4-6 the Fortran frame's; the third of each captured
      if (.not. app%next_frame()) error stop 'figure_test_plot_frame: next_frame returned false in headless mode'
      call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
      if (ig_begin('plot frame', flags=ImGuiWindowFlags_NoDecoration)) then
         if (fr <= 3_int32) then
            if (ip_begin_plot(plot_id(c), width=ext(1), height=ext(2))) then
               call ip_setup_axes_limits(lim(1), lim(2), lim(3), lim(4), always=.true.)
               if (col(1) < 0.0_real64) then
                  call ip_line('##line', x, y)
               else
                  call ip_line('##line', x, y, spec=ip_spec(line_color=col))
               endif
               call ip_end_plot()
            endif
         else
            if (pf_begin_plot(plot_id(c), width=ext(1), height=ext(2))) then
               call pf_setup_axes_limits(lim(1), lim(2), lim(3), lim(4), always=.true.)
               if (col(1) < 0.0_real64) then
                  call pf_line('##line', x, y)
               else
                  call pf_line('##line', x, y, spec=pf_spec(line_color=col))
               endif
               call pf_end_plot()
            endif
         endif
      endif
      call ig_end()
      if (fr == 3_int32) call test_capture(picture(c, .false.), s)
      if (fr == 6_int32) call test_capture(picture(c, .true.), s)
   enddo
   if (.not. app%next_frame()) error stop 'figure_test_plot_frame: next_frame returned false in headless mode' ! renders
   test_passed(c) = test_compare_image(picture(c, .true.), picture(c, .false.), threshold=2_int32, max_failed=0_int32, &
                                       failed=nf, stat=s)
   if (.not. test_passed(c)) write(output_unit, '(A,I0,A,I0,A,A)') 'case ', c, ': ', nf, ' pixels failed: ', &
                                                                   figure_last_error()
enddo
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine case_data(k)
   !< A case's line, limits and plot size.
   integer(int32), intent(in) :: k !< Case.
   integer(int32)             :: i !< Counter.

   do i = 1_int32, NP
      select case (k)
      case (1_int32, 4_int32)
         x(i) = real(i - 1_int32, real64) * 0.1_real64
         y(i) = sin(x(i))
      case (2_int32)
         x(i) = 1.0e5_real64 + real(i - 1_int32, real64) * 1.0e3_real64
         y(i) = 0.0017_real64 * sin(real(i - 1_int32, real64) * 0.08_real64)
      case default
         x(i) = -2.0_real64 + real(i - 1_int32, real64) * 0.14_real64
         y(i) = 1.6_real64 * cos(0.9_real64 * x(i)) + 0.3_real64 * sin(5.0_real64 * x(i))
      endselect
   enddo
   select case (k)
   case (1_int32, 4_int32)
      lim = [0.0_real64, 10.0_real64, -1.2_real64, 1.2_real64]
      ext = [600.0_real64, 400.0_real64]
      col = [0.91_real64, 0.40_real64, 0.30_real64, 1.0_real64]
   case (2_int32)
      lim = [1.0e5_real64, 2.0e5_real64, -0.0013_real64, 0.0021_real64]
      ext = [600.0_real64, 300.0_real64]
      col = [0.30_real64, 0.62_real64, 0.85_real64, 0.8_real64]
   case default
      lim = [0.0_real64, 10.0_real64, -1.0_real64, 1.0_real64]
      ext = [520.0_real64, 360.0_real64]
      col = [0.55_real64, 0.75_real64, 0.35_real64, 1.0_real64]
   endselect
   if (k == 4_int32) col = -1.0_real64
   endsubroutine case_data

   function plot_id(k) result(id)
   !< A case's plot ID: one plot per case (an ImPlot item keeps the colour it was created with).
   integer(int32), intent(in)    :: k   !< Case.
   character(len=:), allocatable :: id  !< ID.
   character(len=8)              :: tag !< The case's number.

   write(tag, '(I0)') k
   id = '##frame'//trim(tag)
   endfunction plot_id

   function picture(k, fortran) result(name)
   !< A case's picture: ImPlot's or the Fortran frame's.
   integer(int32), intent(in)    :: k       !< Case.
   logical,        intent(in)    :: fortran !< The Fortran frame's.
   character(len=:), allocatable :: name    !< File name.
   character(len=8)              :: tag     !< The case's number.

   write(tag, '(I0)') k
   if (fortran) then
      name = 'figure_test_plot_frame.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame.'//trim(tag)//'.implot.png.tmp'
   endif
   endfunction picture

   subroutine remove_files()
   !< The pictures (a mismatch's .new.png and .diff.png are left for inspection).
   integer(int32) :: unit, ios, k, m !< Unit, status, counters.

   do k = 1_int32, NCASE
      do m = 1_int32, 2_int32
         open(newunit=unit, file=picture(k, m == 1_int32), status='old', iostat=ios)
         if (ios == 0) close(unit, status='delete')
      enddo
   enddo
   endsubroutine remove_files
endprogram figure_test_plot_frame
