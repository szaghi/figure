!< figure_renderer, the renderer seam: which renderers draw the app's frames (the Fortran path: FIGURE's own).
module figure_renderer
!< figure_renderer, the renderer seam: which renderers draw the app's frames (the Fortran path: FIGURE's own).
!<
!< szaghi/figure#15 P9, §2: one module name, two implementations, a build mode's `src` picking one (no run-time flag).
!< This one, `src/paths/fortran/render/`, is the Fortran path's: `renderer_install` gives the native layer the
!< renderers in Fortran: the CPU renderer (figure_render_cpu), which then draws every picture of the headless and
!< remote modes (captures, `test_capture`, `save_image`, the documentation's recordings) in place of
!< figure_swrast.cpp, and the OpenGL 3 renderer (figure_render_gl3), which draws a window's frames in place of Dear
!< ImGui's OpenGL 3 backend. The frame is read from Dear ImGui's draw data (figure_render_imgui) while the core is
!< Dear ImGui's. The current path's implementation (`src/paths/imgui/render/`) installs nothing.
use, intrinsic :: iso_c_binding, only : c_char, c_f_pointer, c_float, c_funloc, c_int, c_ptr
use, intrinsic :: iso_fortran_env, only : int8, int32
use figure_c_native, only : fig_set_cpu_renderer, fig_set_gl_renderer
use figure_cimgui, only : igGetDrawData
use figure_render, only : render_frame
use figure_render_cpu, only : cpu_renderer
use figure_render_gl3, only : gl3_renderer
use figure_render_imgui, only : render_frame_from_imgui

implicit none
private
public :: renderer_install

type(cpu_renderer), save :: cpu    !< The CPU renderer.
type(gl3_renderer), save :: gl     !< The OpenGL 3 renderer.
type(render_frame), save :: frame  !< The frame they draw (its arrays kept from frame to frame).
integer(int8),      save :: none(0) !< The GL renderer's picture: the framebuffer, not an array.

contains
   subroutine renderer_install()
   !< Install the path's renderers in the native layer, before the app's contexts are made: the CPU and the OpenGL 3
   !< renderers.
   integer(c_int) :: s !< Status (always FIG_OK).

   s = fig_set_cpu_renderer(c_funloc(cpu_frame))
   s = fig_set_gl_renderer(c_funloc(gl_init), c_funloc(gl_new_frame), c_funloc(gl_render), c_funloc(gl_shutdown))
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

   function gl_init(glsl, glsl_len) result(ok) bind(C)
   !< A window's OpenGL 3 renderer started, its context current (the backend's Init): 1, or 0 when it cannot.
   character(kind=c_char), intent(in) :: glsl(*)  !< The GLSL version line (`#version ...`, not terminated).
   integer(c_int),         value      :: glsl_len !< Its length.
   integer(c_int)                     :: ok       !< 1 started.
   character(len=glsl_len)            :: line     !< The line.
   integer(int32)                     :: k        !< Counter.

   do k = 1_int32, int(glsl_len, int32)
      line(k:k) = glsl(k)
   enddo
   ok = merge(1_c_int, 0_c_int, gl%init(line))
   endfunction gl_init

   subroutine gl_new_frame() bind(C)
   !< A window's frame begins (the backend's NewFrame: the device objects made on the first).
   call gl%new_frame()
   endsubroutine gl_new_frame

   subroutine gl_render() bind(C)
   !< A window's frame drawn (the backend's RenderDrawData): nothing for an empty framebuffer (a minimized window),
   !< else Dear ImGui's textures as the frame asks, then its lists.
   real(c_float)  :: clear(3)   !< Not used: the native layer cleared the framebuffer.
   integer(int32) :: fb_w, fb_h !< Framebuffer size [pixels].

   call render_frame_from_imgui(frame)
   if (frame%nlists < 0_int32) return
   fb_w = int(frame%size(1) * frame%fb_scale(1) + 0.5_c_float, int32)
   fb_h = int(frame%size(2) * frame%fb_scale(2) + 0.5_c_float, int32)
   if (fb_w <= 0_int32 .or. fb_h <= 0_int32) return
   clear = 0.0_c_float
   call gl%textures(igGetDrawData())
   call gl%render(frame, fb_w, fb_h, clear, none)
   endsubroutine gl_render

   subroutine gl_shutdown() bind(C)
   !< A window's renderer stopped (the backend's Shutdown).
   call gl%shutdown()
   endsubroutine gl_shutdown
endmodule figure_renderer
