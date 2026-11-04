!< cb_scale, cookbook: size windows and plots in proportion to the display content scale.
program cb_scale
!< cb_scale, cookbook: size windows and plots in proportion to the display content scale.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_end, ig_set_next_window, ip_begin_plot, ip_end_plot, ip_line

implicit none
type(app_object) :: app   !< Application.
real(real64)     :: s     !< Content scale.
real(real64)     :: x(2)  !< Abscissae.
real(real64)     :: y(2)  !< Ordinates.

x = [0.0_real64, 1.0_real64]
y = [0.0_real64, 1.0_real64]
call app%init('FIGURE: scale', 800_int32, 600_int32)
!region scale
s = app%content_scale()
do while (app%next_frame())
   call ig_set_next_window(10.0_real64 * s, 10.0_real64 * s, 780.0_real64 * s, 580.0_real64 * s)
   if (ig_begin('Scaled')) then
      if (ip_begin_plot('Diagonal', height=400.0_real64 * s)) then
         call ip_line('y = x', x, y)
         call ip_end_plot()
      endif
   endif
   call ig_end()
enddo
!endregion scale
call app%destroy()
endprogram cb_scale
