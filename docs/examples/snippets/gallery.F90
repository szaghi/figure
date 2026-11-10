!< gallery, the style gallery: one program, recorded in every built-in theme (run with "cycle" to switch them live),
!< and the galleries of palettes, looks and colormaps (run with "palettes", "looks", "colormaps" or "jet"), the layout
!< metrics (run with "layout_metrics"), the numbers and choices (run with "numbers_and_choices") and the canvas's
!< drawing primitives (run with "canvas_primitives") and the axis layouts of a plot (run with "plot_axes").
program gallery
!< gallery, the style gallery: one program, recorded in every built-in theme (run with "cycle" to switch them live),
!< and the galleries of palettes, looks and colormaps (run with "palettes", "looks", "colormaps" or "jet").
!<
!< The galleries draw one small window per palette (or look), each after its own `app%set_style` call: the colours and
!< sizes a widget is drawn with are those in effect when it is declared, so one frame shows them all side by side.
!<
!< "layout_metrics" draws a form and, over it, the lengths FIGURE's layout calls give as dimension lines: the font size
!< (1 em), the line and frame heights with and without spacing, a width in em, the space left, the window padding, the
!< item spacing, an indent and a right-aligned group. The lines are drawn with the canvas's primitives (`ig_draw_line`,
!< `ig_draw_polygon`, `ig_draw_text`) on the window's layer, in screen pixels.
!<
!< "numbers_and_choices" draws every number widget of each kind, scale and shape, and the three ways to choose: radio
!< buttons, a combo, a list box; each with its call written beside it.
!<
!< "canvas_primitives" draws each primitive of the canvas in a cell of its own (a canvas), its call written below it,
!< and the plot layer: a shape in plot units inside a plot.
!<
!< "plot_axes" draws six plots in a grid, each an axis layout with its calls in its title: two y axes, three y axes, a
!< second x axis with fixed ticks, a log axis, a symmetric log axis, a time axis.
use, intrinsic :: iso_fortran_env, only : int8, int32, int64, real32, real64
use figure, only : app_object, ig_begin, ig_button, ig_checkbox, ig_dock_id, ig_dock_layout_begin, ig_dock_layout_end, &
                   ig_dock_space, ig_dock_split, ig_dock_window, ig_end, ig_input, ig_same_line, ig_selectable,          &
                   ig_separator, ig_set_next_window, ig_slider, ig_text, ig_text_colored, ig_text_disabled,              &
                   ip_begin_plot, ip_colormap_scale, ip_end_plot, ip_heatmap, ip_line, ip_setup_axes,                    &
                   ImPlotColormap_Viridis, ip_colormap, ip_colormap_names
use figure, only : ig_align_begin, ig_align_end, ig_align_text_to_frame_padding, ig_available, ig_em, ig_font_size, &
                   ig_frame_height, ig_get_style_var, ig_indent, ig_input_text, ig_last_item, ig_line_height,         &
                   ig_pop_item_width, ig_push_item_width, ig_unindent, item_status_object, ig_dummy, ig_text_size
use figure, only : ig_combo, ig_drag, ig_drag_range, ig_list_box, ig_radio, ig_separator_text, &
                   ig_set_next_item_width, ig_slider_angle, ig_text_disabled
use figure, only : ig_draw_line, ig_draw_polygon, ig_draw_text, canvas_event_object, ig_begin_group, ig_canvas, &
                   ig_draw_circle, ig_draw_image, ig_draw_polyline, ig_draw_rect, ig_end_group, texture_object, &
                   ip_setup_axes_limits
use figure, only : ip_begin_subplots, ip_end_subplots, ip_set_axes, ip_setup_axis, ip_setup_axis_limits, &
                   ip_setup_axis_ticks, ip_setup_legend

