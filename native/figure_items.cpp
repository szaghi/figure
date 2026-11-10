// FIGURE's table of the items Dear ImGui drew, for figure_testing's paths (`Window/Label`, `//Window`, `##id`, `*`).
//
// Dear ImGui calls two hooks for every item it registers when it is compiled with IMGUI_ENABLE_TEST_ENGINE and
// g.TestEngineHookItems is true: ImGuiTestEngineHook_ItemAdd (id, rectangle) and ImGuiTestEngineHook_ItemInfo (label,
// status: checkable, checked, openable, opened, inputable). They are declared by Dear ImGui (imgui_internal.h, MIT) and
// implemented here by FIGURE; no imgui_test_engine code is used (its licence). With the hooks off (every program that
// does not record items) each registration costs one test of a boolean.
//
// The records of one frame form a table (`building`); when the next frame begins it becomes the last frame's
// (`last`), and the text that frame drew is read from its draw lists (glyph quads matched to the font atlas): the
// value an item shows. Queries read the last frame only. The table is shaped as an accessibility tree would want it
// (role, name, value, rectangle, state, parent), so a layer such as AccessKit could read it later.
//
// Main thread only, as Dear ImGui.
#include "figure_items.h"
#include "figure_native.h"

#include "imgui.h"
#include "imgui_internal.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <string>
#include <unordered_map>
#include <vector>

