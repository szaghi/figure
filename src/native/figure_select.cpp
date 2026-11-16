// FIGURE's multi-selection (selection_object, ig_begin_multi_select, ig_end_multi_select): see figure_native.h,
// "Multi-selection".
//
// Dear ImGui's multi-selection (BeginMultiSelect / EndMultiSelect) turns the clicks, shift and ctrl clicks, ctrl+a,
// the keyboard and box-selection on a list's items into requests ("set all", "set the range a..b"), which the program
// applies to its own record of what is selected. FIGURE's record is the selection_object's array of flags, one per
// item, owned by Fortran and passed by address at each begin and end: the requests are applied to it here, through
// Dear ImGui's ImGuiSelectionExternalStorage, so the Fortran side reads plain logicals. Items are given their index
// (SetNextItemSelectionUserData) by ig_selectable and ig_tree_node. Main thread only.
#include "figure_native.h"

#include "imgui.h"

namespace {

int open_count = -1; // items of the multi-selection open (-1: none)

void set_item(ImGuiSelectionExternalStorage *self, int idx, bool selected) {
   static_cast<bool *>(self->UserData)[idx] = selected;
}

void apply(ImGuiMultiSelectIO *io, bool *flags, int count) {
   if (!io || !flags) return;
   ImGuiSelectionExternalStorage storage;
   storage.UserData = flags;
   storage.AdapterSetItemSelected = set_item;
   // the requests' indices are the items' (0-based): a range outside [0, count) cannot come from FIGURE's items
   for (ImGuiSelectionRequest &r : io->Requests) {
      if (r.Type == ImGuiSelectionRequestType_SetRange) {
         if (r.RangeFirstItem < 0) r.RangeFirstItem = 0;
         if (r.RangeLastItem >= count) r.RangeLastItem = count - 1;
      }
   }
   storage.ApplyRequests(io);
}

} // namespace

extern "C" {

// Begin a multi-selection over `count` items whose flags are `flags` (count bools): the begin's requests applied.
// *range_source: the item (0-based) a shift+click extends from, which a clipper must keep drawn; -1 when none.
// FIG_ERR_STATE when one is open already (Dear ImGui allows one at a time).
int fig_multi_select_begin(int ms_flags, bool *flags, int count, int *range_source) {
   *range_source = -1;
   if (open_count >= 0) return FIG_ERR_STATE;
   int selected = 0;
   for (int i = 0; i < count; ++i) selected += flags[i] ? 1 : 0;
   ImGuiMultiSelectIO *io = ImGui::BeginMultiSelect(ms_flags, selected, count);
   apply(io, flags, count);
   *range_source = io ? static_cast<int>(io->RangeSrcItem) : -1;
   open_count = count;
   return FIG_OK;
}

// End it: the end's requests applied to the same flags.
void fig_multi_select_end(bool *flags, int count) {
   apply(ImGui::EndMultiSelect(), flags, count);
   open_count = -1;
}

// Forget the selection open (FIGURE's recovery closed it, or a new frame began without its end).
void fig_multi_select_reset(void) { open_count = -1; }

// The next item's index (0-based) in the multi-selection open: FIG_ERR_STATE when none is open, FIG_ERR_ARGUMENT
// for an index outside [0, count); *count: the selection's items.
int fig_multi_select_item(int index, int *count) {
   *count = open_count;
   if (open_count < 0) return FIG_ERR_STATE;
   if (index < 0 || index >= open_count) return FIG_ERR_ARGUMENT;
   ImGui::SetNextItemSelectionUserData(index);
   return FIG_OK;
}

// Keep the row `index` (0-based) drawn by the clipper, wherever it is (a multi-selection's range source).
void fig_clipper_include(void *clipper, int index) {
   static_cast<ImGuiListClipper *>(clipper)->IncludeItemByIndex(index);
}

} // extern "C"
