!< figure_test_headless, widgets and plots driven by synthetic input, without a window or a GPU.
program figure_test_headless
!< figure_test_headless, widgets and plots driven by synthetic input, without a window or a GPU.
!<
!< A button is clicked by queuing mouse states frame by frame (hover, press, release), exactly as real input arrives;
!< a check box is toggled the same way; a plot is drawn from Fortran arrays. Needs no display, so it runs in CI as is.
use, intrinsic :: iso_c_binding, only : c_double, c_f_pointer, c_float, c_int, c_null_char
use, intrinsic :: iso_fortran_env, only : error_unit, int8, int32, output_unit, real32, real64
use figure, only : FIG_ERR_ARGUMENT, FIG_ERR_FAILED, FIG_OK, app_object, figure_last_error, ig_begin, ig_button, &
                   ig_checkbox, ig_end, &
                   ig_item_rect, ig_set_next_window, ImPlotMarker_Circle, ip_bars, ip_begin_plot, ip_end_plot, ip_line, &
                   ip_scatter, ip_setup_axes, ip_setup_axes_limits, ip_shaded, ip_spec, plot_spec_object, FIG_ERR_STATE,   &
                   ig_image, ip_heatmap,                                                                               &
                   ip_image, ImPlotColormap_Viridis, texture_object, ig_dock_id, ig_dock_layout_begin,             &
                   ig_dock_layout_end, ig_dock_space, ig_dock_split, ig_dock_window, ig_window_dock,                &
                   ig_get_style_color, ig_get_style_var, ig_set_style_color, ig_set_style_var, ip_get_style_color,  &
                   ip_get_style_var, ip_set_style_color, ip_set_style_var, ig_pop_font, ig_push_font,         &
                   ig_pop_style_color, ig_pop_style_var, ig_push_style_color, ig_push_style_var, ig_text,      &
                   ImGuiWindowFlags_NoTitleBar, ig_slider, ig_input
use figure_cimgui, only : im_vec2, im_vec4, igGetFontSize, igGetStyleColorVec4
use figure_cimgui_enums, only : ImGuiCol_WindowBg
use figure_cimplot, only : im_plot_rect, ImPlot_GetColormapColor, ImPlot_GetColormapIndex, ImPlot_GetLastItemColor, &
                           ImPlot_GetPlotLimits, ImPlot_PlotToPixels_double
use figure_testing, only : test_click, test_drag, test_key, test_type, test_window_rect

