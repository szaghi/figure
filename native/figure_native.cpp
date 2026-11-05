// FIGURE native glue: SDL3 window + OpenGL3 renderer + Dear ImGui/ImPlot contexts, behind the C ABI of figure_native.h.
#include "figure_native.h"
#include "figure_remote.h"
#include "figure_style.h"
#include "figure_theme.h"

#include "imgui.h"
#include "imgui_internal.h" // DockBuilder*: Dear ImGui keeps the dock builder internal
#include "imgui_impl_opengl3.h"
#include "imgui_impl_sdl3.h"
#include "implot.h"
#include "implot_internal.h" // GetStyleColorVec4: ImPlot's automatic colours resolved

#include <SDL3/SDL.h>
// The program's main is the Fortran one, not SDL_main: SDL_MAIN_HANDLED keeps SDL_main.h from redefining main, and
// fig_init declares the entry point ready (SDL_SetMainReady) before SDL_Init, as SDL documents for this case.
#define SDL_MAIN_HANDLED
#include <SDL3/SDL_main.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <chrono>
#include <algorithm>
#include <cmath>
#include <exception>
#include <map>
#include <string>
#include <vector>

namespace {

std::string last_error;

int fail(int status, const std::string &msg) {
   last_error = msg;
   return status;
}

#define FIG_TRY try {
#define FIG_CATCH                                                                                                      \
   }                                                                                                                   \
   catch (const std::exception &e) {                                                                                  \
      return fail(FIG_ERR_EXCEPTION, std::string("C++ exception: ") + e.what());                                      \
   }                                                                                                                   \
   catch (...) {                                                                                                       \
      return fail(FIG_ERR_EXCEPTION, "unknown C++ exception");                                                        \
   }

enum class mode { none, window, headless, remote };

struct state_t {
   mode          m = mode::none;
   SDL_Window   *window = nullptr;
   SDL_GLContext gl = nullptr;
   bool          in_frame = false;
   bool          lazy = true;     // wait for events instead of redrawing continuously
   int           max_wait_ms = 500;
   int           frames_left = 3; // frames still to draw after the last event (ImGui settles in a few)
   float         scale = 1.0f;
   float         clear[3] = {0.10f, 0.10f, 0.11f}; // the window's background, behind the ImGui windows (the style's)
   std::string   style_base = "dark";              // base of the style in effect (what save_style writes against)
   std::string   font = "plex-sans";               // the default font: plex-sans (bundled), proggy, or a TTF file
   std::map<std::string, ImFont *> fonts;          // fonts loaded in this context, by name or path
   std::map<std::string, std::vector<unsigned char>> font_data; // TTF files read at run time (the atlas needs them)
   struct saved_t {                                // a style value changed by a push, and what it was
      unsigned char             *where = nullptr;
      std::vector<unsigned char> was;
   };
   std::vector<saved_t> pushed_colors, pushed_vars; // scoped changes, undone by the pops (newest last)
   struct input_t {                                // synthetic input (figure_testing), applied at the next frames
      int         kind = 0;                        // 0 step (a frame boundary), 1 pos, 2 button, 3 wheel, 4 key, 5 text
      float       x = 0.0f, y = 0.0f;
      int         a = 0, b = 0;
      std::string text;
   };
   std::vector<input_t> test_input;                // queued, oldest first
   std::string   ini_file;        // where Dear ImGui keeps window positions and sizes; empty: nowhere (the default)
   struct texture_t {
      int  width = 0, height = 0;
      bool smooth = false;
   };
   std::chrono::steady_clock::time_point last_frame; // remote mode: the frame clock (no SDL)
   double        remote_min_dt = 1.0 / 60.0;           // remote mode: shortest time between frames [s] (0: no cap)
   std::map<unsigned long long, texture_t> textures; // user textures by ImTextureID (the GL name in window mode)
   unsigned long long next_headless_texture = 1;     // headless mode: ids without GL objects
} st;

// Redraw diagnostics, enabled by the environment variable FIGURE_DEBUG_REDRAW (any value): once per second, print to
// stderr the frames drawn, the wakeups by timeout, the events by SDL type, and the time spent waiting, building the
// UI (application code between begin and end), rendering and swapping. Costs nothing when disabled.
struct redraw_stats_t {
   bool                 on = false;
   Uint64               t0 = 0;       // start of the current 1 s window [ns]
   Uint64               t_mark = 0;   // last phase boundary [ns]
   Uint64               wait = 0;     // in SDL_WaitEventTimeout/SDL_PollEvent [ns]
   Uint64               build = 0;    // begin_frame to after ImGui::Render: application + ImGui calls [ns]
   Uint64               render = 0;   // GL draw of the ImGui draw data [ns]
   Uint64               swap = 0;     // SDL_GL_SwapWindow [ns]
   int                  frames = 0;   // frames drawn
   int                  timeouts = 0; // waits that ended without an event
   std::map<Uint32, int> events;      // events by SDL_EventType
} rs;

// Frame capture, enabled by the environment variable FIGURE_CAPTURE=<prefix> (window mode only): every frame drawn is
// read back and written to <prefix>NNNNN.ppm, for documentation screenshots and animations. Capture is hermetic: the
// real mouse and keyboard are ignored (the program scripts its own input with fig_input_mouse), the content scale is
// 1, lazy redraw is off and the frame clock is fixed (FIGURE_CAPTURE_FPS, default 30), so the frames depend only on
// the program. FIGURE_CAPTURE_FROM=N skips the first N frames (default 0); FIGURE_CAPTURE_FRAMES=N ends the program
// (next_frame returns false) after N frames written. FIGURE_CAPTURE_INPUT=<file> replays scripted input, one event per
// line ("#" starts a comment), at the frame given first (frames counted from 0, skipped ones included):
//    <frame> move <x> <y> [<n>]          the pointer glides to (x, y) [pixels] over n frames (default 1)
//    <frame> down|up [left|right|middle] a button is pressed or released (default left)
//    <frame> wheel <dx> <dy>             the wheel turns (positive dy: away from the user)
//    <frame> text <characters>           characters are typed (the rest of the line)
//    <frame> key <name> [down|up]        a key: enter, tab, backspace, escape, left, right, up, down, ctrl (press and
//                                        release when down|up is omitted)
// With an input script Dear ImGui draws its own mouse cursor, so the pointer shows in the frames.
struct capture_event_t {
   long        frame = 0;
   std::string what;
   float       x = 0.0f, y = 0.0f;
   int         n = 1;
   std::string arg;
};

struct capture_t {
   bool        on = false;
   std::string prefix;
   float       dt = 1.0f / 30.0f; // fixed frame time [s]
   long        from = 0;          // frames skipped before writing
   long        count = -1;        // frames to write; negative: unlimited
   long        frame = 0;         // frames drawn
   long        written = 0;       // frames written
   std::vector<capture_event_t> events; // scripted input, by frame
   size_t      next = 0;          // first event not yet applied
   float       px = 0.0f, py = 0.0f;           // pointer position
   float       gx = 0.0f, gy = 0.0f;           // glide target
   int         glide = 0;                      // glide frames left
} cap;

ImGuiKey capture_key(const std::string &name) {
   if (name == "enter") return ImGuiKey_Enter;
   if (name == "tab") return ImGuiKey_Tab;
   if (name == "backspace") return ImGuiKey_Backspace;
   if (name == "escape") return ImGuiKey_Escape;
   if (name == "left") return ImGuiKey_LeftArrow;
   if (name == "right") return ImGuiKey_RightArrow;
   if (name == "up") return ImGuiKey_UpArrow;
   if (name == "down") return ImGuiKey_DownArrow;
   if (name == "ctrl") return ImGuiMod_Ctrl;
   return ImGuiKey_None;
}

int capture_button(const std::string &name) {
   if (name == "right") return ImGuiMouseButton_Right;
   if (name == "middle") return ImGuiMouseButton_Middle;
   return ImGuiMouseButton_Left;
}

// Read the input script; a malformed line is reported and skipped.
void capture_read_input(const char *path) {
   FILE *f = std::fopen(path, "r");
   if (!f) {
      std::fprintf(stderr, "figure capture: cannot read %s\n", path);
      return;
   }
   char line[1024];
   int  lineno = 0;
   while (std::fgets(line, sizeof(line), f)) {
      ++lineno;
      std::string l(line);
      if (const size_t c = l.find('#'); c != std::string::npos && l.compare(0, c, std::string(c, ' ')) == 0) continue;
      while (!l.empty() && (l.back() == '\n' || l.back() == '\r')) l.pop_back();
      if (l.find_first_not_of(" \t") == std::string::npos) continue;
      capture_event_t e;
      char what[16] = {0}, arg[1024] = {0};
      int  used = 0;
      if (std::sscanf(l.c_str(), "%ld %15s %n", &e.frame, what, &used) < 2) {
         std::fprintf(stderr, "figure capture: %s:%d: expected <frame> <event>\n", path, lineno);
         continue;
      }
      e.what = what;
      const char *rest = l.c_str() + used;
      bool ok = true;
      if (e.what == "move") {
         ok = std::sscanf(rest, "%f %f %d", &e.x, &e.y, &e.n) >= 2;
         if (e.n < 1) e.n = 1;
      } else if (e.what == "down" || e.what == "up" || e.what == "key") {
         if (std::sscanf(rest, "%1023s %n", arg, &used) >= 1) {
            e.arg = arg;
            if (e.what == "key") {
               char state[8] = {0};
               if (std::sscanf(rest + used, "%7s", state) == 1) e.what = std::string("key-") + state;
               ok = capture_key(e.arg) != ImGuiKey_None;
            }
         } else {
            ok = e.what != "key";
         }
      } else if (e.what == "wheel") {
         ok = std::sscanf(rest, "%f %f", &e.x, &e.y) == 2;
      } else if (e.what == "text") {
         e.arg = rest;
      } else {
         ok = false;
      }
      if (!ok) {
         std::fprintf(stderr, "figure capture: %s:%d: bad event \"%s\"\n", path, lineno, l.c_str());
         continue;
      }
      cap.events.push_back(e);
   }
   std::fclose(f);
   std::stable_sort(cap.events.begin(), cap.events.end(),
                    [](const capture_event_t &a, const capture_event_t &b) { return a.frame < b.frame; });
}

