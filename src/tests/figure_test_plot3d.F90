!< figure_test_plot3d, ImPlot3D's small 3-D figures (ip3_*): items, axes, colours, rotation, strides, headless.
program figure_test_plot3d
!< figure_test_plot3d, ImPlot3D's small 3-D figures (ip3_*): items, axes, colours, rotation, strides, headless.
!<
!< A window without decorations at the origin holds one 3-D plot at a time, its ranges and rotation fixed by
!< `ip3_setup_axes`:
!< 1. items in the drawn extent: a helix as a line and as markers, each in its own colour, is drawn inside the plot's
!<    rectangle, and the pixels of its first and last points (ImPlot3D's projection) lie inside what was drawn;
!< 2. axes labelled: with labels the axis text colour has more vertices than with empty labels (the tick labels draw in
!<    both), as many more as the labels' glyphs need;
!< 3. a surface z(i, j) = (x(i) + y(j)) / 2 coloured by a map of three colours (red, green, blue) has vertices of the
!<    map's first and last colours exactly (its finite range scaled to the map), none of either with a scale wider than
!<    its range; green at z = 0, then not after the gradient editor moves the green stop (the edit followed);
!< 4. rotation by a scripted drag: a right drag across the plot (ImPlot3D rotates with the right button) moves the
!<    pixel of the point (1, 0, 0); the same drag with the rotation locked by the setup does not;
!< 5. a golden picture of a line, markers, a surface, a mesh and a text (src/tests/data, |d| <= 2);
!< 6. strided data (as figure_test_plot_data): the line, markers, mesh, surface and grid surface from the same numbers
!<    passed in contiguous arrays, as rows of a matrix, mixed strides, reversed sections, single precision, sections of
!<    a rank-3 array and a field with a gap between its columns: each draws the reference's extent with its number of
!<    vertices, gives ImPlot3D the stride of its data and copies exactly the arrays it cannot read in place;
!< 7. the statuses: outside a frame, outside a plot, a setup after an item, sizes, triangles, limits, scales, colours.
!< The picture is `figure_test_plot3d.shot.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps it).
use, intrinsic :: iso_c_binding, only : c_float, c_int
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64, output_unit
use, intrinsic :: ieee_arithmetic, only : ieee_quiet_nan, ieee_value
use figure, only : app_object, ig_begin, ig_end, ig_gradient_edit, ig_set_next_window, ip_colormap, &
                   ip_colormap_stops, ip_load_colormap, ip3_begin_plot, ip3_end_plot, ip3_line, ip3_mesh, &
                   ip3_scatter, ip3_setup_axes, ip3_spec, ip3_surface, ip3_text, plot3d_spec_object, &
                   ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_NoMove, ImPlot3DMarker_Circle,      &
                   ImPlot3DMeshFlags_NoLines, ImPlot3DMeshFlags_NoMarkers, ImPlot3DSurfaceFlags_NoLines, &
                   ImPlot3DSurfaceFlags_NoMarkers, ImPlot3DItemFlags_NoLegend, FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_OK
use figure_cimgui, only : im_vec2, im_vec4
use figure_cimplot3d, only : ImPlot3D_GetPlotRectPos, ImPlot3D_GetPlotRectSize, ImPlot3D_PlotToPixels_double, &
                             ImPlot3D_PopStyleColor, ImPlot3D_PushStyleColor_Vec4
use figure_cimplot3d_enums, only : ImPlot3DCol_AxisText
use figure_testing, only : test_capture, test_compare_image, test_drawn_extent, test_item_rect, test_mouse_button, &
                           test_mouse_move, test_next_frame, test_plot_copies, test_plot_stride

implicit none
character(len=*), parameter :: GOLDEN = 'src/tests/data/figure_test_plot3d.golden.png' !< The committed reference.
character(len=*), parameter :: SHOT = 'figure_test_plot3d.shot.png.tmp' !< The window.
character(len=*), parameter :: CSV = 'figure_test_plot3d.rgb.csv.tmp'   !< A map of three colours.
integer(int32),   parameter :: W = 560_int32                            !< Display width [pixels].
integer(int32),   parameter :: H = 640_int32                            !< Display height [pixels].
real(real64),     parameter :: SIDE = 480.0_real64                      !< The plot's side [pixels].
integer(int32),   parameter :: N = 40_int32                             !< Points of the helix.
integer(int32),   parameter :: NX = 11_int32                            !< Surface grid, along x.
integer(int32),   parameter :: NY = 9_int32                             !< Surface grid, along y.
integer(int32),   parameter :: NT = 4_int32                             !< Triangles of the mesh.
integer(int32),   parameter :: NW = 7_int32                             !< Ways of passing the data.
integer(int32),   parameter :: NI = 5_int32                             !< Items probed per way.
real(real64),     parameter :: PI = acos(-1.0_real64)                   !< Pi.
real(real64),     parameter :: LIMITS(6) = [-1.2_real64, 1.2_real64, -1.2_real64, 1.2_real64, -1.2_real64, &
                                            1.2_real64]                  !< The plots' ranges.
real(real64),     parameter :: CL(4) = [0.9_real64, 0.1_real64, 0.1_real64, 1.0_real64]  !< Line colour.
real(real64),     parameter :: CS(4) = [0.1_real64, 0.8_real64, 0.1_real64, 1.0_real64]  !< Marker colour.
real(real64),     parameter :: CM(4) = [0.1_real64, 0.2_real64, 0.9_real64, 1.0_real64]  !< Mesh colour.
real(real64),     parameter :: CF(4) = [0.8_real64, 0.7_real64, 0.1_real64, 1.0_real64]  !< Surface colour.
real(real64),     parameter :: CG(4) = [0.7_real64, 0.1_real64, 0.8_real64, 1.0_real64]  !< Grid surface colour.
real(real64),     parameter :: CT(4) = [1.0_real64, 0.0_real64, 1.0_real64, 1.0_real64]  !< Axis text colour.
character(len=10), parameter :: WAYS(NW) = [character(len=10) :: 'copies', 'rows', 'mixed', 'reversed', 'real32', &
                                            'rank 3', 'gap'] !< Their names.
type(app_object)          :: app                !< Application.
logical                   :: test_passed(10)    !< Per-check outcome.
real(real64), target      :: hx(N)              !< The helix, contiguous: x ...
real(real64), target      :: hy(N)              !< ... y ...
real(real64), target      :: hz(N)              !< ... z.
real(real64), target      :: hp(3, N)           !< The helix as the rows of a matrix.
real(real64), target      :: hr(N, 3)           !< The helix reversed, a column each.
real(real32), target      :: hs(3, N)           !< The helix, single precision, rows.
real(real64), target      :: gx(NX)             !< The surface's grid along x.
real(real64), target      :: gy(NY)             !< ... along y.
real(real64), target      :: gz(NX, NY)         !< Its heights, contiguous.
real(real64), target      :: g3(3, NX, NY)      !< Its vertices, a rank-3 array: g3(1, :, :) x, (2) y, (3) z.
real(real64), target      :: gzap(NX + 3, NY)   !< The heights with a gap between columns: gzap(1:NX, :).
real(real32), target      :: gz32(NX, NY)       !< The heights, single precision.
real(real32), target      :: gx32(NX)           !< The grid along x, single precision.
real(real32), target      :: gy32(NY)           !< ... along y.
integer(int32)            :: tri(3, NT)         !< The mesh's triangles, on the helix's points.
character(len=8)          :: keep               !< FIGURE_TEST_KEEP.
integer(int32)            :: early              !< A status before the first frame.
integer(int32)            :: cmap               !< The map of three colours.

test_passed = .false.
call build_data()
call app%init_headless(W, H)
early = FIG_OK
call ip3_line('early', hx, hy, hz, stat=early) ! no frame open
call write_map()
call ip_load_colormap('rgb3', CSV)
cmap = ip_colormap('rgb3')

call extent(test_passed(1))
call labelled(test_passed(2))
call surface_colours(test_passed(3:4))
call rotation(test_passed(5:6))
call picture(test_passed(7))
call strides(test_passed(8:9))
call statuses(test_passed(10))
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot3d checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine build_data()
   !< The helix, the surface's grid and heights in every layout, the mesh's triangles.
   integer(int32) :: i, j !< Counters.
   real(real64)   :: t    !< Parameter.

   do i = 1_int32, N
      t = 4.0_real64 * PI * real(i - 1_int32, real64) / real(N - 1_int32, real64)
      hx(i) = cos(t)
      hy(i) = sin(t)
      hz(i) = t / (2.0_real64 * PI) - 1.0_real64
   enddo
   hp(1, :) = hx
   hp(2, :) = hy
   hp(3, :) = hz
   hr(:, 1) = hx(N:1:-1)
   hr(:, 2) = hy(N:1:-1)
   hr(:, 3) = hz(N:1:-1)
   hs = real(hp, real32)
   do i = 1_int32, NX
      gx(i) = -1.0_real64 + 2.0_real64 * real(i - 1_int32, real64) / real(NX - 1_int32, real64)
   enddo
   do j = 1_int32, NY
      gy(j) = -1.0_real64 + 2.0_real64 * real(j - 1_int32, real64) / real(NY - 1_int32, real64)
   enddo
   do j = 1_int32, NY
      do i = 1_int32, NX
         gz(i, j) = 0.5_real64 * (gx(i) + gy(j))
         g3(:, i, j) = [gx(i), gy(j), gz(i, j)]
      enddo
   enddo
   gzap = -9.0_real64
   gzap(1:NX, :) = gz
   gz32 = real(gz, real32)
   gx32 = real(gx, real32)
   gy32 = real(gy, real32)
   tri = reshape([1, 11, 21,  11, 21, 31,  5, 15, 25,  15, 25, 35], [3, NT])
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

   function window() result(open_)
   !< A frame and the test window, at the origin, without decorations; false when the frame or the window is not open.
   logical :: open_ !< Window open: draw, then `ig_end`.

   open_ = .false.
   if (.not. app%next_frame()) return
   call ig_set_next_window(x=0.0_real64, y=0.0_real64, width=real(W, real64), height=real(H, real64))
   open_ = ig_begin('plot3d', flags=ior(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_NoMove))
   endfunction window

   subroutine idle(k)
   !< `k` frames with an empty window.
   integer(int32), intent(in) :: k !< Frames.
   integer(int32)             :: i !< Counter.

   do i = 1_int32, k
      if (window()) continue
      call ig_end()
   enddo
   endsubroutine idle

   subroutine extent(ok)
   !< The helix as a line and as markers: drawn inside the plot, its ends inside what was drawn.
   logical, intent(out) :: ok        !< Outcome.
   real(real64)         :: r(4)      !< The plot's rectangle: left, top, right, bottom [pixels].
   real(real64)         :: el(4)     !< The line's extent.
   real(real64)         :: es(4)     !< The markers' extent.
   real(real64)         :: ends(4)   !< Pixels of the first and last points.
   logical              :: fl, fs    !< Found.
   integer(int32)       :: k         !< Frame.
   type(im_vec2)        :: p, q      !< Plot rectangle; a projection.

   ok = .false.
   do k = 1_int32, 3_int32
      if (window()) then
         if (ip3_begin_plot('extent', width=SIDE, height=SIDE)) then
            call ip3_setup_axes('x', 'y', 'z', limits=LIMITS, elevation=25.0_real64, azimuth=-60.0_real64)
            call ip3_line('helix', hx, hy, hz, spec=ip3_spec(line_color=CL, line_weight=2.0_real64))
            call ip3_scatter('points', hx, hy, hz, spec=ip3_spec(marker=ImPlot3DMarker_Circle, marker_size=3.0_real64, &
                                                                 marker_line_color=CS, marker_fill_color=CS))
            p = ImPlot3D_GetPlotRectPos()
            q = ImPlot3D_GetPlotRectSize()
            r = [real(p%x, real64), real(p%y, real64), real(p%x + q%x, real64), real(p%y + q%y, real64)]
            q = ImPlot3D_PlotToPixels_double(hx(1), hy(1), hz(1))
            ends(1:2) = [real(q%x, real64), real(q%y, real64)]
            q = ImPlot3D_PlotToPixels_double(hx(N), hy(N), hz(N))
            ends(3:4) = [real(q%x, real64), real(q%y, real64)]
            call ip3_end_plot()
         endif
         call test_drawn_extent(CL, el(1), el(2), el(3), el(4), fl)
         call test_drawn_extent(CS, es(1), es(2), es(3), es(4), fs)
      endif
      call ig_end()
   enddo
   ok = fl .and. fs .and. inside(el, r, 0.0_real64) .and. inside(es, r, 0.0_real64) .and. &
        inside([ends(1:2), ends(1:2)], el, 2.0_real64) .and. inside([ends(3:4), ends(3:4)], el, 2.0_real64) .and. &
        inside([ends(1:2), ends(1:2)], es, 1.0_real64) .and. el(3) - el(1) > 0.3_real64 * SIDE
   if (.not. ok) write(output_unit, '(A,2L2,*(F9.2))') 'extent: ', fl, fs, r, el, es, ends
   endsubroutine extent

   pure function inside(a, b, tol) result(yes)
   !< Whether the rectangle a lies inside the rectangle b grown by tol (left, top, right, bottom).
   real(real64), intent(in) :: a(4) !< Inner rectangle.
   real(real64), intent(in) :: b(4) !< Outer rectangle.
   real(real64), intent(in) :: tol  !< Margin [pixels].
   logical                  :: yes  !< Inside.

   yes = a(1) >= b(1) - tol .and. a(2) >= b(2) - tol .and. a(3) <= b(3) + tol .and. a(4) <= b(4) + tol
   endfunction inside

   subroutine labelled(ok)
   !< The axis text's vertices with labels and with empty labels.
   logical, intent(out) :: ok    !< Outcome.
   integer(int32)       :: nv(2) !< Vertices of the axis text colour: labelled, not.
   integer(int32)       :: k, l  !< Frame, case.
   real(real64)         :: e(4)  !< Extent (not used).
   logical              :: f(2)  !< Found.

   nv = 0_int32
   f = .false.
   do l = 1_int32, 2_int32
      do k = 1_int32, 3_int32
         if (window()) then
            call ImPlot3D_PushStyleColor_Vec4(ImPlot3DCol_AxisText, vec4(CT))
            if (ip3_begin_plot('labels', width=SIDE, height=SIDE)) then
               if (l == 1_int32) then
                  call ip3_setup_axes('distance', 'span', 'height', limits=LIMITS, elevation=25.0_real64, &
                                      azimuth=-60.0_real64)
               else
                  call ip3_setup_axes('', '', '', limits=LIMITS, elevation=25.0_real64, azimuth=-60.0_real64)
               endif
               call ip3_line('helix', hx, hy, hz)
               call ip3_end_plot()
            endif
            call ImPlot3D_PopStyleColor(1_c_int)
            call test_drawn_extent(CT, e(1), e(2), e(3), e(4), f(l), vertices=nv(l))
         endif
         call ig_end()
      enddo
   enddo
   ! 'distance', 'span', 'height': 18 glyphs, 4 vertices each
   ok = all(f) .and. nv(1) - nv(2) == 4_int32 * 18_int32
   if (.not. ok) write(output_unit, '(A,2L2,2I6)') 'labelled: ', f, nv
   endsubroutine labelled

   subroutine surface_colours(ok)
   !< The surface coloured by the map's ends, a scale wider than its range; green followed through an edit.
   logical, intent(out)      :: ok(2)      !< Outcomes: the ends and the scale; the edit followed.
   real(real64), parameter   :: RED(4) = [1.0_real64, 0.0_real64, 0.0_real64, 1.0_real64]   !< The map's first colour.
   real(real64), parameter   :: GREEN(4) = [0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64] !< Its middle one.
   real(real64), parameter   :: BLUE(4) = [0.0_real64, 0.0_real64, 1.0_real64, 1.0_real64]  !< Its last one.
   logical                   :: f(3, 3)    !< Found: red, green, blue; auto scale, wide scale, after the edit.
   real(real64)              :: x, y, sw, sh !< The editor's row of stops.
   real(real64), allocatable :: pos(:)     !< Stop positions.
   real(real64), allocatable :: rgb(:,:)   !< Stop colours.

   call surface_frames(.false., f(:, 1))
   call surface_frames(.true., f(:, 2))
   ok(1) = f(1, 1) .and. f(3, 1) .and. f(2, 1) .and. .not. (f(1, 2) .or. f(3, 2))
   ! the green stop of the editor (drawn with the surface) dragged 60 pixels right: green is no longer at z = 0
   ok(2) = test_item_rect('##points', x, y, sw, sh)
   call drag(x + 0.5_real64 * (sw - sh) + 0.5_real64 * sh, y + 0.5_real64 * sh, &
             x + 0.5_real64 * (sw - sh) + 0.5_real64 * sh + 60.0_real64, y + 0.5_real64 * sh, .true.)
   call ip_colormap_stops('rgb3', pos, rgb)
   call surface_frames(.false., f(:, 3))
   ok(2) = ok(2) .and. pos(2) > 0.55_real64 .and. f(1, 3) .and. f(3, 3) .and. .not. f(2, 3)
   if (.not. all(ok)) write(output_unit, '(A,9L2,*(F8.3))') 'surface colours: ', f, pos
   endsubroutine surface_colours

   subroutine surface_frames(wide, found)
   !< Three frames of the surface coloured by the map (and the map's gradient editor); found: red, green, blue drawn.
   logical, intent(in)  :: wide     !< Scale from -3 to 3 (else the field's range).
   logical, intent(out) :: found(3) !< Red, green, blue found in the last frame.
   integer(int32)       :: k        !< Frame.
   real(real64)         :: e(4)     !< Extent (not used).
   type(plot3d_spec_object) :: s    !< Fill only.

   found = .false.
   s = ip3_spec(flags=ior(ior(ImPlot3DSurfaceFlags_NoLines, ImPlot3DSurfaceFlags_NoMarkers), ImPlot3DItemFlags_NoLegend))
   do k = 1_int32, 3_int32
      if (window()) then
         if (ip3_begin_plot('surface', width=SIDE, height=SIDE)) then
            call ip3_setup_axes('x', 'y', 'z', limits=LIMITS, elevation=25.0_real64, azimuth=-60.0_real64)
            if (wide) then
               call ip3_surface('field', gx, gy, gz, colormap=cmap, scale_min=-3.0_real64, scale_max=3.0_real64, spec=s)
            else
               call ip3_surface('field', gx, gy, gz, colormap=cmap, spec=s)
            endif
            call ip3_end_plot()
         endif
         call test_drawn_extent([1.0_real64, 0.0_real64, 0.0_real64, 1.0_real64], e(1), e(2), e(3), e(4), found(1))
         call test_drawn_extent([0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64], e(1), e(2), e(3), e(4), found(2))
         call test_drawn_extent([0.0_real64, 0.0_real64, 1.0_real64, 1.0_real64], e(1), e(2), e(3), e(4), found(3))
         if (ig_gradient_edit('gradient', 'rgb3', width=SIDE)) continue
      endif
      call ig_end()
   enddo
   endsubroutine surface_frames

   subroutine drag(x0, y0, x1, y1, editor)
   !< A drag from (x0, y0) to (x1, y1) over a few frames, drawing the surface and its editor (`editor`: the left button)
   !< or the rotation's plot (the right button: ImPlot3D rotates with it).
   real(real64), intent(in) :: x0     !< Start abscissa [pixels].
   real(real64), intent(in) :: y0     !< Start ordinate [pixels].
   real(real64), intent(in) :: x1     !< End abscissa [pixels].
   real(real64), intent(in) :: y1     !< End ordinate [pixels].
   logical,      intent(in) :: editor !< Draw the surface and the editor (else the rotation's plot).
   integer(int32)           :: k      !< Step.
   logical                  :: f(3)   !< Not used.

   call test_mouse_move(x0, y0)
   call test_next_frame()
   call test_next_frame()
   call test_mouse_button(.true., merge('left ', 'right', editor))
   call test_next_frame()
   call test_next_frame()
   do k = 1_int32, 4_int32
      call test_mouse_move(x0 + (x1 - x0) * real(k, real64) / 4.0_real64, y0 + (y1 - y0) * real(k, real64) / 4.0_real64)
      call test_next_frame()
   enddo
   call test_mouse_button(.false., merge('left ', 'right', editor))
   call test_next_frame()
   call test_mouse_move(real(W, real64) - 2.0_real64, real(H, real64) - 2.0_real64) ! parked off the plot
   if (editor) then
      call surface_frames(.false., f)
      call surface_frames(.false., f)
      call surface_frames(.false., f)
   else
      call rotation_frames(10_int32, .false.)
   endif
   endsubroutine drag

   subroutine rotation(ok)
   !< A right drag across the plot (ImPlot3D's rotation) moves the pixel of (1, 0, 0); not with the rotation locked by
   !< the setup.
   logical, intent(out) :: ok(2)    !< Outcomes: moved by the drag; held by the setup.
   real(real64)         :: before(2) !< The pixel of (1, 0, 0) before the drag.
   real(real64)         :: after(2)  !< ... after.
   real(real64)         :: held(2)   !< ... after a drag with the rotation set every frame.

   call rotation_frames(3_int32, .false., before)
   call drag(0.5_real64 * SIDE - 60.0_real64, 0.5_real64 * SIDE, 0.5_real64 * SIDE + 60.0_real64, 0.5_real64 * SIDE, &
             .false.)
   call rotation_frames(2_int32, .false., after)
   ok(1) = norm2(after - before) > 10.0_real64
   ! a second plot whose rotation is set by every frame's setup: the drag turns it, the next frame puts it back
   call rotation_frames(3_int32, .true., before)
   call test_mouse_move(0.5_real64 * SIDE - 60.0_real64, 0.5_real64 * SIDE)
   call test_next_frame()
   call test_next_frame()
   call test_mouse_button(.true., 'right')
   call test_next_frame()
   call test_next_frame()
   call test_mouse_move(0.5_real64 * SIDE + 60.0_real64, 0.5_real64 * SIDE)
   call test_next_frame()
   call test_mouse_button(.false., 'right')
   call test_next_frame()
   call test_mouse_move(real(W, real64) - 2.0_real64, real(H, real64) - 2.0_real64)
   call rotation_frames(10_int32, .true., held)
   ok(2) = norm2(held - before) < 0.5_real64
   if (.not. all(ok)) write(output_unit, '(A,*(F9.2))') 'rotation: ', before, after, held
   endsubroutine rotation

   subroutine rotation_frames(k, fixed, pixel)
   !< `k` frames of a plot of the helix; `fixed`: its rotation set every frame (a fresh plot id); the pixel of
   !< (1, 0, 0) in the last frame.
   integer(int32),         intent(in)  :: k        !< Frames.
   logical,                intent(in)  :: fixed    !< Rotation set every frame.
   real(real64), optional, intent(out) :: pixel(2) !< Pixel of (1, 0, 0).
   integer(int32)                      :: i        !< Frame.
   type(im_vec2)                       :: q        !< Projection.
   character(len=12)                   :: id       !< Plot id.

   id = merge('##held     ', '##turned   ', fixed)
   do i = 1_int32, k
      if (window()) then
         if (ip3_begin_plot(trim(id), width=SIDE, height=SIDE)) then
            if (fixed) then
               call ip3_setup_axes('x', 'y', 'z', limits=LIMITS)
               call fixed_rotation()
            else
               call ip3_setup_axes('x', 'y', 'z', limits=LIMITS, elevation=25.0_real64, azimuth=-60.0_real64)
            endif
            call ip3_line('helix', hx, hy, hz)
            q = ImPlot3D_PlotToPixels_double(1.0_real64, 0.0_real64, 0.0_real64)
            if (present(pixel)) pixel = [real(q%x, real64), real(q%y, real64)]
            call ip3_end_plot()
         endif
      endif
      call ig_end()
   enddo
   endsubroutine rotation_frames

   subroutine fixed_rotation()
   !< The box's rotation set every frame (ImPlot3D's `SetupBoxRotation` with `ImPlot3DCond_Always`), through the raw
   !< binding: what a program that holds its view does.
   use figure_cimplot3d, only : ImPlot3D_SetupBoxRotation_double
   use figure_cimplot3d_enums, only : ImPlot3DCond_Always
   use, intrinsic :: iso_c_binding, only : c_bool

   call ImPlot3D_SetupBoxRotation_double(25.0_real64, -60.0_real64, .false._c_bool, ImPlot3DCond_Always)
   endsubroutine fixed_rotation

   subroutine picture(ok)
   !< A line, markers, a surface, a mesh and a text, labelled axes: against the golden.
   logical, intent(out) :: ok !< Outcome.
   integer(int32)       :: k  !< Frame.

   do k = 1_int32, 4_int32
      if (window()) then
         if (ip3_begin_plot('Probes', width=SIDE, height=SIDE)) then
            call ip3_setup_axes('x [m]', 'y [m]', 'z [m]', limits=LIMITS, elevation=25.0_real64, azimuth=-60.0_real64)
            call ip3_surface('field', gx, gy, 0.3_real64 * gz - 0.8_real64, colormap=ip_colormap('batlow'))
            call ip3_line('helix', hx, hy, hz, spec=ip3_spec(line_color=CL, line_weight=2.0_real64))
            call ip3_scatter('probes', hx(1:N:5), hy(1:N:5), hz(1:N:5), spec=ip3_spec(marker=ImPlot3DMarker_Circle, &
                                                                                      marker_size=4.0_real64))
            call ip3_mesh('panel', hx, hy, hz, tri, spec=ip3_spec(fill_color=CM, fill_alpha=0.6_real64))
            call ip3_text('start', hx(1), hy(1), hz(1), offset=[0.0_real64, -12.0_real64])
            call ip3_end_plot()
         endif
         if (k == 4_int32) call test_capture(SHOT)
      endif
      call ig_end()
   enddo
   call idle(1_int32)
   ok = test_compare_image(SHOT, GOLDEN)
   endsubroutine picture

   subroutine strides(ok)
   !< The five items from the same numbers passed seven ways: extents, vertices, strides and copies.
   logical, intent(out)      :: ok(2)            !< Outcomes: extents and vertices; strides and copies.
   real(real64), parameter   :: COLS(4, NI) = reshape([CL, CS, CM, CF, CG], [4, NI]) !< Item colours.
   real(real64)              :: ext(4, NI, NW)   !< Extents drawn [pixels].
   integer(int32)            :: nv(NI, NW)       !< Vertices drawn.
   logical                   :: found(NI, NW)    !< Something drawn.
   integer(int64)            :: st(NI, NW)       !< Stride given to ImPlot3D [bytes].
   integer(int64)            :: cp(NI, NW)       !< Arrays copied.
   integer(int64)            :: want_st(NI, NW)  !< ... expected.
   integer(int64)            :: want_cp(NI, NW)  !< ... expected.
   integer(int32)            :: wy, k, i         !< Way, frame, item.
   integer(int64)            :: c0               !< Copies before an item.

   ! expected: line, markers, mesh (one copy more: its triangles), surface over x(i), y(j) (two copies: the grid),
   ! surface over a grid of vertices
   want_st(:, 1) = [8, 8, 8, 8, 8]
   want_cp(:, 1) = [0, 0, 1, 2, 0]
   want_st(:, 2) = [24, 24, 24, 24, 24] ! rows of the helix; the field and the grid of g3: stride 3 doubles
   want_cp(:, 2) = [0, 0, 1, 2, 0]
   want_st(:, 3) = [8, 8, 8, 8, 8]      ! x contiguous, y and z rows: copied at x's stride; the grid's x contiguous
   want_cp(:, 3) = [2, 2, 3, 2, 2]
   want_st(:, 4) = [8, 8, 8, 8, 8]      ! reversed sections: each copied; the field's columns reversed: copied
   want_cp(:, 4) = [3, 3, 4, 3, 3]
   want_st(:, 5) = [12, 12, 12, 4, 4]   ! single precision rows; a single-precision field
   want_cp(:, 5) = [0, 0, 1, 2, 0]
   want_st(:, 6) = [24, 24, 24, 24, 24] ! a rank-3 array's sections: hp's rows again, g3's planes
   want_cp(:, 6) = [0, 0, 1, 2, 0]
   want_st(:, 7) = [8, 8, 8, 8, 8]      ! a field with a gap between its columns: copied; grid's x, y copied at z's
   want_cp(:, 7) = [0, 0, 1, 3, 3]
   ext = 0.0_real64
   nv = 0_int32
   found = .false.
   st = 0_int64
   cp = 0_int64
   do wy = 1_int32, NW
      do k = 1_int32, 3_int32
         if (window()) then
            if (ip3_begin_plot('strides', width=SIDE, height=SIDE)) then
               call ip3_setup_axes('x', 'y', 'z', limits=LIMITS, elevation=25.0_real64, azimuth=-60.0_real64)
               do i = 1_int32, NI
                  c0 = test_plot_copies()
                  call item(wy, i)
                  cp(i, wy) = test_plot_copies() - c0
                  st(i, wy) = test_plot_stride()
               enddo
               call ip3_end_plot()
            endif
            do i = 1_int32, NI
               call test_drawn_extent(COLS(:, i), ext(1, i, wy), ext(2, i, wy), ext(3, i, wy), ext(4, i, wy), &
                                      found(i, wy), vertices=nv(i, wy))
            enddo
         endif
         call ig_end()
      enddo
   enddo
   ok(1) = all(found)
   do wy = 2_int32, NW
      ok(1) = ok(1) .and. all(abs(ext(:, :, wy) - ext(:, :, 1)) < 0.5_real64) .and. all(nv(:, wy) == nv(:, 1))
   enddo
   ok(2) = all(st == want_st) .and. all(cp == want_cp)
   if (.not. all(ok)) then
      do wy = 1_int32, NW
         write(output_unit, '(A,A10,5L2,5I6,A,5I4,A,5I3)') 'strides: ', WAYS(wy), found(:, wy), nv(:, wy), &
            ' stride', st(:, wy), ' copies', cp(:, wy)
      enddo
   endif
   endsubroutine strides

   subroutine item(wy, i)
   !< Item i (1 line, 2 markers, 3 mesh, 4 surface over x(i), y(j), 5 surface over a grid) with the data of way wy.
   integer(int32), intent(in) :: wy !< Way.
   integer(int32), intent(in) :: i  !< Item.
   type(plot3d_spec_object)   :: s  !< Its style.

   select case (i)
   case (1_int32)
      s = ip3_spec(line_color=CL)
   case (2_int32)
      s = ip3_spec(marker=ImPlot3DMarker_Circle, marker_size=2.0_real64, marker_line_color=CS, marker_fill_color=CS)
   case (3_int32)
      s = ip3_spec(fill_color=CM, flags=ior(ImPlot3DMeshFlags_NoLines, ImPlot3DMeshFlags_NoMarkers))
   case (4_int32)
      s = ip3_spec(fill_color=CF, flags=ior(ImPlot3DSurfaceFlags_NoLines, ImPlot3DSurfaceFlags_NoMarkers))
   case default
      s = ip3_spec(fill_color=CG, flags=ior(ImPlot3DSurfaceFlags_NoLines, ImPlot3DSurfaceFlags_NoMarkers))
   endselect
   select case (wy)
   case (1_int32) ! contiguous copies
      select case (i)
      case (1_int32); call ip3_line('line', hx, hy, hz, spec=s)
      case (2_int32); call ip3_scatter('markers', hx, hy, hz, spec=s)
      case (3_int32); call ip3_mesh('mesh', hx, hy, hz, tri, spec=s)
      case (4_int32); call ip3_surface('surface', gx, gy, gz, spec=s)
      case default; call ip3_surface('grid', g3(1, :, :) + 0.0_real64, g3(2, :, :) + 0.0_real64, gz, spec=s)
      endselect
   case (2_int32, 6_int32) ! rows of a matrix (a rank-2 array; way 6: the same through the rank-3 array's planes)
      select case (i)
      case (1_int32); call ip3_line('line', hp(1, :), hp(2, :), hp(3, :), spec=s)
      case (2_int32); call ip3_scatter('markers', hp(1, :), hp(2, :), hp(3, :), spec=s)
      case (3_int32); call ip3_mesh('mesh', hp(1, :), hp(2, :), hp(3, :), tri, spec=s)
      case (4_int32); call ip3_surface('surface', gx, gy, g3(3, :, :), spec=s)
      case default; call ip3_surface('grid', g3(1, :, :), g3(2, :, :), g3(3, :, :), spec=s)
      endselect
   case (3_int32) ! mixed strides
      select case (i)
      case (1_int32); call ip3_line('line', hx, hp(2, :), hp(3, :), spec=s)
      case (2_int32); call ip3_scatter('markers', hx, hp(2, :), hp(3, :), spec=s)
      case (3_int32); call ip3_mesh('mesh', hx, hp(2, :), hp(3, :), tri, spec=s)
      case (4_int32); call ip3_surface('surface', gx, gy, gz, spec=s)
      case default; call ip3_surface('grid', g3(1, :, :), g3(2, :, :), gz, spec=s)
      endselect
   case (4_int32) ! reversed sections
      select case (i)
      case (1_int32); call ip3_line('line', hr(N:1:-1, 1), hr(N:1:-1, 2), hr(N:1:-1, 3), spec=s)
      case (2_int32); call ip3_scatter('markers', hr(N:1:-1, 1), hr(N:1:-1, 2), hr(N:1:-1, 3), spec=s)
      case (3_int32); call ip3_mesh('mesh', hr(N:1:-1, 1), hr(N:1:-1, 2), hr(N:1:-1, 3), tri, spec=s)
      case (4_int32); call ip3_surface('surface', gx, gy(NY:1:-1), gz(:, NY:1:-1), spec=s)
      case default; call ip3_surface('grid', g3(1, :, NY:1:-1), g3(2, :, NY:1:-1), gz(:, NY:1:-1), spec=s)
      endselect
   case (5_int32) ! single precision
      select case (i)
      case (1_int32); call ip3_line('line', hs(1, :), hs(2, :), hs(3, :), spec=s)
      case (2_int32); call ip3_scatter('markers', hs(1, :), hs(2, :), hs(3, :), spec=s)
      case (3_int32); call ip3_mesh('mesh', hs(1, :), hs(2, :), hs(3, :), tri, spec=s)
      case (4_int32); call ip3_surface('surface', gx32, gy32, gz32, spec=s)
      case default; call ip3_surface('grid', spread(gx32, 2, NY), spread(gy32, 1, NX), gz32, spec=s)
      endselect
   case default ! a field with a gap between its columns
      select case (i)
      case (1_int32); call ip3_line('line', hx, hy, hz, spec=s)
      case (2_int32); call ip3_scatter('markers', hx, hy, hz, spec=s)
      case (3_int32); call ip3_mesh('mesh', hx, hy, hz, tri, spec=s)
      case (4_int32); call ip3_surface('surface', gx, gy, gzap(1:NX, :), spec=s)
      case default; call ip3_surface('grid', g3(1, :, :), g3(2, :, :), gzap(1:NX, :), spec=s)
      endselect
   endselect
   endsubroutine item

   subroutine statuses(ok)
   !< The refusals.
   logical, intent(out) :: ok    !< Outcome.
   integer(int32)       :: s(14) !< Statuses.
   type(plot3d_spec_object) :: sp !< A spec.
   real(real64)         :: nan   !< A NaN.

   s = FIG_OK
   nan = ieee_value(0.0_real64, ieee_quiet_nan)
   if (window()) then
      call ip3_line('outside', hx, hy, hz, stat=s(1))                                     ! no 3-D plot
      call ip3_setup_axes('x', 'y', 'z', stat=s(2))                                       ! no 3-D plot
      if (ip3_begin_plot('statuses', width=200.0_real64, height=200.0_real64)) then
         call ip3_setup_axes('x', 'y', 'z', limits=[1.0_real64, 0.0_real64, 0.0_real64, 1.0_real64, 0.0_real64, &
                                                    1.0_real64], stat=s(3))               ! xmin > xmax
         call ip3_setup_axes('x', 'y', 'z', limits=[0.0_real64, 1.0_real64], stat=s(4))   ! 2 values
         call ip3_setup_axes('x', 'y', 'z', elevation=10.0_real64, stat=s(5))            ! no azimuth
         call ip3_line('sizes', hx, hy(1:N - 1), hz, stat=s(6))
         call ip3_mesh('rows', hx, hy, hz, reshape(tri, [2, 6]), stat=s(7))
         call ip3_mesh('vertex', hx, hy, hz, tri + N, stat=s(8))
         call ip3_surface('shape', gx(1:NX - 1), gy, gz, stat=s(9))
         call ip3_surface('scale', gx, gy, gz, scale_min=0.0_real64, stat=s(10))
         call ip3_surface('colormap', gx, gy, gz, colormap=-5_int32, stat=s(11))
         call ip3_text('nan', nan, 0.0_real64, 0.0_real64, stat=s(12))
         call ip3_line('helix', hx, hy, hz)
         call ip3_setup_axes('x', 'y', 'z', stat=s(13))                                   ! after an item
         call ip3_end_plot()
      endif
   endif
   call ig_end()
   sp = ip3_spec(line_color=[1.0_real64, 0.0_real64, 0.0_real64], stat=s(14))            ! 3 components
   call idle(1_int32)
   ok = early == FIG_ERR_STATE .and. s(1) == FIG_ERR_STATE .and. s(2) == FIG_ERR_STATE .and. &
        all(s(3:12) == FIG_ERR_ARGUMENT) .and. s(13) == FIG_ERR_STATE .and. s(14) == FIG_ERR_ARGUMENT
   if (.not. ok) write(output_unit, '(A,*(I4))') 'statuses: ', early, s
   endsubroutine statuses

   pure function vec4(c) result(v)
   !< An RGBA colour as an `ImVec4`.
   real(real64), intent(in) :: c(4) !< Colour.
   type(im_vec4)            :: v    !< The same.

   v = im_vec4(real(c(1), c_float), real(c(2), c_float), real(c(3), c_float), real(c(4), c_float))
   endfunction vec4

   subroutine remove_files()
   !< The temporary files.
   character(len=*), parameter :: FILES(2) = [character(len=40) :: SHOT, CSV] !< Files.
   integer(int32)              :: u, ios, k !< Unit, status, counter.

   do k = 1_int32, size(FILES, kind=int32)
      open(newunit=u, file=trim(FILES(k)), status='old', iostat=ios)
      if (ios == 0) close(u, status='delete')
   enddo
   endsubroutine remove_files
endprogram figure_test_plot3d
