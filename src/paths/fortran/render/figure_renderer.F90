!< figure_renderer, the renderer seam: which renderers draw the app's frames (the Fortran path: FIGURE's own).
module figure_renderer
!< figure_renderer, the renderer seam: which renderers draw the app's frames (the Fortran path: FIGURE's own).
!<
!< szaghi/figure#15 P9, §2: one module name, two implementations, a build mode's `src` picking one (no run-time flag).
!< This one, `src/paths/fortran/render/`, is the Fortran path's: `renderer_install` gives the native layer the CPU
!< renderer in Fortran (figure_render_cpu), which then draws every picture of the headless and remote modes (captures,
!< `test_capture`, `save_image`, the documentation's recordings) in place of figure_swrast.cpp. The frame is read from
!< Dear ImGui's draw data (figure_render_imgui) while the core is Dear ImGui's. The current path's implementation
!< (`src/paths/imgui/render/`) installs nothing.
use, intrinsic :: iso_c_binding, only : c_f_pointer, c_float, c_funloc, c_int, c_ptr
use, intrinsic :: iso_fortran_env, only : int8, int32
use figure_c_native, only : fig_set_cpu_renderer
use figure_render, only : render_frame
use figure_render_cpu, only : cpu_renderer
use figure_render_imgui, only : render_frame_from_imgui

implicit none
private
public :: renderer_install

type(cpu_renderer), save :: cpu   !< The CPU renderer.
type(render_frame), save :: frame !< The frame it draws (its arrays kept from frame to frame).

contains
   subroutine renderer_install()
   !< Install the path's renderers in the native layer, before the app's contexts are made: the CPU renderer.
   integer(c_int) :: s !< Status (always FIG_OK).

   s = fig_set_cpu_renderer(c_funloc(cpu_frame))
   endsubroutine renderer_install

   subroutine cpu_frame(width, height, clear, rgb, threads) bind(C)
   !< The native layer's CPU picture of the frame just rendered (after `ImGui::Render`): drawn by the CPU renderer.
   integer(c_int), value      :: width    !< Picture's width [pixels].
   integer(c_int), value      :: height   !< Picture's height [pixels].
   real(c_float),  intent(in) :: clear(3) !< Clear colour.
   type(c_ptr),    value      :: rgb      !< Picture: 3 * width * height bytes, RGB, rows from the top.
   integer(c_int), value      :: threads  !< Threads (0: the renderer's default, `FIGURE_RENDER_THREADS`).
   integer(int8), pointer     :: pixels(:) !< The picture.

   if (width <= 0_c_int .or. height <= 0_c_int) return
   call c_f_pointer(rgb, pixels, [3 * int(width, int32) * int(height, int32)])
   call render_frame_from_imgui(frame)
   cpu%threads = int(threads, int32)
   call cpu%render(frame, int(width, int32), int(height, int32), clear, pixels)
   endsubroutine cpu_frame
endmodule figure_renderer
