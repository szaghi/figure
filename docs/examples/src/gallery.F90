!< gallery, the theme gallery: one program, recorded in every built-in theme (run with "cycle" to switch them live).
program gallery
!< gallery, the theme gallery: one program, recorded in every built-in theme (run with "cycle" to switch them live).
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_button, ig_checkbox, ig_dock_id, ig_dock_layout_begin, ig_dock_layout_end, &
                   ig_dock_space, ig_dock_split, ig_dock_window, ig_end, ig_input, ig_same_line, ig_separator,          &
                   ig_slider, ig_text, ip_begin_plot, ip_colormap_scale, ip_end_plot, ip_heatmap, ip_line,             &
                   ip_setup_axes, ImPlotColormap_Viridis

implicit none
integer(int32),    parameter :: N = 200_int32                    !< Points per line.
integer(int32),    parameter :: NF = 60_int32                    !< Field size.
integer(int32),    parameter :: NT = 7_int32                     !< Themes.
character(len=13), parameter :: THEMES(NT) = [character(len=13) :: 'seal', 'seal-light', 'paper', 'high-contrast', &
                                             'dark', 'light', 'classic']
type(app_object)             :: app                              !< Application.
real(real64)                 :: x(N)                             !< Abscissae.
real(real64)                 :: f(NF, NF)                        !< A field.
real(real64)                 :: amplitude                        !< A value.
real(real64)                 :: rate                             !< Another.
integer(int32)               :: cells                            !< An integer value.
logical                      :: viscous                          !< A flag.
logical                      :: cycle_themes                     !< Switch the themes every 45 frames.
integer(int32)               :: frame                            !< Frames drawn.
integer(int32)               :: i                                !< Counter.
integer(int32)               :: j                                !< Counter.
integer(int32)               :: k                                !< Line.
integer(int32)               :: root                             !< Dock space.
integer(int32)               :: left                             !< Its left area.
integer(int32)               :: right                            !< Its right area.
integer(int32)               :: top                              !< The upper right area.
integer(int32)               :: bottom                           !< The lower right area.
character(len=16)            :: arg                              !< Command argument.
character(len=24)            :: label                            !< Legend label.

x = [(real(i - 1, real64) / real(N - 1, real64), i = 1_int32, N)]
do j = 1_int32, NF
   do i = 1_int32, NF
      f(i, j) = sin(6.0_real64 * real(i, real64) / NF) * cos(4.0_real64 * real(j, real64) / NF)
   enddo
enddo
amplitude = 0.8_real64
rate = 2.5_real64
cells = 128_int32
viscous = .true.
frame = 0_int32
call get_command_argument(1, arg)
cycle_themes = trim(arg) == 'cycle'

call app%init('FIGURE: gallery', 1100_int32, 640_int32)
do while (app%next_frame())
   if (cycle_themes .and. mod(frame, 45_int32) == 0_int32) &
      call app%set_style(trim(THEMES(mod(frame / 45_int32, NT) + 1_int32)))
   frame = frame + 1_int32
   root = ig_dock_id('gallery')
   if (ig_dock_layout_begin(root)) then
      call ig_dock_split(root, 'left', 0.3_real64, left, right)
      call ig_dock_split(right, 'down', 0.45_real64, bottom, top)
      call ig_dock_window('Controls', left)
      call ig_dock_window('Signals', top)
      call ig_dock_window('Field', bottom)
      call ig_dock_layout_end(root)
   endif
   call ig_dock_space(root)
   if (ig_begin('Controls')) then
      if (ig_slider('amplitude', amplitude, 0.0_real64, 1.0_real64)) continue
      if (ig_slider('rate', rate, 0.5_real64, 5.0_real64)) continue
      if (ig_slider('cells', cells, 16_int32, 512_int32)) continue
      if (ig_input('time step', rate, 0.1_real64)) continue
      if (ig_checkbox('viscous', viscous)) continue
      call ig_separator()
      if (ig_button('Run')) continue
      call ig_same_line()
      if (ig_button('Reset')) continue
      call ig_text('iterations: 1200, residual 3.2e-07')
   endif
   call ig_end()
   if (ig_begin('Signals')) then
      if (ip_begin_plot('Probes', height=-1.0_real64)) then
         call ip_setup_axes('t', 'u')
         do k = 1_int32, 5_int32
            write(label, '(A,I0)') 'probe ', k
            call ip_line(trim(label), x, amplitude * exp(-0.4_real64 * k * x) * &
                                         sin(rate * 6.0_real64 * x + 0.9_real64 * k))
         enddo
         call ip_end_plot()
      endif
   endif
   call ig_end()
   if (ig_begin('Field')) then
      if (ip_begin_plot('f(x, y)', width=-90.0_real64, height=-1.0_real64)) then
         call ip_heatmap('f', f, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, scale_min=-1.0_real64, &
                         scale_max=1.0_real64, colormap=ImPlotColormap_Viridis)
         call ip_end_plot()
      endif
      call ig_same_line()
      call ip_colormap_scale('##scale', -1.0_real64, 1.0_real64, width=80.0_real64, height=-1.0_real64, &
                             colormap=ImPlotColormap_Viridis)
   endif
   call ig_end()
enddo
call app%destroy()
endprogram gallery
