!< figure_c_native, the raw C interfaces of FIGURE's native glue (native/figure_native.h).
module figure_c_native
!< figure_c_native, the raw C interfaces of FIGURE's native glue (native/figure_native.h).
!<
!< Private to the library: applications use figure_app, figure_imgui and figure_implot. The glue owns the platform
!< (window, OpenGL context) and calls the cimgui/cimplot functions Fortran cannot call directly (structs larger than
!< `ImVec2` passed by value); the direct ones are generated in figure_cimgui and figure_cimplot. Strings passed to
!< the glue are (pointer, length), not NUL-terminated.
use, intrinsic :: iso_c_binding, only : c_char, c_double, c_float, c_int, c_long_long, c_ptr

implicit none
private
public :: FIG_OK, FIG_ERR_STATE, FIG_ERR_ARGUMENT, FIG_ERR_FAILED, FIG_ERR_EXCEPTION
public :: fig_init, fig_init_headless, fig_begin_frame, fig_end_frame, fig_shutdown, fig_set_lazy, fig_request_frames
public :: fig_init_remote, fig_set_ini_file, fig_texture_create, fig_texture_destroy, fig_texture_sampling, fig_texture_update
public :: fig_content_scale, fig_last_error, fig_set_last_error, fig_input_mouse

! Status codes: must match native/figure_native.h.
integer(c_int), parameter :: FIG_OK            = 0_c_int !< Success.
integer(c_int), parameter :: FIG_ERR_STATE     = 1_c_int !< Call not allowed in the current state.
integer(c_int), parameter :: FIG_ERR_ARGUMENT  = 2_c_int !< Invalid argument.
integer(c_int), parameter :: FIG_ERR_FAILED    = 3_c_int !< The platform (SDL, OpenGL) reported a failure.
integer(c_int), parameter :: FIG_ERR_EXCEPTION = 4_c_int !< A C++ exception was caught at the boundary.