namespace {

using figure_items::found_t;

// One item (or window) registered in a frame.
struct record_t {
   ImGuiID           id = 0;          // its id; a window's: the key it is found by (a popup's: the item that opened it)
   ImGuiID           parent = 0;      // a window: the seed it hangs from (raw, aliased when the tree is built); 0 root
   ImGuiID           raw = 0;         // a window: its own id, the seed its items are hashed from
   ImRect            rect, clip;      // its rectangle and its window's clip rectangle [pixels]
   const ImDrawList *dl = nullptr;    // its window's draw list (its text)
   unsigned          stack_at = 0, stack_n = 0; // its window's ID stack when it was added (pool `ids`)
   unsigned          label_at = 0, label_n = 0; // Dear ImGui's label; a window's full name (pool `chars`)
   unsigned          name_at = 0, name_n = 0;   // an accessible name: a window's shown name, a widget's own label
   int               status = 0;      // ImGuiItemStatusFlags of ItemInfo
   int               role = figure_items::R_OTHER;
   bool              info = false;    // ItemInfo seen (a label and a status)
   bool              visible = false; // in its window's clip rectangle, the window shown
   bool              disabled = false;
   bool              tooltip = false; // a tooltip or a shortcut's tooltip
   bool              window = false;
};

// A glyph the frame drew.
struct glyph_t {
   const ImDrawList *dl;
   float             pen, end, cy, height, space; // pen position, after its advance, centre, line height, space advance
   float             x0, y0, x1, y1;              // its quad
   unsigned          cp;
};

struct table_t {
   std::vector<record_t> items;
   std::vector<ImGuiID>  ids;
   std::string           chars;
   std::vector<glyph_t>  glyphs;
   void clear() {
      items.clear();
      ids.clear();
      chars.clear();
      glyphs.clear();
   }
   std::string label(const record_t &r) const { return chars.substr(r.label_at, r.label_n); }
   std::string name(const record_t &r) const { return chars.substr(r.name_at, r.name_n); }
};

table_t building, last;
bool    want_recording = false; // asked before a context existed

// ItemInfo before its ItemAdd (a tab registers its label first): applied when the item is added.
struct pending_t {
   ImGuiID     id = 0;
   std::string label;
   int         flags = 0;
} pending;

// The last frame's records as a tree: windows, items, and the seeds of the ID stack between them (PushID, a table, a
// tab bar, a menu bar), each by its key.
struct node_t {
   ImGuiID          key = 0, parent = 0;
   ImGuiID          seeds[2] = {0, 0}; // what its children's ids are hashed from (itself; a popup window it opened)
   int              rec = -1;          // its record; -1: a seed of the ID stack only
   int              dups = 0;          // more records with the same id (an id conflict)
   std::vector<int> children;
};
struct tree_t {
   bool                            built = false;
   std::vector<node_t>             nodes;
   std::unordered_map<ImGuiID, int> by_key;
   std::unordered_map<ImGuiID, ImGuiID> alias; // a popup window's own id -> its key
   std::vector<int>                roots, windows;
   void clear() {
      built = false;
      nodes.clear();
      by_key.clear();
      alias.clear();
      roots.clear();
      windows.clear();
   }
} tree;

ImGuiContext *ctx() { return ImGui::GetCurrentContext(); }

unsigned append(std::string &pool, const char *s, size_t n) {
   const unsigned at = static_cast<unsigned>(pool.size());
   pool.append(s, n);
   return at;
}

// Dear ImGui's shown part of a label: up to its first "##".
std::string visible_part(const std::string &l) {
   const size_t p = l.find("##");
   return p == std::string::npos ? l : l.substr(0, p);
}

// The id part of a label: from its first "##" ("##id", "###id"); empty without one.
std::string id_part(const std::string &l) {
   const size_t p = l.find("##");
   return p == std::string::npos ? std::string() : l.substr(p);
}

// The name a window is shown by: a menu's label, a child window's own name, the visible part of the others.
std::string window_shown_name(const ImGuiWindow *w) {
   std::string n = w->Name;
   if ((w->Flags & ImGuiWindowFlags_ChildWindow) && !(w->Flags & ImGuiWindowFlags_Popup)) {
      // BeginChild names its window "<parent>/<name>_<8 hex digits>"
      const size_t slash = n.rfind('/');
      if (slash != std::string::npos) n = n.substr(slash + 1);
      if (n.size() > 9 && n[n.size() - 9] == '_') n = n.substr(0, n.size() - 9);
      return n;
   }
   const std::string v = visible_part(n);
   return v.empty() ? n : v;
}

int find_building(ImGuiID id) {
   for (int i = static_cast<int>(building.items.size()) - 1, k = 0; i >= 0 && k < 256; --i, ++k)
      if (building.items[i].id == id && !building.items[i].window) return i;
   return -1;
}

// ---- The tree of the last frame ---------------------------------------------------------------------------------------

ImGuiID unalias(ImGuiID s) {
   const auto a = tree.alias.find(s);
   return a == tree.alias.end() ? s : a->second;
}

int node_of(ImGuiID key) {
   const auto n = tree.by_key.find(key);
   return n == tree.by_key.end() ? -1 : n->second;
}

int add_node(ImGuiID key, ImGuiID parent, int rec) {
   node_t n;
   n.key = key;
   n.parent = parent;
   n.seeds[0] = key;
   n.rec = rec;
   tree.nodes.push_back(n);
   const int i = static_cast<int>(tree.nodes.size()) - 1;
   tree.by_key[key] = i;
   return i;
}

// The seed an item hangs from: the top of its ID stack, below itself (a menu pushes its own id before its item).
ImGuiID item_parent(const record_t &r) {
   const ImGuiID *s = last.ids.data() + r.stack_at;
   for (unsigned k = r.stack_n; k-- > 0;)
      if (s[k] != r.id) return unalias(s[k]);
   return 0;
}

void build_tree() {
   if (tree.built) return;
   tree.clear();
   tree.built = true;
   // the windows' keys first: the items of a popup hang from the item that opened it
   for (const record_t &r : last.items)
      if (r.window && r.raw != r.id) tree.alias[r.raw] = r.id;
   // items, by id (a second record with an id: a conflict)
   for (int i = 0; i < static_cast<int>(last.items.size()); ++i) {
      const record_t &r = last.items[i];
      if (r.window) continue;
      const int n = node_of(r.id);
      if (n < 0) {
         add_node(r.id, item_parent(r), i);
      } else if (tree.nodes[n].rec >= 0) {
         const record_t &o = last.items[tree.nodes[n].rec];
         if (o.rect.Min.x != r.rect.Min.x || o.rect.Min.y != r.rect.Min.y || o.rect.Max.x != r.rect.Max.x ||
             o.rect.Max.y != r.rect.Max.y)
            ++tree.nodes[n].dups;
      }
   }
   // windows: a node of their own, or the item that opened them (a menu, a combo, an item's context menu)
   for (int i = 0; i < static_cast<int>(last.items.size()); ++i) {
      const record_t &r = last.items[i];
      if (!r.window) continue;
      int n = node_of(r.id);
      if (n < 0) {
         n = add_node(r.id, unalias(r.parent), i);
      } else if (tree.nodes[n].rec < 0) {
         tree.nodes[n].rec = i;
         tree.nodes[n].parent = unalias(r.parent);
      }
      if (r.raw != r.id) tree.nodes[n].seeds[1] = r.raw;
      tree.windows.push_back(i);
   }
   // the seeds of the ID stacks between a window and its items
   for (const record_t &r : last.items) {
      if (r.window || r.stack_n == 0) continue;
      const ImGuiID *s = last.ids.data() + r.stack_at;
      for (unsigned k = 1; k < r.stack_n; ++k) {
         const ImGuiID key = unalias(s[k]);
         if (key != r.id && node_of(key) < 0) add_node(key, unalias(s[k - 1]), -1);
      }
      if (node_of(unalias(s[0])) < 0) add_node(unalias(s[0]), 0, -1); // a window not registered (a tooltip's)
   }
   for (int i = 0; i < static_cast<int>(tree.nodes.size()); ++i) {
      node_t &n = tree.nodes[i];
      if (n.parent == 0) {
         tree.roots.push_back(i);
         continue;
      }
      int p = node_of(n.parent);
      if (p < 0) { // a seed no stack shows (a popup opened from a seed): a root of its own
         p = add_node(n.parent, 0, -1);
         tree.roots.push_back(p);
      }
      if (p != i) tree.nodes[p].children.push_back(i);
   }
}

const record_t *rec_of(const node_t &n) { return n.rec >= 0 ? &last.items[n.rec] : nullptr; }

// A level a path may skip: a seed of the ID stack, or an item with no label (a tab bar, a table: their ids are seeds).
bool anonymous(const node_t &n) {
   const record_t *r = rec_of(n);
   return !r || (!r->window && !r->info && r->name_n == 0);
}

bool matches_record(const record_t *r, const std::string &seg) {
   const std::string l = last.label(*r), nm = last.name(*r);
   if (r->window) {
      if (seg == l || seg == nm || (!visible_part(l).empty() && seg == visible_part(l))) return true;
      const std::string id = id_part(l);
      if (!id.empty() && (seg == id || (id.rfind("###", 0) == 0 && seg == id.substr(1)))) return true;
      return false;
   }
   if (!r->info && nm.empty()) return false;
   if (seg == l) return true;
   if (!nm.empty() && seg == nm) return true;
   const std::string v = visible_part(l);
   if (!v.empty() && seg == v) return true;
   const std::string id = id_part(l);
   return !id.empty() && seg.rfind("##", 0) == 0 && seg == id;
}

bool matches(const node_t &n, const std::string &seg) {
   const record_t *r = rec_of(n);
   return r && matches_record(r, seg);
}

// The nodes a label route reaches under node p: its children, and the children of its anonymous seeds (a PushID, a
// table, a tab bar, a menu bar: levels a path may skip).
void label_route(int p, const std::string &seg, std::vector<int> &out, int depth = 0) {
   if (depth > 32) return;
   for (int c : tree.nodes[p].children) {
      if (matches(tree.nodes[c], seg)) out.push_back(c);
      if (anonymous(tree.nodes[c])) label_route(c, seg, out, depth + 1);
   }
}

ImGuiID hash_segment(const std::string &seg, ImGuiID seed) {
   if (seg.size() > 2 && seg[0] == '$' && seg[1] == '$') { // "$$n": an integer id (PushID(n)), as the test engine
      char *end = nullptr;
      const long v = std::strtol(seg.c_str() + 2, &end, 10);
      if (end && *end == '\0') {
         const int iv = static_cast<int>(v);
         return ImHashData(&iv, sizeof(iv), seed);
      }
   }
   return ImHashStr(seg.c_str(), seg.size(), seed);
}

void step(const std::vector<int> &frontier, const std::string &seg, std::vector<int> &out) {
   out.clear();
   for (int p : frontier) {
      if (seg == "*") {
         for (int c : tree.nodes[p].children) out.push_back(c);
         continue;
      }
      label_route(p, seg, out);
      for (ImGuiID s : tree.nodes[p].seeds) {
         if (s == 0) continue;
         const int h = node_of(unalias(hash_segment(seg, s)));
         if (h >= 0) out.push_back(h);
      }
   }
   std::sort(out.begin(), out.end());
   out.erase(std::unique(out.begin(), out.end()), out.end());
}

std::string escaped(const std::string &s) {
   std::string e;
   for (char c : s) {
      if (c == '/') e += '\\';
      e += c;
   }
   return e;
}

// A node's path, as the messages write it: `//Window/label/...`, `*` for a seed with no label.
std::string path_of(int n) {
   std::vector<std::string> segs;
   bool absolute = false;
   for (int k = 0; n >= 0 && k < 64; ++k) {
      const node_t &nd = tree.nodes[n];
      const record_t *r = rec_of(nd);
      if (r && r->window && nd.parent == 0) {
         segs.push_back(escaped(last.label(*r)));
         absolute = true;
         break;
      }
      if (!r) segs.push_back("*");
      else if (r->window) segs.push_back(escaped(last.name(*r).empty() ? last.label(*r) : last.name(*r)));
      else if (r->info) segs.push_back(escaped(last.label(*r)));
      else segs.push_back(last.name(*r).empty() ? "*" : escaped(last.name(*r)));
      if (nd.parent == 0) break;
      n = node_of(nd.parent);
   }
   std::string p = absolute ? "//" : "";
   for (size_t i = segs.size(); i-- > 0;) {
      p += segs[i];
      if (i > 0) p += '/';
   }
   return p;
}

size_t distance(const std::string &a, const std::string &b) {
   std::vector<size_t> d(b.size() + 1);
   for (size_t j = 0; j <= b.size(); ++j) d[j] = j;
   for (size_t i = 1; i <= a.size(); ++i) {
      size_t prev = d[0];
      d[0] = i;
      for (size_t j = 1; j <= b.size(); ++j) {
         const size_t cur = d[j];
         d[j] = std::min({d[j] + 1, d[j - 1] + 1, prev + (a[i - 1] == b[j - 1] ? 0 : 1)});
         prev = cur;
      }
   }
   return d[b.size()];
}

// The labelled node nearest to `seg` among `candidates` (all labelled nodes when it is empty); -1: none.
int nearest(const std::string &seg, const std::vector<int> &candidates) {
   int    best = -1;
   size_t best_d = SIZE_MAX;
   auto consider = [&](int c) {
      const record_t *r = rec_of(tree.nodes[c]);
      if (!r || (!r->info && !r->window && last.name(*r).empty())) return;
      const std::string l = last.label(*r), nm = last.name(*r);
      size_t d = distance(seg, l);
      if (!visible_part(l).empty()) d = std::min(d, distance(seg, visible_part(l)));
      if (!nm.empty()) d = std::min(d, distance(seg, nm));
      if (d < best_d) {
         best_d = d;
         best = c;
      }
   };
   if (candidates.empty())
      for (int c = 0; c < static_cast<int>(tree.nodes.size()); ++c) consider(c);
   else
      for (int c : candidates) consider(c);
   return best;
}

void reachable(int p, std::vector<int> &out, int depth = 0) {
   if (depth > 32) return;
   for (int c : tree.nodes[p].children) {
      out.push_back(c);
      if (anonymous(tree.nodes[c])) reachable(c, out, depth + 1);
   }
}

std::string utf8(unsigned cp) {
   std::string s;
   if (cp < 0x80) {
      s += static_cast<char>(cp);
   } else if (cp < 0x800) {
      s += static_cast<char>(0xC0 | (cp >> 6));
      s += static_cast<char>(0x80 | (cp & 0x3F));
   } else if (cp < 0x10000) {
      s += static_cast<char>(0xE0 | (cp >> 12));
      s += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
      s += static_cast<char>(0x80 | (cp & 0x3F));
   } else {
      s += static_cast<char>(0xF0 | (cp >> 18));
      s += static_cast<char>(0x80 | ((cp >> 12) & 0x3F));
      s += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
      s += static_cast<char>(0x80 | (cp & 0x3F));
   }
   return s;
}

// Blanks collapsed to one space, none at the ends.
std::string normalized(const std::string &s) {
   std::string o;
   bool blank = false;
   for (char c : s) {
      if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
         blank = !o.empty();
         continue;
      }
      if (blank) o += ' ';
      blank = false;
      o += c;
   }
   return o;
}

