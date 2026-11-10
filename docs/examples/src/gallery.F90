!< gallery, the style gallery: one program, recorded in every built-in theme (run with "cycle" to switch them live),
!< and the galleries of palettes, looks and colormaps (run with "palettes", "looks", "colormaps" or "jet"), and the
!< layout metrics (run with "layout_metrics").
program gallery
!< gallery, the style gallery: one program, recorded in every built-in theme (run with "cycle" to switch them live),
!< and the galleries of palettes, looks and colormaps (run with "palettes", "looks", "colormaps" or "jet").
!<
!< The galleries draw one small window per palette (or look), each after its own `app%set_style` call: the colours and
!< sizes a widget is drawn with are those in effect when it is declared, so one frame shows them all side by side.
!<
!< "layout_metrics" draws a form and, over it, the lengths FIGURE's layout calls give as dimension lines: the font size
!< (1 em), the line and frame heights with and without spacing, a width in em, the space left, the window padding, the
!< item spacing, an indent and a right-aligned group. The lines are drawn through Dear ImGui's draw list of the window
!< (cimgui's ImDrawList_* functions, declared here: FIGURE has no drawing wrappers yet).
use, intrinsic :: iso_c_binding, only : c_char, c_float, c_int, c_null_char, c_null_ptr, c_ptr
use, intrinsic :: iso_fortran_env, only : int32, int64, real64
use figure, only : app_object, ig_begin, ig_button, ig_checkbox, ig_dock_id, ig_dock_layout_begin, ig_dock_layout_end, &
                   ig_dock_space, ig_dock_split, ig_dock_window, ig_end, ig_input, ig_same_line, ig_selectable,          &
                   ig_separator, ig_set_next_window, ig_slider, ig_text, ig_text_colored, ig_text_disabled,              &
                   ip_begin_plot, ip_colormap_scale, ip_end_plot, ip_heatmap, ip_line, ip_setup_axes,                    &
                   ImPlotColormap_Viridis, ip_colormap, ip_colormap_names
use figure, only : ig_align_begin, ig_align_end, ig_align_text_to_frame_padding, ig_available, ig_em, ig_font_size, &
                   ig_frame_height, ig_get_style_var, ig_indent, ig_input_text, ig_last_item, ig_line_height,         &
                   ig_pop_item_width, ig_push_item_width, ig_unindent, item_status_object, ig_dummy, ig_text_size
use figure_cimgui, only : igGetWindowDrawList, im_vec2

implicit none
interface
   subroutine ImDrawList_AddLine(self, p1, p2, col, thickness, flags) bind(C, name='ImDrawList_AddLine')
   !< ImDrawList::AddLine (cimgui).
   import :: c_float, c_int, c_ptr, im_vec2
   implicit none
   type(c_ptr),    value :: self      !< Draw list.
   type(im_vec2),  value :: p1        !< From [pixels].
   type(im_vec2),  value :: p2        !< To [pixels].
   integer(c_int), value :: col       !< Colour, ImU32 (ABGR).
   real(c_float),  value :: thickness !< Thickness [pixels].
   integer(c_int), value :: flags     !< ImDrawFlags.
   endsubroutine ImDrawList_AddLine

   subroutine ImDrawList_AddTriangleFilled(self, p1, p2, p3, col) bind(C, name='ImDrawList_AddTriangleFilled')
   !< ImDrawList::AddTriangleFilled (cimgui).
   import :: c_int, c_ptr, im_vec2
   implicit none
   type(c_ptr),    value :: self !< Draw list.
   type(im_vec2),  value :: p1   !< Corner [pixels].
   type(im_vec2),  value :: p2   !< Corner [pixels].
   type(im_vec2),  value :: p3   !< Corner [pixels].
   integer(c_int), value :: col  !< Colour, ImU32 (ABGR).
   endsubroutine ImDrawList_AddTriangleFilled

   subroutine ImDrawList_AddText_Vec2(self, pos, col, text_begin, text_end) bind(C, name='ImDrawList_AddText_Vec2')
   !< ImDrawList::AddText (cimgui).
   import :: c_char, c_int, c_ptr, im_vec2
   implicit none
   type(c_ptr),            value      :: self          !< Draw list.
   type(im_vec2),          value      :: pos           !< Top left [pixels].
   integer(c_int),         value      :: col           !< Colour, ImU32 (ABGR).
   character(kind=c_char), intent(in) :: text_begin(*) !< NUL-terminated text.
   type(c_ptr),            value      :: text_end      !< Null: up to the NUL.
   endsubroutine ImDrawList_AddText_Vec2
endinterface
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

if (trim(arg) == 'layout_metrics') then
   call app%init('FIGURE: layout metrics', 680_int32, 400_int32)
   do while (app%next_frame())
      call metrics()
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
   subroutine metrics()
   !< The layout metrics over a form: each length FIGURE's layout calls give, as a dimension line, its call written in
   !< a column at the right, level with it. The form leaves an empty row (`ig_dummy`) below each part for its lines.
   type(item_status_object) :: s         !< Status of an item.
   type(c_ptr)              :: dl        !< The window's draw list.
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
      dl = igGetWindowDrawList()
      xc = l1(1)
      x0 = 10.0_real64
      xv = f1(1) + f1(3) + ig_em(1)
      xl = xv + ig_em(3)
      write(t, '(A,I0,A)') 'ig_font_size() = 1 em = ', nint(ig_font_size()), ' px'
      call vdim(dl, xv, l1(2), l1(2) + ig_line_height(), xl, l1(2) + 0.5_real64 * l1(4), trim(t))
      write(t, '(A,I0,A)') 'ig_line_height(spacing=.true.) = ', nint(ig_line_height(spacing=.true.)), ' px'
      call vdim(dl, xv + ig_em(1), l1(2), l2(2), xl, l2(2) + 0.5_real64 * l2(4), trim(t))
      call hdim(dl, x0, f1(1), y(1), xl, 'ig_same_line(ig_em(5)): from the window''s edge')
      write(t, '(A,I0,A)') 'ig_frame_height() = ', nint(ig_frame_height()), ' px'
      call vdim(dl, xv, f1(2), f1(2) + f1(4), xl, f1(2) + 0.5_real64 * f1(4), trim(t))
      write(t, '(A,I0,A)') 'ig_frame_height(spacing=.true.) = ', nint(ig_frame_height(spacing=.true.)), ' px'
      call vdim(dl, xv + ig_em(1), f1(2), f2(2), xl, f2(2) + 0.5_real64 * f2(4), trim(t))
      write(t, '(A,I0,A)') 'ig_push_item_width(ig_em(12)) = ', nint(f1(3)), ' px'
      call hdim(dl, f1(1), f1(1) + f1(3), y(2), xl, trim(t))
      call hdim(dl, x0, xc, y(3), xl, 'WindowPadding (style)')
      call hdim(dl, b1(1) + b1(3), b2(1), y(4), xl, 'ItemSpacing (style), after ig_same_line()')
      call hdim(dl, xc, ind(1), y(5), xl, 'ig_indent(): IndentSpacing (style)')
      write(t, '(A,I0,A)') 'ig_available(w, h): w = ', nint(w), ' px'
      call hdim(dl, xc, xc + w, y(6) + 0.25_real64 * ig_line_height(), -1.0_real64, trim(t))
      call hdim(dl, grp(1), grp(1) + grp(3), y(7), -2.0_real64, 'ig_align_begin(''buttons'', ''right'')')
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

   subroutine vdim(dl, x, ya, yb, xl, yl, label)
   !< A vertical dimension line at `x` from `ya` to `yb` [pixels], `label` at (`xl`, `yl`) with a leader to it.
   type(c_ptr),      intent(in) :: dl    !< Draw list.
   real(real64),     intent(in) :: x     !< Abscissa [pixels].
   real(real64),     intent(in) :: ya    !< From [pixels].
   real(real64),     intent(in) :: yb    !< To [pixels].
   real(real64),     intent(in) :: xl    !< The label's left [pixels].
   real(real64),     intent(in) :: yl    !< Its middle [pixels].
   character(len=*), intent(in) :: label !< Text.
   integer(c_int)               :: c     !< Colour.

   c = abgr(240_int64, 176_int64, 64_int64, 255_int64)
   call ImDrawList_AddLine(dl, v2(x, ya), v2(x, yb), c, 1.0_c_float, 0_c_int)
   call ImDrawList_AddLine(dl, v2(x - 5.0_real64, ya), v2(x + 5.0_real64, ya), c, 1.0_c_float, 0_c_int)
   call ImDrawList_AddLine(dl, v2(x - 5.0_real64, yb), v2(x + 5.0_real64, yb), c, 1.0_c_float, 0_c_int)
   call ImDrawList_AddTriangleFilled(dl, v2(x, ya), v2(x - 3.0_real64, ya + 5.0_real64), v2(x + 3.0_real64, ya + 5.0_real64), c)
   call ImDrawList_AddTriangleFilled(dl, v2(x, yb), v2(x + 3.0_real64, yb - 5.0_real64), v2(x - 3.0_real64, yb - 5.0_real64), c)
   call leader(dl, x + 4.0_real64, 0.5_real64 * (ya + yb), xl, yl, label)
   endsubroutine vdim

   subroutine hdim(dl, xa, xb, y, xl, label)
   !< A horizontal dimension line at `y` from `xa` to `xb` [pixels]; `label` at `xl` with a leader to it, or, for `xl`
   !< -1, centred above the line, -2, at the left of its start.
   type(c_ptr),      intent(in) :: dl    !< Draw list.
   real(real64),     intent(in) :: xa    !< From [pixels].
   real(real64),     intent(in) :: xb    !< To [pixels].
   real(real64),     intent(in) :: y     !< Ordinate [pixels].
   real(real64),     intent(in) :: xl    !< The label's left [pixels], or -1, -2.
   character(len=*), intent(in) :: label !< Text.
   integer(c_int)               :: c     !< Colour.
   real(real64)                 :: tw    !< The label's width [pixels].
   real(real64)                 :: ext(2) !< The label's width and height [pixels].

   c = abgr(240_int64, 176_int64, 64_int64, 255_int64)
   call ImDrawList_AddLine(dl, v2(xa, y), v2(xb, y), c, 1.0_c_float, 0_c_int)
   call ImDrawList_AddLine(dl, v2(xa, y - 5.0_real64), v2(xa, y + 5.0_real64), c, 1.0_c_float, 0_c_int)
   call ImDrawList_AddLine(dl, v2(xb, y - 5.0_real64), v2(xb, y + 5.0_real64), c, 1.0_c_float, 0_c_int)
   call ImDrawList_AddTriangleFilled(dl, v2(xa, y), v2(xa + 5.0_real64, y + 3.0_real64), v2(xa + 5.0_real64, y - 3.0_real64), c)
   call ImDrawList_AddTriangleFilled(dl, v2(xb, y), v2(xb - 5.0_real64, y - 3.0_real64), v2(xb - 5.0_real64, y + 3.0_real64), c)
   if (len(label) == 0) return
   if (xl > 0.0_real64) then
      call leader(dl, xb + 4.0_real64, y, xl, y, label)
   else
      ext = ig_text_size(label)
      tw = ext(1)
      if (xl < -1.5_real64) then
         call text_at(dl, xa - tw - 10.0_real64, y, label)
      else
         call text_at(dl, 0.5_real64 * (xa + xb - tw), y - ig_line_height(), label)
      endif
   endif
   endsubroutine hdim

   subroutine leader(dl, xa, ya, xl, yl, label)
   !< A thin leader from (`xa`, `ya`) to the label at (`xl`, `yl`), when there is room, and the label.
   type(c_ptr),      intent(in) :: dl    !< Draw list.
   real(real64),     intent(in) :: xa    !< From [pixels].
   real(real64),     intent(in) :: ya    !< ...
   real(real64),     intent(in) :: xl    !< The label's left [pixels].
   real(real64),     intent(in) :: yl    !< Its middle [pixels].
   character(len=*), intent(in) :: label !< Text.

   if (xl - 6.0_real64 > xa) call ImDrawList_AddLine(dl, v2(xa, ya), v2(xl - 6.0_real64, yl), &
                                                     abgr(240_int64, 176_int64, 64_int64, 110_int64), 1.0_c_float, 0_c_int)
   call text_at(dl, xl, yl, label)
   endsubroutine leader

   subroutine text_at(dl, x, ymid, label)
   !< `label` from `x`, its middle at `ymid` [pixels].
   type(c_ptr),      intent(in) :: dl    !< Draw list.
   real(real64),     intent(in) :: x     !< Left [pixels].
   real(real64),     intent(in) :: ymid  !< Middle [pixels].
   character(len=*), intent(in) :: label !< Text.
   call ImDrawList_AddText_Vec2(dl, v2(x, ymid - 0.5_real64 * ig_line_height()), &
                                abgr(240_int64, 176_int64, 64_int64, 255_int64), label//c_null_char, c_null_ptr)
   endsubroutine text_at

   pure function v2(x, y) result(p)
   !< A point [pixels].
   real(real64), intent(in) :: x !< Abscissa.
   real(real64), intent(in) :: y !< Ordinate.
   type(im_vec2)            :: p !< Point.
   p = im_vec2(real(x, c_float), real(y, c_float))
   endfunction v2

   pure function abgr(r, g, b, a) result(c)
   !< A colour as Dear ImGui packs it (ImU32: alpha, blue, green, red from the high byte), in a C int.
   integer(int64), intent(in) :: r !< Red, 0 to 255.
   integer(int64), intent(in) :: g !< Green.
   integer(int64), intent(in) :: b !< Blue.
   integer(int64), intent(in) :: a !< Alpha.
   integer(c_int)             :: c !< Colour.
   integer(int64)             :: u !< Unsigned value.
   u = ior(ishft(a, 24), ior(ishft(b, 16), ior(ishft(g, 8), r)))
   if (u > 2147483647_int64) u = u - 4294967296_int64 ! the same 32 bits, as a signed C int
   c = int(u, c_int)
   endfunction abgr

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
