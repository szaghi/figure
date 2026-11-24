!< figure_test_plot_frame_scales, the Fortran plot frame's log10, symlog and time axes, as ImPlot's.
program figure_test_plot_frame_scales
!< figure_test_plot_frame_scales, the Fortran plot frame's log10, symlog and time axes, as ImPlot's.
!<
!< szaghi/figure#15 P10, step 5. Each case is a few frames of a plot drawn twice in one headless window, at the same
!< place: first by ImPlot through FIGURE's API (`ip_setup_axes(..., xscale=, yscale=)`, `ip_setup_axis(..., scale=)`,
!< `ip_setup_axes_limits`, `ip_set_axes`, `ip_line`, `ip_plot_limits`), then by the Fortran frame (`pf_*`, its ticks
!< from figure_plot_locators); the same plot IDs on both sides, one per case. Checked: the ranges of X1-Y1 and of the
!< current axes on every frame (equal to the bit: the fit is ImPlot's, on the raw values within the scale's
!< constraint), and the picture of the last frame at FIGURE's oracle rule (|d| <= 2 on every channel, no pixel
!< failing). Lines of given colours (FIGURE's style seal). The cases:
!<
!< 1. log y over five decades, fit; 2. log x over five decades (limits), y fit; 3. symlog y crossing zero (+-8000),
!< fit; 4. a time x axis over three hours (limits); 5. a time x axis over four months, fit; 6. log y with values <= 0
!< in the data (left out of the fit, the line through them clipped); 7. symlog within [-1, 1] (the linear ticks);
!< 8. a log y2 axis beside a linear y1 (`set_axes`); 9. a time x axis over thirty years.
!<
!< The pictures are `figure_test_plot_frame_scales.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them; a
!< mismatch's .new.png and .diff.png are left for inspection).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ImGuiWindowFlags_NoDecoration
use figure_implot_ref, only : ip_begin_plot, ip_end_plot, ip_line, ip_plot_limits, ip_set_axes, ip_setup_axes, &
                              ip_setup_axes_limits, ip_setup_axis, ip_setup_axis_limits, ip_spec
use figure_plot_frame, only : pf_begin_plot, pf_end_plot, pf_plot_limits, pf_set_axes, pf_setup_axes, &
                              pf_setup_axes_limits, pf_setup_axis, pf_setup_axis_limits
use figure_plot_items, only : pf_line, pf_spec
use figure_testing, only : test_capture, test_compare_image, test_mouse_move

implicit none
integer(int32), parameter :: W = 640_int32      !< Display width [pixels].
integer(int32), parameter :: H = 440_int32      !< Display height [pixels].
integer(int32), parameter :: NCASE = 9_int32    !< Cases.
integer(int32), parameter :: NF = 3_int32       !< Frames per side.
integer(int32), parameter :: NP = 121_int32     !< Points of a line.
real(real64),   parameter :: T0 = 1700000000.0_real64 !< 2023-11-14 22:13:20 UTC [s].
real(real64),   parameter :: C1(4) = [0.91_real64, 0.40_real64, 0.30_real64, 1.0_real64] !< A colour.
real(real64),   parameter :: C2(4) = [0.30_real64, 0.62_real64, 0.85_real64, 1.0_real64] !< Another.
type(app_object)          :: app                !< Application.
real(real64)              :: xs(NP, 2), ys(NP, 2) !< Two lines.
real(real64)              :: lims(4, 2, NF, 2)  !< Ranges drawn: (xmin, xmax, ymin, ymax), pair, frame, side.
logical                   :: test_passed(NCASE) !< Per-case outcome.
logical                   :: side_fortran       !< Drawing with the Fortran frame.
integer(int32)            :: c, f, s, sd        !< Case, frame, status, side.
character(len=16)         :: keep               !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do c = 1_int32, NCASE
   call case_data(c)
   lims = 0.0_real64
   do sd = 1_int32, 2_int32 ! 1 ImPlot, 2 the Fortran frame
      side_fortran = sd == 2_int32
      do f = 1_int32, NF
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_scales: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('plot frame scales', flags=ImGuiWindowFlags_NoDecoration)) call draw_case(c, f)
         call ig_end()
         if (f == NF) call test_capture(picture(c, side_fortran), s)
      enddo
   enddo
   if (.not. app%next_frame()) error stop 'figure_test_plot_frame_scales: next_frame returned false headless' ! renders
   test_passed(c) = limits_equal(c) .and. pictures_equal(c)
enddo
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_scales checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine case_data(k)
   !< A case's lines.
   integer(int32), intent(in) :: k !< Case.
   integer(int32)             :: i !< Counter.
   real(real64)               :: u !< Parameter in [0, 1].

   do i = 1_int32, NP
      u = real(i - 1_int32, real64) / real(NP - 1_int32, real64)
      select case (k)
      case (1_int32)
         xs(i, 1) = 10.0_real64 * u
         ys(i, 1) = 10.0_real64**(0.5_real64 * xs(i, 1)) * (1.0_real64 + 0.3_real64 * sin(3.0_real64 * xs(i, 1)))
      case (2_int32)
         xs(i, 1) = 10.0_real64**(-2.0_real64 + 5.0_real64 * u)
         ys(i, 1) = log10(xs(i, 1))**2
      case (3_int32)
         xs(i, 1) = -20.0_real64 + 40.0_real64 * u
         ys(i, 1) = xs(i, 1)**3
      case (4_int32)
         xs(i, 1) = T0 + 3.0_real64 * 3600.0_real64 * u
         ys(i, 1) = sin(12.0_real64 * u)
      case (5_int32)
         xs(i, 1) = T0 + 120.0_real64 * 86400.0_real64 * u
         ys(i, 1) = 20.0_real64 + 8.0_real64 * sin(6.0_real64 * u)
      case (6_int32)
         xs(i, 1) = 10.0_real64 * u
         ys(i, 1) = (xs(i, 1) - 2.0_real64)**3
      case (7_int32)
         xs(i, 1) = 10.0_real64 * u
         ys(i, 1) = 0.8_real64 * sin(xs(i, 1))
      case (8_int32)
         xs(i, 1) = 10.0_real64 * u
         ys(i, 1) = sin(xs(i, 1))
         xs(i, 2) = xs(i, 1)
         ys(i, 2) = 10.0_real64**(0.4_real64 * xs(i, 1))
      case default
         xs(i, 1) = T0 + 30.0_real64 * 365.25_real64 * 86400.0_real64 * u
         ys(i, 1) = cos(9.0_real64 * u)
      endselect
   enddo
   endsubroutine case_data

   subroutine draw_case(k, fr)
   !< A case's plot on a frame, by the side drawing.
   integer(int32), intent(in) :: k  !< Case.
   integer(int32), intent(in) :: fr !< Frame.

   if (.not. begin(plot_id(k))) return
   select case (k)
   case (1_int32, 6_int32)
      call axes(yscale='log')
   case (2_int32)
      call axes(xscale='log')
      call axis_limits('x1', 0.01_real64, 1000.0_real64)
   case (3_int32, 7_int32)
      call axes(yscale='symlog')
   case (4_int32)
      call axes(xscale='time')
      call axis_limits('x1', T0, T0 + 3.0_real64 * 3600.0_real64)
      call axis_limits('y1', -1.2_real64, 1.2_real64)
   case (5_int32, 9_int32)
      call axes(xscale='time')
   case default
      call axis('y2', 'log')
      call axis_limits('x1', 0.0_real64, 10.0_real64)
      call axis_limits('y1', -1.2_real64, 1.2_real64)
   endselect
   call line('##a', 1_int32, C1)
   if (k == 8_int32) then
      call set_axes('x1', 'y2')
      call line('##b', 2_int32, C2)
   endif
   call finish(fr)
   endsubroutine draw_case

   function begin(id) result(visible)
   !< `ip_begin_plot` or `pf_begin_plot`, 600 x 400.
   character(len=*), intent(in) :: id      !< Plot's ID.
   logical                      :: visible !< Plot visible.

   if (side_fortran) then
      visible = pf_begin_plot(id, width=600.0_real64, height=400.0_real64)
   else
      visible = ip_begin_plot(id, width=600.0_real64, height=400.0_real64)
   endif
   endfunction begin

   subroutine axes(xscale, yscale)
   !< `ip_setup_axes` or `pf_setup_axes`, no labels, the scales given.
   character(len=*), intent(in), optional :: xscale, yscale !< Scales.

   if (side_fortran) then
      call pf_setup_axes('', '', xscale=xscale, yscale=yscale)
   else
      call ip_setup_axes('', '', xscale=xscale, yscale=yscale)
   endif
   endsubroutine axes

   subroutine axis(name, scale)
   !< `ip_setup_axis` or `pf_setup_axis` with a scale.
   character(len=*), intent(in) :: name  !< Axis.
   character(len=*), intent(in) :: scale !< Scale.

   if (side_fortran) then
      call pf_setup_axis(name, scale=scale)
   else
      call ip_setup_axis(name, scale=scale)
   endif
   endsubroutine axis

   subroutine axis_limits(name, vmin, vmax)
   !< An axis's range, every frame.
   character(len=*), intent(in) :: name       !< Axis.
   real(real64),     intent(in) :: vmin, vmax !< Range.

   if (side_fortran) then
      call pf_setup_axis_limits(name, vmin, vmax, always=.true.)
   else
      call ip_setup_axis_limits(name, vmin, vmax, always=.true.)
   endif
   endsubroutine axis_limits

   subroutine set_axes(x, y)
   !< `ip_set_axes` or `pf_set_axes`.
   character(len=*), intent(in) :: x, y !< Axes.

   if (side_fortran) then
      call pf_set_axes(x, y)
   else
      call ip_set_axes(x, y)
   endif
   endsubroutine set_axes

   subroutine line(label, j, col)
   !< `ip_line` or `pf_line` of the j-th line.
   character(len=*), intent(in) :: label  !< Label.
   integer(int32),   intent(in) :: j      !< Line.
   real(real64),     intent(in) :: col(4) !< Colour.

   if (side_fortran) then
      call pf_line(label, xs(:, j), ys(:, j), spec=pf_spec(line_color=col))
   else
      call ip_line(label, xs(:, j), ys(:, j), spec=ip_spec(line_color=col))
   endif
   endsubroutine line

   subroutine finish(fr)
   !< The ranges of X1-Y1 and of the current axes on the frame fr kept, and the plot ended.
   integer(int32), intent(in) :: fr !< Frame.
   integer(int32)             :: m  !< Side.

   m = merge(2_int32, 1_int32, side_fortran)
   if (side_fortran) then
      call pf_plot_limits(lims(1, 1, fr, m), lims(2, 1, fr, m), lims(3, 1, fr, m), lims(4, 1, fr, m), 'x1', 'y1')
      call pf_plot_limits(lims(1, 2, fr, m), lims(2, 2, fr, m), lims(3, 2, fr, m), lims(4, 2, fr, m))
      call pf_end_plot()
   else
      call ip_plot_limits(lims(1, 1, fr, m), lims(2, 1, fr, m), lims(3, 1, fr, m), lims(4, 1, fr, m), 'x1', 'y1')
      call ip_plot_limits(lims(1, 2, fr, m), lims(2, 2, fr, m), lims(3, 2, fr, m), lims(4, 2, fr, m))
      call ip_end_plot()
   endif
   endsubroutine finish

   function limits_equal(k) result(ok)
   !< The ranges of both sides equal on every frame.
   integer(int32), intent(in) :: k     !< Case.
   logical                    :: ok    !< Equal.
   integer(int32)             :: j, fr !< Pair, frame.

   ok = .true.
   do fr = 1_int32, NF
      do j = 1_int32, 2_int32
         if (all(lims(:, j, fr, 1) == lims(:, j, fr, 2))) cycle
         ok = .false.
         write(output_unit, '(A,I0,A,I0,A,I0,A,4ES24.16)') 'case ', k, ', pair ', j, ', frame ', fr, ': ImPlot ', &
                                                           lims(:, j, fr, 1)
         write(output_unit, '(A,4ES24.16)') '                        frame  ', lims(:, j, fr, 2)
      enddo
   enddo
   endfunction limits_equal

   function pictures_equal(k) result(ok)
   !< The last pictures of both sides equal at the oracle's rule.
   integer(int32), intent(in) :: k   !< Case.
   logical                    :: ok  !< Equal.
   integer(int64)             :: nf_ !< Pixels that failed.
   integer(int32)             :: st  !< Status.

   ok = test_compare_image(picture(k, .true.), picture(k, .false.), threshold=2_int32, max_failed=0_int32, &
                           failed=nf_, stat=st)
   if (.not. ok) write(output_unit, '(A,I0,A,I0,A,A)') 'case ', k, ': ', nf_, ' pixels failed: ', figure_last_error()
   endfunction pictures_equal

   function plot_id(k) result(id)
   !< A case's plot ID.
   integer(int32), intent(in)    :: k   !< Case.
   character(len=:), allocatable :: id  !< ID.
   character(len=8)              :: tag !< The case's number.

   write(tag, '(I0)') k
   id = '##sc'//trim(tag)
   endfunction plot_id

   function picture(k, fortran) result(name)
   !< A case's picture: ImPlot's or the Fortran frame's.
   integer(int32), intent(in)    :: k       !< Case.
   logical,        intent(in)    :: fortran !< The Fortran frame's.
   character(len=:), allocatable :: name    !< File name.
   character(len=8)              :: tag     !< The case's number.

   write(tag, '(I0)') k
   if (fortran) then
      name = 'figure_test_plot_frame_scales.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_scales.'//trim(tag)//'.implot.png.tmp'
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
endprogram figure_test_plot_frame_scales
