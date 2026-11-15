// FIGURE's table of the items Dear ImGui drew (figure_items.cpp): what figure_testing's paths address. Internal to the
// native layer (figure_native.cpp drives it); the C ABI is in figure_native.h.
#ifndef FIGURE_ITEMS_H
#define FIGURE_ITEMS_H

#include <string>
#include <vector>

namespace figure_items {

// Roles: what kind of item a record is, from the status Dear ImGui reports and where the item is (an accessibility
// layer's roles, coarse: Dear ImGui does not say which widget registered an item).
enum role_t { R_OTHER = 0, R_WINDOW, R_ITEM, R_CHECKBOX, R_TREE_NODE, R_MENU, R_MENU_ITEM, R_TAB, R_INPUT };

// State bits of found_t::state: must match the ITEM_* parameters of src/lib/figure_testing.F90.
enum state_t {
   S_VISIBLE = 1, S_CHECKABLE = 2, S_CHECKED = 4, S_OPENABLE = 8, S_OPENED = 16, S_INPUTABLE = 32, S_DISABLED = 64,
   S_WINDOW = 128
};

// An item found by a path, as it was in the last frame drawn.
struct found_t {
   float       x0 = 0.0f, y0 = 0.0f, x1 = 0.0f, y1 = 0.0f; // its rectangle [pixels]
   float       cx = 0.0f, cy = 0.0f;                       // where to click: the centre of its visible part
   int         state = 0;                                  // S_* bits
   int         role = R_OTHER;
   std::string label;                                      // the label Dear ImGui was given (with any ##id)
   std::string path;                                       // its full path, as the messages write it
   unsigned    index = 0;                                  // the record (shown_value)
   bool        several = false;                            // find failed: the path names several items
};

void record(bool on);   // record the items from the next frame on (Dear ImGui's test-engine hooks on or off)
bool recording();
void frame_begin();     // before NewFrame: the frame that ended becomes the last frame; its text is read
void reset();           // a new context: both tables emptied

// Find the one item `path` names in the last frame. 0: found; otherwise a FIG_ERR_* status with `err` set (no item,
// with the nearest match, several items, a malformed path). `missing` is true when no item matched (not an error for
// a caller that only asks whether it exists).
int find(const std::string &path, found_t &out, std::string &err, bool &missing);

// The text the last frame drew inside an item's rectangle, its label taken out: the value it shows.
std::string shown_value(const found_t &f);

// The paths of the ids shared by items with different rectangles (id conflicts), and of the interactive items with no
// visible name and no tooltip (an empty visible label, or icons only), in the last frame.
void id_conflicts(std::vector<std::string> &paths);
void unnamed_items(std::vector<std::string> &paths);

// The last item drawn: its accessible name (a widget that draws its label itself), or a tooltip it has.
void name_last(const std::string &name);
void tooltip_last();

// Split a path into its segments (`\/` is a slash inside a segment); `absolute` for a leading `//`. False for a
// malformed path (empty, or an empty segment).
bool split(const std::string &path, std::vector<std::string> &segments, bool &absolute);

} // namespace figure_items

#endif
