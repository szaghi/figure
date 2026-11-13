!< figure_test_view3d, the 3-D view (view3d_object) checked pixel by pixel, headless.
program figure_test_view3d
!< figure_test_view3d, the 3-D view (view3d_object) checked pixel by pixel, headless.
!<
!< Six views, each 240x240 pixels in its own window, without lighting where colours are compared:
!< - a cube seen from +z: its silhouette is the projected top face (the edges within 2 pixels of the perspective's
!<   prediction); clipped by the plane x >= 0, the half x < 0 is background; with the eye inside it, every pixel is
!<   cube (the near plane clipped, nothing dropped);
!< - two layers: the nearer one is seen from +z, the other from -z (depth order);
!< - a structured surface coloured per cell (cividis): the first and last cells have the map's end colours; picking
!<   the centre of every cell gives that cell and its centre point; a synthetic click gives the clicked cell, a
!<   synthetic hover the hovered one;
!< - a lit wavy surface rendered with 1 and with 4 threads: the same pixels;
!< - lines over a surface with edges: the line and the edges in their colours, the cells in theirs;
!< - the camera: set and read back, orbits, pans and zooms undone, the standard views, a drag (rendered at half
!<   resolution while it moves, at full size when it ends) and the wheel; no render when nothing changed;
!< - the wheel inside a scrolling child: over the view it zooms the view and does not scroll the child; beside the view
!<   it scrolls the child and does not zoom.
!< Then the refusals with their statuses, the mesh ids (each the next one, none given back by remove or clear), and
!< the time of a 3.2e5-triangle render (printed, not checked).
use, intrinsic :: iso_c_binding, only : c_float, c_int
use, intrinsic :: iso_fortran_env, only : int8, int32, int64, real64, output_unit
use figure, only : app_object, ig_begin, ig_end, ig_item_rect, ig_set_next_window, ip_colormap, view3d_object, &
                   ImGuiWindowFlags_NoDecoration, FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_OK
use figure, only : ig_begin_child, ig_end_child
use figure_cimgui, only : im_vec4
use figure_cimgui, only : igDummy, igGetScrollY, im_vec2
use figure_cimplot, only : ImPlot_SampleColormap
use figure_testing, only : test_mouse_button, test_mouse_move, test_wheel

implicit none
integer(int32), parameter :: N = 240_int32                !< Views' size [pixels].
integer(int32), parameter :: NV = 6_int32                 !< Views.
character(len=6), parameter :: NAMES(NV) = ['cube  ', 'layers', 'pick  ', 'lit1  ', 'lit4  ', 'lines '] !< Windows.
real(real64), parameter   :: PI = acos(-1.0_real64)       !< Pi.
type(app_object)          :: app                          !< Application.
type(view3d_object)       :: v(NV)                        !< The views.
real(real64)              :: origin(2, NV)                !< Each view's top-left on the display [pixels].
logical                   :: test_passed(17)              !< Per-check outcome.
! the data, kept by address: target
real(real64), target      :: cube_xyz(3, 8)               !< Cube's vertices.
integer(int32), target    :: cube_quads(4, 6)             !< Cube's faces.
real(real64), target      :: layer_xyz(3, 4, 2)           !< Two squares.
integer(int32), target    :: layer_quad(4, 1, 2)          !< One quad each.
real(real64), target      :: grid_xyz(3, 4, 3)            !< A 4x3 node plane z = 0 over [0, 3] x [0, 2].
real(real64), target      :: grid_cells(3, 2)             !< Its cell scalar.
real(real64), target      :: wave_xyz(3, 40, 30)          !< A wavy surface.
real(real64), target      :: wave_s(40, 30)               !< Its height, as scalar.
real(real64), target      :: line_xyz(3, 2)               !< A line along x.
real(real64), target      :: plane_xyz(3, 3, 3)           !< A plane under it, with edges.
real(real64), target      :: big_xyz(3, 400, 401)         !< A sphere (perf).
real(real64), target      :: big_s(400, 401)              !< Its scalar.
integer(int32)            :: i, j, k, m, s                !< Counters, mesh, status.
integer(int8), allocatable :: img(:,:,:), img4(:,:,:)     !< Pixels.

