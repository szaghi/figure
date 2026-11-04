// FIGURE native glue: SDL3 window + OpenGL3 renderer + Dear ImGui/ImPlot contexts, behind the C ABI of figure_native.h.
#include "figure_native.h"
#include "figure_remote.h"

#include "imgui.h"
#include "imgui_impl_opengl3.h"
#include "imgui_impl_sdl3.h"
#include "implot.h"

#include <SDL3/SDL.h>
// The program's main is the Fortran one, not SDL_main: SDL_MAIN_HANDLED keeps SDL_main.h from redefining main, and
// fig_init declares the entry point ready (SDL_SetMainReady) before SDL_Init, as SDL documents for this case.
#define SDL_MAIN_HANDLED
#include <SDL3/SDL_main.h>

#include <cstdio>
#include <cstdlib>
#include <chrono>
#include <algorithm>
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
   std::string   ini_file;        // where Dear ImGui keeps window positions and sizes; empty: nowhere (the default)
   struct texture_t {
      int  width = 0, height = 0;
      bool smooth = false;
   };
   std::chrono::steady_clock::time_point last_frame; // remote mode: the frame clock (no SDL)
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

void create_contexts() {
   IMGUI_CHECKVERSION();
   ImGui::CreateContext();
   ImPlot::CreateContext();
   ImGuiIO &io = ImGui::GetIO();
   // No docking: the pinned cimgui tag (1.93dock) is generated from the non-docking Dear ImGui (see plans/plan.md).
   io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;
   // No imgui.ini by default: a layout restored from whatever directory the program runs in silently overrides the
   // positions and sizes the program sets on first use. fig_set_ini_file opts in.
   io.IniFilename = nullptr;
   ImGui::StyleColorsDark();
}

void destroy_contexts() {
   if (ImPlot::GetCurrentContext()) ImPlot::DestroyContext();
   if (ImGui::GetCurrentContext()) ImGui::DestroyContext();
}

// ---- Styles ---------------------------------------------------------------------------------------------------
// A style sets Dear ImGui's colours, ImPlot's (derived from them) and its colormap of line colours, and the window's
// background. "dark", "light", "classic": Dear ImGui's own, with ImPlot's default colormap (Deep). "seal" (the
// default) and "seal-light": FIGURE's, from the palette of its mark (docs/brand/marks.py): ink, paper and one vermilion, spent on
// what the user touches (slider grabs, check marks, pressed buttons) and on the first plotted line.

ImVec4 hex(unsigned int rgb, float alpha = 1.0f) {
   return ImVec4(static_cast<float>((rgb >> 16) & 0xFF) / 255.0f, static_cast<float>((rgb >> 8) & 0xFF) / 255.0f,
                 static_cast<float>(rgb & 0xFF) / 255.0f, alpha);
}

struct seal_palette_t {
   unsigned int text, text_disabled, window, popup, border, frame, frame_hovered, frame_active, title, title_active,
      scroll_grab, scroll_hovered, scroll_active, button, button_hovered, button_active, accent, accent_active,
      check, plot_lines, clear;
   bool         light;
   ImU32        lines[8];
};

const seal_palette_t SEAL_INK = {
   0xf6f2ea, 0x8a8278, 0x1c1915, 0x1c1915, 0x3a332c, 0x2a2520, 0x3a322b, 0x4a4038, 0x14120f, 0x2a2520,
   0x3a332c, 0x4a4038, 0x5a4e44, 0x3a322b, 0x952414, 0xc8321e, 0xd9442c, 0xf08a72,
   0xf08a72, 0xe9e2d4, 0x14120f, false,
   {0xe8664c, 0xe9e2d4, 0xc9a25a, 0x7f9cb0, 0x8fa06a, 0xa77a95, 0xd98b6a, 0xa3998c}};

const seal_palette_t SEAL_PAPER = {
   0x16130f, 0x8a8278, 0xfbf9f4, 0xffffff, 0xd8d0c2, 0xece6da, 0xe2dacb, 0xd8cfbf, 0xece6da, 0xe0d7c6,
   0xd8d0c2, 0xc8bfae, 0xb8ae9b, 0xe6e0d4, 0xf4c3b4, 0xf08a72, 0xc8321e, 0x952414,
   0xb42d1a, 0x16130f, 0xe6e0d4, true,
   {0xb42d1a, 0x16130f, 0xa57a2a, 0x4a6a80, 0x5f7a3a, 0x7d4a6a, 0xc0603a, 0x6b645a}};

