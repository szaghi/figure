// FIGURE's application layer (figure_app.F90's window registry, layouts, preferences, message boxes and size limits;
// figure_imgui.F90's splitter): see figure_native.h, "Application layer".
//
// Everything here runs on the frame loop's thread (the Fortran entry points refuse a task). The state lives from
// fig_init* to fig_shutdown, which saves the preferences first (fig_app_shutdown) and then forgets everything.
//
// Window registry: the windows a program declares with app%add_window, by name (the name given to ig_begin). Each has
// a visibility flag that the View menu toggles and that ig_begin's close button clears (fig_window_open_flag hands
// ig_begin the flag's address: Dear ImGui writes it, so nothing is called back).
//
// Layouts: names the program declares (app%add_layout); one is current. FIGURE does not call the program to build one
// (no callbacks into Fortran): the program builds the current layout (app%layout) when ig_dock_layout_begin returns
// true, and switch_layout/reset_layout make ig_dock_layout_begin return true again for every dock space the program
// laid out (fig_app_layout_rebuild). The user's changes to a layout (Dear ImGui's settings text) are kept by name when
// another is switched to, and given back when it is switched to again; reset_layout forgets them.
//
// Preferences: key/value pairs of text (the Fortran side converts numbers and logicals), with the window registry's
// visibilities, the current layout and each layout's arrangement, the style set by app%set_style and, in window mode,
// the window's position, size and maximized state. app%open_prefs names the file and reads it; it is written when
// changed every 30 seconds of frame time (ImGui::GetTime: the fixed frame time in headless mode, as notifications
// count it) and at fig_shutdown, to <file>.tmp first and then renamed over <file> (SDL_RenamePath replaces it), so a
// crash leaves either the old file or the new one, never half of one. During a capture (FIGURE_CAPTURE) nothing is
// read or written.
//
// Message boxes: modal popups drawn after the program's windows (fig_app_draw, from fig_end_frame), each opened inside
// the one before (Dear ImGui stacks modals that way), so any number are shown at once, the newest on top; each answer is
// kept by id until app%message_box reads it.
#include "figure_native.h"

#include "imgui.h"
#include "imgui_internal.h" // SplitterBehavior, ItemSize, the popup stack, IMGUI_TEST_ENGINE_ITEM_INFO

#include <SDL3/SDL.h>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <map>
#include <memory>
#include <set>
#include <string>
#include <vector>

