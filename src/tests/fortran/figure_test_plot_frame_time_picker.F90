!< figure_test_plot_frame_time_picker, a time axis's date and time pickers in the Fortran frame's axis menu, as ImPlot's.
program figure_test_plot_frame_time_picker
!< figure_test_plot_frame_time_picker, a time axis's date and time pickers in the Fortran frame's axis menu, as ImPlot's.
!<
!< szaghi/figure#15, figure_plot_time_picker. One plot with a time x axis (ten days from 2020-01-01 00:00 UTC), driven
!< the same way on NF frames, first by ImPlot through FIGURE's API, then by the Fortran frame, 40 frames apart: a right
!< click on the x axis opens its menu; "Min Time" opened (a time picker over a month of days); its hour combo opened,
!< 05 picked; the month's button (the year's months), March picked (March's days), the 20th picked; then "Max Time"
!< opened (March: the range's max was moved past its new min), its month's button, its year browsed back with the
!< arrow, the year's button (twenty years). Checked: the axes' ranges of every frame equal to the bit (the picks set
!< the range: 05:00, then March 20th, 05:00), and the pictures of six moments at FIGURE's oracle rule (|d| <= 2, no
!< pixel failing). The input is spaced five frames apart: a click takes two frames, a popup one more to show.
!<
!< The pictures are `figure_test_plot_frame_time_picker.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ip_begin_plot, ip_end_plot, &
                   ip_line, ip_plot_limits, ip_setup_axes, ip_setup_axes_limits, ImGuiWindowFlags_NoDecoration
use figure_plot_frame, only : pf_begin_plot, pf_end_plot, pf_plot_limits, pf_setup_axes, pf_setup_axes_limits
use figure_plot_items, only : pf_line
use figure_testing, only : test_capture, test_click, test_compare_image, test_item_click, test_mouse_button, &
                          test_mouse_move, test_popup_rect

implicit none
integer(int32), parameter :: W = 900_int32      !< Display width [pixels].
integer(int32), parameter :: H = 640_int32      !< Display height [pixels].
integer(int32), parameter :: NF = 60_int32      !< Frames per side.
integer(int32), parameter :: NPIC = 6_int32     !< Pictures per side.
integer(int32), parameter :: SHOTS(NPIC) = [12_int32, 18_int32, 28_int32, 33_int32, 53_int32, 58_int32] !< When.
real(real64),   parameter :: T0 = 1577836800.0_real64 !< 2020-01-01 00:00 UTC.
type(app_object)          :: app               !< Application.
real(real64)              :: tx(11), ty(11)    !< A line.
real(real64)              :: lim(4, NF, 2)     !< The ranges per frame and side.
logical                   :: test_passed(NPIC + 1) !< Per-picture outcome, the ranges.
logical                   :: side_fortran      !< Drawing with the Fortran frame.
logical                   :: missed = .false.  !< A scripted click found no item.
integer(int32)            :: f, s, sd, i, k    !< Frame, status, side, counters.
character(len=16)         :: keep              !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do i = 1_int32, 11_int32
   tx(i) = T0 + real(i - 1_int32, real64) * 86400.0_real64
   ty(i) = sin(real(i, real64))
enddo
lim = 0.0_real64
do sd = 1_int32, 2_int32 ! 1 ImPlot, 2 the Fortran frame
   side_fortran = sd == 2_int32
   do f = 1_int32, NF
      call pointer(f)
      if (.not. app%next_frame()) error stop 'figure_test_plot_frame_time_picker: next_frame returned false headless'
      call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
      if (ig_begin('plot frame time picker', flags=ImGuiWindowFlags_NoDecoration)) call draw(lim(:, f, sd))
      call ig_end()
      do k = 1_int32, NPIC
         if (f == SHOTS(k)) call test_capture(picture(k, side_fortran), s)
      enddo
   enddo
   call test_mouse_move(880.0_real64, 630.0_real64) ! the menus closed by a click outside them
   do i = 1_int32, 40_int32
      if (i == 2_int32) call test_mouse_button(.true.)
      if (i == 3_int32) call test_mouse_button(.false.)
      if (i == 4_int32) call test_mouse_move(-100.0_real64, -100.0_real64)
      if (.not. app%next_frame()) error stop 'figure_test_plot_frame_time_picker: next_frame returned false headless'
   enddo
enddo
call app%destroy()
do k = 1_int32, NPIC
   test_passed(k) = pictures_equal(k)
enddo
test_passed(NPIC + 1) = all(lim(:, :, 1) == lim(:, :, 2)) .and. lim(1, NF, 1) /= T0 .and. .not. missed
if (.not. test_passed(NPIC + 1)) then
   do f = 1_int32, NF
      if (all(lim(:, f, 1) == lim(:, f, 2))) cycle
      write(output_unit, '(A,I0,A)') 'frame ', f, ': ImPlot, frame'
      write(output_unit, '(4ES24.16)') lim(:, f, 1)
      write(output_unit, '(4ES24.16)') lim(:, f, 2)
   enddo
   write(output_unit, '(A,4ES24.16)') 'last frame: ', lim(:, NF, 1)
endif
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_time_picker checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine pointer(fr)
   !< The input queued before a frame, the same on both sides.
   integer(int32), intent(in) :: fr !< Frame.

   select case (fr)
   case (2_int32)
      call test_mouse_move(300.0_real64, 352.0_real64) ! over the x axis's tick labels
   case (3_int32)
      call test_mouse_button(.true., 'right')
   case (4_int32)
      call test_mouse_button(.false., 'right')
   case (8_int32)
      call click('Min Time')
   case (13_int32) ! the hour combo: the menu's first item
      call click_at(18.0_real64, 17.0_real64)
   case (19_int32)
      call click('05')
   case (24_int32)
      call click('January 2020')
   case (29_int32)
      call click_at(122.0_real64, 84.0_real64) ! Mar, third of the first row of months
   case (34_int32)
      call click_at(152.0_real64, 132.0_real64) ! the 20th, Friday of March's third week
   case (39_int32)
      call click('Max Time')
   case (44_int32)
      call click_at(40.0_real64, 48.0_real64) ! the month's button
   case (49_int32)
      call click('##Up')
   case (54_int32)
      call click_at(20.0_real64, 48.0_real64) ! the year's button
   case default
   endselect
   endsubroutine pointer

   subroutine click_at(dx, dy)
   !< A click at a point of the innermost popup open in the last frame, from its top-left corner (the date picker's
   !< buttons: their labels repeat, and the item recorder does not find all of them).
   real(real64), intent(in) :: dx, dy         !< Offset [pixels].
   real(real64)             :: x0, y0, x1, y1 !< The popup.
   logical                  :: found          !< A popup open.

   call test_popup_rect(x0, y0, x1, y1, found)
   if (.not. found) then
      missed = .true.
      write(output_unit, '(A)') 'not clicked: no popup open'
      return
   endif
   call test_click(x0 + dx, y0 + dy)
   endsubroutine click_at

   subroutine click(path)
   !< A click on an item of the last frame; a missing item recorded (the check of the ranges fails).
   character(len=*), intent(in) :: path !< Item.
   integer(int32)               :: st   !< Status.

   call test_item_click(path, stat=st)
   if (st /= 0_int32) then
      missed = .true.
      write(output_unit, '(A,A)') 'not clicked: ', trim(figure_last_error())
   endif
   endsubroutine click

   subroutine draw(v)
   !< The plot, by the side drawing; its ranges.
   real(real64), intent(out) :: v(4) !< X1's and Y1's ranges.

   v = 0.0_real64
   if (side_fortran) then
      if (pf_begin_plot('Time picker', width=600.0_real64, height=360.0_real64)) then
         call pf_setup_axes('date', 'y', xscale='time')
         call pf_setup_axes_limits(T0, T0 + 10.0_real64 * 86400.0_real64, -1.5_real64, 1.5_real64)
         call pf_line('y', tx, ty)
         call pf_plot_limits(v(1), v(2), v(3), v(4))
         call pf_end_plot()
      endif
   else
      if (ip_begin_plot('Time picker', width=600.0_real64, height=360.0_real64)) then
         call ip_setup_axes('date', 'y', xscale='time')
         call ip_setup_axes_limits(T0, T0 + 10.0_real64 * 86400.0_real64, -1.5_real64, 1.5_real64)
         call ip_line('y', tx, ty)
         call ip_plot_limits(v(1), v(2), v(3), v(4))
         call ip_end_plot()
      endif
   endif
   endsubroutine draw

   function pictures_equal(k) result(ok)
   !< A moment's pictures of both sides equal at the oracle's rule.
   integer(int32), intent(in) :: k   !< Picture.
   logical                    :: ok  !< Equal.
   integer(int64)             :: nf_ !< Pixels that failed.
   integer(int32)             :: st  !< Status.

   ok = test_compare_image(picture(k, .true.), picture(k, .false.), threshold=2_int32, max_failed=0_int32, &
                           failed=nf_, stat=st)
   if (.not. ok) write(output_unit, '(A,I0,A,I0,A,A)') 'picture ', k, ': ', nf_, ' pixels failed: ', &
                                                     figure_last_error()
   endfunction pictures_equal

   function picture(k, fortran) result(name)
   !< A moment's picture: ImPlot's or the Fortran frame's.
   integer(int32), intent(in)    :: k       !< Picture.
   logical,        intent(in)    :: fortran !< The Fortran frame's.
   character(len=:), allocatable :: name    !< File name.
   character(len=8)              :: tag     !< Its number.

   write(tag, '(I0)') k
   if (fortran) then
      name = 'figure_test_plot_frame_time_picker.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_time_picker.'//trim(tag)//'.implot.png.tmp'
   endif
   endfunction picture

   subroutine remove_files()
   !< The pictures removed.
   integer(int32) :: k, m, u, ios !< Picture, side, unit, status.
   logical        :: there        !< The file exists.

   do k = 1_int32, NPIC
      do m = 1_int32, 2_int32
         inquire(file=picture(k, m == 2_int32), exist=there)
         if (.not. there) cycle
         open(newunit=u, file=picture(k, m == 2_int32), status='old', iostat=ios)
         if (ios == 0) close(u, status='delete')
      enddo
   enddo
   endsubroutine remove_files
endprogram figure_test_plot_frame_time_picker
