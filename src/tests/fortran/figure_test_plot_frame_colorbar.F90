!< figure_test_plot_frame_colorbar, the Fortran plot frame's colour-scale legend, as FIGURE's `ip_colormap_legend`.
program figure_test_plot_frame_colorbar
!< figure_test_plot_frame_colorbar, the Fortran plot frame's colour-scale legend, as FIGURE's `ip_colormap_legend`.
!<
!< szaghi/figure#15 P10 (what P10-P12 left, night 2026-11-23 step 07). Each case draws legends first with FIGURE's
!< current path (`ip_colormap_legend`, `ip_colormap_legend_edit`: native/figure_colormap.cpp), then with the Fortran
!< frame (`pf_colormap_legend`, `pf_colormap_legend_edit`), 40 frames apart, the same scripted input on both sides.
!< Checked: the pictures of the last frame at FIGURE's oracle rule (|d| <= 2, no pixel failing) and, for the edited
!< legend, its range on every frame to the bit. The cases:
!<
!< 1. vertical, continuous, linear, the default size and "%g"; beside it 8 levels labelled '%.0f' (the edges' digits
!<    raised: 12.5, 37.5), a given width and height;
!< 2. horizontal on a log scale, the room left (width < 0), continuous, and 5 levels of a reversed range;
!< 3. symlog continuous, ticks thinned to their labels' room; a text format; '%+.2e' edges;
!< 4. the edited legend: a drag along the bar (the range moves), the wheel over it (zoomed about the pointer), on a log
!<    scale.
!<
!< The pictures are `figure_test_plot_frame_colorbar.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_same_line, ig_set_next_window, &
                   ImGuiWindowFlags_NoDecoration
use figure_implot_ref, only : ip_colormap, ip_colormap_legend, ip_colormap_legend_edit
use figure_plot_colorbar, only : pf_colormap_legend, pf_colormap_legend_edit
use figure_plot_colormaps, only : cm_colormap
use figure_testing, only : test_capture, test_compare_image, test_drag, test_mouse_move, test_wheel

implicit none
integer(int32), parameter :: W = 640_int32      !< Display width [pixels].
integer(int32), parameter :: H = 440_int32      !< Display height [pixels].
integer(int32), parameter :: NCASE = 4_int32    !< Cases.
integer(int32), parameter :: NF = 16_int32      !< Frames per side.
type(app_object)          :: app                !< Application.
real(real64)              :: state(2, NF, 2)    !< The edited range per frame and side.
real(real64)              :: rng(2)             !< The edited range.
logical                   :: test_passed(NCASE) !< Per-case outcome.
logical                   :: side_fortran       !< Drawing with the Fortran frame.
integer(int32)            :: c, f, s, sd, i     !< Case, frame, status, side, counter.
character(len=16)         :: keep               !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do c = 1_int32, NCASE
   state = 0.0_real64
   do sd = 1_int32, 2_int32 ! 1 the current path, 2 the Fortran frame
      side_fortran = sd == 2_int32
      rng = [1.0e-2_real64, 1.0e3_real64]
      do f = 1_int32, NF
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_colorbar: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('plot frame colorbar', flags=ImGuiWindowFlags_NoDecoration)) call draw_case(c)
         call ig_end()
         state(:, f, sd) = rng
         if (f == NF) call test_capture(picture(c, side_fortran), s)
         if (c == 4_int32) call pointer(f)
      enddo
      call test_mouse_move(-100.0_real64, -100.0_real64)
      do i = 1_int32, 40_int32
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_colorbar: next_frame returned false headless'
      enddo
   enddo
   test_passed(c) = pictures_equal(c)
   if (c == 4_int32) then
      test_passed(c) = test_passed(c) .and. all(state(:, :, 1) == state(:, :, 2)) .and. &
                       any(state(:, NF, 1) /= [1.0e-2_real64, 1.0e3_real64])
      if (.not. all(state(:, :, 1) == state(:, :, 2))) then
         write(output_unit, '(A)') 'edited range: current path, frame'
         write(output_unit, '(4ES24.16)') (state(:, i, 1), state(:, i, 2), i=1, NF)
      endif
   endif
enddo
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_colorbar checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine pointer(fr)
   !< Case 4's input after a frame: a drag along the bar, then the wheel over it.
   integer(int32), intent(in) :: fr !< Frame.

   if (fr == 2_int32) call test_drag(16.0_real64, 200.0_real64, 16.0_real64, 140.0_real64)
   if (fr == 8_int32) call test_mouse_move(16.0_real64, 100.0_real64)
   if (fr == 10_int32 .or. fr == 11_int32) call test_wheel(1.0_real64)
   if (fr == 13_int32) call test_wheel(-2.0_real64)
   endsubroutine pointer

   subroutine draw_case(k)
   !< A case's legends, by the side drawing.
   integer(int32), intent(in) :: k !< Case.
   logical                    :: moved !< The edited range changed.

   select case (k)
   case (1_int32)
      if (side_fortran) then
         call pf_colormap_legend('##l1', cm_colormap('Viridis'), -3.7_real64, 12.2_real64)
         call ig_same_line()
         call pf_colormap_legend('##l2', cm_colormap('turbo', 8_int32), 0.0_real64, 100.0_real64, levels=8_int32, &
                                 width=90.0_real64, height=380.0_real64, label_format='%.0f')
      else
         call ip_colormap_legend('##l1', ip_colormap('Viridis'), -3.7_real64, 12.2_real64)
         call ig_same_line()
         call ip_colormap_legend('##l2', ip_colormap('turbo', 8_int32), 0.0_real64, 100.0_real64, levels=8_int32, &
                                 width=90.0_real64, height=380.0_real64, label_format='%.0f')
      endif
   case (2_int32)
      if (side_fortran) then
         call pf_colormap_legend('##l3', cm_colormap('Plasma'), 1.0e-3_real64, 1.0e4_real64, horizontal=.true., &
                                 width=-1.0_real64, scale='log')
         call pf_colormap_legend('##l4', cm_colormap('balance_r', 5_int32), 2.5_real64, -2.5_real64, levels=5_int32, &
                                 horizontal=.true., width=500.0_real64, label_format='%g units')
      else
         call ip_colormap_legend('##l3', ip_colormap('Plasma'), 1.0e-3_real64, 1.0e4_real64, horizontal=.true., &
                                 width=-1.0_real64, scale='log')
         call ip_colormap_legend('##l4', ip_colormap('balance_r', 5_int32), 2.5_real64, -2.5_real64, levels=5_int32, &
                                 horizontal=.true., width=500.0_real64, label_format='%g units')
      endif
   case (3_int32)
      if (side_fortran) then
         call pf_colormap_legend('##l5', cm_colormap('RdBu'), -1000.0_real64, 1000.0_real64, height=260.0_real64, &
                                 scale='symlog')
         call ig_same_line()
         call pf_colormap_legend('##l6', cm_colormap('cividis'), 0.0_real64, 1.0_real64, label_format='text')
         call ig_same_line()
         call pf_colormap_legend('##l7', cm_colormap('vik', 6_int32), -1.0_real64, 2.0_real64, levels=6_int32, &
                                 label_format='%+.2e')
      else
         call ip_colormap_legend('##l5', ip_colormap('RdBu'), -1000.0_real64, 1000.0_real64, height=260.0_real64, &
                                 scale='symlog')
         call ig_same_line()
         call ip_colormap_legend('##l6', ip_colormap('cividis'), 0.0_real64, 1.0_real64, label_format='text')
         call ig_same_line()
         call ip_colormap_legend('##l7', ip_colormap('vik', 6_int32), -1.0_real64, 2.0_real64, levels=6_int32, &
                                 label_format='%+.2e')
      endif
   case default
      if (side_fortran) then
         moved = pf_colormap_legend_edit('##l8', cm_colormap('Viridis'), rng(1), rng(2), height=380.0_real64, &
                                         scale='log')
      else
         moved = ip_colormap_legend_edit('##l8', ip_colormap('Viridis'), rng(1), rng(2), height=380.0_real64, &
                                         scale='log')
      endif
   endselect
   endsubroutine draw_case

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
   !< A case's picture: the current path's or the Fortran frame's.
   integer(int32), intent(in)    :: k       !< Case.
   logical,        intent(in)    :: fortran !< The Fortran frame's.
   character(len=:), allocatable :: name    !< File name.
   character(len=8)              :: tag     !< The case's number.

   write(tag, '(I0)') k
   if (fortran) then
      name = 'figure_test_plot_frame_colorbar.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_colorbar.'//trim(tag)//'.implot.png.tmp'
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
endprogram figure_test_plot_frame_colorbar
