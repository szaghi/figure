!< figure_c_native, the raw C interfaces of FIGURE's native glue (native/figure_native.h).
module figure_c_native
!< figure_c_native, the raw C interfaces of FIGURE's native glue (native/figure_native.h).
!<
!< Private to the library: applications use figure_app, figure_imgui and figure_implot. The glue owns the platform
!< (window, OpenGL context) and calls the cimgui/cimplot functions Fortran cannot call directly (structs larger than
!< `ImVec2` passed by value); the direct ones are generated in figure_cimgui and figure_cimplot. Strings passed to
!< the glue are (pointer, length), not NUL-terminated.
use, intrinsic :: iso_c_binding, only : c_char, c_double, c_float, c_funptr, c_int, c_long_long, c_ptr

implicit none
private
public :: FIG_OK, FIG_ERR_STATE, FIG_ERR_ARGUMENT, FIG_ERR_FAILED, FIG_ERR_EXCEPTION
public :: fig_init, fig_init_headless, fig_begin_frame, fig_end_frame, fig_shutdown, fig_set_lazy, fig_request_frames
public :: fig_set_remote_fps, fig_set_remote_compress, fig_set_remote_token, fig_remote_token
public :: fig_set_remote_lossy
public :: fig_init_remote, fig_set_ini_file, fig_set_style, fig_texture_create, fig_texture_destroy, fig_texture_sampling
public :: fig_texture_update, fig_image_read, fig_image_free, fig_image_write
public :: fig_content_scale, fig_last_error, fig_set_last_error, fig_input_mouse
public :: fig_set_docking, fig_dock_id, fig_dock_space, fig_dock_layout_begin, fig_dock_split, fig_dock_window
public :: fig_dock_layout_end, fig_window_dock, fig_style_color, fig_style_var, fig_load_style, fig_save_style
public :: fig_show_style_editor, fig_set_font, fig_push_font, fig_pop_font, fig_push_style_color, fig_push_style_var
public :: fig_pop_style, fig_input_mouse_pos, fig_input_mouse_button, fig_input_wheel, fig_input_key, fig_input_text
public :: fig_window_rect, fig_input_next_frame, fig_widget_input_text, fig_shortcut, fig_plot_tick_label
public :: fig_app_wake, fig_set_next_item_shortcut, fig_last_item, fig_item_status, fig_mark_last_item_edited
public :: fig_drag_range, fig_list_box
public :: fig_align_begin, fig_align_end, fig_align_next, fig_plot_end, fig_plot_state, fig_plot_axis_constraints
public :: fig_plot3d_colormap, fig_plot3d_end, fig_plot3d_state
public :: fig_set_confirm_quit, fig_quit_requested, fig_quit, fig_input_quit, fig_file_dialog, fig_file_dialog_result
public :: fig_save_image, fig_image_result, fig_save_layout, fig_load_layout, fig_begin_side_bar
public :: fig_test_capture, fig_render_threads
public :: fig_tool_button, fig_clipper_new, fig_clipper_begin, fig_clipper_step, fig_clipper_delete
public :: fig_table_sort, fig_table_row_color, fig_table_column_enabled, fig_table_hovered_column
public :: fig_set_title, fig_title, fig_set_style_parts, fig_palette_color, fig_input_system_theme
public :: fig_frame_options, fig_set_icon_rgba, fig_set_icon_glyph, fig_frame_hit, fig_frame_rect, fig_frame_state
public :: fig_process_start, fig_process_pending, fig_process_take, fig_process_info, fig_process_kill
public :: fig_process_release
public :: fig_task_start, fig_task_state, fig_task_report, fig_task_fail, fig_task_cancel, fig_task_cancelled
public :: fig_task_finish, fig_task_release, fig_task_on_worker, fig_task_refuse
public :: fig_usage_error, fig_time, fig_add_fallback_font, fig_test_glyph
public :: fig_set_checks, fig_checks, fig_draw_refuse, fig_scope_open, fig_scope_close, fig_scope_report
public :: fig_notify, fig_notification_count, fig_notification_get, fig_notification_rect, fig_drawn_extent
public :: fig_notification_alpha
public :: fig_file_browser, fig_file_browser_settings, fig_file_browser_get, fig_file_browser_rect
public :: fig_text_set, fig_text_get, fig_text_length, fig_text_release, fig_widget_input_text_multiline
public :: fig_input_drop, fig_dropped, fig_dropped_path, fig_set_clipboard, fig_get_clipboard
public :: fig_colormap, fig_load_colormap, fig_colormap_count, fig_colormap_name
public :: fig_gradient_edit, fig_colormap_stops
public :: fig_plot_annotation, fig_drawn_extent_rgba, fig_plot_tag
public :: fig_colormap_legend, fig_popup_rect, fig_opened_url
public :: fig_items_record, fig_item_find, fig_item_value, fig_items_list, fig_items_name, fig_items_tooltip
public :: fig_item_click, fig_item_type, fig_menu_click, fig_test_run
public :: fig_field_image, fig_field_uploads, fig_field_count, fig_field_time, fig_field_pixel
public :: fig_canvas_event, fig_canvas, fig_draw, fig_cursor_screen_pos, fig_invisible_button, fig_drawn_extent_layer

public :: fig_window_add, fig_window_visible, fig_window_set_visible, fig_window_open_flag, fig_view_menu
public :: fig_layout_add, fig_layout_switch, fig_layout_reset, fig_layout_current
public :: fig_prefs_open, fig_prefs_file, fig_pref_set, fig_pref_get, fig_message_box, fig_splitter, fig_set_size_limits
! Status codes: must match native/figure_native.h.
integer(c_int), parameter :: FIG_OK            = 0_c_int !< Success.
integer(c_int), parameter :: FIG_ERR_STATE     = 1_c_int !< Call not allowed in the current state.
integer(c_int), parameter :: FIG_ERR_ARGUMENT  = 2_c_int !< Invalid argument.
integer(c_int), parameter :: FIG_ERR_FAILED    = 3_c_int !< The platform (SDL, OpenGL) reported a failure.
integer(c_int), parameter :: FIG_ERR_EXCEPTION = 4_c_int !< A C++ exception was caught at the boundary.

type, bind(C) :: fig_item_status
   !< The status of the item drawn last, as native/figure_native.h's `fig_item_status`: 1 or 0 each.
   integer(c_int) :: hovered = 0_c_int                !< IsItemHovered.
   integer(c_int) :: active = 0_c_int                 !< IsItemActive.
   integer(c_int) :: focused = 0_c_int                !< IsItemFocused.
   integer(c_int) :: visible = 0_c_int                !< IsItemVisible.
   integer(c_int) :: activated = 0_c_int              !< IsItemActivated.
   integer(c_int) :: edited = 0_c_int                 !< IsItemEdited.
   integer(c_int) :: deactivated = 0_c_int            !< IsItemDeactivated.
   integer(c_int) :: deactivated_after_edit = 0_c_int !< IsItemDeactivatedAfterEdit.
   integer(c_int) :: toggled_open = 0_c_int           !< IsItemToggledOpen.
   integer(c_int) :: clicked(3) = 0_c_int             !< IsItemClicked, per button (left, right, middle).
   integer(c_int) :: double_clicked(3) = 0_c_int      !< Double-clicked over the item, per button.
   real(c_double) :: rect(4) = 0.0_c_double           !< x, y, width, height [pixels].
endtype fig_item_status

type, bind(C) :: fig_canvas_event
   !< The event of a canvas in a frame, as native/figure_native.h's `fig_canvas_event`: flags 1 or 0, per button (left,
   !< right, middle).
   integer(c_int) :: hovered = 0_c_int           !< The pointer is over it.
   integer(c_int) :: active = 0_c_int            !< A button pressed over it is held.
   integer(c_int) :: clicked(3) = 0_c_int        !< Pressed over it on this frame.
   integer(c_int) :: double_clicked(3) = 0_c_int !< Double-clicked over it on this frame.
   integer(c_int) :: down(3) = 0_c_int           !< Held, pressed over it.
   integer(c_int) :: released(3) = 0_c_int       !< Released on this frame, pressed over it.
   integer(c_int) :: ctrl = 0_c_int              !< Ctrl held.
   integer(c_int) :: shift = 0_c_int             !< Shift held.
   integer(c_int) :: alt = 0_c_int               !< Alt held.
   integer(c_int) :: super = 0_c_int             !< Super (cmd, windows key) held.
   real(c_double) :: mouse(2) = 0.0_c_double     !< The pointer from the canvas's top-left [pixels].
   real(c_double) :: drag(2) = 0.0_c_double      !< The pointer from where the held button was pressed [pixels].
   real(c_double) :: delta(2) = 0.0_c_double     !< The pointer's motion this frame, while held [pixels].
   real(c_double) :: wheel = 0.0_c_double        !< Vertical wheel steps this frame, while hovered.
   real(c_double) :: wheel_h = 0.0_c_double      !< Horizontal wheel steps this frame, while hovered.
   real(c_double) :: origin(2) = 0.0_c_double    !< The canvas's top-left on the screen [pixels].
   real(c_double) :: size(2) = 0.0_c_double      !< Its width and height [pixels].