namespace {

int fail(int status, const std::string &msg) {
   fig_set_last_error(msg.c_str(), static_cast<int>(msg.size()));
   return status;
}

std::string str(const char *p, int n) { return std::string(p, n > 0 ? static_cast<size_t>(n) : 0); }

std::string trim(const std::string &s) {
   const size_t a = s.find_first_not_of(" \t\r"), b = s.find_last_not_of(" \t\r");
   return a == std::string::npos ? std::string() : s.substr(a, b - a + 1);
}

// Newline-separated items (the Fortran side joins a character array that way), each trimmed of trailing blanks; empty
// ones dropped.
std::vector<std::string> split_lines(const std::string &s) {
   std::vector<std::string> out;
   for (size_t a = 0; a <= s.size();) {
      size_t b = s.find('\n', a);
      if (b == std::string::npos) b = s.size();
      std::string t = s.substr(a, b - a);
      t.erase(t.find_last_not_of(' ') + 1);
      if (!t.empty()) out.push_back(t);
      a = b + 1;
   }
   return out;
}

constexpr double SAVE_PERIOD = 30.0; // seconds of frame time between two saves of the preferences (when changed)

// ---- window registry ----------------------------------------------------------------------------------------------

struct window_t {
   std::string name;
   bool        visible = true;  // Dear ImGui writes it through ig_begin's p_open (closable windows)
   bool        closable = true;
   bool        in_menu = true;
   bool        remember = true;
};
std::vector<std::unique_ptr<window_t>> windows; // in the order added (the View menu's); the flags stay put
std::map<std::string, bool>            saved_visible; // read from the preferences, for the windows added after

window_t *find_window(const std::string &name) {
   for (auto &w : windows)
      if (w->name == name) return w.get();
   return nullptr;
}

// The label a menu shows for a window: its name without the ## or ### part.
std::string visible_part(const std::string &name) {
   const size_t k = name.find("##");
   return k == std::string::npos ? name : name.substr(0, k);
}

// ---- layouts ----------------------------------------------------------------------------------------------------

struct layout_t {
   std::string              name;
   bool                     has_windows = false; // the layout says which registered windows it shows
   std::vector<std::string> windows;
};
std::vector<layout_t>              layouts;
int                                current = -1;     // index into layouts; -1: none added
std::string                        wanted;           // the current layout of the preferences, until it is added
std::map<std::string, std::string> arrangements;     // a layout's settings text (Dear ImGui's ini), by layout name
std::set<unsigned int>             dock_roots;       // the dock spaces laid out with ig_dock_layout_begin
std::set<unsigned int>             rebuild;          // ... to lay out again (switch_layout, reset_layout)

std::string current_name() { return current >= 0 ? layouts[static_cast<size_t>(current)].name : std::string(); }

// The windows of a layout that says which it shows: those shown, the other registered ones hidden.
void apply_layout_windows(const layout_t &l) {
   if (!l.has_windows) return;
   for (auto &w : windows) w->visible = std::find(l.windows.begin(), l.windows.end(), w->name) != l.windows.end();
}

// Lay out again every dock space laid out so far: ig_dock_layout_begin returns true for each on its next call.
void rebuild_all() {
   rebuild = dock_roots;
   fig_request_frames(3);
}

// ---- style kept -------------------------------------------------------------------------------------------------

struct style_memo_t {
   std::string name, look, palette, auto_dark, auto_light, lines;
   bool        any() const { return !(name.empty() && look.empty() && palette.empty() && lines.empty()); }
};
style_memo_t style;

// ---- preferences ------------------------------------------------------------------------------------------------

struct geometry_t {
   bool has = false;
   int  x = 0, y = 0, w = 0, h = 0;
   bool maximized = false;
};

bool                               prefs_open = false; // open_prefs was called
std::string                        prefs_name;         // the program's name
std::string                        prefs_path;         // the file ('' : memory only)
std::map<std::string, std::string> prefs;              // key -> value text
geometry_t                         geometry;           // the window's last normal geometry (window mode)
double                             last_save = 0.0;    // ImGui::GetTime of the last save (or check)
std::string                        last_written;       // the text last written (or read): unchanged is not rewritten

// Escapes of a key, a name or a value: backslash, newline, carriage return, tab, and in a key or a name '=' (so that
// the first unescaped '=' of a line separates the key from the value).
std::string escape(const std::string &s, bool eq = true) {
   std::string o;
   for (const char c : s) {
      switch (c) {
      case '\\': o += "\\\\"; break;
      case '\n': o += "\\n"; break;
      case '\r': o += "\\r"; break;
      case '\t': o += "\\t"; break;
      case '=':
         if (eq) o += '\\';
         o += c;
         break;
      default: o += c;
      }
   }
   return o;
}

// A line `key = value` split at its first unescaped '=', both unescaped; the key trimmed, the value without the one
// blank after '='. False for a line without '='.
bool split_entry(const std::string &line, std::string &key, std::string &value) {
   std::string *out = &key;
   key.clear();
   value.clear();
   bool seen = false;
   for (size_t i = 0; i < line.size(); ++i) {
      const char c = line[i];
      if (c == '\\' && i + 1 < line.size()) {
         const char e = line[++i];
         *out += e == 'n' ? '\n' : e == 'r' ? '\r' : e == 't' ? '\t' : e;
      } else if (c == '=' && !seen) {
         seen = true;
         out = &value;
         if (i + 1 < line.size() && line[i + 1] == ' ') ++i;
      } else {
         *out += c;
      }
   }
   key = trim(key);
   return seen;
}

std::string default_path(const std::string &name) {
   char *pref = SDL_GetPrefPath("", name.c_str()); // the folder is created if missing
   if (!pref) return "";
   std::string p = std::string(pref) + "preferences.ini";
   SDL_free(pref);
   return p;
}

// The window's normal geometry, remembered while it is neither maximized nor minimized (a maximized window's size is
// the screen's: the one to restore is the one before).
void track_geometry() {
   if (fig_mode() != 1) return;
   SDL_Window *win = static_cast<SDL_Window *>(fig_window_handle());
   if (!win) return;
   const SDL_WindowFlags f = SDL_GetWindowFlags(win);
   geometry.maximized = (f & SDL_WINDOW_MAXIMIZED) != 0;
   if (f & (SDL_WINDOW_MAXIMIZED | SDL_WINDOW_MINIMIZED | SDL_WINDOW_FULLSCREEN)) return;
   int x = 0, y = 0, w = 0, h = 0;
   if (!SDL_GetWindowPosition(win, &x, &y) || !SDL_GetWindowSize(win, &w, &h) || w <= 0 || h <= 0) return;
   geometry = geometry_t{true, x, y, w, h, false};
}

// The preferences file's text.
std::string prefs_text() {
   std::string t = "# Preferences of " + prefs_name +
                   ", kept by FIGURE: written while the program runs and when it ends; edit them with the program\n"
                   "# closed. Lines: key = value, with the escapes \\n \\t \\\\ (and \\= in a key). The [arrangement ...] lines\n"
                   "# are Dear ImGui's settings, after '|'.\n[figure]\n";
   if (!style.name.empty()) t += "style = " + escape(style.name, false) + "\n";
   if (!style.look.empty()) t += "look = " + escape(style.look, false) + "\n";
   if (!style.palette.empty()) t += "palette = " + escape(style.palette, false) + "\n";
   if (!style.auto_dark.empty()) t += "auto_dark = " + escape(style.auto_dark, false) + "\n";
   if (!style.auto_light.empty()) t += "auto_light = " + escape(style.auto_light, false) + "\n";
   if (!style.lines.empty()) t += "lines = " + escape(style.lines, false) + "\n";
   track_geometry();
   if (geometry.has) {
      t += "window = " + std::to_string(geometry.x) + " " + std::to_string(geometry.y) + " " +
           std::to_string(geometry.w) + " " + std::to_string(geometry.h) + "\n";
      t += std::string("maximized = ") + (geometry.maximized ? "true" : "false") + "\n";
   }
   if (current >= 0) t += "layout = " + escape(current_name(), false) + "\n";
   std::map<std::string, bool> vis = saved_visible; // the windows of earlier runs not added in this one are kept
   for (const auto &w : windows)
      if (w->remember) vis[w->name] = w->visible;
      else vis.erase(w->name);
   if (!vis.empty()) {
      t += "\n[windows]\n";
      for (const auto &v : vis) t += escape(v.first) + " = " + (v.second ? "shown" : "hidden") + "\n";
   }
   if (!prefs.empty()) {
      t += "\n[preferences]\n";
      for (const auto &p : prefs) t += escape(p.first) + " = " + escape(p.second, false) + "\n";
   }
   // the arrangements: the live one under the current layout's name (none while a layout is to be laid out again:
   // the live one is the layout being left), the others as kept
   std::map<std::string, std::string> arr = arrangements;
   if (ImGui::GetCurrentContext() && rebuild.empty()) {
      size_t      n = 0;
      const char *ini = ImGui::SaveIniSettingsToMemory(&n);
      if (ini && n > 0) arr[current_name()] = std::string(ini, n);
   }
   for (const auto &a : arr) {
      if (a.second.empty()) continue;
      t += "\n[arrangement" + (a.first.empty() ? std::string() : " " + escape(a.first)) + "]\n";
      for (size_t s = 0; s < a.second.size();) {
         size_t e = a.second.find('\n', s);
         if (e == std::string::npos) e = a.second.size();
         const std::string line = a.second.substr(s, e - s);
         if (!trim(line).empty()) t += "|" + line + "\n";
         s = e + 1;
      }
   }
   return t;
}

// Write the text to <path>.tmp, then rename it over <path>: a crash leaves the old file or the new one.
bool write_atomic(const std::string &path, const std::string &text, std::string &err) {
   const std::string tmp = path + ".tmp";
   if (!SDL_SaveFile(tmp.c_str(), text.data(), text.size())) {
      err = "cannot write " + tmp + ": " + SDL_GetError();
      return false;
   }
   if (!SDL_RenamePath(tmp.c_str(), path.c_str())) {
      err = "cannot rename " + tmp + " to " + path + ": " + SDL_GetError();
      SDL_RemovePath(tmp.c_str());
      return false;
   }
   return true;
}

// Save when the text changed since the last write; a failure is printed once per run (the program cannot act on it
// between frames), not fatal.
void save_prefs() {
   if (!prefs_open || prefs_path.empty() || fig_capture_on()) return;
   const std::string t = prefs_text();
   if (t == last_written) return;
   std::string err;
   static bool warned = false;
   if (write_atomic(prefs_path, t, err)) {
      last_written = t;
   } else if (!warned) {
      warned = true;
      SDL_Log("FIGURE: preferences not saved: %s", err.c_str());
   }
}

// Read the file: false when it does not exist (nothing read).
bool read_prefs(const std::string &path) {
   size_t n = 0;
   void  *data = SDL_LoadFile(path.c_str(), &n);
   if (!data) return false;
   const std::string text(static_cast<const char *>(data), n);
   SDL_free(data);
   last_written = text;
   std::string section, key, value;
   style = style_memo_t{};
   for (size_t s = 0; s < text.size();) {
      size_t e = text.find('\n', s);
      if (e == std::string::npos) e = text.size();
      std::string line = text.substr(s, e - s);
      s = e + 1;
      if (!line.empty() && line.back() == '\r') line.pop_back();
      if (section.rfind("arrangement", 0) == 0 && !line.empty() && line[0] == '|') {
         std::string name;
         if (section.size() > 12) split_entry(section.substr(12) + "=", name, value); // unescaped
         arrangements[name] += line.substr(1) + "\n";
         continue;
      }
      const std::string t = trim(line);
      if (t.empty() || t[0] == '#' || t[0] == ';') continue;
      if (t[0] == '[' && t.back() == ']') {
         section = t.substr(1, t.size() - 2);
         continue;
      }
      if (!split_entry(line, key, value)) continue;
      if (section == "figure") {
         if (key == "style") style.name = value;
         else if (key == "look") style.look = value;
         else if (key == "palette") style.palette = value;
         else if (key == "auto_dark") style.auto_dark = value;
         else if (key == "auto_light") style.auto_light = value;
         else if (key == "lines") style.lines = value;
         else if (key == "layout") wanted = value;
         else if (key == "maximized") geometry.maximized = trim(value) == "true";
         else if (key == "window") {
            int x, y, w, h;
            if (std::sscanf(value.c_str(), "%d %d %d %d", &x, &y, &w, &h) == 4 && w > 0 && h > 0)
               geometry = geometry_t{true, x, y, w, h, geometry.maximized};
         }
      } else if (section == "windows") {
         const std::string v = trim(value);
         if (v == "shown" || v == "hidden") saved_visible[key] = v == "shown";
      } else if (section == "preferences") {
         prefs[key] = value;
      }
   }
   return true;
}

// The window's place and size of the last run, in window mode: the size always, the position when it is on a display
// now (a monitor unplugged since), then maximized.
void restore_geometry() {
   if (fig_mode() != 1 || !geometry.has) return;
   SDL_Window *win = static_cast<SDL_Window *>(fig_window_handle());
   if (!win) return;
   SDL_SetWindowSize(win, geometry.w, geometry.h);
   int   count = 0;
   bool  on_display = false;
   SDL_DisplayID *ids = SDL_GetDisplays(&count);
   for (int i = 0; ids && i < count && !on_display; ++i) {
      SDL_Rect r;
      if (SDL_GetDisplayBounds(ids[i], &r))
         on_display = geometry.x >= r.x && geometry.y >= r.y && geometry.x < r.x + r.w && geometry.y < r.y + r.h;
   }
   SDL_free(ids);
   if (on_display) SDL_SetWindowPosition(win, geometry.x, geometry.y);
   if (geometry.maximized) SDL_MaximizeWindow(win);
}

// A key of the preferences: not empty, no newline, no blank at either end.
bool key_ok(const std::string &k) {
   return !k.empty() && k.find_first_of("\n\r") == std::string::npos && k.front() != ' ' && k.back() != ' ' &&
          k.front() != '[' && k.front() != '#' && k.front() != ';';
}

// ---- message boxes ----------------------------------------------------------------------------------------------

struct box_t {
   std::string              id, title, text;
   std::vector<std::string> buttons;
   int                      chosen = 0; // answered this frame: removed after drawing
};
std::vector<box_t>         boxes;   // open, oldest first (the newest is drawn on top)
std::map<std::string, int> answers; // id -> the button chosen, until read

std::string box_name(const box_t &b) { return b.title + "###figure message box " + b.id; }

// Box i, a modal, then the boxes after it inside it (each modal opened from the one before stacks on it).
void draw_box(size_t i) {
   if (i >= boxes.size()) return;
   box_t            &b = boxes[i];
   const std::string name = box_name(b);
   if (!ImGui::IsPopupOpen(name.c_str())) {
      ImGui::OpenPopup(name.c_str());
      fig_request_frames(3); // a box sizes itself over its first frames: drawn even when the loop would wait
   }
   const ImGuiViewport *vp = ImGui::GetMainViewport();
   const float          step = 2.0f * ImGui::GetFontSize() * static_cast<float>(i); // each box below and right of the last
   ImGui::SetNextWindowPos(ImVec2(vp->WorkPos.x + 0.5f * vp->WorkSize.x + step,
                                  vp->WorkPos.y + 0.5f * vp->WorkSize.y + step),
                           ImGuiCond_Appearing, ImVec2(0.5f, 0.5f));
   if (!ImGui::BeginPopupModal(name.c_str(), nullptr,
                               ImGuiWindowFlags_AlwaysAutoResize | ImGuiWindowFlags_NoSavedSettings |
                                  ImGuiWindowFlags_NoCollapse))
      return;
   const float fs = ImGui::GetFontSize();
   ImGui::PushTextWrapPos(ImGui::GetCursorPosX() + 28.0f * fs);
   ImGui::TextUnformatted(b.text.c_str());
   ImGui::PopTextWrapPos();
   ImGui::Spacing();
   for (size_t k = 0; k < b.buttons.size(); ++k) {
      if (k > 0) ImGui::SameLine();
      const float w = ImGui::CalcTextSize(b.buttons[k].c_str(), nullptr, true).x + 2.0f * ImGui::GetStyle().FramePadding.x;
      if (ImGui::Button(b.buttons[k].c_str(), ImVec2(std::max(5.0f * fs, w), 0.0f))) // at least 5 em wide
         b.chosen = static_cast<int>(k) + 1;
   }
   // the top box takes Enter (its first button) and Escape (its last), unless a field of it is being edited; not on
   // the frame it appears, whose key (the Escape that closed a popup, the Enter that asked) was meant for something else
   if (i + 1 == boxes.size() && b.chosen == 0 && !ImGui::IsAnyItemActive() && !ImGui::IsWindowAppearing() &&
       ImGui::IsWindowFocused(ImGuiFocusedFlags_RootAndChildWindows)) {
      if (ImGui::IsKeyPressed(ImGuiKey_Enter, false) || ImGui::IsKeyPressed(ImGuiKey_KeypadEnter, false)) b.chosen = 1;
      else if (ImGui::IsKeyPressed(ImGuiKey_Escape, false)) b.chosen = static_cast<int>(b.buttons.size());
   }
   draw_box(i + 1);
   if (b.chosen != 0) ImGui::CloseCurrentPopup();
   ImGui::EndPopup();
}

void draw_boxes() {
   if (boxes.empty()) return;
   // a popup of the program's (a menu, its own modal, FIGURE's file browser) is open at the root: Dear ImGui keeps one
   // popup per level, so opening the boxes now would close it; they wait for it to close
   const ImGuiContext &g = *ImGui::GetCurrentContext();
   if (!g.OpenPopupStack.empty() && g.OpenPopupStack[0].PopupId != ImGui::GetID(box_name(boxes[0]).c_str())) return;
   draw_box(0);
   bool any = false;
   for (auto it = boxes.begin(); it != boxes.end();) {
      if (it->chosen != 0) {
         answers[it->id] = it->chosen;
         it = boxes.erase(it);
         any = true;
      } else {
         ++it;
      }
   }
   if (any) fig_request_frames(3); // the answer is read on the next frame, the box below takes the focus
}

bool initialized() { return fig_mode() != 0; }

} // namespace