// ---- The text of the last frame: glyph quads matched to the font atlas ---------------------------------------------

struct glyph_info_t {
   unsigned cp;
   float    x0, x1, y0, advance, size, space; // in the baked font's units
   float    u1, v1;
};
std::unordered_map<std::uint64_t, glyph_info_t> glyph_map;
long long                                       glyph_map_key = -1;

std::uint64_t uv_key(float u, float v) {
   std::uint32_t a, b;
   std::memcpy(&a, &u, 4);
   std::memcpy(&b, &v, 4);
   return (static_cast<std::uint64_t>(a) << 32) | b;
}

void build_glyph_map(ImFontAtlas *atlas) {
   if (!atlas->Builder) return;
   long long key = reinterpret_cast<std::intptr_t>(atlas->TexData) * 31 + atlas->TexData->Width * 7 + atlas->TexData->Height;
   ImStableVector<ImFontBaked, 32> &pool = atlas->Builder->BakedPool;
   for (int i = 0; i < pool.Size; ++i) key = key * 131 + pool[i].Glyphs.Size;
   if (key == glyph_map_key) return;
   glyph_map_key = key;
   glyph_map.clear();
   for (int i = 0; i < pool.Size; ++i) {
      ImFontBaked &b = pool[i];
      float space = 0.25f * b.Size;
      for (const ImFontGlyph &g : b.Glyphs)
         if (g.Codepoint == ' ') space = g.AdvanceX;
      for (const ImFontGlyph &g : b.Glyphs) {
         if (!g.Visible || g.X1 <= g.X0) continue;
         glyph_map[uv_key(g.U0, g.V0)] = {g.Codepoint, g.X0, g.X1, g.Y0, g.AdvanceX, b.Size, space, g.U1, g.V1};
      }
   }
}

