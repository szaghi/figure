// figure_core's reads for the Fortran code editor (szaghi/figure#15 P16, implementation A of the seam: Dear ImGui only).
// Apart from figure_editor.cpp (ImGuiColorTextEdit's glue), so that a program of the Fortran path links them without
// the C++ editor (szaghi/figure#15 G2). Every function is extern "C" and never lets a C++ exception escape
// (figure_native.h).
#include "figure_native.h"

#include "imgui.h"
#include "imgui_internal.h"

#include <algorithm>
#include <cstring>

extern "C" {

// ---- figure_core's reads for the Fortran code editor (szaghi/figure#15 P16; implementation A of the seam) ---------
// What src/paths/fortran/editor/ reads of Dear ImGui that no C API function gives, through
// src/paths/imgui/core/figure_core_text.F90: the current window's and the style's and io's values (f, i), the
// characters typed this frame (taken, as the fork takes them), the input method's position, and the fork's
// navigation-cursor workaround of a child window (TextEditor::render's end, verbatim).

// f: InnerRect size (0, 1), style FontScaleDpi (2), InputTextCursorSize (3), Alpha (4), io DeltaTime (5),
// MouseDoubleClickTime (6), style ScrollbarSize (7), ChildBorderSize (8), WindowPadding (9, 10), ItemSpacing (11, 12),
// FramePadding (13, 14), the window's width (15); i: ScrollbarY (0), ConfigInputTextCursorBlink (1),
// ConfigMacOSXBehaviors (2), ConfigFlags (3), the window's ParentWindow is not null (4).
void fig_core_text_state(float *f, int *i) {
   const ImGuiWindow *w = ImGui::GetCurrentWindowRead();
   const ImGuiStyle &st = ImGui::GetStyle();
   const ImGuiIO &io = ImGui::GetIO();
   const ImVec2 inner = w->InnerRect.GetSize();
   f[0] = inner.x, f[1] = inner.y, f[2] = st.FontScaleDpi, f[3] = st.InputTextCursorSize, f[4] = st.Alpha;
   f[5] = io.DeltaTime, f[6] = io.MouseDoubleClickTime, f[7] = st.ScrollbarSize, f[8] = st.ChildBorderSize;
   f[9] = st.WindowPadding.x, f[10] = st.WindowPadding.y, f[11] = st.ItemSpacing.x, f[12] = st.ItemSpacing.y;
   f[13] = st.FramePadding.x, f[14] = st.FramePadding.y, f[15] = w->Size.x;
   i[0] = w->ScrollbarY ? 1 : 0, i[1] = io.ConfigInputTextCursorBlink ? 1 : 0, i[2] = io.ConfigMacOSXBehaviors ? 1 : 0;
   i[3] = io.ConfigFlags, i[4] = w->ParentWindow != nullptr ? 1 : 0;
}

// The characters typed this frame (up to cap of them, as ImWchar values) and their number; with take, the queue is
// emptied (the fork's io.InputQueueCharacters.resize(0)).
int fig_core_text_chars(int *out, int cap, int take) {
   ImGuiIO &io = ImGui::GetIO();
   const int n = io.InputQueueCharacters.Size;
   for (int k = 0; k < n && k < cap; k++) out[k] = static_cast<int>(io.InputQueueCharacters[k]);
   if (take) io.InputQueueCharacters.resize(0);
   return n;
}

// The code editor's glyphs, a run of n on one row at y, each as the fork's renderText draws it:
// font->RenderChar(drawList, fontSize, ImVec2(x[k], y), col[k], cp[k]), with the current font, the window's draw list
// and the font size taken once (szaghi/figure#16 S10: one call a run, not three getters and a cimgui call a glyph).
void fig_core_text_glyphs(int n, const float *x, float y, const unsigned int *col, const int *cp) {
   ImFont *font = ImGui::GetFont();
   ImDrawList *dl = ImGui::GetWindowDrawList();
   const float size = ImGui::GetFontSize();
   for (int k = 0; k < n; k++) font->RenderChar(dl, size, ImVec2(x[k], y), col[k], static_cast<ImWchar>(cp[k]));
}

// The input method's position (TextEditor::handleKeyboardInputs: visible, text input, at x, y, a line of height h).
void fig_core_text_ime(float x, float y, float h) {
   ImGuiContext *context = ImGui::GetCurrentContext();
   context->PlatformImeData.WantVisible = true;
   context->PlatformImeData.WantTextInput = true;
   context->PlatformImeData.InputPos = ImVec2(x, y);
   context->PlatformImeData.InputLineHeight = h;
   context->PlatformImeData.ViewportId = ImGui::GetCurrentWindow()->Viewport->ID;
}

// TextEditor::render's navigation-cursor workaround for a child window (scale: the style's FontScaleDpi).
void fig_core_text_nav(float scale) {
   if (ImGui::GetIO().ConfigFlags & (ImGuiConfigFlags_NavEnableKeyboard | ImGuiConfigFlags_NavEnableGamepad)) {
      auto window = ImGui::GetCurrentWindow();
      if (ImGui::IsWindowFocused()) {
         if (ImGui::GetCurrentContext()->NavCursorVisible && !window->ScrollbarY) {
            const ImVec2 wp = ImGui::GetWindowPos(), ws = ImGui::GetWindowSize();
            ImRect bb(wp, ImVec2(wp.x + ws.x, wp.y + ws.y));
            bb.Expand(ImVec2(2.0f, 2.0f));
            window->ParentWindow->DrawList->AddRect(bb.Min, bb.Max, ImGui::GetColorU32(ImGuiCol_NavCursor),
                                                    ImGui::GetStyle().FrameRounding, scale);
         }
      } else {
         window->DC.NavLayersActiveMaskNext |= (1 << window->DC.NavLayerCurrent);
      }
   }
}

// The fork's find and replace fields: InputText over a buffer of cap bytes (NUL-terminated); 1 when edited.
int fig_core_text_input(const char *label, char *buf, int cap, int flags) {
   return ImGui::InputText(label, buf, static_cast<size_t>(cap), flags) ? 1 : 0;
}

// The autocomplete popup brought to the front (BringWindowToDisplayFront(GetCurrentWindow())).
void fig_core_text_front(void) { ImGui::BringWindowToDisplayFront(ImGui::GetCurrentWindow()); }

// TextDiff's horizontal scroll bar over [x0, x1] (renderScrollbar(s), verbatim): the frame at the bottom of the current
// window, its rounding in the window, ScrollbarEx by id; scroll (pixels, whole) read and written; 1 when held.
int fig_core_text_hscroll(float x0, float x1, const char *id, long long *scroll, float visible, float total) {
   const auto window = ImGui::GetCurrentWindow();
   const auto outerRect = window->Rect();
   const auto borderSize = std::round(window->WindowBorderSize * 0.5f);
   const auto scrollbarSize = ImGui::GetStyle().ScrollbarSize;
   const auto scrollbarTop = std::max(outerRect.Min.y + borderSize, outerRect.Max.y - borderSize - scrollbarSize);
   const ImRect frame(x0, scrollbarTop, x1, scrollbarTop + scrollbarSize);
   ImS64 s = static_cast<ImS64>(*scroll);
   const auto corners = ImGui::CalcRoundingFlagsForRectInRect(frame, outerRect, ImGui::GetStyle().WindowBorderSize);
   const bool held = ImGui::ScrollbarEx(frame, ImGui::GetID(id), ImGuiAxis_X, &s, static_cast<ImS64>(visible),
                                        static_cast<ImS64>(total), corners);
   *scroll = static_cast<long long>(s);
   return held ? 1 : 0;
}

// The current window's vertical scroll bar (r[0:4], GetWindowScrollbarRect; 1 when it has one), its border size
// (r[4]), GetScrollMaxY (r[5]), io.MouseWheelH (r[6]).
int fig_core_text_vscroll(float *r) {
   const auto window = ImGui::GetCurrentWindow();
   r[4] = window->WindowBorderSize;
   r[5] = ImGui::GetScrollMaxY();
   r[6] = ImGui::GetIO().MouseWheelH;
   if (!window->ScrollbarY) return 0;
   const ImRect rect = ImGui::GetWindowScrollbarRect(window, ImGuiAxis_Y);
   r[0] = rect.Min.x, r[1] = rect.Min.y, r[2] = rect.Max.x, r[3] = rect.Max.y;
   return 1;
}

} // extern "C"