endtype fig_canvas_event

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

   function fig_set_style_parts(name, name_len, look, look_len, palette, palette_len, auto_dark, auto_dark_len, &
                                auto_light, auto_light_len, lines, lines_len) result(status) &
                                bind(C, name='fig_set_style_parts')
   !< The style by parts, at once: a built-in style, then a look, a palette, a line palette (empty: kept).
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: name(*)        !< Style name (not NUL-terminated).
   integer(c_int), value              :: name_len       !< Its length [bytes]; 0: not given.
   character(kind=c_char), intent(in) :: look(*)        !< Look name.
   integer(c_int), value              :: look_len       !< Its length [bytes]; 0: not given.
   character(kind=c_char), intent(in) :: palette(*)     !< Palette name, or auto.
   integer(c_int), value              :: palette_len    !< Its length [bytes]; 0: not given.
   character(kind=c_char), intent(in) :: auto_dark(*)   !< Palette of auto on a dark system.
   integer(c_int), value              :: auto_dark_len  !< Its length [bytes]; 0: not given.
   character(kind=c_char), intent(in) :: auto_light(*)  !< Palette of auto on a light system.
   integer(c_int), value              :: auto_light_len !< Its length [bytes]; 0: not given.
   character(kind=c_char), intent(in) :: lines(*)       !< Line palette (okabe-ito).
   integer(c_int), value              :: lines_len      !< Its length [bytes]; 0: not given.
   integer(c_int)                     :: status         !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_set_style_parts

   function fig_palette_color(role, role_len, rgba) result(status) bind(C, name='fig_palette_color')
   !< The colour of a palette role in effect.
   import :: c_char, c_float, c_int
   implicit none
   character(kind=c_char), intent(in)  :: role(*)  !< Role name (not NUL-terminated).
   integer(c_int), value               :: role_len !< Its length [bytes].
   real(c_float),          intent(out) :: rgba(4)  !< Colour, components in [0, 1].
   integer(c_int)                      :: status   !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_palette_color

   function fig_input_system_theme(theme) result(status) bind(C, name='fig_input_system_theme')
   !< The system's light (1) or dark (2) setting, handled at the next frame as SDL's event; 0: the system's again.
   import :: c_int
   implicit none
   integer(c_int), value :: theme  !< 0, 1 or 2.
   integer(c_int)        :: status !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_input_system_theme

   function fig_frame_options(decorations, buttons) result(status) bind(C, name='fig_frame_options')
   !< The window's frame of the next init: decorations 0 native, 1 figure; buttons 0 the platform's side, 1 right, 2 left.
   import :: c_int
   implicit none
   integer(c_int), value :: decorations !< 0 native, 1 figure.
   integer(c_int), value :: buttons     !< 0 the platform's side, 1 right, 2 left.
   integer(c_int)        :: status      !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_frame_options

   function fig_set_icon_rgba(rgba, width, height) result(status) bind(C, name='fig_set_icon_rgba')
   !< The window's icon from RGBA pixels, rows from the top (window mode).
   import :: c_int, c_ptr
   implicit none
   type(c_ptr),    value :: rgba   !< Pixels, 4 bytes each.
   integer(c_int), value :: width  !< Width [pixels].
   integer(c_int), value :: height !< Height [pixels].
   integer(c_int)        :: status !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_set_icon_rgba

   function fig_set_icon_glyph(icon, icon_len) result(status) bind(C, name='fig_set_icon_glyph')
   !< The window's icon from one ICON_* glyph (window mode).
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: icon(*)  !< UTF-8 glyph (not NUL-terminated).
   integer(c_int), value              :: icon_len !< Its length [bytes].
   integer(c_int)                     :: status   !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_set_icon_glyph

   function fig_process_start(id, args, arg_lens, nargs, cwd, cwd_len, env, env_lens, nenv, merge_stderr, detached, &
                              log, log_len) result(status) bind(C, name='fig_process_start')
   !< Start a process: captured (output piped, a reader thread drains it) or detached (output to `log`).
   import :: c_char, c_int
   implicit none
   integer(c_int),         intent(out) :: id           !< Its handle.
   character(kind=c_char), intent(in)  :: args(*)      !< The arguments, packed (program first).
   integer(c_int),         intent(in)  :: arg_lens(*)  !< Length of each argument [bytes].
   integer(c_int),         value       :: nargs        !< Arguments.
   character(kind=c_char), intent(in)  :: cwd(*)       !< Working directory (empty: the program's).
   integer(c_int),         value       :: cwd_len      !< Its length [bytes].
   character(kind=c_char), intent(in)  :: env(*)       !< NAME=value entries, packed.
   integer(c_int),         intent(in)  :: env_lens(*)  !< Length of each entry [bytes].
   integer(c_int),         value       :: nenv         !< Entries.
   integer(c_int),         value       :: merge_stderr !< 1: standard error into standard output.
   integer(c_int),         value       :: detached     !< 1: detached, output to `log`.
   character(kind=c_char), intent(in)  :: log(*)       !< Log file (detached).
   integer(c_int),         value       :: log_len      !< Its length [bytes].
   integer(c_int)                      :: status       !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_process_start

   function fig_process_pending(id, length, running) result(status) bind(C, name='fig_process_pending')
   !< Bytes ready to take (complete lines; all of them once it ended) and whether it runs.
   import :: c_int, c_long_long
   implicit none
   integer(c_int),       value       :: id      !< Handle.
   integer(c_long_long), intent(out) :: length  !< Bytes ready [bytes].
   integer(c_int),       intent(out) :: running !< 1 while running.
   integer(c_int)                    :: status  !< Status: FIG_OK or FIG_ERR_STATE.
   endfunction fig_process_pending

   function fig_process_take(id, buf, length, got) result(status) bind(C, name='fig_process_take')
   !< Copy out up to `length` bytes of output (as given by fig_process_pending).
   import :: c_char, c_int, c_long_long
   implicit none
   integer(c_int),         value       :: id     !< Handle.
   character(kind=c_char), intent(out) :: buf(*) !< Buffer.
   integer(c_long_long),   value       :: length !< Its size [bytes].
   integer(c_long_long),   intent(out) :: got    !< Bytes copied [bytes].
   integer(c_int)                      :: status !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_process_take

   function fig_process_info(id, running, exited, code, killed, pid, detached) result(status) &
            bind(C, name='fig_process_info')
   !< The state of a process.
   import :: c_int, c_long_long
   implicit none
   integer(c_int),       value       :: id       !< Handle.
   integer(c_int),       intent(out) :: running  !< 1 while running (captured: until its output is all read).
   integer(c_int),       intent(out) :: exited   !< 1 once it ended.
   integer(c_int),       intent(out) :: code     !< Exit code (captured).
   integer(c_int),       intent(out) :: killed   !< 1 when it ended after a kill.
   integer(c_long_long), intent(out) :: pid      !< Process id.
   integer(c_int),       intent(out) :: detached !< 1 if detached.
   integer(c_int)                    :: status   !< Status: FIG_OK or FIG_ERR_STATE.
   endfunction fig_process_info

   function fig_process_kill(id, force) result(status) bind(C, name='fig_process_kill')
   !< Ask a process to end (force: at once).
   import :: c_int
   implicit none
   integer(c_int), value :: id     !< Handle.
   integer(c_int), value :: force  !< 1: SIGKILL / TerminateProcess.
   integer(c_int)        :: status !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_process_kill

   subroutine fig_process_release(id) bind(C, name='fig_process_release')
   !< Forget a process: a captured one still running is killed, a detached one goes on.
   import :: c_int
   implicit none
   integer(c_int), value :: id !< Handle.
   endsubroutine fig_process_release

   function fig_notify(text, text_len, kind, icon, icon_len, seconds) result(status) bind(C, name='fig_notify')
   !< Queue a notification.
   import :: c_char, c_double, c_int
   implicit none
   character(kind=c_char), intent(in) :: text(*)  !< Text (UTF-8).
   integer(c_int),         value      :: text_len !< Its length [bytes].
   integer(c_int),         value      :: kind     !< 0 info, 1 success, 2 warning, 3 error.
   character(kind=c_char), intent(in) :: icon(*)  !< Icon glyph (UTF-8).
   integer(c_int),         value      :: icon_len !< Its length [bytes].
   real(c_double),         value      :: seconds  !< Time shown [s] (<= 0: until clicked).
   integer(c_int)                     :: status   !< Status.
   endfunction fig_notify

   function fig_notification_count(count) result(status) bind(C, name='fig_notification_count')
   !< Notifications kept.
   import :: c_int
   implicit none
   integer(c_int), intent(out) :: count  !< Kept (at most 100).
   integer(c_int)              :: status !< Status.
   endfunction fig_notification_count

   function fig_notification_get(idx, buf, buf_len, length, kind, shown) result(status) &
            bind(C, name='fig_notification_get')
   !< A kept notification, 1 the oldest.
   import :: c_char, c_int
   implicit none
   integer(c_int),         value       :: idx     !< Index.
   character(kind=c_char), intent(out) :: buf(*)  !< Text buffer.
   integer(c_int),         value       :: buf_len !< Its size [bytes].
   integer(c_int),         intent(out) :: length  !< Text length [bytes].
   integer(c_int),         intent(out) :: kind    !< 0 info, 1 success, 2 warning, 3 error.
   integer(c_int),         intent(out) :: shown   !< 1 while shown.
   integer(c_int)                      :: status  !< Status.
   endfunction fig_notification_get

   function fig_notification_rect(idx, rect, found) result(status) bind(C, name='fig_notification_rect')
   !< A shown notification's rectangle in the last frame, 1 the newest.
   import :: c_float, c_int
   implicit none
   integer(c_int), value       :: idx     !< Index.
   real(c_float),  intent(out) :: rect(4) !< xmin, ymin, xmax, ymax [pixels].
   integer(c_int), intent(out) :: found   !< 1 if shown.
   integer(c_int)              :: status  !< Status.
   endfunction fig_notification_rect

   function fig_notification_alpha(idx, alpha) result(status) bind(C, name='fig_notification_alpha')
   !< A shown notification's largest vertex alpha in the last frame, 1 the newest (0 past the last).
   import :: c_float, c_int
   implicit none
   integer(c_int), value       :: idx     !< Index.
   real(c_float),  intent(out) :: alpha   !< Alpha, in [0, 1].
   integer(c_int)              :: status  !< Status.
   endfunction fig_notification_alpha

   function fig_drawn_extent(color, color_len, rect, found) result(status) bind(C, name='fig_drawn_extent')
   !< The extent drawn in the current window in a style colour.
   import :: c_char, c_float, c_int
   implicit none
   character(kind=c_char), intent(in)  :: color(*)  !< Dear ImGui's colour name.
   integer(c_int),         value       :: color_len !< Its length [bytes].
   real(c_float),          intent(out) :: rect(4)   !< xmin, ymin, xmax, ymax [pixels].
   integer(c_int),         intent(out) :: found     !< 1 if anything.
   integer(c_int)                      :: status    !< Status.
   endfunction fig_drawn_extent

   function fig_drawn_extent_rgba(rgba, rect, found) result(status) bind(C, name='fig_drawn_extent_rgba')
   !< The extent of the vertices drawn so far in the current window in an RGBA colour.
   import :: c_float, c_int
   implicit none
   real(c_float),  intent(in)  :: rgba(4) !< Colour, RGBA in [0, 1].
   real(c_float),  intent(out) :: rect(4) !< xmin, ymin, xmax, ymax [pixels].
   integer(c_int), intent(out) :: found   !< 1: something was drawn in it.
   integer(c_int)              :: status  !< Status.
   endfunction fig_drawn_extent_rgba

   function fig_popup_rect(rect, found) result(status) bind(C, name='fig_popup_rect')
   !< The rectangle of the innermost open popup, as in the last frame.
   import :: c_float, c_int
   implicit none
   real(c_float),  intent(out) :: rect(4) !< xmin, ymin, xmax, ymax [pixels].
   integer(c_int), intent(out) :: found   !< 1: a popup is open.
   integer(c_int)              :: status  !< Status.
   endfunction fig_popup_rect

   function fig_task_start(fn, arg, id) result(status) bind(C, name='fig_task_start')
   !< Run fn(arg) on a worker thread.
   import :: c_funptr, c_int, c_ptr
   implicit none
   type(c_funptr), value       :: fn     !< The bind(C) trampoline.
   type(c_ptr),    value       :: arg    !< Its argument.
   integer(c_int), intent(out) :: id     !< Handle.
   integer(c_int)              :: status !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_task_start

   function fig_task_state(id, done, fraction, msg, msg_len, length, task_status) result(status) &
            bind(C, name='fig_task_state')
   !< A task's end, last progress and message, and its failure's status.
   import :: c_char, c_double, c_int
   implicit none
   integer(c_int),         value       :: id          !< Handle.
   integer(c_int),         intent(out) :: done        !< 1 once ended.
   real(c_double),         intent(out) :: fraction    !< Last progress (negative: none yet).
   character(kind=c_char), intent(out) :: msg(*)      !< Its message (up to msg_len bytes).
   integer(c_int),         value       :: msg_len     !< Buffer size [bytes].
   integer(c_int),         intent(out) :: length      !< Message length [bytes].
   integer(c_int),         intent(out) :: task_status !< FIG_OK or the failure's status.
   integer(c_int)                      :: status      !< Status: FIG_OK or FIG_ERR_STATE.
   endfunction fig_task_state

   function fig_task_report(id, fraction, msg, msg_len, keep_message) result(status) bind(C, name='fig_task_report')
   !< Progress from the task.
   import :: c_char, c_double, c_int
   implicit none
   integer(c_int),         value      :: id           !< Handle.
   real(c_double),         value      :: fraction     !< Done [0, 1].
   character(kind=c_char), intent(in) :: msg(*)       !< Message.
   integer(c_int),         value      :: msg_len      !< Its length [bytes].
   integer(c_int),         value      :: keep_message !< 1: keep the previous message.
   integer(c_int)                     :: status       !< Status.
   endfunction fig_task_report

   function fig_task_fail(id, msg, msg_len) result(status) bind(C, name='fig_task_fail')
   !< A failure reported by the task.
   import :: c_char, c_int
   implicit none
   integer(c_int),         value      :: id      !< Handle.
   character(kind=c_char), intent(in) :: msg(*)  !< Message.
   integer(c_int),         value      :: msg_len !< Its length [bytes].
   integer(c_int)                     :: status  !< Status.
   endfunction fig_task_fail

   function fig_task_cancel(id) result(status) bind(C, name='fig_task_cancel')
   !< Ask a task to stop.
   import :: c_int
   implicit none
   integer(c_int), value :: id     !< Handle.
   integer(c_int)        :: status !< Status.
   endfunction fig_task_cancel

   function fig_task_cancelled(id) result(cancelled) bind(C, name='fig_task_cancelled')
   !< 1 once the task was asked to stop.
   import :: c_int
   implicit none
   integer(c_int), value :: id        !< Handle.
   integer(c_int)        :: cancelled !< 1: asked to stop.
   endfunction fig_task_cancelled

   function fig_task_finish(id) result(status) bind(C, name='fig_task_finish')
   !< Wait for an ended task's thread; its failure's status (message in fig_last_error).
   import :: c_int
   implicit none
   integer(c_int), value :: id     !< Handle.
   integer(c_int)        :: status !< Status.
   endfunction fig_task_finish

   subroutine fig_task_release(id) bind(C, name='fig_task_release')
   !< Forget a task (a running one is asked to stop and waited for).
   import :: c_int
   implicit none
   integer(c_int), value :: id !< Handle.
   endsubroutine fig_task_release

   function fig_task_on_worker() result(on) bind(C, name='fig_task_on_worker')
   !< 1 on a task's thread.
   import :: c_int
   implicit none
   integer(c_int) :: on !< 1 on a worker.
   endfunction fig_task_on_worker

   function fig_task_refuse(name, name_len) result(refused) bind(C, name='fig_task_refuse')
   !< At a drawing entry point: 1 on a worker (the refusal recorded in its task), 0 on the main thread.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: name(*)  !< The entry point.
   integer(c_int),         value      :: name_len !< Its length [bytes].
   integer(c_int)                     :: refused  !< 1: refused.
   endfunction fig_task_refuse

   function fig_set_checks(mode) result(status) bind(C, name='fig_set_checks')
   !< The usage checks: 0 abort, 1 report (the default), 2 recover; `FIG_ERR_ARGUMENT` for another value.
   import :: c_int
   implicit none
   integer(c_int), value :: mode   !< Mode.
   integer(c_int)        :: status !< Status.
   endfunction fig_set_checks

   function fig_checks() result(mode) bind(C, name='fig_checks')
   !< The usage checks in effect: 0 abort, 1 report, 2 recover.
   import :: c_int
   implicit none
   integer(c_int) :: mode !< Mode.
   endfunction fig_checks

   function fig_draw_refuse(who, who_len, has_stat) result(action) bind(C, name='fig_draw_refuse')
   !< At a drawing entry point: 0 go on; 1 refused (from a task, or no frame open); 2 refused, stop ('abort').
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: who(*)   !< The entry point.
   integer(c_int),         value      :: who_len  !< Its length [bytes].
   integer(c_int),         value      :: has_stat !< 1: the caller has a stat (the error is returned there).
   integer(c_int)                     :: action   !< 0, 1 or 2.
   endfunction fig_draw_refuse

   function fig_usage_error(msg, msg_len, has_stat) result(action) bind(C, name='fig_usage_error')
   !< A usage error found by a wrapper: kept and answered as the others; 1 refused, 2 refused, stop ('abort').
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: msg(*)   !< The message.
   integer(c_int),         value      :: msg_len  !< Its length [bytes].
   integer(c_int),         value      :: has_stat !< 1: the caller has a stat (the error is returned there).
   integer(c_int)                     :: action   !< 1 or 2.
   endfunction fig_usage_error

   function fig_add_fallback_font(path, path_len) result(status) bind(C, name='fig_add_fallback_font')
   !< A program's own fallback font (TTF or OTF file), merged into every text font after the bundled ones.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: path(*)  !< File (not NUL-terminated).
   integer(c_int),         value      :: path_len !< Its length [bytes].
   integer(c_int)                     :: status   !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_add_fallback_font

   function fig_test_glyph(text, text_len, font, font_len, source, source_cap, source_len, pixels, width, height, &
                           checksum) result(status) bind(C, name='fig_test_glyph')
   !< One glyph of a font: the source that has it, its bitmap's pixels that are not empty, advance, height, checksum.
   import :: c_char, c_double, c_int, c_long_long
   implicit none
   character(kind=c_char), intent(in)  :: text(*)    !< One UTF-8 character (not NUL-terminated).
   integer(c_int),         value       :: text_len   !< Its length [bytes].
   character(kind=c_char), intent(in)  :: font(*)    !< Font name or file (not NUL-terminated).
   integer(c_int),         value       :: font_len   !< Its length [bytes].
   character(kind=c_char), intent(out) :: source(*)  !< Name of the source font (not NUL-terminated).
   integer(c_int),         value       :: source_cap !< Capacity of `source` [bytes].
   integer(c_int),         intent(out) :: source_len !< Length written [bytes]; 0: no source has the glyph.
   integer(c_long_long),   intent(out) :: pixels     !< Pixels of the bitmap that are not empty.
   real(c_double),         intent(out) :: width      !< Advance [pixels].
   real(c_double),         intent(out) :: height     !< Height of the bitmap [pixels].
   integer(c_long_long),   intent(out) :: checksum   !< FNV-1a of the bitmap's coverage values.
   integer(c_int)                      :: status     !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_test_glyph

   function fig_time() result(seconds) bind(C, name='fig_time')
   !< Seconds since the first call, on the system's monotonic clock; any thread, any time.
   import :: c_double
   implicit none
   real(c_double) :: seconds !< Seconds since the first call [s].
   endfunction fig_time

   subroutine fig_scope_open(kind, who, who_len, label, label_len, returned, aux) bind(C, name='fig_scope_open')
   !< A begin or a push, after it: its scope in the record of the frame.
   import :: c_char, c_int
   implicit none
   integer(c_int),         value      :: kind      !< SCOPE_* of figure_base.
   character(kind=c_char), intent(in) :: who(*)    !< The procedure.
   integer(c_int),         value      :: who_len   !< Its length [bytes].
   character(kind=c_char), intent(in) :: label(*)  !< The label (or id) of the scope.
   integer(c_int),         value      :: label_len !< Its length [bytes].
   integer(c_int),         value      :: returned  !< 1: the begin returned true.
   integer(c_int),         value      :: aux       !< The dock id of a dock layout (else 0).
   endsubroutine fig_scope_open

   function fig_scope_close(kind, who, who_len, n, has_stat) result(action) bind(C, name='fig_scope_close')
   !< An end or a pop, before it: checked against the record; 0 go on, 1 refused, 2 refused, stop ('abort').
   import :: c_char, c_int
   implicit none
   integer(c_int),         value      :: kind     !< SCOPE_* of figure_base.
   character(kind=c_char), intent(in) :: who(*)   !< The procedure.
   integer(c_int),         value      :: who_len  !< Its length [bytes].
   integer(c_int),         value      :: n        !< Pops (style changes; 1 otherwise).
   integer(c_int),         value      :: has_stat !< 1: the caller has a stat (the error is returned there).
   integer(c_int)                     :: action   !< 0, 1 or 2.
   endfunction fig_scope_close

   function fig_scope_report(notify) result(status) bind(C, name='fig_scope_report')
   !< The usage errors of the last frame (and between frames): `FIG_ERR_STATE` with every message in the last error,
   !< or, in mode recover, `FIG_OK` and `notify` 1 when they are new.
   import :: c_int
   implicit none
   integer(c_int), intent(out) :: notify !< 1: show them in a notification.
   integer(c_int)              :: status !< Status.
   endfunction fig_scope_report

   function fig_frame_hit(x, y, hit) result(status) bind(C, name='fig_frame_hit')
   !< The frame's hit-test class at (x, y), from the last frame.
   import :: c_float, c_int
   implicit none
   real(c_float),  value       :: x      !< Abscissa [pixels].
   real(c_float),  value       :: y      !< Ordinate [pixels].
   integer(c_int), intent(out) :: hit    !< 0 client, 1 drag, 2..9 resize (SDL_HitTestResult).
   integer(c_int)              :: status !< Status: FIG_OK.
   endfunction fig_frame_hit

   function fig_frame_rect(part, rect, found) result(status) bind(C, name='fig_frame_rect')
   !< A part of the frame's title bar in the last frame.
   import :: c_float, c_int
   implicit none
   integer(c_int), value       :: part    !< 0 bar, 1 icon, 2 menus, 3 title, 4 minimize, 5 maximize, 6 close.
   real(c_float),  intent(out) :: rect(4) !< x0, y0, x1, y1 [pixels].
   integer(c_int), intent(out) :: found   !< 1 if drawn.
   integer(c_int)              :: status  !< Status: FIG_OK or FIG_ERR_ARGUMENT.
   endfunction fig_frame_rect

   function fig_frame_state(minimized, maximized) result(status) bind(C, name='fig_frame_state')
   !< The window minimized, maximized (headless: as the frame's buttons recorded it).
   import :: c_int
   implicit none
   integer(c_int), intent(out) :: minimized !< 1 if minimized.
   integer(c_int), intent(out) :: maximized !< 1 if maximized.
   integer(c_int)              :: status    !< Status: FIG_OK or FIG_ERR_STATE.
   endfunction fig_frame_state

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

   subroutine fig_set_remote_lossy(on) bind(C, name='fig_set_remote_lossy')
   !< Remote mode: a user texture updated in consecutive frames goes as JPEG, then exact when it stops (1); 0: exact.
   import :: c_int
   implicit none
   integer(c_int), value :: on !< JPEG while changing (1) or not (0).
   endsubroutine fig_set_remote_lossy

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

   function fig_file_browser(kind, id, id_len, filters, filters_len, path, path_len) result(status) &
      bind(C, name='fig_file_browser')
   !< Open FIGURE's file browser (every mode): kind 0 open a file, 1 save a file, 2 choose a folder.
   import :: c_char, c_int
   implicit none
   integer(c_int), value              :: kind        !< 0 open, 1 save, 2 folder.
   character(kind=c_char), intent(in) :: id(*)       !< Dialog id (not NUL-terminated).
   integer(c_int), value              :: id_len      !< Its length.
   character(kind=c_char), intent(in) :: filters(*)  !< "name|pattern" entries separated by newlines.
   integer(c_int), value              :: filters_len !< Their length.
   character(kind=c_char), intent(in) :: path(*)     !< Where to start.
   integer(c_int), value              :: path_len    !< Its length (0: the working directory).
   integer(c_int)                     :: status      !< Status.
   endfunction fig_file_browser

   function fig_file_browser_settings(path, path_len) result(status) bind(C, name='fig_file_browser_settings')
   !< The settings file keeping the recent folders, until the program ends ('': none, memory only).
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: path(*)  !< File.
   integer(c_int), value              :: path_len !< Its length.
   integer(c_int)                     :: status   !< Status.
   endfunction fig_file_browser_settings

   function fig_file_browser_get(what, idx, buf, buf_len, length, count) result(status) &
      bind(C, name='fig_file_browser_get')
   !< A text of the browser in front: 0 folder, 1 entry, 2 error, 3 asking, 4 path field, 5 recent folder, 6 name field.
   import :: c_char, c_int
   implicit none
   integer(c_int), value                :: what    !< Query.
   integer(c_int), value                :: idx     !< Index in a list, from 1.
   character(kind=c_char), intent(out)  :: buf(*)  !< Text.
   integer(c_int), value                :: buf_len !< Buffer length.
   integer(c_int), intent(out)          :: length  !< Full length of the text.
   integer(c_int), intent(out)          :: count   !< Length of the list (1 for a text, 0 without a browser).
   integer(c_int)                       :: status  !< Status.
   endfunction fig_file_browser_get

   function fig_file_browser_rect(part, part_len, rect, found) result(status) bind(C, name='fig_file_browser_rect')
   !< A part of the browser in front, as drawn in the last frame.
   import :: c_char, c_float, c_int
   implicit none
   character(kind=c_char), intent(in) :: part(*)  !< Part name.
   integer(c_int), value              :: part_len !< Its length.
   real(c_float), intent(out)         :: rect(4)  !< xmin, ymin, xmax, ymax [pixels].
   integer(c_int), intent(out)        :: found    !< 1 if drawn.
   integer(c_int)                     :: status   !< Status.
   endfunction fig_file_browser_rect

   function fig_save_image(path, path_len, x0, y0, x1, y1) result(status) bind(C, name='fig_save_image')
   !< Ask for the rectangle (x0, y0)-(x1, y1) [logical pixels] of the window as a PNG file, written when this frame is
   !< rendered (a window's from the GPU, headless and remote modes' from the CPU renderer).
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

   function fig_test_capture(path, path_len) result(status) bind(C, name='fig_test_capture')
   !< Ask for the whole frame as a PNG file, written when this frame is rendered (an earlier file of that name removed).
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: path(*)  !< File.
   integer(c_int), value              :: path_len !< Its length.
   integer(c_int)                     :: status   !< Status.
   endfunction fig_test_capture

   function fig_render_threads(threads) result(status) bind(C, name='fig_render_threads')
   !< The CPU renderer's threads (0: the default; tests compare pictures rendered with different counts).
   import :: c_int
   implicit none
   integer(c_int), value :: threads !< Threads, 0-64.
   integer(c_int)        :: status  !< Status.
   endfunction fig_render_threads

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

   function fig_tool_button(label, label_len, icon, icon_len, width, height, selected, accent) result(clicked) &
      bind(C, name='fig_tool_button')
   !< A workspace button, an icon above its label: 1 on the frame it is clicked.
   import :: c_char, c_double, c_int
   implicit none
   character(kind=c_char), intent(in) :: label(*)   !< Label (text before '##' shown; all of it the id).
   integer(c_int), value              :: label_len  !< Its length.
   character(kind=c_char), intent(in) :: icon(*)    !< Icon (UTF-8).
   integer(c_int), value              :: icon_len   !< Its length.
   real(c_double), value              :: width      !< Width [pixels] (<= 0: default).
   real(c_double), value              :: height     !< Height [pixels] (<= 0: default).
   integer(c_int), value              :: selected   !< 1: framed and tinted in the accent.
   real(c_double), intent(in)         :: accent(4)  !< Accent [r, g, b, _] (accent(4) < 0: the style's).
   integer(c_int)                     :: clicked    !< 1: clicked.
   endfunction fig_tool_button

   function fig_clipper_new() result(clipper) bind(C, name='fig_clipper_new')
   !< A list clipper.
   import :: c_ptr
   implicit none
   type(c_ptr) :: clipper !< Clipper.
   endfunction fig_clipper_new

   subroutine fig_clipper_begin(clipper, count, item_height) bind(C, name='fig_clipper_begin')
   !< Start clipping `count` rows (item_height <= 0: measured on the first row).
   import :: c_double, c_int, c_ptr
   implicit none
   type(c_ptr),    value :: clipper     !< Clipper.
   integer(c_int), value :: count       !< Rows.
   real(c_double), value :: item_height !< Row height [pixels].
   endsubroutine fig_clipper_begin

   function fig_clipper_step(clipper, first, last, item_height) result(more) bind(C, name='fig_clipper_step')
   !< The next range of rows to draw (1-based): 1 while there is one; the row height once known (0 before).
   import :: c_double, c_int, c_ptr
   implicit none
   type(c_ptr),    value       :: clipper     !< Clipper.
   integer(c_int), intent(out) :: first       !< First row.
   integer(c_int), intent(out) :: last        !< Last row.
   real(c_double), intent(out) :: item_height !< Height of a row with its spacing [pixels] (0: not known yet).
   integer(c_int)              :: more        !< 1: draw first..last.
   endfunction fig_clipper_step

   subroutine fig_clipper_delete(clipper) bind(C, name='fig_clipper_delete')
   !< Free a clipper (ended first when left before its end).
   import :: c_ptr
   implicit none
   type(c_ptr), value :: clipper !< Clipper.
   endsubroutine fig_clipper_delete

   function fig_table_sort(column, descending, changed) result(code) bind(C, name='fig_table_sort')
   !< The order asked of the current table: its primary key, and whether it is new on this frame (cleared then).
   import :: c_int
   implicit none
   integer(c_int), intent(out) :: column     !< Column, 1-based (0: no order).
   integer(c_int), intent(out) :: descending !< 1: descending.
   integer(c_int), intent(out) :: changed    !< 1: a new order on this frame.
   integer(c_int)              :: code       !< 0 done, 1 no table, 2 not sortable, 5 columns not all declared.
   endfunction fig_table_sort

   function fig_table_row_color(rgba, column) result(code) bind(C, name='fig_table_row_color')
   !< A colour behind the current row (`column` 0) or one of its cells.
   import :: c_double, c_int
   implicit none
   real(c_double), intent(in) :: rgba(4) !< Colour, RGBA in [0, 1].
   integer(c_int), value      :: column  !< 0 the row, else the cell's column (1-based).
   integer(c_int)             :: code    !< 0 done, 1 no table, 3 column out of range, 4 no row begun.
   endfunction fig_table_row_color

   function fig_table_column_enabled(column, enabled) result(code) bind(C, name='fig_table_column_enabled')
   !< Show or hide a column of the current table from the next frame.
   import :: c_int
   implicit none
   integer(c_int), value :: column  !< Column, 1-based.
   integer(c_int), value :: enabled !< 1 shown, 0 hidden.
   integer(c_int)        :: code    !< 0 done, 1 no table, 2 not hideable, 3 column out of range.
   endfunction fig_table_column_enabled

   function fig_table_hovered_column(column) result(code) bind(C, name='fig_table_hovered_column')
   !< The column of the current table under the pointer.
   import :: c_int
   implicit none
   integer(c_int), intent(out) :: column !< Column, 1-based (0: none).
   integer(c_int)              :: code   !< 0 done, 1 no table.
   endfunction fig_table_hovered_column

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
   !< End the loop at the next begin_frame (from any thread; from another than the loop's, it wakes the loop).
   endsubroutine fig_quit

   subroutine fig_app_wake() bind(C, name='fig_app_wake')
   !< From any thread: the next frame starts without waiting for input or max_wait.
   endsubroutine fig_app_wake

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

   function fig_image_read(path, path_len, rgba, width, height) result(status) bind(C, name='fig_image_read')
   !< Read a PNG or JPEG file into RGBA pixels, rows of `width` pixels from the top row down (any thread).
   import :: c_char, c_int, c_ptr
   implicit none
   character(kind=c_char), intent(in) :: path(*)  !< File name, UTF-8 (`path_len` bytes, no terminator).
   integer(c_int), value              :: path_len !< Length of `path` [bytes].
   type(c_ptr),            intent(out) :: rgba    !< The decoder's pixels, released with `fig_image_free`.
   integer(c_int),         intent(out) :: width   !< Width [pixels].
   integer(c_int),         intent(out) :: height  !< Height [pixels].
   integer(c_int)                      :: status  !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_image_read

   subroutine fig_image_free(rgba) bind(C, name='fig_image_free')
   !< Release the pixels of `fig_image_read`.
   import :: c_ptr
   implicit none
   type(c_ptr), value :: rgba !< The pixels.
   endsubroutine fig_image_free

   function fig_image_write(path, path_len, pixels, channels, width, height, quality) result(status) &
      bind(C, name='fig_image_write')
   !< Write pixels as a PNG (`quality` 0) or a JPEG (`quality` 1-100); rows of `width` pixels from the top (any thread).
   import :: c_char, c_int, c_ptr
   implicit none
   character(kind=c_char), intent(in) :: path(*)  !< File name, UTF-8 (`path_len` bytes, no terminator).
   integer(c_int), value              :: path_len !< Length of `path` [bytes].
   type(c_ptr), value                 :: pixels   !< First byte of the pixels.
   integer(c_int), value              :: channels !< Bytes a pixel: 1 grey, 2 grey + alpha, 3 RGB, 4 RGBA.
   integer(c_int), value              :: width    !< Width [pixels].
   integer(c_int), value              :: height   !< Height [pixels].
   integer(c_int), value              :: quality  !< 0: PNG; 1-100: JPEG of that quality.
   integer(c_int)                     :: status   !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_image_write

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
   integer(c_int), value               :: axis      !< An ImAxis: 0-2 X1-X3, 3-5 Y1-Y3.
   integer(c_int), value               :: index     !< Tick, from 1.
   character(kind=c_char), intent(out) :: buf(*)    !< Label.
   integer(c_int), value               :: buf_len   !< Buffer length.
   integer(c_int), intent(out)         :: count     !< Ticks on the axis.
   integer(c_int), intent(out)         :: label_len !< Length of the label.
   integer(c_int)                      :: status    !< Status.
   endfunction fig_plot_tick_label

   function fig_plot_annotation(x, y, rgba, dx, dy, clamp, text, text_len) result(status) &
      bind(C, name='fig_plot_annotation')
   !< An annotation of the plot being declared (drawn at its end).
   import :: c_char, c_double, c_float, c_int
   implicit none
   real(c_double), value              :: x        !< Abscissa [plot units].
   real(c_double), value              :: y        !< Ordinate [plot units].
   real(c_float),          intent(in) :: rgba(4)  !< Box colour (alpha 0: no box).
   real(c_float), value               :: dx       !< Offset along x [pixels] (0: centred).
   real(c_float), value               :: dy       !< Offset along y [pixels], down (0: centred).
   integer(c_int), value              :: clamp    !< 1: kept inside the plot.
   character(kind=c_char), intent(in) :: text(*)  !< Text (not NUL-terminated).
   integer(c_int), value              :: text_len !< Its length [bytes].
   integer(c_int)                     :: status   !< Status.
   endfunction fig_plot_annotation

   function fig_plot_tag(axis, value, rgba, text, text_len, has_text) result(status) bind(C, name='fig_plot_tag')
   !< A tag of the plot being declared on an axis set up, drawn at its end: a box with a text or the axis's label.
   import :: c_char, c_double, c_float, c_int
   implicit none
   integer(c_int), value              :: axis     !< ImAxis (X1-X3 0-2, Y1-Y3 3-5).
   real(c_double), value              :: value    !< Position [axis units].
   real(c_float),          intent(in) :: rgba(4)  !< Box colour (alpha < 0: the last item's; 0: no box).
   character(kind=c_char), intent(in) :: text(*)  !< Text (not NUL-terminated).
   integer(c_int), value              :: text_len !< Its length [bytes].
   integer(c_int), value              :: has_text !< 1: the text; 0: the axis's label of the value.
   integer(c_int)                     :: status   !< Status: FIG_ERR_STATE outside a plot or for an axis not set up.
   endfunction fig_plot_tag

   function fig_shortcut(keys, keys_len, scope, scope_len, repeat, pressed) result(status) bind(C, name='fig_shortcut')
   !< A routed shortcut ("ctrl+s", scope "focused", "global" or "item"); `pressed` 1 on the frame it fires.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: keys(*)   !< Chord name (not NUL-terminated).
   integer(c_int), value              :: keys_len  !< Name length [bytes].
   character(kind=c_char), intent(in) :: scope(*)  !< Scope (not NUL-terminated).
   integer(c_int), value              :: scope_len !< Scope length [bytes].
   integer(c_int), value              :: repeat    !< 1: fire again while held.
   integer(c_int), intent(out)        :: pressed   !< 1 on the frame it fires.
   integer(c_int)                     :: status    !< Status: FIG_OK or FIG_ERR_ARGUMENT.
   endfunction fig_shortcut

   function fig_set_next_item_shortcut(keys, keys_len, scope, scope_len) result(status) &
      bind(C, name='fig_set_next_item_shortcut')
   !< The next item owns the chord ("ctrl+s", scope "focused" or "global"): the chord presses it.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: keys(*)   !< Chord name (not NUL-terminated).
   integer(c_int), value              :: keys_len  !< Name length [bytes].
   character(kind=c_char), intent(in) :: scope(*)  !< Scope (not NUL-terminated).
   integer(c_int), value              :: scope_len !< Scope length [bytes].
   integer(c_int)                     :: status    !< Status: FIG_OK or FIG_ERR_ARGUMENT.
   endfunction fig_set_next_item_shortcut

   function fig_last_item(s) result(status) bind(C, name='fig_last_item')
   !< The status of the item drawn last, in one call.
   import :: c_int, fig_item_status
   implicit none
   type(fig_item_status), intent(out) :: s      !< Status of the item.
   integer(c_int)                     :: status !< Status: FIG_OK or FIG_ERR_STATE (no context).
   endfunction fig_last_item

   subroutine fig_mark_last_item_edited() bind(C, name='fig_mark_last_item_edited')
   !< The item drawn last changed its value on this frame (Dear ImGui's MarkItemEdited).
   implicit none
   endsubroutine fig_mark_last_item_edited

   function fig_drag_range(label, data_type, lo, hi, speed, vmin, vmax, format, flags) result(changed) &
      bind(C, name='fig_drag_range')
   !< Two drags side by side for the ends of a range, then the label: 1 when either end changed.
   import :: c_char, c_float, c_int, c_ptr
   implicit none
   character(kind=c_char), intent(in) :: label(*)  !< Label (NUL-terminated; also the id).
   integer(c_int), value              :: data_type !< ImGuiDataType of the four values.
   type(c_ptr), value                 :: lo        !< Lower end.
   type(c_ptr), value                 :: hi        !< Upper end.
   real(c_float), value               :: speed     !< Change per pixel dragged.
   type(c_ptr), value                 :: vmin      !< Lower bound of the lower end.
   type(c_ptr), value                 :: vmax      !< Upper bound of the upper end.
   type(c_ptr), value                 :: format    !< printf format (NUL-terminated), or null: Dear ImGui's default.
   integer(c_int), value              :: flags     !< ImGuiSliderFlags.
   integer(c_int)                     :: changed   !< 1: changed this frame.
   endfunction fig_drag_range

   function fig_list_box(label, current, items, item_len, count, height) result(changed) bind(C, name='fig_list_box')
   !< A list box of blank-padded strings: 1 on the frame the user picks an item.
   import :: c_char, c_double, c_int
   implicit none
   character(kind=c_char), intent(in)    :: label(*) !< Label (NUL-terminated; also the id).
   integer(c_int),         intent(inout) :: current  !< 0-based index of the chosen item (any other value: none).
   character(kind=c_char), intent(in)    :: items(*) !< The items, `item_len` bytes each, one after the other.
   integer(c_int), value                 :: item_len !< Length of an item [bytes].
   integer(c_int), value                 :: count    !< Items.
   real(c_double), value                 :: height   !< Height [pixels]; 0 default; < 0 the space left minus it.
   integer(c_int)                        :: changed  !< 1: an item picked this frame.
   endfunction fig_list_box

   subroutine fig_plot_end() bind(C, name='fig_plot_end')
   !< End the current plot (ImPlot's EndPlot) without fitting an axis that has no data (an FPE under traps).
   implicit none
   endsubroutine fig_plot_end

   function fig_plot_state(enabled, scale) result(state) bind(C, name='fig_plot_state')
   !< The plot being declared: 0 none, 1 its setup open, 2 its setup over; its axes set up and their scales.
   import :: c_int
   implicit none
   integer(c_int), intent(out) :: enabled(6) !< 1 for each axis (ImAxis order: X1-X3, Y1-Y3) set up.
   integer(c_int), intent(out) :: scale(6)   !< Each axis's ImPlotScale.
   integer(c_int)              :: state      !< 0 no plot, 1 setup open, 2 setup over.
   endfunction fig_plot_state

   function fig_plot3d_colormap(implot_id, id) result(status) bind(C, name='fig_plot3d_colormap')
   !< The ImPlot3D id of the ImPlot colormap `implot_id`, copied into ImPlot3D's registry (again when edited).
   import :: c_int
   implicit none
   integer(c_int), value       :: implot_id !< ImPlot colormap id (`ip_colormap`).
   integer(c_int), intent(out) :: id        !< ImPlot3D colormap id (-1 on a failure).
   integer(c_int)              :: status    !< FIG_OK or an error code.
   endfunction fig_plot3d_colormap

   subroutine fig_plot3d_end() bind(C, name='fig_plot3d_end')
   !< End the current 3-D plot (ImPlot3D's EndPlot).
   implicit none
   endsubroutine fig_plot3d_end

   function fig_plot3d_state() result(state) bind(C, name='fig_plot3d_state')
   !< The 3-D plot being declared: 0 none, 1 its setup open, 2 its setup over.
   import :: c_int
   implicit none
   integer(c_int) :: state !< 0 no 3-D plot, 1 setup open, 2 setup over.
   endfunction fig_plot3d_state

   subroutine fig_plot_axis_constraints(axis, given, v) bind(C, name='fig_plot_axis_constraints')
   !< Constraints of an axis of the plot being declared: the ends whose bit is set in `given` take `v`.
   import :: c_double, c_int
   implicit none
   integer(c_int), value      :: axis  !< An ImAxis.
   integer(c_int), value      :: given !< Bits: 1 range min, 2 range max, 4 zoom min, 8 zoom max.
   real(c_double), intent(in) :: v(4)  !< Range min, range max [axis units], zoom min, zoom max [axis units].
   endsubroutine fig_plot_axis_constraints

   function fig_align_begin(id, id_len, where) result(status) bind(C, name='fig_align_begin')
   !< Begin an aligned group: moved by the space left on the line (`where` 1 centre, 2 right, 0 not moved), its width
   !< remembered from the previous frame under `id`.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: id(*)  !< Id (not NUL-terminated).
   integer(c_int),         value      :: id_len !< Its length [bytes].
   integer(c_int),         value      :: where  !< 1 centre, 2 right, 0 not moved.
   integer(c_int)                     :: status !< FIG_OK or a FIG_ERR_* code.
   endfunction fig_align_begin

   subroutine fig_align_end() bind(C, name='fig_align_end')
   !< End the aligned group begun last; its width kept for the next frame (one more frame asked when it changed).
   implicit none
   endsubroutine fig_align_end

   subroutine fig_align_next(width, where) bind(C, name='fig_align_next')
   !< Move the cursor so that an item `width` pixels wide is centred (`where` 1) or right-aligned (2) on the line.
   import :: c_double, c_int
   implicit none
   real(c_double), value :: width !< The item's width [pixels].
   integer(c_int), value :: where !< 1 centre, 2 right.
   endsubroutine fig_align_next

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

   function fig_text_set(id, text, length) result(status) bind(C, name='fig_text_set')
   !< Set the text of a text buffer, CRLF turned into LF; `id` 0 (or unknown): a new buffer, its handle returned.
   import :: c_char, c_int, c_long_long
   implicit none
   integer(c_int),         intent(inout) :: id      !< Handle (0: new).
   character(kind=c_char), intent(in)    :: text(*) !< Text (not NUL-terminated).
   integer(c_long_long),   value         :: length  !< Its length [bytes].
   integer(c_int)                        :: status  !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_text_set

   function fig_text_get(id, buf, cap) result(length) bind(C, name='fig_text_get')
   !< Copy at most `cap` bytes of a text buffer's text; its whole length (an unknown handle: 0).
   import :: c_char, c_int, c_long_long
   implicit none
   integer(c_int),         value       :: id     !< Handle.
   character(kind=c_char), intent(out) :: buf(*) !< Buffer.
   integer(c_long_long),   value       :: cap    !< Its size [bytes].
   integer(c_long_long)                :: length !< The text's length [bytes].
   endfunction fig_text_get

   function fig_text_length(id) result(length) bind(C, name='fig_text_length')
   !< The length of a text buffer's text (an unknown handle: 0).
   import :: c_int, c_long_long
   implicit none
   integer(c_int), value :: id     !< Handle.
   integer(c_long_long)  :: length !< Length [bytes].
   endfunction fig_text_length

   subroutine fig_text_release(id) bind(C, name='fig_text_release')
   !< Forget a text buffer (an unknown handle: nothing).
   import :: c_int
   implicit none
   integer(c_int), value :: id !< Handle.
   endsubroutine fig_text_release

   function fig_widget_input_text_multiline(id, label, label_len, width, height, flags) result(edited) &
      bind(C, name='fig_widget_input_text_multiline')
   !< A multi-line text field over a text buffer (`id` 0: a new, empty one); 1 when the user edited it this frame.
   import :: c_char, c_double, c_int
   implicit none
   integer(c_int),         intent(inout) :: id        !< Handle (0: new).
   character(kind=c_char), intent(in)    :: label(*)  !< Label (not NUL-terminated).
   integer(c_int),         value         :: label_len !< Label length [bytes].
   real(c_double),         value         :: width     !< Width [pixels] (0: default).
   real(c_double),         value         :: height    !< Height [pixels] (0: default).
   integer(c_int),         value         :: flags     !< ImGuiInputTextFlags.
   integer(c_int)                        :: edited    !< 1: edited this frame.
   endfunction fig_widget_input_text_multiline

   function fig_input_drop(path, path_len, x, y) result(status) bind(C, name='fig_input_drop')
   !< Queue a synthetic drop of one path at (x, y) (tests).
   import :: c_char, c_float, c_int
   implicit none
   character(kind=c_char), intent(in) :: path(*)  !< Path (not NUL-terminated).
   integer(c_int), value              :: path_len !< Its length [bytes].
   real(c_float), value               :: x        !< Abscissa [pixels].
   real(c_float), value               :: y        !< Ordinate [pixels].
   integer(c_int)                     :: status   !< Status: FIG_OK, FIG_ERR_ARGUMENT (empty), FIG_ERR_STATE.
   endfunction fig_input_drop

   function fig_dropped(count, x, y) result(status) bind(C, name='fig_dropped')
   !< The paths dropped for this frame: how many, and where the last one was dropped.
   import :: c_float, c_int
   implicit none
   integer(c_int), intent(out) :: count  !< Paths.
   real(c_float),  intent(out) :: x      !< Abscissa [pixels].
   real(c_float),  intent(out) :: y      !< Ordinate [pixels].
   integer(c_int)              :: status !< Status: FIG_OK or FIG_ERR_STATE before init.
   endfunction fig_dropped

   function fig_dropped_path(index, buf, buf_len) result(length) bind(C, name='fig_dropped_path')
   !< A path dropped for this frame (index from 1): up to `buf_len` bytes copied; its length.
   import :: c_char, c_int
   implicit none
   integer(c_int), value               :: index   !< Index, from 1.
   character(kind=c_char), intent(out) :: buf(*)  !< Buffer.
   integer(c_int), value               :: buf_len !< Its size [bytes].
   integer(c_int)                      :: length  !< The path's length [bytes] (0: no such path).
   endfunction fig_dropped_path

   function fig_set_clipboard(text, text_len) result(status) bind(C, name='fig_set_clipboard')
   !< Put a text on the clipboard.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: text(*)  !< Text (not NUL-terminated).
   integer(c_int), value              :: text_len !< Its length [bytes].
   integer(c_int)                     :: status   !< Status: FIG_OK or FIG_ERR_STATE before init.
   endfunction fig_set_clipboard

   function fig_get_clipboard(buf, cap) result(length) bind(C, name='fig_get_clipboard')
   !< Copy at most `cap` bytes of the clipboard's text; its whole length (0 before init).
   import :: c_char, c_long_long
   implicit none
   character(kind=c_char), intent(out) :: buf(*) !< Buffer.
   integer(c_long_long),   value       :: cap    !< Its size [bytes].
   integer(c_long_long)                :: length !< The text's length [bytes].
   endfunction fig_get_clipboard

   function fig_opened_url(buf, cap) result(length) bind(C, name='fig_opened_url')
   !< Copy at most `cap` bytes of the URL the last click on a link asked to open; its whole length ('' before any).
   import :: c_char, c_long_long
   implicit none
   character(kind=c_char), intent(out) :: buf(*) !< Buffer.
   integer(c_long_long),   value       :: cap    !< Its size [bytes].
   integer(c_long_long)                :: length !< The URL's length [bytes].
   endfunction fig_opened_url

   function fig_items_record(on) result(status) bind(C, name='fig_items_record')
   !< Record the items of each frame (Dear ImGui's test-engine hooks) from the next frame on, or stop.
   import :: c_int
   implicit none
   integer(c_int), value :: on     !< 1: record, 0: stop.
   integer(c_int)        :: status !< Status.
   endfunction fig_items_record

   function fig_item_find(path, path_len, must, found, rect, state, label, label_cap, label_len) result(status) &
      bind(C, name='fig_item_find')
   !< The item a path names in the last frame: its rectangle, the point to click, its state and its full path.
   import :: c_char, c_float, c_int
   implicit none
   character(kind=c_char), intent(in)  :: path(*)   !< Path (not NUL-terminated).
   integer(c_int), value               :: path_len  !< Its length [bytes].
   integer(c_int), value               :: must      !< 1: no item is a failure; 0: found 0.
   integer(c_int), intent(out)         :: found     !< 1: found.
   real(c_float), intent(out)          :: rect(6)   !< xmin, ymin, xmax, ymax, the point to click [pixels].
   integer(c_int), intent(out)         :: state     !< State bits, the role from bit 16.
   character(kind=c_char), intent(out) :: label(*)  !< Its full path.
   integer(c_int), value               :: label_cap !< Buffer size [bytes].
   integer(c_int), intent(out)         :: label_len !< Its length [bytes].
   integer(c_int)                      :: status    !< Status.
   endfunction fig_item_find

   function fig_item_value(path, path_len, text, text_len, equal, buf, cap, n) result(status) &
      bind(C, name='fig_item_value')
   !< The text the item a path names shows in the last frame, its label taken out; equal 1 when it is `text`.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in)  :: path(*)  !< Path (not NUL-terminated).
   integer(c_int), value               :: path_len !< Its length [bytes].
   character(kind=c_char), intent(in)  :: text(*)  !< Expected text.
   integer(c_int), value               :: text_len !< Its length [bytes].
   integer(c_int), intent(out)         :: equal    !< 1: shown.
   character(kind=c_char), intent(out) :: buf(*)   !< The text shown.
   integer(c_int), value               :: cap      !< Buffer size [bytes].
   integer(c_int), intent(out)         :: n        !< Its length [bytes].
   integer(c_int)                      :: status   !< Status.
   endfunction fig_item_value

   function fig_items_list(what, index, buf, cap, n, count) result(status) bind(C, name='fig_items_list')
   !< The id conflicts (what 1) or the unnamed items (2) of the last frame: index 0 lists, from 1 reads.
   import :: c_char, c_int
   implicit none
   integer(c_int), value               :: what   !< 1 conflicts, 2 unnamed.
   integer(c_int), value               :: index  !< 0: list them; from 1: one of them.
   character(kind=c_char), intent(out) :: buf(*) !< Its path.
   integer(c_int), value               :: cap    !< Buffer size [bytes].
   integer(c_int), intent(out)         :: n      !< Its length [bytes].
   integer(c_int), intent(out)         :: count  !< How many.
   integer(c_int)                      :: status !< Status.
   endfunction fig_items_list

   subroutine fig_items_name(name, name_len) bind(C, name='fig_items_name')
   !< The accessible name of the last item (a widget that draws its label itself).
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: name(*)  !< Name.
   integer(c_int), value              :: name_len !< Its length [bytes].
   endsubroutine fig_items_name

   subroutine fig_items_tooltip() bind(C, name='fig_items_tooltip')
   !< The last item has a tooltip.
   implicit none
   endsubroutine fig_items_tooltip

   function fig_item_click(path, path_len, button) result(status) bind(C, name='fig_item_click')
   !< Queue a click on the item a path names.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: path(*)  !< Path (not NUL-terminated).
   integer(c_int), value              :: path_len !< Its length [bytes].
   integer(c_int), value              :: button   !< 0 left, 1 right, 2 middle.
   integer(c_int)                     :: status   !< Status.
   endfunction fig_item_click

   function fig_item_type(path, path_len, text, text_len) result(status) bind(C, name='fig_item_type')
   !< Queue typed text into the field a path names (click, select all, the text, Enter).
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: path(*)  !< Path (not NUL-terminated).
   integer(c_int), value              :: path_len !< Its length [bytes].
   character(kind=c_char), intent(in) :: text(*)  !< Text (UTF-8).
   integer(c_int), value              :: text_len !< Its length [bytes].
   integer(c_int)                     :: status   !< Status.
   endfunction fig_item_type

   function fig_menu_click(path, path_len) result(status) bind(C, name='fig_menu_click')
   !< Queue a menu path: each level clicked once it appears.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: path(*)  !< Path (not NUL-terminated).
   integer(c_int), value              :: path_len !< Its length [bytes].
   integer(c_int)                     :: status   !< Status.
   endfunction fig_menu_click

   function fig_test_run(max_frames, more) result(status) bind(C, name='fig_test_run')
   !< The frame driver of a test: more 1 while the interface is not idle.
   import :: c_int
   implicit none
   integer(c_int), value       :: max_frames !< Frames allowed.
   integer(c_int), intent(out) :: more       !< 1: draw one more frame.
   integer(c_int)              :: status     !< Status.
   endfunction fig_test_run

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

   function fig_colormap(name, name_len, levels, id) result(status) bind(C, name='fig_colormap')
   !< The ImPlot id of a colormap by name (`<name>_r` reversed, levels > 0 discrete), registered at its first use.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in)  :: name(*)  !< Name (not NUL-terminated).
   integer(c_int), value               :: name_len !< Its length [bytes].
   integer(c_int), value               :: levels   !< Discrete bands, in [2, 256]; 0: continuous.
   integer(c_int),         intent(out) :: id       !< ImPlot colormap id (-1 on a failure).
   integer(c_int)                      :: status   !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_colormap

   function fig_colormap_legend(id, id_len, cmap, vmin, vmax, levels, horizontal, width, height, fmt, fmt_len, scale, &
                                interactive, range, changed) result(status) bind(C, name='fig_colormap_legend')
   !< A colour-scale legend of a colormap, as an item of the current window.
   import :: c_char, c_double, c_float, c_int
   implicit none
   character(kind=c_char), intent(in) :: id(*)      !< Widget id (not NUL-terminated).
   integer(c_int), value              :: id_len     !< Its length [bytes].
   integer(c_int), value              :: cmap       !< ImPlot colormap id.
   real(c_double), value              :: vmin       !< Value at the bottom (left).
   real(c_double), value              :: vmax       !< Value at the top (right).
   integer(c_int), value              :: levels     !< Bands (0: continuous).
   integer(c_int), value              :: horizontal !< 1: horizontal.
   real(c_float), value               :: width      !< Width [pixels] (0: default, < 0: the space left).
   real(c_float), value               :: height     !< Height [pixels] (0: default, < 0: the space left).
   character(kind=c_char), intent(in) :: fmt(*)     !< printf format of the values (not NUL-terminated; empty: %g).
   integer(c_int), value              :: fmt_len    !< Its length [bytes].
   integer(c_int), value              :: scale      !< 0 linear, 1 log, 2 symlog.
   integer(c_int), value              :: interactive !< 1: dragged and scrolled by the user.
   real(c_double),         intent(out) :: range(2)  !< The range after this frame's input.
   integer(c_int),         intent(out) :: changed   !< 1 when the user changed it.
   integer(c_int)                     :: status     !< Status.
   endfunction fig_colormap_legend

   function fig_field_image(label, label_len, data, kind, nx, ny, x0, x1, y0, y1, cmap, has_vmin, vmin, has_vmax, &
                            vmax, scale, nan_rgba, changed, range) result(status) bind(C, name='fig_field_image')
   !< A field through a colormap, as a texture cached by its label's id, drawn in the current plot.
   import :: c_char, c_double, c_float, c_int, c_ptr
   implicit none
   character(kind=c_char), intent(in)  :: label(*)    !< Label (not NUL-terminated).
   integer(c_int), value               :: label_len   !< Its length [bytes].
   type(c_ptr), value                  :: data        !< The values, column-major.
   integer(c_int), value               :: kind        !< 4 float, 8 double.
   integer(c_int), value               :: nx          !< Values along x.
   integer(c_int), value               :: ny          !< Values along y.
   real(c_double), value               :: x0          !< Left edge.
   real(c_double), value               :: x1          !< Right edge.
   real(c_double), value               :: y0          !< Bottom edge.
   real(c_double), value               :: y1          !< Top edge.
   integer(c_int), value               :: cmap        !< ImPlot colormap id.
   integer(c_int), value               :: has_vmin    !< 1: vmin given.
   real(c_double), value               :: vmin        !< Value at the colormap's bottom.
   integer(c_int), value               :: has_vmax    !< 1: vmax given.
   real(c_double), value               :: vmax        !< Value at its top.
   integer(c_int), value               :: scale       !< 0 linear, 1 log, 2 symlog.
   real(c_float),          intent(in)  :: nan_rgba(4) !< NaN colour, RGBA in [0, 1].
   integer(c_int), value               :: changed     !< 1: the values changed.
   real(c_double),         intent(out) :: range(2)    !< The range applied.
   integer(c_int)                      :: status      !< Status.
   endfunction fig_field_image

   function fig_field_uploads() result(n) bind(C, name='fig_field_uploads')
   !< Field colourings uploaded since the start (tests).
   import :: c_long_long
   implicit none
   integer(c_long_long) :: n !< Uploads.
   endfunction fig_field_uploads

   function fig_field_count() result(n) bind(C, name='fig_field_count')
   !< Field textures cached (tests).
   import :: c_int
   implicit none
   integer(c_int) :: n !< Entries.
   endfunction fig_field_count

   function fig_field_time() result(ms) bind(C, name='fig_field_time')
   !< The last field colouring's time, upload included [ms] (tests).
   import :: c_double
   implicit none
   real(c_double) :: ms !< Time [ms].
   endfunction fig_field_time

   function fig_field_pixel(label, label_len, i, j, rgba) result(status) bind(C, name='fig_field_pixel')
   !< The colour of the field `label`'s value (i, j), as uploaded last (tests).
   import :: c_char, c_float, c_int
   implicit none
   character(kind=c_char), intent(in)  :: label(*)  !< Label (not NUL-terminated).
   integer(c_int), value               :: label_len !< Its length [bytes].
   integer(c_int), value               :: i         !< Index along x (1-based).
   integer(c_int), value               :: j         !< Index along y (1-based).
   real(c_float),          intent(out) :: rgba(4)   !< Colour, RGBA in [0, 1].
   integer(c_int)                      :: status    !< Status.
   endfunction fig_field_pixel

   function fig_load_colormap(name, name_len, path, path_len) result(status) bind(C, name='fig_load_colormap')
   !< Read a user colormap (CSV table of RGB rows, or a ParaView JSON preset) under a new name.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: name(*)  !< Name (not NUL-terminated).
   integer(c_int), value              :: name_len !< Its length [bytes].
   character(kind=c_char), intent(in) :: path(*)  !< File (not NUL-terminated).
   integer(c_int), value              :: path_len !< Its length [bytes].
   integer(c_int)                     :: status   !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_load_colormap

   function fig_colormap_count() result(count) bind(C, name='fig_colormap_count')
   !< The number of colormap names: bundled, ImPlot's own, the user's.
   import :: c_int
   implicit none
   integer(c_int) :: count !< Names.
   endfunction fig_colormap_count

   function fig_colormap_name(index, buf, buf_len) result(length) bind(C, name='fig_colormap_name')
   !< The index-th colormap name (from 1): up to `buf_len` bytes copied; its length.
   import :: c_char, c_int
   implicit none
   integer(c_int), value               :: index   !< Index, from 1.
   character(kind=c_char), intent(out) :: buf(*)  !< Buffer.
   integer(c_int), value               :: buf_len !< Its size [bytes].
   integer(c_int)                      :: length  !< The name's length [bytes] (0: no such name).
   endfunction fig_colormap_name

   function fig_gradient_edit(id, id_len, name, name_len, width, height, changed) result(status) &
      bind(C, name='fig_gradient_edit')
   !< The gradient editor of the colormap `name`: its stops dragged, added, recoloured, removed; changed 1 on a change.
   import :: c_char, c_float, c_int
   implicit none
   character(kind=c_char), intent(in)  :: id(*)    !< Id (not NUL-terminated).
   integer(c_int), value               :: id_len   !< Its length [bytes].
   character(kind=c_char), intent(in)  :: name(*)  !< Colormap name.
   integer(c_int), value               :: name_len !< Its length [bytes].
   real(c_float), value                :: width    !< Width [pixels] (<= 0: the space left plus it).
   real(c_float), value                :: height   !< Height [pixels] (<= 0: the default).
   integer(c_int), intent(out)         :: changed  !< 1: the map changed on this frame.
   integer(c_int)                      :: status   !< Status.
   endfunction fig_gradient_edit

   function fig_colormap_stops(name, name_len, pos, rgb, cap, n) result(status) bind(C, name='fig_colormap_stops')
   !< The stops of the colormap `name` (sorted by position): up to `cap` copied, `n` their number.
   import :: c_char, c_double, c_int
   implicit none
   character(kind=c_char), intent(in)  :: name(*)  !< Colormap name.
   integer(c_int), value               :: name_len !< Its length [bytes].
   real(c_double), intent(out)         :: pos(*)   !< Positions in [0, 1].
   real(c_double), intent(out)         :: rgb(*)   !< Colours, 3 per stop, in [0, 1].
   integer(c_int), value               :: cap      !< Stops room.
   integer(c_int), intent(out)         :: n        !< Stops.
   integer(c_int)                      :: status   !< Status.
   endfunction fig_colormap_stops

   ! ---- the canvas (native/figure_canvas.cpp) --------------------------------------------------------------------------
   function fig_canvas(id, id_len, width, height, texture, ev) result(status) bind(C, name='fig_canvas')
   !< An area taking the mouse, owning the wheel while hovered, the texture drawn over it; its event of the frame.
   import :: c_char, c_double, c_int, c_long_long, fig_canvas_event
   implicit none
   character(kind=c_char), intent(in)  :: id(*)   !< Id (not NUL-terminated).
   integer(c_int), value               :: id_len  !< Its length [bytes].
   real(c_double), value               :: width   !< Width [pixels] (<= 0: the space left plus it).
   real(c_double), value               :: height  !< Height [pixels] (<= 0: the space left plus it).
   integer(c_long_long), value         :: texture !< ImTextureID drawn over it (0: none).
   type(fig_canvas_event), intent(out) :: ev      !< Its event.
   integer(c_int)                      :: status  !< Status: FIG_OK or FIG_ERR_*.
   endfunction fig_canvas

   function fig_draw(kind, layer, x, y, n, rgba, thickness, radius, filled, text, text_len, texture) result(status) &
      bind(C, name='fig_draw')
   !< One drawing primitive on a layer: FIG_OK, -1 for the plot layer outside a plot.
   import :: c_char, c_double, c_int, c_long_long
   implicit none
   integer(c_int), value              :: kind      !< 1 line, 2 rect, 3 circle, 4 polyline, 5 polygon, 6 text, 7 image.
   integer(c_int), value              :: layer     !< 1 window, 2 foreground, 3 background, 4 plot.
   real(c_double), intent(in)         :: x(*)      !< Abscissae [pixels, or plot units on layer 4].
   real(c_double), intent(in)         :: y(*)      !< Ordinates [pixels, or plot units on layer 4].
   integer(c_int), value              :: n         !< Points.
   real(c_double), intent(in)         :: rgba(4)   !< Colour, RGBA in [0, 1].
   real(c_double), value              :: thickness !< Line thickness [pixels].
   real(c_double), value              :: radius    !< A circle's radius [pixels].
   integer(c_int), value              :: filled    !< 1: filled (a polyline: closed).
   character(kind=c_char), intent(in) :: text(*)   !< Text (not NUL-terminated).
   integer(c_int), value              :: text_len  !< Its length [bytes].
   integer(c_long_long), value        :: texture   !< ImTextureID (an image).
   integer(c_int)                     :: status    !< Status.
   endfunction fig_draw

   subroutine fig_cursor_screen_pos(x, y) bind(C, name='fig_cursor_screen_pos')
   !< Where the next item goes, on the screen (GetCursorScreenPos).
   import :: c_double
   implicit none
   real(c_double), intent(out) :: x !< Abscissa [pixels].
   real(c_double), intent(out) :: y !< Ordinate [pixels].
   endsubroutine fig_cursor_screen_pos

   function fig_invisible_button(id, id_len, width, height, pressed) result(status) bind(C, name='fig_invisible_button')
   !< An invisible button (InvisibleButton).
   import :: c_char, c_double, c_int
   implicit none
   character(kind=c_char), intent(in)  :: id(*)   !< Id (not NUL-terminated).
   integer(c_int), value               :: id_len  !< Its length [bytes].
   real(c_double), value               :: width   !< Width [pixels] (<= 0: the space left plus it).
   real(c_double), value               :: height  !< Height [pixels] (<= 0: the space left plus it).
   integer(c_int),         intent(out) :: pressed !< 1: clicked on this frame.
   integer(c_int)                      :: status  !< Status.
   endfunction fig_invisible_button

   function fig_drawn_extent_layer(rgba, layer, rect, found, vertices) result(status) &
      bind(C, name='fig_drawn_extent_layer')
   !< The extent and number of the vertices drawn so far in an RGBA colour on a layer (1 window, 2 foreground,
   !< 3 background).
   import :: c_float, c_int
   implicit none
   real(c_float),  intent(in)  :: rgba(4) !< Colour, RGBA in [0, 1].
   integer(c_int), value       :: layer   !< Layer.
   real(c_float),  intent(out) :: rect(4) !< xmin, ymin, xmax, ymax [pixels].
   integer(c_int), intent(out) :: found    !< 1: something was drawn in it.
   integer(c_int), intent(out) :: vertices !< Vertices in it.
   integer(c_int)              :: status   !< Status.
   endfunction fig_drawn_extent_layer
   ! Application layer (native/figure_app.cpp).

   function fig_window_add(name, name_len, visible, closable, in_view_menu, remember) result(status) &
      bind(C, name='fig_window_add')
   !< Register a window by its `ig_begin` name; the flags are 0 or 1.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: name(*)      !< Window name.
   integer(c_int), value              :: name_len     !< Its length.
   integer(c_int), value              :: visible      !< Shown at first.
   integer(c_int), value              :: closable     !< A close button.
   integer(c_int), value              :: in_view_menu !< Listed in the View menu.
   integer(c_int), value              :: remember     !< Its visibility kept by the preferences.
   integer(c_int)                     :: status       !< Status.
   endfunction fig_window_add

   function fig_window_visible(name, name_len, visible) result(status) bind(C, name='fig_window_visible')
   !< Whether a registered window is shown (1) or hidden (0).
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in)  :: name(*)  !< Window name.
   integer(c_int), value               :: name_len !< Its length.
   integer(c_int),         intent(out) :: visible  !< 1: shown.
   integer(c_int)                      :: status   !< Status.
   endfunction fig_window_visible

   function fig_window_set_visible(name, name_len, visible) result(status) bind(C, name='fig_window_set_visible')
   !< Show (1) or hide (0) a registered window.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: name(*)  !< Window name.
   integer(c_int), value              :: name_len !< Its length.
   integer(c_int), value              :: visible  !< 1: shown.
   integer(c_int)                     :: status   !< Status.
   endfunction fig_window_set_visible

   function fig_window_open_flag(name, name_len) result(flag) bind(C, name='fig_window_open_flag')
   !< The `bool*` of a registered closable window, for `igBegin`'s close button (null otherwise).
   import :: c_char, c_int, c_ptr
   implicit none
   character(kind=c_char), intent(in) :: name(*)  !< Window name.
   integer(c_int), value              :: name_len !< Its length.
   type(c_ptr)                        :: flag     !< The flag, or null.
   endfunction fig_window_open_flag

   function fig_view_menu(label, label_len) result(status) bind(C, name='fig_view_menu')
   !< The View menu (label empty: 'View'), inside a menu bar.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: label(*)  !< Menu label.
   integer(c_int), value              :: label_len !< Its length.
   integer(c_int)                     :: status    !< Status.
   endfunction fig_view_menu

   function fig_layout_add(name, name_len, names, names_len, has_windows) result(status) bind(C, name='fig_layout_add')
   !< Declare a layout; `names`: the registered windows it shows, newline-separated (with `has_windows` 1).
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: name(*)     !< Layout name.
   integer(c_int), value              :: name_len    !< Its length.
   character(kind=c_char), intent(in) :: names(*)    !< Window names.
   integer(c_int), value              :: names_len   !< Their length.
   integer(c_int), value              :: has_windows !< 1: the layout says which windows it shows.
   integer(c_int)                     :: status      !< Status.
   endfunction fig_layout_add

   function fig_layout_switch(name, name_len) result(status) bind(C, name='fig_layout_switch')
   !< Make a layout current.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: name(*)  !< Layout name.
   integer(c_int), value              :: name_len !< Its length.
   integer(c_int)                     :: status   !< Status.
   endfunction fig_layout_switch

   function fig_layout_reset() result(status) bind(C, name='fig_layout_reset')
   !< Lay the current layout out again, the user's changes to it forgotten.
   import :: c_int
   implicit none
   integer(c_int) :: status !< Status.
   endfunction fig_layout_reset

   function fig_layout_current(buf, buf_len) result(n) bind(C, name='fig_layout_current')
   !< The current layout's name copied into `buf` (up to `buf_len` bytes); its length.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(out) :: buf(*)  !< Buffer.
   integer(c_int), value               :: buf_len !< Its size.
   integer(c_int)                      :: n       !< Length.
   endfunction fig_layout_current

   function fig_prefs_open(name, name_len, file, file_len) result(status) bind(C, name='fig_prefs_open')
   !< Name the preferences' file (empty: the platform's folder for `name`) and read it.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: name(*)  !< The program's name.
   integer(c_int), value              :: name_len !< Its length.
   character(kind=c_char), intent(in) :: file(*)  !< File.
   integer(c_int), value              :: file_len !< Its length (0: the default).
   integer(c_int)                     :: status   !< Status.
   endfunction fig_prefs_open

   function fig_prefs_file(buf, buf_len) result(n) bind(C, name='fig_prefs_file')
   !< The preferences' file copied into `buf` (up to `buf_len` bytes); its length (0: none).
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(out) :: buf(*)  !< Buffer.
   integer(c_int), value               :: buf_len !< Its size.
   integer(c_int)                      :: n       !< Length.
   endfunction fig_prefs_file

   function fig_pref_set(key, key_len, value, value_len) result(status) bind(C, name='fig_pref_set')
   !< Keep a preference, as text.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in) :: key(*)    !< Key.
   integer(c_int), value              :: key_len   !< Its length.
   character(kind=c_char), intent(in) :: value(*)  !< Value.
   integer(c_int), value              :: value_len !< Its length.
   integer(c_int)                     :: status    !< Status.
   endfunction fig_pref_set

   function fig_pref_get(key, key_len, buf, buf_len, n, found) result(status) bind(C, name='fig_pref_get')
   !< A preference's text copied into `buf` (up to `buf_len` bytes), its length `n`; `found` 0 or 1.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in)  :: key(*)  !< Key.
   integer(c_int), value               :: key_len !< Its length.
   character(kind=c_char), intent(out) :: buf(*)  !< Buffer.
   integer(c_int), value               :: buf_len !< Its size.
   integer(c_int),         intent(out) :: n       !< The value's length.
   integer(c_int),         intent(out) :: found   !< 1: kept.
   integer(c_int)                      :: status  !< Status.
   endfunction fig_pref_get

   function fig_message_box(id, id_len, title, title_len, text, text_len, buttons, buttons_len, answer) result(status) &
      bind(C, name='fig_message_box')
   !< A message box: `answer` 0 while open, then the button chosen (from 1), once.
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in)  :: id(*)       !< Id.
   integer(c_int), value               :: id_len      !< Its length.
   character(kind=c_char), intent(in)  :: title(*)    !< Title.
   integer(c_int), value               :: title_len   !< Its length.
   character(kind=c_char), intent(in)  :: text(*)     !< Text.
   integer(c_int), value               :: text_len    !< Its length.
   character(kind=c_char), intent(in)  :: buttons(*)  !< Button labels, newline-separated.
   integer(c_int), value               :: buttons_len !< Their length (< 0: one button, OK).
   integer(c_int),         intent(out) :: answer      !< The button chosen, 0 while open.
   integer(c_int)                      :: status      !< Status.
   endfunction fig_message_box

   function fig_splitter(id, id_len, vertical, sizes, min_size, changed) result(status) bind(C, name='fig_splitter')
   !< A splitter bar at the cursor between two panes; `changed` 1 when dragged.
   import :: c_char, c_double, c_int
   implicit none
   character(kind=c_char), intent(in)    :: id(*)    !< Id (and its label for paths).
   integer(c_int), value                 :: id_len   !< Its length.
   integer(c_int), value                 :: vertical !< 1: the panes one above the other.
   real(c_double),         intent(inout) :: sizes(2) !< The panes' sizes [pixels].
   real(c_double), value                 :: min_size !< A pane's least size [pixels] (< 0: the frame height).
   integer(c_int),         intent(out)   :: changed  !< 1: dragged.
   integer(c_int)                        :: status   !< Status.
   endfunction fig_splitter

   function fig_set_size_limits(min_w, min_h, max_w, max_h) result(status) bind(C, name='fig_set_size_limits')
   !< The window's least and greatest size [logical pixels] (0: none); window mode only.
   import :: c_int
   implicit none
   integer(c_int), value :: min_w  !< Least width.
   integer(c_int), value :: min_h  !< Least height.
   integer(c_int), value :: max_w  !< Greatest width (0: none).
   integer(c_int), value :: max_h  !< Greatest height (0: none).
   integer(c_int)        :: status !< Status.
   endfunction fig_set_size_limits
endinterface
endmodule figure_c_native
