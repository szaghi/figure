// FIGURE native glue: SDL3 window + OpenGL3 renderer + Dear ImGui/ImPlot contexts, behind the C ABI of figure_native.h.
#include "figure_native.h"
#include "figure_fonts.h"
#include "figure_image.h"
#include "figure_items.h"
#include "figure_remote.h"
#include "figure_swrast.h"
#include "figure_style.h"
#include "figure_theme.h"

#include "imgui.h"
#include "imgui_internal.h" // DockBuilder*: Dear ImGui keeps the dock builder internal
#include "imgui_impl_opengl3.h"
#include "imgui_impl_sdl3.h"
#include "implot.h"
#include "implot_internal.h" // GetStyleColorVec4: ImPlot's automatic colours resolved
#include "implot3d.h"        // ImPlot3D's context, beside ImPlot's
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

#include <cfenv>
#include <climits>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <chrono>
#include <ctime>
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
#include <thread>
#include <vector>

namespace {

// The last failure's message, one per thread (as errno): a task that fails (fig_image_read) does not overwrite the
// main thread's, and the two never race on it.
thread_local std::string last_error;

// Work off the frame loop (process readers, tasks, any thread calling app%wake, request_frames or quit) wakes it:
// window mode pushes an SDL event (SDL_PushEvent is safe from any thread); remote mode, which waits on its sockets,
// sends a datagram to its wake socket, one of those it waits on; headless mode never waits.
std::atomic<bool> woken{false};       // fig_wake since the last frame began to wait: its wake-up is on its way
std::atomic<std::thread::id> main_thread{}; // the thread that called fig_init*: the one that runs the frame loop

bool on_main_thread() { return std::this_thread::get_id() == main_thread.load(); }

// fig_init*: this thread runs the frame loop; no wake-up is pending.
void loop_starts() {
   main_thread = std::this_thread::get_id();
   woken = false;
}
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

// A field of the state that another thread may write or read while the main thread uses it (the calls processes.md
// lets a task make: quit, quit_requested, request_frames, set_lazy, set_confirm_quit, content_scale): atomic, and still
// copied, so that st = state_t{} resets it (fig_shutdown, no other thread calling then).
template <class T> struct shared : std::atomic<T> {
   using std::atomic<T>::atomic;
   using std::atomic<T>::operator=;
   shared(const shared &o) : std::atomic<T>(o.load()) {}
   shared &operator=(const shared &o) {
      this->store(o.load());
      return *this;
   }
};

struct state_t {
   mode          m = mode::none;
   SDL_Window   *window = nullptr;
   SDL_GLContext gl = nullptr;
   bool          in_frame = false;
   shared<bool>  lazy{true};      // wait for events instead of redrawing continuously
   shared<bool>  confirm_quit{false};   // a quit request is reported (fig_quit_requested) instead of ending the loop
   shared<bool>  quit_requested{false}; // a request not yet read by fig_quit_requested
   shared<bool>  quit_now{false};       // fig_quit: the next fig_begin_frame ends the loop
   std::string   title;                  // the window's title (kept in every mode: fig_title)
   shared<int>   max_wait_ms{500};
   shared<int>   frames_left{3}; // frames still to draw after the last event (ImGui settles in a few): raised by
                                 // frames_at_least, lowered by the loop alone (frame_drawn)
   shared<float> scale{1.0f};
   float         clear[3] = {0.10f, 0.10f, 0.11f}; // the window's background, behind the ImGui windows (the style's)
   std::string   style_base = "dark";              // base of the style in effect (what save_style writes against)
   std::string   look;                             // the look in effect (themes/looks); empty: Dear ImGui's geometry
   float         title_bar = 0.0f;                 // the height of FIGURE's title bar [logical pixels]; 0: the menu
                                                   // bar's (a look's or theme's [figure.vars] TitleBarHeight)
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
   std::string   font = "plex-sans";               // the default font: plex-sans, plex-mono, proggy, or a TTF file
   std::map<std::string, ImFont *> fonts;          // fonts loaded in this context, by name or path
   std::map<std::string, std::vector<unsigned char>> font_data; // TTF files read at run time (the atlas needs them)
   std::map<const ImFont *, float> font_em;        // a text font's em per pixel of size (see em_per_size)
   // The program's own fallback fonts (app%add_fallback_font), in order: path and bytes (a deque: the bytes stay put)
   std::deque<std::pair<std::string, std::vector<unsigned char>>> fallbacks;
   size_t fallbacks_merged = 0; // the first ones, merged into the fonts; the others wait for the next frame
   struct saved_t {                                // a style value changed by a push, and what it was
      unsigned char             *where = nullptr;
      std::vector<unsigned char> was;
   };
   std::vector<saved_t> pushed_colors, pushed_vars; // scoped changes, undone by the pops (newest last)
   struct input_t {                                // synthetic input (figure_testing), applied at the next frames
      int         kind = 0;                        // 0 step (a frame boundary), 1 pos, 2 button, 3 wheel, 4 key, 5 text,
                                                   // 6 a dropped path (text) at (x, y)
      float       x = 0.0f, y = 0.0f;
      int         a = 0, b = 0;
      std::string text;
   };
   std::vector<input_t> test_input;                // queued, oldest first
   std::vector<std::string> drops;                 // paths dropped since the last frame began (SDL, tests, capture)
   float         drop_x = 0.0f, drop_y = 0.0f;     // ... where the last one was dropped [pixels]
   std::vector<std::string> dropped;               // the paths dropped for this frame (app%dropped)
   float         dropped_x = 0.0f, dropped_y = 0.0f;
   std::string   ini_file;        // where Dear ImGui keeps window positions and sizes; empty: nowhere (the default)
   struct texture_t {
      int  width = 0, height = 0;
      bool smooth = false;
      std::vector<unsigned char> rgba; // headless mode: the pixels, for the CPU renderer (remote mode keeps its own)
   };
   std::chrono::steady_clock::time_point last_frame; // remote mode: the frame clock (no SDL)
   double        remote_min_dt = 1.0 / 60.0;           // remote mode: shortest time between frames [s] (0: no cap)
   std::map<unsigned long long, texture_t> textures; // user textures by ImTextureID (the GL name in window mode)
   unsigned long long next_headless_texture = 1;     // headless mode: ids without GL objects
   bool          window_capture = false; // headless mode started by fig_init (FIGURE_CAPTURE_HEADLESS): a window's
                                         // program, whose set_icon then gives the bar its icon as in the window
} st;

// At least n more frames, from any thread: a compare-and-swap maximum, so that concurrent requests keep the largest
// and an event never lowers a request.
void frames_at_least(int n) {
   int cur = st.frames_left.load();
   while (n > cur && !st.frames_left.compare_exchange_weak(cur, n)) {
   }
}

// A frame begun without an event (the loop, on the main thread): one frame fewer to draw, never below 0, a request
// raised meanwhile by another thread kept.
void frame_without_event() {
   int cur = st.frames_left.load();
   while (cur > 0 && !st.frames_left.compare_exchange_weak(cur, cur - 1)) {
   }
}

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

// Frame capture, enabled by the environment variable FIGURE_CAPTURE=<prefix>, in every mode: every frame drawn is
// written to <prefix>NNNNN.ppm, for documentation screenshots and animations; a window's frames are read back from the
// GPU, headless and remote modes render theirs with FIGURE's CPU renderer (figure_swrast.cpp).
// FIGURE_CAPTURE_HEADLESS=1 makes fig_init start headless mode instead of a window (same size, no SDL): the frames of
// a window program without a display or a GPU (scripts/docs_media.py --check). Capture is hermetic: the
// real mouse and keyboard are ignored (the program scripts its own input with fig_input_mouse), the content scale is
// 1, lazy redraw is off and the frame clock is fixed (FIGURE_CAPTURE_FPS, default 30), so the frames depend only on
// the program. FIGURE_CAPTURE_FROM=N skips the first N frames (default 0); FIGURE_CAPTURE_FRAMES=N ends the program
// (next_frame returns false) after N frames written. FIGURE_CAPTURE_INPUT=<file> replays scripted input, one event per
// line ("#" starts a comment), at the frame given first (frames counted from 0, skipped ones included):
//    <frame> move <x> <y> [<n>]          the pointer glides to (x, y) [pixels] over n frames (default 1)
//    <frame> down|up [left|right|middle] a button is pressed or released (default left)
//    <frame> wheel <dx> <dy>             the wheel turns (positive dy: away from the user)
//    <frame> text <characters>           characters are typed (the rest of the line, after one space)
//    <frame> drop <x> <y> <path>         a file or folder is dropped on the window at (x, y) [pixels]
//    <frame> key <name> [down|up]        a key, by the names of test_key: a-z, 0-9, f1-f12, enter, tab, backspace,
//                                        delete, escape, space, arrows, home, end, pageup, pagedown, ctrl, shift, alt,
//                                        super (press and release when down|up is omitted)
//    <frame> close                       the window's close button is clicked (a quit request)
// With an input script Dear ImGui draws its own mouse cursor, so the pointer shows in the frames. In remote mode the
// browser's input still reaches the program (the recording is of the session), with the fixed clock and the script.
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
   bool        hold = false;      // a "wait" holds the script: until no task or process is busy
   bool        held = false;      // this frame is held: not counted, not written, no scripted input
   int         idle = 0;          // held frames in a row with nothing busy
   Uint64      hold_t0 = 0;       // when the hold began [ns]
} cap;
constexpr int    HOLD_IDLE = 10;                          // idle frames that end a hold
constexpr Uint64 HOLD_LIMIT = 600ull * SDL_NS_PER_SECOND; // a hold longer than this ends, with a warning

// Drops: a path dropped on the window (SDL's drop events; a test's or a capture script's), at (x, y) [pixels]; the
// paths dropped before a frame begins are that frame's (app%dropped), and only that frame's.
void drop_path(const std::string &path, float x, float y) {
   st.drops.push_back(path);
   st.drop_x = x;
   st.drop_y = y;
}

void take_drops() {
   st.dropped = std::move(st.drops);
   st.drops.clear();
   st.dropped_x = st.drop_x;
   st.dropped_y = st.drop_y;
}

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
         e.arg = l.size() > l.find("text") + 5 ? l.substr(l.find("text") + 5) : ""; // after one space: the rest typed
      } else if (e.what == "drop") {
         int at = 0;
         ok = std::sscanf(rest, "%f %f %n", &e.x, &e.y, &at) == 2 && rest[at] != '\0';
         if (ok) e.arg = rest + at;
      } else if (e.what == "close" || e.what == "wait") {
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

// A hold begins: the thread waits, drawing nothing, until no task runs and no process is alive or still has output to
// be read (at most HOLD_LIMIT): the program then takes each result whole, in one frame; the held frames that follow
// see to what it does with them.
void capture_hold() {
   cap.hold = true;
   cap.idle = 0;
   cap.hold_t0 = SDL_GetTicksNS();
   while ((fig_tasks_busy() > 0 || fig_processes_busy(0) > 0) && SDL_GetTicksNS() - cap.hold_t0 <= HOLD_LIMIT)
      SDL_Delay(1);
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
      if (e.what == "wait") { // after events of its frame: the next frames are held (capture_frame_input)
         capture_hold();
         ++cap.next;
         return; // the events after it: on the first frame after the hold
      }
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
      } else if (e.what == "drop") {
         drop_path(e.arg, e.x, e.y);
      } else if (e.what == "close") { // the window's close button: a request with confirm_quit, else the end
         if (st.confirm_quit) st.quit_requested = true;
         else st.quit_now = true;
      }
   }
}