// ---- entry points ---------------------------------------------------------------------------------------------------

extern "C" {

int fig_window_add(const char *name, int name_len, int visible, int closable, int in_view_menu, int remember) {
   try {
      if (!initialized()) return fail(FIG_ERR_STATE, "app%add_window: figure is not initialized");
      const std::string n = str(name, name_len);
      if (n.empty()) return fail(FIG_ERR_ARGUMENT, "app%add_window: the name is empty");
      if (find_window(n)) return fail(FIG_ERR_ARGUMENT, "app%add_window: '" + n + "' is added already");
      auto w = std::make_unique<window_t>();
      w->name = n;
      w->visible = visible != 0;
      w->closable = closable != 0;
      w->in_menu = in_view_menu != 0;
      w->remember = remember != 0;
      const auto s = saved_visible.find(n);
      if (w->remember && s != saved_visible.end()) w->visible = s->second; // as the user left it
      windows.push_back(std::move(w));
      return FIG_OK;
   } catch (...) {
      return fail(FIG_ERR_EXCEPTION, "app%add_window: C++ exception");
   }
}

int fig_window_visible(const char *name, int name_len, int *visible) {
   *visible = 0;
   const window_t *w = find_window(str(name, name_len));
   if (!w) return fail(FIG_ERR_ARGUMENT, "app%window_visible: no window '" + str(name, name_len) + "' was added");
   *visible = w->visible ? 1 : 0;
   return FIG_OK;
}

int fig_window_set_visible(const char *name, int name_len, int visible) {
   window_t *w = find_window(str(name, name_len));
   if (!w) return fail(FIG_ERR_ARGUMENT, "app%set_window_visible: no window '" + str(name, name_len) + "' was added");
   w->visible = visible != 0;
   fig_request_frames(3);
   return FIG_OK;
}

void *fig_window_open_flag(const char *name, int name_len) {
   if (windows.empty()) return nullptr; // the common case: no registry, no lookup
   window_t *w = find_window(str(name, name_len));
   return w && w->closable ? &w->visible : nullptr;
}

int fig_view_menu(const char *label, int label_len) {
   try {
      const std::string l = label_len > 0 ? str(label, label_len) : std::string("View");
      if (!ImGui::BeginMenu(l.c_str())) return FIG_OK;
      bool any = false;
      for (auto &w : windows) {
         if (!w->in_menu) continue;
         if (ImGui::MenuItem(visible_part(w->name).c_str(), nullptr, &w->visible)) fig_request_frames(3);
         any = true;
      }
      if (!layouts.empty()) {
         if (any) ImGui::Separator();
         for (size_t i = 0; i < layouts.size(); ++i)
            if (ImGui::MenuItem(layouts[i].name.c_str(), nullptr, static_cast<int>(i) == current))
               fig_layout_switch(layouts[i].name.c_str(), static_cast<int>(layouts[i].name.size()));
         any = true;
      }
      if (!layouts.empty() || !dock_roots.empty()) {
         if (any) ImGui::Separator();
         if (ImGui::MenuItem("Reset layout")) fig_layout_reset();
      }
      ImGui::EndMenu();
      return FIG_OK;
   } catch (...) {
      return fail(FIG_ERR_EXCEPTION, "app%view_menu: C++ exception");
   }
}

int fig_layout_add(const char *name, int name_len, const char *names, int names_len, int has_windows) {
   try {
      if (!initialized()) return fail(FIG_ERR_STATE, "app%add_layout: figure is not initialized");
      const std::string n = str(name, name_len);
      if (n.empty()) return fail(FIG_ERR_ARGUMENT, "app%add_layout: the name is empty");
      for (const auto &l : layouts)
         if (l.name == n) return fail(FIG_ERR_ARGUMENT, "app%add_layout: '" + n + "' is added already");
      layout_t l;
      l.name = n;
      l.has_windows = has_windows != 0;
      if (l.has_windows) l.windows = split_lines(str(names, names_len));
      layouts.push_back(l);
      if (current < 0 || n == wanted) current = static_cast<int>(layouts.size()) - 1; // the first, or the user's
      return FIG_OK;
   } catch (...) {
      return fail(FIG_ERR_EXCEPTION, "app%add_layout: C++ exception");
   }
}

int fig_layout_switch(const char *name, int name_len) {
   try {
      const std::string n = str(name, name_len);
      int               k = -1;
      for (size_t i = 0; i < layouts.size(); ++i)
         if (layouts[i].name == n) k = static_cast<int>(i);
      if (k < 0) return fail(FIG_ERR_ARGUMENT, "app%switch_layout: no layout '" + n + "' was added");
      if (k == current) return FIG_OK;
      if (ImGui::GetCurrentContext() && rebuild.empty()) { // the user's arrangement of the layout left, kept
         size_t      len = 0;
         const char *ini = ImGui::SaveIniSettingsToMemory(&len);
         arrangements[current_name()] = ini ? std::string(ini, len) : std::string();
      }
      current = k;
      wanted.clear();
      apply_layout_windows(layouts[static_cast<size_t>(k)]);
      const auto a = arrangements.find(n);
      if (a != arrangements.end() && !a->second.empty()) {
         rebuild.clear();
         fig_layout_text(a->second.data(), static_cast<long long>(a->second.size())); // before the next frame
      } else {
         rebuild_all();
      }
      return FIG_OK;
   } catch (...) {
      return fail(FIG_ERR_EXCEPTION, "app%switch_layout: C++ exception");
   }
}

int fig_layout_reset(void) {
   arrangements.erase(current_name());
   if (current >= 0) apply_layout_windows(layouts[static_cast<size_t>(current)]);
   rebuild_all();
   return FIG_OK;
}

int fig_layout_current(char *buf, int buf_len) {
   const std::string n = current_name();
   if (buf_len > 0) std::memcpy(buf, n.data(), std::min(n.size(), static_cast<size_t>(buf_len)));
   return static_cast<int>(n.size());
}

int fig_prefs_open(const char *name, int name_len, const char *file, int file_len) {
   try {
      if (!initialized()) return fail(FIG_ERR_STATE, "app%open_prefs: figure is not initialized");
      if (prefs_open) return fail(FIG_ERR_STATE, "app%open_prefs: the preferences are open already (" +
                                                    (prefs_path.empty() ? std::string("in memory") : prefs_path) + ")");
      const std::string n = str(name, name_len);
      if (n.empty() || n[0] == '.' ||
          n.find_first_not_of("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 ._-") != std::string::npos)
         return fail(FIG_ERR_ARGUMENT, "app%open_prefs: the name '" + n +
                                          "' is a folder's name: letters, digits, blanks and . _ - (not first a .)");
      prefs_name = n;
      if (file_len > 0) prefs_path = str(file, file_len);
      else if (fig_mode() != 2) prefs_path = default_path(n); // headless: memory only, unless a file is named
      if (fig_capture_on()) prefs_path.clear(); // a recording reads nothing of the user's
      prefs_open = true;
      std::map<std::string, std::string> kept = prefs; // the run's own, set before the file was opened, win
      if (!prefs_path.empty() && read_prefs(prefs_path)) {
         for (const auto &k : kept) prefs[k.first] = k.second;
         if (style.any()) { // a style FIGURE no longer knows is skipped
            const style_memo_t s = style;
            if (fig_set_style_parts(s.name.data(), static_cast<int>(s.name.size()), s.look.data(),
                                    static_cast<int>(s.look.size()), s.palette.data(),
                                    static_cast<int>(s.palette.size()), s.auto_dark.data(),
                                    static_cast<int>(s.auto_dark.size()), s.auto_light.data(),
                                    static_cast<int>(s.auto_light.size()), s.lines.data(),
                                    static_cast<int>(s.lines.size())) != FIG_OK)
               style = style_memo_t{};
            else
               style = s;
         }
         restore_geometry();
         for (auto &w : windows) {
            const auto s = saved_visible.find(w->name);
            if (w->remember && s != saved_visible.end()) w->visible = s->second;
         }
         for (size_t i = 0; i < layouts.size(); ++i)
            if (layouts[i].name == wanted) current = static_cast<int>(i);
         const auto a = arrangements.find(wanted.empty() ? current_name() : wanted);
         if (a != arrangements.end() && !a->second.empty()) {
            fig_layout_text(a->second.data(), static_cast<long long>(a->second.size()));
            arrangements.erase(a); // live from now on
         }
      }
      last_save = ImGui::GetCurrentContext() ? ImGui::GetTime() : 0.0;
      return FIG_OK;
   } catch (...) {
      return fail(FIG_ERR_EXCEPTION, "app%open_prefs: C++ exception");
   }
}

int fig_prefs_file(char *buf, int buf_len) {
   if (buf_len > 0) std::memcpy(buf, prefs_path.data(), std::min(prefs_path.size(), static_cast<size_t>(buf_len)));
   return static_cast<int>(prefs_path.size());
}

int fig_pref_set(const char *key, int key_len, const char *value, int value_len) {
   try {
      if (!initialized()) return fail(FIG_ERR_STATE, "app%save_pref: figure is not initialized");
      const std::string k = str(key, key_len);
      if (!key_ok(k))
         return fail(FIG_ERR_ARGUMENT, "app%save_pref: the key '" + k +
                                          "' is empty, has a newline, a blank at an end, or starts with [ # ;");
      prefs[k] = str(value, value_len);
      return FIG_OK;
   } catch (...) {
      return fail(FIG_ERR_EXCEPTION, "app%save_pref: C++ exception");
   }
}

int fig_pref_get(const char *key, int key_len, char *buf, int buf_len, int *len, int *found) {
   *len = 0;
   *found = 0;
   if (!initialized()) return fail(FIG_ERR_STATE, "app%load_pref: figure is not initialized");
   const std::string k = str(key, key_len);
   if (!key_ok(k))
      return fail(FIG_ERR_ARGUMENT, "app%load_pref: the key '" + k +
                                       "' is empty, has a newline, a blank at an end, or starts with [ # ;");
   const auto p = prefs.find(k);
   if (p == prefs.end()) return FIG_OK;
   *found = 1;
   *len = static_cast<int>(p->second.size());
   if (buf_len > 0) std::memcpy(buf, p->second.data(), std::min(p->second.size(), static_cast<size_t>(buf_len)));
   return FIG_OK;
}

int fig_message_box(const char *id, int id_len, const char *title, int title_len, const char *text, int text_len,
                    const char *buttons, int buttons_len, int *answer) {
   try {
      *answer = 0;
      if (!initialized()) return fail(FIG_ERR_STATE, "app%message_box: figure is not initialized");
      const std::string i = str(id, id_len);
      if (i.empty()) return fail(FIG_ERR_ARGUMENT, "app%message_box: the id is empty");
      const auto a = answers.find(i);
      if (a != answers.end()) {
         *answer = a->second;
         answers.erase(a);
         return FIG_OK;
      }
      std::vector<std::string> b = split_lines(str(buttons, buttons_len));
      if (buttons_len < 0) b = {"OK"};
      if (b.empty()) return fail(FIG_ERR_ARGUMENT, "app%message_box: every button label is empty");
      for (auto &x : boxes)
         if (x.id == i) { // open: the texts may change (a count shown, say)
            x.title = str(title, title_len);
            x.text = str(text, text_len);
            x.buttons = b;
            return FIG_OK;
         }
      box_t box;
      box.id = i;
      box.title = str(title, title_len);
      box.text = str(text, text_len);
      box.buttons = b;
      boxes.push_back(box);
      fig_request_frames(3);
      return FIG_OK;
   } catch (...) {
      return fail(FIG_ERR_EXCEPTION, "app%message_box: C++ exception");
   }
}

int fig_splitter(const char *id, int id_len, int vertical, double *sizes, double min_size, int *changed) {
   try {
      *changed = 0;
      ImGuiContext &g = *ImGui::GetCurrentContext();
      ImGuiWindow  *w = ImGui::GetCurrentWindow();
      if (w->SkipItems) return FIG_OK;
      const std::string label = str(id, id_len);
      const ImGuiID     iid = w->GetID(label.c_str());
      const ImGuiStyle &s = ImGui::GetStyle();
      const ImVec2      p = ImGui::GetCursorScreenPos(), avail = ImGui::GetContentRegionAvail();
      const float       t = std::max(2.0f, vertical ? s.ItemSpacing.y : s.ItemSpacing.x); // the bar's thickness
      const ImRect      bb(p, vertical ? ImVec2(p.x + avail.x, p.y + t) : ImVec2(p.x + t, p.y + std::max(avail.y, t)));
      ImGui::ItemSize(bb.GetSize(), 0.0f);
      float       a = static_cast<float>(sizes[0]), b = static_cast<float>(sizes[1]);
      const float m = min_size >= 0.0 ? static_cast<float>(min_size) : ImGui::GetFrameHeight();
      ImGui::SplitterBehavior(bb, iid, vertical ? ImGuiAxis_Y : ImGuiAxis_X, &a, &b, m, m, 4.0f, 0.04f);
      IMGUI_TEST_ENGINE_ITEM_INFO(iid, label.c_str(), g.LastItemData.StatusFlags);
      if (a != static_cast<float>(sizes[0]) || b != static_cast<float>(sizes[1])) {
         sizes[0] = a;
         sizes[1] = b;
         *changed = 1;
      }
      return FIG_OK;
   } catch (...) {
      return fail(FIG_ERR_EXCEPTION, "ig_splitter: C++ exception");
   }
}

int fig_set_size_limits(int min_w, int min_h, int max_w, int max_h) {
   if (!initialized()) return fail(FIG_ERR_STATE, "app%set_size_limits: figure is not initialized");
   if (min_w < 0 || min_h < 0 || max_w < 0 || max_h < 0)
      return fail(FIG_ERR_ARGUMENT, "app%set_size_limits: a negative size");
   if ((max_w > 0 && max_w < min_w) || (max_h > 0 && max_h < min_h))
      return fail(FIG_ERR_ARGUMENT, "app%set_size_limits: a maximum below its minimum");
   if (fig_mode() != 1) return FIG_OK; // headless and remote: no window to limit
   SDL_Window *win = static_cast<SDL_Window *>(fig_window_handle());
   if (!SDL_SetWindowMinimumSize(win, min_w, min_h) || !SDL_SetWindowMaximumSize(win, max_w, max_h))
      return fail(FIG_ERR_FAILED, std::string("app%set_size_limits: ") + SDL_GetError());
   return FIG_OK;
}

// ---- hooks of figure_native.cpp ---------------------------------------------------------------------------------------

void fig_app_frame_begin(void) {
   if (!prefs_open) return;
   track_geometry();
   const double now = ImGui::GetTime();
   if (now - last_save < SAVE_PERIOD) return;
   last_save = now;
   save_prefs();
}

void fig_app_draw(void) {
   try {
      draw_boxes();
   } catch (...) {
   }
}

int fig_app_layout_rebuild(unsigned int id) {
   dock_roots.insert(id);
   return rebuild.erase(id) > 0 ? 1 : 0;
}

void fig_app_style_parts(const char *name, int name_len, const char *look, int look_len, const char *palette,
                         int palette_len, const char *auto_dark, int auto_dark_len, const char *auto_light,
                         int auto_light_len, const char *lines, int lines_len) {
   if (name_len > 0) style = style_memo_t{str(name, name_len), "", "", "", "", ""}; // a name sets every part
   if (look_len > 0) style.look = str(look, look_len);
   if (palette_len > 0) style.palette = str(palette, palette_len);
   if (auto_dark_len > 0) style.auto_dark = str(auto_dark, auto_dark_len);
   if (auto_light_len > 0) style.auto_light = str(auto_light, auto_light_len);
   if (lines_len > 0) style.lines = str(lines, lines_len);
}

void fig_app_style_forget(void) { style = style_memo_t{}; }

void fig_app_shutdown(void) {
   try {
      save_prefs();
   } catch (...) {
   }
   windows.clear();
   saved_visible.clear();
   layouts.clear();
   current = -1;
   wanted.clear();
   arrangements.clear();
   dock_roots.clear();
   rebuild.clear();
   style = style_memo_t{};
   prefs_open = false;
   prefs_name.clear();
   prefs_path.clear();
   prefs.clear();
   geometry = geometry_t{};
   last_save = 0.0;
   last_written.clear();
   boxes.clear();
   answers.clear();
}

} // extern "C"
