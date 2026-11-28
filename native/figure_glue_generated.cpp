// FIGURE generated glue (scripts/gen_bindings.py: do not edit).
//
// C wrappers of the cimgui/cimplot/cimplot3d functions that pass structs by value, which Fortran cannot call directly:
// `figure_<name>` takes each such struct by pointer and returns a struct result through `res`. Every wrapper
// is noexcept: Dear ImGui and ImPlot do not throw, and an exception must not unwind through Fortran frames,
// so one would terminate the program. Also: the size of each struct Fortran mirrors (checked by
// src/tests/figure_test_layout.F90) and the C++ defaults of ImPlotSpec. Three files, one per part a program may
// link alone: figure_glue_generated.cpp (Dear ImGui), figure_glue_generated_plot.cpp (ImPlot, ImPlot3D),
// figure_glue_generated_layout.cpp (the plot mirrors' sizes and the spec defaults: no ImPlot function).
// Same includes, in the same order, as cimgui.cpp: cimgui.h's internal section needs the internal headers.
#include "imgui.h"
#include "imgui_internal.h"
#include "cimgui.h"

#include <cstddef>
#include <cstring>

extern "C" {

bool figure_igColorButton(const char* desc_id, const ImVec4_c* col, ImGuiColorEditFlags flags, const ImVec2_c size) noexcept { return igColorButton(desc_id, *col, flags, size); }
ImU32 figure_igColorConvertFloat4ToU32(const ImVec4_c* in) noexcept { return igColorConvertFloat4ToU32(*in); }
void figure_igColorConvertU32ToFloat4(ImU32 in, ImVec4_c* res) noexcept { *res = igColorConvertU32ToFloat4(in); }
ImU32 figure_igGetColorU32_Vec4(const ImVec4_c* col) noexcept { return igGetColorU32_Vec4(*col); }
void figure_igImage(const ImTextureRef_c* tex_ref, const ImVec2_c image_size, const ImVec2_c uv0, const ImVec2_c uv1) noexcept { igImage(*tex_ref, image_size, uv0, uv1); }
bool figure_igImageButton(const char* str_id, const ImTextureRef_c* tex_ref, const ImVec2_c image_size, const ImVec2_c uv0, const ImVec2_c uv1, const ImVec4_c* bg_col, const ImVec4_c* tint_col) noexcept { return igImageButton(str_id, *tex_ref, image_size, uv0, uv1, *bg_col, *tint_col); }
void figure_igImageWithBg(const ImTextureRef_c* tex_ref, const ImVec2_c image_size, const ImVec2_c uv0, const ImVec2_c uv1, const ImVec4_c* bg_col, const ImVec4_c* tint_col) noexcept { igImageWithBg(*tex_ref, image_size, uv0, uv1, *bg_col, *tint_col); }
void figure_igPushStyleColor_Vec4(ImGuiCol idx, const ImVec4_c* col) noexcept { igPushStyleColor_Vec4(idx, *col); }
bool figure_igButtonBehavior(const ImRect_c* bb, ImGuiID id, bool* out_hovered, bool* out_held, ImGuiButtonFlags flags) noexcept { return igButtonBehavior(*bb, id, out_hovered, out_held, flags); }
bool figure_igIsClippedEx(const ImRect_c* bb, ImGuiID id) noexcept { return igIsClippedEx(*bb, id); }
bool figure_igItemAdd(const ImRect_c* bb, ImGuiID id, const ImRect* nav_bb, ImGuiItemFlags extra_flags) noexcept { return igItemAdd(*bb, id, nav_bb, extra_flags); }
bool figure_igItemHoverable(const ImRect_c* bb, ImGuiID id, ImGuiItemFlags item_flags) noexcept { return igItemHoverable(*bb, id, item_flags); }
void figure_igItemSize_Rect(const ImRect_c* bb, float text_baseline_y) noexcept { igItemSize_Rect(*bb, text_baseline_y); }
void figure_ImDrawList_AddImage(ImDrawList* self, const ImTextureRef_c* tex_ref, const ImVec2_c p_min, const ImVec2_c p_max, const ImVec2_c uv_min, const ImVec2_c uv_max, ImU32 col) noexcept { ImDrawList_AddImage(self, *tex_ref, p_min, p_max, uv_min, uv_max, col); }
void figure_ImDrawList_PushTexture(ImDrawList* self, const ImTextureRef_c* tex_ref) noexcept { ImDrawList_PushTexture(self, *tex_ref); }

size_t figure_sizeof_ImVec4_c(void) noexcept { return sizeof(ImVec4_c); }
size_t figure_sizeof_ImTextureRef_c(void) noexcept { return sizeof(ImTextureRef_c); }
size_t figure_sizeof_ImRect_c(void) noexcept { return sizeof(ImRect_c); }

// figure_core's draw list (szaghi/figure#15 P8): a batch of n_vtx vertices (ImDrawVert's layout) and n_idx indices
// (0-based in the batch) appended to an ImDrawList as one primitive (PrimReserve: a new command when the 16-bit
// indices would wrap; with new_cmd, a batch the Fortran list opened where PrimReserve would have started a command,
// that command started first, as PrimReserve starts it, even when the batch, its culled room given back, would fit:
// szaghi/figure#16 S2), and the state its primitives read: _FringeScale, the white pixel's and the anti-aliased line
// textures' UVs (n_lines of them, u0 u1 v 1/thickness), the list's flags.
void figure_ImDrawList_append(ImDrawList* dl, const ImDrawVert* vtx, int n_vtx, const int* idx, int n_idx,
                              int new_cmd) noexcept {
   if (new_cmd && sizeof(ImDrawIdx) == 2 && (dl->Flags & ImDrawFlags_UseVtxOffset)) {
      dl->_CmdHeader.VtxOffset = dl->VtxBuffer.Size;
      dl->_OnChangedVtxOffset();
   }
   if (n_vtx <= 0 || n_idx <= 0) return;
   dl->PrimReserve(n_idx, n_vtx);
   const unsigned int base = dl->_VtxCurrentIdx;
   std::memcpy(dl->_VtxWritePtr, vtx, sizeof(ImDrawVert) * (size_t)n_vtx);
   for (int k = 0; k < n_idx; k++) dl->_IdxWritePtr[k] = (ImDrawIdx)(base + (unsigned int)idx[k]);
   dl->_VtxWritePtr += n_vtx;
   dl->_IdxWritePtr += n_idx;
   dl->_VtxCurrentIdx += (unsigned int)n_vtx;
}
int figure_ImDrawList_shared(const ImDrawList* dl, float* fringe_scale, ImVec2_c* uv_white, ImVec4_c* uv_lines,
                             int n_lines, int* flags) noexcept {
   const int n = IM_DRAWLIST_TEX_LINES_WIDTH_MAX + 1 + IM_DRAWLIST_TEX_LINES_DETAILED_WIDTH_COUNT;
   *fringe_scale = dl->_FringeScale;
   *uv_white = ImVec2_c{dl->_Data->TexUvWhitePixel.x, dl->_Data->TexUvWhitePixel.y};
   *flags = dl->Flags;
   if (dl->_Data->TexUvLines == NULL) return 0;
   for (int k = 0; k < n && k < n_lines; k++) {
      const ImVec4 u = dl->_Data->TexUvLines[k];
      uv_lines[k] = ImVec4_c{u.x, u.y, u.z, u.w};
   }
   return n;
}

// figure_core's runs written in place (szaghi/figure#16 D2, the plot items' primitives): PrimReserve(n_idx, n_vtx),
// then the write cursors and _VtxCurrentIdx moved past the room, as if written; the caller writes the vertices and
// their 16-bit indices (absolute in the draw command, from *base) itself, into the list's buffers (*vtx, *idx: the
// whole of them, sizes included; a reservation may move them). The unreservation is PrimUnreserve with the cursors
// and _VtxCurrentIdx moved back: the end of the last room given back, unwritten.
static_assert(sizeof(ImDrawIdx) == 2, "figure_core's runs write 16-bit indices");
void figure_ImDrawList_reserve(ImDrawList* dl, int n_vtx, int n_idx, int* base, ImDrawVert** vtx, int* vtx_size,
                               ImDrawIdx** idx, int* idx_size) noexcept {
   dl->PrimReserve(n_idx, n_vtx);
   *base = (int)dl->_VtxCurrentIdx;
   dl->_VtxCurrentIdx += (unsigned int)n_vtx;
   dl->_VtxWritePtr = dl->VtxBuffer.Data + dl->VtxBuffer.Size;
   dl->_IdxWritePtr = dl->IdxBuffer.Data + dl->IdxBuffer.Size;
   *vtx = dl->VtxBuffer.Data, *vtx_size = dl->VtxBuffer.Size;
   *idx = dl->IdxBuffer.Data, *idx_size = dl->IdxBuffer.Size;
}
void figure_ImDrawList_unreserve(ImDrawList* dl, int n_vtx, int n_idx) noexcept {
   dl->PrimUnreserve(n_idx, n_vtx);
   dl->_VtxCurrentIdx -= (unsigned int)n_vtx;
   dl->_VtxWritePtr = dl->VtxBuffer.Data + dl->VtxBuffer.Size;
   dl->_IdxWritePtr = dl->IdxBuffer.Data + dl->IdxBuffer.Size;
}

// The input state the plot frame reads (#15 P10 step 8: ImPlot's UpdateInput) that no C API function gives: the
// frame's mouse delta (mouse[0:2]), the wheel (mouse[2], horizontal mouse[3]), the squared distance each button has
// travelled since its click (mouse[4:9], MouseDragMaxDistanceSqr), the key mods (state[0], io.KeyMods) and whether a
// drag and drop is active (state[1], g.DragDropActive).
void figure_io_input(float* mouse, int* state) noexcept {
   const ImGuiIO& io = ImGui::GetIO();
   mouse[0] = io.MouseDelta.x, mouse[1] = io.MouseDelta.y, mouse[2] = io.MouseWheel, mouse[3] = io.MouseWheelH;
   for (int k = 0; k < 5; k++) mouse[4 + k] = io.MouseDragMaxDistanceSqr[k];
   state[0] = (int)io.KeyMods;
   state[1] = GImGui->DragDropActive ? 1 : 0;
}

// The draw data as a renderer reads them (#15 P9: the Fortran path's renderers, through figure_render_imgui): the
// lists (-1: no valid data) and the view (display position, size, framebuffer scale), each list's buffers, each
// command (clip rectangle, texture, offsets and count; the result: 0 a draw, 1-4 the sampler callbacks reset, from the
// texture, linear, nearest, 5 a program's own callback), and the pixels of Dear ImGui's own textures.
int figure_ImDrawData_get(const ImDrawData* dd, float* view) noexcept {
   if (dd == NULL || !dd->Valid) return -1;
   view[0] = dd->DisplayPos.x, view[1] = dd->DisplayPos.y, view[2] = dd->DisplaySize.x, view[3] = dd->DisplaySize.y;
   view[4] = dd->FramebufferScale.x, view[5] = dd->FramebufferScale.y;
   return dd->CmdLists.Size;
}
void figure_ImDrawData_list(const ImDrawData* dd, int l, const ImDrawVert** vtx, int* n_vtx, const ImDrawIdx** idx,
                            int* n_idx, int* n_cmd) noexcept {
   const ImDrawList* dl = dd->CmdLists[l];
   *vtx = dl->VtxBuffer.Data, *n_vtx = dl->VtxBuffer.Size;
   *idx = dl->IdxBuffer.Data, *n_idx = dl->IdxBuffer.Size;
   *n_cmd = dl->CmdBuffer.Size;
}
int figure_ImDrawData_cmd(const ImDrawData* dd, int l, int c, float* clip, const void** tex_data,
                          unsigned long long* tex_id, unsigned int* offsets) noexcept {
   const ImDrawCmd& cmd = dd->CmdLists[l]->CmdBuffer[c];
   clip[0] = cmd.ClipRect.x, clip[1] = cmd.ClipRect.y, clip[2] = cmd.ClipRect.z, clip[3] = cmd.ClipRect.w;
   *tex_data = cmd.TexRef._TexData;
   *tex_id = (unsigned long long)cmd.TexRef._TexID;
   offsets[0] = cmd.VtxOffset, offsets[1] = cmd.IdxOffset, offsets[2] = cmd.ElemCount;
   if (cmd.UserCallback == NULL) return 0;
   const ImGuiPlatformIO& pio = ImGui::GetPlatformIO();
   if (cmd.UserCallback == pio.DrawCallback_ResetRenderState) return 1;
   if (cmd.UserCallback == pio.DrawCallback_SetSamplerFromTex) return 2;
   if (cmd.UserCallback == pio.DrawCallback_SetSamplerLinear) return 3;
   if (cmd.UserCallback == pio.DrawCallback_SetSamplerNearest) return 4;
   return 5;
}
int figure_ImTextureData_pixels(const void* tex_data, const unsigned char** pixels, int* width, int* height,
                                int* channels) noexcept {
   const ImTextureData* td = (const ImTextureData*)tex_data;
   if (td == NULL || td->Pixels == NULL) return 0;
   if (td->Format != ImTextureFormat_RGBA32 && td->Format != ImTextureFormat_Alpha8) return 0;
   *pixels = td->Pixels, *width = td->Width, *height = td->Height;
   *channels = td->Format == ImTextureFormat_Alpha8 ? 1 : 4;
   return 1;
}

// The renderer back end's side of Dear ImGui (#15 P9: the Fortran path's OpenGL 3 renderer, figure_render_gl3): what
// imgui_impl_opengl3.cpp's Init sets (on 1: the back end's name, the flags RendererHasTextures and, with vtx_offset,
// RendererHasVtxOffset, the texture size limit, the samplers' callbacks) and its Shutdown clears (on 0); the textures
// a frame asks for (ImDrawData::Textures; with no draw data the platform's, at shutdown), each one's state and update
// rectangles, its GL name and status set once handled; a program's own callback called with its list and command.
void figure_renderer_backend(int on, int vtx_offset, int max_texture, ImDrawCallback reset, ImDrawCallback from_tex,
                             ImDrawCallback linear, ImDrawCallback nearest) noexcept {
   ImGuiIO& io = ImGui::GetIO();
   ImGuiPlatformIO& pio = ImGui::GetPlatformIO();
   if (on) {
      io.BackendRendererName = "figure_render_gl3";
      if (vtx_offset) io.BackendFlags |= ImGuiBackendFlags_RendererHasVtxOffset;
      io.BackendFlags |= ImGuiBackendFlags_RendererHasTextures;
      pio.Renderer_TextureMaxWidth = pio.Renderer_TextureMaxHeight = max_texture;
      pio.DrawCallback_ResetRenderState = reset;
      pio.DrawCallback_SetSamplerLinear = linear;
      pio.DrawCallback_SetSamplerNearest = nearest;
      pio.DrawCallback_SetSamplerFromTex = from_tex;
   } else {
      io.BackendRendererName = NULL;
      io.BackendRendererUserData = NULL;
      io.BackendFlags &= ~(ImGuiBackendFlags_RendererHasVtxOffset | ImGuiBackendFlags_RendererHasTextures |
                           ImGuiBackendFlags_RendererHasViewports);
      pio.ClearRendererHandlers();
   }
}
int figure_ImDrawData_textures(const ImDrawData* dd) noexcept {
   if (dd == NULL) return ImGui::GetPlatformIO().Textures.Size;
   return dd->Textures != NULL ? dd->Textures->Size : 0;
}
void* figure_ImDrawData_texture(const ImDrawData* dd, int k) noexcept {
   return dd == NULL ? ImGui::GetPlatformIO().Textures[k] : (*dd->Textures)[k];
}
int figure_ImTextureData_state(const void* tex_data, int* status, int* format, int* width, int* height,
                               unsigned long long* tex_id, int* unused_frames, int* ref_count) noexcept {
   const ImTextureData* td = (const ImTextureData*)tex_data;
   *status = td->Status, *format = td->Format, *width = td->Width, *height = td->Height;
   *tex_id = (unsigned long long)td->TexID, *unused_frames = td->UnusedFrames, *ref_count = td->RefCount;
   return td->Updates.Size;
}
void figure_ImTextureData_rect(const void* tex_data, int k, int* rect) noexcept {
   const ImTextureRect& r = ((const ImTextureData*)tex_data)->Updates[k];
   rect[0] = r.x, rect[1] = r.y, rect[2] = r.w, rect[3] = r.h;
}
void figure_ImTextureData_set(void* tex_data, unsigned long long tex_id, int status) noexcept {
   ImTextureData* td = (ImTextureData*)tex_data;
   td->SetTexID((ImTextureID)tex_id);
   td->SetStatus((ImTextureStatus)status);
}
unsigned long long figure_ImTextureData_id(const void* tex_data) noexcept {
   return (unsigned long long)((const ImTextureData*)tex_data)->TexID;
}
void figure_ImDrawData_callback(const ImDrawData* dd, int l, int c) noexcept {
   const ImDrawList* dl = dd->CmdLists[l];
   const ImDrawCmd* cmd = &dl->CmdBuffer[c];
   if (cmd->UserCallback != NULL) cmd->UserCallback(dl, cmd);
}

} // extern "C"
