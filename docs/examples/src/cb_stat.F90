!< cb_stat, cookbook: handle failures with `stat` instead of stopping.
program cb_stat
!< cb_stat, cookbook: handle failures with `stat` instead of stopping.
use, intrinsic :: iso_fortran_env, only : int32, output_unit, real64
use figure, only : app_object, figure_last_error, FIG_OK, FIG_ERR_ARGUMENT, FIG_ERR_STATE, ig_begin, ig_end, &
                   ip_begin_plot, ip_end_plot, ip_line

implicit none
type(app_object) :: app    !< Application.
integer(int32)   :: stat   !< Status.
real(real64)     :: x(3)   !< Abscissae.
real(real64)     :: y(2)   !< Ordinates: one too few.
!run cb_stat ./cb_stat

!region stat
call app%init_headless(0_int32, 300_int32, stat=stat)          ! invalid size
if (stat /= FIG_OK) write(output_unit, '(A,I0,A)') 'init_headless: stat = ', stat, ', "'//figure_last_error()//'"'

call app%init_headless(400_int32, 300_int32, stat=stat)        ! succeeds
call app%init_headless(400_int32, 300_int32, stat=stat)        ! already initialized
if (stat == FIG_ERR_STATE) write(output_unit, '(A,I0,A)') 'init_headless: stat = ', stat, ', "'//figure_last_error()//'"'
!endregion stat

x = [1.0_real64, 2.0_real64, 3.0_real64]
y = [1.0_real64, 4.0_real64]
!region line
if (app%next_frame(stat=stat)) then
   if (ig_begin('Data')) then
      if (ip_begin_plot('Mismatch')) then
         call ip_line('y', x, y, stat=stat)                    ! size(x) /= size(y): nothing drawn
         if (stat == FIG_ERR_ARGUMENT) write(output_unit, '(A,I0,A)') 'ip_line: stat = ', stat, &
                                                                   ', "'//figure_last_error()//'"'
         call ip_end_plot()
      endif
   endif
   call ig_end()
endif
!endregion line
call app%destroy()
endprogram cb_stat