// Apply the scripted input of the current frame (before ImGui::NewFrame).
void capture_apply_input() {
   ImGuiIO &io = ImGui::GetIO();
   if (cap.glide > 0) {
      cap.px += (cap.gx - cap.px) / static_cast<float>(cap.glide);
      cap.py += (cap.gy - cap.py) / static_cast<float>(cap.glide);
      --cap.glide;
      io.AddMousePosEvent(cap.px, cap.py);
   }
   for (; cap.next < cap.events.size() && cap.events[cap.next].frame <= cap.frame; ++cap.next) {
      const capture_event_t &e = cap.events[cap.next];
      if (e.what == "move") {
         cap.gx = e.x;
         cap.gy = e.y;
         cap.glide = e.n;
         cap.px += (cap.gx - cap.px) / static_cast<float>(cap.glide);
         cap.py += (cap.gy - cap.py) / static_cast<float>(cap.glide);
         --cap.glide;
         io.AddMousePosEvent(cap.px, cap.py);
      } else if (e.what == "down" || e.what == "up") {
         io.AddMouseButtonEvent(capture_button(e.arg), e.what == "down");
      } else if (e.what == "wheel") {
         io.AddMouseWheelEvent(e.x, e.y);
      } else if (e.what == "text") {
         io.AddInputCharactersUTF8(e.arg.c_str());
      } else if (e.what == "key") {
         io.AddKeyEvent(capture_key(e.arg), true);
         io.AddKeyEvent(capture_key(e.arg), false);
      } else if (e.what == "key-down" || e.what == "key-up") {
         io.AddKeyEvent(capture_key(e.arg), e.what == "key-down");
      }
   }
}

void capture_setup() {
   cap = capture_t{};
   const char *prefix = std::getenv("FIGURE_CAPTURE");
   if (!prefix || !*prefix) return;
   cap.on = true;
   cap.prefix = prefix;
   if (const char *v = std::getenv("FIGURE_CAPTURE_FPS")) {
      const double fps = std::atof(v);
      if (fps > 0.0) cap.dt = static_cast<float>(1.0 / fps);
   }
   if (const char *v = std::getenv("FIGURE_CAPTURE_FROM")) cap.from = std::atol(v);
   if (const char *v = std::getenv("FIGURE_CAPTURE_FRAMES")) cap.count = std::atol(v);
   if (const char *v = std::getenv("FIGURE_CAPTURE_INPUT"); v && *v) capture_read_input(v);
}

void redraw_stats_flush(Uint64 now) {
   if (now - rs.t0 < SDL_NS_PER_SECOND) return;
   const double ms = 1.0e-6, span = static_cast<double>(now - rs.t0) * 1.0e-9;
   std::fprintf(stderr, "figure redraw: %.2f s frames=%d timeouts=%d wait=%.1fms build=%.1fms render=%.1fms swap=%.1fms events:",
                span, rs.frames, rs.timeouts, rs.wait * ms, rs.build * ms, rs.render * ms, rs.swap * ms);
   for (const auto &e : rs.events) std::fprintf(stderr, " 0x%x=%d", e.first, e.second);
   std::fprintf(stderr, "\n");
   const bool on = rs.on;
   rs = redraw_stats_t{};
   rs.on = on;
   rs.t0 = now;
   rs.t_mark = now;
}

// The GL calls the glue makes itself (frame clear, user textures), loaded through SDL: no link-time dependency on
// libGL/opengl32.
typedef void (*gl_viewport_t)(int, int, int, int);
typedef void (*gl_clear_color_t)(float, float, float, float);
typedef void (*gl_clear_t)(unsigned int);
gl_viewport_t    p_glViewport = nullptr;
gl_clear_color_t p_glClearColor = nullptr;
gl_clear_t       p_glClear = nullptr;
constexpr unsigned int GL_COLOR_BUFFER_BIT_ = 0x00004000;
typedef void (*gl_gen_textures_t)(int, unsigned int *);
typedef void (*gl_delete_textures_t)(int, const unsigned int *);
typedef void (*gl_bind_texture_t)(unsigned int, unsigned int);
typedef void (*gl_tex_parameteri_t)(unsigned int, unsigned int, int);
typedef void (*gl_tex_image_2d_t)(unsigned int, int, int, int, int, int, unsigned int, unsigned int, const void *);
typedef void (*gl_tex_sub_image_2d_t)(unsigned int, int, int, int, int, int, unsigned int, unsigned int, const void *);
typedef void (*gl_pixel_storei_t)(unsigned int, int);
typedef void (*gl_read_pixels_t)(int, int, int, int, unsigned int, unsigned int, void *);
gl_gen_textures_t     p_glGenTextures = nullptr;
gl_delete_textures_t  p_glDeleteTextures = nullptr;
gl_bind_texture_t     p_glBindTexture = nullptr;
gl_tex_parameteri_t   p_glTexParameteri = nullptr;
gl_tex_image_2d_t     p_glTexImage2D = nullptr;
gl_tex_sub_image_2d_t p_glTexSubImage2D = nullptr;
gl_pixel_storei_t     p_glPixelStorei = nullptr;
gl_read_pixels_t      p_glReadPixels = nullptr;
constexpr unsigned int GL_TEXTURE_2D_ = 0x0DE1, GL_TEXTURE_MAG_FILTER_ = 0x2800, GL_TEXTURE_MIN_FILTER_ = 0x2801;
constexpr unsigned int GL_TEXTURE_WRAP_S_ = 0x2802, GL_TEXTURE_WRAP_T_ = 0x2803, GL_CLAMP_TO_EDGE_ = 0x812F;
constexpr unsigned int GL_NEAREST_ = 0x2600, GL_LINEAR_ = 0x2601, GL_RGBA_ = 0x1908, GL_UNSIGNED_BYTE_ = 0x1401;
constexpr unsigned int GL_UNPACK_ROW_LENGTH_ = 0x0CF2, GL_UNPACK_ALIGNMENT_ = 0x0CF5, GL_PACK_ALIGNMENT_ = 0x0D05;
constexpr unsigned int GL_RGB_ = 0x1907;

// Capture: read the back buffer (just rendered) and write it as a binary PPM, top row first.
void capture_write(int w, int h) {
   if (w <= 0 || h <= 0) return;
   std::vector<unsigned char> px(static_cast<size_t>(w) * h * 3);
   p_glPixelStorei(GL_PACK_ALIGNMENT_, 1);
   p_glReadPixels(0, 0, w, h, GL_RGB_, GL_UNSIGNED_BYTE_, px.data());
   char name[32];
   std::snprintf(name, sizeof(name), "%05ld.ppm", cap.written);
   const std::string path = cap.prefix + name;
   FILE *f = std::fopen(path.c_str(), "wb");
   if (!f) {
      std::fprintf(stderr, "figure capture: cannot write %s\n", path.c_str());
      cap.on = false;
      return;
   }
   std::fprintf(f, "P6\n%d %d\n255\n", w, h);
   const size_t row = static_cast<size_t>(w) * 3;
   for (int y = h - 1; y >= 0; --y) std::fwrite(px.data() + static_cast<size_t>(y) * row, 1, row, f); // GL rows go up
   std::fclose(f);
   ++cap.written;
}

#include "figure_font.inc" // plex_sans_ttf[]: IBM Plex Sans Regular (third_party/fonts, OFL-1.1)

constexpr float DEFAULT_FONT_SIZE = 15.0f; // logical pixels: the size the interface is drawn at

// A font by name ("plex-sans", "proggy") or TTF path, loaded on first use into this context's atlas; null with err.
ImFont *get_font(const std::string &name, std::string &err) {
   const auto found = st.fonts.find(name);
   if (found != st.fonts.end()) return found->second;
   ImGuiIO &io = ImGui::GetIO();
   ImFontConfig cfg;
   cfg.FontDataOwnedByAtlas = false; // the bundled bytes are static; files are kept in st.font_data
   // Dear ImGui clamps each advance to GlyphMaxAdvanceX * (size / reference size); its default FLT_MAX overflows to
   // infinity for any size above the reference, which stops programs built with -ffpe-trap=overflow. No glyph is
   // 1e30 pixels wide, so a finite bound changes nothing else.
   cfg.GlyphMaxAdvanceX = 1.0e30f;
   ImFont *f = nullptr;
   if (name == "plex-sans") {
      std::snprintf(cfg.Name, sizeof(cfg.Name), "IBM Plex Sans");
      f = io.Fonts->AddFontFromMemoryTTF(const_cast<unsigned char *>(plex_sans_ttf), static_cast<int>(sizeof(plex_sans_ttf)),
                                         DEFAULT_FONT_SIZE, &cfg);
   } else if (name == "proggy") {
      ImFontConfig bitmap;
      bitmap.GlyphMaxAdvanceX = cfg.GlyphMaxAdvanceX;
      f = io.Fonts->AddFontDefaultBitmap(&bitmap);
   } else {
      FILE *in = std::fopen(name.c_str(), "rb");
      if (!in) {
         err = "cannot read the font " + name;
         return nullptr;
      }
      std::vector<unsigned char> data;
      unsigned char buf[65536];
      size_t n;
      while ((n = std::fread(buf, 1, sizeof(buf), in)) > 0) data.insert(data.end(), buf, buf + n);
      std::fclose(in);
      // TrueType (00 01 00 00, "true") or OpenType with TrueType or CFF outlines ("OTTO"): Dear ImGui reads them
      const bool ttf = data.size() > 12 && ((data[0] == 0 && data[1] == 1 && data[2] == 0 && data[3] == 0) ||
                                            std::memcmp(data.data(), "true", 4) == 0 ||
                                            std::memcmp(data.data(), "OTTO", 4) == 0);
      if (!ttf) {
         err = name + " is not a TrueType or OpenType font";
         return nullptr;
      }
      std::vector<unsigned char> &kept = st.font_data[name];
      kept = std::move(data);
      std::snprintf(cfg.Name, sizeof(cfg.Name), "%s", name.substr(name.find_last_of("/\\") + 1).c_str());
      f = io.Fonts->AddFontFromMemoryTTF(kept.data(), static_cast<int>(kept.size()), DEFAULT_FONT_SIZE, &cfg);
   }
   if (!f) {
      err = "cannot load the font " + name;
      return nullptr;
   }
   st.fonts[name] = f;
   return f;
}