void seal_colors(ImGuiStyle &s, const seal_palette_t &p) {
   if (p.light) ImGui::StyleColorsLight(&s);
   else ImGui::StyleColorsDark(&s);
   ImVec4 *c = s.Colors;
   c[ImGuiCol_Text] = hex(p.text);
   c[ImGuiCol_TextDisabled] = hex(p.text_disabled);
   c[ImGuiCol_WindowBg] = hex(p.window);
   c[ImGuiCol_ChildBg] = hex(p.window, 0.0f);
   c[ImGuiCol_PopupBg] = hex(p.popup, 0.97f);
   c[ImGuiCol_Border] = hex(p.border);
   c[ImGuiCol_BorderShadow] = hex(0, 0.0f);
   c[ImGuiCol_FrameBg] = hex(p.frame);
   c[ImGuiCol_FrameBgHovered] = hex(p.frame_hovered);
   c[ImGuiCol_FrameBgActive] = hex(p.frame_active);
   c[ImGuiCol_TitleBg] = hex(p.title);
   c[ImGuiCol_TitleBgActive] = hex(p.title_active);
   c[ImGuiCol_TitleBgCollapsed] = hex(p.title);
   c[ImGuiCol_MenuBarBg] = hex(p.title);
   c[ImGuiCol_ScrollbarBg] = hex(p.window);
   c[ImGuiCol_ScrollbarGrab] = hex(p.scroll_grab);
   c[ImGuiCol_ScrollbarGrabHovered] = hex(p.scroll_hovered);
   c[ImGuiCol_ScrollbarGrabActive] = hex(p.scroll_active);
   c[ImGuiCol_CheckMark] = hex(p.check);
   c[ImGuiCol_SliderGrab] = hex(p.accent);
   c[ImGuiCol_SliderGrabActive] = hex(p.accent_active);
   c[ImGuiCol_Button] = hex(p.button);
   c[ImGuiCol_ButtonHovered] = hex(p.button_hovered);
   c[ImGuiCol_ButtonActive] = hex(p.button_active);
   c[ImGuiCol_Header] = hex(p.button);
   c[ImGuiCol_HeaderHovered] = hex(p.frame_hovered);
   c[ImGuiCol_HeaderActive] = hex(p.frame_active);
   c[ImGuiCol_Separator] = hex(p.border);
   c[ImGuiCol_SeparatorHovered] = hex(p.accent, 0.78f);
   c[ImGuiCol_SeparatorActive] = hex(p.accent);
   c[ImGuiCol_ResizeGrip] = hex(p.accent, 0.20f);
   c[ImGuiCol_ResizeGripHovered] = hex(p.accent, 0.67f);
   c[ImGuiCol_ResizeGripActive] = hex(p.accent, 0.95f);
   c[ImGuiCol_InputTextCursor] = hex(p.text);
   c[ImGuiCol_Tab] = hex(p.frame);
   c[ImGuiCol_TabHovered] = hex(p.frame_hovered);
   c[ImGuiCol_TabSelected] = hex(p.frame_active);
   c[ImGuiCol_TabSelectedOverline] = hex(p.accent);
   c[ImGuiCol_TabDimmed] = hex(p.title);
   c[ImGuiCol_TabDimmedSelected] = hex(p.frame);
   c[ImGuiCol_TabDimmedSelectedOverline] = hex(p.border);
   c[ImGuiCol_PlotLines] = hex(p.plot_lines);
   c[ImGuiCol_PlotLinesHovered] = hex(p.accent_active);
   c[ImGuiCol_PlotHistogram] = hex(p.lines[2]);
   c[ImGuiCol_PlotHistogramHovered] = hex(p.accent_active);
   c[ImGuiCol_TableHeaderBg] = hex(p.frame);
   c[ImGuiCol_TableBorderStrong] = hex(p.border);
   c[ImGuiCol_TableBorderLight] = hex(p.frame);
   c[ImGuiCol_TextLink] = hex(p.check);
   c[ImGuiCol_TextSelectedBg] = hex(p.accent, 0.35f);
   c[ImGuiCol_TreeLines] = hex(p.border);
   c[ImGuiCol_DragDropTarget] = hex(p.accent_active);
   c[ImGuiCol_DragDropTargetBg] = hex(p.accent, 0.10f);
   c[ImGuiCol_UnsavedMarker] = hex(p.text);
   c[ImGuiCol_NavCursor] = hex(p.check);
   // the seal's edges are cut straight: no rounding anywhere
   s.WindowRounding = s.ChildRounding = s.FrameRounding = s.PopupRounding = 0.0f;
   s.ScrollbarRounding = s.GrabRounding = s.TabRounding = 0.0f;
}

