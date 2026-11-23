!< figure_plot3d_items, the Fortran 3-D frame's items: lines, markers, triangles, quads, surfaces, meshes, images.
module figure_plot3d_items
!< figure_plot3d_items, the Fortran 3-D frame's items: lines, markers, triangles, quads, surfaces, meshes, images.
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
!< Step 5: `pf3_triangles` and `pf3_quads` (`PlotTriangle`, `PlotQuad`: `RendererTriangleFill`, `RendererQuadFill`,
!< their edges through `GetterTriangleLines`/`GetterQuadLines`), `pf3_surface` on a rectilinear grid or any grid
!< (`PlotSurface`: `RendererSurfaceFill`, a cell's two triangles each with its depth, coloured by the colormap pushed
!< for the item (`SampleColormap` of the heights between the scale's ends), the grid lines (`GetterSurfaceLines`)),
!< `pf3_mesh` (`PlotMesh`: the user's 1-based triangles read in place (`GetterMeshTriangles`), edges only with a line
!< colour), `pf3_image` (`PlotImage`: a textured quad, the texture's run in the 3-D list, the v coordinates flipped).
!< `pf3_text` is the frame's.
!<
!< The arrays are read in place, any stride, `real32` or `real64` (module pointers to the dummies, which are TARGET:
!< no copy); per-point colours are packed point by point as figure_implot3d packs them. No allocation per item per
!< frame.
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use, intrinsic :: ieee_arithmetic, only : ieee_is_finite, ieee_is_nan
use figure_core, only : core_color, core_line_texture, core_white_pixel
use figure_plot_colormaps, only : cm_sample
use figure_texture, only : texture_object, texture_ref
use figure_cimgui, only : im_texture_ref
use figure_plot3d_camera, only : view3d, plot_to_pixels, point_depth
use figure_plot3d_style, only : style3_color_u32
use figure_plot3d_drawlist, only : d3_reserve, d3_room, d3_set_texture, d3_tri, d3_vtx, d3_vtx_count
use figure_plot3d_frame, only : plot3d_spec, item3d_style, pf3_item_begin, pf3_item_end, pf3_item_fit, &
                                pf3_item_fitting, pf3_item_view, pf3_push_colormap, pf3_pop_colormap,  &
                                pf3_item_recolor, pf3_colormap, pf3_text

implicit none
private
public :: plot3d_spec, pf3_spec, pf3_line, pf3_scatter, pf3_triangles, pf3_quads, pf3_surface, pf3_mesh, pf3_image
public :: pf3_text

interface pf3_line
   !< A line through the points (x(i), y(i), z(i)): `ip3_line`.
   module procedure line_r32, line_r64
endinterface pf3_line

interface pf3_scatter
   !< Markers at the points (x(i), y(i), z(i)): `ip3_scatter`.
   module procedure scatter_r32, scatter_r64
endinterface pf3_scatter

interface pf3_triangles
   !< Triangles, each three points in a row: `ip3_triangles`.
   module procedure triangles_r32, triangles_r64
endinterface pf3_triangles

interface pf3_quads
   !< Quadrilaterals, each four points in a row: `ip3_quads`.
   module procedure quads_r32, quads_r64
endinterface pf3_quads

interface pf3_surface
   !< A surface z(i, j) over a grid: `ip3_surface`.
   module procedure surface_r32, surface_r64, surface_grid_r32, surface_grid_r64
endinterface pf3_surface

interface pf3_mesh
   !< A mesh of triangles: `ip3_mesh`.
   module procedure mesh_r32, mesh_r64
endinterface pf3_mesh

! ImPlot3DLineFlags
integer(int32), parameter :: LF_SEGMENTS = 1024_int32 !< Segments.
integer(int32), parameter :: LF_LOOP = 2048_int32     !< Loop.
integer(int32), parameter :: LF_SKIP_NAN = 4096_int32 !< SkipNaN.
integer(int32), parameter :: F_NO_LINES = 1024_int32   !< ImPlot3DTriangleFlags/Quad/Surface/Mesh _NoLines.
integer(int32), parameter :: F_NO_FILL = 2048_int32    !< ... _NoFill.
integer(int32), parameter :: F_NO_MARKERS = 4096_int32 !< ... _NoMarkers.
! getters
integer(int32), parameter :: G_SERIES = 0_int32  !< The points x(i), y(i), z(i) (`GetterXYZ`).
integer(int32), parameter :: G_RECT = 1_int32    !< A rectilinear grid's vertices x(i), y(j), z(i, j).
integer(int32), parameter :: G_GRID = 2_int32    !< A grid's vertices x(i, j), y(i, j), z(i, j).
integer(int32), parameter :: G_MESH = 3_int32    !< A mesh's triangles' corners (`GetterMeshTriangles`).
integer(int32), parameter :: G_CORNERS = 4_int32 !< An image's four corners (`Getter3DPoints`).
integer(int32), parameter :: L_NONE = 0_int32, L_TRI = 1_int32, L_QUAD = 2_int32, L_SURF = 3_int32 !< Line getters.
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
real(real32), pointer :: x2_32(:,:) => null(), y2_32(:,:) => null(), z2_32(:,:) => null() !< Grids, single.
real(real64), pointer :: x2_64(:,:) => null(), y2_64(:,:) => null(), z2_64(:,:) => null() !< Grids, double.
integer(int32), pointer :: tri(:,:) => null() !< A mesh's triangles (3, n), 1-based.
real(real64)          :: corners4(3, 4) = 0.0_real64 !< An image's corners.
integer(int32)        :: gmode = G_SERIES    !< The base getter.
integer(int32)        :: nx = 0_int32        !< A grid's first extent (x_count).
integer(int32)        :: ny = 0_int32        !< ... its second (y_count).
integer(int32)        :: base_count = 0_int32 !< The base getter's points (the mesh's vertices for its fit).
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
      if (gmode == G_MESH) then ! BeginItemEx's getter: the vertices
         do i = 0_int32, base_count - 1_int32
            call vertex(i, p)
            call pf3_item_fit(p(1), p(2), p(3))
         enddo
      else
         do i = 0_int32, count - 1_int32
            call point(i, p)
            call pf3_item_fit(p(1), p(2), p(3))
         enddo
      endif
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
   x2_32 => null()
   y2_32 => null()
   z2_32 => null()
   x2_64 => null()
   y2_64 => null()
   z2_64 => null()
   tri => null()
   gmode = G_SERIES
   count = 0_int32
   endsubroutine end_item


   ! triangles, quads, surfaces, meshes, images

   subroutine triangles_r32(label, x, y, z, spec)
   !< `ip3_triangles`, single precision.
   character(len=*),  intent(in)           :: label            !< Legend label.
   real(real32),      intent(in), target   :: x(:), y(:), z(:) !< Vertices, three per triangle.
   type(plot3d_spec), intent(in), optional :: spec             !< Style.

   call set_arrays32(x, y, z)
   call poly_item(label, 3_int32, spec)
   endsubroutine triangles_r32

   subroutine triangles_r64(label, x, y, z, spec)
   !< `ip3_triangles`, double precision.
   character(len=*),  intent(in)           :: label            !< Legend label.
   real(real64),      intent(in), target   :: x(:), y(:), z(:) !< Vertices, three per triangle.
   type(plot3d_spec), intent(in), optional :: spec             !< Style.

   call set_arrays64(x, y, z)
   call poly_item(label, 3_int32, spec)
   endsubroutine triangles_r64

   subroutine quads_r32(label, x, y, z, spec)
   !< `ip3_quads`, single precision.
   character(len=*),  intent(in)           :: label            !< Legend label.
   real(real32),      intent(in), target   :: x(:), y(:), z(:) !< Vertices, four per quad.
   type(plot3d_spec), intent(in), optional :: spec             !< Style.

   call set_arrays32(x, y, z)
   call poly_item(label, 4_int32, spec)
   endsubroutine quads_r32

   subroutine quads_r64(label, x, y, z, spec)
   !< `ip3_quads`, double precision.
   character(len=*),  intent(in)           :: label            !< Legend label.
   real(real64),      intent(in), target   :: x(:), y(:), z(:) !< Vertices, four per quad.
   type(plot3d_spec), intent(in), optional :: spec             !< Style.

   call set_arrays64(x, y, z)
   call poly_item(label, 4_int32, spec)
   endsubroutine quads_r64

   subroutine poly_item(label, nside, spec)
   !< `PlotTriangleEx` / `PlotQuadEx`: at least 3 points; the fill (the fill colour), the edges (the line colour),
   !< the markers, each unless its flag.
   character(len=*),  intent(in)           :: label !< Legend label.
   integer(int32),    intent(in)           :: nside !< 3 or 4.
   type(plot3d_spec), intent(in), optional :: spec  !< Style.
   type(plot3d_spec)                       :: sp    !< Style given.
   type(item3d_style)                      :: st    !< Staged.

   if (count < 3_int32) then
      call end_item()
      return
   endif
   if (present(spec)) sp = spec
   if (.not. begin_item_ex(label, sp, sp%fill_color, sp%marker, st)) return
   if (count >= nside .and. st%render_fill .and. iand(sp%flags, F_NO_FILL) == 0_int32) &
      call render_fill(nside, style3_color_u32(st%fill_color))
   if (count >= 2_int32 .and. st%render_line .and. iand(sp%flags, F_NO_LINES) == 0_int32) &
      call render_segments(st, merge(L_TRI, L_QUAD, nside == 3_int32))
   if (st%marker /= MK_NONE .and. iand(sp%flags, F_NO_MARKERS) == 0_int32) call render_markers(st, .false.)
   call end_item()
   endsubroutine poly_item

   subroutine surface_r32(label, x, y, z, colormap, scale_min, scale_max, spec)
   !< `ip3_surface` over a rectilinear grid, single precision.
   character(len=*),  intent(in)           :: label     !< Legend label.
   real(real32),      intent(in), target   :: x(:), y(:) !< The grid's abscissae (size(z, 1)), ordinates (size(z, 2)).
   real(real32),      intent(in), target   :: z(:,:)    !< Heights.
   integer(int32),    intent(in), optional :: colormap  !< Colormap (default Viridis).
   real(real64),      intent(in), optional :: scale_min !< Height at the first colour.
   real(real64),      intent(in), optional :: scale_max !< Height at the last colour.
   type(plot3d_spec), intent(in), optional :: spec      !< Style.

   if (size(x) /= size(z, 1) .or. size(y) /= size(z, 2)) error stop 'figure_plot3d_items: pf3_surface: x, y and z'
   x32 => x
   y32 => y
   z2_32 => z
   k64 = .false.
   call surface_item(label, G_RECT, size(z, 1, kind=int32), size(z, 2, kind=int32), surface_range32(z, scale_min, &
                     scale_max), colormap, spec)
   endsubroutine surface_r32

   subroutine surface_r64(label, x, y, z, colormap, scale_min, scale_max, spec)
   !< `ip3_surface` over a rectilinear grid, double precision.
   character(len=*),  intent(in)           :: label     !< Legend label.
   real(real64),      intent(in), target   :: x(:), y(:) !< The grid's abscissae (size(z, 1)), ordinates (size(z, 2)).
   real(real64),      intent(in), target   :: z(:,:)    !< Heights.
   integer(int32),    intent(in), optional :: colormap  !< Colormap (default Viridis).
   real(real64),      intent(in), optional :: scale_min !< Height at the first colour.
   real(real64),      intent(in), optional :: scale_max !< Height at the last colour.
   type(plot3d_spec), intent(in), optional :: spec      !< Style.

   if (size(x) /= size(z, 1) .or. size(y) /= size(z, 2)) error stop 'figure_plot3d_items: pf3_surface: x, y and z'
   x64 => x
   y64 => y
   z2_64 => z
   k64 = .true.
   call surface_item(label, G_RECT, size(z, 1, kind=int32), size(z, 2, kind=int32), surface_range64(z, scale_min, &
                     scale_max), colormap, spec)
   endsubroutine surface_r64

   subroutine surface_grid_r32(label, x, y, z, colormap, scale_min, scale_max, spec)
   !< `ip3_surface` over any grid of quadrilaterals, single precision.
   character(len=*),  intent(in)           :: label     !< Legend label.
   real(real32),      intent(in), target   :: x(:,:), y(:,:), z(:,:) !< Vertices.
   integer(int32),    intent(in), optional :: colormap  !< Colormap (default Viridis).
   real(real64),      intent(in), optional :: scale_min !< Height at the first colour.
   real(real64),      intent(in), optional :: scale_max !< Height at the last colour.
   type(plot3d_spec), intent(in), optional :: spec      !< Style.

   if (any(shape(x) /= shape(z)) .or. any(shape(y) /= shape(z))) error stop 'figure_plot3d_items: pf3_surface: shapes'
   x2_32 => x
   y2_32 => y
   z2_32 => z
   k64 = .false.
   call surface_item(label, G_GRID, size(z, 1, kind=int32), size(z, 2, kind=int32), surface_range32(z, scale_min, &
                     scale_max), colormap, spec)
   endsubroutine surface_grid_r32

   subroutine surface_grid_r64(label, x, y, z, colormap, scale_min, scale_max, spec)
   !< `ip3_surface` over any grid of quadrilaterals, double precision.
   character(len=*),  intent(in)           :: label     !< Legend label.
   real(real64),      intent(in), target   :: x(:,:), y(:,:), z(:,:) !< Vertices.
   integer(int32),    intent(in), optional :: colormap  !< Colormap (default Viridis).
   real(real64),      intent(in), optional :: scale_min !< Height at the first colour.
   real(real64),      intent(in), optional :: scale_max !< Height at the last colour.
   type(plot3d_spec), intent(in), optional :: spec      !< Style.

   if (any(shape(x) /= shape(z)) .or. any(shape(y) /= shape(z))) error stop 'figure_plot3d_items: pf3_surface: shapes'
   x2_64 => x
   y2_64 => y
   z2_64 => z
   k64 = .true.
   call surface_item(label, G_GRID, size(z, 1, kind=int32), size(z, 2, kind=int32), surface_range64(z, scale_min, &
                     scale_max), colormap, spec)
   endsubroutine surface_grid_r64

   subroutine surface_item(label, mode, mx, my, lohi, colormap, spec)
   !< As figure_implot3d draws a surface: the colormap pushed (default Viridis), `PlotSurface` (at least 4 vertices;
   !< the fill (`RendererSurfaceFill`), the grid lines, the markers, each unless its flag), the colormap popped.
   character(len=*),  intent(in)           :: label    !< Legend label.
   integer(int32),    intent(in)           :: mode     !< G_RECT or G_GRID.
   integer(int32),    intent(in)           :: mx, my   !< x_count, y_count.
   real(real64),      intent(in)           :: lohi(2)  !< Heights at the first and last colours.
   integer(int32),    intent(in), optional :: colormap !< Colormap.
   type(plot3d_spec), intent(in), optional :: spec     !< Style.
   type(plot3d_spec)                       :: sp       !< Style given.
   type(item3d_style)                      :: st       !< Staged.
   integer(int32)                          :: cm       !< Colormap.

   gmode = mode
   nx = mx
   ny = my
   count = mx * my
   call white_uv()
   cm = 4_int32 ! ImPlotColormap_Viridis
   if (present(colormap)) cm = colormap
   call pf3_push_colormap(cm)
   if (count >= 4_int32) then
      if (present(spec)) sp = spec
      if (begin_item_ex(label, sp, sp%fill_color, sp%marker, st)) then
         if (count >= 4_int32 .and. st%render_fill .and. iand(sp%flags, F_NO_FILL) == 0_int32) &
            call render_surface(st, lohi)
         if (count >= 2_int32 .and. st%render_line .and. iand(sp%flags, F_NO_LINES) == 0_int32) &
            call render_segments(st, L_SURF)
         if (st%marker /= MK_NONE .and. iand(sp%flags, F_NO_MARKERS) == 0_int32) call render_markers(st, .false.)
         call end_item()
      endif
   else
      call end_item()
   endif
   call pf3_pop_colormap()
   endsubroutine surface_item

   subroutine mesh_r32(label, x, y, z, triangles, spec)
   !< `ip3_mesh`, single precision.
   character(len=*),  intent(in)           :: label            !< Legend label.
   real(real32),      intent(in), target   :: x(:), y(:), z(:) !< Vertices.
   integer(int32),    intent(in), target   :: triangles(:,:)   !< Each triangle's vertices (3, n), from 1.
   type(plot3d_spec), intent(in), optional :: spec             !< Style.

   call set_arrays32(x, y, z)
   call mesh_item(label, triangles, spec)
   endsubroutine mesh_r32

   subroutine mesh_r64(label, x, y, z, triangles, spec)
   !< `ip3_mesh`, double precision.
   character(len=*),  intent(in)           :: label            !< Legend label.
   real(real64),      intent(in), target   :: x(:), y(:), z(:) !< Vertices.
   integer(int32),    intent(in), target   :: triangles(:,:)   !< Each triangle's vertices (3, n), from 1.
   type(plot3d_spec), intent(in), optional :: spec             !< Style.

   call set_arrays64(x, y, z)
   call mesh_item(label, triangles, spec)
   endsubroutine mesh_r64

   subroutine mesh_item(label, triangles, spec)
   !< `PlotMesh`/`PlotMeshEx`: at least 3 vertices and 3 corners; the triangles' fill, their edges (only with a line
   !< colour given), the vertices' markers, each unless its flag.
   character(len=*),  intent(in)           :: label          !< Legend label.
   integer(int32),    intent(in), target   :: triangles(:,:) !< Triangles.
   type(plot3d_spec), intent(in), optional :: spec           !< Style.
   type(plot3d_spec)                       :: sp             !< Style given.
   type(item3d_style)                      :: st             !< Staged.

   if (size(triangles, 1) /= 3) error stop 'figure_plot3d_items: pf3_mesh: triangles needs 3 rows'
   if (any(triangles < 1_int32) .or. any(triangles > count)) error stop 'figure_plot3d_items: pf3_mesh: a vertex out'
   if (count < 3_int32 .or. size(triangles) < 3) then
      call end_item()
      return
   endif
   if (present(spec)) sp = spec
   tri => triangles
   base_count = count
   gmode = G_MESH
   count = size(triangles, kind=int32)
   if (.not. begin_item_ex(label, sp, sp%fill_color, sp%marker, st)) return
   if (base_count >= 3_int32 .and. st%render_fill .and. iand(sp%flags, F_NO_FILL) == 0_int32) &
      call render_fill(3_int32, style3_color_u32(st%fill_color))
   if (base_count >= 2_int32 .and. st%render_line .and. .not. st%auto_line .and. iand(sp%flags, F_NO_LINES) == 0_int32) &
      call render_segments(st, L_TRI)
   if (st%marker /= MK_NONE .and. iand(sp%flags, F_NO_MARKERS) == 0_int32) then
      gmode = G_SERIES ! RenderColoredMarkers(getter): the vertices
      count = base_count
      call render_markers(st, .false.)
   endif
   call end_item()
   endsubroutine mesh_item

   subroutine pf3_image(label, texture, corners, tint)
   !< As `ip3_image` (`PlotImage` with corners (0, 0), (1, 0), (1, 1), (0, 1) in texture coordinates, flipped in v):
   !< a textured quad sorted with the other items; the item's colour the tint.
   character(len=*),     intent(in)           :: label         !< Legend label.
   type(texture_object), intent(in)           :: texture       !< Image.
   real(real64),         intent(in)           :: corners(:, :) !< x, y, z of the four corners (3 x 4).
   real(real64),         intent(in), optional :: tint(:)       !< RGBA (default white).
   type(plot3d_spec)                          :: sp            !< Style (the defaults).
   type(item3d_style)                         :: st            !< Staged.
   real(real32)                               :: c(4)          !< Tint.
   integer(int32)                             :: col           !< Packed.
   integer(int64)                             :: tex           !< Texture.
   type(im_texture_ref)                       :: ref           !< Its reference.

   if (size(corners, 1) /= 3 .or. size(corners, 2) /= 4) error stop 'figure_plot3d_items: pf3_image: corners 3 x 4'
   c = 1.0_real32
   if (present(tint)) c = real(tint, real32)
   corners4 = corners
   gmode = G_CORNERS
   count = 4_int32
   call white_uv()
   if (.not. begin_item_ex(label, sp, c, sp%marker, st)) return
   col = u32(c)
   call pf3_item_recolor(col)
   ref = texture_ref(texture)
   tex = ref%TexID
   if (iand(ishft(int(col, int64), -24), 255_int64) /= 0_int64) call render_image(tex, col)
   call end_item()
   endsubroutine pf3_image

   ! renderers of fills

   subroutine render_fill(nside, col)
   !< `RendererTriangleFill` / `RendererQuadFill`: each primitive with a corner in the cull box, its vertices, its
   !< triangles at the corners' mean depth.
   integer(int32), intent(in) :: nside !< 3 or 4.
   integer(int32), intent(in) :: col   !< Colour.
   integer(int32)             :: np, k, j, base !< Drawn, primitive, corner, first vertex.
   real(real64)               :: q(3, 4), m(3), z !< Corners, mean, depth.
   real(real32)               :: px, py !< Pixel.
   logical                    :: any_in !< A corner in the box.

   np = d3_room(count / nside, nside)
   call d3_reserve(nside * np, (nside - 2_int32) * np)
   do k = 0_int32, np - 1_int32
      any_in = .false.
      do j = 1_int32, nside
         call point(nside * k + j - 1_int32, q(:, j))
         if (contains(q(:, j))) any_in = .true.
      enddo
      if (.not. any_in) cycle
      base = d3_vtx_count()
      do j = 1_int32, nside
         call plot_to_pixels(v, q(:, j), px, py)
         call d3_vtx(px, py, uvw(1), uvw(2), col)
      enddo
      if (nside == 3_int32) then
         m = (q(:, 1) + q(:, 2)) + q(:, 3)
         m = m / 3.0_real64
         call d3_tri(base, base + 1_int32, base + 2_int32, point_depth(v, m))
      else
         m = ((q(:, 1) + q(:, 2)) + q(:, 3)) + q(:, 4)
         m = m / 4.0_real64
         z = point_depth(v, m)
         call d3_tri(base, base + 1_int32, base + 2_int32, z)
         call d3_tri(base, base + 2_int32, base + 3_int32, z)
      endif
   enddo
   endsubroutine render_fill

   subroutine render_surface(st, lohi)
   !< `RendererSurfaceFill`: each cell with a corner in the cull box, its corners coloured by the colormap (the heights
   !< between the scale's ends, or the data's when both are 0) times the fill alpha, or the fill colour; its two
   !< triangles each at its corners' mean depth.
   type(item3d_style), intent(in) :: st      !< Style.
   real(real64),       intent(in) :: lohi(2) !< Scale's ends.
   integer(int32)                 :: np, k, ix, iy, j, base, cols(4), cfill, cm !< Work.
   real(real64)                   :: q(3, 4), m(3), zmin, zmax, lo, hi, t !< Corners, mean, ranges, fraction.
   real(real32)                   :: px, py, f(4) !< Pixel, a colour.
   logical                        :: any_in !< A corner in the box.

   np = d3_room((nx - 1_int32) * (ny - 1_int32), 4_int32)
   call d3_reserve(4_int32 * np, 2_int32 * np)
   cfill = style3_color_u32(st%fill_color)
   cm = pf3_colormap()
   zmin = 0.0_real64
   zmax = 0.0_real64
   if (st%auto_fill) then ! Init: the data's range
      zmin = huge(1.0_real64)
      zmax = -huge(1.0_real64)
      do k = 0_int32, count - 1_int32
         call point(k, q(:, 1))
         if (.not. zmin < q(3, 1)) zmin = q(3, 1) ! ImMin, ImMax (a NaN taken as C takes it)
         if (.not. zmax > q(3, 1)) zmax = q(3, 1)
      enddo
   endif
   do k = 0_int32, np - 1_int32
      ix = mod(k, nx - 1_int32)
      iy = k / (nx - 1_int32)
      call point(ix + iy * nx, q(:, 1))
      call point(ix + 1_int32 + iy * nx, q(:, 2))
      call point(ix + 1_int32 + (iy + 1_int32) * nx, q(:, 3))
      call point(ix + (iy + 1_int32) * nx, q(:, 4))
      any_in = .false.
      do j = 1_int32, 4_int32
         if (contains(q(:, j))) any_in = .true.
      enddo
      if (.not. any_in) cycle
      cols = cfill
      if (st%auto_fill) then
         lo = zmin
         hi = zmax
         if (lohi(1) /= 0.0_real64 .or. lohi(2) /= 0.0_real64) then
            lo = lohi(1)
            hi = lohi(2)
         endif
         do j = 1_int32, 4_int32
            t = (q(3, j) - lo) / (hi - lo)
            if (t < 0.0_real64) then ! ImClamp
               t = 0.0_real64
            elseif (t > 1.0_real64) then
               t = 1.0_real64
            endif
            call unpack4(cm_sample(cm, real(t, real32)), f)
            f(4) = f(4) * st%fill_alpha
            cols(j) = u32(f)
         enddo
      endif
      base = d3_vtx_count()
      do j = 1_int32, 4_int32
         call plot_to_pixels(v, q(:, j), px, py)
         call d3_vtx(px, py, uvw(1), uvw(2), cols(j))
      enddo
      m = (q(:, 1) + q(:, 2)) + q(:, 3)
      m = m / 3.0_real64
      call d3_tri(base, base + 1_int32, base + 2_int32, point_depth(v, m))
      m = (q(:, 1) + q(:, 3)) + q(:, 4)
      m = m / 3.0_real64
      call d3_tri(base, base + 2_int32, base + 3_int32, point_depth(v, m))
   enddo
   endsubroutine render_surface

   subroutine render_image(tex, col)
   !< `RendererQuadImage`: the quad, culled as a quad, drawn with its texture (its run in the 3-D list).
   integer(int64), intent(in) :: tex !< Texture.
   integer(int32), intent(in) :: col !< Tint.
   real(real32), parameter    :: U(4) = [0.0_real32, 1.0_real32, 1.0_real32, 0.0_real32] !< Texture u.
   real(real32), parameter    :: W(4) = [1.0_real32, 1.0_real32, 0.0_real32, 0.0_real32] !< Texture v, flipped.
   integer(int32)             :: np, j, base !< Drawn, corner, first vertex.
   real(real64)               :: q(3, 4), m(3), z !< Corners, mean, depth.
   real(real32)               :: px, py !< Pixel.
   logical                    :: any_in !< A corner in the box.

   np = d3_room(1_int32, 4_int32)
   if (np < 1_int32) return
   call d3_reserve(4_int32, 2_int32)
   any_in = .false.
   do j = 1_int32, 4_int32
      call point(j - 1_int32, q(:, j))
      if (contains(q(:, j))) any_in = .true.
   enddo
   if (.not. any_in) return
   call d3_set_texture(tex)
   base = d3_vtx_count()
   do j = 1_int32, 4_int32
      call plot_to_pixels(v, q(:, j), px, py)
      call d3_vtx(px, py, U(j), W(j), col)
   enddo
   m = ((q(:, 1) + q(:, 2)) + q(:, 3)) + q(:, 4)
   m = m / 4.0_real64
   z = point_depth(v, m)
   call d3_tri(base, base + 1_int32, base + 2_int32, z)
   call d3_tri(base, base + 2_int32, base + 3_int32, z)
   call d3_set_texture(0_int64)
   endsubroutine render_image

   pure subroutine unpack4(col, f)
   !< `ColorConvertU32ToFloat4`.
   integer(int32), intent(in)  :: col  !< Packed.
   real(real32),   intent(out) :: f(4) !< RGBA.
   integer(int64)              :: u    !< Unsigned.
   integer(int32)              :: k    !< Channel.

   u = iand(int(col, int64), 4294967295_int64)
   do k = 1_int32, 4_int32
      f(k) = real(iand(ishft(u, -8 * (k - 1_int32)), 255_int64), real32) * (1.0_real32 / 255.0_real32)
   enddo
   endsubroutine unpack4

   function surface_range32(z, scale_min, scale_max) result(lohi)
   !< figure_implot3d's scale of a surface: the given ends, else z's finite range (widened about a flat z).
   real(real32), intent(in)           :: z(:,:)              !< Heights.
   real(real64), intent(in), optional :: scale_min, scale_max !< Given ends.
   real(real64)                       :: lohi(2)             !< Ends.

   real(real32)                       :: lo, hi              !< z's finite range.
   integer(int32)                     :: i, j                !< Counters.

   if (present(scale_min) .neqv. present(scale_max)) error stop 'figure_plot3d_items: give both scale ends or neither'
   if (present(scale_min)) then
      lohi(1) = scale_min
      lohi(2) = scale_max
      return
   endif
   lo = huge(1.0_real32) ! as minval/maxval with a mask of the finite values (figure_plot3d_series), no temporary
   hi = -huge(1.0_real32)
   do j = 1_int32, size(z, 2, kind=int32)
      do i = 1_int32, size(z, 1, kind=int32)
         if (.not. ieee_is_finite(z(i, j))) cycle
         lo = min(lo, z(i, j))
         hi = max(hi, z(i, j))
      enddo
   enddo
   call widen(real(lo, real64), real(hi, real64), lohi)
   endfunction surface_range32

   function surface_range64(z, scale_min, scale_max) result(lohi)
   !< figure_implot3d's scale of a surface: the given ends, else z's finite range (widened about a flat z).
   real(real64), intent(in)           :: z(:,:)              !< Heights.
   real(real64), intent(in), optional :: scale_min, scale_max !< Given ends.
   real(real64)                       :: lohi(2)             !< Ends.

   real(real64)                       :: lo, hi              !< z's finite range.
   integer(int32)                     :: i, j                !< Counters.

   if (present(scale_min) .neqv. present(scale_max)) error stop 'figure_plot3d_items: give both scale ends or neither'
   if (present(scale_min)) then
      lohi(1) = scale_min
      lohi(2) = scale_max
      return
   endif
   lo = huge(1.0_real64)
   hi = -huge(1.0_real64)
   do j = 1_int32, size(z, 2, kind=int32)
      do i = 1_int32, size(z, 1, kind=int32)
         if (.not. ieee_is_finite(z(i, j))) cycle
         lo = min(lo, z(i, j))
         hi = max(hi, z(i, j))
      enddo
   enddo
   call widen(lo, hi, lohi)
   endfunction surface_range64

   pure subroutine widen(lo, hi, lohi)
   !< figure_plot3d_series' `field_range_*` rule: a range not increasing widened by one about its centre (to 0 when
   !< not finite).
   real(real64), intent(in)  :: lo, hi  !< Range.
   real(real64), intent(out) :: lohi(2) !< Ends.

   lohi(1) = lo
   lohi(2) = hi
   if (.not. lohi(1) < lohi(2)) then
      if (.not. (ieee_is_finite(lohi(1)) .and. ieee_is_finite(lohi(2)))) then
         lohi(1) = 0.0_real64
         lohi(2) = 0.0_real64
      endif
      lohi(1) = lohi(1) - 0.5_real64
      lohi(2) = lohi(2) + 0.5_real64
   endif
   endsubroutine widen

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
   if (.not. associated(pcol)) col = style3_color_u32(st%line_color)
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

   subroutine render_segments(st, lg)
   !< `RendererLineSegments`: a quad for each pair of points of a line getter, clipped (NaN pairs skipped), no joints.
   type(item3d_style), intent(in)           :: st !< Style.
   integer(int32),     intent(in), optional :: lg !< Line getter (default: the base points).
   integer(int32)                 :: np, k, col, g !< Drawn, segment, colour, getter.
   real(real64)                   :: p1(3), p2(3), c1(3), c2(3) !< Points, clipped.
   real(real32)                   :: hw, uv0(2), uv1(2), a(2), b(2), nrm(2), off(2) !< Work.

   g = L_NONE
   if (present(lg)) g = lg
   np = d3_room(line_count(g, count) / 2_int32, 4_int32)
   call d3_reserve(4_int32 * np, 2_int32 * np)
   hw = max(1.0_real32, st%line_weight) * 0.5_real32
   call line_props(hw, uv0, uv1)
   col = 0_int32
   if (.not. associated(pcol)) col = style3_color_u32(st%line_color)
   do k = 0_int32, np - 1_int32
      call line_point(g, 2_int32 * k, p1)
      call line_point(g, 2_int32 * k + 1_int32, p2)
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
   ccol = style3_color_u32(st%mfill_color)
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
   ccol = style3_color_u32(st%mline_color)
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
   !< Point i (0-based) of the base getter as double (`GetterXYZ`, a grid's vertex, a mesh's triangle corner, an
   !< image's corner).
   integer(int32), intent(in)  :: i    !< Index.
   real(real64),   intent(out) :: p(3) !< Point.
   integer(int32)              :: a, b !< Grid indices (1-based).

   select case (gmode)
   case (G_RECT)
      a = mod(i, nx) + 1_int32
      b = i / nx + 1_int32
      if (k64) then
         p(1) = x64(a)
         p(2) = y64(b)
         p(3) = z2_64(a, b)
      else
         p(1) = real(x32(a), real64)
         p(2) = real(y32(b), real64)
         p(3) = real(z2_32(a, b), real64)
      endif
      return
   case (G_GRID)
      a = mod(i, nx) + 1_int32
      b = i / nx + 1_int32
      if (k64) then
         p(1) = x2_64(a, b)
         p(2) = y2_64(a, b)
         p(3) = z2_64(a, b)
      else
         p(1) = real(x2_32(a, b), real64)
         p(2) = real(y2_32(a, b), real64)
         p(3) = real(z2_32(a, b), real64)
      endif
      return
   case (G_MESH)
      call vertex(tri(mod(i, 3_int32) + 1_int32, i / 3_int32 + 1_int32) - 1_int32, p)
      return
   case (G_CORNERS)
      p = corners4(:, i + 1_int32)
      return
   endselect
   call vertex(i, p)
   endsubroutine point

   subroutine vertex(i, p)
   !< Vertex i (0-based) of the series as double.
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
   endsubroutine vertex

   subroutine line_point(lg, i, p)
   !< Endpoint i (0-based) of a line getter over the base getter: `GetterTriangleLines`, `GetterQuadLines`,
   !< `GetterSurfaceLines`, or the base itself.
   integer(int32), intent(in)  :: lg   !< Line getter.
   integer(int32), intent(in)  :: i    !< Index.
   real(real64),   intent(out) :: p(3) !< Point.
   integer(int32)              :: e, sg, hs, row, col, px, py !< Endpoint, segment, horizontal segments, grid.

   select case (lg)
   case (L_TRI)
      call point(mod((mod(i, 6_int32) + 1_int32) / 2_int32, 3_int32) + i / 6_int32 * 3_int32, p)
   case (L_QUAD)
      call point(mod((mod(i, 8_int32) + 1_int32) / 2_int32, 4_int32) + i / 8_int32 * 4_int32, p)
   case (L_SURF)
      e = mod(i, 2_int32)
      sg = i / 2_int32
      hs = (nx - 1_int32) * ny
      if (sg < hs) then
         row = sg / (nx - 1_int32)
         col = mod(sg, nx - 1_int32)
         px = col
         if (e /= 0_int32) px = col + 1_int32
         py = row
      else
         col = (sg - hs) / (ny - 1_int32)
         row = mod(sg - hs, ny - 1_int32)
         px = col
         py = row + e
      endif
      call point(py * nx + px, p)
   case default
      call point(i, p)
   endselect
   endsubroutine line_point

   function line_count(lg, n) result(m)
   !< A line getter's endpoints over a base of n points.
   integer(int32), intent(in) :: lg !< Line getter.
   integer(int32), intent(in) :: n  !< Base points.
   integer(int32)             :: m  !< Endpoints.

   select case (lg)
   case (L_TRI, L_QUAD)
      m = 2_int32 * n
   case (L_SURF)
      m = 2_int32 * ((nx - 1_int32) * ny + (ny - 1_int32) * nx)
   case default
      m = n
   endselect
   endfunction line_count

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
   !< `ColorConvertFloat4ToU32`: a colour packed (the style's alpha not applied; figure_plot3d_style's
   !< `style3_color_u32` where ImPlot3D calls `GetColorU32`).
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