void create_contexts() {
   IMGUI_CHECKVERSION();
   ImGui::CreateContext();
   ImPlot::CreateContext();
   ImGuiIO &io = ImGui::GetIO();
   // Docking on by default: a window dragged by its title bar docks into another window or into a dock space
   // (fig_set_docking turns it off). Multi-viewports stay off: remote and headless modes cannot have them.
   io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard | ImGuiConfigFlags_DockingEnable;
   // No imgui.ini by default: a layout restored from whatever directory the program runs in silently overrides the
   // positions and sizes the program sets on first use. fig_set_ini_file opts in.
   io.IniFilename = nullptr;
   ImGui::StyleColorsDark();
   // The bundled font at 15 logical pixels (Dear ImGui's own is a 13-pixel bitmap font: set_font('proggy'))
   std::string err;
   if (ImFont *f = get_font("plex-sans", err)) io.FontDefault = f;
   ImGui::GetStyle().FontSizeBase = DEFAULT_FONT_SIZE;
   st.font = "plex-sans";
}

void destroy_contexts() {
   st.fonts.clear(); // the fonts belong to the context's atlas
   st.font_data.clear();
   if (ImPlot::GetCurrentContext()) ImPlot::DestroyContext();
   if (ImGui::GetCurrentContext()) ImGui::DestroyContext();
}

// ---- Style fields by name ------------------------------------------------------------------------------------------
// lib 0: Dear ImGui (ImGuiStyle), 1: ImPlot (ImPlotStyle). Colours by the libraries' own names (GetStyleColorName);
// the other fields by the generated tables of figure_style_generated.cpp.

int style_color_index(int lib, const std::string &name) {
   const int n = lib == 0 ? static_cast<int>(ImGuiCol_COUNT) : static_cast<int>(ImPlotCol_COUNT);
   for (int i = 0; i < n; ++i)
      if (name == (lib == 0 ? ImGui::GetStyleColorName(i) : ImPlot::GetStyleColorName(i))) return i;
   return -1;
}

const figure_style::field *style_field(int lib, const std::string &name) {
   const figure_style::field *t = lib == 0 ? figure_style::IMGUI_FIELDS : figure_style::IMPLOT_FIELDS;
   const int n = lib == 0 ? figure_style::IMGUI_FIELDS_COUNT : figure_style::IMPLOT_FIELDS_COUNT;
   for (int i = 0; i < n; ++i)
      if (name == t[i].name) return &t[i];
   return nullptr;
}

unsigned char *style_base(int lib) {
   return lib == 0 ? reinterpret_cast<unsigned char *>(&ImGui::GetStyle())
                   : reinterpret_cast<unsigned char *>(&ImPlot::GetStyle());
}

// ---- Styles ---------------------------------------------------------------------------------------------------
// A style is a theme (figure_theme.h): a base Dear ImGui style, colours and variables of Dear ImGui and ImPlot by name,
// ImPlot's line colours, and the window's background. The built-in ones are themes/*.toml, embedded in the library:
// "seal" (the default) and "seal-light", FIGURE's, from the palette of its mark; "dark", "light", "classic", Dear
// ImGui's own with ImPlot's default line colours.

ImVec4 vec4(const figure_theme::color_t &c) { return ImVec4(c.r, c.g, c.b, c.a); }

// Write a style variable into a style struct (ImGuiStyle or ImPlotStyle) at `base`.
bool write_var(unsigned char *base, const figure_style::field &f, const std::vector<double> &v) {
   unsigned char *p = base + f.offset;
   const size_t ncomp = f.kind == figure_style::FIG_STYLE_VEC2 ? 2 : 1;
   if (v.size() != ncomp) return false;
   switch (f.kind) {
   case figure_style::FIG_STYLE_FLOAT: *reinterpret_cast<float *>(p) = static_cast<float>(v[0]); break;
   case figure_style::FIG_STYLE_VEC2:
      *reinterpret_cast<ImVec2 *>(p) = ImVec2(static_cast<float>(v[0]), static_cast<float>(v[1]));
      break;
   case figure_style::FIG_STYLE_BOOL: *reinterpret_cast<bool *>(p) = v[0] != 0.0; break;
   default: *reinterpret_cast<int *>(p) = static_cast<int>(v[0]); break;
   }
   return true;
}

// Apply a parsed theme; false with `err` on an unknown name or a wrong value. Sizes in the theme are logical pixels,
// scaled by the content scale; fonts are kept. `cmap_name` names the ImPlot colormap of its lines.
bool apply_theme(const figure_theme::theme_t &t, const std::string &where, const std::string &cmap_name,
                 std::string &err) {
   auto bad = [&](const figure_theme::entry_t &e, const std::string &what) {
      err = where + ":" + std::to_string(e.line) + ": " + what + " \"" + e.name + "\"";
      return false;
   };
   const ImGuiStyle old = ImGui::GetStyle();
   ImGuiStyle s;
   if (t.base == "light") ImGui::StyleColorsLight(&s);
   else if (t.base == "classic") ImGui::StyleColorsClassic(&s);
   else ImGui::StyleColorsDark(&s);
   for (const auto &e : t.imgui_vars) {
      const figure_style::field *f = style_field(0, e.name);
      if (!f) return bad(e, "unknown Dear ImGui style variable");
      if (!write_var(reinterpret_cast<unsigned char *>(&s), *f, e.values)) return bad(e, "wrong number of values for");
   }
   for (const auto &e : t.imgui_colors) {
      const int i = style_color_index(0, e.name);
      if (i < 0) return bad(e, "unknown Dear ImGui colour");
      s.Colors[i] = vec4(e.color);
   }
   ImPlotStyle ps; // ImPlot's defaults; colours derived from Dear ImGui's below (StyleColorsAuto)
   for (const auto &e : t.implot_vars) {
      const figure_style::field *f = style_field(1, e.name);
      if (!f) return bad(e, "unknown ImPlot style variable");
      if (!write_var(reinterpret_cast<unsigned char *>(&ps), *f, e.values)) return bad(e, "wrong number of values for");
   }
   std::vector<std::pair<int, ImVec4>> plot_colors;
   for (const auto &e : t.implot_colors) {
      const int i = style_color_index(1, e.name);
      if (i < 0) return bad(e, "unknown ImPlot colour");
      plot_colors.emplace_back(i, vec4(e.color));
   }
   int cmap = ImPlotColormap_Deep;
   if (!t.lines.empty()) {
      cmap = ImPlot::GetColormapIndex(cmap_name.c_str()); // ImPlot keeps colormaps for the context's life
      if (cmap < 0) {
         std::vector<ImU32> cols;
         for (const auto &c : t.lines) cols.push_back(ImGui::ColorConvertFloat4ToU32(vec4(c)));
         cmap = ImPlot::AddColormap(cmap_name.c_str(), cols.data(), static_cast<int>(cols.size()), true);
      }
   }
   float clear[3] = {0.10f, 0.10f, 0.11f};
   if (t.has_background) {
      clear[0] = t.background.r;
      clear[1] = t.background.g;
      clear[2] = t.background.b;
   }
   ImFont *font = nullptr;
   if (!t.font.empty()) {
      font = get_font(t.font, err);
      if (!font) {
         err = where + ": " + err;
         return false;
      }
   }
   s.ScaleAllSizes(st.scale);
   s.FontSizeBase = t.font_size > 0.0 ? static_cast<float>(t.font_size) : old.FontSizeBase;
   s.FontScaleMain = old.FontScaleMain;
   s.FontScaleDpi = old.FontScaleDpi;
   ImGui::GetStyle() = s;
   ImPlot::GetStyle() = ps;
   ImPlot::StyleColorsAuto();
   for (const auto &pc : plot_colors) ImPlot::GetStyle().Colors[pc.first] = pc.second;
   ImPlot::GetStyle().Colormap = cmap;
   for (int i = 0; i < 3; ++i) st.clear[i] = clear[i];
   st.style_base = t.base;
   if (font) {
      ImGui::GetIO().FontDefault = font;
      st.font = t.font;
   }
   if (st.m == mode::remote) figure_remote::set_background(clear[0], clear[1], clear[2]);
   return true;
}

// Apply a built-in style by name, with its own line colours or a named palette (`lines`, empty: the theme's); false if
// the name is unknown (err empty) or the theme or the palette is wrong (err set).
bool apply_style(const std::string &name, std::string &err, const std::string &lines = "") {
   err.clear();
   for (int i = 0; i < figure_theme::builtin_count(); ++i) {
      if (name != figure_theme::builtin_name(i)) continue;
      figure_theme::theme_t t;
      const std::string where = "themes/" + name + ".toml";
      if (!figure_theme::parse(figure_theme::builtin_text(i), where, t, err)) return false;
      std::string cmap = "FIGURE " + name;
      if (!lines.empty()) {
         if (!figure_theme::line_palette(lines, t.lines)) {
            err = "unknown line palette \"" + lines + "\" (okabe-ito)";
            return false;
         }
         cmap = "FIGURE " + lines; // the palette's colours, whatever the theme
      }
      return apply_theme(t, where, cmap, err);
   }
   return false;
}

// Apply a theme file read at run time; false with err. Its line colours get a colormap named by the colours themselves,
// so loading the same file again reuses it and a changed file gets a new one (ImPlot cannot replace a colormap).
bool apply_style_file(const std::string &path, std::string &err) {
   FILE *f = std::fopen(path.c_str(), "rb");
   if (!f) {
      err = "cannot read " + path;
      return false;
   }
   std::string text;
   char buf[4096];
   size_t n;
   while ((n = std::fread(buf, 1, sizeof(buf), f)) > 0) text.append(buf, n);
   std::fclose(f);
   figure_theme::theme_t t;
   if (!figure_theme::parse(text, path, t, err)) return false;
   std::string cmap = "FIGURE lines";
   char hex[16];
   for (const auto &c : t.lines) {
      std::snprintf(hex, sizeof(hex), " %08x", ImGui::ColorConvertFloat4ToU32(vec4(c)));
      cmap += hex;
   }
   return apply_theme(t, path, cmap, err);
}

