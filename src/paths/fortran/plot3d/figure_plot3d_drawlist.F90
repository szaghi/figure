!< figure_plot3d_drawlist, a 3-D plot's triangles, sorted by depth before they are drawn (ImPlot3D's ImDrawList3D).
module figure_plot3d_drawlist
!< figure_plot3d_drawlist, a 3-D plot's triangles, sorted by depth before they are drawn (ImPlot3D's ImDrawList3D).
!<
!< szaghi/figure#15 P13. A 3-D plot's items write their triangles here (vertices: pixel position, texture coordinates,
!< packed colour; three 0-based indices and a depth per triangle), as ImPlot3D's `ImDrawList3D`: `d3_reserve` and
!< `d3_unreserve` (`PrimReserve`, `PrimUnreserve`), `d3_room` (what `RenderPrimitivesEx` may still draw: the list's
!< 16-bit indices stop at 65535 vertices per plot, the primitives past them are not drawn), the writes
!< (`d3_vtx`, `d3_tri`), and `d3_flush` (`SortedMoveToImGuiDrawList`): the triangles sorted by increasing depth as
!< glibc's `qsort` sorts them (2.39: a top-down merge sort, stable; reproduced step for step, so that a NaN depth, which
!< the comparator calls equal to anything, lands where glibc puts it), appended to the window's list through
!< figure_core (`core_draw_prims`), the list emptied.
!<
!< The buffers and the sort's scratch are module arrays grown once and kept (no allocation per frame).
use, intrinsic :: iso_fortran_env, only : int32, real32, real64
use figure_core, only : core_draw_prims

implicit none
private
public :: d3_reset, d3_reserve, d3_unreserve, d3_room, d3_vtx, d3_tri, d3_flush, d3_vtx_count, d3_tri_count
public :: D3_MAX_IDX

integer(int32), parameter :: D3_MAX_IDX = 65535_int32 !< ImDrawList3D::MaxIdx() (16-bit ImDrawIdx).

real(real32),   allocatable :: vx(:), vy(:), vu(:), vv(:) !< Vertices: position, texture coordinates.
integer(int32), allocatable :: vc(:)                      !< ... packed colour.
integer(int32), allocatable :: ix(:)                      !< Indices, three per triangle, 0-based.
real(real64),   allocatable :: zb(:)                      !< Depth per triangle.
integer(int32), allocatable :: ord(:), tmp(:)             !< The sorted order, the sort's scratch.
integer(int32), allocatable :: sidx(:)                    !< The indices in the sorted order.
integer(int32)              :: nv = 0_int32               !< Vertices (_VtxCurrentIdx).
integer(int32)              :: nt = 0_int32               !< Triangles.

contains
   subroutine d3_reset()
   !< `ResetBuffers`: no vertex, no triangle.

   nv = 0_int32
   nt = 0_int32
   endsubroutine d3_reset

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
   !< `RenderPrimitivesEx`'s count: at most `prims`, as many as the vertices left under 65535 hold.
   integer(int32), intent(in) :: prims        !< Primitives asked.
   integer(int32), intent(in) :: vtx_per_prim !< Vertices per primitive.
   integer(int32)             :: n            !< Primitives drawn.

   n = min(prims, (D3_MAX_IDX - nv) / vtx_per_prim)
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
   !< `SortedMoveToImGuiDrawList`: the triangles by increasing depth (ties in their order), appended to the window's
   !< list with every vertex; the list emptied.
   integer(int32) :: t, k !< Triangle, position.

   if (nt == 0_int32) then
      call d3_reset()
      return
   endif
   do t = 1_int32, nt
      ord(t) = t
   enddo
   call merge_sort()
   do k = 1_int32, nt
      t = ord(k)
      sidx(3_int32 * k - 2_int32) = ix(3_int32 * t - 2_int32)
      sidx(3_int32 * k - 1_int32) = ix(3_int32 * t - 1_int32)
      sidx(3_int32 * k) = ix(3_int32 * t)
   enddo
   call core_draw_prims(vx(1:nv), vy(1:nv), vu(1:nv), vv(1:nv), vc(1:nv), sidx(1:3_int32 * nt))
   call d3_reset()
   endsubroutine d3_flush

   ! private

   subroutine merge_sort()
   !< glibc's `qsort` (2.39: `msort_with_tmp`, a top-down merge sort) of `ord(1:nt)` by `zb` with ImPlot3D's comparator
   !< (-1, 1 or 0: a NaN depth compares equal to anything): the same halving and the same merge (the left element taken
   !< unless the comparator says the right one is smaller), so the order is glibc's even with NaN depths, for which no
   !< other stable sort agrees.

   call msort(1_int32, nt)
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
   !< ImPlot3D's comparator of two triangles: -1 when a's depth is below c's, 1 above, 0 otherwise.
   integer(int32), intent(in) :: a, c !< Triangles.
   integer(int32)             :: r    !< Order.

   if (zb(a) < zb(c)) then
      r = -1_int32
   elseif (zb(a) > zb(c)) then
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
