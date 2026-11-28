// The 3-D view's gizmos (view3d_object%view_cube, %gizmo): ImGuizmo's calls (third_party/ImGuizmo, FIGURE's patches),
// apart from figure_view3d.cpp, which does the rest (szaghi/figure#15 G2: a program that never calls these two links no
// ImGuizmo; the Fortran path's gizmos are figure_gizmo's). Every function is extern "C" and never lets a C++ exception
// escape (figure_native.h).
#include "figure_native.h"
#include "figure_view3d.h"

#include "imgui.h"
#include "imgui_internal.h"
#include "ImGuizmo.h"

#include <utility>

namespace {

// ImGuizmo's per-frame state, once a frame, without its full-screen window (FIGURE's patch 0001).
void gizmo_frame() {
   static int last = -1;
   static ImGuiContext *context = nullptr;
   const int frame = ImGui::GetFrameCount();
   if (frame == last && context == ImGui::GetCurrentContext()) return;
   last = frame, context = ImGui::GetCurrentContext();
   ImGuizmo::BeginFrameState();
}

int cube(const float *rect, float *cv, const float *fp, float distance, float x, float y, float s, unsigned int id) {
   gizmo_frame();
   ImGuizmo::SetDrawlist(ImGui::GetWindowDrawList());
   ImGuizmo::SetOrthographic(false);
   ImGuizmo::SetRect(rect[0], rect[1], rect[2], rect[3]);
   static const float identity[16] = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1};
   float model[16];
   for (int k = 0; k < 16; ++k) model[k] = identity[k];
   ImGuizmo::Style &st = ImGuizmo::GetStyle();
   std::swap(st.Colors[ImGuizmo::DIRECTION_Y], st.Colors[ImGuizmo::DIRECTION_Z]); // y' is FIGURE's z
   ImGuizmo::PushID(static_cast<int>(id));
   const bool using_before = ImGuizmo::IsUsingViewManipulate();
   ImGuizmo::ViewManipulate(cv, fp, ImGuizmo::TRANSLATE, ImGuizmo::WORLD, model, distance, ImVec2(x, y), ImVec2(s, s),
                            0);
   const bool using_it = ImGuizmo::IsUsingViewManipulate() && !using_before;
   ImGuizmo::PopID();
   std::swap(st.Colors[ImGuizmo::DIRECTION_Y], st.Colors[ImGuizmo::DIRECTION_Z]);
   return using_it ? 1 : 0;
}

int manipulate(const float *rect, float size_clip, const float *fv, const float *fp, int mode, int space, float *fm,
               const float *snap, unsigned int id, int *using_it, int *over) {
   gizmo_frame();
   ImGuizmo::SetDrawlist(ImGui::GetWindowDrawList());
   ImGuizmo::SetOrthographic(false);
   ImGuizmo::SetRect(rect[0], rect[1], rect[2], rect[3]);
   ImGuizmo::SetGizmoSizeClipSpace(size_clip);
   ImGuizmo::AllowAxisFlip(false); // the arrows point along +x, +y, +z (ImGuizmo's default flips them to the eye)
   static const ImGuizmo::OPERATION OPS[3] = {ImGuizmo::TRANSLATE, ImGuizmo::ROTATE, ImGuizmo::SCALE};
   ImGuizmo::PushID(static_cast<int>(id));
   const bool moved = ImGuizmo::Manipulate(fv, fp, OPS[mode], space == 1 ? ImGuizmo::LOCAL : ImGuizmo::WORLD, fm,
                                           nullptr, snap);
   *using_it = ImGuizmo::IsUsing() ? 1 : 0;
   *over = ImGuizmo::GetHoveredHandleType() != ImGuizmo::MT_NONE ? 1 : 0;
   ImGuizmo::PopID();
   return moved ? 1 : 0;
}

const fig_v3d_gizmo_ops ops = {cube, manipulate};

} // namespace

extern "C" {

int fig_view3d_cube(int handle, double size, int corner, int *changed) {
   // name map: ImGuizmo::ViewManipulate, ImGui::IsMouseDown
   return figure_view3d_cube_impl(handle, size, corner, changed, &ops);
}

int fig_view3d_gizmo(int handle, const char *id, int id_len, double *matrix, int mode, int space, int has_snap,
                     double snap, int *changed) {
   // name map: ImGuizmo::Manipulate, ImGui::IsMouseDown
   return figure_view3d_gizmo_impl(handle, id, id_len, matrix, mode, space, has_snap, snap, changed, &ops);
}

} // extern "C"