// A style name or a theme file: a value with a '/' or ending in ".toml" is a file.
bool is_style_file(const std::string &v) {
   return v.find('/') != std::string::npos || (v.size() > 5 && v.compare(v.size() - 5, 5, ".toml") == 0);
}

// The shortest decimal that reads back to the same float (0.97, not 0.970000029).
std::string short_float(float v) {
   char out[32];
   for (int digits = 6; digits <= 9; ++digits) {
      std::snprintf(out, sizeof(out), "%.*g", digits, v);
      if (std::strtof(out, nullptr) == v) break;
   }
   return out;
}

// Colour as the theme format writes it: "#rrggbb", or ["#rrggbb", alpha] with the alpha exact.
std::string theme_color(const ImVec4 &c) {
   auto byte = [](float v) { return static_cast<int>(std::lround(std::min(1.0f, std::max(0.0f, v)) * 255.0f)); };
   char out[64];
   if (c.w >= 1.0f) std::snprintf(out, sizeof(out), "\"#%02x%02x%02x\"", byte(c.x), byte(c.y), byte(c.z));
   else std::snprintf(out, sizeof(out), "[\"#%02x%02x%02x\", %s]", byte(c.x), byte(c.y), byte(c.z), short_float(c.w).c_str());
   return out;
}

// Write the style in effect as a theme file: base, background, lines, and every colour and variable that differs from
// the base. Sizes are written in logical pixels (divided by the content scale): which fields are sizes is asked to Dear
// ImGui itself (the fields ScaleAllSizes changes).
bool save_style_file(const std::string &path, std::string &err) {
   const std::string base = st.style_base;
   ImGuiStyle ref;
   if (base == "light") ImGui::StyleColorsLight(&ref);
   else if (base == "classic") ImGui::StyleColorsClassic(&ref);
   else ImGui::StyleColorsDark(&ref);
   ImGuiStyle probe; // every plain field set to 1, then scaled by 2: the sizes become 2
   for (int i = 0; i < figure_style::IMGUI_FIELDS_COUNT; ++i) {
      const figure_style::field &f = figure_style::IMGUI_FIELDS[i];
      unsigned char *p = reinterpret_cast<unsigned char *>(&probe) + f.offset;
      if (f.kind == figure_style::FIG_STYLE_FLOAT) *reinterpret_cast<float *>(p) = 1.0f;
      else if (f.kind == figure_style::FIG_STYLE_VEC2) *reinterpret_cast<ImVec2 *>(p) = ImVec2(1.0f, 1.0f);
   }
   probe.ScaleAllSizes(2.0f);
   const ImGuiStyle &cur = ImGui::GetStyle();
   const float scale = st.scale > 0.0f ? st.scale : 1.0f;
   std::string out = "# FIGURE theme, written by app%save_style\n\nbase = \"" + base + "\"\n";
   if (st.font != "plex-sans") out += "font = \"" + st.font + "\"\n";
   if (cur.FontSizeBase != DEFAULT_FONT_SIZE) out += "font_size = " + short_float(cur.FontSizeBase) + "\n";
   out += "background = " + theme_color(ImVec4(st.clear[0], st.clear[1], st.clear[2], 1.0f)) + "\n";
   const ImPlotColormap cmap = ImPlot::GetStyle().Colormap;
   if (cmap != ImPlotColormap_Deep) {
      out += "lines = [";
      for (int i = 0; i < ImPlot::GetColormapSize(cmap); ++i) {
         if (i) out += ", ";
         ImVec4 c = ImPlot::GetColormapColor(i, cmap);
         c.w = 1.0f;
         out += theme_color(c);
      }
      out += "]\n";
   }
   char num[96];
   auto vars = [&](const char *section, const figure_style::field *table, int count, const unsigned char *now,
                   const unsigned char *was, const unsigned char *sizes) {
      std::string block;
      for (int i = 0; i < count; ++i) {
         const figure_style::field &f = table[i];
         const unsigned char *a = now + f.offset, *b = was + f.offset;
         const float k = sizes && f.kind <= figure_style::FIG_STYLE_VEC2 &&
                                 *reinterpret_cast<const float *>(sizes + f.offset) == 2.0f
                            ? scale
                            : 1.0f;
         switch (f.kind) {
         case figure_style::FIG_STYLE_FLOAT: {
            const float v = *reinterpret_cast<const float *>(a) / k;
            if (v == *reinterpret_cast<const float *>(b)) continue;
            std::snprintf(num, sizeof(num), "%s", short_float(v).c_str());
            break;
         }
         case figure_style::FIG_STYLE_VEC2: {
            const ImVec2 v = *reinterpret_cast<const ImVec2 *>(a), w = *reinterpret_cast<const ImVec2 *>(b);
            if (v.x / k == w.x && v.y / k == w.y) continue;
            std::snprintf(num, sizeof(num), "[%s, %s]", short_float(v.x / k).c_str(), short_float(v.y / k).c_str());
            break;
         }
         case figure_style::FIG_STYLE_BOOL: {
            const bool v = *reinterpret_cast<const bool *>(a);
            if (v == *reinterpret_cast<const bool *>(b)) continue;
            std::snprintf(num, sizeof(num), "%s", v ? "true" : "false");
            break;
         }
         default: {
            const int v = *reinterpret_cast<const int *>(a);
            if (v == *reinterpret_cast<const int *>(b)) continue;
            std::snprintf(num, sizeof(num), "%d", v);
            break;
         }
         }
         block += std::string(f.name) + " = " + num + "\n";
      }
      if (!block.empty()) out += std::string("\n[") + section + "]\n" + block;
   };
   vars("imgui.vars", figure_style::IMGUI_FIELDS, figure_style::IMGUI_FIELDS_COUNT,
        reinterpret_cast<const unsigned char *>(&cur), reinterpret_cast<const unsigned char *>(&ref),
        reinterpret_cast<const unsigned char *>(&probe));
   std::string colors;
   for (int i = 0; i < ImGuiCol_COUNT; ++i) {
      const ImVec4 &c = cur.Colors[i], &r = ref.Colors[i];
      if (c.x == r.x && c.y == r.y && c.z == r.z && c.w == r.w) continue;
      colors += std::string(ImGui::GetStyleColorName(i)) + " = " + theme_color(c) + "\n";
   }
   if (!colors.empty()) out += "\n[imgui.colors]\n" + colors;
   const ImPlotStyle pref;
   vars("implot.vars", figure_style::IMPLOT_FIELDS, figure_style::IMPLOT_FIELDS_COUNT,
        reinterpret_cast<const unsigned char *>(&ImPlot::GetStyle()), reinterpret_cast<const unsigned char *>(&pref),
        nullptr);
   colors.clear();
   for (int i = 0; i < ImPlotCol_COUNT; ++i) {
      const ImVec4 &c = ImPlot::GetStyle().Colors[i];
      if (ImPlot::IsColorAuto(c)) continue; // derived from Dear ImGui's: nothing to write
      colors += std::string(ImPlot::GetStyleColorName(i)) + " = " + theme_color(c) + "\n";
   }
   if (!colors.empty()) out += "\n[implot.colors]\n" + colors;
   FILE *f = std::fopen(path.c_str(), "wb");
   if (!f) {
      err = "cannot write " + path;
      return false;
   }
   const bool ok = std::fwrite(out.data(), 1, out.size(), f) == out.size();
   if (std::fclose(f) != 0 || !ok) {
      err = "cannot write " + path;
      return false;
   }
   return true;
}

std::string builtin_style_names() {
   std::string names;
   for (int i = 0; i < figure_theme::builtin_count(); ++i) {
      if (i) names += ", ";
      names += figure_theme::builtin_name(i);
   }
   return names;
}

// The style at initialisation: "seal", or the one named by the environment variable FIGURE_STYLE (a program's own
// set_style call comes later and wins). An unknown name is reported and ignored.
void apply_initial_style() {
   std::string err;
   if (!apply_style("seal", err)) std::fprintf(stderr, "figure: the default style: %s\n", err.c_str());
   const char *v = std::getenv("FIGURE_STYLE");
   if (v && *v && is_style_file(v)) {
      if (!apply_style_file(v, err)) std::fprintf(stderr, "figure: FIGURE_STYLE=%s: %s, ignored\n", v, err.c_str());
      return;
   }
   if (v && *v && !apply_style(v, err))
      std::fprintf(stderr, "figure: FIGURE_STYLE=%s: %s, ignored\n", v,
                   err.empty() ? ("unknown style (" + builtin_style_names() + ")").c_str() : err.c_str());
}

// Headless renderer: acknowledge texture requests (font atlas pages) without a GPU, as a real backend would.
void headless_textures() {
   for (ImTextureData *t : ImGui::GetPlatformIO().Textures) {
      if (t->Status == ImTextureStatus_WantCreate || t->Status == ImTextureStatus_WantUpdates) {
         t->SetTexID(static_cast<ImTextureID>(1));
         t->SetStatus(ImTextureStatus_OK);
      } else if (t->Status == ImTextureStatus_WantDestroy) {
         t->SetTexID(ImTextureID_Invalid);
         t->SetStatus(ImTextureStatus_Destroyed);
      }
   }
}

} // namespace

extern "C" {

const char *fig_last_error(int *len) {
   *len = static_cast<int>(last_error.size());
   return last_error.c_str();
}

void fig_set_last_error(const char *msg, int msg_len) {
   try {
      last_error.assign(msg, msg_len > 0 ? static_cast<size_t>(msg_len) : 0);
   } catch (...) {
   }
}

int fig_init(const char *title, int title_len, int width, int height, int vsync) {
   FIG_TRY
   if (st.m != mode::none) return fail(FIG_ERR_STATE, "figure is already initialized");
   if (width <= 0 || height <= 0) return fail(FIG_ERR_ARGUMENT, "window size must be positive");
   SDL_SetMainReady();
   if (!SDL_Init(SDL_INIT_VIDEO)) return fail(FIG_ERR_FAILED, std::string("SDL_Init: ") + SDL_GetError());
#if defined(__APPLE__)
   const char *glsl = "#version 150";
   SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG);
   SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
   SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
   SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2);
