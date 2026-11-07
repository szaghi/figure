// FIGURE's file browser (app%open_file_browser, app%save_file_browser): see figure_native.h, "File browser".
//
// A browser is a modal drawn by FIGURE in Dear ImGui at the end of each frame (fig_end_frame, before the
// notifications), so it works the same in window, remote and headless modes: in remote mode it lists the files of the
// machine the program runs on. It is answered through fig_file_dialog_result, as the system's dialogs are: the answer
// is kept here by id until read. Everything runs on the main thread (the entry points are refused from tasks).
//
// The folder is read with std::filesystem when entered and when Refresh is pressed; a failure (permissions, a folder
// that vanished) is shown in the browser, never fatal. Names travel as UTF-8 everywhere: std::filesystem's paths are
// converted with u8string/u8path, the size and the modification time come from stat (_wstat64 on Windows), the home
// folder and the settings folder from SDL (UTF-8 on every platform). The recent folders are kept in FIGURE's settings
// file, settings.ini in SDL_GetPrefPath("", "figure"), in window and remote modes; in headless mode and during a
// capture (FIGURE_CAPTURE) they are kept in memory only, unless a test names a file (fig_file_browser_settings).
#include "figure_native.h"

#include "imgui.h"
#include "imgui_internal.h" // ClearActiveID: a path field edited from code shows the new text

#include <SDL3/SDL.h>

#include <sys/stat.h>
#include <sys/types.h>
#if defined(_WIN32)
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#endif

#include <algorithm>
#include <cstdio>
#include <cstring>
#include <ctime>
#include <filesystem>
#include <map>
#include <memory>
#include <string>
#include <system_error>
#include <vector>

