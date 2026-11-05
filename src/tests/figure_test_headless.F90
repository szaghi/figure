!< figure_test_headless, widgets and plots driven by synthetic input, without a window or a GPU.
program figure_test_headless
!< figure_test_headless, widgets and plots driven by synthetic input, without a window or a GPU.
!<
!< A button is clicked by queuing mouse states frame by frame (hover, press, release), exactly as real input arrives;
!< a check box is toggled the same way; a plot is drawn from Fortran arrays. Needs no display, so it runs in CI as is.
use, intrinsic :: iso_c_binding, only : c_double, c_f_pointer, c_float, c_int, c_null_char
use, intrinsic :: iso_fortran_env, only : error_unit, int8, int32, output_unit, real32, real64
use figure, only : FIG_ERR_ARGUMENT, FIG_OK, app_object, figure_last_error, ig_begin, ig_button, ig_checkbox, ig_end, &
                   ig_item_rect, ig_set_next_window, ImPlotMarker_Circle, ip_bars, ip_begin_plot, ip_end_plot, ip_line, &
                   ip_scatter, ip_setup_axes, ip_shaded, ip_spec, plot_spec_object, FIG_ERR_STATE, ig_image, ip_heatmap,   &
                   ip_image, ImPlotColormap_Viridis, texture_object, ig_dock_id, ig_dock_layout_begin,             &
                   ig_dock_layout_end, ig_dock_space, ig_dock_split, ig_dock_window, ig_window_dock
use figure_cimgui, only : im_vec4, igGetStyleColorVec4
use figure_cimgui_enums, only : ImGuiCol_WindowBg
use figure_cimplot, only : im_plot_rect, ImPlot_GetColormapIndex, ImPlot_GetLastItemColor, ImPlot_GetPlotLimits
use figure_c_native, only : fig_input_mouse

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
logical                   :: test_passed(27)  !< Per-check outcome.
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
stat_dock = -1_int32
dock_left = 0_int32
dock_right = 0_int32
layouts = 0_int32
docked = .false.
dock_node = -1_int32
do frame = 1_int32, 12_int32
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
   call ig_set_next_window(20.0_real64, 20.0_real64, 400.0_real64, 500.0_real64, always=.true.)
   if (ig_begin('Test')) then
      if (ig_button('Hit me')) clicks = clicks + 1_int32
      call ig_item_rect(x0, y0, x1, y1)
      bx = [0.5_real64 * (x0 + x1), 0.5_real64 * (y0 + y1)]
      if (ig_checkbox('Flag', flag)) toggles = toggles + 1_int32
      call ig_item_rect(x0, y0, x1, y1)
      by = [x0 + 8.0_real64, 0.5_real64 * (y0 + y1)]
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
   ! input for the next frames: frames 2-4 click the button (hover, press, release), 6-8 the check box
   select case (frame)
   case (1_int32, 2_int32)
      call fig_input_mouse(real(bx(1), c_float), real(bx(2), c_float), 0_c_int)
   case (3_int32)
      call fig_input_mouse(real(bx(1), c_float), real(bx(2), c_float), 1_c_int)
   case (4_int32)
      call fig_input_mouse(real(bx(1), c_float), real(bx(2), c_float), 0_c_int)
   case (5_int32, 6_int32)
      call fig_input_mouse(real(by(1), c_float), real(by(2), c_float), 0_c_int)
   case (7_int32)
      call fig_input_mouse(real(by(1), c_float), real(by(2), c_float), 1_c_int)
   case (8_int32)
      call fig_input_mouse(real(by(1), c_float), real(by(2), c_float), 0_c_int)
   endselect
enddo
call ip_line('bad row', m, 4_int32, stat=stat_bad_row)
call c_f_pointer(igGetStyleColorVec4(ImGuiCol_WindowBg), style_color)
window_bg = style_color ! the default style, seal
seal_cmap = ImPlot_GetColormapIndex('FIGURE seal'//c_null_char)
call app%set_style('dark', stat=stat_style(1))
call app%set_style('bogus', stat=stat_style(2))
call app%set_docking(.false.)
if (app%next_frame()) call ig_dock_space(dock_root, stat=stat_dock) ! docking off: rejected
call ip_heatmap('one end', fld, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, scale_min=0.0_real64, stat=stat_scale)
call tex%destroy()
call tex%update(pix, stat=stat_dead)
call ip_line('mismatch', x, y(1:N - 1_int32), stat=stat)
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

write(output_unit, '(A,27L2)') 'figure_test_headless checks:', test_passed
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
