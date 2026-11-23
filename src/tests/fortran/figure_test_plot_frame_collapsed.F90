!< figure_test_plot_frame_collapsed, the Fortran plot frame in a collapsed window, as ImPlot's (`SkipItems`).
program figure_test_plot_frame_collapsed
!< figure_test_plot_frame_collapsed, the Fortran plot frame in a collapsed window, as ImPlot's (`SkipItems`).
!<
!< szaghi/figure#15 P12 (what P10-P12 left, night 2026-11-23 step 11). A window collapsed on its first four frames,
!< then opened, holding a plot, a 1 x 2 subplot, two aligned plots, a colour bar and a colour-scale legend, drawn on
!< every frame whatever its begin returned (a program may), first with FIGURE's current path (`ip_*`: ImPlot's
!< `BeginPlot`, `BeginSubplots`, `BeginAlignedPlots`, `ColormapScale` and FIGURE's legend return false or draw nothing
!< while the window's items are skipped), then with the Fortran frame (`pf_*`: figure_core's `core_window_collapsed`),
!< 40 frames apart. Checked: what each begin returned on every frame, equal; the pictures collapsed and opened (the
!< plots' first fit made on the first frame they are drawn), at FIGURE's oracle rule.
!<
!< The pictures are `figure_test_plot_frame_collapsed.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: iso_c_binding, only : c_bool
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_same_line, ig_set_next_window, ip_begin_aligned, &
                   ip_begin_plot, ip_begin_subplots, ip_colormap, ip_colormap_legend, ip_colormap_scale,               &
                   ip_end_aligned, ip_end_plot, ip_end_subplots, ip_line, ip_spec
use figure_cimgui, only : igSetNextWindowCollapsed
use figure_cimgui_enums, only : ImGuiCond_Always
use figure_plot_colorbar, only : pf_colormap_legend
use figure_plot_colormaps, only : cm_colormap
use figure_plot_frame, only : pf_begin_aligned, pf_begin_plot, pf_begin_subplots, pf_colormap_scale, pf_end_aligned, &
                              pf_end_plot, pf_end_subplots
use figure_plot_items, only : pf_line, pf_spec
use figure_testing, only : test_capture, test_compare_image, test_mouse_move

implicit none
integer(int32), parameter :: W = 700_int32      !< Display width [pixels].
integer(int32), parameter :: H = 560_int32      !< Display height [pixels].
integer(int32), parameter :: NF = 8_int32       !< Frames per side.
integer(int32), parameter :: NP = 101_int32     !< Points of a line.
real(real64),   parameter :: C1(4) = [0.91_real64, 0.40_real64, 0.30_real64, 1.0_real64] !< A colour.
type(app_object)          :: app                !< Application.
real(real64)              :: xs(NP), ys(NP)     !< A line.
logical                   :: got(5, NF, 2)      !< What each begin returned, per frame and side.
logical                   :: side_fortran, ok(3) !< Drawing with the Fortran frame, the checks.
integer(int32)            :: f, s, sd, i        !< Frame, status, side, counter.
character(len=16)         :: keep               !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do i = 1_int32, NP
   xs(i) = real(i - 1_int32, real64) * 0.1_real64
   ys(i) = sin(xs(i))
enddo
got = .false.
do sd = 1_int32, 2_int32 ! 1 the current path, 2 the Fortran frame
   side_fortran = sd == 2_int32
   do f = 1_int32, NF
      if (.not. app%next_frame()) error stop 'figure_test_plot_frame_collapsed: next_frame returned false headless'
      call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
      if (f == 1_int32) call igSetNextWindowCollapsed(.true._c_bool, ImGuiCond_Always)
      if (f == 5_int32) call igSetNextWindowCollapsed(.false._c_bool, ImGuiCond_Always)
      if (ig_begin('collapsible')) continue
      call draw(got(:, f, sd)) ! whatever ig_begin returned
      call ig_end()
      if (f == 4_int32) call test_capture(picture(1_int32, side_fortran), s)
      if (f == NF) call test_capture(picture(2_int32, side_fortran), s)
   enddo
   do i = 1_int32, 40_int32
      if (.not. app%next_frame()) error stop 'figure_test_plot_frame_collapsed: next_frame returned false headless'
   enddo
enddo
ok(1) = all(got(:, :, 1) .eqv. got(:, :, 2))
if (.not. ok(1)) then
   do f = 1_int32, NF
      write(output_unit, '(A,I0,A,5L2,A,5L2)') 'frame ', f, ': current', got(:, f, 1), ', frame', got(:, f, 2)
   enddo
endif
ok(2) = .not. any(got(1:3, 1:4, 1)) .and. all(got(1:3, 5:NF, 1)) ! false collapsed, true opened (current path)
ok(3) = pictures_equal(1_int32) .and. pictures_equal(2_int32)
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_collapsed checks:', ok
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(ok)
if (.not. all(ok)) error stop 1

contains
   subroutine draw(v)
   !< The window's content, by the side drawing: v what the plot's, the subplot's and the aligned group's begins
   !< returned.
   logical, intent(inout) :: v(:) !< Begins.
   integer(int32)         :: k    !< Cell, plot.

   if (side_fortran) then
      v(1) = pf_begin_plot('Plot##cl', width=420.0_real64, height=200.0_real64)
      if (v(1)) then
         call pf_line('sine', xs, ys, spec=pf_spec(line_color=C1))
         call pf_end_plot()
      endif
      call ig_same_line()
      call pf_colormap_scale('bar', -1.0_real64, 1.0_real64, height=200.0_real64)
      call ig_same_line()
      call pf_colormap_legend('##leg', cm_colormap('Viridis'), 0.0_real64, 1.0_real64, height=200.0_real64)
      v(2) = pf_begin_subplots('Cells##cl', 1_int32, 2_int32, height=140.0_real64)
      if (v(2)) then
         do k = 1_int32, 2_int32
            if (pf_begin_plot(merge('##c1', '##c2', k == 1_int32))) then
               call pf_line('##s', xs, ys, spec=pf_spec(line_color=C1))
               call pf_end_plot()
            endif
         enddo
         call pf_end_subplots()
      endif
      v(3) = pf_begin_aligned('pair##cl', horizontal=.true.)
      if (v(3)) then
         do k = 1_int32, 2_int32
            if (k == 2_int32) call ig_same_line()
            if (pf_begin_plot(merge('##a1', '##a2', k == 1_int32), width=300.0_real64, height=140.0_real64)) then
               call pf_line('##s', xs, ys, spec=pf_spec(line_color=C1))
               call pf_end_plot()
            endif
         enddo
         call pf_end_aligned()
      endif
   else
      v(1) = ip_begin_plot('Plot##cl', width=420.0_real64, height=200.0_real64)
      if (v(1)) then
         call ip_line('sine', xs, ys, spec=ip_spec(line_color=C1))
         call ip_end_plot()
      endif
      call ig_same_line()
      call ip_colormap_scale('bar', -1.0_real64, 1.0_real64, height=200.0_real64)
      call ig_same_line()
      call ip_colormap_legend('##leg', ip_colormap('Viridis'), 0.0_real64, 1.0_real64, height=200.0_real64)
      v(2) = ip_begin_subplots('Cells##cl', 1_int32, 2_int32, height=140.0_real64)
      if (v(2)) then
         do k = 1_int32, 2_int32
            if (ip_begin_plot(merge('##c1', '##c2', k == 1_int32))) then
               call ip_line('##s', xs, ys, spec=ip_spec(line_color=C1))
               call ip_end_plot()
            endif
         enddo
         call ip_end_subplots()
      endif
      v(3) = ip_begin_aligned('pair##cl', horizontal=.true.)
      if (v(3)) then
         do k = 1_int32, 2_int32
            if (k == 2_int32) call ig_same_line()
            if (ip_begin_plot(merge('##a1', '##a2', k == 1_int32), width=300.0_real64, height=140.0_real64)) then
               call ip_line('##s', xs, ys, spec=ip_spec(line_color=C1))
               call ip_end_plot()
            endif
         enddo
         call ip_end_aligned()
      endif
   endif
   endsubroutine draw

   function pictures_equal(k) result(eq)
   !< The k-th pictures of both sides equal at the oracle's rule.
   integer(int32), intent(in) :: k   !< Picture.
   logical                    :: eq  !< Equal.
   integer(int64)             :: nf_ !< Pixels that failed.
   integer(int32)             :: st  !< Status.

   eq = test_compare_image(picture(k, .true.), picture(k, .false.), threshold=2_int32, max_failed=0_int32, &
                           failed=nf_, stat=st)
   if (.not. eq) write(output_unit, '(A,I0,A,I0,A,A)') 'picture ', k, ': ', nf_, ' pixels failed: ', figure_last_error()
   endfunction pictures_equal

   function picture(k, fortran) result(name)
   !< The k-th picture: the current path's or the Fortran frame's.
   integer(int32), intent(in)    :: k       !< Picture.
   logical,        intent(in)    :: fortran !< The Fortran frame's.
   character(len=:), allocatable :: name    !< File name.
   character(len=8)              :: tag     !< Its number.

   write(tag, '(I0)') k
   if (fortran) then
      name = 'figure_test_plot_frame_collapsed.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_collapsed.'//trim(tag)//'.implot.png.tmp'
   endif
   endfunction picture

   subroutine remove_files()
   !< The pictures (a mismatch's .new.png and .diff.png are left for inspection).
   integer(int32) :: unit, ios, k, m !< Unit, status, counters.

   do k = 1_int32, 2_int32
      do m = 1_int32, 2_int32
         open(newunit=unit, file=picture(k, m == 1_int32), status='old', iostat=ios)
         if (ios == 0) close(unit, status='delete')
      enddo
   enddo
   endsubroutine remove_files
endprogram figure_test_plot_frame_collapsed
