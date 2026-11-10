// FIGURE's usage checks: the scope record of the frame (see figure_native.h, "Usage checks", and errors.md).
//
// Every begin/end and push/pop pair FIGURE wraps registers here: a begin (after Dear ImGui's or ImPlot's own) opens an
// entry (its kind, the Fortran procedure, its label, what the begin returned, and the sizes of Dear ImGui's stacks it
// left); an end (before Dear ImGui's) is checked against the record first. A wrong end never reaches Dear ImGui, whose
// answer to it is an assertion that names no Fortran call. Scopes still open when the frame ends are closed here, in
// reverse order, and reported by the next app%next_frame. The sizes of Dear ImGui's stacks are compared with what each
// scope left at its begin, so calls made through the raw bindings that leave something open inside a scope are caught
// too (and repaired by Dear ImGui's error recovery). Main thread only: the entry points refuse a task first.
#include "figure_native.h"

#include "imgui.h"
#include "imgui_internal.h"
#include "implot.h"
#include "implot_internal.h"

#include <string>
#include <vector>

namespace {

// Kinds: must match the SCOPE_* parameters of src/lib/figure_base.F90.
enum kind_t {
   K_WINDOW = 1, K_CHILD, K_TAB_BAR, K_TAB, K_TABLE, K_TREE, K_MAIN_MENU_BAR, K_MENU_BAR, K_MENU, K_POPUP, K_PLOT,
   K_SUBPLOTS, K_DOCK_LAYOUT, K_ID, K_DISABLED, K_FONT, K_STYLE_COLOR, K_STYLE_VAR, K_COUNT
};

struct kind_info_t {
   const char *opener;  // the Fortran procedure that opens it (the usual one)
   const char *closer;  // ... and the one that closes it
   bool        nests;   // containers and id scopes: an end closes the innermost of them
   bool        true_only; // "end only after a true begin" (else: always paired)
   bool        window;  // a Dear ImGui window: what was opened inside it must be closed before it (fonts, disabled)
};

const kind_info_t KINDS[K_COUNT] = {
   {"", "", false, false, false},
   {"ig_begin", "ig_end", true, false, true},
   {"ig_begin_child", "ig_end_child", true, false, true},
   {"ig_begin_tab_bar", "ig_end_tab_bar", true, true, false},
   {"ig_begin_tab", "ig_end_tab", true, true, false},
   {"ig_begin_table", "ig_end_table", true, true, false},
   {"ig_tree_node", "ig_tree_pop", true, true, false},
   {"ig_begin_main_menu_bar", "ig_end_main_menu_bar", true, true, true},
   {"ig_begin_menu_bar", "ig_end_menu_bar", true, true, false},
   {"ig_begin_menu", "ig_end_menu", true, true, true},
   {"ig_begin_popup", "ig_end_popup", true, true, true},
   {"ip_begin_plot", "ip_end_plot", true, true, false},
   {"ip_begin_subplots", "ip_end_subplots", true, true, false},
   {"ig_dock_layout_begin", "ig_dock_layout_end", true, true, false},
   {"ig_push_id", "ig_pop_id", true, false, false},
   {"ig_begin_disabled", "ig_end_disabled", false, false, false},
   {"ig_push_font", "ig_pop_font", false, false, false},
   {"ig_push_style_color", "ig_pop_style_color", false, false, false},
   {"ig_push_style_var", "ig_pop_style_var", false, false, false},
};

constexpr int CHECKS_ABORT = 0, CHECKS_REPORT = 1, CHECKS_RECOVER = 2;
constexpr size_t ERRORS_KEPT = 20; // messages kept per report; the others are counted

// What Dear ImGui's and ImPlot's stacks held when a scope began (after its begin), or when the frame began.
struct sizes_t {
   ImGuiErrorRecoveryState s;
   ImGuiTable             *table = nullptr;
   ImGuiTabBar            *tab_bar = nullptr;
   ImPlotPlot             *plot = nullptr;
   ImPlotSubplot          *subplot = nullptr;
};

struct entry_t {
   int         kind = 0;
   std::string who;      // the opener, when not the kind's usual one (ig_begin_side_bar, ig_begin_popup_modal, ip_*)
   std::string label;
   bool        returned = true;
   int         aux = 0;  // an integer id (ig_push_id), the dock id of a dock layout: the label when it is empty
   sizes_t     sizes;    // nesting kinds only
};

struct false_begin_t {
   bool        valid = false;
   std::string who, label;
   int         aux = 0;
   size_t      depth = 0; // nesting entries open when it returned false
};

struct state_t {
   int                        mode = CHECKS_REPORT;
   std::vector<entry_t>       stack;
   std::vector<std::string>   errors;  // since the last frame boundary
   std::vector<std::string>   pending; // for the next fig_scope_report
   size_t                     dropped = 0; // errors not kept
   false_begin_t              last_false[K_COUNT];
   sizes_t                    base;    // at the frame's begin
   bool                       muted = false; // Dear ImGui's error callback ignored (FIGURE's own recovery)
   std::string                last_notified;
} sc;

bool in_frame() {
   const ImGuiContext *g = ImGui::GetCurrentContext();
   return g && g->WithinFrameScope;
}

sizes_t take_sizes() {
   sizes_t z;
   ImGui::ErrorRecoveryStoreState(&z.s);
   ImGuiContext &g = *GImGui;
   z.table = g.CurrentTable;
   z.tab_bar = g.CurrentTabBar;
   if (ImPlot::GetCurrentContext()) {
      z.plot = GImPlot->CurrentPlot;
      z.subplot = GImPlot->CurrentSubplot;
   }
   return z;
}

// The stacks that hold more now than in `then` (or another table, tab bar, plot): Dear ImGui's names, comma separated.
std::string grown(const sizes_t &then, int kind) {
   const sizes_t now = take_sizes();
   std::string out;
   auto add = [&](const char *name, int a, int b) {
      if (a <= b) return;
      if (!out.empty()) out += ", ";
      out += std::string(name) + " " + std::to_string(a) + " (" + std::to_string(b) + " expected)";
   };
   add("windows", now.s.SizeOfWindowStack, then.s.SizeOfWindowStack);
   if (now.s.SizeOfWindowStack == then.s.SizeOfWindowStack) { // the same window: its own stacks compare
      if (kind != K_PLOT && kind != K_SUBPLOTS) // ImPlot pushes an id of its own at a plot's first item
         add("ids", now.s.SizeOfIDStack, then.s.SizeOfIDStack);
      add("tree depth", now.s.SizeOfTreeStack, then.s.SizeOfTreeStack);
   }
   add("colours", now.s.SizeOfColorStack, then.s.SizeOfColorStack);
   add("style variables", now.s.SizeOfStyleVarStack, then.s.SizeOfStyleVarStack);
   add("focus scopes", now.s.SizeOfFocusScopeStack, then.s.SizeOfFocusScopeStack);
   add("groups", now.s.SizeOfGroupStack, then.s.SizeOfGroupStack);
   add("popups", now.s.SizeOfBeginPopupStack, then.s.SizeOfBeginPopupStack);
   if (kind == 0 || KINDS[kind].window) { // fonts and disabled blocks may outlive a scope that is not a window
      add("fonts", now.s.SizeOfFontStack, then.s.SizeOfFontStack);
      add("item flags", now.s.SizeOfItemFlagsStack, then.s.SizeOfItemFlagsStack);
      add("disabled blocks", now.s.SizeOfDisabledStack, then.s.SizeOfDisabledStack);
   }
   auto other = [&](const char *name, bool differs) {
      if (!differs) return;
      if (!out.empty()) out += ", ";
      out += std::string("another ") + name + " current";
   };
   other("table", now.table != then.table);
   other("tab bar", now.tab_bar != then.tab_bar);
   other("plot", now.plot != then.plot);
   other("subplot figure", now.subplot != then.subplot);
   return out;
}

// Back to `then`: Dear ImGui's error recovery (windows, then the current window's stacks), an ImPlot plot ended.
void recover_to(const sizes_t &then) {
   ImGuiIO   &io = ImGui::GetIO();
   const bool asserts = io.ConfigErrorRecoveryEnableAssert; // FIGURE's own repair: no assertion ('abort' included)
   io.ConfigErrorRecoveryEnableAssert = false;
   sc.muted = true;
   if (ImPlot::GetCurrentContext() && GImPlot->CurrentPlot && !then.plot) ImPlot::EndPlot();
   if (ImPlot::GetCurrentContext() && GImPlot->CurrentSubplot && !then.subplot) ImPlot::EndSubplots();
   if (GImGui->CurrentWindowStack.Size > then.s.SizeOfWindowStack)
      ImGui::ErrorRecoveryTryToRecoverState(&then.s);
   else
      ImGui::ErrorRecoveryTryToRecoverWindowState(&then.s);
   sc.muted = false;
   io.ConfigErrorRecoveryEnableAssert = asserts;
}

const char *opener_of(const entry_t &e) { return e.who.empty() ? KINDS[e.kind].opener : e.who.c_str(); }

std::string closer_of(const entry_t &e) {
   if ((e.kind == K_STYLE_COLOR || e.kind == K_STYLE_VAR) && e.who.rfind("ip_", 0) == 0)
      return std::string("ip_") + (KINDS[e.kind].closer + 3);
   return KINDS[e.kind].closer;
}

// A call as the program wrote it: opener('label'), opener(7) for an integer id or a dock id, opener() without label.
std::string call_text(int kind, const char *opener, const std::string &label, int aux) {
   if (!label.empty()) return std::string(opener) + "('" + label + "')";
   if (kind == K_ID || kind == K_DOCK_LAYOUT) return std::string(opener) + "(" + std::to_string(aux) + ")";
   return std::string(opener) + "()";
}

std::string named(const entry_t &e) {
   std::string s = call_text(e.kind, opener_of(e), e.label, e.aux);
   if (!KINDS[e.kind].true_only && !e.returned) s += " (it returned false)";
   return s;
}

std::string kind_openers(int kind) {
   if (kind == K_STYLE_COLOR) return "ig_push_style_color or ip_push_style_color";
   if (kind == K_STYLE_VAR) return "ig_push_style_var or ip_push_style_var";
   if (kind == K_WINDOW) return "ig_begin or ig_begin_side_bar";
   if (kind == K_POPUP) return "ig_begin_popup or ig_begin_popup_modal";
   return KINDS[kind].opener;
}

// A usage error: kept for the report (when the call has no stat of its own) and the last error. Returns what the
// Fortran side does: 1 return at once (refused, or stat set), 2 stop the program ('abort', no stat).
int usage_error(const std::string &msg, int has_stat) {
   fig_set_last_error(msg.c_str(), static_cast<int>(msg.size()));
   if (has_stat) return 1;
   if (sc.mode == CHECKS_ABORT) return 2;
   if (sc.errors.size() + sc.pending.size() < ERRORS_KEPT)
      sc.errors.push_back(msg);
   else
      ++sc.dropped;
   return 1;
}

// Dear ImGui's error callback (an error it detects itself: raw calls FIGURE does not see).
void on_imgui_error(ImGuiContext *, void *, const char *msg) {
   if (sc.muted) return;
   usage_error(std::string("Dear ImGui: ") + msg, 0);
}

// Close what the entry opened, as its end would (Dear ImGui's or ImPlot's end, FIGURE's style pop).
void close_entry(const entry_t &e) {
   switch (e.kind) {
   case K_WINDOW: ImGui::End(); break;
   case K_CHILD: ImGui::EndChild(); break;
   case K_TAB_BAR: ImGui::EndTabBar(); break;
   case K_TAB: ImGui::EndTabItem(); break;
   case K_TABLE: ImGui::EndTable(); break;
   case K_TREE: ImGui::TreePop(); break;
   case K_MAIN_MENU_BAR: ImGui::EndMainMenuBar(); break;
   case K_MENU_BAR: ImGui::EndMenuBar(); break;
   case K_MENU: ImGui::EndMenu(); break;
   case K_POPUP: ImGui::EndPopup(); break;
   case K_PLOT: ImPlot::EndPlot(); break;
   case K_SUBPLOTS: ImPlot::EndSubplots(); break;
   case K_DOCK_LAYOUT: ImGui::DockBuilderFinish(static_cast<ImGuiID>(static_cast<unsigned int>(e.aux))); break;
   case K_ID: ImGui::PopID(); break;
   case K_DISABLED: ImGui::EndDisabled(); break;
   case K_FONT: ImGui::PopFont(); break;
   case K_STYLE_COLOR: fig_pop_style(0, 1); break;
   case K_STYLE_VAR: fig_pop_style(1, 1); break;
   default: break;
   }
}

// Close the entries from `i` up, newest first, raw leftovers inside each recovered first. keep_style: the style
// colours and variables stay open (they belong to the frame, not to a scope: 'recover' closing missing ends).
void close_from(size_t i, bool keep_style = false) {
   for (size_t j = sc.stack.size(); j-- > i;) {
      const entry_t e = sc.stack[j];
      if (keep_style && (e.kind == K_STYLE_COLOR || e.kind == K_STYLE_VAR)) continue;
      sc.stack.erase(sc.stack.begin() + static_cast<std::ptrdiff_t>(j));
      if (KINDS[e.kind].nests && !grown(e.sizes, e.kind).empty()) recover_to(e.sizes);
      sc.muted = true;
      close_entry(e);
      sc.muted = false;
   }
}

// The innermost nesting entry (fonts, disabled blocks and style changes skipped); npos when none.
size_t innermost() {
   for (size_t i = sc.stack.size(); i-- > 0;)
      if (KINDS[sc.stack[i].kind].nests) return i;
   return std::string::npos;
}

size_t nesting_open() {
   size_t n = 0;
   for (const entry_t &e : sc.stack) n += KINDS[e.kind].nests ? 1 : 0;
   return n;
}

} // namespace

