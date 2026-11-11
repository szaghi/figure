// FIGURE's code editor and text diff: the glue of ImGuiColorTextEdit (goossens fork, vendored unmodified in
// third_party/ImGuiColorTextEdit; see THIRD_PARTY.md and docs/guide/editor.md).
//
// The fork draws only through Dear ImGui (a child window, its draw list, popups and tooltips), so the editor looks the
// same in a window, headless and remote. FIGURE adds, without changing the fork's files:
//   - languages built from a packed definition (src/lib/figure_editor.F90's language_object): keywords, types,
//     comments, strings, numbers (one tokenizer: Fortran's kinds and exponents included), case, and a key = value mode
//     (sections and keys coloured by a tokenizer of FIGURE's); the fork's own languages by name;
//   - marks: one per line, the fork's markers (a tinted line and line number, the message as a tooltip) with a
//     severity icon in a decoration column, so that the colour is not the only sign;
//   - completion of the program's words: the fork's autocomplete framework, with FIGURE's matcher as its callback
//     (prefix first, then substring, case-insensitive) and no delay (the popup on the next frame, as tests need);
//   - find, replace, the word at the cursor, the screen rectangle of a line, the completion state: through a subclass,
//     which reaches the fork's protected members (document, cursors, autocomplete) without a patch;
//   - the text diff by id (an immediate-mode call: its state kept per Dear ImGui id), and the changed lines computed by
//     the diff's own algorithm (dtl), callable from a task.
// Every function is extern "C", returns a FIG_* status and never lets a C++ exception escape (figure_native.h).
#include "figure_native.h"

#include "imgui.h"
#include "imgui_internal.h"

#include "TextDiff.h"
#include "TextEditor.h"
#include "dtl.h"

#include <algorithm>
#include <cctype>
#include <cstring>
#include <map>
#include <memory>
#include <string>
#include <string_view>
#include <vector>

namespace {

int fail(int status, const std::string &msg) {
   fig_set_last_error(msg.c_str(), static_cast<int>(msg.size()));
   return status;
}

#define ED_TRY try {
#define ED_CATCH                                                                                                       \
   }                                                                                                                   \
   catch (const std::exception &e) {                                                                                   \
      return fail(FIG_ERR_EXCEPTION, std::string("code editor: C++ exception: ") + e.what());                          \
   }                                                                                                                   \
   catch (...) {                                                                                                       \
      return fail(FIG_ERR_EXCEPTION, "code editor: unknown C++ exception");                                            \
   }

std::string str(const char *p, long long n) { return n > 0 && p ? std::string(p, static_cast<size_t>(n)) : std::string(); }

// The text with CR LF (and lone CR) as LF: the editor's lines and the diff's are the same.
std::string unix_lines(std::string_view t) {
   std::string out;
   out.reserve(t.size());
   for (size_t i = 0; i < t.size(); ++i) {
      if (t[i] == '\r') {
         out += '\n';
         if (i + 1 < t.size() && t[i + 1] == '\n') ++i;
      } else {
         out += t[i];
      }
   }
   return out;
}

std::vector<std::string> split(const std::string &s, char sep) {
   std::vector<std::string> out;
   size_t a = 0;
   while (true) {
      const size_t b = s.find(sep, a);
      out.push_back(s.substr(a, b == std::string::npos ? std::string::npos : b - a));
      if (b == std::string::npos) break;
      a = b + 1;
   }
   return out;
}

std::string lower(std::string s) {
   for (auto &c : s) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
   return s;
}

// ---- languages -------------------------------------------------------------------------------------------------

using Iter = TextEditor::Iterator;
using CP = TextEditor::CodePoint;

enum lang_flag { L_SINGLE = 1, L_DOUBLE = 2, L_NUMBERS = 4, L_CASE = 8, L_KEY_VALUE = 16 };

bool ident_start(ImWchar c) { return CP::isLetter(c) || c == '_'; }
bool ident_more(ImWchar c) { return CP::isLetter(c) || CP::isNumber(c) || c == '_'; }
bool digit(ImWchar c) { return c >= '0' && c <= '9'; }

Iter get_identifier(Iter start, Iter end) {
   if (start == end || !ident_start(*start)) return start;
   Iter i = start;
   while (i < end && ident_more(*i)) ++i;
   return i;
}