void read_glyphs(table_t &t) {
   ImGuiContext &g = *ctx();
   build_glyph_map(g.IO.Fonts);
   if (glyph_map.empty()) return;
   for (ImGuiViewportP *vp : g.Viewports) {
      const ImDrawData &dd = vp->DrawDataP;
      if (!dd.Valid) continue;
      for (const ImDrawList *dl : dd.CmdLists) {
         for (const ImDrawCmd &cmd : dl->CmdBuffer) {
            if (cmd.UserCallback || cmd.ElemCount < 6) continue;
            const ImDrawIdx  *idx = dl->IdxBuffer.Data + cmd.IdxOffset;
            const ImDrawVert *vtx = dl->VtxBuffer.Data + cmd.VtxOffset;
            const unsigned    n = cmd.ElemCount;
            for (unsigned i = 0; i + 6 <= n;) {
               const unsigned a = idx[i];
               if (idx[i + 1] == a + 1 && idx[i + 2] == a + 2 && idx[i + 3] == a && idx[i + 4] == a + 2 &&
                   idx[i + 5] == a + 3) {
                  const ImDrawVert &v0 = vtx[a], &v2 = vtx[a + 2];
                  const auto gi = glyph_map.find(uv_key(v0.uv.x, v0.uv.y));
                  if (gi != glyph_map.end() && gi->second.u1 == v2.uv.x && gi->second.v1 == v2.uv.y) {
                     const glyph_info_t &G = gi->second;
                     const float s = (v2.pos.x - v0.pos.x) / (G.x1 - G.x0);
                     const float cx = 0.5f * (v0.pos.x + v2.pos.x), cy = 0.5f * (v0.pos.y + v2.pos.y);
                     if (cx >= cmd.ClipRect.x && cx <= cmd.ClipRect.z && cy >= cmd.ClipRect.y && cy <= cmd.ClipRect.w) {
                        const float pen = v0.pos.x - G.x0 * s;
                        t.glyphs.push_back({dl, pen, pen + G.advance * s, v0.pos.y - G.y0 * s + 0.5f * G.size * s,
                                            G.size * s, G.space * s, v0.pos.x, v0.pos.y, v2.pos.x, v2.pos.y, G.cp});
                     }
                     i += 6;
                     continue;
                  }
               }
               i += 3;
            }
         }
      }
   }
}

