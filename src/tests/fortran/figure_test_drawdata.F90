!< figure_test_drawdata, the side-by-side tests' draw data: the window's draw commands, vertices and indices, compared.
module figure_test_drawdata
!< figure_test_drawdata, the side-by-side tests' draw data: the window's draw commands, vertices and indices, compared.
!<
!< szaghi/figure#16 S2 step 05. The side-by-side plot tests compare ImPlot's (ImPlot3D's) pictures with the Fortran
!< frame's; the pictures do not see how the vertices are batched into draw commands. A test takes `dd_snapshot` of
!< the current window's draw list at the end of each frame of each side (before `ig_end`) and compares the frames of
!< the two sides with `dd_equal`: the number of draw commands, of vertices and of indices, and each command's vertex
!< offset, index offset and element count, equal. A change in the batching (a 16-bit split where Dear ImGui's
!< `PrimReserve` would not make it, or the other way round) fails the test even when the pictures are equal.
use, intrinsic :: iso_c_binding, only : c_f_pointer, c_float, c_funptr, c_int, c_int64_t, c_ptr
use, intrinsic :: iso_fortran_env, only : int32, output_unit
use figure_cimgui, only : igGetWindowDrawList

implicit none
private
public :: draw_data, dd_snapshot, dd_equal

integer(int32), parameter :: DD_CMDS = 512_int32 !< Commands kept (offsets and counts) at most.

type :: draw_data
   !< A window's draw data at a point of a frame.
   integer(int32) :: ncmd = 0_int32             !< Draw commands.
   integer(int32) :: nvtx = 0_int32             !< Vertices.
   integer(int32) :: nidx = 0_int32             !< Indices.
   integer(int32) :: cmd(3, DD_CMDS) = 0_int32  !< Each command's VtxOffset, IdxOffset, ElemCount (the first DD_CMDS).
endtype draw_data

type, bind(C) :: list_head
   !< ImDrawList's first members (imgui.h, 1.93): its three buffers.
   integer(c_int) :: cmd_size, cmd_capacity !< CmdBuffer.
   type(c_ptr)    :: cmd_data               !< ...
   integer(c_int) :: idx_size, idx_capacity !< IdxBuffer.
   type(c_ptr)    :: idx_data               !< ...
   integer(c_int) :: vtx_size, vtx_capacity !< VtxBuffer.
   type(c_ptr)    :: vtx_data               !< ...
endtype list_head

type, bind(C) :: draw_cmd
   !< ImDrawCmd (imgui.h, 1.93).
   real(c_float)      :: clip(4)    !< ClipRect.
   type(c_ptr)        :: tex_data   !< TexRef._TexData.
   integer(c_int64_t) :: tex_id     !< TexRef._TexID.
   integer(c_int)     :: vtx_offset !< VtxOffset.
   integer(c_int)     :: idx_offset !< IdxOffset.
   integer(c_int)     :: elem_count !< ElemCount.
   type(c_funptr)     :: callback   !< UserCallback.
   type(c_ptr)        :: cb_data    !< UserCallbackData.
   integer(c_int)     :: cb_size    !< UserCallbackDataSize.
   integer(c_int)     :: cb_offset  !< UserCallbackDataOffset.
endtype draw_cmd

contains
   subroutine dd_snapshot(d)
   !< The current window's draw data now (no allocation).
   type(draw_data), intent(out) :: d    !< Draw data.
   type(list_head), pointer     :: h    !< The window's list.
   type(draw_cmd),  pointer     :: c(:) !< Its commands.
   integer(int32)               :: k    !< Command.

   call c_f_pointer(igGetWindowDrawList(), h)
   d%ncmd = int(h%cmd_size, int32)
   d%nvtx = int(h%vtx_size, int32)
   d%nidx = int(h%idx_size, int32)
   if (d%ncmd <= 0_int32) return
   call c_f_pointer(h%cmd_data, c, [d%ncmd])
   do k = 1_int32, min(d%ncmd, DD_CMDS)
      d%cmd(1, k) = int(c(k)%vtx_offset, int32)
      d%cmd(2, k) = int(c(k)%idx_offset, int32)
      d%cmd(3, k) = int(c(k)%elem_count, int32)
   enddo
   endsubroutine dd_snapshot

   function dd_equal(a, b, label) result(ok)
   !< Two sides' draw data equal (counts, and each command's offsets and count); the difference printed under `label`.
   type(draw_data),  intent(in) :: a, b  !< ImPlot's, the Fortran frame's.
   character(len=*), intent(in) :: label !< What is compared (case, frame).
   logical                      :: ok    !< Equal.
   integer(int32)               :: k     !< Command.

   ok = a%ncmd == b%ncmd .and. a%nvtx == b%nvtx .and. a%nidx == b%nidx
   if (ok) ok = all(a%cmd(:, 1:min(a%ncmd, DD_CMDS)) == b%cmd(:, 1:min(b%ncmd, DD_CMDS)))
   if (ok) return
   write(output_unit, '(A,A,6(1X,I0))') label, ': draw data (commands, vertices, indices) ImPlot, frame:', &
                                        a%ncmd, a%nvtx, a%nidx, b%ncmd, b%nvtx, b%nidx
   do k = 1_int32, min(max(a%ncmd, b%ncmd), DD_CMDS)
      if (all(a%cmd(:, k) == b%cmd(:, k))) cycle
      write(output_unit, '(A,I0,A,3(1X,I0),A,3(1X,I0))') '  command ', k, ': vtx/idx offset, count', a%cmd(:, k), &
                                                          ' |', b%cmd(:, k)
   enddo
   endfunction dd_equal
endmodule figure_test_drawdata
