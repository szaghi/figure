!< figure_test_plot_frame_3d_surfaces, the Fortran 3-D frame's triangles, quads, surfaces, meshes, images, texts, as ImPlot3D's.
program figure_test_plot_frame_3d_surfaces
!< figure_test_plot_frame_3d_surfaces, the Fortran 3-D frame's triangles, quads, surfaces, meshes, images, texts, as ImPlot3D's.
!<
!< szaghi/figure#15 P13, step 5. Each case is a 3-D plot drawn on a few frames first by ImPlot3D through FIGURE's API
!< (`ip3_*`), then by the Fortran frame (`pf3_*`, figure_plot3d_items), 40 frames apart. Checked on every frame, to
!< the bit: the corners' and two points' pixels (the ranges after the fit), the pointer's ray and whether it is over
!< the plot; the pictures of the first and last frames at FIGURE's oracle rule (|d| <= 2, no pixel failing). The cases:
!<
!< 1. triangles and quads crossing each other (the depth sort), their edges in a line colour, markers on the quads;
!< 2. a surface over a rectilinear grid (Viridis, the data's range), a surface over a polar grid (Plasma, a given
!<    scale, a fill alpha of 0.7, its grid lines), a flat surface (the widened range);
!< 3. a mesh (an octahedron) with a fill and a line colour, a mesh with the colormap's colour (no edges: automatic
!<    line colour), single precision;
!< 4. an image on the floor and one standing (a 4 x 4 texture, a tint), texts (an angle, an offset, one outside the
!<    box: not drawn), the first frame's fit to the images' corners.
!<
!< The pictures are `figure_test_plot_frame_3d_surfaces.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
!<
!< szaghi/figure#16 S2: every frame's draw data of the two sides are equal too (`figure_test_drawdata`: the
!< window's draw commands, vertices and indices, and each command's offsets and count): the batching, which
!< the pictures do not see.
use, intrinsic :: iso_fortran_env, only : int8, int32, int64, real32, real64, output_unit
use, intrinsic :: ieee_arithmetic, only : ieee_quiet_nan, ieee_value
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, texture_object, &
                   ImGuiWindowFlags_NoDecoration
use figure_implot3d_ref, only : ip3_begin_plot, ip3_end_plot, ip3_mouse_ray, ip3_plot_to_pixels, ip3_setup_axes, &
                                ip3_triangles, ip3_quads, ip3_surface, ip3_mesh, ip3_image, ip3_text, ip3_spec, &
                                ImPlot3DMarker_Diamond
use figure_implot_ref, only : ImPlotColormap_Plasma
use figure_plot3d_frame, only : pf3_begin_plot, pf3_end_plot, pf3_mouse_ray, pf3_plot_to_pixels, pf3_setup_axes
use figure_plot3d_items, only : pf3_triangles, pf3_quads, pf3_surface, pf3_mesh, pf3_image, pf3_text, pf3_spec
use figure_testing, only : test_capture, test_compare_image, test_mouse_move

use figure_test_drawdata, only : dd_equal, dd_snapshot, draw_data
implicit none
integer(int32), parameter :: W = 640_int32     !< Display width [pixels].
integer(int32), parameter :: H = 480_int32     !< Display height [pixels].
integer(int32), parameter :: NCASE = 4_int32   !< Cases.
integer(int32), parameter :: NF = 3_int32      !< Frames per side of a case.
integer(int32), parameter :: NP = 120_int32    !< Points of the helix.
integer(int32), parameter :: NSTATE = 27_int32 !< Values per frame: 8 corners (16), 2 points (4), the ray (6), over.
real(real64),   parameter :: LIM1(6) = [-1.0_real64, 1.0_real64, -2.0_real64, 2.0_real64, 0.0_real64, 5.0_real64] !< Limits.
real(real64),   parameter :: RED(4) = [0.9_real64, 0.2_real64, 0.15_real64, 1.0_real64]  !< A colour.
real(real64),   parameter :: BLUE(4) = [0.2_real64, 0.4_real64, 0.95_real64, 1.0_real64] !< Another.
real(real64)              :: hx(NP), hy(NP), hz(NP) !< The helix.
real(real32)              :: sx(NP), sy(NP), sz(NP) !< The helix, single precision.
real(real64)              :: cols(4, NP)            !< Per-point colours.
real(real64)              :: sizes(NP)              !< Per-point sizes.
real(real64)              :: nx(12), ny(12), nz(12) !< A line with NaNs.
real(real64)              :: tx(9), ty(9), tz(9), qx(8), qy(8), qz(8) !< Triangles, quads.
real(real64)              :: gx(24), gy(20), gz(24, 20)  !< A rectilinear surface.
real(real64)              :: px(16, 12), py(16, 12), pz(16, 12), fz(6, 5) !< A polar one, a flat one.
real(real64)              :: ox(6), oy(6), oz(6)         !< An octahedron.
real(real32)              :: sox(6), soy(6), soz(6)      !< ... single precision.
integer(int32)            :: otri(3, 8)                  !< Its faces.
real(real64)              :: floor(3, 4), wall(3, 4)     !< Images' corners.
type(texture_object)      :: tex                         !< The image.
integer(int32)            :: ii, jj                      !< Counters.
type(draw_data)           :: dd(NF, 2)          !< Each frame's draw data, per side.
type(app_object)          :: app               !< Application.
real(real64)              :: state(NSTATE, NF, 2) !< Per frame and side.
logical                   :: test_passed(NCASE) !< Per-case outcome.
logical                   :: side_fortran      !< Drawing with the Fortran frame.
integer(int32)            :: c, f, s, sd, i    !< Case, frame, status, side, counter.
character(len=16)         :: keep              !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
call make_texture()
do i = 1_int32, NP
   hx(i) = 0.8_real64 * cos(real(i, real64) * 0.15_real64)
   hy(i) = 1.6_real64 * sin(real(i, real64) * 0.15_real64)
   hz(i) = real(i, real64) * 0.04_real64
   cols(:, i) = [real(i, real64) / real(NP, real64), 0.5_real64, 1.0_real64 - real(i, real64) / real(NP, real64), &
                 1.0_real64]
   sizes(i) = 2.0_real64 + mod(real(i, real64), 5.0_real64)
enddo
sx = real(hx, real32)
sy = real(hy, real32)
sz = real(hz * 2.0_real64, real32)
do i = 1_int32, 12_int32
   nx(i) = -0.9_real64 + real(i, real64) * 0.15_real64
   ny(i) = 1.5_real64 * sin(real(i, real64))
   nz(i) = 2.5_real64 + cos(real(i, real64))
enddo
nx(5) = ieee_value(1.0_real64, ieee_quiet_nan)
nz(9) = ieee_value(1.0_real64, ieee_quiet_nan)
tx = [-0.8_real64, 0.8_real64, 0.0_real64, -0.6_real64, 0.6_real64, 0.1_real64, -1.0_real64, 0.2_real64, 0.9_real64]
ty = [-1.5_real64, -1.0_real64, 1.6_real64, 1.2_real64, 1.4_real64, -1.8_real64, 0.0_real64, -0.4_real64, 1.0_real64]
tz = [0.5_real64, 4.0_real64, 2.0_real64, 3.5_real64, 0.8_real64, 2.2_real64, 1.0_real64, 4.6_real64, 2.8_real64]
qx = [-0.9_real64, 0.9_real64, 0.9_real64, -0.9_real64, -0.5_real64, -0.5_real64, 0.5_real64, 0.5_real64]
qy = [0.2_real64, 0.2_real64, 0.2_real64, 0.2_real64, -1.8_real64, 1.8_real64, 1.8_real64, -1.8_real64]
qz = [0.5_real64, 0.5_real64, 4.5_real64, 4.5_real64, 2.5_real64, 2.5_real64, 2.5_real64, 2.5_real64]
do ii = 1_int32, 24_int32
   gx(ii) = -1.0_real64 + real(ii - 1_int32, real64) * (2.0_real64 / 23.0_real64)
enddo
do jj = 1_int32, 20_int32
   gy(jj) = -2.0_real64 + real(jj - 1_int32, real64) * (4.0_real64 / 19.0_real64)
   do ii = 1_int32, 24_int32
      gz(ii, jj) = 2.5_real64 + 2.0_real64 * sin(2.5_real64 * gx(ii)) * cos(1.2_real64 * gy(jj))
   enddo
enddo
do jj = 1_int32, 12_int32
   do ii = 1_int32, 16_int32
      px(ii, jj) = (0.15_real64 + 0.05_real64 * real(jj, real64)) * cos(real(ii, real64) * 0.4_real64)
      py(ii, jj) = 2.0_real64 * (0.15_real64 + 0.05_real64 * real(jj, real64)) * sin(real(ii, real64) * 0.4_real64)
      pz(ii, jj) = 1.0_real64 + 0.3_real64 * real(jj, real64)
   enddo
enddo
fz = 3.0_real64
ox = [1.0_real64, -1.0_real64, 0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64]
oy = [0.0_real64, 0.0_real64, 1.5_real64, -1.5_real64, 0.0_real64, 0.0_real64]
oz = [2.5_real64, 2.5_real64, 2.5_real64, 2.5_real64, 4.5_real64, 0.5_real64]
sox = real(ox * 0.5_real64, real32)
soy = real(oy * 0.5_real64, real32)
soz = real(oz, real32)
otri = reshape([1, 3, 5, 3, 2, 5, 2, 4, 5, 4, 1, 5, 3, 1, 6, 2, 3, 6, 4, 2, 6, 1, 4, 6], [3, 8])
floor = reshape([-0.8_real64, -1.5_real64, 0.2_real64, 0.8_real64, -1.5_real64, 0.2_real64, 0.8_real64, 1.5_real64, &
                 0.2_real64, -0.8_real64, 1.5_real64, 0.2_real64], [3, 4])
wall = reshape([-0.8_real64, 1.0_real64, 0.5_real64, 0.8_real64, 1.0_real64, 0.5_real64, 0.8_real64, 1.0_real64, &
                3.5_real64, -0.8_real64, 1.0_real64, 3.5_real64], [3, 4])
do c = 1_int32, NCASE
   state = 0.0_real64
   do sd = 1_int32, 2_int32 ! 1 ImPlot3D, 2 the Fortran frame
      side_fortran = sd == 2_int32
      do f = 1_int32, NF
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_3d_surfaces: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('plot frame 3d surfaces', flags=ImGuiWindowFlags_NoDecoration)) call draw_case(c, f)
         call dd_snapshot(dd(f, sd))
         call ig_end()
         if (f == NF) call test_capture(picture(c, side_fortran), s)
         if (f == 1_int32) call test_capture(picture(10_int32 + c, side_fortran), s)
      enddo
      do i = 1_int32, 40_int32
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_3d_surfaces: next_frame returned false headless'
      enddo
   enddo
   test_passed(c) = state_equal(c) .and. pictures_equal(c) .and. pictures_equal(10_int32 + c)
   test_passed(c) = draws_equal(c) .and. test_passed(c)
enddo
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_3d_surfaces checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   function draws_equal(k) result(ok)
   !< Both sides' draw data equal on every frame (`dd_equal`).
   integer(int32), intent(in) :: k     !< Case.
   logical                    :: ok    !< Equal.
   integer(int32)             :: fr    !< Frame.
   character(len=32)          :: label !< The case and frame.

   ok = .true.
   do fr = 1_int32, NF
      write(label, '(A,I0,A,I0)') 'case ', k, ', frame ', fr
      ok = dd_equal(dd(fr, 1), dd(fr, 2), trim(label)) .and. ok
   enddo
   endfunction draws_equal

   subroutine draw_case(k, fr)
   !< A case's plot on a frame, by the side drawing.
   integer(int32), intent(in) :: k, fr !< Case, frame.
   integer(int32)             :: m     !< Side.

   m = merge(2_int32, 1_int32, side_fortran)
   associate(v => state(:, fr, m))
      if (side_fortran) then
         select case (k)
         case (1_int32)
            if (.not. pf3_begin_plot('Polygons', width=600.0_real64, height=440.0_real64)) return
            call pf3_setup_axes('x', 'y', 'z', limits=LIM1, elevation=25.0_real64, azimuth=35.0_real64)
            call pf3_triangles('triangles', tx, ty, tz, spec=pf3_spec(line_color=RED, line_weight=2.0_real64))
            call pf3_quads('quads', qx, qy, qz, spec=pf3_spec(fill_alpha=0.8_real64, marker=ImPlot3DMarker_Diamond))
         case (2_int32)
            if (.not. pf3_begin_plot('Surfaces', width=600.0_real64, height=440.0_real64)) return
            call pf3_setup_axes('x', 'y', 'z', limits=LIM1, elevation=30.0_real64, azimuth=-55.0_real64)
            call pf3_surface('rectilinear', gx, gy, gz)
            call pf3_surface('polar', px, py, pz, colormap=ImPlotColormap_Plasma, scale_min=1.0_real64, &
                             scale_max=5.0_real64, spec=pf3_spec(fill_alpha=0.7_real64, line_color=BLUE))
            call pf3_surface('flat', gx(1:6), gy(1:5), fz)
         case (3_int32)
            if (.not. pf3_begin_plot('Meshes', width=600.0_real64, height=440.0_real64)) return
            call pf3_setup_axes('x', 'y', 'z', limits=LIM1, elevation=20.0_real64, azimuth=60.0_real64)
            call pf3_mesh('octahedron', ox, oy, oz, otri, spec=pf3_spec(fill_color=BLUE, line_color=RED))
            call pf3_mesh('small', sox, soy, soz, otri)
         case default
            if (.not. pf3_begin_plot('Images', width=600.0_real64, height=440.0_real64)) return
            call pf3_setup_axes('x', 'y', 'z', elevation=25.0_real64, azimuth=-30.0_real64)
            call pf3_image('floor', tex, floor)
            call pf3_image('wall', tex, wall, tint=[1.0_real64, 0.8_real64, 0.6_real64, 0.9_real64])
            call pf3_text('origin', 0.0_real64, 0.0_real64, 0.2_real64)
            call pf3_text('turned', 0.5_real64, 1.0_real64, 2.0_real64, angle=0.6_real64, offset=[10.0_real64, -4.0_real64])
            call pf3_text('outside', 9.0_real64, 0.0_real64, 2.0_real64)
         endselect
         call measure(v)
         call pf3_end_plot()
      else
         select case (k)
         case (1_int32)
            if (.not. ip3_begin_plot('Polygons', width=600.0_real64, height=440.0_real64)) return
            call ip3_setup_axes('x', 'y', 'z', limits=LIM1, elevation=25.0_real64, azimuth=35.0_real64)
            call ip3_triangles('triangles', tx, ty, tz, spec=ip3_spec(line_color=RED, line_weight=2.0_real64))
            call ip3_quads('quads', qx, qy, qz, spec=ip3_spec(fill_alpha=0.8_real64, marker=ImPlot3DMarker_Diamond))
         case (2_int32)
            if (.not. ip3_begin_plot('Surfaces', width=600.0_real64, height=440.0_real64)) return
            call ip3_setup_axes('x', 'y', 'z', limits=LIM1, elevation=30.0_real64, azimuth=-55.0_real64)
            call ip3_surface('rectilinear', gx, gy, gz)
            call ip3_surface('polar', px, py, pz, colormap=ImPlotColormap_Plasma, scale_min=1.0_real64, &
                             scale_max=5.0_real64, spec=ip3_spec(fill_alpha=0.7_real64, line_color=BLUE))
            call ip3_surface('flat', gx(1:6), gy(1:5), fz)
         case (3_int32)
            if (.not. ip3_begin_plot('Meshes', width=600.0_real64, height=440.0_real64)) return
            call ip3_setup_axes('x', 'y', 'z', limits=LIM1, elevation=20.0_real64, azimuth=60.0_real64)
            call ip3_mesh('octahedron', ox, oy, oz, otri, spec=ip3_spec(fill_color=BLUE, line_color=RED))
            call ip3_mesh('small', sox, soy, soz, otri)
         case default
            if (.not. ip3_begin_plot('Images', width=600.0_real64, height=440.0_real64)) return
            call ip3_setup_axes('x', 'y', 'z', elevation=25.0_real64, azimuth=-30.0_real64)
            call ip3_image('floor', tex, floor)
            call ip3_image('wall', tex, wall, tint=[1.0_real64, 0.8_real64, 0.6_real64, 0.9_real64])
            call ip3_text('origin', 0.0_real64, 0.0_real64, 0.2_real64)
            call ip3_text('turned', 0.5_real64, 1.0_real64, 2.0_real64, angle=0.6_real64, offset=[10.0_real64, -4.0_real64])
            call ip3_text('outside', 9.0_real64, 0.0_real64, 2.0_real64)
         endselect
         call measure(v)
         call ip3_end_plot()
      endif
   endassociate
   endsubroutine draw_case

   subroutine make_texture()
   !< A 4 x 4 checker of two colours (bytes below 128: int8).
   integer(int8)  :: rgba(4, 4, 4) !< Pixels.
   integer(int32) :: i, j, st      !< Pixel, status.

   call tex%init(4_int32, 4_int32, smooth=.false.)
   do j = 1_int32, 4_int32
      do i = 1_int32, 4_int32
         if (mod(i + j, 2_int32) == 0_int32) then
            rgba(1, i, j) = 120_int8
            rgba(2, i, j) = 30_int8
            rgba(3, i, j) = 20_int8
         else
            rgba(1, i, j) = 20_int8
            rgba(2, i, j) = 45_int8
            rgba(3, i, j) = 110_int8
         endif
         rgba(4, i, j) = 127_int8
      enddo
   enddo
   call tex%update(rgba, stat=st)
   endsubroutine make_texture

   subroutine measure(v)
   !< The state of the plot being declared, by the side drawing: corners' and points' pixels, the pointer's ray.
   real(real64), intent(out) :: v(NSTATE) !< State.
   real(real64)              :: o(3), d(3) !< Ray.
   real(real64)              :: q(3)      !< A point.
   integer(int32)            :: j         !< Corner.
   logical                   :: over      !< Over the plot.

   do j = 0_int32, 7_int32 ! the box of LIM1 (the ranges of cases 1-4, a point of the others')
      q(1) = LIM1(1)
      if (iand(j, 1_int32) /= 0_int32) q(1) = LIM1(2)
      q(2) = LIM1(3)
      if (iand(j, 2_int32) /= 0_int32) q(2) = LIM1(4)
      q(3) = LIM1(5)
      if (iand(j, 4_int32) /= 0_int32) q(3) = LIM1(6)
      call to_pixels(q, v(2_int32 * j + 1_int32), v(2_int32 * j + 2_int32))
   enddo
   q(1) = 0.3_real64
   q(2) = -0.7_real64
   q(3) = 1.1_real64
   call to_pixels(q, v(17), v(18))
   q(1) = 0.25_real64
   q(2) = 0.5_real64
   q(3) = 0.75_real64
   call to_pixels(q, v(19), v(20))
   if (side_fortran) then
      over = pf3_mouse_ray(o, d)
   else
      over = ip3_mouse_ray(o, d)
   endif
   v(21:23) = o
   v(24:26) = d
   v(27) = merge(1.0_real64, 0.0_real64, over)
   endsubroutine measure

   subroutine to_pixels(q, px, py)
   !< A point's pixel, by the side drawing.
   real(real64), intent(in)  :: q(3)   !< Point.
   real(real64), intent(out) :: px, py !< Pixel.

   if (side_fortran) then
      call pf3_plot_to_pixels(q(1), q(2), q(3), px, py)
   else
      call ip3_plot_to_pixels(q(1), q(2), q(3), px, py)
   endif
   endsubroutine to_pixels

   function state_equal(k) result(ok)
   !< Both sides' state equal on every frame.
   integer(int32), intent(in) :: k  !< Case.
   logical                    :: ok !< Equal.
   integer(int32)             :: fr !< Frame.

   ok = .true.
   do fr = 1_int32, NF
      if (all(state(:, fr, 1) == state(:, fr, 2))) cycle
      ok = .false.
      write(output_unit, '(A,I0,A,I0,A)') 'case ', k, ', frame ', fr, ': ImPlot3D, frame'
      write(output_unit, '(5ES24.16)') state(:, fr, 1)
      write(output_unit, '(5ES24.16)') state(:, fr, 2)
   enddo
   endfunction state_equal

   function pictures_equal(k) result(ok)
   !< A case's pictures of both sides equal at the oracle's rule.
   integer(int32), intent(in) :: k   !< Case.
   logical                    :: ok  !< Equal.
   integer(int64)             :: nf_ !< Pixels that failed.
   integer(int32)             :: st  !< Status.

   ok = test_compare_image(picture(k, .true.), picture(k, .false.), threshold=2_int32, max_failed=0_int32, &
                           failed=nf_, stat=st)
   if (.not. ok) write(output_unit, '(A,I0,A,I0,A,A)') 'case ', k, ': ', nf_, ' pixels failed: ', figure_last_error()
   endfunction pictures_equal

   function picture(k, fortran) result(name)
   !< A case's picture: ImPlot3D's or the Fortran frame's.
   integer(int32), intent(in)    :: k       !< Case.
   logical,        intent(in)    :: fortran !< The Fortran frame's.
   character(len=:), allocatable :: name    !< File name.
   character(len=8)              :: tag     !< The case's number.

   write(tag, '(I0)') k
   if (fortran) then
      name = 'figure_test_plot_frame_3d_surfaces.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_3d_surfaces.'//trim(tag)//'.implot3d.png.tmp'
   endif
   endfunction picture

   subroutine remove_files()
   !< The pictures removed (and a mismatch's .new.png and .diff.png, left only on a failure).
   integer(int32) :: k, u, ios, j !< Case, unit, status, side.
   logical        :: there        !< The file exists.

   do k = 1_int32, 10_int32 + NCASE
      do j = 1_int32, 2_int32
         inquire(file=picture(k, j == 2_int32), exist=there)
         if (.not. there) cycle
         open(newunit=u, file=picture(k, j == 2_int32), status='old', iostat=ios)
         if (ios == 0) close(u, status='delete')
      enddo
   enddo
   endsubroutine remove_files
endprogram figure_test_plot_frame_3d_surfaces