namespace {

namespace fs = std::filesystem;

int fail(int status, const std::string &msg) {
   fig_set_last_error(msg.c_str(), static_cast<int>(msg.size()));
   return status;
}

// UTF-8 <-> std::filesystem::path, the same on every platform (on Windows path::string() is the ANSI code page).
std::string u8(const fs::path &p) {
   const auto s = p.u8string();
   return std::string(s.begin(), s.end());
}

fs::path from_u8(const std::string &s) {
#if defined(__cpp_char8_t)
   return fs::path(std::u8string(s.begin(), s.end()));
#else
   return fs::u8path(s);
#endif
}

// Lucide glyphs of the bundled icon font (src/lib/figure_icons.F90 names them ICON_*), as UTF-8.
constexpr const char *I_FOLDER = "\xee\x83\x97";         // ICON_FOLDER, U+E0D7
constexpr const char *I_FILE = "\xee\x83\x80";           // ICON_FILE, U+E0C0
constexpr const char *I_UP = "\xee\x81\x8a";             // ICON_ARROW_UP, U+E04A
constexpr const char *I_REFRESH = "\xee\x85\x85";        // ICON_REFRESH_CW, U+E145
constexpr const char *I_NEW_FOLDER = "\xee\x83\x99";     // ICON_FOLDER_PLUS, U+E0D9
constexpr const char *I_HOME = "\xee\x83\xb5";           // ICON_HOUSE, U+E0F5
constexpr const char *I_WORKING = "\xee\x86\x81";        // ICON_TERMINAL, U+E181
constexpr const char *I_DRIVE = "\xee\x83\xad";          // ICON_HARD_DRIVE, U+E0ED
constexpr const char *I_RECENT = "\xee\x82\x87";         // ICON_CLOCK, U+E087
constexpr const char *I_ALERT = "\xee\x86\x93";          // ICON_TRIANGLE_ALERT, U+E193

constexpr size_t RECENT_KEEP = 8; // recent folders kept

struct entry_t {
   std::string        name;          // UTF-8
   bool               folder = false;
   bool               hidden = false; // a dot name, or (Windows) the hidden attribute
   bool               info = false;   // size and time read
   unsigned long long size = 0;       // [bytes]
   long long          mtime = 0;      // [s since the epoch]
   std::string        size_text, date_text;
};

struct browser_t {
   std::string                           id;
   int                                   kind = 0; // 0 open a file, 1 save a file, 2 choose a folder
   std::vector<std::string>              filter_names;
   std::vector<std::vector<std::string>> filter_exts; // lower case; "*" any
   int                                   filter = 0;
   fs::path                              folder;      // absolute, normal
   std::vector<entry_t>                  all;         // the folder's entries
   std::vector<int>                      shown;       // indices into all: filtered, sorted
   std::string                           error;       // shown under the path field ('' none)
   bool                                  hidden = false;
   int                                   sort_column = 0; // 0 name, 1 size, 2 modified
   bool                                  descending = false;
   int                                   selected = -1;   // index into all
   std::string                           path_text, name_text, new_text; // the fields
   bool                                  new_folder = false; // the new folder row is shown
   bool                                  asking = false;     // a save over an existing file asks first
   std::string                           asking_path;
   bool                                  done = false;       // answered: closed at the end of this frame
};

std::vector<std::unique_ptr<browser_t>>              browsers; // open, the first is drawn
std::map<std::string, std::pair<int, std::string>>   answers;  // id -> (1 chosen, 2 cancelled; path)
std::map<std::string, ImVec4>                        parts;    // the front browser's parts in the last frame
std::vector<std::string>                             recent;   // recent folders, newest first (UTF-8)
bool        initialized = false;
bool        persist = false;             // the settings file of SDL's pref path (window, remote; not capture)
bool        settings_override = false;   // a test named the file
std::string settings_named;              // ... this one ('' none: memory only)

// ---- settings file ----------------------------------------------------------------------------------------------

std::string settings_path() {
   if (settings_override) return settings_named;
   if (!persist) return "";
   char *pref = SDL_GetPrefPath("", "figure"); // created if missing
   if (!pref) return "";
   std::string p = std::string(pref) + "settings.ini";
   SDL_free(pref);
   return p;
}

std::string trim(const std::string &s) {
   const size_t a = s.find_first_not_of(" \t\r"), b = s.find_last_not_of(" \t\r");
   return a == std::string::npos ? std::string() : s.substr(a, b - a + 1);
}

// The file's lines; the recent folders of its [file browser] section into `found`, the other sections into `others`.
void settings_read(const std::string &path, std::vector<std::string> *found, std::vector<std::string> *others) {
   size_t n = 0;
   void  *data = SDL_LoadFile(path.c_str(), &n);
   if (!data) return;
   const std::string text(static_cast<const char *>(data), n);
   SDL_free(data);
   bool ours = false;
   for (size_t start = 0; start < text.size();) {
      size_t end = text.find('\n', start);
      if (end == std::string::npos) end = text.size();
      const std::string line = text.substr(start, end - start), t = trim(line);
      start = end + 1;
      if (!t.empty() && t[0] == '[') ours = t == "[file browser]";
      if (ours) {
         const size_t eq = t.find('=');
         if (found && eq != std::string::npos && trim(t.substr(0, eq)) == "recent") {
            const std::string v = trim(t.substr(eq + 1));
            if (!v.empty()) found->push_back(v);
         }
      } else if (others && !(t.size() > 0 && t[0] == '#' && others->empty())) {
         others->push_back(line);
      }
   }
}

void recent_load() {
   const std::string path = settings_path();
   if (path.empty()) return; // memory only: the list of this run
   std::vector<std::string> found;
   settings_read(path, &found, nullptr);
   recent = found;
   if (recent.size() > RECENT_KEEP) recent.resize(RECENT_KEEP);
}

// The folder becomes the most recent; the file is rewritten (its other sections kept). A failure is ignored: the
// recent folders are a convenience.
void recent_add(const fs::path &folder) {
   const std::string f = u8(folder);
   recent_load();
   recent.erase(std::remove(recent.begin(), recent.end(), f), recent.end());
   recent.insert(recent.begin(), f);
   if (recent.size() > RECENT_KEEP) recent.resize(RECENT_KEEP);
   const std::string path = settings_path();
   if (path.empty()) return;
   std::vector<std::string> others;
   settings_read(path, nullptr, &others);
   std::string text = "# FIGURE's settings, kept by the programs built with FIGURE (written by FIGURE: edits are kept\n"
                      "# outside its sections).\n[file browser]\n";
   for (const auto &r : recent) text += "recent = " + r + "\n";
   for (const auto &o : others)
      if (!trim(o).empty()) text += o + "\n";
   SDL_SaveFile(path.c_str(), text.data(), text.size());
}

// ---- listing ------------------------------------------------------------------------------------------------------

bool file_info(const fs::path &p, unsigned long long &size, long long &mtime) {
#if defined(_WIN32)
   struct _stat64 s;
   if (_wstat64(p.c_str(), &s) != 0) return false;
#else
   struct stat s;
   if (::stat(p.c_str(), &s) != 0) return false;
#endif
   size = static_cast<unsigned long long>(s.st_size);
   mtime = static_cast<long long>(s.st_mtime);
   return true;
}

std::string size_text(unsigned long long n) {
   if (n < 1024ull) return std::to_string(n) + " B";
   const char *unit[] = {"KiB", "MiB", "GiB", "TiB", "PiB"};
   double v = static_cast<double>(n) / 1024.0;
   int    u = 0;
   while (v >= 1024.0 && u < 4) {
      v /= 1024.0;
      ++u;
   }
   char buf[32];
   std::snprintf(buf, sizeof(buf), v < 10.0 ? "%.1f %s" : "%.0f %s", v, unit[u]);
   return buf;
}

std::string date_text(long long t) {
   const std::time_t tt = static_cast<std::time_t>(t);
   std::tm           tm{};
#if defined(_WIN32)
   if (localtime_s(&tm, &tt) != 0) return "";
#else
   if (!localtime_r(&tt, &tm)) return "";
#endif
   char buf[32];
   if (std::strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M", &tm) == 0) return "";
   return buf;
}

std::string lower(std::string s) {
   for (auto &c : s)
      if (c >= 'A' && c <= 'Z') c = static_cast<char>(c - 'A' + 'a');
   return s;
}

// Names compared without case (ASCII), then byte by byte: a stable order on every platform.
bool name_less(const std::string &a, const std::string &b) {
   const std::string la = lower(a), lb = lower(b);
   if (la != lb) return la < lb;
   return a < b;
}

bool filter_keeps(const browser_t &b, const entry_t &e) {
   if (e.folder || b.kind == 2 || b.filter_exts.empty()) return true;
   const auto &exts = b.filter_exts[static_cast<size_t>(b.filter)];
   const size_t dot = e.name.find_last_of('.');
   const std::string ext = dot == std::string::npos ? std::string() : lower(e.name.substr(dot + 1));
   for (const auto &x : exts)
      if (x == "*" || x == ext) return true;
   return false;
}

// The entries shown: hidden ones on request, files through the filter; folders first, then by the sort column.
void apply_view(browser_t &b) {
   b.shown.clear();
   for (size_t i = 0; i < b.all.size(); ++i) {
      const entry_t &e = b.all[i];
      if (e.hidden && !b.hidden) continue;
      if (!filter_keeps(b, e)) continue;
      b.shown.push_back(static_cast<int>(i));
   }
   std::stable_sort(b.shown.begin(), b.shown.end(), [&b](int i, int j) {
      const entry_t &x = b.all[static_cast<size_t>(i)], &y = b.all[static_cast<size_t>(j)];
      if (x.folder != y.folder) return x.folder;
      bool less = false, greater = false;
      if (b.sort_column == 1 && !x.folder) {
         less = x.size < y.size;
         greater = y.size < x.size;
      } else if (b.sort_column == 2) {
         less = x.mtime < y.mtime;
         greater = y.mtime < x.mtime;
      }
      if (!less && !greater) {
         less = name_less(x.name, y.name);
         greater = name_less(y.name, x.name);
      }
      return b.descending ? greater : less;
   });
   if (b.selected >= 0 && std::find(b.shown.begin(), b.shown.end(), b.selected) == b.shown.end()) b.selected = -1;
}

void list_folder(browser_t &b) {
   b.all.clear();
   b.error.clear();
   b.selected = -1;
   std::error_code ec;
   fs::directory_iterator it(b.folder, ec);
   if (ec) {
      b.error = u8(b.folder) + ": " + ec.message();
      apply_view(b);
      return;
   }
   for (const fs::directory_iterator end; it != end;) {
      entry_t e;
      e.name = u8(it->path().filename());
      std::error_code e2;
      e.folder = it->is_directory(e2);
      e.hidden = !e.name.empty() && e.name[0] == '.';
#if defined(_WIN32)
      const DWORD attr = GetFileAttributesW(it->path().c_str());
      if (attr != INVALID_FILE_ATTRIBUTES && (attr & FILE_ATTRIBUTE_HIDDEN)) e.hidden = true;
#endif
      e.info = file_info(it->path(), e.size, e.mtime);
      if (e.info) {
         if (!e.folder) e.size_text = size_text(e.size);
         e.date_text = date_text(e.mtime);
      }
      b.all.push_back(std::move(e));
      it.increment(ec);
      if (ec) {
         b.error = u8(b.folder) + ": " + ec.message();
         break;
      }
   }
   apply_view(b);
}

// Absolute and normal, without a trailing separator (but a root keeps its own).
fs::path normal(const fs::path &p, const fs::path &base) {
   std::error_code ec;
   fs::path a = p.is_absolute() ? p : base / p;
   a = fs::absolute(a, ec);
   if (ec) a = p;
   a = a.lexically_normal();
   if (!a.has_filename() && a.has_relative_path()) a = a.parent_path();
   return a;
}

// Enter a folder: listed at once; a path that is not a folder is reported and the browser stays where it is.
bool go(browser_t &b, const fs::path &p) {
   const fs::path f = normal(p, b.folder);
   std::error_code ec;
   if (!fs::is_directory(f, ec)) {
      b.error = u8(f) + ": " + (ec ? ec.message() : std::string("not a folder"));
      return false;
   }
   b.folder = f;
   b.path_text = u8(f);
   b.new_folder = false;
   if (b.kind == 0) b.name_text.clear();
   list_folder(b);
   return true;
}

void answer(browser_t &b, int state, const fs::path &path) {
   answers[b.id] = {state, state == 1 ? u8(path) : std::string()};
   if (state == 1) recent_add(b.kind == 2 ? path : path.parent_path());
   b.done = true;
}

// The Open / Save / Choose button, Enter in the name field, a double-click on a file.
void confirm(browser_t &b) {
   std::error_code ec;
   const bool sel_folder = b.selected >= 0 && b.all[static_cast<size_t>(b.selected)].folder;
   if (b.kind == 2) {
      answer(b, 1, sel_folder ? b.folder / from_u8(b.all[static_cast<size_t>(b.selected)].name) : b.folder);
      return;
   }
   if (b.name_text.empty()) {
      if (sel_folder) go(b, b.folder / from_u8(b.all[static_cast<size_t>(b.selected)].name));
      else b.error = b.kind == 0 ? "choose a file" : "type a name for the file";
      return;
   }
   const fs::path p = normal(from_u8(b.name_text), b.folder);
   if (fs::is_directory(p, ec)) {
      b.name_text.clear();
      go(b, p);
      return;
   }
   if (b.kind == 0) {
      if (!fs::exists(p, ec)) {
         b.error = u8(p) + ": no such file";
         return;
      }
      answer(b, 1, p);
      return;
   }
   if (!fs::is_directory(p.parent_path(), ec)) {
      b.error = u8(p.parent_path()) + ": no such folder";
      return;
   }
   if (fs::exists(p, ec)) { // replacing a file is asked first
      b.asking = true;
      b.asking_path = u8(p);
      return;
   }
   answer(b, 1, p);
}

// Enter in the path field: a folder is entered; a file (or, to save, a new name in an existing folder) is taken as
// the name.
void path_entered(browser_t &b) {
   const fs::path p = normal(from_u8(b.path_text), b.folder);
   std::error_code ec;
   if (fs::is_directory(p, ec)) {
      go(b, p);
      return;
   }
   if (b.kind != 2 && fs::is_directory(p.parent_path(), ec) && go(b, p.parent_path())) {
      b.name_text = u8(p.filename());
      confirm(b);
      return;
   }
   b.error = u8(p) + ": no such " + (b.kind == 2 ? "folder" : "file or folder");
   b.path_text = u8(b.folder);
}

bool is_separator(char c) {
#if defined(_WIN32)
   return c == '/' || c == '\\';
#else
   return c == '/';
#endif
}

// Tab in the path field: the last part completed to the longest prefix common to the names that start with it; a
// single folder gets its separator.
std::string complete(const browser_t &b, const std::string &text) {
   size_t cut = std::string::npos;
   for (size_t i = text.size(); i-- > 0;)
      if (is_separator(text[i])) {
         cut = i;
         break;
      }
   const std::string head = cut == std::string::npos ? std::string() : text.substr(0, cut + 1);
   const std::string prefix = cut == std::string::npos ? text : text.substr(cut + 1);
   const fs::path dir = head.empty() ? b.folder : normal(from_u8(head), b.folder);
   std::vector<std::pair<std::string, bool>> found;
   std::error_code ec;
   fs::directory_iterator it(dir, ec);
   for (const fs::directory_iterator end; !ec && it != end; it.increment(ec)) {
      const std::string name = u8(it->path().filename());
      if (name.compare(0, prefix.size(), prefix) != 0) continue;
      if (!name.empty() && name[0] == '.' && !b.hidden && (prefix.empty() || prefix[0] != '.')) continue;
      std::error_code e2;
      found.emplace_back(name, it->is_directory(e2));
   }
   if (found.empty()) return text;
   std::string common = found[0].first;
   for (const auto &f : found) {
      size_t k = 0;
      while (k < common.size() && k < f.first.size() && common[k] == f.first[k]) ++k;
      common.resize(k);
   }
   std::string out = head + common;
   if (found.size() == 1 && found[0].second) out += u8(fs::path("/").make_preferred());
   return out;
}

int path_callback(ImGuiInputTextCallbackData *data) {
   if (data->EventFlag != ImGuiInputTextFlags_CallbackCompletion) return 0;
   const auto       *b = static_cast<const browser_t *>(data->UserData);
   const std::string text(data->Buf, static_cast<size_t>(data->BufTextLen));
   const std::string done = complete(*b, text);
   if (done != text) {
      data->DeleteChars(0, data->BufTextLen);
      data->InsertChars(0, done.c_str());
   }
   return 0;
}

// ---- drawing ------------------------------------------------------------------------------------------------------

void part(const std::string &name) {
   const ImVec2 a = ImGui::GetItemRectMin(), z = ImGui::GetItemRectMax();
   parts[name] = ImVec4(a.x, a.y, z.x, z.y);
}

ImVec4 role(const char *name) {
   float c[4] = {1.0f, 1.0f, 1.0f, 1.0f};
   fig_palette_color(name, static_cast<int>(std::strlen(name)), c);
   return ImVec4(c[0], c[1], c[2], 1.0f);
}

// A text field over a std::string (Dear ImGui's resize callback), with Tab completion when `b` is given.
bool text_field(const char *label, const char *hint, std::string &s, ImGuiInputTextFlags flags, browser_t *b) {
   struct ctx_t {
      std::string *s;
      browser_t   *b;
   } ctx{&s, b};
   auto cb = [](ImGuiInputTextCallbackData *data) -> int {
      auto *c = static_cast<ctx_t *>(data->UserData);
      if (data->EventFlag == ImGuiInputTextFlags_CallbackResize) {
         c->s->resize(static_cast<size_t>(data->BufTextLen));
         data->Buf = c->s->data();
         return 0;
      }
      data->UserData = c->b;
      const int r = path_callback(data);
      data->UserData = c;
      return r;
   };
   flags |= ImGuiInputTextFlags_CallbackResize;
   if (b) flags |= ImGuiInputTextFlags_CallbackCompletion;
   return ImGui::InputTextWithHint(label, hint, s.data(), s.capacity() + 1, flags, cb, &ctx);
}

void place(browser_t &b, const char *icon, const std::string &label, const fs::path &where, const std::string &key) {
   const bool here = b.folder == where;
   const std::string text = std::string(icon) + "  " + label + "##" + key;
   if (ImGui::Selectable(text.c_str(), here)) go(b, where);
   part(key);
   ImGui::SetItemTooltip("%s", u8(where).c_str());
}

void draw_places(browser_t &b) {
   if (const char *home = SDL_GetUserFolder(SDL_FOLDER_HOME)) place(b, I_HOME, "Home", normal(from_u8(home), b.folder),
                                                                    "place:home");
   std::error_code ec;
   const fs::path cwd = fs::current_path(ec);
   if (!ec) place(b, I_WORKING, "Working folder", normal(cwd, b.folder), "place:cwd");
#if defined(_WIN32)
   const DWORD drives = GetLogicalDrives();
   int         n = 0;
   for (int i = 0; i < 26; ++i)
      if (drives & (1u << i)) {
         const std::string d = std::string(1, static_cast<char>('A' + i)) + ":\\";
         place(b, I_DRIVE, d.substr(0, 2), from_u8(d), "place:root:" + std::to_string(++n));
      }
#else
   place(b, I_DRIVE, "/", fs::path("/"), "place:root:1");
#endif
   bool title = false;
   int  n_recent = 0;
   for (const auto &r : recent) {
      const fs::path p = from_u8(r);
      if (!fs::is_directory(p, ec)) continue; // gone, or out of reach: not offered (kept in the file)
      if (!title) {
         ImGui::Spacing();
         ImGui::TextDisabled("Recent");
         title = true;
      }
      const std::string label = p.has_filename() ? u8(p.filename()) : r;
      place(b, I_RECENT, label, p, "place:recent:" + std::to_string(++n_recent));
   }
}

void draw_entries(browser_t &b, float height) {
   const ImGuiTableFlags tf = ImGuiTableFlags_Sortable | ImGuiTableFlags_ScrollY | ImGuiTableFlags_RowBg |
                              ImGuiTableFlags_BordersOuter | ImGuiTableFlags_Resizable | ImGuiTableFlags_SizingFixedFit;
   const float fs_ = ImGui::GetFontSize();
   if (!ImGui::BeginTable("##entries", 3, tf, ImVec2(0.0f, height))) return;
   ImGui::TableSetupScrollFreeze(0, 1);
   ImGui::TableSetupColumn("Name", ImGuiTableColumnFlags_WidthStretch | ImGuiTableColumnFlags_DefaultSort, 0.0f, 0);
   ImGui::TableSetupColumn("Size", ImGuiTableColumnFlags_WidthFixed, 5.5f * fs_, 1);
   ImGui::TableSetupColumn("Modified", ImGuiTableColumnFlags_WidthFixed, 8.0f * fs_, 2);
   ImGui::TableNextRow(ImGuiTableRowFlags_Headers);
   const char *keys[] = {"sort:name", "sort:size", "sort:modified"};
   for (int c = 0; c < 3; ++c) {
      ImGui::TableSetColumnIndex(c);
      ImGui::TableHeader(ImGui::TableGetColumnName(c));
      part(keys[c]);
   }
   if (ImGuiTableSortSpecs *s = ImGui::TableGetSortSpecs()) {
      if (s->SpecsDirty && s->SpecsCount > 0) {
         b.sort_column = static_cast<int>(s->Specs[0].ColumnUserID);
         b.descending = s->Specs[0].SortDirection == ImGuiSortDirection_Descending;
         apply_view(b);
      }
      s->SpecsDirty = false;
   }
   const ImVec4 accent = role("accent");
   const ImU32  text = ImGui::GetColorU32(ImGuiCol_Text);
   int          go_to = -1, choose = -1;
   ImGuiListClipper clip; // only the rows in view are drawn: folders of many thousand files
   clip.Begin(static_cast<int>(b.shown.size()));
   while (clip.Step())
      for (int r = clip.DisplayStart; r < clip.DisplayEnd; ++r) {
         const int      i = b.shown[static_cast<size_t>(r)];
         const entry_t &e = b.all[static_cast<size_t>(i)];
         const bool     off = b.kind == 2 && !e.folder; // choosing a folder: the files are shown, not chosen
         ImGui::TableNextRow();
         ImGui::TableSetColumnIndex(0);
         ImGui::PushID(r);
         if (off) ImGui::BeginDisabled();
         const ImVec2 at = ImGui::GetCursorScreenPos();
         const bool   hit = ImGui::Selectable("##entry", b.selected == i,
                                              ImGuiSelectableFlags_SpanAllColumns | ImGuiSelectableFlags_AllowDoubleClick);
         part("entry:" + e.name);
         const float  alpha = off ? ImGui::GetStyle().DisabledAlpha : 1.0f;
         ImVec4       ic = e.folder ? accent : ImGui::GetStyleColorVec4(ImGuiCol_TextDisabled);
         ic.w *= alpha;
         ImDrawList  *dl = ImGui::GetWindowDrawList();
         dl->AddText(at, ImGui::GetColorU32(ic), e.folder ? I_FOLDER : I_FILE);
         dl->AddText(ImVec2(at.x + 1.6f * fs_, at.y), off ? ImGui::GetColorU32(ImGuiCol_TextDisabled) : text,
                     e.name.c_str());
         if (off) ImGui::EndDisabled();
         if (hit) {
            b.selected = i;
            if (!e.folder) b.name_text = e.name;
            else if (b.kind == 0) b.name_text.clear();
            if (ImGui::IsMouseDoubleClicked(ImGuiMouseButton_Left)) (e.folder ? go_to : choose) = i;
         }
         ImGui::TableSetColumnIndex(1);
         ImGui::TextDisabled("%s", e.size_text.c_str());
         ImGui::TableSetColumnIndex(2);
         ImGui::TextDisabled("%s", e.date_text.c_str());
         ImGui::PopID();
      }
   ImGui::EndTable();
   if (go_to >= 0) go(b, b.folder / from_u8(b.all[static_cast<size_t>(go_to)].name));
   else if (choose >= 0) confirm(b);
}

void draw_question(browser_t &b) {
   const char *name = "Replace the file?###figure file browser replace";
   if (b.asking && !ImGui::IsPopupOpen(name)) ImGui::OpenPopup(name);
   if (!ImGui::BeginPopupModal(name, nullptr, ImGuiWindowFlags_AlwaysAutoResize | ImGuiWindowFlags_NoSavedSettings))
      return;
   ImGui::TextColored(role("warning"), "%s", I_ALERT);
   ImGui::SameLine();
   ImGui::Text("%s exists. Replace it?", u8(from_u8(b.asking_path).filename()).c_str());
   if (ImGui::Button("Replace")) {
      b.asking = false;
      answer(b, 1, from_u8(b.asking_path));
      ImGui::CloseCurrentPopup();
   }
   part("replace");
   ImGui::SameLine();
   if (ImGui::Button("Cancel##keep") || ImGui::IsKeyPressed(ImGuiKey_Escape, false)) {
      b.asking = false;
      ImGui::CloseCurrentPopup();
   }
   part("keep");
   ImGui::EndPopup();
}

void draw_browser(browser_t &b) {
   parts.clear();
   const char       *titles[] = {"Open a file", "Save as", "Choose a folder"};
   const std::string name = std::string(titles[b.kind]) + "###figure file browser " + b.id;
   if (!ImGui::IsPopupOpen(name.c_str())) ImGui::OpenPopup(name.c_str()); // again if something closed it
   const ImGuiViewport *vp = ImGui::GetMainViewport();
   const float          fs_ = ImGui::GetFontSize();
   const ImVec2 size(std::min(vp->WorkSize.x - 2.0f * fs_, std::max(0.6f * vp->WorkSize.x, 44.0f * fs_)),
                     std::min(vp->WorkSize.y - 2.0f * fs_, std::max(0.6f * vp->WorkSize.y, 26.0f * fs_)));
   ImGui::SetNextWindowSize(size, ImGuiCond_Appearing);
   ImGui::SetNextWindowPos(ImVec2(vp->WorkPos.x + 0.5f * vp->WorkSize.x, vp->WorkPos.y + 0.5f * vp->WorkSize.y),
                           ImGuiCond_Appearing, ImVec2(0.5f, 0.5f));
   bool open = true;
   if (!ImGui::BeginPopupModal(name.c_str(), &open, ImGuiWindowFlags_NoSavedSettings)) {
      if (!open) answer(b, 2, fs::path());
      return;
   }
   // Escape cancels (a field being edited takes its own Escape first; the new folder row closes on its own)
   const bool editing = ImGui::IsAnyItemActive();
   if (!editing && !b.asking && ImGui::IsWindowFocused(ImGuiFocusedFlags_RootAndChildWindows) &&
       ImGui::IsKeyPressed(ImGuiKey_Escape, false)) {
      if (b.new_folder) b.new_folder = false;
      else answer(b, 2, fs::path());
   }
   const ImGuiStyle &style = ImGui::GetStyle();
   // the path: parent, refresh, the field (Enter goes, Tab completes), new folder
   const bool root = !b.folder.has_relative_path();
   if (root) ImGui::BeginDisabled();
   if (ImGui::Button(I_UP)) go(b, b.folder.parent_path());
   if (root) ImGui::EndDisabled();
   part("parent");
   ImGui::SetItemTooltip("Parent folder");
   ImGui::SameLine();
   if (ImGui::Button(I_REFRESH)) { // the selection kept by name
      const std::string keep = b.selected >= 0 ? b.all[static_cast<size_t>(b.selected)].name : std::string();
      list_folder(b);
      for (size_t i = 0; i < b.all.size(); ++i)
         if (!keep.empty() && b.all[i].name == keep) b.selected = static_cast<int>(i);
      apply_view(b);
   }
   part("refresh");
   ImGui::SetItemTooltip("Read the folder again");
   ImGui::SameLine();
   const float new_w = ImGui::CalcTextSize(I_NEW_FOLDER).x + 2.0f * style.FramePadding.x;
   ImGui::SetNextItemWidth(ImGui::GetContentRegionAvail().x - new_w - style.ItemSpacing.x);
   if (text_field("##path", "folder", b.path_text, ImGuiInputTextFlags_EnterReturnsTrue | ImGuiInputTextFlags_ElideLeft,
                  &b)) {
      path_entered(b);
      ImGui::ClearActiveID(); // shows the text set from code
   }
   part("path");
   ImGui::SameLine();
   if (ImGui::Button(I_NEW_FOLDER)) {
      b.new_folder = !b.new_folder;
      b.new_text.clear();
   }
   part("new folder");
   ImGui::SetItemTooltip("New folder");
   if (b.new_folder) {
      ImGui::AlignTextToFramePadding();
      ImGui::TextUnformatted("New folder");
      ImGui::SameLine();
      const float create_w = ImGui::CalcTextSize("Create").x + 2.0f * style.FramePadding.x;
      ImGui::SetNextItemWidth(ImGui::GetContentRegionAvail().x - create_w - style.ItemSpacing.x);
      const bool enter = text_field("##new folder", "name", b.new_text, ImGuiInputTextFlags_EnterReturnsTrue, nullptr);
      part("new folder name");
      ImGui::SameLine();
      const bool create = ImGui::Button("Create");
      part("create");
      if ((enter || create) && !b.new_text.empty()) {
         const fs::path p = b.folder / from_u8(b.new_text);
         std::error_code ec;
         if (fs::create_directory(p, ec)) {
            const std::string made = u8(p.filename());
            b.new_folder = false;
            list_folder(b);
            for (size_t i = 0; i < b.all.size(); ++i)
               if (b.all[i].name == made) b.selected = static_cast<int>(i);
         } else {
            b.error = u8(p) + ": " + (ec ? ec.message() : std::string("already exists"));
         }
      }
   }
   if (!b.error.empty()) {
      ImGui::TextColored(role("error"), "%s", I_ALERT);
      ImGui::SameLine();
      ImGui::PushStyleColor(ImGuiCol_Text, role("error"));
      ImGui::TextWrapped("%s", b.error.c_str());
      ImGui::PopStyleColor();
   }
   // the body: places on the left, the entries on the right; the footer below
   const float footer = 2.0f * ImGui::GetFrameHeightWithSpacing() + style.ItemSpacing.y;
   const float body = std::max(4.0f * fs_, ImGui::GetContentRegionAvail().y - footer);
   if (ImGui::BeginChild("##places", ImVec2(11.0f * fs_, body), ImGuiChildFlags_Borders)) draw_places(b);
   ImGui::EndChild();
   ImGui::SameLine();
   draw_entries(b, body);
   // the footer: the name and the filter, hidden files, then cancel and the action
   if (b.kind != 2) {
      ImGui::AlignTextToFramePadding();
      ImGui::TextUnformatted("Name");
      ImGui::SameLine();
      const float filter_w = b.filter_names.empty() ? 0.0f : 14.0f * fs_ + style.ItemSpacing.x;
      ImGui::SetNextItemWidth(ImGui::GetContentRegionAvail().x - filter_w);
      if (text_field("##name", b.kind == 0 ? "file to open" : "file name", b.name_text,
                     ImGuiInputTextFlags_EnterReturnsTrue, nullptr))
         confirm(b);
      part("name");
      if (!b.filter_names.empty()) {
         ImGui::SameLine();
         ImGui::SetNextItemWidth(14.0f * fs_);
         if (ImGui::BeginCombo("##filter", b.filter_names[static_cast<size_t>(b.filter)].c_str())) {
            for (size_t k = 0; k < b.filter_names.size(); ++k) {
               if (ImGui::Selectable(b.filter_names[k].c_str(), static_cast<int>(k) == b.filter)) {
                  b.filter = static_cast<int>(k);
                  apply_view(b);
               }
               part("filter:" + std::to_string(k + 1));
            }
            ImGui::EndCombo();
         }
         part("filter");
      }
   } else {
      const bool  sel = b.selected >= 0 && b.all[static_cast<size_t>(b.selected)].folder;
      const fs::path chosen = sel ? b.folder / from_u8(b.all[static_cast<size_t>(b.selected)].name) : b.folder;
      ImGui::AlignTextToFramePadding();
      ImGui::TextDisabled("Folder");
      ImGui::SameLine();
      ImGui::TextUnformatted(u8(chosen).c_str());
   }
   if (ImGui::Checkbox("Hidden files", &b.hidden)) apply_view(b);
   part("hidden");
   const char *action = b.kind == 0 ? "Open" : b.kind == 1 ? "Save" : "Choose";
   const float bw = std::max(6.0f * fs_, ImGui::CalcTextSize(action).x + 2.0f * style.FramePadding.x);
   ImGui::SameLine();
   ImGui::SetCursorPosX(ImGui::GetCursorPosX() +
                        std::max(0.0f, ImGui::GetContentRegionAvail().x - 2.0f * bw - style.ItemSpacing.x));
   if (ImGui::Button("Cancel", ImVec2(bw, 0.0f))) answer(b, 2, fs::path());
   part("cancel");
   ImGui::SameLine();
   if (ImGui::Button(action, ImVec2(bw, 0.0f))) confirm(b);
   part("ok");
   draw_question(b);
   if (b.done) ImGui::CloseCurrentPopup();
   ImGui::EndPopup();
}

browser_t *front() { return browsers.empty() ? nullptr : browsers.front().get(); }

} // namespace

extern "C" {

int fig_file_browser(int kind, const char *id, int id_len, const char *filters, int filters_len, const char *path,
                     int path_len) {
   try {
      const char *entry = kind == 1 ? "app%save_file_browser" : "app%open_file_browser";
      if (fig_task_refuse(entry, 21)) return FIG_ERR_STATE; // a task does not draw
      if (!initialized) return fail(FIG_ERR_STATE, "file browser: figure is not initialized");
      if (kind < 0 || kind > 2) return fail(FIG_ERR_ARGUMENT, "file browser: unknown kind");
      const std::string key(id, id_len > 0 ? static_cast<size_t>(id_len) : 0);
      for (const auto &o : browsers)
         if (o->id == key) return fail(FIG_ERR_STATE, "file browser \"" + key + "\" is already open");
      if (fig_file_dialog_pending(id, id_len))
         return fail(FIG_ERR_STATE, "file dialog \"" + key + "\" is already open");
      auto b = std::make_unique<browser_t>();
      b->id = key;
      b->kind = kind;
      const std::string f(filters, filters_len > 0 ? static_cast<size_t>(filters_len) : 0);
      for (size_t start = 0; start < f.size();) {
         size_t end = f.find('\n', start);
         if (end == std::string::npos) end = f.size();
         const std::string entry = f.substr(start, end - start);
         start = end + 1;
         if (entry.empty()) continue;
         const size_t bar = entry.find('|');
         if (bar == std::string::npos)
            return fail(FIG_ERR_ARGUMENT, "file browser: a filter is \"name|pattern\", got \"" + entry + "\"");
         b->filter_names.push_back(entry.substr(0, bar));
         std::vector<std::string> exts;
         const std::string pattern = entry.substr(bar + 1);
         for (size_t s = 0; s <= pattern.size();) {
            size_t e = pattern.find(';', s);
            if (e == std::string::npos) e = pattern.size();
            std::string x = trim(pattern.substr(s, e - s));
            if (x.rfind("*.", 0) == 0) x = x.substr(2); // "*.inp" taken as "inp"
            if (!x.empty()) exts.push_back(lower(x));
            s = e + 1;
         }
         b->filter_exts.push_back(exts);
      }
      // where it starts: a folder, or a file (its folder, its name proposed); relative to the working directory
      std::error_code ec;
      const fs::path   cwd = fs::current_path(ec);
      const std::string where(path, path_len > 0 ? static_cast<size_t>(path_len) : 0);
      const fs::path   start = normal(where.empty() ? fs::path(".") : from_u8(where), cwd);
      b->folder = cwd;
      if (fs::is_directory(start, ec)) {
         b->folder = start;
      } else if (fs::is_directory(start.parent_path(), ec)) {
         b->folder = start.parent_path();
         if (kind != 2) b->name_text = u8(start.filename());
      }
      b->folder = normal(b->folder, cwd);
      b->path_text = u8(b->folder);
      list_folder(*b);
      if (kind == 0 && !b->name_text.empty())
         for (size_t i = 0; i < b->all.size(); ++i)
            if (b->all[i].name == b->name_text) b->selected = static_cast<int>(i);
      recent_load();
      browsers.push_back(std::move(b));
      return FIG_OK;
   } catch (const std::exception &e) {
      return fail(FIG_ERR_EXCEPTION, std::string("C++ exception: ") + e.what());
   } catch (...) {
      return fail(FIG_ERR_EXCEPTION, "unknown C++ exception");
   }
}

int fig_file_browser_pending(const char *id, int id_len) {
   const std::string key(id, id_len > 0 ? static_cast<size_t>(id_len) : 0);
   for (const auto &b : browsers)
      if (b->id == key) return 1;
   return 0;
}

int fig_file_browser_result(const char *id, int id_len, char *buf, int buf_len, int *state, int *path_len) {
   const std::string key(id, id_len > 0 ? static_cast<size_t>(id_len) : 0);
   *state = 0;
   *path_len = 0;
   const auto it = answers.find(key);
   if (it == answers.end()) return FIG_OK; // open, or no browser: nothing to report
   *state = it->second.first;
   const std::string p = it->second.second;
   answers.erase(it);
   *path_len = static_cast<int>(p.size());
   const int n = std::min(*path_len, buf_len);
   if (n > 0) std::memcpy(buf, p.data(), static_cast<size_t>(n));
   return FIG_OK;
}

void fig_file_browser_draw(void) {
   try {
      browser_t *b = front();
      if (!b) {
         parts.clear();
         return;
      }
      draw_browser(*b);
      if (b->done) browsers.erase(browsers.begin());
   } catch (...) {
   }
}

void fig_file_browser_reset(int init, int keep) {
   browsers.clear();
   answers.clear();
   parts.clear();
   recent.clear();
   initialized = init != 0;
   persist = keep != 0;
}

int fig_file_browser_settings(const char *path, int path_len) {
   settings_override = true;
   settings_named.assign(path, path_len > 0 ? static_cast<size_t>(path_len) : 0);
   recent.clear();
   return FIG_OK;
}

int fig_file_browser_get(int what, int index, char *buf, int buf_len, int *len, int *count) {
   *len = 0;
   *count = 0;
   const browser_t *b = front();
   if (!b && what != 5) return FIG_OK;
   std::string s;
   switch (what) {
   case 0: s = u8(b->folder); *count = 1; break;
   case 1:
      *count = static_cast<int>(b->shown.size());
      if (index >= 1 && index <= *count) {
         const entry_t &e = b->all[static_cast<size_t>(b->shown[static_cast<size_t>(index - 1)])];
         s = e.name + (e.folder ? "/" : "");
      }
      break;
   case 2: s = b->error; *count = 1; break;
   case 3: s = b->asking ? "1" : ""; *count = 1; break;
   case 4: s = b->path_text; *count = 1; break;
   case 5:
      *count = static_cast<int>(recent.size());
      if (index >= 1 && index <= *count) s = recent[static_cast<size_t>(index - 1)];
      break;
   case 6: s = b->name_text; *count = 1; break;
   default: return fail(FIG_ERR_ARGUMENT, "file browser: unknown query");
   }
   *len = static_cast<int>(s.size());
   const int n = std::min(*len, buf_len);
   if (n > 0) std::memcpy(buf, s.data(), static_cast<size_t>(n));
   return FIG_OK;
}

int fig_file_browser_rect(const char *part_name, int part_len, float *rect, int *found) {
   const std::string key(part_name, part_len > 0 ? static_cast<size_t>(part_len) : 0);
   *found = 0;
   const auto it = parts.find(key);
   if (it == parts.end()) return FIG_OK;
   rect[0] = it->second.x;
   rect[1] = it->second.y;
   rect[2] = it->second.z;
   rect[3] = it->second.w;
   *found = 1;
   return FIG_OK;
}

} // extern "C"
