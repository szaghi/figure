!< figure_test_gizmo_gradient, the Fortran gradient editor (`ig_gradient_edit` on the Fortran path) against ImGradient.
program figure_test_gizmo_gradient
!< figure_test_gizmo_gradient, the Fortran gradient editor (`ig_gradient_edit` on the Fortran path) against ImGradient.
!<
!< szaghi/figure#15 P14. Three maps (ImPlot's Viridis, the bundled batlow, a user's loaded from a CSV) are edited by
!< the same scripted input at the same frames, first with FIGURE's current path's editor (`ig_gradient_edit` of
!< `figure_implot_ref`: native/figure_colormap.cpp over ImGradient), then with FIGURE's API on the Fortran path
!< (`ig_gradient_edit`: figure_gradient_edit), 40 frames apart, in a window without a title bar (a press on no item
!< would move it). The input: the pointer over the
!< first stop, a press (it is selected), a drag to the right (it moves, clamped at 1 past the end), the release; a
!< double click on the row (a stop added there, of the map's colour); a click on the last stop, then on Remove (it is
!< removed); a click on the strip (nothing). Checked on every frame, to the bit: the map's stops (native
!< `ip_colormap_stops` against `cm_stops`, sorted), whether the frame reported a change, the window's position; the
!< pictures of four frames at FIGURE's oracle rule (|d| <= 2, no pixel failing). The editors' IDs differ (`##ref`,
!< `##fortran`): each keeps its selection in the window's storage. After the Fortran side, the native registry holds
!< its stops (`fig_colormap_set_stops`: what the 3-D views colour with): native `ip_colormap_stops` equal to `cm_stops`.
!<
!< The CSV and the pictures are `figure_test_gizmo_gradient.*.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_gradient_edit, ig_set_next_window, &
                   ImGuiWindowFlags_NoDecoration
use figure_implot_ref, only : ref_gradient_edit => ig_gradient_edit, ip_colormap_stops, ip_load_colormap
use figure_cimgui_enums, only : ImGuiStyleVar_FramePadding, ImGuiStyleVar_ItemSpacing
use figure_core, only : core_frame_height, core_style_vec2, core_text_size, core_window_pos
use figure_plot_colormaps, only : cm_load, cm_stops
use figure_testing, only : test_capture, test_compare_image, test_mouse_button, test_mouse_move, test_next_frame

implicit none
integer(int32),   parameter :: W = 640_int32      !< Display width [pixels].
integer(int32),   parameter :: H = 200_int32      !< Display height [pixels].
integer(int32),   parameter :: NF = 34_int32      !< Frames per side.
integer(int32),   parameter :: NS = 64_int32      !< Stops compared at most.
integer(int32),   parameter :: SHOTS(4) = [10_int32, 18_int32, 27_int32, 34_int32] !< Frames pictured.
character(len=*), parameter :: CSV = 'figure_test_gizmo_gradient.csv.tmp' !< The user's map.
character(len=8), parameter :: MAPS(3) = ['Viridis ', 'batlow  ', 'grad_u  '] !< The maps edited.
real(real64),     parameter :: WIDTH = 500.0_real64 !< The editor's width [pixels].
type(app_object)            :: app                !< Application.
logical                     :: test_passed(3)     !< Per-map outcome.
real(real64)                :: state(5 + 4 * NS, NF, 2) !< Per frame and side: changed, stops, window position, the
                                                  !< stops (position, r, g, b).
integer(int32)              :: m, f, sd, st, i    !< Map, frame, side, status, counter.
real(real64)                :: row, isx, isy, fpx, fpy, tw, th, bar, cy, wx, wy !< The editor's layout.
character(len=:), allocatable :: msg              !< A message.
character(len=16)           :: keep               !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
call write_csv()
call ip_load_colormap('grad_u', CSV, st)
call cm_load('grad_u', CSV, st, msg)
test_passed = .true.
do m = 1_int32, 3_int32
   state = 0.0_real64
   do sd = 1_int32, 2_int32 ! 1 ImGradient (native), 2 the Fortran editor
      do f = 1_int32, NF
         if (.not. app%next_frame()) error stop 'figure_test_gizmo_gradient: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.false.)
         if (ig_begin('gradient', flags=ImGuiWindowFlags_NoDecoration)) call draw(m, sd, f)
         call ig_end()
         if (any(SHOTS == f)) call test_capture(picture(m, f, sd), st)
         call pointer(f)
      enddo
      call test_mouse_move(-100.0_real64, -100.0_real64)
      do i = 1_int32, 40_int32
         if (.not. app%next_frame()) error stop 'figure_test_gizmo_gradient: next_frame returned false headless'
      enddo
   enddo
   do f = 1_int32, NF
      if (all(state(:, f, 1) == state(:, f, 2))) cycle
      test_passed(m) = .false.
      write(output_unit, '(A,I0,A)') trim(MAPS(m))//': frame ', f, ' differs (changed, stops, window x, y):'
      write(output_unit, '(A,5(1X,G0))') '  ref    ', state(1:5, f, 1)
      write(output_unit, '(A,5(1X,G0))') '  fortran', state(1:5, f, 2)
      exit
   enddo
   if (all(state(1, :, 1) == 0.0_real64)) then ! the input edited the map (no test for nothing)
      test_passed(m) = .false.
      write(output_unit, '(A)') trim(MAPS(m))//': the input changed nothing'
   endif
   do i = 1_int32, size(SHOTS)
      test_passed(m) = test_passed(m) .and. pictures_equal(m, SHOTS(i))
   enddo
enddo
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_gizmo_gradient checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine draw(k, side, fr)
   !< The editor of map k on a frame, by a side, and the state it leaves.
   integer(int32), intent(in)    :: k, side, fr !< Map, side, frame.
   logical                       :: changed     !< The map changed.
   integer(int32)                :: s, j        !< Status, counter.
   real(real64), allocatable     :: p(:), c(:,:) !< Stops.
   character(len=:), allocatable :: e           !< Message.

   if (side == 1_int32) then
      changed = ref_gradient_edit('##ref', trim(MAPS(k)), width=WIDTH, stat=s)
      call ip_colormap_stops(trim(MAPS(k)), p, c, s)
   else
      changed = ig_gradient_edit('##fortran', trim(MAPS(k)), width=WIDTH, stat=s)
      call cm_stops(trim(MAPS(k)), p, c, s, e)
      if (fr == NF) call synced(k, p, c)
   endif
   call core_window_pos(wx, wy)
   state(1, fr, side) = merge(1.0_real64, 0.0_real64, changed)
   state(2, fr, side) = real(size(p), real64)
   state(3, fr, side) = real(s, real64)
   state(4, fr, side) = wx
   state(5, fr, side) = wy
   do j = 1_int32, min(size(p, kind=int32), NS)
      state(5 + 4 * j - 3:5 + 4 * j, fr, side) = [p(j), c(:, j)]
   enddo
   if (fr == 1_int32) then ! the layout, as the editor computes it
      row = core_frame_height()
      call core_style_vec2(ImGuiStyleVar_ItemSpacing, isx, isy)
      call core_style_vec2(ImGuiStyleVar_FramePadding, fpx, fpy)
      call core_text_size('Remove', tw, th)
      bar = WIDTH - (row + isx + tw + 2.0_real64 * fpx) - isx
      cy = 8.0_real64 + row + isy + 0.5_real64 * row ! the stops' row's middle
   endif
   endsubroutine draw

   subroutine synced(k, p, c)
   !< The native registry holds the Fortran side's stops of map k.
   integer(int32), intent(in) :: k       !< Map.
   real(real64),   intent(in) :: p(:), c(:,:) !< The Fortran side's stops.
   real(real64), allocatable  :: q(:), d(:,:) !< The native ones.
   integer(int32)             :: s       !< Status.

   call ip_colormap_stops(trim(MAPS(k)), q, d, s)
   if (size(q) == size(p)) then
      if (all(q == p) .and. all(d == c)) return
   endif
   test_passed(k) = .false.
   write(output_unit, '(A)') trim(MAPS(k))//': the native registry does not hold the edited stops'
   endsubroutine synced

   subroutine pointer(fr)
   !< The input after frame fr, the same on both sides.
   integer(int32), intent(in) :: fr !< Frame.
   real(real64)               :: x0 !< The stop at 0's centre.

   x0 = 8.0_real64 + 0.5_real64 * row
   select case (fr)
   case (2_int32)
      call test_mouse_move(x0, cy)
   case (3_int32)
      call test_mouse_button(.true.)
   case (5_int32:9_int32)
      call test_mouse_move(x0 + 23.0_real64 * real(fr - 4_int32, real64), cy)
   case (11_int32)
      call test_mouse_move(x0 + 23.0_real64 * 5.0_real64 + 700.0_real64, cy) ! past the end: clamped at 1
   case (13_int32)
      call test_mouse_button(.false.)
   case (14_int32)
      call test_mouse_move(8.0_real64 + 0.37_real64 * bar, cy)
   case (15_int32)
      call double_click()
   case (20_int32)
      call test_mouse_move(8.0_real64 + bar - 0.5_real64 * row, cy) ! the stop at 1
   case (21_int32)
      call test_mouse_button(.true.)
   case (22_int32)
      call test_mouse_button(.false.)
   case (24_int32) ! Remove: on the colour button's right
      call test_mouse_move(8.0_real64 + bar + isx + row + isx + 0.5_real64 * tw + fpx, cy)
   case (25_int32)
      call test_mouse_button(.true.)
   case (26_int32)
      call test_mouse_button(.false.)
   case (29_int32)
      call test_mouse_move(8.0_real64 + 0.6_real64 * bar, 8.0_real64 + 0.5_real64 * row) ! the strip
   case (30_int32)
      call test_mouse_button(.true.)
   case (31_int32)
      call test_mouse_button(.false.)
   endselect
   endsubroutine pointer

   subroutine double_click()
   !< A double click queued where the pointer is.

   call test_mouse_button(.true.)
   call test_next_frame()
   call test_mouse_button(.false.)
   call test_next_frame()
   call test_mouse_button(.true.)
   call test_next_frame()
   call test_mouse_button(.false.)
   endsubroutine double_click

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

   function pictures_equal(k, fr) result(ok)
   !< A frame's pictures of both sides equal at the oracle's rule.
   integer(int32), intent(in) :: k, fr !< Map, frame.
   logical                    :: ok    !< Equal.
   integer(int64)             :: nf_   !< Pixels that failed.
   integer(int32)             :: s     !< Status.

   ok = test_compare_image(picture(k, fr, 2_int32), picture(k, fr, 1_int32), threshold=2_int32, max_failed=0_int32, &
                           failed=nf_, stat=s)
   if (.not. ok) write(output_unit, '(A,I0,A,I0,A,A)') trim(MAPS(k))//': frame ', fr, ': ', nf_, ' pixels failed: ', &
                                                       figure_last_error()
   endfunction pictures_equal

   function picture(k, fr, side) result(name)
   !< A frame's picture: ImGradient's or the Fortran editor's.
   integer(int32), intent(in)    :: k, fr, side !< Map, frame, side.
   character(len=:), allocatable :: name        !< File name.
   character(len=16)             :: tag         !< The map's and the frame's numbers.

   write(tag, '(I0,A,I0)') k, '.', fr
   if (side == 2_int32) then
      name = 'figure_test_gizmo_gradient.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_gizmo_gradient.'//trim(tag)//'.imgradient.png.tmp'
   endif
   endfunction picture

   subroutine remove_files()
   !< The CSV and the pictures removed (and a mismatch's .new.png and .diff.png, left only on a failure).
   integer(int32) :: k, j, s !< Map, shot, side.

   call remove(CSV)
   do k = 1_int32, 3_int32
      do j = 1_int32, size(SHOTS)
         do s = 1_int32, 2_int32
            call remove(picture(k, SHOTS(j), s))
         enddo
      enddo
   enddo
   endsubroutine remove_files

   subroutine remove(name)
   !< A file removed if it exists.
   character(len=*), intent(in) :: name !< File.
   integer(int32)               :: u, ios !< Unit, status.

   open(newunit=u, file=name, status='old', iostat=ios)
   if (ios == 0) close(u, status='delete')
   endsubroutine remove
endprogram figure_test_gizmo_gradient
