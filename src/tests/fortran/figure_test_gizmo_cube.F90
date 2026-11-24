!< figure_test_gizmo_cube, the Fortran view cube (figure_gizmo's `gz_view_cube`) against ImGuizmo's `ViewManipulate`.
program figure_test_gizmo_cube
!< figure_test_gizmo_cube, the Fortran view cube (figure_gizmo's `gz_view_cube`) against ImGuizmo's `ViewManipulate`.
!<
!< szaghi/figure#15 P14. A 400 x 400 view of a cube with its view cube, driven by the same scripted input at the same
!< frames, first through FIGURE's current path (`v%view_cube`: native/figure_view3d.cpp over ImGuizmo), then through
!< the Fortran cube (`gz_view_cube` on the same view), 40 frames apart, the camera set again before each side. The
!< cases (the cube top-right, 96 pixels, unless said):
!<
!< 1. a click at the cube's centre, the eye at azimuth 10, elevation 5: the camera turned to the +x face over 40 frames;
!< 2. a click near the cube's top front edge (an edge or a corner of the cube), the eye at azimuth 35, elevation 30;
!< 3. a click on the top face, the eye at elevation 75 (the up vector chosen from the camera's right);
!< 4. a drag on the cube: the camera orbits, clamped at the poles;
!< 5. the cube bottom-left, 120 pixels: a click on it;
!< 6. the pointer across the cube without a press (its faces lit), then a drag on the view beside it (the view orbits).
!<
!< Checked on every frame, to the bit: the camera (target, distance, azimuth, elevation) and whether the frame turned
!< it; the pictures of three frames at FIGURE's oracle rule (|d| <= 2, no pixel failing).
!<
!< The pictures are `figure_test_gizmo_cube.*.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: iso_c_binding, only : c_double, c_int
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_item_rect, ig_set_next_window, view3d_object, &
                   ImGuiWindowFlags_NoDecoration, FIG_OK
use figure_gizmo, only : gz_view_cube
use figure_testing, only : test_capture, test_compare_image, test_mouse_button, test_mouse_move
use figure_view3d, only : view3d_handle

implicit none
integer(int32), parameter :: W = 640_int32      !< Display width [pixels].
integer(int32), parameter :: H = 480_int32      !< Display height [pixels].
integer(int32), parameter :: NCASE = 6_int32    !< Cases.
integer(int32), parameter :: NF = 60_int32      !< Frames per side.
integer(int32), parameter :: NSTATE = 7_int32   !< Values per frame: target, distance, azimuth, elevation, turned.
integer(int32), parameter :: SHOTS(3) = [8_int32, 24_int32, 60_int32] !< Frames pictured.
real(real64),   parameter :: VIEW_SIDE = 400.0_real64 !< The view's side [pixels].
real(real64),   parameter :: AZ(NCASE) = [10.0_real64, 35.0_real64, 20.0_real64, 30.0_real64, 10.0_real64, &
                                          30.0_real64] !< The cases' azimuths [degrees].
real(real64),   parameter :: EL(NCASE) = [5.0_real64, 30.0_real64, 75.0_real64, 20.0_real64, 5.0_real64, &
                                          20.0_real64] !< ... elevations.
type(app_object)          :: app                !< Application.
type(view3d_object)       :: v                  !< The view.
real(real64), target      :: cube_xyz(3, 8)     !< Cube's vertices.
integer(int32), target    :: cube_quads(4, 6)   !< Cube's faces.
real(real64)              :: state(NSTATE, NF, 2) !< Per frame and side.
real(real64)              :: view0(2)           !< The view's top-left corner [pixels].
real(real64)              :: cc(2)              !< The cube's centre [pixels].
logical                   :: test_passed(NCASE) !< Per-case outcome.
integer(int32)            :: c, f, sd, i, mesh, st !< Case, frame, side, counter, mesh, status.
character(len=16)         :: keep               !< FIGURE_TEST_KEEP.

cube_xyz = reshape([-1, -1, -1,  1, -1, -1,  1, 1, -1,  -1, 1, -1, &
                    -1, -1,  1,  1, -1,  1,  1, 1,  1,  -1, 1,  1], [3, 8]) * 1.0_real64
cube_quads = reshape([1, 2, 3, 4,  5, 6, 7, 8,  1, 2, 6, 5,  2, 3, 7, 6,  3, 4, 8, 7,  4, 1, 5, 8], [4, 6])
call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
call v%init(lighting=.false., background=[0.1_real64, 0.1_real64, 0.1_real64])
mesh = v%quads(cube_xyz, cube_quads, color=[0.8_real64, 0.6_real64, 0.2_real64], edges=.true.)
test_passed = .true.
do c = 1_int32, NCASE
   state = 0.0_real64
   do sd = 1_int32, 2_int32 ! 1 ImGuizmo (native), 2 the Fortran cube
      call v%set_camera(target=[0.1_real64, -0.2_real64, 0.3_real64], distance=7.5_real64, azimuth=AZ(c), &
                        elevation=EL(c))
      do f = 1_int32, NF
         if (.not. app%next_frame()) error stop 'figure_test_gizmo_cube: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('cube', flags=ImGuiWindowFlags_NoDecoration)) call draw(c, sd, f)
         call ig_end()
         if (any(SHOTS == f)) call test_capture(picture(c, f, sd), st)
         call pointer(c, f)
      enddo
      call test_mouse_move(-100.0_real64, -100.0_real64)
      do i = 1_int32, 40_int32
         if (.not. app%next_frame()) error stop 'figure_test_gizmo_cube: next_frame returned false headless'
      enddo
   enddo
   do f = 1_int32, NF
      if (all(state(:, f, 1) == state(:, f, 2))) cycle
      test_passed(c) = .false.
      write(output_unit, '(A,I0,A,I0,A)') 'case ', c, ': frame ', f, ' differs (target, distance, azimuth, elevation, turned):'
      write(output_unit, '(A,7(1X,G0))') '  imguizmo', state(:, f, 1)
      write(output_unit, '(A,7(1X,G0))') '  fortran ', state(:, f, 2)
      exit
   enddo
   if (all(state(5:6, NF, 1) == state(5:6, 1, 1))) then ! the input turned the camera (no test for nothing)
      write(output_unit, '(A,I0,A)') 'case ', c, ': the camera did not turn'
      test_passed(c) = .false.
   endif
   if (c /= NCASE .and. all(state(7, :, 1) == 0.0_real64)) then
      write(output_unit, '(A,I0,A)') 'case ', c, ': the cube turned nothing'
      test_passed(c) = .false.
   endif
   do i = 1_int32, size(SHOTS)
      test_passed(c) = test_passed(c) .and. pictures_equal(c, SHOTS(i))
   enddo
enddo
call v%destroy()
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_gizmo_cube checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine draw(k, who, fr)
   !< The view and its cube on a frame, by a side, and the state they leave.
   integer(int32), intent(in) :: k, who, fr !< Case, side, frame.
   real(real64)               :: x0, y0, x1, y1, t(3), d, a, e !< The view's rectangle, the camera.
   integer(c_int)             :: turned, s  !< Turned, status.
   real(real64)               :: az0, el0   !< The camera before the cube.

   call v%draw('view', VIEW_SIDE, VIEW_SIDE)
   call ig_item_rect(x0, y0, x1, y1)
   view0 = [x0, y0]
   call v%get_camera(azimuth=az0, elevation=el0)
   turned = 0_c_int
   if (who == 1_int32) then
      if (k == 5_int32) then
         call v%view_cube(size=120.0_real64, corner='bottom-left')
      else
         call v%view_cube()
      endif
      call v%get_camera(azimuth=a, elevation=e)
      if (a /= az0 .or. e /= el0) turned = 1_c_int
   else
      if (k == 5_int32) then
         s = gz_view_cube(view3d_handle(v), 120.0_c_double, 3_c_int, turned)
      else
         s = gz_view_cube(view3d_handle(v), 96.0_c_double, 0_c_int, turned)
      endif
      if (s /= FIG_OK) write(output_unit, '(A)') 'gz_view_cube: '//figure_last_error()
      call v%get_camera(azimuth=a, elevation=e) ! turned: as the other side sees it (at a pole a turn of the up vector
      turned = merge(1_c_int, 0_c_int, a /= az0 .or. e /= el0) ! may leave the azimuth and the elevation as they were)
   endif
   call v%get_camera(target=t, distance=d, azimuth=a, elevation=e)
   state(:, fr, who) = [t, d, a, e, real(turned, real64)]
   if (k == 5_int32) then
      cc = [view0(1) + 60.0_real64, view0(2) + VIEW_SIDE - 60.0_real64]
   else
      cc = [view0(1) + VIEW_SIDE - 48.0_real64, view0(2) + 48.0_real64]
   endif
   endsubroutine draw

   subroutine pointer(k, fr)
   !< The input after frame fr, the same on both sides.
   integer(int32), intent(in) :: k, fr !< Case, frame.
   real(real64)               :: p(2)  !< The pixel pressed.

   p = cc
   if (k == 2_int32) p = cc + [-20.0_real64, -12.0_real64]
   if (k == 3_int32) p = cc + [0.0_real64, -14.0_real64]
   select case (k)
   case (4_int32) ! a drag on the cube
      select case (fr)
      case (2_int32)
         call test_mouse_move(p(1), p(2))
      case (4_int32)
         call test_mouse_button(.true.)
      case (6_int32:20_int32)
         call test_mouse_move(p(1) + 3.0_real64 * real(fr - 5_int32, real64), p(2) + 4.0_real64 * real(fr - 5_int32, real64))
      case (22_int32)
         call test_mouse_button(.false.)
      endselect
   case (6_int32) ! hover across the cube, then a drag on the view
      select case (fr)
      case (2_int32:16_int32)
         call test_mouse_move(cc(1) - 45.0_real64 + 6.0_real64 * real(fr - 2_int32, real64), cc(2) - 20.0_real64 + &
                              3.0_real64 * real(fr - 2_int32, real64))
      case (18_int32)
         call test_mouse_move(view0(1) + 100.0_real64, view0(2) + 300.0_real64)
      case (20_int32)
         call test_mouse_button(.true.)
      case (22_int32:30_int32)
         call test_mouse_move(view0(1) + 100.0_real64 + 5.0_real64 * real(fr - 21_int32, real64), view0(2) + 300.0_real64)
      case (32_int32)
         call test_mouse_button(.false.)
      endselect
   case default ! a click
      select case (fr)
      case (2_int32)
         call test_mouse_move(p(1), p(2))
      case (4_int32)
         call test_mouse_button(.true.)
      case (5_int32)
         call test_mouse_button(.false.)
      case (8_int32)
         call test_mouse_move(-100.0_real64, -100.0_real64)
      endselect
   endselect
   endsubroutine pointer

   function pictures_equal(k, fr) result(ok)
   !< A frame's pictures of both sides equal at the oracle's rule.
   integer(int32), intent(in) :: k, fr !< Case, frame.
   logical                    :: ok    !< Equal.
   integer(int64)             :: nf_   !< Pixels that failed.
   integer(int32)             :: s     !< Status.

   ok = test_compare_image(picture(k, fr, 2_int32), picture(k, fr, 1_int32), threshold=2_int32, max_failed=0_int32, &
                           failed=nf_, stat=s)
   if (.not. ok) write(output_unit, '(A,I0,A,I0,A,I0,A,A)') 'case ', k, ': frame ', fr, ': ', nf_, ' pixels failed: ', &
                                                           figure_last_error()
   endfunction pictures_equal

   function picture(k, fr, who) result(name)
   !< A frame's picture: ImGuizmo's or the Fortran cube's.
   integer(int32), intent(in)    :: k, fr, who !< Case, frame, side.
   character(len=:), allocatable :: name       !< File name.
   character(len=16)             :: tag        !< The case's and the frame's numbers.

   write(tag, '(I0,A,I0)') k, '.', fr
   if (who == 2_int32) then
      name = 'figure_test_gizmo_cube.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_gizmo_cube.'//trim(tag)//'.imguizmo.png.tmp'
   endif
   endfunction picture

   subroutine remove_files()
   !< The pictures removed (and a mismatch's .new.png and .diff.png, left only on a failure).
   integer(int32) :: k, j, s, u, ios !< Case, shot, side, unit, status.

   do k = 1_int32, NCASE
      do j = 1_int32, size(SHOTS)
         do s = 1_int32, 2_int32
            open(newunit=u, file=picture(k, SHOTS(j), s), status='old', iostat=ios)
            if (ios == 0) close(u, status='delete')
         enddo
      enddo
   enddo
   endsubroutine remove_files
endprogram figure_test_gizmo_cube
