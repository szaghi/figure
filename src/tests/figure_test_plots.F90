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
use, intrinsic :: iso_c_binding, only : c_float, c_int
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : app_object, ig_begin, ig_dock_id, ig_dock_layout_begin, ig_dock_layout_end, ig_dock_space, &
                   ig_dock_split, ig_dock_window, ig_end, ig_set_next_window_dock, ig_text, ig_window_dock,   &
                   ip_begin_plot, ip_begin_subplots, ip_end_plot, ip_end_subplots, ip_line, ip_setup_axes,   &
                   ip_colormap, ip_colormap_names, ip_colormap_scale, ip_heatmap, ip_load_colormap,         &
                   FIG_ERR_ARGUMENT, FIG_ERR_FAILED, FIG_ERR_STATE, FIG_OK
use figure_cimgui, only : im_vec4
use figure_cimplot, only : im_plot_rect, ImPlot_GetColormapColor, ImPlot_GetColormapCount, ImPlot_GetColormapSize, &
                           ImPlot_GetPlotLimits, ImPlot_SampleColormap
use figure_testing, only : test_plot_tick

implicit none
integer(int32), parameter     :: FRAMES = 20_int32 !< Frames run.
type(app_object)              :: app               !< Application.
logical                       :: test_passed(13)   !< Per-check outcome.
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

late_node = 0_int32
late_docked = .false.
call write_files()
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
call app%destroy()

test_passed(1) = nticks(1) > 1_int32 .and. all_formatted                       ! every label follows the format
test_passed(2) = nticks(2) > 1_int32 .and. .not. any_default                   ! the default does not
test_passed(3) = all(drawn_subplots)                                           ! the figures are drawn
test_passed(4) = abs(linked(1)%X%Max - linked(2)%X%Max) < 1.0e-9_real64 .and. linked(1)%X%Max > 9.99_real64 ! linked,
                                                                    ! fitted to the data (ImPlot gives linked axes none)
test_passed(5) = unlinked(1)%X%Max < 5.0_real64 .and. unlinked(2)%X%Max > 5.0_real64     ! unlinked: their own
test_passed(6) = late_docked .and. late_node == right                          ! the late window in its node

write(output_unit, '(A,*(L2))') 'figure_test_plots checks:', test_passed
if (.not. all(test_passed)) write(output_unit, '(A,2I3,A,2L2,A,4F9.3,A,2I12,L2)') 'ticks', nticks, &
   ', formatted/default', all_formatted, any_default, ', x max linked/unlinked', linked(1)%X%Max, linked(2)%X%Max, &
   unlinked(1)%X%Max, unlinked(2)%X%Max, ', late node/right/docked', late_node, right, late_docked
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
endprogram figure_test_plots
