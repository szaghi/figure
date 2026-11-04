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
int    fig_begin_frame(int *running);
int    fig_end_frame(void);
void   fig_shutdown(void);
void   fig_set_lazy(int enabled, double max_wait_s);
/* Keep window positions and sizes in this file (Dear ImGui's imgui.ini); off by default. Before the first frame. */
int    fig_set_ini_file(const char *path, int path_len);
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

/* Synthetic input, for tests (headless or not): mouse position in pixels and left-button state. */
void   fig_input_mouse(float x, float y, int left_down);

/* The cimgui/cimplot functions passing structs by value are wrapped in figure_glue_generated.cpp (generated). */

#ifdef __cplusplus
}
#endif

#endif