bool private_use(unsigned cp) { return (cp >= 0xE000 && cp <= 0xF8FF) || cp >= 0xF0000; }

// The visible name of a record: its own name, or the visible part of its label, blank or icons only counting as none.
bool has_name(const record_t &r) {
   std::string n = last.name(r);
   if (n.empty()) n = visible_part(last.label(r));
   const unsigned char *p = reinterpret_cast<const unsigned char *>(n.c_str());
   while (*p) {
      unsigned cp = *p;
      int      extra = 0;
      if (cp >= 0xF0) {
         cp &= 0x07;
         extra = 3;
      } else if (cp >= 0xE0) {
         cp &= 0x0F;
         extra = 2;
      } else if (cp >= 0xC0) {
         cp &= 0x1F;
         extra = 1;
      }
      ++p;
      for (int k = 0; k < extra && *p; ++k, ++p) cp = (cp << 6) | (*p & 0x3F);
      if (cp != ' ' && cp != '\t' && !private_use(cp)) return true;
   }
   return false;
}

} // namespace

// ---- Dear ImGui's test-engine hooks (imgui_internal.h, IMGUI_ENABLE_TEST_ENGINE) -----------------------------------

namespace {
void apply_info(ImGuiContext &g, record_t &r, const char *label, int flags);
}

void ImGuiTestEngineHook_ItemAdd(ImGuiContext *c, ImGuiID id, const ImRect &bb, const ImGuiLastItemData *item_data) {
   ImGuiContext &g = *c;
   ImGuiWindow  *w = g.CurrentWindow;
   if (!w || id == 0) return;
   record_t r;
   r.id = id;
   r.rect = bb;
   r.clip = w->ClipRect;
   r.dl = w->DrawList;
   r.visible = !w->Hidden && w->HiddenFramesCannotSkipItems <= 0 && bb.Overlaps(w->ClipRect);
   if (w->IDStack.Size == 0 && id == w->ID && !item_data) { // Begin registers the window itself (its stack emptied)
      if (w->Flags & ImGuiWindowFlags_Tooltip) return;
      r.window = true;
      r.role = figure_items::R_WINDOW;
      r.raw = w->ID;
      r.visible = !w->Hidden && w->HiddenFramesCannotSkipItems <= 0;
      r.label_at = append(building.chars, w->Name, std::strlen(w->Name));
      r.label_n = static_cast<unsigned>(std::strlen(w->Name));
      const std::string shown = window_shown_name(w);
      r.name_at = append(building.chars, shown.c_str(), shown.size());
      r.name_n = static_cast<unsigned>(shown.size());
      if (w->Flags & ImGuiWindowFlags_Popup) {
         ImGuiID open_parent = 0;
         for (int i = g.BeginPopupStack.Size - 1; i >= 0; --i)
            if (g.BeginPopupStack[i].Window == w) {
               open_parent = g.BeginPopupStack[i].OpenParentId;
               break;
            }
         const ImGuiID last_item = g.LastItemData.ID;
         if (last_item != 0 && (w->PopupId == last_item ||
                                w->PopupId == ImHashStr("##ComboPopup", 0, last_item))) {
            r.id = last_item; // a menu, an item's context menu, a combo's list: under the item that opened it
            const int o = find_building(last_item);
            r.parent = o >= 0 && building.items[o].stack_n > 0
                          ? building.ids[building.items[o].stack_at + building.items[o].stack_n - 1] : open_parent;
         } else {
            r.id = w->PopupId; // BeginPopup(name), a modal: under the seed it was opened from
            r.parent = open_parent;
         }
      } else if ((w->Flags & ImGuiWindowFlags_ChildWindow) && w->ParentWindow &&
                 w->ParentWindow->IDStack.Size > 0) {
         r.parent = w->ParentWindow->IDStack.back();
      }
   } else {
      r.disabled = item_data && (item_data->ItemFlags & ImGuiItemFlags_Disabled);
      r.tooltip = item_data && (item_data->StatusFlags & ImGuiItemStatusFlags_HasShortcut);
      r.stack_at = static_cast<unsigned>(building.ids.size());
      r.stack_n = static_cast<unsigned>(w->IDStack.Size);
      building.ids.insert(building.ids.end(), w->IDStack.Data, w->IDStack.Data + w->IDStack.Size);
   }
   building.items.push_back(r);
   if (pending.id == id && !r.window) {
      pending.id = 0;
      apply_info(g, building.items.back(), pending.label.c_str(), pending.flags);
   }
}

void ImGuiTestEngineHook_ItemInfo(ImGuiContext *c, ImGuiID id, const char *label, ImGuiItemStatusFlags flags) {
   ImGuiContext &g = *c;
   ImGuiWindow  *w = g.CurrentWindow;
   if (!w || id == 0) return;
   if (!building.items.empty() && building.items.back().window && building.items.back().raw == id) {
      building.items.back().info = true; // the window registered just before: its name is kept
      return;
   }
   int i = find_building(id);
   if (i < 0) { // an item registered without ItemAdd: Dear ImGui's last item; or one added next (a tab)
      if (g.LastItemData.ID != id) {
         pending.id = id;
         pending.label = label ? label : "";
         pending.flags = flags;
         return;
      }
      ImGuiTestEngineHook_ItemAdd(c, id, g.LastItemData.Rect, &g.LastItemData);
      i = static_cast<int>(building.items.size()) - 1;
   }
   apply_info(g, building.items[i], label, flags);
}