#else
   const char *glsl = "#version 130";
   SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, 0);
   SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
   SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
   SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);
#endif
   SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
   SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 0);
   SDL_GL_SetAttribute(SDL_GL_STENCIL_SIZE, 8);
   capture_setup();
   st.scale = SDL_GetDisplayContentScale(SDL_GetPrimaryDisplay());
   if (st.scale <= 0.0f || cap.on) st.scale = 1.0f; // capture: pixel sizes independent of the display
   const std::string t(title, title_len > 0 ? static_cast<size_t>(title_len) : 0);
   const SDL_WindowFlags flags =
      SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIDDEN | SDL_WINDOW_HIGH_PIXEL_DENSITY;
   st.window = SDL_CreateWindow(t.c_str(), static_cast<int>(width * st.scale), static_cast<int>(height * st.scale), flags);
   if (!st.window) {
      SDL_Quit();
      return fail(FIG_ERR_FAILED, std::string("SDL_CreateWindow: ") + SDL_GetError());
   }
   st.gl = SDL_GL_CreateContext(st.window);
   if (!st.gl) {
      SDL_DestroyWindow(st.window);
      SDL_Quit();
      return fail(FIG_ERR_FAILED, std::string("SDL_GL_CreateContext: ") + SDL_GetError());
   }
   SDL_GL_MakeCurrent(st.window, st.gl);
   SDL_GL_SetSwapInterval(vsync ? 1 : 0);
   p_glViewport = reinterpret_cast<gl_viewport_t>(SDL_GL_GetProcAddress("glViewport"));
   p_glClearColor = reinterpret_cast<gl_clear_color_t>(SDL_GL_GetProcAddress("glClearColor"));
   p_glClear = reinterpret_cast<gl_clear_t>(SDL_GL_GetProcAddress("glClear"));
   p_glGenTextures = reinterpret_cast<gl_gen_textures_t>(SDL_GL_GetProcAddress("glGenTextures"));
   p_glDeleteTextures = reinterpret_cast<gl_delete_textures_t>(SDL_GL_GetProcAddress("glDeleteTextures"));
   p_glBindTexture = reinterpret_cast<gl_bind_texture_t>(SDL_GL_GetProcAddress("glBindTexture"));
   p_glTexParameteri = reinterpret_cast<gl_tex_parameteri_t>(SDL_GL_GetProcAddress("glTexParameteri"));
   p_glTexImage2D = reinterpret_cast<gl_tex_image_2d_t>(SDL_GL_GetProcAddress("glTexImage2D"));
   p_glTexSubImage2D = reinterpret_cast<gl_tex_sub_image_2d_t>(SDL_GL_GetProcAddress("glTexSubImage2D"));
   p_glPixelStorei = reinterpret_cast<gl_pixel_storei_t>(SDL_GL_GetProcAddress("glPixelStorei"));
   p_glReadPixels = reinterpret_cast<gl_read_pixels_t>(SDL_GL_GetProcAddress("glReadPixels"));
   SDL_SetWindowPosition(st.window, SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED);
   SDL_ShowWindow(st.window);

   create_contexts();
   ImGuiStyle &style = ImGui::GetStyle();
   style.ScaleAllSizes(st.scale);
   style.FontScaleDpi = st.scale;
   ImGui_ImplSDL3_InitForOpenGL(st.window, st.gl);
   ImGui_ImplOpenGL3_Init(glsl);
   st.m = mode::window;
   apply_initial_style();
   st.frames_left = 3;
   rs = redraw_stats_t{};
   rs.on = std::getenv("FIGURE_DEBUG_REDRAW") != nullptr;
   rs.t0 = rs.t_mark = SDL_GetTicksNS();
   return FIG_OK;
   FIG_CATCH
}

int fig_init_headless(int width, int height) {
   FIG_TRY
   if (st.m != mode::none) return fail(FIG_ERR_STATE, "figure is already initialized");
   if (width <= 0 || height <= 0) return fail(FIG_ERR_ARGUMENT, "display size must be positive");
   create_contexts();
   ImGuiIO &io = ImGui::GetIO();
   io.DisplaySize = ImVec2(static_cast<float>(width), static_cast<float>(height));
   io.BackendFlags |= ImGuiBackendFlags_RendererHasTextures;
   // draw lists over 65536 vertices are split into ranges, each command carrying its VtxOffset (16-bit indices)
   io.BackendFlags |= ImGuiBackendFlags_RendererHasVtxOffset;
   st.m = mode::headless;
   apply_initial_style();
   return FIG_OK;
   FIG_CATCH
}

int fig_init_remote(int width, int height, const char *host, int host_len, int port, int *bound_port) {
   FIG_TRY
   *bound_port = 0;
   if (st.m != mode::none) return fail(FIG_ERR_STATE, "figure is already initialized");
   if (width <= 0 || height <= 0) return fail(FIG_ERR_ARGUMENT, "display size must be positive");
   if (port < 0 || port > 65535) return fail(FIG_ERR_ARGUMENT, "port must be in 0..65535");
   std::string err;
   const std::string h(host, host_len > 0 ? static_cast<size_t>(host_len) : 0);
   if (!figure_remote::start(h.empty() ? "127.0.0.1" : h, port, *bound_port, err)) return fail(FIG_ERR_FAILED, err);
   create_contexts();
   ImGuiIO &io = ImGui::GetIO();
   io.DisplaySize = ImVec2(static_cast<float>(width), static_cast<float>(height)); // until the browser sends its size
   io.BackendFlags |= ImGuiBackendFlags_RendererHasTextures;
   // draw lists over 65536 vertices are split into ranges, each command carrying its VtxOffset (16-bit indices)
   io.BackendFlags |= ImGuiBackendFlags_RendererHasVtxOffset;
   io.BackendPlatformName = "figure_remote";
   st.m = mode::remote;
   apply_initial_style();
   st.frames_left = 3;
   st.last_frame = std::chrono::steady_clock::now();
   return FIG_OK;
   FIG_CATCH
}

int fig_set_style(const char *name, int name_len, const char *lines, int lines_len) {
   FIG_TRY
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   const std::string n(name, name_len > 0 ? static_cast<size_t>(name_len) : 0);
   const std::string l(lines, lines_len > 0 ? static_cast<size_t>(lines_len) : 0);
   std::string err;
   if (!apply_style(n, err, l))
      return fail(FIG_ERR_ARGUMENT, err.empty() ? "set_style: unknown style \"" + n + "\" (" + builtin_style_names() + ")"
                                                : "set_style: " + err);
   return FIG_OK;
   FIG_CATCH
}

int fig_load_style(const char *path, int path_len) {
   FIG_TRY
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   const std::string p(path, path_len > 0 ? static_cast<size_t>(path_len) : 0);
   std::string err;
   if (!apply_style_file(p, err)) {
      if (err.rfind("cannot read", 0) == 0) return fail(FIG_ERR_FAILED, "load_style: " + err);
      return fail(FIG_ERR_ARGUMENT, "load_style: " + err);
   }
   return FIG_OK;
   FIG_CATCH
}

int fig_save_style(const char *path, int path_len) {
   FIG_TRY
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   const std::string p(path, path_len > 0 ? static_cast<size_t>(path_len) : 0);
   std::string err;
   if (!save_style_file(p, err)) return fail(FIG_ERR_FAILED, "save_style: " + err);
   return FIG_OK;
   FIG_CATCH
}

int fig_show_style_editor(int *open) {
   FIG_TRY
   if (!st.in_frame) return fail(FIG_ERR_STATE, "ig_show_style_editor: no frame is open");
   bool o = open ? *open != 0 : true;
   if (ImGui::Begin("Style editor", open ? &o : nullptr)) {
      if (ImGui::CollapsingHeader("Dear ImGui", ImGuiTreeNodeFlags_DefaultOpen)) ImGui::ShowStyleEditor();
      if (ImGui::CollapsingHeader("ImPlot")) ImPlot::ShowStyleEditor();
   }
   ImGui::End();
   if (open) *open = o ? 1 : 0;
   return FIG_OK;
   FIG_CATCH
}

// Scoped style changes: remember the bytes a push overwrites, restore them on pop. Any colour or variable of either
// library (the whole generated field table, not only Dear ImGui's ImGuiStyleVar subset).
void remember(std::vector<state_t::saved_t> &stack, unsigned char *where, size_t size) {
   state_t::saved_t s;
   s.where = where;
   s.was.assign(where, where + size);
   stack.push_back(std::move(s));
}

int fig_push_style_color(int lib, const char *name, int name_len, const float *rgba) {
   FIG_TRY
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   if (lib != 0 && lib != 1) return fail(FIG_ERR_ARGUMENT, "push style colour: unknown library");
   const std::string n(name, name_len > 0 ? static_cast<size_t>(name_len) : 0);
   const int i = style_color_index(lib, n);
   if (i < 0) return fail(FIG_ERR_ARGUMENT, "push style colour: unknown name \"" + n + "\"");
   for (int k = 0; k < 4; ++k)
      if (!(rgba[k] >= 0.0f && rgba[k] <= 1.0f)) return fail(FIG_ERR_ARGUMENT, "push style colour: components must be in [0, 1]");
   ImVec4 &c = lib == 0 ? ImGui::GetStyle().Colors[i] : ImPlot::GetStyle().Colors[i];
   remember(st.pushed_colors, reinterpret_cast<unsigned char *>(&c), sizeof(ImVec4));
   c = ImVec4(rgba[0], rgba[1], rgba[2], rgba[3]);
   return FIG_OK;
   FIG_CATCH
}

