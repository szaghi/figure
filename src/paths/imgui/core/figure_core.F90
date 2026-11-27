!< figure_core, the inner seam: what the layers above the core need from it (implementation over Dear ImGui).
module figure_core
!< figure_core, the inner seam: what the layers above the core need from it (implementation over Dear ImGui).
!<
!< szaghi/figure#15 P8. The layers above the core (plots, 3-D plots, gizmos, Markdown, the code editor: block D) are to
!< talk to this interface only; it has two implementations under the same module name, chosen by a build mode's `src`
!< (#15 §2): this one, `src/paths/imgui/core/`, a thin layer over Dear ImGui through the generated bindings
!< (figure_cimgui, figure_cimgui_core), with no behaviour of its own; and the Fortran core of block E, later, in
!< `src/paths/fortran/core/`. The groups, from what ImPlot, ImPlot3D, ImGuizmo, imgui_rich_md and ImGuiColorTextEdit call
!< (the inventory of P8's log):
!<
!< - IDs and the ID stack: `core_get_id`, `core_push_id`, `core_pop_id`;
!< - items and their behaviour: `core_item_size`, `core_item_add`, `core_button_behavior`, `core_keep_alive`,
!<   `core_item_hovered`, `core_item_active`, `core_active_id`, `core_hovered_id`;
!< - the window and the frame: `core_cursor_screen_pos`, `core_set_cursor_screen_pos`, `core_content_region_avail`,
!<   `core_window_pos`, `core_window_size`, `core_frame_count`, `core_time`, `core_font_size`, `core_frame_height`,
!<   `core_text_size`;
!< - style: `core_style_color` (a style colour as a packed colour), `core_style_var` (a style variable by its
!<   `ImGuiStyle` name), `core_color` (a colour packed as Dear ImGui packs it);
!< - input: `core_mouse_pos`, `core_mouse_down`, `core_mouse_clicked`, `core_mouse_released`,
!<   `core_mouse_hovering_rect`, `core_key_down`, `core_key_pressed`;
!< - the draw list: `core_draw_begin` (the current window's), then lines, rectangles, triangles, convex polygons,
!<   polylines, circles, text, images, clip rectangles and callbacks, and `core_draw_end`; for the plot frame
!<   (src/paths/fortran/plot/), Dear ImGui 1.93's axis-aligned lines (`core_draw_line_h`, `core_draw_line_v`), a
!<   line's texture (`core_line_texture`) and a textured quad (`core_draw_quad_uv`), thin wrappers of the list's calls;
!<   szaghi/figure#16 S2: the batch interface of the Fortran draw list for the frames' loops (`core_prim_reserve`,
!<   `core_prim_unreserve`, `core_prim_vtx_current`, and `core_prim_list`, the list itself, written in place: no Dear
!<   ImGui type); szaghi/figure#16 D2, the plot items' runs written in place in the target's own buffers, no second copy
!<   (`core_run_reserve`, `core_run_unreserve`, `core_run_vtx_current`: the room as `draw_vert` vertices and 16-bit
!<   indices, absolute in the draw command, as Dear ImGui's `PrimReserve` gives it; implementation B gives the same
!<   room in its own list);
!< - for the plot frame's input and menus (szaghi/figure#15 P10 step 8, ImPlot's `UpdateInput` and context menus):
!<   the input state no C API gives (`core_io_input`: io.MouseDelta, MouseWheel, MouseWheelH, MouseDragMaxDistanceSqr,
!<   KeyMods, g.DragDropActive), `core_mouse_drag_delta`, `core_mouse_double_clicked`, `core_mouse_pos_valid`,
!<   `core_window_hovered`, `core_set_key_owner`, `core_set_mouse_cursor`; IDs `core_push_override_id`,
!<   `core_push_id_int`; ImPlot's menu widgets as it calls them (`core_push_item_width` without a FIGURE scope,
!<   `core_push_item_flag`, `core_push_style_var`, `core_drag_double`, `core_radio_button`, `core_invisible_button`,
!<   `core_text_unformatted`; P10 step 9: `core_open_popup`, `core_begin_popup`, `core_end_popup`, the popups ImPlot
!<   declares every frame, without the allocations of src/lib's `ig_*_popup` and their scope record; a popup by its ID,
!<   `core_open_popup_id`, `core_begin_popup_id`: ImPlot's legend entries' popups, `OpenPopupEx`, `BeginPopupEx`); P11: the white
!<   pixel's texture coordinates (`core_white_pixel`) and the framebuffer scale (`core_framebuffer_scale`) for the
!<   items' primitives and decimation; `core_texture_sampling`, the texture filter callback around a user image;
!<   a glyph of the current font at its size (`core_font_glyph`: `GetFontBaked`, `FindGlyph`), for text drawn glyph by
!<   glyph (ImPlot's vertical text); a rectangle of four corner colours (`core_draw_rect_filled_multicolor`:
!<   `AddRectFilledMultiColor`, ImPlot's colour bars); P13: triangles appended as given (`core_draw_prims`, the 3-D
!<   plots' depth-sorted list); P14, the gradient editor's widgets (`core_begin_child`, `core_end_child`,
!<   `core_begin_group`, `core_end_group`, `core_dummy`, `core_same_line`, `core_begin_disabled`, `core_end_disabled`,
!<   `core_button`, `core_color_edit3`) and the window's storage (`core_storage_int`, `core_set_storage_int`); the
!<   gizmos' (`core_any_item_hovered`, `core_any_item_active`, `core_set_active_id`, `core_clear_active_id`,
!<   `core_want_capture_mouse`, `core_window_hover_state`).
!<
!< The draw list is built in Fortran (figure_drawlist, the first piece of block E) and appended to the window's Dear
!< ImGui list by `core_draw_end`: the primitives figure_drawlist tessellates (filled rectangles without rounding,
!< lines, filled triangles and convex polygons, textured quads and the frames' batches) are kept there, its finished
!< batches appended as soon as a new one opens (the list's sink), its first batch opened in the window's draw command
!< as Dear ImGui's `PrimReserve` would continue it (`dl_open` with its `_VtxCurrentIdx`); the others (rounded rectangles, outlines, polylines,
!< circles, text, images, clip rectangles, callbacks) are drawn by Dear ImGui's list after what is pending was appended,
!< so the order of the primitives is the order of the calls. Coordinates are screen pixels (`real(real64)`, as the
!< public API's); colours are packed `ImU32` in an `integer(int32)`, red in the low byte (`core_color`).
!<
!< No allocation per item: text and IDs go through a buffer of the module (NUL-terminated copies, `to_buf`, no
!< concatenation; a text longer than the buffer gets an allocated copy).
use, intrinsic :: iso_c_binding, only : c_associated, c_bool, c_char, c_double, c_f_pointer, c_float, c_funptr, c_int, &
                                         c_int16_t, c_int32_t, c_loc, c_null_char, c_null_ptr, c_ptr, &
                                         c_size_t
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use figure_cimgui, only : im_rect, im_texture_ref, im_vec2, im_vec4, igCalcTextSize, igGetColorU32_Col,             &
                          igGetStyleColorVec4, igGetStyle,                                                      &
                          igGetContentRegionAvail, igGetCursorScreenPos, igGetFont, igGetFontSize, igGetFrameCount,     &
                          igGetFrameHeight, igGetID_Str, igGetMousePos, igGetTime, igGetWindowDrawList, igGetWindowPos, &
                          igGetWindowSize, igIsItemActive, igIsItemHovered, igIsKeyDown_Nil, igIsKeyPressed_Bool,       &
                          igIsMouseClicked_Bool, igIsMouseDown_Nil, igIsMouseHoveringRect, igIsMouseReleased_Nil,       &
                          igPopID, igPushID_Str, igSetCursorScreenPos, igDragScalar, igGetMouseDragDelta,              &
                          igBeginDragDropTarget, igAcceptDragDropPayload, igEndDragDropTarget,                       &
                          igInvisibleButton, igIsMouseDoubleClicked_Nil, igIsMousePosValid, igIsWindowHovered,         &
                          igPopItemFlag, igPopStyleVar, igPushID_Int, igPushItemFlag, igPushItemWidth,                 &
                          igPushStyleVar_Float, igPushStyleVar_Vec2, igRadioButton_Bool, igSetMouseCursor,             &
                          igTextUnformatted, igBeginPopup, igEndPopup, igOpenPopup_Str, igGetIO_Nil
use figure_cimgui_enums, only : ImDrawFlags_Closed, ImGuiDataType_Double_ => ImGuiDataType_Double
use figure_cimgui_core, only : figure_io_input, igPushOverrideID, igSetKeyOwner,                                         &
                               figure_ImDrawList_append, figure_ImDrawList_reserve, figure_ImDrawList_shared,               &
                               figure_ImDrawList_unreserve, igButtonBehavior, igGetActiveID,                                &
                               igGetHoveredID, igItemAdd, igItemSize_Vec2, igKeepAliveID, ImDrawList_AddCallback,          &
                               ImDrawList_AddCircle, ImDrawList_AddCircleFilled, ImDrawList_AddImage, ImDrawList_AddPolyline, &
                               ImDrawList_AddRect, ImDrawList_AddRectFilled, ImDrawList_AddText_Vec2, ImDrawList_PopClipRect, &
                               ImDrawList_PushClipRect, igBeginPopupEx, igOpenPopupEx, &
                               igGetStyleVarInfo,              &
                               ImDrawList_PushTexture, ImDrawList_PopTexture
use figure_c_native, only : fig_texture_sampling
use figure_style, only : ig_get_style_var
use figure_cimgui_core, only : ImDrawList_AddConcavePolyFilled, igArrowButtonEx
use figure_cimgui, only : igBeginCombo, igEndCombo
use figure_c_native, only : fig_window_skip_items
use figure_drawlist, only : dl_prims
use figure_cimgui, only : igBeginChild_ID, igBeginDisabled, igBeginGroup, igButton, igColorEdit3, igDummy, igEndChild,  &
                          igEndDisabled, igEndGroup, igGetStateStorage, igSameLine, igIsAnyItemActive,                &
                          igIsAnyItemHovered, igSetNextFrameWantCaptureMouse
use figure_cimgui_core, only : igClearActiveID, igGetCurrentWindow, igSetActiveID
use figure_c_native, only : fig_window_hover_state
use figure_drawlist, only : draw_list, dl_batch, dl_convex_poly_filled, dl_line, dl_rect_filled, dl_reset, dl_set_state, &
                            dl_triangle_filled, DL_LINE_TEXTURES
use figure_drawlist, only : draw_vert, dl_open, dl_quad_uv, dl_reserve, dl_unreserve, dl_vtx_current

implicit none
private
public :: core_get_id, core_push_id, core_pop_id
public :: core_item_size, core_item_add, core_button_behavior, core_keep_alive, core_item_hovered, core_item_active
public :: core_active_id, core_hovered_id
public :: core_cursor_screen_pos, core_set_cursor_screen_pos, core_content_region_avail, core_window_pos, core_window_size
public :: core_frame_count, core_time, core_font_size, core_frame_height, core_text_size
public :: core_style_color, core_style_var, core_color
public :: core_mouse_pos, core_mouse_down, core_mouse_clicked, core_mouse_released, core_mouse_hovering_rect
public :: core_key_down, core_key_pressed
public :: core_draw_begin, core_draw_end, core_draw_line, core_draw_rect_filled, core_draw_rect, core_draw_triangle_filled
public :: core_draw_convex_poly_filled, core_draw_polyline, core_draw_circle, core_draw_text, core_draw_image
public :: core_push_clip_rect, core_pop_clip_rect, core_draw_callback
public :: core_draw_line_h, core_draw_line_v, core_line_texture, core_draw_quad_uv
public :: core_font_glyph, core_draw_rect_filled_multicolor
public :: core_io_input, core_mouse_drag_delta, core_mouse_double_clicked, core_mouse_pos_valid, core_window_hovered
public :: core_begin_child, core_end_child, core_begin_group, core_end_group, core_dummy, core_same_line   ! P14
public :: core_begin_disabled, core_end_disabled, core_button, core_color_edit3, core_storage_int, core_set_storage_int
public :: core_any_item_hovered, core_any_item_active, core_set_active_id, core_clear_active_id, core_want_capture_mouse
public :: core_window_hover_state
public :: core_set_key_owner, core_set_mouse_cursor, core_push_override_id, core_push_id_int
public :: core_push_item_width, core_push_item_flag, core_pop_item_flag, core_push_style_var, core_pop_style_var
public :: core_drag_double, core_radio_button, core_invisible_button, core_text_unformatted
public :: core_open_popup, core_begin_popup, core_end_popup, core_open_popup_id, core_begin_popup_id
public :: core_style_vec2, core_drop_target, core_end_drop_target, core_window_collapsed
public :: core_white_pixel, core_framebuffer_scale, core_texture_sampling
public :: core_draw_prims, core_delta_time, core_style_color_rgba
public :: core_draw_list
public :: core_draw_concave_poly_filled
public :: core_arrow_button, core_begin_combo, core_end_combo
public :: core_window_skip_items
public :: core_prim_reserve, core_prim_unreserve, core_prim_vtx_current, core_prim_list
public :: core_run_reserve, core_run_unreserve, core_run_vtx_current

integer(int32), parameter :: BUF_LEN = 4096_int32 !< Text copied into the module's buffer up to this length.

character(kind=c_char, len=BUF_LEN + 1), target :: buf  !< NUL-terminated copy of a text or an ID.
type(draw_list), target                         :: list !< The Fortran draw list (`core_draw_begin` .. `core_draw_end`).
type(c_ptr)                                     :: target_list = c_null_ptr !< The Dear ImGui list it goes to.

interface
   ! cimgui's functions of the plot frame's calls (imgui.h, Dear ImGui 1.93), not in the generated layer
   subroutine ImDrawList_AddLineH(self, min_x, max_x, y, col, thickness, flags) bind(C, name='ImDrawList_AddLineH')
   !< ImDrawList::AddLineH(float,float,float,ImU32,float,ImDrawFlags), imgui.h.
   import :: c_float, c_int, c_ptr
   implicit none
   type(c_ptr),    value :: self         !< C `ImDrawList*`.
   real(c_float),  value :: min_x, max_x !< C `float`.
   real(c_float),  value :: y            !< C `float`.
   integer(c_int), value :: col          !< C `ImU32`.
   real(c_float),  value :: thickness    !< C `float`.
   integer(c_int), value :: flags        !< C `ImDrawFlags`.
   endsubroutine ImDrawList_AddLineH

   subroutine ImDrawList_AddLineV(self, x, min_y, max_y, col, thickness, flags) bind(C, name='ImDrawList_AddLineV')
   !< ImDrawList::AddLineV(float,float,float,ImU32,float,ImDrawFlags), imgui.h.
   import :: c_float, c_int, c_ptr
   implicit none
   type(c_ptr),    value :: self         !< C `ImDrawList*`.
   real(c_float),  value :: x            !< C `float`.
   real(c_float),  value :: min_y, max_y !< C `float`.
   integer(c_int), value :: col          !< C `ImU32`.
   real(c_float),  value :: thickness    !< C `float`.
   integer(c_int), value :: flags        !< C `ImDrawFlags`.
   endsubroutine ImDrawList_AddLineV

   subroutine ImDrawList__SelectLineTexture(self, screen_thickness, out_uv0, out_uv1, out_fringe, flags) &
      bind(C, name='ImDrawList__SelectLineTexture')
   !< ImDrawList::_SelectLineTexture(float,ImVec2*,ImVec2*,float*,ImDrawFlags), imgui.h.
   import :: c_float, c_int, c_ptr, im_vec2
   implicit none
   type(c_ptr),    value         :: self             !< C `ImDrawList*`.
   real(c_float),  value         :: screen_thickness !< C `float`.
   type(im_vec2),  intent(out)   :: out_uv0          !< C `ImVec2_c*`.
   type(im_vec2),  intent(out)   :: out_uv1          !< C `ImVec2_c*`.
   real(c_float),  intent(out)   :: out_fringe       !< C `float*`.
   integer(c_int), value         :: flags            !< C `ImDrawFlags`.
   endsubroutine ImDrawList__SelectLineTexture

   subroutine ImDrawList_AddRectFilledMultiColor(self, p_min, p_max, col_upr_left, col_upr_right, col_bot_right, &
                                                 col_bot_left) bind(C, name='ImDrawList_AddRectFilledMultiColor')
   !< ImDrawList::AddRectFilledMultiColor(ImVec2,ImVec2,ImU32 x4), imgui.h.
   import :: c_int, c_ptr, im_vec2
   implicit none
   type(c_ptr),    value :: self                         !< C `ImDrawList*`.
   type(im_vec2),  value :: p_min, p_max                 !< C `const ImVec2_c`.
   integer(c_int), value :: col_upr_left, col_upr_right  !< C `ImU32`.
   integer(c_int), value :: col_bot_right, col_bot_left  !< C `ImU32`.
   endsubroutine ImDrawList_AddRectFilledMultiColor

   function ImFont_GetFontBaked(self, font_size, density) result(res) bind(C, name='ImFont_GetFontBaked')
   !< ImFont::GetFontBaked(float,float), imgui.h.
   import :: c_float, c_ptr
   implicit none
   type(c_ptr),   value :: self      !< C `ImFont*`.
   real(c_float), value :: font_size !< C `float`.
   real(c_float), value :: density   !< C `float` (negative: the current rasterizer density).
   type(c_ptr)          :: res       !< C `ImFontBaked*`.
   endfunction ImFont_GetFontBaked

   function ImFontBaked_FindGlyph(self, c) result(res) bind(C, name='ImFontBaked_FindGlyph')
   !< ImFontBaked::FindGlyph(ImWchar), imgui.h (the fallback glyph when the font has none).
   import :: c_int16_t, c_ptr
   implicit none
   type(c_ptr),        value :: self !< C `ImFontBaked*`.
   integer(c_int16_t), value :: c    !< C `ImWchar` (16 bits).
   type(c_ptr)               :: res  !< C `ImFontGlyph*`.
   endfunction ImFontBaked_FindGlyph

   ! the window's storage, for the gradient editor's state (szaghi/figure#15 P14: ImGradient, FIGURE's patch 0003)
   function ImGuiStorage_GetInt(self, key, default_val) result(res) bind(C, name='ImGuiStorage_GetInt')
   !< ImGuiStorage::GetInt(ImGuiID,int), imgui.h.
   import :: c_int, c_ptr
   implicit none
   type(c_ptr),    value :: self        !< C `ImGuiStorage*`.
   integer(c_int), value :: key         !< C `ImGuiID`.
   integer(c_int), value :: default_val !< C `int`.
   integer(c_int)        :: res         !< C `int`.
   endfunction ImGuiStorage_GetInt

   subroutine ImGuiStorage_SetInt(self, key, val) bind(C, name='ImGuiStorage_SetInt')
   !< ImGuiStorage::SetInt(ImGuiID,int), imgui.h.
   import :: c_int, c_ptr
   implicit none
   type(c_ptr),    value :: self !< C `ImGuiStorage*`.
   integer(c_int), value :: key  !< C `ImGuiID`.
   integer(c_int), value :: val  !< C `int`.
   endsubroutine ImGuiStorage_SetInt
endinterface

type, bind(C) :: im_font_glyph
   !< ImFontGlyph (imgui.h, 1.93): what `core_font_glyph` reads of it.
   integer(c_int32_t) :: bits      !< Colored, Visible, SourceIdx, Codepoint (bit fields).
   real(c_float)      :: advance_x !< AdvanceX.
   real(c_float)      :: x0, y0    !< Glyph corners, from the pen at the line's top.
   real(c_float)      :: x1, y1    !< ...
   real(c_float)      :: u0, v0    !< Texture coordinates.
   real(c_float)      :: u1, v1    !< ...
   integer(c_int32_t) :: pack_id   !< PackId.
endtype im_font_glyph

type, bind(C) :: im_font_baked_head
   !< The first members of ImFontBaked (imgui.h, 1.93), up to Size.
   integer(c_int)  :: index_advance_size     !< IndexAdvanceX.Size.
   integer(c_int)  :: index_advance_capacity !< IndexAdvanceX.Capacity.
   type(c_ptr)     :: index_advance_data     !< IndexAdvanceX.Data.
   real(c_float)   :: fallback_advance_x     !< FallbackAdvanceX.
   real(c_float)   :: size                   !< Size: the size it was baked at [pixels].
endtype im_font_baked_head

type, bind(C) :: payload_head
   !< `ImGuiPayload`'s first members: its data and their size.
   type(c_ptr)    :: data      !< Data.
   integer(c_int) :: data_size !< Size [bytes].
endtype payload_head

type, bind(C) :: style_floats
   !< `ImGuiStyle` read as floats (its first 4 KiB at most: only the variable asked for is read).
   real(c_float) :: f(1024) !< Floats.
endtype style_floats

type, bind(C) :: im_io_head
   !< The first members of ImGuiIO (imgui.h, 1.93), up to DeltaTime.
   integer(c_int) :: config_flags  !< ConfigFlags.
   integer(c_int) :: backend_flags !< BackendFlags.
   real(c_float)  :: display_size(2)              !< DisplaySize.
   real(c_float)  :: display_framebuffer_scale(2) !< DisplayFramebufferScale.
   real(c_float)  :: delta_time                   !< DeltaTime.
endtype im_io_head

type, bind(C) :: im_draw_list_head
   !< The first members of ImDrawList (imgui.h, 1.93), up to _VtxCurrentIdx.
   integer(c_int) :: cmd_size, cmd_capacity !< CmdBuffer's Size, Capacity.
   type(c_ptr)    :: cmd_data               !< ... Data.
   integer(c_int) :: idx_size, idx_capacity !< IdxBuffer's Size, Capacity.
   type(c_ptr)    :: idx_data               !< ... Data.
   integer(c_int) :: vtx_size, vtx_capacity !< VtxBuffer's Size, Capacity.
   type(c_ptr)    :: vtx_data               !< ... Data.
   integer(c_int) :: flags                  !< Flags.
   integer(c_int) :: vtx_current_idx        !< _VtxCurrentIdx (unsigned in C): the open command's vertices.
endtype im_draw_list_head

contains
   ! IDs

   function core_get_id(label) result(id)
   !< The ID of a label in the current ID stack (`##` and `###` as Dear ImGui reads them).
   character(len=*), intent(in) :: label !< Label.
   integer(int32)               :: id    !< ID (`ImGuiID`, an unsigned 32-bit value in its bits).
   character(kind=c_char, len=:), allocatable :: long !< A label longer than the buffer.

   if (len(label) <= BUF_LEN) then
      call to_buf(label)
      id = int(igGetID_Str(buf), int32)
   else
      long = label//c_null_char
      id = int(igGetID_Str(long), int32)
   endif
   endfunction core_get_id

   subroutine core_push_id(label)
   !< Push a label on the ID stack.
   character(len=*), intent(in) :: label !< Label.
   character(kind=c_char, len=:), allocatable :: long !< A label longer than the buffer.

   if (len(label) <= BUF_LEN) then
      call to_buf(label)
      call igPushID_Str(buf)
   else
      long = label//c_null_char
      call igPushID_Str(long)
   endif
   endsubroutine core_push_id

   subroutine core_pop_id()
   !< Pop the ID stack.

   call igPopID()
   endsubroutine core_pop_id

   subroutine core_push_override_id(id)
   !< Push an ID on the ID stack as it is, not hashed (`PushOverrideID`).
   integer(int32), intent(in) :: id !< ID.

   call igPushOverrideID(int(id, c_int))
   endsubroutine core_push_override_id

   subroutine core_push_id_int(i)
   !< Push an integer on the ID stack (`PushID(int)`: its own hash, not a string's).
   integer(int32), intent(in) :: i !< Integer.

   call igPushID_Int(int(i, c_int))
   endsubroutine core_push_id_int

   ! items

   subroutine core_item_size(w, h, baseline)
   !< Reserve an item's room in the layout (`ItemSize`), its text baseline `baseline` pixels from its top (default:
   !< none, -1).
   real(real64), intent(in)           :: w, h     !< Size [pixels].
   real(real64), intent(in), optional :: baseline !< Text baseline [pixels].

   if (present(baseline)) then
      call igItemSize_Vec2(im_vec2(real(w, c_float), real(h, c_float)), real(baseline, c_float))
   else
      call igItemSize_Vec2(im_vec2(real(w, c_float), real(h, c_float)), -1.0_c_float)
   endif
   endsubroutine core_item_size

   function core_item_add(x0, y0, x1, y1, id) result(visible)
   !< Register an item of ID `id` on the rectangle (x0, y0)-(x1, y1) (`ItemAdd`): false when clipped (draw nothing).
   real(real64),   intent(in) :: x0, y0, x1, y1 !< Rectangle [pixels].
   integer(int32), intent(in) :: id             !< ID (0: an item without one).
   logical                    :: visible        !< Not clipped.

   visible = logical(igItemAdd(rect(x0, y0, x1, y1), int(id, c_int), c_null_ptr, 0_c_int))
   endfunction core_item_add

   function core_button_behavior(x0, y0, x1, y1, id, hovered, held, flags) result(pressed)
   !< A button's behaviour on the rectangle (`ButtonBehavior`): pressed this frame, and whether it is hovered and held.
   real(real64),   intent(in)            :: x0, y0, x1, y1 !< Rectangle [pixels].
   integer(int32), intent(in)            :: id             !< The item's ID.
   logical,        intent(out)           :: hovered        !< Hovered.
   logical,        intent(out)           :: held           !< Held.
   integer(int32), intent(in), optional  :: flags          !< `ImGuiButtonFlags` (default 0).
   logical                               :: pressed        !< Pressed.
   logical(c_bool), target               :: h, d           !< C copies.
   integer(c_int)                        :: f              !< Flags.

   f = 0_c_int
   if (present(flags)) f = int(flags, c_int)
   pressed = logical(igButtonBehavior(rect(x0, y0, x1, y1), int(id, c_int), c_loc(h), c_loc(d), f))
   hovered = logical(h)
   held = logical(d)
   endfunction core_button_behavior

   subroutine core_keep_alive(id)
   !< Keep an ID alive this frame without an item (`KeepAliveID`).
   integer(int32), intent(in) :: id !< ID.

   call igKeepAliveID(int(id, c_int))
   endsubroutine core_keep_alive

   function core_item_hovered() result(yes)
   !< The last item is hovered.
   logical :: yes !< Hovered.

   yes = logical(igIsItemHovered(0_c_int))
   endfunction core_item_hovered

   function core_item_active() result(yes)
   !< The last item is active.
   logical :: yes !< Active.

   yes = logical(igIsItemActive())
   endfunction core_item_active

   function core_active_id() result(id)
   !< The active item's ID (0: none).
   integer(int32) :: id !< ID.

   id = int(igGetActiveID(), int32)
   endfunction core_active_id

   function core_hovered_id() result(id)
   !< The hovered item's ID (0: none).
   integer(int32) :: id !< ID.

   id = int(igGetHoveredID(), int32)
   endfunction core_hovered_id

   ! the window and the frame

   subroutine core_cursor_screen_pos(x, y)
   !< The layout cursor [screen pixels].
   real(real64), intent(out) :: x, y !< Position.
   type(im_vec2)             :: p    !< C value.

   p = igGetCursorScreenPos()
   x = real(p%x, real64)
   y = real(p%y, real64)
   endsubroutine core_cursor_screen_pos

   subroutine core_set_cursor_screen_pos(x, y)
   !< Move the layout cursor [screen pixels].
   real(real64), intent(in) :: x, y !< Position.

   call igSetCursorScreenPos(im_vec2(real(x, c_float), real(y, c_float)))
   endsubroutine core_set_cursor_screen_pos

   subroutine core_content_region_avail(w, h)
   !< The room left in the window from the cursor [pixels].
   real(real64), intent(out) :: w, h !< Size.
   type(im_vec2)             :: p    !< C value.

   p = igGetContentRegionAvail()
   w = real(p%x, real64)
   h = real(p%y, real64)
   endsubroutine core_content_region_avail

   subroutine core_window_pos(x, y)
   !< The current window's position [screen pixels].
   real(real64), intent(out) :: x, y !< Position.
   type(im_vec2)             :: p    !< C value.

   p = igGetWindowPos()
   x = real(p%x, real64)
   y = real(p%y, real64)
   endsubroutine core_window_pos

   subroutine core_window_size(w, h)
   !< The current window's size [pixels].
   real(real64), intent(out) :: w, h !< Size.
   type(im_vec2)             :: p    !< C value.

   p = igGetWindowSize()
   w = real(p%x, real64)
   h = real(p%y, real64)
   endsubroutine core_window_size

   function core_frame_count() result(n)
   !< Frames since the start.
   integer(int32) :: n !< Frames.

   n = int(igGetFrameCount(), int32)
   endfunction core_frame_count

   function core_time() result(t)
   !< Time since the start [s].
   real(real64) :: t !< Time.

   t = real(igGetTime(), real64)
   endfunction core_time

   function core_font_size() result(s)
   !< The current font's size [pixels].
   real(real64) :: s !< Size.

   s = real(igGetFontSize(), real64)
   endfunction core_font_size

   function core_frame_height() result(h)
   !< The height of a framed item (font size and frame padding) [pixels].
   real(real64) :: h !< Height.

   h = real(igGetFrameHeight(), real64)
   endfunction core_frame_height

   subroutine core_text_size(text, w, h, hide_after_hash)
   !< The size of a text in the current font [pixels] (`hide_after_hash`: the part before `##` only, default false).
   character(len=*), intent(in)           :: text            !< Text (UTF-8).
   real(real64),     intent(out)          :: w, h            !< Size.
   logical,          intent(in), optional :: hide_after_hash !< Measure the part before `##`.
   type(im_vec2)                          :: p               !< C value.
   logical(c_bool)                        :: hide            !< C copy.
   character(kind=c_char, len=:), allocatable :: long        !< A text longer than the buffer.

   hide = .false.
   if (present(hide_after_hash)) hide = logical(hide_after_hash, c_bool)
   if (len(text) <= BUF_LEN) then
      call to_buf(text)
      p = igCalcTextSize(buf, c_null_ptr, hide, -1.0_c_float)
   else
      long = text//c_null_char
      p = igCalcTextSize(long, c_null_ptr, hide, -1.0_c_float)
   endif
   w = real(p%x, real64)
   h = real(p%y, real64)
   endsubroutine core_text_size

   ! style colours

   function core_style_color(idx, alpha_mul) result(col)
   !< A style colour (`ImGuiCol_*`) as a packed colour, its alpha times the style's and `alpha_mul` (default 1).
   integer(int32), intent(in)           :: idx       !< Colour (`ImGuiCol_*`).
   real(real64),   intent(in), optional :: alpha_mul !< Alpha factor.
   integer(int32)                       :: col       !< Packed colour.
   real(c_float)                        :: a         !< C copy.

   a = 1.0_c_float
   if (present(alpha_mul)) a = real(alpha_mul, c_float)
   col = int(igGetColorU32_Col(int(idx, c_int), a), int32)
   endfunction core_style_color

   function core_drop_target(x0, y0, x1, y1, type, payload, n) result(open)
   !< A drop target on a rectangle (ImPlot's `BeginDragDropTargetPlot`, `...Axis`, `...Legend`: Dear ImGui's
   !< `BeginDragDropTargetCustom`, here an item without an ID on it, `ItemAdd`, then `BeginDragDropTarget`, which the
   !< public API gives), and when open the payload of `type` accepted (`AcceptDragDropPayload`, drawing the target's
   !< highlight): `n` its length on the frame it is delivered (`payload` then allocated and holding it: a frame of a
   !< drop only), else -1 and `payload` untouched. End it with `core_end_drop_target` when true.
   real(real64),     intent(in)    :: x0, y0, x1, y1 !< Rectangle [pixels].
   character(len=*), intent(in)    :: type           !< Payload type (at most 32 characters).
   character(len=:), allocatable, intent(inout) :: payload !< The payload delivered.
   integer(int32),   intent(out)   :: n              !< Its length, or -1.
   logical                         :: open           !< The target opened: end it.
   type(payload_head), pointer     :: p              !< The payload.
   character(kind=c_char), pointer :: d(:)           !< Its bytes.
   type(c_ptr)                     :: cp             !< Its address.
   integer(int32)                  :: k              !< Counter.

   n = -1_int32
   open = .false.
   if (.not. logical(igItemAdd(rect(x0, y0, x1, y1), 0_c_int, c_null_ptr, 0_c_int))) return
   open = logical(igBeginDragDropTarget())
   if (.not. open) return
   call to_buf(type)
   cp = igAcceptDragDropPayload(buf, 0_c_int)
   if (.not. c_associated(cp)) return
   call c_f_pointer(cp, p)
   n = int(p%data_size, int32)
   if (allocated(payload)) deallocate(payload)
   allocate(character(len=max(n, 0_int32)) :: payload)
   if (n > 0_int32) then
      call c_f_pointer(p%data, d, [n])
      do k = 1_int32, n
         payload(k:k) = d(k)
      enddo
   endif
   endfunction core_drop_target

   function core_window_collapsed() result(yes)
   !< The current window skips its items (`ImGuiWindow::SkipItems`, through `core_window_skip_items`): collapsed, or
   !< hidden for its first frames while an auto-resizing window measures itself, as ImPlot's BeginPlot tests.
   logical :: yes !< Items skipped.

   yes = core_window_skip_items() ! SkipItems: collapsed, or hidden while an auto-resizing window measures itself
   endfunction core_window_collapsed

   subroutine core_end_drop_target()
   !< `EndDragDropTarget` (after `core_drop_target` returned true).

   call igEndDragDropTarget()
   endsubroutine core_end_drop_target

   subroutine core_style_vec2(idx, x, y)
   !< A pair of the style by its `ImGuiStyleVar` (`GetStyleVarInfo(idx)->GetVarPtr(&GetStyle())`), without the
   !< allocation of a lookup by name (`core_style_var`: a name past 15 characters is a heap `std::string`). The style
   !< is read as floats (`style_floats`, a scalar pointer: no address arithmetic, since nvfortran 26.9's `transfer` of
   !< an integer to a `c_ptr` allocates on the heap on every call; `transfer` of a `c_ptr` to an integer and an array
   !< `c_f_pointer` do not, measured: https://github.com/szaghi/figure/issues/4#issuecomment-7110453868), the pair at
   !< the info's Offset (the bitfield's high 16 bits, as GCC lays it out).
   integer(int32), intent(in)  :: idx  !< `ImGuiStyleVar` of an `ImVec2` (`ImGuiStyleVar_ItemInnerSpacing`, ...).
   real(real64),   intent(out) :: x, y !< Its components.
   integer(c_int32_t),  pointer :: info !< `ImGuiStyleVarInfo`: Count (8 bits), DataType (8), Offset (16).
   type(style_floats),  pointer :: st   !< The style.
   integer(int32)               :: k    !< The pair's first float.

   call c_f_pointer(igGetStyleVarInfo(int(idx, c_int)), info)
   call c_f_pointer(igGetStyle(), st)
   k = int(ishft(info, -16), int32) / 4_int32 + 1_int32
   x = real(st%f(k), real64)
   y = real(st%f(k + 1_int32), real64)
   endsubroutine core_style_vec2

   subroutine core_style_var(name, values, n)
   !< A style variable by its `ImGuiStyle` name (`'FramePadding'`, `'FrameRounding'`, ...): its value(s) and how many
   !< (1, or 2 for a pair; 0 for an unknown name).
   character(len=*), intent(in)  :: name      !< Name.
   real(real64),     intent(out) :: values(2) !< Values.
   integer(int32),   intent(out) :: n         !< 1 or 2 (0: unknown).
   integer(int32)                :: s         !< Status (an unknown name: n = 0).

   call ig_get_style_var(name, values, n, s)
   endsubroutine core_style_var

   pure function core_color(r, g, b, a) result(col)
   !< A colour [0, 1] packed as Dear ImGui packs it (`ColorConvertFloat4ToU32`: each channel saturated, times 255,
   !< rounded half up; red in the low byte, alpha in the high one).
   real(real64), intent(in) :: r, g, b, a !< Channels.
   integer(int32)           :: col        !< Packed colour.
   integer(int64)           :: u          !< Unsigned value.

   u = ior(ior(byte(r), ishft(byte(g), 8)), ior(ishft(byte(b), 16), ishft(byte(a), 24)))
   if (u >= 2147483648_int64) u = u - 4294967296_int64
   col = int(u, int32)
   contains
      pure function byte(x) result(v)
      !< A channel as a byte (`IM_F32_TO_INT8_SAT`, in C float).
      real(real64), intent(in) :: x !< Channel.
      integer(int64)           :: v !< Byte.

      v = int(min(max(real(x, c_float), 0.0_c_float), 1.0_c_float) * 255.0_c_float + 0.5_c_float, int64)
      endfunction byte
   endfunction core_color

   ! input

   subroutine core_mouse_pos(x, y)
   !< The pointer [screen pixels].
   real(real64), intent(out) :: x, y !< Position.
   type(im_vec2)             :: p    !< C value.

   p = igGetMousePos()
   x = real(p%x, real64)
   y = real(p%y, real64)
   endsubroutine core_mouse_pos

   function core_mouse_down(button) result(yes)
   !< A mouse button (0 left, 1 right, 2 middle) is down.
   integer(int32), intent(in) :: button !< Button.
   logical                    :: yes    !< Down.

   yes = logical(igIsMouseDown_Nil(int(button, c_int)))
   endfunction core_mouse_down

   function core_mouse_clicked(button) result(yes)
   !< A mouse button was clicked this frame.
   integer(int32), intent(in) :: button !< Button.
   logical                    :: yes    !< Clicked.

   yes = logical(igIsMouseClicked_Bool(int(button, c_int), .false._c_bool))
   endfunction core_mouse_clicked

   function core_mouse_released(button) result(yes)
   !< A mouse button was released this frame.
   integer(int32), intent(in) :: button !< Button.
   logical                    :: yes    !< Released.

   yes = logical(igIsMouseReleased_Nil(int(button, c_int)))
   endfunction core_mouse_released

   function core_mouse_hovering_rect(x0, y0, x1, y1, clip) result(yes)
   !< The pointer is in the rectangle (and in the current clip rectangle, `clip` default true).
   real(real64), intent(in)           :: x0, y0, x1, y1 !< Rectangle [pixels].
   logical,      intent(in), optional :: clip           !< Clipped by the clip rectangle.
   logical                            :: yes            !< Hovering.
   logical(c_bool)                    :: c              !< C copy.

   c = .true.
   if (present(clip)) c = logical(clip, c_bool)
   yes = logical(igIsMouseHoveringRect(im_vec2(real(x0, c_float), real(y0, c_float)), &
                                       im_vec2(real(x1, c_float), real(y1, c_float)), c))
   endfunction core_mouse_hovering_rect

   function core_key_down(key) result(yes)
   !< A key (`ImGuiKey_*`) is down.
   integer(int32), intent(in) :: key !< Key.
   logical                    :: yes !< Down.

   yes = logical(igIsKeyDown_Nil(int(key, c_int)))
   endfunction core_key_down

   function core_key_pressed(key, repeat) result(yes)
   !< A key was pressed this frame (`repeat`: the key's repeats too, default true).
   integer(int32), intent(in)           :: key    !< Key.
   logical,        intent(in), optional :: repeat !< Count repeats.
   logical                              :: yes    !< Pressed.
   logical(c_bool)                      :: r      !< C copy.

   r = .true.
   if (present(repeat)) r = logical(repeat, c_bool)
   yes = logical(igIsKeyPressed_Bool(int(key, c_int), r))
   endfunction core_key_pressed

   subroutine core_io_input(dx, dy, wheel, wheel_h, drag_max_sqr, key_mods, drag_drop)
   !< The input state of this frame no C API function gives (Dear ImGui's io and context): the mouse's delta, the
   !< wheels, each button's squared travel since its click, the key mods (`ImGuiMod_*` bits), a drag and drop active.
   real(real64),   intent(out) :: dx, dy          !< io.MouseDelta [pixels].
   real(real64),   intent(out) :: wheel, wheel_h  !< io.MouseWheel, MouseWheelH.
   real(real64),   intent(out) :: drag_max_sqr(5) !< io.MouseDragMaxDistanceSqr [pixels^2].
   integer(int32), intent(out) :: key_mods        !< io.KeyMods.
   logical,        intent(out) :: drag_drop       !< g.DragDropActive.
   real(c_float)               :: m(9)            !< C values.
   integer(c_int)              :: st(2)           !< C values.

   call figure_io_input(m, st)
   dx = real(m(1), real64)
   dy = real(m(2), real64)
   wheel = real(m(3), real64)
   wheel_h = real(m(4), real64)
   drag_max_sqr = real(m(5:9), real64)
   key_mods = int(st(1), int32)
   drag_drop = st(2) /= 0_c_int
   endsubroutine core_io_input

   subroutine core_mouse_drag_delta(button, dx, dy)
   !< The mouse's travel since the button was clicked, while it is down (`GetMouseDragDelta(button, -1)`).
   integer(int32), intent(in)  :: button !< Button (0 left, 1 right, 2 middle).
   real(real64),   intent(out) :: dx, dy !< Travel [pixels].
   type(im_vec2)               :: d      !< C value.

   d = igGetMouseDragDelta(int(button, c_int), -1.0_c_float)
   dx = real(d%x, real64)
   dy = real(d%y, real64)
   endsubroutine core_mouse_drag_delta

   function core_mouse_double_clicked(button) result(yes)
   !< A button double-clicked on this frame (`IsMouseDoubleClicked`).
   integer(int32), intent(in) :: button !< Button.
   logical                    :: yes    !< Double-clicked.

   yes = logical(igIsMouseDoubleClicked_Nil(int(button, c_int)))
   endfunction core_mouse_double_clicked

   function core_mouse_pos_valid() result(yes)
   !< The pointer's position is known (`IsMousePosValid`).
   logical :: yes !< Valid.

   yes = logical(igIsMousePosValid(c_null_ptr))
   endfunction core_mouse_pos_valid

   function core_window_hovered(flags) result(yes)
   !< The current window is hovered (`IsWindowHovered`).
   integer(int32), intent(in), optional :: flags !< `ImGuiHoveredFlags` (default 0).
   logical                              :: yes   !< Hovered.
   integer(c_int)                       :: f     !< C value.

   f = 0_c_int
   if (present(flags)) f = int(flags, c_int)
   yes = logical(igIsWindowHovered(f))
   endfunction core_window_hovered

   subroutine core_set_key_owner(key, id)
   !< Take a key for an ID on this frame (`SetKeyOwner(key, id, 0)`: the wheel kept from the window's scroll).
   integer(int32), intent(in) :: key !< `ImGuiKey`.
   integer(int32), intent(in) :: id  !< Owner ID.

   call igSetKeyOwner(int(key, c_int), int(id, c_int), 0_c_int)
   endsubroutine core_set_key_owner

   subroutine core_set_mouse_cursor(cursor)
   !< The mouse cursor's shape for this frame (`SetMouseCursor`).
   integer(int32), intent(in) :: cursor !< `ImGuiMouseCursor`.

   call igSetMouseCursor(int(cursor, c_int))
   endsubroutine core_set_mouse_cursor

   subroutine core_push_item_width(width)
   !< `PushItemWidth`, as ImPlot calls it (no FIGURE scope: the window's end pops it).
   real(real64), intent(in) :: width !< Width [pixels].

   call igPushItemWidth(real(width, c_float))
   endsubroutine core_push_item_width

   subroutine core_push_item_flag(flag, on)
   !< `PushItemFlag`.
   integer(int32), intent(in) :: flag !< `ImGuiItemFlags`.
   logical,        intent(in) :: on   !< Set.

   call igPushItemFlag(int(flag, c_int), logical(on, c_bool))
   endsubroutine core_push_item_flag

   subroutine core_pop_item_flag()
   !< `PopItemFlag`.

   call igPopItemFlag()
   endsubroutine core_pop_item_flag

   subroutine core_push_style_var(idx, x, y)
   !< `PushStyleVar` of a float (`x`) or a vector (`x`, `y`).
   integer(int32), intent(in)           :: idx !< `ImGuiStyleVar`.
   real(real64),   intent(in)           :: x   !< Value (first component).
   real(real64),   intent(in), optional :: y   !< Second component.

   if (present(y)) then
      call igPushStyleVar_Vec2(int(idx, c_int), v2(x, y))
   else
      call igPushStyleVar_Float(int(idx, c_int), real(x, c_float))
   endif
   endsubroutine core_push_style_var

   subroutine core_pop_style_var(count)
   !< `PopStyleVar`.
   integer(int32), intent(in), optional :: count !< Variables (default 1).

   if (present(count)) then
      call igPopStyleVar(int(count, c_int))
   else
      call igPopStyleVar(1_c_int)
   endif
   endsubroutine core_pop_style_var

   function core_drag_double(label, v, speed, vmin, vmax, format, flags) result(changed)
   !< `DragScalar` of a double (ImPlot's `DragFloat<double>`).
   character(len=*), intent(in)    :: label  !< Label.
   real(real64),     intent(inout) :: v      !< Value.
   real(real64),     intent(in)    :: speed  !< Speed (as a float).
   real(real64),     intent(in)    :: vmin   !< Minimum.
   real(real64),     intent(in)    :: vmax   !< Maximum.
   character(len=*), intent(in)    :: format !< printf format.
   integer(int32),   intent(in)    :: flags  !< `ImGuiSliderFlags`.
   logical                         :: changed !< Changed.
   real(c_double), target          :: cv, cmin, cmax !< C copies.
   character(kind=c_char, len=:), allocatable, target :: cfmt !< Format, NUL-terminated (a long label and format).
   character(kind=c_char, len=:), allocatable        :: clabel !< Label, NUL-terminated (...).
   integer(int32)                  :: nl     !< The label's length.

   cv = v
   cmin = vmin
   cmax = vmax
   nl = len(label, kind=int32)
   if (nl + len(format, kind=int32) + 1_int32 <= BUF_LEN) then ! both in the buffer, one after the other
      call to_buf(label)
      call to_buf(format, nl + 2_int32)
      changed = logical(igDragScalar(buf, ImGuiDataType_Double_, c_loc(cv), real(speed, c_float), c_loc(cmin), &
                                     c_loc(cmax), c_loc(buf(nl + 2_int32:nl + 2_int32)), int(flags, c_int)))
   else
      cfmt = format//c_null_char
      clabel = label//c_null_char
      changed = logical(igDragScalar(clabel, ImGuiDataType_Double_, c_loc(cv), real(speed, c_float), c_loc(cmin), &
                                     c_loc(cmax), c_loc(cfmt), int(flags, c_int)))
   endif
   v = cv
   endfunction core_drag_double

   function core_arrow_button(id, dir, w, h) result(pressed)
   !< `ArrowButtonEx(id, dir, ImVec2(w, h), 0)`: a button with an arrow, of a given size (ImPlot's date picker).
   character(len=*), intent(in) :: id      !< ID (`##...`).
   integer(int32),   intent(in) :: dir     !< `ImGuiDir`.
   real(real64),     intent(in) :: w, h    !< Size [pixels].
   logical                      :: pressed !< Clicked this frame.

   call to_buf(id(1:min(len(id), BUF_LEN)))
   pressed = logical(igArrowButtonEx(buf, int(dir, c_int), v2(w, h), 0_c_int))
   endfunction core_arrow_button

   function core_begin_combo(label, preview, flags) result(open)
   !< `BeginCombo(label, preview, flags)`; when true, its lines (`ig_selectable`), then `core_end_combo`.
   character(len=*), intent(in) :: label   !< Label.
   character(len=*), intent(in) :: preview !< The text shown closed.
   integer(int32),   intent(in) :: flags   !< `ImGuiComboFlags`.
   logical                      :: open    !< Open.
   integer(int32)               :: a       !< Where the preview starts in the buffer.

   a = len(label, kind=int32) + 2_int32
   if (a + len(preview, kind=int32) > BUF_LEN) error stop 'figure_core: core_begin_combo: texts too long'
   call to_buf(label)
   call to_buf(preview, a)
   open = logical(igBeginCombo(buf, buf(a:), int(flags, c_int)))
   endfunction core_begin_combo

   subroutine core_end_combo()
   !< `EndCombo` (after `core_begin_combo` returned true).

   call igEndCombo()
   endsubroutine core_end_combo

   function core_window_skip_items() result(yes)
   !< The current window skips its items (`ImGuiWindow::SkipItems`): collapsed, or hidden for its first frames while an
   !< auto-resizing window measures itself (what `IsWindowCollapsed` does not tell). ImPlot's `BeginPlot` and
   !< `BeginSubplots` return false then.
   logical :: yes !< Skipped.

   yes = fig_window_skip_items() /= 0_c_int
   endfunction core_window_skip_items

   function core_radio_button(label, active) result(pressed)
   !< `RadioButton(label, active)`.
   character(len=*), intent(in) :: label   !< Label.
   logical,          intent(in) :: active  !< Selected.
   logical                      :: pressed !< Pressed.

   if (len(label) <= BUF_LEN) then
      call to_buf(label)
      pressed = logical(igRadioButton_Bool(buf, logical(active, c_bool)))
   else
      pressed = logical(igRadioButton_Bool(label//c_null_char, logical(active, c_bool)))
   endif
   endfunction core_radio_button

   function core_invisible_button(id, w, h) result(pressed)
   !< `InvisibleButton(id, (w, h))`.
   character(len=*), intent(in) :: id      !< ID.
   real(real64),     intent(in) :: w, h    !< Size [pixels].
   logical                      :: pressed !< Pressed.

   if (len(id) <= BUF_LEN) then
      call to_buf(id)
      pressed = logical(igInvisibleButton(buf, v2(w, h), 0_c_int))
   else
      pressed = logical(igInvisibleButton(id//c_null_char, v2(w, h), 0_c_int))
   endif
   endfunction core_invisible_button

   subroutine core_text_unformatted(text)
   !< `TextUnformatted`.
   character(len=*), intent(in) :: text !< Text.

   if (len(text) <= BUF_LEN) then
      call to_buf(text)
      call igTextUnformatted(buf, c_null_ptr)
   else
      call igTextUnformatted(text//c_null_char, c_null_ptr)
   endif
   endsubroutine core_text_unformatted

   subroutine core_open_popup(id)
   !< `OpenPopup(id)` (ImPlot's context menus: Dear ImGui's call, without FIGURE's scope record of `ig_open_popup`).
   character(len=*), intent(in) :: id !< Popup id.

   if (len(id) <= BUF_LEN) then
      call to_buf(id)
      if (igOpenPopup_Str(buf, 0_c_int)) continue
   else
      if (igOpenPopup_Str(id//c_null_char, 0_c_int)) continue
   endif
   endsubroutine core_open_popup

   function core_begin_popup(id) result(open)
   !< `BeginPopup(id, 0)`, every frame (ImPlot's context menus; `ig_begin_popup` without FIGURE's scope record: end it
   !< with `core_end_popup`, only when true).
   character(len=*), intent(in) :: id   !< Popup id.
   logical                      :: open !< Open.

   if (len(id) <= BUF_LEN) then
      call to_buf(id)
      open = logical(igBeginPopup(buf, 0_c_int))
   else
      open = logical(igBeginPopup(id//c_null_char, 0_c_int))
   endif
   endfunction core_begin_popup

   subroutine core_open_popup_id(id)
   !< `OpenPopupEx(id, ImGuiPopupFlags_None)`: the popup of an ID (ImPlot's `BeginLegendPopup`).
   integer(int32), intent(in) :: id !< Popup's ID.

   if (igOpenPopupEx(int(id, c_int), 0_c_int)) continue
   endsubroutine core_open_popup_id

   function core_begin_popup_id(id, flags) result(open)
   !< `BeginPopupEx(id, flags)`, every frame (ImPlot's `BeginLegendPopup`; end it with `core_end_popup`, only when
   !< true).
   integer(int32), intent(in) :: id    !< Popup's ID.
   integer(int32), intent(in) :: flags !< ImGuiWindowFlags added.
   logical                    :: open  !< Open.

   open = logical(igBeginPopupEx(int(id, c_int), int(flags, c_int)))
   endfunction core_begin_popup_id

   subroutine core_end_popup()
   !< `EndPopup` (after `core_begin_popup` returned true).

   call igEndPopup()
   endsubroutine core_end_popup

   ! the gradient editor's widgets (szaghi/figure#15 P14: ImGradient and its FIGURE glue)

   function core_begin_child(id, w, h, flags) result(visible)
   !< `BeginChild(id, (w, h), flags, 0)`: a child window of a given ID; `core_end_child` after it, whatever the result.
   integer(int32), intent(in) :: id      !< ID.
   real(real64),   intent(in) :: w, h    !< Size [pixels].
   integer(int32), intent(in) :: flags   !< `ImGuiChildFlags`.
   logical                    :: visible !< Visible.

   visible = logical(igBeginChild_ID(int(id, c_int), v2(w, h), int(flags, c_int), 0_c_int))
   endfunction core_begin_child

   subroutine core_end_child()
   !< `EndChild`.

   call igEndChild()
   endsubroutine core_end_child

   subroutine core_begin_group()
   !< `BeginGroup`.

   call igBeginGroup()
   endsubroutine core_begin_group

   subroutine core_end_group()
   !< `EndGroup`.

   call igEndGroup()
   endsubroutine core_end_group

   subroutine core_dummy(w, h)
   !< `Dummy((w, h))`: room in the layout, no item.
   real(real64), intent(in) :: w, h !< Size [pixels].

   call igDummy(v2(w, h))
   endsubroutine core_dummy

   subroutine core_same_line()
   !< `SameLine()`.

   call igSameLine(0.0_c_float, -1.0_c_float)
   endsubroutine core_same_line

   subroutine core_begin_disabled(disabled)
   !< `BeginDisabled(disabled)`; `core_end_disabled` after it.
   logical, intent(in) :: disabled !< Disabled.

   call igBeginDisabled(logical(disabled, c_bool))
   endsubroutine core_begin_disabled

   subroutine core_end_disabled()
   !< `EndDisabled`.

   call igEndDisabled()
   endsubroutine core_end_disabled

   function core_button(label) result(pressed)
   !< `Button(label)`, of its text's size.
   character(len=*), intent(in) :: label   !< Label.
   logical                      :: pressed !< Pressed.

   call to_buf(label(1:min(len(label), BUF_LEN)))
   pressed = logical(igButton(buf, v2(0.0_real64, 0.0_real64)))
   endfunction core_button

   function core_color_edit3(label, rgb, flags) result(changed)
   !< `ColorEdit3(label, rgb, flags)`.
   character(len=*),      intent(in)    :: label   !< Label.
   real(real32), target,  intent(inout) :: rgb(3)  !< Colour (as floats).
   integer(int32),        intent(in)    :: flags   !< `ImGuiColorEditFlags`.
   logical                              :: changed !< Changed.

   call to_buf(label(1:min(len(label), BUF_LEN)))
   changed = logical(igColorEdit3(buf, c_loc(rgb), int(flags, c_int)))
   endfunction core_color_edit3

   function core_storage_int(id, default) result(v)
   !< An integer kept in the current window's storage (`GetStateStorage()->GetInt(id, default)`).
   integer(int32), intent(in) :: id      !< Key.
   integer(int32), intent(in) :: default !< Value when none is kept.
   integer(int32)             :: v       !< Value.

   v = int(ImGuiStorage_GetInt(igGetStateStorage(), int(id, c_int), int(default, c_int)), int32)
   endfunction core_storage_int

   subroutine core_set_storage_int(id, v)
   !< An integer kept in the current window's storage (`GetStateStorage()->SetInt(id, v)`).
   integer(int32), intent(in) :: id !< Key.
   integer(int32), intent(in) :: v  !< Value.

   call ImGuiStorage_SetInt(igGetStateStorage(), int(id, c_int), int(v, c_int))
   endsubroutine core_set_storage_int

   ! the gizmos' (szaghi/figure#15 P14: ImGuizmo and its FIGURE glue)

   function core_any_item_hovered() result(yes)
   !< `IsAnyItemHovered`.
   logical :: yes !< An item is hovered.

   yes = logical(igIsAnyItemHovered())
   endfunction core_any_item_hovered

   function core_any_item_active() result(yes)
   !< `IsAnyItemActive`.
   logical :: yes !< An item is active.

   yes = logical(igIsAnyItemActive())
   endfunction core_any_item_active

   subroutine core_set_active_id(id)
   !< `SetActiveID(id, the current window)`.
   integer(int32), intent(in) :: id !< ID.

   call igSetActiveID(int(id, c_int), igGetCurrentWindow())
   endsubroutine core_set_active_id

   subroutine core_clear_active_id()
   !< `ClearActiveID`.

   call igClearActiveID()
   endsubroutine core_clear_active_id

   subroutine core_want_capture_mouse()
   !< `SetNextFrameWantCaptureMouse(true)`.

   call igSetNextFrameWantCaptureMouse(.true._c_bool)
   endsubroutine core_want_capture_mouse

   subroutine core_window_hover_state(state, inner)
   !< The current window as ImGuizmo's `IsHoveringWindow` sees it: `state` 1 Dear ImGui's hovered window, 2 no window
   !< hovered, 0 another one; `inner` its inner rectangle (min x, y, max x, y) [pixels].
   integer(int32), intent(out) :: state    !< State.
   real(real64),   intent(out) :: inner(4) !< Inner rectangle.
   real(c_float)               :: r(4)     !< C copy.

   state = int(fig_window_hover_state(r), int32)
   inner = real(r, real64)
   endsubroutine core_window_hover_state

   subroutine to_buf(s, at)
   !< A text copied into the module's buffer, NUL-terminated, from `at` (default 1); the caller checked it fits. Two
   !< assignments, no concatenation: a concatenation of run-time length is a heap temporary (gfortran).
   character(len=*), intent(in)           :: s  !< Text.
   integer(int32),   intent(in), optional :: at !< Where it starts.
   integer(int32)                         :: a, n !< Start, length.

   a = 1_int32
   if (present(at)) a = at
   n = len(s, kind=int32)
   buf(a:a + n - 1_int32) = s
   buf(a + n:a + n) = c_null_char
   endsubroutine to_buf

   ! the draw list

   subroutine core_draw_begin()
   !< Start drawing into the current window's list: the Fortran list emptied, its state read from Dear ImGui's.
   real(c_float)  :: fringe                         !< Fringe scale.
   type(im_vec2)  :: white                          !< White pixel's UV.
   type(im_vec4)  :: lines(DL_LINE_TEXTURES)        !< Lines' textures.
   real(c_float)  :: uv(4, DL_LINE_TEXTURES)        !< ... as an array.
   integer(c_int) :: n, flags                       !< Textures, flags.
   integer(int32) :: k                              !< Counter.

   if (list%nvtx > 0_int32) call core_draw_end()
   target_list = igGetWindowDrawList()
   call dl_reset(list)
   n = figure_ImDrawList_shared(target_list, fringe, white, lines, int(DL_LINE_TEXTURES, c_int), flags)
   do k = 1_int32, int(n, int32)
      uv(:, k) = [lines(k)%x, lines(k)%y, lines(k)%z, lines(k)%w]
   enddo
   call dl_set_state(list, fringe, [white%x, white%y], uv, int(n, int32), flags)
   endsubroutine core_draw_begin

   subroutine core_draw_end()
   !< Append what is pending to Dear ImGui's list (one primitive per batch) and empty the Fortran list.
   integer(int32) :: k, v0, nv, i0, ni !< Batch, its extent.
   logical        :: split             !< It starts a draw command.

   if (.not. c_associated(target_list)) return
   do k = 1_int32, list%nbatch
      call dl_batch(list, k, v0, nv, i0, ni, split)
      if (nv > 0_int32 .and. ni > 0_int32) then
         call append_batch(list%vtx(v0), nv, list%idx(i0), ni, split)
      elseif (split) then ! empty, the command started all the same
         call append_batch(list%vtx(1), 0_int32, list%idx(1), 0_int32, split)
      endif
   enddo
   call dl_reset(list)
   endsubroutine core_draw_end

   function core_draw_list() result(p)
   !< The Dear ImGui list the drawing goes to (for a layer that hands it to Dear ImGui itself).
   type(c_ptr) :: p !< `ImDrawList*`.

   p = target_list
   endfunction core_draw_list

   subroutine core_draw_line(x1, y1, x2, y2, col, thickness)
   !< A segment (Dear ImGui's `AddLine`), `thickness` pixels wide (default 1).
   real(real64),   intent(in)           :: x1, y1, x2, y2 !< Ends [pixels].
   integer(int32), intent(in)           :: col            !< Packed colour.
   real(real64),   intent(in), optional :: thickness      !< Thickness [pixels].
   real(c_float)                        :: t              !< C copy.

   t = 1.0_c_float
   if (present(thickness)) t = real(thickness, c_float)
   call open_list()
   call dl_line(list, real(x1, c_float), real(y1, c_float), real(x2, c_float), real(y2, c_float), int(col, c_int32_t), t, &
                0_c_int)
   endsubroutine core_draw_line

   subroutine core_draw_rect_filled(x0, y0, x1, y1, col, rounding)
   !< A filled rectangle (`AddRectFilled`), its corners rounded by `rounding` pixels (default 0).
   real(real64),   intent(in)           :: x0, y0, x1, y1 !< Corners [pixels].
   integer(int32), intent(in)           :: col            !< Packed colour.
   real(real64),   intent(in), optional :: rounding       !< Rounding [pixels].

   if (present(rounding)) then
      if (rounding >= 0.5_real64) then
         call core_draw_end_pending()
         call ImDrawList_AddRectFilled(target_list, v2(x0, y0), v2(x1, y1), int(col, c_int), real(rounding, c_float), 0_c_int)
         return
      endif
   endif
   call open_list()
   call dl_rect_filled(list, real(x0, c_float), real(y0, c_float), real(x1, c_float), real(y1, c_float), int(col, c_int32_t))
   endsubroutine core_draw_rect_filled

   subroutine core_draw_rect_filled_multicolor(x0, y0, x1, y1, col_ul, col_ur, col_br, col_bl)
   !< A filled rectangle of four corner colours blended across it (`AddRectFilledMultiColor`).
   real(real64),   intent(in) :: x0, y0, x1, y1 !< Corners [pixels].
   integer(int32), intent(in) :: col_ul, col_ur !< Packed colours: upper left, upper right.
   integer(int32), intent(in) :: col_br, col_bl !< ... bottom right, bottom left.

   call core_draw_end_pending()
   call ImDrawList_AddRectFilledMultiColor(target_list, v2(x0, y0), v2(x1, y1), int(col_ul, c_int), int(col_ur, c_int), &
                                           int(col_br, c_int), int(col_bl, c_int))
   endsubroutine core_draw_rect_filled_multicolor

   subroutine core_draw_rect(x0, y0, x1, y1, col, rounding, thickness)
   !< A rectangle's outline (`AddRect`).
   real(real64),   intent(in)           :: x0, y0, x1, y1 !< Corners [pixels].
   integer(int32), intent(in)           :: col            !< Packed colour.
   real(real64),   intent(in), optional :: rounding       !< Rounding [pixels] (default 0).
   real(real64),   intent(in), optional :: thickness      !< Thickness [pixels] (default 1).

   call core_draw_end_pending()
   call ImDrawList_AddRect(target_list, v2(x0, y0), v2(x1, y1), int(col, c_int), opt(rounding, 0.0_real64), &
                           opt(thickness, 1.0_real64), 0_c_int)
   endsubroutine core_draw_rect

   subroutine core_draw_triangle_filled(x1, y1, x2, y2, x3, y3, col)
   !< A filled triangle (`AddTriangleFilled`).
   real(real64),   intent(in) :: x1, y1, x2, y2, x3, y3 !< Vertices [pixels].
   integer(int32), intent(in) :: col                    !< Packed colour.

   call open_list()
   call dl_triangle_filled(list, real(x1, c_float), real(y1, c_float), real(x2, c_float), real(y2, c_float), &
                           real(x3, c_float), real(y3, c_float), int(col, c_int32_t))
   endsubroutine core_draw_triangle_filled

   subroutine core_draw_convex_poly_filled(x, y, col)
   !< A filled convex polygon, its points clockwise (`AddConvexPolyFilled`); up to 16 points without a heap allocation
   !< (the 3-D frame's quads, every frame).
   real(real64),   intent(in) :: x(:), y(:) !< Points [pixels].
   integer(int32), intent(in) :: col        !< Packed colour.
   integer(int32), parameter  :: NFIX = 16_int32 !< Points converted in fixed arrays.
   real(c_float)              :: fx(NFIX), fy(NFIX) !< Points, C kind.
   integer(int32)             :: n          !< Points.

   call open_list()
   n = size(x, kind=int32)
   if (n <= NFIX) then
      fx(1:n) = real(x, c_float)
      fy(1:n) = real(y, c_float)
      call dl_convex_poly_filled(list, fx(1:n), fy(1:n), int(col, c_int32_t), 0_c_int)
      return
   endif
   call dl_convex_poly_filled(list, real(x, c_float), real(y, c_float), int(col, c_int32_t), 0_c_int) ! nvf-ok: > NFIX
   endsubroutine core_draw_convex_poly_filled

   subroutine core_draw_polyline(x, y, col, thickness, closed)
   !< A polyline (`AddPolyline`), closed or not (default not); up to 256 points without a heap allocation.
   real(real64),   intent(in)           :: x(:), y(:) !< Points [pixels].
   integer(int32), intent(in)           :: col        !< Packed colour.
   real(real64),   intent(in), optional :: thickness  !< Thickness [pixels] (default 1).
   logical,        intent(in), optional :: closed     !< Closed.
   integer(int32), parameter            :: NFIX = 256_int32 !< Points converted in a fixed array (no heap allocation).
   type(im_vec2), target                :: q(NFIX)    !< Points, C layout.
   type(im_vec2), allocatable, target   :: p(:)       !< ... beyond NFIX.
   integer(c_int)                       :: f          !< Flags.
   integer(int32)                       :: k, n       !< Counter, points.

   call core_draw_end_pending()
   f = 0_c_int
   if (present(closed)) then
      if (closed) f = ImDrawFlags_Closed
   endif
   n = size(x, kind=int32)
   if (n <= NFIX) then
      do k = 1_int32, n
         q(k) = im_vec2(real(x(k), c_float), real(y(k), c_float))
      enddo
      call ImDrawList_AddPolyline(target_list, c_loc(q), int(n, c_int), int(col, c_int), opt(thickness, 1.0_real64), f)
      return
   endif
   allocate(p(n))
   do k = 1_int32, n
      p(k) = im_vec2(real(x(k), c_float), real(y(k), c_float))
   enddo
   call ImDrawList_AddPolyline(target_list, c_loc(p), int(size(p), c_int), int(col, c_int), opt(thickness, 1.0_real64), f)
   endsubroutine core_draw_polyline

   subroutine core_draw_concave_poly_filled(x, y, col)
   !< A filled polygon, convex or not, not self-intersecting (`AddConcavePolyFilled`); up to 64 points without a heap
   !< allocation.
   real(real64),   intent(in)         :: x(:), y(:) !< Points [pixels].
   integer(int32), intent(in)         :: col        !< Packed colour.
   integer(int32), parameter          :: NFIX = 64_int32 !< Points converted in a fixed array.
   type(im_vec2), target              :: f(NFIX)    !< Points, C layout.
   type(im_vec2), allocatable, target :: p(:)       !< ... beyond NFIX.
   integer(int32)                     :: k, n       !< Counter, points.

   call core_draw_end_pending()
   n = size(x, kind=int32)
   if (n <= NFIX) then
      do k = 1_int32, n
         f(k) = im_vec2(real(x(k), c_float), real(y(k), c_float))
      enddo
      call ImDrawList_AddConcavePolyFilled(target_list, c_loc(f), int(n, c_int), int(col, c_int))
      return
   endif
   allocate(p(n))
   do k = 1_int32, n
      p(k) = im_vec2(real(x(k), c_float), real(y(k), c_float))
   enddo
   call ImDrawList_AddConcavePolyFilled(target_list, c_loc(p), int(n, c_int), int(col, c_int))
   endsubroutine core_draw_concave_poly_filled

   subroutine core_draw_circle(x, y, radius, col, filled, thickness, segments)
   !< A circle (`AddCircle`, `AddCircleFilled`), `segments` 0 for Dear ImGui's automatic count (default).
   real(real64),   intent(in)           :: x, y, radius !< Centre, radius [pixels].
   integer(int32), intent(in)           :: col          !< Packed colour.
   logical,        intent(in), optional :: filled       !< Filled (default false).
   real(real64),   intent(in), optional :: thickness    !< Outline thickness [pixels] (default 1).
   integer(int32), intent(in), optional :: segments     !< Segments.
   integer(c_int)                       :: s            !< C copy.
   logical                              :: fill         !< Filled.

   call core_draw_end_pending()
   s = 0_c_int
   if (present(segments)) s = int(segments, c_int)
   fill = .false.
   if (present(filled)) fill = filled
   if (fill) then
      call ImDrawList_AddCircleFilled(target_list, v2(x, y), real(radius, c_float), int(col, c_int), s)
   else
      call ImDrawList_AddCircle(target_list, v2(x, y), real(radius, c_float), int(col, c_int), s, opt(thickness, 1.0_real64), &
                                0_c_int)
   endif
   endsubroutine core_draw_circle

   subroutine core_draw_text(x, y, col, text)
   !< A text in the current font, its top-left corner at (x, y) (`AddText`).
   real(real64),     intent(in) :: x, y !< Position [pixels].
   integer(int32),   intent(in) :: col  !< Packed colour.
   character(len=*), intent(in) :: text !< Text (UTF-8).
   character(kind=c_char, len=:), allocatable :: long !< A text longer than the buffer.

   call core_draw_end_pending()
   if (len(text) <= BUF_LEN) then
      call to_buf(text)
      call ImDrawList_AddText_Vec2(target_list, v2(x, y), int(col, c_int), buf, c_null_ptr)
   else
      long = text//c_null_char
      call ImDrawList_AddText_Vec2(target_list, v2(x, y), int(col, c_int), long, c_null_ptr)
   endif
   endsubroutine core_draw_text

   subroutine core_draw_image(texture, x0, y0, x1, y1, u0, v0, u1, v1, col)
   !< A texture on a rectangle (`AddImage`), texture coordinates (u0, v0)-(u1, v1) (default 0-1), tinted by `col`
   !< (default opaque white).
   integer(int64), intent(in)           :: texture        !< Texture (`ImTextureID`).
   real(real64),   intent(in)           :: x0, y0, x1, y1 !< Rectangle [pixels].
   real(real64),   intent(in), optional :: u0, v0, u1, v1 !< Texture coordinates.
   integer(int32), intent(in), optional :: col            !< Packed colour.
   type(im_texture_ref)                 :: t              !< Texture reference.
   integer(c_int)                       :: c              !< Colour.

   call core_draw_end_pending()
   t%texid = texture
   c = -1_c_int ! 0xFFFFFFFF, opaque white
   if (present(col)) c = int(col, c_int)
   call ImDrawList_AddImage(target_list, t, v2(x0, y0), v2(x1, y1), v2(opt64(u0, 0.0_real64), opt64(v0, 0.0_real64)), &
                            v2(opt64(u1, 1.0_real64), opt64(v1, 1.0_real64)), c)
   endsubroutine core_draw_image

   subroutine core_push_clip_rect(x0, y0, x1, y1, intersect)
   !< Clip what follows to a rectangle (`PushClipRect`), intersected with the current one (default true).
   real(real64), intent(in)           :: x0, y0, x1, y1 !< Rectangle [pixels].
   logical,      intent(in), optional :: intersect      !< Intersect with the current clip rectangle.
   logical(c_bool)                    :: i              !< C copy.

   call core_draw_end_pending()
   i = .true.
   if (present(intersect)) i = logical(intersect, c_bool)
   call ImDrawList_PushClipRect(target_list, v2(x0, y0), v2(x1, y1), i)
   endsubroutine core_push_clip_rect

   subroutine core_pop_clip_rect()
   !< Restore the clip rectangle (`PopClipRect`).

   call core_draw_end_pending()
   call ImDrawList_PopClipRect(target_list)
   endsubroutine core_pop_clip_rect

   subroutine core_draw_callback(callback, data)
   !< A callback the renderer calls at this point of the list (`AddCallback`, no copied data).
   type(c_funptr), intent(in) :: callback !< `void (*)(const ImDrawList*, const ImDrawCmd*)`.
   type(c_ptr),    intent(in) :: data     !< Its user data.

   call core_draw_end_pending()
   call ImDrawList_AddCallback(target_list, callback, data, 0_c_size_t)
   endsubroutine core_draw_callback

   subroutine core_draw_line_h(x0, x1, y, col, thickness)
   !< A horizontal line from x0 to x1 (Dear ImGui 1.93's `AddLineH`, flags 0): the stroke below `y` (inside), drawn as
   !< a rectangle when pixel-aligned, `thickness` pixels wide (default 1).
   real(real64),   intent(in)           :: x0, x1, y !< Ends and ordinate [pixels].
   integer(int32), intent(in)           :: col       !< Packed colour.
   real(real64),   intent(in), optional :: thickness !< Thickness [pixels].

   call core_draw_end_pending()
   call ImDrawList_AddLineH(target_list, real(x0, c_float), real(x1, c_float), real(y, c_float), int(col, c_int), &
                            opt(thickness, 1.0_real64), 0_c_int)
   endsubroutine core_draw_line_h

   subroutine core_draw_line_v(x, y0, y1, col, thickness)
   !< A vertical line from y0 to y1 (Dear ImGui 1.93's `AddLineV`, flags 0): the stroke right of `x` (inside), drawn as
   !< a rectangle when pixel-aligned, `thickness` pixels wide (default 1).
   real(real64),   intent(in)           :: x, y0, y1 !< Abscissa and ends [pixels].
   integer(int32), intent(in)           :: col       !< Packed colour.
   real(real64),   intent(in), optional :: thickness !< Thickness [pixels].

   call core_draw_end_pending()
   call ImDrawList_AddLineV(target_list, real(x, c_float), real(y0, c_float), real(y1, c_float), int(col, c_int), &
                            opt(thickness, 1.0_real64), 0_c_int)
   endsubroutine core_draw_line_v

   subroutine core_white_pixel(u, v)
   !< The texture coordinates of the font atlas's white pixel (`_Data->TexUvWhitePixel`, read at `core_draw_begin`):
   !< what filled primitives written vertex by vertex take (the plot frame's items, `core_draw_quad_uv`).
   real(real64), intent(out) :: u, v !< Texture coordinates.

   u = real(list%uv_white(1), real64)
   v = real(list%uv_white(2), real64)
   endsubroutine core_white_pixel

   subroutine core_texture_sampling(from_texture)
   !< Around a user image (the plot frame's `pf_image`, `pf_field_image`): the renderer samples with the texture's own
   !< filter (`from_texture` true) or its default again (false): FIGURE's native `fig_texture_sampling` on the window's
   !< list, after what is pending (so the callback lands in order).
   logical, intent(in) :: from_texture !< The texture's own filter.

   call core_draw_end_pending()
   call fig_texture_sampling(0_c_int, merge(1_c_int, 0_c_int, from_texture))
   endsubroutine core_texture_sampling

   function core_delta_time() result(dt)
   !< io.DeltaTime: the time since the last frame [s] (the 3-D plots' rotation animation).
   real(real64)              :: dt !< Time [s].
   type(im_io_head), pointer :: io !< Dear ImGui's io.

   call c_f_pointer(igGetIO_Nil(), io)
   dt = real(io%delta_time, real64)
   endfunction core_delta_time

   subroutine core_style_color_rgba(idx, rgba)
   !< A style colour (`ImGuiCol_*`) as its four float channels (`GetStyleColorVec4`, no alpha factor).
   integer(int32), intent(in)  :: idx     !< Colour.
   real(real64),   intent(out) :: rgba(4) !< Channels.
   type(im_vec4), pointer      :: c       !< Dear ImGui's.

   call c_f_pointer(igGetStyleColorVec4(int(idx, c_int)), c)
   rgba(1) = real(c%x, real64)
   rgba(2) = real(c%y, real64)
   rgba(3) = real(c%z, real64)
   rgba(4) = real(c%w, real64)
   endsubroutine core_style_color_rgba

   subroutine core_framebuffer_scale(sx, sy)
   !< io.DisplayFramebufferScale: display pixels per pixel (the plot frame's decimation, as figure_implot's).
   real(real64), intent(out) :: sx, sy !< Scale.
   type(im_io_head), pointer :: io     !< Dear ImGui's io.

   call c_f_pointer(igGetIO_Nil(), io)
   sx = real(io%display_framebuffer_scale(1), real64)
   sy = real(io%display_framebuffer_scale(2), real64)
   endsubroutine core_framebuffer_scale

   subroutine core_line_texture(thickness, uv0, uv1, fringe)
   !< The texture coordinates of the two sides of an anti-aliased line `thickness` screen pixels wide (at least 1), and
   !< its fringe [pixels] (`_SelectLineTexture` with the list's flags; without anti-aliased lines: the white pixel, 0).
   real(real64), intent(in)  :: thickness !< Thickness [screen pixels].
   real(real64), intent(out) :: uv0(2)    !< One side's (u, v).
   real(real64), intent(out) :: uv1(2)    !< The other's.
   real(real64), intent(out) :: fringe    !< Fringe [pixels].
   type(im_vec2)             :: a, b      !< C values.
   real(c_float)             :: f         !< C value.

   if (.not. c_associated(target_list)) target_list = igGetWindowDrawList() ! it reads the list: what is pending stays
   call ImDrawList__SelectLineTexture(target_list, real(thickness, c_float), a, b, f, list%flags)
   uv0 = [real(a%x, real64), real(a%y, real64)]
   uv1 = [real(b%x, real64), real(b%y, real64)]
   fringe = real(f, real64)
   endsubroutine core_line_texture

   subroutine core_draw_prims(x, y, u, v, col, idx, texture)
   !< Vertices and triangles as given, appended in order (the 3-D plots' depth-sorted triangles: ImPlot3D's
   !< `SortedMoveToImGuiDrawList`, `PrimReserve` and its 16-bit indices included): positions [pixels] and texture
   !< coordinates in single precision, packed colours, three 0-based vertex indices per triangle; with `texture`
   !< (an `ImTextureID`), drawn with it (`PushTexture`, `PopTexture` around them).
   real(real32),   intent(in)           :: x(:), y(:) !< Positions.
   real(real32),   intent(in)           :: u(:), v(:) !< Texture coordinates.
   integer(int32), intent(in)           :: col(:)     !< Colours.
   integer(int32), intent(in)           :: idx(:)     !< Triangles.
   integer(int64), intent(in), optional :: texture    !< Texture.
   type(im_texture_ref)                 :: t          !< Its reference.

   if (.not. present(texture)) then
      call open_list()
      call dl_prims(list, x, y, u, v, col, idx)
      return
   endif
   call core_draw_end_pending()
   t%texid = texture
   call ImDrawList_PushTexture(target_list, t)
   call open_list()
   call dl_prims(list, x, y, u, v, col, idx)
   call core_draw_end_pending()
   call ImDrawList_PopTexture(target_list)
   endsubroutine core_draw_prims

   subroutine core_draw_quad_uv(x, y, u, v, col)
   !< A quad of four textured vertices, triangles (1, 2, 3) and (1, 3, 4) (`PrimReserve(6, 4)` and `PrimQuadUV`, into
   !< the Fortran list: `dl_quad_uv`): the texture is the list's current one (the font atlas: its white pixel, a line's
   !< texture).
   real(real64),   intent(in) :: x(4), y(4)   !< Vertices [pixels].
   real(real64),   intent(in) :: u(4), v(4)   !< Their texture coordinates.
   integer(int32), intent(in) :: col          !< Packed colour.
   real(c_float)              :: fx(4), fy(4) !< Vertices, C kind.
   real(c_float)              :: fu(4), fv(4) !< Texture coordinates, C kind.

   fx(1) = real(x(1), c_float)
   fx(2) = real(x(2), c_float)
   fx(3) = real(x(3), c_float)
   fx(4) = real(x(4), c_float)
   fy(1) = real(y(1), c_float)
   fy(2) = real(y(2), c_float)
   fy(3) = real(y(3), c_float)
   fy(4) = real(y(4), c_float)
   fu(1) = real(u(1), c_float)
   fu(2) = real(u(2), c_float)
   fu(3) = real(u(3), c_float)
   fu(4) = real(u(4), c_float)
   fv(1) = real(v(1), c_float)
   fv(2) = real(v(2), c_float)
   fv(3) = real(v(3), c_float)
   fv(4) = real(v(4), c_float)
   call open_list()
   call dl_quad_uv(list, fx, fy, fu, fv, int(col, c_int32_t))
   endsubroutine core_draw_quad_uv

   subroutine core_prim_reserve(nvtx, nidx, iv, ii, base)
   !< `PrimReserve(nidx, nvtx)` on the Fortran list (`dl_reserve`): room for nvtx vertices and nidx indices, written in
   !< place by the caller into `core_prim_list()`: the vertices at `%vtx(iv:iv + nvtx - 1)`, the indices at
   !< `%idx(ii:ii + nidx - 1)`, 0-based in the batch from `base` (the first vertex's). A reservation that opens a new
   !< batch appends the finished ones to Dear ImGui and starts the list again: what was reserved before it must be
   !< written or given back first (as ImPlot's `RenderPrimitivesEx` does).
   integer(int32), intent(in)  :: nvtx !< Vertices.
   integer(int32), intent(in)  :: nidx !< Indices.
   integer(int32), intent(out) :: iv   !< First vertex's place in the list's `vtx`.
   integer(int32), intent(out) :: ii   !< First index's place in the list's `idx`.
   integer(int32), intent(out) :: base !< First vertex, 0-based in its batch.

   call open_list()
   call dl_reserve(list, nvtx, nidx, base)
   iv = list%nvtx - nvtx + 1_int32
   ii = list%nidx - nidx + 1_int32
   endsubroutine core_prim_reserve

   subroutine core_prim_unreserve(nvtx, nidx)
   !< `PrimUnreserve(nidx, nvtx)` on the Fortran list (`dl_unreserve`): the last room reserved and not written given back.
   integer(int32), intent(in) :: nvtx !< Vertices.
   integer(int32), intent(in) :: nidx !< Indices.

   call dl_unreserve(list, nvtx, nidx)
   endsubroutine core_prim_unreserve

   function core_prim_vtx_current() result(n)
   !< The window's draw command's vertices as Dear ImGui's `_VtxCurrentIdx` counts them, with the Fortran list's pending
   !< ones and reserved ones (`dl_vtx_current`): what ImPlot sizes a run of primitives by.
   integer(int32) :: n !< Vertices.

   call open_list()
   n = dl_vtx_current(list)
   endfunction core_prim_vtx_current

   function core_prim_list() result(dl)
   !< The Fortran draw list the primitives go to, for a loop that writes its reservations in place.
   type(draw_list), pointer :: dl !< List.

   dl => list
   endfunction core_prim_list

   subroutine core_run_reserve(nvtx, nidx, iv, ii, base, vtx, idx)
   !< `PrimReserve(nidx, nvtx)` in the target list itself (szaghi/figure#16 D2), for a run of primitives written in
   !< place: what the Fortran list holds appended first (the order of the calls kept); `vtx` and `idx` are the whole of
   !< the target's buffers (valid until the next reservation, which may move them), the room at `vtx(iv:iv + nvtx -
   !< 1)` and `idx(ii:ii + nidx - 1)`. The indices are the target's (Dear ImGui's `ImDrawIdx`, 16-bit), absolute in its
   !< draw command from `base`, the first vertex's (`_VtxCurrentIdx` there: a new command started where `PrimReserve`
   !< starts one, base 0): a vertex number v (0 to 65535) is stored as `v - ishft(iand(v, 32768), 1)`, its 16-bit
   !< pattern. The target's vertex count moves past the room as if written: what is not written is given back with
   !< `core_run_unreserve` before the next reservation or draw.
   integer(int32),     intent(in)                      :: nvtx   !< Vertices.
   integer(int32),     intent(in)                      :: nidx   !< Indices.
   integer(int32),     intent(out)                     :: iv     !< First vertex's place in vtx.
   integer(int32),     intent(out)                     :: ii     !< First index's place in idx.
   integer(int32),     intent(out)                     :: base   !< First vertex's index in the draw command.
   type(draw_vert),    intent(inout), pointer, contiguous :: vtx(:) !< The target's vertices.
   integer(c_int16_t), intent(inout), pointer, contiguous :: idx(:) !< The target's indices.
   type(c_ptr)                                         :: pv, pi !< Buffers.
   integer(c_int)                                      :: nv, ni, b !< Their sizes, the base.

   call core_draw_end_pending()
   call figure_ImDrawList_reserve(target_list, int(nvtx, c_int), int(nidx, c_int), b, pv, nv, pi, ni)
   call c_f_pointer(pv, vtx, [nv])
   call c_f_pointer(pi, idx, [ni])
   iv = int(nv, int32) - nvtx + 1_int32
   ii = int(ni, int32) - nidx + 1_int32
   base = int(b, int32)
   endsubroutine core_run_reserve

   subroutine core_run_unreserve(nvtx, nidx)
   !< `PrimUnreserve(nidx, nvtx)` in the target list (szaghi/figure#16 D2): the end of the last room of
   !< `core_run_reserve` given back unwritten, the target's vertex count moved back.
   integer(int32), intent(in) :: nvtx !< Vertices.
   integer(int32), intent(in) :: nidx !< Indices.

   call figure_ImDrawList_unreserve(target_list, int(nvtx, c_int), int(nidx, c_int))
   endsubroutine core_run_unreserve

   function core_run_vtx_current() result(n)
   !< The target's draw command's vertices (Dear ImGui's `_VtxCurrentIdx`, the room of `core_run_reserve` not given
   !< back included), what the Fortran list holds appended first: what ImPlot sizes a run of primitives by.
   integer(int32)                   :: n !< Vertices.
   type(im_draw_list_head), pointer :: h !< Dear ImGui's list.

   call core_draw_end_pending()
   call c_f_pointer(target_list, h)
   n = int(h%vtx_current_idx, int32)
   endfunction core_run_vtx_current

   subroutine core_font_glyph(c, found, scale, advance, x0, y0, x1, y1, u0, v0, u1, v1)
   !< A glyph of the current font at the current size (`g.Font->GetFontBaked(g.FontSize)`, `FindGlyph((ImWchar)c)`:
   !< the fallback glyph when the font has none), in the baked font's units: its corners from the pen (x0, y0)-(x1, y1),
   !< its texture coordinates in the font atlas, its advance, and `scale`, the current size over the baked one (what
   !< ImPlot's `AddTextVertical` multiplies them by). `found` false: no glyph (the values 0).
   integer(int32), intent(in)           :: c              !< Code point (taken modulo 2**16, as `ImWchar`).
   logical,        intent(out)          :: found          !< A glyph.
   real(real64),   intent(out)          :: scale          !< Font size over the baked size.
   real(real64),   intent(out)          :: advance        !< AdvanceX.
   real(real64),   intent(out)          :: x0, y0, x1, y1 !< Corners.
   real(real64),   intent(out)          :: u0, v0, u1, v1 !< Texture coordinates.
   type(c_ptr)                          :: baked, glyph   !< C objects.
   type(im_font_baked_head), pointer    :: b              !< Baked font.
   type(im_font_glyph),      pointer    :: g              !< Glyph.
   integer(int32)                       :: w              !< 16-bit value.

   found = .false.
   scale = 0.0_real64
   advance = 0.0_real64
   x0 = 0.0_real64
   y0 = 0.0_real64
   x1 = 0.0_real64
   y1 = 0.0_real64
   u0 = 0.0_real64
   v0 = 0.0_real64
   u1 = 0.0_real64
   v1 = 0.0_real64
   baked = ImFont_GetFontBaked(igGetFont(), igGetFontSize(), -1.0_c_float)
   if (.not. c_associated(baked)) return
   call c_f_pointer(baked, b)
   w = iand(c, 65535_int32)
   if (w > 32767_int32) w = w - 65536_int32
   glyph = ImFontBaked_FindGlyph(baked, int(w, c_int16_t))
   if (.not. c_associated(glyph)) return
   call c_f_pointer(glyph, g)
   found = .true.
   scale = real(igGetFontSize() / b%size, real64)
   advance = real(g%advance_x, real64)
   x0 = real(g%x0, real64)
   y0 = real(g%y0, real64)
   x1 = real(g%x1, real64)
   y1 = real(g%y1, real64)
   u0 = real(g%u0, real64)
   v0 = real(g%v0, real64)
   u1 = real(g%u1, real64)
   v1 = real(g%v1, real64)
   endsubroutine core_font_glyph

   ! private

   subroutine core_draw_end_pending()
   !< Append what is pending before Dear ImGui's list draws (the order of the calls kept); the list stays bound.
   type(c_ptr) :: keep !< The bound list.

   if (.not. c_associated(target_list)) target_list = igGetWindowDrawList()
   if (list%nbatch == 0_int32) return ! (an opened list, even empty, is reset: its first batch is opened again)
   keep = target_list
   call core_draw_end()
   target_list = keep
   endsubroutine core_draw_end_pending

   subroutine open_list()
   !< Before the Fortran list's primitives: an empty list opened in the window's draw command, which holds
   !< `_VtxCurrentIdx` vertices already (so its batches split where Dear ImGui's would), its sink set.
   type(im_draw_list_head), pointer :: h !< Dear ImGui's list.

   if (list%nbatch > 0_int32) return
   if (.not. c_associated(target_list)) target_list = igGetWindowDrawList()
   if (.not. associated(list%sink)) list%sink => append_batch
   call c_f_pointer(target_list, h)
   call dl_open(list, int(h%vtx_current_idx, int32))
   endsubroutine open_list

   subroutine append_batch(vtx, nv, idx, ni, split)
   !< A batch of the Fortran list appended to Dear ImGui's as one primitive (the list's sink), a draw command started
   !< first when it starts one (`split`: `PrimReserve`'s, at a 16-bit wrap).
   integer(int32),  intent(in)         :: nv      !< Vertices.
   type(draw_vert), intent(in), target :: vtx(nv) !< The batch's vertices.
   integer(int32),  intent(in)         :: ni      !< Indices.
   integer(c_int),  intent(in)         :: idx(ni) !< Its indices, 0-based in the batch.
   logical,         intent(in)         :: split   !< It starts a draw command.

   if (nv > 0_int32) then
      call figure_ImDrawList_append(target_list, c_loc(vtx), int(nv, c_int), idx, int(ni, c_int), &
                                    merge(1_c_int, 0_c_int, split))
   else ! (no vertices: the command started only; c_loc of an empty array is not allowed)
      call figure_ImDrawList_append(target_list, c_null_ptr, 0_c_int, idx, 0_c_int, merge(1_c_int, 0_c_int, split))
   endif
   endsubroutine append_batch

   pure function rect(x0, y0, x1, y1) result(r)
   !< An `ImRect`.
   real(real64), intent(in) :: x0, y0, x1, y1 !< Corners [pixels].
   type(im_rect)            :: r              !< Rectangle.

   r%min = im_vec2(real(x0, c_float), real(y0, c_float))
   r%max = im_vec2(real(x1, c_float), real(y1, c_float))
   endfunction rect

   pure function v2(x, y) result(v)
   !< An `ImVec2`.
   real(real64), intent(in) :: x, y !< Components.
   type(im_vec2)            :: v    !< Vector.

   v = im_vec2(real(x, c_float), real(y, c_float))
   endfunction v2

   pure function opt(x, default) result(v)
   !< An optional value as a C float.
   real(real64), intent(in), optional :: x       !< Value.
   real(real64), intent(in)           :: default !< Default.
   real(c_float)                      :: v       !< C value.

   v = real(default, c_float)
   if (present(x)) v = real(x, c_float)
   endfunction opt

   pure function opt64(x, default) result(v)
   !< An optional value.
   real(real64), intent(in), optional :: x       !< Value.
   real(real64), intent(in)           :: default !< Default.
   real(real64)                       :: v       !< Value.

   v = default
   if (present(x)) v = x
   endfunction opt64
endmodule figure_core