implicit none
integer(int32), parameter :: N = 100_int32    !< Plot points.
type(app_object)          :: app              !< Application.
integer(int32)            :: frame            !< Frame counter.
integer(int32)            :: clicks           !< Button clicks seen.
integer(int32)            :: toggles          !< Check box toggles seen.
logical                   :: flag             !< Check box value.
real(real64)              :: bx(2)            !< Button center [pixels].
real(real64)              :: by(2)            !< Check box center [pixels].
real(real64)              :: x0               !< Item rectangle, left [pixels].
real(real64)              :: y0               !< Item rectangle, top [pixels].
real(real64)              :: x1               !< Item rectangle, right [pixels].
real(real64)              :: y1               !< Item rectangle, bottom [pixels].
real(real64)              :: x(N)             !< Plot abscissae.
real(real64)              :: y(N)             !< Plot ordinates.
logical                   :: test_passed(45)  !< Per-check outcome.
real(real64)              :: long_x(100000)   !< A line over 65536 vertices: abscissae.
real(real64)              :: long_y(100000)   !< Its ordinates.
integer(int32)            :: long_frames      !< Frames drawn with it.
type(texture_object)      :: tex              !< A 4 x 2 texture.
integer(int8)             :: pix(4, 4, 2)     !< Its pixels.
integer(int8)             :: pix_bad(3, 4, 2) !< Pixels of the wrong shape (3 channels).
real(real64)              :: fld(4, 2)        !< A 4 x 2 field: 4 columns along x, 2 rows along y.
integer(int32)            :: stat_tex(3)      !< init, update, update with the wrong shape.
integer(int32)            :: stat_draw(3)     !< ip_heatmap, ip_image, ip_heatmap with labels and a colormap.
integer(int32)            :: stat_dead        !< update after destroy.
integer(int32)            :: stat_scale       !< ip_heatmap with scale_min only.
type(im_plot_rect)        :: field_limits     !< Limits of the field plot after ImPlot's fit.
real(real64)              :: m(3, N)          !< Rows in disjoint ranges: ~0, ~10, ~100.
integer(int32)            :: stat_row         !< Status of the strided row line.
integer(int32)            :: stat_values      !< Status of the uniform-x line.
integer(int32)            :: stat_bad_row     !< Status of a row out of range.
type(im_plot_rect)        :: limits           !< Limits of the plot of row 2, after ImPlot's fit.
type(im_plot_rect)        :: grown            !< Limits of the auto-fit plot of growing data, last frame.
type(im_vec2)             :: log_px(3)        !< Pixels of y = 1e-6, 1e-3, 1 on the logarithmic axis.
type(im_vec4)             :: window_bg        !< Window background of the default style (a copy).
type(im_vec4), pointer    :: style_color      !< A colour of the current style, in Dear ImGui's memory.
integer(int32)            :: stat_style(2)    !< set_style('dark'), set_style('bogus').
integer(c_int)            :: seal_cmap        !< Index of the seal colormap.
integer(int32)            :: dock_root        !< Dock space.
integer(int32)            :: dock_left        !< Its left node.
integer(int32)            :: dock_right       !< Its right node.
integer(int32)            :: dock_node(2)     !< Nodes the windows A and B ended in.
integer(int32)            :: layouts          !< Times the layout was built.
integer(int32)            :: stat_dock        !< ig_dock_space with docking off.
logical                   :: docked(2)        !< Windows A and B docked.
real(real64)              :: rgba(4)          !< A colour read back.
real(real64)              :: rgba_plot(4)     !< An ImPlot colour read back.
real(real64)              :: var(2)           !< A style variable read back.
real(real64)              :: var2(2)          !< A pair read back.
real(real64)              :: var_plot(2)      !< An ImPlot variable read back.
integer(int32)            :: nvar(3)          !< Their counts.
integer(int32)            :: stat_sv(5)       !< Statuses of the style calls that must fail.
integer(int32)            :: stat_builtin(5)  !< set_style of every built-in theme.
integer(int32)            :: stat_lines(2)    !< set_style with the okabe-ito lines, and with an unknown palette.
integer(c_int)            :: okabe_cmap       !< Index of the okabe-ito colormap.
character(len=*), parameter :: STYLE_FILE = 'figure_test_headless.style.toml' !< Theme file of the round trip.
character(len=*), parameter :: BAD_FILE = 'figure_test_headless.bad.toml'     !< A malformed theme file.
integer(int32)            :: stat_file(4)     !< save, load, load of a malformed file, load of a missing file.
real(real64)              :: back_button(4)   !< Button after the round trip.
real(real64)              :: back_window(4)   !< WindowBg after the round trip (from the seal base).
real(real64)              :: back_plot_bg(4)  !< ImPlot PlotBg after the round trip.
real(real64)              :: back_round(2)    !< FrameRounding after the round trip.
real(real64)              :: back_padding(2)  !< ImPlot PlotPadding after the round trip.
integer(int32)            :: back_n(2)        !< Their counts.
type(im_vec4)             :: back_line        !< First line colour after the round trip.
character(len=:), allocatable :: bad_message  !< Error message of the malformed file.
integer(int32)            :: unit             !< File unit.
integer(int32)            :: stat_font(4)     !< set_font: proggy, plex-sans at 18, a missing file, not a font.
real(c_float)             :: font_px(4)       !< Font size: default, pushed to 22, after the pop, the frame after set_font 18.
real(real64)              :: pushed(4)        !< Button colour while pushed.
real(real64)              :: popped(4)        !< Button colour after the pop.
real(real64)              :: round_pushed(2)  !< FrameRounding while pushed.
real(real64)              :: round_popped(2)  !< FrameRounding after the pop.
integer(int32)            :: stat_pop         !< A pop without a push.
real(real64)              :: titled_y         !< Top of the first item of a window with a title bar.
real(real64)              :: level            !< A slider's value, dragged to its maximum.
real(real64)              :: typed            !< A numeric field's value, typed.
real(real64)              :: sx(3)            !< Slider: left, right, middle height.
real(real64)              :: vx(2)            !< Numeric field: centre.
real(real64)              :: win(4)           !< The Test window's rectangle.
logical                   :: win_found(2)     !< The Test window found; a missing window not found.
real(real64)              :: untitled_y       !< The same in a window without one (NoTitleBar).
integer(int32)            :: stat_items(5)    !< Status of the scatter, bars and shaded items.
integer(int32)            :: stat_spec        !< Status of a spec with a bad colour.
type(plot_spec_object)    :: red              !< Red line, 2 pixels, circle markers.
type(plot_spec_object)    :: bad              !< Spec with a 1-component colour.
type(im_vec4)             :: red_seen         !< Colour ImPlot gave the last red line.
integer(int32)            :: stat             !< Status of a failing call.
integer(int32)            :: stat_r32         !< Status of the single-precision line.
integer(int32)            :: stat_empty       !< Status of the empty line.
integer(int32)            :: i                !< Counter.

