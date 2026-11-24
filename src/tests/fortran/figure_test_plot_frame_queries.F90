!< figure_test_plot_frame_queries, the Fortran plot frame's state queries and recovery, as ImPlot's through FIGURE.
program figure_test_plot_frame_queries
!< figure_test_plot_frame_queries, the Fortran plot frame's state queries and recovery, as ImPlot's through FIGURE.
!<
!< szaghi/figure#15 P10 (what P10-P12 left, night 2026-11-23 step 05). Each case is drawn first by ImPlot through
!< FIGURE's API and its native queries (`ip_plot_size`: `GetPlotSize`; `fig_plot_state`; `fig_plot_x_transform`), then
!< by the Fortran frame (`pf_plot_size`, `pf_plot_state`, `pf_plot_x_transform`, `pf_open_state`, `pf_recover_to`),
!< 40 frames apart. Checked on every frame: the queries' values and the ranges of X1 and Y1, equal to the bit; the
!< pictures of the last frame at FIGURE's oracle rule (|d| <= 2, no pixel failing). The cases:
!<
!< 1. a plot with a log X1, a symlog Y1, an X2 (time) and a Y2: the state before the setup ends (1), the plot's size
!<    (it ends the setup), the state after (2), the axes set up and their scales, X1's transform, then X2's after
!<    `set_axes`;
!< 2. a 1 x 2 subplot whose second cell's plot and the subplot are left open, ended by `pf_recover_to` from the
!<    snapshot taken before the subplot (as FIGURE's error recovery ends them: `fig_plot_end`, `EndSubplots`), against
!<    ImPlot's side ended by `ip_end_plot`, `ip_end_subplots`;
!< 3. a plot left open and recovered, a plot after it drawn as usual.
!<
!< The pictures are `figure_test_plot_frame_queries.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them; a
!< mismatch's .new.png and .diff.png are left for inspection).
use, intrinsic :: iso_c_binding, only : c_double, c_int
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ImGuiWindowFlags_NoDecoration
use figure_implot_ref, only : ip_begin_plot, ip_end_plot, ip_line, ip_plot_limits, ip_plot_size, ip_set_axes, &
                              ip_setup_axes, ip_setup_axes_limits, ip_setup_axis, ip_spec, ip_begin_subplots, &
                              ip_end_subplots
use figure_c_native, only : fig_plot_state, fig_plot_x_transform
use figure_plot_frame, only : pf_begin_plot, pf_end_plot, pf_plot_limits, pf_plot_size, pf_set_axes, pf_setup_axes, &
                              pf_setup_axes_limits, pf_setup_axis, pf_plot_state, pf_plot_x_transform,               &
                              pf_open_state, pf_recover_to, pf_begin_subplots, pf_end_subplots
use figure_plot_items, only : pf_line, pf_spec
use figure_testing, only : test_capture, test_compare_image, test_mouse_move

implicit none
integer(int32), parameter :: W = 640_int32      !< Display width [pixels].
integer(int32), parameter :: H = 440_int32      !< Display height [pixels].
integer(int32), parameter :: NCASE = 3_int32    !< Cases.
integer(int32), parameter :: NF = 3_int32       !< Frames per side.
integer(int32), parameter :: NP = 201_int32     !< Points of a line.
integer(int32), parameter :: NSTATE = 64_int32  !< Values checked per frame.
real(real64),   parameter :: T0 = 1.6e9_real64  !< The time axis's start [s since the epoch].
real(real64),   parameter :: C1(4) = [0.91_real64, 0.40_real64, 0.30_real64, 1.0_real64] !< A colour.
real(real64),   parameter :: C2(4) = [0.30_real64, 0.62_real64, 0.85_real64, 1.0_real64] !< Another.
type(app_object)          :: app                !< Application.
real(real64)              :: xs(NP), ys(NP), lx(NP), ts(NP) !< The lines.
real(real64)              :: state(NSTATE, NF, 2) !< Per frame and side.
logical                   :: test_passed(NCASE) !< Per-case outcome.
logical                   :: side_fortran       !< Drawing with the Fortran frame.
integer(int32)            :: c, f, s, sd, i     !< Case, frame, status, side, counter.
character(len=16)         :: keep               !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do i = 1_int32, NP
   xs(i) = real(i - 1_int32, real64) * 0.05_real64
   ys(i) = 20.0_real64 * sin(xs(i))
   lx(i) = 10.0_real64**(xs(i) * 0.4_real64)
   ts(i) = T0 + real(i - 1_int32, real64) * 1800.0_real64
enddo
do c = 1_int32, NCASE
   state = 0.0_real64
   do sd = 1_int32, 2_int32 ! 1 ImPlot, 2 the Fortran frame
      side_fortran = sd == 2_int32
      do f = 1_int32, NF
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_queries: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('plot frame queries', flags=ImGuiWindowFlags_NoDecoration)) then
            if (side_fortran) then
               call draw_fortran(c, state(:, f, 2))
            else
               call draw_implot(c, state(:, f, 1))
            endif
         endif
         call ig_end()
         if (f == NF) call test_capture(picture(c, side_fortran), s)
      enddo
      do i = 1_int32, 40_int32 ! as the other frame tests: the sides apart
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_queries: next_frame returned false headless'
      enddo
   enddo
   test_passed(c) = state_equal(c) .and. pictures_equal(c)
enddo
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_queries checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine draw_implot(k, v)
   !< A case by ImPlot (FIGURE's API and native queries).
   integer(int32), intent(in)    :: k    !< Case.
   real(real64),   intent(inout) :: v(:) !< State.
   integer(c_int)                :: on(6), sc(6), st, xs_ !< The plot's state, the transform's scale.
   real(c_double)                :: tr(9) !< The transform.
   integer(int32)                :: j     !< Cell.

   select case (k)
   case (1_int32)
      if (.not. ip_begin_plot('##qy1', width=600.0_real64, height=400.0_real64)) return
      call ip_setup_axes('', '', xscale='log', yscale='symlog')
      call ip_setup_axis('x2', scale='time')
      call ip_setup_axis('y2')
      call ip_setup_axes_limits(1.0_real64, 1.0e4_real64, -30.0_real64, 30.0_real64)
      st = fig_plot_state(on, sc)
      v(1) = real(st, real64)
      v(2:7) = real(on, real64)
      v(8:13) = real(sc, real64)
      call ip_plot_size(v(14), v(15))
      st = fig_plot_state(on, sc)
      v(16) = real(st, real64)
      st = fig_plot_x_transform(tr, xs_)
      v(17:25) = tr
      v(26) = real(xs_ + 10_c_int * st, real64)
      call ip_line('##log', lx, ys, spec=ip_spec(line_color=C1))
      call ip_set_axes('x2', 'y2')
      st = fig_plot_x_transform(tr, xs_)
      v(27:35) = tr
      v(36) = real(xs_ + 10_c_int * st, real64)
      call ip_line('##time', ts, ys, spec=ip_spec(line_color=C2))
      call ip_plot_limits(v(37), v(38), v(39), v(40), 'x1', 'y1')
      call ip_end_plot()
   case (2_int32)
      if (ip_begin_subplots('Recovered', 1_int32, 2_int32, height=400.0_real64)) then
         do j = 1_int32, 2_int32
            if (ip_begin_plot(merge('##c1', '##c2', j == 1_int32))) then
               call ip_line('##s', xs, ys * real(j, real64), spec=ip_spec(line_color=C1))
               call ip_plot_limits(v(4 * j - 3), v(4 * j - 2), v(4 * j - 1), v(4 * j), 'x1', 'y1')
               call ip_end_plot()
            endif
         enddo
         call ip_end_subplots()
      endif
      st = fig_plot_state(on, sc)
      v(9) = real(st, real64)
   case default
      if (ip_begin_plot('##qy3', width=600.0_real64, height=180.0_real64)) then
         call ip_line('##s', xs, ys, spec=ip_spec(line_color=C1))
         call ip_plot_limits(v(1), v(2), v(3), v(4), 'x1', 'y1')
         call ip_end_plot()
      endif
      if (ip_begin_plot('##qy4', width=600.0_real64, height=180.0_real64)) then
         call ip_line('##c', xs, -ys, spec=ip_spec(line_color=C2))
         call ip_plot_limits(v(5), v(6), v(7), v(8), 'x1', 'y1')
         call ip_end_plot()
      endif
   endselect
   endsubroutine draw_implot

   subroutine draw_fortran(k, v)
   !< A case by the Fortran frame.
   integer(int32), intent(in)    :: k    !< Case.
   real(real64),   intent(inout) :: v(:) !< State.
   integer(int32)                :: on(6), sc(6), st, xs_ !< The plot's state, the transform's scale.
   real(real64)                  :: tr(9) !< The transform.
   integer(int32)                :: j     !< Cell.
   logical                       :: p0, s0 !< The snapshot: a plot, a subplot open.

   select case (k)
   case (1_int32)
      if (.not. pf_begin_plot('##qy1', width=600.0_real64, height=400.0_real64)) return
      call pf_setup_axes('', '', xscale='log', yscale='symlog')
      call pf_setup_axis('x2', scale='time')
      call pf_setup_axis('y2')
      call pf_setup_axes_limits(1.0_real64, 1.0e4_real64, -30.0_real64, 30.0_real64)
      st = pf_plot_state(on, sc)
      v(1) = real(st, real64)
      v(2:7) = real(on, real64)
      v(8:13) = real(sc, real64)
      call pf_plot_size(v(14), v(15))
      st = pf_plot_state(on, sc)
      v(16) = real(st, real64)
      st = pf_plot_x_transform(tr, xs_)
      v(17:25) = tr
      v(26) = real(xs_ + 10_int32 * st, real64)
      call pf_line('##log', lx, ys, spec=pf_spec(line_color=C1))
      call pf_set_axes('x2', 'y2')
      st = pf_plot_x_transform(tr, xs_)
      v(27:35) = tr
      v(36) = real(xs_ + 10_int32 * st, real64)
      call pf_line('##time', ts, ys, spec=pf_spec(line_color=C2))
      call pf_plot_limits(v(37), v(38), v(39), v(40), 'x1', 'y1')
      call pf_end_plot()
   case (2_int32)
      call pf_open_state(p0, s0)
      if (pf_begin_subplots('Recovered', 1_int32, 2_int32, height=400.0_real64)) then
         do j = 1_int32, 2_int32
            if (pf_begin_plot(merge('##c1', '##c2', j == 1_int32))) then
               call pf_line('##s', xs, ys * real(j, real64), spec=pf_spec(line_color=C1))
               call pf_plot_limits(v(4 * j - 3), v(4 * j - 2), v(4 * j - 1), v(4 * j), 'x1', 'y1')
               if (j == 1_int32) call pf_end_plot() ! the second left open, and the subplot
            endif
         enddo
         call pf_recover_to(p0, s0)
      endif
      st = pf_plot_state(on, sc)
      v(9) = real(st, real64)
   case default
      call pf_open_state(p0, s0)
      if (pf_begin_plot('##qy3', width=600.0_real64, height=180.0_real64)) then
         call pf_line('##s', xs, ys, spec=pf_spec(line_color=C1))
         call pf_plot_limits(v(1), v(2), v(3), v(4), 'x1', 'y1')
         call pf_recover_to(p0, s0) ! left open: recovered
      endif
      if (pf_begin_plot('##qy4', width=600.0_real64, height=180.0_real64)) then
         call pf_line('##c', xs, -ys, spec=pf_spec(line_color=C2))
         call pf_plot_limits(v(5), v(6), v(7), v(8), 'x1', 'y1')
         call pf_end_plot()
      endif
   endselect
   endsubroutine draw_fortran

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

   function pictures_equal(k) result(ok)
   !< A case's pictures of both sides equal at the oracle's rule.
   integer(int32), intent(in) :: k   !< Case.
   logical                    :: ok  !< Equal.
   integer(int64)             :: nf_ !< Pixels that failed.
   integer(int32)             :: st  !< Status.

   ok = test_compare_image(picture(k, .true.), picture(k, .false.), threshold=2_int32, max_failed=0_int32, &
                           failed=nf_, stat=st)
   if (.not. ok) write(output_unit, '(A,I0,A,I0,A,A)') 'case ', k, ': ', nf_, ' pixels failed: ', figure_last_error()
   endfunction pictures_equal

   function picture(k, fortran) result(name)
   !< A case's picture: ImPlot's or the Fortran frame's.
   integer(int32), intent(in)    :: k       !< Case.
   logical,        intent(in)    :: fortran !< The Fortran frame's.
   character(len=:), allocatable :: name    !< File name.
   character(len=8)              :: tag     !< The case's number.

   write(tag, '(I0)') k
   if (fortran) then
      name = 'figure_test_plot_frame_queries.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_queries.'//trim(tag)//'.implot.png.tmp'
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
endprogram figure_test_plot_frame_queries
