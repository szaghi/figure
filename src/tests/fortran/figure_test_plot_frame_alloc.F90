!< figure_test_plot_frame_alloc, the Fortran plot frame draws a frame without a heap allocation.
program figure_test_plot_frame_alloc
!< figure_test_plot_frame_alloc, the Fortran plot frame draws a frame without a heap allocation.
!<
!< szaghi/figure#15 P10, step 9 (ADR 0001: no allocation per item per frame in the core and the plot frame). A plot
!< with every per-frame string of the frame on: a title, axis labels, a log x axis, a time x axis (X2: dates on two
!< levels), a symlog y axis and a linear Y2, four labelled lines in the legend (one with square markers), a scatter
!< (P11), the pointer resting on the plot (the mouse text: values of four axes, a time among them), and beside it a
!< colour bar with a label format and a label; below them (P12) a 1 x 2 subplot, titled, its x axes linked, and two
!< plots side by side in an aligned group, their x axes linked in a group (`pf_link_axis`), the second with the four
!< drag tools (figure_plot_tools); tags on three of the plot's axes (`pf_tag`: a value labelled, a date, a text);
!< tick formats on the symlog Y1 and on Y2 (`%a` among them: the mouse text and the tag in them), and Y2's ticks given
!< with labels (`pf_setup_axis_ticks`); Y2's limit and zoom constraints (`pf_setup_axis_constraints`); the legend
!< sorted (`pf_setup_legend(sort=.true.)`), a legend entry's popup asked for (closed).
!< Drawn first by ImPlot through FIGURE's API (`ip_*`), then by the Fortran frame (`pf_*`), NF frames each: on the
!< Fortran side the last NCOUNT frames are counted, from `pf_begin_plot` to `pf_end_plot` and around
!< `pf_colormap_scale`, by figure_test_plot_alloc_counter (the C library's allocator entry points defined in the
!< program: every allocation of the thread, the Fortran run-time's, Dear ImGui's, the C++ library's), and must make
!< none. Checks:
!<
!< 1. no allocation on the counted frames (the stacks of the first ones are printed on standard error);
!< 2. the counter sees allocations: an ALLOCATE and a character concatenation of run-time length, counted (a counter
!<    blind to the compiler's run-time would pass check 1 for nothing);
!< 3. the pictures of the last frame of both sides equal at FIGURE's oracle rule (|d| <= 2, no pixel failing);
!< 4. the ranges of the last frame equal to the bit.
!<
!< The pictures are `figure_test_plot_frame_alloc.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : ip_begin_aligned, ip_begin_subplots, ip_end_aligned, ip_end_subplots, ip_link_axis
use figure, only : ip_drag_line_x, ip_drag_line_y, ip_drag_point, ip_drag_rect, ip_tag
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_same_line, ig_set_next_window, ip_begin_plot, &
                   ip_colormap_scale, ip_end_plot, ip_line, ip_plot_limits, ip_set_axes, ip_setup_axes,             &
                   ip_setup_axis, ip_setup_axis_limits, ip_spec, ip_scatter, ImGuiWindowFlags_NoDecoration
use figure, only : ip_setup_axis_ticks, ip_setup_axis_constraints, ip_begin_legend_popup, ip_end_legend_popup
use figure_cimplot, only : ImPlot_SetupLegend
use figure_cimplot_enums, only : ImPlotLegendFlags_Sort, ImPlotLocation_NorthWest
use figure_plot_frame, only : pf_begin_aligned, pf_begin_subplots, pf_end_aligned, pf_end_subplots, pf_link_axis
use figure_plot_frame, only : pf_tag, pf_setup_axis_ticks, pf_setup_axis_constraints, pf_setup_legend, &
                              pf_begin_legend_popup, pf_end_legend_popup
use figure_plot_frame, only : pf_begin_plot, pf_colormap_scale, pf_end_plot, pf_plot_limits, pf_set_axes, &
                              pf_setup_axes, pf_setup_axis, pf_setup_axis_limits
use figure_plot_items, only : pf_line, pf_scatter, pf_spec
use figure_plot_tools, only : pf_drag_line_x, pf_drag_line_y, pf_drag_point, pf_drag_rect
use figure_testing, only : test_capture, test_compare_image, test_mouse_move
use figure_test_plot_alloc_counter, only : alloc_arm, alloc_count, alloc_disarm

implicit none
integer(int32), parameter :: W = 640_int32      !< Display width [pixels].
integer(int32), parameter :: H = 800_int32      !< Display height [pixels].
integer(int32), parameter :: NF = 30_int32      !< Frames per side.
integer(int32), parameter :: NCOUNT = 10_int32  !< The last frames counted.
integer(int32), parameter :: NP = 201_int32     !< Points of a line.
real(real64),   parameter :: T0 = 1.6e9_real64  !< The time axis's start [s since the epoch].
real(real64),   parameter :: Y2T(3) = [0.5_real64, 1.75_real64, 3.0_real64] !< Y2's ticks.
character(len=4), parameter :: Y2L(3) = ['low ', 'mid ', 'high'] !< Their labels.
real(real64),   parameter :: C(4, 4) = reshape([0.91_real64, 0.40_real64, 0.30_real64, 1.0_real64,  &
                                                0.30_real64, 0.62_real64, 0.85_real64, 1.0_real64,  &
                                                0.35_real64, 0.75_real64, 0.40_real64, 1.0_real64,  &
                                                0.80_real64, 0.60_real64, 0.20_real64, 1.0_real64], [4, 4]) !< Colours.
type(app_object)          :: app                !< Application.
real(real64)              :: xs(NP), ts(NP), ys(NP, 4) !< The lines.
real(real64)              :: xd(21), yd(21)     !< The scatter (named arrays: nvfortran, see the report of P11 (a)).
real(real64)              :: lim(8, 2)          !< The last frame's ranges (X1, Y1, X2, Y2) per side.
integer(int64)            :: counted            !< Allocations on the counted frames.
integer(int64)            :: control            !< Allocations of the control.
logical                   :: test_passed(4)     !< Per-check outcome.
logical                   :: side_fortran       !< Drawing with the Fortran frame.
integer(int32)            :: f, s, sd, i        !< Frame, status, side, counter.
character(len=16)         :: keep               !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do i = 1_int32, NP
   xs(i) = 10.0_real64**(real(i - 1_int32, real64) * 0.02_real64)
   ts(i) = T0 + real(i - 1_int32, real64) * 1800.0_real64
   ys(i, 1) = 30.0_real64 * sin(real(i, real64) * 0.05_real64)
   ys(i, 2) = 0.5_real64 * cos(real(i, real64) * 0.04_real64 + 0.3_real64)
   ys(i, 3) = 2.0_real64 + sin(real(i, real64) * 0.03_real64)
   ys(i, 4) = 1.0_real64 + 0.5_real64 * cos(real(i, real64) * 0.07_real64)
enddo
xd = xs(::10)
yd = ys(::10, 1) * 0.5_real64
counted = 0_int64
lim = 0.0_real64
do sd = 1_int32, 2_int32 ! 1 ImPlot, 2 the Fortran frame
   side_fortran = sd == 2_int32
   do f = 1_int32, NF
      if (.not. app%next_frame()) error stop 'figure_test_plot_frame_alloc: next_frame returned false headless'
      call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
      if (ig_begin('plot frame alloc', flags=ImGuiWindowFlags_NoDecoration)) &
         call draw(f > NF - NCOUNT .and. side_fortran)
      call ig_end()
      if (f == NF) call test_capture(picture(side_fortran), s)
      if (f == 1_int32) call test_mouse_move(250.0_real64, 170.0_real64) ! resting on the plot from frame 2
   enddo
   call test_mouse_move(-100.0_real64, -100.0_real64)
   do i = 1_int32, 40_int32 ! as the other frame tests: the sides apart
      if (.not. app%next_frame()) error stop 'figure_test_plot_frame_alloc: next_frame returned false headless'
   enddo
enddo
control = control_count()
call app%destroy()
test_passed(1) = counted == 0_int64
test_passed(2) = control > 0_int64
test_passed(3) = pictures_equal()
test_passed(4) = all(lim(:, 1) == lim(:, 2))
if (.not. test_passed(1)) write(output_unit, '(A,I0,A,I0,A)') 'allocations on the ', NCOUNT, ' counted frames: ', &
                                                             counted, ' (stacks on standard error)'
if (.not. test_passed(2)) write(output_unit, '(A)') 'the counter saw no allocation of the control'
if (.not. test_passed(4)) then
   write(output_unit, '(A)') 'ranges of the last frame: ImPlot, frame'
   write(output_unit, '(4ES24.16)') lim(:, 1)
   write(output_unit, '(4ES24.16)') lim(:, 2)
endif
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_alloc checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine draw(count)
   !< The plot and the colour bar, by the side drawing; `count`: the frame's allocations counted.
   logical, intent(in) :: count !< Count.

   if (count) call alloc_arm()
   if (side_fortran) then
      if (pf_begin_plot('Allocations##alloc', width=520.0_real64, height=420.0_real64)) then
         call pf_setup_axes('x (log)', 'y (symlog)', xscale='log', yscale='symlog', yformat='%+.1f')
         call pf_setup_axis('x2', label='time', scale='time')
         call pf_setup_axis('y2', label='y2', format='%.2a')
         call pf_setup_axis_ticks('y2', Y2T, Y2L)
         call pf_setup_axis_constraints('y2', vmin=-1.0_real64, zoom_min=0.5_real64)
         call pf_setup_legend(sort=.true.)
         call pf_setup_axis_limits('x1', 1.0_real64, 1.0e4_real64)
         call pf_setup_axis_limits('y1', -40.0_real64, 40.0_real64)
         call pf_setup_axis_limits('x2', T0, ts(NP))
         call pf_setup_axis_limits('y2', 0.0_real64, 3.5_real64)
         call pf_line('wave', xs, ys(:, 1), spec=pf_spec(line_color=C(:, 1)))
         call pf_line('small', xs, ys(:, 2), spec=pf_spec(line_color=C(:, 2), marker=1_int32))
         call pf_scatter('dots', xd, yd, spec=pf_spec(marker=0_int32))
         call pf_set_axes('x2', 'y2')
         call pf_line('daily', ts, ys(:, 3), spec=pf_spec(line_color=C(:, 3)))
         call pf_line('hourly', ts, ys(:, 4), spec=pf_spec(line_color=C(:, 4)))
         call pf_tag('y1', 10.0_real64)
         call pf_tag('x2', ts(100), color=C(:, 2))
         call pf_tag('y2', 2.0_real64, text='level')
         call pf_tag('y2', 1.25_real64)
         if (pf_begin_legend_popup('wave')) call pf_end_legend_popup()
         call pf_plot_limits(lim(1, 2), lim(2, 2), lim(3, 2), lim(4, 2), 'x1', 'y1')
         call pf_plot_limits(lim(5, 2), lim(6, 2), lim(7, 2), lim(8, 2), 'x2', 'y2')
         call pf_end_plot()
      endif
   else
      if (ip_begin_plot('Allocations##alloc', width=520.0_real64, height=420.0_real64)) then
         call ip_setup_axes('x (log)', 'y (symlog)', xscale='log', yscale='symlog', yformat='%+.1f')
         call ip_setup_axis('x2', label='time', scale='time')
         call ip_setup_axis('y2', label='y2', format='%.2a')
         call ip_setup_axis_ticks('y2', Y2T, Y2L)
         call ip_setup_axis_constraints('y2', vmin=-1.0_real64, zoom_min=0.5_real64)
         call ImPlot_SetupLegend(ImPlotLocation_NorthWest, ImPlotLegendFlags_Sort)
         call ip_setup_axis_limits('x1', 1.0_real64, 1.0e4_real64)
         call ip_setup_axis_limits('y1', -40.0_real64, 40.0_real64)
         call ip_setup_axis_limits('x2', T0, ts(NP))
         call ip_setup_axis_limits('y2', 0.0_real64, 3.5_real64)
         call ip_line('wave', xs, ys(:, 1), spec=ip_spec(line_color=C(:, 1)))
         call ip_line('small', xs, ys(:, 2), spec=ip_spec(line_color=C(:, 2), marker=1_int32))
         call ip_scatter('dots', xd, yd, spec=ip_spec(marker=0_int32))
         call ip_set_axes('x2', 'y2')
         call ip_line('daily', ts, ys(:, 3), spec=ip_spec(line_color=C(:, 3)))
         call ip_line('hourly', ts, ys(:, 4), spec=ip_spec(line_color=C(:, 4)))
         call ip_tag('y1', 10.0_real64)
         call ip_tag('x2', ts(100), color=C(:, 2))
         call ip_tag('y2', 2.0_real64, text='level')
         call ip_tag('y2', 1.25_real64)
         if (ip_begin_legend_popup('wave')) call ip_end_legend_popup()
         call ip_plot_limits(lim(1, 1), lim(2, 1), lim(3, 1), lim(4, 1), 'x1', 'y1')
         call ip_plot_limits(lim(5, 1), lim(6, 1), lim(7, 1), lim(8, 1), 'x2', 'y2')
         call ip_end_plot()
      endif
   endif
   if (count) call pause()
   call ig_same_line()
   if (count) call alloc_arm() ! its count reset: `pause` kept the plot's
   if (side_fortran) then
      call pf_colormap_scale('Temperature', 250.0_real64, 310.0_real64, height=420.0_real64, label_format='%.1f K')
   else
      call ip_colormap_scale('Temperature', 250.0_real64, 310.0_real64, height=420.0_real64, label_format='%.1f K')
   endif
   if (count) call pause()
   if (count) call alloc_arm()
   call cells()
   if (count) call pause()
   endsubroutine draw

   subroutine cells()
   !< A 1 x 2 subplot with linked x axes and two aligned plots side by side (P12), by the side drawing.
   integer(int32) :: k !< Cell.
   real(real64)   :: tv(8) = [20.0_real64, 1.2_real64, 50.0_real64, 0.8_real64, 100.0_real64, 400.0_real64, &
                              0.9_real64, 1.3_real64] !< The drag tools' values (kept: the pointer never moves them).
   logical        :: moved !< A tool moved.


   if (side_fortran) then
      if (pf_begin_subplots('Cells', 1_int32, 2_int32, height=150.0_real64, link_x=.true.)) then
         do k = 1_int32, 2_int32
            if (pf_begin_plot(merge('##c1', '##c2', k == 1_int32))) then
               call pf_line('##w', xs(1:60 * k), ys(1:60 * k, k), spec=pf_spec(line_color=C(:, k)))
               call pf_end_plot()
            endif
         enddo
         call pf_end_subplots()
      endif
      if (pf_begin_aligned('pair', horizontal=.true.)) then
         if (pf_begin_plot('##a1', width=300.0_real64, height=150.0_real64)) then
            call pf_setup_axes('x', '')
            call pf_link_axis('x1', 'pair x')
            call pf_line('##w', xs, ys(:, 3), spec=pf_spec(line_color=C(:, 3)))
            call pf_end_plot()
         endif
         call ig_same_line()
         if (pf_begin_plot('##a2', width=300.0_real64, height=150.0_real64)) then
            call pf_link_axis('x1', 'pair x')
            call pf_line('##w', xs, ys(:, 4), spec=pf_spec(line_color=C(:, 4)))
            moved = pf_drag_line_x(1_int32, tv(1))
            moved = pf_drag_line_y(2_int32, tv(2), color=C(:, 1), thickness=2.0_real64)
            moved = pf_drag_point(3_int32, tv(3), tv(4), radius=5.0_real64)
            moved = pf_drag_rect(4_int32, tv(5), tv(6), tv(7), tv(8), color=C(:, 2))
            call pf_end_plot()
         endif
         call pf_end_aligned()
      endif
   else
      if (ip_begin_subplots('Cells', 1_int32, 2_int32, height=150.0_real64, link_x=.true.)) then
         do k = 1_int32, 2_int32
            if (ip_begin_plot(merge('##c1', '##c2', k == 1_int32))) then
               call ip_line('##w', xs(1:60 * k), ys(1:60 * k, k), spec=ip_spec(line_color=C(:, k)))
               call ip_end_plot()
            endif
         enddo
         call ip_end_subplots()
      endif
      if (ip_begin_aligned('pair', horizontal=.true.)) then
         if (ip_begin_plot('##a1', width=300.0_real64, height=150.0_real64)) then
            call ip_setup_axes('x', '')
            call ip_link_axis('x1', 'pair x')
            call ip_line('##w', xs, ys(:, 3), spec=ip_spec(line_color=C(:, 3)))
            call ip_end_plot()
         endif
         call ig_same_line()
         if (ip_begin_plot('##a2', width=300.0_real64, height=150.0_real64)) then
            call ip_link_axis('x1', 'pair x')
            call ip_line('##w', xs, ys(:, 4), spec=ip_spec(line_color=C(:, 4)))
            moved = ip_drag_line_x(1_int32, tv(1))
            moved = ip_drag_line_y(2_int32, tv(2), color=C(:, 1), thickness=2.0_real64)
            moved = ip_drag_point(3_int32, tv(3), tv(4), radius=5.0_real64)
            moved = ip_drag_rect(4_int32, tv(5), tv(6), tv(7), tv(8), color=C(:, 2))
            call ip_end_plot()
         endif
         call ip_end_aligned()
      endif
   endif
   endsubroutine cells

   subroutine pause()
   !< The counting stopped, its count kept.

   call alloc_disarm()
   counted = counted + alloc_count()
   endsubroutine pause

   function control_count() result(n)
   !< The allocations the counter sees of an ALLOCATE and of a concatenation of run-time length.
   integer(int64)                :: n    !< Allocations.
   real(real64),     allocatable :: a(:) !< An array.
   character(len=:), allocatable :: t    !< A text.
   integer(int32)                :: k    !< Its length.

   k = NP + int(xs(2), int32) ! run-time
   call alloc_arm()
   allocate(a(k))
   a = xs(1:k)
   t = repeat('x', k)//'y'
   call alloc_disarm()
   n = alloc_count()
   if (len(t) /= k + 1_int32 .or. a(k) /= xs(k)) n = -1_int64 ! used: not optimised away
   endfunction control_count

   function pictures_equal() result(ok)
   !< Both sides' pictures equal at the oracle's rule.
   logical        :: ok  !< Equal.
   integer(int64) :: nf_ !< Pixels that failed.
   integer(int32) :: st  !< Status.

   ok = test_compare_image(picture(.true.), picture(.false.), threshold=2_int32, max_failed=0_int32, failed=nf_, &
                           stat=st)
   if (.not. ok) write(output_unit, '(A,I0,A,A)') 'pictures: ', nf_, ' pixels failed: ', figure_last_error()
   endfunction pictures_equal

   function picture(fortran) result(name)
   !< The picture of ImPlot's side or the Fortran frame's.
   logical,          intent(in)  :: fortran !< The Fortran frame's.
   character(len=:), allocatable :: name    !< File name.

   if (fortran) then
      name = 'figure_test_plot_frame_alloc.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_alloc.implot.png.tmp'
   endif
   endfunction picture

   subroutine remove_files()
   !< The pictures (a mismatch's .new.png and .diff.png are left for inspection).
   integer(int32) :: unit, ios, m !< Unit, status, side.

   do m = 1_int32, 2_int32
      open(newunit=unit, file=picture(m == 1_int32), status='old', iostat=ios)
      if (ios == 0) close(unit, status='delete')
   enddo
   endsubroutine remove_files
endprogram figure_test_plot_frame_alloc
