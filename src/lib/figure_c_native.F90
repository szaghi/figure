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
public :: fig_set_remote_fps, fig_set_remote_compress, fig_set_remote_token, fig_remote_token
public :: fig_init_remote, fig_set_ini_file, fig_set_style, fig_texture_create, fig_texture_destroy, fig_texture_sampling
public :: fig_texture_update
public :: fig_content_scale, fig_last_error, fig_set_last_error, fig_input_mouse
public :: fig_set_docking, fig_dock_id, fig_dock_space, fig_dock_layout_begin, fig_dock_split, fig_dock_window
public :: fig_dock_layout_end, fig_window_dock, fig_style_color, fig_style_var, fig_load_style, fig_save_style
public :: fig_show_style_editor, fig_set_font, fig_push_font, fig_pop_font, fig_push_style_color, fig_push_style_var
public :: fig_pop_style, fig_input_mouse_pos, fig_input_mouse_button, fig_input_wheel, fig_input_key, fig_input_text
public :: fig_window_rect, fig_input_next_frame, fig_widget_input_text, fig_key_chord, fig_plot_tick_label
public :: fig_set_confirm_quit, fig_quit_requested, fig_quit, fig_input_quit, fig_file_dialog, fig_file_dialog_result
public :: fig_save_image, fig_image_result, fig_save_layout, fig_load_layout, fig_begin_side_bar
public :: fig_set_title, fig_title

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

   function fig_set_style(name, name_len, lines, lines_len) result(status) bind(C, name='fig_set_style')
   !< Apply a built-in style (themes/<name>.toml), with its own line colours or a named palette.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: name(*)   !< Style name (not NUL-terminated).
   integer(c_int), value              :: name_len  !< Name length [bytes].
   character(kind=c_char), intent(in) :: lines(*)  !< Line palette (okabe-ito), or empty for the theme's own.
   integer(c_int), value              :: lines_len !< Palette name length [bytes].
   integer(c_int)                     :: status    !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_set_style

   subroutine fig_set_lazy(enabled, max_wait_s) bind(C, name='fig_set_lazy')
   !< Lazy redraw: sleep until an event or `max_wait_s` seconds once the UI has settled.
   import :: c_double, c_int
   implicit none
   integer(c_int), value :: enabled    !< 1: lazy redraw on.
   real(c_double), value :: max_wait_s !< Longest sleep [s].
   endsubroutine fig_set_lazy

   subroutine fig_set_remote_fps(max_fps) bind(C, name='fig_set_remote_fps')
   !< Remote mode: at most `max_fps` frames per second (0 or less: no cap).
   import :: c_double
   implicit none
   real(c_double), value :: max_fps !< Frames per second.
   endsubroutine fig_set_remote_fps

   subroutine fig_set_remote_compress(mode) bind(C, name='fig_set_remote_compress')
   !< Remote mode: deflate frames and textures, 0 auto (while the client is the bottleneck), 1 always, 2 never.
   import :: c_int
   implicit none
   integer(c_int), value :: mode !< Mode.
   endsubroutine fig_set_remote_compress

   subroutine fig_set_remote_token(token, token_len) bind(C, name='fig_set_remote_token')
   !< Remote mode: the access token (empty: none).
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: token(*)  !< Token (not NUL-terminated).
   integer(c_int), value              :: token_len !< Its length.
   endsubroutine fig_set_remote_token

   function fig_remote_token(buf, buf_len) result(n) bind(C, name='fig_remote_token')
   !< Remote mode: copy the access token into `buf` (up to `buf_len` characters); its length.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(out) :: buf(*)  !< Buffer.
   integer(c_int), value               :: buf_len !< Its length.
   integer(c_int)                      :: n       !< Token length.
   endfunction fig_remote_token

   function fig_file_dialog(kind, id, id_len, filters, filters_len, path, path_len) result(status) &
      bind(C, name='fig_file_dialog')
   !< Open a native file dialog (window mode): kind 0 open, 1 save, 2 folder.
   import :: c_char, c_int
   implicit none
   integer(c_int), value              :: kind        !< 0 open, 1 save, 2 folder.
   character(kind=c_char), intent(in) :: id(*)       !< Dialog id (not NUL-terminated).
   integer(c_int), value              :: id_len      !< Its length.
   character(kind=c_char), intent(in) :: filters(*)  !< "name|pattern" entries separated by newlines.
   integer(c_int), value              :: filters_len !< Their length.
   character(kind=c_char), intent(in) :: path(*)     !< Default location.
   integer(c_int), value              :: path_len    !< Its length (0: none).
   integer(c_int)                     :: status      !< Status.
   endfunction fig_file_dialog

   function fig_file_dialog_result(id, id_len, buf, buf_len, state, path_len) result(status) &
      bind(C, name='fig_file_dialog_result')
   !< The result of a dialog: state 0 open, 1 chosen, 2 cancelled, 3 failed.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in)  :: id(*)    !< Dialog id.
   integer(c_int), value               :: id_len   !< Its length.
   character(kind=c_char), intent(out) :: buf(*)   !< Path chosen.
   integer(c_int), value               :: buf_len  !< Buffer length.
   integer(c_int), intent(out)         :: state    !< State.
   integer(c_int), intent(out)         :: path_len !< Full length of the path.
   integer(c_int)                      :: status   !< Status.
   endfunction fig_file_dialog_result

   function fig_save_image(path, path_len, x0, y0, x1, y1) result(status) bind(C, name='fig_save_image')
   !< Ask for the rectangle (x0, y0)-(x1, y1) [logical pixels] of the window as a PNG file, written when this frame is
   !< rendered.
   import :: c_char, c_double, c_int
   implicit none
   character(kind=c_char), intent(in) :: path(*)  !< File.
   integer(c_int), value              :: path_len !< Its length.
   real(c_double), value              :: x0, y0   !< Top left.
   real(c_double), value              :: x1, y1   !< Bottom right.
   integer(c_int)                     :: status   !< Status.
   endfunction fig_save_image

   function fig_image_result(buf, buf_len, state, path_len) result(status) bind(C, name='fig_image_result')
   !< The outcome of the last save_image, once: state 0 none yet, 2 written, 3 failed.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(out) :: buf(*)   !< File.
   integer(c_int), value               :: buf_len  !< Buffer length.
   integer(c_int), intent(out)         :: state    !< State.
   integer(c_int), intent(out)         :: path_len !< Full length of the path.
   integer(c_int)                      :: status   !< Status.
   endfunction fig_image_result

   function fig_save_layout(path, path_len, comment, comment_len) result(status) bind(C, name='fig_save_layout')
   !< Write the layout (Dear ImGui's settings) to `path`, after the `comment` lines (newline-separated) as comments.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: path(*)     !< File.
   integer(c_int), value              :: path_len    !< Its length.
   character(kind=c_char), intent(in) :: comment(*)  !< Comment lines.
   integer(c_int), value              :: comment_len !< Their length.
   integer(c_int)                     :: status      !< Status.
   endfunction fig_save_layout

   function fig_begin_side_bar(name, name_len, side, size) result(visible) bind(C, name='fig_begin_side_bar')
   !< Begin a bar along one side of the display (0 left, 1 right, 2 top, 3 bottom): 1 when its content is drawn.
   import :: c_char, c_double, c_int
   implicit none
   character(kind=c_char), intent(in) :: name(*)  !< Window name.
   integer(c_int), value              :: name_len !< Its length.
   integer(c_int), value              :: side     !< Side.
   real(c_double), value              :: size     !< Width (left, right) or height (top, bottom) [pixels].
   integer(c_int)                     :: visible  !< 1: drawn.
   endfunction fig_begin_side_bar

   function fig_load_layout(path, path_len) result(status) bind(C, name='fig_load_layout')
   !< Read a layout from `path`, applied before the next frame.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: path(*)  !< File.
   integer(c_int), value              :: path_len !< Its length.
   integer(c_int)                     :: status   !< Status.
   endfunction fig_load_layout

   subroutine fig_set_confirm_quit(on) bind(C, name='fig_set_confirm_quit')
   !< A quit request (the window's close button) is reported instead of ending the loop (1) or ends it (0).
   import :: c_int
   implicit none
   integer(c_int), value :: on !< 1: confirm first.
   endsubroutine fig_set_confirm_quit

   function fig_quit_requested() result(requested) bind(C, name='fig_quit_requested')
   !< 1 once per quit request (then cleared).
   import :: c_int
   implicit none
   integer(c_int) :: requested !< 1: requested.
   endfunction fig_quit_requested

   subroutine fig_quit() bind(C, name='fig_quit')
   !< End the loop at the next begin_frame.
   endsubroutine fig_quit

   function fig_set_title(title, title_len) result(status) bind(C, name='fig_set_title')
   !< The window's title (window mode: shown; every mode: kept).
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: title(*)  !< Title (not NUL-terminated).
   integer(c_int), value              :: title_len !< Its length.
   integer(c_int)                     :: status    !< Status.
   endfunction fig_set_title

   function fig_title(buf, buf_len) result(n) bind(C, name='fig_title')
   !< Copy the window's title into `buf` (up to `buf_len` characters); its length.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(out) :: buf(*)  !< Buffer.
   integer(c_int), value               :: buf_len !< Its length.
   integer(c_int)                      :: n       !< Title length.
   endfunction fig_title

   function fig_input_quit() result(status) bind(C, name='fig_input_quit')
   !< A quit request, as the window's close button makes it.
   import :: c_int
   implicit none
   integer(c_int) :: status !< Status.
   endfunction fig_input_quit

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

   function fig_load_style(path, path_len) result(status) bind(C, name='fig_load_style')
   !< Apply a theme file.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: path(*)  !< File path (not NUL-terminated).
   integer(c_int), value              :: path_len !< Path length [bytes].
   integer(c_int)                     :: status   !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_load_style

   function fig_save_style(path, path_len) result(status) bind(C, name='fig_save_style')
   !< Write the style in effect as a theme file.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: path(*)  !< File path (not NUL-terminated).
   integer(c_int), value              :: path_len !< Path length [bytes].
   integer(c_int)                     :: status   !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_save_style

   function fig_push_style_color(lib, name, name_len, rgba) result(status) bind(C, name='fig_push_style_color')
   !< Change a style colour until fig_pop_style(0, n): lib 0 Dear ImGui, 1 ImPlot.
   import :: c_char, c_float, c_int
   implicit none
   integer(c_int), value              :: lib      !< 0: Dear ImGui, 1: ImPlot.
   character(kind=c_char), intent(in) :: name(*)  !< Colour name (not NUL-terminated).
   integer(c_int), value              :: name_len !< Name length [bytes].
   real(c_float), intent(in)          :: rgba(4)  !< Colour, components in [0, 1].
   integer(c_int)                     :: status   !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_push_style_color

   function fig_push_style_var(lib, name, name_len, values, count) result(status) bind(C, name='fig_push_style_var')
   !< Change a style variable until fig_pop_style(1, n): lib 0 Dear ImGui, 1 ImPlot.
   import :: c_char, c_double, c_int
   implicit none
   integer(c_int), value              :: lib       !< 0: Dear ImGui, 1: ImPlot.
   character(kind=c_char), intent(in) :: name(*)   !< Variable name (not NUL-terminated).
   integer(c_int), value              :: name_len  !< Name length [bytes].
   real(c_double), intent(in)         :: values(2) !< Value(s).
   integer(c_int), value              :: count     !< Values given: 1 or 2.
   integer(c_int)                     :: status    !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_push_style_var

   function fig_pop_style(vars, n) result(status) bind(C, name='fig_pop_style')
   !< Undo the n newest pushes of colours (vars = 0) or variables (vars = 1).
   import :: c_int
   implicit none
   integer(c_int), value :: vars   !< 0: colours, 1: variables.
   integer(c_int), value :: n      !< How many.
   integer(c_int)        :: status !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_pop_style

   function fig_set_font(name, name_len, size) result(status) bind(C, name='fig_set_font')
   !< The default font (plex-sans, proggy or a TTF/OTF file) and, if size > 0, its size [logical pixels].
   import :: c_char, c_double, c_int
   implicit none
   character(kind=c_char), intent(in) :: name(*)  !< Font (not NUL-terminated).
   integer(c_int), value              :: name_len !< Name length [bytes].
   real(c_double), value              :: size     !< Size [logical pixels]; 0: keep.
   integer(c_int)                     :: status   !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_set_font

   function fig_push_font(name, name_len, size) result(status) bind(C, name='fig_push_font')
   !< Switch the font (name empty: keep) and/or its size (0: keep) until fig_pop_font.
   import :: c_char, c_double, c_int
   implicit none
   character(kind=c_char), intent(in) :: name(*)  !< Font (not NUL-terminated).
   integer(c_int), value              :: name_len !< Name length [bytes].
   real(c_double), value              :: size     !< Size [logical pixels]; 0: keep.
   integer(c_int)                     :: status   !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_push_font

   function fig_pop_font() result(status) bind(C, name='fig_pop_font')
   !< Back to the font before the last fig_push_font.
   import :: c_int
   implicit none
   integer(c_int) :: status !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_pop_font

   function fig_show_style_editor(open) result(status) bind(C, name='fig_show_style_editor')
   !< Dear ImGui's and ImPlot's style editors in a window.
   import :: c_int, c_ptr
   implicit none
   type(c_ptr), value :: open   !< int* (1: open), or null for no close button.
   integer(c_int)     :: status !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_show_style_editor

   function fig_style_color(lib, name, name_len, set, rgba) result(status) bind(C, name='fig_style_color')
   !< Read (set = 0) or write (set = 1) a style colour by name: lib 0 Dear ImGui, 1 ImPlot.
   import :: c_char, c_float, c_int
   implicit none
   integer(c_int), value              :: lib      !< 0: Dear ImGui, 1: ImPlot.
   character(kind=c_char), intent(in) :: name(*)  !< Colour name (not NUL-terminated).
   integer(c_int), value              :: name_len !< Name length [bytes].
   integer(c_int), value              :: set      !< 1: write, 0: read.
   real(c_float), intent(inout)       :: rgba(4)  !< Colour, components in [0, 1].
   integer(c_int)                     :: status   !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_style_color

   function fig_style_var(lib, name, name_len, set, values, count) result(status) bind(C, name='fig_style_var')
   !< Read (set = 0) or write (set = 1) a style variable by name: lib 0 Dear ImGui, 1 ImPlot.
   import :: c_char, c_double, c_int
   implicit none
   integer(c_int), value              :: lib       !< 0: Dear ImGui, 1: ImPlot.
   character(kind=c_char), intent(in) :: name(*)   !< Variable name (not NUL-terminated).
   integer(c_int), value              :: name_len  !< Name length [bytes].
   integer(c_int), value              :: set       !< 1: write, 0: read.
   real(c_double), intent(inout)      :: values(2) !< Value(s).
   integer(c_int), intent(inout)      :: count     !< Values given (write) or returned (read): 1 or 2.
   integer(c_int)                     :: status    !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_style_var

   function fig_set_docking(enabled) result(status) bind(C, name='fig_set_docking')
   !< Docking on (1) or off (0).
   import :: c_int
   implicit none
   integer(c_int), value :: enabled !< 1: docking on.
   integer(c_int)        :: status  !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_set_docking

   function fig_dock_id(name, name_len) result(id) bind(C, name='fig_dock_id')
   !< Dock id (an ImGuiID, unsigned 32-bit, carried as c_int) of a name.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: name(*)  !< Name (not NUL-terminated).
   integer(c_int), value              :: name_len !< Name length [bytes].
   integer(c_int)                     :: id       !< Dock id.
   endfunction fig_dock_id

   function fig_dock_space(id, flags) result(status) bind(C, name='fig_dock_space')
   !< A dock space over the whole display, every frame, before the windows docked into it.
   import :: c_int
   implicit none
   integer(c_int), value :: id     !< Dock id.
   integer(c_int), value :: flags  !< ImGuiDockNodeFlags.
   integer(c_int)        :: status !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_dock_space

   function fig_dock_layout_begin(id, needed) result(status) bind(C, name='fig_dock_layout_begin')
   !< Start a layout if the dock node does not exist yet (needed = 1).
   import :: c_int
   implicit none
   integer(c_int), value       :: id     !< Dock id.
   integer(c_int), intent(out) :: needed !< 1: build the layout now.
   integer(c_int)              :: status !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_dock_layout_begin

   function fig_dock_split(id, direction, fraction, id_at_dir, id_other) result(status) bind(C, name='fig_dock_split')
   !< Split a dock node in two.
   import :: c_double, c_int
   implicit none
   integer(c_int), value       :: id        !< Node to split.
   integer(c_int), value       :: direction !< ImGuiDir: 0 left, 1 right, 2 up, 3 down.
   real(c_double), value       :: fraction  !< Part of the node given to the side at `direction`.
   integer(c_int), intent(out) :: id_at_dir !< The new node at `direction`.
   integer(c_int), intent(out) :: id_other  !< The new node on the other side.
   integer(c_int)              :: status    !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_dock_split

   function fig_dock_window(name, name_len, id) result(status) bind(C, name='fig_dock_window')
   !< Dock a window (by its name) into a node of a layout.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: name(*)  !< Window name (not NUL-terminated).
   integer(c_int), value              :: name_len !< Name length [bytes].
   integer(c_int), value              :: id       !< Dock node.
   integer(c_int)                     :: status   !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_dock_window

   function fig_dock_layout_end(id) result(status) bind(C, name='fig_dock_layout_end')
   !< Finish a layout.
   import :: c_int
   implicit none
   integer(c_int), value :: id     !< Dock id.
   integer(c_int)        :: status !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_dock_layout_end

   function fig_window_dock(id, docked) result(status) bind(C, name='fig_window_dock')
   !< Inside a window: its dock node (0 if none) and whether it is docked.
   import :: c_int
   implicit none
   integer(c_int), intent(out) :: id     !< Dock node.
   integer(c_int), intent(out) :: docked !< 1: docked.
   integer(c_int)              :: status !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_window_dock

   function fig_input_next_frame() result(status) bind(C, name='fig_input_next_frame')
   !< A frame boundary in the queued input: what follows reaches Dear ImGui one frame later.
   import :: c_int
   implicit none
   integer(c_int) :: status !< Status.
   endfunction fig_input_next_frame

   function fig_input_mouse_pos(x, y) result(status) bind(C, name='fig_input_mouse_pos')
   !< Queue a mouse position [pixels].
   import :: c_float, c_int
   implicit none
   real(c_float), value :: x      !< Abscissa.
   real(c_float), value :: y      !< Ordinate.
   integer(c_int)       :: status !< Status.
   endfunction fig_input_mouse_pos

   function fig_input_mouse_button(button, down) result(status) bind(C, name='fig_input_mouse_button')
   !< Queue a mouse button change: 0 left, 1 right, 2 middle.
   import :: c_int
   implicit none
   integer(c_int), value :: button !< Button.
   integer(c_int), value :: down   !< 1: pressed.
   integer(c_int)        :: status !< Status.
   endfunction fig_input_mouse_button

   function fig_input_wheel(dx, dy) result(status) bind(C, name='fig_input_wheel')
   !< Queue a wheel turn.
   import :: c_float, c_int
   implicit none
   real(c_float), value :: dx     !< Horizontal.
   real(c_float), value :: dy     !< Vertical (positive: away from the user).
   integer(c_int)       :: status !< Status.
   endfunction fig_input_wheel

   function fig_input_key(name, name_len, down) result(status) bind(C, name='fig_input_key')
   !< Queue a key change, by name.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: name(*)  !< Key name (not NUL-terminated).
   integer(c_int), value              :: name_len !< Name length [bytes].
   integer(c_int), value              :: down     !< 1: pressed.
   integer(c_int)                     :: status   !< Status.
   endfunction fig_input_key

   function fig_input_text(text, text_len) result(status) bind(C, name='fig_input_text')
   !< Queue typed characters (UTF-8).
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: text(*)  !< Text (not NUL-terminated).
   integer(c_int), value              :: text_len !< Text length [bytes].
   integer(c_int)                     :: status   !< Status.
   endfunction fig_input_text

   function fig_plot_tick_label(axis, index, buf, buf_len, count, label_len) result(status) &
      bind(C, name='fig_plot_tick_label')
   !< A tick label of the plot being declared.
   import :: c_char, c_int
   implicit none
   integer(c_int), value               :: axis      !< 0 x, 1 y.
   integer(c_int), value               :: index     !< Tick, from 1.
   character(kind=c_char), intent(out) :: buf(*)    !< Label.
   integer(c_int), value               :: buf_len   !< Buffer length.
   integer(c_int), intent(out)         :: count     !< Ticks on the axis.
   integer(c_int), intent(out)         :: label_len !< Length of the label.
   integer(c_int)                      :: status    !< Status.
   endfunction fig_plot_tick_label

   function fig_key_chord(keys, keys_len, chord) result(status) bind(C, name='fig_key_chord')
   !< A key chord from its name ("ctrl+s").
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: keys(*)  !< Chord name (not NUL-terminated).
   integer(c_int), value              :: keys_len !< Name length [bytes].
   integer(c_int), intent(out)        :: chord    !< ImGuiKeyChord.
   integer(c_int)                     :: status   !< Status: FIG_OK or FIG_ERR_ARGUMENT.
   endfunction fig_key_chord

   function fig_widget_input_text(label, label_len, hint, hint_len, buf, buf_size, flags) result(edited) &
      bind(C, name='fig_widget_input_text')
   !< A text field over a NUL-terminated buffer of `buf_size` bytes; 1 when the user edited it this frame.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in)    :: label(*)  !< Label (not NUL-terminated).
   integer(c_int), value                 :: label_len !< Label length [bytes].
   character(kind=c_char), intent(in)    :: hint(*)   !< Hint shown while empty (not NUL-terminated).
   integer(c_int), value                 :: hint_len  !< Hint length [bytes] (0: no hint).
   character(kind=c_char), intent(inout) :: buf(*)    !< Text, NUL-terminated.
   integer(c_int), value                 :: buf_size  !< Buffer size [bytes], NUL included.
   integer(c_int), value                 :: flags     !< ImGuiInputTextFlags.
   integer(c_int)                        :: edited    !< 1: edited this frame.
   endfunction fig_widget_input_text

   function fig_window_rect(name, name_len, rect, found) result(status) bind(C, name='fig_window_rect')
   !< A window's rectangle by name, as in the last frame.
   import :: c_char, c_float, c_int
   implicit none
   character(kind=c_char), intent(in) :: name(*)  !< Window name (not NUL-terminated).
   integer(c_int), value              :: name_len !< Name length [bytes].
   real(c_float), intent(out)         :: rect(4)  !< xmin, ymin, xmax, ymax [pixels].
   integer(c_int), intent(out)        :: found    !< 1: the window exists.
   integer(c_int)                     :: status   !< Status.
   endfunction fig_window_rect

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
