// FIGURE's canvas (src/lib/figure_canvas.F90): an area that takes the mouse, and drawing primitives on Dear ImGui's draw
// lists. Every argument is checked on the Fortran side (finite coordinates within single precision, colours in [0, 1],
// sizes): what reaches here is drawn. Main thread only, inside a frame: the Fortran entry points refuse a task and a
// call with no frame open first.
#include "figure_native.h"

#include "imgui.h"
#include "imgui_internal.h"
#include "implot.h"
#include "implot_internal.h"

#include <algorithm>
#include <cmath>
#include <string>
#include <vector>

namespace {

int fail(int status, const std::string &msg) {
   fig_set_last_error(msg.c_str(), static_cast<int>(msg.size()));
   return status;
}

#define FIG_TRY_CANVAS try {
#define FIG_CATCH_CANVAS                                                                                               \
   }                                                                                                                   \
   catch (const std::exception &e) {                                                                                  \
      return fail(FIG_ERR_EXCEPTION, std::string("canvas: C++ exception: ") + e.what());                              \
   }                                                                                                                   \
   catch (...) {                                                                                                       \
      return fail(FIG_ERR_EXCEPTION, "canvas: unknown C++ exception");                                                \
   }

// Layers: must match the LAYER_* parameters of src/lib/figure_canvas.F90.
enum layer_t { L_WINDOW = 1, L_FOREGROUND = 2, L_BACKGROUND = 3, L_PLOT = 4 };
// Primitives: must match the DRAW_* parameters of src/lib/figure_canvas.F90.
enum kind_t { D_LINE = 1, D_RECT, D_CIRCLE, D_POLYLINE, D_POLYGON, D_TEXT, D_IMAGE };

// A pixel coordinate computed in double precision from plot units, kept within 1e7 pixels of the display's origin: a
// point far outside the plot (a strong zoom) would overflow single precision when ImGui stores it (a trap under
// -ffpe-trap=overflow), and 1e7 pixels is still far beyond any display, so the visible part of a line hardly moves.
float to_pixel(double v) {
   constexpr double LIMIT = 1.0e7;
   return static_cast<float>(std::min(std::max(v, -LIMIT), LIMIT));
}

// One plot coordinate to pixels along an ImPlot axis, in double precision (ImPlotAxis::PlotToPixels, before its cast).
double axis_to_pixel(const ImPlotAxis &a, double plt) {
   if (a.TransformForward != nullptr) {
      const double s = a.TransformForward(plt, a.TransformData);
      const double t = (s - a.ScaleMin) / (a.ScaleMax - a.ScaleMin);
      plt = a.Range.Min + a.Range.Size() * t;
   }
   return a.PixelMin + a.ScaleToPixel * (plt - a.Range.Min);
}

} // namespace