// A number: digits [. digits] or . digits, an exponent [eEdDqQ][+-]digits (only with its digits), a kind suffix
// _identifier or _digits (Fortran's 1.0_real64, 2.5d-3, 7_int8; C's 1e5 and 0.5 alike).
Iter get_number(Iter start, Iter end) {
   Iter i = start;
   bool digits = false;
   while (i < end && digit(*i)) ++i, digits = true;
   if (i < end && *i == '.') {
      Iter j = i;
      ++j;
      bool frac = false;
      while (j < end && digit(*j)) ++j, frac = true;
      if (!digits && !frac) return start;
      // "1." followed by a letter is Fortran's 1.and. or 1.e5: an exponent letter keeps it, any other ends at the digit
      if (frac || j == end || !CP::isLetter(*j) || *j == 'e' || *j == 'E' || *j == 'd' || *j == 'D') i = j;
      digits = true;
   }
   if (!digits) return start;
   if (i < end && (*i == 'e' || *i == 'E' || *i == 'd' || *i == 'D' || *i == 'q' || *i == 'Q')) {
      Iter j = i;
      ++j;
      if (j < end && (*j == '+' || *j == '-')) ++j;
      if (j < end && digit(*j)) {
         while (j < end && digit(*j)) ++j;
         i = j;
      }
   }
   if (i < end && *i == '_') {
      Iter j = i;
      ++j;
      if (j < end && ident_more(*j)) {
         while (j < end && ident_more(*j)) ++j;
         i = j;
      }
   }
   if (i < end && ident_more(*i)) return start; // 12abc is not a number
   return i;
}

bool punctuation(ImWchar c) { return c < 128 && std::ispunct(static_cast<int>(c)) != 0; }

// key = value files: "[section]" alone on its line (a declaration's colour), a key (a keyword's colour: the words up
// to the line's "="). The rest by the language's other rules.
Iter key_value_token(Iter start, Iter end, TextEditor::Color &color) {
   if (start == end) return start;
   if (*start == '[') {
      Iter i = start;
      ++i;
      while (i < end && *i != ']' && *i != '=') ++i;
      if (i == end || *i != ']') return start;
      ++i;
      Iter j = i;
      while (j < end && CP::isWhiteSpace(*j)) ++j;
      if (j != end && *j != '!' && *j != '#' && *j != ';') return start;
      color = TextEditor::Color::declaration;
      return i;
   }
   if (!ident_start(*start)) return start;
   Iter i = start, last = start; // last: just after the key's last non-blank character
   while (i < end && (ident_more(*i) || *i == ' ' || *i == '\t' || *i == '-' || *i == '.' || *i == '%')) {
      if (!CP::isWhiteSpace(*i)) last = i, ++last;
      ++i;
   }
   if (i == end || *i != '=') return start;
   color = TextEditor::Color::keyword;
   return last;
}

struct language_t {
   TextEditor::Language lang;
   bool key_value = false;
};

// Languages by their packed definition (identical definitions share one; never freed: a handful per program).
std::map<std::string, std::unique_ptr<language_t>> languages;

// The packed definition (figure_editor.F90's pack): fields separated by 0x1f: name, builtin (0/1), keywords and
// types (LF-separated), line comment, its alternative, block comment start and end, preprocessor character, flags.
int language_of(const std::string &packed, const TextEditor::Language **out, bool *key_value) {
   *out = nullptr;
   *key_value = false;
   if (packed.empty()) return FIG_OK;
   auto found = languages.find(packed);
   if (found != languages.end()) {
      *out = &found->second->lang;
      *key_value = found->second->key_value;
      return FIG_OK;
   }
   const auto f = split(packed, '\x1f');
   if (f.size() != 10) return fail(FIG_ERR_ARGUMENT, "code editor: a malformed language definition");
   const std::string &name = f[0];
   if (f[1] == "1") { // one of the fork's own languages, by name in any case
      for (const auto &n : TextEditor::GetRegisteredLanguages()) {
         if (lower(n) == lower(name)) {
            *out = TextEditor::LookupLanguage(n);
            return FIG_OK;
         }
      }
      return fail(FIG_ERR_ARGUMENT, "code editor: unknown language \"" + name + "\"");
   }
   if (name.empty()) return FIG_OK; // plain text
   auto l = std::make_unique<language_t>();
   const int flags = std::atoi(f[9].c_str());
   TextEditor::Language &g = l->lang;
   g.name = name;
   g.caseSensitive = (flags & L_CASE) != 0;
   for (const auto &k : split(f[2], '\n'))
      if (!k.empty()) g.keywords.insert(g.caseSensitive ? k : lower(k));
   for (const auto &k : split(f[3], '\n'))
      if (!k.empty()) g.declarations.insert(g.caseSensitive ? k : lower(k));
   g.singleLineComment = f[4];
   g.singleLineCommentAlt = f[5];
   g.commentStart = f[6];
   g.commentEnd = f[7];
   g.preprocess = f[8].empty() ? 0 : static_cast<ImWchar>(static_cast<unsigned char>(f[8][0]));
   g.hasSingleQuotedStrings = (flags & L_SINGLE) != 0;
   g.hasDoubleQuotedStrings = (flags & L_DOUBLE) != 0;
   g.isPunctuation = punctuation;
   g.getIdentifier = get_identifier;
   if (flags & L_NUMBERS) g.getNumber = get_number;
   if (flags & L_KEY_VALUE) {
      g.customTokenizer = key_value_token;
      l->key_value = true;
   }
   *out = &g;
   *key_value = l->key_value;
   languages[packed] = std::move(l);
   return FIG_OK;
}