int fig_push_style_var(int lib, const char *name, int name_len, const double *values, int count) {
   FIG_TRY
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   if (lib != 0 && lib != 1) return fail(FIG_ERR_ARGUMENT, "push style variable: unknown library");
   const std::string n(name, name_len > 0 ? static_cast<size_t>(name_len) : 0);
   const figure_style::field *f = style_field(lib, n);
   if (!f) return fail(FIG_ERR_ARGUMENT, "push style variable: unknown name \"" + n + "\"");
   const int ncomp = f->kind == figure_style::FIG_STYLE_VEC2 ? 2 : 1;
   if (count != ncomp)
      return fail(FIG_ERR_ARGUMENT, "push style variable \"" + n + "\" takes " + std::to_string(ncomp) + " value(s)");
   unsigned char *p = style_base(lib) + f->offset;
   const size_t size = f->kind == figure_style::FIG_STYLE_VEC2 ? sizeof(ImVec2)
                       : f->kind == figure_style::FIG_STYLE_BOOL ? sizeof(bool)
                       : f->kind == figure_style::FIG_STYLE_FLOAT ? sizeof(float) : sizeof(int);
   remember(st.pushed_vars, p, size);
   const std::vector<double> v(values, values + count);
   write_var(style_base(lib), *f, v);
   return FIG_OK;
   FIG_CATCH
}

int fig_pop_style(int vars, int n) {
   FIG_TRY
   std::vector<state_t::saved_t> &stack = vars ? st.pushed_vars : st.pushed_colors;
   if (n < 1 || static_cast<size_t>(n) > stack.size())
      return fail(FIG_ERR_STATE, std::string(vars ? "pop style variable" : "pop style colour") + ": " +
                                     std::to_string(n) + " pop(s) for " + std::to_string(stack.size()) + " push(es)");
   for (int k = 0; k < n; ++k) {
      const state_t::saved_t &s = stack.back();
      std::memcpy(s.where, s.was.data(), s.was.size());
      stack.pop_back();
   }
   return FIG_OK;
   FIG_CATCH
}

int fig_set_font(const char *name, int name_len, double size) {
   FIG_TRY
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   const std::string n(name, name_len > 0 ? static_cast<size_t>(name_len) : 0);
   if (size < 0.0 || size > 200.0) return fail(FIG_ERR_ARGUMENT, "set_font: size must be in (0, 200] pixels");
   std::string err;
   ImFont *f = get_font(n, err);
   if (!f) return fail(err.rfind("cannot read", 0) == 0 ? FIG_ERR_FAILED : FIG_ERR_ARGUMENT, "set_font: " + err);
   ImGui::GetIO().FontDefault = f;
   st.font = n;
   if (size > 0.0) ImGui::GetStyle().FontSizeBase = static_cast<float>(size);
   return FIG_OK;
   FIG_CATCH
}

int fig_push_font(const char *name, int name_len, double size) {
   FIG_TRY
   if (!st.in_frame) return fail(FIG_ERR_STATE, "ig_push_font: no frame is open");
   const std::string n(name, name_len > 0 ? static_cast<size_t>(name_len) : 0);
   if (size < 0.0 || size > 200.0) return fail(FIG_ERR_ARGUMENT, "ig_push_font: size must be in (0, 200] pixels");
   ImFont *f = nullptr;
   if (!n.empty()) {
      std::string err;
      f = get_font(n, err);
      if (!f) return fail(err.rfind("cannot read", 0) == 0 ? FIG_ERR_FAILED : FIG_ERR_ARGUMENT, "ig_push_font: " + err);
   }
   ImGui::PushFont(f, size > 0.0 ? static_cast<float>(size) : 0.0f); // 0: the current size; null font: the current
   return FIG_OK;
   FIG_CATCH
}

int fig_pop_font(void) {
   FIG_TRY
   if (!st.in_frame) return fail(FIG_ERR_STATE, "ig_pop_font: no frame is open");
   ImGui::PopFont();
   return FIG_OK;
   FIG_CATCH
}

int fig_style_color(int lib, const char *name, int name_len, int set, float *rgba) {
   FIG_TRY
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   if (lib != 0 && lib != 1) return fail(FIG_ERR_ARGUMENT, "style colour: unknown library");
   const std::string n(name, name_len > 0 ? static_cast<size_t>(name_len) : 0);
   const int i = style_color_index(lib, n);
   if (i < 0)
      return fail(FIG_ERR_ARGUMENT, std::string("style colour: unknown name \"") + n + "\" for " +
                                        (lib == 0 ? "Dear ImGui (ImGuiCol_*)" : "ImPlot (ImPlotCol_*)"));
   if (set) {
      for (int k = 0; k < 4; ++k)
         if (!(rgba[k] >= 0.0f && rgba[k] <= 1.0f)) return fail(FIG_ERR_ARGUMENT, "style colour: components must be in [0, 1]");
      const ImVec4 c(rgba[0], rgba[1], rgba[2], rgba[3]);
      if (lib == 0) ImGui::GetStyle().Colors[i] = c;
      else ImPlot::GetStyle().Colors[i] = c;
   } else {
      // ImPlot's automatic colours (derived from Dear ImGui's) are resolved, as ImPlot would draw them
      const ImVec4 c = lib == 0 ? ImGui::GetStyle().Colors[i] : ImPlot::GetStyleColorVec4(i);
      rgba[0] = c.x;
      rgba[1] = c.y;
      rgba[2] = c.z;
      rgba[3] = c.w;
   }
   return FIG_OK;
   FIG_CATCH
}

int fig_style_var(int lib, const char *name, int name_len, int set, double *values, int *count) {
   FIG_TRY
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   if (lib != 0 && lib != 1) return fail(FIG_ERR_ARGUMENT, "style variable: unknown library");
   const std::string n(name, name_len > 0 ? static_cast<size_t>(name_len) : 0);
   const figure_style::field *f = style_field(lib, n);
   if (!f)
      return fail(FIG_ERR_ARGUMENT, std::string("style variable: unknown name \"") + n + "\" for " +
                                        (lib == 0 ? "Dear ImGui (ImGuiStyle)" : "ImPlot (ImPlotStyle)"));
   unsigned char *p = style_base(lib) + f->offset;
   const int ncomp = f->kind == figure_style::FIG_STYLE_VEC2 ? 2 : 1;
   if (set) {
      if (*count != ncomp)
         return fail(FIG_ERR_ARGUMENT, "style variable \"" + n + "\" takes " + std::to_string(ncomp) + " value(s)");
      switch (f->kind) {
      case figure_style::FIG_STYLE_FLOAT: *reinterpret_cast<float *>(p) = static_cast<float>(values[0]); break;
      case figure_style::FIG_STYLE_VEC2:
         *reinterpret_cast<ImVec2 *>(p) = ImVec2(static_cast<float>(values[0]), static_cast<float>(values[1]));
         break;
      case figure_style::FIG_STYLE_BOOL: *reinterpret_cast<bool *>(p) = values[0] != 0.0; break;
      default: *reinterpret_cast<int *>(p) = static_cast<int>(values[0]); break;
      }
   } else {
      *count = ncomp;
      switch (f->kind) {
      case figure_style::FIG_STYLE_FLOAT: values[0] = *reinterpret_cast<float *>(p); break;
      case figure_style::FIG_STYLE_VEC2:
         values[0] = reinterpret_cast<ImVec2 *>(p)->x;
         values[1] = reinterpret_cast<ImVec2 *>(p)->y;
         break;
      case figure_style::FIG_STYLE_BOOL: values[0] = *reinterpret_cast<bool *>(p) ? 1.0 : 0.0; break;
      default: values[0] = *reinterpret_cast<int *>(p); break;
      }
   }
   return FIG_OK;
   FIG_CATCH
}

int fig_set_ini_file(const char *path, int path_len) {
   FIG_TRY
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   if (ImGui::GetFrameCount() > 0) return fail(FIG_ERR_STATE, "the ini file must be set before the first frame");
   st.ini_file.assign(path, path_len > 0 ? static_cast<size_t>(path_len) : 0);
   ImGui::GetIO().IniFilename = st.ini_file.empty() ? nullptr : st.ini_file.c_str();
   return FIG_OK;
   FIG_CATCH
}

void fig_set_lazy(int enabled, double max_wait_s) {
   st.lazy = enabled != 0;
   st.max_wait_ms = max_wait_s > 0.0 ? static_cast<int>(max_wait_s * 1000.0) : 0;
}

void fig_set_remote_fps(double max_fps) { st.remote_min_dt = max_fps > 0.0 ? 1.0 / max_fps : 0.0; }

void fig_set_remote_compress(int mode) { figure_remote::set_compression(mode); }

void fig_set_remote_token(const char *token, int token_len) {
   figure_remote::set_token(std::string(token, token_len > 0 ? static_cast<size_t>(token_len) : 0));
}

int fig_remote_token(char *buf, int buf_len) {
   const std::string &t = figure_remote::token();
   const int n = static_cast<int>(t.size());
   if (buf_len > 0) std::memcpy(buf, t.data(), static_cast<size_t>(std::min(n, buf_len)));
   return n;
}

void fig_request_frames(int n) {
   if (n > st.frames_left) st.frames_left = n;
}

double fig_content_scale(void) { return st.scale; }

void apply_test_input(); // figure_testing's queued input (defined with the synthetic input below)

