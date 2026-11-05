!< cb_subplots, cookbook: several plots sharing the x axis, with tick labels in a chosen format.
program cb_subplots
!< cb_subplots, cookbook: several plots sharing the x axis, with tick labels in a chosen format.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_end, ig_set_next_window, ip_begin_plot, ip_begin_subplots, ip_end_plot, &
                   ip_end_subplots, ip_line, ip_setup_axes

implicit none
integer(int32), parameter :: N = 400_int32    !< Samples.
type(app_object)          :: app              !< Application.
real(real64)              :: t(N)             !< Time.
real(real64)              :: drag(N)          !< A force near -3781.3: its default tick labels look alike.
real(real64)              :: moment(N)        !< A moment.
integer(int32)            :: i                !< Counter.

t = [(0.01_real64 * real(i, real64), i = 1_int32, N)]
drag = -3781.315_real64 + 0.004_real64 * sin(9.0_real64 * t) * exp(-0.5_real64 * t)
moment = 0.02_real64 * cos(9.0_real64 * t) * exp(-0.5_real64 * t)
call app%init('FIGURE: subplots', 900_int32, 560_int32)
do while (app%next_frame())
   call ig_set_next_window(10.0_real64, 10.0_real64, 880.0_real64, 540.0_real64)
   if (ig_begin('Forces')) then
      !region subplots
      if (ip_begin_subplots('##forces', 2_int32, 1_int32, height=-1.0_real64, link_x=.true.)) then
         if (ip_begin_plot('drag')) then
            call ip_setup_axes('time', 'Cx', yformat='%.4f')   ! the default would print -3781.31 on every tick
            call ip_line('Cx', t, drag)
            call ip_end_plot()
         endif
         if (ip_begin_plot('pitching moment')) then
            call ip_setup_axes('time', 'CMy')
            call ip_line('CMy', t, moment)
            call ip_end_plot()
         endif
         call ip_end_subplots()
      endif
      !endregion subplots
   endif
   call ig_end()
enddo
call app%destroy()
endprogram cb_subplots