// ---- the style -------------------------------------------------------------------------------------------------

ImU32 opaque_over(const ImVec4 &top, const ImVec4 &under) {
   const float a = top.w;
   return ImGui::ColorConvertFloat4ToU32(ImVec4(top.x * a + under.x * (1.0f - a), top.y * a + under.y * (1.0f - a),
                                                top.z * a + under.z * (1.0f - a), 1.0f));
}

// The fork's dark or light palette (by the window background's lightness) with the style's text, background,
// selection and line-number colours: the editor follows FIGURE's styles and palettes.
TextEditor::Palette style_palette() {
   const ImGuiStyle &s = ImGui::GetStyle();
   const ImVec4 bg = s.Colors[ImGuiCol_WindowBg];
   const float lum = 0.2126f * bg.x + 0.7152f * bg.y + 0.0722f * bg.z;
   TextEditor::Palette p = lum > 0.5f ? TextEditor::GetLightPalette() : TextEditor::GetDarkPalette();
   auto set = [&p](TextEditor::Color c, ImU32 v) { p[static_cast<size_t>(c)] = v; };
   set(TextEditor::Color::background, opaque_over(s.Colors[ImGuiCol_FrameBg], ImVec4(bg.x, bg.y, bg.z, 1.0f)));
   set(TextEditor::Color::text, ImGui::ColorConvertFloat4ToU32(s.Colors[ImGuiCol_Text]));
   set(TextEditor::Color::cursor, ImGui::ColorConvertFloat4ToU32(s.Colors[ImGuiCol_Text]));
   set(TextEditor::Color::selection, ImGui::ColorConvertFloat4ToU32(s.Colors[ImGuiCol_TextSelectedBg]));
   set(TextEditor::Color::lineNumber, ImGui::ColorConvertFloat4ToU32(s.Colors[ImGuiCol_TextDisabled]));
   set(TextEditor::Color::currentLineNumber, ImGui::ColorConvertFloat4ToU32(s.Colors[ImGuiCol_Text]));
   return p;
}

// ---- marks -----------------------------------------------------------------------------------------------------

constexpr int N_SEVERITY = 3;           // 1 error, 2 warning, 3 info
const ImU32 SEVERITY_RGB[N_SEVERITY] = { // Okabe-Ito vermilion, orange, blue
   IM_COL32(213, 94, 0, 255), IM_COL32(230, 159, 0, 255), IM_COL32(0, 114, 178, 255)};
const char *SEVERITY_ICON[N_SEVERITY] = {"\xee\x82\x84", "\xee\x86\x93", "\xee\x83\xb9"}; // circle-x, triangle-alert, info
const char *SEVERITY_WORD[N_SEVERITY] = {"error", "warning", "info"};
constexpr unsigned TEXT_ALPHA = 64;  // the tint of a marked line
constexpr unsigned NUMBER_ALPHA = 140; // ... of its line number

ImU32 with_alpha(ImU32 c, unsigned a) { return (c & ~IM_COL32_A_MASK) | (static_cast<ImU32>(a) << IM_COL32_A_SHIFT); }

// ---- the editor ------------------------------------------------------------------------------------------------

class editor_t : public TextEditor {
 public:
   editor_t() {
      SetShowWhitespacesEnabled(false);
      SetCompletePairedGlyphs(false); // Fortran's ' and " (and an input file's) are typed in pairs by hand
      SetShowScrollbarMiniMapEnabled(false);
      SetShowPanScrollIndicatorEnabled(false);
      SetLineDecorator(2, [this](Decorator &d) { decorate(d); });
      ac.triggerDelay = std::chrono::milliseconds(0);
      ac.callback = [this](AutoCompleteState &s) { suggest(s); };
   }

