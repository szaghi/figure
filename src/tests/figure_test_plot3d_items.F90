!< figure_test_plot3d_items, ImPlot3D's further items and setup, headless: triangles, quads, an image on a plane, a log
!< axis, the box's scale and rotation, the legend's place, the pointer's ray, and the usage errors.
program figure_test_plot3d_items
!< figure_test_plot3d_items, ImPlot3D's further items and setup, headless: triangles, quads, an image on a plane, a log
!< axis, the box's scale and rotation, the legend's place, the pointer's ray, and the usage errors.
!<
!< Plot A: two triangles and a quad in colours of their own, without legend entries (an icon would carry the colour),
!< drawn; an image on the plane z = 0, drawn in its tint; the legend in the south-east corner (a quad with an entry:
!< its colour's extent, icon included, reaches the box's bottom-right); the pointer moved to the pixel of a point: the ray under it passes through the point. Plot B: z on
!< a log scale, so z = 10 lies halfway between z = 1 and z = 100 on the screen; its box stretched twice along x (the
!< x edge longer on screen than in plot A, where the box is a cube). Plot C: rotated from the program (elevation
!< 90: seen from above, the x and y axes on the screen's plane). The refusals with their statuses and messages.
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_OK, app_object, figure_last_error, ig_begin, ig_end,        &
                   ig_same_line, ig_set_next_window, ip3_begin_plot, ip3_end_plot, ip3_image, ip3_mouse_ray, ip3_plot_to_pixels,  &
                   ip3_quads, ip3_setup_axes, ip3_setup_axis, ip3_setup_box, ip3_setup_legend, ip3_spec,           &
                   ip3_triangles, plot3d_spec_object, texture_object, ImPlot3DItemFlags_NoLegend
use figure_testing, only : test_drawn_extent, test_mouse_move

implicit none
real(real64), parameter :: TRI_COLOR(4) = [0.27_real64, 0.93_real64, 0.11_real64, 1.0_real64]  !< The triangles' fill.
real(real64), parameter :: QUAD_COLOR(4) = [0.8_real64, 0.2_real64, 0.6_real64, 1.0_real64] !< The quad's fill.
real(real64), parameter :: TINT(4) = [0.4_real64, 0.6_real64, 1.0_real64, 1.0_real64]       !< The image's tint.
real(real64), parameter :: QUAD2_COLOR(4) = [0.6_real64, 0.4_real64, 0.2_real64, 1.0_real64] !< A quad, no legend.
type(app_object)         :: app          !< Application.
type(texture_object)     :: tex          !< The image.
type(plot3d_spec_object) :: tri_spec     !< The triangles' style.
type(plot3d_spec_object) :: quad_spec    !< The quad's style.
type(plot3d_spec_object) :: quad2_spec   !< The second quad's (no legend entry: no icon in its colour).
logical                  :: ok(11)       !< Per-check outcome.
real(real64)             :: tri(3, 6)    !< Two triangles: x, y, z of each vertex.
real(real64)             :: quad(3, 4)   !< A quad.
real(real64)             :: corners(3, 4) !< The image's corners.
real(real64)             :: ext(4, 4)    !< Extents of the triangles, the quad, the image, the second quad [pixels].
real(real64)             :: box_a(4)     !< Plot A's corner pixels: (xmin, ymin, zmin) and (xmax, ymin, zmin).
real(real64)             :: box_b(4)     !< ... plot B's.
real(real64)             :: zpix(2, 3)   !< Plot B: the pixels of z = 1, 10, 100 at x = y = 0.
real(real64)             :: probe(3)     !< A point of plot A.
real(real64)             :: probe_px(2)  !< Its pixel.
real(real64)             :: origin(3)    !< The pointer's ray: origin.
real(real64)             :: dir(3)       !< ... direction.
real(real64)             :: dist         !< The probe's distance from the ray.
real(real64)             :: top(4)       !< Plot C: pixels of (0, 0, 0) and (0, 0, 1).
real(real64)             :: plot_a(4)    !< Plot A's box: pixels of (1, 1, -1) [the bottom-right corner] and others.
logical                  :: found(4)     !< The extents were found.
logical                  :: over         !< The pointer was over plot A.
integer(int32)           :: st(6)        !< Statuses of refused calls.
character(len=160)       :: msg(6)       !< Their messages.
integer(int32)           :: errors       !< Frames with a usage error.
integer(int32)           :: f            !< Frame.
integer(int32)           :: i            !< Index.
integer(int32)           :: s            !< Status of a frame.

ok = .false.
errors = 0_int32
st = -1_int32
msg = ''
over = .false.
dist = huge(1.0_real64)
tri = reshape([0.0_real64, 0.0_real64, 0.0_real64, 0.5_real64, 0.0_real64, 0.0_real64, 0.0_real64, 0.5_real64, &
               0.0_real64, -0.5_real64, -0.5_real64, 0.0_real64, -0.2_real64, -0.5_real64, 0.0_real64,         &
               -0.5_real64, -0.2_real64, 0.0_real64], [3, 6])
quad = reshape([0.2_real64, 0.2_real64, 0.5_real64, 0.6_real64, 0.2_real64, 0.5_real64, 0.6_real64, 0.6_real64, &
                0.5_real64, 0.2_real64, 0.6_real64, 0.5_real64], [3, 4])
corners = reshape([-1.0_real64, 1.0_real64, -1.0_real64, 1.0_real64, 1.0_real64, -1.0_real64, 1.0_real64,     &
                   -1.0_real64, -1.0_real64, -1.0_real64, -1.0_real64, -1.0_real64], [3, 4])
probe = [0.3_real64, -0.4_real64, 0.5_real64]
tri_spec = ip3_spec(fill_color=TRI_COLOR, line_color=TRI_COLOR, flags=ImPlot3DItemFlags_NoLegend) ! no icon
quad_spec = ip3_spec(fill_color=QUAD_COLOR, line_color=QUAD_COLOR)
quad2_spec = ip3_spec(fill_color=QUAD2_COLOR, line_color=QUAD2_COLOR, flags=ImPlot3DItemFlags_NoLegend)
call app%init_headless(1200_int32, 500_int32)
call tex%init(4_int32, 4_int32)
call tex%update(reshape([(int(mod(i, 120), kind=1), i = 1, 64)], [4, 4, 4]))
do f = 1_int32, 30_int32
   if (.not. app%next_frame(s)) exit
   if (s /= FIG_OK) errors = errors + 1_int32
   call ig_set_next_window(0.0_real64, 0.0_real64, 1200.0_real64, 500.0_real64, always=.true.)
   if (ig_begin('3-D')) then
      if (ip3_begin_plot('A', width=380.0_real64, height=380.0_real64)) then
         call ip3_setup_axes('x', 'y', 'z', limits=[-1.0_real64, 1.0_real64, -1.0_real64, 1.0_real64, &
                             -1.0_real64, 1.0_real64])
         call ip3_setup_legend('se')
         call ip3_triangles('triangles', tri(1, :), tri(2, :), tri(3, :), spec=tri_spec)
         call ip3_quads('quad', quad(1, :), quad(2, :), quad(3, :), spec=quad_spec)
         call ip3_quads('quad 2', quad(1, :) - 0.8_real64, quad(2, :), quad(3, :), spec=quad2_spec)
         call ip3_image('image', tex, corners, tint=TINT)
         call ip3_plot_to_pixels(-1.0_real64, -1.0_real64, -1.0_real64, box_a(1), box_a(2))
         call ip3_plot_to_pixels(1.0_real64, -1.0_real64, -1.0_real64, box_a(3), box_a(4))
         call ip3_plot_to_pixels(1.0_real64, 1.0_real64, 1.0_real64, plot_a(1), plot_a(2))
         call ip3_plot_to_pixels(-1.0_real64, -1.0_real64, 1.0_real64, plot_a(3), plot_a(4))
         call ip3_plot_to_pixels(probe(1), probe(2), probe(3), probe_px(1), probe_px(2))
         if (f >= 12_int32) then
            if (ip3_mouse_ray(origin, dir)) over = .true.
            dist = distance_to_ray(probe, origin, dir)
         endif
         if (f == 25_int32) then
            call ip3_setup_axis('x', scale='log', stat=st(1))               ! after the first item
            msg(1) = figure_last_error()
            call ip3_triangles('bad', tri(1, 1:4), tri(2, 1:4), tri(3, 1:4), stat=st(2)) ! 4 vertices
            msg(2) = figure_last_error()
            call ip3_image('bad', tex, corners(:, 1:3), stat=st(3))          ! 3 corners
            msg(3) = figure_last_error()
         endif
         call ip3_end_plot()
      endif
      call test_drawn_extent(TRI_COLOR, ext(1, 1), ext(2, 1), ext(3, 1), ext(4, 1), found=found(1))
      call test_drawn_extent(QUAD_COLOR, ext(1, 2), ext(2, 2), ext(3, 2), ext(4, 2), found=found(2))
      call test_drawn_extent(TINT, ext(1, 3), ext(2, 3), ext(3, 3), ext(4, 3), found=found(3))
      call test_drawn_extent(QUAD2_COLOR, ext(1, 4), ext(2, 4), ext(3, 4), ext(4, 4), found=found(4))
      call ig_same_line()
      if (ip3_begin_plot('B', width=380.0_real64, height=380.0_real64)) then
         call ip3_setup_axes('x', 'y', 'z', limits=[-1.0_real64, 1.0_real64, -1.0_real64, 1.0_real64, &
                             1.0_real64, 100.0_real64])
         call ip3_setup_axis('z', label='z (log)', scale='log')
         call ip3_setup_box(scale=[2.0_real64, 1.0_real64, 1.0_real64])
         call ip3_triangles('triangles', tri(1, :), tri(2, :), 1.0_real64 + 50.0_real64 * (tri(3, :) + 0.5_real64))
         call ip3_plot_to_pixels(0.0_real64, 0.0_real64, 1.0_real64, zpix(1, 1), zpix(2, 1))
         call ip3_plot_to_pixels(0.0_real64, 0.0_real64, 10.0_real64, zpix(1, 2), zpix(2, 2))
         call ip3_plot_to_pixels(0.0_real64, 0.0_real64, 100.0_real64, zpix(1, 3), zpix(2, 3))
         call ip3_plot_to_pixels(-1.0_real64, -1.0_real64, 1.0_real64, box_b(1), box_b(2))
         call ip3_plot_to_pixels(1.0_real64, -1.0_real64, 1.0_real64, box_b(3), box_b(4))
         if (f == 25_int32) then
            call ip3_setup_axis('w', stat=st(4))                             ! no such axis (and after an item)
            msg(4) = figure_last_error()
         endif
         call ip3_end_plot()
      endif
      call ig_same_line()
      if (ip3_begin_plot('C', width=380.0_real64, height=380.0_real64)) then
         call ip3_setup_axes('x', 'y', 'z')
         call ip3_setup_box(elevation=90.0_real64, azimuth=0.0_real64)
         call ip3_triangles('triangles', tri(1, :), tri(2, :), tri(3, :))
         call ip3_plot_to_pixels(0.0_real64, 0.0_real64, -1.0_real64, top(1), top(2))
         call ip3_plot_to_pixels(0.0_real64, 0.0_real64, 1.0_real64, top(3), top(4))
         call ip3_end_plot()
      endif
      if (f == 25_int32) then
         if (ip3_mouse_ray(origin, dir, stat=st(5))) continue                ! outside a 3-D plot
         msg(5) = figure_last_error()
         call ip3_setup_legend('up', stat=st(6))                             ! outside, and an unknown place
         msg(6) = figure_last_error()
      endif
   endif
   call ig_end()
   if (f == 10_int32) call test_mouse_move(probe_px(1), probe_px(2))
enddo
if (app%next_frame(s)) continue
if (s /= FIG_OK) errors = errors + 1_int32
call tex%destroy()
call app%destroy()

ok(1) = found(1) .and. found(4)                                         ! triangles and quads drawn (no icons)
ok(2) = found(3)                                                        ! the image, in its tint
ok(3) = found(2) .and. ext(3, 2) > plot_a(1) - 60.0_real64 .and. ext(4, 2) > 0.5_real64 * (plot_a(2) + plot_a(4)) ! legend
ok(4) = abs(zpix(2, 2) - 0.5_real64 * (zpix(2, 1) + zpix(2, 3))) < 1.0_real64 ! z on a log scale
ok(5) = hypot(box_b(3) - box_b(1), box_b(4) - box_b(2)) > 1.3_real64 * hypot(box_a(3) - box_a(1), box_a(4) - box_a(2))
ok(6) = over .and. dist < 1.0e-2_real64                                 ! the ray through the probe's pixel
ok(7) = hypot(top(3) - top(1), top(4) - top(2)) < 2.0_real64            ! seen from above: z along the view
ok(8) = all(st([1, 5]) == int(FIG_ERR_STATE, int32)) .and.                                                    &
        msg(1) == 'ip3_setup_axis: the setup of the 3-D plot is over (call it before the first item)' .and.   &
        msg(5) == 'ip3_mouse_ray: no 3-D plot is being declared (call it between ip3_begin_plot and '// &
                  'ip3_end_plot)'
ok(9) = all(st([2, 3, 4, 6]) == int(FIG_ERR_ARGUMENT, int32)) .and.                                          &
        msg(2) == 'ip3_triangles: 4 vertices are not a whole number of triangles (3 each)' .and.              &
        msg(3) == 'ip3_image: corners must be 3 x 4 (x, y, z of four corners)' .and.                          &
        msg(4) == "ip3_setup_axis: unknown axis 'w' ('x', 'y' or 'z')" .and.                                   &
        msg(6) == "ip3_setup_legend: unknown location 'up' ('n', 'ne', 'e', 'se', 's', 'sw', 'w', 'nw' or 'c')"
ok(10) = errors == 0_int32
ok(11) = zpix(2, 3) < zpix(2, 1)                                         ! the geometry was read: z grows upwards

write(output_unit, '(A,*(L2))') 'figure_test_plot3d_items checks:', ok
if (.not. all(ok)) then
   write(output_unit, '(A,16F8.1)') 'extents ', ext
   write(output_unit, '(A,4F8.1)') 'plot a ', plot_a
   write(output_unit, '(A,6F8.1)') 'zpix ', zpix
   write(output_unit, '(A,4F8.1,A,4F8.1)') 'box a ', box_a, ' box b ', box_b
   write(output_unit, '(A,L2,ES12.4)') 'ray over, distance ', over, dist
   write(output_unit, '(A,4F8.1)') 'top ', top
   write(output_unit, '(A,6I3)') 'statuses ', st
   do i = 1_int32, 6_int32
      write(output_unit, '(A)') trim(msg(i))
   enddo
endif
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(ok)
if (.not. all(ok)) error stop 1
contains
   pure function distance_to_ray(p, o, d) result(dd)
   !< Distance of point `p` from the line through `o` along the unit vector `d`.
   real(real64), intent(in) :: p(3) !< Point.
   real(real64), intent(in) :: o(3) !< Origin.
   real(real64), intent(in) :: d(3) !< Direction (unit).
   real(real64)             :: dd   !< Distance.
   real(real64)             :: v(3) !< p - o, less its component along d.

   v = (p - o) - dot_product(p - o, d) * d
   dd = norm2(v)
   endfunction distance_to_ray
endprogram figure_test_plot3d_items
