!< figure_drawlist, a draw list built in Fortran: the primitives' vertices and indices, as Dear ImGui's ImDrawList builds them.
module figure_drawlist
!< figure_drawlist, a draw list built in Fortran: the primitives' vertices and indices, as Dear ImGui's ImDrawList builds them.
!<
!< The first piece of the Fortran core (szaghi/figure#15 P8, block E): the tessellation of the primitives the layers above
!< the core draw, written once. A `draw_list` holds
!<
!< - the vertices, `draw_vert` (`bind(C)`, Dear ImGui's `ImDrawVert` layout: position, texture coordinates, packed
!<   colour), handed as they are to a renderer or appended to a Dear ImGui list (figure_core's implementation over Dear
!<   ImGui does that at the end of an item);
!< - the indices, 0-based in their batch;
!< - the batches, a structure of arrays (each one's first vertex and first index; `dl_batch` gives its extent):
!<   consecutive primitives share a batch while its vertices fit 16-bit indices (Dear ImGui's `ImDrawIdx`), so a batch
!<   is one `PrimReserve` there. A batch splits where Dear ImGui's `PrimReserve` starts a draw command: when the
!<   reservation would take the batch past 65535 vertices, counting those the target's open command already holds
!<   before the list's first batch (`dl_open`).
!<
!< The primitives (`dl_rect_filled`, `dl_rect_filled_multicolor`, `dl_convex_poly_filled`, `dl_triangle_filled`,
!< `dl_line`, `dl_quad_uv`) give the vertices and indices that Dear ImGui 1.93's `ImDrawList` gives for the same call
!< (imgui_draw.cpp: `AddRectFilled` without rounding, `AddRectFilledMultiColor`, `AddConvexPolyFilled`,
!< `AddTriangleFilled`, `AddLine`, `PrimReserve(6, 4)` and `PrimQuadUV`), in the same order, from the same state: the
!< fringe scale, the white pixel's
!< coordinates, the anti-aliased lines' texture coordinates and the list's flags (`dl_set_state`). Arithmetic in
!< `real(c_float)`, as the C++'s; `ImRsqrtPrecise` is `1 / sqrt` (Dear ImGui built with `IMGUI_DISABLE_SSE`, no
!< rsqrtss estimate). Rounded rectangles, polylines, circles and text are not here yet: figure_core draws them
!< through Dear ImGui.
!<
!< Loops that write many primitives (the plot frames' items: szaghi/figure#16 S2) use the batch interface, as ImPlot's
!< `RenderPrimitives` uses `PrimReserve` and `PrimUnreserve`: `dl_reserve` takes room for a run of primitives (the
!< vertices and indices at the end of the list, `dl%vtx` and `dl%idx`, written in place by the caller, for instance with
!< `dl_put_quad_uv`), `dl_unreserve` gives back what the caller did not write (the culled primitives), and
!< `dl_vtx_current` is what Dear ImGui's `_VtxCurrentIdx` would be, to size a run as ImPlot does.
!<
!< A list with a sink (`dl%sink`, figure_core's appends to Dear ImGui) hands its batches to it when a reservation opens a
!< new batch, and starts again from its first vertex: the list holds one batch at most, not the frame's whole draw data.
!< A batch opened at a 16-bit wrap is marked (`dl_batch`'s `split`): Dear ImGui's `PrimReserve` starts its draw command
!< at the reservation, so the batch starts one even when the room given back afterwards would let it fit the previous.
!< So what was reserved before a reservation that opens a batch must be written (or given back) first; the primitives,
!< and loops that reserve as ImPlot's `RenderPrimitivesEx` does, keep to it.
!<
!< Colours are `ImU32` packed as Dear ImGui packs them (red in the low byte, alpha in the high one), held in a
!< `c_int32_t`; the alpha is read and rewritten with explicit unsigned arithmetic on 64-bit integers (#15 §5).
use, intrinsic :: iso_c_binding, only : c_float, c_int, c_int32_t
use, intrinsic :: iso_fortran_env, only : int32, int64
use figure_cimgui_enums, only : ImDrawFlags_AAFill, ImDrawFlags_AALineEnds, ImDrawFlags_AALines, ImDrawFlags_CapSquare, &
                                ImDrawFlags_JoinMiter, ImDrawFlags_StrokeCenter, ImDrawFlags_StrokeCenterBiased,      &
                                ImDrawFlags_StrokeInside, ImDrawFlags_StrokeLegacy, ImDrawFlags_StrokeMask_,          &
                                ImDrawFlags_StrokeOutside

implicit none
private
public :: draw_vert, draw_list
public :: dl_reset, dl_set_state, dl_rect_filled, dl_rect_filled_multicolor, dl_convex_poly_filled, dl_triangle_filled
public :: dl_line, dl_prim_rect, dl_batch, dl_prims
public :: dl_quad_uv, dl_put_quad_uv, dl_open, dl_reserve, dl_unreserve, dl_vtx_current, dl_sink
public :: DL_LINE_TEXTURES, DL_BATCH_VERTICES

integer(int32), parameter :: DL_LINE_TEXTURES = 64_int32  !< Room for the anti-aliased lines' textures (Dear ImGui 1.93
                                                          !< bakes 46: widths 0 to 32, then 13 samples of 1 to 4).
integer(int32), parameter :: DL_BATCH_VERTICES = 65535_int32 !< Vertices of a batch at most (16-bit indices).
integer(int32), parameter :: TEX_LINES_WIDTH_MAX = 32_int32  !< IM_DRAWLIST_TEX_LINES_WIDTH_MAX.
integer(int32), parameter :: TEX_LINES_DETAILED_WIDTH = 4_int32 !< IM_DRAWLIST_TEX_LINES_DETAILED_WIDTH.
integer(int32), parameter :: TEX_LINES_SAMPLE_COUNT = 4_int32 !< IM_DRAWLIST_TEX_LINES_SAMPLE_COUNT.
real(c_float),  parameter :: MITER_ANGLE_LIMIT = -0.9999619_c_float !< IM_POLYLINE_MITER_ANGLE_LIMIT, cos(179.5 degrees).
real(c_float),  parameter :: MITER_LIMIT = 4.0_c_float     !< IM_POLYLINE_MITER_LIMIT.
integer(int32), parameter :: MAX_BEVELS = 2_int32          !< IM_POLYLINE_CONVEX_POLY_MAX_BEVELS.
integer(int64), parameter :: ALPHA_MASK = 4278190080_int64 !< IM_COL32_A_MASK, 0xFF000000.
integer(int64), parameter :: U32 = 4294967296_int64        !< 2**32.

type, bind(C) :: draw_vert
   !< A vertex, Dear ImGui's `ImDrawVert` (20 bytes).
   real(c_float)      :: x = 0.0_c_float   !< Position, abscissa [pixels].
   real(c_float)      :: y = 0.0_c_float   !< Position, ordinate [pixels].
   real(c_float)      :: u = 0.0_c_float   !< Texture coordinate u.
   real(c_float)      :: v = 0.0_c_float   !< Texture coordinate v.
   integer(c_int32_t) :: col = 0_c_int32_t !< Colour, packed `ImU32`.
endtype draw_vert

abstract interface
   subroutine dl_sink(vtx, nv, idx, ni, split)
   !< Where a list's finished batches go (figure_core: appended to Dear ImGui's list, one primitive each).
   import :: c_int, draw_vert, int32
   implicit none
   integer(int32),  intent(in)         :: nv       !< Vertices.
   type(draw_vert), intent(in), target :: vtx(nv)  !< The batch's vertices.
   integer(int32),  intent(in)         :: ni       !< Indices.
   integer(c_int),  intent(in)         :: idx(ni)  !< Its indices, 0-based in the batch.
   logical,         intent(in)         :: split    !< The batch starts a draw command (`PrimReserve`'s 16-bit wrap).
   endsubroutine dl_sink
endinterface

type :: draw_list
   !< A draw list: vertices, indices and their batches, and the state the primitives read.
   type(draw_vert), allocatable :: vtx(:)        !< Vertices, 1-based.
   integer(c_int),  allocatable :: idx(:)        !< Indices, 0-based in their batch.
   integer(int32)               :: nvtx = 0      !< Vertices used.
   integer(int32)               :: nidx = 0      !< Indices used.
   integer(int32), allocatable  :: batch_vtx(:)  !< Each batch's first vertex.
   integer(int32), allocatable  :: batch_idx(:)  !< ... its first index.
   logical,        allocatable  :: batch_split(:) !< ... it starts a draw command (opened where `PrimReserve` would
                                                  !< start one: kept even if its culled room is given back).
   integer(int32)               :: nbatch = 0    !< Batches used.
   integer(int32)               :: seed = 0      !< Vertices the target's open command holds before the first batch.
   procedure(dl_sink), pointer, nopass :: sink => null() !< Where finished batches go (none: kept until emptied).
   real(c_float)                :: fringe = 1.0_c_float     !< `_FringeScale`: the anti-aliasing fringe [pixels].
   real(c_float)                :: inv_fringe = 1.0_c_float !< `_InvFringeScale`.
   logical                      :: fringe_integer = .true.  !< `_FringeScaleIsInteger`.
   real(c_float)                :: uv_white(2) = 0.0_c_float !< The white pixel's texture coordinates.
   real(c_float)                :: uv_lines(4, DL_LINE_TEXTURES) = 0.0_c_float !< The lines' textures: u0, u1, v,
                                                                              !< 1/thickness (index 0 at column 1).
   integer(int32)               :: n_lines = 0   !< Lines' textures known (0: lines drawn without one).
   integer(c_int)               :: flags = 0_c_int !< The list's flags (`ImDrawList::Flags`).
   real(c_float), allocatable   :: tmp(:,:)      !< Work: normals and squared lengths of a polygon's edges.
endtype draw_list

contains
   subroutine dl_reset(dl)
   !< Empty the list (its storage kept).
   type(draw_list), intent(inout) :: dl !< List.

   dl%nvtx = 0_int32
   dl%nidx = 0_int32
   dl%nbatch = 0_int32
   dl%seed = 0_int32
   endsubroutine dl_reset

   subroutine dl_open(dl, vtx_current)
   !< Open an empty list's first batch in the target's open command, which holds `vtx_current` vertices already (Dear
   !< ImGui's `_VtxCurrentIdx`): the batch splits where `PrimReserve` would split that command. A list not opened
   !< starts its first batch from 0 at its first reservation.
   type(draw_list), intent(inout) :: dl          !< List.
   integer(int32),  intent(in)    :: vtx_current !< Vertices of the target's open command.

   if (dl%nbatch > 0_int32) return
   call new_batch(dl, .false.)
   dl%seed = max(0_int32, min(vtx_current, DL_BATCH_VERTICES))
   endsubroutine dl_open

   pure function dl_vtx_current(dl) result(n)
   !< The open batch's vertices, as Dear ImGui's `_VtxCurrentIdx` counts them: those of the target's command before the
   !< first batch included, the reserved ones too (a caller with culled primitives pending subtracts their vertices).
   type(draw_list), intent(in) :: dl !< List.
   integer(int32)              :: n  !< Vertices.

   n = 0_int32
   if (dl%nbatch == 0_int32) return
   n = dl%nvtx - dl%batch_vtx(dl%nbatch) + 1_int32
   if (dl%nbatch == 1_int32) n = n + dl%seed
   endfunction dl_vtx_current

   subroutine dl_reserve(dl, nv, ni, b)
   !< `PrimReserve(ni, nv)`: room for nv vertices and ni indices at the end of the list, in the open batch or in a new one
   !< when it would pass 65535 vertices; b is the first one's index in its batch (0-based). The caller writes them in
   !< place: the vertices `dl%vtx(dl%nvtx - nv + 1:dl%nvtx)`, the indices `dl%idx(dl%nidx - ni + 1:dl%nidx)` (0-based
   !< in the batch, from b). With a sink, a new batch hands the finished ones to it first (the module's description).
   type(draw_list), intent(inout) :: dl !< List.
   integer(int32),  intent(in)    :: nv !< Vertices.
   integer(int32),  intent(in)    :: ni !< Indices.
   integer(int32),  intent(out)   :: b  !< First vertex, 0-based in the batch.

   call reserve(dl, nv, ni, b)
   dl%nvtx = dl%nvtx + nv
   dl%nidx = dl%nidx + ni
   endsubroutine dl_reserve

   subroutine dl_unreserve(dl, nv, ni)
   !< `PrimUnreserve(ni, nv)`: the last nv vertices and ni indices reserved given back (not past the open batch's start).
   type(draw_list), intent(inout) :: dl !< List.
   integer(int32),  intent(in)    :: nv !< Vertices.
   integer(int32),  intent(in)    :: ni !< Indices.

   if (dl%nbatch == 0_int32) return
   dl%nvtx = max(dl%nvtx - nv, dl%batch_vtx(dl%nbatch) - 1_int32)
   dl%nidx = max(dl%nidx - ni, dl%batch_idx(dl%nbatch) - 1_int32)
   endsubroutine dl_unreserve

   subroutine dl_set_state(dl, fringe, uv_white, uv_lines, n_lines, flags)
   !< The state the primitives read, from the list they are drawn for (figure_core reads Dear ImGui's).
   type(draw_list), intent(inout) :: dl            !< List.
   real(c_float),   intent(in)    :: fringe        !< Fringe scale.
   real(c_float),   intent(in)    :: uv_white(2)   !< White pixel's texture coordinates.
   real(c_float),   intent(in)    :: uv_lines(:,:) !< Lines' textures, (4, n_lines).
   integer(int32),  intent(in)    :: n_lines       !< Lines' textures.
   integer(c_int),  intent(in)    :: flags         !< Flags.

   dl%fringe = fringe
   dl%inv_fringe = 1.0_c_float / fringe
   dl%fringe_integer = real(int(dl%inv_fringe), c_float) == dl%inv_fringe
   dl%uv_white = uv_white
   dl%n_lines = min(n_lines, DL_LINE_TEXTURES)
   if (dl%n_lines > 0_int32) dl%uv_lines(:, 1:dl%n_lines) = uv_lines(:, 1:dl%n_lines)
   dl%flags = flags
   endsubroutine dl_set_state

   subroutine dl_batch(dl, k, v0, nv, i0, ni, split)
   !< Batch k's extent: its first vertex and vertices, its first index and indices; whether it starts a draw command.
   type(draw_list), intent(in)            :: dl     !< List.
   integer(int32),  intent(in)            :: k      !< Batch, 1 to dl%nbatch.
   integer(int32),  intent(out)           :: v0, nv !< First vertex (1-based), vertices.
   integer(int32),  intent(out)           :: i0, ni !< First index (1-based), indices.
   logical,         intent(out), optional :: split  !< It starts a draw command.

   if (present(split)) split = dl%batch_split(k)
   v0 = dl%batch_vtx(k)
   i0 = dl%batch_idx(k)
   if (k < dl%nbatch) then
      nv = dl%batch_vtx(k + 1_int32) - v0
      ni = dl%batch_idx(k + 1_int32) - i0
   else
      nv = dl%nvtx + 1_int32 - v0
      ni = dl%nidx + 1_int32 - i0
   endif
   endsubroutine dl_batch

   ! the primitives

   subroutine dl_prim_rect(dl, ax, ay, cx, cy, col)
   !< `PrimRect`: a rectangle of two triangles, no anti-aliasing.
   type(draw_list),    intent(inout) :: dl     !< List.
   real(c_float),      intent(in)    :: ax, ay !< Upper-left corner [pixels].
   real(c_float),      intent(in)    :: cx, cy !< Lower-right corner [pixels].
   integer(c_int32_t), intent(in)    :: col    !< Colour.
   integer(int32)                    :: b      !< First vertex in the batch.

   call reserve(dl, 4_int32, 6_int32, b)
   call put_vtx(dl, ax, ay, dl%uv_white(1), dl%uv_white(2), col)
   call put_vtx(dl, cx, ay, dl%uv_white(1), dl%uv_white(2), col)
   call put_vtx(dl, cx, cy, dl%uv_white(1), dl%uv_white(2), col)
   call put_vtx(dl, ax, cy, dl%uv_white(1), dl%uv_white(2), col)
   call put_tri(dl, b, b + 1_int32, b + 2_int32)
   call put_tri(dl, b, b + 2_int32, b + 3_int32)
   endsubroutine dl_prim_rect

   subroutine dl_quad_uv(dl, x, y, u, v, col)
   !< `PrimReserve(6, 4)` and `PrimQuadUV`: the quad a, b, c, d (x(1:4), y(1:4)) of the given texture coordinates and
   !< colour, triangles (a, b, c) and (a, c, d); no anti-aliasing, the texture the target's current one.
   type(draw_list),    intent(inout) :: dl         !< List.
   real(c_float),      intent(in)    :: x(4), y(4) !< Vertices [pixels].
   real(c_float),      intent(in)    :: u(4), v(4) !< Their texture coordinates.
   integer(c_int32_t), intent(in)    :: col        !< Colour.
   integer(int32)                    :: b          !< First vertex in the batch.

   call dl_reserve(dl, 4_int32, 6_int32, b)
   call dl_put_quad_uv(dl, dl%nvtx - 3_int32, dl%nidx - 5_int32, b, x, y, u, v, col)
   endsubroutine dl_quad_uv

   subroutine dl_put_quad_uv(dl, iv, ii, b, x, y, u, v, col)
   !< `PrimQuadUV` into reserved room: the four vertices at `dl%vtx(iv:iv + 3)` (a, b, c, d: x(1:4), y(1:4), their
   !< texture coordinates, the colour), the indices (b, b + 1, b + 2) and (b, b + 2, b + 3) at `dl%idx(ii:ii + 5)`.
   type(draw_list),    intent(inout) :: dl         !< List.
   integer(int32),     intent(in)    :: iv         !< First vertex's place in `dl%vtx`.
   integer(int32),     intent(in)    :: ii         !< First index's place in `dl%idx`.
   integer(int32),     intent(in)    :: b          !< First vertex, 0-based in its batch.
   real(c_float),      intent(in)    :: x(4), y(4) !< Vertices [pixels].
   real(c_float),      intent(in)    :: u(4), v(4) !< Their texture coordinates.
   integer(c_int32_t), intent(in)    :: col        !< Colour.

   dl%idx(ii) = int(b, c_int)
   dl%idx(ii + 1_int32) = int(b + 1_int32, c_int)
   dl%idx(ii + 2_int32) = int(b + 2_int32, c_int)
   dl%idx(ii + 3_int32) = int(b, c_int)
   dl%idx(ii + 4_int32) = int(b + 2_int32, c_int)
   dl%idx(ii + 5_int32) = int(b + 3_int32, c_int)
   associate(vt => dl%vtx(iv))
      vt%x = x(1)
      vt%y = y(1)
      vt%u = u(1)
      vt%v = v(1)
      vt%col = col
   endassociate
   associate(vt => dl%vtx(iv + 1_int32))
      vt%x = x(2)
      vt%y = y(2)
      vt%u = u(2)
      vt%v = v(2)
      vt%col = col
   endassociate
   associate(vt => dl%vtx(iv + 2_int32))
      vt%x = x(3)
      vt%y = y(3)
      vt%u = u(3)
      vt%v = v(3)
      vt%col = col
   endassociate
   associate(vt => dl%vtx(iv + 3_int32))
      vt%x = x(4)
      vt%y = y(4)
      vt%u = u(4)
      vt%v = v(4)
      vt%col = col
   endassociate
   endsubroutine dl_put_quad_uv

   subroutine dl_rect_filled(dl, x0, y0, x1, y1, col)
   !< `AddRectFilled` without rounding: the rectangle from (x0, y0) to (x1, y1).
   type(draw_list),    intent(inout) :: dl     !< List.
   real(c_float),      intent(in)    :: x0, y0 !< Upper-left corner [pixels].
   real(c_float),      intent(in)    :: x1, y1 !< Lower-right corner [pixels].
   integer(c_int32_t), intent(in)    :: col    !< Colour.
   real(c_float)                     :: w, h   !< Width, height.
   real(c_float)                     :: px(4), py(4) !< Corners.
   integer(c_int32_t)                :: c      !< Colour drawn.

   if (alpha(col) == 0_int64) return
   if (iand(dl%flags, ImDrawFlags_StrokeMask_) == ImDrawFlags_StrokeLegacy) then
      call dl_prim_rect(dl, x0, y0, x1, y1, col)
      return
   endif
   w = x1 - x0
   h = y1 - y0
   c = col
   if (min(w, h) < dl%fringe) then ! smaller than a pixel in one dimension
      if (min(w, h) < (1.0_c_float / 255.0_c_float) * dl%fringe) return
      if (w < dl%fringe) then
         c = alpha_multiply(c, w * dl%inv_fringe)
         w = dl%fringe
      endif
      if (h < dl%fringe) then
         c = alpha_multiply(c, h * dl%inv_fringe)
         h = dl%fringe
      endif
      px = [x0, x0 + w, x0 + w, x0]
      py = [y0, y0, y0 + h, y0 + h]
      call dl_convex_poly_filled(dl, px, py, c, ImDrawFlags_JoinMiter)
      return
   endif
   if (dl%fringe_integer .and. truncated(x0) .and. truncated(y0) .and. truncated(x1) .and. truncated(y1)) then
      call dl_prim_rect(dl, x0, y0, x1, y1, col)
      return
   endif
   px = [x0, x1, x1, x0]
   py = [y0, y0, y1, y1]
   call dl_convex_poly_filled(dl, px, py, col, ImDrawFlags_JoinMiter)
   endsubroutine dl_rect_filled

   subroutine dl_rect_filled_multicolor(dl, x0, y0, x1, y1, col_ul, col_ur, col_br, col_bl)
   !< `AddRectFilledMultiColor`: a rectangle, a colour at each corner, no anti-aliasing.
   type(draw_list),    intent(inout) :: dl     !< List.
   real(c_float),      intent(in)    :: x0, y0 !< Upper-left corner [pixels].
   real(c_float),      intent(in)    :: x1, y1 !< Lower-right corner [pixels].
   integer(c_int32_t), intent(in)    :: col_ul, col_ur, col_br, col_bl !< Colours: upper left, upper right, bottom
                                                                       !< right, bottom left.
   integer(int32)                    :: b      !< First vertex in the batch.

   if (alpha(col_ul) + alpha(col_ur) + alpha(col_br) + alpha(col_bl) == 0_int64) return
   call reserve(dl, 4_int32, 6_int32, b)
   call put_tri(dl, b, b + 1_int32, b + 2_int32)
   call put_tri(dl, b, b + 2_int32, b + 3_int32)
   call put_vtx(dl, x0, y0, dl%uv_white(1), dl%uv_white(2), col_ul)
   call put_vtx(dl, x1, y0, dl%uv_white(1), dl%uv_white(2), col_ur)
   call put_vtx(dl, x1, y1, dl%uv_white(1), dl%uv_white(2), col_br)
   call put_vtx(dl, x0, y1, dl%uv_white(1), dl%uv_white(2), col_bl)
   endsubroutine dl_rect_filled_multicolor

   subroutine dl_triangle_filled(dl, x1, y1, x2, y2, x3, y3, col)
   !< `AddTriangleFilled`.
   type(draw_list),    intent(inout) :: dl     !< List.
   real(c_float),      intent(in)    :: x1, y1 !< First vertex [pixels].
   real(c_float),      intent(in)    :: x2, y2 !< Second vertex [pixels].
   real(c_float),      intent(in)    :: x3, y3 !< Third vertex [pixels].
   integer(c_int32_t), intent(in)    :: col    !< Colour.

   if (alpha(col) == 0_int64) return
   call dl_convex_poly_filled(dl, [x1, x2, x3], [y1, y2, y3], col, 0_c_int)
   endsubroutine dl_triangle_filled

   subroutine dl_convex_poly_filled(dl, px, py, col, flags)
   !< `AddConvexPolyFilled`: a convex polygon, its points clockwise; anti-aliased with the list's `AAFill` flag.
   type(draw_list),    intent(inout) :: dl      !< List.
   real(c_float),      intent(in)    :: px(:)   !< Points' abscissae [pixels].
   real(c_float),      intent(in)    :: py(:)   !< Points' ordinates [pixels].
   integer(c_int32_t), intent(in)    :: col     !< Colour.
   integer(c_int),     intent(in)    :: flags   !< `ImDrawFlags` (or-ed with the list's).
   integer(c_int)                    :: f       !< Flags in effect.
   integer(int32)                    :: n       !< Points.
   integer(int32)                    :: i0, i1, i !< Edges, counter.
   integer(int32)                    :: b       !< First vertex (the inner ones) in the batch.
   integer(int32)                    :: first_idx !< The polygon's first index.
   integer(int32)                    :: prev_outer, outer, bevels !< Outer vertices, bevels made.
   integer(c_int32_t)                :: col_trans !< The colour, transparent.
   real(c_float)                     :: half_aa, dx, dy, d2, inv_len !< Half the fringe, an edge.
   real(c_float)                     :: cos_t, scale, mx, my, md2, limit2, ref2 !< A corner's miter.
   real(c_float)                     :: u, v    !< White pixel.
   logical                           :: bevel   !< A beveled corner.

   n = size(px, kind=int32)
   if (n < 3_int32 .or. alpha(col) == 0_int64) return
   u = dl%uv_white(1)
   v = dl%uv_white(2)
   f = ior(flags, dl%flags)
   if (iand(f, ImDrawFlags_AAFill) == 0_c_int) then
      call reserve(dl, n, 3_int32 * (n - 2_int32), b)
      do i = 1_int32, n
         call put_vtx(dl, px(i), py(i), u, v, col)
      enddo
      do i = 2_int32, n - 1_int32
         call put_tri(dl, b, b + i - 1_int32, b + i)
      enddo
      return
   endif
   half_aa = dl%fringe * 0.5_c_float
   col_trans = without_alpha(col)
   call reserve(dl, 2_int32 * n + MAX_BEVELS, 3_int32 * ((n - 2_int32) + 2_int32 * n + MAX_BEVELS), b)
   call work(dl, n)
   do i1 = 1_int32, n ! normals and squared lengths of the edges, i0 to i1
      i0 = merge(n, i1 - 1_int32, i1 == 1_int32)
      dx = px(i1) - px(i0)
      dy = py(i1) - py(i0)
      d2 = dx * dx + dy * dy
      if (d2 > 0.0_c_float) then
         inv_len = 1.0_c_float / sqrt(d2)
         dx = dx * inv_len
         dy = dy * inv_len
      endif
      dl%tmp(1, i0) = dy
      dl%tmp(2, i0) = -dx
      dl%tmp(3, i0) = d2
   enddo
   dl%nvtx = dl%nvtx + n ! the inner vertices, b .. b + n - 1, written below; the outer ones follow
   first_idx = dl%nidx + 1_int32
   prev_outer = 0_int32 ! patched once the last outer vertex is known
   bevels = 0_int32
   do i1 = 1_int32, n
      i0 = merge(n, i1 - 1_int32, i1 == 1_int32)
      cos_t = dl%tmp(1, i0) * dl%tmp(1, i1) + dl%tmp(2, i0) * dl%tmp(2, i1)
      scale = min(1000.0_c_float, 1.0_c_float / (1.0_c_float + max(MITER_ANGLE_LIMIT, cos_t)))
      mx = (dl%tmp(1, i0) + dl%tmp(1, i1)) * scale
      my = (dl%tmp(2, i0) + dl%tmp(2, i1)) * scale
      bevel = .false.
      if (iand(f, ImDrawFlags_JoinMiter) == 0_c_int) then
         md2 = mx * mx + my * my
         bevel = md2 > MITER_LIMIT * MITER_LIMIT
         if (bevel) then ! the inner bevel kept inside the polygon
            limit2 = max(dl%tmp(3, i0), dl%tmp(3, i1))
            ref2 = md2 * (half_aa * half_aa)
            if (ref2 > limit2) then
               mx = mx * sqrt(limit2 / ref2)
               my = my * sqrt(limit2 / ref2)
            endif
         endif
      endif
      mx = mx * half_aa
      my = my * half_aa
      associate(vt => dl%vtx(dl%batch_vtx(dl%nbatch) + b + i1 - 1_int32))
         vt%x = px(i1) - mx ! inner
         vt%y = py(i1) - my
         vt%u = u
         vt%v = v
         vt%col = col
      endassociate
      outer = dl%nvtx - dl%batch_vtx(dl%nbatch) + 1_int32
      if (bevel .and. bevels < MAX_BEVELS) then
         bevels = bevels + 1_int32
         call put_vtx(dl, px(i1) + dl%tmp(1, i0) * half_aa, py(i1) + dl%tmp(2, i0) * half_aa, u, v, col_trans)
         call put_vtx(dl, px(i1) + dl%tmp(1, i1) * half_aa, py(i1) + dl%tmp(2, i1) * half_aa, u, v, col_trans)
         call put_tri(dl, prev_outer, outer, b + i1 - 1_int32)
         call put_tri(dl, prev_outer, b + i1 - 1_int32, b + i0 - 1_int32)
         call put_tri(dl, outer, outer + 1_int32, b + i1 - 1_int32)
         outer = outer + 1_int32
      else
         call put_vtx(dl, px(i1) + mx, py(i1) + my, u, v, col_trans)
         call put_tri(dl, prev_outer, outer, b + i1 - 1_int32)
         call put_tri(dl, prev_outer, b + i1 - 1_int32, b + i0 - 1_int32)
      endif
      prev_outer = outer
   enddo
   dl%idx(first_idx) = prev_outer ! the first segment wraps around
   dl%idx(first_idx + 3_int32) = prev_outer
   do i = 3_int32, n ! the fill
      call put_tri(dl, b, b + i - 2_int32, b + i - 1_int32)
   enddo
   endsubroutine dl_convex_poly_filled

   subroutine dl_prims(dl, px, py, pu, pv, col, idx)
   !< Vertices and triangles as given (the 3-D plots' depth-sorted triangles, ImPlot3D's `SortedMoveToImGuiDrawList`):
   !< every vertex in one batch (a new batch when they would pass 65535, as Dear ImGui's `PrimReserve` with
   !< `AllowVtxOffset`), a triangle with an index past what the batch can still address dropped, as ImPlot3D drops it.
   type(draw_list),    intent(inout) :: dl                     !< List.
   real(c_float),      intent(in)    :: px(:), py(:), pu(:), pv(:) !< Vertices: position, texture coordinates.
   integer(c_int32_t), intent(in)    :: col(:)                 !< ... colour.
   integer(c_int),     intent(in)    :: idx(:)                 !< Triangles' vertices, 0-based, three each.
   integer(int32)                    :: n, b, t, mx, i          !< Vertices, first vertex, triangle, max index, counter.

   n = size(px, kind=int32)
   if (n == 0_int32 .or. size(idx) < 3) return
   call reserve(dl, n, size(idx, kind=int32), b)
   mx = DL_BATCH_VERTICES - dl_vtx_current(dl) ! ImPlot3D's MaxIdx() - _VtxCurrentIdx, after the reservation
   do i = 1_int32, n
      call put_vtx(dl, px(i), py(i), pu(i), pv(i), col(i))
   enddo
   do t = 1_int32, size(idx, kind=int32) / 3_int32
      if (idx(3 * t - 2) > mx .or. idx(3 * t - 1) > mx .or. idx(3 * t) > mx) cycle
      call put_tri(dl, idx(3 * t - 2) + b, idx(3 * t - 1) + b, idx(3 * t) + b)
   enddo
   endsubroutine dl_prims

   subroutine dl_line(dl, x1, y1, x2, y2, col, thickness, flags)
   !< `AddLine`: a segment from (x1, y1) to (x2, y2), `thickness` pixels wide (Dear ImGui's default 1, flags 0).
   type(draw_list),    intent(inout) :: dl        !< List.
   real(c_float),      intent(in)    :: x1, y1    !< Start [pixels].
   real(c_float),      intent(in)    :: x2, y2    !< End [pixels].
   integer(c_int32_t), intent(in)    :: col       !< Colour.
   real(c_float),      intent(in)    :: thickness !< Thickness [pixels].
   integer(c_int),     intent(in)    :: flags     !< `ImDrawFlags` (or-ed with the list's).
   integer(c_int)                    :: f         !< Flags in effect.

   if (alpha(col) == 0_int64) return
   f = ior(flags, dl%flags)
   if (stroke_pos(f, ImDrawFlags_StrokeCenter) == ImDrawFlags_StrokeLegacy) then
      call add_line(dl, x1 + 0.5_c_float, y1 + 0.5_c_float, x2 + 0.5_c_float, y2 + 0.5_c_float, col, thickness, f)
   else
      call add_line(dl, x1, y1, x2, y2, col, thickness, f)
   endif
   endsubroutine dl_line

   ! private

   subroutine add_line(dl, x1, y1, x2, y2, col_in, thickness_in, flags_in)
   !< `_AddLine`: the segment as a textured quad (anti-aliased by the line's texture), its ends anti-aliased or not.
   type(draw_list),    intent(inout) :: dl           !< List.
   real(c_float),      intent(in)    :: x1, y1       !< Start [pixels].
   real(c_float),      intent(in)    :: x2, y2       !< End [pixels].
   integer(c_int32_t), intent(in)    :: col_in       !< Colour.
   real(c_float),      intent(in)    :: thickness_in !< Thickness [pixels].
   integer(c_int),     intent(in)    :: flags_in     !< Flags in effect.
   integer(c_int32_t)                :: col, col_trans !< Colour, transparent.
   integer(c_int)                    :: flags, spos  !< Flags, stroke position.
   real(c_float)                     :: thickness, st, fringe !< Thickness, on screen, the fringe.
   real(c_float)                     :: uv0(2), uv1(2) !< The line's texture coordinates.
   real(c_float)                     :: dx, dy, d2, inv_len, nx, ny !< Direction, normal.
   real(c_float)                     :: t0, t1, half_aa, ht !< Offsets.
   real(c_float)                     :: p1x, p1y, p2x, p2y, pax, pay, pbx, pby !< Ends.
   integer(int32)                    :: b, nb        !< Vertices in the batch.
   logical                           :: aa_ends      !< Anti-aliased ends.

   col = col_in
   thickness = thickness_in
   flags = flags_in
   st = thickness * dl%inv_fringe
   if (st < 1.0_c_float) then
      if (st < 1.0_c_float / 255.0_c_float) return
      col = alpha_multiply(col, st)
      st = 1.0_c_float
      thickness = dl%fringe
   endif
   call line_texture(dl, st, flags, uv0, uv1, fringe)
   dx = x2 - x1
   dy = y2 - y1
   d2 = dx * dx + dy * dy
   inv_len = 0.0_c_float
   if (d2 > 0.0_c_float) inv_len = 1.0_c_float / sqrt(d2)
   dx = dx * inv_len
   dy = dy * inv_len
   nx = -dy
   ny = dx
   col_trans = without_alpha(col)
   spos = stroke_pos(flags, ImDrawFlags_StrokeCenter)
   if (spos == ImDrawFlags_StrokeLegacy) flags = iand(ior(flags, ImDrawFlags_JoinMiter), not(ImDrawFlags_AALineEnds))
   t0 = (thickness + fringe) * 0.5_c_float
   if (spos == ImDrawFlags_StrokeOutside) then
      t0 = thickness + fringe * 0.5_c_float
   elseif (spos == ImDrawFlags_StrokeCenterBiased) then
      t0 = center_biased(dl, thickness) + fringe * 0.5_c_float
   elseif (spos == ImDrawFlags_StrokeInside) then
      t0 = fringe * 0.5_c_float
   endif
   t1 = (thickness + fringe) - t0
   half_aa = dl%fringe * 0.5_c_float
   aa_ends = iand(flags, ior(ImDrawFlags_AALines, ImDrawFlags_AALineEnds)) == ior(ImDrawFlags_AALines, ImDrawFlags_AALineEnds)
   p1x = x1
   p1y = y1
   p2x = x2
   p2y = y2
   if (iand(flags, ImDrawFlags_CapSquare) /= 0_c_int) then
      ht = thickness * 0.5_c_float
      p1x = p1x - dx * ht
      p1y = p1y - dy * ht
      p2x = p2x + dx * ht
      p2y = p2y + dy * ht
   endif
   if (.not. aa_ends) then
      call reserve(dl, 4_int32, 6_int32, b)
      call put_vtx(dl, p1x - nx * t0, p1y - ny * t0, uv0(1), uv0(2), col)
      call put_vtx(dl, p1x + nx * t1, p1y + ny * t1, uv1(1), uv1(2), col)
      call put_vtx(dl, p2x - nx * t0, p2y - ny * t0, uv0(1), uv0(2), col)
      call put_vtx(dl, p2x + nx * t1, p2y + ny * t1, uv1(1), uv1(2), col)
      call put_tri(dl, b, b + 2_int32, b + 3_int32)
      call put_tri(dl, b, b + 3_int32, b + 1_int32)
      return
   endif
   call reserve(dl, 8_int32, 18_int32, b)
   pax = p1x - dx * half_aa ! start
   pay = p1y - dy * half_aa
   pbx = p1x + dx * half_aa
   pby = p1y + dy * half_aa
   call put_vtx(dl, pax - nx * t0, pay - ny * t0, uv0(1), uv0(2), col_trans)
   call put_vtx(dl, pax + nx * t1, pay + ny * t1, uv1(1), uv1(2), col_trans)
   nb = b + 2_int32
   call put_vtx(dl, pbx - nx * t0, pby - ny * t0, uv0(1), uv0(2), col)
   call put_vtx(dl, pbx + nx * t1, pby + ny * t1, uv1(1), uv1(2), col)
   call put_tri(dl, b, b + 2_int32, b + 3_int32) ! the start's anti-aliased cap
   call put_tri(dl, b, b + 3_int32, b + 1_int32)
   b = nb
   pax = p2x - dx * half_aa ! end
   pay = p2y - dy * half_aa
   pbx = p2x + dx * half_aa
   pby = p2y + dy * half_aa
   nb = b + 2_int32
   call put_vtx(dl, pax - nx * t0, pay - ny * t0, uv0(1), uv0(2), col)
   call put_vtx(dl, pax + nx * t1, pay + ny * t1, uv1(1), uv1(2), col)
   call put_vtx(dl, pbx - nx * t0, pby - ny * t0, uv0(1), uv0(2), col_trans)
   call put_vtx(dl, pbx + nx * t1, pby + ny * t1, uv1(1), uv1(2), col_trans)
   call put_tri(dl, b, b + 2_int32, b + 3_int32) ! the segment
   call put_tri(dl, b, b + 3_int32, b + 1_int32)
   b = nb
   call put_tri(dl, b, b + 2_int32, b + 3_int32) ! the end's anti-aliased cap
   call put_tri(dl, b, b + 3_int32, b + 1_int32)
   endsubroutine add_line

   subroutine line_texture(dl, st, flags, uv0, uv1, fringe)
   !< `_SelectLineTexture`: the texture coordinates and the fringe of a line `st` screen pixels thick (at least 1).
   type(draw_list), intent(in)  :: dl     !< List.
   real(c_float),   intent(in)  :: st     !< Thickness on screen [pixels].
   integer(c_int),  intent(in)  :: flags  !< Flags in effect.
   real(c_float),   intent(out) :: uv0(2) !< Texture coordinates of one side.
   real(c_float),   intent(out) :: uv1(2) !< ... of the other.
   real(c_float),   intent(out) :: fringe !< Fringe [pixels].
   integer(int32)               :: k      !< Texture (0-based, as Dear ImGui's).

   if (iand(flags, ImDrawFlags_AALines) /= 0_c_int .and. dl%n_lines > 0_int32) then
      if (st <= real(TEX_LINES_DETAILED_WIDTH, c_float)) then
         k = int((st - 1.0_c_float) * real(TEX_LINES_SAMPLE_COUNT, c_float) + 0.5_c_float, int32) + &
             (TEX_LINES_WIDTH_MAX + 1_int32)
      elseif (st < real(TEX_LINES_WIDTH_MAX, c_float) - 1.5_c_float) then
         k = int(st + 0.5_c_float, int32)
      else
         k = TEX_LINES_WIDTH_MAX - 1_int32
      endif
      k = min(k, dl%n_lines - 1_int32)
      uv0 = [dl%uv_lines(1, k + 1_int32), dl%uv_lines(3, k + 1_int32)]
      uv1 = [dl%uv_lines(2, k + 1_int32), dl%uv_lines(3, k + 1_int32)]
      fringe = dl%fringe * st * dl%uv_lines(4, k + 1_int32)
   else
      uv0 = dl%uv_white
      uv1 = dl%uv_white
      fringe = 0.0_c_float
   endif
   endsubroutine line_texture

   pure function center_biased(dl, thickness) result(o)
   !< `_CalculateCenterBiasedOffset`: one side of the line on a pixel's edge.
   type(draw_list), intent(in) :: dl        !< List.
   real(c_float),   intent(in) :: thickness !< Thickness [pixels].
   real(c_float)               :: o         !< Offset.
   real(c_float)               :: st        !< On screen.
   integer(int32)              :: s         !< ... truncated.

   st = thickness * dl%inv_fringe
   s = int(st, int32)
   o = (real(s / 2_int32, c_float) + real(iand(s, 1_int32), c_float) * (st - real(s, c_float))) * dl%fringe
   endfunction center_biased

   pure function stroke_pos(flags, default) result(p)
   !< `_GetStrokePos`: the stroke position of the flags, else the default.
   integer(c_int), intent(in) :: flags   !< Flags.
   integer(c_int), intent(in) :: default !< Default position.
   integer(c_int)             :: p       !< Position.

   p = iand(flags, ImDrawFlags_StrokeMask_)
   if (p == 0_c_int) p = default
   endfunction stroke_pos

   pure function truncated(a) result(t)
   !< `ImIsTruncated`: a has no fractional part (as `(float)(int)a == a`).
   real(c_float), intent(in) :: a !< Value.
   logical                   :: t !< Truncated.

   t = abs(a) < 2.0e9_c_float
   if (t) t = real(int(a, int32), c_float) == a
   endfunction truncated

   pure function alpha(col) result(a)
   !< The alpha of a packed colour, 0-255.
   integer(c_int32_t), intent(in) :: col !< Colour.
   integer(int64)                 :: a   !< Alpha.

   a = ishft(iand(as_u32(col), ALPHA_MASK), -24)
   endfunction alpha

   pure function without_alpha(col) result(c)
   !< The colour, transparent (`col & ~IM_COL32_A_MASK`).
   integer(c_int32_t), intent(in) :: col !< Colour.
   integer(c_int32_t)             :: c   !< Transparent.

   c = packed(iand(as_u32(col), U32 - 1_int64 - ALPHA_MASK))
   endfunction without_alpha

   pure function alpha_multiply(col, mul) result(c)
   !< `ImAlphaMultiply`: the alpha times mul (in [0, 1), truncated).
   integer(c_int32_t), intent(in) :: col !< Colour.
   real(c_float),      intent(in) :: mul !< Factor.
   integer(c_int32_t)             :: c   !< Colour.
   integer(int64)                 :: a   !< Alpha.

   a = int(real(alpha(col), c_float) * mul, int64)
   c = packed(ior(iand(as_u32(col), U32 - 1_int64 - ALPHA_MASK), ishft(a, 24)))
   endfunction alpha_multiply

   pure function as_u32(col) result(u)
   !< A packed colour as the unsigned 32-bit value it is, in 64 bits.
   integer(c_int32_t), intent(in) :: col !< Colour.
   integer(int64)                 :: u   !< 0 to 2**32 - 1.

   u = int(col, int64)
   if (u < 0_int64) u = u + U32
   endfunction as_u32

   pure function packed(u) result(col)
   !< An unsigned 32-bit value (in 64 bits) as the packed colour's `c_int32_t`.
   integer(int64), intent(in) :: u   !< 0 to 2**32 - 1.
   integer(c_int32_t)         :: col !< Colour.

   if (u >= U32 / 2_int64) then
      col = int(u - U32, c_int32_t)
   else
      col = int(u, c_int32_t)
   endif
   endfunction packed

   subroutine reserve(dl, nv, ni, b)
   !< Room for nv vertices and ni indices; the batch they go to (a new one when its 16-bit indices would wrap, as
   !< `PrimReserve`'s `_VtxCurrentIdx + vtx_count >= 65536`; with a sink, the finished batches handed to it first) and
   !< their first vertex's index in it, b.
   type(draw_list), intent(inout) :: dl !< List.
   integer(int32),  intent(in)    :: nv !< Vertices.
   integer(int32),  intent(in)    :: ni !< Indices.
   integer(int32),  intent(out)   :: b  !< First vertex, 0-based in the batch.
   integer(int32)                 :: n  !< The open batch's vertices, as `_VtxCurrentIdx`.

   if (dl%nbatch == 0_int32) call new_batch(dl, .false.)
   n = dl_vtx_current(dl)
   if (n > 0_int32 .and. n + nv > DL_BATCH_VERTICES) then
      if (associated(dl%sink)) call hand_over(dl)
      call new_batch(dl, .true.)
   endif
   if (.not. allocated(dl%vtx)) then ! (the calls only when the storage must grow)
      call grow_vtx(dl, dl%nvtx + nv)
   elseif (size(dl%vtx, kind=int32) < dl%nvtx + nv) then
      call grow_vtx(dl, dl%nvtx + nv)
   endif
   if (.not. allocated(dl%idx)) then
      call grow_idx(dl, dl%nidx + ni)
   elseif (size(dl%idx, kind=int32) < dl%nidx + ni) then
      call grow_idx(dl, dl%nidx + ni)
   endif
   b = dl%nvtx - dl%batch_vtx(dl%nbatch) + 1_int32
   endsubroutine reserve

   subroutine hand_over(dl)
   !< The list's batches handed to its sink, the list emptied (its storage kept).
   type(draw_list), intent(inout) :: dl                !< List.
   integer(int32)                 :: k, v0, nv, i0, ni !< Batch, its extent.
   logical                        :: split             !< It starts a draw command.

   do k = 1_int32, dl%nbatch
      call dl_batch(dl, k, v0, nv, i0, ni, split)
      if (nv > 0_int32 .and. ni > 0_int32) then
         call dl%sink(dl%vtx(v0), nv, dl%idx(i0), ni, split)
      elseif (split) then ! an empty batch that starts a command: the command started all the same, as PrimReserve's
         call dl%sink(dl%vtx(1), 0_int32, dl%idx(1), 0_int32, split)
      endif
   enddo
   dl%nvtx = 0_int32
   dl%nidx = 0_int32
   dl%nbatch = 0_int32
   dl%seed = 0_int32
   endsubroutine hand_over

   subroutine new_batch(dl, split)
   !< A batch starting at the next vertex and index; `split`: where a draw command starts (a 16-bit wrap).
   type(draw_list), intent(inout) :: dl    !< List.
   logical,         intent(in)    :: split !< It starts a draw command.
   integer(int32), allocatable    :: t(:)  !< Grown array.
   logical,        allocatable    :: l(:)  !< ...
   integer(int32)                 :: c     !< Capacity.

   c = 0_int32
   if (allocated(dl%batch_vtx)) c = size(dl%batch_vtx, kind=int32)
   if (dl%nbatch >= c) then
      c = max(16_int32, 2_int32 * c)
      allocate(t(c))
      if (dl%nbatch > 0_int32) t(1:dl%nbatch) = dl%batch_vtx(1:dl%nbatch)
      call move_alloc(t, dl%batch_vtx)
      allocate(t(c))
      if (dl%nbatch > 0_int32) t(1:dl%nbatch) = dl%batch_idx(1:dl%nbatch)
      call move_alloc(t, dl%batch_idx)
      allocate(l(c))
      if (dl%nbatch > 0_int32) l(1:dl%nbatch) = dl%batch_split(1:dl%nbatch)
      call move_alloc(l, dl%batch_split)
   endif
   dl%nbatch = dl%nbatch + 1_int32
   dl%batch_vtx(dl%nbatch) = dl%nvtx + 1_int32
   dl%batch_idx(dl%nbatch) = dl%nidx + 1_int32
   dl%batch_split(dl%nbatch) = split
   endsubroutine new_batch

   subroutine put_vtx(dl, x, y, u, v, col)
   !< Append a vertex to the open batch (field by field, as `dl_put_quad_uv`: a `draw_vert(...)` constructor makes ifx
   !< copy a temporary with one 16-byte load over smaller stores, a store-forwarding stall; szaghi/figure#16 S2).
   type(draw_list),    intent(inout) :: dl         !< List.
   real(c_float),      intent(in)    :: x, y, u, v !< Position, texture coordinates.
   integer(c_int32_t), intent(in)    :: col        !< Colour.

   dl%nvtx = dl%nvtx + 1_int32
   associate(vt => dl%vtx(dl%nvtx))
      vt%x = x
      vt%y = y
      vt%u = u
      vt%v = v
      vt%col = col
   endassociate
   endsubroutine put_vtx


   subroutine put_tri(dl, i, j, k)
   !< Append a triangle (vertices 0-based in the open batch).
   type(draw_list), intent(inout) :: dl      !< List.
   integer(int32),  intent(in)    :: i, j, k !< Vertices.

   dl%idx(dl%nidx + 1_int32) = int(i, c_int)
   dl%idx(dl%nidx + 2_int32) = int(j, c_int)
   dl%idx(dl%nidx + 3_int32) = int(k, c_int)
   dl%nidx = dl%nidx + 3_int32
   endsubroutine put_tri

   subroutine work(dl, n)
   !< Work room for a polygon of n points.
   type(draw_list), intent(inout) :: dl !< List.
   integer(int32),  intent(in)    :: n  !< Points.

   if (allocated(dl%tmp)) then
      if (size(dl%tmp, 2, kind=int32) >= n) return
      deallocate(dl%tmp)
   endif
   allocate(dl%tmp(3, max(n, 64_int32)))
   endsubroutine work

   subroutine grow_vtx(dl, need)
   !< Room for `need` vertices (grown by half again, the vertices kept).
   type(draw_list), intent(inout) :: dl      !< List.
   integer(int32),  intent(in)    :: need    !< Vertices needed.
   type(draw_vert), allocatable   :: more(:) !< Larger array.
   integer(int32)                 :: c       !< Capacity.

   c = 0_int32
   if (allocated(dl%vtx)) c = size(dl%vtx, kind=int32)
   if (c >= need) return
   allocate(more(max(need, c + c / 2_int32, 1024_int32)))
   if (dl%nvtx > 0_int32) more(1:dl%nvtx) = dl%vtx(1:dl%nvtx)
   call move_alloc(more, dl%vtx)
   endsubroutine grow_vtx

   subroutine grow_idx(dl, need)
   !< Room for `need` indices (grown by half again, the indices kept).
   type(draw_list), intent(inout) :: dl      !< List.
   integer(int32),  intent(in)    :: need    !< Indices needed.
   integer(c_int), allocatable    :: more(:) !< Larger array.
   integer(int32)                 :: c       !< Capacity.

   c = 0_int32
   if (allocated(dl%idx)) c = size(dl%idx, kind=int32)
   if (c >= need) return
   allocate(more(max(need, c + c / 2_int32, 1536_int32)))
   if (dl%nidx > 0_int32) more(1:dl%nidx) = dl%idx(1:dl%nidx)
   call move_alloc(more, dl%idx)
   endsubroutine grow_idx
endmodule figure_drawlist
