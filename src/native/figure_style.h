// FIGURE style fields by name: the tables are generated from the cimgui/cimplot metadata into
// figure_style_generated.cpp (scripts/gen_bindings.py), so every field of the bound Dear ImGui and ImPlot is listed.
#ifndef FIGURE_STYLE_H
#define FIGURE_STYLE_H

#include <cstddef>

namespace figure_style {

enum kind { FIG_STYLE_FLOAT = 1, FIG_STYLE_VEC2 = 2, FIG_STYLE_BOOL = 3, FIG_STYLE_INT = 4 };

struct field {
   const char *name;   // the field's name, as in imgui.h / implot.h
   std::size_t offset; // offsetof(ImGuiStyle or ImPlotStyle, name)
   int         kind;   // FIG_STYLE_*
};

extern const field IMGUI_FIELDS[];
extern const int   IMGUI_FIELDS_COUNT;
extern const field IMPLOT_FIELDS[];
extern const int   IMPLOT_FIELDS_COUNT;

} // namespace figure_style

#endif
