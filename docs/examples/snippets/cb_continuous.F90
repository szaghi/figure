!< cb_continuous, cookbook: redraw continuously, as fast as the display (or the machine) allows.
program cb_continuous
!< cb_continuous, cookbook: redraw continuously, as fast as the display (or the machine) allows.
use, intrinsic :: iso_fortran_env, only : int32, int64, real64
use figure, only : app_object, ig_begin, ig_end, ig_text

implicit none
type(app_object)  :: app    !< Application.
integer(int64)    :: frames !< Frames drawn.
character(len=32) :: line   !< Text buffer.

frames = 0_int64
call app%init('FIGURE: continuous', 400_int32, 200_int32, vsync=.false.) ! do not wait for the display refresh
call app%set_lazy(.false.)                                              ! never sleep waiting for input
do while (app%next_frame())
   frames = frames + 1_int64
   write(line, '(A,I0)') 'frames: ', frames
   if (ig_begin('Counter')) then
      call ig_text(trim(line))
   endif
   call ig_end()
enddo
call app%destroy()
endprogram cb_continuous
