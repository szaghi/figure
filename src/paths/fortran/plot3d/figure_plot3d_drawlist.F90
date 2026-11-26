!< figure_plot3d_drawlist, a 3-D plot's triangles, sorted by depth before they are drawn (ImPlot3D's ImDrawList3D).
module figure_plot3d_drawlist
!< figure_plot3d_drawlist, a 3-D plot's triangles, sorted by depth before they are drawn (ImPlot3D's ImDrawList3D).
!<
!< szaghi/figure#15 P13. A 3-D plot's items write their triangles here (vertices: pixel position, texture coordinates,
!< packed colour; three 0-based indices and a depth per triangle), as ImPlot3D's `ImDrawList3D`: `d3_reserve` and
!< `d3_unreserve` (`PrimReserve`, `PrimUnreserve`), `d3_room` (what `RenderPrimitivesEx` may still draw: the list's
!< indices are 32-bit, FIGURE's ImPlot3D patch 0002, so up to `D3_MAX_VTX` vertices per plot), the writes
!< (`d3_vtx`, `d3_tri`), and `d3_flush` (`SortedMoveToImGuiDrawList`): the triangles with a NaN depth left out and the
!< others sorted by increasing depth, equal depths by their index (FIGURE's ImPlot3D patch 0004: a total order, so any
!< sort gives it; here glibc's top-down merge sort), appended to the window's list through figure_core
!< (`core_draw_prims`), the list emptied. A list of more than 65535 vertices (past 16-bit indices) is
!< appended as ImPlot3D's patch appends it: each sorted triangle's three vertices in the sorted order, in runs of one
!< texture of at most 21845 triangles, each run one `core_draw_prims` (a new batch, Dear ImGui's `VtxOffset`, when the
!< window's would pass 65535 vertices).
!<
!< The buffers and the sort's scratch are module arrays grown once and kept (no allocation per frame).
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use figure_core, only : core_draw_prims

implicit none
private
public :: d3_reset, d3_reserve, d3_unreserve, d3_room, d3_vtx, d3_tri, d3_flush, d3_vtx_count, d3_tri_count
public :: d3_set_texture
public :: D3_MAX_IDX, D3_MAX_VTX

integer(int32), parameter :: D3_MAX_IDX = 65535_int32     !< ImDrawList3D::MaxIdx() (16-bit ImDrawIdx).
integer(int32), parameter :: D3_MAX_VTX = 536870911_int32 !< ImDrawList3D::MaxVtx() (FIGURE's patch): a plot's
                                                          !< vertices at most, 2^29 - 1.
integer(int32), parameter :: RUN_MAX = D3_MAX_IDX / 3_int32 !< Triangles of a run of a large list (21845).

real(real32),   allocatable :: vx(:), vy(:), vu(:), vv(:) !< Vertices: position, texture coordinates.
integer(int32), allocatable :: vc(:)                      !< ... packed colour.
integer(int32), allocatable :: ix(:)                      !< Indices, three per triangle, 0-based.
real(real64),   allocatable :: zb(:)                      !< Depth per triangle.
integer(int32), allocatable :: ord(:), tmp(:)             !< The sorted order, the sort's scratch.
integer(int32), allocatable :: sidx(:)                    !< The indices in the sorted order.
integer(int32)              :: nv = 0_int32               !< Vertices (_VtxCurrentIdx).
integer(int32)              :: nt = 0_int32               !< Triangles.
integer(int32)              :: ns = 0_int32               !< Triangles sorted (those with a depth not NaN).
integer(int64)              :: run_tex(64) = 0_int64      !< Texture runs (`_TextureBuffer`): texture (0: the default),
integer(int32)              :: run_vtx(64) = 0_int32      !< ... from this vertex (0-based) on.
integer(int32)              :: nrun = 0_int32             !< Runs.
real(real32),   allocatable :: bx(:), by(:), bu(:), bv(:) !< A large list's run: its vertices, in the sorted order,
integer(int32), allocatable :: bc(:), bi(:)               !< ... their colours, their indices (0, 1, 2, ...).

contains
   subroutine d3_reset()
   !< `ResetBuffers`: no vertex, no triangle.

   nv = 0_int32
   nt = 0_int32
   nrun = 0_int32
   endsubroutine d3_reset

   subroutine d3_set_texture(tex)
   !< `SetTexture` (`ResetTexture`: 0): the triangles from the next vertex on drawn with `tex`, runs coalesced as
   !< ImPlot3D coalesces them.
   integer(int64), intent(in) :: tex !< Texture (`ImTextureID`; 0 the default).

   if (nrun == 0_int32) then
      nrun = 1_int32
      run_tex(1) = tex
      run_vtx(1) = nv
      return
   endif
   if (run_vtx(nrun) == nv) then
      run_tex(nrun) = tex
      if (nrun >= 2_int32) then
         if (run_tex(nrun - 1_int32) == tex) nrun = nrun - 1_int32
      endif
   elseif (run_tex(nrun) /= tex) then
      if (nrun == size(run_tex, kind=int32)) error stop 'figure_plot3d_drawlist: more than 64 texture runs in a plot'
      nrun = nrun + 1_int32
      run_tex(nrun) = tex
      run_vtx(nrun) = nv
   endif
   endsubroutine d3_set_texture

   pure function d3_vtx_count() result(n)
   !< Vertices written (`_VtxCurrentIdx`).
   integer(int32) :: n !< Vertices.

   n = nv
   endfunction d3_vtx_count

   pure function d3_tri_count() result(n)
   !< Triangles written.
   integer(int32) :: n !< Triangles.

   n = nt
   endfunction d3_tri_count

   pure function d3_room(prims, vtx_per_prim) result(n)
   !< `RenderPrimitivesEx`'s count: at most `prims`, as many as the vertices left under `D3_MAX_VTX` hold.
   integer(int32), intent(in) :: prims        !< Primitives asked.
   integer(int32), intent(in) :: vtx_per_prim !< Vertices per primitive.
   integer(int32)             :: n            !< Primitives drawn.

   n = min(prims, (D3_MAX_VTX - nv) / vtx_per_prim)
   endfunction d3_room

   subroutine d3_reserve(nvtx, ntri)
   !< Room for nvtx more vertices and ntri more triangles (grown, kept).
   integer(int32), intent(in) :: nvtx !< Vertices.
   integer(int32), intent(in) :: ntri !< Triangles.

   call grow(nv + nvtx, nt + ntri)
   endsubroutine d3_reserve

   subroutine d3_unreserve(nvtx, ntri)
   !< `PrimUnreserve`: nothing to give back (the writes are counted; the room stays).
   integer(int32), intent(in) :: nvtx !< Vertices.
   integer(int32), intent(in) :: ntri !< Triangles.

   if (nvtx < 0_int32 .or. ntri < 0_int32) error stop 'figure_plot3d_drawlist: d3_unreserve of a negative count'
   endsubroutine d3_unreserve

   subroutine d3_vtx(x, y, u, v, col)
   !< A vertex (the next index).
   real(real32),   intent(in) :: x, y !< Position [pixels].
   real(real32),   intent(in) :: u, v !< Texture coordinates.
   integer(int32), intent(in) :: col  !< Packed colour.

   if (nv + 1_int32 > size(vx, kind=int32)) call grow(nv + 1_int32, nt)
   nv = nv + 1_int32
   vx(nv) = x
   vy(nv) = y
   vu(nv) = u
   vv(nv) = v
   vc(nv) = col
   endsubroutine d3_vtx

   subroutine d3_tri(i, j, k, z)
   !< A triangle of three vertices (0-based) and its depth.
   integer(int32), intent(in) :: i, j, k !< Vertices.
   real(real64),   intent(in) :: z       !< Depth.

   if (nt + 1_int32 > size(zb, kind=int32)) call grow(nv, nt + 1_int32)
   nt = nt + 1_int32
   ix(3_int32 * nt - 2_int32) = i
   ix(3_int32 * nt - 1_int32) = j
   ix(3_int32 * nt) = k
   zb(nt) = z
   endsubroutine d3_tri

   subroutine d3_flush()
   !< `SortedMoveToImGuiDrawList`: the triangles with a depth not NaN by increasing depth (ties in their order),
   !< appended to the window's list with every vertex; the list emptied.
   integer(int32) :: t, k !< Triangle, position.

   ns = 0_int32
   do t = 1_int32, nt
      if (zb(t) /= zb(t)) cycle ! a NaN (inline): FIGURE's ImPlot3D patch 0004: nothing to draw, no place in the order
      ns = ns + 1_int32
      ord(ns) = t
   enddo
   if (ns == 0_int32) then
      call d3_reset()
      return
   endif
   call merge_sort()
   do k = 1_int32, ns
      t = ord(k)
      sidx(3_int32 * k - 2_int32) = ix(3_int32 * t - 2_int32)
      sidx(3_int32 * k - 1_int32) = ix(3_int32 * t - 1_int32)
      sidx(3_int32 * k) = ix(3_int32 * t)
   enddo
   if (nv > D3_MAX_IDX) then
      call flush_large()
   elseif (nrun <= 1_int32) then
      call core_draw_prims(vx(1:nv), vy(1:nv), vu(1:nv), vv(1:nv), vc(1:nv), sidx(1:3_int32 * ns))
   else
      call flush_runs()
   endif
   call d3_reset()
   endsubroutine d3_flush

   ! private

   subroutine flush_runs()
   !< The sorted triangles in runs of one texture (a triangle's texture: the last run starting at or before its first
   !< vertex), each run drawn with its texture (the default one without): ImPlot3D's draw commands per texture.
   integer(int32) :: a, b, k   !< A run of triangles, a triangle.
   integer(int64) :: ta, tk    !< Their textures.

   a = 1_int32
   ta = tri_texture(sidx(1))
   do k = 2_int32, ns + 1_int32
      tk = -1_int64
      if (k <= ns) tk = tri_texture(sidx(3_int32 * k - 2_int32))
      if (k <= ns .and. tk == ta) cycle
      b = k - 1_int32
      if (ta == 0_int64) then
         call core_draw_prims(vx(1:nv), vy(1:nv), vu(1:nv), vv(1:nv), vc(1:nv), sidx(3_int32 * a - 2_int32:3_int32 * b))
      else
         call core_draw_prims(vx(1:nv), vy(1:nv), vu(1:nv), vv(1:nv), vc(1:nv), sidx(3_int32 * a - 2_int32:3_int32 * b), &
                              texture=ta)
      endif
      a = k
      ta = tk
   enddo
   endsubroutine flush_runs

   subroutine flush_large()
   !< A list past 16-bit indices (ImPlot3D's patch 0002): each sorted triangle's three vertices in the sorted order, in
   !< runs of one texture (`_TextureBuffer` read with two runs or more) of at most `RUN_MAX` triangles, each run drawn
   !< with its texture (the default one without).
   integer(int32) :: k, m, j, c, n !< Run start, its triangles, a triangle, a corner, vertices written.
   integer(int64) :: tex          !< The run's texture.

   if (.not. allocated(bx)) then
      allocate(bx(3_int32 * RUN_MAX), by(3_int32 * RUN_MAX), bu(3_int32 * RUN_MAX), bv(3_int32 * RUN_MAX))
      allocate(bc(3_int32 * RUN_MAX), bi(3_int32 * RUN_MAX))
      do j = 1_int32, 3_int32 * RUN_MAX
         bi(j) = j - 1_int32
      enddo
   endif
   k = 1_int32
   do while (k <= ns)
      tex = large_texture(k)
      m = 1_int32
      do while (k + m <= ns .and. m < RUN_MAX)
         if (large_texture(k + m) /= tex) exit
         m = m + 1_int32
      enddo
      n = 0_int32
      do j = k, k + m - 1_int32
         do c = 2_int32, 0_int32, -1_int32
            n = n + 1_int32
            bx(n) = vx(sidx(3_int32 * j - c) + 1_int32)
            by(n) = vy(sidx(3_int32 * j - c) + 1_int32)
            bu(n) = vu(sidx(3_int32 * j - c) + 1_int32)
            bv(n) = vv(sidx(3_int32 * j - c) + 1_int32)
            bc(n) = vc(sidx(3_int32 * j - c) + 1_int32)
         enddo
      enddo
      if (tex == 0_int64) then
         call core_draw_prims(bx(1:n), by(1:n), bu(1:n), bv(1:n), bc(1:n), bi(1:n))
      else
         call core_draw_prims(bx(1:n), by(1:n), bu(1:n), bv(1:n), bc(1:n), bi(1:n), texture=tex)
      endif
      k = k + m
   enddo
   endsubroutine flush_large

   pure function large_texture(k) result(tex)
   !< The texture of the k-th sorted triangle of a large list (0, the default, with fewer than two runs).
   integer(int32), intent(in) :: k   !< Sorted triangle.
   integer(int64)             :: tex !< Texture.

   tex = 0_int64
   if (nrun > 1_int32) tex = tri_texture(sidx(3_int32 * k - 2_int32))
   endfunction large_texture

   pure function tri_texture(i0) result(tex)
   !< The texture of a triangle whose first vertex is i0 (0-based).
   integer(int32), intent(in) :: i0  !< First vertex.
   integer(int64)             :: tex !< Texture (0: the default).
   integer(int32)             :: j   !< Run.

   tex = 0_int64
   do j = 1_int32, nrun
      if (i0 >= run_vtx(j)) tex = run_tex(j)
   enddo
   endfunction tri_texture

   subroutine merge_sort()
   !< glibc's `qsort` (2.39: `msort_with_tmp`, a top-down merge sort) of `ord(1:ns)` by `zb` with ImPlot3D's comparator
   !< (FIGURE's patch 0004: no NaN depth, equal depths by index: a total order, which any correct sort follows).

   call msort(1_int32, ns)
   endsubroutine merge_sort

   recursive subroutine msort(b, n)
   !< `msort_with_tmp` of ord(b:b+n-1).
   integer(int32), intent(in) :: b, n          !< First element, elements.
   integer(int32)             :: n1, n2, i, j, k !< Halves, cursors.

   if (n <= 1_int32) return
   n1 = n / 2_int32
   n2 = n - n1
   call msort(b, n1)
   call msort(b + n1, n2)
   i = b
   j = b + n1
   k = 0_int32
   do while (n1 > 0_int32 .and. n2 > 0_int32)
      if (compare(ord(i), ord(j)) <= 0_int32) then
         k = k + 1_int32
         tmp(k) = ord(i)
         i = i + 1_int32
         n1 = n1 - 1_int32
      else
         k = k + 1_int32
         tmp(k) = ord(j)
         j = j + 1_int32
         n2 = n2 - 1_int32
      endif
   enddo
   do while (n1 > 0_int32)
      k = k + 1_int32
      tmp(k) = ord(i)
      i = i + 1_int32
      n1 = n1 - 1_int32
   enddo
   ord(b:b + k - 1_int32) = tmp(1:k) ! (n - n2) elements; the right run's rest is in place
   endsubroutine msort

   pure function compare(a, c) result(r)
   !< ImPlot3D's comparator of two triangles: -1 when a's depth is below c's, 1 above; equal depths by index (FIGURE's
   !< patch 0004).
   integer(int32), intent(in) :: a, c !< Triangles.
   integer(int32)             :: r    !< Order.

   if (zb(a) < zb(c)) then
      r = -1_int32
   elseif (zb(a) > zb(c)) then
      r = 1_int32
   elseif (a < c) then
      r = -1_int32
   elseif (a > c) then
      r = 1_int32
   else
      r = 0_int32
   endif
   endfunction compare

   subroutine grow(mv, mt)
   !< Room for mv vertices and mt triangles, what is held kept (grown by half again at least).
   integer(int32), intent(in)  :: mv, mt !< Vertices, triangles.
   real(real32),   allocatable :: r(:)   !< Work.
   integer(int32), allocatable :: g(:)   !< Work.
   real(real64),   allocatable :: d(:)   !< Work.
   integer(int32)              :: c      !< Capacity.

   if (.not. allocated(vx)) then
      allocate(vx(4096), vy(4096), vu(4096), vv(4096), vc(4096))
      allocate(ix(3 * 4096), zb(4096), ord(4096), tmp(4096), sidx(3 * 4096))
   endif
   if (mv > size(vx, kind=int32)) then
      c = max(mv, size(vx, kind=int32) + size(vx, kind=int32) / 2_int32)
      allocate(r(c))
      r(1:nv) = vx(1:nv)
      call move_alloc(r, vx)
      allocate(r(c))
      r(1:nv) = vy(1:nv)
      call move_alloc(r, vy)
      allocate(r(c))
      r(1:nv) = vu(1:nv)
      call move_alloc(r, vu)
      allocate(r(c))
      r(1:nv) = vv(1:nv)
      call move_alloc(r, vv)
      allocate(g(c))
      g(1:nv) = vc(1:nv)
      call move_alloc(g, vc)
   endif
   if (mt > size(zb, kind=int32)) then
      c = max(mt, size(zb, kind=int32) + size(zb, kind=int32) / 2_int32)
      allocate(g(3 * c))
      g(1:3 * nt) = ix(1:3 * nt)
      call move_alloc(g, ix)
      allocate(d(c))
      d(1:nt) = zb(1:nt)
      call move_alloc(d, zb)
      deallocate(ord, tmp, sidx)
      allocate(ord(c), tmp(c), sidx(3 * c))
   endif
   endsubroutine grow
endmodule figure_plot3d_drawlist
