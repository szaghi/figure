!< cb_dock, cookbook: a docked layout, controls on the left, a plot on the right, a log below it.
program cb_dock
!< cb_dock, cookbook: a docked layout, controls on the left, a plot on the right, a log below it.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_dock_id, ig_dock_layout_begin, ig_dock_layout_end, ig_dock_space, &
                   ig_dock_split, ig_dock_window, ig_end, ig_set_next_window, ig_slider, ig_text, ip_begin_plot,  &
                   ip_end_plot, ip_line, ip_setup_axes

implicit none
integer(int32), parameter :: N = 400_int32 !< Points.
type(app_object)          :: app           !< Application.
real(real64)              :: x(N)          !< Abscissae.
real(real64)              :: y(N)          !< Signal.
real(real64)              :: frequency     !< Frequency of the signal.
real(real64)              :: damping       !< Damping of the signal.
integer(int32)            :: root          !< The dock space.
integer(int32)            :: left          !< Its left area.
integer(int32)            :: right         !< Its right area.
integer(int32)            :: plot          !< The upper part of the right area.
integer(int32)            :: log           !< The lower part of the right area.
integer(int32)            :: i             !< Counter.
character(len=80)         :: line          !< Text buffer.

x = [(10.0_real64 * real(i - 1, real64) / real(N - 1, real64), i = 1_int32, N)]
frequency = 2.0_real64
damping = 0.2_real64

call app%init('FIGURE: docking', 1000_int32, 640_int32)
do while (app%next_frame())
   !region layout
   root = ig_dock_id('main')
   if (ig_dock_layout_begin(root)) then                       ! the first frame only: no layout yet
      call ig_dock_split(root, 'left', 0.3_real64, left, right) ! controls | the rest
      call ig_dock_split(right, 'down', 0.25_real64, log, plot) ! the rest: plot above, log below
      call ig_dock_window('Controls', left)
      call ig_dock_window('Plot', plot)
      call ig_dock_window('Log', log)
      call ig_dock_layout_end(root)
   endif
   call ig_dock_space(root)                                   ! every frame, before the windows
   !endregion layout

   y = exp(-damping * x) * cos(frequency * x)
   if (ig_begin('Controls')) then
      if (ig_slider('frequency', frequency, 0.5_real64, 6.0_real64)) continue
      if (ig_slider('damping', damping, 0.0_real64, 1.0_real64)) continue
   endif
   call ig_end()
   if (ig_begin('Plot')) then
      if (ip_begin_plot('Damped oscillation', height=-1.0_real64)) then
         call ip_setup_axes('t', 'y')
         call ip_line('y', x, y)
         call ip_end_plot()
      endif
   endif
   call ig_end()
   if (ig_begin('Log')) then
      write(line, '(A,F0.3,A,F0.3)') 'frequency ', frequency, ', damping ', damping
      call ig_text(trim(line))
   endif
   call ig_end()
   ! not in the layout: a floating window, which the user can dock anywhere by dragging its title bar
   call ig_set_next_window(620.0_real64, 120.0_real64, 300.0_real64, 140.0_real64)
   if (ig_begin('Notes')) call ig_text('Drag me by the title bar.')
   call ig_end()
enddo
call app%destroy()
endprogram cb_dock
