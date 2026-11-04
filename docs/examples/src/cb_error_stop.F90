!< cb_error_stop, cookbook: without `stat`, a failure prints the message and stops.
program cb_error_stop
!< cb_error_stop, cookbook: without `stat`, a failure prints the message and stops.
use, intrinsic :: iso_fortran_env, only : int32
use figure, only : app_object

implicit none
type(app_object) :: app !< Application.
!run cb_error_stop ./cb_error_stop

!region stop
call app%init_headless(400_int32, 300_int32)
call app%init_headless(400_int32, 300_int32) ! already initialized: error stop
!endregion stop
call app%destroy()
endprogram cb_error_stop
