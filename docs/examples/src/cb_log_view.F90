!< cb_log_view, reference example: a log view with a cap, drawn in a window, and what it keeps, shows and copies;
!< checked headless.
program cb_log_view
!< cb_log_view, reference example: a log view with a cap, drawn in a window, and what it keeps, shows and copies;
!< checked headless.
use, intrinsic :: iso_fortran_env, only : int32, output_unit, real64
use figure, only : app_object, ig_begin, ig_end, ig_set_next_window, log_view_object

implicit none
type(app_object)      :: app     !< Application.
type(log_view_object) :: log     !< The log.
character(len=40)     :: line    !< A line.
integer(int32)        :: first   !< First line in view.
integer(int32)        :: last    !< Last line in view.
integer(int32)        :: i       !< Counter.
!run cb_log_view ./cb_log_view

call app%init_headless(500_int32, 300_int32)
!region log
call log%set_cap(1000_int32)                                  ! keep the last 1000 lines
do i = 1_int32, 1200_int32
   write(line, '(A,I0,A,ES9.2)') 'step ', i, ' residual ', 10.0_real64**(-real(i, real64) / 200.0_real64)
   call log%add(trim(line))                                   ! or log%add(lines), as p%poll gives them
enddo
do i = 1_int32, 3_int32                                       ! every frame
   if (.not. app%next_frame()) exit
   call ig_set_next_window(0.0_real64, 0.0_real64, 500.0_real64, 300.0_real64, always=.true.)
   if (ig_begin('Log')) call log%draw('lines')                ! only the lines in view; follows the end
   call ig_end()
enddo
!endregion log
!region read
call log%in_view(first, last)
write(output_unit, '(A,I0,A,A)') 'kept: ', log%count(), ', the oldest: ', log%line(1_int32)
write(output_unit, '(A,L1,A,I0,A,I0,A,A)') 'following: ', log%following(), ', in view: ', first, ' to ', last, &
                                           ', the newest: ', log%line(log%count())
!endregion read
call app%destroy()
if (log%count() /= 1000_int32 .or. last /= 1000_int32 .or. .not. log%following()) error stop 'cb_log_view: not kept'
endprogram cb_log_view
