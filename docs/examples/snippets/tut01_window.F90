!< tut01_window, tutorial chapter 1: a window with one line of text.
program tut01_window
!< tut01_window, tutorial chapter 1: a window with one line of text.
use, intrinsic :: iso_fortran_env, only : int32
use figure, only : app_object, ig_begin, ig_end, ig_text

implicit none
type(app_object) :: app !< Application.

call app%init('FIGURE: first window', 640_int32, 360_int32)
do while (app%next_frame())
   if (ig_begin('Hello')) then
      call ig_text('Hello from Fortran.')
   endif
   call ig_end()
enddo
call app%destroy()
endprogram tut01_window