   std::vector<std::string> words;    // completions (the program's)
   std::vector<std::string> offered;  // what the popup offers (the last suggestions)
   bool key_value = false;
   std::string packed;                // the language's definition
   ImVec2 rect_min{0, 0}, rect_max{0, 0}; // the child window on the last draw
   bool drawn = false;

   void set_words(std::vector<std::string> w) {
      words = std::move(w);
      offered.clear();
      if (words.empty()) {
         SetAutoCompleteConfig(nullptr);
      } else {
         ac.wordCharacters = key_value ? " -" : ""; // a key of several words ("reynolds number") is one term
         SetAutoCompleteConfig(&ac);
      }
   }

   bool completing() const { return autocomplete.isActive() && !offered.empty(); }

   int mark(size_t line, int sev, const std::string &message) {
      if (line >= document.size()) return fail(FIG_ERR_ARGUMENT, "code_editor_object%mark: line " +
                                                                    std::to_string(line + 1) + " is past the last, " +
                                                                    std::to_string(document.size()));
      std::string text = std::string(SEVERITY_WORD[sev - 1]) + ": " + message;
      const int old = line_severity(line);
      if (old > 0) { // a second mark on the line: one marker, the messages joined, the gravest severity
         text = mark_text(line) + "\n" + text;
         sev = std::min(sev, old);
      }
      const ImU32 c = SEVERITY_RGB[sev - 1];
      AddMarker(line, with_alpha(c, NUMBER_ALPHA), with_alpha(c, TEXT_ALPHA), text, text);
      return FIG_OK;
   }

   void clear_marks() { ClearMarkers(); }

   // The severity of a line's marker, from its colour (the fork renumbers its markers after deletions).
   int line_severity(size_t line) const {
      if (line >= document.size()) return 0;
      const size_t m = document[line].marker;
      if (m == 0 || m > markers.size()) return 0;
      for (int k = 0; k < N_SEVERITY; ++k)
         if (markers[m - 1].textColor == with_alpha(SEVERITY_RGB[k], TEXT_ALPHA)) return k + 1;
      return 0;
   }

   std::string mark_text(size_t line) const {
      if (line >= document.size()) return "";
      const size_t m = document[line].marker;
      return m > 0 && m <= markers.size() ? markers[m - 1].textTooltip : "";
   }

   std::string word_at_cursor() const {
      const DocPos p = GetMainCursorPosition();
      if (p.line >= document.size()) return "";
      const auto &l = document[p.line];
      size_t a = std::min(p.index, l.size()), b = a;
      while (a > 0 && CP::isWord(l[a - 1].codepoint)) --a;
      while (b < l.size() && CP::isWord(l[b].codepoint)) ++b;
      return a < b ? GetSectionText(DocPos(p.line, a), DocPos(p.line, b)) : "";
   }

   // The screen rectangle of a line's text on the last draw (false when not drawn or not in view).
   bool line_rect(size_t line, float *r) const {
      // in view: its first row among the rows drawn (the fork's IsDocPosVisible leaves out the last one drawn)
      if (!drawn || line >= document.size() || IsLineHidden(line)) return false;
      const size_t row = docPos2VisPos(DocPos(line, 0)).row;
      if (row < firstVisibleRow || row > lastVisibleRow) return false;
      const ImVec2 p = DocPos2ScreenPos(DocPos(line, 0));
      r[0] = rect_min.x + textLeftOffset;
      r[1] = p.y;
      r[2] = std::max(r[0], rect_min.x + textRightOffset);
      r[3] = p.y + glyphSize.y;
      return true;
   }

 private:
   AutoCompleteConfig ac;

   void suggest(AutoCompleteState &s) {
      s.suggestions.clear();
      s.labels.clear();
      // a term of several words starts at its first non-blank (the line's indentation is kept)
      size_t lead = 0;
      while (lead < s.searchTerm.size() && (s.searchTerm[lead] == ' ' || s.searchTerm[lead] == '\t')) ++lead;
      const std::string term = lower(s.searchTerm.substr(lead));
      s.replacementStart.index += lead; // ASCII blanks: one byte, one glyph
      if (!term.empty()) {
         for (const auto &w : words)
            if (lower(w).rfind(term, 0) == 0 && lower(w) != term) s.suggestions.push_back(w);
         for (const auto &w : words) {
            const std::string lw = lower(w);
            if (lw.rfind(term, 0) != 0 && lw.find(term) != std::string::npos) s.suggestions.push_back(w);
         }
      }
      offered = s.suggestions;
   }

