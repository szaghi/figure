// FIGURE's bundled fonts, for the other native files (defined in figure_native.cpp, which embeds them).
#ifndef FIGURE_FONTS_H
#define FIGURE_FONTS_H

#include <string>

struct ImFont;

namespace figure_fonts {

// The bytes of a bundled font: "plex-sans", "plex-sans-bold", "plex-sans-italic", "plex-sans-bold-italic",
// "plex-mono". False for another name.
bool bytes(const std::string &name, const unsigned char *&data, int &size);
// Treat a font another library added to the atlas (imgui_rich_md's) as FIGURE's own, before any of its glyphs is drawn:
// a finite advance bound on its sources, `label` as its name (null: kept), the Lucide icons and the fallbacks merged
// (Noto Sans Math, the program's, those added later too), its em known; kept as `key` (a name no font file has). False
// with err.
bool adopt(ImFont *f, const std::string &key, const char *label, std::string &err);

} // namespace figure_fonts

#endif