extern "C" {

int fig_set_checks(int mode) {
   if (mode < CHECKS_ABORT || mode > CHECKS_RECOVER) {
      static const char msg[] = "app%set_checks: mode must be 'abort', 'report' or 'recover'";
      fig_set_last_error(msg, static_cast<int>(sizeof(msg) - 1));
      return FIG_ERR_ARGUMENT;
   }
   sc.mode = mode;
   return FIG_OK;
}

int fig_checks(void) { return sc.mode; }

int fig_draw_refuse(const char *who, int who_len, int has_stat) {
   if (fig_task_refuse(who, who_len)) return 1; // a task does not draw
   if (in_frame()) return 0;
   try {
      return usage_error(std::string(who, who_len > 0 ? static_cast<size_t>(who_len) : 0) + ": no frame open", has_stat);
   } catch (...) {
      return 1;
   }
}

void fig_scope_open(int kind, const char *who, int who_len, const char *label, int label_len, int returned, int aux) {
   if (kind <= 0 || kind >= K_COUNT || !in_frame()) return;
   try {
      const kind_info_t &k = KINDS[kind];
      const std::string w(who, who_len > 0 ? static_cast<size_t>(who_len) : 0);
      if (k.true_only && !returned) { // nothing to end: remembered for the message of a wrong end
         false_begin_t &f = sc.last_false[kind];
         f.valid = true;
         f.who = w;
         f.label.assign(label, label_len > 0 ? static_cast<size_t>(label_len) : 0);
         f.aux = aux;
         f.depth = nesting_open();
         return;
      }
      entry_t e;
      e.kind = kind;
      if (w != k.opener) e.who = w;
      e.label.assign(label, label_len > 0 ? static_cast<size_t>(label_len) : 0);
      e.returned = returned != 0;
      e.aux = aux;
      if (k.nests) e.sizes = take_sizes();
      sc.stack.push_back(std::move(e));
   } catch (...) {
   }
}

int fig_scope_close(int kind, const char *who, int who_len, int n, int has_stat) {
   if (fig_task_refuse(who, who_len)) return 1; // a task does not draw
   try {
      const std::string w(who, who_len > 0 ? static_cast<size_t>(who_len) : 0);
      if (!in_frame()) return usage_error(w + ": no frame open", has_stat);
      if (kind <= 0 || kind >= K_COUNT) return 0;
      const kind_info_t &k = KINDS[kind];
      if (!k.nests) { // the newest pushes of this kind, wherever they were made
         size_t open = 0;
         for (const entry_t &e : sc.stack) open += e.kind == kind ? 1 : 0;
         if (n < 1) n = 1;
         if (open < static_cast<size_t>(n)) {
            const std::string what = n == 1 ? std::string("no ") + kind_openers(kind) + " is open"
                                            : std::to_string(n) + " pops for " + std::to_string(open) + " open " +
                                                 kind_openers(kind);
            return usage_error(w + ": " + what, has_stat);
         }
         for (int m = 0; m < n; ++m)
            for (size_t i = sc.stack.size(); i-- > 0;)
               if (sc.stack[i].kind == kind) {
                  sc.stack.erase(sc.stack.begin() + static_cast<std::ptrdiff_t>(i));
                  break;
               }
         return 0;
      }
      const size_t top = innermost();
      if (top != std::string::npos && sc.stack[top].kind == kind) {
         const entry_t &e = sc.stack[top];
         int action = 0;
         std::string msg;
         if (k.window) { // fonts and disabled blocks opened inside it: Dear ImGui's End requires them closed
            for (size_t i = sc.stack.size(); i-- > top + 1;) {
               const entry_t &l = sc.stack[i];
               if (l.kind != K_FONT && l.kind != K_DISABLED) continue;
               msg = w + ": " + named(l) + " is still open inside " + named(e) + " (close it with " + closer_of(l) +
                     " before " + w + ")";
               action = usage_error(msg, 0);
               if (action == 2) return 2;
               close_entry(l);
               sc.stack.erase(sc.stack.begin() + static_cast<std::ptrdiff_t>(i));
            }
         }
         const std::string left = grown(e.sizes, kind);
         if (!left.empty()) { // calls outside FIGURE (raw bindings) left something open inside this scope
            action = usage_error(w + ": Dear ImGui holds " + left + " inside " + named(e) +
                                    ": a call outside FIGURE (a raw binding) did not close what it opened",
                                 0);
            if (action == 2) return 2;
            recover_to(e.sizes);
         }
         sc.stack.erase(sc.stack.begin() + static_cast<std::ptrdiff_t>(top));
         sc.last_false[kind].valid = false;
         return 0;
      }
      false_begin_t &f = sc.last_false[kind];
      if (f.valid && f.depth == nesting_open()) { // the begin of this level returned false
         f.valid = false;
         return usage_error(w + ": " + call_text(kind, f.who.c_str(), f.label, f.aux) +
                               " returned false (end only after a true begin)",
                            has_stat);
      }
      if (top == std::string::npos)
         return usage_error(w + ": no " + kind_openers(kind) + " is open (no scope is open)", has_stat);
      const entry_t &e = sc.stack[top];
      size_t mine = std::string::npos; // the innermost open entry of this kind, below the innermost one
      for (size_t i = top; i-- > 0;)
         if (sc.stack[i].kind == kind) {
            mine = i;
            break;
         }
      if (mine == std::string::npos)
         return usage_error(w + ": no " + kind_openers(kind) + " is open; the open scope is " + named(e) +
                               " (closed by " + closer_of(e) + ")",
                            has_stat);
      const int action = usage_error(w + ": the open scope is " + named(e) + " (close it with " + closer_of(e) +
                                        " before " + w + ")",
                                     has_stat);
      if (action != 1 || sc.mode != CHECKS_RECOVER || has_stat) return action;
      // recover: what was opened after it is closed, then this end goes on
      const sizes_t sizes = sc.stack[mine].sizes;
      close_from(mine + 1, true);
      sc.stack.erase(sc.stack.begin() + static_cast<std::ptrdiff_t>(mine));
      if (!grown(sizes, kind).empty()) recover_to(sizes);
      return 0;
   } catch (...) {
      return 1;
   }
}

int fig_scope_report(int *notify) {
   *notify = 0;
   try {
      if (sc.pending.empty() && sc.dropped == 0) return FIG_OK;
      std::string msg;
      for (const std::string &m : sc.pending) msg += (msg.empty() ? "" : "\n") + m;
      if (sc.dropped > 0) msg += "\n(and " + std::to_string(sc.dropped) + " more)";
      sc.pending.clear();
      sc.dropped = 0;
      fig_set_last_error(msg.c_str(), static_cast<int>(msg.size()));
      if (sc.mode != CHECKS_RECOVER) return FIG_ERR_STATE;
      if (msg != sc.last_notified) *notify = 1; // the same errors every frame: one notification
      sc.last_notified = msg;
      return FIG_OK;
   } catch (...) {
      return FIG_ERR_EXCEPTION;
   }
}

void fig_scope_frame_begin(void) {
   try {
      for (std::string &m : sc.errors) sc.pending.push_back(std::move(m)); // made between frames
      sc.errors.clear();
      sc.stack.clear();
      for (false_begin_t &f : sc.last_false) f.valid = false;
      ImGuiIO &io = ImGui::GetIO();
      io.ConfigErrorRecovery = true;
      io.ConfigErrorRecoveryEnableAssert = sc.mode == CHECKS_ABORT; // 'abort': Dear ImGui's own assertions stay
      io.ConfigErrorRecoveryEnableTooltip = false;
      io.ConfigErrorRecoveryEnableDebugLog = false;
      GImGui->ErrorCallback = on_imgui_error;
      GImGui->ErrorCallbackUserData = nullptr;
      sc.base = take_sizes();
   } catch (...) {
   }
}

void fig_scope_frame_end(void) {
   try {
      for (size_t i = sc.stack.size(); i-- > 0;) {
         const entry_t &e = sc.stack[i];
         const std::string msg = "app%next_frame: " + named(e) + " is still open (close it with " + closer_of(e) + ")";
         if (sc.errors.size() + sc.pending.size() < ERRORS_KEPT)
            sc.errors.push_back(msg);
         else
            ++sc.dropped;
      }
      close_from(0);
      const std::string left = grown(sc.base, 0);
      if (!left.empty()) {
         const std::string msg = "app%next_frame: Dear ImGui holds " + left +
                                 " at the end of the frame: a call outside FIGURE (a raw binding) did not close what "
                                 "it opened";
         if (sc.errors.size() + sc.pending.size() < ERRORS_KEPT)
            sc.errors.push_back(msg);
         else
            ++sc.dropped;
         recover_to(sc.base);
      }
      for (std::string &m : sc.errors) sc.pending.push_back(std::move(m));
      sc.errors.clear();
   } catch (...) {
   }
}

void fig_scope_reset(void) {
   sc.stack.clear();
   sc.errors.clear();
   sc.pending.clear();
   sc.dropped = 0;
   sc.mode = CHECKS_REPORT;
   sc.last_notified.clear();
   for (false_begin_t &f : sc.last_false) f.valid = false;
}

} // extern "C"
