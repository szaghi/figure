// FIGURE's Markdown: the glue of imgui_rich_md (pthom, MIT, vendored in third_party/imgui_rich_md with md4c, its parser;
// see THIRD_PARTY.md and docs/guide/widgets.md, "Markdown").
//
// imgui_rich_md draws only through Dear ImGui (text, its draw lists, child windows, tables, popups) and creates its
// textures as Dear ImGui's ImTextureData, so Markdown looks the same in a window, headless and remote. FIGURE gives it,
// without changing its files but for one include (patch 0001, stb_image):
//   - its fonts: IBM Plex Sans in four styles for the text and the headings, IBM Plex Mono for code spans and blocks
//     (served through the host's ReadAsset under the names the library asks for), then adopted as FIGURE's own fonts:
//     the Lucide icons and the fallbacks (Noto Sans Math, the program's) merged, a finite advance bound;
//   - links: reported, never opened. A click on a link (one to a heading of the same text excepted: it scrolls there)
//     records its URL, and the call that drew it returns it (polled, no callback into Fortran);
//   - images from files only (PNG and JPEG, FIGURE's decoder), never from a URL; no LaTeX, no Mermaid, no
//     transclusion: RenderRaw draws the text as it is;
//   - documents (markdown_view_object): the text kept here by handle, drawn in a scroll area of its own with the
//     library's table of contents and search; a search and a scroll to a heading asked by the program, through the
//     library's internal document state (rich_md_internal.h: no patch).
// Every function is extern "C", returns a FIG_* status and never lets a C++ exception escape (figure_native.h).
#include "figure_native.h"
#include "figure_fonts.h"

#include "imgui.h"
#include "imgui_internal.h"

#include "rich_md.h"
#include "internal/rich_md_internal.h"
#include "internal/rich_md_renderer.h" // UniqueSlug

#include <SDL3/SDL.h>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <map>
#include <memory>
#include <optional>
#include <string>
#include <unordered_map>
#include <vector>

namespace {

int fail(int status, const std::string &msg) {
   fig_set_last_error(msg.c_str(), static_cast<int>(msg.size()));
   return status;
}

#define MD_TRY try {
#define MD_CATCH                                                                                                       \
   }                                                                                                                   \
   catch (const std::exception &e) {                                                                                   \
      return fail(FIG_ERR_EXCEPTION, std::string("markdown: C++ exception: ") + e.what());                             \
   }                                                                                                                   \
   catch (...) {                                                                                                       \
      return fail(FIG_ERR_EXCEPTION, "markdown: unknown C++ exception");                                               \
   }

std::string str(const char *p, long long n) { return n > 0 && p ? std::string(p, static_cast<size_t>(n)) : std::string(); }

// Copy s into buf (up to n bytes); its length.
long long give(const std::string &s, char *buf, long long n) {
   if (buf && n > 0) std::memcpy(buf, s.data(), static_cast<size_t>(std::min<long long>(n, static_cast<long long>(s.size()))));
   return static_cast<long long>(s.size());
}

constexpr float TEXT_SIZE = 15.0f; // logical pixels: FIGURE's text size (figure_native.cpp's DEFAULT_FONT_SIZE)
// The font files imgui_rich_md asks for (fontBasePath + "-Regular.ttf", ...; its code font by a fixed name) and the
// bundled fonts FIGURE serves for them
const char *const BASE = "figure/IBMPlexSans";
const char *const CODE_ASSET = "fonts/Inconsolata-Medium.ttf";
struct font_asset {
   const char *asset;
   const char *font;
};
const font_asset FONT_ASSETS[] = {
   {"figure/IBMPlexSans-Regular.ttf", "plex-sans"},
   {"figure/IBMPlexSans-Bold.ttf", "plex-sans-bold"},
   {"figure/IBMPlexSans-RegularItalic.ttf", "plex-sans-italic"},
   {"figure/IBMPlexSans-BoldItalic.ttf", "plex-sans-bold-italic"},
   {CODE_ASSET, "plex-mono"},
};

RichMd::Context *context = nullptr; // created at the first Markdown drawn, destroyed by fig_markdown_shutdown
ImFont *fortran_fonts[5] = {};       // the Fortran path's Markdown fonts (fig_markdown_fonts), forgotten at shutdown
int fortran_generation = 1;          // ... their application: a new one after each shutdown (fig_markdown_generation)
bool link_clicked = false;           // a link was clicked in the call being drawn
std::string link;                    // its URL (kept until the next click)
std::string swallow;                 // the anchor a view scrolls to by the program's request: not a link clicked