x = [(real(i, real64) / 10.0_real64, i = 1_int32, N)]
y = sin(x)
clicks = 0_int32
toggles = 0_int32
flag = .false.
bx = 0.0_real64
by = 0.0_real64
test_passed = .false.
stat_r32 = -1_int32
stat_empty = -1_int32
stat_items = -1_int32
stat_row = -1_int32
log_px = im_vec2(0.0_c_float, 0.0_c_float)
stat_values = -1_int32
m(1,:) = 0.5_real64 + 0.5_real64 * y
m(2,:) = 10.5_real64 + 0.5_real64 * y
m(3,:) = 100.5_real64 + 0.5_real64 * y
red = ip_spec(line_color=[1.0_real64, 0.0_real64, 0.0_real64, 1.0_real64], line_weight=2.0_real64, &
              marker=ImPlotMarker_Circle)
bad = ip_spec(line_color=[1.0_real64], stat=stat_spec)
call app%init_headless(800_int32, 600_int32)
pix = 0_int8
pix(4,:,:) = -1_int8                                 ! alpha 255
pix(1,:,1) = -1_int8                                 ! row 1 red, row 2 black
fld = reshape([(real(i, real64), i = 1_int32, 8_int32)], [4, 2])
stat_draw = -1_int32
call tex%init(4_int32, 2_int32, stat=stat_tex(1))
call tex%update(pix, stat=stat_tex(2))
call tex%update(pix_bad, stat=stat_tex(3))

