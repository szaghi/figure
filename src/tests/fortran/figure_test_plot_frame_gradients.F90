!< figure_test_plot_frame_gradients, the Fortran plot frame's edited colormaps, as FIGURE's `ig_gradient_edit` edits them.
program figure_test_plot_frame_gradients
!< figure_test_plot_frame_gradients, the Fortran plot frame's edited colormaps, as FIGURE's `ig_gradient_edit` edits
!< them.
!<
!< szaghi/figure#15 P10 (what P10-P12 left, night 2026-11-23 step 08). Three maps (ImPlot's Viridis, the bundled
!< batlow, a user's loaded from a CSV) are edited with FIGURE's current path's editor (`ig_gradient_edit`, scripted: a
!< double click on the stops' row adds a stop, a drag moves the first one), their stops then read
!< (`ip_colormap_stops`) and given to the Fortran frame's registry (`cm_edit_stops`). Checked, to the bit:
!<
!< 1. the stops of each map on both (`ip_colormap_stops`, `cm_stops`), after the edit (an edit made: more stops);
!< 2. the keys of each map and of its variants registered before the edit (`_r`, levels: rewritten from the edited
!<    keys) and after it, as ImPlot holds them (`GetColormapColor`) and as the frame does (`cm_key`);
!< 3. the frame's `cm_generation` raised by each edit, not by giving the same stops again; the refusals (a reversed
!<    map, a qualitative one) with the native messages.
!<
!< The CSV is `figure_test_plot_frame_gradients.csv.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps it).
use, intrinsic :: iso_c_binding, only : c_int
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_gradient_edit, ig_set_next_window, ip_colormap, &
                   ip_colormap_stops, ip_load_colormap, ImGuiWindowFlags_NoDecoration
use figure_cimgui, only : im_vec4
use figure_cimgui_enums, only : ImGuiStyleVar_ItemSpacing
use figure_cimplot, only : ImPlot_GetColormapColor, ImPlot_GetColormapSize
use figure_core, only : core_frame_height, core_style_vec2
use figure_plot_colormaps, only : cm_colormap, cm_edit_stops, cm_generation, cm_key, cm_load, cm_size, cm_stops
use figure_testing, only : test_drag, test_mouse_button, test_mouse_move, test_next_frame

implicit none
integer(int32), parameter :: W = 640_int32      !< Display width [pixels].
integer(int32), parameter :: H = 200_int32      !< Display height [pixels].
character(len=*), parameter :: CSV = 'figure_test_plot_frame_gradients.csv.tmp' !< The user's map.
character(len=8), parameter :: MAPS(3) = ['Viridis ', 'batlow  ', 'grad_u  '] !< The maps edited.
type(app_object)          :: app                !< Application.
logical                   :: test_passed(3)     !< Per-check outcome.
integer(int32)            :: m, f, st, g0, i, n0 !< Map, frame, status, a generation, counter, stops before.
real(real64)              :: row, sp(2)         !< The editor's row, the item spacing.
real(real64),     allocatable :: p1(:), c1(:,:), p2(:), c2(:,:) !< Stops.
character(len=:), allocatable :: msg           !< A message.
character(len=16)         :: keep               !< FIGURE_TEST_KEEP.
logical                   :: moved              !< An edit.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
call write_csv()
call ip_load_colormap('grad_u', CSV, st)
call cm_load('grad_u', CSV, st, msg)
call variants() ! registered before the edits
test_passed = .true.
do m = 1_int32, 3_int32
   call ip_colormap_stops(trim(MAPS(m)), p1, c1, st)
   n0 = size(p1)
   do f = 1_int32, 14_int32
      if (.not. app%next_frame()) error stop 'figure_test_plot_frame_gradients: next_frame returned false headless'
      call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
      if (ig_begin('gradient', flags=ImGuiWindowFlags_NoDecoration)) &
         moved = ig_gradient_edit('##g'//trim(MAPS(m)), trim(MAPS(m)), width=500.0_real64)
      call ig_end()
      if (f == 1_int32) then
         row = core_frame_height()
         call core_style_vec2(ImGuiStyleVar_ItemSpacing, sp(1), sp(2))
         call double_click(8.0_real64 + 190.0_real64, 8.0_real64 + row + sp(2) + 0.5_real64 * row)
      endif
      if (f == 7_int32) call test_drag(8.0_real64 + 0.5_real64 * row, 8.0_real64 + row + sp(2) + 0.5_real64 * row, &
                                       8.0_real64 + 0.5_real64 * row + 70.0_real64, &
                                       8.0_real64 + row + sp(2) + 0.5_real64 * row)
   enddo
   call test_mouse_move(-100.0_real64, -100.0_real64)
   do i = 1_int32, 20_int32
      if (.not. app%next_frame()) error stop 'figure_test_plot_frame_gradients: next_frame returned false headless'
   enddo
   call ip_colormap_stops(trim(MAPS(m)), p1, c1, st)
   g0 = cm_generation()
   call cm_edit_stops(trim(MAPS(m)), p1, c1, st, msg)
   test_passed(3) = test_passed(3) .and. st == 0_int32 .and. cm_generation() == g0 + 1_int32
   call cm_edit_stops(trim(MAPS(m)), p1, c1, st, msg) ! the same stops: nothing done
   test_passed(3) = test_passed(3) .and. cm_generation() == g0 + 1_int32
   call cm_stops(trim(MAPS(m)), p2, c2, st, msg)
   if (.not. (size(p1) == size(p2) .and. size(p1) > n0)) then
      test_passed(1) = .false.
      write(output_unit, '(A,2(I0,1X))') 'stops of '//trim(MAPS(m))//': ', size(p1), size(p2)
   elseif (.not. (all(p1 == p2) .and. all(c1 == c2))) then
      test_passed(1) = .false.
      write(output_unit, '(A)') 'stops of '//trim(MAPS(m))//' differ'
   endif
enddo
call variants() ! registered after the edits
test_passed(2) = keys_equal()
call cm_edit_stops('Viridis_r', p1, c1, st, msg)
test_passed(3) = test_passed(3) .and. msg == "ig_gradient_edit: 'Viridis_r' is a reversed map: edit 'Viridis'"
call cm_edit_stops('Deep', p1, c1, st, msg)
test_passed(3) = test_passed(3) .and. &
                 msg == "ig_gradient_edit: 'Deep' is qualitative (a list of colours, not a scale): it has no gradient"
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_csv()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_gradients checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine write_csv()
   !< The user's map: five colours.
   integer(int32) :: u !< Unit.

   open(newunit=u, file=CSV, status='replace', action='write')
   write(u, '(A)') '0.1 0.1 0.3'
   write(u, '(A)') '0.2 0.5 0.6'
   write(u, '(A)') '0.9 0.9 0.8'
   write(u, '(A)') '0.8 0.4 0.1'
   write(u, '(A)') '0.5 0.0 0.1'
   close(u)
   endsubroutine write_csv

   subroutine remove_csv()
   !< The user's map's file.
   integer(int32) :: u, ios !< Unit, status.

   open(newunit=u, file=CSV, status='old', iostat=ios)
   if (ios == 0) close(u, status='delete')
   endsubroutine remove_csv

   subroutine double_click(x, y)
   !< A double click queued at (x, y).
   real(real64), intent(in) :: x, y !< Pixel.

   call test_mouse_move(x, y)
   call test_next_frame()
   call test_mouse_button(.true.)
   call test_next_frame()
   call test_mouse_button(.false.)
   call test_next_frame()
   call test_mouse_button(.true.)
   call test_next_frame()
   call test_mouse_button(.false.)
   endsubroutine double_click

   subroutine variants()
   !< The maps' variants registered on both sides (the frame's ids are found again by name).
   integer(int32) :: k, id !< Map, id.

   do k = 1_int32, 3_int32
      id = ip_colormap(trim(MAPS(k))//'_r')
      id = cm_colormap(trim(MAPS(k))//'_r')
      id = ip_colormap(trim(MAPS(k)), 7_int32)
      id = cm_colormap(trim(MAPS(k)), 7_int32)
      id = ip_colormap(trim(MAPS(k))//'_r', 5_int32)
      id = cm_colormap(trim(MAPS(k))//'_r', 5_int32)
   enddo
   id = ip_colormap('Viridis', 9_int32)
   id = cm_colormap('Viridis', 9_int32)
   endsubroutine variants

   function keys_equal() result(ok)
   !< The keys of each map and its variants on both sides.
   logical                       :: ok     !< Equal.
   integer(int32)                :: k, v, lv, id1, id2, j, n, ch !< Map, variant, levels, ids, counters.
   type(im_vec4)                 :: c      !< ImPlot's key.
   real(kind(1.0e0))             :: fk(4)  !< The frame's, as floats.
   character(len=:), allocatable :: nm     !< Name.
   integer(int32), parameter     :: LEVS(4) = [0_int32, 0_int32, 7_int32, 5_int32] !< Variants' levels.

   ok = .true.
   do k = 1_int32, 3_int32
      do v = 1_int32, 5_int32
         nm = trim(MAPS(k))
         if (v == 2_int32 .or. v == 4_int32) nm = nm//'_r'
         lv = 0_int32
         if (v <= 4_int32) lv = LEVS(v)
         if (v == 5_int32) then
            if (k /= 1_int32) cycle
            lv = 9_int32
         endif
         if (lv > 0_int32) then
            id1 = ip_colormap(nm, levels=lv)
            id2 = cm_colormap(nm, lv)
         else
            id1 = ip_colormap(nm)
            id2 = cm_colormap(nm)
         endif
         n = int(ImPlot_GetColormapSize(int(id1, c_int)), int32)
         if (n /= cm_size(id2)) then
            ok = .false.
            write(output_unit, '(A,2(1X,I0))') 'sizes of '//nm, n, cm_size(id2)
            cycle
         endif
         do j = 0_int32, n - 1_int32
            call ImPlot_GetColormapColor(int(j, c_int), int(id1, c_int), c)
            do ch = 0_int32, 3_int32
               fk(ch + 1_int32) = real(iand(ishft(cm_key(id2, j), -8_int32 * ch), 255_int32), kind(fk)) * &
                                  (1.0e0 / 255.0e0)
            enddo
            if (c%x == fk(1) .and. c%y == fk(2) .and. c%z == fk(3)) cycle
            ok = .false.
            write(output_unit, '(A,1X,I0,A,I0)') 'key of '//nm, j, ' levels ', lv
            exit
         enddo
      enddo
   enddo
   endfunction keys_equal
endprogram figure_test_plot_frame_gradients
