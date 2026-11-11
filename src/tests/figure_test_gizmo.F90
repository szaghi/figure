!< figure_test_gizmo, the 3-D view's gizmos (view cube, translate gizmo) and the gradient editor, headless.
program figure_test_gizmo
!< figure_test_gizmo, the 3-D view's gizmos (view cube, translate gizmo) and the gradient editor, headless.
!<
!< A 400x400 view of a cube in a window without a title bar at the origin (a press on no item would move it):
!< - the view cube: a click at its centre, the camera at azimuth 10 and elevation 5, turns the camera to the +x face
!<   (azimuth 0, elevation 0) over the cube's 40 frames, its target and distance kept, the window not moved; at
!<   elevation 75 to the top face (elevation 90); a drag on the cube orbits the camera;
!< - the translate gizmo at the origin (the camera's target), the eye on -y: a drag of its x arrow by D pixels moves
!<   the matrix by D times the world's size of a pixel at the target, along x only (relative error <= 1e-4); a drag
!<   beside it orbits the view and leaves the matrix alone; snap rounds the motion to its step; the arrow seen at 30,
!<   20 and 12 degrees from the line of sight, toward the eye, moves the matrix forward by about 1 / sin of the angle
!<   (the ratios printed); the drag 1e5 units from the origin as exact;
!< - view_matrix and projection_matrix: the eye's position from the view matrix, a world point to the pixel the view
!<   shows it at;
!< - the gradient editor of a map of three stops (red, green, blue): the green stop dragged 60 pixels to the right
!<   moves to 0.5 + 60 / (the stops' width), and the map's colour at 0.5 changes as the stops say in ImPlot's registry,
!<   in its reverse registered before, in a field image and a 3-D view coloured by it, the window not moved; a double
!<   click adds a stop; a qualitative or reversed map is refused;
!< - a golden picture of the view, its cube and a gizmo, and the gradient editor (src/tests/data, |d| <= 2);
!< - the statuses: before the view is drawn, unknown modes and corners, a matrix with a bad last row.
!< The pictures are `figure_test_gizmo.*.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: iso_c_binding, only : c_float, c_int
use, intrinsic :: iso_fortran_env, only : int8, int32, real64, output_unit
use figure, only : app_object, ig_begin, ig_end, ig_item_rect, ig_set_next_window, ip_begin_plot, ip_colormap, &
                   ip_colormap_stops, ip_end_plot, ip_field_image, ip_load_colormap, ig_gradient_edit, view3d_object, &
                   ImGuiWindowFlags_NoDecoration, FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_OK
use figure_cimgui, only : im_vec4
use figure_cimplot, only : ImPlot_SampleColormap
use figure_testing, only : test_capture, test_compare_image, test_field_pixel, test_item_rect, test_mouse_button, &
                           test_mouse_move, test_next_frame, test_window_rect

implicit none
character(len=*), parameter :: GOLDEN = 'src/tests/data/figure_test_gizmo.golden.png' !< The committed reference.
character(len=*), parameter :: SHOT = 'figure_test_gizmo.shot.png.tmp' !< The window.
character(len=*), parameter :: CSV = 'figure_test_gizmo.rgb.csv.tmp'   !< A map of three colours.
integer(int32),   parameter :: W = 640_int32                           !< Display width [pixels].
integer(int32),   parameter :: H = 560_int32                           !< Display height [pixels].
real(real64),     parameter :: SIDE = 400.0_real64                     !< The view's side [pixels].
real(real64),     parameter :: PI = acos(-1.0_real64)                  !< Pi.
type(app_object)            :: app             !< Application.
type(view3d_object)         :: v               !< The view.
type(view3d_object)         :: swatch          !< A view of a square coloured by the map at 0.5.
real(real64), target        :: square_xyz(3, 4) !< The square's corners.
integer(int32), target      :: square_quad(4, 1) !< Its quad.
real(real64), target        :: square_s(4)     !< Its scalar, 0.5 everywhere (the map's ends at 0 and 1).
logical                     :: test_passed(14) !< Per-check outcome.
real(real64), target        :: cube_xyz(3, 8)  !< Cube's vertices.
integer(int32), target      :: cube_quads(4, 6) !< Cube's faces.
real(real64), target        :: field(3, 1)     !< A field of the values 0, 0.5, 1.
real(real64)                :: m(4, 4)         !< The gizmo's matrix.
real(real64)                :: view0(2)        !< The view's top-left corner [pixels].
character(len=16)           :: mode            !< The gizmo's mode ('': none drawn).
real(real64)                :: snap            !< The gizmo's snap (0: none).
logical                     :: show_cube       !< The view cube is drawn.
logical                     :: show_gradient   !< The gradient editor is drawn.
logical                     :: moved           !< The gizmo reported a move, over some frames.
logical                     :: edited          !< The gradient editor reported a change, over some frames.
integer(int32)              :: mesh            !< Mesh id.
integer(int32)              :: early           !< A status before the first frame.
character(len=8)            :: keep            !< FIGURE_TEST_KEEP.

test_passed = .false.
call build_data()
call app%init_headless(W, H)
call v%init(lighting=.false., background=[0.1_real64, 0.1_real64, 0.1_real64])
mesh = v%quads(cube_xyz, cube_quads, color=[0.8_real64, 0.6_real64, 0.2_real64], edges=.true.)
call write_map()
call ip_load_colormap('rgb3', CSV)
call swatch%init(lighting=.false., background=[0.0_real64, 0.0_real64, 0.0_real64])
mesh = swatch%quads(square_xyz, square_quad, scalar=square_s, colormap='rgb3')
call swatch%set_mesh(mesh, vmin=0.0_real64, vmax=1.0_real64)
call swatch%view('+z')
early = FIG_OK
call v%view_cube(stat=early) ! no frame open
mode = ''
snap = 0.0_real64
show_cube = .true.
show_gradient = .true.
m = identity()
call frames(2)

call cube_face(test_passed(1))
call cube_top(test_passed(2))
call cube_drag(test_passed(3))
call translate(test_passed(4))
call beside(test_passed(5))
call far_away(test_passed(14))
call snapping(test_passed(6))
call matrices(test_passed(7))
call gradient(test_passed(8:9))
call gradient_add(test_passed(10))
call grazing(test_passed(13))
call picture(test_passed(11))
call statuses(test_passed(12))
call v%destroy()
call swatch%destroy()
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_gizmo checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine build_data()
   !< The cube's arrays, the field.
   cube_xyz = reshape([-1, -1, -1,  1, -1, -1,  1, 1, -1,  -1, 1, -1, &
                       -1, -1,  1,  1, -1,  1,  1, 1,  1,  -1, 1,  1], [3, 8]) * 1.0_real64
   cube_quads = reshape([1, 2, 3, 4,  5, 6, 7, 8,  1, 2, 6, 5,  2, 3, 7, 6,  3, 4, 8, 7,  4, 1, 5, 8], [4, 6])
   field(:, 1) = [0.0_real64, 0.5_real64, 1.0_real64]
   square_xyz = reshape([-1, -1, 0,  1, -1, 0,  1, 1, 0,  -1, 1, 0], [3, 4]) * 1.0_real64
   square_quad(:, 1) = [1, 2, 3, 4]
   square_s = 0.5_real64
   endsubroutine build_data

   subroutine write_map()
   !< A CSV map of three colours: red, green, blue.
   integer(int32) :: u !< Unit.

   open(newunit=u, file=CSV, status='replace', action='write')
   write(u, '(A)') '1, 0, 0'
   write(u, '(A)') '0, 1, 0'
   write(u, '(A)') '0, 0, 1'
   close(u)
   endsubroutine write_map

   pure function identity() result(a)
   !< The 4x4 identity.
   real(real64) :: a(4, 4) !< Matrix.
   integer      :: i       !< Counter.

   a = 0.0_real64
   do i = 1, 4
      a(i, i) = 1.0_real64
   enddo
   endfunction identity

   subroutine frames(n)
   !< Draw `n` frames: the view, its cube and gizmo as asked, the gradient editor and a field coloured by the map.
   integer(int32), intent(in) :: n   !< Frames.
   integer(int32)             :: k   !< Counter.
   real(real64)               :: x0  !< Item rectangle.
   real(real64)               :: y0  !< ...
   real(real64)               :: x1  !< ...
   real(real64)               :: y1  !< ...

   do k = 1_int32, n
      if (.not. app%next_frame()) exit
      call ig_set_next_window(x=0.0_real64, y=0.0_real64, width=real(W, real64), height=real(H, real64))
      if (ig_begin('gizmos', flags=ImGuiWindowFlags_NoDecoration)) then
         call v%draw('view', SIDE, SIDE)
         call ig_item_rect(x0, y0, x1, y1)
         view0 = [x0, y0]
         if (show_cube) call v%view_cube()
         if (len_trim(mode) > 0) then
            if (snap > 0.0_real64) then
               if (v%gizmo('plane', m, mode=trim(mode), snap=snap)) moved = .true.
            else
               if (v%gizmo('plane', m, mode=trim(mode))) moved = .true.
            endif
         endif
         if (show_gradient) then
            if (ig_gradient_edit('gradient', 'rgb3', width=SIDE)) edited = .true.
            if (ip_begin_plot('field', width=SIDE, height=40.0_real64)) then
               call ip_field_image('rgb', field, 0.0_real64, 3.0_real64, 0.0_real64, 1.0_real64, &
                                   colormap=ip_colormap('rgb3'), vmin=0.0_real64, vmax=1.0_real64)
               call ip_end_plot()
            endif
            call swatch%draw('swatch', 40.0_real64, 40.0_real64)
         endif
      endif
      call ig_end()
   enddo
   endsubroutine frames

   subroutine click(x, y, settle)
   !< A click at (x, y), then `settle` frames.
   real(real64),   intent(in) :: x      !< Abscissa [pixels].
   real(real64),   intent(in) :: y      !< Ordinate [pixels].
   integer(int32), intent(in) :: settle !< Frames after it.

   call test_mouse_move(x, y)
   call test_next_frame()
   call test_next_frame()
   call test_mouse_button(.true.)
   call test_next_frame()
   call test_mouse_button(.false.)
   call frames(4_int32 + settle)
   endsubroutine click

   subroutine drag(x0, y0, x1, y1)
   !< A drag with the left button from (x0, y0) to (x1, y1): the pointer rests on the handle for two frames (the
   !< gizmos take the mouse from the frame after it reaches them), is pressed and held for two, moved, released.
   real(real64), intent(in) :: x0 !< Start abscissa [pixels].
   real(real64), intent(in) :: y0 !< Start ordinate [pixels].
   real(real64), intent(in) :: x1 !< End abscissa [pixels].
   real(real64), intent(in) :: y1 !< End ordinate [pixels].

   call test_mouse_move(x0, y0)
   call test_next_frame()
   call test_next_frame()
   call test_mouse_button(.true.)
   call test_next_frame()
   call test_next_frame()
   call test_mouse_move(x1, y1)
   call test_next_frame()
   call test_mouse_button(.false.)
   call frames(8_int32)
   endsubroutine drag

   subroutine park()
   !< The pointer away from the view, the gizmo and the editor.
   call test_mouse_move(real(W, real64) - 5.0_real64, real(H, real64) - 5.0_real64)
   call frames(3_int32)
   endsubroutine park

   subroutine cube_centre(x, y)
   !< The centre of the view cube (96 pixels, top-right of the view).
   real(real64), intent(out) :: x !< Abscissa [pixels].
   real(real64), intent(out) :: y !< Ordinate [pixels].

   x = view0(1) + SIDE - 48.0_real64
   y = view0(2) + 48.0_real64
   endsubroutine cube_centre

   subroutine cube_face(ok)
   !< A click at the cube's centre, the eye near +x: the camera turns to +x, target and distance kept, no orbit.
   logical, intent(out) :: ok          !< Outcome.
   real(real64)         :: x, y        !< Cube centre.
   real(real64)         :: t0(3), d0   !< Target and distance before.
   real(real64)         :: t(3), d     !< ... after.
   real(real64)         :: az, el      !< Camera after.
   real(real64)         :: wx, wy, ww, wh !< The window's rectangle.

   call v%set_camera(target=[0.0_real64, 0.0_real64, 0.0_real64], distance=8.0_real64, azimuth=10.0_real64, &
                     elevation=5.0_real64)
   call frames(2_int32)
   call v%get_camera(target=t0, distance=d0)
   call cube_centre(x, y)
   call click(x, y, 44_int32)
   call v%get_camera(target=t, distance=d, azimuth=az, elevation=el)
   call test_window_rect('gizmos', wx, wy, ww, wh)
   ok = abs(az) < 1.0e-3_real64 .and. abs(el) < 1.0e-3_real64 .and. all(abs(t - t0) < 1.0e-9_real64) .and. &
        abs(d - d0) < 1.0e-9_real64 .and. abs(wx) < 0.5_real64 .and. abs(wy) < 0.5_real64
   if (.not. ok) write(output_unit, '(A,4G14.6)') 'cube_face: azimuth, elevation, window ', az, el, wx, wy
   call park()
   endsubroutine cube_face

   subroutine cube_top(ok)
   !< A click at the cube's centre, the eye high above: the camera looks down (elevation 90).
   logical, intent(out) :: ok     !< Outcome.
   real(real64)         :: x, y   !< Cube centre.
   real(real64)         :: el     !< Elevation after.

   call v%set_camera(azimuth=10.0_real64, elevation=75.0_real64)
   call frames(2_int32)
   call cube_centre(x, y)
   call click(x, y, 44_int32)
   call v%get_camera(elevation=el)
   ok = abs(el - 90.0_real64) < 1.0e-3_real64
   if (.not. ok) write(output_unit, '(A,G14.6)') 'cube_top: elevation ', el
   call park()
   endsubroutine cube_top

   subroutine cube_drag(ok)
   !< A drag across the cube: the camera's azimuth changes, the window stays.
   logical, intent(out) :: ok             !< Outcome.
   real(real64)         :: x, y           !< Cube centre.
   real(real64)         :: az0, az        !< Azimuth before and after.
   real(real64)         :: wx, wy, ww, wh !< The window's rectangle.

   call v%set_camera(azimuth=30.0_real64, elevation=20.0_real64)
   call frames(2_int32)
   call cube_centre(x, y)
   call v%get_camera(azimuth=az0)
   call drag(x, y, x + 30.0_real64, y)
   call v%get_camera(azimuth=az)
   call test_window_rect('gizmos', wx, wy, ww, wh)
   ok = abs(az - az0) > 5.0_real64 .and. abs(wx) < 0.5_real64 .and. abs(wy) < 0.5_real64
   if (.not. ok) write(output_unit, '(A,3G14.6)') 'cube_drag: azimuth before, after, window x ', az0, az, wx
   call park()
   endsubroutine cube_drag

   pure function pixel_size(d, fov) result(s)
   !< The world's size of a pixel at distance `d` from the eye, the view SIDE pixels tall with vertical field `fov`.
   real(real64), intent(in) :: d   !< Distance.
   real(real64), intent(in) :: fov !< Field of view [degrees].
   real(real64)             :: s   !< Size [world units].

   s = 2.0_real64 * d * tan(0.5_real64 * fov * PI / 180.0_real64) / SIDE
   endfunction pixel_size

   subroutine translate(ok)
   !< The eye on -y looking at the origin: a drag of the x arrow by 40 pixels moves the matrix by 40 pixels' worth.
   logical, intent(out) :: ok      !< Outcome.
   real(real64)         :: d, fov  !< Camera.
   real(real64)         :: cx, cy  !< The gizmo's origin on screen.
   real(real64)         :: want    !< Expected motion.

   show_cube = .false.
   call v%set_camera(target=[0.0_real64, 0.0_real64, 0.0_real64], distance=8.0_real64, azimuth=-90.0_real64, &
                     elevation=0.0_real64)
   m = identity()
   mode = 'translate'
   moved = .false.
   call frames(2_int32)
   call v%get_camera(distance=d, fov=fov)
   cx = view0(1) + 0.5_real64 * SIDE
   cy = view0(2) + 0.5_real64 * SIDE
   call drag(cx + 50.0_real64, cy, cx + 90.0_real64, cy)
   want = 40.0_real64 * pixel_size(d, fov)
   ok = moved .and. abs(m(1, 4) - want) <= 1.0e-4_real64 * want .and. abs(m(2, 4)) < 1.0e-6_real64 .and. &
        abs(m(3, 4)) < 1.0e-6_real64 .and. all(abs(m(1:3, 1:3) - identity3()) < 1.0e-6_real64)
   if (.not. ok) write(output_unit, '(A,L2,4G16.8)') 'translate: moved, x, y, z, expected ', moved, m(1:3, 4), want
   call park()
   endsubroutine translate

   subroutine far_away(ok)
   !< The same drag as `translate`, everything 1e5 world units along x: the motion as exact (FIGURE hands ImGuizmo the
   !< world moved by the camera's target; in single precision 1e5 has a step of 0.0078).
   logical, intent(out) :: ok      !< Outcome.
   real(real64)         :: d, fov  !< Camera.
   real(real64)         :: cx, cy  !< The gizmo's origin on screen.
   real(real64)         :: want    !< Expected motion.
   real(real64), parameter :: X0 = 1.0e5_real64 !< The offset.

   call v%set_camera(target=[X0, 0.0_real64, 0.0_real64], distance=8.0_real64, azimuth=-90.0_real64, &
                     elevation=0.0_real64)
   m = identity()
   m(1, 4) = X0
   mode = 'translate'
   moved = .false.
   call frames(2_int32)
   call v%get_camera(distance=d, fov=fov)
   cx = view0(1) + 0.5_real64 * SIDE
   cy = view0(2) + 0.5_real64 * SIDE
   call drag(cx + 50.0_real64, cy, cx + 90.0_real64, cy)
   want = 40.0_real64 * pixel_size(d, fov)
   ok = moved .and. abs(m(1, 4) - X0 - want) <= 1.0e-4_real64 * want
   if (.not. ok) write(output_unit, '(A,L2,2G18.10)') 'far_away: moved, motion, expected ', moved, m(1, 4) - X0, want
   call v%set_camera(target=[0.0_real64, 0.0_real64, 0.0_real64], azimuth=-90.0_real64, elevation=0.0_real64)
   m = identity()
   call park()
   endsubroutine far_away

   pure function identity3() result(a)
   !< The 3x3 identity.
   real(real64) :: a(3, 3) !< Matrix.
   integer      :: i       !< Counter.

   a = 0.0_real64
   do i = 1, 3
      a(i, i) = 1.0_real64
   enddo
   endfunction identity3

   subroutine beside(ok)
   !< A drag on the view away from the gizmo orbits the camera and leaves the matrix alone.
   logical, intent(out) :: ok      !< Outcome.
   real(real64)         :: before(4, 4) !< The matrix before.
   real(real64)         :: az0, az !< Azimuth before and after.
   real(real64)         :: cx, cy  !< The view's centre.

   before = m
   moved = .false.
   call v%get_camera(azimuth=az0)
   cx = view0(1) + 0.5_real64 * SIDE
   cy = view0(2) + 0.5_real64 * SIDE
   call drag(cx - 120.0_real64, cy + 120.0_real64, cx - 80.0_real64, cy + 120.0_real64)
   call v%get_camera(azimuth=az)
   ok = .not. moved .and. all(m == before) .and. abs(az - az0) > 5.0_real64
   if (.not. ok) write(output_unit, '(A,L2,2G14.6)') 'beside: moved, azimuth before, after ', moved, az0, az
   call v%set_camera(azimuth=-90.0_real64, elevation=0.0_real64)
   call frames(2_int32)
   endsubroutine beside

   subroutine snapping(ok)
   !< With snap 0.5, a drag of about 0.9 world units moves the matrix by 1 (a whole number of steps).
   logical, intent(out) :: ok     !< Outcome.
   real(real64)         :: d, fov !< Camera.
   real(real64)         :: cx, cy !< The gizmo's origin on screen.
   real(real64)         :: px     !< Pixels for 0.9 world units.
   real(real64)         :: x0     !< The matrix's x before.

   call v%get_camera(distance=d, fov=fov)
   m = identity()
   snap = 0.5_real64
   moved = .false.
   call frames(2_int32)
   x0 = m(1, 4)
   cx = view0(1) + 0.5_real64 * SIDE
   cy = view0(2) + 0.5_real64 * SIDE
   px = 0.9_real64 / pixel_size(d, fov)
   call drag(cx + 50.0_real64, cy, cx + 50.0_real64 + px, cy)
   ok = moved .and. abs(m(1, 4) - x0 - 1.0_real64) < 1.0e-5_real64
   if (.not. ok) write(output_unit, '(A,L2,G16.8)') 'snapping: moved, x ', moved, m(1, 4)
   snap = 0.0_real64
   call park()
   endsubroutine snapping

   subroutine matrices(ok)
   !< The eye from the inverse of the view matrix; a world point through projection * view to its pixel in the view.
   logical, intent(out) :: ok         !< Outcome.
   real(real64)         :: vm(4, 4)   !< View.
   real(real64)         :: pm(4, 4)   !< Projection.
   real(real64)         :: t(3), d    !< Camera.
   real(real64)         :: az, el     !< ...
   real(real64)         :: eye(3)     !< The eye, from the view matrix.
   real(real64)         :: want(3)    !< ... from the camera.
   real(real64)         :: q(4)       !< A point in clip coordinates.

   call v%set_camera(target=[0.5_real64, -0.25_real64, 0.0_real64], azimuth=35.0_real64, elevation=20.0_real64)
   call frames(2_int32)
   call v%view_matrix(vm)
   call v%projection_matrix(pm)
   call v%get_camera(target=t, distance=d, azimuth=az, elevation=el)
   ! eye = -R^T t for the view matrix [R t]
   eye = -matmul(transpose(vm(1:3, 1:3)), vm(1:3, 4))
   az = az * PI / 180.0_real64
   el = el * PI / 180.0_real64
   want = t + d * [cos(el) * cos(az), cos(el) * sin(az), sin(el)]
   ok = all(abs(eye - want) < 1.0e-9_real64 * d) .and. abs(pm(4, 3) + 1.0_real64) < 1.0e-12_real64
   ! the target lands at the view's centre (clip x = y = 0)
   q = matmul(pm, matmul(vm, [t, 1.0_real64]))
   ok = ok .and. abs(q(1) / q(4)) < 1.0e-12_real64 .and. abs(q(2) / q(4)) < 1.0e-12_real64
   if (.not. ok) write(output_unit, '(A,6G14.6)') 'matrices: eye, expected ', eye, want
   call v%set_camera(target=[0.0_real64, 0.0_real64, 0.0_real64], azimuth=-90.0_real64, elevation=0.0_real64)
   call frames(2_int32)
   endsubroutine matrices

   subroutine gradient(ok)
   !< The green stop dragged 60 pixels right: its position, the map's colour at 0.5 in ImPlot and in the field.
   logical, intent(out)      :: ok(2)          !< Outcomes: stops and ImPlot's map; the field.
   real(real64), allocatable :: pos(:)         !< Stop positions.
   real(real64), allocatable :: rgb(:,:)       !< Stop colours.
   real(real64)              :: x, y, sw, sh   !< The stops' row.
   real(real64)              :: before(4)      !< The field's colour at 0.5 before.
   real(real64)              :: after(4)       !< ... after.
   real(real64)              :: p, wt          !< The green stop's new position, the weight of green at 0.5.
   type(im_vec4)             :: c              !< ImPlot's colour at 0.5.
   type(im_vec4)             :: cr             !< ... of the reversed map.
   integer(int32)            :: r_id           !< The reversed map's id.
   real(real64)              :: wx, wy, wx1, wy1 !< The window's rectangle.
   real(real64)              :: sw_before(3)   !< The 3-D swatch's colour before.
   real(real64)              :: sw_after(3)    !< ... after.

   mode = ''
   call frames(2_int32)
   call ip_colormap_stops('rgb3', pos, rgb)
   ok(1) = size(pos) == 3 .and. abs(pos(2) - 0.5_real64) < 1.0e-6_real64
   call swatch_colour(sw_before)
   call test_field_pixel('rgb', 2_int32, 1_int32, before)
   ok(2) = all(abs(before(1:3) - [0.0_real64, 1.0_real64, 0.0_real64]) < 1.0e-6_real64)
   ok(1) = ok(1) .and. test_item_rect('##points', x, y, sw, sh)
   r_id = ip_colormap('rgb3_r')                ! a variant registered before the edit follows it
   edited = .false.
   ! a stop at t is drawn centred at x + t (sw - sh) + sh / 2
   call drag(x + 0.5_real64 * (sw - sh) + 0.5_real64 * sh, y + 0.5_real64 * sh, &
             x + 0.5_real64 * (sw - sh) + 0.5_real64 * sh + 60.0_real64, y + 0.5_real64 * sh)
   call ip_colormap_stops('rgb3', pos, rgb)
   p = 0.5_real64 + 60.0_real64 / sw ! ImGradient moves a stop by the mouse's motion over the row's width
   ok(1) = ok(1) .and. edited .and. size(pos) == 3 .and. abs(pos(2) - p) < 2.0e-3_real64 .and. &
           all(abs(rgb(:, 2) - [0.0_real64, 1.0_real64, 0.0_real64]) < 1.0e-6_real64)
   wt = 0.5_real64 / pos(2) ! 0.5 between red at 0 and green at pos(2)
   call ImPlot_SampleColormap(0.5_c_float, int(ip_colormap('rgb3'), c_int), c)
   ok(1) = ok(1) .and. abs(c%y - wt) < 0.02_real64 .and. abs(c%x - (1.0_real64 - wt)) < 0.02_real64
   call ImPlot_SampleColormap(0.5_c_float, int(r_id, c_int), cr)
   ok(1) = ok(1) .and. abs(cr%x - c%x) < 0.02_real64 .and. abs(cr%y - c%y) < 0.02_real64
   call test_field_pixel('rgb', 2_int32, 1_int32, after)
   ok(2) = ok(2) .and. abs(after(2) - wt) < 0.02_real64 .and. abs(after(1) - (1.0_real64 - wt)) < 0.02_real64
   call test_window_rect('gizmos', wx, wy, wx1, wy1)
   ok(1) = ok(1) .and. abs(wx) < 0.5_real64 .and. abs(wy) < 0.5_real64 ! the press was the editor's, not the window's
   call swatch_colour(sw_after)                 ! the 3-D view coloured again
   ok(2) = ok(2) .and. abs(sw_before(2) - 1.0_real64) < 0.01_real64 .and. abs(sw_after(2) - wt) < 0.02_real64 .and. &
           abs(sw_after(1) - (1.0_real64 - wt)) < 0.02_real64
   if (.not. all(ok)) write(output_unit, '(A,L2,*(G12.4))') 'gradient: edited, stop, colour ', edited, pos, c%x, c%y, &
                                                            after
   call park()
   endsubroutine gradient

   subroutine swatch_colour(rgb)
   !< The colour at the centre of the swatch's last render, RGB in [0, 1].
   real(real64), intent(out)  :: rgb(3)      !< Colour.
   integer(int8), allocatable :: px(:,:,:)   !< Pixels.

   rgb = -1.0_real64
   call swatch%image(px)
   if (.not. allocated(px)) return
   rgb = real(iand(int(px(1:3, size(px, 2) / 2 + 1, size(px, 3) / 2 + 1), int32), 255_int32), real64) / 255.0_real64
   endsubroutine swatch_colour

   subroutine gradient_add(ok)
   !< A double click on the stops' row adds a stop there.
   logical, intent(out)      :: ok           !< Outcome.
   real(real64), allocatable :: pos(:)       !< Stop positions.
   real(real64), allocatable :: rgb(:,:)     !< Stop colours.
   real(real64)              :: x, y, sw, sh !< The stops' row.
   real(real64)              :: px           !< Where.
   integer(int32)            :: k            !< Counter.

   ok = test_item_rect('##points', x, y, sw, sh)
   px = x + 0.85_real64 * sw
   call test_mouse_move(px, y + 0.5_real64 * sh)
   call test_next_frame()
   call test_next_frame()
   do k = 1_int32, 2_int32
      call test_mouse_button(.true.)
      call test_next_frame()
      call test_mouse_button(.false.)
      call test_next_frame()
   enddo
   call frames(8_int32)
   call ip_colormap_stops('rgb3', pos, rgb)
   ok = ok .and. size(pos) == 4
   if (.not. ok) write(output_unit, '(A,*(G12.4))') 'gradient_add: stops ', pos
   call park()
   endsubroutine gradient_add

   subroutine grazing(ok)
   !< The x arrow seen at phi = 30, 20, 12 degrees from the line of sight, pointing toward the eye, dragged 5 pixels
   !< along itself: the matrix moves along +x (not back: the handle is nearer the eye than the meshes' centre), by
   !< 5 pixels' worth at the target over sin(phi), less the perspective's gain as the point comes nearer (within 20%).
   !< The ratios are printed (known-issues.md, "Gizmos").
   logical, intent(out) :: ok !< Outcome.
   real(real64)   :: phi(3) = [30.0_real64, 20.0_real64, 12.0_real64] !< Angles [degrees].
   real(real64)   :: d, fov, len, cx, cy, grab !< Camera, the arrow's length on the screen, the origin, the grab.
   real(real64)   :: r !< Motion over 5 pixels' worth, times sin(phi).
   integer(int32) :: k !< Counter.

   show_cube = .false.
   mode = 'translate'
   do k = 1_int32, 3_int32
      call v%set_camera(target=[0.0_real64, 0.0_real64, 0.0_real64], distance=8.0_real64, azimuth=phi(k), &
                        elevation=0.0_real64)
      m = identity()
      call frames(2_int32)
      call v%get_camera(distance=d, fov=fov)
      len = 80.0_real64 * sin(phi(k) * PI / 180.0_real64) ! the arrow points to the left, foreshortened
      cx = view0(1) + 0.5_real64 * SIDE
      cy = view0(2) + 0.5_real64 * SIDE
      grab = max(0.6_real64 * len, 12.0_real64)          ! outside the centre's 10-pixel square
      call drag(cx - grab, cy, cx - grab - 5.0_real64, cy)
      r = m(1, 4) / (5.0_real64 * pixel_size(d, fov)) * sin(phi(k) * PI / 180.0_real64)
      write(output_unit, '(A,F5.1,A,F7.3,A,F7.3)') 'grazing: phi ', phi(k), ', motion / 5 pixels at the target ', &
         m(1, 4) / (5.0_real64 * pixel_size(d, fov)), ', 1 / sin(phi) ', 1.0_real64 / sin(phi(k) * PI / 180.0_real64)
      if (k == 1_int32) ok = .true.
      ok = ok .and. r > 0.8_real64 .and. r <= 1.0_real64 .and. all(m(2:3, 4) == 0.0_real64)
      call park()
   enddo
   mode = ''
   show_cube = .true.
   endsubroutine grazing

   subroutine picture(ok)
   !< The window, its view with the cube and a gizmo, the gradient editor: against the golden.
   logical, intent(out) :: ok !< Outcome.

   show_cube = .true.
   mode = 'translate'
   m = identity()
   call v%set_camera(target=[0.0_real64, 0.0_real64, 0.0_real64], distance=8.0_real64, azimuth=-60.0_real64, &
                     elevation=25.0_real64)
   call frames(3_int32)
   if (app%next_frame()) then
      call ig_set_next_window(x=0.0_real64, y=0.0_real64, width=real(W, real64), height=real(H, real64))
      if (ig_begin('gizmos', flags=ImGuiWindowFlags_NoDecoration)) then
         call v%draw('view', SIDE, SIDE)
         call v%view_cube()
         if (v%gizmo('plane', m, mode='translate')) continue
         if (ig_gradient_edit('gradient', 'rgb3', width=SIDE)) continue
      endif
      call ig_end()
      call test_capture(SHOT)
   endif
   call frames(1_int32)
   ok = test_compare_image(SHOT, GOLDEN)
   mode = ''
   endsubroutine picture

   subroutine statuses(ok)
   !< The refusals.
   logical, intent(out) :: ok       !< Outcome.
   integer(int32)       :: s(7)     !< Statuses.
   real(real64)         :: bad(4, 4) !< A matrix with a bad last row.
   logical              :: r        !< A result.

   s = FIG_OK
   bad = identity()
   bad(4, 1) = 1.0_real64
   if (app%next_frame()) then
      if (ig_begin('statuses')) then
         call v%view_cube(stat=s(1))                              ! the view not drawn in this window
         r = v%gizmo('g', m, stat=s(2))
         call v%draw('view', 100.0_real64, 100.0_real64)
         call v%view_cube(corner='middle', stat=s(3))
         r = v%gizmo('g', m, mode='shear', stat=s(4))
         r = v%gizmo('g', bad, stat=s(5))
         r = ig_gradient_edit('q', 'Deep', stat=s(6))             ! qualitative
         r = ig_gradient_edit('r', 'rgb3_r', stat=s(7))           ! reversed
      endif
      call ig_end()
   endif
   call frames(1_int32)
   ok = early == FIG_ERR_STATE .and. s(1) == FIG_ERR_STATE .and. s(2) == FIG_ERR_STATE .and. &
        all(s(3:7) == FIG_ERR_ARGUMENT) .and. all(bad(4, :) == [1.0_real64, 0.0_real64, 0.0_real64, 1.0_real64])
   if (.not. ok) write(output_unit, '(A,*(I4))') 'statuses: ', early, s
   endsubroutine statuses

   subroutine remove_files()
   !< The temporary files.
   integer(int32) :: u, ios !< Unit, status.
   character(len=*), parameter :: FILES(2) = [character(len=40) :: SHOT, CSV] !< Files.
   integer(int32) :: k !< Counter.

   do k = 1_int32, size(FILES, kind=int32)
      open(newunit=u, file=trim(FILES(k)), status='old', iostat=ios)
      if (ios == 0) close(u, status='delete')
   enddo
   endsubroutine remove_files
endprogram figure_test_gizmo