   void decorate(Decorator &d) {
      const int sev = line_severity(d.line);
      if (sev == 0) return;
      const ImVec2 p = ImGui::GetCursorScreenPos();
      ImGui::GetWindowDrawList()->AddText(p, SEVERITY_RGB[sev - 1], SEVERITY_ICON[sev - 1]);
   }
};

std::map<int, std::unique_ptr<editor_t>> editors;
int next_editor = 1;

editor_t *find(int handle) {
   const auto e = editors.find(handle);
   return e == editors.end() ? nullptr : e->second.get();
}

#define ED_FIND(what)                                                                                                  \
   editor_t *e = find(handle);                                                                                         \
   if (!e) return fail(FIG_ERR_STATE, std::string("code_editor_object%") + (what) + ": the editor is not initialized");

// Copy s into buf (up to n bytes); its length.
long long give(const std::string &s, char *buf, long long n) {
   if (buf && n > 0) std::memcpy(buf, s.data(), static_cast<size_t>(std::min<long long>(n, static_cast<long long>(s.size()))));
   return static_cast<long long>(s.size());
}

// ---- the diff --------------------------------------------------------------------------------------------------

struct diff_t {
   TextDiff view;
   std::string left, right, packed;
   int side = -1;
   int last_frame = 0;
};

std::map<ImGuiID, std::unique_ptr<diff_t>> diffs;
constexpr int DIFF_KEEP_FRAMES = 600; // a diff not drawn for this many frames is forgotten

std::vector<std::string_view> lines_of(const std::string &t) {
   std::vector<std::string_view> out;
   size_t a = 0;
   while (true) {
      const size_t b = t.find('\n', a);
      if (b == std::string::npos) {
         out.emplace_back(t.data() + a, t.size() - a);
         break;
      }
      out.emplace_back(t.data() + a, b - a);
      a = b + 1;
   }
   return out;
}

} // namespace

