!< figure_test_gizmo_manipulate, the Fortran gizmos (figure_gizmo's `gz_view_gizmo`) against ImGuizmo's `Manipulate`.
program figure_test_gizmo_manipulate
!< figure_test_gizmo_manipulate, the Fortran gizmos (figure_gizmo's `gz_view_gizmo`) against ImGuizmo's `Manipulate`.
!<
!< szaghi/figure#15 P14. A 400 x 400 view of a cube (eye at azimuth 30, elevation 20, 8 units from the origin), and a
!< gizmo moving a matrix at the origin, driven by the same scripted input at the same frames, first through FIGURE's
!< current path (`v%gizmo`: native/figure_view3d.cpp over ImGuizmo), then through the Fortran gizmo (`gz_view_gizmo`
!< on the same view), 40 frames apart, the camera and the matrix set again before each side. The cases:
!<
!< 1. translate, world: the x arrow dragged; 2. the same with a snap of 0.25; 3. translate, local, the matrix turned
!< 30 degrees about z: its own x arrow dragged; 4. translate on the screen's plane (the centre); 5. rotate, world: the
!< z ring dragged; 6. rotate, local, snap 15 degrees, the matrix turned: its z ring; 7. scale: the x handle dragged;
!< 8. scale, uniform (the centre), snap 0.5; 9. the pointer over the handles without a press, then a drag beside the
!< gizmo (the view orbits, the matrix stays).
!<
!< Checked on every frame, to the bit: the matrix, whether the frame reported a move, the camera (azimuth, elevation,
!< distance); the pictures of two frames at FIGURE's oracle rule (|d| <= 2, no pixel failing). The handles' pixels
!< come from the view's matrices: the gizmo's axes are 80 pixels long seen across (a fifth of the view's side).
!<
!< The pictures are `figure_test_gizmo_manipulate.*.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: iso_c_binding, only : c_double, c_int
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_item_rect, ig_set_next_window, view3d_object, &
                   ImGuiWindowFlags_NoDecoration, FIG_OK
use figure_gizmo, only : gz_view_gizmo
use figure_testing, only : test_capture, test_compare_image, test_mouse_button, test_mouse_move
use figure_view3d, only : view3d_handle

implicit none
integer(int32), parameter :: W = 640_int32      !< Display width [pixels].
integer(int32), parameter :: H = 480_int32      !< Display height [pixels].
integer(int32), parameter :: NCASE = 9_int32    !< Cases.
integer(int32), parameter :: NF = 26_int32      !< Frames per side.
integer(int32), parameter :: NSTATE = 20_int32  !< Values per frame: the matrix, moved, azimuth, elevation, distance.
integer(int32), parameter :: SHOTS(2) = [12_int32, 26_int32] !< Frames pictured.
real(real64),   parameter :: SIDE = 400.0_real64 !< The view's side [pixels].
real(real64),   parameter :: DIST = 8.0_real64  !< The camera's distance.
real(real64),   parameter :: PI = acos(-1.0_real64) !< Pi.
type(app_object)          :: app                !< Application.
type(view3d_object)       :: v                  !< The view.
real(real64), target      :: cube_xyz(3, 8)     !< Cube's vertices.
integer(int32), target    :: cube_quads(4, 6)   !< Cube's faces.
real(real64)              :: m(4, 4)            !< The gizmo's matrix.
real(real64)              :: state(NSTATE, NF, 2) !< Per frame and side.
real(real64)              :: view0(2)           !< The view's top-left corner [pixels].
real(real64)              :: vm(4, 4), pm(4, 4) !< The view's matrices.
real(real64)              :: sf                 !< The gizmo's axis length [world units].
real(real64)              :: target(2)          !< The case's handle [pixels].
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
sf = 80.0_real64 * 2.0_real64 * DIST * tan(15.0_real64 * PI / 180.0_real64) / SIDE ! 80 pixels across, at the target
test_passed = .true.
do c = 1_int32, NCASE
   state = 0.0_real64
   do sd = 1_int32, 2_int32 ! 1 ImGuizmo (native), 2 the Fortran gizmo
      call v%set_camera(target=[0.0_real64, 0.0_real64, 0.0_real64], distance=DIST, azimuth=30.0_real64, &
                        elevation=20.0_real64)
      m = start_matrix(c)
      do f = 1_int32, NF
         if (.not. app%next_frame()) error stop 'figure_test_gizmo_manipulate: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('gizmo', flags=ImGuiWindowFlags_NoDecoration)) call draw(c, sd, f)
         call ig_end()
         if (any(SHOTS == f)) call test_capture(picture(c, f, sd), st)
         if (f == 1_int32) then
            call v%view_matrix(vm)
            call v%projection_matrix(pm)
            target = handle(c)
         endif
         call pointer(c, f)
      enddo
      call test_mouse_move(-100.0_real64, -100.0_real64)
      do i = 1_int32, 40_int32
         if (.not. app%next_frame()) error stop 'figure_test_gizmo_manipulate: next_frame returned false headless'
      enddo
   enddo
   do f = 1_int32, NF
      if (all(state(:, f, 1) == state(:, f, 2) .or. (state(:, f, 1) /= state(:, f, 1) .and. &
                                                    state(:, f, 2) /= state(:, f, 2)))) cycle
      test_passed(c) = .false.
      write(output_unit, '(A,I0,A,I0,A)') 'case ', c, ': frame ', f, ' differs (matrix, moved, camera):'
      write(output_unit, '(A,20(1X,G0))') '  imguizmo', state(:, f, 1)
      write(output_unit, '(A,20(1X,G0))') '  fortran ', state(:, f, 2)
      exit
   enddo
   if (c < NCASE .and. all(state(1:16, NF, 1) == state(1:16, 1, 1))) then ! the input moved the matrix
      write(output_unit, '(A,I0,A)') 'case ', c, ': the input moved nothing'
      test_passed(c) = .false.
   endif
   if (c == NCASE .and. state(18, NF, 1) == state(18, 1, 1)) then ! the view orbited
      write(output_unit, '(A,I0,A)') 'case ', c, ': the view did not orbit'
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

write(output_unit, '(A,*(L2))') 'figure_test_gizmo_manipulate checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine draw(k, who, fr)
   !< The view and the case's gizmo on a frame, by a side, and the state they leave.
   integer(int32), intent(in) :: k, who, fr !< Case, side, frame.
   real(real64)               :: x0, y0, x1, y1, az, el, d !< The view's rectangle, the camera.
   real(c_double)             :: a(16)       !< The matrix, C copy.
   integer(c_int)             :: moved, s    !< Moved, status.
   logical                    :: changed     !< Moved.

   call v%draw('view', SIDE, SIDE)
   call ig_item_rect(x0, y0, x1, y1)
   view0 = [x0, y0]
   changed = .false.
   if (who == 1_int32) then
      select case (k)
      case (2_int32)
         changed = v%gizmo('g', m, mode='translate', snap=0.25_real64)
      case (3_int32)
         changed = v%gizmo('g', m, mode='translate', space='local')
      case (5_int32)
         changed = v%gizmo('g', m, mode='rotate')
      case (6_int32)
         changed = v%gizmo('g', m, mode='rotate', space='local', snap=15.0_real64)
      case (7_int32)
         changed = v%gizmo('g', m, mode='scale')
      case (8_int32)
         changed = v%gizmo('g', m, mode='scale', snap=0.5_real64)
      case default
         changed = v%gizmo('g', m, mode='translate')
      endselect
   else
      a = reshape(m, [16])
      moved = 0_c_int
      select case (k)
      case (2_int32)
         s = gz_view_gizmo(view3d_handle(v), 'g', a, 0_c_int, 0_c_int, 1_c_int, 0.25_c_double, moved)
      case (3_int32)
         s = gz_view_gizmo(view3d_handle(v), 'g', a, 0_c_int, 1_c_int, 0_c_int, 0.0_c_double, moved)
      case (5_int32)
         s = gz_view_gizmo(view3d_handle(v), 'g', a, 1_c_int, 0_c_int, 0_c_int, 0.0_c_double, moved)
      case (6_int32)
         s = gz_view_gizmo(view3d_handle(v), 'g', a, 1_c_int, 1_c_int, 1_c_int, 15.0_c_double, moved)
      case (7_int32)
         s = gz_view_gizmo(view3d_handle(v), 'g', a, 2_c_int, 0_c_int, 0_c_int, 0.0_c_double, moved)
      case (8_int32)
         s = gz_view_gizmo(view3d_handle(v), 'g', a, 2_c_int, 0_c_int, 1_c_int, 0.5_c_double, moved)
      case default
         s = gz_view_gizmo(view3d_handle(v), 'g', a, 0_c_int, 0_c_int, 0_c_int, 0.0_c_double, moved)
      endselect
      if (s /= FIG_OK) write(output_unit, '(A)') 'gz_view_gizmo: '//figure_last_error()
      if (moved /= 0_c_int) then
         m = reshape(a, [4, 4])
         changed = .true.
      endif
   endif
   call v%get_camera(distance=d, azimuth=az, elevation=el)
   state(1:16, fr, who) = reshape(m, [16])
   state(17, fr, who) = merge(1.0_real64, 0.0_real64, changed)
   state(18:20, fr, who) = [az, el, d]
   endsubroutine draw

   function start_matrix(k) result(a)
   !< The case's matrix at its start: the identity, turned 30 degrees about z for the local cases.
   integer(int32), intent(in) :: k      !< Case.
   real(real64)               :: a(4, 4) !< Matrix.
   real(real64)               :: t      !< Angle.
   integer(int32)             :: j      !< Counter.

   a = 0.0_real64
   do j = 1_int32, 4_int32
      a(j, j) = 1.0_real64
   enddo
   if (k == 3_int32 .or. k == 6_int32) then
      t = 30.0_real64 * PI / 180.0_real64
      a(1:2, 1) = [cos(t), sin(t)]
      a(1:2, 2) = [-sin(t), cos(t)]
   endif
   endfunction start_matrix

   function pixel(p) result(q)
   !< A world point's pixel in the view.
   real(real64), intent(in) :: p(3)   !< Point.
   real(real64)             :: q(2)   !< Pixel.
   real(real64)             :: e(4), cl(4) !< Eye and clip coordinates.

   e = matmul(vm, [p, 1.0_real64])
   cl = matmul(pm, e)
   q(1) = view0(1) + (cl(1) / cl(4) * 0.5_real64 + 0.5_real64) * SIDE
   q(2) = view0(2) + (1.0_real64 - (cl(2) / cl(4) * 0.5_real64 + 0.5_real64)) * SIDE
   endfunction pixel

   function handle(k) result(q)
   !< The pixel the case presses: an axis's middle, a ring's point facing the eye, or the centre.
   integer(int32), intent(in) :: k    !< Case.
   real(real64)               :: q(2) !< Pixel.
   real(real64)               :: t    !< Angle.

   select case (k)
   case (1_int32, 2_int32, 7_int32)
      q = pixel([0.55_real64 * sf, 0.0_real64, 0.0_real64])
   case (3_int32)
      t = 30.0_real64 * PI / 180.0_real64
      q = pixel([0.55_real64 * sf * cos(t), 0.55_real64 * sf * sin(t), 0.0_real64])
   case (5_int32, 6_int32) ! the z ring toward the eye (azimuth 30)
      t = 30.0_real64 * PI / 180.0_real64
      q = pixel([1.2_real64 * sf * cos(t), 1.2_real64 * sf * sin(t), 0.0_real64])
   case (9_int32)
      q = pixel([0.55_real64 * sf, 0.0_real64, 0.0_real64])
   case default
      q = pixel([0.0_real64, 0.0_real64, 0.0_real64])
   endselect
   endfunction handle

   subroutine pointer(k, fr)
   !< The input after frame fr, the same on both sides.
   integer(int32), intent(in) :: k, fr !< Case, frame.
   real(real64)               :: dx, dy !< The drag's step [pixels].

   dx = 9.0_real64
   dy = -4.0_real64
   if (k == 5_int32 .or. k == 6_int32) dy = 9.0_real64
   if (k == NCASE) then ! hover only, then a drag beside the gizmo
      select case (fr)
      case (2_int32:8_int32)
         call test_mouse_move(target(1) + 3.0_real64 * real(fr - 5_int32, real64), target(2) + 2.0_real64)
      case (10_int32)
         call test_mouse_move(view0(1) + 40.0_real64, view0(2) + 360.0_real64)
      case (12_int32)
         call test_mouse_button(.true.)
      case (14_int32:18_int32)
         call test_mouse_move(view0(1) + 40.0_real64 + 6.0_real64 * real(fr - 13_int32, real64), view0(2) + 360.0_real64)
      case (20_int32)
         call test_mouse_button(.false.)
      endselect
      return
   endif
   select case (fr)
   case (2_int32)
      call test_mouse_move(target(1), target(2))
   case (4_int32)
      call test_mouse_button(.true.)
   case (6_int32:15_int32)
      call test_mouse_move(target(1) + dx * real(fr - 5_int32, real64), target(2) + dy * real(fr - 5_int32, real64))
   case (18_int32)
      call test_mouse_button(.false.)
   case (21_int32)
      call test_mouse_move(target(1) - 30.0_real64, target(2) + 25.0_real64)
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
   !< A frame's picture: ImGuizmo's or the Fortran gizmo's.
   integer(int32), intent(in)    :: k, fr, who !< Case, frame, side.
   character(len=:), allocatable :: name        !< File name.
   character(len=16)             :: tag         !< The case's and the frame's numbers.

   write(tag, '(I0,A,I0)') k, '.', fr
   if (who == 2_int32) then
      name = 'figure_test_gizmo_manipulate.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_gizmo_manipulate.'//trim(tag)//'.imguizmo.png.tmp'
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
endprogram figure_test_gizmo_manipulate