call build_data()
! before init: no view
s = FIG_OK
call v(1)%draw('none', stat=s)
test_passed(14) = s == FIG_ERR_STATE
call app%init_headless(800_int32, 600_int32)
call v(1)%init(lighting=.false., background=[0.0_real64, 0.0_real64, 0.0_real64])
m = v(1)%quads(cube_xyz, cube_quads, color=[1.0_real64, 0.0_real64, 0.0_real64])
call v(2)%init(lighting=.false., background=[0.0_real64, 0.0_real64, 0.0_real64])
m = v(2)%quads(layer_xyz(:,:,1), layer_quad(:,:,1), color=[1.0_real64, 0.0_real64, 0.0_real64])
m = v(2)%quads(layer_xyz(:,:,2), layer_quad(:,:,2), color=[0.0_real64, 1.0_real64, 0.0_real64])
call v(3)%init(lighting=.false., background=[0.0_real64, 0.0_real64, 0.0_real64])
m = v(3)%surface(grid_xyz, cell_scalar=grid_cells, colormap='cividis')
call v(4)%init(threads=1_int32, background=[0.1_real64, 0.1_real64, 0.1_real64])
m = v(4)%surface(wave_xyz, scalar=wave_s, colormap='turbo', edges=.true.)
call v(5)%init(threads=4_int32, background=[0.1_real64, 0.1_real64, 0.1_real64])
m = v(5)%surface(wave_xyz, scalar=wave_s, colormap='turbo', edges=.true.)
call v(6)%init(lighting=.false., background=[0.0_real64, 0.0_real64, 0.0_real64])
m = v(6)%surface(plane_xyz, color=[0.0_real64, 0.0_real64, 1.0_real64], edges=.true.)
call v(6)%set_mesh(m, edge_color=[1.0_real64, 0.0_real64, 0.0_real64])
m = v(6)%lines(line_xyz, color=[0.0_real64, 1.0_real64, 0.0_real64])
do k = 1_int32, 6_int32, 5_int32
   call v(k)%view('+z')
enddo
call v(3)%view('+z')
call frame()
call frame()

test_passed(1) = check_cube()
test_passed(2) = check_clip()
test_passed(3) = check_inside()
test_passed(4) = check_layers()
test_passed(5) = check_colours()
test_passed(6) = check_picks()
test_passed(7) = check_threads()
test_passed(8) = check_lines()
test_passed(9) = check_camera()
test_passed(10) = check_drag()
test_passed(11) = check_mouse_picks()
test_passed(12) = check_cache()
test_passed(13) = check_refusals()
test_passed(17) = check_ids()
call check_wheel_in_child(test_passed(15:16))
call perf_log()

write(output_unit, '(A,*(L2))') 'figure_test_view3d checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
do k = 1_int32, NV
   call v(k)%destroy()
enddo
call app%destroy()
if (.not. all(test_passed)) error stop 1

