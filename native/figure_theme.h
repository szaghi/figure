// FIGURE themes: a theme is a small text file (themes/*.toml in the repository, embedded in the library; or a file
// read at run time). The format is a subset of TOML:
//
//    base = "dark"                        dark | light | classic: Dear ImGui's style the theme starts from
//    background = "#14120f"               the window background behind the windows (default: base's)
//    font = "plex-sans"                   the default font: plex-sans, plex-mono (bundled), proggy, or a TTF/OTF file
//    font_size = 15                       its size [logical pixels]
//    lines = ["#e8664c", "#e9e2d4", ...]  ImPlot's line colours, a qualitative colormap (default: ImPlot's Deep);
//                                         or a named palette: lines = "okabe-ito" (line_palette below)
//    [imgui.colors]   Name = "#rrggbb" | "#rrggbbaa" | ["#rrggbb", alpha]     Dear ImGui colours (ImGuiCol_*)
//    [imgui.vars]     Name = number | [x, y] | true | false                   ImGuiStyle fields
//    [implot.colors], [implot.vars]                                           the same for ImPlot
//    look = "fusion"                      a bundled look (themes/looks): its geometry, before [imgui.vars]
//    palette = "nord"                     a bundled palette (themes/palettes), or "auto" (the system's light or dark)
//    auto_dark = "seal", auto_light = "seal-light"     the palettes "auto" chooses between
//    [palette]        role = "#rrggbb"                                        the twelve roles (ROLE_NAMES), opaque
//
// A colour is "#rrggbb", "#rrggbbaa", ["#rrggbb", alpha] or [r, g, b, a] (four numbers in [0, 1]).
// With a palette (a name, or a [palette] table, which then overrides single roles of the named one) every Dear ImGui
// colour is derived from the roles (figure_native.cpp, derive_colors) and `base` gives none; [imgui.colors] still
// override. A look file holds [imgui.vars] and [implot.vars] only; a palette file a complete [palette] table and,
// optionally, background, lines, [imgui.colors] and [implot.colors].
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

// The palette roles, in the order of ROLE_NAMES.
enum role_t {
   ROLE_BACKGROUND, ROLE_SURFACE, ROLE_RAISED_SURFACE, ROLE_BORDER, ROLE_TEXT, ROLE_DIMMED_TEXT, ROLE_ACCENT,
   ROLE_TEXT_ON_ACCENT, ROLE_SELECTION, ROLE_SUCCESS, ROLE_WARNING, ROLE_ERROR, ROLE_COUNT
};
extern const char *const ROLE_NAMES[ROLE_COUNT];
int role_index(const std::string &name); // -1 if unknown

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
   std::string          look;                    // a bundled look; empty: Dear ImGui's geometry
   std::string          palette;                 // a bundled palette or "auto"; empty: none (unless a [palette] table)
   std::string          auto_dark, auto_light;   // empty: not given
   bool                 has_palette_table = false;
   bool                 role_given[ROLE_COUNT] = {};
   color_t              roles[ROLE_COUNT];
   std::vector<std::string> keys;                // the top-level keys and the sections given (file validation)
   bool has(const std::string &key) const;
   bool has_palette() const { return !palette.empty() || has_palette_table; }
};

// WCAG 2 relative luminance and contrast ratio (1 to 21) of opaque colours.
double luminance(const color_t &c);
double contrast(const color_t &a, const color_t &b);

// The contrast rule of palettes: text on background, surface, raised surface and selection >= 4.5:1, dimmed text on
// background >= 3:1, text on accent >= 4.5:1. False with `err` naming the first failing pair and its ratio.
bool check_contrast(const color_t roles[ROLE_COUNT], std::string &err);

// A named line palette ("okabe-ito": Okabe and Ito's colour-blind-safe set, without its black so that it reads on
// dark and light backgrounds); false if the name is unknown.
bool line_palette(const std::string &name, std::vector<color_t> &lines);

// Parse `text`; false with `err` ("line N: ...") on the first error. `where` prefixes the message (a file name).
bool parse(const std::string &text, const std::string &where, theme_t &theme, std::string &err);

// The themes embedded in the library: names and texts (themes/*.toml).
int         builtin_count();
const char *builtin_name(int i);
const char *builtin_text(int i);

// The bundled looks (themes/looks/*.toml) and palettes (themes/palettes/*.toml): the text by name (null if unknown),
// and the names joined by ", " (for messages).
const char *look_text(const std::string &name);
const char *palette_text(const std::string &name);
std::string look_names();
std::string palette_names();
int         palette_count();
const char *palette_name(int i);

} // namespace figure_theme

#endif
