// FIGURE themes: a theme is a small text file (themes/*.toml in the repository, embedded in the library; or a file
// read at run time). The format is a subset of TOML:
//
//    base = "dark"                        dark | light | classic: Dear ImGui's style the theme starts from
//    background = "#14120f"               the window background behind the windows (default: base's)
//    font = "plex-sans"                   the default font: plex-sans (bundled), proggy, or a TTF/OTF file path
//    font_size = 15                       its size [logical pixels]
//    lines = ["#e8664c", "#e9e2d4", ...]  ImPlot's line colours, a qualitative colormap (default: ImPlot's Deep);
//                                         or a named palette: lines = "okabe-ito" (line_palette below)
//    [imgui.colors]   Name = "#rrggbb" | "#rrggbbaa" | ["#rrggbb", alpha]     Dear ImGui colours (ImGuiCol_*)
//    [imgui.vars]     Name = number | [x, y] | true | false                   ImGuiStyle fields
//    [implot.colors], [implot.vars]                                           the same for ImPlot
//
// '#' starts a comment outside strings. Every entry not given comes from `base`, so a newer Dear ImGui adding style
// colours never leaves a theme incomplete. Sizes are in logical pixels: multiplied by the content scale on apply.
#ifndef FIGURE_THEME_H
#define FIGURE_THEME_H

#include <string>
#include <utility>
#include <vector>

namespace figure_theme {

struct color_t {
   float r = 0.0f, g = 0.0f, b = 0.0f, a = 1.0f;
};

struct entry_t {
   std::string         name;
   std::vector<double> values; // vars: 1 or 2 numbers (booleans as 0/1)
   color_t             color;  // colours
   int                 line = 0;
};

struct theme_t {
   std::string          base = "dark";
   bool                 has_background = false;
   color_t              background;
   std::vector<color_t> lines;
   std::string          font;            // empty: keep the font in effect
   double               font_size = 0.0; // 0: keep the size in effect
   std::vector<entry_t> imgui_colors, imgui_vars, implot_colors, implot_vars;
};

// A named line palette ("okabe-ito": Okabe and Ito's colour-blind-safe set, without its black so that it reads on
// dark and light backgrounds); false if the name is unknown.
bool line_palette(const std::string &name, std::vector<color_t> &lines);

// Parse `text`; false with `err` ("line N: ...") on the first error. `where` prefixes the message (a file name).
bool parse(const std::string &text, const std::string &where, theme_t &theme, std::string &err);

// The themes embedded in the library: names and texts (themes/*.toml).
int         builtin_count();
const char *builtin_name(int i);
const char *builtin_text(int i);

} // namespace figure_theme

#endif