// A file read with SDL (UTF-8 names on every platform); nullopt if it cannot be read.
RichMd::AssetBytes read_file(const std::string &path) {
   size_t n = 0;
   void *data = SDL_LoadFile(path.c_str(), &n);
   if (!data) return std::nullopt;
   std::vector<uint8_t> bytes(static_cast<const uint8_t *>(data), static_cast<const uint8_t *>(data) + n);
   SDL_free(data);
   return bytes;
}

// The host's ReadAsset: the bundled fonts under the names the library asks for; any other path is a file (an image of
// the text, relative to the working directory). The library's own assets (its broken-image picture) are not bundled.
RichMd::AssetBytes read_asset(const std::string &path) {
   for (const font_asset &f : FONT_ASSETS)
      if (path == f.asset) {
         const unsigned char *data = nullptr;
         int size = 0;
         if (!figure_fonts::bytes(f.font, data, size)) return std::nullopt;
         return std::vector<uint8_t>(data, data + size);
      }
   if (path.rfind("images/markdown_broken_image", 0) == 0) return std::nullopt;
   return read_file(path);
}

// A link clicked: kept for the call that draws it. The anchor of a scroll the program asked is not a click.
void on_link(const std::string &url) {
   if (!swallow.empty() && url == "#" + swallow) return;
   link = url;
   link_clicked = true;
}

// Images from files only: a URL (any scheme://) draws nothing, without the library's message about downloads.
std::optional<RichMd::MarkdownImage> on_image(const std::string &path) {
   if (path.find("://") != std::string::npos) return std::nullopt;
   return RichMd::OnImage_Default(path);
}

// The context, created at the first use (after Dear ImGui's), its fonts loaded and adopted at once (before a glyph is
// drawn). A FIG_* status (the error recorded).
int ensure() {
   if (context) {
      RichMd::SetCurrentContext(context);
      return FIG_OK;
   }
   RichMd::HostServices host;
   host.ReadAsset = read_asset;
   host.Log = [](const std::string &message) { std::fprintf(stderr, "figure: markdown: %s\n", message.c_str()); };
   RichMd::SetHostServices(host);
   RichMd::MarkdownOptions options;
   options.fontOptions.fontBasePath = BASE;
   options.fontOptions.regularSize = TEXT_SIZE;
   options.callbacks.OnOpenLink = on_link;
   options.callbacks.OnImage = on_image;
   options.withLatex = false;
   context = RichMd::CreateContext(options);
   RichMd::SetCurrentContext(context);
   // the fonts load with the renderer, made by the first query of a font
   const RichMd::SizedFont code = RichMd::GetCodeFont();
   struct adopted {
      ImFont *font;
      const char *key;
      const char *label;
   };
   const adopted fonts[] = {
      {RichMd::GetFont(RichMd::MarkdownFontSpec(false, false)).font, "<markdown>", "IBM Plex Sans (Markdown)"},
      {RichMd::GetFont(RichMd::MarkdownFontSpec(false, true)).font, "<markdown bold>", "IBM Plex Sans Bold"},
      {RichMd::GetFont(RichMd::MarkdownFontSpec(true, false)).font, "<markdown italic>", "IBM Plex Sans Italic"},
      {RichMd::GetFont(RichMd::MarkdownFontSpec(true, true)).font, "<markdown bold italic>", "IBM Plex Sans Bold Italic"},
      {code.font, "<markdown code>", "IBM Plex Mono (Markdown)"},
   };
   std::string err;
   for (const adopted &a : fonts)
      if (!figure_fonts::adopt(a.font, a.key, a.label, err)) return fail(FIG_ERR_FAILED, "markdown: " + err);
   return FIG_OK;
}

// A draw is possible: a frame open, the context made.
int ready(const char *what) {
   if (!ImGui::GetCurrentContext()) return fail(FIG_ERR_STATE, "figure is not initialized");
   if (!ImGui::GetCurrentContext()->WithinFrameScope)
      return fail(FIG_ERR_STATE, std::string(what) + ": no frame open");
   return ensure();
}

