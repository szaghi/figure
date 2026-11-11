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
#include <cfenv>
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

// Floating-point traps held while a Markdown text is drawn, restored after (with the flags as they were): Dear ImGui
// divides 0 by 0 in the first frame of a table sized in proportion to its content (ImGuiTableFlags_SizingStretchProp,
// imgui_rich_md's tables: TableUpdateLayout, the columns' widths still unknown), a NaN weight it computes again in the
// next frame. A program built with -ffpe-trap=invalid (gfortran) would stop there.
struct traps_held {
   std::fenv_t env;
   traps_held() { std::feholdexcept(&env); }
   ~traps_held() { std::fesetenv(&env); }
   traps_held(const traps_held &) = delete;
   traps_held &operator=(const traps_held &) = delete;
};

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
}

int fig_markdown(const char *text, long long len, int *clicked) {
   MD_TRY
   *clicked = 0;
   const int s = ready("ig_markdown");
   if (s != FIG_OK) return s;
   link_clicked = false;
   const traps_held held;
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
   const traps_held held;
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

} // extern "C"