extern "C" int fig_canvas(const char *id, int id_len, double width, double height, unsigned long long texture,
                          fig_canvas_event *ev) {
   FIG_TRY_CANVAS
   *ev = fig_canvas_event{};
   if (!ImGui::GetCurrentContext()) return fail(FIG_ERR_STATE, "figure is not initialized");
   const std::string label(id, static_cast<size_t>(std::max(id_len, 0)));
   const ImVec2 avail = ImGui::GetContentRegionAvail();
   float w = static_cast<float>(width), h = static_cast<float>(height);
   if (w <= 0.0f) w = std::max(1.0f, avail.x + w);
   if (h <= 0.0f) h = std::max(1.0f, avail.y + h);
   const ImVec2 p0 = ImGui::GetCursorScreenPos();
   ImGui::InvisibleButton(label.c_str(), ImVec2(w, h),
                          ImGuiButtonFlags_MouseButtonLeft | ImGuiButtonFlags_MouseButtonRight |
                              ImGuiButtonFlags_MouseButtonMiddle);
   // the wheel is the canvas's while the pointer is over it: claimed for the next frame, so that a scrolling window or
   // child holding the canvas does not scroll on the same turn of the wheel (Dear ImGui's key ownership, as view3d)
   ImGui::SetItemKeyOwner(ImGuiKey_MouseWheelY);
   ImGui::SetItemKeyOwner(ImGuiKey_MouseWheelX);
   const ImGuiIO &io = ImGui::GetIO();
   const bool hovered = ImGui::IsItemHovered();
   const bool active = ImGui::IsItemActive();
   const bool deactivated = ImGui::IsItemDeactivated();
   ev->hovered = hovered ? 1 : 0;
   ev->active = active ? 1 : 0;
   for (int b = 0; b < 3; ++b) {
      ev->clicked[b] = ImGui::IsItemClicked(b) ? 1 : 0;
      ev->double_clicked[b] = hovered && ImGui::IsMouseDoubleClicked(b) ? 1 : 0;
      ev->down[b] = active && ImGui::IsMouseDown(b) ? 1 : 0;
      ev->released[b] = (active || deactivated) && ImGui::IsMouseReleased(b) ? 1 : 0;
   }
   // the drag: from where the button that holds the canvas was pressed, while it is held and on its release
   for (int b = 0; b < 3; ++b) {
      if (ev->down[b] || ev->released[b]) {
         ev->drag[0] = io.MousePos.x - io.MouseClickedPos[b].x;
         ev->drag[1] = io.MousePos.y - io.MouseClickedPos[b].y;
         break;
      }
   }
   if (active && ImGui::IsMousePosValid()) {
      ev->delta[0] = io.MouseDelta.x;
      ev->delta[1] = io.MouseDelta.y;
   }
   if (hovered) {
      ev->wheel = io.MouseWheel;
      ev->wheel_h = io.MouseWheelH;
   }
   if (ImGui::IsMousePosValid()) {
      ev->mouse[0] = io.MousePos.x - p0.x;
      ev->mouse[1] = io.MousePos.y - p0.y;
   }
   ev->ctrl = io.KeyCtrl ? 1 : 0;
   ev->shift = io.KeyShift ? 1 : 0;
   ev->alt = io.KeyAlt ? 1 : 0;
   ev->super = io.KeySuper ? 1 : 0;
   const ImVec2 p1 = ImGui::GetItemRectMax();
   ev->origin[0] = p0.x;
   ev->origin[1] = p0.y;
   ev->size[0] = p1.x - p0.x;
   ev->size[1] = p1.y - p0.y;
   if (texture != 0) {
      ImDrawList *dl = ImGui::GetWindowDrawList();
      fig_texture_sampling(0, 1);
      dl->AddImage(ImTextureRef(static_cast<ImTextureID>(texture)), p0, p1);
      fig_texture_sampling(0, 0);
   }
   return FIG_OK;
   FIG_CATCH_CANVAS
}