dock_root = ig_dock_id('main')
level = 0.0_real64
typed = 1.0_real64
stat_dock = -1_int32
titled_y = 0.0_real64
untitled_y = 0.0_real64
dock_left = 0_int32
dock_right = 0_int32
layouts = 0_int32
docked = .false.
dock_node = -1_int32
do frame = 1_int32, 24_int32
   if (.not. app%next_frame()) error stop 'figure_test_headless: next_frame returned false in headless mode'
   ! docking: a layout built once (left 30% | right), two windows docked into it, the dock space every frame
   if (ig_dock_layout_begin(dock_root)) then
      layouts = layouts + 1_int32
      call ig_dock_split(dock_root, 'left', 0.3_real64, dock_left, dock_right)
      call ig_dock_window('Dock A', dock_left)
      call ig_dock_window('Dock B', dock_right)
      call ig_dock_layout_end(dock_root)
   endif
   call ig_dock_space(dock_root)
   if (ig_begin('Dock A')) call ig_window_dock(dock_node(1), docked(1))
   call ig_end()
   if (ig_begin('Dock B')) call ig_window_dock(dock_node(2), docked(2))
   call ig_end()
   ! window flags: the same window placement with and without a title bar
   call ig_set_next_window(20.0_real64, 530.0_real64, 150.0_real64, 60.0_real64, always=.true.)
   if (ig_begin('Titled')) then
      call ig_text('first')
      call ig_item_rect(x0, titled_y, x1, y1)
   endif
   call ig_end()
   call ig_set_next_window(200.0_real64, 530.0_real64, 150.0_real64, 60.0_real64, always=.true.)
   if (ig_begin('Untitled', flags=ImGuiWindowFlags_NoTitleBar)) then
      call ig_text('first')
      call ig_item_rect(x0, untitled_y, x1, y1)
   endif
   call ig_end()
   call ig_set_next_window(20.0_real64, 20.0_real64, 400.0_real64, 500.0_real64, always=.true.)
   if (ig_begin('Test')) then
      if (ig_button('Hit me')) clicks = clicks + 1_int32
      call ig_item_rect(x0, y0, x1, y1)
      bx = [0.5_real64 * (x0 + x1), 0.5_real64 * (y0 + y1)]
      if (ig_checkbox('Flag', flag)) toggles = toggles + 1_int32
      call ig_item_rect(x0, y0, x1, y1)
      by = [x0 + 8.0_real64, 0.5_real64 * (y0 + y1)]
      if (ig_slider('Level', level, 0.0_real64, 1.0_real64)) continue
      call ig_item_rect(x0, y0, x1, y1)
      sx = [x0, x1, 0.5_real64 * (y0 + y1)]
      if (ig_input('Value', typed)) continue
      call ig_item_rect(x0, y0, x1, y1)
      vx = [x0 + 20.0_real64, 0.5_real64 * (y0 + y1)]
      if (ip_begin_plot('sine')) then
         call ip_setup_axes('x', 'sin(x)')
         call ip_line('sin', x, y)
         call ip_line('sin (real32)', real(x, real32), real(y, real32), stat=stat_r32)
         call ip_line('sin, uniform x', y, xscale=0.1_real64, xstart=0.1_real64, stat=stat_values)
         call ip_line('empty', x(1:0), y(1:0), stat=stat_empty)
         call ip_line('red', x, y, spec=red)
         call ImPlot_GetLastItemColor(red_seen)
         call ip_scatter('scatter', x, y, spec=red, stat=stat_items(1))
         call ip_bars('bars (real32)', real(x, real32), real(y, real32), 0.05_real64, stat=stat_items(2))
         call ip_shaded('band', x, y - 0.1_real64, y + 0.1_real64, stat=stat_items(3))
         call ip_shaded('to zero (real32)', real(x, real32), real(y, real32), 0.0_real64, stat=stat_items(4))
         call ip_scatter('scatter (real32)', real(x, real32), real(y, real32), stat=stat_items(5))
         call ip_end_plot()
      endif
   endif
   call ig_end()
   ! textures and heatmaps: the field plot must fit [0, 2] x [0, 1] (the heatmap's y bounds are swapped internally)
   call ig_set_next_window(440.0_real64, 340.0_real64, 340.0_real64, 240.0_real64, always=.true.)
   if (ig_begin('Images')) then
      call ig_image(tex, 40.0_real64, 20.0_real64)
      if (ip_begin_plot('field')) then
         call ip_heatmap('f', fld, 0.0_real64, 2.0_real64, 0.0_real64, 1.0_real64, stat=stat_draw(1))
         call ip_image('img', tex, 0.0_real64, 2.0_real64, 0.0_real64, 1.0_real64, stat=stat_draw(2))
         call ip_heatmap('f labelled', real(fld, real32), 0.0_real64, 2.0_real64, 0.0_real64, 1.0_real64, &
                         scale_min=0.0_real64, scale_max=8.0_real64, label_format='%.0f', &
                         colormap=ImPlotColormap_Viridis, stat=stat_draw(3))
         call ImPlot_GetPlotLimits(-1_c_int, -1_c_int, field_limits)
         call ip_end_plot()
      endif
   endif
   call ig_end()
   ! strided row: only row 2 (values in [10, 11]) must reach the plot, which ImPlot then fits
   call ig_set_next_window(440.0_real64, 20.0_real64, 340.0_real64, 300.0_real64, always=.true.)
   if (ig_begin('Rows')) then
      if (ip_begin_plot('row 2')) then
         call ip_line('row 2', m, 2_int32, xscale=0.1_real64, stat=stat_row)
         call ImPlot_GetPlotLimits(-1_c_int, -1_c_int, limits)
         call ip_end_plot()
      endif
   endif
   call ig_end()
   ! auto_fit: data growing every frame (x up to 10 frame) must stay in view, not keep the first frame's fit
   call ig_set_next_window(20.0_real64, 340.0_real64, 400.0_real64, 240.0_real64, always=.true.)
   if (ig_begin('Growing')) then
      if (ip_begin_plot('growing')) then
         call ip_setup_axes('x', 'y', auto_fit=.true.)
         call ip_line('grows', [0.0_real64, 10.0_real64 * frame], [0.0_real64, real(frame, real64)])
         call ImPlot_GetPlotLimits(-1_c_int, -1_c_int, grown)
         call ip_end_plot()
      endif
   endif
   call ig_end()
   ! ylog: on [1e-6, 1], 1e-3 must sit halfway between the ends in pixels (on a linear axis it would sit at the bottom)
   call ig_set_next_window(440.0_real64, 340.0_real64, 340.0_real64, 240.0_real64, always=.true.)
   if (ig_begin('Log')) then
      if (ip_begin_plot('log')) then
         call ip_setup_axes('x', 'residual', ylog=.true.)
         call ip_setup_axes_limits(0.0_real64, 1.0_real64, 1.0e-6_real64, 1.0_real64, always=.true.)
         call ip_line('residual', [0.0_real64, 1.0_real64], [1.0_real64, 1.0e-6_real64])
         log_px(1) = ImPlot_PlotToPixels_double(0.5_c_double, 1.0e-6_c_double, -1_c_int, -1_c_int)
         log_px(2) = ImPlot_PlotToPixels_double(0.5_c_double, 1.0e-3_c_double, -1_c_int, -1_c_int)
         log_px(3) = ImPlot_PlotToPixels_double(0.5_c_double, 1.0_c_double, -1_c_int, -1_c_int)
         call ip_end_plot()
      endif
   endif
   call ig_end()
   ! input, queued once and applied over the next frames (figure_testing; Dear ImGui trickles it one change per frame)
   select case (frame)
   case (1_int32)
      call test_click(bx(1), bx(2))                                  ! the button
   case (5_int32)
      call test_click(by(1), by(2))                                  ! the check box
   case (9_int32)
      call test_drag(sx(1) + 4.0_real64, sx(3), sx(2) + 40.0_real64, sx(3)) ! the slider, past its right end
   case (14_int32)
      call test_click(vx(1), vx(2))                                  ! the numeric field: select all, type, enter
      call test_key('shortcut', down=.true.)
      call test_key('a')
      call test_key('shortcut', down=.false.)
      call test_type('2.5')
      call test_key('enter')
   endselect
enddo
call ip_line('bad row', m, 4_int32, stat=stat_bad_row)
call c_f_pointer(igGetStyleColorVec4(ImGuiCol_WindowBg), style_color)
window_bg = style_color ! the default style, seal
seal_cmap = ImPlot_GetColormapIndex('FIGURE seal'//c_null_char)
call app%set_style('dark', stat=stat_style(1))
call app%set_style('bogus', stat=stat_style(2))
! style by name: colours (hex and components) and variables of both libraries, then the failures
call ig_set_style_color('Button', '#3a322b80')
call ig_get_style_color('Button', rgba)
call ip_set_style_color('PlotBg', [0.25_real64, 0.5_real64, 0.75_real64])
call ip_get_style_color('PlotBg', rgba_plot)
call ig_set_style_var('FrameRounding', 3.0_real64)
call ig_get_style_var('FrameRounding', var, nvar(1))
call ig_set_style_var('ItemSpacing', [7.0_real64, 5.0_real64])
call ig_get_style_var('ItemSpacing', var2, nvar(2))
call ip_set_style_var('PlotPadding', [4.0_real64, 6.0_real64])
call ip_get_style_var('PlotPadding', var_plot, nvar(3))
call ig_set_style_color('NoSuchColour', '#000000', stat=stat_sv(1))
call ig_set_style_color('Button', '#12345', stat=stat_sv(2))
call ig_set_style_var('FrameRounding', [1.0_real64, 2.0_real64], stat=stat_sv(3))
call ip_set_style_var('NoSuchVariable', 1.0_real64, stat=stat_sv(4))
call ig_set_style_color('Button', [1.5_real64, 0.0_real64, 0.0_real64], stat=stat_sv(5))
call app%set_style('dark', stat=stat_builtin(1))       ! every built-in theme (the embedded theme files) applies
call app%set_style('light', stat=stat_builtin(2))
call app%set_style('classic', stat=stat_builtin(3))
call app%set_style('seal-light', stat=stat_builtin(4))
call app%set_style('seal', stat=stat_builtin(5))
call app%set_style('seal', lines='okabe-ito', stat=stat_lines(1))
okabe_cmap = ImPlot_GetColormapIndex('FIGURE okabe-ito'//c_null_char)
call app%set_style('seal', lines='rainbow', stat=stat_lines(2))
call app%set_style('seal')
! theme files: save the style in effect (seal + four changes by name), switch away, load it back
call app%set_style('seal')
call ig_set_style_color('Button', '#123456')
call ig_set_style_var('FrameRounding', 5.0_real64)
call ip_set_style_color('PlotBg', '#20304080')
call ip_set_style_var('PlotPadding', [3.0_real64, 4.0_real64])
call app%save_style(STYLE_FILE, stat=stat_file(1))
call app%set_style('dark')
call app%load_style(STYLE_FILE, stat=stat_file(2))
call ig_get_style_color('Button', back_button)
call ig_get_style_color('WindowBg', back_window)
call ip_get_style_color('PlotBg', back_plot_bg)
call ig_get_style_var('FrameRounding', back_round, back_n(1))
call ip_get_style_var('PlotPadding', back_padding, back_n(2))
call ImPlot_GetColormapColor(0_c_int, -1_c_int, back_line)
open(newunit=unit, file=BAD_FILE, action='write', status='replace')
write(unit, '(A)') 'base = "dark"', '[imgui.colors]', 'Buton = "#ffffff"'
close(unit)
call app%load_style(BAD_FILE, stat=stat_file(3))
bad_message = figure_last_error()
call app%load_style('no/such/theme.toml', stat=stat_file(4))
open(newunit=unit, file=STYLE_FILE, status='old')
close(unit, status='delete')
open(newunit=unit, file=BAD_FILE, status='old')
close(unit, status='delete')
call app%set_style('seal')
call test_window_rect('Test', win(1), win(2), win(3), win(4), found=win_found(1))
call test_window_rect('No such window', x0, y0, x1, y1, found=win_found(2))
call app%set_docking(.false.)
if (app%next_frame()) call ig_dock_space(dock_root, stat=stat_dock) ! docking off: rejected
! fonts: the bundled one at 15 px by default, a size pushed for a block, then the default font switched
font_px(1) = igGetFontSize()
call ig_push_font('', 22.0_real64)
font_px(2) = igGetFontSize()
call ig_pop_font()
font_px(3) = igGetFontSize()
call ig_push_style_color('Button', [1.0_real64, 0.0_real64, 0.0_real64])  ! scoped changes, then undone
call ig_push_style_var('FrameRounding', 9.0_real64)
call ig_get_style_color('Button', pushed)
call ig_get_style_var('FrameRounding', round_pushed, back_n(1))
call ig_pop_style_var()
call ig_pop_style_color()
call ig_get_style_color('Button', popped)
call ig_get_style_var('FrameRounding', round_popped, back_n(1))
call ig_pop_style_color(stat=stat_pop)
call app%set_font('proggy', stat=stat_font(1))
call app%set_font('plex-sans', 18.0_real64, stat=stat_font(2))
call app%set_font('no/such/font.ttf', stat=stat_font(3))
call app%set_font('fpm.toml', stat=stat_font(4))
call ip_heatmap('one end', fld, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, scale_min=0.0_real64, stat=stat_scale)
call tex%destroy()
call tex%update(pix, stat=stat_dead)
call ip_line('mismatch', x, y(1:N - 1_int32), stat=stat)
! a draw list over 65536 vertices (a 100000-point line): Dear ImGui splits it into vertex ranges, which the headless
! renderer declares it handles (RendererHasVtxOffset); without that, 16-bit indices abort the program
long_x = [(real(i, real64), i = 1_int32, size(long_x))]
long_y = sin(0.01_real64 * long_x)
long_frames = 0_int32
do i = 1_int32, 2_int32
   if (.not. app%next_frame()) exit
   if (i == 1_int32) font_px(4) = igGetFontSize()   ! the size set by set_font in an earlier frame reaches this one
   call ig_set_next_window(10.0_real64, 10.0_real64, 400.0_real64, 300.0_real64)
   if (ig_begin('Long line')) then
      if (ip_begin_plot('long', height=-1.0_real64)) then
         call ip_line('y', long_x, long_y)
         call ip_end_plot()
      endif
   endif
   call ig_end()
   long_frames = long_frames + 1_int32
enddo
if (app%next_frame()) long_frames = long_frames + 1_int32 ! renders the second frame's long line
call app%destroy()

test_passed(1) = clicks == 1_int32                                                 ! button clicked once
test_passed(2) = toggles == 1_int32                                                ! check box toggled once
test_passed(3) = flag                                                              ! check box value is true
test_passed(4) = stat == int(FIG_ERR_ARGUMENT, int32)                              ! ip_line size mismatch reported
test_passed(5) = figure_last_error() == 'ip_line: the series have different sizes' ! ... with its own message
test_passed(6) = stat_r32 == int(FIG_OK, int32)                                    ! single-precision line drawn
test_passed(7) = stat_empty == int(FIG_OK, int32)                                  ! empty series accepted
test_passed(8) = all(stat_items == int(FIG_OK, int32))                             ! scatter, bars, shaded drawn
test_passed(9) = stat_spec == int(FIG_ERR_ARGUMENT, int32)                         ! bad colour rejected
test_passed(10) = red_seen%x == 1.0_c_float .and. red_seen%y == 0.0_c_float        ! the red spec reached ImPlot
test_passed(11) = red_seen%z == 0.0_c_float .and. red_seen%w == 1.0_c_float        ! ... blue and alpha too
test_passed(12) = stat_row == int(FIG_OK, int32) .and. stat_values == int(FIG_OK, int32) ! row and uniform x drawn
test_passed(13) = limits%Y%Min > 9.0_c_double .and. limits%Y%Max < 12.0_c_double  ! the stride picked row 2 only
test_passed(14) = limits%X%Max > 9.0_c_double .and. limits%X%Max < 11.0_c_double  ! x = 0.1 (j - 1), j <= 100
test_passed(15) = stat_bad_row == int(FIG_ERR_ARGUMENT, int32)                     ! row out of range rejected
test_passed(16) = all(stat_tex(1:2) == int(FIG_OK, int32))                         ! texture created and uploaded
test_passed(17) = stat_tex(3) == int(FIG_ERR_ARGUMENT, int32)                      ! wrong pixel shape rejected
test_passed(18) = all(stat_draw == int(FIG_OK, int32))                             ! heatmaps and image drawn
test_passed(19) = abs(field_limits%X%Min) < 1.0e-9_c_double .and. abs(field_limits%X%Max - 2.0_c_double) < 1.0e-9_c_double
test_passed(20) = abs(field_limits%Y%Min) < 1.0e-9_c_double .and. abs(field_limits%Y%Max - 1.0_c_double) < 1.0e-9_c_double
test_passed(21) = stat_dead == int(FIG_ERR_STATE, int32) .and. stat_scale == int(FIG_ERR_ARGUMENT, int32)
test_passed(22) = grown%X%Max >= 110.0_c_double .and. grown%Y%Max >= 11.0_c_double ! auto_fit followed the data
test_passed(23) = stat_style(1) == int(FIG_OK, int32) .and. seal_cmap >= 0_c_int    ! seal by default; dark set
test_passed(23) = test_passed(23) .and. abs(window_bg%x - 28.0_c_float / 255.0_c_float) < 1.0e-6_c_float &
                                  .and. abs(window_bg%z - 21.0_c_float / 255.0_c_float) < 1.0e-6_c_float  ! #1c1915
test_passed(24) = stat_style(2) == int(FIG_ERR_ARGUMENT, int32)                     ! unknown style rejected
test_passed(25) = layouts == 1_int32 .and. dock_left /= 0_int32 .and. dock_right /= 0_int32 ! layout built once
test_passed(26) = all(docked) .and. dock_node(1) == dock_left .and. dock_node(2) == dock_right ! docked where laid out
test_passed(27) = stat_dock == int(FIG_ERR_STATE, int32)                            ! no dock space with docking off
test_passed(28) = all(abs(rgba - [58.0_real64, 50.0_real64, 43.0_real64, 128.0_real64] / 255.0_real64) < 1.0e-6_real64) ! hex
test_passed(29) = all(abs(rgba_plot - [0.25_real64, 0.5_real64, 0.75_real64, 1.0_real64]) < 1.0e-6_real64) ! ImPlot rgb
test_passed(30) = nvar(1) == 1_int32 .and. abs(var(1) - 3.0_real64) < 1.0e-6_real64 .and. nvar(2) == 2_int32 .and. &
                  all(abs(var2 - [7.0_real64, 5.0_real64]) < 1.0e-6_real64) .and. nvar(3) == 2_int32 .and.            &
                  all(abs(var_plot - [4.0_real64, 6.0_real64]) < 1.0e-6_real64)                ! variables round-trip
test_passed(31) = all(stat_sv == int(FIG_ERR_ARGUMENT, int32))                     ! bad names, colours, arity
test_passed(32) = all(stat_builtin == int(FIG_OK, int32))                           ! every built-in theme parses
test_passed(34) = all(stat_file(1:2) == int(FIG_OK, int32)) .and.                                        &
                  all(abs(back_button - [18.0_real64, 52.0_real64, 86.0_real64, 255.0_real64] / 255.0_real64) < 1.0e-6_real64) &
                  .and. all(abs(back_window - [28.0_real64, 25.0_real64, 21.0_real64, 255.0_real64] / 255.0_real64)  &
                  < 1.0e-6_real64) .and. abs(back_line%x - 232.0_c_float / 255.0_c_float) < 1.0e-6_c_float ! colours back
test_passed(35) = back_n(1) == 1_int32 .and. abs(back_round(1) - 5.0_real64) < 1.0e-6_real64 .and.          &
                  back_n(2) == 2_int32 .and. all(abs(back_padding - [3.0_real64, 4.0_real64]) < 1.0e-6_real64) .and. &
                  all(abs(back_plot_bg - [32.0_real64, 48.0_real64, 64.0_real64, 128.0_real64] / 255.0_real64)       &
                  < 1.0e-6_real64)                                                  ! variables and ImPlot back
test_passed(36) = stat_file(3) == int(FIG_ERR_ARGUMENT, int32) .and. index(bad_message, ':3:') > 0 .and.   &
                  index(bad_message, 'Buton') > 0 .and. stat_file(4) == int(FIG_ERR_FAILED, int32) ! errors with lines
test_passed(37) = abs(font_px(1) - 15.0_c_float) < 1.0e-4_c_float .and. abs(font_px(2) - 22.0_c_float) < 1.0e-4_c_float &
                  .and. abs(font_px(3) - 15.0_c_float) < 1.0e-4_c_float &  ! default 15 px, push and pop a size
                  .and. abs(font_px(4) - 18.0_c_float) < 1.0e-4_c_float    ! set_font's size, from the next frame
test_passed(38) = all(stat_font(1:2) == int(FIG_OK, int32)) .and. stat_font(3) == int(FIG_ERR_FAILED, int32) .and. &
                  stat_font(4) == int(FIG_ERR_ARGUMENT, int32)                     ! fonts by name, bad files rejected
test_passed(39) = all(abs(pushed - [1.0_real64, 0.0_real64, 0.0_real64, 1.0_real64]) < 1.0e-6_real64) .and.        &
                  all(abs(popped - [58.0_real64, 50.0_real64, 43.0_real64, 255.0_real64] / 255.0_real64) < 1.0e-6_real64) &
                  .and. abs(round_pushed(1) - 9.0_real64) < 1.0e-6_real64 .and. abs(round_popped(1)) < 1.0e-6_real64     &
                  .and. stat_pop == int(FIG_ERR_STATE, int32)                       ! push, pop, restore; no extra pop
test_passed(40) = titled_y - untitled_y > 10.0_real64                              ! NoTitleBar: no title bar
test_passed(41) = abs(level - 1.0_real64) < 1.0e-9_real64                        ! dragged to the slider's maximum
test_passed(42) = abs(typed - 2.5_real64) < 1.0e-9_real64                         ! typed into the numeric field
test_passed(43) = win_found(1) .and. .not. win_found(2) .and.                                                      &
                  all(abs(win - [20.0_real64, 20.0_real64, 420.0_real64, 520.0_real64]) < 1.0e-6_real64) ! window lookup
test_passed(44) = long_frames == 3_int32                                           ! a list over 65536 vertices
test_passed(45) = log_px(1)%y > log_px(3)%y + 50.0_c_float .and. &
                  abs(log_px(2)%y - 0.5_c_float * (log_px(1)%y + log_px(3)%y)) < 1.0_c_float ! ylog: 1e-3 halfway
test_passed(33) = stat_lines(1) == int(FIG_OK, int32) .and. okabe_cmap >= 0_c_int .and. &
                  stat_lines(2) == int(FIG_ERR_ARGUMENT, int32)                     ! named line palette

write(output_unit, '(A,*(L2))') 'figure_test_headless checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) then
   write(error_unit, '(A,4(G0,1X))') 'field plot limits x, y: ', field_limits%X%Min, field_limits%X%Max, &
                                     field_limits%Y%Min, field_limits%Y%Max
   write(error_unit, '(A,4(G0,1X))') 'row 2 plot limits x, y: ', limits%X%Min, limits%X%Max, limits%Y%Min, limits%Y%Max
   write(error_unit, '(A,I0,A,I0,A,L1,A,I0,A)') 'clicks: ', clicks, ', toggles: ', toggles, ', flag: ', flag, &
                                               ', stat: ', stat, ', message: "'//figure_last_error()//'"'
   error stop 1
endif
endprogram figure_test_headless