void ImGuiTestEngineHook_Log(ImGuiContext *, const char *, ...) {} // Dear ImGui's debug log: not kept

namespace {
void apply_info(ImGuiContext &g, record_t &r, const char *label, int flags) {
   ImGuiWindow *w = g.CurrentWindow;
   const size_t n = label ? std::strlen(label) : 0;
   r.label_at = append(building.chars, label ? label : "", n);
   r.label_n = static_cast<unsigned>(n);
   r.status = flags;
   r.info = true;
   const ImGuiID id = r.id;
   const bool in_menu = (w->Flags & ImGuiWindowFlags_ChildMenu) || w->DC.MenuBarAppending ||
                        ((w->Flags & ImGuiWindowFlags_Popup) && !(w->Flags & ImGuiWindowFlags_Modal));
   if (g.CurrentTabBar && ImGui::TabBarFindTabByID(g.CurrentTabBar, id)) r.role = figure_items::R_TAB;
   else if (flags & ImGuiItemStatusFlags_Openable) r.role = in_menu ? figure_items::R_MENU : figure_items::R_TREE_NODE;
   else if (flags & ImGuiItemStatusFlags_Checkable) r.role = in_menu ? figure_items::R_MENU_ITEM : figure_items::R_CHECKBOX;
   else if (flags & ImGuiItemStatusFlags_Inputable) r.role = figure_items::R_INPUT;
   else r.role = figure_items::R_ITEM;
}
} // namespace

// The ID stack tool's label of an id it cannot name otherwise (Dear ImGui's debug tools).
const char *ImGuiTestEngine_FindItemDebugLabel(ImGuiContext *, ImGuiID id) {
   static std::string label; // until the next call: Dear ImGui copies it at once
   for (const record_t &r : last.items)
      if (r.id == id && r.info && !r.window) {
         label = last.label(r);
         return label.c_str();
      }
   return nullptr;
}

// ---- figure_items ------------------------------------------------------------------------------------------------