int fig_begin_frame(int *running) {
   FIG_TRY
   *running = 0;
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   if (st.in_frame) return fail(FIG_ERR_STATE, "begin_frame called twice without end_frame");
   *running = 1;
   if (st.m == mode::headless) {
      ImGui::GetIO().DeltaTime = 1.0f / 60.0f;
      apply_test_input();
      ImGui::NewFrame();
      st.in_frame = true;
      return FIG_OK;
   }
   if (st.m == mode::remote) {
      // the same lazy redraw as a window, waiting on the network instead of SDL's event queue; then the frame-rate
      // cap (a browser has no vsync to pace the program): input arriving meanwhile is gathered into the next frame
      using clock = std::chrono::steady_clock;
      // wait for input up to max_wait when idle, or, when a frame was skipped for a slow client, until the queue
      // drains (serve returns early then); otherwise go on at once
      const bool pending = figure_remote::frame_pending(), busy = figure_remote::queue_busy();
      const bool wait = pending ? busy : st.lazy && st.frames_left <= 0;
      bool got = figure_remote::serve(wait ? st.max_wait_ms : 0);
      const auto next = st.last_frame + std::chrono::duration_cast<clock::duration>(
                                           std::chrono::duration<double>(st.remote_min_dt));
      for (auto t = clock::now(); t < next; t = clock::now())
         got = figure_remote::serve(static_cast<int>(
                  std::chrono::duration_cast<std::chrono::milliseconds>(next - t).count()) + 1) || got;
      while (figure_remote::serve(0)) got = true; // drain what else arrived
      if (got) st.frames_left = 3;
      else if (st.frames_left > 0) --st.frames_left;
      const auto now = clock::now();
      const float dt = std::chrono::duration<float>(now - st.last_frame).count();
      st.last_frame = now;
      ImGui::GetIO().DeltaTime = dt > 0.0f ? dt : 1.0e-4f;
      apply_test_input();
      ImGui::NewFrame();
      st.in_frame = true;
      return FIG_OK;
   }
   SDL_Event ev;
   bool      got = false;
   if (rs.on) {
      const Uint64 now = SDL_GetTicksNS();
      redraw_stats_flush(now);
      rs.t_mark = now;
   }
   auto handle = [&](const SDL_Event &e) {
      if (rs.on) ++rs.events[e.type];
      if (!cap.on) ImGui_ImplSDL3_ProcessEvent(&e); // capture: the program's scripted input only
      if (e.type == SDL_EVENT_QUIT) *running = 0;
      if (e.type == SDL_EVENT_WINDOW_CLOSE_REQUESTED && e.window.windowID == SDL_GetWindowID(st.window)) *running = 0;
      got = true;
   };
   // Lazy redraw: once ImGui has settled, sleep until an event arrives or max_wait elapses (a periodic refresh that
   // lets live data from the application appear); never spin at the display rate while idle.
   if (cap.on && cap.count >= 0 && cap.written >= cap.count) *running = 0; // capture: enough frames written
   if (st.lazy && st.frames_left <= 0 && !cap.on) {
      if (SDL_WaitEventTimeout(&ev, st.max_wait_ms))
         handle(ev);
      else if (rs.on)
         ++rs.timeouts;
   }
   while (SDL_PollEvent(&ev)) handle(ev);
   if (!*running) return FIG_OK; // quitting: no frame is opened
   if (got) st.frames_left = 3;
   else if (st.frames_left > 0) --st.frames_left;
   if (SDL_GetWindowFlags(st.window) & SDL_WINDOW_MINIMIZED) SDL_Delay(10);
   if (rs.on) {
      const Uint64 now = SDL_GetTicksNS();
      rs.wait += now - rs.t_mark;
      rs.t_mark = now;
   }
   ImGui_ImplOpenGL3_NewFrame();
   if (cap.on) { // what ImGui_ImplSDL3_NewFrame does, without the real mouse, keyboard focus or wall clock
      ImGuiIO &io = ImGui::GetIO();
      int w, h, fw, fh;
      SDL_GetWindowSize(st.window, &w, &h);
      SDL_GetWindowSizeInPixels(st.window, &fw, &fh);
      io.DisplaySize = ImVec2(static_cast<float>(w), static_cast<float>(h));
      if (w > 0 && h > 0) io.DisplayFramebufferScale = ImVec2(static_cast<float>(fw) / w, static_cast<float>(fh) / h);
      io.DeltaTime = cap.dt;
      io.MouseDrawCursor = !cap.events.empty();
      capture_apply_input();
   } else {
      ImGui_ImplSDL3_NewFrame();
   }
   apply_test_input();
   ImGui::NewFrame();
   st.in_frame = true;
   return FIG_OK;
   FIG_CATCH
}

int fig_end_frame(void) {
   FIG_TRY
   if (!st.in_frame) return fail(FIG_ERR_STATE, "end_frame without begin_frame");
   st.in_frame = false;
   ImGui::Render();
   if (st.m == mode::headless) {
      headless_textures();
      return FIG_OK;
   }
   if (st.m == mode::remote) {
      figure_remote::send_frame(ImGui::GetDrawData());
      return FIG_OK;
   }
   Uint64 t_render = 0;
   if (rs.on) {
      t_render = SDL_GetTicksNS();
      rs.build += t_render - rs.t_mark;
   }
   const ImGuiIO &io = ImGui::GetIO();
   p_glViewport(0, 0, static_cast<int>(io.DisplaySize.x * io.DisplayFramebufferScale.x),
                static_cast<int>(io.DisplaySize.y * io.DisplayFramebufferScale.y));
   p_glClearColor(st.clear[0], st.clear[1], st.clear[2], 1.0f);
   p_glClear(GL_COLOR_BUFFER_BIT_);
   ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
   if (cap.on) {
      if (cap.frame >= cap.from && (cap.count < 0 || cap.written < cap.count))
         capture_write(static_cast<int>(io.DisplaySize.x * io.DisplayFramebufferScale.x),
                       static_cast<int>(io.DisplaySize.y * io.DisplayFramebufferScale.y));
      ++cap.frame;
   }
   Uint64 t_swap = 0;
   if (rs.on) t_swap = SDL_GetTicksNS();
   SDL_GL_SwapWindow(st.window);
   if (rs.on) {
      const Uint64 now = SDL_GetTicksNS();
      rs.render += t_swap - t_render;
      rs.swap += now - t_swap;
      ++rs.frames;
   }
   return FIG_OK;
   FIG_CATCH
}

void fig_shutdown(void) {
   try {
      if (st.in_frame) {
         ImGui::EndFrame();
         st.in_frame = false;
      }
      if (st.m == mode::window) {
         for (const auto &t : st.textures) {
            const unsigned int name = static_cast<unsigned int>(t.first);
            p_glDeleteTextures(1, &name);
         }
         ImGui_ImplOpenGL3_Shutdown();
         ImGui_ImplSDL3_Shutdown();
      }
      destroy_contexts();
      if (st.m == mode::remote) figure_remote::stop();
      if (st.m == mode::window) {
         SDL_GL_DestroyContext(st.gl);
         SDL_DestroyWindow(st.window);
         SDL_Quit();
      }
   } catch (...) {
   }
   st = state_t{};
   cap = capture_t{};
}

int fig_texture_create(int width, int height, int smooth, unsigned long long *id) {
   FIG_TRY
   *id = 0;
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   if (width <= 0 || height <= 0) return fail(FIG_ERR_ARGUMENT, "texture size must be positive");
   if (st.m == mode::headless) {
      *id = st.next_headless_texture++;
   } else if (st.m == mode::remote) {
      *id = figure_remote::new_texture_id();
   } else {
      unsigned int name = 0;
      p_glGenTextures(1, &name);
      if (name == 0) return fail(FIG_ERR_FAILED, "glGenTextures returned no texture");
      p_glBindTexture(GL_TEXTURE_2D_, name);
      const int filter = static_cast<int>(smooth ? GL_LINEAR_ : GL_NEAREST_);
      p_glTexParameteri(GL_TEXTURE_2D_, GL_TEXTURE_MIN_FILTER_, filter);
      p_glTexParameteri(GL_TEXTURE_2D_, GL_TEXTURE_MAG_FILTER_, filter);
      p_glTexParameteri(GL_TEXTURE_2D_, GL_TEXTURE_WRAP_S_, static_cast<int>(GL_CLAMP_TO_EDGE_));
      p_glTexParameteri(GL_TEXTURE_2D_, GL_TEXTURE_WRAP_T_, static_cast<int>(GL_CLAMP_TO_EDGE_));
      p_glTexImage2D(GL_TEXTURE_2D_, 0, static_cast<int>(GL_RGBA_), width, height, 0, GL_RGBA_, GL_UNSIGNED_BYTE_,
                     nullptr);
      *id = name;
   }
   st.textures[*id] = {width, height, smooth != 0};
   return FIG_OK;
   FIG_CATCH
}

int fig_texture_update(unsigned long long id, int width, int height, const unsigned char *rgba) {
   FIG_TRY
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   const auto t = st.textures.find(id);
   if (t == st.textures.end()) return fail(FIG_ERR_ARGUMENT, "unknown texture (destroyed, or never created)");
   if (width != t->second.width || height != t->second.height)
      return fail(FIG_ERR_ARGUMENT, "pixel array size differs from the texture size");
   if (st.m == mode::window) {
      // tightly packed RGBA rows straight from the caller's array: one upload, no staging copy
      p_glBindTexture(GL_TEXTURE_2D_, static_cast<unsigned int>(id));
      p_glPixelStorei(GL_UNPACK_ROW_LENGTH_, 0);
      p_glPixelStorei(GL_UNPACK_ALIGNMENT_, 1);
      p_glTexSubImage2D(GL_TEXTURE_2D_, 0, 0, 0, width, height, GL_RGBA_, GL_UNSIGNED_BYTE_, rgba);
   } else if (st.m == mode::remote) {
      figure_remote::texture_update(id, width, height, rgba, t->second.smooth); // kept, and sent to the browser
   }
   return FIG_OK;
   FIG_CATCH
}

void fig_texture_sampling(int plot, int from_texture) {
   // The OpenGL3 backend samples every texture through its own (linear) sampler object, which overrides the
   // glTexParameteri filter of user textures: around a user image, ask it to use the texture's own filter, then
   // restore its render state. No-op without a renderer backend (headless).
   try {
      if (!ImGui::GetCurrentContext()) return;
      const ImGuiPlatformIO &pio = ImGui::GetPlatformIO();
      const ImDrawCallback cb = from_texture ? pio.DrawCallback_SetSamplerFromTex : pio.DrawCallback_ResetRenderState;
      if (cb == nullptr) return;
      ImDrawList *dl = plot ? ImPlot::GetPlotDrawList() : ImGui::GetWindowDrawList();
      dl->AddCallback(cb, nullptr);
   } catch (...) {
   }
}

void fig_texture_destroy(unsigned long long id) {
   try {
      const auto t = st.textures.find(id);
      if (t == st.textures.end()) return;
      if (st.m == mode::window) {
         const unsigned int name = static_cast<unsigned int>(id);
         p_glDeleteTextures(1, &name);
      } else if (st.m == mode::remote) {
         figure_remote::texture_destroy(id);
      }
      st.textures.erase(t);
   } catch (...) {
   }
}

int fig_set_docking(int enabled) {
   FIG_TRY
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   ImGuiIO &io = ImGui::GetIO();
   if (enabled) io.ConfigFlags |= ImGuiConfigFlags_DockingEnable;
   else io.ConfigFlags &= ~ImGuiConfigFlags_DockingEnable;
   return FIG_OK;
   FIG_CATCH
}

