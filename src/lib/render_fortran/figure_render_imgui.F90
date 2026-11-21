!< figure_render_imgui, a frame of the renderer contract read from Dear ImGui's draw data (implementation over Dear ImGui).
module figure_render_imgui
!< figure_render_imgui, a frame of the renderer contract read from Dear ImGui's draw data (implementation over Dear ImGui).
!<
!< szaghi/figure#15 P9: `render_frame_from_imgui` fills a `render_frame` (figure_render) from the current `ImDrawData`
!< (after `ImGui::Render`, before the next frame): the view, each list's vertices and indices in place (no copy), each
!< command's clip rectangle, texture, offsets, count and kind (a draw, or one of the samplers' callbacks the backends
!< register). Its `texture_of` finds the pixels of Dear ImGui's own textures (the font atlas: RGBA32 or Alpha8) and of
!< the program's (headless and remote modes' copies, through the native layer's `fig_cpu_texture`). Part of
!< implementation A of the seam (src/lib/core_imgui/): the Fortran core fills a frame from its own lists.
use, intrinsic :: iso_c_binding, only : c_associated, c_f_pointer, c_float, c_int, c_long_long, c_null_ptr, c_ptr
use, intrinsic :: iso_fortran_env, only : int32
use figure_c_native, only : fig_cpu_texture
use figure_cimgui, only : igGetDrawData
use figure_cimgui_core, only : figure_ImDrawData_cmd, figure_ImDrawData_get, figure_ImDrawData_list, &
                               figure_ImTextureData_pixels
use figure_render, only : render_frame, render_list, render_texture

implicit none
private
public :: render_frame_from_imgui

contains
   subroutine render_frame_from_imgui(frame)
   !< The current draw data as a frame (`frame%nlists` -1 when there are none); the arrays of its lists kept from call
   !< to call (grown when too short).
   type(render_frame), intent(inout) :: frame   !< Frame.
   type(c_ptr)                       :: dd      !< `ImDrawData*`.
   real(c_float)                     :: view(6) !< Position, size, framebuffer scale.
   integer(c_int)                    :: n       !< Lists.
   integer(c_int)                    :: nv, ni, nc, k !< A list's vertices, indices, commands; kind.
   type(c_ptr)                       :: pv, pi  !< Its buffers.
   integer(c_int)                    :: off(3)  !< A command's offsets and count.
   integer(int32)                    :: l, c    !< List, command.

   frame%texture_of => texture_of
   dd = igGetDrawData()
   n = -1_c_int
   if (c_associated(dd)) n = figure_ImDrawData_get(dd, view)
   frame%nlists = int(n, int32)
   if (n < 0_c_int) return
   frame%pos = view(1:2)
   frame%size = view(3:4)
   frame%fb_scale = view(5:6)
   if (allocated(frame%lists)) then
      if (size(frame%lists) < n) deallocate(frame%lists)
   endif
   if (.not. allocated(frame%lists)) allocate(frame%lists(max(int(n, int32), 8_int32)))
   do l = 1_int32, int(n, int32)
      associate(lst => frame%lists(l))
         call figure_ImDrawData_list(dd, int(l - 1_int32, c_int), pv, nv, pi, ni, nc)
         lst%vtx => null()
         lst%idx => null()
         if (nv > 0_c_int) call c_f_pointer(pv, lst%vtx, [nv])
         if (ni > 0_c_int) call c_f_pointer(pi, lst%idx, [ni])
         lst%ncmd = int(nc, int32)
         call reserve(lst, lst%ncmd)
         do c = 1_int32, lst%ncmd
            k = figure_ImDrawData_cmd(dd, int(l - 1_int32, c_int), int(c - 1_int32, c_int), lst%clip(:, c), &
                                      lst%tex_data(c), lst%tex_id(c), off)
            lst%kind(c) = int(k, int32)
            lst%vtx_offset(c) = int(off(1), int32)
            lst%idx_offset(c) = int(off(2), int32)
            lst%count(c) = int(off(3), int32)
         enddo
      endassociate
   enddo
   endsubroutine render_frame_from_imgui

   function texture_of(tex_data, tex_id, tex) result(found)
   !< The pixels of Dear ImGui's own texture, or of the program's by its id.
   type(c_ptr),          intent(in)  :: tex_data !< Dear ImGui's texture, or null.
   integer(c_long_long), intent(in)  :: tex_id   !< Else the texture's id.
   type(render_texture), intent(out) :: tex      !< Its pixels.
   logical                           :: found    !< It has pixels.
   type(c_ptr)                       :: p        !< Pixels.
   integer(c_int)                    :: w, h, ch, smooth !< Size, channels, filter.

   found = .false.
   p = c_null_ptr
   if (c_associated(tex_data)) then
      found = figure_ImTextureData_pixels(tex_data, p, w, h, ch) == 1_c_int
      smooth = 1_c_int
   else
      found = fig_cpu_texture(tex_id, w, h, ch, p, smooth) == 1_c_int
   endif
   if (.not. found) return
   found = c_associated(p) .and. w > 0_c_int .and. h > 0_c_int .and. (ch == 1_c_int .or. ch == 4_c_int)
   if (.not. found) return
   tex%width = int(w, int32)
   tex%height = int(h, int32)
   tex%channels = int(ch, int32)
   tex%smooth = smooth /= 0_c_int
   call c_f_pointer(p, tex%pixels, [int(w, int32) * int(h, int32) * int(ch, int32)])
   endfunction texture_of

   subroutine reserve(lst, n)
   !< Room for n commands in a list's arrays (kept when large enough).
   type(render_list), intent(inout) :: lst !< List.
   integer(int32),    intent(in)    :: n   !< Commands.
   integer(int32)                   :: m   !< Capacity.

   if (allocated(lst%kind)) then
      if (size(lst%kind, kind=int32) >= n) return
      deallocate(lst%clip, lst%tex_data, lst%tex_id, lst%vtx_offset, lst%idx_offset, lst%count, lst%kind)
   endif
   m = max(n, 64_int32)
   allocate(lst%clip(4, m), lst%tex_data(m), lst%tex_id(m), lst%vtx_offset(m), lst%idx_offset(m), lst%count(m), &
            lst%kind(m))
   endsubroutine reserve
endmodule figure_render_imgui
