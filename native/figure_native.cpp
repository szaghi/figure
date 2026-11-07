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
// stb_truetype, as Dear ImGui bundles it, private to this file: an ICON_* rendered as the window's icon (set_icon)
#define STBRP_STATIC
#define STB_RECT_PACK_IMPLEMENTATION
#include "imstb_rectpack.h"
#define STBTT_STATIC
#define STB_TRUETYPE_IMPLEMENTATION
#include "imstb_truetype.h"

#include <SDL3/SDL.h>
// The program's main is the Fortran one, not SDL_main: SDL_MAIN_HANDLED keeps SDL_main.h from redefining main, and
// fig_init declares the entry point ready (SDL_SetMainReady) before SDL_Init, as SDL documents for this case.
#define SDL_MAIN_HANDLED
#include <SDL3/SDL_main.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <chrono>
#include <deque>
#include <algorithm>
#include <filesystem>
#include <cmath>
#include <atomic>
#include <exception>
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

namespace {

std::string last_error;

// Work off the frame loop (process readers, tasks) wakes it: window mode pushes an SDL event (SDL_PushEvent is safe
// from any thread); remote mode, which waits on its sockets, waits in slices of 10 ms while such work exists and
// ends the wait when woken; headless mode never waits.
std::atomic<bool> woken{false};       // fig_wake since the last frame began
std::atomic<int>  background{0};      // readers and workers alive
std::atomic<bool> sdl_events{false};  // window mode: SDL's event queue is up

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

// The window's frame drawn by FIGURE (decorations='figure'): the rectangles of its title bar in the last frame, in
// window coordinates (Dear ImGui's display coordinates), and the hit test answered from them.
struct frame_rect_t {
   float x0 = 0.0f, y0 = 0.0f, x1 = 0.0f, y1 = 0.0f;
   bool  contains(float x, float y) const { return x >= x0 && x < x1 && y >= y0 && y < y1; }
};
enum frame_part { FRAME_BAR, FRAME_ICON, FRAME_MENUS, FRAME_TITLE, FRAME_MINIMIZE, FRAME_MAXIMIZE, FRAME_CLOSE, FRAME_PARTS };
struct frame_geom_t {
   bool         valid = false;     // a bar was drawn
   float        width = 0.0f, height = 0.0f; // the window [window coordinates]
   float        border = 6.0f;     // the resize edges' thickness
   bool         maximized = false; // no resize edges
   frame_rect_t parts[FRAME_PARTS];
};
// Hit-test classes, the values of SDL_HitTestResult.
enum frame_hit_t {
   HIT_CLIENT, HIT_DRAG, HIT_RESIZE_TOPLEFT, HIT_RESIZE_TOP, HIT_RESIZE_TOPRIGHT, HIT_RESIZE_RIGHT,
   HIT_RESIZE_BOTTOMRIGHT, HIT_RESIZE_BOTTOM, HIT_RESIZE_BOTTOMLEFT, HIT_RESIZE_LEFT
};

// The class of the point (x, y): the edges and corners resize (none when maximized; a corner takes twice the edge's
// thickness along each side), the buttons and the menus are the program's (client), the rest of the bar (the icon,
// the title, the empty space) drags the window, everything else is the program's. A pure function of the geometry.
int frame_hit(const frame_geom_t &g, float x, float y) {
   if (!g.valid) return HIT_CLIENT;
   if (!g.maximized) {
      const float b = g.border, c = 2.0f * g.border;
      const bool l = x < b, r = x >= g.width - b, t = y < b, d = y >= g.height - b;
      const bool lc = x < c, rc = x >= g.width - c, tc = y < c, dc = y >= g.height - c;
      if ((t && lc) || (l && tc)) return HIT_RESIZE_TOPLEFT;
      if ((t && rc) || (r && tc)) return HIT_RESIZE_TOPRIGHT;
      if ((d && lc) || (l && dc)) return HIT_RESIZE_BOTTOMLEFT;
      if ((d && rc) || (r && dc)) return HIT_RESIZE_BOTTOMRIGHT;
      if (t) return HIT_RESIZE_TOP;
      if (d) return HIT_RESIZE_BOTTOM;
      if (l) return HIT_RESIZE_LEFT;
      if (r) return HIT_RESIZE_RIGHT;
   }
   for (int p : {FRAME_MINIMIZE, FRAME_MAXIMIZE, FRAME_CLOSE, FRAME_MENUS})
      if (g.parts[p].contains(x, y)) return HIT_CLIENT;
   if (g.parts[FRAME_BAR].contains(x, y)) return HIT_DRAG;
   return HIT_CLIENT;
}

struct state_t {
   mode          m = mode::none;
   SDL_Window   *window = nullptr;
   SDL_GLContext gl = nullptr;
   bool          in_frame = false;
   bool          lazy = true;     // wait for events instead of redrawing continuously
   bool          confirm_quit = false;   // a quit request is reported (fig_quit_requested) instead of ending the loop
   bool          quit_requested = false; // a request not yet read by fig_quit_requested
   bool          quit_now = false;       // fig_quit: the next fig_begin_frame ends the loop
   std::string   title;                  // the window's title (kept in every mode: fig_title)
   int           max_wait_ms = 500;
   int           frames_left = 3; // frames still to draw after the last event (ImGui settles in a few)
   float         scale = 1.0f;
   float         clear[3] = {0.10f, 0.10f, 0.11f}; // the window's background, behind the ImGui windows (the style's)
   std::string   style_base = "dark";              // base of the style in effect (what save_style writes against)
   std::string   look;                             // the look in effect (themes/looks); empty: Dear ImGui's geometry
   std::string   palette;                          // the palette in effect: a bundled name, "auto", "custom" (a
                                                   // [palette] table) or empty (the colours of a base)
   std::string   palette_resolved;                 // the bundled palette "auto" chose
   std::string   auto_dark = "seal", auto_light = "seal-light"; // the palettes of "auto"
   std::string   lines_name;                       // the line palette of the last set_style (kept by "auto")
   bool          has_roles = false;                // roles: those of the palette in effect
   figure_theme::color_t roles[figure_theme::ROLE_COUNT];
   struct frame_t {                                // decorations='figure': the window's frame drawn by FIGURE
      bool        on = false;                      // the title bar is drawn (window and headless modes)
      bool        buttons_left = false;            // the buttons on the left (macOS), else on the right
      bool        minimized = false, maximized = false; // headless: the actions recorded as state
      std::string icon_glyph;                      // set_icon(ICON_*): drawn in the bar
      unsigned int icon_tex = 0;                   // set_icon(image), window mode: the bar's texture
      int         icon_w = 0, icon_h = 0;
      frame_geom_t geom;                           // the last frame's rectangles: the hit test's answers
   } frame;
   int           system_theme = -1;                // the system's light (1) or dark (2) setting given by a test; -1: SDL's
   bool          system_theme_changed = false;     // a change to handle at the next frame (fig_input_system_theme)
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

// The frame options of the next init (fig_frame_options, called before fig_init and fig_init_headless).
struct frame_options_t {
   int decorations = 0; // 0 native, 1 figure
   int buttons = 0;     // 0 the platform's side, 1 right, 2 left
} frame_options;

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
//    <frame> key <name> [down|up]        a key, by the names of test_key: a-z, 0-9, f1-f12, enter, tab, backspace,
//                                        delete, escape, space, arrows, home, end, pageup, pagedown, ctrl, shift, alt,
//                                        super (press and release when down|up is omitted)
//    <frame> close                       the window's close button is clicked (a quit request)
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

// The keys of a capture script: the names of test_key (fig_input_key), defined further down.
extern "C" ImGuiKey key_by_name(const std::string &n);
ImGuiKey capture_key(const std::string &name) { return key_by_name(name); }

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
      } else if (e.what == "close") {
         ok = true;
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
      } else if (e.what == "close") { // the window's close button: a request with confirm_quit, else the end
         if (st.confirm_quit) st.quit_requested = true;
         else st.quit_now = true;
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

// Layouts (fig_save_layout, fig_load_layout): Dear ImGui's settings (windows' positions and sizes, docking nodes,
// tables' columns) as text. A load is applied before the next NewFrame: the settings cleared, then read, which rebuilds
// the dock nodes and applies the windows' settings to the windows that exist.
std::string layout_pending;
bool        layout_due = false;

void apply_layout() {
   if (!layout_due) return;
   layout_due = false;
   ImGui::ClearIniSettings();
   ImGui::LoadIniSettingsFromMemory(layout_pending.data(), layout_pending.size());
   layout_pending.clear();
}

// Save an image of a rectangle of the window (fig_save_image): asked for during a frame, written when that frame is
// rendered (fig_end_frame, before the swap), reported once by fig_image_result. Window mode only.
struct image_request_t {
   std::string path, error;
   float       x0 = 0.0f, y0 = 0.0f, x1 = 0.0f, y1 = 0.0f; // logical pixels
   int         state = 0;                                 // 0 none, 1 pending, 2 written, 3 failed
};
image_request_t img;

void image_write(const ImGuiIO &io) {
   const float sx = io.DisplayFramebufferScale.x, sy = io.DisplayFramebufferScale.y;
   const int fw = static_cast<int>(io.DisplaySize.x * sx), fh = static_cast<int>(io.DisplaySize.y * sy);
   const int x0 = std::max(0, static_cast<int>(img.x0 * sx)), x1 = std::min(fw, static_cast<int>(img.x1 * sx + 0.5f));
   const int y0 = std::max(0, static_cast<int>(img.y0 * sy)), y1 = std::min(fh, static_cast<int>(img.y1 * sy + 0.5f));
   const int w = x1 - x0, h = y1 - y0;
   if (w <= 0 || h <= 0) {
      img.state = 3;
      img.error = "save_image: the rectangle is outside the window";
      return;
   }
   std::vector<unsigned char> px(static_cast<size_t>(w) * h * 3), top(px.size());
   p_glPixelStorei(GL_PACK_ALIGNMENT_, 1);
   p_glReadPixels(x0, fh - y1, w, h, GL_RGB_, GL_UNSIGNED_BYTE_, px.data()); // GL counts rows from the bottom
   const size_t row = static_cast<size_t>(w) * 3;
   for (int y = 0; y < h; ++y) std::memcpy(top.data() + y * row, px.data() + (h - 1 - y) * row, row);
   SDL_Surface *surf = SDL_CreateSurfaceFrom(w, h, SDL_PIXELFORMAT_RGB24, top.data(), static_cast<int>(row));
   if (!surf) {
      img.state = 3;
      img.error = std::string("save_image: ") + SDL_GetError();
      return;
   }
   const bool ok = SDL_SavePNG(surf, img.path.c_str());
   SDL_DestroySurface(surf);
   img.state = ok ? 2 : 3;
   if (!ok) img.error = "save_image: cannot write " + img.path + ": " + SDL_GetError();
}

#include "figure_font.inc" // plex_sans_ttf[]: IBM Plex Sans Regular (OFL-1.1); lucide_ttf[]: Lucide (ISC); third_party/fonts

constexpr float DEFAULT_FONT_SIZE = 15.0f; // logical pixels: the size the interface is drawn at
constexpr float PROGGY_FONT_SIZE = 13.0f;  // logical pixels: Dear ImGui's bitmap font, drawn sharp at this size only

// Merge the Lucide icons into a text font just added (its reference size ref_size): the icons (Private Use Area code
// points, figure_icons.F90) then draw in any label set in that font, at any size. Since Dear ImGui 1.92 the sources of
// a font are asked in order for each glyph, so no glyph range is needed: the text font keeps every glyph it has.
bool merge_icons(ImFont *dst, float ref_size) {
   ImFontConfig cfg;
   cfg.MergeMode = true;
   cfg.DstFont = dst;
   cfg.FontDataOwnedByAtlas = false; // static bytes
   cfg.GlyphMaxAdvanceX = 1.0e30f;   // finite, as for the text fonts (see get_font)
   // Lucide's glyphs stand on the baseline, a font size tall: lowered by 0.23 of the size they are centred on the
   // capitals of IBM Plex Sans (measured at 15 and 32 pixels) and nearly so on Proggy's
   cfg.GlyphOffset.y = 0.23f * ref_size;
   std::snprintf(cfg.Name, sizeof(cfg.Name), "Lucide");
   return ImGui::GetIO().Fonts->AddFontFromMemoryTTF(const_cast<unsigned char *>(lucide_ttf),
                                                     static_cast<int>(sizeof(lucide_ttf)), ref_size, &cfg) != nullptr;
}

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
   float ref_size = DEFAULT_FONT_SIZE;
   if (name == "plex-sans") {
      std::snprintf(cfg.Name, sizeof(cfg.Name), "IBM Plex Sans");
      f = io.Fonts->AddFontFromMemoryTTF(const_cast<unsigned char *>(plex_sans_ttf), static_cast<int>(sizeof(plex_sans_ttf)),
                                         DEFAULT_FONT_SIZE, &cfg);
   } else if (name == "proggy") {
      ImFontConfig bitmap;
      bitmap.GlyphMaxAdvanceX = cfg.GlyphMaxAdvanceX;
      // Its reference size given explicitly (the default, 13, when left implicit): Dear ImGui merges a font with an
      // explicit size, as the icons need for their finite GlyphMaxAdvanceX, only into one with an explicit size.
      bitmap.SizePixels = PROGGY_FONT_SIZE;
      ref_size = PROGGY_FONT_SIZE;
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
   if (!merge_icons(f, ref_size)) {
      err = "cannot merge the icons into the font " + name;
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
// A style is a theme (figure_theme.h): a look (geometry: the variables of both libraries), a palette or a base (the
// colours), explicit colours and variables of Dear ImGui and ImPlot by name, ImPlot's line colours, and the window's
// background. The built-in ones are themes/*.toml, embedded in the library: "seal" (the default) and "seal-light",
// FIGURE's, from the palette of its mark; "paper" and "high-contrast"; "dark", "light", "classic", Dear ImGui's own
// with ImPlot's default line colours. The bundled looks are themes/looks/*.toml, the palettes themes/palettes/*.toml.

using figure_theme::color_t;
using figure_theme::ROLE_COUNT;

ImVec4 vec4(const color_t &c) { return ImVec4(c.r, c.g, c.b, c.a); }

color_t mix_color(const color_t &a, const color_t &b, float t) {
   color_t c;
   c.r = a.r + (b.r - a.r) * t;
   c.g = a.g + (b.g - a.g) * t;
   c.b = a.b + (b.b - a.b) * t;
   c.a = 1.0f;
   return c;
}

ImVec4 with_alpha(const color_t &c, float a) { return ImVec4(c.r, c.g, c.b, a); }

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

// The window's background of a palette without its own: the background role darkened (the windows stand out).
color_t derived_clear(const color_t roles[ROLE_COUNT]) {
   const color_t &bg = roles[figure_theme::ROLE_BACKGROUND];
   return mix_color(bg, color_t{0.0f, 0.0f, 0.0f, 1.0f}, figure_theme::luminance(bg) < 0.5 ? 0.25f : 0.08f);
}

// Every Dear ImGui colour from the twelve palette roles. Hovered and active fills are mixes toward the text colour,
// or away from it where the mix would bring the text below 4.5:1 on them; disabled text is the dimmed text; ImPlot's
// colours stay automatic, derived by ImPlot from these (plot frame from FrameBg, plot background from WindowBg, grid
// and ticks from Text).
void derive_colors(const color_t roles[ROLE_COUNT], ImVec4 *colors) {
   using namespace figure_theme;
   const color_t &bg = roles[ROLE_BACKGROUND], &sf = roles[ROLE_SURFACE], &rs = roles[ROLE_RAISED_SURFACE];
   const color_t &bd = roles[ROLE_BORDER], &tx = roles[ROLE_TEXT], &dm = roles[ROLE_DIMMED_TEXT];
   const color_t &ac = roles[ROLE_ACCENT], &sel = roles[ROLE_SELECTION];
   const color_t black{0.0f, 0.0f, 0.0f, 1.0f}, white{1.0f, 1.0f, 1.0f, 1.0f};
   auto shade = [&](const color_t &c, float t) {
      const color_t toward = mix_color(c, tx, t);
      if (contrast(tx, toward) >= 4.5 || contrast(tx, toward) >= contrast(tx, c)) return vec4(toward);
      return vec4(mix_color(c, luminance(tx) > luminance(c) ? black : white, t));
   };
   colors[ImGuiCol_Text] = vec4(tx);
   colors[ImGuiCol_TextDisabled] = vec4(dm);
   colors[ImGuiCol_WindowBg] = vec4(bg);
   colors[ImGuiCol_ChildBg] = with_alpha(bg, 0.0f);
   colors[ImGuiCol_PopupBg] = vec4(sf);
   colors[ImGuiCol_Border] = vec4(bd);
   colors[ImGuiCol_BorderShadow] = with_alpha(black, 0.0f);
   colors[ImGuiCol_FrameBg] = vec4(sf);
   colors[ImGuiCol_FrameBgHovered] = shade(sf, 0.08f);
   colors[ImGuiCol_FrameBgActive] = shade(sf, 0.16f);
   colors[ImGuiCol_TitleBg] = vec4(bg);
   colors[ImGuiCol_TitleBgActive] = vec4(sf);
   colors[ImGuiCol_TitleBgCollapsed] = vec4(bg);
   colors[ImGuiCol_MenuBarBg] = vec4(sf);
   colors[ImGuiCol_ScrollbarBg] = vec4(bg);
   colors[ImGuiCol_ScrollbarGrab] = vec4(bd);
   colors[ImGuiCol_ScrollbarGrabHovered] = vec4(mix_color(bd, tx, 0.20f));
   colors[ImGuiCol_ScrollbarGrabActive] = vec4(mix_color(bd, tx, 0.35f));
   colors[ImGuiCol_CheckMark] = vec4(ac);
   colors[ImGuiCol_CheckboxSelectedBg] = vec4(sf);
   colors[ImGuiCol_SliderGrab] = vec4(ac);
   colors[ImGuiCol_SliderGrabActive] = vec4(mix_color(ac, tx, 0.25f));
   colors[ImGuiCol_Button] = vec4(rs);
   colors[ImGuiCol_ButtonHovered] = shade(rs, 0.10f);
   colors[ImGuiCol_ButtonActive] = shade(rs, 0.20f);
   colors[ImGuiCol_Header] = vec4(sel);
   colors[ImGuiCol_HeaderHovered] = shade(sel, 0.08f);
   colors[ImGuiCol_HeaderActive] = shade(sel, 0.16f);
   colors[ImGuiCol_Separator] = vec4(bd);
   colors[ImGuiCol_SeparatorHovered] = with_alpha(ac, 0.78f);
   colors[ImGuiCol_SeparatorActive] = vec4(ac);
   colors[ImGuiCol_ResizeGrip] = with_alpha(ac, 0.20f);
   colors[ImGuiCol_ResizeGripHovered] = with_alpha(ac, 0.67f);
   colors[ImGuiCol_ResizeGripActive] = with_alpha(ac, 0.95f);
   colors[ImGuiCol_InputTextCursor] = vec4(tx);
   colors[ImGuiCol_TabHovered] = shade(sf, 0.10f);
   colors[ImGuiCol_Tab] = vec4(sf);
   colors[ImGuiCol_TabSelected] = vec4(rs);
   colors[ImGuiCol_TabSelectedOverline] = vec4(ac);
   colors[ImGuiCol_TabDimmed] = vec4(bg);
   colors[ImGuiCol_TabDimmedSelected] = vec4(sf);
   colors[ImGuiCol_TabDimmedSelectedOverline] = vec4(bd);
   colors[ImGuiCol_DockingPreview] = with_alpha(ac, 0.55f);
   colors[ImGuiCol_DockingEmptyBg] = vec4(derived_clear(roles));
   colors[ImGuiCol_PlotLines] = vec4(dm);
   colors[ImGuiCol_PlotLinesHovered] = vec4(ac);
   colors[ImGuiCol_PlotHistogram] = vec4(ac);
   colors[ImGuiCol_PlotHistogramHovered] = vec4(mix_color(ac, tx, 0.30f));
   colors[ImGuiCol_TableHeaderBg] = vec4(sf);
   colors[ImGuiCol_TableBorderStrong] = vec4(bd);
   colors[ImGuiCol_TableBorderLight] = vec4(mix_color(bd, bg, 0.50f));
   colors[ImGuiCol_TableRowBg] = with_alpha(bg, 0.0f);
   colors[ImGuiCol_TableRowBgAlt] = with_alpha(tx, 0.04f);
   colors[ImGuiCol_TextLink] = vec4(ac);
   colors[ImGuiCol_TextSelectedBg] = vec4(sel);
   colors[ImGuiCol_TreeLines] = vec4(bd);
   colors[ImGuiCol_DragDropTarget] = vec4(ac);
   colors[ImGuiCol_DragDropTargetBg] = with_alpha(ac, 0.10f);
   colors[ImGuiCol_UnsavedMarker] = vec4(tx);
   colors[ImGuiCol_NavCursor] = vec4(ac);
   colors[ImGuiCol_NavWindowingHighlight] = with_alpha(tx, 0.70f);
   colors[ImGuiCol_NavWindowingDimBg] = with_alpha(black, 0.30f);
   colors[ImGuiCol_ModalWindowDimBg] = with_alpha(black, 0.45f);
}

// The roles of a style without a palette, read from its Dear ImGui colours (what FIGURE's own widgets draw with);
// success, warning and error are Okabe and Ito's bluish green, orange and vermilion.
void infer_roles(const ImVec4 *colors, color_t roles[ROLE_COUNT]) {
   using namespace figure_theme;
   auto opaque = [](const ImVec4 &c) { return color_t{c.x, c.y, c.z, 1.0f}; };
   roles[ROLE_BACKGROUND] = opaque(colors[ImGuiCol_WindowBg]);
   roles[ROLE_SURFACE] = opaque(colors[ImGuiCol_FrameBg]);
   roles[ROLE_RAISED_SURFACE] = opaque(colors[ImGuiCol_Button]);
   roles[ROLE_BORDER] = opaque(colors[ImGuiCol_Border]);
   roles[ROLE_TEXT] = opaque(colors[ImGuiCol_Text]);
   roles[ROLE_DIMMED_TEXT] = opaque(colors[ImGuiCol_TextDisabled]);
   roles[ROLE_ACCENT] = opaque(colors[ImGuiCol_CheckMark]);
   roles[ROLE_TEXT_ON_ACCENT] = contrast(roles[ROLE_TEXT], roles[ROLE_ACCENT]) >=
                                      contrast(roles[ROLE_BACKGROUND], roles[ROLE_ACCENT])
                                   ? roles[ROLE_TEXT]
                                   : roles[ROLE_BACKGROUND];
   roles[ROLE_SELECTION] = opaque(colors[ImGuiCol_Header]);
   roles[ROLE_SUCCESS] = color_t{0.0f, 158.0f / 255.0f, 115.0f / 255.0f, 1.0f};
   roles[ROLE_WARNING] = color_t{230.0f / 255.0f, 159.0f / 255.0f, 0.0f, 1.0f};
   roles[ROLE_ERROR] = color_t{213.0f / 255.0f, 94.0f / 255.0f, 0.0f, 1.0f};
}

// The system's dark setting: a test's (fig_input_system_theme), else SDL's in window mode; unknown counts as dark.
bool system_is_dark() {
   if (st.system_theme > 0) return st.system_theme == 2;
   if (st.m == mode::window) return SDL_GetSystemTheme() != SDL_SYSTEM_THEME_LIGHT;
   return true;
}

// A bundled look: its file parsed and checked (variables only).
bool load_look(const std::string &name, figure_theme::theme_t &look, std::string &err) {
   const char *text = figure_theme::look_text(name);
   if (!text) {
      err = "unknown look \"" + name + "\" (" + figure_theme::look_names() + ")";
      return false;
   }
   const std::string where = "themes/looks/" + name + ".toml";
   if (!figure_theme::parse(text, where, look, err)) return false;
   for (const std::string &k : look.keys)
      if (k != "[imgui.vars]" && k != "[implot.vars]") {
         err = where + ": a look holds [imgui.vars] and [implot.vars] only, not " + k;
         return false;
      }
   return true;
}

// A bundled palette: its file parsed and checked (a complete [palette] table; background, lines and explicit colours
// only besides it).
bool load_palette(const std::string &name, figure_theme::theme_t &pal, std::string &err) {
   const char *text = figure_theme::palette_text(name);
   if (!text) {
      err = "unknown palette \"" + name + "\" (" + figure_theme::palette_names() + ", auto)";
      return false;
   }
   const std::string where = "themes/palettes/" + name + ".toml";
   if (!figure_theme::parse(text, where, pal, err)) return false;
   for (const std::string &k : pal.keys)
      if (k != "[palette]" && k != "background" && k != "lines" && k != "[imgui.colors]" && k != "[implot.colors]") {
         err = where + ": a palette holds [palette], background, lines, [imgui.colors] and [implot.colors] only, not " +
               k;
         return false;
      }
   for (int r = 0; r < ROLE_COUNT; ++r)
      if (!pal.role_given[r]) {
         err = where + ": [palette] misses " + figure_theme::ROLE_NAMES[r];
         return false;
      }
   return true;
}

// A style being built: both libraries' styles and what goes with them, applied at once by commit_style (a failure
// on the way leaves the style in effect untouched).
struct style_build_t {
   ImGuiStyle           s;                // sizes multiplied by the content scale
   ImPlotStyle          ps;               // colours: ImPlot's automatic ones unless set
   bool                 lines_set = false; // the line colours change (empty lines: ImPlot's Deep)
   std::vector<color_t> lines;
   std::string          cmap_name;
   float                clear[3] = {0.10f, 0.10f, 0.11f};
   std::string          base = "dark", look, palette, palette_resolved;
   bool                 has_roles = false;
   color_t              roles[ROLE_COUNT];
   ImFont              *font = nullptr;
   std::string          font_name;
   float                font_size = 0.0f; // 0: keep
};

// The style in effect, as a build to change parts of.
style_build_t current_build() {
   style_build_t b;
   b.s = ImGui::GetStyle();
   b.ps = ImPlot::GetStyle();
   for (int i = 0; i < 3; ++i) b.clear[i] = st.clear[i];
   b.base = st.style_base;
   b.look = st.look;
   b.palette = st.palette;
   b.palette_resolved = st.palette_resolved;
   b.has_roles = st.has_roles;
   for (int r = 0; r < ROLE_COUNT; ++r) b.roles[r] = st.roles[r];
   return b;
}

// The colours of a palette (t.palette: a bundled name or "auto"; t's [palette] table: roles over it, or all twelve)
// into b: Dear ImGui's derived from the roles, then the palette file's explicit ones; ImPlot's automatic, then the
// palette file's; the window's background and the line colours.
bool palette_colors(const figure_theme::theme_t &t, const std::string &where, style_build_t &b, std::string &err) {
   figure_theme::theme_t pal;
   std::string name = t.palette;
   if (name == "auto") {
      const std::string dark = t.auto_dark.empty() ? st.auto_dark : t.auto_dark;
      const std::string light = t.auto_light.empty() ? st.auto_light : t.auto_light;
      name = system_is_dark() ? dark : light;
   }
   color_t roles[ROLE_COUNT];
   if (!name.empty()) {
      if (!load_palette(name, pal, err)) return false;
      for (int r = 0; r < ROLE_COUNT; ++r) roles[r] = pal.roles[r];
   }
   bool table = false;
   for (int r = 0; r < ROLE_COUNT; ++r) {
      if (!t.role_given[r]) continue;
      roles[r] = t.roles[r];
      table = true;
   }
   if (name.empty()) {
      std::string missing;
      for (int r = 0; r < ROLE_COUNT; ++r)
         if (!t.role_given[r]) missing += std::string(missing.empty() ? "" : ", ") + figure_theme::ROLE_NAMES[r];
      if (!missing.empty()) {
         err = where + ": [palette] misses " + missing + " (or name a palette: palette = \"...\")";
         return false;
      }
   }
   std::string why;
   if (!figure_theme::check_contrast(roles, why)) {
      err = (table || name.empty() ? where + ": [palette]" : "palette \"" + name + "\"") + ": " + why;
      return false;
   }
   derive_colors(roles, b.s.Colors);
   for (const auto &e : pal.imgui_colors) {
      const int i = style_color_index(0, e.name);
      if (i < 0) {
         err = "themes/palettes/" + name + ".toml:" + std::to_string(e.line) + ": unknown Dear ImGui colour \"" + e.name + "\"";
         return false;
      }
      b.s.Colors[i] = vec4(e.color);
   }
   for (ImVec4 &c : b.ps.Colors) c = IMPLOT_AUTO_COL; // as ImPlot::StyleColorsAuto, which also resets MinorAlpha
   for (const auto &e : pal.implot_colors) {
      const int i = style_color_index(1, e.name);
      if (i < 0) {
         err = "themes/palettes/" + name + ".toml:" + std::to_string(e.line) + ": unknown ImPlot colour \"" + e.name + "\"";
         return false;
      }
      b.ps.Colors[i] = vec4(e.color);
   }
   const color_t clear = pal.has_background ? pal.background : derived_clear(roles);
   b.clear[0] = clear.r;
   b.clear[1] = clear.g;
   b.clear[2] = clear.b;
   b.lines_set = true;
   b.lines = pal.lines;
   b.cmap_name = "FIGURE " + name; // as the theme of the same name names its lines (same colours)
   b.palette = table ? "custom" : t.palette;
   b.palette_resolved = name;
   b.has_roles = true;
   for (int r = 0; r < ROLE_COUNT; ++r) b.roles[r] = roles[r];
   return true;
}

// The variables of a look (`name`) into fresh styles: Dear ImGui's and ImPlot's defaults, then the look's.
bool look_vars(const std::string &name, ImGuiStyle &s, ImPlotStyle &ps, std::string &err) {
   figure_theme::theme_t look;
   if (!load_look(name, look, err)) return false;
   const std::string where = "themes/looks/" + name + ".toml";
   for (const auto &e : look.imgui_vars) {
      const figure_style::field *f = style_field(0, e.name);
      if (!f || !write_var(reinterpret_cast<unsigned char *>(&s), *f, e.values)) {
         err = where + ":" + std::to_string(e.line) + ": wrong Dear ImGui style variable \"" + e.name + "\"";
         return false;
      }
   }
   for (const auto &e : look.implot_vars) {
      const figure_style::field *f = style_field(1, e.name);
      if (!f || !write_var(reinterpret_cast<unsigned char *>(&ps), *f, e.values)) {
         err = where + ":" + std::to_string(e.line) + ": wrong ImPlot style variable \"" + e.name + "\"";
         return false;
      }
   }
   return true;
}

// A look in place of the geometry of b: every variable from the look (sizes scaled), the colours kept.
bool apply_look(const std::string &name, style_build_t &b, std::string &err) {
   ImGuiStyle  s;
   ImPlotStyle ps;
   if (!look_vars(name, s, ps, err)) return false;
   s.ScaleAllSizes(st.scale);
   std::memcpy(s.Colors, b.s.Colors, sizeof(s.Colors));
   s.FontSizeBase = b.s.FontSizeBase;
   s.FontScaleMain = b.s.FontScaleMain;
   s.FontScaleDpi = b.s.FontScaleDpi;
   std::memcpy(ps.Colors, b.ps.Colors, sizeof(ps.Colors));
   ps.Colormap = b.ps.Colormap;
   b.s = s;
   b.ps = ps;
   b.look = name;
   return true;
}

// Build a parsed theme: colours from its palette or its base, variables from its look, then its own entries; false
// with `err` on an unknown name or a wrong value. Sizes in the theme are logical pixels, scaled by the content scale
// unless `scale` is false (save_style's reference). `cmap_name` names the ImPlot colormap of the theme's own lines.
bool build_theme(const figure_theme::theme_t &t, const std::string &where, const std::string &cmap_name, bool scale,
                 style_build_t &b, std::string &err) {
   auto bad = [&](const figure_theme::entry_t &e, const std::string &what) {
      err = where + ":" + std::to_string(e.line) + ": " + what + " \"" + e.name + "\"";
      return false;
   };
   b = style_build_t{};
   b.base = t.base;
   if (t.base == "light") ImGui::StyleColorsLight(&b.s);
   else if (t.base == "classic") ImGui::StyleColorsClassic(&b.s);
   else ImGui::StyleColorsDark(&b.s);
   b.lines_set = true;
   if (t.has_palette() && !palette_colors(t, where, b, err)) return false;
   if (!t.look.empty()) {
      ImGuiStyle  s;
      ImPlotStyle ps;
      if (!look_vars(t.look, s, ps, err)) return false;
      std::memcpy(s.Colors, b.s.Colors, sizeof(s.Colors));
      std::memcpy(ps.Colors, b.ps.Colors, sizeof(ps.Colors));
      b.s = s;
      b.ps = ps;
      b.look = t.look;
   }
   for (const auto &e : t.imgui_vars) {
      const figure_style::field *f = style_field(0, e.name);
      if (!f) return bad(e, "unknown Dear ImGui style variable");
      if (!write_var(reinterpret_cast<unsigned char *>(&b.s), *f, e.values)) return bad(e, "wrong number of values for");
   }
   for (const auto &e : t.imgui_colors) {
      const int i = style_color_index(0, e.name);
      if (i < 0) return bad(e, "unknown Dear ImGui colour");
      b.s.Colors[i] = vec4(e.color);
   }
   for (const auto &e : t.implot_vars) {
      const figure_style::field *f = style_field(1, e.name);
      if (!f) return bad(e, "unknown ImPlot style variable");
      if (!write_var(reinterpret_cast<unsigned char *>(&b.ps), *f, e.values)) return bad(e, "wrong number of values for");
   }
   for (const auto &e : t.implot_colors) {
      const int i = style_color_index(1, e.name);
      if (i < 0) return bad(e, "unknown ImPlot colour");
      b.ps.Colors[i] = vec4(e.color);
   }
   if (!t.lines.empty()) {
      b.lines = t.lines;
      b.cmap_name = cmap_name;
   }
   if (t.has_background) {
      b.clear[0] = t.background.r;
      b.clear[1] = t.background.g;
      b.clear[2] = t.background.b;
   }
   if (!t.font.empty()) {
      b.font = get_font(t.font, err);
      if (!b.font) {
         err = where + ": " + err;
         return false;
      }
      b.font_name = t.font;
   }
   b.font_size = static_cast<float>(t.font_size);
   if (!t.auto_dark.empty() && !figure_theme::palette_text(t.auto_dark)) {
      err = where + ": auto_dark: unknown palette \"" + t.auto_dark + "\" (" + figure_theme::palette_names() + ")";
      return false;
   }
   if (!t.auto_light.empty() && !figure_theme::palette_text(t.auto_light)) {
      err = where + ": auto_light: unknown palette \"" + t.auto_light + "\" (" + figure_theme::palette_names() + ")";
      return false;
   }
   if (scale) b.s.ScaleAllSizes(st.scale);
   return true;
}

// Make a build the style in effect. The font sizes in effect are kept unless the build sets one.
void commit_style(style_build_t &b, const figure_theme::theme_t *t = nullptr) {
   const ImGuiStyle old = ImGui::GetStyle();
   b.s.FontSizeBase = b.font_size > 0.0f ? b.font_size : old.FontSizeBase;
   b.s.FontScaleMain = old.FontScaleMain;
   b.s.FontScaleDpi = old.FontScaleDpi;
   if (b.lines_set) {
      int cmap = ImPlotColormap_Deep;
      if (!b.lines.empty()) {
         cmap = ImPlot::GetColormapIndex(b.cmap_name.c_str()); // ImPlot keeps colormaps for the context's life
         if (cmap < 0) {
            std::vector<ImU32> cols;
            for (const auto &c : b.lines) cols.push_back(ImGui::ColorConvertFloat4ToU32(vec4(c)));
            cmap = ImPlot::AddColormap(b.cmap_name.c_str(), cols.data(), static_cast<int>(cols.size()), true);
         }
      }
      b.ps.Colormap = cmap;
   }
   ImGui::GetStyle() = b.s;
   ImPlot::GetStyle() = b.ps;
   for (int i = 0; i < 3; ++i) st.clear[i] = b.clear[i];
   st.style_base = b.base;
   st.look = b.look;
   st.palette = b.palette;
   st.palette_resolved = b.palette_resolved;
   st.has_roles = b.has_roles;
   for (int r = 0; r < ROLE_COUNT; ++r) st.roles[r] = b.roles[r];
   if (t && !t->auto_dark.empty()) st.auto_dark = t->auto_dark;
   if (t && !t->auto_light.empty()) st.auto_light = t->auto_light;
   if (b.font) {
      ImGui::GetIO().FontDefault = b.font;
      st.font = b.font_name;
   }
   if (st.m == mode::remote) figure_remote::set_background(b.clear[0], b.clear[1], b.clear[2]);
}

// Apply a parsed theme; false with `err`.
bool apply_theme(const figure_theme::theme_t &t, const std::string &where, const std::string &cmap_name,
                 std::string &err) {
   style_build_t b;
   if (!build_theme(t, where, cmap_name, true, b, err)) return false;
   commit_style(b, &t);
   return true;
}

// A built-in theme by name, parsed; false if the name is unknown (err empty) or the theme is wrong (err set).
bool builtin_theme(const std::string &name, figure_theme::theme_t &t, std::string &err) {
   err.clear();
   for (int i = 0; i < figure_theme::builtin_count(); ++i) {
      if (name != figure_theme::builtin_name(i)) continue;
      return figure_theme::parse(figure_theme::builtin_text(i), "themes/" + name + ".toml", t, err);
   }
   return false;
}

// A named line palette in place of the build's line colours; false with err if the name is unknown.
bool apply_lines(const std::string &lines, style_build_t &b, std::string &err) {
   if (!figure_theme::line_palette(lines, b.lines)) {
      err = "unknown line palette \"" + lines + "\" (okabe-ito)";
      return false;
   }
   b.lines_set = true;
   b.cmap_name = "FIGURE " + lines; // the palette's colours, whatever the theme
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

// The style by parts, at once (nothing changes on an error): a built-in theme by `name`, then a look, then a
// palette (a bundled name or "auto", choosing between auto_dark and auto_light), then a line palette. An empty
// argument is not given: what is not given is kept from the style in effect (or from the theme `name`).
bool apply_style_parts(const std::string &name, const std::string &look, const std::string &palette,
                       const std::string &auto_dark, const std::string &auto_light, const std::string &lines,
                       std::string &err) {
   err.clear();
   style_build_t b;
   figure_theme::theme_t named;
   if (!name.empty()) {
      if (!builtin_theme(name, named, err)) {
         if (err.empty()) err = "unknown style \"" + name + "\" (" + builtin_style_names() + ")";
         return false;
      }
      if (!build_theme(named, "themes/" + name + ".toml", "FIGURE " + name, true, b, err)) return false;
   } else {
      b = current_build();
   }
   for (const std::string *p : {&auto_dark, &auto_light})
      if (!p->empty() && !figure_theme::palette_text(*p)) {
         err = std::string(p == &auto_dark ? "auto_dark" : "auto_light") + ": unknown palette \"" + *p + "\" (" +
               figure_theme::palette_names() + ")";
         return false;
      }
   if (!look.empty() && !apply_look(look, b, err)) return false;
   figure_theme::theme_t t; // the palette's part: its name and the auto pair
   t.auto_dark = auto_dark.empty() ? named.auto_dark : auto_dark;
   t.auto_light = auto_light.empty() ? named.auto_light : auto_light;
   // a new auto pair re-applies "auto" in effect
   const std::string pal = !palette.empty() ? palette
                           : (name.empty() && b.palette == "auto" && (!auto_dark.empty() || !auto_light.empty()))
                               ? "auto"
                               : "";
   if (!pal.empty()) {
      t.palette = pal;
      if (!palette_colors(t, "set_style", b, err)) return false;
   }
   if (!lines.empty() && !apply_lines(lines, b, err)) return false;
   commit_style(b, &t);
   if (!lines.empty()) st.lines_name = lines;
   else if (!name.empty() || !palette.empty()) st.lines_name.clear();
   return true;
}

// Apply a built-in style by name, with its own line colours or a named palette (`lines`, empty: the theme's); false if
// the name is unknown (err empty) or the theme or the palette is wrong (err set).
bool apply_style(const std::string &name, std::string &err, const std::string &lines = "") {
   figure_theme::theme_t t;
   if (!builtin_theme(name, t, err)) return false;
   return apply_style_parts(name, "", "", "", "", lines, err);
}

// The system's light or dark setting changed: a palette "auto" in effect is chosen again (the geometry and the line
// palette of the last set_style are kept; colours changed by name are not).
void system_theme_changed() {
   if (st.palette != "auto") return;
   style_build_t b = current_build();
   figure_theme::theme_t t;
   t.palette = "auto";
   std::string err;
   if (!palette_colors(t, "auto", b, err) || (!st.lines_name.empty() && !apply_lines(st.lines_name, b, err))) {
      std::fprintf(stderr, "figure: the system's theme changed: %s\n", err.c_str());
      return;
   }
   commit_style(b);
   st.frames_left = 3;
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

// Write the style in effect as a theme file: its look and palette (or base), background, lines, and every colour and
// variable that differs from what the look and the palette (or the base) give. Sizes are written in logical pixels
// (divided by the content scale): which fields are sizes is asked to Dear ImGui itself (the fields ScaleAllSizes
// changes).
bool save_style_file(const std::string &path, std::string &err) {
   figure_theme::theme_t r; // what the file's look, palette and base give, unscaled: the reference
   r.base = st.style_base;
   r.look = st.look;
   const bool custom = st.palette == "custom";
   if (custom) {
      r.has_palette_table = true;
      for (int k = 0; k < ROLE_COUNT; ++k) {
         r.roles[k] = st.roles[k];
         r.role_given[k] = true;
      }
   } else {
      r.palette = st.palette;
   }
   style_build_t ref;
   if (!build_theme(r, path, "", false, ref, err)) return false;
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
   std::string out = "# FIGURE theme, written by app%save_style\n\n";
   if (st.palette.empty()) out += "base = \"" + st.style_base + "\"\n";
   if (!st.look.empty()) out += "look = \"" + st.look + "\"\n";
   if (!st.palette.empty() && !custom) out += "palette = \"" + st.palette + "\"\n";
   if (st.palette == "auto")
      out += "auto_dark = \"" + st.auto_dark + "\"\nauto_light = \"" + st.auto_light + "\"\n";
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
   if (custom) {
      out += "\n[palette]\n";
      for (int k = 0; k < ROLE_COUNT; ++k)
         out += std::string(figure_theme::ROLE_NAMES[k]) + " = " + theme_color(vec4(st.roles[k])) + "\n";
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
        reinterpret_cast<const unsigned char *>(&cur), reinterpret_cast<const unsigned char *>(&ref.s),
        reinterpret_cast<const unsigned char *>(&probe));
   std::string colors;
   for (int i = 0; i < ImGuiCol_COUNT; ++i) {
      const ImVec4 &c = cur.Colors[i], &rc = ref.s.Colors[i];
      if (c.x == rc.x && c.y == rc.y && c.z == rc.z && c.w == rc.w) continue;
      colors += std::string(ImGui::GetStyleColorName(i)) + " = " + theme_color(c) + "\n";
   }
   if (!colors.empty()) out += "\n[imgui.colors]\n" + colors;
   vars("implot.vars", figure_style::IMPLOT_FIELDS, figure_style::IMPLOT_FIELDS_COUNT,
        reinterpret_cast<const unsigned char *>(&ImPlot::GetStyle()), reinterpret_cast<const unsigned char *>(&ref.ps),
        nullptr);
   colors.clear();
   for (int i = 0; i < ImPlotCol_COUNT; ++i) {
      const ImVec4 &c = ImPlot::GetStyle().Colors[i], &rc = ref.ps.Colors[i];
      if (ImPlot::IsColorAuto(c)) continue; // derived from Dear ImGui's: nothing to write
      if (c.x == rc.x && c.y == rc.y && c.z == rc.z && c.w == rc.w) continue; // as the palette gives it
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

// ---- The window's frame drawn by FIGURE ----------------------------------------------------------------------------
// decorations='figure': the window is borderless and FIGURE draws its title bar, which is Dear ImGui's main menu bar
// ("##MainMenuBar"): opened at the start of the frame with the icon (fig_begin_frame), appended to by the program's own
// main menu bar (ig_begin_main_menu_bar appends to the same window), and closed at the end of the frame with the title
// and the buttons (fig_end_frame). The rectangles drawn are kept for the hit test (SDL_SetWindowHitTest), which
// answers from the last frame's.

// The side of the buttons by default: left on macOS, right elsewhere.
bool frame_buttons_left_default() {
#if defined(__APPLE__)
   return true;
#else
   return false;
#endif
}

// The roles in effect: the palette's, or read from Dear ImGui's colours.
void roles_in_effect(color_t roles[ROLE_COUNT]) {
   if (st.has_roles) std::copy(st.roles, st.roles + ROLE_COUNT, roles);
   else infer_roles(ImGui::GetStyle().Colors, roles);
}

// Notifications (app%notify): kept, the last 100, oldest first; those still shown are drawn by FIGURE after the
// program's windows, newest at the bottom-right corner of the work area, stacked upwards, each in its kind's palette
// role with its icon. Their age grows by Dear ImGui's frame time (fixed in headless mode and in captures: no wall
// clock); in the last NOTE_FADE seconds of their time they fade out; a click dismisses one.
struct note_t {
   int         id = 0;
   int         kind = 0; // 0 info, 1 success, 2 warning, 3 error
   std::string text, icon;
   float       seconds = 5.0f; // <= 0: until dismissed
   float       age = 0.0f;
   bool        shown = true;
};
constexpr size_t NOTE_KEEP = 100;
constexpr float  NOTE_FADE = 0.5f;
std::deque<note_t>        notes;
int                       next_note = 1;
std::vector<frame_rect_t> note_rects; // last frame's shown notifications, newest first

void draw_notifications() {
   note_rects.clear();
   if (notes.empty()) return;
   const float dt = ImGui::GetIO().DeltaTime;
   color_t roles[ROLE_COUNT];
   roles_in_effect(roles);
   const int   role_of[4] = {figure_theme::ROLE_ACCENT, figure_theme::ROLE_SUCCESS, figure_theme::ROLE_WARNING,
                             figure_theme::ROLE_ERROR};
   const ImGuiViewport *vp = ImGui::GetMainViewport();
   const float fs = ImGui::GetFontSize();
   const float width = 22.0f * fs, margin = 0.75f * fs, gap = 0.5f * fs;
   float       bottom = vp->WorkPos.y + vp->WorkSize.y - margin;
   bool        animate = false;
   for (auto it = notes.rbegin(); it != notes.rend(); ++it) {
      note_t &n = *it;
      if (!n.shown) continue;
      n.age += dt;
      if (n.seconds > 0.0f && n.age >= n.seconds) {
         n.shown = false;
         continue;
      }
      float alpha = 1.0f;
      if (n.seconds > 0.0f && n.seconds - n.age < NOTE_FADE) {
         alpha = std::max(0.0f, (n.seconds - n.age) / NOTE_FADE);
         animate = true;
      }
      const color_t c = roles[role_of[n.kind]];
      const ImVec4  kc(c.r, c.g, c.b, 1.0f);
      ImGui::SetNextWindowPos(ImVec2(vp->WorkPos.x + vp->WorkSize.x - margin, bottom), ImGuiCond_Always,
                              ImVec2(1.0f, 1.0f));
      ImGui::SetNextWindowSizeConstraints(ImVec2(width, 0.0f), ImVec2(width, vp->WorkSize.y));
      ImGui::PushStyleVar(ImGuiStyleVar_Alpha, alpha);
      ImGui::PushStyleVar(ImGuiStyleVar_WindowBorderSize, 1.0f);
      ImGui::PushStyleColor(ImGuiCol_Border, kc);
      const std::string name = "##figure notification " + std::to_string(n.id);
      ImGui::Begin(name.c_str(), nullptr,
                   ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_AlwaysAutoResize | ImGuiWindowFlags_NoNav |
                      ImGuiWindowFlags_NoFocusOnAppearing | ImGuiWindowFlags_NoSavedSettings |
                      ImGuiWindowFlags_NoDocking | ImGuiWindowFlags_NoMove);
      ImGui::BringWindowToDisplayFront(ImGui::GetCurrentWindow());
      ImGui::TextColored(kc, "%s", n.icon.c_str());
      ImGui::SameLine();
      ImGui::PushTextWrapPos(width - ImGui::GetStyle().WindowPadding.x);
      ImGui::TextUnformatted(n.text.c_str());
      ImGui::PopTextWrapPos();
      if (ImGui::IsWindowHovered() && ImGui::IsMouseClicked(ImGuiMouseButton_Left)) n.shown = false;
      const ImVec2 pos = ImGui::GetWindowPos(), size = ImGui::GetWindowSize();
      ImGui::End();
      ImGui::PopStyleColor();
      ImGui::PopStyleVar(2);
      note_rects.push_back(frame_rect_t{pos.x, pos.y, pos.x + size.x, pos.y + size.y});
      bottom = pos.y - gap;
   }
   if (animate) st.frames_left = std::max(st.frames_left, 2); // the fade is drawn frame by frame
}

bool frame_maximized() {
   if (st.m == mode::window && st.window) return (SDL_GetWindowFlags(st.window) & SDL_WINDOW_MAXIMIZED) != 0;
   return st.frame.maximized;
}

bool frame_minimized() {
   if (st.m == mode::window && st.window) return (SDL_GetWindowFlags(st.window) & SDL_WINDOW_MINIMIZED) != 0;
   return st.frame.minimized;
}

// The buttons' actions: the window's in window mode, recorded as state in headless mode; close takes the quit path of
// the window's close button (a request with confirm_quit, else the end of the loop).
void frame_minimize() {
   if (st.m == mode::window && st.window) SDL_MinimizeWindow(st.window);
   else st.frame.minimized = true;
}

void frame_toggle_maximize() {
   if (st.m == mode::window && st.window) {
      if (frame_maximized()) SDL_RestoreWindow(st.window);
      else SDL_MaximizeWindow(st.window);
   } else {
      st.frame.maximized = !st.frame.maximized;
   }
   st.frames_left = 3;
}

void frame_close() {
   if (st.confirm_quit) st.quit_requested = true;
   else st.quit_now = true;
}

SDL_HitTestResult SDLCALL frame_hit_test(SDL_Window *, const SDL_Point *p, void *) {
   return static_cast<SDL_HitTestResult>(frame_hit(st.frame.geom, static_cast<float>(p->x), static_cast<float>(p->y)));
}

// The start of the bar: Dear ImGui's main menu bar in the palette's surface colour, the space of the buttons when
// they are on the left, and the icon.
void frame_bar_open() {
   if (!st.frame.on) return;
   color_t r[ROLE_COUNT];
   roles_in_effect(r);
   ImGui::PushStyleColor(ImGuiCol_MenuBarBg, vec4(r[figure_theme::ROLE_SURFACE]));
   ImGui::PushStyleColor(ImGuiCol_WindowBg, vec4(r[figure_theme::ROLE_SURFACE]));
   const bool open = ImGui::BeginMainMenuBar();
   ImGui::PopStyleColor(2);
   if (!open) return;
   const float h = ImGui::GetFrameHeight();
   if (st.frame.buttons_left) ImGui::Dummy(ImVec2(3.0f * 1.6f * h, h));
   frame_rect_t icon;
   if (!st.frame.icon_glyph.empty()) {
      ImGui::TextColored(vec4(r[figure_theme::ROLE_ACCENT]), "%s", st.frame.icon_glyph.c_str());
   } else if (st.frame.icon_tex != 0) {
      const float side = ImGui::GetFontSize();
      ImGui::Image(ImTextureRef(static_cast<ImTextureID>(st.frame.icon_tex)), ImVec2(side, side));
   }
   if (!st.frame.icon_glyph.empty() || st.frame.icon_tex != 0) {
      const ImVec2 a = ImGui::GetItemRectMin(), b = ImGui::GetItemRectMax();
      icon = frame_rect_t{a.x, a.y, b.x, b.y};
   }
   st.frame.geom.parts[FRAME_ICON] = icon;
   ImGui::EndMainMenuBar();
}

// The end of the bar, after the program's menus: the title, centred in the bar where it does not cover the menus or
// the buttons, and the minimize, maximize (restore) and close buttons; a double-click on the empty bar toggles
// maximize. Then the geometry for the hit test.
void frame_bar_close() {
   if (!st.frame.on) return;
   color_t r[ROLE_COUNT];
   roles_in_effect(r);
   using namespace figure_theme;
   if (!ImGui::BeginMainMenuBar()) return;
   ImGuiWindow *bar = ImGui::GetCurrentWindow();
   const ImVec2 pos = bar->Pos, size = bar->Size;
   const float h = size.y, bw = 1.6f * h;
   const float menus_end = ImGui::GetCursorScreenPos().x; // where the next menu would go: after the program's
   frame_geom_t g;
   g.valid = true;
   g.width = ImGui::GetIO().DisplaySize.x;
   g.height = ImGui::GetIO().DisplaySize.y;
   g.border = 6.0f * st.scale;
   g.maximized = frame_maximized();
   g.parts[FRAME_BAR] = frame_rect_t{pos.x, pos.y, pos.x + size.x, pos.y + size.y};
   g.parts[FRAME_ICON] = st.frame.geom.parts[FRAME_ICON];
   const float b0 = st.frame.buttons_left ? pos.x : pos.x + size.x - 3.0f * bw; // the buttons' left edge
   const int order[3] = {FRAME_MINIMIZE, FRAME_MAXIMIZE, FRAME_CLOSE};
   const int left_order[3] = {FRAME_CLOSE, FRAME_MINIMIZE, FRAME_MAXIMIZE}; // macOS order: close first
   for (int k = 0; k < 3; ++k) {
      const int p = st.frame.buttons_left ? left_order[k] : order[k];
      g.parts[p] = frame_rect_t{b0 + k * bw, pos.y, b0 + (k + 1) * bw, pos.y + h};
   }
   const float menus_start = st.frame.buttons_left ? b0 + 3.0f * bw : pos.x;
   g.parts[FRAME_MENUS] = frame_rect_t{std::max(menus_start, g.parts[FRAME_ICON].x1), pos.y, menus_end, pos.y + h};
   // the title, centred in the bar; moved right of the menus or clipped before the buttons when they are in the way
   const bool focused = st.m != mode::window || cap.on || (SDL_GetWindowFlags(st.window) & SDL_WINDOW_INPUT_FOCUS);
   const ImVec2 ts = ImGui::CalcTextSize(st.title.c_str());
   const float free0 = menus_end + ImGui::GetStyle().ItemSpacing.x * 2.0f;
   const float free1 = st.frame.buttons_left ? pos.x + size.x - ImGui::GetStyle().ItemSpacing.x : b0;
   float tx = pos.x + 0.5f * (size.x - ts.x);
   if (tx < free0) tx = free0;
   const float ty = pos.y + 0.5f * (h - ts.y);
   ImDrawList *dl = ImGui::GetWindowDrawList();
   if (free1 > tx) {
      const ImVec4 clip(tx, pos.y, free1, pos.y + h);
      dl->AddText(nullptr, 0.0f, ImVec2(tx, ty),
                  ImGui::GetColorU32(vec4(r[focused ? ROLE_TEXT : ROLE_DIMMED_TEXT])), st.title.c_str(), nullptr,
                  0.0f, &clip);
      g.parts[FRAME_TITLE] = frame_rect_t{tx, pos.y, std::min(tx + ts.x, free1), pos.y + h};
   }
   // the buttons: drawn shapes, hovered in a mix of the surface toward the text, close in the error colour
   const color_t &sf = r[ROLE_SURFACE], &tx_c = r[ROLE_TEXT], &er = r[ROLE_ERROR];
   const color_t on_error = contrast(tx_c, er) >= contrast(r[ROLE_BACKGROUND], er) ? tx_c : r[ROLE_BACKGROUND];
   const float t = std::max(1.0f, std::round(st.scale));
   for (int p : {FRAME_MINIMIZE, FRAME_MAXIMIZE, FRAME_CLOSE}) {
      const frame_rect_t &rc = g.parts[p];
      ImGui::SetCursorScreenPos(ImVec2(rc.x0, rc.y0));
      ImGui::PushID(p);
      const bool clicked = ImGui::InvisibleButton("##frame_button", ImVec2(rc.x1 - rc.x0, rc.y1 - rc.y0));
      const bool hovered = ImGui::IsItemHovered(), held = ImGui::IsItemActive();
      ImGui::PopID();
      color_t ink = tx_c;
      if (hovered || held) {
         const color_t fill = p == FRAME_CLOSE ? er : mix_color(sf, tx_c, held ? 0.24f : 0.14f);
         dl->AddRectFilled(ImVec2(rc.x0, rc.y0), ImVec2(rc.x1, rc.y1), ImGui::GetColorU32(vec4(fill)));
         if (p == FRAME_CLOSE) ink = on_error;
      }
      const ImU32 col = ImGui::GetColorU32(vec4(ink));
      const ImVec2 c(std::round(0.5f * (rc.x0 + rc.x1)) + 0.5f, std::round(0.5f * (rc.y0 + rc.y1)) + 0.5f);
      const float s = std::round(0.22f * h);
      if (p == FRAME_MINIMIZE) {
         dl->AddLine(ImVec2(c.x - s, c.y), ImVec2(c.x + s, c.y), col, t);
      } else if (p == FRAME_MAXIMIZE) {
         if (g.maximized) { // restore: two overlapping squares
            const float q = std::round(0.3f * s);
            dl->AddRect(ImVec2(c.x - s, c.y - s + q), ImVec2(c.x + s - q, c.y + s), col, 0.0f, t);
            dl->AddLine(ImVec2(c.x - s + q, c.y - s + q), ImVec2(c.x - s + q, c.y - s), col, t);
            dl->AddLine(ImVec2(c.x - s + q, c.y - s), ImVec2(c.x + s, c.y - s), col, t);
            dl->AddLine(ImVec2(c.x + s, c.y - s), ImVec2(c.x + s, c.y + s - q), col, t);
            dl->AddLine(ImVec2(c.x + s, c.y + s - q), ImVec2(c.x + s - q, c.y + s - q), col, t);
         } else {
            dl->AddRect(ImVec2(c.x - s, c.y - s), ImVec2(c.x + s, c.y + s), col, 0.0f, t);
         }
      } else {
         dl->AddLine(ImVec2(c.x - s, c.y - s), ImVec2(c.x + s, c.y + s), col, t);
         dl->AddLine(ImVec2(c.x - s, c.y + s), ImVec2(c.x + s, c.y - s), col, t);
      }
      if (clicked) {
         if (p == FRAME_MINIMIZE) frame_minimize();
         else if (p == FRAME_MAXIMIZE) frame_toggle_maximize();
         else frame_close();
      }
   }
   // a double-click on the bar where it drags the window toggles maximize (Windows does it itself for its caption
   // area, which then sends no click to the program)
   const ImVec2 m = ImGui::GetIO().MousePos;
   if (ImGui::IsWindowHovered() && ImGui::IsMouseDoubleClicked(ImGuiMouseButton_Left) &&
       frame_hit(g, m.x, m.y) == HIT_DRAG)
      frame_toggle_maximize();
   ImGui::EndMainMenuBar();
   st.frame.geom = g;
}

// A Lucide icon (UTF-8, one code point) rendered with the bundled icon font, size x size RGBA pixels: the glyph in the
// palette's text on accent colour on a rounded square of its accent, so it reads on any task bar or dock.
bool render_icon_glyph(const std::string &utf8, int size, std::vector<unsigned char> &rgba, std::string &err) {
   unsigned int cp = 0;
   if (utf8.empty() || ImTextCharFromUtf8(&cp, utf8.c_str(), utf8.c_str() + utf8.size()) != static_cast<int>(utf8.size())) {
      err = "set_icon: the icon is one ICON_* character";
      return false;
   }
   stbtt_fontinfo font;
   if (!stbtt_InitFont(&font, lucide_ttf, stbtt_GetFontOffsetForIndex(lucide_ttf, 0))) {
      err = "set_icon: the icon font cannot be read";
      return false;
   }
   const int glyph = stbtt_FindGlyphIndex(&font, static_cast<int>(cp));
   if (glyph == 0) {
      err = "set_icon: no icon has this code point (an ICON_* constant is expected)";
      return false;
   }
   const float scale = stbtt_ScaleForPixelHeight(&font, 0.72f * size);
   int x0, y0, x1, y1;
   stbtt_GetGlyphBitmapBox(&font, glyph, scale, scale, &x0, &y0, &x1, &y1);
   const int gw = x1 - x0, gh = y1 - y0;
   std::vector<unsigned char> alpha(static_cast<size_t>(std::max(gw, 1) * std::max(gh, 1)), 0);
   if (gw > 0 && gh > 0) stbtt_MakeGlyphBitmap(&font, alpha.data(), gw, gh, gw, scale, scale, glyph);
   color_t r[ROLE_COUNT];
   roles_in_effect(r);
   const color_t &bg = r[figure_theme::ROLE_ACCENT], &fg = r[figure_theme::ROLE_TEXT_ON_ACCENT];
   rgba.assign(static_cast<size_t>(4 * size * size), 0);
   const float radius = 0.2f * size, ox = 0.5f * (size - gw), oy = 0.5f * (size - gh);
   for (int j = 0; j < size; ++j)
      for (int i = 0; i < size; ++i) {
         // coverage of the rounded square (one pixel of anti-aliasing at the corners)
         const float cx = std::min(std::max(i + 0.5f, radius), size - radius);
         const float cy = std::min(std::max(j + 0.5f, radius), size - radius);
         const float d = std::sqrt((i + 0.5f - cx) * (i + 0.5f - cx) + (j + 0.5f - cy) * (j + 0.5f - cy));
         const float cover = std::min(1.0f, std::max(0.0f, radius - d + 0.5f));
         const int gi = i - static_cast<int>(std::round(ox)), gj = j - static_cast<int>(std::round(oy));
         const float a = gi >= 0 && gi < gw && gj >= 0 && gj < gh ? alpha[static_cast<size_t>(gj * gw + gi)] / 255.0f : 0.0f;
         unsigned char *px = &rgba[static_cast<size_t>(4 * (j * size + i))];
         px[0] = static_cast<unsigned char>(std::lround(255.0f * (bg.r + (fg.r - bg.r) * a)));
         px[1] = static_cast<unsigned char>(std::lround(255.0f * (bg.g + (fg.g - bg.g) * a)));
         px[2] = static_cast<unsigned char>(std::lround(255.0f * (bg.b + (fg.b - bg.b) * a)));
         px[3] = static_cast<unsigned char>(std::lround(255.0f * cover));
      }
   return true;
}

// The window's icon (SDL_SetWindowIcon) from RGBA pixels, rows from the top.
bool set_window_icon(const unsigned char *rgba, int width, int height, std::string &err) {
   SDL_Surface *surface = SDL_CreateSurfaceFrom(width, height, SDL_PIXELFORMAT_RGBA32,
                                                const_cast<unsigned char *>(rgba), 4 * width);
   if (!surface) {
      err = std::string("set_icon: SDL_CreateSurfaceFrom: ") + SDL_GetError();
      return false;
   }
   const bool ok = SDL_SetWindowIcon(st.window, surface);
   SDL_DestroySurface(surface);
   if (!ok) err = std::string("set_icon: SDL_SetWindowIcon: ") + SDL_GetError();
   return ok;
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
   sdl_events = true;
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
   st.title = t;
   const frame_options_t fo = frame_options;
   frame_options = frame_options_t{};
   SDL_WindowFlags flags = SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIDDEN | SDL_WINDOW_HIGH_PIXEL_DENSITY;
   if (fo.decorations == 1) flags |= SDL_WINDOW_BORDERLESS; // the frame is FIGURE's: frame_bar_open/close
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
   if (fo.decorations == 1) {
      st.frame.on = true;
      st.frame.buttons_left = fo.buttons == 2 || (fo.buttons == 0 && frame_buttons_left_default());
      SDL_SetWindowHitTest(st.window, frame_hit_test, nullptr);
   }
   SDL_ShowWindow(st.window);

   create_contexts();
   ImGuiStyle &style = ImGui::GetStyle();
   style.ScaleAllSizes(st.scale);
   style.FontScaleDpi = st.scale;
   ImGui_ImplSDL3_InitForOpenGL(st.window, st.gl);
   ImGui_ImplOpenGL3_Init(glsl);
   st.m = mode::window;
   fig_file_browser_reset(1, cap.on ? 0 : 1); // a capture reads nothing of the user's: no recent folders
   apply_initial_style();
   st.frames_left = 3;
   rs = redraw_stats_t{};
   rs.on = std::getenv("FIGURE_DEBUG_REDRAW") != nullptr;
   rs.t0 = rs.t_mark = SDL_GetTicksNS();
   return FIG_OK;
   FIG_CATCH
}

// Headless mode's clipboard: its own text, the same on every platform (without a window there is no system
// clipboard to reach: on macOS Dear ImGui's default then reads back nothing).
static std::string headless_clipboard;
static void headless_set_clipboard(ImGuiContext *, const char *text) { headless_clipboard = text ? text : ""; }
static const char *headless_get_clipboard(ImGuiContext *) { return headless_clipboard.c_str(); }

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
   ImGuiPlatformIO &pio = ImGui::GetPlatformIO();
   headless_clipboard.clear();
   pio.Platform_SetClipboardTextFn = headless_set_clipboard;
   pio.Platform_GetClipboardTextFn = headless_get_clipboard;
   st.m = mode::headless;
   fig_file_browser_reset(1, 0); // tests: the recent folders in memory, or in the file a test names
   st.frame.on = frame_options.decorations == 1; // the bar drawn, its actions recorded as state (tests)
   st.frame.buttons_left = frame_options.buttons == 2 || (frame_options.buttons == 0 && frame_buttons_left_default());
   frame_options = frame_options_t{};
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
   frame_options = frame_options_t{}; // remote mode: the browser's page has no window frame to draw
   if (!figure_remote::start(h.empty() ? "127.0.0.1" : h, port, *bound_port, err)) return fail(FIG_ERR_FAILED, err);
   create_contexts();
   ImGuiIO &io = ImGui::GetIO();
   io.DisplaySize = ImVec2(static_cast<float>(width), static_cast<float>(height)); // until the browser sends its size
   io.BackendFlags |= ImGuiBackendFlags_RendererHasTextures;
   // draw lists over 65536 vertices are split into ranges, each command carrying its VtxOffset (16-bit indices)
   io.BackendFlags |= ImGuiBackendFlags_RendererHasVtxOffset;
   io.BackendPlatformName = "figure_remote";
   st.m = mode::remote;
   fig_file_browser_reset(1, 1);
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

int fig_set_style_parts(const char *name, int name_len, const char *look, int look_len, const char *palette,
                        int palette_len, const char *auto_dark, int auto_dark_len, const char *auto_light,
                        int auto_light_len, const char *lines, int lines_len) {
   FIG_TRY
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   auto str = [](const char *p, int n) { return std::string(p, n > 0 ? static_cast<size_t>(n) : 0); };
   const std::string n = str(name, name_len), lk = str(look, look_len), pal = str(palette, palette_len);
   const std::string ad = str(auto_dark, auto_dark_len), al = str(auto_light, auto_light_len);
   const std::string l = str(lines, lines_len);
   if (n.empty() && lk.empty() && pal.empty() && ad.empty() && al.empty() && l.empty())
      return fail(FIG_ERR_ARGUMENT, "set_style: give a name, a look, a palette or line colours");
   std::string err;
   if (!apply_style_parts(n, lk, pal, ad, al, l, err)) return fail(FIG_ERR_ARGUMENT, "set_style: " + err);
   return FIG_OK;
   FIG_CATCH
}

int fig_palette_color(const char *role, int role_len, float *rgba) {
   FIG_TRY
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   const std::string r(role, role_len > 0 ? static_cast<size_t>(role_len) : 0);
   const int k = figure_theme::role_index(r);
   if (k < 0) {
      std::string names;
      for (int i = 0; i < ROLE_COUNT; ++i) names += std::string(i ? ", " : "") + figure_theme::ROLE_NAMES[i];
      return fail(FIG_ERR_ARGUMENT, "palette_color: unknown role \"" + r + "\" (" + names + ")");
   }
   color_t roles[ROLE_COUNT];
   roles_in_effect(roles);
   rgba[0] = roles[k].r;
   rgba[1] = roles[k].g;
   rgba[2] = roles[k].b;
   rgba[3] = roles[k].a;
   return FIG_OK;
   FIG_CATCH
}

int fig_input_system_theme(int theme) {
   FIG_TRY
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   if (theme < 0 || theme > 2) return fail(FIG_ERR_ARGUMENT, "test_system_theme: 0 (the system's), 1 light or 2 dark");
   st.system_theme = theme == 0 ? -1 : theme;
   st.system_theme_changed = true;
   return FIG_OK;
   FIG_CATCH
}

int fig_frame_options(int decorations, int buttons) {
   FIG_TRY
   if (decorations < 0 || decorations > 1) return fail(FIG_ERR_ARGUMENT, "init: decorations is 'native' or 'figure'");
   if (buttons < 0 || buttons > 2) return fail(FIG_ERR_ARGUMENT, "init: buttons is 'right' or 'left'");
   if (st.m != mode::none) return FIG_OK; // the init that follows fails: "figure is already initialized"
   frame_options.decorations = decorations;
   frame_options.buttons = buttons;
   return FIG_OK;
   FIG_CATCH
}

int fig_set_icon_rgba(const unsigned char *rgba, int width, int height) {
   FIG_TRY
   if (st.m != mode::window) return fail(FIG_ERR_STATE, std::string("set_icon: there is no window in ") +
                                                         (st.m == mode::none ? "no mode (before init)"
                                                          : st.m == mode::headless ? "headless mode" : "remote mode"));
   if (width <= 0 || height <= 0 || width > 1024 || height > 1024)
      return fail(FIG_ERR_ARGUMENT, "set_icon: the image is rgba(4, width, height), 1 to 1024 pixels a side");
   std::string err;
   if (!set_window_icon(rgba, width, height, err)) return fail(FIG_ERR_FAILED, err);
   if (st.frame.on) { // the bar's icon: a texture of the image
      if (st.frame.icon_tex == 0) p_glGenTextures(1, &st.frame.icon_tex);
      p_glBindTexture(GL_TEXTURE_2D_, st.frame.icon_tex);
      p_glTexParameteri(GL_TEXTURE_2D_, GL_TEXTURE_MIN_FILTER_, static_cast<int>(GL_LINEAR_));
      p_glTexParameteri(GL_TEXTURE_2D_, GL_TEXTURE_MAG_FILTER_, static_cast<int>(GL_LINEAR_));
      p_glPixelStorei(GL_UNPACK_ROW_LENGTH_, 0);
      p_glPixelStorei(GL_UNPACK_ALIGNMENT_, 1);
      p_glTexImage2D(GL_TEXTURE_2D_, 0, static_cast<int>(GL_RGBA_), width, height, 0, GL_RGBA_, GL_UNSIGNED_BYTE_, rgba);
      st.frame.icon_w = width;
      st.frame.icon_h = height;
   }
   st.frame.icon_glyph.clear();
   return FIG_OK;
   FIG_CATCH
}

int fig_set_icon_glyph(const char *icon, int icon_len) {
   FIG_TRY
   if (st.m != mode::window) return fail(FIG_ERR_STATE, std::string("set_icon: there is no window in ") +
                                                         (st.m == mode::none ? "no mode (before init)"
                                                          : st.m == mode::headless ? "headless mode" : "remote mode"));
   const std::string g(icon, icon_len > 0 ? static_cast<size_t>(icon_len) : 0);
   std::vector<unsigned char> rgba;
   std::string err;
   const int side = 64;
   if (!render_icon_glyph(g, side, rgba, err)) return fail(FIG_ERR_ARGUMENT, err);
   if (!set_window_icon(rgba.data(), side, side, err)) return fail(FIG_ERR_FAILED, err);
   if (st.frame.icon_tex != 0) {
      p_glDeleteTextures(1, &st.frame.icon_tex);
      st.frame.icon_tex = 0;
   }
   st.frame.icon_glyph = g;
   return FIG_OK;
   FIG_CATCH
}

int fig_frame_hit(float x, float y, int *hit) {
   *hit = frame_hit(st.frame.geom, x, y);
   return FIG_OK;
}

int fig_frame_rect(int part, float *rect, int *found) {
   if (part < 0 || part >= FRAME_PARTS) return fail(FIG_ERR_ARGUMENT, "frame rectangle: unknown part");
   const frame_rect_t &r = st.frame.geom.parts[part];
   *found = st.frame.geom.valid && r.x1 > r.x0 ? 1 : 0;
   rect[0] = r.x0;
   rect[1] = r.y0;
   rect[2] = r.x1;
   rect[3] = r.y1;
   return FIG_OK;
}

int fig_frame_state(int *minimized, int *maximized) {
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   *minimized = frame_minimized() ? 1 : 0;
   *maximized = frame_maximized() ? 1 : 0;
   return FIG_OK;
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
   if (size > 0.0) {
      // Dear ImGui (1.92) takes the base size at the next NewFrame from _NextFrameFontSizeBase when set, as its own
      // style editor does: a FontSizeBase written alone between frames does not reach the next frame.
      ImGui::GetStyle().FontSizeBase = static_cast<float>(size);
      ImGui::GetStyle()._NextFrameFontSizeBase = static_cast<float>(size);
   }
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

void fig_set_confirm_quit(int on) {
   st.confirm_quit = on != 0;
   if (!st.confirm_quit) st.quit_requested = false;
}

int fig_quit_requested(void) {
   const bool r = st.quit_requested;
   st.quit_requested = false;
   if (r) st.frames_left = 3; // a request is an event: the frames that answer it are drawn
   return r ? 1 : 0;
}

void fig_quit(void) { st.quit_now = true; }

// The window's title after fig_init (the file being edited, a mark when it has changes): shown in window mode, kept
// in every mode (fig_title).
int fig_set_title(const char *title, int title_len) {
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   st.title.assign(title, title_len > 0 ? static_cast<size_t>(title_len) : 0);
   if (st.m == mode::window && st.window && !SDL_SetWindowTitle(st.window, st.title.c_str()))
      return fail(FIG_ERR_FAILED, std::string("SDL_SetWindowTitle: ") + SDL_GetError());
   return FIG_OK;
}

int fig_title(char *buf, int buf_len) {
   const int n = static_cast<int>(st.title.size());
   if (buf_len > 0) std::memcpy(buf, st.title.data(), static_cast<size_t>(std::min(n, buf_len)));
   return n;
}

// A quit request as the window's close button makes it (tests, headless or not).
int fig_input_quit(void) {
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   if (st.confirm_quit) st.quit_requested = true;
   else st.quit_now = true;
   return FIG_OK;
}

void fig_request_frames(int n) {
   if (n > st.frames_left) st.frames_left = n;
}

double fig_content_scale(void) { return st.scale; }

void apply_test_input(); // figure_testing's queued input (defined with the synthetic input below)

int fig_begin_frame(int *running) {
   FIG_TRY
   if (fig_task_refuse("app%next_frame", 14)) return FIG_ERR_STATE; // a task does not draw
   *running = 0;
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   if (st.in_frame) return fail(FIG_ERR_STATE, "begin_frame called twice without end_frame");
   *running = 1;
   if (st.quit_now) { // fig_quit, in every mode
      st.quit_now = false;
      *running = 0;
      return FIG_OK;
   }
   if (st.system_theme_changed) { // a test's change of the system's light or dark setting, handled as SDL's event
      st.system_theme_changed = false;
      system_theme_changed();
   }
   if (st.m == mode::headless) {
      ImGui::GetIO().DeltaTime = 1.0f / 60.0f;
      apply_test_input();
      apply_layout(); // a layout asked for by fig_load_layout: between frames, as Dear ImGui wants it
      ImGui::NewFrame();
      st.in_frame = true;
      frame_bar_open();
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
      bool got = false;
      if (wait && background.load() > 0) { // in slices, so that a reader or a task can end the wait
         const auto until = std::chrono::steady_clock::now() + std::chrono::milliseconds(st.max_wait_ms);
         while (!got && !woken.load() && std::chrono::steady_clock::now() < until) got = figure_remote::serve(10);
         got = got || woken.load();
      } else {
         got = figure_remote::serve(wait ? st.max_wait_ms : 0);
      }
      woken = false;
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
      apply_layout(); // a layout asked for by fig_load_layout: between frames, as Dear ImGui wants it
      ImGui::NewFrame();
      st.in_frame = true;
      frame_bar_open();
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
      if (e.type == SDL_EVENT_SYSTEM_THEME_CHANGED && st.system_theme < 0) system_theme_changed();
      if (e.type == SDL_EVENT_QUIT ||
          (e.type == SDL_EVENT_WINDOW_CLOSE_REQUESTED && e.window.windowID == SDL_GetWindowID(st.window))) {
         if (st.confirm_quit) st.quit_requested = true; // the program asks first, then calls fig_quit
         else *running = 0;
      }
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
   woken = false;
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
   apply_layout(); // a layout asked for by fig_load_layout: between frames, as Dear ImGui wants it
   ImGui::NewFrame();
   st.in_frame = true;
   frame_bar_open();
   return FIG_OK;
   FIG_CATCH
}

int fig_end_frame(void) {
   FIG_TRY
   if (fig_task_refuse("app%next_frame", 14)) return FIG_ERR_STATE; // a task does not draw
   if (!st.in_frame) return fail(FIG_ERR_STATE, "end_frame without begin_frame");
   frame_bar_close();
   fig_file_browser_draw(); // FIGURE's file browser, a modal over the program's windows
   draw_notifications();    // after the program's windows, above them
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
   if (img.state == 1) image_write(io);
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
      fig_process_shutdown(); // the captured children end with the program (before SDL_Quit)
      if (st.in_frame) {
         ImGui::EndFrame();
         st.in_frame = false;
      }
      if (st.m == mode::window) {
         if (st.frame.icon_tex != 0) p_glDeleteTextures(1, &st.frame.icon_tex);
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
         sdl_events = false;
         SDL_GL_DestroyContext(st.gl);
         SDL_DestroyWindow(st.window);
         SDL_Quit();
      }
   } catch (...) {
   }
   st = state_t{};
   cap = capture_t{};
   notes.clear();
   note_rects.clear();
   fig_file_browser_reset(0, 0);
}

int fig_texture_create(int width, int height, int smooth, unsigned long long *id) {
   FIG_TRY
   if (fig_task_refuse("texture_object%init", 19)) return FIG_ERR_STATE; // a task does not draw
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
   if (fig_task_refuse("texture_object%update", 21)) return FIG_ERR_STATE; // a task does not draw
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

// A bar along one side of the display (Dear ImGui's viewport side bar, as the main menu bar is): it takes its size
// from the work area, so a dock space over the viewport (fig_dock_space) and the windows placed in the work area leave
// it free. side: 0 left, 1 right, 2 top, 3 bottom. Returns 1 when its content is drawn; ImGui::End always follows.
int fig_begin_side_bar(const char *name, int name_len, int side, double size) {
   const std::string n(name, name_len > 0 ? static_cast<size_t>(name_len) : 0);
   const ImGuiDir dir = side == 0 ? ImGuiDir_Left : side == 1 ? ImGuiDir_Right : side == 2 ? ImGuiDir_Up : ImGuiDir_Down;
   const ImGuiWindowFlags flags = ImGuiWindowFlags_NoScrollbar | ImGuiWindowFlags_NoScrollWithMouse |
                                  ImGuiWindowFlags_NoSavedSettings;
   return ImGui::BeginViewportSideBar(n.c_str(), ImGui::GetMainViewport(), dir, static_cast<float>(size), flags) ? 1 : 0;
}

// A workspace button: an icon above its label (Fusion 360's style), on a framed, rounded button that shades under the
// pointer; selected, it is framed and tinted in the accent colour (accent[3] < 0: the style's CheckMark colour) and
// the icon is drawn in it. width/height <= 0: the default size (as wide as the label, room for the icon at 1.8 font
// sizes). The label's text before "##" is shown; the whole label is the id. Returns 1 on the frame it is clicked.
int fig_tool_button(const char *label, int label_len, const char *icon, int icon_len, double width, double height,
                    int selected, const double *accent) {
   const std::string lab(label, label_len > 0 ? static_cast<size_t>(label_len) : 0);
   const std::string ic(icon, icon_len > 0 ? static_cast<size_t>(icon_len) : 0);
   const float fs = ImGui::GetFontSize();
   const char *shown_end = ImGui::FindRenderedTextEnd(lab.c_str());
   const ImVec2 text = ImGui::CalcTextSize(lab.c_str(), shown_end);
   const float icon_px = 1.8f * fs;
   const float w = width > 0.0 ? static_cast<float>(width) : std::max(4.6f * fs, text.x + 1.2f * fs);
   const float h = height > 0.0 ? static_cast<float>(height) : icon_px + 2.0f * fs;
   const ImVec4 acc = accent[3] < 0.0 ? ImGui::GetStyleColorVec4(ImGuiCol_CheckMark)
                                      : ImVec4(static_cast<float>(accent[0]), static_cast<float>(accent[1]),
                                               static_cast<float>(accent[2]), 1.0f);
   const ImVec4 ink = ImGui::GetStyleColorVec4(ImGuiCol_Text);
   ImGui::PushStyleVar(ImGuiStyleVar_FrameRounding, 0.35f * fs);
   ImGui::PushStyleVar(ImGuiStyleVar_FrameBorderSize, (selected ? 2.0f : 1.0f) * std::max(1.0f, fs / 15.0f));
   if (selected) {
      ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(acc.x, acc.y, acc.z, 0.22f));
      ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(acc.x, acc.y, acc.z, 0.32f));
      ImGui::PushStyleColor(ImGuiCol_ButtonActive, ImVec4(acc.x, acc.y, acc.z, 0.42f));
      ImGui::PushStyleColor(ImGuiCol_Border, acc);
   } else {
      ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(ink.x, ink.y, ink.z, 0.0f));
      ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(ink.x, ink.y, ink.z, 0.10f));
      ImGui::PushStyleColor(ImGuiCol_ButtonActive, ImVec4(ink.x, ink.y, ink.z, 0.18f));
   }
   const bool clicked = ImGui::Button(("##" + lab).c_str(), ImVec2(w, h));
   ImGui::PopStyleColor(selected ? 4 : 3);
   ImGui::PopStyleVar(2);
   const ImVec2 at = ImGui::GetItemRectMin();
   ImDrawList *dl = ImGui::GetWindowDrawList();
   ImFont *font = ImGui::GetFont();
   const ImVec2 isz = font->CalcTextSizeA(icon_px, FLT_MAX, 0.0f, ic.c_str());
   dl->AddText(font, icon_px, ImVec2(at.x + 0.5f * (w - isz.x), at.y + 0.3f * fs),
               ImGui::GetColorU32(selected ? acc : ink), ic.c_str());
   dl->AddText(font, fs, ImVec2(at.x + 0.5f * (w - text.x), at.y + h - 1.45f * fs), ImGui::GetColorU32(ink),
               lab.c_str(), shown_end);
   return clicked ? 1 : 0;
}

// Dear ImGui's list clipper: only the rows of a long list that are in view are drawn (rows of equal height).
void *fig_clipper_new(void) { return IM_NEW(ImGuiListClipper)(); }

void fig_clipper_begin(void *clipper, int count, double item_height) {
   static_cast<ImGuiListClipper *>(clipper)->Begin(count, static_cast<float>(item_height));
}

// The next range of rows to draw, 1-based [first, last]: 1 while there is one; 0 at the end (the clipper ended).
int fig_clipper_step(void *clipper, int *first, int *last) {
   ImGuiListClipper *c = static_cast<ImGuiListClipper *>(clipper);
   if (!c->Step()) return 0;
   *first = c->DisplayStart + 1;
   *last = c->DisplayEnd;
   return 1;
}

void fig_clipper_delete(void *clipper) {
   ImGuiListClipper *c = static_cast<ImGuiListClipper *>(clipper);
   if (c->ItemsCount >= 0 && ImGui::GetCurrentContext()) c->End(); // left before its end
   IM_DELETE(c);
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

// File dialogs (SDL3's native ones), window mode only. The dialog is asynchronous: its callback, possibly on another
// thread, stores the result in the dialog's entry and wakes the loop with an SDL event; the program polls the entry
// by its id (fig_file_dialog_result) on later frames, so the interface keeps drawing meanwhile. An entry lives from
// fig_file_dialog to the poll that returns its result; its filters live as long, as SDL requires.
struct file_dialog_t {
   int                               state = 0; // 0 pending, 1 chosen, 2 cancelled, 3 failed
   std::string                       path, error;
   std::vector<std::string>          names, patterns;
   std::vector<SDL_DialogFileFilter> filters;
};
std::mutex                                            dialogs_mutex;
std::map<std::string, std::unique_ptr<file_dialog_t>> dialogs;

void SDLCALL file_dialog_done(void *userdata, const char *const *filelist, int) {
   auto *d = static_cast<file_dialog_t *>(userdata);
   {
      std::lock_guard<std::mutex> lock(dialogs_mutex);
      if (!filelist) {
         d->state = 3;
         d->error = SDL_GetError();
      } else if (!*filelist) {
         d->state = 2;
      } else {
         d->state = 1;
         d->path = *filelist;
      }
   }
   SDL_Event e;
   SDL_zero(e);
   e.type = SDL_EVENT_USER; // wake a lazy loop: the result is drawn at once
   SDL_PushEvent(&e);
}

// kind: 0 open a file, 1 save a file, 2 open a folder. filters: "name|pattern" entries separated by newlines, the pattern
// as SDL wants it ("input;inp", "*" for any). An id with a dialog still open is refused.
int fig_file_dialog(int kind, const char *id, int id_len, const char *filters, int filters_len, const char *path,
                    int path_len) {
   FIG_TRY
   if (st.m != mode::window)
      return fail(FIG_ERR_STATE, "file dialogs need a window: in remote and headless modes ask for the path in a field");
   if (kind < 0 || kind > 2) return fail(FIG_ERR_ARGUMENT, "file dialog: unknown kind");
   const std::string key(id, id_len > 0 ? static_cast<size_t>(id_len) : 0);
   if (fig_file_browser_pending(id, id_len)) return fail(FIG_ERR_STATE, "file browser \"" + key + "\" is already open");
   auto d = std::make_unique<file_dialog_t>();
   const std::string f(filters, filters_len > 0 ? static_cast<size_t>(filters_len) : 0);
   for (size_t start = 0; start < f.size();) {
      size_t end = f.find('\n', start);
      if (end == std::string::npos) end = f.size();
      const std::string entry = f.substr(start, end - start);
      const size_t bar = entry.find('|');
      if (!entry.empty()) {
         if (bar == std::string::npos)
            return fail(FIG_ERR_ARGUMENT, "file dialog: a filter is \"name|pattern\", got \"" + entry + "\"");
         d->names.push_back(entry.substr(0, bar));
         d->patterns.push_back(entry.substr(bar + 1));
      }
      start = end + 1;
   }
   for (size_t i = 0; i < d->names.size(); ++i) d->filters.push_back({d->names[i].c_str(), d->patterns[i].c_str()});
   // The default location, absolute: the dialog may be shown by another process (the desktop portal, zenity) that
   // resolves a relative path against its own working directory (the user's home), not the program's. No location: the
   // program's working directory.
   std::string where(path, path_len > 0 ? static_cast<size_t>(path_len) : 0);
   {
      std::error_code ec;
      const std::filesystem::path abs = std::filesystem::absolute(where.empty() ? "." : where, ec);
      if (!ec) where = abs.lexically_normal().string();
   }
   file_dialog_t *raw = d.get();
   {
      std::lock_guard<std::mutex> lock(dialogs_mutex);
      auto it = dialogs.find(key);
      if (it != dialogs.end() && it->second->state == 0)
         return fail(FIG_ERR_STATE, "file dialog \"" + key + "\" is already open");
      dialogs[key] = std::move(d);
   }
   const SDL_DialogFileFilter *fl = raw->filters.empty() ? nullptr : raw->filters.data();
   const int nf = static_cast<int>(raw->filters.size());
   const char *loc = where.empty() ? nullptr : where.c_str(); // SDL copies it
   if (kind == 0) SDL_ShowOpenFileDialog(file_dialog_done, raw, st.window, fl, nf, loc, false);
   else if (kind == 1) SDL_ShowSaveFileDialog(file_dialog_done, raw, st.window, fl, nf, loc);
   else SDL_ShowOpenFolderDialog(file_dialog_done, raw, st.window, loc, false);
   return FIG_OK;
   FIG_CATCH
}

// The result of dialog id: state 0 still open, 1 chosen (the path in buf, its full length in path_len, cut to buf_len),
// 2 cancelled, 3 failed (FIG_ERR_FAILED, with SDL's message); an id with no dialog is state 0, so a program can poll
// every frame. A final state is returned once: the entry is then forgotten.
int fig_file_dialog_result(const char *id, int id_len, char *buf, int buf_len, int *state, int *path_len) {
   const std::string key(id, id_len > 0 ? static_cast<size_t>(id_len) : 0);
   *state = 0;
   *path_len = 0;
   std::unique_ptr<file_dialog_t> done;
   {
      std::lock_guard<std::mutex> lock(dialogs_mutex);
      auto it = dialogs.find(key);
      if (it == dialogs.end()) // no system dialog with this id: FIGURE's browser, if any (else state 0)
         return fig_file_browser_result(id, id_len, buf, buf_len, state, path_len);
      *state = it->second->state;
      if (*state == 0) return FIG_OK;
      done = std::move(it->second);
      dialogs.erase(it);
   }
   if (*state == 1) {
      *path_len = static_cast<int>(done->path.size());
      const int n = std::min(*path_len, buf_len);
      if (n > 0) std::memcpy(buf, done->path.data(), static_cast<size_t>(n));
   }
   if (*state == 3) {
#if defined(__linux__)
      return fail(FIG_ERR_FAILED, "file dialog: " + done->error +
                                  " (Linux needs xdg-desktop-portal or zenity at run time)");
#else
      return fail(FIG_ERR_FAILED, "file dialog: " + done->error);
#endif
   }
   return FIG_OK;
}

int fig_file_dialog_pending(const char *id, int id_len) {
   const std::string           key(id, id_len > 0 ? static_cast<size_t>(id_len) : 0);
   std::lock_guard<std::mutex> lock(dialogs_mutex);
   const auto                  it = dialogs.find(key);
   return it != dialogs.end() && it->second->state == 0 ? 1 : 0;
}

int fig_save_layout(const char *path, int path_len, const char *comment, int comment_len) {
   FIG_TRY
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   if (path_len <= 0) return fail(FIG_ERR_ARGUMENT, "save_layout: no file name");
   const std::string p(path, static_cast<size_t>(path_len));
   const std::string c(comment, comment_len > 0 ? static_cast<size_t>(comment_len) : 0);
   size_t n = 0;
   const char *ini = ImGui::SaveIniSettingsToMemory(&n);
   FILE *f = std::fopen(p.c_str(), "wb");
   if (!f) return fail(FIG_ERR_FAILED, "save_layout: cannot write " + p);
   for (size_t start = 0; start < c.size();) { // the program's lines, as comments Dear ImGui skips
      size_t end = c.find('\n', start);
      if (end == std::string::npos) end = c.size();
      std::fprintf(f, "; %s\n", c.substr(start, end - start).c_str());
      start = end + 1;
   }
   const bool ok = std::fwrite(ini, 1, n, f) == n;
   std::fclose(f);
   if (!ok) return fail(FIG_ERR_FAILED, "save_layout: cannot write " + p);
   return FIG_OK;
   FIG_CATCH
}

int fig_load_layout(const char *path, int path_len) {
   FIG_TRY
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   if (path_len <= 0) return fail(FIG_ERR_ARGUMENT, "load_layout: no file name");
   const std::string p(path, static_cast<size_t>(path_len));
   FILE *f = std::fopen(p.c_str(), "rb");
   if (!f) return fail(FIG_ERR_FAILED, "load_layout: cannot read " + p);
   std::string data;
   char buf[4096];
   for (size_t n; (n = std::fread(buf, 1, sizeof(buf), f)) > 0;) data.append(buf, n);
   std::fclose(f);
   if (data.find("[Window][") == std::string::npos && data.find("[Docking][") == std::string::npos)
      return fail(FIG_ERR_ARGUMENT, "load_layout: " + p + " is not a layout (no [Window] or [Docking] section)");
   layout_pending = data;
   layout_due = true;
   st.frames_left = std::max(st.frames_left, 3);
   return FIG_OK;
   FIG_CATCH
}

int fig_save_image(const char *path, int path_len, double x0, double y0, double x1, double y1) {
   FIG_TRY
   if (st.m != mode::window)
      return fail(FIG_ERR_STATE, "save_image needs a window: in remote and headless modes there are no pixels here");
   if (path_len <= 0) return fail(FIG_ERR_ARGUMENT, "save_image: no file name");
   if (!(x1 > x0) || !(y1 > y0)) return fail(FIG_ERR_ARGUMENT, "save_image: an empty rectangle");
   img = image_request_t{};
   img.path.assign(path, static_cast<size_t>(path_len));
   img.x0 = static_cast<float>(x0);
   img.y0 = static_cast<float>(y0);
   img.x1 = static_cast<float>(x1);
   img.y1 = static_cast<float>(y1);
   img.state = 1;
   st.frames_left = std::max(st.frames_left, 2); // the frame that renders it, even in lazy mode
   return FIG_OK;
   FIG_CATCH
}

int fig_image_result(char *buf, int buf_len, int *state, int *path_len) {
   *state = 0;
   *path_len = 0;
   if (img.state < 2) return FIG_OK; // none, or not rendered yet
   *state = img.state;
   *path_len = static_cast<int>(img.path.size());
   const int n = std::min(*path_len, buf_len);
   if (n > 0) std::memcpy(buf, img.path.data(), static_cast<size_t>(n));
   const int s = img.state;
   const std::string err = img.error;
   img = image_request_t{};
   if (s == 3) return fail(FIG_ERR_FAILED, err);
   return FIG_OK;
}

// A key chord from its name, "ctrl+s", "ctrl+shift+f5", "escape": modifiers (ctrl, shift, alt, super) and one key, by
// the names of test_key, joined by '+'. With ConfigMacOSXBehaviors (macOS), Dear ImGui reads ctrl as the cmd key.
int fig_key_chord(const char *keys, int keys_len, int *chord) {
   const std::string s(keys, keys_len > 0 ? static_cast<size_t>(keys_len) : 0);
   int mods = 0, key = ImGuiKey_None;
   size_t start = 0;
   while (start <= s.size()) {
      size_t end = s.find('+', start);
      if (end == std::string::npos) end = s.size();
      const std::string name = s.substr(start, end - start);
      const ImGuiKey k = key_by_name(name);
      if (k == ImGuiKey_None) return fail(FIG_ERR_ARGUMENT, "ig_shortcut: unknown key \"" + name + "\" in \"" + s + "\"");
      if (k & ImGuiMod_Mask_) {
         mods |= k;
      } else {
         if (key != ImGuiKey_None) return fail(FIG_ERR_ARGUMENT, "ig_shortcut: more than one key in \"" + s + "\"");
         key = k;
      }
      start = end + 1;
   }
   if (key == ImGuiKey_None) return fail(FIG_ERR_ARGUMENT, "ig_shortcut: no key besides the modifiers in \"" + s + "\"");
   *chord = mods | key;
   return FIG_OK;
}

int fig_input_key(const char *name, int name_len, int down) {
   if (!ImGui::GetCurrentContext()) return fail(FIG_ERR_STATE, "figure is not initialized");
   const std::string n(name, name_len > 0 ? static_cast<size_t>(name_len) : 0);
   // "shortcut": the platform's shortcut key, the one ig_shortcut's ctrl means: cmd (super) on macOS, where Dear ImGui
   // swaps it with ctrl as the events arrive, ctrl elsewhere
#if defined(__APPLE__)
   const ImGuiKey k = n == "shortcut" ? ImGuiMod_Super : key_by_name(n);
#else
   const ImGuiKey k = n == "shortcut" ? ImGuiMod_Ctrl : key_by_name(n);
#endif
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

// A tick label of the plot being declared (between BeginPlot and EndPlot, after its setup): axis 0 x, 1 y; index from 1;
// count is the number of ticks. For tests of axis formats.
int fig_plot_tick_label(int axis, int index, char *buf, int buf_len, int *count, int *len) {
   *count = 0;
   *len = 0;
   ImPlotPlot *plot = ImPlot::GetCurrentContext() ? ImPlot::GetCurrentPlot() : nullptr;
   if (!plot)
      return fail(FIG_ERR_STATE, "test_plot_tick: no plot is being declared (between ip_begin_plot and ip_end_plot)");
   if (axis != 0 && axis != 1) return fail(FIG_ERR_ARGUMENT, "test_plot_tick: axis is 'x' or 'y'");
   ImPlot::SetupLock(); // the ticks exist once the setup is locked (the first item locks it)
   const ImPlotTicker &ticker = plot->Axes[axis == 0 ? ImAxis_X1 : ImAxis_Y1].Ticker;
   *count = ticker.TickCount();
   if (index < 1 || index > *count) return FIG_OK;
   const char *text = ticker.GetText(index - 1);
   *len = static_cast<int>(std::strlen(text));
   const int n = std::min(*len, buf_len);
   if (n > 0) std::memcpy(buf, text, static_cast<size_t>(n));
   return FIG_OK;
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

// A text field over a caller-owned buffer of buf_size bytes (NUL-terminated, the text at most buf_size - 1 bytes): Dear
// ImGui's InputText/InputTextWithHint without a callback, which the bindings generator skips. Returns 1 when the user
// edited the text this frame. An empty hint draws no hint.
int fig_widget_input_text(const char *label, int label_len, const char *hint, int hint_len, char *buf, int buf_size,
                          int flags) {
   if (!ImGui::GetCurrentContext() || buf_size < 1) return 0;
   const std::string l(label, label_len > 0 ? static_cast<size_t>(label_len) : 0);
   const bool edited = hint_len > 0
      ? ImGui::InputTextWithHint(l.c_str(), std::string(hint, static_cast<size_t>(hint_len)).c_str(), buf,
                                 static_cast<size_t>(buf_size), static_cast<ImGuiInputTextFlags>(flags))
      : ImGui::InputText(l.c_str(), buf, static_cast<size_t>(buf_size), static_cast<ImGuiInputTextFlags>(flags));
   return edited ? 1 : 0;
}

void fig_input_mouse(float x, float y, int left_down) {
   if (!ImGui::GetCurrentContext()) return;
   ImGuiIO &io = ImGui::GetIO();
   io.AddMousePosEvent(x, y);
   io.AddMouseButtonEvent(ImGuiMouseButton_Left, left_down != 0);
}

} // extern "C"

extern "C" void fig_wake(void) {
   if (woken.exchange(true)) return; // one wake-up per frame is enough
   if (sdl_events.load()) {
      SDL_Event e;
      SDL_zero(e);
      e.type = SDL_EVENT_USER;
      SDL_PushEvent(&e);
   }
}

extern "C" void fig_background(int delta) { background += delta; }

extern "C" int fig_notify(const char *text, int text_len, int kind, const char *icon, int icon_len, double seconds) {
   FIG_TRY
   if (fig_task_refuse("app%notify", 10)) return FIG_ERR_STATE; // a task does not draw
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "notify: figure is not initialized");
   if (kind < 0 || kind > 3) return fail(FIG_ERR_ARGUMENT, "notify: kind is 'info', 'success', 'warning' or 'error'");
   note_t n;
   n.id = next_note++;
   n.kind = kind;
   n.text.assign(text, text_len > 0 ? static_cast<size_t>(text_len) : 0);
   n.icon.assign(icon, icon_len > 0 ? static_cast<size_t>(icon_len) : 0);
   n.seconds = static_cast<float>(seconds);
   notes.push_back(n);
   while (notes.size() > NOTE_KEEP) notes.pop_front();
   st.frames_left = std::max(st.frames_left, 3); // drawn at once, even with lazy redraw
   fig_wake();
   return FIG_OK;
   FIG_CATCH
}

extern "C" int fig_notification_count(int *count) {
   *count = static_cast<int>(notes.size());
   return FIG_OK;
}

extern "C" int fig_notification_get(int index, char *buf, int buf_len, int *len, int *kind, int *shown) {
   *len = 0;
   *kind = 0;
   *shown = 0;
   if (index < 1 || index > static_cast<int>(notes.size())) return fail(FIG_ERR_ARGUMENT, "notification: no such index");
   const note_t &n = notes[static_cast<size_t>(index - 1)];
   *len = static_cast<int>(n.text.size());
   if (buf && buf_len > 0) std::memcpy(buf, n.text.data(), static_cast<size_t>(std::min(*len, buf_len)));
   *kind = n.kind;
   *shown = n.shown ? 1 : 0;
   return FIG_OK;
}

extern "C" int fig_notification_rect(int index, float *rect, int *found) {
   *found = 0;
   if (index < 1 || index > static_cast<int>(note_rects.size())) return FIG_OK;
   const frame_rect_t &r = note_rects[static_cast<size_t>(index - 1)];
   rect[0] = r.x0;
   rect[1] = r.y0;
   rect[2] = r.x1;
   rect[3] = r.y1;
   *found = 1;
   return FIG_OK;
}

extern "C" int fig_drawn_extent(const char *color, int color_len, float *rect, int *found) {
   *found = 0;
   if (!ImGui::GetCurrentContext() || !ImGui::GetCurrentWindowRead())
      return fail(FIG_ERR_STATE, "test_drawn_extent: call it inside a window, in a frame");
   const std::string name(color, color_len > 0 ? static_cast<size_t>(color_len) : 0);
   int col = -1;
   for (int i = 0; i < ImGuiCol_COUNT; ++i)
      if (name == ImGui::GetStyleColorName(i)) col = i;
   if (col < 0) return fail(FIG_ERR_ARGUMENT, "test_drawn_extent: unknown colour \"" + name + "\" (Dear ImGui's names)");
   const ImU32 c = ImGui::GetColorU32(col);
   const ImDrawList *dl = ImGui::GetWindowDrawList();
   for (const ImDrawVert &v : dl->VtxBuffer) {
      if (v.col != c) continue;
      if (!*found) {
         rect[0] = rect[2] = v.pos.x;
         rect[1] = rect[3] = v.pos.y;
         *found = 1;
      }
      rect[0] = std::min(rect[0], v.pos.x);
      rect[1] = std::min(rect[1], v.pos.y);
      rect[2] = std::max(rect[2], v.pos.x);
      rect[3] = std::max(rect[3], v.pos.y);
   }
   return FIG_OK;
}