unsigned int fig_dock_id(const char *name, int name_len) {
   if (!ImGui::GetCurrentContext()) return 0;
   return ImHashStr(name, static_cast<size_t>(name_len > 0 ? name_len : 0));
}

int fig_dock_space(unsigned int id, int flags) {
   FIG_TRY
   if (!st.in_frame) return fail(FIG_ERR_STATE, "ig_dock_space: no frame is open");
   if (!(ImGui::GetIO().ConfigFlags & ImGuiConfigFlags_DockingEnable))
      return fail(FIG_ERR_STATE, "ig_dock_space: docking is off (app%set_docking)");
   // over the whole display; its central node lets the window background through when empty
   ImGui::DockSpaceOverViewport(id, ImGui::GetMainViewport(), flags | ImGuiDockNodeFlags_PassthruCentralNode);
   return FIG_OK;
   FIG_CATCH
}

int fig_dock_layout_begin(unsigned int id, int *needed) {
   FIG_TRY
   *needed = 0;
   if (!st.in_frame) return fail(FIG_ERR_STATE, "ig_dock_layout_begin: no frame is open");
   if (ImGui::DockBuilderGetNode(id) != nullptr) return FIG_OK; // laid out already (this run, or an ini file)
   const ImGuiViewport *vp = ImGui::GetMainViewport();
   ImGui::DockBuilderRemoveNode(id);
   ImGui::DockBuilderAddNode(id, ImGuiDockNodeFlags_DockSpace);
   ImGui::DockBuilderSetNodePos(id, vp->WorkPos);
   ImGui::DockBuilderSetNodeSize(id, vp->WorkSize);
   *needed = 1;
   return FIG_OK;
   FIG_CATCH
}

int fig_dock_split(unsigned int id, int direction, double fraction, unsigned int *id_at_dir, unsigned int *id_other) {
   FIG_TRY
   if (direction < ImGuiDir_Left || direction > ImGuiDir_Down)
      return fail(FIG_ERR_ARGUMENT, "ig_dock_split: direction must be left, right, up or down");
   if (!(fraction > 0.0 && fraction < 1.0)) return fail(FIG_ERR_ARGUMENT, "ig_dock_split: fraction must be in (0, 1)");
   if (ImGui::DockBuilderGetNode(id) == nullptr) return fail(FIG_ERR_ARGUMENT, "ig_dock_split: unknown dock node");
   ImGuiID a = 0, b = 0;
   ImGui::DockBuilderSplitNode(id, static_cast<ImGuiDir>(direction), static_cast<float>(fraction), &a, &b);
   *id_at_dir = a;
   *id_other = b;
   return FIG_OK;
   FIG_CATCH
}

int fig_dock_window(const char *name, int name_len, unsigned int id) {
   FIG_TRY
   if (ImGui::DockBuilderGetNode(id) == nullptr) return fail(FIG_ERR_ARGUMENT, "ig_dock_window: unknown dock node");
   const std::string n(name, name_len > 0 ? static_cast<size_t>(name_len) : 0);
   ImGui::DockBuilderDockWindow(n.c_str(), id);
   return FIG_OK;
   FIG_CATCH
}

int fig_dock_layout_end(unsigned int id) {
   FIG_TRY
   if (ImGui::DockBuilderGetNode(id) == nullptr) return fail(FIG_ERR_ARGUMENT, "ig_dock_layout_end: unknown dock node");
   ImGui::DockBuilderFinish(id);
   return FIG_OK;
   FIG_CATCH
}

int fig_window_dock(unsigned int *id, int *docked) {
   FIG_TRY
   *id = ImGui::GetWindowDockID();
   *docked = ImGui::IsWindowDocked() ? 1 : 0;
   return FIG_OK;
   FIG_CATCH
}

// ---- Synthetic input (figure_testing) --------------------------------------------------------------------------------
// Queued into Dear ImGui's input queue, as real input is: with input trickling (Dear ImGui's default) a move, a press
// and a release queued together are applied over the next frames, so a click needs no per-frame scheduling.

// Events are kept in FIGURE's queue and handed to Dear ImGui at the start of the next frame, up to the next frame
// boundary (fig_input_next_frame): what is queued between two boundaries arrives in one frame (and Dear ImGui
// trickles it further, one change of each kind per frame); a boundary makes the next events wait one frame more.
int queue_input(const state_t::input_t &e) {
   if (!ImGui::GetCurrentContext()) return fail(FIG_ERR_STATE, "figure is not initialized");
   st.test_input.push_back(e);
   return FIG_OK;
}

// At the start of a frame (before NewFrame): hand the queued events to Dear ImGui, up to the first boundary.
void apply_test_input() {
   if (st.test_input.empty()) return;
   ImGuiIO &io = ImGui::GetIO();
   size_t i = 0;
   for (; i < st.test_input.size(); ++i) {
      const state_t::input_t &e = st.test_input[i];
      if (e.kind == 0) {
         ++i; // the boundary is consumed: what follows waits for the next frame
         break;
      }
      switch (e.kind) {
      case 1: io.AddMousePosEvent(e.x, e.y); break;
      case 2: io.AddMouseButtonEvent(e.a, e.b != 0); break;
      case 3: io.AddMouseWheelEvent(e.x, e.y); break;
      case 4: io.AddKeyEvent(static_cast<ImGuiKey>(e.a), e.b != 0); break;
      default: io.AddInputCharactersUTF8(e.text.c_str()); break;
      }
   }
   st.test_input.erase(st.test_input.begin(), st.test_input.begin() + static_cast<long>(i));
}

int fig_input_next_frame(void) {
   state_t::input_t e;
   e.kind = 0;
   return queue_input(e);
}

int fig_input_mouse_pos(float x, float y) {
   state_t::input_t e;
   e.kind = 1;
   e.x = x;
   e.y = y;
   return queue_input(e);
}

int fig_input_mouse_button(int button, int down) {
   if (button < 0 || button > 2) return fail(FIG_ERR_ARGUMENT, "mouse button: 0 left, 1 right, 2 middle");
   state_t::input_t e;
   e.kind = 2;
   e.a = button;
   e.b = down != 0;
   return queue_input(e);
}

int fig_input_wheel(float dx, float dy) {
   state_t::input_t e;
   e.kind = 3;
   e.x = dx;
   e.y = dy;
   return queue_input(e);
}

// Keys by name: a-z, 0-9, enter, tab, backspace, delete, escape, space, left, right, up, down, home, end, pageup,
// pagedown, f1-f12, ctrl, shift, alt, super; ImGuiKey_None if unknown.
ImGuiKey key_by_name(const std::string &n) {
   if (n.size() == 1 && n[0] >= 'a' && n[0] <= 'z') return static_cast<ImGuiKey>(ImGuiKey_A + (n[0] - 'a'));
   if (n.size() == 1 && n[0] >= '0' && n[0] <= '9') return static_cast<ImGuiKey>(ImGuiKey_0 + (n[0] - '0'));
   if (n.size() >= 2 && n.size() <= 3 && n[0] == 'f') {
      const int k = std::atoi(n.c_str() + 1);
      if (k >= 1 && k <= 12) return static_cast<ImGuiKey>(ImGuiKey_F1 + (k - 1));
   }
   static const std::pair<const char *, ImGuiKey> named[] = {
      {"enter", ImGuiKey_Enter},     {"tab", ImGuiKey_Tab},       {"backspace", ImGuiKey_Backspace},
      {"delete", ImGuiKey_Delete},   {"escape", ImGuiKey_Escape}, {"space", ImGuiKey_Space},
      {"left", ImGuiKey_LeftArrow},  {"right", ImGuiKey_RightArrow}, {"up", ImGuiKey_UpArrow},
      {"down", ImGuiKey_DownArrow},  {"home", ImGuiKey_Home},     {"end", ImGuiKey_End},
      {"pageup", ImGuiKey_PageUp},   {"pagedown", ImGuiKey_PageDown}, {"ctrl", ImGuiMod_Ctrl},
      {"shift", ImGuiMod_Shift},     {"alt", ImGuiMod_Alt},       {"super", ImGuiMod_Super}};
   for (const auto &k : named)
      if (n == k.first) return k.second;
   return ImGuiKey_None;
}

int fig_input_key(const char *name, int name_len, int down) {
   if (!ImGui::GetCurrentContext()) return fail(FIG_ERR_STATE, "figure is not initialized");
   const std::string n(name, name_len > 0 ? static_cast<size_t>(name_len) : 0);
   const ImGuiKey k = key_by_name(n);
   if (k == ImGuiKey_None) return fail(FIG_ERR_ARGUMENT, "key: unknown name \"" + n + "\"");
   state_t::input_t e;
   e.kind = 4;
   e.a = static_cast<int>(k);
   e.b = down != 0;
   return queue_input(e);
}

int fig_input_text(const char *text, int text_len) {
   state_t::input_t e;
   e.kind = 5;
   e.text.assign(text, text_len > 0 ? static_cast<size_t>(text_len) : 0);
   return queue_input(e);
}

// A window's rectangle, by its name (as passed to Begin), as drawn in the last frame; found 0 if no such window.
int fig_window_rect(const char *name, int name_len, float *rect, int *found) {
   if (!ImGui::GetCurrentContext()) return fail(FIG_ERR_STATE, "figure is not initialized");
   const std::string n(name, name_len > 0 ? static_cast<size_t>(name_len) : 0);
   ImGuiWindow *w = ImGui::FindWindowByName(n.c_str());
   *found = w ? 1 : 0;
   if (w) {
      rect[0] = w->Pos.x;
      rect[1] = w->Pos.y;
      rect[2] = w->Pos.x + w->Size.x;
      rect[3] = w->Pos.y + w->Size.y;
   }
   return FIG_OK;
}

void fig_input_mouse(float x, float y, int left_down) {
   if (!ImGui::GetCurrentContext()) return;
   ImGuiIO &io = ImGui::GetIO();
   io.AddMousePosEvent(x, y);
   io.AddMouseButtonEvent(ImGuiMouseButton_Left, left_down != 0);
}

} // extern "C"
