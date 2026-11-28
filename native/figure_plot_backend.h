// The native layer's plot side, apart from its core (szaghi/figure#15 G2): what figure_native.cpp, figure_scope.cpp and
// figure_canvas.cpp ask of the plots goes through the tables below, so that a program links ImPlot, ImPlot3D and their
// glue only where something references them. Native internal (C++), not part of figure_native.h's C API.
//
// - fig_implot: ImPlot's and ImPlot3D's side (figure_implot_glue.cpp), registered by that file's static initializer,
//   so present exactly in the programs that link it: the current path's (its figure_implot calls the glue's
//   fig_plot_* functions) and the Fortran path's side-by-side tests (their reference modules do). It makes and
//   destroys the contexts, holds ImPlot's and ImPlot3D's styles (a store as the Fortran one), draws the canvas's plot
//   layer and serves the scope record. Null: none (the Fortran path's other programs).
// - The plots' style stores (fig_pstyle_store_t): the Fortran path's (fig_plot_style_hooks, registered at init) and
//   ImPlot's (fig_implot->style). The first present is the one read (names, values); every change goes to each.
// - figure_on_frame_end, figure_on_shutdown: other parts linked only where referenced (the field cache, Markdown) ask
//   to be called at each frame's end and at shutdown.
#ifndef FIGURE_PLOT_BACKEND_H
#define FIGURE_PLOT_BACKEND_H

#include "figure_native.h"

struct ImDrawList;

// A store of the plots' styles: the calls and statuses of fig_plot_style_hooks (figure_native.h).
struct fig_pstyle_store_t {
   fig_pstyle_color_fn  color = nullptr;
   fig_pstyle_var_fn    var = nullptr;
   fig_pstyle_push_fn   push = nullptr;
   fig_pstyle_pop_fn    pop = nullptr;
   fig_pstyle_theme_fn  theme = nullptr;
   fig_pstyle_field_fn  field = nullptr;
   fig_pstyle_editor_fn editor = nullptr;
};

// The scope record's plot kinds the plot side closes (fig_implot_backend_t::close).
enum { FIG_PLOT_KIND_PLOT = 1, FIG_PLOT_KIND_SUBPLOTS, FIG_PLOT_KIND_PLOT3D, FIG_PLOT_KIND_ALIGNED,
       FIG_PLOT_KIND_LEGEND_POPUP };

struct fig_implot_backend_t {
   void (*create)();  // ImPlot's and ImPlot3D's contexts made (after Dear ImGui's)
   void (*destroy)(); // ... destroyed, the plot links reset (before Dear ImGui's)
   fig_pstyle_store_t style; // ImPlot's (lib 1) and ImPlot3D's (lib 2) styles
   // the style's line colours made its colormap (a theme's commit): n 0, ImPlot's Deep
   void (*lines)(const char *cmap_name, const unsigned int *keys, int n);
   // the style colormap's keys for save_style (the first cap): their number, -1 for ImPlot's Deep
   int (*saved_lines)(unsigned int *keys, int cap);
   // the canvas's plot layer: the current plot's draw list (null: no plot), the n points (x, y) [plot units] into
   // pixels, the plot's clip rectangle pushed; then popped
   ImDrawList *(*plot_layer)(int n, const double *x, const double *y, float *px, float *py);
   void (*plot_layer_end)();
   ImDrawList *(*plot_draw_list)(); // the current plot's draw list (fig_texture_sampling)
   // the scope record: what ImPlot and ImPlot3D have open (plot, subplot, 3-D plot), ending what is open now and not
   // in `then`, closing one entry of a plot kind (FIG_PLOT_KIND_*: 1 closed)
   void (*snapshot)(void **open);
   void (*recover)(void *const *then);
   int (*close)(int kind);
};

extern fig_implot_backend_t *fig_implot;

// Referenced by the native parts that need ImPlot's contexts (the colormaps, the fields, the 3-D plots, the plot
// links), so that a program linking one of them links the plot side too.
extern "C" void fig_implot_glue_anchor(void);

void figure_on_frame_end(void (*fn)());
void figure_on_shutdown(void (*fn)());

#endif
