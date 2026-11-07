!< figure_test_plots, tick formats, linked subplots, a window docked after the layout was built and colormaps, headless.
program figure_test_plots
!< figure_test_plots, tick formats, linked subplots, a window docked after the layout was built and colormaps, headless.
!<
!< A y axis with a printf format: every tick label follows it (and without it, none does); two subplots with linked x
!< show the same x range although their data do not; unlinked, they do not; a window that first appears after the
!< layout was built lands in the node given by ig_set_next_window_dock.
!<
!< Colormaps: every bundled map is registered under its name with 256 samples and the end colours of its table;
!< `<name>_r` is reversed, `levels` gives discrete bands (the map's colour at each band's centre, not blended); a CSV
!< table (loaded before init) and a ParaView JSON preset (Diverging, checked against Moreland's table) are loaded;
!< unknown names, bad levels, taken names and malformed files are refused with their statuses.
!<
!< Contour lines, without a GUI: a paraboloid gives closed circles of the expected radii; the two saddle cases join
!< the corners the centre value says; NaNs leave holes; automatic levels are round numbers inside the range. In a
!< plot: error bars, an annotation and a contour drawn where expected (by their colours' extents); two drag lines and a
!< drag point moved by synthetic drags; bad arguments refused.
!<
!< Colour-scale legends: a continuous vertical one has the map's first colour at the bottom, its last at the top and its
!< middle colour half-way; a horizontal one of 5 levels has 5 bands of equal width in order, each the map's colour at
!< its centre, and the value 0.3 of [-1, 1] falls in the fourth; bad arguments refused.
use, intrinsic :: iso_c_binding, only : c_double, c_float, c_int
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64, output_unit
use, intrinsic :: ieee_arithmetic, only : ieee_quiet_nan, ieee_value
use figure, only : app_object, ig_begin, ig_dock_id, ig_dock_layout_begin, ig_dock_layout_end, ig_dock_space, &
                   ig_dock_split, ig_dock_window, ig_end, ig_set_next_window_dock, ig_text, ig_window_dock,   &
                   ip_begin_plot, ip_begin_subplots, ip_end_plot, ip_end_subplots, ip_line, ip_setup_axes,   &
                   ip_colormap, ip_colormap_names, ip_colormap_scale, ip_heatmap, ip_load_colormap,         &
                   FIG_ERR_ARGUMENT, FIG_ERR_FAILED, FIG_ERR_STATE, FIG_OK
use figure, only : ig_set_next_window, ip_annotation, ip_contour, ip_contour_levels, ip_contour_lines, ip_drag_line_x, &
                   ip_drag_line_y, ip_drag_point, ip_error_bars, ip_setup_axes_limits, ip_spec
use figure, only : ig_item_rect, ip_colormap_legend
use figure_cimgui, only : im_vec4
use figure_cimgui, only : im_vec2
use figure_cimplot, only : im_plot_rect, ImPlot_GetColormapColor, ImPlot_GetColormapCount, ImPlot_GetColormapSize, &
                           ImPlot_GetPlotLimits, ImPlot_SampleColormap, ImPlot_PlotToPixels_double
use figure_testing, only : test_drag, test_drawn_extent, test_plot_tick

implicit none
integer(int32), parameter     :: FRAMES = 40_int32 !< Frames run.
type(app_object)              :: app               !< Application.
logical                       :: test_passed(27)   !< Per-check outcome.
character(len=:), allocatable :: label             !< A tick label.
integer(int32)                :: nticks(2)         !< Ticks: formatted axis, default axis.
logical                       :: all_formatted     !< Every tick of the formatted axis starts with 'T='.
logical                       :: any_default       !< ... and some tick of the default axis does.
type(im_plot_rect)            :: linked(2)         !< x limits of the two linked subplots.
type(im_plot_rect)            :: unlinked(2)       !< ... of two unlinked ones.
integer(int32)                :: root, left, right !< Dock nodes.
integer(int32)                :: late_node         !< Node the late window is in.
logical                       :: late_docked       !< The late window is docked.
logical                       :: drawn_subplots(2) !< ip_begin_subplots returned true.
integer(int32)                :: frame             !< Frame counter.
integer(int32)                :: k                 !< Counter.
integer(int32), parameter     :: NB = 14_int32     !< Bundled colormaps.
character(len=9), parameter   :: BUNDLED(NB) = [character(len=9) :: 'balance', 'batlow', 'cividis', 'cool-warm', &
   'curl', 'deep', 'haline', 'inferno', 'magma', 'roma', 'romaO', 'thermal', 'turbo', 'vik'] !< Their names.
real(real64), parameter       :: ENDS(6, NB) = reshape([                                  & ! first, last rows
   0.093176_real64, 0.111173_real64, 0.261512_real64, 0.236056_real64, 0.035297_real64, 0.069437_real64, & ! balance
   0.005193_real64, 0.098238_real64, 0.349842_real64, 0.981354_real64, 0.800406_real64, 0.981267_real64, & ! batlow
   0.000000_real64, 0.135112_real64, 0.304751_real64, 0.995737_real64, 0.909344_real64, 0.217772_real64, & ! cividis
   0.230000_real64, 0.298999_real64, 0.754000_real64, 0.706000_real64, 0.015992_real64, 0.150000_real64, & ! cool-warm
   0.082256_real64, 0.114924_real64, 0.264790_real64, 0.203400_real64, 0.051257_real64, 0.208537_real64, & ! curl
   0.992837_real64, 0.994373_real64, 0.800136_real64, 0.156102_real64, 0.102608_real64, 0.172722_real64, & ! deep
   0.162953_real64, 0.095216_real64, 0.422573_real64, 0.994081_real64, 0.936728_real64, 0.602670_real64, & ! haline
   0.001462_real64, 0.000466_real64, 0.013866_real64, 0.988362_real64, 0.998364_real64, 0.644924_real64, & ! inferno
   0.001462_real64, 0.000466_real64, 0.013866_real64, 0.987053_real64, 0.991438_real64, 0.749504_real64, & ! magma
   0.492325_real64, 0.090787_real64, 0.000076_real64, 0.009824_real64, 0.192129_real64, 0.596704_real64, & ! roma
   0.451374_real64, 0.223459_real64, 0.341871_real64, 0.448555_real64, 0.224596_real64, 0.347728_real64, & ! romaO
   0.015556_real64, 0.138244_real64, 0.201811_real64, 0.909042_real64, 0.982157_real64, 0.355508_real64, & ! thermal
   0.189950_real64, 0.071760_real64, 0.232170_real64, 0.479600_real64, 0.015830_real64, 0.010550_real64, & ! turbo
   0.001328_real64, 0.069836_real64, 0.379529_real64, 0.350423_real64, 0.000061_real64, 0.030499_real64  & ! vik
   ], [6, NB]) !< Each bundled map's first and last colour, from its table (third_party/colormaps).
real(real64), parameter       :: TOL8 = 0.5_real64 / 255.0_real64 + 1.0e-6_real64 !< ImPlot keeps 8-bit colours.
character(len=*), parameter   :: CSV = 'figure_test_plots.tmp.csv'     !< A user table.
character(len=*), parameter   :: CSV4 = 'figure_test_plots.tmp4.csv'   !< A user table with positions.
character(len=*), parameter   :: BAD = 'figure_test_plots.bad.csv'     !< A malformed one.
character(len=*), parameter   :: JSON = 'figure_test_plots.tmp.json'   !< ParaView presets.
character(len=:), allocatable :: names(:)          !< The colormap names.
integer(int32)                :: stat_before(2)    !< ip_load_colormap and ip_colormap before init.
integer(int32)                :: id_before         !< ip_colormap's id before init.
real(real64), parameter       :: C_ERR(4) = [0.9_real64, 0.1_real64, 0.8_real64, 1.0_real64] !< Error bars' colour.
real(real64), parameter       :: C_ANN(4) = [0.1_real64, 0.9_real64, 0.7_real64, 1.0_real64] !< Annotation's box.
real(real64), parameter       :: C_CON(4) = [0.8_real64, 0.7_real64, 0.1_real64, 1.0_real64] !< A contour's colour.
real(real64)                  :: bowl(41, 41)      !< (x - 5)^2 + (y - 5)^2 over [0, 10]^2.
real(real64)                  :: drag_x = 2.0_real64     !< The vertical drag line.
real(real64)                  :: drag_y = 2.0_real64     !< The horizontal drag line.
real(real64)                  :: point(2) = [7.0_real64, 6.0_real64] !< The drag point.
logical                       :: moved(3) = .false.      !< Each drag tool reported a move.
real(real64)                  :: pix(2, 6)         !< Pixels of plot points: 1-2 bars' ends, 3 annotation, 4-5 the
                                                   !< circle's left and right, 6 a pixel per unit (x, y).
real(real64)                  :: ext(4, 3)         !< Extents drawn: error bars, annotation, contour.
logical                       :: drawn(3)          !< ... found.
integer(int32)                :: s_extra(4)        !< Statuses of the plot extras.
real(real64)                  :: leg_y(3)          !< Vertical legend: rows of the colours at 0, 0.5, 1 [pixels].
real(real64)                  :: leg_item(4)       !< ... its item rectangle.
logical                       :: leg_found(3)      !< ... those colours found.
real(real64)                  :: band(4, 5)        !< Horizontal legend: each band's extent.
logical                       :: band_found(5)     !< ... found.
integer(int32)                :: s_legend(5)       !< Statuses of the legends.

late_node = 0_int32
late_docked = .false.
call write_files()
call check_contours(test_passed(14:17))
call ip_load_colormap('rgb-test', CSV, stat=stat_before(1)) ! no ImPlot context needed
id_before = ip_colormap('magma', stat=stat_before(2))      ! one is: refused
call app%init_headless(1000_int32, 800_int32)
do frame = 1_int32, FRAMES
   if (.not. app%next_frame()) error stop 'figure_test_plots: next_frame returned false in headless mode'
   root = ig_dock_id('main')
   if (ig_dock_layout_begin(root)) then
      call ig_dock_split(root, 'left', 0.5_real64, left, right)
      call ig_dock_window('Plots', left)
      call ig_dock_layout_end(root)
   endif
   call ig_dock_space(root)
   if (ig_begin('Plots')) then
      if (ip_begin_plot('formatted', height=200.0_real64)) then
         call ip_setup_axes('x', 'force', yformat='T=%.4f')
         call ip_line('f', [0.0_real64, 1.0_real64], [-3781.312_real64, -3781.318_real64])
         all_formatted = .true.
         call test_plot_tick('y', 1_int32, label, nticks(1))
         do k = 1_int32, nticks(1)
            call test_plot_tick('y', k, label)
            all_formatted = all_formatted .and. index(label, 'T=') == 1
         enddo
         call ip_end_plot()
      endif
      if (ip_begin_plot('default', height=200.0_real64)) then
         call ip_setup_axes('x', 'force')
         call ip_line('f', [0.0_real64, 1.0_real64], [-3781.312_real64, -3781.318_real64])
         any_default = .false.
         call test_plot_tick('y', 1_int32, label, nticks(2))
         do k = 1_int32, nticks(2)
            call test_plot_tick('y', k, label)
            any_default = any_default .or. index(label, 'T=') == 1
         enddo
         call ip_end_plot()
      endif
      drawn_subplots(1) = ip_begin_subplots('linked', 1_int32, 2_int32, height=200.0_real64, link_x=.true.)
      if (drawn_subplots(1)) then
         do k = 1_int32, 2_int32
            if (ip_begin_plot('##linked'//achar(48 + k))) then
               call ip_line('d', [0.0_real64, 10.0_real64**(k - 1)], [0.0_real64, 1.0_real64])
               call ImPlot_GetPlotLimits(-1_c_int, -1_c_int, linked(k))
               call ip_end_plot()
            endif
         enddo
         call ip_end_subplots()
      endif
      drawn_subplots(2) = ip_begin_subplots('unlinked', 1_int32, 2_int32, height=200.0_real64)
      if (drawn_subplots(2)) then
         do k = 1_int32, 2_int32
            if (ip_begin_plot('##unlinked'//achar(48 + k))) then
               call ip_line('d', [0.0_real64, 10.0_real64**(k - 1)], [0.0_real64, 1.0_real64])
               call ImPlot_GetPlotLimits(-1_c_int, -1_c_int, unlinked(k))
               call ip_end_plot()
            endif
         enddo
         call ip_end_subplots()
      endif
   endif
   call ig_end()
   call draw_extras(frame)
   call draw_legends()
   if (frame >= 10_int32) then                       ! a window that appears after the layout was built
      call ig_set_next_window_dock(right)
      if (ig_begin('Late')) then
         call ig_text('appeared on frame 10')
         call ig_window_dock(late_node, late_docked)
      endif
      call ig_end()
   endif
enddo
call check_colormaps(test_passed(7:13))
call check_refusals(test_passed(24))
call app%destroy()

test_passed(1) = nticks(1) > 1_int32 .and. all_formatted                       ! every label follows the format
test_passed(2) = nticks(2) > 1_int32 .and. .not. any_default                   ! the default does not
test_passed(3) = all(drawn_subplots)                                           ! the figures are drawn
test_passed(4) = abs(linked(1)%X%Max - linked(2)%X%Max) < 1.0e-9_real64 .and. linked(1)%X%Max > 9.99_real64 ! linked,
                                                                    ! fitted to the data (ImPlot gives linked axes none)
test_passed(5) = unlinked(1)%X%Max < 5.0_real64 .and. unlinked(2)%X%Max > 5.0_real64     ! unlinked: their own
test_passed(6) = late_docked .and. late_node == right                          ! the late window in its node
test_passed(18) = drawn(1) .and. abs(ext(4, 1) - pix(2, 1)) < 3.0_real64 .and. abs(ext(2, 1) - pix(2, 2)) < 3.0_real64 &
                  .and. all(s_extra(1:2) == FIG_OK)                            ! error bars from y - err to y + err_high
test_passed(19) = drawn(2) .and. ext(1, 2) < pix(1, 3) .and. pix(1, 3) < ext(3, 2) .and. ext(2, 2) < pix(2, 3) .and. &
                  pix(2, 3) < ext(4, 2) .and. s_extra(3) == FIG_OK               ! the annotation's box around its point
test_passed(20) = drawn(3) .and. abs(ext(1, 3) - pix(1, 4)) < 3.0_real64 .and. abs(ext(3, 3) - pix(1, 5)) < 3.0_real64 &
                  .and. s_extra(4) == FIG_OK                                   ! the circle of radius 2, 2 units wide
test_passed(21) = moved(1) .and. abs(drag_x - 3.0_real64) < 0.15_real64          ! dragged by one unit
test_passed(22) = moved(2) .and. abs(drag_y - 4.0_real64) < 0.15_real64          ! by two
test_passed(25) = all(leg_found) .and. leg_y(1) > leg_y(3) + 150.0_real64 .and. &          ! vmin at the bottom
                  abs(leg_y(2) - 0.5_real64 * (leg_y(1) + leg_y(3))) < 1.0_real64 .and. &   ! the middle half-way
                  leg_y(1) <= leg_item(4) .and. leg_y(3) >= leg_item(2) .and. all(s_legend(1:2) == FIG_OK)
test_passed(26) = all(band_found) .and. all(abs(band(1, 2:5) - band(3, 1:4)) < 1.0_real64) .and.            &
                  all(abs((band(3, :) - band(1, :)) - (band(3, 1) - band(1, 1))) < 1.5_real64) .and.         &
                  band(1, 4) < band(1, 1) + 0.65_real64 * (band(3, 5) - band(1, 1)) .and.                    &
                  band(3, 4) > band(1, 1) + 0.65_real64 * (band(3, 5) - band(1, 1)) ! 0.3 of [-1, 1]: band 4
test_passed(27) = all(s_legend(3:5) == FIG_ERR_ARGUMENT)
test_passed(23) = moved(3) .and. all(abs(point - [8.0_real64, 7.0_real64]) < 0.15_real64)

write(output_unit, '(A,*(L2))') 'figure_test_plots checks:', test_passed
if (.not. all(test_passed)) write(output_unit, '(A,2I3,A,2L2,A,4F9.3,A,2I12,L2)') 'ticks', nticks, &
   ', formatted/default', all_formatted, any_default, ', x max linked/unlinked', linked(1)%X%Max, linked(2)%X%Max, &
   unlinked(1)%X%Max, unlinked(2)%X%Max, ', late node/right/docked', late_node, right, late_docked
if (.not. all(test_passed(18:23))) write(output_unit, '(A,12F8.1,A,12F8.1,A,3L2,A,4F8.3,A,4I3)') 'pixels', pix, &
   ', extents', ext, ', drawn', drawn, ', drags', drag_x, drag_y, point, ', statuses', s_extra
if (.not. all(test_passed(25:27))) write(output_unit, '(A,3F8.1,A,4F8.1,A,3L2,A,20F8.1,A,5L2,A,5I3)') 'legend rows', &
   leg_y, ', item', leg_item, ', found', leg_found, ', bands', band, ', found', band_found, ', statuses', s_legend
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine write_files()
   !< The user colormaps: a CSV table (header, comment, 0-255 values), one with positions, a malformed one, and two
   !< ParaView presets in one file (ParaView's "Cool to Warm", Diverging, and a plain RGB one).
   integer :: u !< Unit.

   open(newunit=u, file=CSV, status='replace', action='write')
   write(u, '(A)') 'r,g,b', '# red, half green, blue', '255,0,0', '0,128,0', '0,0,255'
   close(u)
   open(newunit=u, file=CSV4, status='replace', action='write')
   write(u, '(A)') '0 0 0 0', '0.25 1 1 1', '1 0 0 0'
   close(u)
   open(newunit=u, file=BAD, status='replace', action='write')
   write(u, '(A)') '0.1, 0.2, 0.3', '0.4, 0.5'
   close(u)
   open(newunit=u, file=JSON, status='replace', action='write')
   write(u, '(A)') '[', '  {', '    "ColorSpace" : "Diverging",', '    "Name" : "Cool to Warm",',              &
      '    "NanColor" : [1, 1, 0],', '    "RGBPoints" : [0, 0.231373, 0.298039, 0.752941,',                    &
      '                   0.5, 0.865003, 0.865003, 0.865003,', '                   1, 0.705882, 0.0156863, 0.14902]', &
      '  },', '  { "Name" : "two", "ColorSpace" : "RGB", "RGBPoints" : [-1, 0, 0, 0, 1, 1, 1, 1] }', ']'
   close(u)
   endsubroutine write_files

   subroutine delete_files()
   !< Remove the files of write_files.
   integer :: u !< Unit.

   open(newunit=u, file=CSV)
   close(u, status='delete')
   open(newunit=u, file=CSV4)
   close(u, status='delete')
   open(newunit=u, file=BAD)
   close(u, status='delete')
   open(newunit=u, file=JSON)
   close(u, status='delete')
   endsubroutine delete_files

   function colour(id, index) result(c)
   !< The index-th colour (from 0) of the ImPlot colormap id, rgb.
   integer(int32), intent(in) :: id    !< Colormap id.
   integer(int32), intent(in) :: index !< Colour index, from 0.
   real(real64)               :: c(3)  !< Colour.
   type(im_vec4)              :: v     !< ImPlot's.

   call ImPlot_GetColormapColor(int(index, c_int), int(id, c_int), v)
   c = real([v%x, v%y, v%z], real64)
   endfunction colour

   function sample(id, t) result(c)
   !< The colour of the ImPlot colormap id at t in [0, 1] (ImPlot's lookup, as a heatmap colours a value), rgb.
   integer(int32), intent(in) :: id   !< Colormap id.
   real(real64),   intent(in) :: t    !< Position.
   real(real64)               :: c(3) !< Colour.
   type(im_vec4)              :: v    !< ImPlot's.

   call ImPlot_SampleColormap(real(t, c_float), int(id, c_int), v)
   c = real([v%x, v%y, v%z], real64)
   endfunction sample

   subroutine check_colormaps(passed)
   !< The colormap checks (an ImPlot context is alive).
   logical, intent(out)          :: passed(7)     !< Outcomes.
   integer(int32)                :: id, id2, rid  !< Colormap ids.
   integer(int32)                :: s(8)          !< Statuses.
   integer(int32)                :: count0        !< ImPlot's colormaps before a repeated request.
   integer(int32)                :: j             !< Counter.
   logical                       :: ok            !< Accumulated outcome.
   real(real64), parameter       :: BLUE(3) = [0.0_real64, 0.0_real64, 1.0_real64] !< Last row of the CSV table.

   ! 1. every bundled map: listed, its name, 256 samples, its table's end colours; asked again, the same id
   call ip_colormap_names(names)
   ok = size(names) == NB + 16 + 1 .and. trim(names(NB + 1)) == 'Deep' .and. trim(names(NB + 16)) == 'Greys' .and. &
        trim(names(NB + 17)) == 'rgb-test'
   do j = 1_int32, NB
      ok = ok .and. trim(names(j)) == trim(BUNDLED(j))
      id = ip_colormap(trim(BUNDLED(j)), stat=s(1))
      ok = ok .and. s(1) == FIG_OK .and. id >= 16_int32
      ok = ok .and. ImPlot_GetColormapSize(int(id, c_int)) == 256_c_int
      ok = ok .and. all(abs(colour(id, 0_int32) - ENDS(1:3, j)) <= TOL8)
      ok = ok .and. all(abs(colour(id, 255_int32) - ENDS(4:6, j)) <= TOL8)
      count0 = int(ImPlot_GetColormapCount(), int32)
      ok = ok .and. ip_colormap(trim(BUNDLED(j))) == id .and. int(ImPlot_GetColormapCount(), int32) == count0
   enddo
   passed(1) = ok .and. ip_colormap('Viridis') == 4_int32
   ! 2. reversed: a bundled map and one of ImPlot's
   id = ip_colormap('magma')
   rid = ip_colormap('magma_r', stat=s(1))
   ok = s(1) == FIG_OK .and. rid /= id .and. ImPlot_GetColormapSize(int(rid, c_int)) == 256_c_int
   do j = 0_int32, 255_int32, 15_int32
      ok = ok .and. all(abs(colour(rid, j) - colour(id, 255_int32 - j)) < 1.0e-6_real64)
   enddo
   rid = ip_colormap('Viridis_r')
   passed(2) = ok .and. all(abs(colour(rid, 0_int32) - colour(4_int32, ImPlot_GetColormapSize(4_c_int) - 1_int32)) &
                            < 1.0e-6_real64)
   ! 3. discrete: 5 bands, each the map at its centre, not blended (the same colour across a band)
   id = ip_colormap('cool-warm')
   id2 = ip_colormap('cool-warm', levels=5_int32, stat=s(1))
   ok = s(1) == FIG_OK .and. id2 /= id .and. ImPlot_GetColormapSize(int(id2, c_int)) == 5_c_int
   do j = 0_int32, 4_int32
      ok = ok .and. all(abs(colour(id2, j) - sample(id, (j + 0.5_real64) / 5.0_real64)) <= 2.0_real64 / 255.0_real64)
   enddo
   ok = ok .and. all(abs(sample(id2, 0.01_real64) - sample(id2, 0.19_real64)) < 1.0e-6_real64)
   ok = ok .and. any(abs(sample(id2, 0.19_real64) - sample(id2, 0.21_real64)) > 0.05_real64)
   rid = ip_colormap('cool-warm_r', levels=5_int32)
   ok = ok .and. all(abs(colour(rid, 0_int32) - colour(id2, 4_int32)) < 1.0e-6_real64)
   ok = ok .and. ip_colormap('cool-warm', levels=5_int32) == id2
   id = ip_colormap('Deep', levels=2_int32) ! a qualitative map: bands take its colours, not blends
   passed(3) = ok .and. all(abs(colour(id, 0_int32) - colour(0_int32, 2_int32)) < 1.0e-6_real64)
   ! 4. a CSV table loaded before init (0-255, header, comment) and one with positions (resampled)
   id = ip_colormap('rgb-test', stat=s(1))
   ok = all(stat_before == [FIG_OK, FIG_ERR_STATE]) .and. id_before == -1_int32 .and. s(1) == FIG_OK
   ok = ok .and. ImPlot_GetColormapSize(int(id, c_int)) == 3_c_int .and. all(abs(colour(id, 2_int32) - BLUE) < 1.0e-6_real64)
   ok = ok .and. all(abs(colour(id, 0_int32) - [1.0_real64, 0.0_real64, 0.0_real64]) < 1.0e-6_real64)
   ok = ok .and. all(abs(colour(id, 1_int32) - [0.0_real64, 128.0_real64 / 255.0_real64, 0.0_real64]) <= TOL8)
   call ip_load_colormap('peak', CSV4, stat=s(2))
   id = ip_colormap('peak')
   passed(4) = ok .and. s(2) == FIG_OK .and. ImPlot_GetColormapSize(int(id, c_int)) == 256_c_int .and. &
               all(colour(id, 64_int32) > 0.98_real64) .and. all(colour(id, 255_int32) < 1.0e-6_real64) .and. &
               all(abs(colour(id, 160_int32) - (1.0_real64 - (160.0_real64 / 255.0_real64 - 0.25_real64) / 0.75_real64)) &
                   <= TOL8 + 1.0e-3_real64)
   ! 5. a ParaView preset, chosen by name among two; Diverging interpolation as Moreland's table (bundled cool-warm)
   call ip_load_colormap('Cool to Warm', JSON, stat=s(1))
   id = ip_colormap('Cool to Warm')
   id2 = ip_colormap('cool-warm')
   ok = s(1) == FIG_OK .and. ImPlot_GetColormapSize(int(id, c_int)) == 256_c_int
   ok = ok .and. all(abs(colour(id, 0_int32) - [0.231373_real64, 0.298039_real64, 0.752941_real64]) <= TOL8)
   ok = ok .and. all(abs(colour(id, 255_int32) - [0.705882_real64, 0.0156863_real64, 0.14902_real64]) <= TOL8)
   do j = 0_int32, 255_int32, 17_int32
      ok = ok .and. all(abs(colour(id, j) - colour(id2, j)) < 0.02_real64)
   enddo
   call ip_load_colormap('two', JSON, stat=s(2))
   id = ip_colormap('two')
   passed(5) = ok .and. s(2) == FIG_OK .and. all(abs(colour(id, 128_int32) - 128.0_real64 / 255.0_real64) <= TOL8)
   ! 6. unknown names (case-sensitive), bad levels: FIG_ERR_ARGUMENT, id -1; a bad id refused by the heatmap's scale
   ok = ip_colormap('no-such-map', stat=s(1)) == -1_int32 .and. ip_colormap('Magma', stat=s(2)) == -1_int32
   ok = ok .and. ip_colormap('magma', levels=1_int32, stat=s(3)) == -1_int32
   ok = ok .and. ip_colormap('magma', levels=257_int32, stat=s(4)) == -1_int32
   ok = ok .and. ip_colormap('magma_r_r', stat=s(5)) == -1_int32
   call ip_colormap_scale('##bad', 0.0_real64, 1.0_real64, colormap=-1_int32, stat=s(6))
   call ip_heatmap('bad', reshape([0.0_real64], [1, 1]), 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, &
                   colormap=100000_int32, stat=s(7))
   passed(6) = ok .and. all(s(1:7) == FIG_ERR_ARGUMENT)
   ! 7. loading refused: a name taken (a map, the reverse of one), a reserved name, a malformed file, a missing file,
   !    a preset name absent from a file of two
   call ip_load_colormap('magma', CSV, stat=s(1))
   call ip_load_colormap('batlow_r', CSV, stat=s(2))
   call ip_load_colormap('a|b', CSV, stat=s(3))
   call ip_load_colormap('bad', BAD, stat=s(4))
   call ip_load_colormap('missing', 'figure_test_plots.none.csv', stat=s(5))
   call ip_load_colormap('three', JSON, stat=s(6))
   call ip_load_colormap('', CSV, stat=s(7))
   passed(7) = all(s([1, 2, 3, 4, 6, 7]) == FIG_ERR_ARGUMENT) .and. s(5) == FIG_ERR_FAILED .and. &
               ip_colormap('bad', stat=s(8)) == -1_int32
   if (.not. all(passed)) write(output_unit, '(A,7L2,A,8I3)') 'colormaps', passed, ', statuses', s
   call delete_files()
   endsubroutine check_colormaps
   function pixel(x, y) result(p)
   !< The pixel of the plot point (x, y), in the plot being declared.
   real(real64), intent(in) :: x    !< Abscissa.
   real(real64), intent(in) :: y    !< Ordinate.
   real(real64)             :: p(2) !< Pixel.
   type(im_vec2)            :: v    !< ImPlot's.

   v = ImPlot_PlotToPixels_double(real(x, c_double), real(y, c_double), -1_c_int, -1_c_int)
   p = real([v%x, v%y], real64)
   endfunction pixel

   subroutine draw_legends()
   !< A vertical continuous legend and a horizontal one of 5 levels, measured by their colours; bad arguments.
   integer(int32) :: k          !< Band.
   real(real64)   :: c(4)       !< A colour.
   real(real64)   :: x0, x1, y0 !< An extent.
   integer(int32) :: magma      !< Colormap ids.
   integer(int32) :: cw         !< ...

   magma = ip_colormap('magma')
   cw = ip_colormap('cool-warm')
   call ig_set_next_window(520.0_real64, 500.0_real64, 460.0_real64, 290.0_real64, always=.true.)
   if (ig_begin('Legends')) then
      call ip_colormap_legend('##v', magma, 0.0_real64, 10.0_real64, height=200.0_real64, stat=s_legend(1))
      call ig_item_rect(leg_item(1), leg_item(2), leg_item(3), leg_item(4))
      do k = 1_int32, 3_int32
         c = [sample(magma, 0.5_real64 * (k - 1)), 1.0_real64]
         call test_drawn_extent(c, x0, y0, x1, leg_y(k), leg_found(k))
      enddo
      call ip_colormap_legend('##h', cw, -1.0_real64, 1.0_real64, levels=5_int32, horizontal=.true., &
                              width=400.0_real64, stat=s_legend(2))
      do k = 1_int32, 5_int32
         c = [sample(cw, (k - 0.5_real64) / 5.0_real64), 1.0_real64]
         call test_drawn_extent(c, band(1, k), band(2, k), band(3, k), band(4, k), band_found(k))
      enddo
      call ip_colormap_legend('##bad1', -3_int32, 0.0_real64, 1.0_real64, stat=s_legend(3))
      call ip_colormap_legend('##bad2', magma, 1.0_real64, 1.0_real64, stat=s_legend(4))
      call ip_colormap_legend('##bad3', magma, 0.0_real64, 1.0_real64, levels=1_int32, stat=s_legend(5))
   endif
   call ig_end()
   endsubroutine draw_legends

   subroutine draw_extras(frame)
   !< A plot with error bars, an annotation, contours and drag tools, the drags queued on frames 5, 15 and 25.
   integer(int32), intent(in) :: frame  !< Frame.
   integer(int32)             :: i, j   !< Counters.
   real(real64)               :: a(2)   !< A drag's start [pixels].
   real(real64)               :: b(2)   !< Its end.

   if (frame == 1_int32) then
      do j = 1_int32, 41_int32
         do i = 1_int32, 41_int32
            bowl(i, j) = ((i - 1) * 0.25_real64 - 5.0_real64)**2 + ((j - 1) * 0.25_real64 - 5.0_real64)**2
         enddo
      enddo
   endif
   call ig_set_next_window(520.0_real64, 20.0_real64, 460.0_real64, 460.0_real64, always=.true.)
   if (ig_begin('Extras')) then
      if (ip_begin_plot('extras', width=420.0_real64, height=400.0_real64)) then
         call ip_setup_axes('x', 'y')
         call ip_setup_axes_limits(0.0_real64, 10.0_real64, 0.0_real64, 10.0_real64, always=.true.)
         call ip_error_bars('err', [2.0_real64, 4.0_real64], [5.0_real64, 5.0_real64], [1.0_real64, 2.0_real64], &
                            [1.0_real64, 1.5_real64], spec=ip_spec(line_color=C_ERR), stat=s_extra(1))
         call ip_error_bars('err32', [2.0_real32], [5.0_real32], [0.5_real32], stat=s_extra(2))
         call ip_annotation(8.0_real64, 8.0_real64, 'peak', color=C_ANN, stat=s_extra(3))
         call ip_annotation(1.0_real64, 9.0_real64, 'note', offset=[10.0_real64, -10.0_real64])
         call ip_contour('##bowl', bowl, 0.0_real64, 10.0_real64, 0.0_real64, 10.0_real64, levels=[4.0_real64], &
                         color=C_CON, line_weight=2.0_real64, stat=s_extra(4))
         call ip_contour('bowl levels', bowl, 0.0_real64, 10.0_real64, 0.0_real64, 10.0_real64, nlevels=5_int32, &
                         colormap=ip_colormap('magma'), labels=.true.)
         call ip_contour('bowl32', real(bowl, real32), 0.0_real64, 10.0_real64, 0.0_real64, 10.0_real64, &
                         levels=[1.0_real64])
         moved(1) = ip_drag_line_x(1_int32, drag_x) .or. moved(1)
         moved(2) = ip_drag_line_y(2_int32, drag_y, color=[1.0_real64, 0.0_real64, 0.0_real64, 1.0_real64]) .or. moved(2)
         moved(3) = ip_drag_point(3_int32, point(1), point(2), radius=6.0_real64) .or. moved(3)
         pix(:, 1) = pixel(4.0_real64, 3.0_real64)
         pix(:, 2) = pixel(4.0_real64, 6.5_real64)
         pix(:, 3) = pixel(8.0_real64, 8.0_real64)
         pix(:, 4) = pixel(3.0_real64, 5.0_real64)
         pix(:, 5) = pixel(7.0_real64, 5.0_real64)
         if (frame == 5_int32) then
            a = pixel(drag_x, 8.0_real64)
            b = pixel(drag_x + 1.0_real64, 8.0_real64)
         elseif (frame == 15_int32) then
            a = pixel(9.0_real64, drag_y)
            b = pixel(9.0_real64, drag_y + 2.0_real64)
         elseif (frame == 25_int32) then
            a = pixel(point(1), point(2))
            b = pixel(point(1) + 1.0_real64, point(2) + 1.0_real64)
         endif
         call ip_end_plot()
         if (frame == 5_int32 .or. frame == 15_int32 .or. frame == 25_int32) call test_drag(a(1), a(2), b(1), b(2))
         call test_drawn_extent(C_ERR, ext(1, 1), ext(2, 1), ext(3, 1), ext(4, 1), drawn(1))
         call test_drawn_extent(C_ANN, ext(1, 2), ext(2, 2), ext(3, 2), ext(4, 2), drawn(2))
         call test_drawn_extent(C_CON, ext(1, 3), ext(2, 3), ext(3, 3), ext(4, 3), drawn(3))
      endif
   endif
   call ig_end()
   endsubroutine draw_extras

   function closed(x, y) result(ok)
   !< Whether segment ends make closed lines: every end is shared by an even number of ends (within 1e-12).
   real(real64), intent(in) :: x(:) !< Ends, x.
   real(real64), intent(in) :: y(:) !< Ends, y.
   logical                  :: ok   !< Closed.
   integer(int64)           :: e    !< Counter.

   ok = .true.
   do e = 1_int64, size(x, kind=int64)
      ok = ok .and. mod(count(abs(x - x(e)) < 1.0e-12_real64 .and. abs(y - y(e)) < 1.0e-12_real64), 2) == 0
   enddo
   endfunction closed

   function edge_of(x, y) result(c)
   !< The edge of the unit square a point lies on: B, R, T, L (or ? for none).
   real(real64), intent(in) :: x !< Abscissa.
   real(real64), intent(in) :: y !< Ordinate.
   character(len=1)         :: c !< Edge.

   c = '?'
   if (abs(y) < 1.0e-12_real64) c = 'B'
   if (abs(x - 1.0_real64) < 1.0e-12_real64) c = 'R'
   if (abs(y - 1.0_real64) < 1.0e-12_real64) c = 'T'
   if (abs(x) < 1.0e-12_real64) c = 'L'
   endfunction edge_of

   function saddle(g, pairs) result(ok)
   !< Whether the single cell g (unit square) at level 0.5 gives two segments joining the edges `pairs` (two pairs).
   real(real64),     intent(in) :: g(2, 2) !< Corner values.
   character(len=4), intent(in) :: pairs   !< Expected pairs of edges, each sorted: 'BLRT' is B-L and R-T.
   logical                      :: ok      !< As expected.
   real(real64), allocatable    :: x(:)    !< Ends, x.
   real(real64), allocatable    :: y(:)    !< Ends, y.
   integer(int64), allocatable  :: first(:)!< Level offsets.
   character(len=2)             :: got(2)  !< Edges of each segment, sorted.
   integer(int32)               :: s       !< Segment.

   call ip_contour_lines(g, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, [0.5_real64], x, y, first)
   ok = size(x) == 4
   if (.not. ok) return
   do s = 1_int32, 2_int32
      got(s) = edge_of(x(2 * s - 1), y(2 * s - 1))//edge_of(x(2 * s), y(2 * s))
      if (got(s)(1:1) > got(s)(2:2)) got(s) = got(s)(2:2)//got(s)(1:1)
   enddo
   ok = (got(1) == pairs(1:2) .and. got(2) == pairs(3:4)) .or. (got(1) == pairs(3:4) .and. got(2) == pairs(1:2))
   endfunction saddle

   subroutine check_contours(passed)
   !< The contour checks, without a GUI: circles, saddles, holes, automatic levels.
   logical, intent(out)          :: passed(4) !< Outcomes.
   real(real64)                  :: f(41, 41) !< x^2 + y^2 over [-1, 1]^2.
   real(real64)                  :: fn(41, 41)!< ... with NaNs where x > 0.31.
   real(real64), allocatable     :: x(:), y(:), lev(:)
   integer(int64), allocatable   :: first(:)  !< Level offsets.
   real(real64), parameter       :: RADII(2) = [0.5_real64, 0.7071067811865476_real64] !< sqrt of the levels.
   integer(int32)                :: i, j, k   !< Counters.
   integer(int64)                :: e         !< An end.
   logical                       :: ok        !< Accumulated outcome.

   do j = 1_int32, 41_int32
      do i = 1_int32, 41_int32
         f(i, j) = (-1.0_real64 + (i - 1) * 0.05_real64)**2 + (-1.0_real64 + (j - 1) * 0.05_real64)**2
         fn(i, j) = f(i, j)
         if (-1.0_real64 + (i - 1) * 0.05_real64 > 0.31_real64) fn(i, j) = ieee_value(1.0_real64, ieee_quiet_nan)
      enddo
   enddo
   ! 1. a paraboloid: closed circles of radius sqrt(level), within the interpolation's error; single precision too
   call ip_contour_lines(f, -1.0_real64, 1.0_real64, -1.0_real64, 1.0_real64, [0.25_real64, 0.5_real64], x, y, first)
   ok = size(first) == 3 .and. first(1) == 1_int64 .and. first(3) == size(x, kind=int64) + 1_int64
   do k = 1_int32, 2_int32
      ok = ok .and. first(k + 1) - first(k) > 80_int64
      do e = first(k), first(k + 1) - 1_int64
         ok = ok .and. abs(hypot(x(e), y(e)) - RADII(k)) < 2.0e-3_real64
      enddo
      ok = ok .and. closed(x(first(k):first(k + 1) - 1), y(first(k):first(k + 1) - 1))
   enddo
   call ip_contour_lines(real(f, real32), -1.0_real64, 1.0_real64, -1.0_real64, 1.0_real64, [0.25_real64], x, y, first)
   ok = ok .and. size(x) > 80 .and. all(abs(hypot(x, y) - RADII(1)) < 2.0e-3_real64)
   passed(1) = ok
   ! 2. saddles: the centre value (the mean) decides which corners are joined
   passed(2) = saddle(reshape([1.0_real64, 0.0_real64, 0.0_real64, 0.9_real64], [2, 2]), 'BLRT') .and. & ! mean below
               saddle(reshape([1.0_real64, 0.0_real64, 0.2_real64, 1.0_real64], [2, 2]), 'BRLT') .and. & ! mean above
               saddle(reshape([0.0_real64, 1.0_real64, 1.0_real64, 0.1_real64], [2, 2]), 'BLRT')       ! the other diagonal
   ! 3. NaNs leave holes: no line where a cell has one, none at all in a field of NaNs
   call ip_contour_lines(fn, -1.0_real64, 1.0_real64, -1.0_real64, 1.0_real64, [0.25_real64], x, y, first)
   ok = size(x) > 20
   ok = ok .and. all(ieee_finite(x)) .and. all(ieee_finite(y)) .and. all(x < 0.31_real64)
   call ip_contour_lines(fn(30:, :), -1.0_real64, 1.0_real64, -1.0_real64, 1.0_real64, [0.25_real64], x, y, first)
   passed(3) = ok .and. size(x) == 0 .and. all(first == 1_int64)
   ! 4. automatic levels: round numbers strictly inside the finite range
   lev = ip_contour_levels(f)
   ok = size(lev) == 9
   if (ok) ok = all(abs(lev - [(0.2_real64 * k, k = 1, 9)]) < 1.0e-12_real64)
   lev = ip_contour_levels(real(f, real32), 4_int32)
   ok = ok .and. size(lev) == 3
   if (ok) ok = all(abs(lev - [0.5_real64, 1.0_real64, 1.5_real64]) < 1.0e-12_real64)
   lev = ip_contour_levels(fn(20:, :), 3_int32)            ! the NaNs ignored: range [0, 0.3^2 + 1], step 0.5
   ok = ok .and. size(lev) == 2
   if (ok) ok = all(abs(lev - [0.5_real64, 1.0_real64]) < 1.0e-12_real64)
   lev = ip_contour_levels(reshape([3.0_real64, 3.0_real64, 3.0_real64, 3.0_real64], [2, 2])) ! constant: none
   ok = ok .and. size(lev) == 0
   lev = ip_contour_levels(fn(30:, :))                     ! no finite value: none
   passed(4) = ok .and. size(lev) == 0
   if (.not. all(passed)) write(output_unit, '(A,4L2,A,*(F8.3))') 'contours', passed, ', levels', &
      ip_contour_levels(f), ip_contour_levels(real(f, real32), 4_int32), ip_contour_levels(fn(20:, :), 3_int32)
   endsubroutine check_contours

   elemental function ieee_finite(v) result(ok)
   !< Whether v is finite.
   use, intrinsic :: ieee_arithmetic, only : ieee_is_finite
   real(real64), intent(in) :: v  !< Value.
   logical                  :: ok !< Finite.

   ok = ieee_is_finite(v)
   endfunction ieee_finite

   subroutine check_refusals(passed)
   !< Bad arguments of the plot extras refused (outside a plot: the checks come first).
   logical, intent(out) :: passed !< Outcome.
   integer(int32)       :: s(9)   !< Statuses.
   real(real64)         :: v      !< A drag value.
   logical              :: m(2)   !< Drags' results.

   v = 1.0_real64
   call ip_annotation(0.0_real64, 0.0_real64, 'x', stat=s(1))                                 ! outside a plot
   call ip_annotation(0.0_real64, 0.0_real64, 'x', color=[1.0_real64, 0.0_real64], stat=s(2))
   call ip_annotation(0.0_real64, 0.0_real64, 'x', offset=[1.0_real64, 2.0_real64, 3.0_real64], stat=s(3))
   call ip_contour('c', bowl, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, color=[1.0_real64], stat=s(4))
   call ip_contour('c', bowl, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, nlevels=0_int32, stat=s(5))
   call ip_contour('c', real(bowl, real32), 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, colormap=-5_int32, stat=s(6))
   m(1) = ip_drag_line_x(1_int32, v, color=[1.0_real64], stat=s(7))
   m(2) = ip_drag_point(1_int32, v, v, color=[1.0_real64, 1.0_real64, 1.0_real64], stat=s(8))
   call ip_error_bars('e', [1.0_real64, 2.0_real64], [1.0_real64, 2.0_real64], [1.0_real64], stat=s(9))
   passed = s(1) == FIG_ERR_STATE .and. all(s(2:9) == FIG_ERR_ARGUMENT) .and. .not. any(m)
   if (.not. passed) write(output_unit, '(A,9I3)') 'refusals', s
   endsubroutine check_refusals
endprogram figure_test_plots
