!< figure_test_plot_frame_colormaps, the Fortran plot frame's user colormaps, colormap lists and stops, as FIGURE's.
program figure_test_plot_frame_colormaps
!< figure_test_plot_frame_colormaps, the Fortran plot frame's user colormaps, colormap lists and stops, as FIGURE's.
!<
!< szaghi/figure#15 P10 (what P10-P12 left, night 2026-11-23 step 06). The same files are loaded by FIGURE's current
!< path (`ip_load_colormap`: native/figure_colormap.cpp) and by the Fortran frame's registry (`cm_load`,
!< figure_plot_colormap_files), the same names asked of both. Checked:
!<
!< 1. every load's status and message, equal: CSV tables (a header, comments, `;` and tabs, 0-255 components, 4
!<    columns of positions, CR LF lines), ParaView presets (an array of five, one per colour space: RGB, Lab/CIEDE2000,
!<    Diverging, HSV, Step; a single object loaded under another name; escapes in names), and the refusals (a name
!<    taken, reversed, empty, with '|', 'FIGURE '; a file missing; malformed tables and presets: mixed columns,
!<    decreasing positions, a negative component, above 255, one row, no RGBPoints, a bad escape, an unclosed string,
!<    no preset of the name, an unsupported colour space, a non-number);
!< 2. the lists of names (`ip_colormap_names`, `cm_list_name`), equal;
!< 3. the stops of every listed map (`ip_colormap_stops`, `cm_stops`): statuses, messages, positions and colours to
!<    the bit (ImPlot's qualitative maps refused, the 256-sample maps' stops taken greedily);
!< 4. the keys of each user map, its reverse and its 9 levels (ImPlot's registered keys through `GetColormapColor`,
!<    the frame's `cm_key`), to the bit;
!< 5. a colour bar of a user map (`ip_colormap_scale`, `pf_colormap_scale`): pictures at FIGURE's oracle rule.
!<
!< The files and pictures are `figure_test_plot_frame_colormaps.*.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps
!< them).
use, intrinsic :: iso_c_binding, only : c_int
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ip_colormap, &
                   ip_colormap_names, ip_colormap_scale, ip_colormap_stops, ip_load_colormap,           &
                   ImGuiWindowFlags_NoDecoration
use figure_cimgui, only : im_vec4
use figure_cimplot, only : ImPlot_GetColormapColor, ImPlot_GetColormapSize
use figure_plot_colormaps, only : cm_colormap, cm_key, cm_list_count, cm_list_name, cm_load, cm_size, cm_stops
use figure_plot_frame, only : pf_colormap_scale
use figure_testing, only : test_capture, test_compare_image, test_mouse_move

implicit none
integer(int32), parameter :: W = 400_int32      !< Display width [pixels].
integer(int32), parameter :: H = 340_int32      !< Display height [pixels].
integer(int32), parameter :: NFILE = 26_int32   !< Loads.
character(len=*), parameter :: P = 'figure_test_plot_frame_colormaps.' !< Files' prefix.
type(app_object)          :: app                !< Application.
character(len=32)         :: lname(NFILE)       !< The loads' names.
character(len=64)         :: lfile(NFILE)       !< ... files.
logical                   :: test_passed(5)     !< Per-check outcome.
integer(int32)            :: k, s               !< Counters, status.
character(len=16)         :: keep               !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
call write_files()
test_passed(1) = loads_equal()
test_passed(2) = names_equal()
test_passed(3) = stops_equal()
test_passed(4) = keys_equal()
test_passed(5) = scale_equal()
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_colormaps checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine put(name, text)
   !< A file written (stream: its bytes as given).
   character(len=*), intent(in) :: name, text !< File, text.
   integer(int32)               :: u          !< Unit.

   open(newunit=u, file=P//name//'.tmp', access='stream', form='unformatted', status='replace')
   write(u) text
   close(u)
   endsubroutine put

   subroutine load(i, name, file)
   !< A load of the list.
   integer(int32),   intent(in) :: i          !< Its place.
   character(len=*), intent(in) :: name, file !< Name, file (without prefix; '' for a missing one).

   lname(i) = name
   lfile(i) = P//file//'.tmp'
   endsubroutine load

   subroutine write_files()
   !< The files and the loads.
   character(len=1), parameter :: NL = achar(10), CR = achar(13), TB = achar(9) !< Line feed, return, tab.
   character(len=:), allocatable :: t !< A text.
   integer(int32)                :: i !< Row.
   character(len=40)             :: row !< A row.

   call put('a.csv', '# a map of three'//NL//'red, green; blue'//NL//'1.0;0.2'//TB//'0.1  # warm'//NL//NL// &
            '0.9, 0.9, 0.3'//NL//'0.1,0.3,0.8'//NL)
   t = ''
   do i = 0_int32, 19_int32 ! 20 rows in 0-255: the stops taken greedily
      write(row, '(I0,1X,I0,1X,I0)') 13_int32 * i, 255_int32 - 11_int32 * i, mod(37_int32 * i, 256_int32)
      t = t//trim(row)//NL
   enddo
   call put('b.csv', t)
   call put('c.csv', 'x,r,g,b'//CR//NL//'-1, 0, 0, 0.5'//CR//NL//'0.25, 0.2, 0.8, 0.2'//CR//NL//'0.25, 1, 1, 0'// &
            CR//NL//'3, 0.9, 0.1, 0.1'//CR//NL)
   call put('pv.json', '[ {"ColorSpace": "RGB", "Name": "pv_rgb", "RGBPoints": [0, 0.1, 0.2, 0.6, 0.5, 0.9, 0.9, '// &
            '0.9, 1, 0.7, 0.1, 0.1]},'//NL//' {"ColorSpace": "Lab/CIEDE2000", "Name": "pv_lab", "RGBPoints": [-2, '// &
            '0.05, 0.05, 0.4, 0, 0.3, 0.8, 0.4, 2, 1, 0.95, 0.2], "Creator": "a \"test\" \\ \/ é"},'//NL// &
            ' {"ColorSpace": "Diverging", "Name": "pv_div", "RGBPoints": [0, 0.231373, 0.298039, 0.752941, 1, '// &
            '0.705882, 0.0156863, 0.14902], "NanColor": [1, 1, 0], "Flag": true, "Other": null},'//NL// &
            ' {"ColorSpace": "HSV", "Name": "pv_hsv", "RGBPoints": [0, 1, 0, 0, 0.6, 0.2, 0.2, 1, 1, 0.9, 0.1, 0.6]},'// &
            NL//' {"ColorSpace": "Step", "Name": "pv_step", "RGBPoints": [0, 0, 0, 0, 0.3e0, 0.5, 0.5, 0.5, 1E0, 1, '// &
            '1, 1]} ]'//NL)
   call put('one.json', '  {"Name": "something else", "RGBPoints": [0, 0, 0, 1, 1, 1, 0.5, 0]}')
   call put('bad1.csv', '0.1 0.2 0.3'//NL//'0 0.1 0.2 0.3'//NL)
   call put('bad2.csv', '0 0 0 0'//NL//'0.5 1 1 1'//NL//'0.4 0 1 0'//NL)
   call put('bad3.csv', '0 0 0'//NL//'1 -0.5 1'//NL)
   call put('bad4.csv', '0 0 0'//NL//'300 1 1'//NL)
   call put('bad5.csv', 'r g b'//NL//'0.5 0.5 0.5'//NL)
   call put('bad6.json', '{"Name": "x", "IndexedColors": [1, 0, 0]}')
   call put('bad7.json', '{"Name": "x\q", "RGBPoints": [0, 0, 0, 0, 1, 1, 1, 1]}')
   call put('bad8.json', '{"Name": "x'//NL//NL)
   call put('bad9.json', '[{"Name": "a", "RGBPoints": [0, 0, 0, 0, 1, 1, 1, 1]}, {"Name": "b"}, {}]')
   call put('bad10.json', '{"ColorSpace": "XYZ", "RGBPoints": [0, 0, 0, 0, 1, 1, 1, 1]}')
   call put('bad11.json', '{"RGBPoints": [0, 0, 0, "zero", 1, 1, 1, 1]}')
   call put('bad12.json', '{"RGBPoints": [0, 0, 0, 0, 1, 1, 1 1]}')
   call load(1_int32, 'user_a', 'a.csv')
   call load(2_int32, 'user_b', 'b.csv')
   call load(3_int32, 'user_c', 'c.csv')
   call load(4_int32, 'pv_rgb', 'pv.json')
   call load(5_int32, 'pv_lab', 'pv.json')
   call load(6_int32, 'pv_div', 'pv.json')
   call load(7_int32, 'pv_hsv', 'pv.json')
   call load(8_int32, 'pv_step', 'pv.json')
   call load(9_int32, 'only one', 'one.json')
   call load(10_int32, 'Viridis', 'a.csv')
   call load(11_int32, 'user_a_r', 'a.csv')
   call load(12_int32, 'a|b', 'a.csv')
   call load(13_int32, 'FIGURE map', 'a.csv')
   call load(14_int32, 'missing', 'no such file')
   call load(15_int32, 'bad1', 'bad1.csv')
   call load(16_int32, 'bad2', 'bad2.csv')
   call load(17_int32, 'bad3', 'bad3.csv')
   call load(18_int32, 'bad4', 'bad4.csv')
   call load(19_int32, 'bad5', 'bad5.csv')
   call load(20_int32, 'bad6', 'bad6.json')
   call load(21_int32, 'bad7', 'bad7.json')
   call load(22_int32, 'bad8', 'bad8.json')
   call load(23_int32, 'bad9', 'bad9.json')
   call load(24_int32, 'bad10', 'bad10.json')
   call load(25_int32, 'bad11', 'bad11.json')
   call load(26_int32, 'bad12', 'bad12.json')
   endsubroutine write_files

   function loads_equal() result(ok)
   !< Each load's status and message on both paths.
   logical                       :: ok  !< Equal.
   integer(int32)                :: st1, st2 !< Statuses.
   character(len=:), allocatable :: m1, m2   !< Messages.
   integer(int32)                :: nok      !< Loads read.

   ok = .true.
   nok = 0_int32
   do k = 1_int32, NFILE
      call ip_load_colormap(trim(lname(k)), trim(lfile(k)), st1)
      if (st1 == 0_int32) nok = nok + 1_int32
      m1 = ''
      if (st1 /= 0_int32) m1 = figure_last_error()
      call cm_load(trim(lname(k)), trim(lfile(k)), st2, m2)
      if (st1 == st2 .and. m1 == m2 .and. len(m1) == len(m2)) cycle
      ok = .false.
      write(output_unit, '(A,I0,2(A,I0))') 'load ', k, ': status ', st1, ', frame ', st2
      write(output_unit, '(A)') '  '//m1
      write(output_unit, '(A)') '  '//m2
   enddo
   if (nok /= 9_int32) write(output_unit, '(A,I0)') 'loads read: ', nok
   ok = ok .and. nok == 9_int32 ! the nine good files read, the others refused
   endfunction loads_equal

   function names_equal() result(ok)
   !< The lists of names on both paths.
   logical                       :: ok       !< Equal.
   character(len=:), allocatable :: names(:) !< The current path's.

   call ip_colormap_names(names)
   ok = size(names) == cm_list_count()
   if (.not. ok) write(output_unit, '(A,I0,A,I0)') 'names: ', size(names), ', frame ', cm_list_count()
   if (.not. ok) return
   do k = 1_int32, cm_list_count()
      if (trim(names(k)) == cm_list_name(k)) cycle
      ok = .false.
      write(output_unit, '(A)') 'name '//trim(names(k))//', frame '//cm_list_name(k)
   enddo
   endfunction names_equal

   function stops_equal() result(ok)
   !< The stops of every listed map (and two variants) on both paths.
   logical                       :: ok      !< Equal.
   real(real64),     allocatable :: p1(:), c1(:,:), p2(:), c2(:,:) !< Positions, colours.
   integer(int32)                :: st1, st2 !< Statuses.
   character(len=:), allocatable :: m1, m2, nm !< Messages, the name.
   integer(int32)                :: n, nstops !< Names, stops seen.

   ok = .true.
   n = cm_list_count()
   nstops = 0_int32
   do k = 1_int32, n + 2_int32
      if (k <= n) then
         nm = cm_list_name(k)
      elseif (k == n + 1_int32) then
         nm = 'user_b_r'
      else
         nm = 'no such map'
      endif
      call ip_colormap_stops(nm, p1, c1, st1)
      m1 = ''
      if (st1 /= 0_int32) m1 = figure_last_error()
      call cm_stops(nm, p2, c2, st2, m2)
      nstops = nstops + size(p1)
      if (st1 == st2 .and. m1 == m2 .and. len(m1) == len(m2) .and. size(p1) == size(p2)) then
         if (all(p1 == p2) .and. all(c1 == c2)) cycle
      endif
      ok = .false.
      write(output_unit, '(A,2(A,I0),2(A,I0))') 'stops of '//nm, ': status ', st1, ', frame ', st2, ', stops ', &
                                                size(p1), ', frame ', size(p2)
      write(output_unit, '(A)') '  '//m1
      write(output_unit, '(A)') '  '//m2
   enddo
   ok = ok .and. nstops > 100_int32 ! the maps' stops were compared, not only refusals
   endfunction stops_equal

   function keys_equal() result(ok)
   !< The keys of every user map, its reverse and its 9 levels on both paths.
   logical                       :: ok     !< Equal.
   integer(int32)                :: v, lv, id1, id2, i, n, ch !< Variant, levels, ids, counters.
   type(im_vec4)                 :: c      !< ImPlot's key.
   real(kind(1.0e0))             :: f(4)   !< The frame's key, as floats (ColorConvertU32ToFloat4).
   character(len=:), allocatable :: nm     !< Name.

   ok = .true.
   do k = 1_int32, 9_int32
      do v = 1_int32, 3_int32
         nm = trim(lname(k))
         lv = 0_int32
         if (v == 2_int32) nm = nm//'_r'
         if (v == 3_int32) lv = 9_int32
         if (lv > 0_int32) then
            id1 = ip_colormap(nm, levels=lv)
            id2 = cm_colormap(nm, lv)
         else
            id1 = ip_colormap(nm)
            id2 = cm_colormap(nm)
         endif
         n = int(ImPlot_GetColormapSize(int(id1, c_int)), int32)
         if (id1 < 0_int32 .or. id2 < 0_int32 .or. n /= cm_size(id2)) then
            ok = .false.
            write(output_unit, '(A,4(A,I0))') 'keys of '//nm, ': ids ', id1, ', ', id2, ', sizes ', n, ', ', &
                                             cm_size(max(id2, 0_int32))
            cycle
         endif
         do i = 0_int32, n - 1_int32
            call ImPlot_GetColormapColor(int(i, c_int), int(id1, c_int), c)
            do ch = 0_int32, 3_int32
               f(ch + 1_int32) = real(iand(ishft(cm_key(id2, i), -8_int32 * ch), 255_int32), kind(f)) * &
                                 (1.0e0 / 255.0e0)
            enddo
            if (c%x == f(1) .and. c%y == f(2) .and. c%z == f(3)) cycle
            ok = .false.
            write(output_unit, '(A,I0,A,3F10.6,A,3F10.6)') 'key of '//nm//' ', i, ': ', c%x, c%y, c%z, ', frame ', f(1:3)
            exit
         enddo
      enddo
   enddo
   endfunction keys_equal

   function scale_equal() result(ok)
   !< A colour bar of the Diverging preset on both paths, pictures compared.
   logical        :: ok  !< Equal.
   integer(int32) :: sd, f, i, st !< Side, frame, counter, status.
   integer(int64) :: nf_ !< Pixels that failed.

   do sd = 1_int32, 2_int32
      do f = 1_int32, 2_int32
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_colormaps: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('plot frame colormaps', flags=ImGuiWindowFlags_NoDecoration)) then
            if (sd == 1_int32) then
               call ip_colormap_scale('Diverging', -1.0_real64, 1.0_real64, height=300.0_real64, &
                                      colormap=ip_colormap('pv_div'))
            else
               call pf_colormap_scale('Diverging', -1.0_real64, 1.0_real64, height=300.0_real64, &
                                      colormap=cm_colormap('pv_div'))
            endif
         endif
         call ig_end()
         if (f == 2_int32 .and. sd == 1_int32) call test_capture(P//'implot.png.tmp', s)
         if (f == 2_int32 .and. sd == 2_int32) call test_capture(P//'fortran.png.tmp', s)
      enddo
      do i = 1_int32, 40_int32
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_colormaps: next_frame returned false headless'
      enddo
   enddo
   ok = test_compare_image(P//'fortran.png.tmp', P//'implot.png.tmp', threshold=2_int32, max_failed=0_int32, &
                           failed=nf_, stat=st)
   if (.not. ok) write(output_unit, '(A,I0,A,A)') 'colour bar: ', nf_, ' pixels failed: ', figure_last_error()
   endfunction scale_equal

   subroutine remove_files()
   !< The files and the pictures.
   integer(int32) :: unit, ios !< Unit, status.

   do k = 1_int32, NFILE + 2_int32
      if (k <= NFILE) then
         open(newunit=unit, file=trim(lfile(k)), status='old', iostat=ios)
      elseif (k == NFILE + 1_int32) then
         open(newunit=unit, file=P//'fortran.png.tmp', status='old', iostat=ios)
      else
         open(newunit=unit, file=P//'implot.png.tmp', status='old', iostat=ios)
      endif
      if (ios == 0) close(unit, status='delete')
   enddo
   endsubroutine remove_files
endprogram figure_test_plot_frame_colormaps
