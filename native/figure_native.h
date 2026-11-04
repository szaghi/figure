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
void   fig_request_frames(int n);
double fig_content_scale(void);
const char *fig_last_error(int *len);

/* Synthetic input, for tests (headless or not): mouse position in pixels and left-button state. */
void   fig_input_mouse(float x, float y, int left_down);

/* ImPlot items whose C signature carries a by-value ImPlotSpec (kept on this side of the boundary). */
int    fig_plot_line(const char *label, int label_len, const double *xs, const double *ys, int n);

#ifdef __cplusplus
}
#endif

#endif