// ---- documents ------------------------------------------------------------------------------------------------------

struct view_t {
   std::string text;
   RichMd::DocumentOptions options;
   bool find_due = false;
   std::string query;
   bool scroll_due = false;
   std::string slug;
   int matches = 0, current = -1;
};

std::map<int, std::unique_ptr<view_t>> views;
int next_view = 1;

view_t *find(int handle) {
   const auto v = views.find(handle);
   return v == views.end() ? nullptr : v->second.get();
}

#define MD_FIND(what)                                                                                                  \
   view_t *v = find(handle);                                                                                           \
   if (!v) return fail(FIG_ERR_STATE, std::string("markdown_view_object%") + (what) + ": the view is not initialized");

} // namespace

extern "C" {

void fig_markdown_shutdown(void) {
   try {
      if (context) RichMd::DestroyContext(context);
   } catch (...) {
   }
   context = nullptr;
   link.clear();
   link_clicked = false;
   for (ImFont *&f : fortran_fonts) f = nullptr; // the atlas goes with Dear ImGui's context
   ++fortran_generation;
}

int fig_markdown(const char *text, long long len, int *clicked) {
   MD_TRY
   *clicked = 0;
   const int s = ready("ig_markdown");
   if (s != FIG_OK) return s;
   link_clicked = false;
   RichMd::RenderRaw(str(text, len));
   *clicked = link_clicked ? 1 : 0;
   link_clicked = false;
   return FIG_OK;
   MD_CATCH
}

long long fig_markdown_link(char *buf, long long n) { return give(link, buf, n); }

int fig_markdown_view_create(int *handle, int toc, int search) {
   MD_TRY
   auto v = std::make_unique<view_t>();
   v->options.toc = toc != 0;
   v->options.search = search != 0;
   *handle = next_view++;
   views[*handle] = std::move(v);
   return FIG_OK;
   MD_CATCH
}

void fig_markdown_view_destroy(int handle) {
   try {
      views.erase(handle);
   } catch (...) {
   }
}

int fig_markdown_view_set_text(int handle, const char *text, long long len) {
   MD_TRY
   MD_FIND("set_text")
   v->text = str(text, len);
   return FIG_OK;
   MD_CATCH
}

int fig_markdown_view_load(int handle, const char *path, int len) {
   MD_TRY
   MD_FIND("load")
   const std::string p = str(path, len);
   if (p.empty()) return fail(FIG_ERR_ARGUMENT, "markdown_view_object%load: no file name");
   size_t n = 0;
   void *data = SDL_LoadFile(p.c_str(), &n);
   if (!data) return fail(FIG_ERR_FAILED, "markdown_view_object%load: '" + p + "' cannot be read: " + SDL_GetError());
   v->text.assign(static_cast<const char *>(data), n);
   SDL_free(data);
   return FIG_OK;
   MD_CATCH
}

long long fig_markdown_view_text(int handle, char *buf, long long n) {
   try {
      const view_t *v = find(handle);
      return v ? give(v->text, buf, n) : 0;
   } catch (...) {
      return 0;
   }
}

int fig_markdown_view_find(int handle, const char *text, int len) {
   MD_TRY
   MD_FIND("find")
   const std::string q = str(text, len);
   if (q.size() >= sizeof(RichMd::DocumentState{}.query))
      return fail(FIG_ERR_ARGUMENT, "markdown_view_object%find: the text is longer than 255 bytes");
   if (q.find('\n') != std::string::npos)
      return fail(FIG_ERR_ARGUMENT, "markdown_view_object%find: the text is more than one line");
   v->query = q;
   v->find_due = true;
   return FIG_OK;
   MD_CATCH
}

int fig_markdown_view_scroll_to(int handle, const char *heading, int len) {
   MD_TRY
   MD_FIND("scroll_to")
   std::string h = str(heading, len);
   if (h.empty()) return fail(FIG_ERR_ARGUMENT, "markdown_view_object%scroll_to: the heading is empty");
   if (h[0] == '#') {
      h.erase(0, 1);
   } else { // a heading's text: its slug, as the library makes it (GitHub's)
      std::unordered_map<std::string, int> none;
      h = RichMd::UniqueSlug(h, none);
   }
   v->slug = h;
   v->scroll_due = true;
   return FIG_OK;
   MD_CATCH
}

int fig_markdown_view_info(int handle, int *matches, int *current) {
   MD_TRY
   MD_FIND("matches")
   *matches = v->matches;
   *current = v->current;
   return FIG_OK;
   MD_CATCH
}

int fig_markdown_view_draw(int handle, const char *id, int id_len, double width, double height, int *clicked) {
   MD_TRY
   *clicked = 0;
   MD_FIND("draw")
   const std::string label = str(id, id_len);
   if (label.empty()) return fail(FIG_ERR_ARGUMENT, "markdown_view_object%draw: the id is empty");
   const int s = ready("markdown_view_object%draw");
   if (s != FIG_OK) return s;
   const ImGuiID doc = ImGui::GetID(label.c_str()); // the document's id, as BeginDocument makes it
   {
      RichMd::DocumentState &state = context->documents[doc];
      if (v->find_due) {
         ImStrncpy(state.query, v->query.c_str(), sizeof(state.query));
         state.searchOpen = !v->query.empty();
         state.focusQuery = state.selectQuery = false;
         state.jumpToFirst = true;
         state.currentFragmentIndex = -1;
         v->find_due = false;
      }
      if (v->scroll_due) {
         state.scroll = RichMd::DocumentScroll();
         state.scroll.anchor.slug = v->slug;
         state.scroll.frames = 8;
         swallow = v->slug;
         v->scroll_due = false;
      }
   }
   link_clicked = false;
   RichMd::BeginDocument(label.c_str(), ImVec2(static_cast<float>(width), static_cast<float>(height)), v->options);
   RichMd::RenderRaw(v->text);
   RichMd::EndDocument();
   const RichMd::DocumentState &state = context->documents[doc];
   if (state.scroll.anchor.slug.empty()) swallow.clear(); // reached, or no heading has it
   v->matches = state.searchOpen ? state.matchCount : 0;
   v->current = state.searchOpen ? state.currentMatch : -1;
   *clicked = link_clicked ? 1 : 0;
   link_clicked = false;
   return FIG_OK;
   MD_CATCH
}

// ---- the Fortran path (szaghi/figure#15 P15) ------------------------------------------------------------------------
// The Fortran Markdown renderer (src/paths/fortran/markdown/) draws through figure_core; what figure_core_layout's
// implementation over Dear ImGui (src/paths/imgui/core/figure_core_layout.F90) reads and writes of Dear ImGui's internals,
// that no C API function gives, is here (implementation A of the core seam: it goes with Dear ImGui in P27). The
// renderer's fonts are loaded as imgui_rich_md loads its own (the same files, sizes and configuration, then adopted as
// FIGURE's fonts under the same keys), without its context.

// The Markdown fonts of the Fortran renderer: regular, bold, italic, bold italic (IBM Plex Sans, loaded at 16 pixels as
// imgui_rich_md's FontCollection does) and the code font (IBM Plex Mono at the text size), made at the first call of an
// application. When imgui_rich_md has drawn already in this application (both paths' renderers in one program: the
// side-by-side tests), its fonts are taken: a second copy of the same fonts, loaded later into the atlas, draws a few
// glyphs' edge pixels otherwise (measured: up to 37 levels on 1 to 13 pixels of a 640 x 400 picture). A FIG_* status
// (the error recorded).
int fig_markdown_fonts(ImFont **fonts) {
   MD_TRY
   if (!ImGui::GetCurrentContext()) return fail(FIG_ERR_STATE, "figure is not initialized");
   if (!fortran_fonts[0] && context) { // the current path's Markdown drawn already: its fonts, not a second copy
      RichMd::SetCurrentContext(context);
      fortran_fonts[0] = RichMd::GetFont(RichMd::MarkdownFontSpec(false, false)).font;
      fortran_fonts[1] = RichMd::GetFont(RichMd::MarkdownFontSpec(false, true)).font;
      fortran_fonts[2] = RichMd::GetFont(RichMd::MarkdownFontSpec(true, false)).font;
      fortran_fonts[3] = RichMd::GetFont(RichMd::MarkdownFontSpec(true, true)).font;
      fortran_fonts[4] = RichMd::GetCodeFont().font;
   }
   if (!fortran_fonts[0]) {
      struct spec {
         const char *stem;  // the file's stem imgui_rich_md names the font after
         const char *font;  // FIGURE's bundled font
         float size;        // the size it is loaded at
         const char *key;   // FIGURE's key
         const char *label; // and name
      };
      const spec specs[] = {
         {"IBMPlexSans-Regular", "plex-sans", 16.0f, "<markdown>", "IBM Plex Sans (Markdown)"},
         {"IBMPlexSans-Bold", "plex-sans-bold", 16.0f, "<markdown bold>", "IBM Plex Sans Bold"},
         {"IBMPlexSans-RegularItalic", "plex-sans-italic", 16.0f, "<markdown italic>", "IBM Plex Sans Italic"},
         {"IBMPlexSans-BoldItalic", "plex-sans-bold-italic", 16.0f, "<markdown bold italic>", "IBM Plex Sans Bold Italic"},
         {"Inconsolata-Medium", "plex-mono", TEXT_SIZE, "<markdown code>", "IBM Plex Mono (Markdown)"},
      };
      ImFont *made[5] = {};
      for (int k = 0; k < 5; ++k) {
         const unsigned char *data = nullptr;
         int size = 0;
         if (!figure_fonts::bytes(specs[k].font, data, size))
            return fail(FIG_ERR_FAILED, std::string("markdown: no font ") + specs[k].font);
         ImFontConfig cfg;
         cfg.MergeMode = false;
         cfg.FontDataOwnedByAtlas = true;
         std::snprintf(cfg.Name, sizeof(cfg.Name), "%s %d", specs[k].stem, static_cast<int>(std::lround(specs[k].size)));
         void *copy = IM_ALLOC(static_cast<size_t>(size));
         std::memcpy(copy, data, static_cast<size_t>(size));
         made[k] = ImGui::GetIO().Fonts->AddFontFromMemoryTTF(copy, size, specs[k].size, &cfg);
         std::string err;
         if (!figure_fonts::adopt(made[k], specs[k].key, specs[k].label, err)) return fail(FIG_ERR_FAILED, "markdown: " + err);
      }
      for (int k = 0; k < 5; ++k) fortran_fonts[k] = made[k];
   }
   for (int k = 0; k < 5; ++k) fonts[k] = fortran_fonts[k];
   return FIG_OK;
   MD_CATCH
}

// The application the Fortran renderer's caches belong to (its fonts, its images' textures): another after each
// shutdown.
int fig_markdown_generation(void) { return fortran_generation; }

// The scale of a size pushed with PushFont(NULL, size), relative to the frame's base size (imgui_rich_md's _FontScale).
float fig_core_font_scale(void) {
   ImGuiContext *g = ImGui::GetCurrentContext();
   if (g == nullptr || g->FontStack.Size == 0 || g->FontStack[0].FontSizeBeforeScaling <= 0.f) return 1.f;
   return g->FontSizeBase / g->FontStack[0].FontSizeBeforeScaling;
}

// Whether the current window's line is open (an item ended with SameLine: DC.IsSameLine).
int fig_core_line_open(void) {
   const ImGuiWindow *w = ImGui::GetCurrentContext() ? ImGui::GetCurrentWindowRead() : nullptr;
   return w != nullptr && w->DC.IsSameLine ? 1 : 0;
}

// The current window's state: position (0, 1), scroll (2, 3), largest scroll (4, 5), the decorations above its content
// (6: DecoOuterSizeY1, 7: DecoInnerSizeY1), its work rectangle's right edge (8), size (9, 10), a vertical scrollbar (11:
// 0 or 1), its content's start in local coordinates (12, 13: DC.CursorStartPos - Pos).
void fig_core_window_state(float *s) {
   const ImGuiWindow *w = ImGui::GetCurrentWindowRead();
   s[0] = w->Pos.x, s[1] = w->Pos.y, s[2] = w->Scroll.x, s[3] = w->Scroll.y, s[4] = w->ScrollMax.x, s[5] = w->ScrollMax.y;
   s[6] = w->DecoOuterSizeY1, s[7] = w->DecoInnerSizeY1, s[8] = w->WorkRect.Max.x, s[9] = w->Size.x, s[10] = w->Size.y;
   s[11] = w->ScrollbarY ? 1.f : 0.f;
   s[12] = w->DC.CursorStartPos.x - w->Pos.x, s[13] = w->DC.CursorStartPos.y - w->Pos.y;
}

// The input state the renderer reads that no C API function gives: the position of the last left click (f[0:2]),
// the wheel (f[2]), the mouse's move in x (f[3]); macOS behaviours (i[0]), a text field wants the keys (i[1]), a touch
// screen (i[2]), shift held (i[3]), the characters typed this frame (i[4]) and a slash among them (i[5]).
void fig_core_io_state(float *f, int *i) {
   const ImGuiIO &io = ImGui::GetIO();
   f[0] = io.MouseClickedPos[0].x, f[1] = io.MouseClickedPos[0].y, f[2] = io.MouseWheel, f[3] = io.MouseDelta.x;
   i[0] = io.ConfigMacOSXBehaviors ? 1 : 0;
   i[1] = io.WantTextInput ? 1 : 0;
   i[2] = (io.ConfigFlags & ImGuiConfigFlags_IsTouchScreen) != 0 ? 1 : 0;
   i[3] = io.KeyShift ? 1 : 0;
   i[4] = io.InputQueueCharacters.Size;
   i[5] = 0;
   for (ImWchar c : io.InputQueueCharacters)
      if (c == '/') i[5] = 1;
}

// The vertices of the current window's draw list, and those from `start` moved right by dx (an aligned table cell).
int fig_core_vtx_count(void) { return ImGui::GetWindowDrawList()->VtxBuffer.Size; }
void fig_core_vtx_shift(int start, float dx) {
   ImDrawList *dl = ImGui::GetWindowDrawList();
   for (int i = start; i < dl->VtxBuffer.Size; ++i) dl->VtxBuffer[i].pos.x += dx;
}

// SetTooltip("%s", text), the text of n bytes.
void fig_core_tooltip(const char *text, int n) { ImGui::SetTooltip("%.*s", n, text); }

// The style values the renderer reads: FramePadding (0, 1), IndentSpacing (2), ItemSpacing (3, 4), WindowPadding (5, 6),
// ItemInnerSpacing (7, 8), ScrollbarSize (9), FontScaleMain (10), FontScaleDpi (11).
void fig_core_style(float *s) {
   const ImGuiStyle &st = ImGui::GetStyle();
   s[0] = st.FramePadding.x, s[1] = st.FramePadding.y, s[2] = st.IndentSpacing, s[3] = st.ItemSpacing.x;
   s[4] = st.ItemSpacing.y, s[5] = st.WindowPadding.x, s[6] = st.WindowPadding.y, s[7] = st.ItemInnerSpacing.x;
   s[8] = st.ItemInnerSpacing.y, s[9] = st.ScrollbarSize, s[10] = st.FontScaleMain, s[11] = st.FontScaleDpi;
}

// The current window's vertical scrollbar (x0, y0, x1, y1).
void fig_core_scrollbar_rect(float *r) {
   ImGuiWindow *w = ImGui::GetCurrentWindow();
   const ImRect bar = ImGui::GetWindowScrollbarRect(w, ImGuiAxis_Y);
   r[0] = bar.Min.x, r[1] = bar.Min.y, r[2] = bar.Max.x, r[3] = bar.Max.y;
}

// imgui_rich_md's find field (rich_md.cpp's _DrawFindBar): InputTextWithHint with its callback, which steps with the
// arrows (step -1 up, 1 down; the down arrow opens the list) and selects the text at its first call while select_query.
int fig_core_find_field(const char *label, const char *hint, char *buf, int size, int *step, int *dropdown,
                        int *select_query) {
   struct state_t {
      int *step, *dropdown, *select_query;
   } state{step, dropdown, select_query};
   auto callback = [](ImGuiInputTextCallbackData *data) {
      state_t &s = *static_cast<state_t *>(data->UserData);
      if (data->EventFlag == ImGuiInputTextFlags_CallbackHistory) {
         *s.step = (data->EventKey == ImGuiKey_UpArrow) ? -1 : 1;
         if (data->EventKey == ImGuiKey_DownArrow) *s.dropdown = 1;
      } else if (*s.select_query) {
         data->SelectAll();
         *s.select_query = 0;
      }
      return 0;
   };
   const ImGuiInputTextFlags flags = ImGuiInputTextFlags_CallbackHistory | ImGuiInputTextFlags_CallbackAlways;
   return ImGui::InputTextWithHint(label, hint, buf, static_cast<size_t>(size), flags, callback, &state) ? 1 : 0;
}

} // extern "C"
