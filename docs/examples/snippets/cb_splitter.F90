!< cb_splitter, reference example: a window split in two panes by a bar the user drags; checked headless by dragging
!< the bar found by its path.
program cb_splitter
!< cb_splitter, reference example: a window split in two panes by a bar the user drags; checked headless by dragging
!< the bar found by its path.
use, intrinsic :: iso_fortran_env, only : int32, output_unit, real64
use figure, only : app_object, ig_begin, ig_begin_child, ig_end, ig_end_child, ig_same_line, ig_set_next_window, &
                   ig_splitter, ig_text
use figure_testing, only : test_drag, test_item_rect, test_run

implicit none
type(app_object) :: app                                   !< Application.
real(real64)     :: sizes(2) = [240.0_real64, 460.0_real64] !< The panes' widths [pixels].
real(real64)     :: x, y, w, h                            !< The bar's rectangle.

call app%init_headless(800_int32, 500_int32)
call draw(30_int32)
if (.not. test_item_rect('Files/split', x, y, w, h)) error stop 'cb_splitter: no bar'
call test_drag(x + 0.5_real64 * w, y + 50.0_real64, x + 0.5_real64 * w + 60.0_real64, y + 50.0_real64)
call draw(30_int32)
write(output_unit, '(A,2F7.1)') 'panes after a drag of 60 pixels:', sizes
call app%destroy()

contains
   subroutine draw(frames)
   !< Draw until idle, at most `frames` frames.
   integer(int32), intent(in) :: frames !< Frames allowed.

   call app%request_frames(3_int32)
   do while (test_run(frames))
      if (.not. app%next_frame()) exit
      call ig_set_next_window(20.0_real64, 20.0_real64, 760.0_real64, 400.0_real64)
      if (ig_begin('Files')) then
         if (ig_begin_child('tree', sizes(1), 0.0_real64, border=.true.)) call ig_text('the tree')
         call ig_end_child()
         call ig_same_line()
         if (ig_splitter('split', sizes)) continue          ! true while dragged: sizes changed
         call ig_same_line()
         if (ig_begin_child('view', sizes(2), 0.0_real64, border=.true.)) call ig_text('the file')
         call ig_end_child()
      endif
      call ig_end()
   enddo
   endsubroutine draw
endprogram cb_splitter