implicit none
integer(int32),    parameter :: N = 200_int32                    !< Points per line.
integer(int32),    parameter :: NF = 60_int32                    !< Field size.
real(real64), parameter :: DIM(4) = [240.0_real64, 176.0_real64, 64.0_real64, 255.0_real64] / 255.0_real64 !< Dimension colour.
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
character(len=32)            :: arg                              !< Command argument.
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

if (trim(arg) == 'layout_metrics') then
   call app%init('FIGURE: layout metrics', 680_int32, 400_int32)
   do while (app%next_frame())
      call metrics()
   enddo
   call app%destroy()
   stop
endif
if (trim(arg) == 'plot_axes') then
   call app%init('FIGURE: plot axes', 1000_int32, 640_int32)
   do while (app%next_frame())
      call plot_axes()
   enddo
   call app%destroy()
   stop
endif
if (trim(arg) == 'canvas_primitives') then
   call app%init('FIGURE: canvas primitives', 900_int32, 520_int32)
   do while (app%next_frame())
      call canvas_primitives()
   enddo
   call app%destroy()
   stop
endif
if (trim(arg) == 'numbers_and_choices') then
   call app%init('FIGURE: numbers and choices', 1010_int32, 450_int32)
   do while (app%next_frame())
      call numbers_and_choices()
   enddo
   call app%destroy()
   stop
