!< cb_hidden_window, cookbook: skip the content of a collapsed window, and pair every begin with its end.
program cb_hidden_window
!< cb_hidden_window, cookbook: skip the content of a collapsed window, and pair every begin with its end.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_end, ig_set_next_window, ig_text, ip_begin_plot, ip_end_plot, ip_line

implicit none
integer(int32), parameter :: N = 100000_int32 !< Points.
type(app_object)          :: app              !< Application.
real(real64)              :: x(N)             !< Abscissae.
real(real64)              :: y(N)             !< Ordinates.
integer(int32)            :: i                !< Counter.

x = [(real(i, real64) * 1.0e-4_real64, i = 1_int32, N)]
call app%init('FIGURE: begin and end', 900_int32, 600_int32)
do while (app%next_frame())
   call ig_set_next_window(20.0_real64, 20.0_real64, 400.0_real64, 300.0_real64, always=.true.)
   if (ig_begin('Fixed')) then                    ! false when collapsed: skip the content, not the end
      call ig_text('Placed and sized every frame: cannot be moved.')
   endif
   call ig_end()                                  ! always, whatever ig_begin returned

   call ig_set_next_window(440.0_real64, 20.0_real64, 400.0_real64, 300.0_real64)
   if (ig_begin('Expensive')) then
      y = sin(x) * exp(-x)                        ! computed only while the window is visible
      if (ip_begin_plot('##damped')) then         ! end the plot only if it began
         call ip_line('damped', x, y)
         call ip_end_plot()
      endif
   endif
   call ig_end()
enddo
call app%destroy()
endprogram cb_hidden_window
