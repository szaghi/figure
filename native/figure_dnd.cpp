// FIGURE's drag and drop (ig_drag_source, ig_drop_target, ip_drop_target): see figure_native.h, "Drag and drop".
//
// Dear ImGui's drag and drop moves a payload of bytes from a source item to a target item, matched by a type string;
// FIGURE's payload is text (an id, a name, a path), so a Fortran program never deals with Dear ImGui's payload struct.
// A source is the last item drawn (Dear ImGui's BeginDragDropSource, with SourceAllowNullID so that text and other
// items without an id can be dragged too); a target is the last item, or a plot, one of its axes or its legend
// (ImPlot's BeginDragDropTarget*). A payload delivered to a target is kept here until the Fortran side reads it
// (fig_dnd_payload), as the file browser's answers are. Main thread only: the entry points are refused from tasks.
#include "figure_native.h"

#include "imgui.h"

#include <string>

namespace {

std::string delivered; // the payload of the last delivery, until read

int fail(int status, const std::string &msg) {
   fig_set_last_error(msg.c_str(), static_cast<int>(msg.size()));
   return status;
}

} // namespace

// Dear ImGui's type: at most 32 bytes, its own types start with '_' (also the plot's drop targets':
// figure_implot_glue.cpp).
int figure_dnd_type_ok(const std::string &type, const char *who) {
   if (type.empty() || type.size() > 32)
      return fail(FIG_ERR_ARGUMENT, std::string(who) + ": type '" + type + "' must have 1 to 32 characters");
   if (type[0] == '_')
      return fail(FIG_ERR_ARGUMENT, std::string(who) + ": type '" + type + "' starts with '_' (Dear ImGui's own types)");
   return FIG_OK;
}

extern "C" {

int fig_dnd_source(const char *type, int type_len, const char *payload, int payload_len, const char *preview,
                   int preview_len, int *dragging) {
   *dragging = 0;
   const std::string t(type, static_cast<size_t>(type_len));
   if (const int s = figure_dnd_type_ok(t, "ig_drag_source"); s != FIG_OK) return s;
   if (!ImGui::BeginDragDropSource(ImGuiDragDropFlags_SourceAllowNullID)) return FIG_OK;
   ImGui::SetDragDropPayload(t.c_str(), payload, static_cast<size_t>(payload_len)); // copied by Dear ImGui
   const std::string shown = preview_len >= 0 ? std::string(preview, static_cast<size_t>(preview_len))
                                              : std::string(payload, static_cast<size_t>(payload_len));
   ImGui::TextUnformatted(shown.c_str(), shown.c_str() + shown.size());
   ImGui::EndDragDropSource();
   *dragging = 1;
   return FIG_OK;
}

} // extern "C"

// A target opened (Dear ImGui's or ImPlot's begin returned true): accept `type`, keep the payload delivered.
int figure_dnd_accept(const std::string &type, int *len) {
   if (const ImGuiPayload *p = ImGui::AcceptDragDropPayload(type.c_str())) {
      delivered.assign(static_cast<const char *>(p->Data), static_cast<size_t>(p->DataSize));
      *len = static_cast<int>(delivered.size());
   }
   ImGui::EndDragDropTarget();
   return *len >= 0 ? 1 : 0;
}

extern "C" {

int fig_dnd_target(const char *type, int type_len, int *len) {
   *len = -1;
   const std::string t(type, static_cast<size_t>(type_len));
   if (const int s = figure_dnd_type_ok(t, "ig_drop_target"); s != FIG_OK) return s;
   if (ImGui::BeginDragDropTarget()) figure_dnd_accept(t, len);
   return FIG_OK;
}

void fig_dnd_payload(char *buf, int len) {
   delivered.copy(buf, static_cast<size_t>(len));
   delivered.clear();
}

// 1 while a payload of `type` is being dragged (a drop zone can show itself), 0 otherwise.
int fig_dnd_dragging(const char *type, int type_len) {
   const ImGuiPayload *p = ImGui::GetDragDropPayload();
   if (!p) return 0;
   return std::string(type, static_cast<size_t>(type_len)) == p->DataType ? 1 : 0;
}

} // extern "C"
