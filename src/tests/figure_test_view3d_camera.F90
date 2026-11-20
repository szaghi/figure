!< figure_test_view3d_camera, the 3-D view's camera moved by the program (fit, orbit, pan, zoom) and a mesh removed,
!< against a golden, headless.
program figure_test_view3d_camera
!< figure_test_view3d_camera, the 3-D view's camera moved by the program (fit, orbit, pan, zoom) and a mesh removed,
!< against a golden, headless.
!<
!< A view (`view3d_object`, without lighting) of two triangle meshes (`v%triangles`): a red pyramid with its edges, a
!< blue square beside it.
!< 1. `v%is_initialized`: false before `init`, true after, false after `destroy`;
!< 2. `v%fit` from a camera set far off: the target is the centre of the meshes' bounding box, the direction kept, the
!<    distance shorter;
!< 3. `v%orbit(20, 10)`: azimuth and elevation change by that much, target and distance kept; `v%pan(0.5, 0.25)`: the
!<    target moves by sqrt(0.5^2 + 0.25^2), the distance and the direction kept; `v%zoom(2)`: the distance halves;
!< 4. `v%remove` of the square: done; again: refused (`FIG_ERR_ARGUMENT`);
!< then the view against the golden src/tests/data/figure_test_view3d_camera.golden.png (|d| <= 2): the pyramid
!< alone, seen from where the camera moves left it.
!< The picture is `figure_test_view3d_camera.shot.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps it).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, view3d_object, &
                   ImGuiWindowFlags_NoDecoration, FIG_ERR_ARGUMENT, FIG_OK
use figure_testing, only : test_capture, test_compare_image

implicit none
character(len=*), parameter :: GOLDEN = 'src/tests/data/figure_test_view3d_camera.golden.png' !< The reference.
character(len=*), parameter :: SHOT = 'figure_test_view3d_camera.shot.png.tmp'               !< The window.
integer(int32),   parameter :: W = 360_int32                                                  !< Display width.
integer(int32),   parameter :: H = 300_int32                                                  !< Display height.
real(real64),     parameter :: TOL = 1.0e-9_real64                                            !< Arithmetic's slack.
type(app_object)            :: app             !< Application.
type(view3d_object)         :: v               !< The view.
logical                     :: test_passed(7)  !< Per-check outcome.
logical                     :: inited(3)       !< is_initialized: before init, after, after destroy.
real(real64), target        :: pyr_xyz(3, 5)   !< The pyramid's vertices.
integer(int32), target      :: pyr_tri(3, 6)   !< ... its triangles.
real(real64), target        :: sq_xyz(3, 4)    !< The square's vertices.
integer(int32), target      :: sq_tri(3, 2)    !< ... its triangles.
integer(int32)              :: pyramid, square !< Mesh ids.
real(real64)                :: t0(3), t1(3)    !< Targets: before and after a step.
real(real64)                :: d0, d1          !< Distances.
real(real64)                :: az0, az1        !< Azimuths [degrees].
real(real64)                :: el0, el1        !< Elevations [degrees].
real(real64)                :: centre(3)       !< The meshes' bounding box's centre.
integer(int32)              :: s(3)            !< Statuses.
integer(int64)              :: nf              !< Pixels that failed.
character(len=16)           :: keep            !< FIGURE_TEST_KEEP.

pyr_xyz = reshape([-1, -1, 0,  1, -1, 0,  1, 1, 0,  -1, 1, 0,  0, 0, 2], [3, 5]) * 1.0_real64
pyr_tri = reshape([1, 2, 5,  2, 3, 5,  3, 4, 5,  4, 1, 5,  1, 3, 2,  1, 4, 3], [3, 6])
sq_xyz = reshape([2, -1, 0,  4, -1, 0,  4, 1, 0,  2, 1, 0], [3, 4]) * 1.0_real64
sq_tri = reshape([1, 2, 3,  1, 3, 4], [3, 2])
centre = [1.5_real64, 0.0_real64, 1.0_real64]          ! x in [-1, 4], y in [-1, 1], z in [0, 2]
call app%init_headless(W, H)
inited(1) = v%is_initialized()
call v%init(lighting=.false., background=[0.1_real64, 0.1_real64, 0.12_real64])
inited(2) = v%is_initialized()
pyramid = v%triangles(pyr_xyz, pyr_tri, color=[0.9_real64, 0.2_real64, 0.2_real64], edges=.true., flat=.true.)
square = v%triangles(sq_xyz, sq_tri, color=[0.2_real64, 0.4_real64, 0.9_real64])
call run(3_int32)
! 2. fit from far off
call v%set_camera(target=[30.0_real64, -20.0_real64, 5.0_real64], distance=200.0_real64, azimuth=-40.0_real64, &
                  elevation=25.0_real64)
call v%fit()
call v%get_camera(t0, d0, az0, el0)
test_passed(2) = all(abs(t0 - centre) < TOL) .and. abs(az0 + 40.0_real64) < TOL .and. abs(el0 - 25.0_real64) < TOL &
                 .and. d0 < 200.0_real64 .and. d0 > 0.0_real64
if (.not. test_passed(2)) write(output_unit, '(A,6ES13.5)') 'fit: ', t0, d0, az0, el0
! 3. orbit, pan, zoom
call v%orbit(20.0_real64, 10.0_real64)
call v%get_camera(t1, d1, az1, el1)
test_passed(3) = abs(az1 - az0 - 20.0_real64) < TOL .and. abs(el1 - el0 - 10.0_real64) < TOL .and. &
                 all(abs(t1 - t0) < TOL) .and. abs(d1 - d0) < TOL
call v%pan(0.5_real64, 0.25_real64)
call v%get_camera(t0, d0, az0, el0)
test_passed(4) = abs(norm2(t0 - t1) - sqrt(0.5_real64**2 + 0.25_real64**2)) < 1.0e-6_real64 .and. &
                 abs(d0 - d1) < TOL .and. abs(az0 - az1) < TOL .and. abs(el0 - el1) < TOL
call v%zoom(2.0_real64)
call v%get_camera(t1, d1, az1, el1)
test_passed(5) = abs(d1 - 0.5_real64 * d0) < TOL .and. all(abs(t1 - t0) < TOL)
if (.not. all(test_passed(3:5))) write(output_unit, '(A,3L2,8ES12.4)') 'camera: ', test_passed(3:5), t0, t1, d0, d1
! 4. remove
call v%remove(square, stat=s(1))
call v%remove(square, stat=s(2))
test_passed(6) = s(1) == FIG_OK .and. s(2) == FIG_ERR_ARGUMENT .and. pyramid /= square .and. pyramid > 0_int32
call run(3_int32)
s(3) = -1_int32
call run(1_int32, shot=SHOT, stat=s(3))
call run(1_int32)
test_passed(7) = s(3) == FIG_OK
if (test_passed(7)) test_passed(7) = test_compare_image(SHOT, GOLDEN, failed=nf, stat=s(3))
if (.not. test_passed(7)) write(output_unit, '(A,I0,A,I0,A,A)') 'golden: status ', s(3), ', ', nf, ' failed: ', &
                                                               figure_last_error()
call v%destroy()
inited(3) = v%is_initialized()
test_passed(1) = .not. inited(1) .and. inited(2) .and. .not. inited(3)
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_shot()

write(output_unit, '(A,*(L2))') 'figure_test_view3d_camera checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine run(n, shot, stat)
   !< `n` frames of the view; the last captured to `shot`.
   integer(int32),   intent(in)            :: n    !< Frames.
   character(len=*), intent(in),  optional :: shot !< Capture of the last.
   integer(int32),   intent(out), optional :: stat !< Status of the capture.
   integer(int32)                          :: f    !< Frame.

   do f = 1_int32, n
      if (.not. app%next_frame()) error stop 'figure_test_view3d_camera: next_frame returned false in headless mode'
      call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
      if (ig_begin('view', flags=ImGuiWindowFlags_NoDecoration)) call v%draw('pyramid', 340.0_real64, 280.0_real64)
      call ig_end()
      if (f == n .and. present(shot)) call test_capture(shot, stat)
   enddo
   endsubroutine run

   subroutine remove_shot()
   !< The capture.
   integer(int32) :: unit, ios !< Unit, status.

   open(newunit=unit, file=SHOT, status='old', iostat=ios)
   if (ios == 0) close(unit, status='delete')
   endsubroutine remove_shot
endprogram figure_test_view3d_camera
