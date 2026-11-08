!< cb_frame, cookbook: the window's frame drawn by FIGURE, with the menus in its title bar, and the window's icon.
program cb_frame
!< cb_frame, cookbook: the window's frame drawn by FIGURE, with the menus in its title bar, and the window's icon.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ICON_CHART_LINE, ig_begin, ig_begin_main_menu_bar, ig_begin_menu, ig_checkbox, &
                   ig_dock_id, ig_dock_layout_begin, ig_dock_layout_end, ig_dock_space, ig_dock_window, ig_end,  &
                   ig_end_main_menu_bar, ig_end_menu, ig_menu_item, ig_separator, ig_slider, ig_text,           &
                   ip_begin_plot, ip_end_plot, ip_line

implicit none
integer(int32), parameter :: N = 200_int32 !< Points.
type(app_object)          :: app           !< Application.
real(real64)              :: x(N)          !< Abscissae.
real(real64)              :: cfl           !< A value.
logical                   :: viscous       !< A flag.
logical                   :: running       !< False once Quit is picked.
integer(int32)            :: i             !< Counter.
integer(int32)            :: root          !< Dock space, below the bar.
integer(int32)            :: stat          !< Status of the icon: refused where the system has none.

x = [(real(i - 1, real64) / real(N - 1, real64), i = 1_int32, N)]
cfl = 0.8_real64
viscous = .true.
running = .true.
call app%init('FIGURE: frame', 900_int32, 520_int32, decorations='figure') ! no system frame: FIGURE draws it
call app%set_icon(ICON_CHART_LINE, stat=stat)                              ! the task bar's icon, and the bar's
call app%set_confirm_quit(.true.)                                          ! the bar's close button asks too
do while (running)
   if (.not. app%next_frame()) exit
   if (app%quit_requested()) running = .false.
   if (ig_begin_main_menu_bar()) then                    ! inside the title bar, after the icon
      if (ig_begin_menu('File')) then
         if (ig_menu_item('Open...', shortcut='Ctrl+O')) continue
         if (ig_menu_item('Save', shortcut='Ctrl+S')) continue
         call ig_separator()
         if (ig_menu_item('Quit')) running = .false.
         call ig_end_menu()
      endif
      if (ig_begin_menu('View')) then
         if (ig_menu_item('Residuals', selected=viscous)) continue
         call ig_end_menu()
      endif
      call ig_end_main_menu_bar()
   endif
   root = ig_dock_id('frame')                            ! the dock space fills the window below the bar
   if (ig_dock_layout_begin(root)) then
      call ig_dock_window('Run', root)
      call ig_dock_layout_end(root)
   endif
   call ig_dock_space(root)
   if (ig_begin('Run')) then
      if (ig_checkbox('viscous', viscous)) continue
      if (ig_slider('CFL', cfl, 0.1_real64, 2.0_real64)) continue
      call ig_text('step 412 of 1000')
      if (ip_begin_plot('Residual', height=-1.0_real64)) then
         call ip_line('rho', x, exp(-3.0_real64 * x) + 0.05_real64 * sin(40.0_real64 * x))
         call ip_line('energy', x, 0.8_real64 * exp(-2.0_real64 * x))
         call ip_end_plot()
      endif
   endif
   call ig_end()
enddo
call app%destroy()
endprogram cb_frame