extern "C" int fig_draw(int kind, int layer, const double *x, const double *y, int n, const double *rgba,
                        double thickness, double radius, int filled, const char *text, int text_len,
                        unsigned long long texture) {
   FIG_TRY_CANVAS
   if (!ImGui::GetCurrentContext()) return fail(FIG_ERR_STATE, "figure is not initialized");
   ImDrawList *dl = nullptr;
   const ImPlotAxis *ax = nullptr, *ay = nullptr;
   switch (layer) {
   case L_FOREGROUND: dl = ImGui::GetForegroundDrawList(); break;
   case L_BACKGROUND: dl = ImGui::GetBackgroundDrawList(); break;
   case L_PLOT: {
      ImPlotContext *gp = ImPlot::GetCurrentContext();
      if (gp == nullptr || gp->CurrentPlot == nullptr) return -1; // a usage error, worded by the Fortran caller
      ImPlot::SetupLock(); // the axes' ranges and pixels are final from here (ImPlot's own PlotToPixels does the same)
      ImPlotPlot &plot = *gp->CurrentPlot;
      ax = &plot.Axes[plot.CurrentX];
      ay = &plot.Axes[plot.CurrentY];
      dl = ImPlot::GetPlotDrawList();
      break;
   }
   default: dl = ImGui::GetWindowDrawList(); break;
   }
   const ImU32 col = ImGui::GetColorU32(ImVec4(static_cast<float>(rgba[0]), static_cast<float>(rgba[1]),
                                               static_cast<float>(rgba[2]), static_cast<float>(rgba[3])));
   const float t = static_cast<float>(thickness);
   std::vector<ImVec2> p(static_cast<size_t>(std::max(n, 0)));
   for (int i = 0; i < n; ++i) {
      if (ax != nullptr)
         p[i] = ImVec2(to_pixel(axis_to_pixel(*ax, x[i])), to_pixel(axis_to_pixel(*ay, y[i])));
      else
         p[i] = ImVec2(static_cast<float>(x[i]), static_cast<float>(y[i]));
   }
   if (layer == L_PLOT) ImPlot::PushPlotClipRect();
   switch (kind) {
   case D_LINE: dl->AddLine(p[0], p[1], col, t); break;
   case D_RECT: {
      const ImVec2 a(std::min(p[0].x, p[1].x), std::min(p[0].y, p[1].y));
      const ImVec2 b(std::max(p[0].x, p[1].x), std::max(p[0].y, p[1].y));
      if (filled)
         dl->AddRectFilled(a, b, col);
      else
         dl->AddRect(a, b, col, 0.0f, t);
      break;
   }
   case D_CIRCLE:
      if (filled)
         dl->AddCircleFilled(p[0], static_cast<float>(radius), col);
      else
         dl->AddCircle(p[0], static_cast<float>(radius), col, 0, t);
      break;
   case D_POLYLINE: dl->AddPolyline(p.data(), n, col, t, filled ? ImDrawFlags_Closed : ImDrawFlags_None); break;
   case D_POLYGON:
      if (filled)
         dl->AddConcavePolyFilled(p.data(), n, col);
      else
         dl->AddPolyline(p.data(), n, col, t, ImDrawFlags_Closed);
      break;
   case D_TEXT: dl->AddText(p[0], col, text, text + std::max(text_len, 0)); break;
   case D_IMAGE: {
      const ImVec2 a(std::min(p[0].x, p[1].x), std::min(p[0].y, p[1].y));
      const ImVec2 b(std::max(p[0].x, p[1].x), std::max(p[0].y, p[1].y));
      // the texture's row 1 at the top whatever the order of the corners, in every layer (as ig_image and ip_image)
      const ImVec2 uv0(0.0f, 0.0f), uv1(1.0f, 1.0f);
      const ImGuiPlatformIO &pio = ImGui::GetPlatformIO();
      if (pio.DrawCallback_SetSamplerFromTex != nullptr) dl->AddCallback(pio.DrawCallback_SetSamplerFromTex, nullptr);
      dl->AddImage(ImTextureRef(static_cast<ImTextureID>(texture)), a, b, uv0, uv1, col);
      if (pio.DrawCallback_ResetRenderState != nullptr) dl->AddCallback(pio.DrawCallback_ResetRenderState, nullptr);
      break;
   }
   default: break;
   }
   if (layer == L_PLOT) ImPlot::PopPlotClipRect();
   return FIG_OK;
   FIG_CATCH_CANVAS
}

extern "C" void fig_cursor_screen_pos(double *x, double *y) {
   *x = 0.0;
   *y = 0.0;
   if (!ImGui::GetCurrentContext()) return;
   const ImVec2 p = ImGui::GetCursorScreenPos();
   *x = p.x;
   *y = p.y;
}

extern "C" int fig_invisible_button(const char *id, int id_len, double width, double height, int *pressed) {
   FIG_TRY_CANVAS
   *pressed = 0;
   if (!ImGui::GetCurrentContext()) return fail(FIG_ERR_STATE, "figure is not initialized");
   const std::string label(id, static_cast<size_t>(std::max(id_len, 0)));
   const ImVec2 avail = ImGui::GetContentRegionAvail();
   float w = static_cast<float>(width), h = static_cast<float>(height);
   if (w <= 0.0f) w = std::max(1.0f, avail.x + w);
   if (h <= 0.0f) h = std::max(1.0f, avail.y + h);
   *pressed = ImGui::InvisibleButton(label.c_str(), ImVec2(w, h)) ? 1 : 0;
   return FIG_OK;
   FIG_CATCH_CANVAS
}

extern "C" int fig_drawn_extent_layer(const float *rgba, int layer, float *rect, int *found, int *vertices) {
   *found = 0;
   *vertices = 0;
   if (!ImGui::GetCurrentContext() || !ImGui::GetCurrentWindowRead())
      return fail(FIG_ERR_STATE, "test_drawn_extent: call it inside a window, in a frame");
   const ImDrawList *dl = layer == L_FOREGROUND   ? ImGui::GetForegroundDrawList()
                          : layer == L_BACKGROUND ? ImGui::GetBackgroundDrawList()
                                                  : ImGui::GetWindowDrawList();
   const ImU32 c = ImGui::GetColorU32(ImVec4(rgba[0], rgba[1], rgba[2], rgba[3]));
   for (const ImDrawVert &v : dl->VtxBuffer) {
      if (v.col != c) continue;
      ++*vertices;
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
   return FIG_OK;
}
