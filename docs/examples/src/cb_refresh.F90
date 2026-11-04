!< cb_refresh, cookbook: show data that changes without user input, at a chosen refresh period.
program cb_refresh
!< cb_refresh, cookbook: show data that changes without user input, at a chosen refresh period.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_end, ig_text

implicit none
type(app_object)  :: app   !< Application.
character(len=10) :: clock !< hhmmss.sss.

call app%init('FIGURE: refresh', 400_int32, 200_int32)
!region refresh
call app%set_lazy(.true., max_wait=1.0_real64) ! idle: redraw at least once per second
do while (app%next_frame())
   call date_and_time(time=clock)
   if (ig_begin('Clock')) then
      call ig_text(clock(1:2)//':'//clock(3:4)//':'//clock(5:6))
   endif
   call ig_end()
enddo
!endregion refresh
call app%destroy()
endprogram cb_refresh
