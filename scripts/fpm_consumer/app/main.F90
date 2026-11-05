!< A program of another fpm project using FIGURE: a button clicked and a plot drawn, headless.
program consumer
use, intrinsic :: iso_fortran_env, only : error_unit, int32, output_unit, real64
use figure, only : app_object, ig_begin, ig_button, ig_end, ig_item_rect, ig_set_next_window, ip_begin_plot, &
                   ip_end_plot, ip_line
use figure_testing, only : test_click

implicit none
type(app_object) :: app
real(real64)     :: x(100), y(100), r(4)
integer(int32)   :: i, clicks
logical          :: plotted

x = [(real(i, real64), i = 1, 100)]
y = sin(0.1_real64 * x)
clicks = 0
plotted = .false.
call app%init_headless(640, 480)
do i = 1, 12
   if (.not. app%next_frame()) exit
   call ig_set_next_window(10.0_real64, 10.0_real64, 400.0_real64, 300.0_real64)
   if (ig_begin('Consumer')) then
      if (ig_button('Press')) clicks = clicks + 1
      call ig_item_rect(r(1), r(2), r(3), r(4))
      if (ip_begin_plot('p', height=150.0_real64)) then
         call ip_line('y', x, y)
         call ip_end_plot()
         plotted = .true.
      endif
   endif
   call ig_end()
   if (i == 3) call test_click(0.5_real64 * (r(1) + r(3)), 0.5_real64 * (r(2) + r(4)))
enddo
call app%destroy()
write(output_unit, '(A,I0,A,L1)') 'consumer: clicks ', clicks, ', plotted ', plotted
if (clicks /= 1 .or. .not. plotted) then
   write(error_unit, '(A)') 'consumer: FAILED'
   error stop 1
endif
write(output_unit, '(A)') 'consumer: ok'
endprogram consumer
