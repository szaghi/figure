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
/* Theme files (figure_theme.h format): load one, or write the style in effect as one (what differs from its base). */
int    fig_load_style(const char *path, int path_len);
int    fig_save_style(const char *path, int path_len);
/* Dear ImGui's and ImPlot's style editors in a window ("Style editor"); open: the window's close button (may be NULL). */
int    fig_show_style_editor(int *open);
/* Fonts: "plex-sans" (bundled, the default, 15 px), "proggy" (Dear ImGui's bitmap font) or a TTF/OTF file. set_font
 * sets the default font and, if size > 0, its size [logical pixels]; push_font switches the font (name empty: the
 * current one) and/or the size (0: the current one) until pop_font. */
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
/* A window's rectangle (xmin, ymin, xmax, ymax) [pixels] by name, as in the last frame; found 0 if none. */
int    fig_window_rect(const char *name, int name_len, float *rect, int *found);
/* Synthetic input, for tests (headless or not): mouse position in pixels and left-button state. */
void   fig_input_mouse(float x, float y, int left_down);

/* The cimgui/cimplot functions passing structs by value are wrapped in figure_glue_generated.cpp (generated). */

#ifdef __cplusplus
}
#endif

#endif