interface
   ! ---- FIGURE glue ---------------------------------------------------------------------------------------------------
   function fig_init(title, title_len, width, height, vsync) result(status) bind(C, name='fig_init')
   !< Open the window and create the ImGui/ImPlot contexts.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: title(*)  !< Window title (UTF-8, not NUL-terminated).
   integer(c_int), value              :: title_len !< Title length [bytes].
   integer(c_int), value              :: width     !< Window width [logical pixels].
   integer(c_int), value              :: height    !< Window height [logical pixels].
   integer(c_int), value              :: vsync     !< 1: synchronize swaps with the display.
   integer(c_int)                     :: status    !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_init

   function fig_init_headless(width, height) result(status) bind(C, name='fig_init_headless')
   !< Create the ImGui/ImPlot contexts without a window or GPU (tests).
   import :: c_int
   implicit none
   integer(c_int), value :: width  !< Virtual display width [pixels].
   integer(c_int), value :: height !< Virtual display height [pixels].
   integer(c_int)        :: status !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_init_headless

   function fig_init_remote(width, height, host, host_len, port, bound_port) result(status) &
      bind(C, name='fig_init_remote')
   !< Create the contexts and serve the UI to a web browser on http://host:port/ (no window, display or GPU).
   import :: c_char, c_int
   implicit none
   integer(c_int), value              :: width      !< Initial display width [pixels], until the browser's.
   integer(c_int), value              :: height     !< Initial display height [pixels].
   character(kind=c_char), intent(in) :: host(*)    !< Address to listen on (not NUL-terminated); empty: 127.0.0.1.
   integer(c_int), value              :: host_len   !< Host length [bytes].
   integer(c_int), value              :: port       !< Port; 0: any free port.
   integer(c_int), intent(out)        :: bound_port !< The port listened on.
   integer(c_int)                     :: status     !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_init_remote

   function fig_begin_frame(running) result(status) bind(C, name='fig_begin_frame')
   !< Process events (waiting if lazy) and open a frame; `running` is 0 when the user closed the window.
   import :: c_int
   implicit none
   integer(c_int), intent(out) :: running !< 1 while the application should keep running.
   integer(c_int)              :: status  !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_begin_frame

   function fig_end_frame() result(status) bind(C, name='fig_end_frame')
   !< Render the frame and present it.
   import :: c_int
   implicit none
   integer(c_int) :: status !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_end_frame

   subroutine fig_shutdown() bind(C, name='fig_shutdown')
   !< Destroy contexts, window and platform; safe to call in any state.
   implicit none
   endsubroutine fig_shutdown

   function fig_set_ini_file(path, path_len) result(status) bind(C, name='fig_set_ini_file')
   !< Keep window positions and sizes in this file (Dear ImGui's imgui.ini); off by default. Before the first frame.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: path(*)  !< File path (not NUL-terminated); empty: no file.
   integer(c_int), value              :: path_len !< Path length [bytes].
   integer(c_int)                     :: status   !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_set_ini_file

   subroutine fig_set_lazy(enabled, max_wait_s) bind(C, name='fig_set_lazy')
   !< Lazy redraw: sleep until an event or `max_wait_s` seconds once the UI has settled.
   import :: c_double, c_int
   implicit none
   integer(c_int), value :: enabled    !< 1: lazy redraw on.
   real(c_double), value :: max_wait_s !< Longest sleep [s].
   endsubroutine fig_set_lazy

   subroutine fig_request_frames(n) bind(C, name='fig_request_frames')
   !< Draw at least `n` more frames without waiting (animations, data that changed).
   import :: c_int
   implicit none
   integer(c_int), value :: n !< Frames.
   endsubroutine fig_request_frames

   function fig_content_scale() result(scale) bind(C, name='fig_content_scale')
   !< Display content scale (1 on standard displays, 2 on most high-DPI ones).
   import :: c_double
   implicit none
   real(c_double) :: scale !< Content scale.
   endfunction fig_content_scale

   function fig_last_error(len) result(msg) bind(C, name='fig_last_error')
   !< Message of the last failure (borrowed: copy it).
   import :: c_int, c_ptr
   implicit none
   integer(c_int), intent(out) :: len !< Message length [bytes].
   type(c_ptr)                 :: msg !< First byte of the message (borrowed).
   endfunction fig_last_error

   subroutine fig_set_last_error(msg, msg_len) bind(C, name='fig_set_last_error')
   !< Set the message `fig_last_error` returns (failures detected on the Fortran side).
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: msg(*)  !< Message (not NUL-terminated).
   integer(c_int), value              :: msg_len !< Message length [bytes].
   endsubroutine fig_set_last_error

   function fig_texture_create(width, height, smooth, id) result(status) bind(C, name='fig_texture_create')
   !< Create an RGBA texture (contents undefined until updated).
   import :: c_int, c_long_long
   implicit none
   integer(c_int), value             :: width  !< Width [pixels].
   integer(c_int), value             :: height !< Height [pixels].
   integer(c_int), value             :: smooth !< 1: linear filtering, 0: nearest (pixels stay sharp).
   integer(c_long_long), intent(out) :: id     !< ImTextureID (C `unsigned long long`).
   integer(c_int)                    :: status !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_texture_create

   function fig_texture_update(id, width, height, rgba) result(status) bind(C, name='fig_texture_update')
   !< Upload all the pixels of a texture: `width` x `height` RGBA, 8 bits per channel, rows of `width` pixels.
   import :: c_int, c_long_long, c_ptr
   implicit none
   integer(c_long_long), value :: id     !< Texture.
   integer(c_int), value       :: width  !< Width [pixels]: must equal the texture's.
   integer(c_int), value       :: height !< Height [pixels]: must equal the texture's.
   type(c_ptr), value          :: rgba   !< First byte of the pixels (read during the call only).
   integer(c_int)              :: status !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_texture_update

   subroutine fig_texture_destroy(id) bind(C, name='fig_texture_destroy')
   !< Destroy a texture; an unknown id (already destroyed, or after shutdown) is ignored.
   import :: c_long_long
   implicit none
   integer(c_long_long), value :: id !< Texture.
   endsubroutine fig_texture_destroy

   subroutine fig_texture_sampling(plot, from_texture) bind(C, name='fig_texture_sampling')
   !< Around a user image: 1 = sample with the texture's own filter, 0 = restore the backend's render state.
   import :: c_int
   implicit none
   integer(c_int), value :: plot         !< 1: the current plot's draw list; 0: the current window's.
   integer(c_int), value :: from_texture !< 1: before the image; 0: after it.
   endsubroutine fig_texture_sampling

   subroutine fig_input_mouse(x, y, left_down) bind(C, name='fig_input_mouse')
   !< Queue a synthetic mouse state (tests).
   import :: c_float, c_int
   implicit none
   real(c_float), value  :: x         !< Abscissa [pixels].
   real(c_float), value  :: y         !< Ordinate [pixels].
   integer(c_int), value :: left_down !< 1: left button pressed.
   endsubroutine fig_input_mouse
endinterface
endmodule figure_c_native
