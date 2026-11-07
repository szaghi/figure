!< gallery, the style gallery: one program, recorded in every built-in theme (run with "cycle" to switch them live),
!< and the galleries of palettes, looks and colormaps (run with "palettes", "looks", "colormaps" or "jet").
program gallery
!< gallery, the style gallery: one program, recorded in every built-in theme (run with "cycle" to switch them live),
!< and the galleries of palettes, looks and colormaps (run with "palettes", "looks", "colormaps" or "jet").
!<
!< The galleries draw one small window per palette (or look), each after its own `app%set_style` call: the colours and
!< sizes a widget is drawn with are those in effect when it is declared, so one frame shows them all side by side.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_button, ig_checkbox, ig_dock_id, ig_dock_layout_begin, ig_dock_layout_end, &
                   ig_dock_space, ig_dock_split, ig_dock_window, ig_end, ig_input, ig_same_line, ig_selectable,          &
                   ig_separator, ig_set_next_window, ig_slider, ig_text, ig_text_colored, ig_text_disabled,              &
                   ip_begin_plot, ip_colormap_scale, ip_end_plot, ip_heatmap, ip_line, ip_setup_axes,                    &
                   ImPlotColormap_Viridis, ip_colormap, ip_colormap_names

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
character(len=:), allocatable :: names(:)                        !< Every colormap name.
character(len=12)            :: own(16)                          !< ImPlot's own colormaps.
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

if (trim(arg) == 'colormaps') then
   call app%init('FIGURE: colormaps', 1240_int32, 760_int32)
   call ip_colormap_names(names)
   do while (app%next_frame())
      call swatches('Sequential', [character(len=9) :: 'cividis', 'inferno', 'magma', 'batlow', 'thermal', 'haline', &
                                   'deep', 'turbo'], 10.0_real64, 10.0_real64, 690.0_real64)
      call swatches('Diverging', [character(len=9) :: 'cool-warm', 'balance', 'curl', 'vik', 'roma'], 710.0_real64, &
                    10.0_real64, 400.0_real64)
      call swatches('Cyclic', [character(len=9) :: 'romaO'], 1120.0_real64, 10.0_real64, 100.0_real64)
      k = findloc(names, 'Deep', dim=1)         ! ImPlot's 16, after the bundled ones
      own = names(k:k + 15)                     ! a copy: gfortran passes a section of names from its start (known issues)
      call swatches("ImPlot's own", own, 10.0_real64, 380.0_real64, 1220.0_real64)
   enddo
   call app%destroy()
   stop
endif
if (trim(arg) == 'jet') then ! the same smooth field in Jet and in cividis: Jet draws bands the data do not have
   do j = 1_int32, NF
      do i = 1_int32, NF
         f(i, j) = exp(-((real(i, real64) / NF - 0.45_real64)**2 + (real(j, real64) / NF - 0.55_real64)**2) / 0.08_real64)
      enddo
   enddo
   call app%init('FIGURE: Jet and cividis', 1100_int32, 470_int32)
   do while (app%next_frame())
      call field('Jet (misleading)', 'Jet', 10.0_real64)
      call field('cividis (perceptually uniform)', 'cividis', 555.0_real64)
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
   subroutine swatches(title, maps, left, top, width)
   !< A window of colour bars, one per colormap, each named by its label.
   character(len=*), intent(in) :: title   !< Window title (the category).
   character(len=*), intent(in) :: maps(:) !< Colormap names.
   real(real64),     intent(in) :: left    !< Left [pixels].
   real(real64),     intent(in) :: top     !< Top [pixels].
   real(real64),     intent(in) :: width   !< Width [pixels].
   integer(int32)               :: m       !< Map.

   call ig_set_next_window(left, top, width, 360.0_real64, always=.true.)
   if (ig_begin(title)) then
      do m = 1_int32, size(maps, kind=int32)
         if (m > 1_int32) call ig_same_line()
         call ip_colormap_scale(trim(maps(m)), 0.0_real64, 1.0_real64, width=64.0_real64, height=300.0_real64, &
                                label_format='%.1f', colormap=ip_colormap(trim(maps(m))))
      enddo
   endif
   call ig_end()
   endsubroutine swatches

   subroutine field(title, map, left)
   !< A window with the field f in the colormap `map`, and its colour bar.
   character(len=*), intent(in) :: title !< Window title.
   character(len=*), intent(in) :: map   !< Colormap name.
   real(real64),     intent(in) :: left  !< Left [pixels].

   call ig_set_next_window(left, 10.0_real64, 535.0_real64, 450.0_real64, always=.true.)
   if (ig_begin(title)) then
      if (ip_begin_plot('##'//map, width=-90.0_real64, height=-1.0_real64, equal=.true.)) then
         call ip_heatmap('f', f, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, scale_min=0.0_real64, &
                         scale_max=1.0_real64, colormap=ip_colormap(map))
         call ip_end_plot()
      endif
      call ig_same_line()
      call ip_colormap_scale('##'//map//' scale', 0.0_real64, 1.0_real64, width=80.0_real64, height=-1.0_real64, &
                             colormap=ip_colormap(map))
   endif
   call ig_end()
   endsubroutine field

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