// A captured frame's clock and input: the fixed frame time, the script's events, Dear ImGui's cursor drawn with a
// script (every mode).
// A "wait" holds the script. First the frame waits, without drawing, until no task runs and no process is alive or has
// output still to be read (the work started before the first frame, a file read at the start, is then there when frame
// 0 is drawn, whatever the machine). Then the frames go on, at a frame time of 10 us (the animations and the
// notifications do not move), not counted, not written and without scripted input, until no task (fig_tasks_busy) and
// no process (fig_processes_busy) has been busy for HOLD_IDLE frames: the frame after the hold shows the work done,
// however long it took by the wall clock.
void capture_frame_input() {
   ImGuiIO &io = ImGui::GetIO();
   io.DeltaTime = cap.dt;
   io.MouseDrawCursor = !cap.events.empty();
   cap.held = false;
   if (!cap.hold && cap.next < cap.events.size() && cap.events[cap.next].what == "wait" &&
       cap.events[cap.next].frame <= cap.frame) { // a wait first at its frame: this frame is held too
      capture_hold();
      ++cap.next;
   }
   if (cap.hold) {
      cap.idle = fig_tasks_busy() == 0 && fig_processes_busy(1) == 0 ? cap.idle + 1 : 0;
      const bool late = SDL_GetTicksNS() - cap.hold_t0 > HOLD_LIMIT;
      if (late) std::fprintf(stderr, "figure capture: a wait still busy after %llu s: the script goes on\n",
                             static_cast<unsigned long long>(HOLD_LIMIT / SDL_NS_PER_SECOND));
      if (cap.idle < HOLD_IDLE && !late) {
         cap.held = true;
         io.DeltaTime = 1.0e-5f;
         SDL_Delay(1); // the work's threads and processes get the processor
         return;
      }
      cap.hold = false;
   }
   capture_apply_input();
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

// Capture: the frame (RGB, rows from the top) as the next binary PPM.
void capture_write(const unsigned char *rgb, int w, int h) {
   if (w <= 0 || h <= 0) return;
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
   std::fwrite(rgb, 1, static_cast<size_t>(w) * h * 3, f);
   std::fclose(f);
   ++cap.written;
}

// Window mode: the back buffer just rendered, RGB, rows from the top (GL counts them from the bottom).
void gl_read(std::vector<unsigned char> &rgb, int w, int h) {
   std::vector<unsigned char> px(static_cast<size_t>(w) * h * 3);
   rgb.resize(px.size());
   p_glPixelStorei(GL_PACK_ALIGNMENT_, 1);
   p_glReadPixels(0, 0, w, h, GL_RGB_, GL_UNSIGNED_BYTE_, px.data());
   const size_t row = static_cast<size_t>(w) * 3;
   for (int y = 0; y < h; ++y) std::memcpy(rgb.data() + y * row, px.data() + (h - 1 - y) * row, row);
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
// rendered (fig_end_frame; a window's before the swap), reported once by fig_image_result. A window's pixels are read
// back from the GPU; headless and remote modes render the frame with the CPU renderer.
struct image_request_t {
   std::string path, error;
   float       x0 = 0.0f, y0 = 0.0f, x1 = 0.0f, y1 = 0.0f; // logical pixels
   int         state = 0;                                 // 0 none, 1 pending, 2 written, 3 failed
};
image_request_t img;
// A test's picture of the whole frame (fig_test_capture): written when the frame is rendered, as save_image's, its
// failure on standard error (the test's comparison then finds no file).
std::string test_capture_path;

// The rectangle of img of the frame `rgb` (fw x fh pixels, RGB, rows from the top) written as a PNG.
void image_write(const ImGuiIO &io, const unsigned char *rgb, int fw, int fh) {
   const float sx = io.DisplayFramebufferScale.x, sy = io.DisplayFramebufferScale.y;
   const int x0 = std::max(0, static_cast<int>(img.x0 * sx)), x1 = std::min(fw, static_cast<int>(img.x1 * sx + 0.5f));
   const int y0 = std::max(0, static_cast<int>(img.y0 * sy)), y1 = std::min(fh, static_cast<int>(img.y1 * sy + 0.5f));
   const int w = x1 - x0, h = y1 - y0;
   if (w <= 0 || h <= 0) {
      img.state = 3;
      img.error = "save_image: the rectangle is outside the window";
      return;
   }
   std::vector<unsigned char> part(static_cast<size_t>(w) * h * 3);
   const size_t row = static_cast<size_t>(w) * 3;
   for (int y = 0; y < h; ++y)
      std::memcpy(part.data() + y * row, rgb + (static_cast<size_t>(y0 + y) * fw + x0) * 3, row);
   const bool ok = fig_image_write(img.path.data(), static_cast<int>(img.path.size()), part.data(), 3, w, h, 0) == FIG_OK;
   img.state = ok ? 2 : 3;
   if (!ok) img.error = "save_image: " + last_error;
}

// The pictures asked for in this frame (save_image, test_capture), from the frame `rgb`.
void pictures_write(const ImGuiIO &io, const unsigned char *rgb, int fw, int fh) {
   if (img.state == 1) image_write(io, rgb, fw, fh);
   if (!test_capture_path.empty()) {
      const std::string p = test_capture_path;
      test_capture_path.clear();
      if (fig_image_write(p.data(), static_cast<int>(p.size()), rgb, 3, fw, fh, 0) != FIG_OK)
         std::fprintf(stderr, "figure test_capture: %s\n", last_error.c_str());
   }
}

// plex_sans_ttf[], plex_mono_ttf[]: IBM Plex Sans and Plex Mono Regular (OFL-1.1); lucide_ttf[]: Lucide (ISC); from
// third_party/fonts
#include "figure_font.inc"

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

// A font's em in pixels per pixel of the size Dear ImGui draws it at: Dear ImGui sizes a font by its height from
// ascent to descent (hhea, stbtt_ScaleForPixelHeight), so at one size two fonts' letters differ by the ratio of these.
// 0 when the bytes are not a font stb_truetype reads.
float em_per_size(const unsigned char *data) {
   stbtt_fontinfo info;
   if (!stbtt_InitFont(&info, data, stbtt_GetFontOffsetForIndex(data, 0))) return 0.0f;
   const float per_em = stbtt_ScaleForMappingEmToPixels(&info, 1.0f); // 1 / unitsPerEm
   const float per_height = stbtt_ScaleForPixelHeight(&info, 1.0f);    // 1 / (ascent - descent)
   return per_em > 0.0f && per_height > 0.0f ? per_height / per_em : 0.0f;
}

// Merge a fallback font into a text font (after its sources): it gives the glyphs the text font and the sources
// before it lack. Its reference size is scaled so that its em equals the text font's (Noto Sans Math's ascent and
// descent are taller than Plex's: at the same size its letters would be 13 % smaller); its glyphs stand on the text
// font's baseline (Dear ImGui places every source's glyphs on the first source's).
bool merge_fallback(ImFont *dst, const unsigned char *data, int size, const char *name) {
   if (dst->Sources.Size >= 16) return false; // ImFontGlyph::SourceIdx has 4 bits
   const float ref_size = dst->Sources[0]->SizePixels;
   const auto em = st.font_em.find(dst);
   const float dst_em = em != st.font_em.end() ? em->second : 0.0f;
   const float src_em = em_per_size(data);
   ImFontConfig cfg;
   cfg.MergeMode = true;
   cfg.DstFont = dst;
   cfg.FontDataOwnedByAtlas = false; // static bytes, or kept in st.fallbacks
   cfg.GlyphMaxAdvanceX = 1.0e30f;   // finite, as for the text fonts (see get_font)
   std::snprintf(cfg.Name, sizeof(cfg.Name), "%s", name);
   const float scaled = dst_em > 0.0f && src_em > 0.0f ? ref_size * dst_em / src_em : ref_size;
   return ImGui::GetIO().Fonts->AddFontFromMemoryTTF(const_cast<unsigned char *>(data), size, scaled, &cfg) != nullptr;
}

// The fallbacks of a text font, in order: Noto Sans Math (bundled), then the program's own.
bool merge_fallbacks(ImFont *dst, std::string &err) {
   if (!merge_fallback(dst, noto_math_ttf, static_cast<int>(sizeof(noto_math_ttf)), "Noto Sans Math")) {
      err = "cannot merge the fallback font Noto Sans Math";
      return false;
   }
   for (size_t k = 0; k < st.fallbacks_merged; ++k) {
      const auto &fb = st.fallbacks[k];
      const std::string base = fb.first.substr(fb.first.find_last_of("/\\") + 1);
      if (!merge_fallback(dst, fb.second.data(), static_cast<int>(fb.second.size()), base.c_str())) {
         err = "cannot merge the fallback font " + fb.first;
         return false;
      }
   }
   return true;
}

// The bytes of a font file, checked to be TrueType or OpenType; false with err ("cannot read ..." or "... is not a
// TrueType or OpenType font").
bool read_font_file(const std::string &name, std::vector<unsigned char> &data, std::string &err) {
   FILE *in = std::fopen(name.c_str(), "rb");
   if (!in) {
      err = "cannot read the font " + name;
      return false;
   }
   data.clear();
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
      return false;
   }
   return true;
}

// A font by name ("plex-sans", "plex-mono", "proggy") or TTF path, loaded on first use into this context's atlas,
// with the icons and the fallbacks merged; null with err.
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
   float em = em_per_size(plex_sans_ttf); // proggy, a bitmap font, takes Plex Sans's
   if (name == "plex-sans") {
      std::snprintf(cfg.Name, sizeof(cfg.Name), "IBM Plex Sans");
      f = io.Fonts->AddFontFromMemoryTTF(const_cast<unsigned char *>(plex_sans_ttf), static_cast<int>(sizeof(plex_sans_ttf)),
                                         DEFAULT_FONT_SIZE, &cfg);
   } else if (name == "plex-mono") {
      std::snprintf(cfg.Name, sizeof(cfg.Name), "IBM Plex Mono");
      f = io.Fonts->AddFontFromMemoryTTF(const_cast<unsigned char *>(plex_mono_ttf), static_cast<int>(sizeof(plex_mono_ttf)),
                                         DEFAULT_FONT_SIZE, &cfg);
      em = em_per_size(plex_mono_ttf);
   } else if (name == "proggy") {
      ImFontConfig bitmap;
      bitmap.GlyphMaxAdvanceX = cfg.GlyphMaxAdvanceX;
      // Its reference size given explicitly (the default, 13, when left implicit): Dear ImGui merges a font with an
      // explicit size, as the icons need for their finite GlyphMaxAdvanceX, only into one with an explicit size.
      bitmap.SizePixels = PROGGY_FONT_SIZE;
      ref_size = PROGGY_FONT_SIZE;
      f = io.Fonts->AddFontDefaultBitmap(&bitmap);
   } else {
      std::vector<unsigned char> data;
      if (!read_font_file(name, data, err)) return nullptr;
      std::vector<unsigned char> &kept = st.font_data[name];
      kept = std::move(data);
      std::snprintf(cfg.Name, sizeof(cfg.Name), "%s", name.substr(name.find_last_of("/\\") + 1).c_str());
      f = io.Fonts->AddFontFromMemoryTTF(kept.data(), static_cast<int>(kept.size()), DEFAULT_FONT_SIZE, &cfg);
      if (f) em = em_per_size(kept.data());
   }
   if (!f) {
      err = "cannot load the font " + name;
      return nullptr;
   }
   if (!merge_icons(f, ref_size)) {
      err = "cannot merge the icons into the font " + name;
      return nullptr;
   }
   st.font_em[f] = em;
   if (!merge_fallbacks(f, err)) return nullptr;
   st.fonts[name] = f;
   return f;
}

void create_contexts() {
   IMGUI_CHECKVERSION();
   ImGui::CreateContext();
   ImPlot::CreateContext();
   ImPlot3D::CreateContext(); // the small 3-D figures (figure_plot3d.cpp)
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
   figure_items::reset(); // no item recorded yet; recording as test_record_items last asked (on by default)
}

