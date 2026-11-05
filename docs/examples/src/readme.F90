!< readme, the example of README.md: a window, a slider and a plot that follows it.
program readme
!< readme, the example of README.md: a window, a slider and a plot that follows it.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_end, ig_set_next_window, ig_slider, ip_begin_plot, ip_end_plot, ip_line

implicit none
type(app_object) :: app           !< Application.
real(real64)     :: x(200)        !< Abscissae.
real(real64)     :: frequency     !< Set by the slider.
integer(int32)   :: i             !< Counter.

x = [(0.05_real64 * i, i = 0, 199)]
frequency = 1.0_real64
call app%init('FIGURE', 800, 500)
do while (app%next_frame())                 ! the interface is declared every frame
   call ig_set_next_window(20.0_real64, 20.0_real64, 760.0_real64, 460.0_real64)
   if (ig_begin('Wave')) then
      if (ig_slider('frequency', frequency, 0.1_real64, 5.0_real64)) continue
      if (ip_begin_plot('sin(f x)', height=-1.0_real64)) then
         call ip_line('y', x, sin(frequency * x))
         call ip_end_plot()
      endif
   endif
   call ig_end()
enddo
call app%destroy()
endprogram readme