namespace figure_items {

void record(bool on) {
   want_recording = on;
   if (ImGuiContext *c = ctx()) c->TestEngineHookItems = on;
}

bool recording() { return ctx() && ctx()->TestEngineHookItems; }

void reset() {
   building.clear();
   last.clear();
   tree.clear();
   glyph_map.clear();
   glyph_map_key = -1;
   if (ImGuiContext *c = ctx()) c->TestEngineHookItems = want_recording;
}

void frame_begin() {
   std::swap(building, last);
   building.clear();
   pending.id = 0;
   tree.clear();
   if (recording()) read_glyphs(last);
}

bool split(const std::string &path, std::vector<std::string> &segments, bool &absolute) {
   segments.clear();
   absolute = path.rfind("//", 0) == 0;
   std::string seg;
   for (size_t i = absolute ? 2 : 0; i < path.size(); ++i) {
      if (path[i] == '\\' && i + 1 < path.size() && path[i + 1] == '/') {
         seg += '/';
         ++i;
      } else if (path[i] == '/') {
         if (seg.empty()) return false;
         segments.push_back(seg);
         seg.clear();
      } else {
         seg += path[i];
      }
   }
   if (seg.empty()) return false;
   segments.push_back(seg);
   return true;
}

int find(const std::string &path, found_t &out, std::string &err, bool &missing) {
   missing = false;
   std::vector<std::string> segs;
   bool                     absolute = false;
   if (!split(path, segs, absolute)) {
      err = "'" + path + "' is not a path: an empty segment ('Window/Label', '//Window/Label', '##id', '*')";
      return FIG_ERR_ARGUMENT;
   }
   if (!ctx()) {
      err = "figure is not initialized";
      return FIG_ERR_STATE;
   }
   build_tree();
   std::vector<int> frontier, next;
   // the first segment: a window by its name; a relative path's first segment may also be an item anywhere
   for (int wi : tree.windows) {
      const int n = node_of(last.items[wi].id);
      if (n >= 0 && matches_record(&last.items[wi], segs[0])) frontier.push_back(n);
   }
   if (frontier.empty() && !absolute)
      for (int n = 0; n < static_cast<int>(tree.nodes.size()); ++n)
         if (matches(tree.nodes[n], segs[0])) frontier.push_back(n);
   std::sort(frontier.begin(), frontier.end());
   frontier.erase(std::unique(frontier.begin(), frontier.end()), frontier.end());
   size_t k = 1;
   std::vector<int> before; // the frontier where a segment found nothing
   if (!frontier.empty())
      for (; k < segs.size(); ++k) {
         step(frontier, segs[k], next);
         if (next.empty()) {
            before = frontier;
            break;
         }
         frontier.swap(next);
      }
   if (frontier.empty() || k < segs.size()) {
      missing = true;
      std::vector<int> candidates;
      for (int p : before) reachable(p, candidates);
      const size_t failed = frontier.empty() ? 0 : k;
      const int    near = nearest(segs[failed], candidates);
      err = "no item '" + path + "' in the last frame: ";
      if (failed == 0) err += absolute ? "no window '" + segs[0] + "'" : "no window or item '" + segs[0] + "'";
      else err += "nothing named '" + segs[failed] + "' in '" + path_of(before.front()) + "'";
      err += near >= 0 ? "; nearest: '" + path_of(near) + "'" : "; no item was recorded";
      return FIG_ERR_ARGUMENT;
   }
   std::vector<int> items;
   for (int n : frontier)
      if (tree.nodes[n].rec >= 0) items.push_back(n);
   if (items.empty()) {
      missing = true;
      err = "no item '" + path + "' in the last frame: '" + path_of(frontier.front()) +
            "' is a level of ids with no item of its own";
      return FIG_ERR_ARGUMENT;
   }
   if (items.size() > 1) {
      out.several = true;
      err = "'" + path + "' names " + std::to_string(items.size()) + " items:";
      for (size_t i = 0; i < items.size() && i < 4; ++i) err += " '" + path_of(items[i]) + "'";
      if (items.size() > 4) err += " ...";
      err += " (a longer path tells them apart)";
      return FIG_ERR_ARGUMENT;
   }
   const node_t   &nd = tree.nodes[items[0]];
   const record_t &r = last.items[nd.rec];
   if (nd.dups > 0) {
      out.several = true;
      err = "'" + path + "' names " + std::to_string(nd.dups + 1) +
            " items with the same id (an id conflict, test_id_conflicts): '" + path_of(items[0]) + "'";
      return FIG_ERR_ARGUMENT;
   }
   out.x0 = r.rect.Min.x;
   out.y0 = r.rect.Min.y;
   out.x1 = r.rect.Max.x;
   out.y1 = r.rect.Max.y;
   ImRect v = r.rect;
   if (!r.window) v.ClipWith(r.clip);
   out.cx = 0.5f * (v.Min.x + v.Max.x);
   out.cy = 0.5f * (v.Min.y + v.Max.y);
   if (r.role == R_TREE_NODE && (r.status & ImGuiItemStatusFlags_Openable)) // its arrow: what opens and closes it
      out.cx = std::min(out.cx, v.Min.x + 0.5f * (v.Max.y - v.Min.y));
   out.state = (r.visible ? S_VISIBLE : 0) | ((r.status & ImGuiItemStatusFlags_Checkable) ? S_CHECKABLE : 0) |
               ((r.status & ImGuiItemStatusFlags_Checked) ? S_CHECKED : 0) |
               ((r.status & ImGuiItemStatusFlags_Openable) ? S_OPENABLE : 0) |
               ((r.status & ImGuiItemStatusFlags_Opened) ? S_OPENED : 0) |
               ((r.status & ImGuiItemStatusFlags_Inputable) ? S_INPUTABLE : 0) | (r.disabled ? S_DISABLED : 0) |
               (r.window ? S_WINDOW : 0);
   out.role = r.role;
   out.label = last.label(r);
   out.path = path_of(items[0]);
   out.index = static_cast<unsigned>(nd.rec);
   return FIG_OK;
}

std::string shown_value(const found_t &f) {
   if (f.index >= last.items.size()) return "";
   const record_t        &r = last.items[f.index];
   std::vector<const glyph_t *> in;
   for (const glyph_t &g : last.glyphs) {
      const float cx = 0.5f * (g.x0 + g.x1);
      if (g.dl == r.dl && cx >= r.rect.Min.x && cx <= r.rect.Max.x && g.cy >= r.rect.Min.y && g.cy <= r.rect.Max.y)
         in.push_back(&g);
   }
   // lines top to bottom (a glyph within half a line of the line's first), each left to right
   std::sort(in.begin(), in.end(), [](const glyph_t *a, const glyph_t *b) { return a->cy < b->cy; });
   std::vector<std::vector<const glyph_t *>> lines;
   for (const glyph_t *g : in) {
      if (lines.empty() || std::fabs(g->cy - lines.back().front()->cy) > 0.5f * g->height) lines.emplace_back();
      lines.back().push_back(g);
   }
   std::string text;
   for (auto &line : lines) {
      std::sort(line.begin(), line.end(), [](const glyph_t *a, const glyph_t *b) { return a->pen < b->pen; });
      if (!text.empty()) text += ' ';
      for (size_t i = 0; i < line.size(); ++i) {
         if (i > 0 && line[i]->pen - line[i - 1]->end > 0.5f * line[i]->space) text += ' ';
         text += utf8(line[i]->cp);
      }
   }
   text = normalized(text);
   const std::string lab = r.window ? normalized(last.name(r)) : normalized(visible_part(last.label(r)));
   if (!lab.empty()) {
      if (text.size() >= lab.size() && text.compare(text.size() - lab.size(), lab.size(), lab) == 0)
         text = normalized(text.substr(0, text.size() - lab.size()));
      else if (text.rfind(lab, 0) == 0)
         text = normalized(text.substr(lab.size()));
   }
   return text;
}

void id_conflicts(std::vector<std::string> &paths) {
   paths.clear();
   if (!ctx()) return;
   build_tree();
   for (int n = 0; n < static_cast<int>(tree.nodes.size()); ++n)
      if (tree.nodes[n].dups > 0) paths.push_back(path_of(n));
}

void unnamed_items(std::vector<std::string> &paths) {
   paths.clear();
   if (!ctx()) return;
   build_tree();
   for (int n = 0; n < static_cast<int>(tree.nodes.size()); ++n) {
      const record_t *r = rec_of(tree.nodes[n]);
      if (!r || r->window || !r->info || r->tooltip || has_name(*r)) continue;
      paths.push_back(path_of(n));
   }
}

void name_last(const std::string &name) {
   if (!recording()) return;
   const int i = find_building(ctx()->LastItemData.ID);
   if (i < 0) return;
   building.items[i].name_at = append(building.chars, name.c_str(), name.size());
   building.items[i].name_n = static_cast<unsigned>(name.size());
}

void tooltip_last() {
   if (!recording()) return;
   const int i = find_building(ctx()->LastItemData.ID);
   if (i >= 0) building.items[i].tooltip = true;
}

} // namespace figure_items

