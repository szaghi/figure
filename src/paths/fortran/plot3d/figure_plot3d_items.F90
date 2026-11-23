!< figure_plot3d_items, the Fortran 3-D frame's items: lines and markers so far, as ImPlot3D draws them.
module figure_plot3d_items
!< figure_plot3d_items, the Fortran 3-D frame's items: lines and markers so far, as ImPlot3D draws them.
!<
!< szaghi/figure#15 P13, step 4. The items of FIGURE's 3-D API drawn into the Fortran 3-D frame (figure_plot3d_frame),
!< reproduced from implot3d_items.cpp (ImPlot3D 0.6 WIP, FIGURE's copy): `pf3_spec` (the fields of `ip3_spec`),
!< `pf3_line` (`PlotLine`: a strip, `SkipNaN`, `Loop`, `Segments`, per-segment colours, the spec's markers) and
!< `pf3_scatter` (`PlotScatter`: markers, a circle when none is given, per-point colours and sizes), through
!< `BeginItemEx` (the frame's `pf3_item_begin`, the fit of every point) and the renderers: `RendererLineStrip`,
!< `RendererLineStripSkip` (the miter joints of consecutive segments: `PrimLineStrip`, `GetLineJointOffset`),
!< `RendererLineSegments`, `RendererMarkersFill`, `RendererMarkersLine` and the marker tables; each segment clipped to
!< the cull box (Liang-Barsky, `ImPlot3DBox::ClipLineSegment`), each marker culled, each triangle with its depth
!< (`GetPointDepth`) into the 3-D list (figure_plot3d_drawlist), at most 65535 vertices per plot
!< (`RenderPrimitivesEx`). Lines take the anti-aliased line texture (`GetLineRenderProps`), fills the white pixel.
!<
!< The arrays are read in place, any stride, `real32` or `real64` (module pointers to the dummies, which are TARGET:
!< no copy); per-point colours are packed point by point as figure_implot3d packs them. No allocation per item per
!< frame.
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use, intrinsic :: ieee_arithmetic, only : ieee_is_nan
use figure_core, only : core_color, core_line_texture, core_white_pixel
use figure_plot3d_camera, only : view3d, plot_to_pixels, point_depth
use figure_plot3d_drawlist, only : d3_reserve, d3_room, d3_tri, d3_vtx, d3_vtx_count
use figure_plot3d_frame, only : plot3d_spec, item3d_style, pf3_item_begin, pf3_item_end, pf3_item_fit, &
                                pf3_item_fitting, pf3_item_view

implicit none
private
public :: plot3d_spec, pf3_spec, pf3_line, pf3_scatter

interface pf3_line
   !< A line through the points (x(i), y(i), z(i)): `ip3_line`.
   module procedure line_r32, line_r64
endinterface pf3_line

interface pf3_scatter
   !< Markers at the points (x(i), y(i), z(i)): `ip3_scatter`.
   module procedure scatter_r32, scatter_r64
endinterface pf3_scatter

! ImPlot3DLineFlags
integer(int32), parameter :: LF_SEGMENTS = 1024_int32 !< Segments.
integer(int32), parameter :: LF_LOOP = 2048_int32     !< Loop.
integer(int32), parameter :: LF_SKIP_NAN = 4096_int32 !< SkipNaN.
! markers
integer(int32), parameter :: MK_NONE = -2_int32, MK_CIRCLE = 0_int32, MK_SQUARE = 1_int32, MK_DIAMOND = 2_int32, &
                             MK_UP = 3_int32, MK_DOWN = 4_int32, MK_LEFT = 5_int32, MK_RIGHT = 6_int32,          &
                             MK_CROSS = 7_int32, MK_PLUS = 8_int32, MK_ASTERISK = 9_int32 !< ImPlot3DMarker.
real(real32), parameter :: S12 = 0.70710678118_real32 !< SQRT_1_2.
real(real32), parameter :: S32 = 0.86602540378_real32 !< SQRT_3_2.
real(real32), parameter :: FILL_CIRCLE(2, 10) = reshape([1.0_real32, 0.0_real32, 0.809017_real32, 0.58778524_real32, &
   0.30901697_real32, 0.95105654_real32, -0.30901703_real32, 0.9510565_real32, -0.80901706_real32, 0.5877852_real32, &
   -1.0_real32, 0.0_real32, -0.80901694_real32, -0.58778536_real32, -0.3090171_real32, -0.9510565_real32,            &
   0.30901712_real32, -0.9510565_real32, 0.80901694_real32, -0.5877853_real32], [2, 10]) !< MARKER_FILL_CIRCLE.
real(real32), parameter :: FILL_SQUARE(2, 4) = reshape([S12, S12, S12, -S12, -S12, -S12, -S12, S12], [2, 4]) !< ...
real(real32), parameter :: FILL_DIAMOND(2, 4) = reshape([1.0_real32, 0.0_real32, 0.0_real32, -1.0_real32, &
                                                         -1.0_real32, 0.0_real32, 0.0_real32, 1.0_real32], [2, 4]) !< ...
real(real32), parameter :: FILL_UP(2, 3) = reshape([S32, 0.5_real32, 0.0_real32, -1.0_real32, -S32, 0.5_real32], [2, 3])
real(real32), parameter :: FILL_DOWN(2, 3) = reshape([S32, -0.5_real32, 0.0_real32, 1.0_real32, -S32, -0.5_real32], &
                                                     [2, 3]) !< MARKER_FILL_DOWN.
real(real32), parameter :: FILL_LEFT(2, 3) = reshape([-1.0_real32, 0.0_real32, 0.5_real32, S32, 0.5_real32, -S32], &
                                                     [2, 3]) !< MARKER_FILL_LEFT.
real(real32), parameter :: FILL_RIGHT(2, 3) = reshape([1.0_real32, 0.0_real32, -0.5_real32, S32, -0.5_real32, -S32], &
                                                      [2, 3]) !< MARKER_FILL_RIGHT.
real(real32), parameter :: LINE_SQUARE(2, 8) = reshape([S12, S12, S12, -S12, S12, -S12, -S12, -S12, -S12, -S12, &
                                                        -S12, S12, -S12, S12, S12, S12], [2, 8]) !< MARKER_LINE_SQUARE.
real(real32), parameter :: LINE_DIAMOND(2, 8) = reshape([1.0_real32, 0.0_real32, 0.0_real32, -1.0_real32, 0.0_real32, &
   -1.0_real32, -1.0_real32, 0.0_real32, -1.0_real32, 0.0_real32, 0.0_real32, 1.0_real32, 0.0_real32, 1.0_real32,     &
   1.0_real32, 0.0_real32], [2, 8]) !< MARKER_LINE_DIAMOND.
real(real32), parameter :: LINE_UP(2, 6) = reshape([S32, 0.5_real32, 0.0_real32, -1.0_real32, 0.0_real32, -1.0_real32, &
   -S32, 0.5_real32, -S32, 0.5_real32, S32, 0.5_real32], [2, 6]) !< MARKER_LINE_UP.
real(real32), parameter :: LINE_DOWN(2, 6) = reshape([S32, -0.5_real32, 0.0_real32, 1.0_real32, 0.0_real32, 1.0_real32, &
   -S32, -0.5_real32, -S32, -0.5_real32, S32, -0.5_real32], [2, 6]) !< MARKER_LINE_DOWN.
real(real32), parameter :: LINE_LEFT(2, 6) = reshape([-1.0_real32, 0.0_real32, 0.5_real32, S32, 0.5_real32, S32, &
   0.5_real32, -S32, 0.5_real32, -S32, -1.0_real32, 0.0_real32], [2, 6]) !< MARKER_LINE_LEFT.
real(real32), parameter :: LINE_RIGHT(2, 6) = reshape([1.0_real32, 0.0_real32, -0.5_real32, S32, -0.5_real32, S32, &
   -0.5_real32, -S32, -0.5_real32, -S32, 1.0_real32, 0.0_real32], [2, 6]) !< MARKER_LINE_RIGHT.
real(real32), parameter :: LINE_ASTERISK(2, 6) = reshape([-S32, -0.5_real32, S32, 0.5_real32, -S32, 0.5_real32, S32, &
   -0.5_real32, 0.0_real32, -1.0_real32, 0.0_real32, 1.0_real32], [2, 6]) !< MARKER_LINE_ASTERISK.
real(real32), parameter :: LINE_PLUS(2, 4) = reshape([-1.0_real32, 0.0_real32, 1.0_real32, 0.0_real32, 0.0_real32, &
                                                      -1.0_real32, 0.0_real32, 1.0_real32], [2, 4]) !< MARKER_LINE_PLUS.
real(real32), parameter :: LINE_CROSS(2, 4) = reshape([-S12, -S12, S12, S12, S12, -S12, -S12, S12], [2, 4]) !< ...

! the item being drawn: its arrays (one kind set), its view and cull box
real(real32), pointer :: x32(:) => null(), y32(:) => null(), z32(:) => null() !< Single precision arrays.
real(real64), pointer :: x64(:) => null(), y64(:) => null(), z64(:) => null() !< Double precision arrays.
real(real64), pointer :: pcol(:,:) => null() !< Per-point colours (RGBA, 4 x n).
real(real64), pointer :: psize(:) => null()  !< Per-point marker sizes.
logical               :: k64 = .false.       !< The arrays are double precision.
integer(int32)        :: count = 0_int32     !< Points.
type(view3d)          :: v                   !< The plot's view.
real(real64)          :: cmin(3), cmax(3)    !< Cull box.
real(real32)          :: uvw(2)              !< The white pixel's texture coordinates.

contains
   function pf3_spec(line_color, line_weight, fill_color, fill_alpha, marker, marker_size, marker_line_color, &
                     marker_fill_color, flags) result(spec)
   !< As `ip3_spec`: ImPlot3D's item style with the given properties (RGBA in [0, 1]; absent: automatic).
   real(real64),   intent(in), optional :: line_color(:)        !< Line colour, RGBA.
   real(real64),   intent(in), optional :: line_weight          !< Line weight [pixels].
   real(real64),   intent(in), optional :: fill_color(:)        !< Fill colour, RGBA.
   real(real64),   intent(in), optional :: fill_alpha           !< Alpha multiplier of the fills.
   integer(int32), intent(in), optional :: marker               !< Marker (`ImPlot3DMarker_*`).
   real(real64),   intent(in), optional :: marker_size          !< Marker radius [pixels].
   real(real64),   intent(in), optional :: marker_line_color(:) !< Marker outline colour, RGBA.
   real(real64),   intent(in), optional :: marker_fill_color(:) !< Marker fill colour, RGBA.
   integer(int32), intent(in), optional :: flags                !< Item flags.
   type(plot3d_spec)                    :: spec                 !< Style.

   if (present(line_color)) spec%line_color = real(line_color, real32)
   if (present(line_weight)) spec%line_weight = real(line_weight, real32)
   if (present(fill_color)) spec%fill_color = real(fill_color, real32)
   if (present(fill_alpha)) spec%fill_alpha = real(fill_alpha, real32)
   if (present(marker)) spec%marker = marker
   if (present(marker_size)) spec%marker_size = real(marker_size, real32)
   if (present(marker_line_color)) spec%marker_line_color = real(marker_line_color, real32)
   if (present(marker_fill_color)) spec%marker_fill_color = real(marker_fill_color, real32)
   if (present(flags)) spec%flags = flags
   endfunction pf3_spec

   ! the items

   subroutine line_r32(label, x, y, z, spec, colors)
   !< `ip3_line`, single precision.
   character(len=*),  intent(in)                   :: label       !< Legend label.
   real(real32),      intent(in), target           :: x(:), y(:), z(:) !< Points.
   type(plot3d_spec), intent(in), optional         :: spec        !< Style.
   real(real64),      intent(in), target, optional :: colors(:,:) !< Per-point RGBA, (4, size(x)).

   call set_arrays32(x, y, z)
   call line_item(label, spec, colors)
   endsubroutine line_r32

   subroutine line_r64(label, x, y, z, spec, colors)
   !< `ip3_line`, double precision.
   character(len=*),  intent(in)                   :: label       !< Legend label.
   real(real64),      intent(in), target           :: x(:), y(:), z(:) !< Points.
   type(plot3d_spec), intent(in), optional         :: spec        !< Style.
   real(real64),      intent(in), target, optional :: colors(:,:) !< Per-point RGBA, (4, size(x)).

   call set_arrays64(x, y, z)
   call line_item(label, spec, colors)
   endsubroutine line_r64

   subroutine scatter_r32(label, x, y, z, spec, colors, sizes)
   !< `ip3_scatter`, single precision.
   character(len=*),  intent(in)                   :: label       !< Legend label.
   real(real32),      intent(in), target           :: x(:), y(:), z(:) !< Points.
   type(plot3d_spec), intent(in), optional         :: spec        !< Style.
   real(real64),      intent(in), target, optional :: colors(:,:) !< Per-point RGBA, (4, size(x)).
   real(real64),      intent(in), target, optional :: sizes(:)    !< Per-point marker radii.

   call set_arrays32(x, y, z)
   call scatter_item(label, spec, colors, sizes)
   endsubroutine scatter_r32

   subroutine scatter_r64(label, x, y, z, spec, colors, sizes)
   !< `ip3_scatter`, double precision.
   character(len=*),  intent(in)                   :: label       !< Legend label.
   real(real64),      intent(in), target           :: x(:), y(:), z(:) !< Points.
   type(plot3d_spec), intent(in), optional         :: spec        !< Style.
   real(real64),      intent(in), target, optional :: colors(:,:) !< Per-point RGBA, (4, size(x)).
   real(real64),      intent(in), target, optional :: sizes(:)    !< Per-point marker radii.

   call set_arrays64(x, y, z)
   call scatter_item(label, spec, colors, sizes)
   endsubroutine scatter_r64

   subroutine line_item(label, spec, colors)
   !< `PlotLine`/`PlotLineEx`: at least two points; the line (segments, loop, strip, skipping NaNs or not) when drawn,
   !< then the spec's markers.
   character(len=*),  intent(in)                   :: label       !< Legend label.
   type(plot3d_spec), intent(in), optional         :: spec        !< Style.
   real(real64),      intent(in), target, optional :: colors(:,:) !< Per-point RGBA.
   type(plot3d_spec)                               :: sp          !< Style given.
   type(item3d_style)                              :: st          !< Staged.
   real(real32)                                    :: col(4)      !< The item's colour as given.

   if (count < 2_int32) return
   if (present(spec)) sp = spec
   col = sp%line_color
   if (.not. begin_item_ex(label, sp, col, sp%marker, st)) return
   if (present(colors)) pcol => colors
   if (count >= 2_int32 .and. st%render_line) then
      if (iand(sp%flags, LF_SEGMENTS) /= 0_int32) then
         call render_segments(st)
      else
         call render_strip(st, iand(sp%flags, LF_LOOP) /= 0_int32, iand(sp%flags, LF_SKIP_NAN) /= 0_int32)
      endif
   endif
   pcol => null()
   if (st%marker /= MK_NONE) call render_markers(st, .false.)
   call end_item()
   endsubroutine line_item

   subroutine scatter_item(label, spec, colors, sizes)
   !< `PlotScatter`/`PlotScatterEx`: at least a point; markers (a circle when none is given).
   character(len=*),  intent(in)                   :: label       !< Legend label.
   type(plot3d_spec), intent(in), optional         :: spec        !< Style.
   real(real64),      intent(in), target, optional :: colors(:,:) !< Per-point RGBA.
   real(real64),      intent(in), target, optional :: sizes(:)    !< Per-point marker radii.
   type(plot3d_spec)                               :: sp          !< Style given.
   type(item3d_style)                              :: st          !< Staged.

   if (count < 1_int32) return
   if (present(spec)) sp = spec
   if (.not. begin_item_ex(label, sp, sp%marker_line_color, sp%marker, st)) return
   if (st%marker == MK_NONE) st%marker = MK_CIRCLE
   if (present(colors)) pcol => colors
   if (present(sizes)) psize => sizes
   call render_markers(st, present(colors))
   pcol => null()
   psize => null()
   call end_item()
   endsubroutine scatter_item

   function begin_item_ex(label, sp, col, mkr, st) result(shown)
   !< `BeginItemEx`: `BeginItem`, then every point extends the fit.
   character(len=*),   intent(in)  :: label  !< Label.
   type(plot3d_spec),  intent(in)  :: sp     !< Style given.
   real(real32),       intent(in)  :: col(4) !< The colour naming the item.
   integer(int32),     intent(in)  :: mkr    !< The marker naming it.
   type(item3d_style), intent(out) :: st     !< Staged.
   logical                         :: shown  !< Drawn.
   integer(int32)                  :: i      !< Point.
   real(real64)                    :: p(3)   !< A point.
   integer(int32)                  :: flags  !< Plot flags.

   shown = pf3_item_begin(label, sp, col, mkr, st)
   if (.not. shown) then
      call end_item()
      return
   endif
   if (pf3_item_fitting(sp%flags)) then
      do i = 0_int32, count - 1_int32
         call point(i, p)
         call pf3_item_fit(p(1), p(2), p(3))
      enddo
   endif
   call pf3_item_view(v, cmin, cmax, flags)
   endfunction begin_item_ex

   subroutine end_item()
   !< `EndItem`, the arrays forgotten.

   call pf3_item_end()
   x32 => null()
   y32 => null()
   z32 => null()
   x64 => null()
   y64 => null()
   z64 => null()
   count = 0_int32
   endsubroutine end_item

   ! the renderers

   subroutine render_strip(st, loop, skip)
   !< `RendererLineStrip` / `RendererLineStripSkip` (and `GetterLoop`): one quad per segment clipped to the cull box,
   !< joined to the next one at their shared end when the strip goes on through it unclipped.
   type(item3d_style), intent(in) :: st   !< Style.
   logical,            intent(in) :: loop !< Closed.
   logical,            intent(in) :: skip !< NaNs skipped.
   integer(int32)                 :: n, prims, np, k, col !< Points, segments, drawn, segment, colour.
   real(real64)                   :: p1(3), p2(3), p3(3), c1(3), c2(3) !< Points, clipped.
   real(real32)                   :: hw, uv0(2), uv1(2), jpos(2), joff(2) !< Half weight, texture, joint.
   logical                        :: jvalid, vis, has_next !< Joint, visible, continued.

   n = count
   if (loop) n = count + 1_int32
   prims = n - 1_int32
   np = d3_room(prims, 4_int32)
   call d3_reserve(4_int32 * np, 2_int32 * np)
   hw = max(1.0_real32, st%line_weight) * 0.5_real32
   call line_props(hw, uv0, uv1)
   col = 0_int32
   if (.not. associated(pcol)) col = u32(st%line_color)
   call point(modulo_pt(0_int32, loop), p1)
   jvalid = .false.
   jpos = 0.0_real32
   joff = 0.0_real32
   do k = 0_int32, np - 1_int32
      call point(modulo_pt(k + 1_int32, loop), p2)
      vis = .false.
      if (.not. skip .or. (.not. any_nan(p1) .and. .not. any_nan(p2))) then
         vis = clip_segment(p1, p2, c1, c2)
         if (vis) then
            has_next = k + 2_int32 < n .and. contains(p2)
            if (has_next) then
               call point(modulo_pt(k + 2_int32, loop), p3)
               if (skip) has_next = .not. any_nan(p3)
            endif
            if (associated(pcol)) col = packed(modulo_pt(k, loop) + 1_int32)
            call prim_line_strip(jvalid, jpos, joff, c1, c2, p3, has_next, hw, col, uv0, uv1, &
                                 point_depth(v, mid(p1, p2)))
         endif
      endif
      if (.not. vis) jvalid = .false.
      if (skip) then
         if (.not. any_nan(p2)) p1 = p2
      else
         p1 = p2
      endif
   enddo
   endsubroutine render_strip

   subroutine render_segments(st)
   !< `RendererLineSegments`: a quad for each pair of points, clipped (NaN pairs skipped), no joints.
   type(item3d_style), intent(in) :: st !< Style.
   integer(int32)                 :: np, k, col !< Drawn, segment, colour.
   real(real64)                   :: p1(3), p2(3), c1(3), c2(3) !< Points, clipped.
   real(real32)                   :: hw, uv0(2), uv1(2), a(2), b(2), nrm(2), off(2) !< Work.

   np = d3_room(count / 2_int32, 4_int32)
   call d3_reserve(4_int32 * np, 2_int32 * np)
   hw = max(1.0_real32, st%line_weight) * 0.5_real32
   call line_props(hw, uv0, uv1)
   col = 0_int32
   if (.not. associated(pcol)) col = u32(st%line_color)
   do k = 0_int32, np - 1_int32
      call point(2_int32 * k, p1)
      call point(2_int32 * k + 1_int32, p2)
      if (any_nan(p1) .or. any_nan(p2)) cycle
      if (.not. clip_segment(p1, p2, c1, c2)) cycle
      call plot_to_pixels(v, c1, a(1), a(2))
      call plot_to_pixels(v, c2, b(1), b(2))
      call line_normal(a, b, nrm)
      off = nrm * hw
      if (associated(pcol)) col = packed(k + 1_int32)
      call prim_line(a, b, off, off, col, uv0, uv1, point_depth(v, mid(p1, p2)))
   enddo
   endsubroutine render_segments

   subroutine render_markers(st, idx_colors)
   !< `RenderColoredMarkers`, `RenderMarkers`: the filled shapes (when fill is drawn), then the outlines (when lines
   !< are), constant or per-point colours (fills with the fill alpha) and sizes.
   type(item3d_style), intent(in) :: st         !< Style.
   logical,            intent(in) :: idx_colors !< Per-point colours (fill and outline).

   if (st%render_mfill) then
      select case (st%marker)
      case (MK_CIRCLE)
         call markers_fill(st, FILL_CIRCLE, idx_colors)
      case (MK_SQUARE)
         call markers_fill(st, FILL_SQUARE, idx_colors)
      case (MK_DIAMOND)
         call markers_fill(st, FILL_DIAMOND, idx_colors)
      case (MK_UP)
         call markers_fill(st, FILL_UP, idx_colors)
      case (MK_DOWN)
         call markers_fill(st, FILL_DOWN, idx_colors)
      case (MK_LEFT)
         call markers_fill(st, FILL_LEFT, idx_colors)
      case (MK_RIGHT)
         call markers_fill(st, FILL_RIGHT, idx_colors)
      endselect
   endif
   if (st%render_mline) then
      select case (st%marker)
      case (MK_CIRCLE)
         call markers_line_circle(st, idx_colors)
      case (MK_SQUARE)
         call markers_line(st, LINE_SQUARE, idx_colors)
      case (MK_DIAMOND)
         call markers_line(st, LINE_DIAMOND, idx_colors)
      case (MK_UP)
         call markers_line(st, LINE_UP, idx_colors)
      case (MK_DOWN)
         call markers_line(st, LINE_DOWN, idx_colors)
      case (MK_LEFT)
         call markers_line(st, LINE_LEFT, idx_colors)
      case (MK_RIGHT)
         call markers_line(st, LINE_RIGHT, idx_colors)
      case (MK_ASTERISK)
         call markers_line(st, LINE_ASTERISK, idx_colors)
      case (MK_PLUS)
         call markers_line(st, LINE_PLUS, idx_colors)
      case (MK_CROSS)
         call markers_line(st, LINE_CROSS, idx_colors)
      endselect
   endif
   endsubroutine render_markers

   subroutine markers_fill(st, shape, idx_colors)
   !< `RendererMarkersFill`: each point in the cull box a fan of the shape's triangles, its depth the point's.
   type(item3d_style), intent(in) :: st          !< Style.
   real(real32),       intent(in) :: shape(:,:)  !< Shape (2, n).
   logical,            intent(in) :: idx_colors  !< Per-point colours.
   integer(int32)                 :: m, np, k, i, base, col, ccol !< Shape's points, drawn, point, vertex, colours.
   real(real64)                   :: q(3), z     !< Point, depth.
   real(real32)                   :: px, py, sz  !< Pixel, size.

   m = size(shape, 2, kind=int32)
   np = d3_room(count, m)
   call d3_reserve(m * np, (m - 2_int32) * np)
   ccol = u32(st%mfill_color)
   do k = 0_int32, np - 1_int32
      call point(k, q)
      if (.not. contains(q)) cycle
      call plot_to_pixels(v, q, px, py)
      col = ccol
      if (idx_colors) col = with_alpha(packed(k + 1_int32), st%fill_alpha)
      sz = msize(st, k)
      base = d3_vtx_count()
      do i = 1_int32, m
         call d3_vtx(px + shape(1, i) * sz, py + shape(2, i) * sz, uvw(1), uvw(2), col)
      enddo
      z = point_depth(v, q)
      do i = 2_int32, m - 1_int32
         call d3_tri(base, base + i - 1_int32, base + i, z)
      enddo
   enddo
   endsubroutine markers_fill

   subroutine markers_line(st, shape, idx_colors)
   !< `RendererMarkersLine`: each point in the cull box the shape's segments as quads, its depth the point's.
   type(item3d_style), intent(in) :: st          !< Style.
   real(real32),       intent(in) :: shape(:,:)  !< Segments' ends (2, 2 n).
   logical,            intent(in) :: idx_colors  !< Per-point colours.
   integer(int32)                 :: m, np, k, i, col, ccol !< Ends, drawn, point, end, colours.
   real(real64)                   :: q(3), z     !< Point, depth.
   real(real32)                   :: px, py, sz, hw, uv0(2), uv1(2), a(2), b(2), nrm(2), off(2) !< Work.

   m = size(shape, 2, kind=int32)
   np = d3_room(count, m / 2_int32 * 4_int32)
   call d3_reserve(m / 2_int32 * 4_int32 * np, m / 2_int32 * 2_int32 * np)
   hw = max(1.0_real32, st%line_weight) * 0.5_real32
   call line_props(hw, uv0, uv1)
   ccol = u32(st%mline_color)
   do k = 0_int32, np - 1_int32
      call point(k, q)
      if (.not. contains(q)) cycle
      call plot_to_pixels(v, q, px, py)
      col = ccol
      if (idx_colors) col = packed(k + 1_int32)
      sz = msize(st, k)
      z = point_depth(v, q)
      do i = 1_int32, m, 2_int32
         a(1) = px + shape(1, i) * sz
         a(2) = py + shape(2, i) * sz
         b(1) = px + shape(1, i + 1_int32) * sz
         b(2) = py + shape(2, i + 1_int32) * sz
         call line_normal(a, b, nrm)
         off = nrm * hw
         call prim_line(a, b, off, off, col, uv0, uv1, z)
      enddo
   enddo
   endsubroutine markers_line

   subroutine markers_line_circle(st, idx_colors)
   !< The circle's outline: MARKER_LINE_CIRCLE, the fill circle's ten points as twenty segment ends.
   type(item3d_style), intent(in) :: st         !< Style.
   logical,            intent(in) :: idx_colors !< Per-point colours.
   real(real32)                   :: c(2, 20)   !< Segments' ends.
   integer(int32)                 :: i          !< Segment.

   do i = 1_int32, 10_int32
      c(:, 2_int32 * i - 1_int32) = FILL_CIRCLE(:, i)
      c(:, 2_int32 * i) = FILL_CIRCLE(:, mod(i, 10_int32) + 1_int32)
   enddo
   call markers_line(st, c, idx_colors)
   endsubroutine markers_line_circle

   ! primitives

   subroutine prim_line_strip(jvalid, jpos, joff, p1, p2, p3, has_next, hw, col, uv0, uv1, z)
   !< `PrimLineStrip`: the clipped segment p1-p2 (from the joint when valid), its end offset along the miter with the
   !< next segment when the strip goes on; the joint updated.
   logical,        intent(inout) :: jvalid       !< Joint valid.
   real(real32),   intent(inout) :: jpos(2)      !< Joint position.
   real(real32),   intent(inout) :: joff(2)      !< Joint offset.
   real(real64),   intent(in)    :: p1(3), p2(3) !< Clipped ends.
   real(real64),   intent(in)    :: p3(3)        !< Next point.
   logical,        intent(in)    :: has_next     !< The strip goes on.
   real(real32),   intent(in)    :: hw           !< Half weight.
   integer(int32), intent(in)    :: col          !< Colour.
   real(real32),   intent(in)    :: uv0(2), uv1(2) !< Texture.
   real(real64),   intent(in)    :: z            !< Depth.
   real(real32)                  :: a(2), b(2), c(2), nrm(2), n2(2), o1(2), o2(2) !< Work.

   if (jvalid) then
      a = jpos
   else
      call plot_to_pixels(v, p1, a(1), a(2))
   endif
   call plot_to_pixels(v, p2, b(1), b(2))
   call line_normal(a, b, nrm)
   if (jvalid) then
      o1 = joff
   else
      o1 = nrm * hw
   endif
   o2 = nrm * hw
   jvalid = .false.
   if (has_next) then
      call plot_to_pixels(v, p3, c(1), c(2))
      call line_normal(b, c, n2)
      jvalid = joint_offset(nrm, n2, hw, o2)
   endif
   jpos = b
   joff = o2
   call prim_line(a, b, o1, o2, col, uv0, uv1, z)
   endsubroutine prim_line_strip

   subroutine prim_line(a, b, o1, o2, col, uv0, uv1, z)
   !< `PrimLine`: the quad a + o1, b + o2, b - o2, a - o1 (two triangles, the same depth).
   real(real32),   intent(in) :: a(2), b(2), o1(2), o2(2) !< Ends, offsets.
   integer(int32), intent(in) :: col             !< Colour.
   real(real32),   intent(in) :: uv0(2), uv1(2)  !< Texture.
   real(real64),   intent(in) :: z               !< Depth.
   integer(int32)             :: base            !< First vertex.

   base = d3_vtx_count()
   call d3_vtx(a(1) + o1(1), a(2) + o1(2), uv0(1), uv0(2), col)
   call d3_vtx(b(1) + o2(1), b(2) + o2(2), uv0(1), uv0(2), col)
   call d3_vtx(b(1) - o2(1), b(2) - o2(2), uv1(1), uv1(2), col)
   call d3_vtx(a(1) - o1(1), a(2) - o1(2), uv1(1), uv1(2), col)
   call d3_tri(base, base + 1_int32, base + 2_int32, z)
   call d3_tri(base, base + 2_int32, base + 3_int32, z)
   endsubroutine prim_line

   pure subroutine line_normal(a, b, nrm)
   !< `GetLineNormal`: the unit normal (dy, -dx) of a-b ((0, 0) for a null segment; 1/sqrtf, FIGURE's ImRsqrt).
   real(real32), intent(in)  :: a(2), b(2) !< Ends.
   real(real32), intent(out) :: nrm(2)     !< Normal.
   real(real32)              :: dx, dy, d2, inv !< Work.

   dx = b(1) - a(1)
   dy = b(2) - a(2)
   d2 = dx * dx + dy * dy
   if (d2 > 0.0_real32) then
      inv = 1.0_real32 / sqrt(d2)
      dx = dx * inv
      dy = dy * inv
   endif
   nrm(1) = dy
   nrm(2) = -dx
   endsubroutine line_normal

   function joint_offset(n1, n2, hw, off) result(ok)
   !< `GetLineJointOffset`: the offset to the edge two segments share (false for a null segment or a turn sharper
   !< than 120 degrees).
   real(real32), intent(in)    :: n1(2), n2(2) !< Normals.
   real(real32), intent(in)    :: hw           !< Half weight.
   real(real32), intent(inout) :: off(2)       !< Offset (set when true).
   logical                     :: ok           !< Joined.
   real(real32)                :: mx, my, d2   !< Mean normal, its squared length.

   ok = .false.
   if ((n1(1) == 0.0_real32 .and. n1(2) == 0.0_real32) .or. (n2(1) == 0.0_real32 .and. n2(2) == 0.0_real32)) return
   mx = (n1(1) + n2(1)) * 0.5_real32
   my = (n1(2) + n2(2)) * 0.5_real32
   d2 = mx * mx + my * my
   if (.not. (d2 >= 0.25_real32)) return
   off(1) = mx / d2 * hw
   off(2) = my / d2 * hw
   ok = .true.
   endfunction joint_offset

   subroutine line_props(hw, uv0, uv1)
   !< `GetLineRenderProps`: the line texture of a line 2 hw wide, hw grown by half the fringe.
   real(real32), intent(inout) :: hw             !< Half weight.
   real(real32), intent(out)   :: uv0(2), uv1(2) !< Texture.
   real(real64)                :: a(2), b(2), fr !< C values.

   call core_line_texture(real(hw * 2.0_real32, real64), a, b, fr)
   uv0 = real(a, real32)
   uv1 = real(b, real32)
   hw = hw + 0.5_real32 * real(fr, real32)
   call white_uv()
   endsubroutine line_props

   subroutine white_uv()
   !< The white pixel's texture coordinates.
   real(real64) :: u, w !< C values.

   call core_white_pixel(u, w)
   uvw(1) = real(u, real32)
   uvw(2) = real(w, real32)
   endsubroutine white_uv

   ! points, colours

   subroutine set_arrays32(x, y, z)
   !< The item's arrays, single precision (sizes checked).
   real(real32), intent(in), target :: x(:), y(:), z(:) !< Arrays.

   if (size(x) /= size(y) .or. size(x) /= size(z)) error stop 'figure_plot3d_items: the series have different sizes'
   x32 => x
   y32 => y
   z32 => z
   k64 = .false.
   count = size(x, kind=int32)
   call white_uv()
   endsubroutine set_arrays32

   subroutine set_arrays64(x, y, z)
   !< The item's arrays, double precision (sizes checked).
   real(real64), intent(in), target :: x(:), y(:), z(:) !< Arrays.

   if (size(x) /= size(y) .or. size(x) /= size(z)) error stop 'figure_plot3d_items: the series have different sizes'
   x64 => x
   y64 => y
   z64 => z
   k64 = .true.
   count = size(x, kind=int32)
   call white_uv()
   endsubroutine set_arrays64

   subroutine point(i, p)
   !< Point i (0-based) as double (`GetterXYZ`).
   integer(int32), intent(in)  :: i    !< Index.
   real(real64),   intent(out) :: p(3) !< Point.

   if (k64) then
      p(1) = x64(i + 1_int32)
      p(2) = y64(i + 1_int32)
      p(3) = z64(i + 1_int32)
   else
      p(1) = real(x32(i + 1_int32), real64)
      p(2) = real(y32(i + 1_int32), real64)
      p(3) = real(z32(i + 1_int32), real64)
   endif
   endsubroutine point

   pure function modulo_pt(i, loop) result(j)
   !< `GetterLoop`'s index: i modulo the points (a loop), else i.
   integer(int32), intent(in) :: i    !< Index.
   logical,        intent(in) :: loop !< A loop.
   integer(int32)             :: j    !< Point.

   j = i
   if (loop) j = mod(i, count)
   endfunction modulo_pt

   pure function mid(a, b) result(m)
   !< `(a + b) * 0.5`.
   real(real64), intent(in) :: a(3), b(3) !< Points.
   real(real64)             :: m(3)       !< Middle.

   m(1) = (a(1) + b(1)) * 0.5_real64
   m(2) = (a(2) + b(2)) * 0.5_real64
   m(3) = (a(3) + b(3)) * 0.5_real64
   endfunction mid

   pure function any_nan(p) result(yes)
   !< A NaN coordinate.
   real(real64), intent(in) :: p(3) !< Point.
   logical                  :: yes  !< NaN.

   yes = ieee_is_nan(p(1)) .or. ieee_is_nan(p(2)) .or. ieee_is_nan(p(3))
   endfunction any_nan

   function contains(p) result(yes)
   !< `ImPlot3DBox::Contains` of the cull box.
   real(real64), intent(in) :: p(3) !< Point.
   logical                  :: yes  !< Inside.

   yes = (p(1) >= cmin(1) .and. p(1) <= cmax(1)) .and. (p(2) >= cmin(2) .and. p(2) <= cmax(2)) .and. &
         (p(3) >= cmin(3) .and. p(3) <= cmax(3))
   endfunction contains

   function clip_segment(p0, p1, c0, c1) result(visible)
   !< `ImPlot3DBox::ClipLineSegment` (Liang-Barsky) on the cull box.
   real(real64), intent(in)  :: p0(3), p1(3) !< Segment.
   real(real64), intent(out) :: c0(3), c1(3) !< Clipped.
   logical                   :: visible      !< Some of it inside.
   real(real64)              :: t0, t1, d(3) !< Parameters, direction.

   if (contains(p0) .and. contains(p1)) then
      c0 = p0
      c1 = p1
      visible = .true.
      return
   endif
   visible = .false.
   c0 = p0
   c1 = p1
   t0 = 0.0_real64
   t1 = 1.0_real64
   d = p1 - p0
   if (.not. clip_update(-d(1), p0(1) - cmin(1), t0, t1)) return
   if (.not. clip_update(d(1), cmax(1) - p0(1), t0, t1)) return
   if (.not. clip_update(-d(2), p0(2) - cmin(2), t0, t1)) return
   if (.not. clip_update(d(2), cmax(2) - p0(2), t0, t1)) return
   if (.not. clip_update(-d(3), p0(3) - cmin(3), t0, t1)) return
   if (.not. clip_update(d(3), cmax(3) - p0(3), t0, t1)) return
   c0 = p0 + d * t0
   c1 = p0 + d * t1
   visible = .true.
   endfunction clip_segment

   function clip_update(pp, q, t0, t1) result(ok)
   !< Liang-Barsky's update of the parameters for one boundary.
   real(real64), intent(in)    :: pp, q  !< Direction's component, distance.
   real(real64), intent(inout) :: t0, t1 !< Parameters.
   logical                     :: ok     !< Still inside.
   real(real64)                :: r      !< Ratio.

   ok = .true.
   if (pp == 0.0_real64) then
      ok = .not. (q < 0.0_real64)
      return
   endif
   r = q / pp
   if (pp < 0.0_real64) then
      if (r > t1) then
         ok = .false.
         return
      endif
      if (r > t0) t0 = r
   else
      if (r < t0) then
         ok = .false.
         return
      endif
      if (r < t1) t1 = r
   endif
   endfunction clip_update

   function u32(c) result(col)
   !< `GetColorU32(ImVec4)`: a colour packed (the style's alpha 1).
   real(real32), intent(in) :: c(4) !< RGBA.
   integer(int32)           :: col  !< Packed.

   col = core_color(real(c(1), real64), real(c(2), real64), real(c(3), real64), real(c(4), real64))
   endfunction u32

   function packed(i) result(col)
   !< Point i's colour (1-based) packed as figure_implot3d packs `colors` (in double, each channel rounded half up).
   integer(int32), intent(in) :: i   !< Point.
   integer(int32)             :: col !< Packed.
   integer(int64)             :: c(4), w !< Channels, packed.
   integer(int32)             :: k   !< Channel.

   do k = 1_int32, 4_int32
      c(k) = int(min(max(pcol(k, i), 0.0_real64), 1.0_real64) * 255.0_real64 + 0.5_real64, int64)
   enddo
   w = c(1) + c(2) * 256_int64 + c(3) * 65536_int64 + c(4) * 16777216_int64
   if (w >= 2147483648_int64) w = w - 4294967296_int64
   col = int(w, int32)
   endfunction packed

   function with_alpha(col, alpha) result(c)
   !< `GetterIdxColor` with an alpha below 1: unpacked, its alpha times `alpha`, packed again.
   integer(int32), intent(in) :: col   !< Packed colour.
   real(real32),   intent(in) :: alpha !< Fill alpha.
   integer(int32)             :: c     !< Colour.
   integer(int64)             :: u     !< Unsigned.
   real(real32)               :: f(4)  !< Channels.
   integer(int32)             :: k     !< Channel.

   c = col
   if (.not. (alpha < 1.0_real32)) return
   u = iand(int(col, int64), 4294967295_int64)
   do k = 1_int32, 4_int32
      f(k) = real(iand(ishft(u, -8 * (k - 1_int32)), 255_int64), real32) * (1.0_real32 / 255.0_real32)
   enddo
   f(4) = f(4) * alpha
   c = u32(f)
   endfunction with_alpha

   function msize(st, k) result(sz)
   !< Point k's (0-based) marker size: its own, or the style's.
   type(item3d_style), intent(in) :: st !< Style.
   integer(int32),     intent(in) :: k  !< Point.
   real(real32)                   :: sz !< Size.

   sz = st%marker_size
   if (associated(psize)) sz = real(psize(k + 1_int32), real32)
   endfunction msize
endmodule figure_plot3d_items