void destroy_contexts() {
   st.fonts.clear(); // the fonts belong to the context's atlas
   st.font_data.clear();
   st.font_em.clear();
   st.fallbacks.clear(); // a program's fallbacks belong to its application: a new init starts without them
   st.fallbacks_merged = 0;
   if (ImPlot3D::GetCurrentContext()) ImPlot3D::DestroyContext();
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
      if (k != "[imgui.vars]" && k != "[implot.vars]" && k != "[figure.vars]") {
         err = where + ": a look holds [imgui.vars], [implot.vars] and [figure.vars] only, not " + k;
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
   float                title_bar = 0.0f; // FIGURE's title bar [logical pixels]; 0: the menu bar's height
};

// The style in effect, as a build to change parts of.
style_build_t current_build() {
   style_build_t b;
   b.s = ImGui::GetStyle();
   b.ps = ImPlot::GetStyle();
   for (int i = 0; i < 3; ++i) b.clear[i] = st.clear[i];
   b.base = st.style_base;
   b.look = st.look;
   b.title_bar = st.title_bar;
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

// The variables of a look (`name`) into fresh styles: Dear ImGui's and ImPlot's defaults, then the look's; its title
// bar's height [logical pixels] (0: the menu bar's).
bool look_vars(const std::string &name, ImGuiStyle &s, ImPlotStyle &ps, float &title_bar, std::string &err) {
   figure_theme::theme_t look;
   if (!load_look(name, look, err)) return false;
   title_bar = look.title_bar_height > 0.0 ? static_cast<float>(look.title_bar_height) : 0.0f;
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
   float       title_bar = 0.0f;
   if (!look_vars(name, s, ps, title_bar, err)) return false;
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
   b.title_bar = title_bar;
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
      if (!look_vars(t.look, s, ps, b.title_bar, err)) return false;
      std::memcpy(s.Colors, b.s.Colors, sizeof(s.Colors));
      std::memcpy(ps.Colors, b.ps.Colors, sizeof(ps.Colors));
      b.s = s;
      b.ps = ps;
      b.look = t.look;
   }
   if (t.title_bar_height >= 0.0) b.title_bar = static_cast<float>(t.title_bar_height);
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
   st.title_bar = b.title_bar;
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
   frames_at_least(3);
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
   const float scale = st.scale > 0.0f ? st.scale.load() : 1.0f;
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
   if (st.title_bar != ref.title_bar) out += "\n[figure.vars]\nTitleBarHeight = " + short_float(st.title_bar) + "\n";
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
std::vector<float>        note_alphas; // ... the largest alpha of their vertices (the draw data: tests of the fade)

void draw_notifications() {
   note_rects.clear();
   note_alphas.clear();
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
      unsigned int top = 0; // the largest alpha drawn: the window's opaque colours times the fade
      for (const ImDrawVert &v : ImGui::GetWindowDrawList()->VtxBuffer) top = std::max(top, (v.col >> IM_COL32_A_SHIFT) & 0xFFu);
      note_alphas.push_back(static_cast<float>(top) / 255.0f);
      ImGui::End();
      ImGui::PopStyleColor();
      ImGui::PopStyleVar(2);
      note_rects.push_back(frame_rect_t{pos.x, pos.y, pos.x + size.x, pos.y + size.y});
      bottom = pos.y - gap;
   }
   if (animate) frames_at_least(2); // the fade is drawn frame by frame
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
   frames_at_least(3);
}

void frame_close() {
   if (st.confirm_quit) st.quit_requested = true;
   else st.quit_now = true;
}

SDL_HitTestResult SDLCALL frame_hit_test(SDL_Window *, const SDL_Point *p, void *) {
   return static_cast<SDL_HitTestResult>(frame_hit(st.frame.geom, static_cast<float>(p->x), static_cast<float>(p->y)));
}

// The bar's height [pixels]: the look's title bar height (scaled), or the menu bar's (Dear ImGui's frame height).
float frame_bar_height() {
   const float menu = ImGui::GetFrameHeight();
   return st.title_bar > 0.0f ? std::max(menu, std::round(st.title_bar * st.scale)) : menu;
}

// Dear ImGui's main menu bar (BeginMainMenuBar), opened first in the frame at the bar's height: the window's height and
// its menu-bar rectangle are fixed by this first Begin of the frame, and the menus (FIGURE's icon, the program's own
// menus appended later) start half the extra height down, so that they stay centred in a taller bar.
bool frame_bar_begin() {
   const float menu = ImGui::GetFrameHeight(), h = frame_bar_height();
   if (h <= menu) return ImGui::BeginMainMenuBar();
   ImGuiContext &g = *ImGui::GetCurrentContext();
   ImGuiViewportP *vp = static_cast<ImGuiViewportP *>(ImGui::GetMainViewport());
   ImGui::SetCurrentViewport(nullptr, vp);
   const float extra = std::floor(0.5f * (h - menu));
   g.NextWindowData.MenuBarOffsetMinVal =
      ImVec2(g.Style.DisplaySafeAreaPadding.x, std::max(g.Style.DisplaySafeAreaPadding.y - g.Style.FramePadding.y, 0.0f) + extra);
   // the menu bar's rectangle is the whole bar: its height is the offset plus the font plus twice the frame padding
   const float pad = std::max(0.0f, 0.5f * (h - g.NextWindowData.MenuBarOffsetMinVal.y - g.FontSize));
   ImGui::PushStyleVar(ImGuiStyleVar_FramePadding, ImVec2(g.Style.FramePadding.x, pad));
   const bool open = ImGui::BeginViewportSideBar("##MainMenuBar", vp, ImGuiDir_Up, h,
                                                 ImGuiWindowFlags_NoScrollbar | ImGuiWindowFlags_NoSavedSettings |
                                                    ImGuiWindowFlags_MenuBar);
   ImGui::PopStyleVar();
   g.NextWindowData.MenuBarOffsetMinVal = ImVec2(0.0f, 0.0f);
   if (!open) {
      ImGui::End();
      return false;
   }
   g.CurrentWindow->Flags &= ~ImGuiWindowFlags_NoSavedSettings; // as BeginMainMenuBar
   ImGui::BeginMenuBar();
   return true;
}

// The start of the bar: Dear ImGui's main menu bar in the palette's surface colour, the space of the buttons when
// they are on the left, and the icon.
void frame_bar_open() {
   if (!st.frame.on) return;
   color_t r[ROLE_COUNT];
   roles_in_effect(r);
   ImGui::PushStyleColor(ImGuiCol_MenuBarBg, vec4(r[figure_theme::ROLE_SURFACE]));
   ImGui::PushStyleColor(ImGuiCol_WindowBg, vec4(r[figure_theme::ROLE_SURFACE]));
   const bool open = frame_bar_begin();
   ImGui::PopStyleColor(2);
   if (!open) return;
   const float h = ImGui::GetCurrentWindow()->Size.y;
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

// Headless renderer: acknowledge texture requests (font atlas pages) without a GPU, as a real backend would. Their ids
// have the top bit set, so they never meet a user texture's (numbered from 1); the CPU renderer reads their pixels
// from Dear ImGui's ImTextureData.
constexpr unsigned long long ATLAS_ID_BIT = 0x8000000000000000ull;
void headless_textures() {
   for (ImTextureData *t : ImGui::GetPlatformIO().Textures) {
      if (t->Status == ImTextureStatus_WantCreate || t->Status == ImTextureStatus_WantUpdates) {
         t->SetTexID(static_cast<ImTextureID>(ATLAS_ID_BIT | static_cast<unsigned int>(t->UniqueID)));
         t->SetStatus(ImTextureStatus_OK);
      } else if (t->Status == ImTextureStatus_WantDestroy) {
         t->SetTexID(ImTextureID_Invalid);
         t->SetStatus(ImTextureStatus_Destroyed);
      }
   }
}

// The sampler callbacks a renderer backend registers (fig_texture_sampling puts them around a user image), for modes
// without the GL backend: they do nothing when called, and the CPU renderer reads them from the draw lists as the GL
// backend's state changes (a user texture's own filter, then linear again). Remote mode's page ignores them.
void sampler_from_texture(const ImDrawList *, const ImDrawCmd *) {}
void sampler_reset(const ImDrawList *, const ImDrawCmd *) {}
void sampler_linear(const ImDrawList *, const ImDrawCmd *) {}
void sampler_nearest(const ImDrawList *, const ImDrawCmd *) {}
void register_samplers() {
   ImGuiPlatformIO &pio = ImGui::GetPlatformIO();
   pio.DrawCallback_SetSamplerFromTex = sampler_from_texture;
   pio.DrawCallback_ResetRenderState = sampler_reset;
   pio.DrawCallback_SetSamplerLinear = sampler_linear;
   pio.DrawCallback_SetSamplerNearest = sampler_nearest;
}

// The CPU renderer's user textures: headless mode's copies, remote mode's (kept to be sent to the browser).
bool cpu_texture(ImTextureID id, figure_swrast::texture_t *t) {
   if (st.m == mode::remote) return figure_remote::texture_pixels(static_cast<std::uint64_t>(id), t);
   const auto it = st.textures.find(static_cast<unsigned long long>(id));
   if (it == st.textures.end() || it->second.rgba.empty()) return false;
   t->width = it->second.width, t->height = it->second.height, t->channels = 4;
   t->pixels = it->second.rgba.data(), t->smooth = it->second.smooth;
   return true;
}

// The frame just rendered (ImGui::Render), drawn by the CPU renderer: RGB, rows from the top, the frame buffer's size.
int render_threads = 0; // fig_render_threads (tests): 0 the default
void cpu_frame(std::vector<unsigned char> &rgb, int &w, int &h) {
   const ImGuiIO &io = ImGui::GetIO();
   w = static_cast<int>(io.DisplaySize.x * io.DisplayFramebufferScale.x);
   h = static_cast<int>(io.DisplaySize.y * io.DisplayFramebufferScale.y);
   figure_swrast::render(ImGui::GetDrawData(), w, h, st.clear, rgb, cpu_texture, render_threads, nullptr);
}

// Headless and remote modes, after ImGui::Render and the textures' answers: the capture's frame and the pictures
// asked for, rendered by the CPU once for all of them.
void cpu_pictures() {
   const bool due = cap.on && !cap.held && cap.frame >= cap.from && (cap.count < 0 || cap.written < cap.count);
   if (due || img.state == 1 || !test_capture_path.empty()) {
      std::vector<unsigned char> rgb;
      int w = 0, h = 0;
      cpu_frame(rgb, w, h);
      if (due) capture_write(rgb.data(), w, h);
      pictures_write(ImGui::GetIO(), rgb.data(), w, h);
   }
   if (cap.on && !cap.held) ++cap.frame;
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

// Opening a link (Dear ImGui's Platform_OpenInShellFn, called by ig_text_link_url on a click): the URL is kept for
// test_opened_url in every mode; then a window opens it with the platform's handler (SDL_OpenURL: the system's
// browser), except while recording the documentation (the capture opens nothing on the desktop); headless mode opens
// nothing; remote mode sends it to the page, which opens it in the browser (message 9).
static std::string opened_url;
static bool (*platform_open)(ImGuiContext *, const char *) = nullptr; // the backend's handler (window mode)
static bool open_in_shell(ImGuiContext *ctx, const char *url) {
   try {
      opened_url = url ? url : "";
   } catch (...) {
      return false;
   }
   if (st.m == mode::remote) {
      figure_remote::open_url(opened_url.c_str());
      return true;
   }
   if (st.m != mode::window || cap.on) return true;
   return platform_open ? platform_open(ctx, url) : false;
}
static void take_open_in_shell() {
   ImGuiPlatformIO &pio = ImGui::GetPlatformIO();
   platform_open = pio.Platform_OpenInShellFn == open_in_shell ? platform_open : pio.Platform_OpenInShellFn;
   pio.Platform_OpenInShellFn = open_in_shell;
   opened_url.clear();
}

long long fig_opened_url(char *buf, long long cap_bytes) {
   const size_t n = std::min(opened_url.size(), static_cast<size_t>(cap_bytes > 0 ? cap_bytes : 0));
   if (n > 0) std::memcpy(buf, opened_url.data(), n);
   return static_cast<long long>(opened_url.size());
}

// The floating-point environment held around calls into the GL driver and the window system: their own arithmetic
// (Mesa's llvmpipe in glXCreateContext, shader compilation, rasterization) raises IEEE flags that C code may raise
// with the exceptions masked, the default. A program built with traps (gfortran -ffpe-trap=invalid,zero,overflow, a
// debug build) stopped there with SIGFPE at its window's creation (xall_figure's debug xall_gui, 2026-11-13). Inside,
// every exception is masked and the flags cleared; on leaving, the program's environment comes back as it was (its
// traps, and its flags without the driver's). FIGURE's own and Dear ImGui's arithmetic stay outside: still trapped.
struct fp_held_t {
   std::fenv_t env;
   fp_held_t() { std::feholdexcept(&env); }
   ~fp_held_t() { std::fesetenv(&env); }
   fp_held_t(const fp_held_t &) = delete;
   fp_held_t &operator=(const fp_held_t &) = delete;
};

int fig_init(const char *title, int title_len, int width, int height, int vsync) {
   FIG_TRY
   if (st.m != mode::none) return fail(FIG_ERR_STATE, "figure is already initialized");
   if (width <= 0 || height <= 0) return fail(FIG_ERR_ARGUMENT, "window size must be positive");
   const char *cap_prefix = std::getenv("FIGURE_CAPTURE"), *cap_headless = std::getenv("FIGURE_CAPTURE_HEADLESS");
   if (cap_prefix && *cap_prefix && cap_headless && *cap_headless && std::strcmp(cap_headless, "0") != 0) {
      // a capture without a window: the same program headless, at the window's size, drawn by the CPU renderer
      const int s = fig_init_headless(width, height);
      if (s == FIG_OK) {
         st.title.assign(title, title_len > 0 ? static_cast<size_t>(title_len) : 0);
         st.window_capture = true;
      }
      return s;
   }
   SDL_SetMainReady();
   if (!SDL_Init(SDL_INIT_VIDEO)) return fail(FIG_ERR_FAILED, std::string("SDL_Init: ") + SDL_GetError());
   SDL_SetEventEnabled(SDL_EVENT_DROP_FILE, true); // files and folders dropped on the window (app%dropped)
   sdl_events = true;
   fp_held_t held; // the window, its GL context and the GL backend made with the driver's arithmetic untrapped
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
   take_open_in_shell(); // after the backend's: SDL_OpenURL kept as the handler of a window
   st.m = mode::window;
   loop_starts();
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
   platform_open = nullptr;
   take_open_in_shell(); // a link opens nothing: Dear ImGui's default would run xdg-open and wait for it
   register_samplers(); // a user texture's own filter, as the GL backend's, for the CPU renderer
   capture_setup();
   st.m = mode::headless;
   loop_starts();
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
   // the clipboard: the program's own on the server, sent to the browser on a copy, set from it on a paste
   ImGuiPlatformIO &pio = ImGui::GetPlatformIO();
   pio.Platform_SetClipboardTextFn = [](ImGuiContext *, const char *text) { figure_remote::set_clipboard(text); };
   pio.Platform_GetClipboardTextFn = [](ImGuiContext *) { return figure_remote::clipboard(); };
   platform_open = nullptr;
   take_open_in_shell(); // a link is opened by the page, in the browser
   register_samplers(); // a user texture's own filter, as the GL backend's, for the CPU renderer
   capture_setup();
   st.m = mode::remote;
   loop_starts();
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
   fig_app_style_parts(name, name_len, look, look_len, palette, palette_len, auto_dark, auto_dark_len, auto_light,
                       auto_light_len, lines, lines_len); // what the preferences keep
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
   if (st.window_capture) { // the bar's icon only, a texture of the CPU renderer
      if (width <= 0 || height <= 0 || width > 1024 || height > 1024)
         return fail(FIG_ERR_ARGUMENT, "set_icon: the image is rgba(4, width, height), 1 to 1024 pixels a side");
      if (st.frame.icon_tex != 0) fig_texture_destroy(st.frame.icon_tex);
      unsigned long long id = 0;
      const int s = fig_texture_create(width, height, 1, &id);
      if (s != FIG_OK) return s;
      fig_texture_update(id, width, height, rgba);
      st.frame.icon_tex = static_cast<unsigned int>(id);
      st.frame.icon_w = width;
      st.frame.icon_h = height;
      st.frame.icon_glyph.clear();
      return FIG_OK;
   }
   if (st.m != mode::window) return fail(FIG_ERR_STATE, std::string("set_icon: there is no window in ") +
                                                         (st.m == mode::none ? "no mode (before init)"
                                                          : st.m == mode::headless ? "headless mode" : "remote mode"));
   if (width <= 0 || height <= 0 || width > 1024 || height > 1024)
      return fail(FIG_ERR_ARGUMENT, "set_icon: the image is rgba(4, width, height), 1 to 1024 pixels a side");
   if (st.frame.on) { // the bar's icon: a texture of the image (even where the system refuses the window's)
      fp_held_t held; // the upload: the driver's
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
   std::string err;
   if (!set_window_icon(rgba, width, height, err)) return fail(FIG_ERR_FAILED, err);
   return FIG_OK;
   FIG_CATCH
}

int fig_set_icon_glyph(const char *icon, int icon_len) {
   FIG_TRY
   if (st.window_capture) { // the bar's icon only
      const std::string g(icon, icon_len > 0 ? static_cast<size_t>(icon_len) : 0);
      std::vector<unsigned char> rgba;
      std::string err;
      if (!render_icon_glyph(g, 64, rgba, err)) return fail(FIG_ERR_ARGUMENT, err);
      if (st.frame.icon_tex != 0) fig_texture_destroy(st.frame.icon_tex);
      st.frame.icon_tex = 0;
      st.frame.icon_glyph = g;
      return FIG_OK;
   }
   if (st.m != mode::window) return fail(FIG_ERR_STATE, std::string("set_icon: there is no window in ") +
                                                         (st.m == mode::none ? "no mode (before init)"
                                                          : st.m == mode::headless ? "headless mode" : "remote mode"));
   const std::string g(icon, icon_len > 0 ? static_cast<size_t>(icon_len) : 0);
   std::vector<unsigned char> rgba;
   std::string err;
   const int side = 64;
   if (!render_icon_glyph(g, side, rgba, err)) return fail(FIG_ERR_ARGUMENT, err);
   if (st.frame.icon_tex != 0) { // the bar's icon first: kept even where the system refuses the window's
      p_glDeleteTextures(1, &st.frame.icon_tex);
      st.frame.icon_tex = 0;
   }
   st.frame.icon_glyph = g;
   if (!set_window_icon(rgba.data(), side, side, err)) return fail(FIG_ERR_FAILED, err);
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
   fig_app_style_forget(); // a theme file is not kept by the preferences: the program loads it again
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

// The fallbacks added since the last merge, into every font loaded so far (those loaded later get them in
// get_font): between frames, as Dear ImGui wants a font changed (a merge discards the font's baked glyphs).
static void apply_fallbacks() {
   for (; st.fallbacks_merged < st.fallbacks.size(); ++st.fallbacks_merged) {
      const auto &fb = st.fallbacks[st.fallbacks_merged];
      const std::string base = fb.first.substr(fb.first.find_last_of("/\\") + 1);
      for (const auto &f : st.fonts) // checked by fig_add_fallback_font: a font, and room for its source
         merge_fallback(f.second, fb.second.data(), static_cast<int>(fb.second.size()), base.c_str());
   }
}

int fig_add_fallback_font(const char *path, int path_len) {
   FIG_TRY
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "app%add_fallback_font: figure is not initialized");
   const std::string p(path, path_len > 0 ? static_cast<size_t>(path_len) : 0);
   for (const auto &fb : st.fallbacks)
      if (fb.first == p) return FIG_OK; // merged already
   // 16 sources a font at most (ImFontGlyph::SourceIdx): the text font, Lucide, Noto Sans Math and 13 of the program's
   if (st.fallbacks.size() >= 13)
      return fail(FIG_ERR_ARGUMENT, "app%add_fallback_font: 13 fallback fonts already (Dear ImGui's 16 per font)");
   std::vector<unsigned char> data;
   std::string err;
   if (!read_font_file(p, data, err))
      return fail(err.rfind("cannot read", 0) == 0 ? FIG_ERR_FAILED : FIG_ERR_ARGUMENT, "app%add_fallback_font: " + err);
   if (em_per_size(data.data()) <= 0.0f)
      return fail(FIG_ERR_ARGUMENT, "app%add_fallback_font: " + p + " is not a font Dear ImGui reads");
   st.fallbacks.emplace_back(p, std::move(data));
   if (!st.in_frame) apply_fallbacks(); // inside a frame: before the next one
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
   // while capturing, nothing of the user's is read or written: the recordings do not depend on earlier runs
   ImGui::GetIO().IniFilename = st.ini_file.empty() || cap.on ? nullptr : st.ini_file.c_str();
   return FIG_OK;
   FIG_CATCH
}

void fig_set_lazy(int enabled, double max_wait_s) {
   st.max_wait_ms = max_wait_s > 0.0 ? static_cast<int>(max_wait_s * 1000.0) : 0;
   st.lazy = enabled != 0;
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
   const bool r = st.quit_requested.exchange(false);
   if (r) frames_at_least(3); // a request is an event: the frames that answer it are drawn
   return r ? 1 : 0;
}

// From any thread: the next fig_begin_frame ends the loop; from a thread other than the loop's, a lazy loop waiting
// for input stops waiting.
void fig_quit(void) {
   st.quit_now = true;
   if (!on_main_thread()) fig_wake();
}

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

// From any thread: at least n more frames (concurrent requests keep the largest), the first at once: from the loop's
// thread the next fig_begin_frame does not wait; from another, a lazy loop waiting for input stops waiting.
void fig_request_frames(int n) {
   frames_at_least(n);
   if (!on_main_thread()) fig_wake();
}

// app%wake, from any thread: the next frame starts without waiting for input or max_wait.
void fig_app_wake(void) {
   if (on_main_thread()) frames_at_least(1); // the loop is not waiting now: its next fig_begin_frame will not
   else fig_wake();
}

double fig_content_scale(void) { return st.scale; }

void apply_test_input(); // figure_testing's queued input (defined with the synthetic input below)
static int         run_frames = 0; // frames of the current test_run (fig_test_run)
static std::string test_failure; // a queued action that could not be done (test_menu_click): test_run reports it

int fig_begin_frame(int *running) {
   FIG_TRY
   if (fig_task_refuse("app%next_frame", 14)) return FIG_ERR_STATE; // a task does not draw
   *running = 0;
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   if (st.in_frame) return fail(FIG_ERR_STATE, "begin_frame called twice without end_frame");
   *running = 1;
   if (st.quit_now.exchange(false)) { // fig_quit, in every mode
      *running = 0;
      return FIG_OK;
   }
   if (st.system_theme_changed) { // a test's change of the system's light or dark setting, handled as SDL's event
      st.system_theme_changed = false;
      system_theme_changed();
   }
   if (cap.on && cap.count >= 0 && cap.written >= cap.count) { // capture: enough frames written (every mode)
      *running = 0;
      return FIG_OK;
   }
   if (st.m == mode::headless) { // never waits: a wake-up has nothing to end
      woken = false;
      ImGui::GetIO().DeltaTime = 1.0f / 60.0f;
      if (cap.on) capture_frame_input();
      frame_without_event(); // the frames asked for (test_run waits for none), counted down as in window mode
      figure_items::frame_begin(); // the items of the frame that ended: what paths find now
      apply_test_input();
      take_drops();
      fig_app_frame_begin(); // the application layer: the preferences saved every 30 s
      apply_layout(); // a layout asked for by fig_load_layout: between frames, as Dear ImGui wants it
      apply_fallbacks(); // the fallback fonts added inside the last frame
      ImGui::NewFrame();
      st.in_frame = true;
      frame_bar_open();
      fig_scope_frame_begin(); // the scope record: after FIGURE's own bar
      return FIG_OK;
   }
   if (st.m == mode::remote) {
      // the same lazy redraw as a window, waiting on the network instead of SDL's event queue; then the frame-rate
      // cap (a browser has no vsync to pace the program): input arriving meanwhile is gathered into the next frame
      using clock = std::chrono::steady_clock;
      // wait for input up to max_wait when idle, or, when a frame was skipped for a slow client, until the queue
      // drains (serve returns early then); otherwise go on at once
      // (fig_wake ends the wait: its datagram to the wake socket is input to serve; reset before the wait, so that a
      // wake-up during it is never lost)
      woken = false;
      const bool pending = figure_remote::frame_pending(), busy = figure_remote::queue_busy();
      const bool wait = pending ? busy : st.lazy && st.frames_left <= 0 && st.test_input.empty() && !cap.on;
      bool got = figure_remote::serve(wait ? st.max_wait_ms.load() : 0);
      const auto next = st.last_frame + std::chrono::duration_cast<clock::duration>(
                                           std::chrono::duration<double>(st.remote_min_dt));
      for (auto t = clock::now(); t < next; t = clock::now())
         got = figure_remote::serve(static_cast<int>(
                  std::chrono::duration_cast<std::chrono::milliseconds>(next - t).count()) + 1) || got;
      while (figure_remote::serve(0)) got = true; // drain what else arrived
      if (st.quit_now.exchange(false)) { // fig_quit from another thread during the wait (which it ended)
         *running = 0;
         return FIG_OK;
      }
      if (got) frames_at_least(3);
      else frame_without_event();
      const auto now = clock::now();
      const float dt = std::chrono::duration<float>(now - st.last_frame).count();
      st.last_frame = now;
      ImGui::GetIO().DeltaTime = dt > 0.0f ? dt : 1.0e-4f;
      if (cap.on) capture_frame_input(); // the fixed clock and the script; the browser's input goes on
      figure_items::frame_begin(); // the items of the frame that ended: what paths find now
      apply_test_input();
      take_drops();
      fig_app_frame_begin(); // the application layer: the preferences saved every 30 s
      apply_layout(); // a layout asked for by fig_load_layout: between frames, as Dear ImGui wants it
      apply_fallbacks(); // the fallback fonts added inside the last frame
      ImGui::NewFrame();
      st.in_frame = true;
      frame_bar_open();
      fig_scope_frame_begin(); // the scope record: after FIGURE's own bar
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
      if (e.type == SDL_EVENT_DROP_FILE && !cap.on && e.drop.data) drop_path(e.drop.data, e.drop.x, e.drop.y);
      if (e.type == SDL_EVENT_QUIT ||
          (e.type == SDL_EVENT_WINDOW_CLOSE_REQUESTED && e.window.windowID == SDL_GetWindowID(st.window))) {
         if (st.confirm_quit) st.quit_requested = true; // the program asks first, then calls fig_quit
         else *running = 0;
      }
      got = true;
   };
   // Lazy redraw: once ImGui has settled, sleep until an event arrives or max_wait elapses (a periodic refresh that
   // lets live data from the application appear); never spin at the display rate while idle.
   // a fig_wake from now on pushes its event, which ends the wait or is polled below; one before is already queued
   woken = false;
   if (st.lazy && st.frames_left <= 0 && !cap.on && st.test_input.empty()) {
      if (SDL_WaitEventTimeout(&ev, st.max_wait_ms))
         handle(ev);
      else if (rs.on)
         ++rs.timeouts;
   }
   while (SDL_PollEvent(&ev)) handle(ev);
   if (st.quit_now.exchange(false)) *running = 0; // fig_quit from another thread during the wait (which it ended)
   if (!*running) return FIG_OK; // quitting: no frame is opened
   if (got) frames_at_least(3);
   else frame_without_event();
   if (SDL_GetWindowFlags(st.window) & SDL_WINDOW_MINIMIZED) SDL_Delay(10);
   if (rs.on) {
      const Uint64 now = SDL_GetTicksNS();
      rs.wait += now - rs.t_mark;
      rs.t_mark = now;
   }
   {
      fp_held_t held; // the backend's first frame compiles its shaders in the driver
      ImGui_ImplOpenGL3_NewFrame();
   }
   if (cap.on) { // what ImGui_ImplSDL3_NewFrame does, without the real mouse, keyboard focus or wall clock
      ImGuiIO &io = ImGui::GetIO();
      int w, h, fw, fh;
      SDL_GetWindowSize(st.window, &w, &h);
      SDL_GetWindowSizeInPixels(st.window, &fw, &fh);
      io.DisplaySize = ImVec2(static_cast<float>(w), static_cast<float>(h));
      if (w > 0 && h > 0) io.DisplayFramebufferScale = ImVec2(static_cast<float>(fw) / w, static_cast<float>(fh) / h);
      capture_frame_input();
   } else {
      ImGui_ImplSDL3_NewFrame();
   }
   figure_items::frame_begin(); // the items of the frame that ended: what paths find now
   apply_test_input();
   take_drops();
   fig_app_frame_begin(); // the application layer: the preferences saved every 30 s
   apply_layout(); // a layout asked for by fig_load_layout: between frames, as Dear ImGui wants it
   apply_fallbacks(); // the fallback fonts added inside the last frame
   ImGui::NewFrame();
   st.in_frame = true;
   frame_bar_open();
   fig_scope_frame_begin(); // the scope record: after FIGURE's own bar
   return FIG_OK;
   FIG_CATCH
}

int fig_end_frame(void) {
   FIG_TRY
   if (fig_task_refuse("app%next_frame", 14)) return FIG_ERR_STATE; // a task does not draw
   if (!st.in_frame) return fail(FIG_ERR_STATE, "end_frame without begin_frame");
   fig_scope_frame_end(); // what the program left open, closed (and reported by the next fig_scope_report)
   frame_bar_close();
   fig_file_browser_draw(); // FIGURE's file browser, a modal over the program's windows
   fig_app_draw();          // the message boxes, modals over the program's windows
   draw_notifications();    // after the program's windows, above them
   st.in_frame = false;
   fig_field_sweep(); // field textures not drawn for a while released
   ImGui::Render();
   if (st.m == mode::headless) {
      headless_textures();
      cpu_pictures();
      return FIG_OK;
   }
   if (st.m == mode::remote) {
      figure_remote::send_frame(ImGui::GetDrawData()); // the atlas's pixels kept there first
      cpu_pictures();
      return FIG_OK;
   }
   Uint64 t_render = 0;
   if (rs.on) {
      t_render = SDL_GetTicksNS();
      rs.build += t_render - rs.t_mark;
   }
   const ImGuiIO &io = ImGui::GetIO();
   {
      fp_held_t held; // the draw: the driver's
      p_glViewport(0, 0, static_cast<int>(io.DisplaySize.x * io.DisplayFramebufferScale.x),
                   static_cast<int>(io.DisplaySize.y * io.DisplayFramebufferScale.y));
      p_glClearColor(st.clear[0], st.clear[1], st.clear[2], 1.0f);
      p_glClear(GL_COLOR_BUFFER_BIT_);
      ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
   }
   const bool due = cap.on && !cap.held && cap.frame >= cap.from && (cap.count < 0 || cap.written < cap.count);
   if (due || img.state == 1 || !test_capture_path.empty()) { // the GPU's pixels, read back once
      const int fw = static_cast<int>(io.DisplaySize.x * io.DisplayFramebufferScale.x);
      const int fh = static_cast<int>(io.DisplaySize.y * io.DisplayFramebufferScale.y);
      std::vector<unsigned char> rgb;
      if (fw > 0 && fh > 0) {
         fp_held_t held; // the read-back: the driver's
         gl_read(rgb, fw, fh);
      }
      if (due) capture_write(rgb.data(), fw, fh);
      if (fw > 0 && fh > 0) pictures_write(io, rgb.data(), fw, fh);
   }
   if (cap.on && !cap.held) ++cap.frame;
   Uint64 t_swap = 0;
   if (rs.on) t_swap = SDL_GetTicksNS();
   {
      fp_held_t held; // the swap: the driver's (and the window system's)
      SDL_GL_SwapWindow(st.window);
   }
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
      fig_app_shutdown(); // the preferences saved while the window and the contexts exist, then forgotten
      fig_field_reset(); // the field cache forgotten: its textures go with the others below
      fig_markdown_shutdown(); // Markdown's context, its fonts and images: while the renderer can free them
      fig_process_shutdown(); // the captured children end with the program (before SDL_Quit)
      if (st.in_frame) {
         fig_scope_frame_end(); // what the program left open, closed
         ImGui::EndFrame();
         st.in_frame = false;
      }
      if (st.m == mode::window) {
         fp_held_t held; // the backend's and the textures' release: the driver's
         if (st.frame.icon_tex != 0) p_glDeleteTextures(1, &st.frame.icon_tex);
         for (const auto &t : st.textures) {
            const unsigned int name = static_cast<unsigned int>(t.first);
            p_glDeleteTextures(1, &name);
         }
         ImGui_ImplOpenGL3_Shutdown();
         ImGui_ImplSDL3_Shutdown();
      }
      destroy_contexts();
      figure_items::reset();
      test_failure.clear();
      run_frames = 0;
      if (st.m == mode::remote) figure_remote::stop();
      if (st.m == mode::window) {
         fp_held_t held; // the context and the window released: the driver's
         sdl_events = false;
         SDL_GL_DestroyContext(st.gl);
         SDL_DestroyWindow(st.window);
         SDL_Quit();
      }
   } catch (...) {
   }
   st = state_t{};
   cap = capture_t{};
   img = image_request_t{};
   test_capture_path.clear();
   render_threads = 0;
   fig_scope_reset();
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
      fp_held_t held; // the upload: the driver's
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
   state_t::texture_t &t = st.textures[*id];
   t.width = width, t.height = height, t.smooth = smooth != 0;
   // headless mode: the pixels, for the CPU renderer (transparent until the first update, as a fresh GL texture's
   // contents are undefined)
   if (st.m == mode::headless) t.rgba.assign(static_cast<size_t>(width) * static_cast<size_t>(height) * 4u, 0);
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
      fp_held_t held; // the upload: the driver's
      p_glBindTexture(GL_TEXTURE_2D_, static_cast<unsigned int>(id));
      p_glPixelStorei(GL_UNPACK_ROW_LENGTH_, 0);
      p_glPixelStorei(GL_UNPACK_ALIGNMENT_, 1);
      p_glTexSubImage2D(GL_TEXTURE_2D_, 0, 0, 0, width, height, GL_RGBA_, GL_UNSIGNED_BYTE_, rgba);
   } else if (st.m == mode::remote) {
      figure_remote::texture_update(id, width, height, rgba, t->second.smooth); // kept, and sent to the browser
   } else { // headless: kept for the CPU renderer
      std::memcpy(t->second.rgba.data(), rgba, t->second.rgba.size());
   }
   return FIG_OK;
   FIG_CATCH
}

void fig_texture_sampling(int plot, int from_texture) {
   // The OpenGL3 backend samples every texture through its own (linear) sampler object, which overrides the
   // glTexParameteri filter of user textures: around a user image, ask it to use the texture's own filter, then
   // restore its render state. Headless and remote modes register callbacks of their own (register_samplers), which
   // the CPU renderer follows.
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
   figure_items::name_last(std::string(lab.c_str(), shown_end)); // its name for paths: the label it draws itself
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
// *item_height: the height of a row with the spacing below it [pixels], given to Begin or measured on the first row
// (0 until it is known).
int fig_clipper_step(void *clipper, int *first, int *last, double *item_height) {
   ImGuiListClipper *c = static_cast<ImGuiListClipper *>(clipper);
   const int more = c->Step() ? 1 : 0;
   *item_height = c->ItemsHeight > 0.0f ? static_cast<double>(c->ItemsHeight) : 0.0;
   if (!more) return 0;
   *first = c->DisplayStart + 1;
   *last = c->DisplayEnd;
   return 1;
}

void fig_clipper_delete(void *clipper) {
   ImGuiListClipper *c = static_cast<ImGuiListClipper *>(clipper);
   if (c->ItemsCount >= 0 && ImGui::GetCurrentContext()) c->End(); // left before its end
   IM_DELETE(c);
}

// Tables: the current table, or null (no context, no table).
static ImGuiTable *current_table() { return ImGui::GetCurrentContext() ? ImGui::GetCurrentTable() : nullptr; }

int fig_table_sort(int *column, int *descending, int *changed) {
   *column = 0;
   *descending = 0;
   *changed = 0;
   ImGuiTable *t = current_table();
   if (!t) return 1;
   if (!(t->Flags & ImGuiTableFlags_Sortable)) return 2;
   if (!t->IsLayoutLocked && t->DeclColumnsCount > 0 && t->DeclColumnsCount < t->ColumnsCount) return 5;
   ImGuiTableSortSpecs *s = ImGui::TableGetSortSpecs(); // locks the layout when the headers row did not
   if (!s) return 2;
   if (s->SpecsCount > 0) {
      *column = s->Specs[0].ColumnIndex + 1;
      *descending = s->Specs[0].SortDirection == ImGuiSortDirection_Descending ? 1 : 0;
   }
   *changed = s->SpecsDirty ? 1 : 0;
   s->SpecsDirty = false;
   return 0;
}

int fig_table_row_color(const double *rgba, int column) {
   ImGuiTable *t = current_table();
   if (!t) return 1;
   if (column < 0 || column > t->ColumnsCount) return 3;
   if (t->CurrentRow < 0 || !t->IsInsideRow) return 4;
   const ImU32 c = ImGui::GetColorU32(ImVec4(static_cast<float>(rgba[0]), static_cast<float>(rgba[1]),
                                             static_cast<float>(rgba[2]), static_cast<float>(rgba[3])));
   if (column == 0)
      ImGui::TableSetBgColor(ImGuiTableBgTarget_RowBg1, c, -1); // over the alternating background (RowBg0)
   else
      ImGui::TableSetBgColor(ImGuiTableBgTarget_CellBg, c, column - 1);
   return 0;
}

int fig_table_column_enabled(int column, int enabled) {
   ImGuiTable *t = current_table();
   if (!t) return 1;
   if (!(t->Flags & ImGuiTableFlags_Hideable)) return 2;
   if (column < 1 || column > t->ColumnsCount) return 3;
   ImGui::TableSetColumnEnabled(column - 1, enabled != 0);
   return 0;
}

int fig_table_hovered_column(int *column) {
   *column = 0;
   ImGuiTable *t = current_table();
   if (!t) return 1;
   const int h = ImGui::TableGetHoveredColumn(); // -1 not over the table, ColumnsCount right of the last column
   if (h >= 0 && h < t->ColumnsCount) *column = h + 1;
   return 0;
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
   const bool again = fig_app_layout_rebuild(id) == 1; // switch_layout, reset_layout: lay it out again
   if (!again && ImGui::DockBuilderGetNode(id) != nullptr) return FIG_OK; // laid out already (this run, an ini file)
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


// The events of a click at (x, y), as test_click queues them (a move, a frame resting there, a press, a release);
// only the move and the rest with `hover`.
static std::vector<state_t::input_t> click_events(float x, float y, int button, bool hover) {
   std::vector<state_t::input_t> ev(hover ? 2 : 5);
   ev[0].kind = 1;
   ev[0].x = x;
   ev[0].y = y;
   ev[1].kind = 0;
   if (!hover) {
      ev[2].kind = 0;
      ev[3].kind = 2;
      ev[3].a = button;
      ev[3].b = 1;
      ev[4].kind = 2;
      ev[4].a = button;
      ev[4].b = 0;
   }
   return ev;
}

// A queued action on an item named by a path (kind 7: test_menu_click's later steps), done when the item is in the
// last frame drawn: replaced by its click (a menu already open: by a move onto it), or waited for one frame more.
// False: wait (nothing after it this frame). The queue is emptied, and the failure kept for test_run, once the item
// has not appeared in the frames allowed.
static bool resolve_action(size_t i) {
   state_t::input_t &e = st.test_input[i];
   figure_items::found_t f;
   std::string           err;
   bool                  missing = false;
   const int             s = figure_items::find(e.text, f, err, missing);
   const bool ready = s == FIG_OK && (f.state & figure_items::S_VISIBLE) && !(f.state & figure_items::S_DISABLED);
   if (!ready) {
      if (e.b-- > 0) return false;
      if (s == FIG_OK) err = "'" + f.path + "' is " + ((f.state & figure_items::S_DISABLED) ? "disabled" : "not visible");
      test_failure = "test_menu_click: " + err;
      return false;
   }
   const bool hover = e.x > 0.0f && (f.state & figure_items::S_OPENED);
   const std::vector<state_t::input_t> ev = click_events(f.cx, f.cy, e.a, hover);
   st.test_input.erase(st.test_input.begin() + static_cast<long>(i));
   st.test_input.insert(st.test_input.begin() + static_cast<long>(i), ev.begin(), ev.end());
   return true;
}

// At the start of a frame (before NewFrame): hand the queued events to Dear ImGui, up to the first boundary. Events
// handed: three frames more at least, as a real event gives (Dear ImGui settles in a few); events still queued: one.
void apply_test_input() {
   if (st.test_input.empty()) return;
   ImGuiIO &io = ImGui::GetIO();
   size_t i = 0;
   bool   handed = false;
   while (i < st.test_input.size()) {
      if (st.test_input[i].kind == 7) {
         if (!resolve_action(i)) break;
         if (!test_failure.empty()) break;
         continue; // its events, from the same place
      }
      const state_t::input_t &e = st.test_input[i];
      if (e.kind == 0) {
         ++i; // the boundary is consumed: what follows waits for the next frame
         break;
      }
      handed = true;
      switch (e.kind) {
      case 1: io.AddMousePosEvent(e.x, e.y); break;
      case 2: io.AddMouseButtonEvent(e.a, e.b != 0); break;
      case 3: io.AddMouseWheelEvent(e.x, e.y); break;
      case 4: io.AddKeyEvent(static_cast<ImGuiKey>(e.a), e.b != 0); break;
      case 6: drop_path(e.text, e.x, e.y); break;
      default: io.AddInputCharactersUTF8(e.text.c_str()); break;
      }
      ++i;
   }
   if (!test_failure.empty()) st.test_input.clear();
   else st.test_input.erase(st.test_input.begin(), st.test_input.begin() + static_cast<long>(i));
   if (handed) frames_at_least(3);
   else if (!st.test_input.empty()) frames_at_least(1);
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
   frames_at_least(3);
   return FIG_OK;
   FIG_CATCH
}

int fig_save_image(const char *path, int path_len, double x0, double y0, double x1, double y1) {
   FIG_TRY
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   if (path_len <= 0) return fail(FIG_ERR_ARGUMENT, "save_image: no file name");
   if (!(x1 > x0) || !(y1 > y0)) return fail(FIG_ERR_ARGUMENT, "save_image: an empty rectangle");
   img = image_request_t{};
   img.path.assign(path, static_cast<size_t>(path_len));
   img.x0 = static_cast<float>(x0);
   img.y0 = static_cast<float>(y0);
   img.x1 = static_cast<float>(x1);
   img.y1 = static_cast<float>(y1);
   img.state = 1;
   frames_at_least(2); // the frame that renders it, even in lazy mode
   return FIG_OK;
   FIG_CATCH
}

int fig_test_capture(const char *path, int path_len) {
   FIG_TRY
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   if (!st.in_frame) return fail(FIG_ERR_STATE, "test_capture: no frame open (call it between next_frame calls)");
   if (path_len <= 0) return fail(FIG_ERR_ARGUMENT, "test_capture: no file name");
   test_capture_path.assign(path, static_cast<size_t>(path_len));
   std::remove(test_capture_path.c_str()); // a picture of an earlier run is never compared for this one
   frames_at_least(2);
   return FIG_OK;
   FIG_CATCH
}

int fig_render_threads(int threads) {
   FIG_TRY
   if (threads < 0 || threads > 64) return fail(FIG_ERR_ARGUMENT, "render threads must be in [0, 64]");
   render_threads = threads;
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
// `who` names the Fortran procedure in the message of a failure.
static int parse_chord(const std::string &s, const char *who, int *chord) {
   int mods = 0, key = ImGuiKey_None;
   size_t start = 0;
   while (start <= s.size()) {
      size_t end = s.find('+', start);
      if (end == std::string::npos) end = s.size();
      const std::string name = s.substr(start, end - start);
      const ImGuiKey k = key_by_name(name);
      if (k == ImGuiKey_None)
         return fail(FIG_ERR_ARGUMENT, std::string(who) + ": unknown key \"" + name + "\" in \"" + s + "\"");
      if (k & ImGuiMod_Mask_) {
         mods |= k;
      } else {
         if (key != ImGuiKey_None) return fail(FIG_ERR_ARGUMENT, std::string(who) + ": more than one key in \"" + s + "\"");
         key = k;
      }
      start = end + 1;
   }
   if (key == ImGuiKey_None)
      return fail(FIG_ERR_ARGUMENT, std::string(who) + ": no key besides the modifiers in \"" + s + "\"");
   *chord = mods | key;
   return FIG_OK;
}

// The scope of a shortcut: 0 'focused', 1 'global', 2 'item', 3 'always'; 'item' and 'always' only for a call of
// ig_shortcut (`routed_only` false): the next item owns its chord through a route.
static int parse_shortcut_scope(const std::string &s, const char *who, bool routed_only, int *scope) {
   if (s == "focused") *scope = 0;
   else if (s == "global") *scope = 1;
   else if (s == "item" && !routed_only) *scope = 2;
   else if (s == "always" && !routed_only) *scope = 3;
   else
      return fail(FIG_ERR_ARGUMENT, std::string(who) + ": unknown scope \"" + s + "\" (" +
                                       (routed_only ? "'focused' or 'global')" : "'focused', 'global', 'item' or 'always')"));
   return FIG_OK;
}

// The routing flags of a scope. 'focused': Dear ImGui's focus route, the deepest focused window in the focus stack
// of the calling window; a call outside every window (Dear ImGui's fallback window, which never has focus) takes
// the global route of lowest priority instead: it fires unless a focused window routes the same chord. 'global':
// the global route over the focused ones. 'item': the route of the active item.
static ImGuiInputFlags shortcut_route(int scope) {
   const ImGuiContext &g = *GImGui;
   if (scope == 1) return ImGuiInputFlags_RouteGlobal | ImGuiInputFlags_RouteOverFocused;
   if (scope == 2) return ImGuiInputFlags_RouteActive;
   if (g.CurrentWindow && g.CurrentWindow->IsFallbackWindow) return ImGuiInputFlags_RouteGlobal;
   return ImGuiInputFlags_RouteFocused;
}

// A text field being edited uses the plain keys (letters, arrows, home, end, enter, escape, ...): while one is
// edited, a 'focused' chord of a key alone or with shift, other than f1-f24, is not delivered. Dear ImGui filters
// only the keys that type a character.
static bool shortcut_held_by_text(int chord) {
   if (!ImGui::GetIO().WantTextInput) return false;
   if (chord & (ImGuiMod_Ctrl | ImGuiMod_Alt | ImGuiMod_Super)) return false;
   const int key = chord & ~ImGuiMod_Mask_;
   return !(key >= ImGuiKey_F1 && key <= ImGuiKey_F24);
}

int fig_shortcut(const char *keys, int keys_len, const char *scope, int scope_len, int repeat, int *pressed) {
   FIG_TRY
   *pressed = 0;
   int chord = 0, sc = 0;
   const std::string k(keys, keys_len > 0 ? static_cast<size_t>(keys_len) : 0);
   const std::string s(scope, scope_len > 0 ? static_cast<size_t>(scope_len) : 0);
   int status = parse_chord(k, "ig_shortcut", &chord);
   if (status != FIG_OK) return status;
   status = parse_shortcut_scope(s, "ig_shortcut", false, &sc);
   if (status != FIG_OK) return status;
   if (sc == 3) {
      // 'always': no route (Dear ImGui's IsKeyChordPressed, v0.3's ig_shortcut): every call of the chord fires,
      // whatever has the focus, a text field being edited included; not inside a disabled block, as Shortcut.
      if (GImGui->CurrentItemFlags & ImGuiItemFlags_Disabled) return FIG_OK;
      const ImGuiInputFlags rep =
         repeat ? (ImGuiInputFlags_Repeat | ImGuiInputFlags_RepeatUntilKeyModsChange) : ImGuiInputFlags_None;
      *pressed = ImGui::IsKeyChordPressed(chord, rep, ImGuiKeyOwner_Any) ? 1 : 0;
      return FIG_OK;
   }
   if (sc == 0 && shortcut_held_by_text(chord)) return FIG_OK;
   ImGuiInputFlags flags = shortcut_route(sc);
   if (repeat) flags |= ImGuiInputFlags_Repeat;
   ImGuiID owner = 0; // 0: Dear ImGui's routing id, the focus scope of the calling window
   if (sc == 2) {
      owner = GImGui->LastItemData.ID; // the item drawn last
      if (owner == 0) return FIG_OK;
   }
   *pressed = ImGui::Shortcut(chord, flags, owner) ? 1 : 0;
   return FIG_OK;
   FIG_CATCH
}

int fig_set_next_item_shortcut(const char *keys, int keys_len, const char *scope, int scope_len) {
   FIG_TRY
   int chord = 0, sc = 0;
   const std::string k(keys, keys_len > 0 ? static_cast<size_t>(keys_len) : 0);
   const std::string s(scope, scope_len > 0 ? static_cast<size_t>(scope_len) : 0);
   int status = parse_chord(k, "ig_set_next_item_shortcut", &chord);
   if (status != FIG_OK) return status;
   status = parse_shortcut_scope(s, "ig_set_next_item_shortcut", true, &sc);
   if (status != FIG_OK) return status;
   if (sc == 0 && shortcut_held_by_text(chord)) return FIG_OK; // the next item is drawn without its chord
   ImGui::SetNextItemShortcut(chord, shortcut_route(sc) | ImGuiInputFlags_Tooltip);
   return FIG_OK;
   FIG_CATCH
}

// The status of the item drawn last, in one call (Dear ImGui's IsItem*, IsMouseDoubleClicked, GetItemRect*): a
// snapshot the program keeps while it draws other items. clicked and double_clicked, per button (left, right, middle),
// as IsItemClicked: the button went down this frame with the pointer over the item.
// The item drawn last changed its value on this frame (Dear ImGui's MarkItemEdited, as Dear ImGui's own Combo calls
// it after EndCombo): its status reports edited, and deactivated_after_edit when it is left.
void fig_mark_last_item_edited(void) {
   if (ImGui::GetCurrentContext() && GImGui->LastItemData.ID != 0) ImGui::MarkItemEdited(GImGui->LastItemData.ID);
}

// A range [lo, hi] edited by two drags side by side, then the label: Dear ImGui's DragFloatRange2 for any data type.
// Each drag is bounded by the other end and by the outer bound (the lower end may not pass the upper one); an end at
// its bound already (lo at vmin with hi at vmin) is read-only, as upstream.
int fig_drag_range(const char *label, int data_type, void *lo, void *hi, float speed, const void *vmin,
                   const void *vmax, const char *format, int flags) {
   ImGuiWindow *window = ImGui::GetCurrentWindow();
   if (window->SkipItems) return 0;
   ImGuiContext &g = *GImGui;
   const size_t size = ImGui::DataTypeGetInfo(data_type)->Size;
   ImGuiDataTypeStorage lo_max, hi_min; // the bound of one end is the other end (within the outer bounds)
   ImGui::PushID(label);
   ImGui::BeginGroup();
   ImGui::PushMultiItemsWidths(2, ImGui::CalcItemWidth());
   std::memcpy(&lo_max, ImGui::DataTypeCompare(data_type, hi, vmax) > 0 ? vmax : hi, size);
   const int lo_flags = flags | (ImGui::DataTypeCompare(data_type, vmin, &lo_max) == 0 ? ImGuiSliderFlags_ReadOnly : 0);
   bool changed = ImGui::DragScalar("##min", data_type, lo, speed, vmin, &lo_max, format, lo_flags);
   ImGui::PopItemWidth();
   ImGui::SameLine(0.0f, g.Style.ItemInnerSpacing.x);
   std::memcpy(&hi_min, ImGui::DataTypeCompare(data_type, lo, vmin) < 0 ? vmin : lo, size);
   const int hi_flags = flags | (ImGui::DataTypeCompare(data_type, &hi_min, vmax) == 0 ? ImGuiSliderFlags_ReadOnly : 0);
   changed |= ImGui::DragScalar("##max", data_type, hi, speed, &hi_min, vmax, format, hi_flags);
   ImGui::PopItemWidth();
   ImGui::SameLine(0.0f, g.Style.ItemInnerSpacing.x);
   ImGui::TextEx(label, ImGui::FindRenderedTextEnd(label));
   ImGui::EndGroup();
   ImGui::PopID();
   return changed ? 1 : 0;
}

// A list box of Fortran strings (count items of item_len bytes, blank-padded): Dear ImGui's ListBox with a height in
// pixels; the rows out of view are clipped (the chosen one is always submitted, so that keyboard navigation starts
// from it).
int fig_list_box(const char *label, int *current, const char *items, int item_len, int count, double height) {
   ImGuiContext &g = *GImGui;
   const float row = ImGui::GetTextLineHeightWithSpacing();
   const float h = height != 0.0 ? static_cast<float>(height)
                                 : ImTrunc(row * (static_cast<float>(std::min(count, 7)) + 0.25f) +
                                           g.Style.FramePadding.y * 2.0f);
   if (!ImGui::BeginListBox(label, ImVec2(0.0f, h))) return 0;
   bool changed = false;
   std::string text;
   ImGuiListClipper clipper;
   clipper.Begin(count, row);
   if (*current >= 0 && *current < count) clipper.IncludeItemByIndex(*current);
   while (clipper.Step()) {
      for (int i = clipper.DisplayStart; i < clipper.DisplayEnd; ++i) {
         const char *p = items + static_cast<size_t>(i) * static_cast<size_t>(item_len);
         size_t n = item_len > 0 ? static_cast<size_t>(item_len) : 0;
         while (n > 0 && p[n - 1] == ' ') --n;
         text.assign(p, n);
         const bool chosen = i == *current;
         ImGui::PushID(i); // items may repeat a text: the index tells them apart
         if (ImGui::Selectable(text.c_str(), chosen)) {
            *current = i;
            changed = true;
         }
         if (chosen) ImGui::SetItemDefaultFocus();
         ImGui::PopID();
      }
   }
   ImGui::EndListBox();
   if (changed) ImGui::MarkItemEdited(g.LastItemData.ID);
   return changed ? 1 : 0;
}

// Aligned groups: the cursor moved right by the space left on the line (all of it, or half for the centre), the
// width being the group's on the previous frame (Dear ImGui's storage of the window, keyed by the id). The cursor is
// moved as Indent moves it (not SetCursorPos, which an empty group would report as extending its parent).
namespace {
struct align_t {
   ImGuiStorage *storage; // the window's storage at the begin
   ImGuiID       key;
   int           frame;   // Dear ImGui's frame count at the begin
};
std::vector<align_t> aligns; // the open aligned groups, innermost last (the scope record keeps them paired)

void align_shift(float width, int where) {
   if (where != 1 && where != 2) return;
   const float avail = ImGui::GetContentRegionAvail().x;
   const float off = where == 1 ? (avail - width) * 0.5f : avail - width;
   if (off > 0.0f) GImGui->CurrentWindow->DC.CursorPos.x += IM_TRUNC(off);
}
} // namespace

// ImPlot's EndPlot fits the axes asked to fit this frame (every axis of a plot on its first frame, an auto-fitting
// axis, a double click): an axis that received no data has empty extents (+inf, -inf), and ImPlotAxis::ApplyFit
// computes (-inf) * padding, NaN with the default padding 0: an invalid operation, which stops a program built with
// -ffpe-trap=invalid (gfortran's debug flags) at a plot that has no data yet. Without traps ImPlot then ignores the
// NaN and keeps the axis's range, so not fitting such an axis draws the same plot.
void fig_plot_end(void) {
   if (!ImPlot::GetCurrentContext() || !GImPlot->CurrentPlot) return;
   ImPlot::SetupLock(); // as EndPlot would: a plot without items finishes its setup there, which asks for the fits
   ImPlotPlot &p = *GImPlot->CurrentPlot;
   for (int i = 0; i < ImAxis_COUNT; ++i) {
      ImPlotAxis &a = p.Axes[i];
      if (a.FitThisFrame && a.FitExtents.Min > a.FitExtents.Max) a.FitThisFrame = false; // no data: nothing to fit
   }
   ImPlot::EndPlot();
}

int fig_plot_state(int *enabled, int *scale) {
   for (int i = 0; i < ImAxis_COUNT; ++i) {
      enabled[i] = 0;
      scale[i] = ImPlotScale_Linear;
   }
   if (!ImPlot::GetCurrentContext() || !GImPlot->CurrentPlot) return 0;
   const ImPlotPlot &p = *GImPlot->CurrentPlot;
   for (int i = 0; i < ImAxis_COUNT; ++i) {
      enabled[i] = p.Axes[i].Enabled ? 1 : 0;
      scale[i] = p.Axes[i].Scale;
   }
   return p.SetupLocked ? 2 : 1;
}

void fig_plot_axis_constraints(int axis, int given, const double *v) {
   if (!ImPlot::GetCurrentContext() || !GImPlot->CurrentPlot || axis < 0 || axis >= ImAxis_COUNT) return;
   // name map: ImPlot::SetupAxisLimitsConstraints, ImPlot::SetupAxisZoomConstraints (each sets both ends at once)
   ImPlotAxis &a = GImPlot->CurrentPlot->Axes[axis];
   if (given & 1) a.ConstraintRange.Min = v[0];
   if (given & 2) a.ConstraintRange.Max = v[1];
   if (given & 4) a.ConstraintZoom.Min = v[2];
   if (given & 8) a.ConstraintZoom.Max = v[3];
}

int fig_align_begin(const char *id, int id_len, int where) {
   FIG_TRY
   if (!ImGui::GetCurrentContext() || !GImGui->WithinFrameScope) return fail(FIG_ERR_STATE, "no frame open");
   const int frame = ImGui::GetFrameCount();
   while (!aligns.empty() && aligns.back().frame != frame) aligns.pop_back(); // left by an earlier frame
   ImGuiStorage *storage = ImGui::GetStateStorage();
   const ImGuiID key = ImGui::GetID(id, id + (id_len > 0 ? id_len : 0));
   const float   width = storage->GetFloat(key, -1.0f);
   if (width >= 0.0f) align_shift(width, where);
   ImGui::BeginGroup();
   aligns.push_back({storage, key, frame});
   return FIG_OK;
   FIG_CATCH
}

void fig_align_end(void) {
   if (!ImGui::GetCurrentContext()) return;
   ImGui::EndGroup();
   if (aligns.empty()) return;
   const align_t a = aligns.back();
   aligns.pop_back();
   if (a.frame != ImGui::GetFrameCount()) return;
   const float w = ImGui::GetItemRectSize().x;
   if (std::fabs(a.storage->GetFloat(a.key, -1.0f) - w) > 0.5f) { // first frame, or the width changed: one more
      a.storage->SetFloat(a.key, w);                                // frame draws it where it belongs (lazy redraw)
      frames_at_least(1);
   }
}

void fig_align_next(double width, int where) {
   if (!ImGui::GetCurrentContext() || !GImGui->WithinFrameScope) return;
   align_shift(static_cast<float>(width), where);
}

int fig_last_item(fig_item_status *s) {
   FIG_TRY
   *s = fig_item_status{};
   if (!ImGui::GetCurrentContext()) return fail(FIG_ERR_STATE, "figure is not initialized");
   s->hovered = ImGui::IsItemHovered() ? 1 : 0;
   s->active = ImGui::IsItemActive() ? 1 : 0;
   s->focused = ImGui::IsItemFocused() ? 1 : 0;
   s->visible = ImGui::IsItemVisible() ? 1 : 0;
   s->activated = ImGui::IsItemActivated() ? 1 : 0;
   s->edited = ImGui::IsItemEdited() ? 1 : 0;
   s->deactivated = ImGui::IsItemDeactivated() ? 1 : 0;
   s->deactivated_after_edit = ImGui::IsItemDeactivatedAfterEdit() ? 1 : 0;
   s->toggled_open = ImGui::IsItemToggledOpen() ? 1 : 0;
   for (int b = 0; b < 3; ++b) {
      s->clicked[b] = ImGui::IsItemClicked(b) ? 1 : 0;
      s->double_clicked[b] = ImGui::IsMouseDoubleClicked(b) && ImGui::IsItemHovered(ImGuiHoveredFlags_None) ? 1 : 0;
   }
   const ImVec2 a = ImGui::GetItemRectMin(), z = ImGui::GetItemRectSize();
   s->rect[0] = a.x;
   s->rect[1] = a.y;
   s->rect[2] = z.x;
   s->rect[3] = z.y;
   return FIG_OK;
   FIG_CATCH
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

// ---- Items by path (figure_testing): actions on the items of the last frame drawn (figure_items.cpp) ------------------

namespace {
void queue_events(const std::vector<state_t::input_t> &ev) {
   st.test_input.insert(st.test_input.end(), ev.begin(), ev.end());
}

void queue_key(const char *name, int down) { fig_input_key(name, static_cast<int>(std::strlen(name)), down); }

// The item a path names, ready for input: found, shown and enabled. `who` starts the messages.
int item_for_input(const char *who, const char *path, int path_len, figure_items::found_t &f) {
   if (!ImGui::GetCurrentContext()) return fail(FIG_ERR_STATE, "figure is not initialized");
   if (!figure_items::recording()) figure_items::record(true);
   std::string err;
   bool        missing = false;
   const int   s = figure_items::find(std::string(path, path_len > 0 ? static_cast<size_t>(path_len) : 0), f, err,
                                      missing);
   if (s != FIG_OK) return fail(s, std::string(who) + ": " + err);
   if (f.state & figure_items::S_DISABLED) return fail(FIG_ERR_STATE, std::string(who) + ": '" + f.path + "' is disabled");
   if (!(f.state & figure_items::S_VISIBLE))
      return fail(FIG_ERR_STATE, std::string(who) + ": '" + f.path + "' is not visible in the last frame (scrolled " +
                                    "out of view, clipped, or in a window not shown yet)");
   return FIG_OK;
}
} // namespace

int fig_item_click(const char *path, int path_len, int button) {
   FIG_TRY
   if (button < 0 || button > 2) return fail(FIG_ERR_ARGUMENT, "test_item_click: button 0 left, 1 right, 2 middle");
   figure_items::found_t f;
   const int s = item_for_input("test_item_click", path, path_len, f);
   if (s != FIG_OK) return s;
   queue_events(click_events(f.cx, f.cy, button, false));
   return FIG_OK;
   FIG_CATCH
}

// Into a field: a click with the shortcut key held (a slider or a drag takes typed input then; a text field is
// focused), everything selected, the text typed, Enter.
int fig_item_type(const char *path, int path_len, const char *text, int text_len) {
   FIG_TRY
   figure_items::found_t f;
   const int s = item_for_input("test_item_type_text", path, path_len, f);
   if (s != FIG_OK) return s;
   if (!(f.state & figure_items::S_INPUTABLE))
      return fail(FIG_ERR_ARGUMENT, "test_item_type_text: '" + f.path + "' takes no typed text (not a text field, " +
                                       "a number field, a slider or a drag)");
   std::vector<state_t::input_t> ev = click_events(f.cx, f.cy, 0, false);
   queue_events({ev[0], ev[1], ev[2]});
   queue_key("shortcut", 1);
   queue_events({ev[3], ev[4]});
   queue_key("shortcut", 0);
   queue_events({ev[1]});
   queue_key("shortcut", 1);
   queue_key("a", 1);
   queue_key("a", 0);
   queue_key("shortcut", 0);
   queue_events({ev[1]});
   state_t::input_t t;
   t.kind = 5;
   t.text.assign(text, text_len > 0 ? static_cast<size_t>(text_len) : 0);
   queue_events({t, ev[1]});
   queue_key("enter", 1);
   queue_key("enter", 0);
   return FIG_OK;
   FIG_CATCH
}

// A menu path: the first item it names is clicked now (or, already open, pointed at); each following level is clicked
// once it appears, over the next frames (a menu opens a frame after its click).
int fig_menu_click(const char *path, int path_len) {
   FIG_TRY
   if (!ImGui::GetCurrentContext()) return fail(FIG_ERR_STATE, "figure is not initialized");
   if (!figure_items::recording()) figure_items::record(true);
   const std::string        p(path, path_len > 0 ? static_cast<size_t>(path_len) : 0);
   std::vector<std::string> segs;
   bool                     absolute = false;
   if (!figure_items::split(p, segs, absolute))
      return fail(FIG_ERR_ARGUMENT, "test_menu_click: '" + p + "' is not a path: an empty segment");
   std::vector<std::string> prefixes;
   std::string              pre = absolute ? "//" : "";
   for (size_t k = 0; k < segs.size(); ++k) {
      std::string seg;
      for (char c : segs[k]) {
         if (c == '/') seg += '\\';
         seg += c;
      }
      pre += (k > 0 ? "/" : "") + seg;
      prefixes.push_back(pre);
   }
   size_t first = prefixes.size();
   figure_items::found_t f;
   for (size_t k = 0; k < prefixes.size(); ++k) {
      std::string err;
      bool        missing = false;
      const int   s = figure_items::find(prefixes[k], f, err, missing);
      if (s != FIG_OK) return fail(s, "test_menu_click: " + err);
      if (!(f.state & figure_items::S_WINDOW)) {
         first = k;
         break;
      }
   }
   if (first == prefixes.size()) return fail(FIG_ERR_ARGUMENT, "test_menu_click: '" + p + "' names a window, no menu");
   if (f.state & figure_items::S_DISABLED) return fail(FIG_ERR_STATE, "test_menu_click: '" + f.path + "' is disabled");
   if (!(f.state & figure_items::S_VISIBLE))
      return fail(FIG_ERR_STATE, "test_menu_click: '" + f.path + "' is not visible in the last frame");
   const bool last = first + 1 == prefixes.size();
   queue_events(click_events(f.cx, f.cy, 0, !last && (f.state & figure_items::S_OPENED)));
   for (size_t k = first + 1; k < prefixes.size(); ++k) {
      state_t::input_t a;
      a.kind = 7;
      a.text = prefixes[k];
      a.a = 0;
      a.b = 20;                                     // frames it may take to appear
      a.x = k + 1 < prefixes.size() ? 1.0f : 0.0f;  // a menu on the way: pointed at when already open
      queue_events({a});
   }
   return FIG_OK;
   FIG_CATCH
}

// The frame driver of a test: true while the interface is not idle (input queued, an action waiting, frames asked for),
// so the program draws one more frame; false once idle. Past max_frames frames of one run: false, and a failure.
int fig_test_run(int max_frames, int *more) {
   FIG_TRY
   *more = 0;
   if (!ImGui::GetCurrentContext()) return fail(FIG_ERR_STATE, "figure is not initialized");
   if (max_frames < 1) return fail(FIG_ERR_ARGUMENT, "test_run: max_frames must be positive");
   if (!test_failure.empty()) {
      const std::string msg = test_failure;
      test_failure.clear();
      run_frames = 0;
      return fail(FIG_ERR_STATE, msg);
   }
   const ImGuiContext &g = *ImGui::GetCurrentContext();
   const size_t queued = st.test_input.size() + static_cast<size_t>(g.InputEventsQueue.Size);
   const int    requested = st.frames_left.load();
   if (queued == 0 && requested <= 0) {
      run_frames = 0;
      return FIG_OK;
   }
   if (run_frames >= max_frames) {
      run_frames = 0;
      std::string why;
      for (const state_t::input_t &e : st.test_input)
         if (e.kind == 7) {
            why = "an action waits for '" + e.text + "'";
            break;
         }
      if (why.empty() && queued > 0) why = std::to_string(queued) + " input events still queued";
      if (why.empty()) why = "frames are still asked for (app%request_frames, an animation, a process or a task)";
      return fail(FIG_ERR_STATE, "test_run: the interface is not idle after " + std::to_string(max_frames) +
                                    " frames: " + why);
   }
   ++run_frames;
   *more = 1;
   return FIG_OK;
   FIG_CATCH
}

int fig_input_text(const char *text, int text_len) {
   state_t::input_t e;
   e.kind = 5;
   e.text.assign(text, text_len > 0 ? static_cast<size_t>(text_len) : 0);
   return queue_input(e);
}

int fig_input_drop(const char *path, int path_len, float x, float y) {
   if (path_len <= 0) return fail(FIG_ERR_ARGUMENT, "test_drop: a path is empty");
   state_t::input_t e;
   e.kind = 6;
   e.text.assign(path, static_cast<size_t>(path_len));
   e.x = x;
   e.y = y;
   return queue_input(e);
}

int fig_dropped(int *count, float *x, float *y) {
   *count = static_cast<int>(st.dropped.size());
   *x = st.dropped_x;
   *y = st.dropped_y;
   return st.m == mode::none ? fail(FIG_ERR_STATE, "figure is not initialized") : FIG_OK;
}

int fig_dropped_path(int index, char *buf, int buf_len) {
   if (index < 1 || index > static_cast<int>(st.dropped.size())) return 0;
   const std::string &s = st.dropped[static_cast<size_t>(index - 1)];
   const size_t n = std::min(s.size(), static_cast<size_t>(buf_len > 0 ? buf_len : 0));
   if (n > 0) std::memcpy(buf, s.data(), n);
   return static_cast<int>(s.size());
}

int fig_set_clipboard(const char *text, int text_len) {
   FIG_TRY
   if (!ImGui::GetCurrentContext()) return fail(FIG_ERR_STATE, "ig_set_clipboard: figure is not initialized");
   const std::string s(text, text_len > 0 ? static_cast<size_t>(text_len) : 0);
   ImGui::SetClipboardText(s.c_str());
   return FIG_OK;
   FIG_CATCH
}

long long fig_get_clipboard(char *buf, long long cap) {
   if (!ImGui::GetCurrentContext()) return 0;
   const char *text = ImGui::GetClipboardText();
   if (!text) return 0;
   const size_t len = std::strlen(text);
   const size_t n = std::min(len, static_cast<size_t>(cap > 0 ? cap : 0));
   if (n > 0) std::memcpy(buf, text, n);
   return static_cast<long long>(len);
}

// A tick label of the plot being declared (between BeginPlot and EndPlot, after its setup): axis 0 x, 1 y; index from 1;
// count is the number of ticks. For tests of axis formats.
int fig_plot_tick_label(int axis, int index, char *buf, int buf_len, int *count, int *len) {
   *count = 0;
   *len = 0;
   ImPlotPlot *plot = ImPlot::GetCurrentContext() ? ImPlot::GetCurrentPlot() : nullptr;
   if (!plot)
      return fail(FIG_ERR_STATE, "test_plot_tick: no plot is being declared (between ip_begin_plot and ip_end_plot)");
   static const char *names[ImAxis_COUNT] = {"x1", "x2", "x3", "y1", "y2", "y3"};
   if (axis < 0 || axis >= ImAxis_COUNT)
      return fail(FIG_ERR_ARGUMENT, "test_plot_tick: unknown axis ('x1', 'x2', 'x3', 'y1', 'y2', 'y3', 'x' or 'y')");
   if (!plot->Axes[axis].Enabled)
      return fail(FIG_ERR_STATE, std::string("test_plot_tick: axis '") + names[axis] +
                                 "' is not set up (ip_setup_axis('" + names[axis] + "'))");
   ImPlot::SetupLock(); // the ticks exist once the setup is locked (the first item locks it)
   const ImPlotTicker &ticker = plot->Axes[axis].Ticker;
   *count = ticker.TickCount();
   if (index < 1 || index > *count) return FIG_OK;
   const char *text = ticker.GetText(index - 1);
   *len = static_cast<int>(std::strlen(text));
   const int n = std::min(*len, buf_len);
   if (n > 0) std::memcpy(buf, text, static_cast<size_t>(n));
   return FIG_OK;
}

// An annotation of the plot being declared: text in a box at (x, y) [plot units], offset [pixels] (0: centred), drawn at
// EndPlot; rgba[3] = 0: no box, the plot's inlay text colour. Refused outside a plot (ImPlot would assert).
int fig_plot_annotation(double x, double y, const float *rgba, float dx, float dy, int clamp, const char *text,
                        int text_len) {
   if (!ImPlot::GetCurrentContext() || !ImPlot::GetCurrentPlot())
      return fail(FIG_ERR_STATE, "ip_annotation: no plot is being declared (between ip_begin_plot and ip_end_plot)");
   const std::string t(text, text_len > 0 ? static_cast<size_t>(text_len) : 0);
   ImPlot::Annotation(x, y, ImVec4(rgba[0], rgba[1], rgba[2], rgba[3]), ImVec2(dx, dy), clamp != 0, "%s", t.c_str());
   return FIG_OK;
}

// A tag of the plot being declared on the axis `axis` (an ImAxis set up on this frame) at `value` [axis units], drawn at
// EndPlot over the axis: a box of colour rgba (rgba[3] < 0: the colour of the last item drawn; alpha 0: no box, the
// axis's text colour) holding `text` (has_text 1) or the value labelled as the axis labels its ticks (has_text 0).
// Refused outside a plot and for an axis not set up (ImPlot would assert, or draw on a hidden axis).
int fig_plot_tag(int axis, double value, const float *rgba, const char *text, int text_len, int has_text) {
   if (!ImPlot::GetCurrentContext() || !ImPlot::GetCurrentPlot())
      return fail(FIG_ERR_STATE, "ip_tag: no plot is being declared (call it between a true ip_begin_plot and ip_end_plot)");
   if (axis < 0 || axis >= ImAxis_COUNT || !GImPlot->CurrentPlot->Axes[axis].Enabled)
      return fail(FIG_ERR_STATE, "ip_tag: the axis is not set up");
   const ImVec4 c = rgba[3] < 0.0f ? ImPlot::GetLastItemColor() : ImVec4(rgba[0], rgba[1], rgba[2], rgba[3]);
   const std::string t(text, text_len > 0 ? static_cast<size_t>(text_len) : 0);
   // ImPlot's public TagX/TagY tag the current axes (its Tag(ImAxis, ...) is not in a header): the axis is made current
   // for the call, then the program's current axes are restored
   ImPlotPlot &plot = *GImPlot->CurrentPlot;
   const ImAxis cx = plot.CurrentX, cy = plot.CurrentY;
   if (axis < ImAxis_Y1) {
      plot.CurrentX = axis;
      if (has_text != 0) ImPlot::TagX(value, c, "%s", t.c_str());
      else ImPlot::TagX(value, c, false);
   } else {
      plot.CurrentY = axis;
      if (has_text != 0) ImPlot::TagY(value, c, "%s", t.c_str());
      else ImPlot::TagY(value, c, false);
   }
   plot.CurrentX = cx;
   plot.CurrentY = cy;
   return FIG_OK;
}

// The rectangle of the innermost open popup (a menu, a combo's list, a colour picker), as drawn in the last frame;
// found 0 if no popup is open.
int fig_popup_rect(float *rect, int *found) {
   if (!ImGui::GetCurrentContext()) return fail(FIG_ERR_STATE, "figure is not initialized");
   ImGuiContext &g = *ImGui::GetCurrentContext();
   ImGuiWindow *w = g.OpenPopupStack.Size > 0 ? g.OpenPopupStack.back().Window : nullptr;
   *found = w ? 1 : 0;
   if (w) {
      rect[0] = w->Pos.x;
      rect[1] = w->Pos.y;
      rect[2] = w->Pos.x + w->Size.x;
      rect[3] = w->Pos.y + w->Size.y;
   }
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

// ---- Text buffers (text_buffer_object) -----------------------------------------------------------------------------
// The text of a multi-line field, owned here: bytes[0, len) and a NUL, in a vector at least len + 1 long whose whole
// size is the capacity Dear ImGui is given, so that it edits in place and asks the resize callback for more. gen
// counts the sets, so that a field being edited reloads a text set by the program (shown is the gen it last drew).
struct text_buffer_t {
   std::vector<char> bytes = std::vector<char>(1, '\0');
   size_t            len = 0;
   unsigned          gen = 0;
   unsigned          shown = 0;
};
static std::mutex                   text_mutex;   // the handles and the texts: tasks may set and read them
static std::map<int, text_buffer_t> text_buffers;
static int                          text_next_id = 1;

// Dear ImGui's resize request: the text is growing past the capacity (BufSize is at least the new length + 1), or has
// a new length (every edit applied). The vector grows geometrically (std::vector's resize), not by the byte.
static int text_resize(ImGuiInputTextCallbackData *d) {
   if (d->EventFlag != ImGuiInputTextFlags_CallbackResize) return 0;
   text_buffer_t *b = static_cast<text_buffer_t *>(d->UserData);
   if (static_cast<size_t>(d->BufSize) > b->bytes.size()) {
      const size_t need = static_cast<size_t>(d->BufSize);
      b->bytes.resize(std::max(need, b->bytes.size() + b->bytes.size() / 2));
   }
   b->len = static_cast<size_t>(d->BufTextLen);
   d->Buf = b->bytes.data();
   d->BufSize = static_cast<int>(std::min(b->bytes.size(), static_cast<size_t>(INT_MAX)));
   return 0;
}

int fig_text_set(int *id, const char *text, long long len) {
   FIG_TRY
   std::lock_guard<std::mutex> lock(text_mutex);
   if (*id <= 0 || text_buffers.find(*id) == text_buffers.end()) {
      *id = text_next_id++;
      text_buffers[*id];
   }
   text_buffer_t &b = text_buffers[*id];
   const size_t n = len > 0 ? static_cast<size_t>(len) : 0;
   if (n >= static_cast<size_t>(INT_MAX)) return fail(FIG_ERR_ARGUMENT, "text_buffer%set: the text is 2 GiB or more");
   b.bytes.assign(n + 1, '\0');
   size_t k = 0;
   for (size_t i = 0; i < n; ++i) {
      if (text[i] == '\r' && i + 1 < n && text[i + 1] == '\n') continue; // CRLF: the LF alone
      if (text[i] == '\0') break;                                        // Dear ImGui's text ends at a NUL
      b.bytes[k++] = text[i];
   }
   b.bytes[k] = '\0';
   b.len = k;
   ++b.gen;
   return FIG_OK;
   FIG_CATCH
}

long long fig_text_get(int id, char *buf, long long cap) {
   std::lock_guard<std::mutex> lock(text_mutex);
   const auto it = text_buffers.find(id);
   if (it == text_buffers.end()) return 0;
   const size_t n = std::min(it->second.len, cap > 0 ? static_cast<size_t>(cap) : 0);
   if (n > 0) std::memcpy(buf, it->second.bytes.data(), n);
   return static_cast<long long>(it->second.len);
}

long long fig_text_length(int id) {
   std::lock_guard<std::mutex> lock(text_mutex);
   const auto it = text_buffers.find(id);
   return it == text_buffers.end() ? 0 : static_cast<long long>(it->second.len);
}

void fig_text_release(int id) {
   std::lock_guard<std::mutex> lock(text_mutex);
   text_buffers.erase(id);
}

int fig_widget_input_text_multiline(int *id, const char *label, int label_len, double width, double height,
                                    int flags) {
   if (!ImGui::GetCurrentContext()) return 0;
   std::lock_guard<std::mutex> lock(text_mutex); // held while Dear ImGui edits the text: a task's set waits
   if (*id <= 0 || text_buffers.find(*id) == text_buffers.end()) {
      *id = text_next_id++;
      text_buffers[*id];
   }
   text_buffer_t &b = text_buffers[*id];
   const std::string l(label, label_len > 0 ? static_cast<size_t>(label_len) : 0);
   if (b.gen != b.shown) { // a set since the last draw: a field being edited shows it (its undo history kept)
      const ImGuiID wid = ImGui::GetID(l.c_str());
      if (ImGui::GetActiveID() == wid)
         if (ImGuiInputTextState *s = ImGui::GetInputTextState(wid)) s->ReloadUserBufAndKeepSelection();
      b.shown = b.gen;
   }
   const ImVec2 extent(static_cast<float>(width), static_cast<float>(height));
   const bool edited = ImGui::InputTextMultiline(l.c_str(), b.bytes.data(), b.bytes.size(), extent,
                                                 static_cast<ImGuiInputTextFlags>(flags) |
                                                    ImGuiInputTextFlags_CallbackResize,
                                                 text_resize, &b);
   if (edited) b.len = std::strlen(b.bytes.data());
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
   if (woken.exchange(true)) return; // one wake-up per wait is enough
   if (sdl_events.load()) {
      SDL_Event e;
      SDL_zero(e);
      e.type = SDL_EVENT_USER;
      SDL_PushEvent(&e);
   } else {
      figure_remote::wake(); // nothing without a remote server (headless mode never waits)
   }
}

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
   frames_at_least(3); // drawn at once, even with lazy redraw
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

extern "C" int fig_notification_alpha(int index, float *alpha) {
   *alpha = 0.0f;
   if (index >= 1 && index <= static_cast<int>(note_alphas.size())) *alpha = note_alphas[static_cast<size_t>(index - 1)];
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

// The extent of the vertices of colour c in the current window's draw list (rect: xmin, ymin, xmax, ymax).
static void drawn_extent(ImU32 c, float *rect, int *found) {
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
   drawn_extent(ImGui::GetColorU32(col), rect, found);
   return FIG_OK;
}

// The same for an RGBA colour (as an item's spec colour is drawn: ImGui::GetColorU32 of it).
extern "C" int fig_drawn_extent_rgba(const float *rgba, float *rect, int *found) {
   *found = 0;
   if (!ImGui::GetCurrentContext() || !ImGui::GetCurrentWindowRead())
      return fail(FIG_ERR_STATE, "test_drawn_extent: call it inside a window, in a frame");
   drawn_extent(ImGui::GetColorU32(ImVec4(rgba[0], rgba[1], rgba[2], rgba[3])), rect, found);
   return FIG_OK;
}

// ---- Glyphs, for tests -----------------------------------------------------------------------------------------

int fig_test_glyph(const char *text, int text_len, const char *font, int font_len, char *source, int source_cap,
                   int *source_len, long long *pixels, double *width, double *height, long long *checksum) {
   FIG_TRY
   *source_len = 0;
   *pixels = 0;
   *width = 0.0;
   *height = 0.0;
   *checksum = 0;
   if (!st.in_frame) return fail(FIG_ERR_STATE, "test_glyph: no frame is open");
   const std::string n(font, font_len > 0 ? static_cast<size_t>(font_len) : 0);
   std::string err;
   ImFont *f = get_font(n, err);
   if (!f) return fail(err.rfind("cannot read", 0) == 0 ? FIG_ERR_FAILED : FIG_ERR_ARGUMENT, "test_glyph: " + err);
   unsigned int c = 0;
   const int used = text_len > 0 ? ImTextCharFromUtf8(&c, text, text + text_len) : 0;
   if (used <= 0 || used != text_len || c == IM_UNICODE_CODEPOINT_INVALID || c > IM_UNICODE_CODEPOINT_MAX)
      return fail(FIG_ERR_ARGUMENT, "test_glyph: not one character (of the Basic Multilingual Plane) in UTF-8");
   ImFontBaked *baked = f->GetFontBaked(ImGui::GetFontSize());
   const ImFontGlyph *g = baked ? baked->FindGlyphNoFallback(static_cast<ImWchar>(c)) : nullptr;
   if (!g) return FIG_OK; // no source has it: the fallback glyph is drawn
   const char *name = g->SourceIdx < static_cast<unsigned>(f->Sources.Size) ? f->Sources[g->SourceIdx]->Name : "";
   const int len = static_cast<int>(std::min(std::strlen(name), static_cast<size_t>(source_cap)));
   std::memcpy(source, name, static_cast<size_t>(len));
   *source_len = len;
   *width = g->AdvanceX;
   *height = g->Y1 - g->Y0;
   if (!g->Visible || g->PackId < 0) return FIG_OK;
   ImFontAtlas *atlas = ImGui::GetIO().Fonts;
   const ImTextureRect *r = ImFontAtlasPackGetRect(atlas, g->PackId);
   ImTextureData *tex = atlas->TexData;
   if (!r || !tex || !tex->Pixels) return FIG_OK;
   // the coverage of each pixel of the glyph's bitmap: counted where not 0, and hashed (FNV-1a, 64 bits)
   unsigned long long hash = 1469598103934665603ULL;
   long long count = 0;
   for (int y = r->y; y < r->y + r->h; ++y)
      for (int x = r->x; x < r->x + r->w; ++x) {
         const unsigned char *px = static_cast<const unsigned char *>(tex->GetPixelsAt(x, y));
         const unsigned char a = tex->Format == ImTextureFormat_Alpha8 ? px[0] : px[3];
         if (a != 0) ++count;
         hash = (hash ^ a) * 1099511628211ULL;
      }
   *pixels = count;
   *checksum = static_cast<long long>(hash);
   return FIG_OK;
   FIG_CATCH
}

// ---- The monotonic clock -------------------------------------------------------------------------------------------

// Seconds since the first call. Linux and the other POSIX systems: clock_gettime(CLOCK_MONOTONIC), never stepped,
// its rate kept to the real time. Not SDL's performance counter there: SDL reads CLOCK_MONOTONIC_RAW, the counter
// without the kernel's rate correction, which on WSL2 runs 7 to 11 % fast (measured: a usleep of 0.200 s lasts
// 0.200 s by CLOCK_MONOTONIC and 0.2145 to 0.2223 s by CLOCK_MONOTONIC_RAW, 2026-11-10). macOS and Windows: SDL's
// counter (mach_absolute_time, QueryPerformanceCounter). Not SDL_GetTicksNS either: SDL_Quit resets its origin, and
// its first call registers a hint callback (not safe from two threads). The origin and the frequency are read once,
// under std::call_once, so any thread may call it, before init* and after destroy.
#if defined(__unix__) && !defined(__APPLE__)
static Uint64 fig_counter(void) {
   struct timespec now;
   clock_gettime(CLOCK_MONOTONIC, &now);
   return static_cast<Uint64>(now.tv_sec) * 1000000000ULL + static_cast<Uint64>(now.tv_nsec);
}
static Uint64 fig_counter_frequency(void) { return 1000000000ULL; }
#else
static Uint64 fig_counter(void) { return SDL_GetPerformanceCounter(); }
static Uint64 fig_counter_frequency(void) { return SDL_GetPerformanceFrequency(); }
#endif

double fig_time(void) {
   static std::once_flag once;
   static Uint64 origin = 0, frequency = 1;
   std::call_once(once, [] {
      frequency = fig_counter_frequency();
      if (frequency == 0) frequency = 1;
      origin = fig_counter();
   });
   const Uint64 ticks = fig_counter() - origin;
   // whole seconds and the remainder apart: a double holds the count exactly only up to 2^53 ticks (104 days in ns)
   return static_cast<double>(ticks / frequency) +
          static_cast<double>(ticks % frequency) / static_cast<double>(frequency);
}

// ---- the application layer's view of the state (figure_app.cpp) ----------------------------------------------------

int fig_mode(void) {
   switch (st.m) {
   case mode::window: return 1;
   case mode::headless: return 2;
   case mode::remote: return 3;
   default: return 0;
   }
}

void *fig_window_handle(void) { return st.window; }

int fig_capture_on(void) { return cap.on ? 1 : 0; }

void fig_layout_text(const char *text, long long len) {
   layout_pending.assign(text, len > 0 ? static_cast<size_t>(len) : 0);
   layout_due = true;
   frames_at_least(3);
}

// ---- Fonts for the other native files (figure_fonts.h) --------------------------------------------------------------

namespace figure_fonts {

bool bytes(const std::string &name, const unsigned char *&data, int &size) {
   struct entry {
      const char *name;
      const unsigned char *data;
      int size;
   };
   static const entry table[] = {
      {"plex-sans", plex_sans_ttf, static_cast<int>(sizeof(plex_sans_ttf))},
      {"plex-sans-bold", plex_sans_bold_ttf, static_cast<int>(sizeof(plex_sans_bold_ttf))},
      {"plex-sans-italic", plex_sans_italic_ttf, static_cast<int>(sizeof(plex_sans_italic_ttf))},
      {"plex-sans-bold-italic", plex_sans_bold_italic_ttf, static_cast<int>(sizeof(plex_sans_bold_italic_ttf))},
      {"plex-mono", plex_mono_ttf, static_cast<int>(sizeof(plex_mono_ttf))},
   };
   for (const entry &e : table)
      if (name == e.name) {
         data = e.data;
         size = e.size;
         return true;
      }
   return false;
}

bool adopt(ImFont *f, const std::string &key, const char *label, std::string &err) {
   if (!f || f->Sources.Size == 0) {
      err = "cannot load the font " + key;
      return false;
   }
   ImFontConfig *src = f->Sources[0];
   // as get_font: a finite advance bound (FLT_MAX overflows to infinity above the reference size), before any glyph
   for (ImFontConfig *s : f->Sources) s->GlyphMaxAdvanceX = 1.0e30f;
   if (label) std::snprintf(src->Name, sizeof(src->Name), "%s", label);
   if (!merge_icons(f, src->SizePixels)) {
      err = "cannot merge the icons into the font " + key;
      return false;
   }
   st.font_em[f] = em_per_size(static_cast<const unsigned char *>(src->FontData));
   if (!merge_fallbacks(f, err)) return false;
   st.fonts[key] = f; // the program's fallbacks added later reach it too (apply_fallbacks)
   return true;
}

} // namespace figure_fonts
