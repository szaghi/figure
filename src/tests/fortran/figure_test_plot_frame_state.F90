!< figure_test_plot_frame_state, the Fortran plot frame keeps its plots between frames and fits them as ImPlot does.
program figure_test_plot_frame_state
!< figure_test_plot_frame_state, the Fortran plot frame keeps its plots between frames and fits them as ImPlot does.
!<
!< szaghi/figure#15 P10, steps 1 (per-plot state) and 2 (auto-fit, limits' conditions). Each case is a few frames of
!< the same plots drawn twice in one headless window, at the same place: first by ImPlot through FIGURE's API
!< (`ip_begin_plot`, `ip_setup_axes`, `ip_setup_axes_limits`, `ip_setup_axis_limits`, `ip_line`, `ip_plot_limits`,
!< `ip_end_plot`; ImPlot's `SetNextAxesToFit`/`SetNextAxisToFit` through figure_cimplot, which FIGURE's API does not
!< expose), then by the Fortran frame (`pf_*`) on as many frames; the same plot IDs on both sides (ImPlot's plots and
!< the frame's are separate tables), one set per case. Checked: the ranges each plot is drawn with on each frame
!< (`ip_plot_limits` and `pf_plot_limits`, equal to the bit), and the pictures of the frames listed (the last one at
!< least) compared at FIGURE's oracle rule (|d| <= 2 on every channel, no pixel failing). The cases:
!<
!< 1. two plots one after the other in a frame, different IDs and data: one with limits `once`, one fit to its data on
!<    its first frame;
!< 2. a plot with no limits: [0, 1] on its first frame, fit to the data from its second (ImPlot's one-frame lag; the
!<    first and last frames compared);
!< 3. a degenerate range: y constant, fit to [y - 0.5, y + 0.5];
!< 4. limits `once` that change after the first frame, the data changing: the first limits kept;
!< 5. x limits `always` that change, y fit on the first frame only while the data grow: x follows, y stays;
!< 6. both axes `auto_fit`, the data growing every frame: each frame shows the fit of the frame before;
!< 7. `SetNextAxisToFit` of y on frame 2, `SetNextAxesToFit` on frame 3 (limits `once` on frame 1);
!< 8. `equal`: the same units per pixel on x and y, fit on the first frame;
!< 9. in the style 'dark' (ImPlot's colormap Deep: FIGURE's styles' line colours are their own colormaps, not the
!<    frame's yet), three items: automatic, given, automatic on frame 1, then in the reverse order and the given one
!<    automatic: each keeps the colour it was created with (Deep's first and second, the given one);
!< 10. IDs: figure_plot_hash's hash equals Dear ImGui's (`core_get_id`), the frame holds the plots of the cases.
!<
!< The pictures are `figure_test_plot_frame_state.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them; a
!< mismatch's .new.png and .diff.png are left for inspection).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ip_begin_plot, ip_end_plot, &
                   ip_line, ip_plot_limits, ip_setup_axes, ip_setup_axes_limits, ip_setup_axis_limits, ip_spec,   &
                   ImGuiWindowFlags_NoDecoration
use figure_cimplot, only : ImPlot_SetNextAxesToFit, ImPlot_SetNextAxisToFit
use figure_cimplot_enums, only : ImAxis_Y1
use figure_core, only : core_get_id
use figure_plot_frame, only : pf_begin_plot, pf_end_plot, pf_plot_count, pf_plot_limits, pf_setup_axes, &
                              pf_setup_axes_limits, pf_setup_axis_limits, pf_set_next_axes_to_fit,             &
                              pf_set_next_axis_to_fit
use figure_plot_items, only : pf_line, pf_spec
use figure_plot_hash, only : plot_hash
use figure_testing, only : test_capture, test_compare_image, test_mouse_move

implicit none
integer(int32), parameter :: W = 640_int32      !< Display width [pixels].
integer(int32), parameter :: H = 440_int32      !< Display height [pixels].
integer(int32), parameter :: NCASE = 10_int32   !< Cases.
integer(int32), parameter :: NF = 4_int32       !< Frames per side of a case.
integer(int32), parameter :: NPMAX = 200_int32  !< Points of a line at most.
type(app_object)          :: app                !< Application.
real(real64)              :: xs(NPMAX, 3)       !< Lines' abscissae (a line per column).
real(real64)              :: ys(NPMAX, 3)       !< ... ordinates.
integer(int32)            :: ns(3)              !< ... points.
real(real64)              :: lims(4, 2, NF, 2)  !< Ranges drawn: (xmin, xmax, ymin, ymax), plot, frame, side.
logical                   :: test_passed(NCASE) !< Per-case outcome.
logical                   :: side_fortran       !< Drawing with the Fortran frame.
integer(int32)            :: c, f, s, sd        !< Case, frame, status, side.
character(len=16)         :: keep               !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do c = 1_int32, NCASE - 1_int32
   if (c == 9_int32) call app%set_style('dark') ! ImPlot's own line colours (the automatic colour: Deep)
   lims = 0.0_real64
   do sd = 1_int32, 2_int32 ! 1 ImPlot, 2 the Fortran frame
      side_fortran = sd == 2_int32
      do f = 1_int32, NF
         call case_data(c, f)
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_state: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('plot frame state', flags=ImGuiWindowFlags_NoDecoration)) call draw_case(c, f)
         call ig_end()
         if (captured(c, f)) call test_capture(picture(c, f, side_fortran), s)
      enddo
   enddo
   if (.not. app%next_frame()) error stop 'figure_test_plot_frame_state: next_frame returned false headless' ! renders
   test_passed(c) = limits_equal(c)
   do f = 1_int32, NF
      if (.not. captured(c, f)) cycle
      test_passed(c) = pictures_equal(c, f) .and. test_passed(c)
   enddo
enddo
test_passed(NCASE) = ids_ok()
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_state checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine case_data(k, fr)
   !< The lines of a case on a frame.
   integer(int32), intent(in) :: k  !< Case.
   integer(int32), intent(in) :: fr !< Frame (1..NF).
   integer(int32)             :: i  !< Counter.
   real(real64)               :: t  !< Parameter.

   ns = 0_int32
   select case (k)
   case (1_int32) ! a sine; a parabola
      ns(1:2) = 101_int32
      do i = 1_int32, ns(1)
         xs(i, 1) = real(i - 1_int32, real64) * 0.1_real64
         ys(i, 1) = sin(xs(i, 1))
         xs(i, 2) = -1.0_real64 + real(i - 1_int32, real64) * 0.06_real64
         ys(i, 2) = xs(i, 2) * xs(i, 2) - 3.0_real64
      enddo
   case (2_int32) ! a bump
      ns(1) = 121_int32
      do i = 1_int32, ns(1)
         xs(i, 1) = -3.2_real64 + real(i - 1_int32, real64) * 0.085_real64
         ys(i, 1) = 2.5_real64 * exp(-xs(i, 1)**2 / 4.0_real64) - 0.4_real64
      enddo
   case (3_int32) ! y constant
      ns(1) = 31_int32
      do i = 1_int32, ns(1)
         xs(i, 1) = 2.0_real64 + real(i - 1_int32, real64) * 0.2_real64
         ys(i, 1) = 0.7_real64
      enddo
   case (4_int32) ! a sine moving
      ns(1) = 101_int32
      do i = 1_int32, ns(1)
         xs(i, 1) = real(i - 1_int32, real64) * 0.1_real64
         ys(i, 1) = sin(xs(i, 1) + real(fr, real64))
      enddo
   case (5_int32) ! a sine growing
      ns(1) = 101_int32
      do i = 1_int32, ns(1)
         xs(i, 1) = real(i - 1_int32, real64) * 0.1_real64
         ys(i, 1) = real(fr, real64) * sin(xs(i, 1))
      enddo
   case (6_int32) ! more points every frame
      ns(1) = 30_int32 * fr + 5_int32
      do i = 1_int32, ns(1)
         xs(i, 1) = real(i - 1_int32, real64) * 0.25_real64
         ys(i, 1) = sqrt(xs(i, 1)) * sin(xs(i, 1))
      enddo
   case (7_int32) ! a cosine scaled and moved every frame
      ns(1) = 81_int32
      do i = 1_int32, ns(1)
         xs(i, 1) = real(fr, real64) + real(i - 1_int32, real64) * 0.07_real64
         ys(i, 1) = 0.5_real64 * real(fr, real64) * cos(xs(i, 1)) + 0.3_real64 * real(fr, real64)
      enddo
   case (8_int32) ! a circle
      ns(1) = 121_int32
      do i = 1_int32, ns(1)
         t = 2.0_real64 * acos(-1.0_real64) * real(i - 1_int32, real64) / real(ns(1) - 1_int32, real64)
         xs(i, 1) = 1.0_real64 + 2.0_real64 * cos(t)
         ys(i, 1) = 0.5_real64 + 2.0_real64 * sin(t)
      enddo
   case default ! three sines
      ns = 101_int32
      do i = 1_int32, ns(1)
         xs(i, 1:3) = real(i - 1_int32, real64) * 0.1_real64
         ys(i, 1) = sin(xs(i, 1))
         ys(i, 2) = 0.8_real64 * cos(xs(i, 2))
         ys(i, 3) = 0.5_real64 * sin(2.0_real64 * xs(i, 3))
      enddo
   endselect
   endsubroutine case_data

   subroutine draw_case(k, fr)
   !< A case's plots on a frame, by the side drawing.
   integer(int32), intent(in) :: k  !< Case.
   integer(int32), intent(in) :: fr !< Frame (1..NF).
   real(real64), parameter    :: C1(4) = [0.91_real64, 0.40_real64, 0.30_real64, 1.0_real64] !< A colour.
   real(real64), parameter    :: C2(4) = [0.30_real64, 0.62_real64, 0.85_real64, 1.0_real64] !< Another.

   select case (k)
   case (1_int32)
      if (begin('##s1a', 600.0_real64, 200.0_real64)) then
         call limits(0.0_real64, 10.0_real64, -1.2_real64, 1.2_real64, .false.)
         call line('##sine', 1_int32, C1)
         call finish(1_int32, fr)
      endif
      if (begin('##s1b', 600.0_real64, 200.0_real64)) then
         call line('##parabola', 2_int32, C2)
         call finish(2_int32, fr)
      endif
   case (2_int32, 3_int32)
      if (begin(plot_id(k), 600.0_real64, 400.0_real64)) then
         call line('##line', 1_int32, C1)
         call finish(1_int32, fr)
      endif
   case (4_int32)
      if (begin(plot_id(k), 600.0_real64, 400.0_real64)) then
         if (fr == 1_int32) then
            call limits(0.0_real64, 10.0_real64, -1.5_real64, 1.5_real64, .false.)
         else
            call limits(2.0_real64, 5.0_real64, -0.5_real64, 0.5_real64, .false.)
         endif
         call line('##line', 1_int32, C1)
         call finish(1_int32, fr)
      endif
   case (5_int32)
      if (begin(plot_id(k), 600.0_real64, 400.0_real64)) then
         if (fr == 1_int32) then
            call axis_limits('x1', 0.0_real64, 10.0_real64, .true.)
         else
            call axis_limits('x1', 2.0_real64, 6.0_real64, .true.)
         endif
         call line('##line', 1_int32, C1)
         call finish(1_int32, fr)
      endif
   case (6_int32)
      if (begin(plot_id(k), 600.0_real64, 400.0_real64)) then
         call axes_auto_fit()
         call line('##line', 1_int32, C2)
         call finish(1_int32, fr)
      endif
   case (7_int32)
      if (fr == 2_int32) call next_fit_y()
      if (fr == 3_int32) call next_fit_all()
      if (begin(plot_id(k), 600.0_real64, 400.0_real64)) then
         if (fr == 1_int32) call limits(0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, .false.)
         call line('##line', 1_int32, C1)
         call finish(1_int32, fr)
      endif
   case (8_int32)
      if (begin(plot_id(k), 600.0_real64, 400.0_real64, equal=.true.)) then
         call line('##circle', 1_int32, C2)
         call finish(1_int32, fr)
      endif
   case default
      if (begin(plot_id(k), 600.0_real64, 400.0_real64)) then
         call limits(0.0_real64, 10.0_real64, -1.2_real64, 1.2_real64, .true.)
         if (fr == 1_int32) then
            call line('##a', 1_int32)
            call line('##b', 2_int32, C1)
            call line('##c', 3_int32)
         else
            call line('##c', 3_int32)
            call line('##b', 2_int32)
            call line('##a', 1_int32)
         endif
         call finish(1_int32, fr)
      endif
   endselect
   endsubroutine draw_case

   function begin(id, width, height, equal) result(visible)
   !< `ip_begin_plot` or `pf_begin_plot`.
   character(len=*), intent(in)           :: id      !< Plot's ID.
   real(real64),     intent(in)           :: width   !< Width [pixels].
   real(real64),     intent(in)           :: height  !< Height [pixels].
   logical,          intent(in), optional :: equal   !< Same units per pixel.
   logical                                :: visible !< Plot visible.

   if (side_fortran) then
      visible = pf_begin_plot(id, width=width, height=height, equal=equal)
   else
      visible = ip_begin_plot(id, width=width, height=height, equal=equal)
   endif
   endfunction begin

   subroutine limits(xmin, xmax, ymin, ymax, always)
   !< `ip_setup_axes_limits` or `pf_setup_axes_limits`.
   real(real64), intent(in) :: xmin, xmax, ymin, ymax !< Ranges.
   logical,      intent(in) :: always                 !< Every frame.

   if (side_fortran) then
      call pf_setup_axes_limits(xmin, xmax, ymin, ymax, always=always)
   else
      call ip_setup_axes_limits(xmin, xmax, ymin, ymax, always=always)
   endif
   endsubroutine limits

   subroutine axis_limits(axis, vmin, vmax, always)
   !< `ip_setup_axis_limits` or `pf_setup_axis_limits`.
   character(len=*), intent(in) :: axis       !< Axis.
   real(real64),     intent(in) :: vmin, vmax !< Range.
   logical,          intent(in) :: always     !< Every frame.

   if (side_fortran) then
      call pf_setup_axis_limits(axis, vmin, vmax, always=always)
   else
      call ip_setup_axis_limits(axis, vmin, vmax, always=always)
   endif
   endsubroutine axis_limits

   subroutine axes_auto_fit()
   !< `ip_setup_axes` or `pf_setup_axes`, no labels, both axes fit every frame.

   if (side_fortran) then
      call pf_setup_axes('', '', auto_fit=.true.)
   else
      call ip_setup_axes('', '', auto_fit=.true.)
   endif
   endsubroutine axes_auto_fit

   subroutine next_fit_y()
   !< The next plot's y axis fit: `SetNextAxisToFit(ImAxis_Y1)` or `pf_set_next_axis_to_fit('y1')`.

   if (side_fortran) then
      call pf_set_next_axis_to_fit('y1')
   else
      call ImPlot_SetNextAxisToFit(ImAxis_Y1)
   endif
   endsubroutine next_fit_y

   subroutine next_fit_all()
   !< The next plot's axes fit: `SetNextAxesToFit` or `pf_set_next_axes_to_fit`.

   if (side_fortran) then
      call pf_set_next_axes_to_fit()
   else
      call ImPlot_SetNextAxesToFit()
   endif
   endsubroutine next_fit_all

   subroutine line(label, j, col)
   !< `ip_line` or `pf_line` of the j-th line, of the colour `col` or the automatic one.
   character(len=*), intent(in)           :: label  !< Label.
   integer(int32),   intent(in)           :: j      !< Line.
   real(real64),     intent(in), optional :: col(4) !< Colour.

   if (side_fortran) then
      call pf_line(label, xs(1:ns(j), j), ys(1:ns(j), j), spec=pf_spec(line_color=col))
   elseif (present(col)) then
      call ip_line(label, xs(1:ns(j), j), ys(1:ns(j), j), spec=ip_spec(line_color=col))
   else
      call ip_line(label, xs(1:ns(j), j), ys(1:ns(j), j))
   endif
   endsubroutine line

   subroutine finish(j, fr)
   !< The ranges the j-th plot is drawn with on the frame fr kept, and the plot ended.
   integer(int32), intent(in) :: j  !< Plot.
   integer(int32), intent(in) :: fr !< Frame.
   integer(int32)             :: m  !< Side.

   m = merge(2_int32, 1_int32, side_fortran)
   if (side_fortran) then
      call pf_plot_limits(lims(1, j, fr, m), lims(2, j, fr, m), lims(3, j, fr, m), lims(4, j, fr, m))
      call pf_end_plot()
   else
      call ip_plot_limits(lims(1, j, fr, m), lims(2, j, fr, m), lims(3, j, fr, m), lims(4, j, fr, m))
      call ip_end_plot()
   endif
   endsubroutine finish

   function limits_equal(k) result(ok)
   !< The ranges drawn by both sides equal, on every frame, of every plot.
   integer(int32), intent(in) :: k  !< Case.
   logical                    :: ok !< Equal.
   integer(int32)             :: j, fr !< Plot, frame.

   ok = .true.
   do fr = 1_int32, NF
      do j = 1_int32, 2_int32
         if (all(lims(:, j, fr, 1) == lims(:, j, fr, 2))) cycle
         ok = .false.
         write(output_unit, '(A,I0,A,I0,A,I0,A,4ES24.16)') 'case ', k, ', plot ', j, ', frame ', fr, ': ImPlot ', &
                                                           lims(:, j, fr, 1)
         write(output_unit, '(A,4ES24.16)') '                        frame  ', lims(:, j, fr, 2)
      enddo
   enddo
   endfunction limits_equal

   function pictures_equal(k, fr) result(ok)
   !< The pictures of both sides equal at the oracle's rule.
   integer(int32), intent(in) :: k  !< Case.
   integer(int32), intent(in) :: fr !< Frame.
   logical                    :: ok !< Equal.
   integer(int64)             :: nf_ !< Pixels that failed.
   integer(int32)             :: st  !< Status.

   ok = test_compare_image(picture(k, fr, .true.), picture(k, fr, .false.), threshold=2_int32, max_failed=0_int32, &
                           failed=nf_, stat=st)
   if (.not. ok) write(output_unit, '(A,I0,A,I0,A,I0,A,A)') 'case ', k, ', frame ', fr, ': ', nf_, &
                                                            ' pixels failed: ', figure_last_error()
   endfunction pictures_equal

   function ids_ok() result(ok)
   !< figure_plot_hash equals Dear ImGui's hash (seeded with the window's ID: `core_get_id('')`), and the frame holds
   !< the plots the cases drew (10: two in case 1).
   logical        :: ok   !< All right.
   integer(int32) :: seed !< The window's ID.

   ok = .true.
   if (.not. app%next_frame()) error stop 'figure_test_plot_frame_state: next_frame returned false headless'
   if (ig_begin('plot frame state')) then
      seed = core_get_id('')
      ok = same_id('##line', seed) .and. same_id('line', seed) .and. same_id('a###b', seed) .and. &
           same_id('Temperature (K)', seed) .and. same_id('x##1', seed) .and. same_id('##', seed) .and. &
           same_id('###', seed) .and. same_id('a##', seed)
   endif
   call ig_end()
   if (pf_plot_count() /= 10_int32) then
      write(output_unit, '(A,I0)') 'plots held by the frame: ', pf_plot_count()
      ok = .false.
   endif
   endfunction ids_ok

   function same_id(label, seed) result(same)
   !< A label's ID by figure_plot_hash and by Dear ImGui equal.
   character(len=*), intent(in) :: label !< Label.
   integer(int32),   intent(in) :: seed  !< The ID stack's top.
   logical                      :: same  !< Equal.

   same = plot_hash(label, seed) == core_get_id(label)
   if (.not. same) write(output_unit, '(A,A,A,2I12)') 'ID of "', label, '": ', plot_hash(label, seed), &
                                                      core_get_id(label)
   endfunction same_id

   pure function captured(k, fr) result(yes)
   !< The frames whose pictures are compared: the last, and the first of case 2 (before the fit).
   integer(int32), intent(in) :: k   !< Case.
   integer(int32), intent(in) :: fr  !< Frame.
   logical                    :: yes !< Captured.

   yes = fr == NF .or. (k == 2_int32 .and. fr == 1_int32)
   endfunction captured

   function plot_id(k) result(id)
   !< A case's plot ID.
   integer(int32), intent(in)    :: k   !< Case.
   character(len=:), allocatable :: id  !< ID.
   character(len=8)              :: tag !< The case's number.

   write(tag, '(I0)') k
   id = '##s'//trim(tag)
   endfunction plot_id

   function picture(k, fr, fortran) result(name)
   !< A case's picture of a frame: ImPlot's or the Fortran frame's.
   integer(int32), intent(in)    :: k       !< Case.
   integer(int32), intent(in)    :: fr      !< Frame.
   logical,        intent(in)    :: fortran !< The Fortran frame's.
   character(len=:), allocatable :: name    !< File name.
   character(len=16)             :: tag     !< The case's and frame's numbers.

   write(tag, '(I0,A,I0)') k, '.', fr
   if (fortran) then
      name = 'figure_test_plot_frame_state.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_state.'//trim(tag)//'.implot.png.tmp'
   endif
   endfunction picture

   subroutine remove_files()
   !< The pictures (a mismatch's .new.png and .diff.png are left for inspection).
   integer(int32) :: unit, ios, k, fr, m !< Unit, status, counters.

   do k = 1_int32, NCASE
      do fr = 1_int32, NF
         do m = 1_int32, 2_int32
            open(newunit=unit, file=picture(k, fr, m == 1_int32), status='old', iostat=ios)
            if (ios == 0) close(unit, status='delete')
         enddo
      enddo
   enddo
   endsubroutine remove_files
endprogram figure_test_plot_frame_state