extern "C" {

int fig_editor_create(int *handle) {
   ED_TRY
   *handle = 0;
   auto e = std::make_unique<editor_t>();
   *handle = next_editor++;
   editors[*handle] = std::move(e);
   return FIG_OK;
   ED_CATCH
}

void fig_editor_destroy(int handle) {
   try {
      editors.erase(handle);
   } catch (...) {
   }
}

int fig_editor_language(int handle, const char *packed, int packed_len) {
   ED_TRY
   ED_FIND("init")
   const std::string p = str(packed, packed_len);
   const TextEditor::Language *l = nullptr;
   bool kv = false;
   const int s = language_of(p, &l, &kv);
   if (s != FIG_OK) return s;
   e->packed = p;
   e->key_value = kv;
   e->SetLanguage(l);
   if (!e->words.empty()) e->set_words(e->words); // the word characters follow the language
   return FIG_OK;
   ED_CATCH
}

int fig_editor_set_text(int handle, const char *text, long long len) {
   ED_TRY
   ED_FIND("set_text")
   e->SetText(unix_lines(std::string_view(text ? text : "", static_cast<size_t>(std::max(0LL, len)))));
   e->clear_marks();
   return FIG_OK;
   ED_CATCH
}

// what: 0 the text, 1 the word at the cursor, 2 the selected text, 3 the completions offered (LF-separated).
long long fig_editor_string(int handle, int what, char *buf, long long n) {
   try {
      editor_t *e = find(handle);
      if (!e) return 0;
      switch (what) {
      case 0: return give(e->GetText(), buf, n);
      case 1: return give(e->word_at_cursor(), buf, n);
      case 2: return give(e->MainCursorHasSelection() ? e->GetCursorText(0) : std::string(), buf, n);
      case 3: {
         std::string all;
         for (const auto &w : e->offered) all += (all.empty() ? "" : "\n") + w;
         return give(e->completing() ? all : std::string(), buf, n);
      }
      default: return 0;
      }
   } catch (...) {
      return 0;
   }
}

int fig_editor_draw(int handle, const char *id, int id_len, double width, double height, int *changed) {
   ED_TRY
   *changed = 0;
   ED_FIND("draw")
   if (!ImGui::GetCurrentContext()) return fail(FIG_ERR_STATE, "figure is not initialized");
   if (!ImGui::GetCurrentContext()->WithinFrameScope) return fail(FIG_ERR_STATE, "code editor: no frame open");
   const std::string label = str(id, id_len);
   if (label.empty()) return fail(FIG_ERR_ARGUMENT, "code_editor_object%draw: the id is empty");
   const TextEditor::Palette p = style_palette();
   if (p != e->GetPalette()) e->SetPalette(p);
   const int s = fig_push_font("plex-mono", 9, 0.0); // the fork lays text out on a grid of "#"'s width: monospace
   if (s != FIG_OK) return s;
   const bool ch = e->Render(label.c_str(), ImVec2(static_cast<float>(width), static_cast<float>(height)),
                             ImGuiChildFlags_Borders);
   fig_pop_font();
   e->rect_min = ImGui::GetItemRectMin();
   e->rect_max = ImGui::GetItemRectMax();
   e->drawn = true;
   *changed = ch ? 1 : 0;
   return FIG_OK;
   ED_CATCH
}

int fig_editor_mark(int handle, int line, int severity, const char *message, int message_len) {
   ED_TRY
   ED_FIND("mark")
   if (severity < 1 || severity > N_SEVERITY)
      return fail(FIG_ERR_ARGUMENT, "code_editor_object%mark: severity must be 'error', 'warning' or 'info'");
   if (line < 1) return fail(FIG_ERR_ARGUMENT, "code_editor_object%mark: lines are numbered from 1");
   return e->mark(static_cast<size_t>(line - 1), severity, str(message, message_len));
   ED_CATCH
}

int fig_editor_clear_marks(int handle) {
   ED_TRY
   ED_FIND("clear_marks")
   e->clear_marks();
   return FIG_OK;
   ED_CATCH
}

// The severity of the mark on a line (0 none, 1 error, 2 warning, 3 info) and its message (LF-joined when several).
long long fig_editor_mark_of(int handle, int line, int *severity, char *buf, long long n) {
   try {
      *severity = 0;
      editor_t *e = find(handle);
      if (!e || line < 1) return 0;
      *severity = e->line_severity(static_cast<size_t>(line - 1));
      return give(e->mark_text(static_cast<size_t>(line - 1)), buf, n);
   } catch (...) {
      return 0;
   }
}

int fig_editor_goto(int handle, int line, int column, int focus) {
   ED_TRY
   ED_FIND("goto")
   if (line < 1 || column < 1) return fail(FIG_ERR_ARGUMENT, "code_editor_object%goto: lines and columns are numbered from 1");
   e->SetCursor(TextEditor::DocPos(static_cast<size_t>(line - 1), static_cast<size_t>(column - 1)));
   if (focus) e->SetFocus();
   return FIG_OK;
   ED_CATCH
}

int fig_editor_find(int handle, const char *text, int len, int case_sensitive, int whole_word, int *found) {
   ED_TRY
   *found = 0;
   ED_FIND("find")
   const std::string t = str(text, len);
   if (t.empty()) return fail(FIG_ERR_ARGUMENT, "code_editor_object%find: the text is empty");
   e->SelectNextOccurrenceOf(t, case_sensitive != 0, whole_word != 0);
   if (e->MainCursorHasSelection()) {
      const std::string got = e->GetCursorText(0);
      *found = (case_sensitive ? got == t : lower(got) == lower(t)) ? 1 : 0;
   }
   return FIG_OK;
   ED_CATCH
}

int fig_editor_replace(int handle, const char *what, int what_len, const char *with, int with_len, int case_sensitive,
                       int whole_word, int *count) {
   ED_TRY
   *count = 0;
   ED_FIND("replace")
   const std::string w = str(what, what_len);
   if (w.empty()) return fail(FIG_ERR_ARGUMENT, "code_editor_object%replace: the text is empty");
   if (e->IsReadOnlyEnabled()) return fail(FIG_ERR_STATE, "code_editor_object%replace: the editor is read-only");
   e->SelectAllOccurrencesOf(w, case_sensitive != 0, whole_word != 0);
   if (!e->AllCursorsHaveSelection()) {
      e->ClearCursors();
      return FIG_OK;
   }
   *count = static_cast<int>(e->GetNumberOfCursors());
   e->ReplaceTextInAllCursors(str(with, with_len)); // one transaction: one undo
   e->ClearCursors();
   return FIG_OK;
   ED_CATCH
}

int fig_editor_cursor(int handle, int *line, int *column) {
   ED_TRY
   *line = 1, *column = 1;
   ED_FIND("cursor")
   const auto p = e->GetMainCursorPosition();
   *line = static_cast<int>(p.line) + 1;
   *column = static_cast<int>(p.index) + 1;
   return FIG_OK;
   ED_CATCH
}

int fig_editor_selection(int handle, int *pos, int *has) {
   ED_TRY
   *has = 0;
   ED_FIND("selection")
   const auto s = e->GetMainCursorSelection();
   pos[0] = static_cast<int>(s.start.line) + 1;
   pos[1] = static_cast<int>(s.start.index) + 1;
   pos[2] = static_cast<int>(s.end.line) + 1;
   pos[3] = static_cast<int>(s.end.index) + 1;
   *has = e->MainCursorHasSelection() ? 1 : 0;
   return FIG_OK;
   ED_CATCH
}

int fig_editor_select(int handle, int l0, int c0, int l1, int c1) {
   ED_TRY
   ED_FIND("select")
   if (l0 < 1 || c0 < 1 || l1 < 1 || c1 < 1)
      return fail(FIG_ERR_ARGUMENT, "code_editor_object%select: lines and columns are numbered from 1");
   e->SelectRegion(TextEditor::DocPos(static_cast<size_t>(l0 - 1), static_cast<size_t>(c0 - 1)),
                   TextEditor::DocPos(static_cast<size_t>(l1 - 1), static_cast<size_t>(c1 - 1)));
   return FIG_OK;
   ED_CATCH
}

int fig_editor_insert(int handle, const char *text, long long len) {
   ED_TRY
   ED_FIND("insert")
   if (e->IsReadOnlyEnabled()) return fail(FIG_ERR_STATE, "code_editor_object%insert: the editor is read-only");
   e->ReplaceTextInCurrentCursor(unix_lines(std::string_view(text ? text : "", static_cast<size_t>(std::max(0LL, len)))));
   return FIG_OK;
   ED_CATCH
}

int fig_editor_completions(int handle, const char *words, long long len) {
   ED_TRY
   ED_FIND("set_completions")
   std::vector<std::string> w;
   for (auto &x : split(str(words, len), '\n'))
      if (!x.empty()) w.push_back(x);
   e->set_words(std::move(w));
   return FIG_OK;
   ED_CATCH
}

int fig_editor_completing(int handle, int *active) {
   ED_TRY
   *active = 0;
   ED_FIND("completing")
   *active = e->completing() ? 1 : 0;
   return FIG_OK;
   ED_CATCH
}

// option: 0 read-only, 1 line numbers, 2 tab size, 3 whitespace shown, 4 the current line highlighted. set 1 writes.
int fig_editor_option(int handle, int option, int set, int *value) {
   ED_TRY
   ED_FIND("option")
   switch (option) {
   case 0:
      if (set) e->SetReadOnlyEnabled(*value != 0);
      *value = e->IsReadOnlyEnabled() ? 1 : 0;
      break;
   case 1:
      if (set) e->SetShowLineNumbersEnabled(*value != 0);
      *value = e->IsShowLineNumbersEnabled() ? 1 : 0;
      break;
   case 2:
      if (set) {
         if (*value < 1 || *value > 16) return fail(FIG_ERR_ARGUMENT, "code_editor_object%set_tab_size: in [1, 16]");
         e->SetTabSize(static_cast<size_t>(*value));
      }
      *value = static_cast<int>(e->GetTabSize());
      break;
   case 3:
      if (set) e->SetShowWhitespacesEnabled(*value != 0);
      *value = e->IsShowWhitespacesEnabled() ? 1 : 0;
      break;
   case 4:
      if (set) e->SetShowCurrentLineHighlightEnabled(*value != 0);
      *value = e->IsShowCurrentLineHighlightEnabled() ? 1 : 0;
      break;
   default: return fail(FIG_ERR_ARGUMENT, "code editor: unknown option");
   }
   return FIG_OK;
   ED_CATCH
}

int fig_editor_undo(int handle, int redo, int *done) {
   ED_TRY
   *done = 0;
   ED_FIND(redo ? "redo" : "undo")
   if (redo ? e->CanRedo() : e->CanUndo()) {
      if (redo) e->Redo();
      else e->Undo();
      *done = 1;
   }
   return FIG_OK;
   ED_CATCH
}

int fig_editor_info(int handle, int *lines, int *can_undo, int *can_redo) {
   ED_TRY
   *lines = 0, *can_undo = 0, *can_redo = 0;
   ED_FIND("line_count")
   *lines = static_cast<int>(e->GetLineCount());
   *can_undo = e->CanUndo() ? 1 : 0;
   *can_redo = e->CanRedo() ? 1 : 0;
   return FIG_OK;
   ED_CATCH
}

int fig_editor_focus(int handle) {
   ED_TRY
   ED_FIND("focus")
   e->SetFocus();
   return FIG_OK;
   ED_CATCH
}

int fig_editor_line_rect(int handle, int line, float *rect, int *visible) {
   ED_TRY
   *visible = 0;
   ED_FIND("line_rect")
   if (line < 1) return fail(FIG_ERR_ARGUMENT, "code_editor_object%line_rect: lines are numbered from 1");
   *visible = e->line_rect(static_cast<size_t>(line - 1), rect) ? 1 : 0;
   return FIG_OK;
   ED_CATCH
}

int fig_code_diff(const char *id, int id_len, const char *left, long long left_len, const char *right,
                  long long right_len, const char *packed, int packed_len, int side_by_side, double width,
                  double height) {
   ED_TRY
   if (!ImGui::GetCurrentContext()) return fail(FIG_ERR_STATE, "figure is not initialized");
   if (!ImGui::GetCurrentContext()->WithinFrameScope) return fail(FIG_ERR_STATE, "code editor: no frame open");
   const std::string label = str(id, id_len);
   if (label.empty()) return fail(FIG_ERR_ARGUMENT, "code_diff: the id is empty");
   const ImGuiID key = ImGui::GetID(label.c_str());
   auto &slot = diffs[key];
   if (!slot) {
      slot = std::make_unique<diff_t>();
      slot->view.SetShowWhitespacesEnabled(false); // as the editor
   }
   diff_t &d = *slot;
   const int frame = ImGui::GetFrameCount();
   d.last_frame = frame;
   const std::string l = unix_lines(std::string_view(left ? left : "", static_cast<size_t>(std::max(0LL, left_len))));
   const std::string r = unix_lines(std::string_view(right ? right : "", static_cast<size_t>(std::max(0LL, right_len))));
   const std::string p = str(packed, packed_len);
   if (p != d.packed || d.side < 0) {
      const TextEditor::Language *lang = nullptr;
      bool kv = false;
      const int s = language_of(p, &lang, &kv);
      if (s != FIG_OK) return s;
      d.view.SetLanguage(lang);
      d.packed = p;
      d.side = -1; // the text set again below (the colours follow the language)
   }
   if (d.side != side_by_side || l != d.left || r != d.right) {
      d.left = l;
      d.right = r;
      d.side = side_by_side;
      d.view.SetSideBySideMode(side_by_side != 0);
      d.view.SetText(d.left, d.right);
   }
   const TextEditor::Palette pal = style_palette();
   if (pal != d.view.GetPalette()) d.view.SetPalette(pal);
   const int s = fig_push_font("plex-mono", 9, 0.0);
   if (s != FIG_OK) return s;
   d.view.Render(label.c_str(), ImVec2(static_cast<float>(width), static_cast<float>(height)), ImGuiChildFlags_Borders);
   fig_pop_font();
   for (auto it = diffs.begin(); it != diffs.end();) // forget the diffs no longer drawn
      it = frame - it->second->last_frame > DIFF_KEEP_FRAMES ? diffs.erase(it) : std::next(it);
   return FIG_OK;
   ED_CATCH
}

// The lines of right added and of left removed (from 1), by the diff's algorithm: counts in n_added, n_removed; up to
// cap of each written. No Dear ImGui: a task may call it.
int fig_code_diff_lines(const char *left, long long left_len, const char *right, long long right_len, int *added,
                        int *n_added, int *removed, int *n_removed, int cap) {
   ED_TRY
   *n_added = 0, *n_removed = 0;
   const std::string l = unix_lines(std::string_view(left ? left : "", static_cast<size_t>(std::max(0LL, left_len))));
   const std::string r = unix_lines(std::string_view(right ? right : "", static_cast<size_t>(std::max(0LL, right_len))));
   const auto a = lines_of(l), b = lines_of(r);
   dtl::Diff<std::string_view> difference(a, b);
   difference.compose();
   int li = 0, ri = 0;
   for (const auto &[text, info] : difference.getSes().getSequence()) {
      switch (info.type) {
      case dtl::SES_COMMON: ++li, ++ri; break;
      case dtl::SES_ADD:
         ++ri;
         if (*n_added < cap && added) added[*n_added] = ri;
         ++*n_added;
         break;
      case dtl::SES_DELETE:
         ++li;
         if (*n_removed < cap && removed) removed[*n_removed] = li;
         ++*n_removed;
         break;
      }
   }
   return FIG_OK;
   ED_CATCH
}

} // extern "C"