endif
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
   subroutine numbers_and_choices()
   !< Every number widget, by kind, shape and scale, then the three ways to choose; the call beside each widget.
   integer(int32), save :: n32 = 128_int32                                     !< An int32.
   integer(int64), save :: n64 = 6000000000_int64                              !< An int64 beyond 2**31.
   real(real32),   save :: r32 = 1.5e-4_real32                                 !< A real32.
   real(real64),   save :: r64 = 0.8_real64                                    !< A real64.
   real(real64),   save :: v3(3) = [0.0_real64, 0.0_real64, -9.81_real64]      !< A 3-vector.
   integer(int32), save :: grid(2) = [256_int32, 128_int32]                    !< An integer 2-vector.
   real(real64),   save :: cfl = 0.1_real64                                    !< On a log scale.
   real(real64),   save :: angle = 0.785398_real64                             !< An angle [radians].
   real(real64),   save :: lo = 0.2_real64                                     !< A range.
   real(real64),   save :: hi = 0.7_real64                                     !< ...
   integer(int32), save :: scheme = 2_int32                                    !< A radio group.
   integer(int32), save :: limiter = 4_int32                                   !< A combo.
   integer(int32), save :: block = 3_int32                                     !< A list box.
   character(len=10)    :: blocks(12)                                          !< The list.
   real(real64)         :: w                                                   !< Width of the widgets [pixels].

   do i = 1_int32, size(blocks, kind=int32)
      write(blocks(i), '(A,I0)') 'block ', i
   enddo
   w = ig_em(15.0_real64)
   call ig_set_next_window(10.0_real64, 10.0_real64, 640.0_real64, 430.0_real64)
   if (ig_begin('Numbers')) then
      call ig_separator_text('fields: ig_input')
      call ig_set_next_item_width(w)
      if (ig_input('int32', n32, step=1_int32)) continue
      call note('ig_input(..., n32, step=1)')
      call ig_set_next_item_width(w)
      if (ig_input('int64', n64, format='%d cells')) continue
      call note("format='%d cells'")
      call ig_set_next_item_width(w)
      if (ig_input('real32', r32, format='%.3e')) continue
      call note("format='%.3e'")
      call ig_set_next_item_width(w)
      if (ig_input('vector', v3, format='%.2f')) continue
      call note('a vector of 3 real64')
      call ig_separator_text('drag boxes: ig_drag')
      call ig_set_next_item_width(w)
      if (ig_drag('real64', r64, speed=0.01_real64, format='%.2f')) continue
      call note('speed=0.01')
      call ig_set_next_item_width(w)
      if (ig_drag('gravity', v3, speed=0.01_real64, format='%.2f m/s²')) continue
      call note("format='%.2f m/s²'")
      call ig_set_next_item_width(w)
      if (ig_drag('cells', grid, speed=1.0_real64, vmin=1_int32, vmax=4096_int32)) continue
      call note("a vector of 2 int32")
      call ig_separator_text('sliders: ig_slider, ig_slider_angle')
      call ig_set_next_item_width(w)
      if (ig_slider('linear', r64, 0.0_real64, 1.0_real64)) continue
      call note('ig_slider(..., 0.0, 1.0)')
      call ig_set_next_item_width(w)
      if (ig_slider('CFL', cfl, 1.0e-3_real64, 10.0_real64, format='%.3g', scale='log')) continue
      call note("scale='log', 1e-3 to 10")
      call ig_set_next_item_width(w)
      if (ig_slider_angle('angle', angle, 0.0_real64, 360.0_real64)) continue
      call note('radians shown in degrees')
      call ig_separator_text('a range: ig_drag_range')
      call ig_set_next_item_width(w)
      if (ig_drag_range('range', lo, hi, speed=0.01_real64, vmin=0.0_real64, vmax=1.0_real64, format='%.2f')) continue
      call note('lo, hi in [0, 1]')
   endif
   call ig_end()
   call ig_set_next_window(660.0_real64, 10.0_real64, 340.0_real64, 430.0_real64)
   if (ig_begin('Choices')) then
      call ig_separator_text('a few, all shown: ig_radio')
      if (ig_radio('WENO5', scheme, 1_int32)) continue
      call ig_same_line()
      if (ig_radio('WENO7', scheme, 2_int32)) continue
      call ig_same_line()
      if (ig_radio('TVD', scheme, 3_int32)) continue
      call ig_separator_text('many, on demand: ig_combo')
      call ig_set_next_item_width(w)
      if (ig_combo('limiter', limiter, [character(len=10) :: 'minmod', 'van Leer', 'van Albada', 'superbee'])) continue
      call ig_separator_text('a long list in view: ig_list_box')
      call ig_set_next_item_width(w)
      if (ig_list_box('block', block, blocks)) continue
      call ig_text_disabled('(7 rows shown, it scrolls)')
   endif
   call ig_end()
   endsubroutine numbers_and_choices

   subroutine plot_axes()
   !< Six axis layouts in a grid of plots, each titled with the calls that make it.
   integer(int32), parameter :: M = 300_int32 !< Samples.
   real(real64)              :: t(M)          !< Abscissae: iterations.
   real(real64)              :: a(M)          !< A residual, falling over six decades.
   real(real64)              :: b(M)          !< A coefficient near 0.8.
   real(real64)              :: c(M)          !< A temperature near 300.
   real(real64)              :: s(M)          !< A signed quantity over [-5000, 5000].
   real(real64)              :: clock(M)      !< UNIX seconds over three hours of 2026-11-09.

   t = [(real(i, real64), i = 1_int32, M)]
   a = 10.0_real64**(-6.0_real64 * t / real(M, real64)) * (1.0_real64 + 0.3_real64 * sin(t / 5.0_real64))
   b = 0.8_real64 + 0.2_real64 * exp(-t / 60.0_real64) * cos(t / 12.0_real64)
   c = 300.0_real64 + 20.0_real64 * (1.0_real64 - exp(-t / 80.0_real64))
   s = 5000.0_real64 * sin(t / 30.0_real64) * exp(-t / 200.0_real64)
   clock = 1794211200.0_real64 + 36.0_real64 * t
   call ig_set_next_window(10.0_real64, 10.0_real64, 980.0_real64, 620.0_real64)
   if (ig_begin('Axis layouts')) then
      if (ip_begin_subplots('##axes', 2_int32, 3_int32, height=-1.0_real64)) then
         if (ip_begin_plot("ip_setup_axis('y2'): a second y axis")) then
            call ip_setup_axis('y1', label='residual', scale='log')
            call ip_setup_axis('y2', label='cl')
            call ip_setup_legend('s')
            call ip_line('residual (y1)', t, a)
            call ip_set_axes('x1', 'y2')
            call ip_line('cl (y2)', t, b)
            call ip_end_plot()
         endif
         if (ip_begin_plot("'y2' and 'y3': three y axes")) then
            call ip_setup_axis('y2', label='cl')
            call ip_setup_axis('y3', label='T [K]')
            call ip_setup_legend('se')
            call ip_line('residual (y1)', t, a * 1.0e3_real64)
            call ip_set_axes('x1', 'y2')
            call ip_line('cl (y2)', t, b)
            call ip_set_axes('x1', 'y3')
            call ip_line('T (y3)', t, c)
            call ip_end_plot()
         endif
         if (ip_begin_plot("'x2' on top, fixed ticks")) then
            call ip_setup_axis('x1', label='iteration')
            call ip_setup_axis('x2', label='phase')
            call ip_setup_axis_limits('x2', 0.0_real64, 3.0_real64)
            call ip_setup_axis_ticks('x2', [0.5_real64, 1.5_real64, 2.5_real64], &
                                     [character(len=8) :: 'start', 'settle', 'steady'])
            call ip_line('cl over iterations (x1)', t, b)
            call ip_end_plot()
         endif
         if (ip_begin_plot("scale='log'")) then
            call ip_setup_axis('y1', label='residual', scale='log')
            call ip_line('residual', t, a)
            call ip_line('residual / 10', t, a / 10.0_real64)
            call ip_end_plot()
         endif
         if (ip_begin_plot("scale='symlog': both signs")) then
            call ip_setup_axis('y1', label='vorticity', scale='symlog')
            call ip_line('vorticity', t, s)
            call ip_end_plot()
         endif
         if (ip_begin_plot("scale='time' (x only)")) then
            call ip_setup_axis('x1', label='UTC', scale='time')
            call ip_setup_axis('y1', label='T [K]')
            call ip_line('T', clock, c)
            call ip_end_plot()
         endif
         call ip_end_subplots()
      endif
   endif
   call ig_end()
   endsubroutine plot_axes

   subroutine canvas_primitives()
   !< Each drawing primitive in a cell of its own, its call below it; then the plot layer, inside a plot.
   real(real64), parameter :: CW = 200.0_real64                                  !< A cell's width [pixels].
   real(real64), parameter :: CH = 110.0_real64                                  !< Its height [pixels].
   real(real64), parameter :: AMBER(3) = [0.94_real64, 0.69_real64, 0.25_real64] !< The shapes' colour.
   real(real64), parameter :: TEAL(3) = [0.30_real64, 0.75_real64, 0.70_real64]  !< A second colour.
   type(canvas_event_object), save :: ev                                         !< A cell.
   type(texture_object),      save :: tex                                        !< A small image.
   integer(int8)                   :: px(4, 8, 8)                                !< Its pixels.
   real(real64)                    :: x0, y0                                     !< A cell's top-left [pixels].
   real(real64)                    :: t(7)                                       !< Polygon angles [radians].
   integer(int32)                  :: c                                          !< Cell.

   if (.not. tex%is_initialized()) then
      do j = 1_int32, 8_int32
         do i = 1_int32, 8_int32
            px(:, i, j) = int([30 * i - 128, 30 * j - 128, 100, -1], int8) ! -1: 255, opaque
         enddo
      enddo
      call tex%init(8_int32, 8_int32)
      call tex%update(px)
   endif
   t = [(2.0_real64 * acos(-1.0_real64) * real(i, real64) / 7.0_real64, i = 0_int32, 6_int32)]
   call ig_set_next_window(10.0_real64, 10.0_real64, 880.0_real64, 500.0_real64)
   if (ig_begin('Canvas primitives')) then
      do c = 1_int32, 8_int32
         if (mod(c - 1_int32, 4_int32) /= 0_int32) call ig_same_line()
         call ig_begin_group()
         call ig_canvas('cell'//achar(48 + c), CW, CH, ev)
         x0 = ev%origin(1)
         y0 = ev%origin(2)
         call ig_draw_rect(x0, y0, x0 + CW, y0 + CH, [1.0_real64, 1.0_real64, 1.0_real64, 0.12_real64])
         select case (c)
         case (1_int32)
            call ig_draw_line(x0 + 20.0_real64, y0 + 90.0_real64, x0 + 180.0_real64, y0 + 20.0_real64, AMBER, 3.0_real64)
            call ig_text_disabled('ig_draw_line(..., thickness=3)')
         case (2_int32)
            call ig_draw_rect(x0 + 20.0_real64, y0 + 20.0_real64, x0 + 90.0_real64, y0 + 90.0_real64, AMBER, 2.0_real64)
            call ig_draw_rect(x0 + 110.0_real64, y0 + 20.0_real64, x0 + 180.0_real64, y0 + 90.0_real64, TEAL, filled=.true.)
            call ig_text_disabled('ig_draw_rect(..., filled=.true.)')
         case (3_int32)
            call ig_draw_circle(x0 + 60.0_real64, y0 + 55.0_real64, 35.0_real64, AMBER, 2.0_real64)
            call ig_draw_circle(x0 + 140.0_real64, y0 + 55.0_real64, 35.0_real64, TEAL, filled=.true.)
            call ig_text_disabled('ig_draw_circle(x, y, radius, ...)')
         case (4_int32)
            call ig_draw_polyline(x0 + 20.0_real64 + 160.0_real64 * [(real(i, real64) / 40.0_real64, i = 0_int32, 40_int32)], &
                                  y0 + 55.0_real64 - 35.0_real64 * sin([(real(i, real64) / 40.0_real64, i = 0_int32, &
                                  40_int32)] * 4.0_real64 * acos(-1.0_real64)), AMBER, 2.0_real64)
            call ig_text_disabled('ig_draw_polyline(x(:), y(:), ...)')
         case (5_int32)
            call ig_draw_polygon(x0 + 60.0_real64 + 40.0_real64 * cos(t), y0 + 55.0_real64 + 40.0_real64 * sin(t), &
                                 AMBER, 2.0_real64)
            call ig_draw_polygon(x0 + 140.0_real64 + [-35.0_real64, 35.0_real64, 0.0_real64, 0.0_real64], &
                                 y0 + [90.0_real64, 90.0_real64, 55.0_real64, 20.0_real64], TEAL, filled=.true.)
            call ig_text_disabled('ig_draw_polygon(..., filled=.true.)')
         case (6_int32)
            call ig_draw_text(x0 + 20.0_real64, y0 + 30.0_real64, 'inlet, u = 1 m/s', AMBER)
            call ig_draw_text(x0 + 20.0_real64, y0 + 60.0_real64, 'wall'//achar(10)//'no slip', TEAL)
            call ig_text_disabled('ig_draw_text(x, y, text, ...)')
         case (7_int32)
            call ig_draw_image(tex, x0 + 20.0_real64, y0 + 15.0_real64, x0 + 100.0_real64, y0 + 95.0_real64)
            call ig_draw_image(tex, x0 + 110.0_real64, y0 + 15.0_real64, x0 + 190.0_real64, y0 + 95.0_real64, &
                               color=[1.0_real64, 0.5_real64, 0.5_real64])
            call ig_text_disabled('ig_draw_image(tex, ..., color)')
         case default
            call ig_draw_line(x0 + 100.0_real64, y0 + 10.0_real64, x0 + 100.0_real64, y0 + 100.0_real64, TEAL)
            call ig_draw_line(x0 + 10.0_real64, y0 + 55.0_real64, x0 + 190.0_real64, y0 + 55.0_real64, TEAL)
            call ig_draw_text(x0 + 104.0_real64, y0 + 10.0_real64, 'ev%origin + [cx, cy]', AMBER)
            call ig_draw_circle(x0 + 100.0_real64, y0 + 55.0_real64, 4.0_real64, AMBER, filled=.true.)
            call ig_text_disabled('ig_canvas(id, w, h, ev)')
         endselect
         call ig_end_group()
      enddo
      call ig_separator_text('layer=''plot'': plot units, clipped to the plot')
      if (ip_begin_plot('##plot layer', 860.0_real64, 170.0_real64)) then
         call ip_setup_axes('x [m]', 'y [m]')
         call ip_setup_axes_limits(0.0_real64, 4.0_real64, -0.2_real64, 1.2_real64)
         call ip_line('u', x * 4.0_real64, 0.5_real64 + 0.4_real64 * sin(6.0_real64 * x))
         call ig_draw_rect(0.0_real64, 0.0_real64, 4.0_real64, 1.0_real64, TEAL, 2.0_real64, layer='plot')
         call ig_draw_circle(1.0_real64, 0.5_real64, 12.0_real64, AMBER, filled=.true., layer='plot')
         call ig_draw_text(1.1_real64, 0.45_real64, 'probe at (1, 0.5) m', AMBER, layer='plot')
         call ip_end_plot()
      endif
   endif
   call ig_end()
   endsubroutine canvas_primitives

   subroutine note(text)
   !< A note on the widget just drawn, in grey, on its line.
   character(len=*), intent(in) :: text !< What the widget shows.
   call ig_same_line()
   call ig_text_disabled(text)
   endsubroutine note

   subroutine metrics()
   !< The layout metrics over a form: each length FIGURE's layout calls give, as a dimension line, its call written in
   !< a column at the right, level with it. The form leaves an empty row (`ig_dummy`) below each part for its lines.
   type(item_status_object) :: s         !< Status of an item.
   character(len=24)        :: name      !< A field.
   real(real64)             :: l1(4)     !< Line 1's rectangle [pixels].
   real(real64)             :: l2(4)     !< Line 2's.
   real(real64)             :: f1(4)     !< The first field's.
   real(real64)             :: f2(4)     !< The second field's.
   real(real64)             :: b1(4)     !< The two buttons'.
   real(real64)             :: b2(4)     !< ...
   real(real64)             :: ind(4)    !< The indented text's.
   real(real64)             :: grp(4)    !< The right-aligned group's.
   real(real64)             :: y(7)      !< The middle of each empty row [pixels].
   real(real64)             :: w         !< ig_available's width [pixels].
   real(real64)             :: h         !< ... height, not shown.
   real(real64)             :: x0        !< The window's left edge [pixels].
   real(real64)             :: xc        !< The content's left edge [pixels].
   real(real64)             :: xl        !< The labels' column [pixels].
   real(real64)             :: xv        !< The vertical lines' column [pixels].
   character(len=48)        :: t         !< A label.

   name = 'wing-body'
   call ig_set_next_window(10.0_real64, 10.0_real64, 660.0_real64, 380.0_real64)
   if (ig_begin('Layout metrics')) then
      call ig_text('A line of text')
      s = ig_last_item()
      l1 = s%rect
      call ig_text('the next line')
      s = ig_last_item()
      l2 = s%rect
      y(1) = row(1.2_real64)
      call ig_push_item_width(ig_em(12))
      call ig_align_text_to_frame_padding()
      call ig_text('name')
      call ig_same_line(ig_em(5))
      if (ig_input_text('##name', name)) continue
      s = ig_last_item()
      f1 = s%rect
      call ig_align_text_to_frame_padding()
      call ig_text('case')
      call ig_same_line(ig_em(5))
      if (ig_input_text('##case', name)) continue
      s = ig_last_item()
      f2 = s%rect
      call ig_pop_item_width()
      y(2) = row(1.2_real64)
      if (ig_button('Apply')) continue
      s = ig_last_item()
      b1 = s%rect
      call ig_same_line()
      if (ig_button('Cancel')) continue
      s = ig_last_item()
      b2 = s%rect
      y(3) = row(1.2_real64)
      y(4) = row(1.2_real64)
      call ig_indent()
      call ig_text('indented')
      s = ig_last_item()
      ind = s%rect
      call ig_unindent()
      y(5) = row(1.2_real64)
      call ig_available(w, h)
      y(6) = row(2.4_real64)
      y(7) = row(1.2_real64)
      call ig_align_begin('buttons', 'right')
      if (ig_button('OK')) continue
      call ig_same_line()
      if (ig_button('Close')) continue
      call ig_align_end()
      s = ig_last_item()
      grp = s%rect
      ! the dimension lines; their calls in the column at xl
      xc = l1(1)
      x0 = 10.0_real64
      xv = f1(1) + f1(3) + ig_em(1)
      xl = xv + ig_em(3)
      write(t, '(A,I0,A)') 'ig_font_size() = 1 em = ', nint(ig_font_size()), ' px'
      call vdim(xv, l1(2), l1(2) + ig_line_height(), xl, l1(2) + 0.5_real64 * l1(4), trim(t))
      write(t, '(A,I0,A)') 'ig_line_height(spacing=.true.) = ', nint(ig_line_height(spacing=.true.)), ' px'
      call vdim(xv + ig_em(1), l1(2), l2(2), xl, l2(2) + 0.5_real64 * l2(4), trim(t))
      call hdim(x0, f1(1), y(1), xl, 'ig_same_line(ig_em(5)): from the window''s edge')
      write(t, '(A,I0,A)') 'ig_frame_height() = ', nint(ig_frame_height()), ' px'
      call vdim(xv, f1(2), f1(2) + f1(4), xl, f1(2) + 0.5_real64 * f1(4), trim(t))
      write(t, '(A,I0,A)') 'ig_frame_height(spacing=.true.) = ', nint(ig_frame_height(spacing=.true.)), ' px'
      call vdim(xv + ig_em(1), f1(2), f2(2), xl, f2(2) + 0.5_real64 * f2(4), trim(t))
      write(t, '(A,I0,A)') 'ig_push_item_width(ig_em(12)) = ', nint(f1(3)), ' px'
      call hdim(f1(1), f1(1) + f1(3), y(2), xl, trim(t))
      call hdim(x0, xc, y(3), xl, 'WindowPadding (style)')
      call hdim(b1(1) + b1(3), b2(1), y(4), xl, 'ItemSpacing (style), after ig_same_line()')
      call hdim(xc, ind(1), y(5), xl, 'ig_indent(): IndentSpacing (style)')
      write(t, '(A,I0,A)') 'ig_available(w, h): w = ', nint(w), ' px'
      call hdim(xc, xc + w, y(6) + 0.25_real64 * ig_line_height(), -1.0_real64, trim(t))
      call hdim(grp(1), grp(1) + grp(3), y(7), -2.0_real64, 'ig_align_begin(''buttons'', ''right'')')
   endif
   call ig_end()
   endsubroutine metrics

   function row(lines) result(ymid)
   !< An empty row `lines` lines of text high (`ig_dummy`): its middle [pixels].
   real(real64), intent(in) :: lines !< Height [lines of text].
   real(real64)             :: ymid  !< Its middle [pixels].
   type(item_status_object) :: s     !< Its status.
   call ig_dummy(1.0_real64, lines * ig_line_height())
   s = ig_last_item()
   ymid = s%rect(2) + 0.5_real64 * s%rect(4)
   endfunction row

   subroutine vdim(x, ya, yb, xl, yl, label)
   !< A vertical dimension line at `x` from `ya` to `yb` [pixels], `label` at (`xl`, `yl`) with a leader to it.
   real(real64),     intent(in) :: x     !< Abscissa [pixels].
   real(real64),     intent(in) :: ya    !< From [pixels].
   real(real64),     intent(in) :: yb    !< To [pixels].
   real(real64),     intent(in) :: xl    !< The label's left [pixels].
   real(real64),     intent(in) :: yl    !< Its middle [pixels].
   character(len=*), intent(in) :: label !< Text.

   call ig_draw_line(x, ya, x, yb, DIM)
   call ig_draw_line(x - 5.0_real64, ya, x + 5.0_real64, ya, DIM)
   call ig_draw_line(x - 5.0_real64, yb, x + 5.0_real64, yb, DIM)
   call ig_draw_polygon([x, x - 3.0_real64, x + 3.0_real64], [ya, ya + 5.0_real64, ya + 5.0_real64], DIM, filled=.true.)
   call ig_draw_polygon([x, x + 3.0_real64, x - 3.0_real64], [yb, yb - 5.0_real64, yb - 5.0_real64], DIM, filled=.true.)
   call leader(x + 4.0_real64, 0.5_real64 * (ya + yb), xl, yl, label)
   endsubroutine vdim

   subroutine hdim(xa, xb, y, xl, label)
   !< A horizontal dimension line at `y` from `xa` to `xb` [pixels]; `label` at `xl` with a leader to it, or, for `xl`
   !< -1, centred above the line, -2, at the left of its start.
   real(real64),     intent(in) :: xa    !< From [pixels].
   real(real64),     intent(in) :: xb    !< To [pixels].
   real(real64),     intent(in) :: y     !< Ordinate [pixels].
   real(real64),     intent(in) :: xl    !< The label's left [pixels], or -1, -2.
   character(len=*), intent(in) :: label !< Text.
   real(real64)                 :: tw    !< The label's width [pixels].
   real(real64)                 :: ext(2) !< The label's width and height [pixels].

   call ig_draw_line(xa, y, xb, y, DIM)
   call ig_draw_line(xa, y - 5.0_real64, xa, y + 5.0_real64, DIM)
   call ig_draw_line(xb, y - 5.0_real64, xb, y + 5.0_real64, DIM)
   call ig_draw_polygon([xa, xa + 5.0_real64, xa + 5.0_real64], [y, y + 3.0_real64, y - 3.0_real64], DIM, filled=.true.)
   call ig_draw_polygon([xb, xb - 5.0_real64, xb - 5.0_real64], [y, y - 3.0_real64, y + 3.0_real64], DIM, filled=.true.)
   if (len(label) == 0) return
   if (xl > 0.0_real64) then
      call leader(xb + 4.0_real64, y, xl, y, label)
   else
      ext = ig_text_size(label)
      tw = ext(1)
      if (xl < -1.5_real64) then
         call text_at(xa - tw - 10.0_real64, y, label)
      else
         call text_at(0.5_real64 * (xa + xb - tw), y - ig_line_height(), label)
      endif
   endif
   endsubroutine hdim

   subroutine leader(xa, ya, xl, yl, label)
   !< A thin leader from (`xa`, `ya`) to the label at (`xl`, `yl`), when there is room, and the label.
   real(real64),     intent(in) :: xa    !< From [pixels].
   real(real64),     intent(in) :: ya    !< ...
   real(real64),     intent(in) :: xl    !< The label's left [pixels].
   real(real64),     intent(in) :: yl    !< Its middle [pixels].
   character(len=*), intent(in) :: label !< Text.

   if (xl - 6.0_real64 > xa) call ig_draw_line(xa, ya, xl - 6.0_real64, yl, [DIM(1:3), 110.0_real64 / 255.0_real64])
   call text_at(xl, yl, label)
   endsubroutine leader

   subroutine text_at(x, ymid, label)
   !< `label` from `x`, its middle at `ymid` [pixels].
   real(real64),     intent(in) :: x     !< Left [pixels].
   real(real64),     intent(in) :: ymid  !< Middle [pixels].
   character(len=*), intent(in) :: label !< Text.
   call ig_draw_text(x, ymid - 0.5_real64 * ig_line_height(), label, DIM)
   endsubroutine text_at


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
