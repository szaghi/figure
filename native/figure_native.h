/* FIGURE native glue: the C ABI the Fortran side calls besides the cimgui/cimplot functions it binds directly.
 *
 * Conventions:
 *  - every function is plain C (extern "C"), returns an int status (FIG_OK on success) unless documented otherwise, and
 *    never lets a C++ exception escape;
 *  - strings from Fortran arrive as (pointer, byte length) UTF-8, no NUL terminator;
 *  - the glue owns the platform (SDL3 window, OpenGL context) and the ImGui/ImPlot contexts: Fortran never sees them.
 */
#ifndef FIGURE_NATIVE_H
#define FIGURE_NATIVE_H

#ifdef __cplusplus
extern "C" {
#endif

/* Status codes: must match the FIG_* parameters of src/lib/figure_c_native.F90. */
enum { FIG_OK = 0, FIG_ERR_STATE = 1, FIG_ERR_ARGUMENT = 2, FIG_ERR_FAILED = 3, FIG_ERR_EXCEPTION = 4 };

/* Platform and frame loop. */
int    fig_init(const char *title, int title_len, int width, int height, int vsync);
int    fig_init_headless(int width, int height);
/* The UI in a web browser: serve it on http://host:port/ (host empty: 127.0.0.1; port 0: any free port, returned in
 * bound_port). No window, display or GPU needed. One browser at a time; no authentication: keep the default host and
 * reach a remote machine through an SSH tunnel. */
int    fig_init_remote(int width, int height, const char *host, int host_len, int port, int *bound_port);
int    fig_begin_frame(int *running);
int    fig_end_frame(void);
void   fig_shutdown(void);
void   fig_set_lazy(int enabled, double max_wait_s);
// Remote mode: at most `max_fps` frames per second (default 60; 0 or less: no cap).
void   fig_set_remote_fps(double max_fps);
// Remote mode: deflate frames and textures, 0 auto (while the client is the bottleneck), 1 always, 2 never.
void   fig_set_remote_compress(int mode);
// Remote mode: the access token (empty: none, anyone reaching the port is let in). Set after fig_init_remote, which
// makes a random one; fig_remote_token copies it into buf (up to buf_len bytes) and returns its length.
void   fig_set_remote_token(const char *token, int token_len);
int    fig_remote_token(char *buf, int buf_len);
/* Keep window positions and sizes in this file (Dear ImGui's imgui.ini); off by default. Before the first frame. */
int    fig_set_ini_file(const char *path, int path_len);
/* A built-in style (themes/<name>.toml); lines: a named line palette (okabe-ito), empty for the theme's own. */
int    fig_set_style(const char *name, int name_len, const char *lines, int lines_len);
/* Style by name, lib 0 Dear ImGui, 1 ImPlot; set 1 writes, 0 reads. Colours: the libraries' colour names (Text,
 * Button, PlotBg, ...), rgba in [0, 1]. Variables: every plain field of ImGuiStyle/ImPlotStyle (WindowRounding,
 * FramePadding, PlotPadding, ...): count values (1, or 2 for an ImVec2; bools as 0/1, enumerations as integers),
 * returned in count when reading. */
/* The window's frame (decorations), given before fig_init or fig_init_headless: decorations 0 native, 1 figure
 * (borderless, the title bar drawn by FIGURE with the main menu bar in it); buttons 0 the platform's side (left on
 * macOS), 1 right, 2 left. Headless: the bar is drawn and its buttons' actions are recorded as state; remote: none. */
int    fig_frame_options(int decorations, int buttons);
/* The window's icon (window mode): RGBA pixels, rows from the top; or one ICON_* glyph rendered with the icon font. */
int    fig_set_icon_rgba(const unsigned char *rgba, int width, int height);
int    fig_set_icon_glyph(const char *icon, int icon_len);
/* The frame's hit test at (x, y), from the last frame (0 client, 1 drag, 2..9 resize: top-left, top, top-right,
 * right, bottom-right, bottom, bottom-left, left: SDL_HitTestResult); a part's rectangle (0 bar, 1 icon, 2 menus,
 * 3 title, 4 minimize, 5 maximize, 6 close) and whether it was drawn; minimized and maximized (headless: as recorded). */
int    fig_frame_hit(float x, float y, int *hit);
int    fig_frame_rect(int part, float *rect, int *found);
int    fig_frame_state(int *minimized, int *maximized);
/* The style by parts, at once (nothing changes on an error): a built-in style by name, then a look, then a palette (a
 * bundled name or "auto", choosing between auto_dark and auto_light), then a line palette; an empty part is kept. */
int    fig_set_style_parts(const char *name, int name_len, const char *look, int look_len, const char *palette,
                           int palette_len, const char *auto_dark, int auto_dark_len, const char *auto_light,
                           int auto_light_len, const char *lines, int lines_len);
/* The colour of a palette role in effect (rgba[4] in [0, 1]); without a palette, read from Dear ImGui's colours. */
int    fig_palette_color(const char *role, int role_len, float *rgba);
/* Theme files (figure_theme.h format): load one, or write the style in effect as one (what differs from its base). */
int    fig_load_style(const char *path, int path_len);
int    fig_save_style(const char *path, int path_len);
/* Dear ImGui's and ImPlot's style editors in a window ("Style editor"); open: the window's close button (may be NULL). */
int    fig_show_style_editor(int *open);
/* Fonts: "plex-sans" (bundled, the default, 15 px), "plex-mono" (bundled, monospace), "proggy" (Dear ImGui's bitmap
 * font) or a TTF/OTF file. set_font sets the default font and, if size > 0, its size [logical pixels]; push_font
 * switches the font (name empty: the current one) and/or the size (0: the current one) until pop_font. */
int    fig_set_font(const char *name, int name_len, double size);
int    fig_push_font(const char *name, int name_len, double size);
int    fig_pop_font(void);
/* Scoped style changes, either library (lib 0 Dear ImGui, 1 ImPlot): a push changes a colour or a variable (any field,
 * by name) and remembers its value; pop_style(vars 0: colours, 1: variables, n) restores the n newest. */
int    fig_push_style_color(int lib, const char *name, int name_len, const float *rgba);
int    fig_push_style_var(int lib, const char *name, int name_len, const double *values, int count);
int    fig_pop_style(int vars, int n);
int    fig_style_color(int lib, const char *name, int name_len, int set, float *rgba);
int    fig_style_var(int lib, const char *name, int name_len, int set, double *values, int *count);
void   fig_request_frames(int n);
double fig_content_scale(void);
const char *fig_last_error(int *len);
/* Set the message fig_last_error returns, for failures detected on the Fortran side. */
void   fig_set_last_error(const char *msg, int msg_len);

/* User textures: RGBA, 8 bits per channel, rows of `width` pixels. The id is the ImTextureID (in window mode the GL
 * texture name); update uploads straight from `rgba` (one glTexSubImage2D, no staging copy); destroy is safe on an
 * unknown id; shutdown destroys the textures left. In headless mode ids are issued and sizes checked, without GL. */
int    fig_texture_create(int width, int height, int smooth, unsigned long long *id);
int    fig_texture_update(unsigned long long id, int width, int height, const unsigned char *rgba);
void   fig_texture_destroy(unsigned long long id);
/* Around a user image: from_texture = 1 makes the backend sample with the texture's own filter, 0 restores its
 * render state; plot = 1 for the current ImPlot plot's draw list, 0 for the current window's. */
void   fig_texture_sampling(int plot, int from_texture);

/* Docking (Dear ImGui's docking branch). Dock ids are ImGuiIDs: fig_dock_id hashes a name. A layout is built once,
 * while fig_dock_layout_begin reports it is needed (no node yet: first run without an ini file): split, dock
 * windows, end; then fig_dock_space every frame, before the windows docked into it. Direction: ImGuiDir (0 left,
 * 1 right, 2 up, 3 down); fraction: the part of the node given to the side at `direction`. */
int    fig_set_docking(int enabled);
unsigned int fig_dock_id(const char *name, int name_len);
int    fig_dock_space(unsigned int id, int flags);
int    fig_dock_layout_begin(unsigned int id, int *needed);
int    fig_dock_split(unsigned int id, int direction, double fraction, unsigned int *id_at_dir, unsigned int *id_other);
int    fig_dock_window(const char *name, int name_len, unsigned int id);
int    fig_dock_layout_end(unsigned int id);
/* Inside a window (between Begin and End): its dock node (0 if none) and whether it is docked. */
int    fig_window_dock(unsigned int *id, int *docked);

/* Synthetic input (figure_testing), queued as real input is: mouse position [pixels], button (0 left, 1 right,
 * 2 middle) down/up, wheel, key by name (a-z, 0-9, enter, tab, backspace, delete, escape, space, arrows left/right/
 * up/down, home, end, pageup, pagedown, f1-f12, ctrl, shift, alt, super) down/up, typed text (UTF-8). */
/* Queued in FIGURE and handed to Dear ImGui at the next frame, up to a frame boundary (fig_input_next_frame). */
int    fig_input_next_frame(void);
int    fig_input_mouse_pos(float x, float y);
int    fig_input_mouse_button(int button, int down);
int    fig_input_wheel(float dx, float dy);
int    fig_input_key(const char *name, int name_len, int down);
int    fig_input_text(const char *text, int text_len);
/* A tick label of the plot being declared: axis 0 x, 1 y, index from 1; count of ticks (tests of axis formats). */
int    fig_plot_tick_label(int axis, int index, char *buf, int buf_len, int *count, int *len);
/* A window's rectangle (xmin, ymin, xmax, ymax) [pixels] by name, as in the last frame; found 0 if none. */
int    fig_window_rect(const char *name, int name_len, float *rect, int *found);
/* Quitting: with confirm_quit on, the window's close button (or SDL's quit event) sets a request, read and cleared by
 * fig_quit_requested (1 once per request), instead of ending the loop; fig_quit ends it at the next fig_begin_frame.
 * fig_input_quit makes a request as the close button does (tests). */
void   fig_set_confirm_quit(int on);
int    fig_quit_requested(void);
void   fig_quit(void);
/* The window's title: set after fig_init (shown in window mode, kept in every mode); fig_title copies it into buf
 * (up to buf_len bytes) and returns its length. */
int    fig_set_title(const char *title, int title_len);
int    fig_title(char *buf, int buf_len);
int    fig_input_quit(void);
/* The system's light (1) or dark (2) setting, as SDL's theme-changed event reports it, handled at the next frame;
 * 0 gives the setting back to the system (tests of palette "auto"). */
int    fig_input_system_theme(int theme);
/* File dialogs (window mode): kind 0 open, 1 save, 2 folder; filters "name|pattern" separated by newlines. The result
 * is polled by id: state 0 open, 1 chosen (path), 2 cancelled, 3 failed. */
int    fig_file_dialog(int kind, const char *id, int id_len, const char *filters, int filters_len, const char *path,
                       int path_len);
int    fig_file_dialog_result(const char *id, int id_len, char *buf, int buf_len, int *state, int *path_len);
/* 1 while the system's dialog `id` is open (no answer yet). */
int    fig_file_dialog_pending(const char *id, int id_len);
/* File browser (figure_files.cpp): FIGURE's own dialog, a modal drawn in Dear ImGui at the end of each frame, in every
 * mode; kind 0 open a file, 1 save a file, 2 choose a folder; filters and path as fig_file_dialog. Answered through
 * fig_file_dialog_result (state 1 chosen, 2 cancelled). An id open in either kind of dialog is refused. The recent
 * folders are kept in the settings file: SDL_GetPrefPath("", "figure")/settings.ini in window and remote modes, none
 * (memory only) in headless mode and during a capture; fig_file_browser_settings names another (empty: none) until the
 * program ends. Tests: get(what, index) copies into buf (len its length; count: the list's length, or 1) 0 the folder,
 * 1 entry `index` shown (folders end in '/'), 2 the error shown, 3 "1" while a replace is asked, 4 the path field, 5
 * recent folder `index`, 6 the name field; nothing (count 0) without a browser, but for 5. rect: a part of the browser
 * drawn in the last frame (names in figure_testing's test_file_browser_rect). */
int    fig_file_browser(int kind, const char *id, int id_len, const char *filters, int filters_len, const char *path,
                        int path_len);
int    fig_file_browser_settings(const char *path, int path_len);
int    fig_file_browser_get(int what, int index, char *buf, int buf_len, int *len, int *count);
int    fig_file_browser_rect(const char *part, int part_len, float *rect, int *found);
/* Internal (figure_native.cpp): a browser open with this id; its answer, as fig_file_dialog_result; draw the front
 * browser (in fig_end_frame); forget every browser and answer, at init (init 1; keep 1: the settings file of SDL's
 * pref path) and at shutdown (0, 0). */
int    fig_file_browser_pending(const char *id, int id_len);
int    fig_file_browser_result(const char *id, int id_len, char *buf, int buf_len, int *state, int *path_len);
void   fig_file_browser_draw(void);
void   fig_file_browser_reset(int init, int keep);
int    fig_save_image(const char *path, int path_len, double x0, double y0, double x1, double y1);
int    fig_image_result(char *buf, int buf_len, int *state, int *path_len);
int    fig_save_layout(const char *path, int path_len, const char *comment, int comment_len);
int    fig_load_layout(const char *path, int path_len);
int    fig_begin_side_bar(const char *name, int name_len, int side, double size);
int    fig_tool_button(const char *label, int label_len, const char *icon, int icon_len, double width, double height,
                       int selected, const double *accent);
void  *fig_clipper_new(void);
void   fig_clipper_begin(void *clipper, int count, double item_height);
int    fig_clipper_step(void *clipper, int *first, int *last);
void   fig_clipper_delete(void *clipper);
/* A key chord ("ctrl+s": modifiers and one key, by the names of fig_input_key, joined by '+'). */
int    fig_key_chord(const char *keys, int keys_len, int *chord);
/* A text field over a caller-owned NUL-terminated buffer of buf_size bytes (InputText without a callback); 1 when
 * edited this frame. hint_len 0: no hint. */
int    fig_widget_input_text(const char *label, int label_len, const char *hint, int hint_len, char *buf, int buf_size,
                             int flags);
/* Text buffers (text_buffer_object): text of any length owned here, edited in place by a multi-line field that grows
 * it through Dear ImGui's resize callback. A handle is created by set or by the first draw (*id 0: a new one); any
 * thread may set, read and release one (a mutex guards them). set turns CRLF into LF. get copies at most cap bytes
 * and returns the text's length [bytes]; length gives it alone; an unknown handle is an empty text. The widget: width
 * and height [pixels] as ImGui's size (0: default, negative: up to that distance from the region's edge); 1 when
 * edited this frame. */
int       fig_text_set(int *id, const char *text, long long len);
long long fig_text_get(int id, char *buf, long long cap);
long long fig_text_length(int id);
void      fig_text_release(int id);
int       fig_widget_input_text_multiline(int *id, const char *label, int label_len, double width, double height,
                                          int flags);
/* Drops (app%dropped): the paths dropped on the window since the last frame began (SDL's drop events; in every mode
 * a test's, fig_input_drop, queued as the other synthetic input), and where the last one was dropped [pixels]: count
 * and position for this frame, then each path (index from 1; up to buf_len bytes copied, its length returned). */
int    fig_input_drop(const char *path, int path_len, float x, float y);
int    fig_dropped(int *count, float *x, float *y);
int    fig_dropped_path(int index, char *buf, int buf_len);
/* The clipboard (Dear ImGui's platform clipboard: SDL's in a window, the program's own in headless mode, in remote
 * mode the program's own, sent to the browser on a set and set by the browser on a paste). get copies at most cap
 * bytes and returns the text's length [bytes]; 0 before init. */
int       fig_set_clipboard(const char *text, int text_len);
long long fig_get_clipboard(char *buf, long long cap);
/* Synthetic input, for tests (headless or not): mouse position in pixels and left-button state. */
void   fig_input_mouse(float x, float y, int left_down);

/* Work off the frame loop: fig_wake, from any thread, makes a lazy frame loop draw the next frame at once (window:
 * an SDL event; remote: the wait on the sockets ends; headless: nothing waits); fig_background(+1/-1) counts the
 * readers and workers alive (remote mode waits in slices of 10 ms while there are some). */
void   fig_wake(void);
void   fig_background(int delta);

/* Processes (figure_process.cpp). args, env: packed strings (one buffer, the byte length of each); env entries are
 * NAME=value, added to (or replacing in) the program's environment. Captured (detached 0): standard output piped to
 * the program, standard error merged into it with merge_stderr (else inherited), drained by a reader thread; killed
 * when released, at fig_shutdown and at exit. Detached: output to log (required), the child survives the program.
 * pending: the bytes ready to take (complete lines; all at the end) and whether it still runs; take copies them out
 * (got: bytes copied). info: exited, exit code (captured), killed (ended after fig_process_kill), pid. release
 * forgets the process (a captured one is killed if running). */
int    fig_process_start(int *id, const char *args, const int *arg_lens, int nargs, const char *cwd, int cwd_len,
                         const char *env, const int *env_lens, int nenv, int merge_stderr, int detached,
                         const char *log, int log_len);
int    fig_process_pending(int id, long long *len, int *running);
int    fig_process_take(int id, char *buf, long long len, long long *got);
int    fig_process_info(int id, int *running, int *exited, int *code, int *killed, long long *pid, int *detached);
int    fig_process_kill(int id, int force);
void   fig_process_release(int id);
void   fig_process_shutdown(void);

/* Notifications: kind 0 info, 1 success, 2 warning, 3 error, an icon (UTF-8 glyph), seconds shown (<= 0: until
 * clicked); drawn by FIGURE after the program's windows. The kept ones (the last 100, oldest first): count, and each
 * one's text (up to buf_len bytes, len its length), kind and whether it is still shown. rect: the shown ones in the last
 * frame, 1 the newest (bottom); found 0 past the last. */
int    fig_notify(const char *text, int text_len, int kind, const char *icon, int icon_len, double seconds);
int    fig_notification_count(int *count);
int    fig_notification_get(int index, char *buf, int buf_len, int *len, int *kind, int *shown);
int    fig_notification_rect(int index, float *rect, int *found);
/* Tests: the extent (xmin, ymin, xmax, ymax) of the vertices drawn so far in the current window in a style colour of
 * Dear ImGui, by name (PlotHistogram: a progress bar's fill); found 0 if none. */
int    fig_drawn_extent(const char *color, int color_len, float *rect, int *found);

/* Tasks (figure_task.cpp): fn(arg) run on an SDL thread (64 MiB of stack). state: done, the last progress (fraction
 * in [0, 1], negative before the first report) and message (copied into msg, up to msg_len bytes; len its length),
 * and the failure's status. report and fail are called by the task (keep_message 1: the message stays); cancel and
 * cancelled are the cooperative stop. finish waits for an ended task's thread and returns its failure (message in
 * fig_last_error); release asks a task to stop and waits for it. refuse(name), at FIGURE's drawing entry points: 0 on
 * the main thread; on a worker 1, the task's status becomes FIG_ERR_STATE with a message naming the entry point, and
 * the task is asked to stop. */
int    fig_task_start(void (*fn)(void *), void *arg, int *id);
int    fig_task_state(int id, int *done, double *fraction, char *msg, int msg_len, int *len, int *status);
int    fig_task_report(int id, double fraction, const char *msg, int msg_len, int keep_message);
int    fig_task_fail(int id, const char *msg, int msg_len);
int    fig_task_cancel(int id);
int    fig_task_cancelled(int id);
int    fig_task_finish(int id);
void   fig_task_release(int id);
int    fig_task_on_worker(void);
int    fig_task_refuse(const char *name, int name_len);

/* The cimgui/cimplot functions passing structs by value are wrapped in figure_glue_generated.cpp (generated). */

#ifdef __cplusplus
}
#endif

#endif