// ---- C ABI (figure_native.h) ----------------------------------------------------------------------------------------

namespace {
int fail(int status, const std::string &msg) {
   fig_set_last_error(msg.c_str(), static_cast<int>(msg.size()));
   return status;
}

std::string text_of(const char *s, int n) { return std::string(s, n > 0 ? static_cast<size_t>(n) : 0); }

int copy_out(const std::string &s, char *buf, int cap, int *n) {
   *n = static_cast<int>(s.size());
   if (cap > 0) std::memcpy(buf, s.data(), std::min(s.size(), static_cast<size_t>(cap)));
   return FIG_OK;
}

std::vector<std::string> listed; // the last list asked for (fig_items_list)
} // namespace

int fig_items_record(int on) {
   figure_items::record(on != 0);
   return FIG_OK;
}

int fig_item_find(const char *path, int path_len, int must, int *found, float *rect, int *state, char *label,
                  int label_cap, int *label_len) {
   try {
      *found = 0;
      *state = 0;
      *label_len = 0;
      if (!ctx()) return fail(FIG_ERR_STATE, "figure is not initialized");
      if (!figure_items::recording()) figure_items::record(true);
      figure_items::found_t f;
      std::string           err;
      bool                  missing = false;
      const int             s = figure_items::find(text_of(path, path_len), f, err, missing);
      if (s != FIG_OK) {
         if (f.several && !must) { // several: found 2, the message naming them
            *found = 2;
            fig_set_last_error(err.c_str(), static_cast<int>(err.size()));
            return FIG_OK;
         }
         if (missing && !must) {
            fig_set_last_error(err.c_str(), static_cast<int>(err.size())); // the nearest match, for a message
            return FIG_OK;
         }
         return fail(s, err);
      }
      *found = 1;
      rect[0] = f.x0;
      rect[1] = f.y0;
      rect[2] = f.x1;
      rect[3] = f.y1;
      rect[4] = f.cx;
      rect[5] = f.cy;
      *state = f.state | (f.role << 16);
      return copy_out(f.path, label, label_cap, label_len);
   } catch (const std::exception &e) {
      return fail(FIG_ERR_EXCEPTION, std::string("items: C++ exception: ") + e.what());
   }
}

int fig_item_value(const char *path, int path_len, const char *text, int text_len, int *equal, char *buf, int cap,
                   int *n) {
   try {
      *equal = 0;
      *n = 0;
      if (!ctx()) return fail(FIG_ERR_STATE, "figure is not initialized");
      if (!figure_items::recording()) figure_items::record(true);
      figure_items::found_t f;
      std::string           err;
      bool                  missing = false;
      const int             s = figure_items::find(text_of(path, path_len), f, err, missing);
      if (s != FIG_OK) return fail(s, "test_item_value: " + err);
      const std::string shown = figure_items::shown_value(f);
      *equal = shown == normalized(text_of(text, text_len)) ? 1 : 0;
      return copy_out(shown, buf, cap, n);
   } catch (const std::exception &e) {
      return fail(FIG_ERR_EXCEPTION, std::string("items: C++ exception: ") + e.what());
   }
}

// what 1: the id conflicts, 2: the unnamed items of the last frame; listed at index 0 (count only), read by index from 1.
int fig_items_list(int what, int index, char *buf, int cap, int *n, int *count) {
   try {
      *n = 0;
      if (index <= 0) {
         if (!figure_items::recording()) figure_items::record(true);
         if (what == 1) figure_items::id_conflicts(listed);
         else figure_items::unnamed_items(listed);
      }
      *count = static_cast<int>(listed.size());
      if (index >= 1 && index <= *count) return copy_out(listed[static_cast<size_t>(index - 1)], buf, cap, n);
      return FIG_OK;
   } catch (const std::exception &e) {
      return fail(FIG_ERR_EXCEPTION, std::string("items: C++ exception: ") + e.what());
   }
}

void fig_items_name(const char *name, int name_len) { figure_items::name_last(visible_part(text_of(name, name_len))); }

void fig_items_tooltip(void) { figure_items::tooltip_last(); }