// ImPlot colormap of a seal style, added once per context (ImPlot keeps colormaps for the context's life).
int seal_colormap(const char *name, const seal_palette_t &p) {
   int idx = ImPlot::GetColormapIndex(name);
   if (idx >= 0) return idx;
   ImU32 cols[8];
   for (int i = 0; i < 8; ++i) cols[i] = ImGui::ColorConvertFloat4ToU32(hex(p.lines[i]));
   return ImPlot::AddColormap(name, cols, 8, true);
}

// Apply a style by name; false if the name is unknown. Sizes keep the content scale, fonts are untouched.
bool apply_style(const std::string &name) {
   const ImGuiStyle old = ImGui::GetStyle();
   ImGuiStyle s;
   int cmap = ImPlotColormap_Deep;
   float clear[3] = {0.10f, 0.10f, 0.11f};
   if (name == "dark") {
      ImGui::StyleColorsDark(&s);
   } else if (name == "light") {
      ImGui::StyleColorsLight(&s);
      clear[0] = clear[1] = clear[2] = 0.80f;
   } else if (name == "classic") {
      ImGui::StyleColorsClassic(&s);
   } else if (name == "seal" || name == "seal-light") {
      const seal_palette_t &p = name == "seal" ? SEAL_INK : SEAL_PAPER;
      seal_colors(s, p);
      cmap = seal_colormap(name == "seal" ? "FIGURE seal" : "FIGURE seal light", p);
      const ImVec4 bg = hex(p.clear);
      clear[0] = bg.x;
      clear[1] = bg.y;
      clear[2] = bg.z;
   } else {
      return false;
   }
   s.ScaleAllSizes(st.scale);
   s.FontSizeBase = old.FontSizeBase;
   s.FontScaleMain = old.FontScaleMain;
   s.FontScaleDpi = old.FontScaleDpi;
   ImGui::GetStyle() = s;
   ImPlot::StyleColorsAuto();
   ImPlot::GetStyle().Colormap = cmap;
   for (int i = 0; i < 3; ++i) st.clear[i] = clear[i];
   if (st.m == mode::remote) figure_remote::set_background(clear[0], clear[1], clear[2]);
   return true;
}

// The style at initialisation: "seal", or the one named by the environment variable FIGURE_STYLE (a program's own
// set_style call comes later and wins). An unknown name is reported and ignored.
void apply_initial_style() {
   apply_style("seal");
   const char *v = std::getenv("FIGURE_STYLE");
   if (v && *v && !apply_style(v)) std::fprintf(stderr, "figure: FIGURE_STYLE=%s: unknown style, ignored\n", v);
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
   io.BackendPlatformName = "figure_remote";
   st.m = mode::remote;
   apply_initial_style();
   st.frames_left = 3;
   st.last_frame = std::chrono::steady_clock::now();
   return FIG_OK;
   FIG_CATCH
}

int fig_set_style(const char *name, int name_len) {
   FIG_TRY
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   const std::string n(name, name_len > 0 ? static_cast<size_t>(name_len) : 0);
   if (!apply_style(n))
      return fail(FIG_ERR_ARGUMENT, "set_style: unknown style \"" + n + "\" (dark, light, classic, seal, seal-light)");
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

void fig_request_frames(int n) {
   if (n > st.frames_left) st.frames_left = n;
}

double fig_content_scale(void) { return st.scale; }

int fig_begin_frame(int *running) {
   FIG_TRY
   *running = 0;
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   if (st.in_frame) return fail(FIG_ERR_STATE, "begin_frame called twice without end_frame");
   *running = 1;
   if (st.m == mode::headless) {
      ImGui::GetIO().DeltaTime = 1.0f / 60.0f;
      ImGui::NewFrame();
      st.in_frame = true;
      return FIG_OK;
   }
   if (st.m == mode::remote) {
      // the same lazy redraw as a window, waiting on the network instead of SDL's event queue
      bool got = figure_remote::serve(st.lazy && st.frames_left <= 0 ? st.max_wait_ms : 0);
      while (figure_remote::serve(0)) got = true; // drain what else arrived
      if (got) st.frames_left = 3;
      else if (st.frames_left > 0) --st.frames_left;
      const auto now = std::chrono::steady_clock::now();
      const float dt = std::chrono::duration<float>(now - st.last_frame).count();
      st.last_frame = now;
      ImGui::GetIO().DeltaTime = dt > 0.0f ? dt : 1.0e-4f;
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

void fig_input_mouse(float x, float y, int left_down) {
   if (!ImGui::GetCurrentContext()) return;
   ImGuiIO &io = ImGui::GetIO();
   io.AddMousePosEvent(x, y);
   io.AddMouseButtonEvent(ImGuiMouseButton_Left, left_down != 0);
}

} // extern "C"
