!< gallery, the style gallery: one program, recorded in every built-in theme (run with "cycle" to switch them live),
!< and the galleries of palettes and looks (run with "palettes" or "looks").
program gallery
!< gallery, the style gallery: one program, recorded in every built-in theme (run with "cycle" to switch them live),
!< and the galleries of palettes and looks (run with "palettes" or "looks").
!<
!< The galleries draw one small window per palette (or look), each after its own `app%set_style` call: the colours and
!< sizes a widget is drawn with are those in effect when it is declared, so one frame shows them all side by side.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_button, ig_checkbox, ig_dock_id, ig_dock_layout_begin, ig_dock_layout_end, &
                   ig_dock_space, ig_dock_split, ig_dock_window, ig_end, ig_input, ig_same_line, ig_selectable,          &
                   ig_separator, ig_set_next_window, ig_slider, ig_text, ig_text_colored, ig_text_disabled,              &
                   ip_begin_plot, ip_colormap_scale, ip_end_plot, ip_heatmap, ip_line, ip_setup_axes,                    &
                   ImPlotColormap_Viridis

implicit none
integer(int32),    parameter :: N = 200_int32                    !< Points per line.
integer(int32),    parameter :: NF = 60_int32                    !< Field size.
integer(int32),    parameter :: NT = 7_int32                     !< Themes.
character(len=13), parameter :: THEMES(NT) = [character(len=13) :: 'seal', 'seal-light', 'paper', 'high-contrast', &
                                             'dark', 'light', 'classic']
integer(int32),    parameter :: NP = 14_int32                    !< Palettes.
character(len=16), parameter :: PALETTES(NP) = [character(len=16) :: 'seal', 'seal-light', 'paper', 'high-contrast', &
   'nord', 'solarized-dark', 'solarized-light', 'gruvbox-dark', 'gruvbox-light', 'dracula', 'catppuccin-mocha', &
   'catppuccin-latte', 'tokyo-night', 'one-dark'] !< Every bundled palette.
integer(int32),    parameter :: NL = 4_int32                     !< Looks.
character(len=8),  parameter :: LOOKS(NL) = [character(len=8) :: 'seal', 'fusion', 'adwaita', 'fluent'] !< Looks.
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

if (trim(arg) == 'palettes') then
   call app%init('FIGURE: palettes', 1190_int32, 1130_int32)
   do while (app%next_frame())
      do k = 1_int32, NP
         call app%set_style(palette=trim(PALETTES(k)))
         call sample(trim(PALETTES(k)), 10.0_real64 + 295.0_real64 * mod(k - 1_int32, 4_int32), &
                     10.0_real64 + 280.0_real64 * ((k - 1_int32) / 4_int32), 285.0_real64, 270.0_real64)
      enddo
      call app%set_style(palette='seal') ! the window's background, behind the samples
   enddo
   call app%destroy()
   stop
endif
if (trim(arg) == 'looks') then
   call app%init('FIGURE: looks', 1250_int32, 380_int32)
   do while (app%next_frame())
      do k = 1_int32, NL
         call app%set_style(look=trim(LOOKS(k)))
         call sample(trim(LOOKS(k)), 10.0_real64 + 310.0_real64 * (k - 1_int32), 10.0_real64, 300.0_real64, &
                     360.0_real64)
      enddo
      call app%set_style(look='seal')
   enddo
   call app%destroy()
   stop
endif

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

contains
   subroutine sample(title, left, top, width, height)
   !< A small window with a widget of each kind, a status line in the palette's roles and a plot.
   character(len=*), intent(in) :: title    !< Window title.
   real(real64),     intent(in) :: left     !< Left [pixels].
   real(real64),     intent(in) :: top      !< Top [pixels].
   real(real64),     intent(in) :: width    !< Width [pixels].
   real(real64),     intent(in) :: height   !< Height [pixels].
   real(real64)                 :: role(4)  !< A palette role.
   integer(int32)               :: m        !< Line.

   call ig_set_next_window(left, top, width, height, always=.true.)
   if (ig_begin(title)) then
      call ig_text('Text, and')
      call ig_same_line()
      call ig_text_disabled('dimmed text')
      if (ig_button('Run')) continue
      call ig_same_line()
      if (ig_checkbox('viscous', viscous)) continue
      call ig_same_line()
      if (ig_selectable('selected', .true.)) continue
      if (ig_slider('rate', rate, 0.5_real64, 5.0_real64)) continue
      call app%palette_color('success', role)
      call ig_text_colored('[ok] read', role)
      call ig_same_line()
      call app%palette_color('warning', role)
      call ig_text_colored('(!) slow', role)
      call ig_same_line()
      call app%palette_color('error', role)
      call ig_text_colored('[!!] failed', role)
      if (ip_begin_plot('##'//title, height=130.0_real64)) then
         do m = 1_int32, 4_int32
            write(label, '(A,I0)') 'p', m
            call ip_line(trim(label), x, amplitude * exp(-0.4_real64 * m * x) * sin(rate * 6.0_real64 * x + 0.9_real64 * m))
         enddo
         call ip_end_plot()
      endif
   endif
   call ig_end()
   endsubroutine sample
endprogram gallery
