!< figure_test_plot_frame_dnd, the Fortran plot frame's drop targets (`pf_drop_target`), as FIGURE's `ip_drop_target`.
program figure_test_plot_frame_dnd
!< figure_test_plot_frame_dnd, the Fortran plot frame's drop targets (`pf_drop_target`), as FIGURE's `ip_drop_target`.
!<
!< szaghi/figure#15 P10 (what P10-P12 left, night 2026-11-23 step 10). A tree's leaf is a drag source (`ig_drag_source`,
!< type 'case'); beside it a plot with three drop targets: its area (the drop's point in plot units), its x axis, its
!< legend. Drawn first by ImPlot (`ip_drop_target`: FIGURE's `fig_dnd_plot_target` over ImPlot's
!< `BeginDragDropTargetPlot`, `...Axis`, `...Legend`), then by the Fortran frame (`pf_drop_target`), 40 frames apart,
!< with the same three drags (to the area, the x axis's labels, the legend). Checked on every frame: each target's
!< drop (and its payload, its point), equal; each target's drop seen once; the pictures with the payload over the area
!< (the target's highlight) and at the end, at FIGURE's oracle rule.
!<
!< The pictures are `figure_test_plot_frame_dnd.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_drag_source, ig_end, ig_item_rect, ig_same_line, &
                   ig_set_next_window, ig_tree_node, ig_tree_pop, ip_begin_plot, ip_drop_target, ip_end_plot,   &
                   ip_line, ip_plot_to_pixels, ip_setup_axes_limits, ImGuiWindowFlags_NoDecoration
use figure_plot_frame, only : pf_begin_plot, pf_drop_target, pf_end_plot, pf_setup_axes_limits
use figure_plot_items, only : pf_line
use figure_testing, only : test_capture, test_compare_image, test_mouse_button, test_mouse_move, test_next_frame

implicit none
integer(int32), parameter :: W = 700_int32      !< Display width [pixels].
integer(int32), parameter :: H = 460_int32      !< Display height [pixels].
integer(int32), parameter :: NF = 44_int32      !< Frames per side.
type(app_object)          :: app                !< Application.
real(real64)              :: state(8, NF, 2)    !< Per frame and side: drops (area, axis, legend), lengths, x, y.
real(real64)              :: leaf(4), area(2), xaxis(2), lg(2) !< The source, the targets' points.
character(len=:), allocatable :: payload        !< A payload.
logical                   :: side_fortran, ok(3) !< Drawing with the Fortran frame, the checks.
integer(int32)            :: f, s, sd, i        !< Frame, status, side, counter.
character(len=16)         :: keep               !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
state = 0.0_real64
do sd = 1_int32, 2_int32 ! 1 ImPlot, 2 the Fortran frame
   side_fortran = sd == 2_int32
   do f = 1_int32, NF
      if (.not. app%next_frame()) error stop 'figure_test_plot_frame_dnd: next_frame returned false headless'
      call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
      if (ig_begin('plot frame dnd', flags=ImGuiWindowFlags_NoDecoration)) call draw(state(:, f, sd), f)
      call ig_end()
      if (f == 9_int32) call test_capture(picture(1_int32, side_fortran), s)
      if (f == NF) call test_capture(picture(2_int32, side_fortran), s)
      select case (f)
      case (3_int32)
         call drag(leaf, area)
      case (16_int32)
         call drag(leaf, xaxis)
      case (29_int32)
         call drag(leaf, lg)
      case default
      endselect
   enddo
   call test_mouse_move(-100.0_real64, -100.0_real64)
   do i = 1_int32, 40_int32
      if (.not. app%next_frame()) error stop 'figure_test_plot_frame_dnd: next_frame returned false headless'
   enddo
enddo
ok(1) = all(state(:, :, 1) == state(:, :, 2))
if (.not. ok(1)) then
   do f = 1_int32, NF
      if (any(state(:, f, 1) /= state(:, f, 2))) write(output_unit, '(A,I0,/,8ES14.6,/,8ES14.6)') 'frame ', f, &
                                                       state(:, f, 1), state(:, f, 2)
   enddo
endif
ok(2) = sum(state(1, :, 1)) == 1.0_real64 .and. sum(state(2, :, 1)) == 1.0_real64 .and. &
        sum(state(3, :, 1)) == 1.0_real64 ! each target's drop once (ImPlot's side)
if (.not. ok(2)) write(output_unit, '(A,3F5.1)') 'drops: ', sum(state(1, :, 1)), sum(state(2, :, 1)), &
                                                  sum(state(3, :, 1))
ok(3) = pictures_equal(1_int32) .and. pictures_equal(2_int32)
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_dnd checks:', ok
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(ok)
if (.not. all(ok)) error stop 1

contains
   subroutine draw(v, fr)
   !< The source and the plot, by the side drawing.
   real(real64),   intent(inout) :: v(:) !< State.
   integer(int32), intent(in)    :: fr   !< Frame.
   real(real64)                  :: x, y !< A drop's point.
   real(real64)                  :: lx(2) = [0.0_real64, 4.0_real64], ly(2) = [0.0_real64, 1.0_real64] !< A line.

   if (ig_tree_node('mesh-A', leaf=.true.)) call ig_tree_pop()
   call ig_item_rect(leaf(1), leaf(2), leaf(3), leaf(4))
   if (ig_drag_source('case', 'mesh-A', preview='case mesh-A')) continue
   x = -1.0_real64
   y = -1.0_real64
   if (side_fortran) then
      if (pf_begin_plot('Drop here##dnd', width=560.0_real64, height=380.0_real64)) then
         call pf_setup_axes_limits(0.0_real64, 4.0_real64, 0.0_real64, 1.0_real64)
         call pf_line('line', lx, ly)
         if (pf_drop_target('case', payload, x=x, y=y)) call drop(v, 1_int32, x, y)
         if (pf_drop_target('case', payload, axis='x1')) call drop(v, 2_int32, x, y)
         if (pf_drop_target('case', payload, legend=.true.)) call drop(v, 3_int32, x, y)
         call pf_end_plot()
      endif
   else
      if (ip_begin_plot('Drop here##dnd', width=560.0_real64, height=380.0_real64)) then
         call ip_setup_axes_limits(0.0_real64, 4.0_real64, 0.0_real64, 1.0_real64)
         call ip_line('line', lx, ly)
         if (fr == 1_int32) then ! the targets' points
            call ip_plot_to_pixels(2.7_real64, 0.4_real64, area(1), area(2))
            call ip_plot_to_pixels(1.0_real64, 0.0_real64, xaxis(1), xaxis(2))
            xaxis(2) = xaxis(2) + 12.0_real64 ! below the plot area: the tick labels
            call ip_plot_to_pixels(0.0_real64, 1.0_real64, lg(1), lg(2))
            lg = lg + [30.0_real64, 18.0_real64] ! the legend, north-west inside
         endif
         if (ip_drop_target('case', payload, x=x, y=y)) call drop(v, 1_int32, x, y)
         if (ip_drop_target('case', payload, axis='x1')) call drop(v, 2_int32, x, y)
         if (ip_drop_target('case', payload, legend=.true.)) call drop(v, 3_int32, x, y)
         call ip_end_plot()
      endif
   endif
   endsubroutine draw

   subroutine drop(v, k, x, y)
   !< A drop on the target k: seen, its payload's length (negative if not 'mesh-A'), the area's point.
   real(real64),   intent(inout) :: v(:) !< State.
   integer(int32), intent(in)    :: k    !< Target.
   real(real64),   intent(in)    :: x, y !< The drop's point.

   v(k) = 1.0_real64
   v(3 + k) = real(len(payload), real64)
   if (payload /= 'mesh-A') v(3 + k) = -v(3 + k)
   if (k == 1_int32) then
      v(7) = x
      v(8) = y
   endif
   endsubroutine drop

   subroutine drag(from, to)
   !< A drag with the left button from the centre of `from` to `to`, as figure_test_dnd's (two moves, a pause, the
   !< release).
   real(real64), intent(in) :: from(4) !< Source rectangle [pixels].
   real(real64), intent(in) :: to(2)   !< Target point [pixels].
   real(real64)             :: c(2)    !< Source centre.

   c = [0.5_real64 * (from(1) + from(3)), 0.5_real64 * (from(2) + from(4))]
   call test_mouse_move(c(1), c(2))
   call test_next_frame()
   call test_next_frame()
   call test_mouse_button(.true.)
   call test_next_frame()
   call test_mouse_move(c(1) + 20.0_real64, c(2) + 10.0_real64)
   call test_next_frame()
   call test_mouse_move(to(1), to(2))
   call test_next_frame()
   call test_next_frame()
   call test_mouse_button(.false.)
   call test_next_frame()
   call test_mouse_move(-100.0_real64, -100.0_real64)
   endsubroutine drag

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
   !< The k-th picture: ImPlot's or the Fortran frame's.
   integer(int32), intent(in)    :: k       !< Picture.
   logical,        intent(in)    :: fortran !< The Fortran frame's.
   character(len=:), allocatable :: name    !< File name.
   character(len=8)              :: tag     !< Its number.

   write(tag, '(I0)') k
   if (fortran) then
      name = 'figure_test_plot_frame_dnd.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_dnd.'//trim(tag)//'.implot.png.tmp'
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
endprogram figure_test_plot_frame_dnd