contains
   subroutine build_data()
   !< The meshes' arrays.
   real(real64) :: x, y, th, ph !< Coordinates.

   cube_xyz = reshape([-1, -1, -1,  1, -1, -1,  1, 1, -1,  -1, 1, -1, &
                       -1, -1,  1,  1, -1,  1,  1, 1,  1,  -1, 1,  1], [3, 8]) * 1.0_real64
   cube_quads = reshape([1, 2, 3, 4,  5, 6, 7, 8,  1, 2, 6, 5,  2, 3, 7, 6,  3, 4, 8, 7,  4, 1, 5, 8], [4, 6])
   do k = 1_int32, 2_int32
      layer_xyz(1, :, k) = [-1.0_real64, 1.0_real64, 1.0_real64, -1.0_real64]
      layer_xyz(2, :, k) = [-1.0_real64, -1.0_real64, 1.0_real64, 1.0_real64]
      layer_xyz(3, :, k) = 0.5_real64 * (k - 1) ! red at z = 0, green at z = 0.5
      layer_quad(:, 1, k) = [1, 2, 3, 4]
   enddo
   do j = 1_int32, 3_int32
      do i = 1_int32, 4_int32
         grid_xyz(:, i, j) = [real(i - 1, real64), real(j - 1, real64), 0.0_real64]
      enddo
   enddo
   grid_cells = reshape([0.0_real64, 0.3_real64, 0.5_real64, 0.2_real64, 0.8_real64, 1.0_real64], [3, 2])
   do j = 1_int32, 30_int32
      do i = 1_int32, 40_int32
         x = -2.0_real64 + 4.0_real64 * (i - 1) / 39.0_real64
         y = -1.5_real64 + 3.0_real64 * (j - 1) / 29.0_real64
         wave_xyz(:, i, j) = [x, y, 0.4_real64 * sin(2.0_real64 * x) * cos(1.5_real64 * y)]
         wave_s(i, j) = wave_xyz(3, i, j)
      enddo
   enddo
   line_xyz = reshape([-1.0_real64, 0.0_real64, 0.0_real64, 1.0_real64, 0.0_real64, 0.0_real64], [3, 2])
   do j = 1_int32, 3_int32
      do i = 1_int32, 3_int32
         plane_xyz(:, i, j) = [real(i - 2, real64), real(j - 2, real64), -0.5_real64]
      enddo
   enddo
   do j = 1_int32, 401_int32
      do i = 1_int32, 400_int32
         th = 2.0_real64 * PI * (i - 1) / 399.0_real64
         ph = PI * (j - 1) / 400.0_real64
         big_xyz(:, i, j) = [sin(ph) * cos(th), sin(ph) * sin(th), cos(ph)]
         big_s(i, j) = cos(3.0_real64 * th) * sin(ph)
      enddo
   enddo
   endsubroutine build_data

   subroutine frame()
   !< One frame drawing every view in its window.
   integer(int32) :: q    !< View.
   real(real64)   :: x1, y1 !< Item's corner.

   if (.not. app%next_frame()) error stop 'figure_test_view3d: next_frame returned false'
   do q = 1_int32, NV
      call ig_set_next_window(260.0_real64 * mod(q - 1, 3), 280.0_real64 * ((q - 1) / 3), 260.0_real64, 270.0_real64, &
                              always=.true.)
      if (ig_begin(trim(NAMES(q)), flags=ImGuiWindowFlags_NoDecoration)) then
         call v(q)%draw('view', real(N, real64), real(N, real64))
         call ig_item_rect(origin(1, q), origin(2, q), x1, y1)
      endif
      call ig_end()
   enddo
   endsubroutine frame

   function px(q, x, y) result(c)
   !< The colour of pixel (x, y) (from 0, top-left) of view q's last render, 0-255.
   integer(int32), intent(in) :: q, x, y !< View, pixel.
   integer(int32)             :: c(3)    !< RGB.

   call v(q)%image(img)
   c = int(iand(int(img(1:3, x + 1, y + 1), int32), 255_int32), int32)
   endfunction px

   function near(c, ref, tol) result(yes)
   !< Each channel within tol.
   integer(int32), intent(in) :: c(3), ref(3), tol !< Colours, tolerance.
   logical                    :: yes               !< Close.

   yes = all(abs(c - ref) <= tol)
   endfunction near

   real(real64) function top_half_width()
   !< The cube's top face half width [pixels] seen from +z, fitted: the distance R / sin(15 deg), R = sqrt(3).
   real(real64) :: d !< Eye to the top face.

   d = sqrt(3.0_real64) / sin(PI / 12.0_real64) - 1.0_real64
   top_half_width = 0.5_real64 * N / (d * tan(PI / 12.0_real64))
   endfunction top_half_width

   logical function check_cube()
   !< The silhouette: inside 2 pixels within the predicted edge red, 2 pixels outside black, on the four sides.
   integer(int32) :: c, hin, hout !< Centre, offsets.
   integer(int32), parameter :: RED(3) = [255, 0, 0], BLACK(3) = [0, 0, 0]

   c = N / 2_int32
   hin = int(top_half_width()) - 2_int32
   hout = int(top_half_width()) + 2_int32
   check_cube = near(px(1, c, c), RED, 0) .and. near(px(1, c + hin, c), RED, 0) .and.            &
                near(px(1, c - hin - 1, c), RED, 0) .and. near(px(1, c, c + hin), RED, 0) .and.   &
                near(px(1, c, c - hin - 1), RED, 0) .and. near(px(1, c + hout, c), BLACK, 0) .and. &
                near(px(1, c - hout - 1, c), BLACK, 0) .and. near(px(1, c, c + hout), BLACK, 0) .and. &
                near(px(1, c, c - hout - 1), BLACK, 0)
   if (.not. check_cube) write(output_unit, '(A,F8.2,4(1X,3I4))') 'cube: half width', top_half_width(), &
      px(1, c + hin, c), px(1, c + hout, c), px(1, c, c + hin), px(1, c, c + hout)
   endfunction check_cube

   logical function check_clip()
   !< Clipped by x >= 0 (x right in the +z view): the left half background, the right half cube; then unclipped.
   integer(int32) :: c !< Centre.

   c = N / 2_int32
   call v(1)%clip([1.0_real64, 0.0_real64, 0.0_real64], [0.0_real64, 0.0_real64, 0.0_real64])
   call frame()
   check_clip = near(px(1, c - 30, c), [0, 0, 0], 0) .and. near(px(1, c + 30, c), [255, 0, 0], 0) .and. &
                near(px(1, c - 30, c + 50), [0, 0, 0], 0) .and. near(px(1, c + 30, c - 50), [255, 0, 0], 0)
   call v(1)%unclip()
   call frame()
   check_clip = check_clip .and. near(px(1, c - 30, c), [255, 0, 0], 0)
   endfunction check_clip

   logical function check_inside()
   !< The eye inside the cube: every pixel is a face (the triangles crossing the near plane are clipped, not dropped).
   real(real64) :: d !< Distance kept.

   call v(1)%get_camera(distance=d)
   call v(1)%set_camera(distance=0.3_real64, fov=120.0_real64) ! the side faces cross the near plane
   call frame()
   call v(1)%image(img)
   check_inside = all(img(1, :, :) == -1_int8) .and. all(img(2:3, :, :) == 0_int8)
   if (.not. check_inside) write(output_unit, '(A,I0,A,2I4)') 'inside: pixels not red ', &
      count(img(1, :, :) /= -1_int8 .or. img(2, :, :) /= 0_int8), ' of a render ', shape(img(1, :, :))
   call v(1)%set_camera(distance=d, fov=30.0_real64)
   call frame()
   endfunction check_inside

   logical function check_layers()
   !< The green layer (z = 0.5) is seen from +z, the red one (z = 0) from -z.
   integer(int32) :: c !< Centre.

   c = N / 2_int32
   call v(2)%view('+z')
   call frame()
   check_layers = near(px(2, c, c), [0, 255, 0], 0)
   call v(2)%view('-z')
   call frame()
   check_layers = check_layers .and. near(px(2, c, c), [255, 0, 0], 0)
   if (.not. check_layers) write(output_unit, '(A,3I4)') 'layers: from -z', px(2, c, c)
   endfunction check_layers

   subroutine cell_pixel(i, j, x, y)
   !< The pixel at the centre of grid cell (i, j) in view 3 (+z, fitted to the 3 x 2 plane).
   integer(int32), intent(in)  :: i, j !< Cell.
   integer(int32), intent(out) :: x, y !< Pixel.
   real(real64)                :: r, d, scale !< Bounding radius, distance, pixels per unit.

   r = sqrt(1.5_real64**2 + 1.0_real64**2)
   d = r / sin(PI / 12.0_real64)
   scale = 0.5_real64 * N / (d * tan(PI / 12.0_real64))
   x = int(0.5_real64 * N + (i - 0.5_real64 - 1.5_real64) * scale)
   y = int(0.5_real64 * N - (j - 0.5_real64 - 1.0_real64) * scale)
   endsubroutine cell_pixel

   logical function check_colours()
   !< Cells coloured by cividis at their scalar: 0 and 1 give the map's ends, 0.5 its middle (one unit of 8 bits).
   integer(int32) :: x, y, id !< Pixel, map.
   type(im_vec4)  :: c        !< Sampled colour.
   integer(int32) :: ref(3)   !< Expected.

   id = ip_colormap('cividis')
   check_colours = .true.
   do k = 1_int32, 3_int32
      select case (k)
      case (1); i = 1; j = 1
      case (2); i = 3; j = 2
      case (3); i = 3; j = 1
      endselect
      call ImPlot_SampleColormap(real(grid_cells(i, j), c_float), int(id, c_int), c)
      ref = nint([c%x, c%y, c%z] * 255.0_real64)
      call cell_pixel(i, j, x, y)
      check_colours = check_colours .and. near(px(3, x, y), ref, 1)
      if (.not. near(px(3, x, y), ref, 1)) write(output_unit, '(A,2I3,2(1X,3I4))') 'colour of cell', i, j, &
         px(3, x, y), ref
   enddo
   endfunction check_colours

   logical function check_picks()
   !< Every cell picked at its centre: the surface, the cell's number, the point at the cell's centre.
   integer(int32) :: x, y, mesh !< Pixel, mesh.
   integer(int64) :: e          !< Element.
   real(real64)   :: p(3)       !< Point.
   logical        :: hit        !< Hit.

   check_picks = .true.
   do j = 1_int32, 2_int32
      do i = 1_int32, 3_int32
         call cell_pixel(i, j, x, y)
         hit = v(3)%pick(x + 0.5_real64, y + 0.5_real64, mesh, e, p)
         check_picks = check_picks .and. hit .and. mesh == 1_int32 .and. e == int(i + (j - 1) * 3, int64) .and. &
                       all(abs(p - [i - 0.5_real64, j - 0.5_real64, 0.0_real64]) < 0.03_real64)
      enddo
   enddo
   hit = v(3)%pick(2.0_real64, 2.0_real64, mesh, e) ! a corner: background
   check_picks = check_picks .and. .not. hit .and. mesh == 0_int32 .and. e == 0_int64
   endfunction check_picks

   logical function check_threads()
   !< The same lit surface rendered by 1 and by 4 threads: identical pixels.
   call v(4)%image(img)
   call v(5)%image(img4)
   check_threads = allocated(img) .and. allocated(img4)
   if (check_threads) check_threads = all(shape(img) == [4, N, N]) .and. all(img == img4) .and. &
                                      count(img(1, :, :) /= img(1, 1, 1)) > N * N / 10
   endfunction check_threads

   logical function check_lines()
   !< The green line along y = 0 in front of the blue plane; the red edge x = 0 elsewhere; blue inside a cell.
   integer(int32) :: c, q !< Centre, offset.
   logical        :: green, red !< Found.

   c = N / 2_int32
   green = .false.
   red = .false.
   do q = -1_int32, 1_int32
      green = green .or. near(px(6, c + 40, c + q), [0, 255, 0], 0)
      red = red .or. near(px(6, c + q, c - 40), [255, 0, 0], 0)
   enddo
   check_lines = green .and. red .and. near(px(6, c + 30, c - 30), [0, 0, 255], 0)
   endfunction check_lines

   logical function check_camera()
   !< Set and read back; orbits, pans and zooms undone; standard views.
   real(real64) :: t(3), d, a, e, f, t2(3), d2, a2, e2 !< Camera.
   logical      :: ok !< Partial.

   call v(2)%set_camera([0.5_real64, -0.25_real64, 0.1_real64], 7.5_real64, 33.0_real64, 21.0_real64, 40.0_real64)
   call v(2)%get_camera(t, d, a, e, f)
   ok = all(abs(t - [0.5_real64, -0.25_real64, 0.1_real64]) < 1.0e-12_real64) .and. abs(d - 7.5_real64) < 1.0e-12_real64 &
        .and. abs(a - 33.0_real64) < 1.0e-12_real64 .and. abs(e - 21.0_real64) < 1.0e-12_real64 .and. &
        abs(f - 40.0_real64) < 1.0e-12_real64
   call v(2)%orbit(30.0_real64, 10.0_real64)
   call v(2)%pan(1.0_real64, 2.0_real64)
   call v(2)%zoom(2.0_real64)
   call v(2)%get_camera(t2, d2, a2, e2)
   ok = ok .and. abs(a2 - 63.0_real64) < 1.0e-9_real64 .and. abs(e2 - 31.0_real64) < 1.0e-9_real64 .and. &
        abs(d2 - 3.75_real64) < 1.0e-12_real64 .and. abs(norm2(t2 - t) - sqrt(5.0_real64)) < 1.0e-9_real64
   call v(2)%zoom(0.5_real64)
   call v(2)%pan(-1.0_real64, -2.0_real64)
   call v(2)%orbit(-30.0_real64, -10.0_real64)
   call v(2)%get_camera(t2, d2, a2, e2)
   ok = ok .and. all(abs(t2 - t) < 1.0e-9_real64) .and. abs(d2 - d) < 1.0e-12_real64 .and. &
        abs(a2 - a) < 1.0e-9_real64 .and. abs(e2 - e) < 1.0e-9_real64
   call v(2)%orbit(0.0_real64, 80.0_real64) ! elevation kept at 90
   call v(2)%get_camera(elevation=e2)
   ok = ok .and. abs(e2 - 90.0_real64) < 1.0e-12_real64
   call v(2)%view('+x')
   call v(2)%get_camera(t2, d2, a2, e2)
   ok = ok .and. abs(a2) < 1.0e-12_real64 .and. abs(e2) < 1.0e-12_real64 .and. all(abs(t2 - [0.0_real64, 0.0_real64, &
        0.25_real64]) < 1.0e-12_real64)
   call v(2)%view('-y')
   call v(2)%get_camera(azimuth=a2, elevation=e2)
   ok = ok .and. abs(a2 + 90.0_real64) < 1.0e-12_real64 .and. abs(e2) < 1.0e-12_real64
   call v(2)%view('-z')
   call v(2)%get_camera(elevation=e2)
   check_camera = ok .and. abs(e2 + 90.0_real64) < 1.0e-12_real64
   if (.not. check_camera) write(output_unit, '(A,L2,10F10.4)') 'camera', ok, t2, d2, a2, e2
   endfunction check_camera

   subroutine scroll_frame(view, rect, scroll)
   !< One frame of a window holding a scrolling child: the view at its top, then 800 pixels of empty content.
   type(view3d_object), intent(inout) :: view    !< The view.
   real(real64),        intent(out)   :: rect(4) !< The view's rectangle [pixels].
   real(real64),        intent(out)   :: scroll  !< The child's vertical scroll [pixels].

   if (.not. app%next_frame()) error stop 'figure_test_view3d: next_frame returned false'
   call ig_set_next_window(0.0_real64, 0.0_real64, 400.0_real64, 400.0_real64, always=.true.)
   if (ig_begin('scroller', flags=ImGuiWindowFlags_NoDecoration)) then
      if (ig_begin_child('child', 380.0_real64, 300.0_real64)) then
         call view%draw('view', real(N, real64), real(N, real64))
         call ig_item_rect(rect(1), rect(2), rect(3), rect(4))
         call igDummy(im_vec2(10.0_c_float, 800.0_c_float))
         scroll = real(igGetScrollY(), real64)
      endif
      call ig_end_child()
   endif
   call ig_end()
   endsubroutine scroll_frame

   subroutine check_wheel_in_child(passed)
   !< A view inside a child taller than its window: the wheel over the view zooms it, the child does not scroll; the
   !< wheel over the child beside the view scrolls the child, the view does not zoom.
   logical, intent(out) :: passed(2)          !< Over the view; beside it.
   type(view3d_object)  :: view               !< The view.
   real(real64)         :: rect(4)            !< Its rectangle.
   real(real64)         :: s0, s1, s2         !< The child's scroll.
   real(real64)         :: d0, d1, d2         !< The camera's distance.
   integer(int32)       :: q                  !< Frame.

   call view%init(lighting=.false.)
   q = view%quads(cube_xyz, cube_quads, color=[1.0_real64, 0.0_real64, 0.0_real64])
   do q = 1_int32, 3_int32
      call scroll_frame(view, rect, s0)
   enddo
   call test_mouse_move(0.5_real64 * (rect(1) + rect(3)), 0.5_real64 * (rect(2) + rect(4))) ! over the view
   call scroll_frame(view, rect, s0)
   call scroll_frame(view, rect, s0)
   call view%get_camera(distance=d0)
   call test_wheel(-2.0_real64)                                                              ! towards the user
   call scroll_frame(view, rect, s1)
   call scroll_frame(view, rect, s1)
   call view%get_camera(distance=d1)
   passed(1) = abs(d1 - d0 * 1.1_real64**2) < 1.0e-9_real64 * d0 .and. s1 == s0
   call test_mouse_move(0.5_real64 * (rect(1) + rect(3)), rect(4) + 30.0_real64)              ! beside the view
   call scroll_frame(view, rect, s1)
   call test_wheel(-2.0_real64)
   call scroll_frame(view, rect, s2)
   call scroll_frame(view, rect, s2)
   call view%get_camera(distance=d2)
   passed(2) = s2 > s1 .and. d2 == d1
   if (.not. all(passed)) write(output_unit, '(A,3F10.4,A,3F8.1,A,4F8.1)') 'wheel in a child: distance', d0, d1, d2, &
                                                                         ', scroll', s0, s1, s2, ', view', rect
   call view%destroy()
   endsubroutine check_wheel_in_child

   logical function check_drag()
   !< A left drag of 50 pixels right and 25 down turns the camera by -20 and +10 degrees, at half resolution while it
   !< moves and at full size after; the wheel divides the distance by 1.1 per step.
   real(real64)   :: a0, e0, d0, a1, e1, d1 !< Camera before, after.
   integer(int32) :: w, h, w2                !< Render sizes.
   logical        :: half, half2             !< Half resolution.
   real(real64)   :: x0, y0                  !< Start.

   call v(2)%set_camera(azimuth=10.0_real64, elevation=20.0_real64)
   call frame()
   call v(2)%get_camera(azimuth=a0, elevation=e0, distance=d0)
   x0 = origin(1, 2) + 100.0_real64
   y0 = origin(2, 2) + 100.0_real64
   call test_mouse_move(x0, y0)
   call frame()
   call frame()
   call test_mouse_button(.true.)
   call frame()
   call test_mouse_move(x0 + 50.0_real64, y0 + 25.0_real64)
   call frame()
   call v(2)%render_info(width=w, height=h, half=half)
   call test_mouse_button(.false.)
   call frame()
   call frame()
   call v(2)%render_info(width=w2, half=half2)
   call v(2)%get_camera(azimuth=a1, elevation=e1)
   check_drag = half .and. w == N / 2 .and. h == N / 2 .and. .not. half2 .and. w2 == N .and. &
                abs(a1 - (a0 - 20.0_real64)) < 1.0e-6_real64 .and. abs(e1 - (e0 + 10.0_real64)) < 1.0e-6_real64
   if (.not. check_drag) write(output_unit, '(A,2I4,L2,I4,L2,4F9.3)') 'drag', w, h, half, w2, half2, a0, a1, e0, e1
   call test_wheel(2.0_real64)
   call frame()
   call frame()
   call v(2)%get_camera(distance=d1)
   check_drag = check_drag .and. abs(d1 - d0 / 1.1_real64**2) < 1.0e-9_real64 * d0
   endfunction check_drag

   logical function check_mouse_picks()
   !< The mouse over cell (2, 1): hovered; a click there: clicked, for one frame.
   integer(int32) :: x, y, mesh, mesh2, mesh3 !< Pixel, meshes.
   integer(int64) :: e, e2, e3         !< Elements.
   logical        :: h, c, c2          !< Hovered, clicked.

   call cell_pixel(2_int32, 1_int32, x, y)
   call test_mouse_move(origin(1, 3) + x + 0.5_real64, origin(2, 3) + y + 0.5_real64)
   call frame()
   call frame()
   h = v(3)%hovered(mesh, e)
   call test_mouse_button(.true.)
   call frame()
   call test_mouse_button(.false.)
   call frame()
   c = v(3)%clicked(mesh2, e2)
   call frame()
   c2 = v(3)%clicked(mesh3, e3)
   check_mouse_picks = h .and. mesh == 1_int32 .and. e == 2_int64 .and. e2 == 2_int64 .and. c .and. mesh2 == 1_int32 .and. .not. c2
   if (.not. check_mouse_picks) write(output_unit, '(A,L2,I3,I4,L2,I3,I4,L2)') 'mouse picks', h, mesh, e, c, mesh2, e2, c2
   call test_mouse_move(790.0_real64, 590.0_real64) ! away
   call frame()
   endfunction check_mouse_picks

   logical function check_cache()
   !< Frames without a change render nothing; a change renders once.
   integer(int32) :: n0, n1, n2 !< Render counts.

   call v(4)%render_info(count=n0)
   call frame()
   call frame()
   call frame()
   call v(4)%render_info(count=n1)
   call v(4)%changed()
   call frame()
   call frame()
   call v(4)%render_info(count=n2)
   check_cache = n1 == n0 .and. n2 == n0 + 1_int32
   endfunction check_cache

   logical function check_refusals()
   !< Bad arguments refused with FIG_ERR_ARGUMENT, nothing added.
   integer(int32), target :: bad_tri(3, 1) !< An index out of range.
   integer(int32), target :: one_tri(3, 1) !< A valid triangle.
   integer(int32)         :: st(8)         !< Statuses.
   type(view3d_object)    :: w             !< A view.
   real(real64), target   :: short(3)      !< A scalar too short.

   bad_tri(:, 1) = [1, 2, 99]
   one_tri(:, 1) = [1, 2, 3]
   short = 0.0_real64
   m = v(6)%triangles(cube_xyz, bad_tri, stat=st(1))
   st(1) = merge(st(1), -1_int32, m == 0_int32)
   call v(6)%view('+w', stat=st(2))
   call w%init(threads=5_int32, stat=st(3))
   m = v(6)%triangles(cube_xyz, one_tri, scalar=short, stat=st(4))
   st(4) = merge(st(4), -1_int32, m == 0_int32)
   do k = 1_int32, 6_int32
      call v(6)%clip([0.0_real64, 0.0_real64, 1.0_real64], [0.0_real64, 0.0_real64, -10.0_real64])
   enddo
   call v(6)%clip([0.0_real64, 0.0_real64, 1.0_real64], [0.0_real64, 0.0_real64, -10.0_real64], stat=st(5))
   call v(6)%unclip()
   call v(6)%set_mesh(1_int32, vmin=0.0_real64, stat=st(6))
   call v(6)%set_mesh(1_int32, colormap='no-such-map', stat=st(7))
   call v(6)%remove(9_int32, stat=st(8))
   check_refusals = all(st == FIG_ERR_ARGUMENT)
   if (.not. check_refusals) write(output_unit, '(A,8I3)') 'refusals', st
   endfunction check_refusals

   logical function check_ids()
   !< Mesh ids go on: each mesh added gets the next one, from 1; `remove` and `clear` give none back.
   integer(int32), target :: one_tri(3, 1) !< A triangle.
   integer(int32)         :: ids(4)        !< Ids returned.
   type(view3d_object)    :: w             !< A view of its own.

   one_tri(:, 1) = [1, 2, 3]
   call w%init(threads=1_int32)
   ids(1) = w%triangles(cube_xyz, one_tri)
   ids(2) = w%triangles(cube_xyz, one_tri)
   call w%remove(ids(1))
   ids(3) = w%triangles(cube_xyz, one_tri)
   call w%clear()
   ids(4) = w%triangles(cube_xyz, one_tri)
   call w%destroy()
   check_ids = all(ids == [1_int32, 2_int32, 3_int32, 4_int32])
   if (.not. check_ids) write(output_unit, '(A,4I4)') 'ids', ids
   endfunction check_ids

   subroutine perf_log()
   !< A sphere of 3.2e5 triangles rendered at 240x240 with 1 and 4 threads: the times, printed.
   real(real64)   :: ms(2) !< Times.
   integer(int32) :: q     !< View.

   do q = 4_int32, 5_int32
      call v(q)%clear()
      m = v(q)%surface(big_xyz, scalar=big_s, colormap='cool-warm')
   enddo
   call frame()
   call v(4)%render_info(milliseconds=ms(1))
   call v(5)%render_info(milliseconds=ms(2))
   write(output_unit, '(A,F8.2,A,F8.2,A)') 'perf (log only): 3.2e5 triangles at 240x240: ', ms(1), ' ms (1 thread), ', &
      ms(2), ' ms (4 threads)'
   endsubroutine perf_log
endprogram figure_test_view3d
